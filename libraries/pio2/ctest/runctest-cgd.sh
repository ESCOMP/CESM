#!/bin/sh
#==============================================================================
#
#  This script defines how to run CTest on the NCAR CGD local cluster
#  Hobart.
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
echo "export PIO_DASHBOARD_BUILD_NAME=${PIO_DASHBOARD_BUILD_NAME}" >> runctest.sh
echo "export PIO_DASHBOARD_SOURCE_DIR=${PIO_DASHBOARD_BINARY_DIR}/../src/" >> runctest.sh
echo "export PIO_DASHBOARD_BINARY_DIR=${PIO_DASHBOARD_BINARY_DIR}" >> runctest.sh
echo "export PIO_DASHBOARD_SITE=cgd-${HOSTNAME}" >> runctest.sh

echo "CTESTCMD=`which ctest`" >> runctest.sh
echo "\$CTESTCMD -S ${scrdir}/CTestScript-Test.cmake,${model} -V" >> runctest.sh

# Make the QSUB script executable
chmod +x runctest.sh

# Submit the job to the queue
jobid=`/usr/local/bin/qsub -l nodes=1:ppn=8 runctest.sh -q short`

# Wait for the job to complete before exiting
while true; do
	status=`/usr/local/bin/qstat $jobid`
	echo $status
	if [ "$status" == "" ]; then
		break
	else
		sleep 10
	fi
done

exit 0
