#!/bin/sh
#==============================================================================
#
#  This script defines how to run CTest on the National Center for 
#  Supercomputing Applications system (blue waters).
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
echo "#!/bin/sh" > runctest.pbs
echo "#PBS -q debug" >> runctest.pbs
echo "#PBS -l mppwidth=24" >> runctest.pbs
echo "#PBS -l walltime=00:20:00" >> runctest.pbs
echo "#PBS -v PIO_DASHBOARD_SITE,PIO_DASHBOARD_BUILD_NAME,PIO_DASHBOARD_SOURCE_DIR,PIO_DASHBOARD_BINARY_DIR" >> runctest.pbs
echo "cd \$PBS_O_WORKDIR" >> runctest.pbs
echo "CTEST_CMD=`which ctest`" >> runctest.pbs
echo "\$CTEST_CMD -S ${scrdir}/CTestScript-Test.cmake,${model} -V" >> runctest.pbs

# Submit the job to the queue
jobid=`qsub runctest.pbs`

# Wait for the job to complete before exiting
while true; do
	status=`qstat $jobid`
	if [ "$status" == "" ]; then
		break
	else
		sleep 10
	fi
done
