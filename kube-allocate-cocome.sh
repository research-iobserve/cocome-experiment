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

# check setup
check_file $BUILD_SETTINGS_TEMPLATE r
check_file $BUILD_SETTINGS w
check $KUBECTL "kubectl not found"
check $LOCAL_GLASSFISH_ADMIN "local glassfish installation"

if [ "$1" == "start" ] ; then
	declare -A IPS

	# run docker images
	echo "Starting services ..."

	for SERVER in $KUBE_NODE_TYPES ; do
		IMAGE_NAME="blade1.se.internal:5000/${IMAGE[$SERVER]}"
		$KUBECTL --cluster $KUBE_SERVER run "$SERVER" --image=$IMAGE_NAME

		IP="<none>"

		while [ "$IP" == "<none>" ] ; do
			IP=`$KUBECTL --cluster "$KUBE_SERVER" get pods -o wide | grep "$SERVER" | awk '{ print $6 }'`
			if [ "$IP" == "<none>" ] ; then
				sleep 5
			else
				IPS[$SERVER]=$IP
			fi
		done
	done

	# setup build settings
	echo "List IPS ..."
	for IP_KEY in "${!IPS[@]}" ; do
        	IP=${IPS[$IP_KEY]}
		echo "$IP $IP_KEY"
        done

	# connect nodes
	echo "Configuring adapter node ${IPS[adapter]} ..."

	echo "AS_ADMIN_PASSWORD=admin" > pwfile

	retries=0

	while ! $LOCAL_GLASSFISH_ADMIN --user admin --passwordfile pwfile --host ${IPS[adapter]} list-applications >& /dev/null ; do
		echo "Adapter not up and running. Waiting 5 seconds ..."
		sleep 5
		retries=`expr $retries + 1`
		if [ "$retries" == "10" ] ; then
			echo "Allocation unsuccessful"

			for SERVER in $KUBE_NODE_TYPES ; do
		                $KUBECTL --cluster nc05 delete deployments "$SERVER"
		        done

			exit
		fi
	done

	$LOCAL_GLASSFISH_ADMIN --user admin --passwordfile pwfile --host ${IPS[adapter]} --interactive=false \
		create-jdbc-connection-pool \
		--datasourceclassname org.postgresql.ds.PGSimpleDataSource \
		--restype javax.sql.DataSource --property user=cocome:password=dbuser:servername=${IPS[database]}:databasename=cocomedb PostgresPool

	$LOCAL_GLASSFISH_ADMIN --user admin --passwordfile pwfile --host ${IPS[adapter]} --interactive=false \
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
elif [ "$1" == "stop" ] ; then
	echo "Stopping container ..."

	for SERVER in $KUBE_NODE_TYPES ; do
		$KUBECTL --cluster nc05 delete deployments "$SERVER"
	done

	echo "Done."
elif [ "$1" == "check" ] ; then
	echo "$0 check successful"
else
	echo "$0 <start|stop|check>"
fi

# end
