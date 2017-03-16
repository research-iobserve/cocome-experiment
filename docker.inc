##########################
# docker setup

check $DOCKER_CTL "docker not found"

# stop services
function stop_services () {
	for ID_KEY in "${!IDS[@]}" ; do
        	ID=${IDS[$ID_KEY]}
		echo -n "Stopping and removing $ID_KEY with id "
		$DOCKER_CTL stop "$ID"
		$DOCKER_CTL rm "$ID"
        done
}

# detect running nodes
function detect_running_nodes () {
	for SERVER in $NODE_TYPES ; do
		ID=`$DOCKER_CTL ps -a | grep $SERVER | awk '{ print $1 }'`
		if [ "$ID" != "" ] ; then
			IDS[$SERVER]="$ID"
		fi
	done
}

# get container IP address
function get_container_ip_address () {
	IP=""

	while [ "$IP" == "" ] ; do
		IP=`$DOCKER_CTL inspect $1 | grep IPAddress | tail -1 | awk '{ print $2 }' | sed 's/^\"\(.*\)\",$/\1/g'`
		if [ "$IP" == "" ] ; then
			sleep 5
		else
			IPS[$SERVER]=$IP
		fi
	done
}

# start service
function start_service () {
	ID=`$DOCKER_CTL run -h "$1" --name="$1" -d $2`
	IDS[$SERVER]=$ID
	echo $ID
}

