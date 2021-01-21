## This is the autoconf file for the PIO library.
## Ed Hartnett 8/16/17

# Initialize autoconf and automake.
AC_INIT(pio, 2.5.2)
AC_CONFIG_SRCDIR(src/clib/pio_darray.c)
AM_INIT_AUTOMAKE([foreign serial-tests])

# The PIO version, again. Use AC_SUBST for pio_meta.h and
# AC_DEFINE_UNQUOTED for config.h.
AC_SUBST([PIO_VERSION_MAJOR]) PIO_VERSION_MAJOR=2
AC_SUBST([PIO_VERSION_MINOR]) PIO_VERSION_MINOR=5
AC_SUBST([PIO_VERSION_PATCH]) PIO_VERSION_PATCH=2
AC_DEFINE_UNQUOTED([PIO_VERSION_MAJOR], [$PIO_VERSION_MAJOR], [PIO major version])
AC_DEFINE_UNQUOTED([PIO_VERSION_MINOR], [$PIO_VERSION_MINOR], [PIO minor version])
AC_DEFINE_UNQUOTED([PIO_VERSION_PATCH], [$PIO_VERSION_PATCH], [PIO patch version])

# Once more for the documentation.
AC_SUBST([VERSION_MAJOR], [2])
AC_SUBST([VERSION_MINOR], [5])
AC_SUBST([VERSION_PATCH], [2])

# The m4 directory holds macros for autoconf.
AC_CONFIG_MACRO_DIR([m4])

# Configuration date. This follows convention of allowing
# SOURCE_DATE_EPOCH to be used to specify a timestamp, to allow
# byte-for-byte reproducable software builds.
if test "x$SOURCE_DATE_EPOCH" != "x" ; then
    AC_SUBST([CONFIG_DATE]) CONFIG_DATE="`date -u -d "${SOURCE_DATE_EPOCH}"`"
else
    AC_SUBST([CONFIG_DATE]) CONFIG_DATE="`date`"
fi

# Libtool initialisation.
LD=ld # Required for MPE to work.
LT_INIT

# Find and learn about the C compiler.
AC_PROG_CC

# Compiler with version information. This consists of the full path
# name of the compiler and the reported version number.
AC_SUBST([CC_VERSION])
# Strip anything that looks like a flag off of $CC
CC_NOFLAGS=`echo $CC | sed 's/ -.*//'`

if `echo $CC_NOFLAGS | grep ^/ >/dev/null 2>&1`; then
  CC_VERSION="$CC"
else
  CC_VERSION="$CC";
  for x in `echo $PATH | sed -e 's/:/ /g'`; do
    if test -x $x/$CC_NOFLAGS; then
      CC_VERSION="$x/$CC"
      break
    fi
  done
fi

if test -n "$cc_version_info"; then
  CC_VERSION="$CC_VERSION ( $cc_version_info)"
fi

# Find and learn about the Fortran compiler.
AC_PROG_FC

# Compiler with version information. This consists of the full path
# name of the compiler and the reported version number.
AC_SUBST([FC_VERSION])
# Strip anything that looks like a flag off of $FC
FC_NOFLAGS=`echo $FC | sed 's/ -.*//'`

if `echo $FC_NOFLAGS | grep ^/ >/dev/null 2>&1`; then
  FC_VERSION="$FC"
else
  FC_VERSION="$FC";
  for x in `echo $PATH | sed -e 's/:/ /g'`; do
    if test -x $x/$FC_NOFLAGS; then
      FC_VERSION="$x/$FC"
      break
    fi
  done
fi
if test -n "$fc_version_info"; then
  FC_VERSION="$FC_VERSION ( $fc_version_info)"
fi

# Always use malloc in autotools builds.
AC_DEFINE([PIO_USE_MALLOC], [1], [use malloc for memory])

AC_MSG_CHECKING([whether a PIO_BUFFER_SIZE was specified])
AC_ARG_WITH([piobuffersize],
              [AS_HELP_STRING([--with-piobuffersize=<integer>],
                              [Specify buffer size for PIO.])],
            [PIO_BUFFER_SIZE=$with_piobuffersize], [PIO_BUFFER_SIZE=134217728])
