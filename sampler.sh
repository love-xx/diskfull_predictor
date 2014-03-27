#!/bin/bash

# walks trough each mount point, calculates the interval between the first and last check, and uses it as a step to calculate when it will get full
# support: gyula.weber.in@gmail.com
WINDOWSIZE="$@"
if [ ${#WINDOWSIZE} -lt 3 ]; then
    echo "usage: ${0} <window size> (window size can be 2 hours, 4 days, and so on)"
fi
TODAY=$(date  +"%Y-%m-%d")
sqlite3 ./disk.sqlite3 "select distinct mount_point from disk_info" | while read MP; do
    echo
    echo
    echo "### disk stats for ${MP} ####"
    echo
    

    MINDT="select min(datetime(dt,'localtime')) from disk_info where mount_point like '${MP}'"
    MAXDT="select max(datetime(dt,'localtime')) from disk_info where mount_point like '${MP}'"
    
    MINDTRES=`sqlite3 ./disk.sqlite3 "${MINDT}"`
    MAXDTRES=`sqlite3 ./disk.sqlite3 "${MAXDT}"`
    JDIFFDAY=`sqlite3 ./disk.sqlite3 "select julianday(\"$MAXDTRES\") - julianday(\"$MINDTRES\")"`
    JDIFFHOUR=$(echo $JDIFFDAY*24 | bc)
    JDIFFMIN=$(echo $JDIFFHOUR*60 | bc)
    echo "daydiff: ${JDIFFDAY}"
    echo "hourdiff: ${JDIFFHOUR}"
    echo "first data at: ${MINDTRES}"
    echo "last data at: ${MAXDTRES}"

    DTWINDOWSQ="select strftime('%s','${MAXDTRES}') - strftime('%s','${MINDTRES}')" # unixepoch difference
    DTWINRES=`sqlite3 ./disk.sqlite3 "${DTWINDOWSQ}"`

    # add projection to current date
    PROJQ="select datetime(strftime('%s','now') + ${DTWINRES},'unixepoch','localtime')"
    PROJRES=`sqlite3 ./disk.sqlite3 "${PROJQ}"`
    echo "projecting to date: ${PROJRES}"

    QSAMPLES="select count(free) from disk_info where dt < datetime('now') and dt > datetime('now', '-${WINDOWSIZE}') and mount_point like '${MP}'"
    SAMPLES=`sqlite3 ./disk.sqlite3 "${QSAMPLES}"`

    if [ ${SAMPLES} -lt 2 ]; then
	echo "samples: ${SAMPLES}"
	echo "i need at least two sample for calculations"
	exit
    fi

    QMIN="select min(free) from disk_info where dt < datetime('now') and dt > datetime('now', '-${WINDOWSIZE}') and mount_point like '${MP}'"
    QMAX="select max(free) from disk_info where dt < datetime('now') and dt > datetime('now', '-${WINDOWSIZE}') and mount_point like '${MP}'"

    RESMIN=`sqlite3 ./disk.sqlite3 "${QMIN}"`
    RESMAX=`sqlite3 ./disk.sqlite3 "${QMAX}"`

    echo "resmin: ${RESMIN}"
    echo "resmax: ${RESMAX}"

    RESMINMB=$(($RESMIN/1024))
    RESMINGB=$(($RESMIN/1024/1024))
    
    echo "min: ${RESMIN}"
    echo "max: ${RESMAX}"
    
    DIFF=$(($RESMAX-$RESMIN))
    echo "diff: ${DIFF}"
    echo "free: ${RESMIN}"

    PROJECTEDFREE=$(($RESMIN-$DIFF))
    PROJECTEDFREEMB=$(($PROJECTEDFREE/1024))
    PROJECTEDFREEGB=$(($PROJECTEDFREE/1024/1024))
    echo "last free: ${RESMIN} ( $RESMINMB MB / $RESMINGB GB)"
    echo "[samples: ${SAMPLES}] free space at ${PROJRES}: $PROJECTEDFREE ( $PROJECTEDFREEMB MB / $PROJECTEDFREEGB GB) ( diff: ${DIFF} )(${MP})"

    if [ ${DIFF} -lt 1 ]; then
	echo "free space difference in the database is zero, cannot predict yet."
	continue
    fi    
    FILLTIMEDIFF=$(($RESMIN/$DIFF*$DTWINRES))
    FILLTIME=`sqlite3 ./disk.sqlite3 "select datetime(strftime('%s','now') + ${FILLTIMEDIFF}, 'unixepoch', 'localtime')"`
    echo "filltime: ${FILLTIME} (precision = windowsize = ${WINDOWSIZE} )"
done
