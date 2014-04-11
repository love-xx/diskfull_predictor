#!/bin/bash

# walks trough each mount point, calculates the interval between the first and last check, and uses it as a step to calculate when it will get full
# support: gyula.weber.in@gmail.com
DEBUG=0

if [ "$1" = "-v" ]; then
	DEBUG=1
	shift
fi
WINDOWSIZE="$@"

# debug
function dbg {
	if [ $DEBUG -eq 1 ]; then
		I=2
		echo "( $@ )"
	fi
}

# display
function dsp {
    echo "$@"
}

TODAY=$(date  +"%Y-%m-%d")

sqlite3 ./disk.sqlite3 "select distinct mount_point from disk_info" | while read MP; do
	echo
    dbg "### disk stats for ${MP} ####"
	NEGATIVE=0
	MAX=$(sqlite3 ./disk.sqlite3 "select dt from disk_info where mount_point like '${MP}' order by dt desc limit 1")
	MIN=""
	if [ ${#WINDOWSIZE} -lt 3 ]; then
		# get minimum window size
		MIN=$(sqlite3 ./disk.sqlite3 "select dt from disk_info where mount_point like '${MP}' order by dt desc limit 2,1")
	else
		MIN=$(sqlite3 ./disk.sqlite3 "select datetime('now','-${WINDOWSIZE}')")
	fi
		
		dbg "max: ${MAX}"
		dbg "min: ${MIN}"
		MAXDT=$(sqlite3 ./disk.sqlite3 "select strftime('%s','${MAX}')")
		MINDT=$(sqlite3 ./disk.sqlite3 "select strftime('%s','${MIN}')")
		dbg "maxdt: ${MAXDT}"
		dbg "mindt: ${MINDT}"
		DTDIFF=$(($MAXDT-$MINDT))
		dbg "dtdiff: ${DTDIFF}"
		FREE=$(sqlite3 ./disk.sqlite3 "select free from disk_info order by dt desc limit 1")
		dbg "free: ${FREE}"
		DIFF=$(sqlite3 ./disk.sqlite3 "select sum(diff) from disk_info where dt > '$MIN'")
		dbg "space diff: ${DIFF}"
		WINDOW_CNT=$(($FREE/$DIFF))
		dbg "window cnt: ${WINDOW_CNT}"
		TS_OFFSET=$((DTDIFF*WINDOW_CNT))
		if [ $TS_OFFSET -lt 0 ]; then
			NEGATIVE=1
		fi
		dbg "timestamp offset: ${TS_OFFSET}"
		REAL_TS=$(($MAXDT+$TS_OFFSET))
		dbg "real timestamp: ${REAL_TS}"
		FILL_DT=$(sqlite3 ./disk.sqlite3 "select datetime($REAL_TS,'unixepoch','localtime')")
		dbg "predicted fill dt: ${FILL_DT}"

	if [ $DIFF -lt 1 ]; then
		dbg "negative of zero offset, free space is increased in the given period"
		NEGATIVE=1
	fi
	
	if [ $NEGATIVE -ne 1 ]; then
		dsp "${MP} will fill on ${FILL_DT}"
	else
		dbg "its negative"
	fi

done
