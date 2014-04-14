#!/bin/bash

PTH=`pwd`
PTH_ESCAPED=$(echo ${PTH} | sed 's/\//\\\//g')
echo ${PTH_ESCAPED}
echo "installing cron entry to /etc/cron.d/diskfull_predctor"
cat cron_line | sed "s/__PATH__/${PTH_ESCAPED}/g" >/etc/cron.d/diskfull_predictor
echo "setting up permissions"
chown root.root /etc/cron.d/diskfull_predictor
echo "restarting cron"
/etc/init.d/cron restart
echo "done"
