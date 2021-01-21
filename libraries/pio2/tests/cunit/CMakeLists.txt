include (LibMPI)

include_directories("${CMAKE_SOURCE_DIR}/tests/cunit")
include_directories("${CMAKE_BINARY_DIR}")

# Compiler-specific compiler options
if ("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c99")
elseif ("${CMAKE_C_COMPILER_ID}" STREQUAL "PGI")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -c99")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -c99")
elseif ("${CMAKE_C_COMPILER_ID}" STREQUAL "Intel")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c99")
elseif ("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c99")
endif()
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g -O0")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g -O0")

#==============================================================================
#  PREPARE FOR TESTING
#==============================================================================

# Don't run these tests if we are using MPI SERIAL.
if (NOT PIO_USE_MPISERIAL)
  add_executable (test_async_mpi EXCLUDE_FROM_ALL test_async_mpi.c)
  add_dependencies (tests test_async_mpi)
  add_executable (test_intercomm2 EXCLUDE_FROM_ALL test_intercomm2.c test_common.c)
  target_link_libraries (test_intercomm2 pioc)
  add_dependencies (tests test_intercomm2)
  add_executable (test_async_simple EXCLUDE_FROM_ALL test_async_simple.c test_common.c)
  target_link_libraries (test_async_simple pioc)
  add_dependencies (tests test_async_simple)
  add_executable (test_async_3proc EXCLUDE_FROM_ALL test_async_3proc.c test_common.c)
  target_link_libraries (test_async_3proc pioc)
  add_dependencies (tests test_async_3proc)
  add_executable (test_async_4proc EXCLUDE_FROM_ALL test_async_4proc.c test_common.c)
  target_link_libraries (test_async_4proc pioc)
  add_dependencies (tests test_async_4proc)
  add_executable (test_iosystem2_simple EXCLUDE_FROM_ALL test_iosystem2_simple.c test_common.c)
  target_link_libraries (test_iosystem2_simple pioc)
  add_dependencies (tests test_iosystem2_simple)
  add_executable (test_iosystem2_simple2 EXCLUDE_FROM_ALL test_iosystem2_simple2.c test_common.c)
  target_link_libraries (test_iosystem2_simple2 pioc)
  add_dependencies (tests test_iosystem2_simple2)
  add_executable (test_iosystem2 EXCLUDE_FROM_ALL test_iosystem2.c test_common.c)
  target_link_libraries (test_iosystem2 pioc)
  add_dependencies (tests test_iosystem2)
  add_executable (test_iosystem3_simple EXCLUDE_FROM_ALL test_iosystem3_simple.c test_common.c)
  target_link_libraries (test_iosystem3_simple pioc)
  add_dependencies (tests test_iosystem3_simple)
  add_executable (test_iosystem3_simple2 EXCLUDE_FROM_ALL test_iosystem3_simple2.c test_common.c)
  target_link_libraries (test_iosystem3_simple2 pioc)
  add_dependencies (tests test_iosystem3_simple2)
  add_executable (test_iosystem3 EXCLUDE_FROM_ALL test_iosystem3.c test_common.c)
  target_link_libraries (test_iosystem3 pioc)
  add_dependencies (tests test_iosystem3)
  add_executable (test_pioc EXCLUDE_FROM_ALL test_pioc.c test_common.c test_shared.c)
  target_link_libraries (test_pioc pioc)
  add_executable (test_pioc_unlim EXCLUDE_FROM_ALL test_pioc_unlim.c test_common.c test_shared.c)
  target_link_libraries (test_pioc_unlim pioc)
  add_executable (test_pioc_putget EXCLUDE_FROM_ALL test_pioc_putget.c test_common.c test_shared.c)
  target_link_libraries (test_pioc_putget pioc)
  add_executable (test_pioc_fill EXCLUDE_FROM_ALL test_pioc_fill.c test_common.c test_shared.c)
  target_link_libraries (test_pioc_fill pioc)
  add_executable (test_darray EXCLUDE_FROM_ALL test_darray.c test_common.c)
  target_link_libraries (test_darray pioc)
  add_executable (test_darray_append EXCLUDE_FROM_ALL test_darray_append.c test_common.c)
  target_link_libraries (test_darray_append pioc)
  add_executable (test_darray_frame EXCLUDE_FROM_ALL test_darray_frame.c test_common.c)
  target_link_libraries (test_darray_frame pioc)
  add_executable (test_darray_multi EXCLUDE_FROM_ALL test_darray_multi.c test_common.c)
  target_link_libraries (test_darray_multi pioc)
  add_executable (test_darray_multivar EXCLUDE_FROM_ALL test_darray_multivar.c test_common.c)
  target_link_libraries (test_darray_multivar pioc)
  add_executable (test_darray_multivar2 EXCLUDE_FROM_ALL test_darray_multivar2.c test_common.c)
  target_link_libraries (test_darray_multivar2 pioc)
  add_executable (test_darray_multivar3 EXCLUDE_FROM_ALL test_darray_multivar3.c test_common.c)
  target_link_libraries (test_darray_multivar3 pioc)
  add_executable (test_darray_1d EXCLUDE_FROM_ALL test_darray_1d.c test_common.c)
  target_link_libraries (test_darray_1d pioc)
  add_executable (test_darray_3d EXCLUDE_FROM_ALL test_darray_3d.c test_common.c)
  target_link_libraries (test_darray_3d pioc)
  add_executable (test_decomp_uneven EXCLUDE_FROM_ALL test_decomp_uneven.c test_common.c)
  target_link_libraries (test_decomp_uneven pioc)
  add_executable (test_decomps EXCLUDE_FROM_ALL test_decomps.c test_common.c)
  target_link_libraries (test_decomps pioc)
  add_executable (test_rearr EXCLUDE_FROM_ALL test_rearr.c test_common.c)
  target_link_libraries (test_rearr pioc)
  add_executable (test_darray_fill EXCLUDE_FROM_ALL test_darray_fill.c test_common.c)
  target_link_libraries (test_darray_fill pioc)
  add_executable (test_decomp_frame EXCLUDE_FROM_ALL test_decomp_frame.c test_common.c)
  target_link_libraries (test_decomp_frame pioc)
  add_executable (test_perf2 EXCLUDE_FROM_ALL test_perf2.c test_common.c)
    target_link_libraries (test_perf2)
    add_executable (test_darray_async_simple EXCLUDE_FROM_ALL test_darray_async_simple.c test_common.c)
    target_link_libraries (test_darray_async_simple pioc)
    add_executable (test_darray_async EXCLUDE_FROM_ALL test_darray_async.c test_common.c)
    target_link_libraries (test_darray_async pioc)
    add_executable (test_darray_async_many EXCLUDE_FROM_ALL test_darray_async_many.c test_common.c)
    target_link_libraries (test_darray_async_many pioc)
    add_executable (test_darray_2sync EXCLUDE_FROM_ALL test_darray_2sync.c test_common.c)
    target_link_libraries (test_darray_2sync pioc)
    add_executable (test_async_multicomp EXCLUDE_FROM_ALL test_async_multicomp.c test_common.c)
    target_link_libraries (test_async_multicomp pioc)
    add_executable (test_async_multi2 EXCLUDE_FROM_ALL test_async_multi2.c test_common.c)
    target_link_libraries (test_async_multi2 pioc)
    add_executable (test_async_manyproc EXCLUDE_FROM_ALL test_async_manyproc.c test_common.c)
    target_link_libraries (test_async_manyproc pioc)
    add_executable (test_async_1d EXCLUDE_FROM_ALL test_async_1d.c)
    target_link_libraries (test_async_1d pioc)
    add_executable (test_simple EXCLUDE_FROM_ALL test_simple.c test_common.c)
    target_link_libraries (test_simple pioc)