AC_MSG_RESULT([$PIO_BUFFER_SIZE])
AC_DEFINE_UNQUOTED([PIO_BUFFER_SIZE], [$PIO_BUFFER_SIZE], [buffer size for darray data.])

# Does the user want to enable logging?
AC_MSG_CHECKING([whether debug logging is enabled])
AC_ARG_ENABLE([logging],
              [AS_HELP_STRING([--enable-logging],
                              [enable debug logging capability (will negatively impact performance). \
			      This debugging feature is probably only of interest to PIO developers.])])
test "x$enable_logging" = xyes || enable_logging=no
AC_MSG_RESULT([$enable_logging])
if test "x$enable_logging" = xyes; then
   AC_DEFINE([PIO_ENABLE_LOGGING], 1, [If true, turn on logging.])
fi

# Does the user want to enable timing?
AC_MSG_CHECKING([whether GPTL timing library is used])
AC_ARG_ENABLE([timing],
              [AS_HELP_STRING([--enable-timing],
                              [enable use of the GPTL timing library.])])
test "x$enable_timing" = xyes || enable_timing=no
AC_MSG_RESULT([$enable_timing])
if test "x$enable_timing" = xyes; then
   AC_DEFINE([TIMING], 1, [If true, use GPTL timing library.])
   AC_DEFINE([HAVE_MPI], [1], [required by GPTL timing library])
fi
AM_CONDITIONAL(USE_GPTL, [test "x$enable_timing" = xyes])

# Does the user want to disable papi?
AC_MSG_CHECKING([whether PAPI should be enabled (if enable-timing is used)])
AC_ARG_ENABLE([papi], [AS_HELP_STRING([--disable-papi],
              [disable PAPI library use])])
test "x$enable_papi" = xno || enable_papi=yes
AC_MSG_RESULT($enable_papi)

# Does the user want to disable test runs?
AC_MSG_CHECKING([whether test runs should be enabled for make check])
AC_ARG_ENABLE([test-runs], [AS_HELP_STRING([--disable-test-runs],
              [disable running run_test.sh test scripts for make check. Tests will still be built.])])
test "x$enable_test_runs" = xno || enable_test_runs=yes
AC_MSG_RESULT($enable_test_runs)
AM_CONDITIONAL(RUN_TESTS, [test "x$enable_test_runs" = xyes])

# Does the user want to enable Fortran library?
AC_MSG_CHECKING([whether Fortran library should be built])
AC_ARG_ENABLE([fortran],
              [AS_HELP_STRING([--enable-fortran],
                              [build the PIO Fortran library.])])
test "x$enable_fortran" = xyes || enable_fortran=no
AC_MSG_RESULT([$enable_fortran])
AM_CONDITIONAL(BUILD_FORTRAN, [test "x$enable_fortran" = xyes])

# Does the user want to use MPE library?
AC_MSG_CHECKING([whether use of MPE library is enabled])
AC_ARG_ENABLE([mpe],
              [AS_HELP_STRING([--enable-mpe],
                              [enable use of MPE library for timing and diagnostic info (may negatively impact performance).])])
test "x$enable_mpe" = xyes || enable_mpe=no
AC_MSG_RESULT([$enable_mpe])
if test "x$enable_mpe" = xyes; then

   AC_SEARCH_LIBS([pthread_setspecific], [pthread], [], [], [])
   dnl AC_SEARCH_LIBS([MPE_Log_get_event_number], [mpe], [HAVE_LIBMPE=yes], [HAVE_LIBMPE=no], [])
   dnl AC_SEARCH_LIBS([MPE_Init_mpi_core], [lmpe], [HAVE_LIBLMPE=yes], [HAVE_LIBLMPE=no], [])
   AC_CHECK_HEADERS([mpe.h], [HAVE_MPE=yes], [HAVE_MPE=no])
   dnl if test "x$HAVE_LIBMPE" != xyes; then
   dnl    AC_MSG_ERROR([-lmpe not found but --enable-mpe used.])
   dnl fi
   dnl if test "x$HAVE_LIBLMPE" != xyes; then
   dnl    AC_MSG_ERROR([-llmpe not found but --enable-mpe used.])
   dnl fi
   if test $enable_fortran = yes; then
      AC_MSG_ERROR([MPE not implemented in Fortran tests and examples. Build without --enable-fortran])
   fi
   AC_DEFINE([USE_MPE], 1, [If true, use MPE timing library.])

