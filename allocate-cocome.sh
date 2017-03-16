#!/bin/bash

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

BUILD_SETTINGS="$BINDIR/docker-settings.xml"
BUILD_SETTINGS_TEMPLATE="$BINDIR/docker-settings.xml.template"

# check parameter
if [ "$1" == "" ] ; then
	echo "$0 <kube|docker> <start|stop|check|status>"
	exit 1
fi

# info
echo "$1 deployments"

# global variables
declare -A IPS
declare -A IDS

# check setup
check_file $BUILD_SETTINGS_TEMPLATE r "build settings template"
check_file $BUILD_SETTINGS w "build settings"
check $LOCAL_GLASSFISH_ADMIN "local glassfish installation"
check_file $LOCAL_GLASSFISH_PW_FILE r "glassfish password file"
check_file "$1.inc" r "specific container control routines"

. $BINDIR/$1.inc

# main program

if [ "$2" == "start" ] ; then
	# run docker images
	echo "Starting services ..."

	for SERVER in $NODE_TYPES ; do
		echo "Service $SERVER"
		if [ "${DOCKER_REPOSITORY}" == "" ] ; then
			ID=`start_service "$SERVER" "${IMAGE[$SERVER]}"`
		else
			ID=`start_service "$SERVER" "${DOCKER_REPOSITORY}/${IMAGE[$SERVER]}"`
		fi
		get_container_ip_address $ID
	done

	# setup build settings
	echo "List IPS ..."
	for IP_KEY in "${!IPS[@]}" ; do
		IP=${IPS[$IP_KEY]}
		echo "$IP $IP_KEY"
	done

	# connect nodes
	echo "Configuring adapter node ${IPS[adapter]} ..."

	retries=0

	while ! $LOCAL_GLASSFISH_ADMIN --user admin --passwordfile $LOCAL_GLASSFISH_PW_FILE --host ${IPS[adapter]} list-applications ; do
		echo "Adapter not up and running. Waiting 5 seconds ..."
		sleep 5
		retries=`expr $retries + 1`
		if [ "$retries" == "10" ] ; then
			echo "Allocation unsuccessful"
			stop_services
			exit
		fi
	done

	$LOCAL_GLASSFISH_ADMIN --user admin --passwordfile $LOCAL_GLASSFISH_PW_FILE --host ${IPS[adapter]} --interactive=false \
		create-jdbc-connection-pool \
		--datasourceclassname org.postgresql.ds.PGSimpleDataSource \
		--restype javax.sql.DataSource --property user=cocome:password=dbuser:servername=${IPS[database]}:databasename=cocomedb PostgresPool

	$LOCAL_GLASSFISH_ADMIN --user admin --passwordfile $LOCAL_GLASSFISH_PW_FILE --host ${IPS[adapter]} --interactive=false \
		create-jdbc-resource --connectionpoolid PostgresPool jdbc/CoCoMEDB

	echo "Configuring build files"

	BUILD_FILE="/tmp/build-now"
	BUILD_FILE_NEXT="/tmp/build-next"

	cp "$BUILD_SETTINGS_TEMPLATE" "$BUILD_FILE"

	for IP_KEY in "${!IPS[@]}" ; do
        	IP=${IPS[$IP_KEY]}
		sed "s/>$IP_KEY</>$IP</g" < "$BUILD_FILE" > "$BUILD_FILE_NEXT"
		mv "$BUILD_FILE_NEXT" "$BUILD_FILE"
        done

	mv "$BUILD_FILE" "$BUILD_SETTINGS"

	echo "Execute build"

	for LOCATION in ${LOCATIONS[@]} ; do
		echo "Build $LOCATION"
		cd "$BINDIR/$LOCATION/"
		mvn -s "$BUILD_SETTINGS" clean compile package
	done

	echo "Configure deployment configuration"

	echo "HOST_TYPES[web]=\"${IPS[web]}\"" > $BINDIR/hosts.rc
	echo "HOST_TYPES[store]=\"${IPS[store]}\"" >> $BINDIR/hosts.rc
	echo "HOST_TYPES[registry]=\"${IPS[registry]}\"" >> $BINDIR/hosts.rc
	echo "HOST_TYPES[enterprise]=\"${IPS[enterprise]}\"" >> $BINDIR/hosts.rc
	echo "HOST_TYPES[adapter]=\"${IPS[adapter]}\"" >> $BINDIR/hosts.rc
	echo "HOST_TYPES[database]=\"${IPS[database]}\"" >> $BINDIR/hosts.rc

	echo "Done."
elif [ "$2" == "stop" ] ; then
	echo "Stopping container ..."

	detect_running_nodes

	stop_services

	echo "Done."
elif [ "$2" == "check" ] ; then
	echo "$0 check successful"
elif [ "$2" == "status" ] ; then
	echo "$0 status"
else
	echo "$0 <start|stop|check|status> <kube|docker>"
fi

# end
