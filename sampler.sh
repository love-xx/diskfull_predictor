#!/bin/bash

# walks trough each mount point, calculates the interval between the first and last check, and uses it as a step to calculate when it will get full
# support: gyula.weber.in@gmail.com

TODAY=$(date  +"%Y-%m-%d")
sqlite3 ./disk.sqlite3 "select distinct mount_point from disk_info" | while read MP; do
    echo
    echo
    echo "### disk stats for ${MP} ####"
    echo
    

    MINDT="select min(dt) from disk_info where mount_point like '${MP}'"
    MAXDT="select max(dt) from disk_info where mount_point like '${MP}'"
    
    MINDTRES=`sqlite3 ./disk.sqlite3 "${MINDT}"`
    MAXDTRES=`sqlite3 ./disk.sqlite3 "${MAXDT}"`
    JDIFFDAY=`sqlite3 ./disk.sqlite3 "select julianday(\"$MAXDTRES\") - julianday(\"$MINDTRES\")"`
    JDIFFHOUR=$(echo $JDIFFDAY*24 | bc |  awk '{printf("%d\n",$1 + 0.5)}')
    echo "daydiff: ${JDIFFDAY}"
    echo "hourdiff: ${JDIFFHOUR}"
    echo "first data at: ${MINDTRES}"
    echo "last data at: ${MAXDTRES}"

    DTWINDOWSQ="select strftime('%s','${MAXDTRES}') - strftime('%s','${MINDTRES}')" # unixepoch difference
    DTWINRES=`sqlite3 ./disk.sqlite3 "${DTWINDOWSQ}"`

    # add projection to current date
    PROJQ="select datetime(strftime('%s','now') + ${DTWINRES},'unixepoch')"
    PROJRES=`sqlite3 ./disk.sqlite3 "${PROJQ}"`
#    echo "projecting to date: ${PROJRES}"

    QSAMPLES="select count(free) from disk_info where dt < datetime('now') and dt > datetime('now', '-72 hours') and mount_point like '${MP}'"
    SAMPLES=`sqlite3 ./disk.sqlite3 "${QSAMPLES}"`

    QMIN="select min(free) from disk_info where dt < datetime('now') and dt > datetime('now', '-72 hours') and mount_point like '${MP}'"
    QMAX="select max(free) from disk_info where dt < datetime('now') and dt > datetime('now', '-72 hours') and mount_point like '${MP}'"

    RESMIN=`sqlite3 ./disk.sqlite3 "${QMIN}"`
    RESMAX=`sqlite3 ./disk.sqlite3 "${QMAX}"`

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
    
    SFREE=${RESMIN}
    FOUND=0
    for i in {1..1000}
    do
	if [ ${DIFF} -eq 0 ]; then
	    FOUND=1
	    break
	fi
	SFREE=$(($SFREE-$DIFF))
#	echo "checking ${i} ( ${SFREE} )"
	if [ ${SFREE} -lt 0 ]; then
	    FOUND=1
	    echo "the disk will full in loop ${i}"
	    DTDIFF=$((${i}*${DTWINRES}))
	    UTIME=`sqlite3 ./disk.sqlite3 "select strftime('%s','now') + ${DTDIFF}"`
#	    echo "utime: ${UTIME}"
	    CTIME=`sqlite3 ./disk.sqlite3 "select datetime(${UTIME},'unixepoch')"`
	    echo
	    echo " ====> predicted full time: ${CTIME} (precision: ${JDIFFHOUR} hours )<===="
	    echo
	    break
	fi
    done
    if [ ${FOUND} -eq 0 ]; then
	echo "i don't know when it will full"
    fi
    
done
