# - Try to find MPE
#
# This can be controlled by setting the MPE_PATH (or, equivalently,
# the MPE environment variable), or MPE_<lang>_PATH CMake variables,
# where <lang> is the COMPONENT language one needs.
#
# Once done, this will define:
#
#   MPE_<lang>_FOUND        (BOOL) - system has MPE
#   MPE_<lang>_IS_SHARED    (BOOL) - whether library is shared/dynamic
#   MPE_<lang>_INCLUDE_DIR  (PATH) - Location of the C header file
#   MPE_<lang>_INCLUDE_DIRS (LIST) - the MPE include directories
#   MPE_<lang>_LIBRARY      (FILE) - Path to the C library file
#   MPE_<lang>_LIBRARIES    (LIST) - link these to use MPE
#
# The available COMPONENTS are: C 
include (LibFind)
include (LibCheck)

# Define MPE C Component
define_package_component (MPE DEFAULT
  COMPONENT C
  INCLUDE_NAMES mpe.h
  LIBRARY_NAMES mpe)

# Search for list of valid components requested
find_valid_components (MPE)

#==============================================================================
# SEARCH FOR VALIDATED COMPONENTS
foreach (NCDFcomp IN LISTS MPE_FIND_VALID_COMPONENTS)

  # If not found already, search...
  if (NOT MPE_${NCDFcomp}_FOUND)

    # Manually add the MPI include and library dirs to search paths
    # and search for the package component
    if (MPI_${NCDFcomp}_FOUND)
      initialize_paths (MPE_${NCDFcomp}_PATHS
        INCLUDE_DIRECTORIES ${MPI_${NCDFcomp}_INCLUDE_PATH}
        LIBRARIES ${MPI_${NCDFcomp}_LIBRARIES})
      find_package_component(MPE COMPONENT ${NCDFcomp}
        PATHS ${MPE_${NCDFcomp}_PATHS})
    else ()
      find_package_component(MPE COMPONENT ${NCDFcomp})
    endif ()

  endif ()
  
endforeach ()
