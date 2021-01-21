# This is part of the PIO library.
#
# This is the cmake file to build the test directory for netCDF integration.
#
# Ed Hartnett 8/19/20

include (LibMPI)

include_directories("${CMAKE_SOURCE_DIR}/tests/ncint")
include_directories("${CMAKE_BINARY_DIR}")

set (my_tests tst_async_multi tst_ncint_async_perf
  tst_ncint_perf tst_pio_async tst_pio_udf tst_var_compress)

# Test Timeout in seconds.
if (PIO_VALGRIND_CHECK)
  set (DEFAULT_TEST_TIMEOUT 480)
else ()
  set (DEFAULT_TEST_TIMEOUT 240)
endif ()

FOREACH(tst ${my_tests})
  add_executable (${tst} EXCLUDE_FROM_ALL ${tst}.c)
  add_dependencies (tests ${tst})
  target_link_libraries (${tst} pioc)
  add_mpi_test(${tst}
    EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/${tst}
    NUMPROCS 4
    TIMEOUT ${DEFAULT_TEST_TIMEOUT})
ENDFOREACH()

