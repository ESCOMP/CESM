#!/bin/sh

# Get/Generate the Dashboard Model
if [ $# -eq 0 ]; then
	model=Experimental
else
	model=$1
fi

module reset
module unload netcdf
module swap intel intel/15.0.3
module load git/2.3.0
module load cmake/3.0.2
module load netcdf/4.3.3.1

export MPISERIAL=/glade/u/home/jedwards/mpi-serial/intel15.0.3/

export CC=icc
export FC=ifort

export PIO_DASHBOARD_ROOT=`pwd`/dashboard
export PIO_COMPILER_ID=Serial-Intel-`$CC --version | head -n 1 | cut -d' ' -f3`

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
