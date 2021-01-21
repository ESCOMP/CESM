#!/bin/sh
#==============================================================================
#
#  This script defines how to run CTest on the NCAR Wyoming Supercomputing
#  Center systems (cheyenne/laramie).
#
#  This assumes the CTest model name (e.g., "Nightly") is passed to it when
#  run.
#
#==============================================================================

# Get the CTest script directory
scrdir=$1

# Get the CTest model name
model=$2

# Write QSUB submission script with the test execution command
echo "#!/bin/sh" > runctest.sh
echo "#PBS -l walltime=01:00:00" >> runctest.sh
echo "#PBS -l select=1:ncpus=8:mpiprocs=8" >> runctest.sh
echo "#PBS -A P93300606" >> runctest.sh
echo "#PBS -q regular" >> runctest.sh
echo "export PIO_DASHBOARD_SITE=nwscla-${HOSTNAME}" >> runctest.sh
echo "CTESTCMD=`which ctest`" >> runctest.sh
echo "\$CTESTCMD -S ${scrdir}/CTestScript-Test.cmake,${model} -V" >> runctest.sh

# Make the QSUB script executable
chmod +x runctest.sh

# Submit the job to the queue
jobid=`qsub -l walltime=01:00:00 runctest.sh`

# Wait for the job to complete before exiting
while true; do
	qstat $jobid
	if [ $? -eq 0 ]; then
		sleep 30
	else
		break;
	fi
done

exit 0