fi

# Does the user want to disable pnetcdf?
AC_MSG_CHECKING([whether pnetcdf is to be used])
AC_ARG_ENABLE([pnetcdf],
              [AS_HELP_STRING([--disable-pnetcdf],
                              [Disable pnetcdf use.])])
test "x$enable_pnetcdf" = xno || enable_pnetcdf=yes
AC_MSG_RESULT([$enable_pnetcdf])
AM_CONDITIONAL(BUILD_PNETCDF, [test "x$enable_pnetcdf" = xyes])

# Does the user want to build documentation?
AC_MSG_CHECKING([whether documentation should be build (requires doxygen)])
AC_ARG_ENABLE([docs],
              [AS_HELP_STRING([--enable-docs],
                              [enable building of documentation with doxygen.])])
test "x$enable_docs" = xyes || enable_docs=no
AC_MSG_RESULT([$enable_docs])

# Does the user want to developer documentation?
AC_MSG_CHECKING([whether PIO developer documentation should be build (only for PIO developers)])
AC_ARG_ENABLE([developer-docs],
              [AS_HELP_STRING([--enable-developer-docs],
                              [enable building of PIO developer documentation with doxygen.])])
test "x$enable_developer_docs" = xyes || enable_developer_docs=no
AC_MSG_RESULT([$enable_developer_docs])

# Developer docs enables docs.
if test "x$enable_developer_docs" = xyes; then
   enable_docs=yes
fi
AM_CONDITIONAL(BUILD_DOCS, [test "x$enable_docs" = xyes])

# Did the user specify an MPI launcher other than mpiexec?
AC_MSG_CHECKING([whether a user specified program to run mpi programs])
AC_ARG_WITH([mpiexec],
              [AS_HELP_STRING([--with-mpiexec=<command>],
                              [Specify command to launch MPI parallel tests.])],
            [WITH_MPIEXEC=$with_mpiexec], [WITH_MPIEXEC=mpiexec])
AC_MSG_RESULT([$WITH_MPIEXEC])
AC_SUBST([WITH_MPIEXEC], [$WITH_MPIEXEC])

# Is doxygen installed?
AC_CHECK_PROGS([DOXYGEN], [doxygen])
if test -z "$DOXYGEN" -a "x$enable_docs" = xyes; then
   AC_MSG_ERROR([Doxygen not found but --enable-docs used.])
fi

AC_MSG_NOTICE([processing doxyfile])
# If building docs, process Doxyfile.in into Doxyfile.
if test "x$enable_docs" = xyes; then
   AC_SUBST([CMAKE_CURRENT_SOURCE_DIR], ["."])
   AC_SUBST([CMAKE_BINARY_DIR], [".."])
   if test "x$enable_fortran" = xno; then
      AC_MSG_ERROR([--enable-fortran is required for documentation builds.])
   fi
   AC_SUBST([FORTRAN_SRC_FILES], ["../src/flib/piodarray.f90  ../src/flib/pio.F90  ../src/flib/pio_kinds.F90  ../src/flib/piolib_mod.f90  ../src/flib/pionfatt_mod_2.f90  ../src/flib/pio_nf.F90  ../src/flib/pionfget_mod_2.f90  ../src/flib/pionfput_mod.f90  ../src/flib/pio_support.F90  ../src/flib/pio_types.F90"])
   if test "x$enable_developer_docs" = xyes; then
      AC_SUBST([C_SRC_FILES], ["../src/clib ../src/ncint"])
   else
      AC_SUBST([C_SRC_FILES], ["../src/clib/pio_nc.c ../src/clib/pio_nc4.c ../src/clib/pio_darray.c ../src/clib/pio_get_nc.c ../src/clib/pio_put_nc.c ../src/clib/pioc_support.c ../src/clib/pioc.c ../src/clib/pio_file.c ../src/clib/pio.h ../src/clib/pio_get_vard.c ../src/clib/pio_put_vard.c ../src/ncint/ncint_pio.c ../src/ncint/nc_put_vard.c ../src/ncint/nc_get_vard.c"])
   fi
   AC_CONFIG_FILES([doc/Doxyfile])
fi

AC_MSG_NOTICE([finding libraries])

