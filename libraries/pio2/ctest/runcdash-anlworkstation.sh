#!/bin/sh

# Get/Generate the Dashboard Model
if [ $# -eq 0 ]; then
	model=Experimental
else
	model=$1
fi

source /software/common/adm/packages/softenv-1.6.2/etc/softenv-load.sh
source /software/common/adm/packages/softenv-1.6.2/etc/softenv-aliases.sh

soft add +gcc-6.2.0
soft add +mpich-3.2-gcc-6.2.0
soft add +cmake-3.5.1

export NETCDFROOT=/soft/apps/packages/climate/netcdf/4.4.1c-4.2cxx-4.4.4f-parallel/gcc-6.2.0
export PNETCDFROOT=/soft/apps/packages/climate/pnetcdf/1.7.0/gcc-6.2.0
export HDF5ROOT=/soft/apps/packages/climate/hdf5/1.8.16-parallel/gcc-6.2.0

export CC=mpicc
export FC=mpifort

export PIO_DASHBOARD_SITE=anlworkstation-`hostname`
export PIO_DASHBOARD_ROOT=/sandbox/dashboard
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

ctest -S CTestScript.cmake,${model} -VV
