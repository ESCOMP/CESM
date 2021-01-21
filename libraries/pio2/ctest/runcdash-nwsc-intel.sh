#!/bin/sh

# Get/Generate the Dashboard Model
if [ $# -eq 0 ]; then
	model=Experimental
else
	model=$1
fi

module reset
module unload netcdf
module swap intel intel/16.0.3
module load git/2.3.0
module load cmake/3.0.2
module load netcdf-mpi/4.4.1
module load pnetcdf/1.7.0

export CC=mpicc
export FC=mpif90

export PIO_DASHBOARD_ROOT=`pwd`/dashboard
export PIO_COMPILER_ID=Intel-`$CC --version | head -n 1 | cut -d' ' -f3`

if [ ! -d "$PIO_DASHBOARD_ROOT" ]; then
  mkdir "$PIO_DASHBOARD_ROOT"
fi
cd "$PIO_DASHBOARD_ROOT"

if [ ! -d src ]; then
  git clone --branch develop https://github.com/PARALLELIO/ParallelIO src
fi
cd src
git checkout develop
git pull origin develop

ctest -S CTestScript.cmake,${model} -VV
