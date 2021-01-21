# - Try to find LIBRT
#
# This can be controlled by setting the LIBRT_DIR (or, equivalently, the 
# LIBRT environment variable).
#
# Once done, this will define:
#
#   LIBRT_FOUND        (BOOL) - system has LIBRT
#   LIBRT_IS_SHARED    (BOOL) - whether library is shared/dynamic
#   LIBRT_INCLUDE_DIR  (PATH) - Location of the C header file
#   LIBRT_INCLUDE_DIRS (LIST) - the LIBRT include directories
#   LIBRT_LIBRARY      (FILE) - Path to the C library file
#   LIBRT_LIBRARIES    (LIST) - link these to use LIBRT
#
include (LibFind)

# Define LIBRT package
define_package_component (LIBRT
                          INCLUDE_NAMES time.h
                          LIBRARY_NAMES rt)

# SEARCH FOR PACKAGE
if (NOT LIBRT_FOUND)
    
    # Search for the package
    find_package_component(LIBRT)

endif ()
