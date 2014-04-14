#!/bin/bash

# cleanup old entries and 24h+ older not-changed records
# support: gyula.weber.in@gmail.com
DEBUG=0

if [ "$1" = "-v" ]; then
	DEBUG=1
	shift
fi

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

dsp 'Cleaning up logs older than 30 days'
sqlite3 ./disk.sqlite3 "delete from disk_info where dt < date('now','-30 days')"
dsp 'Deleting 24h+ older zero-diff logs'
sqlite3 ./disk.sqlite3 "delete from disk_info where dt > date('now','-24 hours') and diff = 0"
dsp "done"