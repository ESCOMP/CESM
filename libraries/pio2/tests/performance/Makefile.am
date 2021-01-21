## This is the automake file for building the Fortran performance
## tests for the PIO library.

# Ed Hartnett 4/6/19

# Parallel builds don't currently work in this directory.
.NOTPARALLEL:

# Find the pio.mod file.
AM_CPPFLAGS = -I$(top_srcdir)/src/flib

# Link to test util library and PIO Fortran and C libs.
LDADD = $(top_builddir)/src/gptl/libperf_mod.la	\
$(top_builddir)/src/gptl/libperf_utils.la	\
${top_builddir}/tests/general/libpio_tutil.la	\
${top_builddir}/src/flib/libpiof.la		\
${top_builddir}/src/clib/libpioc.la

# Find perf_mod and perf_util.
AM_CPPFLAGS += -I$(top_builddir)/src/gptl

# Find pio_tutil.mod
AM_CPPFLAGS += -I$(top_builddir)/tests/general

# Build the test for make check.
check_PROGRAMS = pioperf

pioperf_SOURCES = pioperformance.F90

if RUN_TESTS
# Tests will run from a bash script.
TESTS = run_tests.sh
endif # RUN_TESTS

EXTRA_DIST = CMakeLists.txt gensimple.pl Pioperformance.md pioperf.nl	\
run_tests.sh.in

# Clean up files produced during testing.
CLEANFILES = *.nc *.log *.mod

DISTCLEANFILES = run_tests.sh
