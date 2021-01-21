#==============================================================================
#
#  This is the CTest script for PIO builds and submission to the CTest
#  Dashboard site: my.cdash.org.
#
#  Example originally stolen from:
#    http://www.vtk.org/Wiki/CTest:Using_CTEST_and_CDASH_without_CMAKE
#==============================================================================

#---------------------------------------
#-- User-defined setup from environment
#---------------------------------------

## -- CTest Dashboard Root Directory
if (DEFINED ENV{PIO_DASHBOARD_ROOT})
    set (CTEST_DASHBOARD_ROOT "$ENV{PIO_DASHBOARD_ROOT}")
else ()
    set (CTEST_DASHBOARD_ROOT "$ENV{HOME}/pio-dashboard")
endif ()

## -- Compiler ID
if (DEFINED ENV{PIO_COMPILER_ID})
    set (compid "$ENV{PIO_COMPILER_ID}")
else ()
    set (compid "?")
endif ()

## -- CTest Dashboard Build Group
set (CTEST_BUILD_GROUP "${CTEST_SCRIPT_ARG}")

#---------------------------------------
#-- Get the machine environment
#---------------------------------------

## -- Set hostname

find_program (HOSTNAME_CMD NAMES hostname)
execute_process (COMMAND ${HOSTNAME_CMD}
                 OUTPUT_VARIABLE HOSTNAME
                 OUTPUT_STRIP_TRAILING_WHITESPACE)

## -- Set hostname ID (e.g., alcf, nwsc, nersc, ...)
message ("hostname is ${HOSTNAME}")

# UCAR/NWSC Machines
if (HOSTNAME MATCHES "^yslogin" OR
    HOSTNAME MATCHES "^geyser" OR
    HOSTNAME MATCHES "^caldera" OR
    HOSTNAME MATCHES "^pronghorn")
    set (HOSTNAME_ID "nwsc")
# New UCAR/NWSC SGI Machines
elseif (HOSTNAME MATCHES "^laramie" OR
        HOSTNAME MATCHES "^chadmin" OR
	HOSTNAME MATCHES "^cheyenne")
   set (HOSTNAME_ID "nwscla")
# ALCF/Argonne Machines
elseif (HOSTNAME MATCHES "^mira" OR
        HOSTNAME MATCHES "^cetus" OR
        HOSTNAME MATCHES "^vesta" OR
        HOSTNAME MATCHES "^cooley")
    set (HOSTNAME_ID "alcf")
# NERSC Machines
elseif (HOSTNAME MATCHES "^edison" OR
        HOSTNAME MATCHES "^cori" OR
        HOSTNAME MATCHES "^nid")
    set (HOSTNAME_ID "nersc")
# Blue Waters at NCSA
elseif (HOSTNAME MATCHES "^h2ologin" )
    set (HOSTNAME_ID "ncsa")
# CGD local linux cluster
elseif (HOSTNAME MATCHES "^hobart")
    set (HOSTNAME_ID "cgd")
# Argonne Linux workstations
elseif (HOSTNAME MATCHES "^compute001" OR
        HOSTNAME MATCHES "^thwomp" OR
        HOSTNAME MATCHES "^stomp" OR
        HOSTNAME MATCHES "^crush" OR
        HOSTNAME MATCHES "^crank" OR
        HOSTNAME MATCHES "^steamroller" OR
        HOSTNAME MATCHES "^grind" OR
        HOSTNAME MATCHES "^churn" OR
        HOSTNAME MATCHES "^trounce" OR
        HOSTNAME MATCHES "^thrash" OR
        HOSTNAME MATCHES "^vanquish")
    set (HOSTNAME_ID "anlworkstation")
else ()
     if (CMAKE_SYSTEM_NAME MATCHES "Catamount")
        set (HOSTNAME_ID "ncsa")
     else ()
     	set (HOSTNAME_ID "unknown")
     endif ()
endif ()

## -- Get system info

find_program (UNAME NAMES uname)
function (getuname name flag)
    execute_process (COMMAND ${UNAME} ${flag}
                     OUTPUT_VARIABLE res
                     OUTPUT_STRIP_TRAILING_WHITESPACE)
    set (${name} ${res} PARENT_SCOPE)
