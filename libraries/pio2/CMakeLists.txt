# This is part of the PIO library.

# This is the CMake build file for the main directory.

# Jim Edwards

cmake_minimum_required (VERSION 2.8.12)
project (PIO C Fortran)
#cmake_policy(VERSION 3.5.2)

# The project version number.
set(VERSION_MAJOR   2   CACHE STRING "Project major version number.")
set(VERSION_MINOR   5   CACHE STRING "Project minor version number.")
set(VERSION_PATCH   2   CACHE STRING "Project patch version number.")
mark_as_advanced(VERSION_MAJOR VERSION_MINOR VERSION_PATCH)

# Create version info in autotools parlance for pio_meta.h.
set(PIO_VERSION_MAJOR ${VERSION_MAJOR})
set(PIO_VERSION_MINOR ${VERSION_MINOR})
set(PIO_VERSION_PATCH ${VERSION_PATCH})

# This is needed for the libpio.settings file.
SET(PACKAGE_VERSION ${PIO_VERSION_MAJOR}.${PIO_VERSION_MINOR}.${PIO_VERSION_PATCH})

# This provides cmake_print_variables() function for debugging.
include(CMakePrintHelpers)

# Determine the configure date.
IF(DEFINED ENV{SOURCE_DATE_EPOCH})
        EXECUTE_PROCESS(
          COMMAND "date" "-u" "-d" "@$ENV{SOURCE_DATE_EPOCH}"
          OUTPUT_VARIABLE CONFIG_DATE
          )
ELSE()
        EXECUTE_PROCESS(
          COMMAND date
          OUTPUT_VARIABLE CONFIG_DATE
          )
ENDIF()
IF(CONFIG_DATE)
        string(STRIP ${CONFIG_DATE} CONFIG_DATE)
ENDIF()

# A function used to create autotools-style 'yes/no' definitions.
# If a variable is set, it 'yes' is returned. Otherwise, 'no' is
# returned.
#
# Also creates a version of the ret_val prepended with 'NC',
# when feature is true, which is used to generate netcdf_meta.h.
FUNCTION(is_enabled feature ret_val)
  IF(${feature})
    SET(${ret_val} "yes" PARENT_SCOPE)
    SET("PIO_${ret_val}" 1 PARENT_SCOPE)
  ELSE()
    SET(${ret_val} "no" PARENT_SCOPE)
    SET("PIO_${ret_val}" 0 PARENT_SCOPE)
  ENDIF(${feature})
ENDFUNCTION()

# A function used to create autotools-style 'yes/no' definitions.
# If a variable is set, it 'yes' is returned. Otherwise, 'no' is
# returned.
#
# Also creates a version of the ret_val prepended with 'NC',
# when feature is true, which is used to generate netcdf_meta.h.
FUNCTION(is_disabled feature ret_val)
  IF(${feature})
    SET(${ret_val} "no" PARENT_SCOPE)
  ELSE()
    SET(${ret_val} "yes" PARENT_SCOPE)
    SET("PIO_${ret_val}" 1 PARENT_SCOPE)
  ENDIF(${feature})
ENDFUNCTION()

# The size of the data buffer for write/read_darray().
set(PIO_BUFFER_SIZE 134217728)

#==============================================================================
#  USER-DEFINED OPTIONS (set with "-DOPT=VAL" from command line)
#==============================================================================

#===== Library Options =====
option (PIO_ENABLE_FORTRAN   "Enable the Fortran library builds"            ON)
option (PIO_ENABLE_TIMING    "Enable the use of the GPTL timing library"    ON)
option (PIO_ENABLE_LOGGING   "Enable debug logging (large output possible)" OFF)
option (PIO_ENABLE_DOC       "Enable building PIO documentation"            ON)
option (PIO_ENABLE_COVERAGE  "Enable code coverage"                         OFF)
option (PIO_ENABLE_EXAMPLES  "Enable PIO examples"                          ON)
option (PIO_ENABLE_NETCDF_INTEGRATION  "Enable netCDF integration"          OFF)
option (PIO_INTERNAL_DOC     "Enable PIO developer documentation"           OFF)
option (PIO_TEST_BIG_ENDIAN  "Enable test to see if machine is big endian"  ON)
option (PIO_USE_MPIIO        "Enable support for MPI-IO auto detect"        ON)
option (PIO_USE_MPISERIAL    "Enable mpi-serial support (instead of MPI)"   OFF)
option (PIO_USE_PNETCDF_VARD       "Use pnetcdf put_vard "  OFF)
option (WITH_PNETCDF         "Require the use of PnetCDF"                   ON)

# Set a variable that appears in the config.h.in file.
if(PIO_USE_PNETCDF_VARD)
  set(USE_VARD 1)
else()
  set(USE_VARD 0)
endif()

# Set a variable that appears in the config.h.in file.
set(USE_MALLOC 1)

