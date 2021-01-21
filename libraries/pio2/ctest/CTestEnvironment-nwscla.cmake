#==============================================================================
#
#  This file sets the environment variables needed to configure and build
#  on the new NCAR Wyoming Supercomputing Center systems
#  (laramie/cheyenne).
#
#==============================================================================

# Assume all package locations (NetCDF, PnetCDF, HDF5, etc) are already
# set with existing environment variables: NETCDF, PNETCDF, HDF5, etc.

# Define the extra CMake configure options
set (CTEST_CONFIGURE_OPTIONS "-DCMAKE_VERBOSE_MAKEFILE=TRUE ")

# If MPISERIAL environment variable is set, then enable MPISERIAL
if (DEFINED ENV{MPISERIAL})
    set (CTEST_CONFIGURE_OPTIONS "${CTEST_CONFIGURE_OPTIONS} -DPIO_USE_MPISERIAL=ON")
endif ()
