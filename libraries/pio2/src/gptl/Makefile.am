# This is part of PIO. It creates the Makefile for the GPTL directory.

# Ed Hartnett 4/9/19

# Turn off parallel builds in this directory.
.NOTPARALLEL:

# Build these uninstalled convenience libraries.
noinst_LTLIBRARIES = libperf_utils.la libperf_mod.la

# The convenience libraries depends on their source.
libperf_utils_la_SOURCES = perf_utils.F90
libperf_mod_la_SOURCES = perf_mod.F90 f_wrappers_2.c private.h

# Each mod file depends on the .o file.
perf_utils.mod: perf_utils.$(OBJEXT)
perf_mod.mod: perf_mod.$(OBJEXT)

# Does the user want to build fortran?
#if BUILD_FORTRAN
#endif

EXTRA_DIST = CMakeLists.txt GPTLget_memusage.c GPTLprint_memusage.c	\
GPTLutil.c f_wrappers.c gptl.c gptl_papi.c threadutil.c gptl.inc	\
gptl.h private.h
