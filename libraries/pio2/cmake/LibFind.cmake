include (CMakeParseArguments)
include(FindPackageHandleStandardArgs)

#==============================================================================
#
#  FUNCTIONS TO HELP WITH Find* MODULES
#
#==============================================================================

#______________________________________________________________________________
# - Wrapper for finding static libraries ONLY
#
macro (find_static_library)
    set (_CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES})
    set (CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_STATIC_LIBRARY_SUFFIX})
    find_library(${ARGN})
    set (CMAKE_FIND_LIBRARY_SUFFIXES ${_CMAKE_FIND_LIBRARY_SUFFIXES})
    unset (_CMAKE_FIND_LIBRARY_SUFFIXES)
endmacro ()


#______________________________________________________________________________
# - Wrapper for finding shared/dynamic libraries ONLY
#
macro (find_shared_library)
    set (_CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES})
    set (CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_SHARED_LIBRARY_SUFFIX})
    find_library(${ARGN})
    set (CMAKE_FIND_LIBRARY_SUFFIXES ${_CMAKE_FIND_LIBRARY_SUFFIXES})
    unset (_CMAKE_FIND_LIBRARY_SUFFIXES)
endmacro ()


#______________________________________________________________________________
# - Function to determine type (SHARED or STATIC) of library
#
#   Input:
#     LIB             (FILE)
#
#   Returns:
#     RETURN_VAR      (BOOL)
#
function (is_shared_library RETURN_VAR LIB)
    get_filename_component(libext ${LIB} EXT)
    if (libext MATCHES ${CMAKE_SHARED_LIBRARY_SUFFIX})
        set (${RETURN_VAR} TRUE PARENT_SCOPE)
    else ()
        set (${RETURN_VAR} FALSE PARENT_SCOPE)
    endif ()
endfunction ()


