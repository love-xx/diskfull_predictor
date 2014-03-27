#!/bin/bash

# walks trough each mount point, calculates the interval between the first and last check, and uses it as a step to calculate when it will get full
# support: gyula.weber.in@gmail.com
WINDOWSIZE="$@"

# debug
function dbg {
#   echo "( $@ )"
   I=2
}

# display
function dsp {
    echo "$@"
}


if [ ${#WINDOWSIZE} -lt 3 ]; then
    dsp "usage: ${0} <window size> (window size can be 2 hours, 4 days, and so on)"
    exit
fi
TODAY=$(date  +"%Y-%m-%d")
sqlite3 ./disk.sqlite3 "select distinct mount_point from disk_info" | while read MP; do
    dbg " "
    dbg "### disk stats for ${MP} ####"
    dbg " "
    

    MINDT="select min(datetime(dt,'localtime')) from disk_info where mount_point like '${MP}'"
    MAXDT="select max(datetime(dt,'localtime')) from disk_info where mount_point like '${MP}'"
    
    MINDTRES=`sqlite3 ./disk.sqlite3 "${MINDT}"`
    MAXDTRES=`sqlite3 ./disk.sqlite3 "${MAXDT}"`
    JDIFFDAY=`sqlite3 ./disk.sqlite3 "select julianday(\"$MAXDTRES\") - julianday(\"$MINDTRES\")"`
    JDIFFHOUR=$(echo $JDIFFDAY*24 | bc)
    JDIFFMIN=$(echo $JDIFFHOUR*60 | bc)
    dbg "daydiff: ${JDIFFDAY}"
    dbg "hourdiff: ${JDIFFHOUR}"
    dbg "first data at: ${MINDTRES}"
    dbg "last data at: ${MAXDTRES}"

    DTWINDOWSQ="select strftime('%s','${MAXDTRES}') - strftime('%s','${MINDTRES}')" # unixepoch difference
    DTWINRES=`sqlite3 ./disk.sqlite3 "${DTWINDOWSQ}"`
    echo "windows size: ${DTWINRES}"
    # add projection to current date
    PROJQ="select datetime(strftime('%s','now') + ${DTWINRES},'unixepoch','localtime')"
    PROJRES=`sqlite3 ./disk.sqlite3 "${PROJQ}"`
    dbg "projecting to date: ${PROJRES}"

    QSAMPLES="select count(free) from disk_info where dt < datetime('now') and dt > datetime('now', '-${WINDOWSIZE}') and mount_point like '${MP}'"
    SAMPLES=`sqlite3 ./disk.sqlite3 "${QSAMPLES}"`

    if [ ${SAMPLES} -lt 2 ]; then
	dsp "samples: ${SAMPLES}"
	dsp "i need at least two sample for calculations"
	exit
    fi

    LASTFREE_Q="select free from disk_info where mount_point like '${MP}' order by dt desc limit 1"
    LASTFREE_RES=$(sqlite3 ./disk.sqlite3 "${LASTFREE_Q}")
    echo "last free: ${LASTFREE_RES}"

    ADDSUM_Q="select sum(diff) from disk_info where dt < datetime('now') and dt > datetime('now', '-${WINDOWSIZE}') and mount_point like '${MP}' and increased <> 2"
    dbg "$ADDSUM_Q"
    ADDSUM_RES=$(sqlite3 ./disk.sqlite3 "$ADDSUM_Q")
    dbg "change: ${ADDSUM_RES}"
    if [ ${#ADDSUM_RES} -lt 1 ]; then
	echo "no diff, cannot predict"
	continue
    fi
    FILLTIMEDIFF=$(($ADDSUM_RES*$DTWINRES))
    FILLTIME=`sqlite3 ./disk.sqlite3 "select datetime(strftime('%s','now') + ${FILLTIMEDIFF}, 'unixepoch', 'localtime')"`
    dsp "filltime: ${FILLTIME} (precision = windowsize = ${WINDOWSIZE} ) [ ${MP} ]"
    dsp " "
done
