# - Try to find GPTL
#
# This can be controlled by setting the GPTL_DIR (or, equivalently, the 
# GPTL environment variable), or GPTL_<lang>_DIR CMake variables, where
# <lang> is the COMPONENT language one needs.
#
# Once done, this will define:
#
#   GPTL_<lang>_FOUND        (BOOL) - system has GPTL
#   GPTL_<lang>_IS_SHARED    (BOOL) - whether library is shared/dynamic
#   GPTL_<lang>_INCLUDE_DIR  (PATH) - Location of the C header file
#   GPTL_<lang>_INCLUDE_DIRS (LIST) - the GPTL include directories
#   GPTL_<lang>_LIBRARY      (FILE) - Path to the C library file
#   GPTL_<lang>_LIBRARIES    (LIST) - link these to use GPTL
#
# The available COMPONENTS are: C Fortran Perfmod
# If no components are specified, it assumes only C
include (LibFind)

# Define GPTL C Component
define_package_component (GPTL DEFAULT
                          COMPONENT C
                          INCLUDE_NAMES gptl.h
                          LIBRARY_NAMES gptl)

# Define GPTL Fortran Component
define_package_component (GPTL
                          COMPONENT Fortran
                          INCLUDE_NAMES gptl.mod
                          LIBRARY_NAMES gptl)

# Define GPTL Fortran_Perf Component
define_package_component (GPTL
                          COMPONENT Fortran_Perf
                          INCLUDE_NAMES perf_mod.mod
                          LIBRARY_NAMES gptl)

# Search for list of valid components requested
find_valid_components (GPTL)

#==============================================================================
# SEARCH FOR VALIDATED COMPONENTS
foreach (GPTL_comp IN LISTS GPTL_FIND_VALID_COMPONENTS)

    # If not found already, search...
    if (NOT GPTL_${GPTL_comp}_FOUND)

        # Manually add the MPI include and library dirs to search paths
        if (GPTL_comp STREQUAL C AND MPI_C_FOUND)
            set (mpiincs ${MPI_C_INCLUDE_PATH})
            set (mpilibs ${MPI_C_LIBRARIES})
            set (mpifound ${MPI_C_FOUND})
        elseif (MPI_Fortran_FOUND)
            set (mpiincs ${MPI_Fortran_INCLUDE_PATH})
            set (mpilibs ${MPI_Fortran_LIBRARIES})
            set (mpifound ${MPI_Fortran_FOUND})
        endif ()
        
        # Search for the package component
        if (mpifound)
            initialize_paths (GPTL_${GPTL_comp}_PATHS
                              INCLUDE_DIRECTORIES ${mpiincs}
                              LIBRARIES ${mpilibs})
            find_package_component(GPTL COMPONENT ${GPTL_comp}
                                   PATHS ${GPTL_${GPTL_comp}_PATHS})
        else ()
            find_package_component(GPTL COMPONENT ${GPTL_comp})
        endif ()

    endif ()
    
endforeach ()
