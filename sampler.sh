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

    QMIN="select min(free) from disk_info where dt < datetime('now') and dt > datetime('now', '-${WINDOWSIZE}') and mount_point like '${MP}'"
    QMAX="select max(free) from disk_info where dt < datetime('now') and dt > datetime('now', '-${WINDOWSIZE}') and mount_point like '${MP}'"

    RESMIN=`sqlite3 ./disk.sqlite3 "${QMIN}"`
    RESMAX=`sqlite3 ./disk.sqlite3 "${QMAX}"`

    dbg "resmin: ${RESMIN}"
    dbg "resmax: ${RESMAX}"

    RESMINMB=$(($RESMIN/1024))
    RESMINGB=$(($RESMIN/1024/1024))
    
    dbg "min: ${RESMIN}"
    dbg "max: ${RESMAX}"
    
    DIFF=$(($RESMAX-$RESMIN))
    dbg "diff: ${DIFF}"
    dbg "free: ${RESMIN}"

    PROJECTEDFREE=$(($RESMIN-$DIFF))
    PROJECTEDFREEMB=$(($PROJECTEDFREE/1024))
    PROJECTEDFREEGB=$(($PROJECTEDFREE/1024/1024))
    dbg "last free: ${RESMIN} ( $RESMINMB MB / $RESMINGB GB)"
    dsp "[samples: ${SAMPLES}] free space at ${PROJRES}: $PROJECTEDFREE ( $PROJECTEDFREEMB MB / $PROJECTEDFREEGB GB) ( diff: ${DIFF} )(${MP})"

    if [ ${DIFF} -lt 1 ]; then
	dsp "free space difference in the database is zero, cannot predict yet."
	continue
    fi    
    FILLTIMEDIFF=$(($RESMIN/$DIFF*$DTWINRES))
    FILLTIME=`sqlite3 ./disk.sqlite3 "select datetime(strftime('%s','now') + ${FILLTIMEDIFF}, 'unixepoch', 'localtime')"`
    dsp "filltime: ${FILLTIME} (precision = windowsize = ${WINDOWSIZE} )"
    dsp " "
done
