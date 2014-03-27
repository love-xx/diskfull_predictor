#!/bin/bash

# stores disk stats (gyula.weber.in@gmail.com)

dt=$(date  +"%Y-%m-%d %H:%M:%S")

if [ ! -f ./disk.sqlite3 ]; then
    sqlite3 ./disk.sqlite3 <./schema.sql
fi

df| grep -vE '^Filesystem' | awk '{print $1 ";" $4}' | grep -v 'tmpfs' | grep -v 'udev'| grep -v 'none' | sort | uniq | while read ENTRY; do
#    echo "entry: ${ENTRY}"
    MP=$(echo ${ENTRY} | awk -F';' '{print $1}')
    AVAIL=$(echo ${ENTRY} | awk -F';' '{print $2}')
#    echo "mp: ${MP}, avail ${AVAIL}"
    Q="insert into disk_info(mount_point,dt,free)  values('${MP}',datetime('now'),${AVAIL})"
#    echo "$Q"
    sqlite3 ./disk.sqlite3 "${Q}"
done
echo "OK"