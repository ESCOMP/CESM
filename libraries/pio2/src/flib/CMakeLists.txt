cmake_minimum_required (VERSION 2.8.12)
project (PIOF Fortran)
include (CheckFunctionExists)
include (ExternalProject)
include (LibCheck)

#==============================================================================
#  DEFINE THE TARGET
#==============================================================================

set (PIO_Fortran_SRCS pio_nf.F90
  pio.F90
  pio_kinds.F90
  pio_types.F90
  piolib_mod.F90
  pio_support.F90)

set (PIO_GenF90_SRCS pionfatt_mod.F90
  pionfput_mod.F90
  pionfget_mod.F90
  piodarray.F90)

set (PIO_Fortran_MODS ${CMAKE_CURRENT_BINARY_DIR}/pio.mod
  ${CMAKE_CURRENT_BINARY_DIR}/pio_nf.mod
  ${CMAKE_CURRENT_BINARY_DIR}/pio_types.mod
  ${CMAKE_CURRENT_BINARY_DIR}/piolib_mod.mod
  ${CMAKE_CURRENT_BINARY_DIR}/pionfget_mod.mod
  ${CMAKE_CURRENT_BINARY_DIR}/pio_kinds.mod
  ${CMAKE_CURRENT_BINARY_DIR}/pio_support.mod
  ${CMAKE_CURRENT_BINARY_DIR}/piodarray.mod
  ${CMAKE_CURRENT_BINARY_DIR}/pionfatt_mod.mod
  ${CMAKE_CURRENT_BINARY_DIR}/pionfput_mod.mod)

if (NETCDF_INTEGRATION)
  set (PIO_Fortran_SRCS ${PIO_Fortran_SRCS} ncint_mod.F90)
  set (PIO_Fortran_MODS ${PIO_Fortran_MODS} ${CMAKE_CURRENT_BINARY_DIR}/ncint_mod.mod)
endif ()

add_library (piof ${PIO_Fortran_SRCS} ${PIO_GenF90_SRCS})
if (NOT PIO_ENABLE_FORTRAN)
  set_target_properties(piof PROPERTIES EXCLUDE_FROM_ALL TRUE)
endif ()

# Include flib source and binary directories (for Fortran modules)
target_include_directories (piof
  PUBLIC ${CMAKE_BINARY_DIR}
  PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}
  PUBLIC ${CMAKE_CURRENT_BINARY_DIR})

# System and compiler CPP directives
target_compile_definitions (piof
  PUBLIC ${CMAKE_SYSTEM_DIRECTIVE})
target_compile_definitions (piof
  PUBLIC ${CMAKE_Fortran_COMPILER_DIRECTIVE})

# Compiler-specific compile options
if ("${CMAKE_Fortran_COMPILER_ID}" STREQUAL "GNU")
  target_compile_options (piof
    PRIVATE -ffree-line-length-none)
