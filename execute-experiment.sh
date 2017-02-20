#!/bin/bash

START_DATE=`date`

BINDIR=$(cd "$(dirname "$0")"; pwd)/

# global initialization
if [ ! -f "$BINDIR/global-config.rc" ] ; then
	echo "Missing global-config.rc Cannot execute $0 script."
	exit 1
else
	. "$BINDIR/global-config.rc"
fi

# global initialization
if [ ! -f "$BINDIR/common-functions.sh" ] ; then
	echo "Missing common-functions.sh Cannot execute $0 script."
	exit 1
else
	. "$BINDIR/common-functions.sh"
fi

NODE_ALLOCATION="$BINDIR/allocate-cocome.sh"
DEPLOYMENT_SCRIPT="$BINDIR/deployment.sh"
ANALYSIS_SCRIPT="$BINDIR/run-analysis.sh"
COMPILE_RESULTS_SCRIPT="$BINDIR/compile-results.sh"


#
# test input parameters
if [ "$1" == "docker" ] ; then
	VIRT_MODE="docker"
elif [ "$1" == "kube" ] ; then
	VIRT_MODE="kube"
else
	echo "Only docker and kube are allowed as virtualization modes. Mode $1 unknown"
	exit 1
fi

# test if we have a jmeter script
if [ "$2" != "" ] ; then
	if [ -f "$2" ] ; then
		export LOADDRIVER="$2"
		echo "Load driver: $LOADDRIVER"
	else
		echo "$2 is not a file."
		exit 1
	fi
else
	echo "Missing parameter: jmeter file."
	exit 1
fi

echo "------------------------------"
echo "Check setup"
echo "------------------------------"
echo ""

#
# test configuration parameters
check_dir $BASE "base directory"
check_file $INIT_COCOME r "CoCoME initialization"

check $JMETER "jmeter"
check $PSQL "psql client"
check $LOCAL_GLASSFISH_ADMIN "local glassfish installation"
check $KIEKER_TRACE_ANALYSIS "kieker trace analysis"
check $KIEKER_DOT_PIC_CONVERTER "kieker pic doc converter"
check $COLLECTOR "data collector"
check $PSQL "postgres client"
check_rec_param $NODE_ALLOCATION $VIRT_MODE "allocation script"
check_rec $DEPLOYMENT_SCRIPT "deployment script"
check_dir $DATA_PATH
check_dir $OUTPUT_PATH
check_dir $VISUALIZATION_PATH

#
# cleanup function in case the experiment setup fails.
function cleanup () {
	$NODE_ALLOCATION $VIRT_MODE stop
	kill -TERM $COLLECTOR_PID
	exit $1
}

#### prepare experiment
echo ""
echo ""
echo "---------------------------------"
echo "Prepare experiment environment"
echo "---------------------------------"
echo ""

echo "Before continuing, make sure no other experiment is running."
echo "If sure press return to continue"
read

# stop still running nodes
echo "Stopping nodes from previous setups"
$NODE_ALLOCATION $VIRT_MODE stop
echo "We must wait for all nodes to have stopped."
echo "Check your kubernetes console/docker ps that this really is the case."
echo "Press return to continue"
read
echo ""

# start nodes
echo "Start nodes for this setup"
$NODE_ALLOCATION $VIRT_MODE start || exit $?

# reload host rc setup
echo "Reload host configuration"
. $BINDIR/hosts.rc

# test availability of all services
echo "List available nodes"

for HOST_KEY in "${!HOST_TYPES[@]}" ; do
	for HOST in ${HOST_TYPES[$HOST_KEY]} ; do
		if ping "$HOST" -c 1 >& /dev/null ; then 
			echo "$HOST available"
		else
			echo "$HOST missing -- retry"
			sleep 10

			if ping "$HOST" -c 1 >& /dev/null ; then 
				echo "$HOST available"
			else
				echo "$HOST missing -- abort"
				cleanup 1
			fi
		fi
	done
done

# Clean directory
echo "Save any files in the data, analysis and visualizations."
echo "Press return to continue"
read

rm -rf $DATA_PATH/kieker-*
rm -rf $OUTPUT_PATH/*
rm -rf $VISUALIZATION_PATH/*

#### initialize experiment
echo ""
echo ""
echo "---------------------------------"
echo "Initialize experiment environment"
echo "---------------------------------"
echo ""

# start collector
$COLLECTOR -p $COLLECTOR_PORT -d $DATA_PATH &
export COLLECTOR_PID=$!

sleep 5

# deploy all services
$DEPLOYMENT_SCRIPT deploy || cleanup $?

# run jmeter initialization
echo "Run jmeter for initialization ${HOST_TYPES[web]}"
$JMETER -p "$BINDIR/jmeter.properties" -l "$BINDIR/results.csv" -n -t "$INIT_COCOME" -JfrontendIP="${HOST_TYPES[web]}" || cleanup $?

echo "Press return to continue"
read

#### run experiment
echo ""
echo ""
echo "------------------------------"
echo "Execute experiment            "
echo "------------------------------"
echo ""

EXP_START_DATE=`date`

$JMETER -p "$BINDIR/jmeter.properties" -l "$BINDIR/results.csv" -n -t "$LOADDRIVER" -JfrontendIP="${HOST_TYPES[web]}" || cleanup $?

EXP_END_DATE=`date`

$NODE_ALLOCATION $VIRT_MODE stop

kill -TERM $COLLECTOR_PID

#### create visualizations
echo ""
echo ""
echo "------------------------------"
echo "Create Visualizations         "
echo "------------------------------"
echo ""

$ANALYSIS_SCRIPT || cleanup $?
$COMPILE_RESULTS_SCRIPT "$LOADDRIVER" || cleanup $?

END_DATE=`date`

echo ""
echo ""
echo "------------------------------"
echo "Summary"
echo ""
echo "Start:            $START_DATE"
echo "Experiment start: $EXP_START_DATE"
echo "Experiment end:   $EXP_END_DATE"
echo "Complete:         $END_DATE"
echo ""
echo "Done."

# end
