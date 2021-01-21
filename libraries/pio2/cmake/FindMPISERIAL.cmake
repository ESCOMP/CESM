# - Try to find MPISERIAL
#
# This can be controlled by setting the MPISERIAL_PATH (or, equivalently, the 
# MPISERIAL environment variable).
#
# Once done, this will define:
#
#   MPISERIAL_FOUND        (BOOL) - system has MPISERIAL
#   MPISERIAL_IS_SHARED    (BOOL) - whether library is shared/dynamic
#   MPISERIAL_INCLUDE_DIR  (PATH) - Location of the C header file
#   MPISERIAL_INCLUDE_DIRS (LIST) - the MPISERIAL include directories
#   MPISERIAL_LIBRARY      (FILE) - Path to the C library file
#   MPISERIAL_LIBRARIES    (LIST) - link these to use MPISERIAL
#
include (LibFind)

# Define MPISERIAL C component
define_package_component (MPISERIAL DEFAULT
                          COMPONENT C
                          INCLUDE_NAMES mpi.h
                          LIBRARY_NAMES mpi-serial)

# Define MPISERIAL Fortran component
define_package_component (MPISERIAL
                          COMPONENT Fortran
                          INCLUDE_NAMES mpi.mod mpif.h
                          LIBRARY_NAMES mpi-serial)

# Search for list of valid components requested
find_valid_components (MPISERIAL)

#==============================================================================
# SEARCH FOR VALIDATED COMPONENTS
foreach (MPISERIAL_comp IN LISTS MPISERIAL_FIND_VALID_COMPONENTS)

    # If not found already, search...
    if (NOT MPISERIAL_${MPISERIAL_comp}_FOUND)

        # Search for the package
        find_package_component(MPISERIAL COMPONENT ${MPISERIAL_comp})
        
    endif ()

endforeach ()
