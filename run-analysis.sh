#!/bin/bash

BINDIR=$(cd "$(dirname "$0")"; pwd)/

# global initialization
if [ ! -f "$BINDIR/global-config.rc" ] ; then
	echo "Missing global-config.rc Cannot execute $0 script."
	exit 1
else
	. "$BINDIR/global-config.rc"
fi

# create input directory
INPUT=""

for I in `find "$DATA_PATH" -type d -name 'kieker-*'` ; do
	INPUT="$INPUT $I"
done

rm -rf "$OUTPUT_PATH"
mkdir "$OUTPUT_PATH"

$KIEKER_TRACE_ANALYSIS -i $INPUT -o "$OUTPUT_PATH" \
       --plot-Deployment-Component-Dependency-Graph \
       --plot-Assembly-Component-Dependency-Graph \
       --plot-Deployment-Operation-Dependency-Graph \
       --plot-Assembly-Operation-Dependency-Graph \
	--plot-Container-Dependency-Graph \
	--plot-Deployment-Operation-Dependency-Graph \
	--plot-Assembly-Operation-Dependency-Graph \
	--plot-Aggregated-Deployment-Call-Tree \
	--plot-Aggregated-Assembly-Call-Tree \
	--print-Message-Traces \
	--print-Execution-Traces \
	--print-invalid-Execution-Traces \
	--print-Deployment-Equivalence-Classes \
	--print-Assembly-Equivalence-Classes \
	--print-System-Model >& /dev/null

rm -rf "$VISUALIZATION_PATH"
mkdir "$VISUALIZATION_PATH"
cd "$OUTPUT_PATH"
$KIEKER_DOT_PIC_CONVERTER . pdf svg
mv *.pdf *.svg *.html "$VISUALIZATION_PATH"

# end