# Set a variable that appears in the config.h.in file.
if(PIO_ENABLE_LOGGING)
  set(ENABLE_LOGGING 1)
  set(HAS_LOGGING "yes")
else()
  set(ENABLE_LOGGING 0)
  set(HAS_LOGGING "no")
endif()

# Set a variable that appears in the config.h.in file.
if(PIO_ENABLE_NETCDF_INTEGRATION)
  set(NETCDF_INTEGRATION 1)
else()
  set(NETCDF_INTEGRATION 0)
endif()

if(PIO_USE_MPISERIAL)
  set(USE_MPI_SERIAL 1)
else()
  set(USE_MPI_SERIAL 0)
endif()

#==============================================================================
#  PREPEND TO CMAKE MODULE PATH
#==============================================================================

#===== Local modules =====
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

#===== External modules =====
if (NOT DEFINED USER_CMAKE_MODULE_PATH)
  message (STATUS "Importing CMake_Fortran_utils")
  execute_process(
    COMMAND git clone https://github.com/CESM-Development/CMake_Fortran_utils
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    OUTPUT_QUIET
    ERROR_QUIET)
  find_path (USER_CMAKE_MODULE_PATH
    NAMES mpiexec.cmake
    HINTS ${CMAKE_BINARY_DIR}/CMake_Fortran_utils)
  if (USER_CMAKE_MODULE_PATH)
    message (STATUS "Importing CMake_Fortran_utils - success")
  else ()
    message (FATAL_ERROR "Failed to import CMake_Fortran_utils")
  endif ()
endif ()
set (USER_CMAKE_MODULE_PATH ${USER_CMAKE_MODULE_PATH}
  CACHE STRING "Location of the CMake_Fortran_utils")
list (APPEND CMAKE_MODULE_PATH ${USER_CMAKE_MODULE_PATH})

INCLUDE (CheckTypeSize)

#===== MPI =====
if (PIO_USE_MPISERIAL)
  find_package (MPISERIAL COMPONENTS C REQUIRED)
  if (MPISERIAL_C_FOUND)
    set (CMAKE_REQUIRED_INCLUDES ${MPISERIAL_C_INCLUDE_DIRS})
  endif ()
else ()
  find_package (MPI REQUIRED)
  set (CMAKE_REQUIRED_INCLUDES ${MPI_INCLUDE_PATH})
endif ()

SET(CMAKE_EXTRA_INCLUDE_FILES "mpi.h")
check_type_size("MPI_Offset" SIZEOF_MPI_OFFSET)
SET(CMAKE_EXTRA_INCLUDE_FILES)

#===== Library Variables =====
set (PIO_FILESYSTEM_HINTS IGNORE CACHE STRING "Filesystem hints (lustre or gpfs)")

#===== Testing Options =====
option (PIO_ENABLE_TESTS  "Enable the testing builds"                           ON)
option (PIO_VALGRIND_CHECK  "Enable memory leak check using valgrind"           OFF)

#==============================================================================
#  BACKWARDS COMPATIBILITY
#==============================================================================

# Old NETCDF_DIR variable --> NetCDF_PATH
if (DEFINED NETCDF_DIR)
  set (NetCDF_PATH ${NETCDF_DIR}
    CACHE STRING "Location of the NetCDF library installation")
endif ()

# Old PNETCDF_DIR variable --> PnetCDF_PATH
if (DEFINED PNETCDF_DIR)
  set (PnetCDF_PATH ${PNETCDF_DIR}
    CACHE STRING "Location of the PnetCDF library installation")
endif ()

#==============================================================================
#  HELPFUL GLOBAL VARIABLES
#==============================================================================

# System Name
string (TOUPPER "${CMAKE_SYSTEM_NAME}" CMAKE_SYSTEM_NAME_CAPS)
set (CMAKE_SYSTEM_DIRECTIVE "${CMAKE_SYSTEM_NAME_CAPS}"
  CACHE STRING "System name preprocessor directive")

# C Compiler Name
string (TOUPPER "${CMAKE_C_COMPILER_ID}" CMAKE_C_COMPILER_NAME)
if (CMAKE_C_COMPILER_NAME STREQUAL "XL")
  set (CMAKE_C_COMPILER_NAME "IBM")
endif ()
set (CMAKE_C_COMPILER_DIRECTIVE "CPR${CMAKE_C_COMPILER_NAME}"
  CACHE STRING "C compiler name preprocessor directive")

# Fortran Compiler Name
string (TOUPPER "${CMAKE_Fortran_COMPILER_ID}" CMAKE_Fortran_COMPILER_NAME)
if (CMAKE_Fortran_COMPILER_NAME STREQUAL "XL")
  set (CMAKE_Fortran_COMPILER_NAME "IBM")
