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

BACKDT="select datetime('now','-${WINDOWSIZE}')"
BACKDTRES=$(sqlite3 ./disk.sqlite3 "${BACKDT}")

CDT="select datetime('now')"
CDTRES=$(sqlite3 ./disk.sqlite3 "${CDT}")

BACKDTWINQ="select strftime('%s','${CDTRES}') - strftime('%s','${BACKDTRES}')"
BACKDTWINRES=$(sqlite3 ./disk.sqlite3 "$BACKDTWINQ") 

echo "measuring from: 
${BACKDTRES} -
${CDTRES}
-------------------------
"


sqlite3 ./disk.sqlite3 "select distinct mount_point from disk_info" | while read MP; do
    dbg " "
    dbg "### disk stats for ${MP} ####"
    dbg " "
    

    # get maximum time window
    MAXWINQ="select strftime('%s','now') - strftime('%s',min(dt)) from disk_info where mount_point like '${MP}'"
    MAXWIN=$(sqlite3 ./disk.sqlite3 "${MAXWINQ}")
    echo "maximum window size for this mount point: ${MAXWIN}"
    echo "given time window: ${BACKDTWINRES}"
    
    
    if [ ${MAXWIN} -lt ${BACKDTWINRES} ]; then
	echo "maximum time window is smaller than the given. adjusting time window to the maximum"
	BACKDTWINRES=$MAXWIN
    fi
    
    DTWINRES=$BACKDTWINRES
    dbg "windows size: ${DTWINRES}"

    QSAMPLES="select count(free) from disk_info where dt < datetime('now') and dt > datetime('now', '-${WINDOWSIZE}') and mount_point like '${MP}'"
    SAMPLES=`sqlite3 ./disk.sqlite3 "${QSAMPLES}"`

    if [ ${SAMPLES} -lt 2 ]; then
	dsp "samples: ${SAMPLES}"
	dsp "i need at least two sample for calculations"
	exit
    fi

    LASTFREE_Q="select free from disk_info where mount_point like '${MP}' order by dt desc limit 1"
    LASTFREE_RES=$(sqlite3 ./disk.sqlite3 "${LASTFREE_Q}")
    dbg "last free: ${LASTFREE_RES}"

    ADDSUM_Q="select sum(diff) from disk_info where dt < datetime('now') and dt > datetime('now', '-${WINDOWSIZE}') and mount_point like '${MP}' and increased <> 2"
    ADDSUM_RES=$(sqlite3 ./disk.sqlite3 "$ADDSUM_Q")
    dbg "change: ${ADDSUM_RES}"
    if [ ${#ADDSUM_RES} -lt 1 ]; then
	echo "no diff, cannot predict"
	continue
    fi
    # 1. megnezzuk hanyszor van meg a jelenlegi szabad helyben a kulonbseg
    # 2. megszorozzuk a szamot az idoablakkal
    # 3. hozzaadjuk a jelenlegi datumhoz
    FILLTIMEDIFF=$(($LASTFREE_RES/$ADDSUM_RES*$DTWINRES))

    dbg "Fill time diff: ${FILLTIMEDIFF}"

    # calculate when it will fill up
    FILLTIME=`sqlite3 ./disk.sqlite3 "select datetime(strftime('%s','now') + ${FILLTIMEDIFF}, 'unixepoch', 'localtime')"`
    dsp "samples: $SAMPLES - filltime: ${FILLTIME} [ ${MP} ]"
    dsp " "
done
