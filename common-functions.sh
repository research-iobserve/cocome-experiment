
# $1 = program
# $2 = name
function check_rec () {
	if [ -f "$1" ] ; then
		if [ -x "$1" ] ; then
			$1 check
		else
			echo "$2 program '$1' is not executable."
			exit 1
		fi
	else
		echo "$2 program '$1' not found."
		exit 1
	fi
}

function check_rec_param () {
	if [ -f "$1" ] ; then
		if [ -x "$1" ] ; then
			$1 $2 check
		else
			echo "$2 program '$1' is not executable."
			exit 1
		fi
	else
		echo "$2 program '$1' not found."
		exit 1
	fi
}

# $1 = program
# $2 = name
function check () {
	if [ -f "$1" ] ; then
		if [ ! -x "$1" ] ; then
			echo "$2 program '$1' is not executable."
			exit 1
		fi
	else
		echo "$2 program '$1' not found."
		exit 1
	fi
}

# $1 = file
# $2 = access
function check_file () {
	if [ -f "$1" ] ; then
		if [ "$2" == "r" ] ; then
			if [ ! -r "$1" ] ; then
				echo "No read permission for $3 file '$1'."
				exit 1
			fi
		elif [ "$2" == "w" ] ; then
			if [ ! -w "$1" ] ; then
				echo "No write permission for $3 file '$1'."
				exit 1
			fi
		else
			echo "Missing or wrong parameter '$2'"
			exit 1
		fi
	else
		if [ "$2" != "w" ] ; then
			echo "File '$1' not found for $3"
			exit 1
		fi
	fi
}

# $1 = directory
# $2 = label
function check_dir () {
	if [ ! -d "$1" ] ; then
		echo "$1 is not a $2."
		exit 1
	fi
}

# end
