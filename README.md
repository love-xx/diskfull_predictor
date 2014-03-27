diskfull_predictor
==================

tries to determine when the disks will be full

1. periodically store the current data: ./store_data.sh
2. get the prediction by: ./sampler.sh <time window> (for example: 15 minutes, or 1 hours, or 2 days)

The calculation currently is very basic, it check the min/max difference in a given time window and projects it to determine when the disk will be filled up