endif ()
add_executable (test_spmd EXCLUDE_FROM_ALL test_spmd.c test_common.c)
target_link_libraries (test_spmd pioc)
add_dependencies (tests test_spmd)
add_dependencies (tests test_rearr)
add_dependencies (tests test_pioc)
add_dependencies (tests test_pioc_unlim)
add_dependencies (tests test_pioc_putget)
add_dependencies (tests test_pioc_fill)
add_dependencies (tests test_darray)
add_dependencies (tests test_darray_append)
add_dependencies (tests test_darray_frame)
add_dependencies (tests test_darray_multi)
add_dependencies (tests test_darray_multivar)
add_dependencies (tests test_darray_multivar2)
add_dependencies (tests test_darray_multivar3)
add_dependencies (tests test_darray_1d)
add_dependencies (tests test_darray_3d)
add_dependencies (tests test_decomp_uneven)
add_dependencies (tests test_decomps)
add_dependencies (tests test_darray_fill)
add_dependencies (tests test_decomp_frame)
#  add_dependencies (tests test_perf2)
add_dependencies (tests test_darray_async_simple)
add_dependencies (tests test_darray_async)
add_dependencies (tests test_darray_async_many)
add_dependencies (tests test_darray_2sync)
add_dependencies (tests test_async_multicomp)
add_dependencies (tests test_async_multi2)
add_dependencies (tests test_async_manyproc)
add_dependencies (tests test_async_1d)
add_dependencies (tests test_simple)

