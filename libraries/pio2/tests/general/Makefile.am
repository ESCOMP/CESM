## This is the automake file for building the Fortran general tests
## for the PIO library.

# Ed Hartnett 3/25/19

# Parallel builds don't currently work in this directory.
.NOTPARALLEL:

# Find the pio.mod file.
AM_CPPFLAGS = -I$(top_srcdir)/src/flib

# Link to our test, fortran, and C libraries.
LDADD = libpio_tutil.la ${top_builddir}/src/flib/libpiof.la	\
${top_builddir}/src/clib/libpioc.la

# There is a test utility mod file in this subdir which must be built.
SUBDIRS = util

# Build these uninstalled convenience libraries.
noinst_LTLIBRARIES = libpio_tutil.la libpio_rearr_opts.la

# The convenience libraries depends on their source.
libpio_tutil_la_SOURCES = pio_tutil.F90 # configure copies this from util dir.
libpio_rearr_opts_la_SOURCES = pio_rearr_opts.F90

# Each mod file depends on the .o file.
pio_tutil.mod: pio_tutil.$(OBJEXT)
pio_rearr_opts_tgv.mod: pio_rearr_opts.$(OBJEXT)

# Some mods are dependant on other mods in this dir.
pio_rearr_opts.$(OBJEXT): pio_tutil.mod

BUILT_SOURCES = pio_tutil.mod pio_rearr_opts_tgv.mod

# Build the test for make check.
check_PROGRAMS = pio_init_finalize pio_file_simple_tests	\
pio_file_fail ncdf_simple_tests ncdf_get_put ncdf_fail ncdf_inq	\
pio_rearr pio_rearr_opts2 pio_decomp_tests	\
pio_decomp_tests_1d pio_decomp_tests_2d pio_decomp_tests_3d	\
pio_decomp_frame_tests pio_decomp_fillval pio_iosystem_tests	\
pio_iosystem_tests2 pio_iosystem_tests3

pio_init_finalize_SOURCES = pio_init_finalize.F90
pio_file_simple_tests_SOURCES = pio_file_simple_tests.F90
pio_file_fail_SOURCES = pio_file_fail.F90
ncdf_simple_tests_SOURCES = ncdf_simple_tests.F90
ncdf_get_put_SOURCES = ncdf_get_put.F90
ncdf_fail_SOURCES = ncdf_fail.F90
ncdf_inq_SOURCES = ncdf_inq.F90
pio_rearr_SOURCES = pio_rearr.F90
#pio_rearr_opts_SOURCES = pio_rearr_opts.F90
pio_rearr_opts2_SOURCES = pio_rearr_opts2.F90
pio_decomp_tests_SOURCES = pio_decomp_tests.F90
pio_decomp_tests_1d_SOURCES = pio_decomp_tests_1d.F90
pio_decomp_tests_2d_SOURCES = pio_decomp_tests_2d.F90
pio_decomp_tests_3d_SOURCES = pio_decomp_tests_3d.F90
pio_decomp_frame_tests_SOURCES = pio_decomp_frame_tests.F90
pio_decomp_fillval_SOURCES = pio_decomp_fillval.F90
pio_iosystem_tests_SOURCES = pio_iosystem_tests.F90
pio_iosystem_tests2_SOURCES = pio_iosystem_tests2.F90
pio_iosystem_tests3_SOURCES = pio_iosystem_tests3.F90

if RUN_TESTS
# Tests will run from a bash script.
TESTS = run_tests.sh
endif # RUN_TESTS

%.F90: %.F90.in
	util/pio_tf_f90gen.pl --annotate-source --out=$@ $<

ncdf_fail.F90: ncdf_fail.F90.in
ncdf_get_put.F90: ncdf_get_put.F90.in
ncdf_inq.F90: ncdf_inq.F90.in
ncdf_simple_tests.F90:ncdf_simple_tests.F90.in
pio_decomp_fillval.F90:pio_decomp_fillval.F90.in
pio_decomp_frame_tests.F90:pio_decomp_frame_tests.F90.in
pio_decomp_tests_1d.F90:pio_decomp_tests_1d.F90.in
pio_decomp_tests_2d.F90:pio_decomp_tests_2d.F90.in
pio_decomp_tests_3d.F90:pio_decomp_tests_3d.F90.in
pio_decomp_tests.F90:pio_decomp_tests.F90.in
pio_file_fail.F90:pio_file_fail.F90.in
pio_file_simple_tests.F90:pio_file_simple_tests.F90.in
pio_init_finalize.F90:pio_init_finalize.F90.in
pio_iosystem_tests2.F90:pio_iosystem_tests2.F90.in
pio_iosystem_tests3.F90:pio_iosystem_tests3.F90.in
pio_iosystem_tests.F90:pio_iosystem_tests.F90.in
pio_rearr.F90:pio_rearr.F90.in
pio_rearr_opts2.F90:pio_rearr_opts2.F90.in
pio_rearr_opts.F90:pio_rearr_opts.F90.in

# Distribute the test script.
EXTRA_DIST = CMakeLists.txt run_tests.sh.in ncdf_fail.F90.in		\
ncdf_get_put.F90.in ncdf_inq.F90.in ncdf_simple_tests.F90.in		\
pio_decomp_fillval.F90.in pio_decomp_frame_tests.F90.in			\
pio_decomp_tests_1d.F90.in pio_decomp_tests_2d.F90.in			\
pio_decomp_tests_3d.F90.in pio_decomp_tests.F90.in pio_fail.F90.in	\
pio_file_fail.F90.in pio_file_simple_tests.F90.in			\
pio_init_finalize.F90.in pio_iosystem_tests2.F90.in			\
pio_iosystem_tests3.F90.in pio_iosystem_tests.F90.in pio_rearr.F90.in	\
pio_rearr_opts2.F90.in pio_rearr_opts.F90.in

# Clean up files produced during testing.
CLEANFILES = *.nc *.log *.mod

DISTCLEANFILES = run_tests.sh
