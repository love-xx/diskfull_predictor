#!/bin/bash

# stores disk stats (gyula.weber.in@gmail.com)

if [ ! -f ./disk.sqlite3 ]; then
    echo " -> disk.sqlite3 does not exists. creating and inserting schema"
    sqlite3 ./disk.sqlite3 <./schema.sql
fi

df| grep -vE '^Filesystem' | awk '{print $1 ";" $4}' | grep -v 'tmpfs' | grep -v 'udev'| grep -v 'none' | sort | uniq | while read ENTRY; do
    #    echo "entry: ${ENTRY}"
    MP=$(echo ${ENTRY} | awk -F';' '{print $1}')
    AVAIL=$(echo ${ENTRY} | awk -F';' '{print $2}')
    #    echo "mp: ${MP}, avail ${AVAIL}"

    echo "getting last entry"
    LASTQ="select free from disk_info where mount_point like '${MP}' order by dt desc limit 1"
    LASTRES=`sqlite3 ./disk.sqlite3 "${LASTQ}"`
    if [ ${#LASTRES} -lt 1 ]; then
	LASTRES=0
    fi
    INCREASED=0

    echo "lastres: ${LASTRES}"
    
    if [ ${LASTRES} -lt ${AVAIL} ]; then
	INCREASED=1
    elif [ ${LASTRES} -eq ${AVAIL} ]; then
	INCREASED=2
    else
	INCREASED=0
    fi

    Q="insert into disk_info(mount_point,dt,free,increased)  values('${MP}',datetime('now'),${AVAIL},${INCREASED})"
    echo "$Q"
    echo "running:     sqlite3 ./disk.sqlite3 ${Q}" 
    sqlite3 ./disk.sqlite3 "${Q}"
done

echo "OK"