#______________________________________________________________________________
# - Function to define a valid package component
#
#   Input:
#     ${PKG}_DEFAULT             (BOOL)
#     ${PKG}_COMPONENT           (STRING)
#     ${PKG}_INCLUDE_NAMES       (LIST)
#     ${PKG}_LIBRARY_NAMES       (LIST)
#
#   Returns:
#     ${PKG}_DEFAULT_COMPONENT           (STRING)
#     ${PKG}_VALID_COMPONENTS            (LIST)
#     ${PKG}_${COMPONENT}_INCLUDE_NAMES  (LIST)
#     ${PKG}_${COMPONENT}_LIBRARY_NAMES  (LIST)
#
function (define_package_component PKG)

    # Parse the input arguments
    set (options DEFAULT)
    set (oneValueArgs COMPONENT)
    set (multiValueArgs INCLUDE_NAMES LIBRARY_NAMES)
    cmake_parse_arguments (${PKG} "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    if (${PKG}_COMPONENT)
        set (PKGCOMP ${PKG}_${${PKG}_COMPONENT})
    else ()
        set (PKGCOMP ${PKG})
    endif ()
    
    # Set return values
    if (${PKG}_COMPONENT)
        if (${PKG}_DEFAULT)
            set (${PKG}_DEFAULT_COMPONENT ${${PKG}_COMPONENT} PARENT_SCOPE)
        endif ()
        set (VALID_COMPONENTS ${${PKG}_VALID_COMPONENTS})
        list (APPEND VALID_COMPONENTS ${${PKG}_COMPONENT})
        set (${PKG}_VALID_COMPONENTS ${VALID_COMPONENTS} PARENT_SCOPE)
    endif ()
    set (${PKGCOMP}_INCLUDE_NAMES ${${PKG}_INCLUDE_NAMES} PARENT_SCOPE)
    set (${PKGCOMP}_LIBRARY_NAMES ${${PKG}_LIBRARY_NAMES} PARENT_SCOPE)

endfunction ()


#______________________________________________________________________________
# - Function to find valid package components
#
#   Assumes pre-defined variables: 
#     ${PKG}_FIND_COMPONENTS        (LIST)
#     ${PKG}_DEFAULT_COMPONENT      (STRING)
#     ${PKG}_VALID_COMPONENTS       (LIST)
#
#   Returns:
#     ${PKG}_FIND_VALID_COMPONENTS  (LIST)
#
function (find_valid_components PKG)

    if (NOT ${PKG}_FIND_COMPONENTS)
        set (${PKG}_FIND_COMPONENTS ${${PKG}_DEFAULT_COMPONENT})
    endif ()
    
    set (FIND_VALID_COMPONENTS)
    foreach (comp IN LISTS ${PKG}_FIND_COMPONENTS)
        if (";${${PKG}_VALID_COMPONENTS};" MATCHES ";${comp};")
            list (APPEND FIND_VALID_COMPONENTS ${comp})
        endif ()
    endforeach ()

    set (${PKG}_FIND_VALID_COMPONENTS ${FIND_VALID_COMPONENTS} PARENT_SCOPE)
    
endfunction ()


#______________________________________________________________________________
# - Initialize a list of paths from a list of includes and libraries
#
# Input:
#   INCLUDE_DIRECTORIES
#   LIBRARIES
#
# Ouput:
#   ${PATHLIST}
#
function (initialize_paths PATHLIST)

    # Parse the input arguments
    set (multiValueArgs INCLUDE_DIRECTORIES LIBRARIES)
    cmake_parse_arguments (INIT "" "" "${multiValueArgs}" ${ARGN})
    
    set (paths)
    foreach (inc IN LISTS INIT_INCLUDE_DIRECTORIES)
        list (APPEND paths ${inc})
        get_filename_component (dname ${inc} NAME)
        if (dname MATCHES "include")
            get_filename_component (prefx ${inc} PATH)
            list (APPEND paths ${prefx})
        endif ()
    endforeach ()
    foreach (lib IN LISTS INIT_LIBRARIES)
        get_filename_component (libdir ${lib} PATH)
        list (APPEND paths ${libdir})
        get_filename_component (dname ${libdir} PATH)
        if (dname MATCHES "lib")
            get_filename_component (prefx ${libdir} PATH)
            list (APPEND paths ${prefx})
        endif ()
    endforeach ()
    
    set (${PATHLIST} ${paths} PARENT_SCOPE)

endfunction ()


#______________________________________________________________________________
# - Basic find package macro for a specific component
#
# Assumes pre-defined variables:
#   ${PKG}_${COMP}_INCLUDE_NAMES or ${PKG}_INCLUDE_NAMES
#   ${PKG}_${COMP}_LIBRARY_NAMES or ${PKG}_LIBRARY_NAMES
#
# Input:
#   ${PKG}_COMPONENT
#   ${PKG}_HINTS
#   ${PKG}_PATHS
#
function (find_package_component PKG)

    # Parse the input arguments
    set (options)
    set (oneValueArgs COMPONENT)
    set (multiValueArgs HINTS PATHS)
    cmake_parse_arguments (${PKG} "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})    
    set (COMP ${${PKG}_COMPONENT})
    if (COMP)
        set (PKGCOMP ${PKG}_${COMP})
    else ()
        set (PKGCOMP ${PKG})
    endif ()
    string (TOUPPER ${PKG} PKGUP)
    string (TOUPPER ${PKGCOMP} PKGCOMPUP)
    
    # Only continue if package not found already
    if (NOT ${PKGCOMP}_FOUND)
    
        # Handle QUIET and REQUIRED arguments
        if (${${PKG}_FIND_QUIETLY})
            set (${PKGCOMP}_FIND_QUIETLY TRUE)
        endif ()
        if (${${PKG}_FIND_REQUIRED})
            set (${PKGCOMP}_FIND_REQUIRED TRUE)
        endif ()
        
        # Determine search order
        set (SEARCH_DIRS)
        if (${PKG}_HINTS)
            list (APPEND SEARCH_DIRS ${${PKG}_HINTS})
        endif ()
        if (${PKGCOMP}_PATH)
            list (APPEND SEARCH_DIRS ${${PKGCOMP}_PATH})
        endif ()
        if (${PKG}_PATH)
            list (APPEND SEARCH_DIRS ${${PKG}_PATH})
        endif ()
        if (DEFINED ENV{${PKGCOMPUP}})
            list (APPEND SEARCH_DIRS $ENV{${PKGCOMPUP}})
        endif ()
        if (DEFINED ENV{${PKGUP}})
            list (APPEND SEARCH_DIRS $ENV{${PKGUP}})
        endif ()
        if (CMAKE_SYSTEM_PREFIX_PATH)
            list (APPEND SEARCH_DIRS ${CMAKE_SYSTEM_PREFIX_PATH})
        endif ()
        if (${PKG}_PATHS)
            list (APPEND SEARCH_DIRS ${${PKG}_PATHS})
        endif ()

        # Start the search for the include file and library file. Only overload
        # if the variable is not defined.
        foreach (suffix PREFIX LIBRARY INCLUDE_DIR)
            if (NOT DEFINED ${PKGCOMP}_${suffix})
                set (${PKGCOMP}_${suffix} ${PKGCOMP}_${suffix}-NOTFOUND)
            endif ()
        endforeach ()

        foreach (dir IN LISTS SEARCH_DIRS)
        
            # Search for include file names in current dirrectory
            foreach (iname IN LISTS ${PKGCOMP}_INCLUDE_NAMES)
                if (EXISTS ${dir}/${iname})
                    set (${PKGCOMP}_PREFIX ${dir})
                    set (${PKGCOMP}_INCLUDE_DIR ${dir})
                    break ()
                endif ()
                if (EXISTS ${dir}/include/${iname})
                    set (${PKGCOMP}_PREFIX ${dir})
                    set (${PKGCOMP}_INCLUDE_DIR ${dir}/include)
                    break ()
                endif ()
            endforeach ()
    
            # Search for library file names in the found prefix only!
            if (${PKGCOMP}_PREFIX)
                find_library (${PKGCOMP}_LIBRARY
                              NAMES ${${PKGCOMP}_LIBRARY_NAMES}
                              PATHS ${${PKGCOMP}_PREFIX}
                              PATH_SUFFIXES lib
                              NO_DEFAULT_PATH)
                              
                # If found, check if library is static or dynamic 
                if (${PKGCOMP}_LIBRARY)
                    is_shared_library (${PKGCOMP}_IS_SHARED ${${PKGCOMP}_LIBRARY})
    
                    # If we want only shared libraries, and it isn't shared...                
                    if (PREFER_SHARED AND NOT ${PKGCOMP}_IS_SHARED)
                        find_shared_library (${PKGCOMP}_SHARED_LIBRARY
                                             NAMES ${${PKGCOMP}_LIBRARY_NAMES}
                                             PATHS ${${PKGCOMP}_PREFIX}
                                             PATH_SUFFIXES lib
                                             NO_DEFAULT_PATH)
                        if (${PKGCOMP}_SHARED_LIBRARY)
                            set (${PKGCOMP}_LIBRARY ${${PKGCOMP}_SHARED_LIBRARY})
                            set (${PKGCOMP}_IS_SHARED TRUE)
                        endif ()
    
                    # If we want only static libraries, and it is shared...
                    elseif (PREFER_STATIC AND ${PKGCOMP}_IS_SHARED)
                        find_static_library (${PKGCOMP}_STATIC_LIBRARY
                                             NAMES ${${PKGCOMP}_LIBRARY_NAMES}
                                             PATHS ${${PKGCOMP}_PREFIX}
                                             PATH_SUFFIXES lib
                                             NO_DEFAULT_PATH)
                        if (${PKGCOMP}_STATIC_LIBRARY)
                            set (${PKGCOMP}_LIBRARY ${${PKGCOMP}_STATIC_LIBRARY})
                            set (${PKGCOMP}_IS_SHARED FALSE)
                        endif ()
                    endif ()
                endif ()
                              
                # If include dir and library both found, then we're done
                if (${PKGCOMP}_INCLUDE_DIR AND ${PKGCOMP}_LIBRARY)
                    break ()
                    
                # Otherwise, reset the search variables and continue
                else ()
                    set (${PKGCOMP}_PREFIX ${PKGCOMP}_PREFIX-NOTFOUND)
                    set (${PKGCOMP}_INCLUDE_DIR ${PKGCOMP}_INCLUDE_DIR-NOTFOUND)
                    set (${PKGCOMP}_LIBRARY ${PKGCOMP}_LIBRARY-NOTFOUND)
                endif ()
            endif ()
            
        endforeach ()
        
        # handle the QUIETLY and REQUIRED arguments and 
        # set NetCDF_C_FOUND to TRUE if all listed variables are TRUE
        find_package_handle_standard_args (${PKGCOMP} DEFAULT_MSG
                                           ${PKGCOMP}_LIBRARY 
                                           ${PKGCOMP}_INCLUDE_DIR)
        mark_as_advanced (${PKGCOMP}_INCLUDE_DIR ${PKGCOMP}_LIBRARY)
        
        # HACK For bug in CMake v3.0:
        set (${PKGCOMP}_FOUND ${${PKGCOMPUP}_FOUND})
    
        # Set return variables
        if (${PKGCOMP}_FOUND)
            set (${PKGCOMP}_INCLUDE_DIRS ${${PKGCOMP}_INCLUDE_DIR})
            set (${PKGCOMP}_LIBRARIES ${${PKGCOMP}_LIBRARY})
        endif ()

        # Set variables in parent scope
        set (${PKGCOMP}_FOUND        ${${PKGCOMP}_FOUND}         PARENT_SCOPE)
        set (${PKGCOMP}_INCLUDE_DIR  ${${PKGCOMP}_INCLUDE_DIR}   PARENT_SCOPE)
        set (${PKGCOMP}_INCLUDE_DIRS ${${PKGCOMP}_INCLUDE_DIRS}  PARENT_SCOPE)
        set (${PKGCOMP}_LIBRARY      ${${PKGCOMP}_LIBRARY}       PARENT_SCOPE)
        set (${PKGCOMP}_LIBRARIES    ${${PKGCOMP}_LIBRARIES}     PARENT_SCOPE)
        set (${PKGCOMP}_IS_SHARED    ${${PKGCOMP}_IS_SHARED}     PARENT_SCOPE)
        
    endif ()

endfunction ()



