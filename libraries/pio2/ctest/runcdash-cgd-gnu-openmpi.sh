#!/bin/sh

# Get/Generate the Dashboard Model
if [ $# -eq 0 ]; then
	model=Experimental
else
	model=$1
fi

module purge
module load compiler/gnu/5.4.0
module load tool/parallel-netcdf/1.8.1/gnu-5.4.0/openmpi

export CC=mpicc
export FC=mpif90
export PIO_DASHBOARD_SITE="cgd"
export PIO_DASHBOARD_ROOT=/scratch/cluster/jedwards/dashboard
export CTEST_SCRIPT_DIRECTORY=${PIO_DASHBOARD_ROOT}/src
export PIO_DASHBOARD_SOURCE_DIR=${CTEST_SCRIPT_DIRECTORY}
export PIO_COMPILER_ID=gcc-`gcc --version | head -n 1 | cut -d' ' -f3`

if [ ! -d "$PIO_DASHBOARD_ROOT" ]; then
  mkdir "$PIO_DASHBOARD_ROOT"
fi
cd "$PIO_DASHBOARD_ROOT"

echo "CTEST_SCRIPT_DIRECTORY="${CTEST_SCRIPT_DIRECTORY}
echo "PIO_DASHBOARD_SOURCE_DIR="${PIO_DASHBOARD_SOURCE_DIR}

if [ ! -d src ]; then
  git clone --branch develop https://github.com/PARALLELIO/ParallelIO src
fi
cd src
git checkout develop
git pull origin develop


ctest -S CTestScript.cmake,${model} -VV -DCTEST_CONFIGURE_OPTIONS="-DCMAKE_EXE_LINKER_FLAGS=-ldl"
