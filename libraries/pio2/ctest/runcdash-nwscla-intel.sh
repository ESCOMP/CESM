#!/bin/sh

# Get/Generate the Dashboard Model
if [ $# -eq 0 ]; then
	model=Experimental
else
	model=$1
fi

source /etc/profile.d/modules.sh

module reset
module unload netcdf
module swap intel intel/19.1.1
module switch mpt mpt/2.22
module load cmake/3.18.2
module load netcdf-mpi/4.7.3
module load pnetcdf/1.12.1
echo "MODULE LIST..."
module list

export CC=mpicc
export FC=mpif90
export MPI_TYPE_DEPTH=24
export PIO_DASHBOARD_ROOT=/glade/scratch/jedwards/dashboard
export PIO_COMPILER_ID=Intel-`$CC --version | head -n 1 | cut -d' ' -f3`

if [ ! -d "$PIO_DASHBOARD_ROOT" ]; then
  mkdir "$PIO_DASHBOARD_ROOT"
fi
cd "$PIO_DASHBOARD_ROOT"

if [ ! -d src ]; then
  git clone https://github.com/PARALLELIO/ParallelIO src
fi
cd src
git checkout master
git pull origin master

ctest -S CTestScript.cmake,${model} -VV