endif ()
set (CMAKE_Fortran_COMPILER_DIRECTIVE "CPR${CMAKE_Fortran_COMPILER_NAME}"
  CACHE STRING "Fortran compiler name preprocessor directive")

#==============================================================================
#  SET CODE COVERAGE COMPILER FLAGS
#==============================================================================

# Only support GNU compilers at this time
if (PIO_ENABLE_COVERAGE)
  if (CMAKE_C_COMPILER_NAME STREQUAL "GNU")
    set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fprofile-arcs -ftest-coverage")
  else ()
    message (WARNING "The C compiler is non-GNU: coverage of C code could NOT be enabled")
  endif ()
  if (CMAKE_Fortran_COMPILER_NAME STREQUAL "GNU")
    set (CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -fprofile-arcs -ftest-coverage")
  else ()
    message (WARNING "The Fortran compiler is non-GNU: coverage of Fortran code could NOT be enabled")
  endif ()
endif ()

# Include this so we can check values in netcdf_meta.h.
INCLUDE(CheckCSourceCompiles)
INCLUDE(FindNetCDF)
message("Fortran Library build is ${PIO_ENABLE_FORTRAN}")
if (PIO_ENABLE_FORTRAN)
  find_package (NetCDF REQUIRED COMPONENTS C Fortran)
  find_package (PnetCDF COMPONENTS C Fortran)
else()
  find_package (NetCDF REQUIRED COMPONENTS C)
  find_package (PnetCDF COMPONENTS C)
endif()

# Did we find pnetCDF? If so, set _PNETCDF in config.h.
if (PnetCDF_C_FOUND)
  set(_PNETCDF 1)
endif ()

#==============================================================================
#  INCLUDE SOURCE DIRECTORIES
#==============================================================================

# Libraries
add_subdirectory (src)

#==============================================================================
#  TESTING TARGET
#==============================================================================

# Custom "piotests" target (builds the test executables)
add_custom_target (tests)
add_dependencies (tests pioc piof)

# Custom "check" target that depends upon "tests"
add_custom_target (check COMMAND ${CMAKE_CTEST_COMMAND})
add_dependencies (check tests)

# Tests
if (PIO_ENABLE_TESTS)
  enable_testing()
  include (CTest)
  add_subdirectory (tests)
  if (PIO_ENABLE_EXAMPLES)
    add_subdirectory (examples)
  endif ()
endif ()

# Documentation
if (PIO_ENABLE_DOC)
  add_subdirectory (doc)
endif ()



SET(STATUS_PNETCDF PnetCDF_C_FOUND)

###
# Check to see if netcdf-4 capability is present in netcdf-c.
###
CHECK_C_SOURCE_COMPILES("
#include <netcdf_meta.h>
#if !NC_HAS_NC4
      choke me
#endif
int main() {return 0;}" HAVE_NETCDF4)

###
# Check to see if netcdf-4 parallel I/O capability is present in
# netcdf-c. (Really we should be checking NC_HAS_PARALLEL4, but that
# was only recently introduced, so we will go with NC_HAS_PARALLEL.)
###
CHECK_C_SOURCE_COMPILES("
#include <netcdf_meta.h>
#if !NC_HAS_PARALLEL
      choke me
#endif
int main() {return 0;}" HAVE_NETCDF_PAR)

# Set this synonym for HAVE_NETCDF_PAR. It is defined in config.h.
if (HAVE_NETCDF_PAR)
  set(_NETCDF4 1)
endif ()

###
# Check to see if szip write capability is present in netcdf-c.
###
SET(CMAKE_REQUIRED_INCLUDES ${NetCDF_C_INCLUDE_DIR})
CHECK_C_SOURCE_COMPILES("
#include <netcdf_meta.h>
#if !NC_HAS_SZIP_WRITE
      choke me
#endif
int main() {return 0;}" HAVE_SZIP_WRITE)

###
# Check to see if parallel filters are supported by HDF5/netcdf-c.
###
CHECK_C_SOURCE_COMPILES("
#include <netcdf_meta.h>
#if !NC_HAS_PAR_FILTERS
      choke me
#endif
int main() {return 0;}" HDF5_HAS_PAR_FILTERS)
if(HDF5_HAS_PAR_FILTERS)
  set(HAVE_PAR_FILTERS 1)
else()
  set(HAVE_PAR_FILTERS 0)
endif()

###
# Check to see if this is netcdf-c-4.7.2, which won't work.
###
CHECK_C_SOURCE_COMPILES("
#include <netcdf_meta.h>
#if NC_VERSION_MAJOR == 4 && NC_VERSION_MINOR == 7 && NC_VERSION_PATCH == 2
#else
      choke me
#endif
int main() {return 0;}" HAVE_472)
if (HAVE_472)
  message (FATAL_ERROR "PIO cannot build with netcdf-c-4.7.2, please upgrade your netCDF library")
endif ()

###
# Check to see if dispatch table version 2 is supported for netcdf integration.
###
CHECK_C_SOURCE_COMPILES("
#include <netcdf_meta.h>
#if NC_DISPATCH_VERSION != 2
      choke me
#endif
int main() {return 0;}" HAVE_DISPATCH2)

if (NETCDF_INTEGRATION)
  if (NOT HAVE_DISPATCH2)
    message (FATAL_ERROR "Need newer version of netcdf-c for netcdf integration feature, please upgrade your netCDF library")
  endif ()
  set(HAVE_NETCDF_INTEGRATION 1)
else ()
  set(HAVE_NETCDF_INTEGRATION 0)
endif ()

# Configure testing with MPIEXEC.
if (NOT WITH_MPIEXEC)
  set(WITH_MPIEXEC mpiexec)
endif()
#set(MPIEXEC "${WITH_MPIEXEC}" CACHE INTERNAL "")
set(MPIEXEC "${WITH_MPIEXEC}")
set_property(GLOBAL PROPERTY WITH_MPIEXEC "${WITH_MPIEXEC}")

#####
# Configure and print the libpio.settings file.
#####

# Get system configuration, Use it to determine osname, os release, cpu. These
# will be used when committing to CDash.
find_program(UNAME NAMES uname)
IF(UNAME)
  macro(getuname name flag)
    exec_program("${UNAME}" ARGS "${flag}" OUTPUT_VARIABLE "${name}")
  endmacro(getuname)
  getuname(osname -s)
  getuname(osrel  -r)
  getuname(cpu    -m)
  set(TMP_BUILDNAME "${osname}-${osrel}-${cpu}")
ENDIF()

# Set
SET(prefix ${CMAKE_INSTALL_PREFIX})
SET(exec_prefix ${CMAKE_INSTALL_PREFIX})
SET(libdir ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR})
SET(includedir ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_INCLUDEDIR})
SET(CC ${CMAKE_C_COMPILER})

# Set variables to mirror those used by autoconf.
# This way we don't need to maintain two separate template
# files.
SET(host_cpu "${cpu}")
SET(host_vendor "${osname}")
SET(host_os "${osrel}")
SET(abs_top_builddir "${CMAKE_CURRENT_BINARY_DIR}")
SET(abs_top_srcdir "${CMAKE_CURRENT_SOURCE_DIR}")

SET(CC_VERSION "${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}")
SET(FC_VERSION "${CMAKE_Fortran_COMPILER_ID} ${CMAKE_Fortran_COMPILER_VERSION}")
# Build *FLAGS for libpio.settings.  (CFLAGS, CPPFLAGS, FFLAGS promoted from src)
SET(LDFLAGS "${CMAKE_EXE_LINKER_FLAGS} ${CMAKE_EXE_LINKER_FLAGS_${CMAKE_BUILD_TYPE}}")

is_disabled(BUILD_SHARED_LIBS enable_static)
is_enabled(BUILD_SHARED_LIBS enable_shared)

is_enabled(USE_SZIP HAS_SZIP_WRITE)
is_enabled(STATUS_PNETCDF HAS_PNETCDF)
is_enabled(HAVE_H5Z_SZIP HAS_SZLIB)
is_enabled(HDF5_HAS_PAR_FILTERS HAS_PAR_FILTERS)
is_enabled(HAVE_NETCDF4 HAS_NETCDF4)
is_enabled(HAVE_NETCDF_PAR HAS_NETCDF4_PAR)
is_enabled(HAVE_NETCDF_INTEGRATION HAS_NETCDF_INTEGRATION)
is_enabled(PIO_ENABLE_FORTRAN HAS_PIO_FORTRAN)

# Generate file from template.
CONFIGURE_FILE("${CMAKE_CURRENT_SOURCE_DIR}/libpio.settings.in"
  "${CMAKE_CURRENT_BINARY_DIR}/libpio.settings"
  @ONLY)

# Read in settings file, print out.
# Avoid using system-specific calls so that this
# might also work on Windows.
FILE(READ "${CMAKE_CURRENT_BINARY_DIR}/libpio.settings"
  LIBPIO_SETTINGS)
MESSAGE(STATUS ${LIBPIO_SETTINGS})

# Install libpio.settings file into same location
# as the libraries.
INSTALL(FILES "${PIO_BINARY_DIR}/libpio.settings"
  DESTINATION lib
  COMPONENT libraries)

#####
# Create pio_meta.h include file.
#####
configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/src/clib/pio_meta.h.in
  ${CMAKE_CURRENT_BINARY_DIR}/src/clib/pio_meta.h @ONLY)

# configure a header file to pass some of the CMake settings
# to the source code
configure_file (
  "${PROJECT_SOURCE_DIR}/cmake_config.h.in"
  "${PROJECT_BINARY_DIR}/config.h"
  )
