#!/bin/sh
#==============================================================================
#
#  This script defines how to run CTest on the National Energy Research
#  Scientific Computing Center systems (edison/cori).
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
echo "#!/bin/sh" > runctest.slurm
echo "#SBATCH --partition debug" >> runctest.slurm
echo "#SBATCH --nodes=1" >> runctest.slurm
case "$NERSC_HOST" in
    edison)
	echo "#SBATCH --ntasks-per-node=32" >> runctest.slurm
	;;
    cori)
	echo "#SBATCH --ntasks-per-node=68" >> runctest.slurm
	echo "#SBATCH -C knl" >> runctest.slurm
	;;
esac

echo "#SBATCH --time=01:00:00" >> runctest.slurm

echo "#SBATCH --export PIO_DASHBOARD_SITE,PIO_DASHBOARD_BUILD_NAME,PIO_DASHBOARD_SOURCE_DIR,PIO_DASHBOARD_BINARY_DIR" >> runctest.slurm
#echo "cd \$PBS_O_WORKDIR" >> runctest.pbs
echo "CTEST_CMD=`which ctest`" >> runctest.slurm
echo "\$CTEST_CMD -S ${scrdir}/CTestScript-Test.cmake,${model} -V" >> runctest.slurm
chmod +x runctest.slurm
# Submit the job to the queue
#jobid=`sbatch runctest.slurm| egrep -o -e "\b[0-9]+$"`
case "$NERSC_HOST" in
    edison)
	salloc -N 1 ./runctest.slurm
	;;
    cori)
	salloc -N 1 -C knl ./runctest.slurm
	;;
esac 
# Wait for the job to complete before exiting
#while true; do
#	status=`squeue -j $jobid`
#	if [ "$status" == "" ]; then
#		break
#	else
#		sleep 10
#	fi
#done
