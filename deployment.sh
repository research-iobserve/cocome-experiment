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

check $LOCAL_GLASSFISH_ADMIN "local glassfish admin"

# parsing parameter
if [ "$1" == "" ] ; then
	echo "Usage: $0 <deploy|undeploy|redeploy|status|check> [container]"
	exit 1
elif [ "$1" == "check" ] ; then
	echo "check successful"
	exit 0
else
	mode="$1"
fi

if [ "$2" != "" ] ; then
	specific_container="$2"
fi

# $1 = ip
# $2 = container type
function isDeployed() {
	ip="$1"
	container="${CONTAINER[$2]}"
	port="${PORTS[${DOMAINS[$2]}]}"
	result=`"$LOCAL_GLASSFISH_ADMIN" --host "$ip" -p "$port" --user "$GLASSFISH_ADMIN_LOGIN" -W "${LOCAL_GLASSFISH_PW_FILE}" list-applications | grep "$container-$REVISION"`
	if [ "$result" == "" ] ; then
		return 1
	else
		return 0
	fi
}


## commands

function undeploy() {
	ip="$1"
	container="${CONTAINER[$2]}"
	port="${PORTS[${DOMAINS[$2]}]}"
	if isDeployed $1 $2 ; then
		echo "Undeploy from $ip: $2 ($container)"
		"$LOCAL_GLASSFISH_ADMIN" --host "$ip" -p $port --user "$GLASSFISH_ADMIN_LOGIN" \
			-W "${LOCAL_GLASSFISH_PW_FILE}" undeploy "$container-$REVISION"
	else
		echo "Already undeployed from $ip: $2 ($container)"
	fi
}

function deploy() {
	if isDeployed $1 $2 ; then
		echo "Already deployed on $1: $2"
 	else
		echo "Deploy $2 to $ip"

		# check dependencies and deploy them if necessary
		for DEP in ${DEPENDS_ON[$2]} ; do
			for HOST in ${HOST_TYPES[$DEP]} ; do
				if ! isDeployed $HOST $DEP ; then
					deploy $HOST $DEP
				fi
			done
		done

		# deploy requested container
		ip="$1"
		container="${CONTAINER[$2]}"
		port="${PORTS[${DOMAINS[$2]}]}"

		DIRS=""
		for DIR in ${LOCATIONS[*]} ; do
			RES=`find $BASE/$DIR -name "$container-$REVISION.[ew]ar"`
			NAME=`echo $RES | sed 's/^.*\/\([^\/]*\)-[0-9]*\.[0-9]*\.[ew]ar$/\1/g'`
			if [ "$RES" != "" ] ; then
				deployed="false"
				retry=0
				while [ "$deployed" == "false" ] ; do
					if "$LOCAL_GLASSFISH_ADMIN" --host "$ip" -p $port --user "$GLASSFISH_ADMIN_LOGIN" \
						-W ${LOCAL_GLASSFISH_PW_FILE} deploy --force=true --contextroot "$NAME" "$RES" ; then
						echo "Success"
						deployed="true"
					else
						echo "Deployment unsuccessfull"
						retry=`expr $retry + 1`
						if [ "$retry" == "5" ] ; then
							echo "FAIL --- deployment failed, recovery strategy failed"
							exit 5
						fi
					fi
				done

				return
			fi
		done

		echo "Container $2 not found"
	fi
}

function status() {
	echo -n "Status of $1: "
	if isDeployed $1 $2 ; then
		echo "deployed     $2"
	else
		echo "Not deployed $2"
	fi
}

## main
for CONTAINER_TYPE in "${!CONTAINER[@]}" ; do
	if [ "$specific_container" == "" -o "$specific_container" = "$CONTAINER_TYPE" ] ; then
		echo "# $mode $CONTAINER_TYPE"
		for HOSTS in ${HOST_TYPES[$CONTAINER_TYPE]} ; do
			for HOST in $HOSTS ; do
				if [ "$mode" == "deploy" ] ; then
					deploy "$HOST" "$CONTAINER_TYPE"
				elif [ "$mode" == "undeploy" ] ; then
					undeploy "$HOST" "$CONTAINER_TYPE"
				elif [ "$mode" == "redeploy" ] ; then
					undeploy "$HOST" "$CONTAINER_TYPE"
					deploy "$HOST" "$CONTAINER_TYPE"
				elif [ "$mode" == "status" ] ; then
					status "$HOST" "$CONTAINER_TYPE"
				else
					echo "$HOST - $CONTAINER_TYPE"
				fi
			done
		done
		echo ""
	fi
done

# end

