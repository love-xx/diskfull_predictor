diskfull_predictor
==================

A very simpe shell script that tries to determine when the disks will be full from the collected data

== requirements ==
- sqlite3
- bc
- bash

== usage ==
 
1. periodically store the current data: ./store_data.sh(cron entry provided)
2. get the prediction by: ./sampler.sh [-v] [time window] (for example: 15 minutes, or 1 hours, or 2 days)

== how it works ==

* It check the disk space change in a given time window and projects it to determine when the disk will be filled up.
* The cleanup script should run every 2 hours, and removes old (1+month) entries and meaningless updates. (crontab entry provided)
