## This is the automake file for building the netCDF integration layer
## tests.

# Ed Hartnett 7/3/19

# Find the pio.mod file.
AM_CPPFLAGS = -I$(top_srcdir)/src/flib

# Link to the PIO Fortran and C libraries.
LDADD = ${top_builddir}/src/flib/libpiof.la ${top_builddir}/src/clib/libpioc.la

# Link to the netCDF fortran library.
LDADD += -lnetcdff

# Find the pio.mod file.
AM_FCFLAGS = -I${top_builddir}/src/flib ${CPPFLAGS}

# Find the pio.h and pio_tests.h file for the C test.
AM_CPPFLAGS += -I${top_srcdir}/src/clib -I${top_srcdir}/tests/cunit

# Build the test for make check.
check_PROGRAMS = ftst_pio ftst_pio_orig tst_c_pio
ftst_pio_SOURCES = ftst_pio.f90
ftst_pio_orig_SOURCES = ftst_pio_orig.f90

if RUN_TESTS
# Tests will run from a bash script.
TESTS = run_tests.sh
endif # RUN_TESTS

# Distribute the test script.
EXTRA_DIST = run_tests.sh

# Clean up files produced during testing.
CLEANFILES = *.nc *.log

DISTCLEANFILES = run_tests.sh
