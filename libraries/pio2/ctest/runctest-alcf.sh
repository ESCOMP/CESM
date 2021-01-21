#!/bin/sh
#==============================================================================
#
#  This script defines how to run CTest on the Argonne Leadership Computing
#  Facility systems (mira/cetus/vesta/cooley).
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
echo "CTESTCMD=`which ctest`" >> runctest.sh
echo "\$CTESTCMD -S ${scrdir}/CTestScript-Test.cmake,${model} -V" >> runctest.sh

# Make the QSUB script executable
chmod +x runctest.sh

# Submit the job to the queue
jobid=`qsub -t 20 -n 4 --proccount 4 \
	--env PIO_DASHBOARD_SITE=$PIO_DASHBOARD_SITE \
	--env PIO_DASHBOARD_BUILD_NAME=$PIO_DASHBOARD_BUILD_NAME \
	--env PIO_DASHBOARD_SOURCE_DIR=$PIO_DASHBOARD_SOURCE_DIR \
	--env PIO_DASHBOARD_BINARY_DIR=$PIO_DASHBOARD_BINARY_DIR \
	--mode script runctest.sh`

# Wait for the job to complete before exiting
while true; do
	status=`qstat $jobid`
	if [ "$status" == "" ]; then
		break
	else
		sleep 10
	fi
done
