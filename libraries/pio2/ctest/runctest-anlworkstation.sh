#!/bin/sh
#==============================================================================
#
#  This script defines how to run CTest on the Argonne Linux workstations.
#
#  This assumes the CTest model name (e.g., "Nightly") is passed to it when
#  run.
#
#==============================================================================

# Get the CTest script directory
scrdir=$1

# Get the CTest model name
model=$2

# Run the "ctest" command in another process
ctest -S ${scrdir}/CTestScript-Test.cmake,${model} -V
