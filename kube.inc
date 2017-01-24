##########################
# kubernetes setup

check $KUBE_CTL "kubectl not found"

# stop services
function stop_services () {
	for SERVER in $NODE_TYPES ; do
		$KUBE_CTL --cluster $KUBE_SERVER delete deployments "$SERVER"
	done
}

# detect running nodes
function detect_running_nodes () {
	# empty as detection is not necessay
	echo -n ""
}

# get container IP address
function get_container_ip_address () {
	IP="<none>"
	while [ "$IP" == "<none>" ] ; do
		IP=`$KUBE_CTL --cluster "$KUBE_SERVER" get pods -o wide | grep "$SERVER" | awk '{ print $6 }'`
		if [ "$IP" == "<none>" ] ; then
			sleep 5
		elif [ "$IP" == "" ] ; then
			IP="<none>"
			sleep 5
		else
			IPS[$SERVER]=$IP
		fi
	done
}

