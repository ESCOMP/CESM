#!/bin/bash

#BSUB -XF               # enable X forwarding
#BSUB -Is               # interactive job
#BSUB -q caldera        # queue
#BSUB -W 00:30          # wall-clock time (hrs:mins)
#BSUB -n 1              # number of tasks in job
#BSUB -J myjob          # job name
#BSUB -o myjob.%J.out   # output file name in which %J is replaced by the job ID
#BSUB -e myjob.%J.err   # error file name in which %J is replaced by the job ID
#BSUB -P P93300606
#start the application
./testpio_run.pl --host=yellowstone --twopass
