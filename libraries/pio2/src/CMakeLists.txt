#==============================================================================
#  PRELIMINARIES
#==============================================================================

# Test for big-endian nature
if (PIO_TEST_BIG_ENDIAN)
  include (TestBigEndian)
  test_big_endian (PIO_BIG_ENDIAN_TEST_RESULT)
  if (PIO_BIG_ENDIAN_TEST_RESULT)
    set (PIO_BIG_ENDIAN ON  CACHE BOOL "Whether machine is big endian")
  else ()
    set (PIO_BIG_ENDIAN OFF CACHE BOOL "Whether machine is big endian")
  endif ()
else ()
  set (PIO_BIG_ENDIAN OFF CACHE BOOL "Whether machine is big endian")
endif ()

# Look for GPTL
if (PIO_ENABLE_TIMING)
  find_package (GPTL COMPONENTS C QUIET)
  find_package (GPTL COMPONENTS Fortran_Perf QUIET)
endif ()

#==============================================================================
#  INCLUDE SOURCE DIRECTORIES
#==============================================================================

# Build GPTL only if necessary
if (PIO_ENABLE_TIMING)
  if (NOT GPTL_C_FOUND OR NOT GPTL_Fortran_Perf_FOUND)
    add_subdirectory (gptl)
  endif ()
endif ()

# Build the C library
add_subdirectory (clib)
set(CFLAGS ${CFLAGS}  PARENT_SCOPE)
set(CPPFLAGS ${CPPFLAGS} PARENT_SCOPE)


# Build the Fortran library
if (PIO_ENABLE_FORTRAN)
  add_subdirectory (flib)
  set(FFLAGS ${FFLAGS} PARENT_SCOPE)
  set(FCFLAGS ${FCFLAGS} PARENT_SCOPE)
  set(FPPFLAGS ${FPPFLAGS} PARENT_SCOPE)
endif ()