elseif (CMAKE_Fortran_COMPILER_ID STREQUAL "NAG")
  set ( CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -mismatch_all " )
  #    target_compile_options (piof
  #        PRIVATE -mismatch_all)
elseif (CMAKE_Fortran_COMPILER_ID STREQUAL "Cray")
  set (CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -ef")
elseif (CMAKE_Fortran_COMPILER_ID STREQUAL "Intel")
  set (CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -debug minimal")
endif()
if (CMAKE_BUILD_TYPE STREQUAL "DEBUG")
     set (CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -g")
endif()

# Look for c_sizeof capability
check_macro (Fortran_CSIZEOF
  NAME TryCSizeOf.f90
  HINTS ${CMAKE_MODULE_PATH}
  COMMENT "whether Fortran compiler supports c_sizeof")
if (NOT Fortran_CSIZEOF)
  target_compile_definitions (piof
    PUBLIC NO_C_SIZEOF)
endif()

# Look for filesystem hints
if (PIO_FILESYSTEM_HINTS)
  if (PIO_FILESYSTEM_HINTS STREQUAL lustre)
    message (STATUS "PIO will use lustre filesystem hints")
    target_compile_definitions (piof
      PUBLIC PIO_LUSTRE_HINTS)
  elseif (PIO_FILESYSTEM_HINTS STREQUAL gpfs)
    message (STATUS "PIO will use gpfs filesystem hints")
    target_compile_definitions (piof
      PUBLIC PIO_GPFS_HINTS)
  else ()
    message (WARNING "${PIO_FILESYSTEM_HINTS} not valid option for PIO_FILESYSTEM_HINTS; use gpfs or lustre.")
  endif ()
endif ()

#==============================================================================
#  DEFINE THE INSTALL
#==============================================================================

# Library
install (TARGETS piof DESTINATION lib)

# Fortran Modules
install (FILES ${PIO_Fortran_MODS} DESTINATION include)

#==============================================================================
#  DEFINE THE DEPENDENCIES
#==============================================================================

#===== pioc =====
target_link_libraries(piof
  PUBLIC pioc)

#===== genf90 =====
if (DEFINED GENF90_PATH)
  add_custom_target(genf90
    DEPENDS ${GENF90_PATH}/genf90.pl)
else ()
  ExternalProject_Add (genf90
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/genf90
    GIT_REPOSITORY https://github.com/PARALLELIO/genf90
    GIT_TAG genf90_200608
    UPDATE_COMMAND ""
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND "")
  ExternalProject_Get_Property (genf90 SOURCE_DIR)
  set (GENF90_PATH ${SOURCE_DIR})
  unset (SOURCE_DIR)
endif ()
add_dependencies (piof genf90)

#===== Fortran Source Generation with GenF90 =====
foreach (SRC_FILE IN LISTS PIO_GenF90_SRCS)
  add_custom_command (OUTPUT ${SRC_FILE}
    COMMAND ${GENF90_PATH}/genf90.pl
    ${CMAKE_CURRENT_SOURCE_DIR}/${SRC_FILE}.in > ${SRC_FILE}
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${SRC_FILE}.in genf90)
endforeach ()

#===== MPI =====
if (PIO_USE_MPISERIAL)
  if (MPISERIAL_Fortran_FOUND)
    target_compile_definitions (piof
      PRIVATE _MPISERIAL)
    target_include_directories (piof
      PUBLIC ${MPISERIAL_Fortran_INCLUDE_DIRS})
    target_link_libraries (piof
      PUBLIC ${MPISERIAL_Fortran_LIBRARIES})

    set (WITH_PNETCDF FALSE)
    set (MPI_Fortran_INCLUDE_PATH ${MPISERIAL_Fortran_INCLUDE_DIRS})
  endif ()
endif ()

# Check MPI I/O capabilities
find_path(MPIF_H_PATH
  NAMES mpif.h
  PATHS ${MPI_Fortran_INCLUDE_PATH}
  NO_DEFAULT_PATH)
if (MPIF_H_PATH)
  check_macro (MPI_HAS_MPIIO
    NAME TryMPIIO.f90
    HINTS ${CMAKE_MODULE_PATH}
    DEFINITIONS -I${MPIF_H_PATH}
    COMMENT "whether MPIIO is supported")
  if (${MPI_HAS_MPIIO})
    message (STATUS "MPIIO verified and enabled.")
    target_compile_definitions (piof
      PUBLIC USEMPIIO)
  else ()
    message (STATUS "MPIIO failed verification and therefore disabled.")
  endif ()
else ()
  message (STATUS "MPIIO not detected and therefore disabled.")
endif ()

# Check for MPI Fortran module
find_path(MPIMOD_PATH
  NAMES mpi.mod MPI.mod
  HINTS ${MPI_Fortran_INCLUDE_PATH})

check_macro (MPI_HAS_Fortran_MOD
  NAME TryMPIMod.f90
  HINTS ${CMAKE_MODULE_PATH}
  DEFINITIONS -I${MPIMOD_PATH}
  COMMENT "whether MPI Fortran module is supported")
if (${MPI_HAS_Fortran_MOD})
  message (STATUS "MPI Fortran module verified and enabled.")
else ()
  message (STATUS "MPI Fortran module failed verification and therefore disabled.")
  if (PIO_ENABLE_TIMING AND NOT GPTL_Fortran_Perf_FOUND)
    target_compile_definitions (gptl
      PUBLIC NO_MPIMOD)
  endif()
endif ()

#===== GPTL =====
if (PIO_ENABLE_TIMING)
  if (GPTL_Fortran_Perf_FOUND)
    message (STATUS "Found GPTL Fortran Perf: ${GPTL_Fortran_Perf_LIBRARIES}")
    target_include_directories (piof
      PUBLIC ${GPTL_Fortran_INCLUDE_DIRS})
    target_link_libraries (piof
      PUBLIC ${GPTL_Fortran_LIBRARIES})
  else ()
    message (STATUS "Using internal GPTL Fortran library for timing")
    target_link_libraries (piof
      PUBLIC gptl)
  endif ()
endif ()

#===== NetCDF-Fortran =====
if (NetCDF_Fortran_FOUND)
  target_include_directories (piof
    PUBLIC ${NetCDF_Fortran_INCLUDE_DIRS})
  target_link_libraries (piof
    PUBLIC ${NetCDF_Fortran_LIBRARIES})
endif ()

#===== PnetCDF =====
if (PnetCDF_Fortran_FOUND)
  target_include_directories (piof
    PUBLIC ${PnetCDF_Fortran_INCLUDE_DIRS})
  target_link_libraries (piof
    PUBLIC ${PnetCDF_Fortran_LIBRARIES})

  # Check library for varn functions
  set (CMAKE_REQUIRED_LIBRARIES ${PnetCDF_Fortran_LIBRARY})
endif ()

#===== Add EXTRAs =====
target_include_directories (piof
  PUBLIC ${PIO_Fortran_EXTRA_INCLUDE_DIRS})
target_link_libraries (piof
  PUBLIC ${PIO_Fortran_EXTRA_LIBRARIES})
target_compile_options (piof
  PRIVATE ${PIO_Fortran_EXTRA_COMPILE_OPTIONS})
target_compile_definitions (piof
  PUBLIC ${PIO_Fortran_EXTRA_COMPILE_DEFINITIONS})
if (PIO_Fortran_EXTRA_LINK_FLAGS)
  set_target_properties(piof PROPERTIES
    LINK_FLAGS ${PIO_Fortran_EXTRA_LINK_FLAGS})
endif ()

#===== Check for necessities =====
if (NOT PnetCDF_Fortran_FOUND AND NOT NetCDF_Fortran_FOUND)
  message (FATAL_ERROR "Must have PnetCDF and/or NetCDF Fortran libraries")
endif ()
set(FFLAGS ${CMAKE_Fortran_FLAGS} PARENT_SCOPE)
get_target_property(fppdefs piof COMPILE_DEFINITIONS)
get_target_property(fincludes piof INCLUDE_DIRECTORIES)
foreach(x IN LISTS fppdefs)
  string(APPEND FPPFLAGS " -D${x}")
endforeach()
foreach(x IN LISTS fincludes)
  if (x)
    string(APPEND FPPFLAGS " -I${x}")
  endif()
endforeach()
set(FPPFLAGS ${FPPFLAGS} PARENT_SCOPE)