# Ensure we have MPI.
AC_CHECK_FUNCS([MPI_Init])
if test "x$ac_cv_func_MPI_Init" != "xyes"; then
   AC_MSG_ERROR([Can't link to MPI library. MPI is required.])
fi

# Check for netCDF library.
AC_CHECK_LIB([netcdf], [nc_create], [], [AC_MSG_ERROR([Can't find or link to the netcdf library.])])
AC_CHECK_HEADERS([netcdf.h netcdf_meta.h])

# Check for pnetcdf library.
AC_CHECK_LIB([pnetcdf], [ncmpi_create], [], [])
if test "x$ac_cv_lib_pnetcdf_ncmpi_create" = xno -a $enable_pnetcdf = yes; then
   AC_MSG_ERROR([Pnetcdf not found. Set CPPFLAGS/LDFLAGS or use --disable-pnetcdf.])
fi

# If we have parallel-netcdf, then set these as well.
if test x$ac_cv_lib_pnetcdf_ncmpi_create = xyes; then
   AC_DEFINE([_PNETCDF], [1], [parallel-netcdf library available])
fi

# Do we have netCDF-4?
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([#include "netcdf_meta.h"],
[[#if !NC_HAS_NC4
# error
#endif]
])], [have_netcdf4=yes], [have_netcdf4=no])
AC_MSG_CHECKING([whether netCDF provides netCDF/HDF5])
AC_MSG_RESULT([${have_netcdf4}])

# Do we have a parallel build of netCDF-4? (Really we should be
# checking NC_HAS_PARALLEL4, but that was only recently introduced, so
# we will go with NC_HAS_PARALLEL.)
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([#include "netcdf_meta.h"],
[[#if !NC_HAS_PARALLEL
# error
#endif]
])], [have_netcdf_par=yes], [have_netcdf_par=no])
AC_MSG_CHECKING([whether netCDF provides parallel I/O for netCDF/HDF5])
AC_MSG_RESULT([${have_netcdf_par}])

# Do we have szip?
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([#include "netcdf_meta.h"],
[[#if !NC_HAS_SZIP_WRITE
# error
#endif]
])], [have_szip_write=yes], [have_szip_write=no])
AC_MSG_CHECKING([whether netCDF provides szip write capability])
AC_MSG_RESULT([${have_szip_write}])

# Do we have parallel filter support? Parallel filters are required
# for iotype NETCDF4P to use compression.
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([#include "netcdf_meta.h"],
[[#if !NC_HAS_PAR_FILTERS
# error
#endif]
])], [have_par_filters=yes], [have_par_filters=no])
AC_MSG_CHECKING([whether netCDF provides parallel filter support])
AC_MSG_RESULT([${have_par_filters}])
if test "x$have_par_filters" = xyes ; then
   AC_DEFINE([HAVE_PAR_FILTERS], [1], [if true, netcdf-c supports filters with parallel I/O])
fi

# Is this version 4.7.2, which does not work?
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([#include "netcdf_meta.h"],
[[#if NC_VERSION_MAJOR == 4 && NC_VERSION_MINOR == 7 && NC_VERSION_PATCH == 2
#else
# error
#endif]
])], [have_472=yes], [have_472=no])
AC_MSG_CHECKING([whether this is netcdf-c-4.7.2])
AC_MSG_RESULT([${have_472}])
if test "x$have_472" = xyes; then
   AC_MSG_ERROR([PIO cannot build with netcdf-c-4.7.2, please upgrade your netCDF version.])
fi

# Do we have the correct dispatch table version in netcdf-c for netcdf
# integration?
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([#include "netcdf_meta.h"],
[[#if NC_DISPATCH_VERSION != 2
# error
#endif]
])], [have_dispatch2=yes], [have_dispatch2=no])
AC_MSG_CHECKING([whether netcdf-c supports version 2 of dispatch table for netcdf integration])
AC_MSG_RESULT([${have_dispatch2}])
if test "x$enable_netcdf_integration" = xyes -a "x$have_dispatch2" = xno; then
   AC_MSG_ERROR([NetCDF integration cannot be used with this version of netcdf-c, please upgrade your netCDF version.])
fi

# Set some build settings for when netcdf-4 is supported.
if test x$have_netcdf_par = xyes; then
  AC_DEFINE([_NETCDF4],[1],[Does netCDF library provide netCDF-4 with parallel access])
fi
AM_CONDITIONAL(BUILD_NETCDF4, [test "x$have_netcdf_par" = xyes])

# Not working for some reason, so I will just set it...
AC_CHECK_TYPE([MPI_Offset], [], [], [#include <mpi.h>])
if test "x${ac_cv_type_MPI_Offset}" = xyes; then
   AC_CHECK_SIZEOF([MPI_Offset], [], [#include <mpi.h>])
else
   AC_MSG_ERROR([Unable to find type MPI_Offset in mpi.h])
fi

# If we want the timing library, we must find it.
if test "x$enable_timing" = xyes; then
   AC_CHECK_HEADERS([gptl.h])
   AC_CHECK_LIB([gptl], [GPTLinitialize], [],
                        [AC_MSG_ERROR([Can't find or link to the GPTL library.])])
   if test "x$enable_fortran" = xyes; then
      AC_LANG_PUSH([Fortran])
#      AC_CHECK_HEADERS([gptl.inc])
      AC_CHECK_LIB([gptlf], [gptlstart], [],
                            [AC_MSG_ERROR([Can't find or link to the GPTL Fortran library.])])
      AC_LANG_POP([Fortran])
   fi

   # Check for papi library.
   AC_CHECK_LIB([papi], [PAPI_library_init])
   AC_MSG_CHECKING([whether system can support PAPI])
   have_papi=no
   if test $enable_papi = yes; then
      if test "x$ac_cv_lib_papi_PAPI_library_init" = xyes; then
         # If we have PAPI library, check /proc/sys/kernel/perf_event_paranoid
         # to see if we have permissions.
         if test -f /proc/sys/kernel/perf_event_paranoid; then
            if test `cat /proc/sys/kernel/perf_event_paranoid` != 1; then
               AC_MSG_ERROR([PAPI library found, but /proc/sys/kernel/perf_event_paranoid != 1
                                                  try sudo sh -c 'echo 1 >/proc/sys/kernel/perf_event_paranoid'])
            fi
         fi
         AC_DEFINE([HAVE_PAPI], [1], [PAPI library is present and usable])
         have_papi=yes
      fi
   fi
   AC_MSG_RESULT($have_papi)
fi
AM_CONDITIONAL([HAVE_PAPI], [test "x$have_papi" = xyes])

# Does the user want to build netcdf-c integration layer?
AC_MSG_CHECKING([whether netcdf-c integration layer should be build])
AC_ARG_ENABLE([netcdf-integration],
              [AS_HELP_STRING([--enable-netcdf-integration],
                              [enable building of netCDF C API integration.])])
test "x$enable_netcdf_integration" = xyes || enable_netcdf_integration=no
AC_MSG_RESULT([$enable_netcdf_integration])
if test "x$enable_netcdf_integration" = xyes -a "x$enable_timing" = xyes; then
   AC_MSG_ERROR([Cannot use GPTL timing library with netCDF interation.])
fi
if test "x$enable_netcdf_integration" = xyes -a "x$have_netcdf_par" = xno; then
   AC_MSG_ERROR([Cannot use netCDF integration unless netCDF library was built for parallel I/O.])
fi
# These are needed by ncdispatch.h. Only build with HDF5 parallel
# versions of netCDF. */
if test "x$enable_netcdf_integration" = xyes; then
  AC_DEFINE([HDF5_PARALLEL],[1],[Does HDF5 library provide parallel access])
  AC_DEFINE([USE_NETCDF4],[1],[Does HDF5 library provide parallel access])
  AC_DEFINE([NETCDF_INTEGRATION],[1],[Are we building with netCDF integration])
fi

AM_CONDITIONAL(BUILD_NCINT, [test "x$enable_netcdf_integration" = xyes])
AM_CONDITIONAL(NETCDF_INTEGRATION, [test "x$enable_netcdf_integration" = xyes])

AC_CONFIG_FILES([tests/general/pio_tutil.F90:tests/general/util/pio_tutil.F90])

# The user may have changed the MPIEXEC for these test scripts.
AC_CONFIG_FILES([tests/cunit/run_tests.sh], [chmod ugo+x tests/cunit/run_tests.sh])
AC_CONFIG_FILES([tests/ncint/run_tests.sh], [chmod ugo+x tests/ncint/run_tests.sh])
AC_CONFIG_FILES([tests/ncint/run_perf.sh], [chmod ugo+x tests/ncint/run_perf.sh])
AC_CONFIG_FILES([tests/fncint/run_tests.sh], [chmod ugo+x tests/fncint/run_tests.sh])
AC_CONFIG_FILES([tests/general/run_tests.sh], [chmod ugo+x tests/general/run_tests.sh])
AC_CONFIG_FILES([tests/performance/run_tests.sh], [chmod ugo+x tests/performance/run_tests.sh])
AC_CONFIG_FILES([tests/unit/run_tests.sh], [chmod ugo+x tests/unit/run_tests.sh])
AC_CONFIG_FILES([examples/c/run_tests.sh], [chmod ugo+x examples/c/run_tests.sh])
AC_CONFIG_FILES([examples/f03/run_tests.sh], [chmod ugo+x examples/f03/run_tests.sh])

# Args:
# 1. netcdf_meta.h variable
# 2. conditional variable that is yes or no.
# 3. default condition
#
# example: AX_SET_META([NC_HAS_NC2],[$nc_build_v2],[]) # Because it checks for no.
#          AX_SET_META([NC_HAS_HDF4],[$enable_hdf4],[yes])
AC_DEFUN([AX_SET_META],[
  if [ test "x$2" = x$3 ]; then
     AC_SUBST([$1]) $1=1
  else
     AC_SUBST([$1]) $1=0
  fi
])

#####
# Define values used in include/pio_meta.h
#####
AX_SET_META([PIO_HAS_SZIP_WRITE],[$have_szip_write],[yes])
AX_SET_META([PIO_HAS_PNETCDF],[$enable_pnetcdf],[yes])
AX_SET_META([PIO_HAS_PAR_FILTERS], [$have_par_filters],[yes])
AX_SET_META([PIO_HAS_NETCDF4], [$have_netcdf4],[yes])
AX_SET_META([PIO_HAS_NETCDF4_PAR], [$have_netcdf_par],[yes])
AX_SET_META([PIO_HAS_NETCDF_INTEGRATION], [$enable_netcdf_integration],[yes])

# Create output variables from various shell variables, for use in
# generating libpio.settings.
AC_SUBST([enable_shared])
AC_SUBST([enable_static])
AC_SUBST([CFLAGS])
AC_SUBST([CPPFLAGS])
AC_SUBST([FFLAGS])
AC_SUBST([FCFLAGS])
AC_SUBST([LDFLAGS])
AC_SUBST([FPPFLAGS]) # ignored by autotools
AC_SUBST(HAS_PNETCDF,[$enable_pnetcdf])
AC_SUBST(HAS_LOGGING, [$enable_logging])
AC_SUBST(HAS_SZIP_WRITE, [$have_szip_write])
AC_SUBST([HAS_PAR_FILTERS], [$have_par_filters])
AC_SUBST([HAS_NETCDF4], [$have_netcdf4])
AC_SUBST([HAS_NETCDF4_PAR], [$have_netcdf_par])
AC_SUBST([HAS_NETCDF_INTEGRATION], [$enable_netcdf_integration])
AC_SUBST([HAS_PIO_FORTRAN], [$enable_fortran])

# Create the build summary file. 
AC_CONFIG_FILES([libpio.settings
                 src/clib/pio_meta.h
		 ])
AC_CONFIG_LINKS([tests/unit/input.nl:tests/unit/input.nl])

# Create the config.h file.
AC_CONFIG_HEADERS([config.h])

# Create the makefiles.
AC_OUTPUT(Makefile
          src/Makefile
          src/clib/Makefile
          src/ncint/Makefile
          src/flib/Makefile
          src/gptl/Makefile
          tests/Makefile
          tests/cunit/Makefile
          tests/ncint/Makefile
          tests/fncint/Makefile
          tests/unit/Makefile
          tests/general/Makefile
          tests/general/util/Makefile
          tests/performance/Makefile
          doc/Makefile
          doc/source/Makefile
          doc/images/Makefile
          examples/Makefile
          examples/c/Makefile
          examples/f03/Makefile
          cmake/Makefile
          scripts/Makefile)

# Show the build summary.
cat libpio.settings


