## This is the automake file for building the netCDF integration layer
## tests.

# Ed Hartnett 7/3/19

# Put together AM_CPPFLAGS and AM_LDFLAGS.
AM_CPPFLAGS = -I$(top_srcdir)/src/clib
LDADD = ${top_builddir}/src/clib/libpioc.la

# Build the test for make check.
check_PROGRAMS = tst_pio_udf tst_pio_async tst_async_multi	\
tst_ncint_async_perf tst_ncint_perf tst_var_compress

tst_pio_udf_SOURCES = tst_pio_udf.c pio_err_macros.h
tst_pio_async_SOURCES = tst_pio_async.c pio_err_macros.h
tst_async_multi_SOURCES = tst_async_multi.c pio_err_macros.h
tst_ncint_async_perf_SOURCES = tst_ncint_async_perf.c pio_err_macros.h
tst_ncint_perf_SOURCES = tst_ncint_perf.c pio_err_macros.h

if RUN_TESTS
# Tests will run from a bash script.
TESTS = run_tests.sh run_perf.sh
endif # RUN_TESTS

# Distribute the test script.
EXTRA_DIST = run_tests.sh.in run_perf.sh.in

# Clean up files produced during testing.
CLEANFILES = *.nc *.log

DISTCLEANFILES = run_tests.sh run_perf.sh