endfunction ()

getuname (osname -s)
getuname (osrel -r)
getuname (cpu -m)

## -- Git command
find_program (CTEST_GIT_COMMAND NAMES git)

## -- make command
find_program (MAKE NAMES make)

#-----------------------------------------------------------
#-- Generate build-specific information
#-----------------------------------------------------------

## -- CTest Site Name

set (CTEST_SITE "${HOSTNAME_ID}-${HOSTNAME}")

## -- CTest Build Name

set (CTEST_BUILD_NAME "${osname}-${osrel}-${cpu}-${compid}")

## -- SRC Dir (where this script exists)
set (CTEST_SOURCE_DIRECTORY   "${CTEST_SCRIPT_DIRECTORY}")

## -- BIN Dir
set (CTEST_BINARY_DIRECTORY   "${CTEST_DASHBOARD_ROOT}/build-${CTEST_BUILD_NAME}-${CTEST_BUILD_GROUP}")

## -- Add the CTest script directory to the module path
set (CTEST_EXTRA_SCRIPT_PATH "${CTEST_SOURCE_DIRECTORY}/ctest")
list (APPEND CMAKE_MODULE_PATH ${CTEST_EXTRA_SCRIPT_PATH})

# -----------------------------------------------------------
# -- Store Build-Specific Info (environment variables)
# -----------------------------------------------------------

set (ENV{PIO_DASHBOARD_SITE}        ${CTEST_SITE})
set (ENV{PIO_DASHBOARD_BUILD_NAME}  ${CTEST_BUILD_NAME})
set (ENV{PIO_DASHBOARD_SOURCE_DIR}  ${CTEST_SOURCE_DIRECTORY})
set (ENV{PIO_DASHBOARD_BINARY_DIR}  ${CTEST_BINARY_DIRECTORY})

# -----------------------------------------------------------
# -- Run CTest
# -----------------------------------------------------------

## -- Empty the binary directory
ctest_empty_binary_directory(${CTEST_BINARY_DIRECTORY})

## -- Start
message (" -- Hostname_id = ${HOSTNAME_ID}")
message (" -- Start dashboard - ${CTEST_BUILD_NAME} --")
ctest_start("${CTEST_SCRIPT_ARG}")

## -- Update
message (" -- Update source - ${CTEST_BUILD_NAME} --")
set (CTEST_UPDATE_COMMAND "${CTEST_GIT_COMMAND}")
ctest_update ()

## -- Configure
message (" -- Configure build - ${CTEST_BUILD_NAME} -- with options ${CTEST_CONFIGURE_OPTIONS}")
include (CTestEnvironment-${HOSTNAME_ID})
set (CTEST_CONFIGURE_COMMAND "${CMAKE_COMMAND} ${CTEST_CONFIGURE_OPTIONS} ${CTEST_SOURCE_DIRECTORY}")
ctest_configure ()

## -- BUILD
message (" -- Build - ${CTEST_BUILD_NAME} --")
set (CTEST_BUILD_COMMAND "${MAKE} tests")
ctest_build ()

## -- TEST
message (" -- Test - ${CTEST_BUILD_NAME} --")
execute_process (COMMAND ${CTEST_EXTRA_SCRIPT_PATH}/runctest-${HOSTNAME_ID}.sh
                         ${CTEST_EXTRA_SCRIPT_PATH} ${CTEST_SCRIPT_ARG}
                 WORKING_DIRECTORY ${CTEST_BINARY_DIRECTORY})

## -- SUBMIT
message (" -- Submit to dashboard - ${CTEST_BUILD_NAME} --")
message ("** -- PIO_DASHBOARD_SITE=$ENV{PIO_DASHBOARD_SITE}")
ctest_submit ()

# -----------------------------------------------------------
# -- Clear environment
# -----------------------------------------------------------

unset (ENV{PIO_DASHBOARD_SITE})
unset (ENV{PIO_DASHBOARD_BUILD_NAME})
unset (ENV{PIO_DASHBOARD_SOURCE_DIR})
unset (ENV{PIO_DASHBOARD_BINARY_DIR})

message (" -- Finished - ${CTEST_BUILD_NAME} --")