# Test Timeout in seconds.
if (PIO_VALGRIND_CHECK)
  set (DEFAULT_TEST_TIMEOUT 480)
else ()
  set (DEFAULT_TEST_TIMEOUT 480)
endif ()

# All tests need a certain number of tasks, but they should be able to
# run successfully with more than they need. Test this by providing an
# extra processor for each C test.
set (AT_LEAST_TWO_TASKS 3)
set (AT_LEAST_THREE_TASKS 4)
set (AT_LEAST_FOUR_TASKS 5)
set (AT_LEAST_EIGHT_TASKS 9)
set (EXACTLY_FOUR_TASKS 4)

if (PIO_USE_MPISERIAL)
  add_test(NAME test_pioc
    COMMAND test_pioc)
else ()
  add_mpi_test(test_async_mpi
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_async_mpi
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_spmd
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_spmd
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_rearr
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_rearr
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_intercomm2
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_intercomm2
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_async_simple
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_async_simple
    NUMPROCS ${AT_LEAST_TWO_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_async_3proc
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_async_3proc
    NUMPROCS ${AT_LEAST_THREE_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_async_4proc
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_async_4proc
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_iosystem2_simple
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_iosystem2_simple
    NUMPROCS ${AT_LEAST_TWO_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_iosystem2_simple2
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_iosystem2_simple2
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_iosystem2
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_iosystem2
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_iosystem3_simple
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_iosystem3_simple
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_iosystem3_simple2
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_iosystem3_simple2
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_iosystem3
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_iosystem3
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_pioc
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_pioc
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_pioc_unlim
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_pioc_unlim
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_pioc_putget
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_pioc_putget
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_pioc_fill
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_pioc_fill
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray_append
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_append
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray_frame
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_frame
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray_multi
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_multi
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray_multivar
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_multivar
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray_multivar2
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_multivar2
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  # add_mpi_test(test_darray_multivar3
  #   EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_multivar3
  #   NUMPROCS ${AT_LEAST_FOUR_TASKS}
  #   TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray_1d
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_1d
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray_3d
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_3d
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray_fill
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_fill
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray_2sync
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_2sync
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray_async_simple
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_async_simple
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
    # add_mpi_test(test_perf2
    #   EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_perf2
    #   NUMPROCS ${AT_LEAST_FOUR_TASKS}
    #   TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray_async
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_async
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_darray_async_many
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_darray_async_many
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_async_multicomp
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_async_multicomp
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_async_multi2
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_async_multi2
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_async_manyproc
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_async_manyproc
    NUMPROCS ${AT_LEAST_EIGHT_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_decomp_uneven
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_decomp_uneven
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_decomps
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_decomps
    NUMPROCS ${AT_LEAST_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
  add_mpi_test(test_simple
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/test_simple
    NUMPROCS ${EXACTLY_FOUR_TASKS}
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
endif ()
MESSAGE("CMAKE_EXE_LINKER_FLAGS ${CMAKE_EXE_LINKER_FLAGS}")
