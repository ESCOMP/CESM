#!/bin/sh

# Get/Generate the Dashboard Model
if [ $# -eq 0 ]; then
	model=Experimental
else
	model=$1
fi

module reset
module unload netcdf
module swap intel gnu/10.1.0
module swap mpt openmpi/4.0.3
module load git
module load cmake
module load netcdf-mpi/4.7.3
module load pnetcdf/1.12.1

export CC=mpicc
export FC=mpif90

export PIO_DASHBOARD_ROOT=/glade/u/home/jedwards/sandboxes/dashboard
export PIO_COMPILER_ID=GNU-`$CC --version | head -n 1 | tail -n 1 | cut -d' ' -f3`

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
