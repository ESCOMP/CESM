# - Try to find SZIP
#
# This can be controlled by setting the SZIP_DIR (or, equivalently, the 
# SZIP environment variable).
#
# Once done, this will define:
#
#   SZIP_FOUND        (BOOL) - system has SZIP
#   SZIP_IS_SHARED    (BOOL) - whether library is shared/dynamic
#   SZIP_INCLUDE_DIR  (PATH) - Location of the C header file
#   SZIP_INCLUDE_DIRS (LIST) - the SZIP include directories
#   SZIP_LIBRARY      (FILE) - Path to the C library file
#   SZIP_LIBRARIES    (LIST) - link these to use SZIP
#
include (LibFind)

# Define SZIP package
define_package_component (SZIP
                          INCLUDE_NAMES szlib.h
                          LIBRARY_NAMES sz)

# SEARCH FOR PACKAGE
if (NOT SZIP_FOUND)

    # Manually add the MPI include and library dirs to search paths 
    # and search for the package component
    if (MPI_C_FOUND)
        initialize_paths (SZIP_PATHS
                          INCLUDE_DIRECTORIES ${MPI_C_INCLUDE_PATH}
                          LIBRARIES ${MPI_C_LIBRARIES})
        find_package_component(SZIP
                               PATHS ${SZIP_PATHS})
    else ()
        find_package_component(SZIP)
    endif ()

endif ()
