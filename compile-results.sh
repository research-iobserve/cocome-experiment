#!/bin/bash

# collect results for distribution

# get present directory
PRESENT=$PWD

INTERACTIVE="no"

BINDIR=$(cd "$(dirname "$0")"; pwd)/

# global initialization
if [ ! -f "$BINDIR/global-config.rc" ] ; then
	echo "Missing global-config.rc Cannot execute $0 script."
	exit 1
else
	. "$BINDIR/global-config.rc"
fi

if [ ! -f "$1" ] ; then
	echo "No experiment file."
	INTERACTIVE="yes"
	export EXPERIMENT_FILE="interactive"
	export EXPERIMENT_NAME="interactive"
else
	export EXPERIMENT_FILE="$1"
	export EXPERIMENT_NAME=`basename "$EXPERIMENT_FILE"`
fi

EXP_FILE_NAME="exp-results-$EXPERIMENT_NAME"

TMPDIR="/tmp/$EXP_FILE_NAME"

mkdir "$TMPDIR"

if [ -d "$TMPDIR" ] ; then
	rm -f "$VISUALIZATION_PATH/tmp-*.pdf"
	cp -r "$VISUALIZATION_PATH" "$TMPDIR"
	cp -r $DATA_PATH/* "$TMPDIR"

	cd /tmp
	tar -cvzpf "$PRESENT/$EXP_FILE_NAME.tgz" "$EXP_FILE_NAME"
	rm -rf "$TMPDIR"
else
	echo "$TMPDIR was not created."
fi

# end
