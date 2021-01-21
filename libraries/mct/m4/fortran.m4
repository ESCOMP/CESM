# This file is part of Autoconf.                       -*- Autoconf -*-
# Fortran languages support.
# Copyright (C) 2001, 2003-2011 Free Software Foundation, Inc.

# This file is part of Autoconf.  This program is free
# software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Under Section 7 of GPL version 3, you are granted additional
# permissions described in the Autoconf Configure Script Exception,
# version 3.0, as published by the Free Software Foundation.
#
# You should have received a copy of the GNU General Public License
# and a copy of the Autoconf Configure Script Exception along with
# this program; see the files COPYINGv3 and COPYING.EXCEPTION
# respectively.  If not, see <http://www.gnu.org/licenses/>.

# Written by David MacKenzie, with help from
# Franc,ois Pinard, Karl Berry, Richard Pixley, Ian Lance Taylor,
# Roland McGrath, Noah Friedman, david d zuhn, and many others.


# Table of Contents:
#
# Preamble
#
# 0. Utility macros
#
# 1. Language selection
#    and routines to produce programs in a given language.
#
# 2. Producing programs in a given language.
#
# 3. Looking for a compiler
#    And possibly the associated preprocessor.
#
# 4. Compilers' characteristics.

# AC_FC_PP_SRCEXT(EXT, [ACTION-IF-SUCCESS], [ACTION-IF-FAILURE])
# --------------------------------------------------------------
# Like AC_FC_SRCEXT, set the source-code extension used in Fortran (FC) tests
# to EXT (which defaults to f).  Also, look for any necessary additional
# FCFLAGS needed to allow this extension for preprocessed Fortran, and store
# them in the output variable FCFLAGS_<EXT> (e.g. FCFLAGS_f90 for EXT=f90).
# If successful, call ACTION-IF-SUCCESS.  If unable to compile preprocessed
# source code with EXT, call ACTION-IF-FAILURE, which defaults to failing with
# an error message.
#
# Some compilers allow preprocessing with either a Fortran preprocessor or
# with the C preprocessor (cpp).  Prefer the Fortran preprocessor, to deal
# correctly with continuation lines, `//' (not a comment), and preserve white
# space (for fixed form).
#
# (The flags for the current source-code extension, if any, are stored in
# $ac_fcflags_srcext and used automatically in subsequent autoconf tests.)
#
# For ordinary extensions like f90, etcetera, the modified FCFLAGS
# are needed for IBM's xlf*.  Also, for Intel's ifort compiler, the
# $FCFLAGS_<EXT> variable *must* go immediately before the source file on the
# command line, unlike other $FCFLAGS.  Ugh.
#
# Known extensions that enable preprocessing by default, and flags to force it:
# GNU: .F .F90 .F95 .F03 .F08, -cpp for most others,
#      -x f77-cpp-input for .f77 .F77; -x f95-cpp-input for gfortran < 4.4
# SGI: .F .F90, -ftpp or -cpp for .f .f90, -E write preproc to stdout
#      -macro_expand enable macro expansion everywhere (with -ftpp)
#      -P preproc only, save in .i, no #line's
# SUN: .F .F95, -fpp for others; -xpp={fpp,cpp} for preprocessor selection
#      -F preprocess only (save in lowercase extension)
# IBM: .F .F77 .F90 .F95 .F03, -qsuffix=cpp=EXT for extension .EXT to invoke cpp
#      -WF,-qnofpp -WF,-qfpp=comment:linecont:nocomment:nolinecont
#      -WF,-qlanglvl=classic or not -qnoescape (trigraph problems)
#      -d no #line in output, -qnoobject for preprocessing only (output in .f)
#      -q{no,}ppsuborigarg substitute original macro args before expansion
# HP:  .F, +cpp={yes|no|default} use cpp, -cpp, +cpp_keep save in .i/.i90
# PGI: -Mpreprocess
# Absoft: .F .FOR .F90 .F95, -cpp for others
# Cray: .F .F90 .FTN, -e Z for others; -F enable macro expansion everywhere
# Intel: .F .F90, -fpp for others, but except for .f and .f90, -Tf may also be
#        needed right before the source file name
# PathScale: .F .F90 .F95, -ftpp or -cpp for .f .f90 .f95
#         -macro_expand for expansion everywhere, -P for no #line in output
# Lahey: .F .FOR .F90 .F95, -Cpp
# NAGWare: .F .F90 .F95, .ff .ff90 .ff95 (new), -fpp for others
# Compaq/Tru64: .F .F90, -cpp, -P keep .i file, -P keep .i file
# f2c: .F, -cpp
# g95: .F .FOR .F90 .F95 .F03, -cpp -no-cpp, -E for stdout
AC_DEFUN([AC_FC_PP_SRCEXT],
[AC_LANG_PUSH(Fortran)dnl
AC_CACHE_CHECK([for Fortran flag to compile preprocessed .$1 files],
		ac_cv_fc_pp_srcext_$1,
[ac_ext=$1
ac_fcflags_pp_srcext_save=$ac_fcflags_srcext
ac_fcflags_srcext=
ac_cv_fc_pp_srcext_$1=unknown
case $ac_ext in #(
  [[fF]]77) ac_try=f77-cpp-input;; #(
  *) ac_try=f95-cpp-input;;
esac
for ac_flag in none -ftpp -fpp -Tf "-fpp -Tf" -xpp=fpp -Mpreprocess "-e Z" \
               -cpp -xpp=cpp -qsuffix=cpp=$1 "-x $ac_try" +cpp -Cpp; do
  test "x$ac_flag" != xnone && ac_fcflags_srcext="$ac_flag"
  AC_COMPILE_IFELSE([AC_LANG_PROGRAM([], [[
#if 0
#include <ac_nonexistent.h>
      choke me
#endif]])],
    [AC_COMPILE_IFELSE([AC_LANG_PROGRAM([], [[
#if 1
#include <ac_nonexistent.h>
      choke me
#endif]])],
       [],
       [ac_cv_fc_pp_srcext_$1=$ac_flag; break])])
done
rm -f conftest.$ac_objext conftest.$1
ac_fcflags_srcext=$ac_fcflags_pp_srcext_save
])
if test "x$ac_cv_fc_pp_srcext_$1" = xunknown; then
  m4_default([$3],
             [AC_MSG_ERROR([Fortran could not compile preprocessed .$1 files])])
else
  ac_fc_srcext=$1
  if test "x$ac_cv_fc_pp_srcext_$1" = xnone; then
    ac_fcflags_srcext=""
    FCFLAGS_[]$1[]=""
  else
    ac_fcflags_srcext=$ac_cv_fc_pp_srcext_$1
    FCFLAGS_[]$1[]=$ac_cv_fc_pp_srcext_$1
  fi
  AC_SUBST(FCFLAGS_[]$1)
  $2
fi
AC_LANG_POP(Fortran)dnl
])# AC_FC_PP_SRCEXT

# AC_FC_PP_DEFINE([ACTION-IF-SUCCESS], [ACTION-IF-FAILURE = FAILURE])
# -------------------------------------------------------------------
# Find a flag to specify defines for preprocessed Fortran.  Not all
# Fortran compilers use -D.  Substitute FC_DEFINE with the result and
# call ACTION-IF-SUCCESS (defaults to nothing) if successful, and
# ACTION-IF-FAILURE (defaults to failing with an error message) if not.
#
# Known flags:
# IBM: -WF,-D
# Lahey/Fujitsu: -Wp,-D     older versions???
# f2c: -D or -Wc,-D
# others: -D
AC_DEFUN([AC_FC_PP_DEFINE],
[AC_LANG_PUSH([Fortran])dnl
ac_fc_pp_define_srcext_save=$ac_fc_srcext
AC_FC_PP_SRCEXT([F])
AC_CACHE_CHECK([how to define symbols for preprocessed Fortran],
  [ac_cv_fc_pp_define],
[ac_fc_pp_define_srcext_save=$ac_fc_srcext
ac_cv_fc_pp_define=unknown
ac_fc_pp_define_FCFLAGS_save=$FCFLAGS
for ac_flag in -D -WF,-D -Wp,-D -Wc,-D
do
  FCFLAGS="$ac_fc_pp_define_FCFLAGS_save ${ac_flag}FOOBAR ${ac_flag}ZORK=42"
  AC_COMPILE_IFELSE([AC_LANG_PROGRAM([], [[
#ifndef FOOBAR
      choke me
#endif
#if ZORK != 42
      choke me
#endif]])],
    [ac_cv_fc_pp_define=$ac_flag])
  test x"$ac_cv_fc_pp_define" != xunknown && break
done
FCFLAGS=$ac_fc_pp_define_FCFLAGS_save
])
ac_fc_srcext=$ac_fc_pp_define_srcext_save
if test "x$ac_cv_fc_pp_define" = xunknown; then
  FC_DEFINE=
  m4_default([$2],
	     [AC_MSG_ERROR([Fortran does not allow to define preprocessor symbols], 77)])
else
  FC_DEFINE=$ac_cv_fc_pp_define
  $1
fi
AC_SUBST([FC_DEFINE])dnl
AC_LANG_POP([Fortran])dnl
])


# AC_FC_FREEFORM([ACTION-IF-SUCCESS], [ACTION-IF-FAILURE = FAILURE])
# ------------------------------------------------------------------
# Look for a compiler flag to make the Fortran (FC) compiler accept
# free-format source code, and adds it to FCFLAGS.  Call
# ACTION-IF-SUCCESS (defaults to nothing) if successful (i.e. can
# compile code using new extension) and ACTION-IF-FAILURE (defaults to
# failing with an error message) if not.  (Defined via DEFUN_ONCE to
# prevent flag from being added to FCFLAGS multiple times.)
#
# The known flags are:
#        -ffree-form: GNU g77, gfortran, g95
#         -FR, -free: Intel compiler (icc, ecc, ifort)
#              -free: Compaq compiler (fort), Sun compiler (f95)
#             -qfree: IBM compiler (xlf)
# -Mfree, -Mfreeform: Portland Group compiler
#          -freeform: SGI compiler
#        -8, -f free: Absoft Fortran
#       +source=free: HP Fortran
#    (-)-nfix, -Free: Lahey/Fujitsu Fortran
#              -free: NAGWare
#         -f, -Wf,-f: f2c (but only a weak form of "free-form" and long lines)
# We try to test the "more popular" flags first, by some prejudiced
# notion of popularity.
AC_DEFUN_ONCE([AC_FC_FREEFORM],
[AC_LANG_PUSH([Fortran])dnl
AC_CACHE_CHECK([for Fortran flag needed to accept free-form source],
	       [ac_cv_fc_freeform],
[ac_cv_fc_freeform=unknown
ac_fc_freeform_FCFLAGS_save=$FCFLAGS
for ac_flag in none -ffree-form -FR -free -qfree -Mfree -Mfreeform \
	       -freeform "-f free" -8 +source=free -nfix --nfix -Free
do
  test "x$ac_flag" != xnone && FCFLAGS="$ac_fc_freeform_FCFLAGS_save $ac_flag"
dnl Use @&t@ below to ensure that editors don't turn 8+ spaces into tab.
  AC_COMPILE_IFELSE([[
  program freeform
       ! FIXME: how to best confuse non-freeform compilers?
       print *, 'Hello ', &
     @&t@     'world.'
       end]],
		    [ac_cv_fc_freeform=$ac_flag; break])
done
rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
FCFLAGS=$ac_fc_freeform_FCFLAGS_save
])
if test "x$ac_cv_fc_freeform" = xunknown; then
  m4_default([$2],
	     [AC_MSG_ERROR([Fortran does not accept free-form source], 77)])
else
  if test "x$ac_cv_fc_freeform" != xnone; then
    FCFLAGS="$FCFLAGS $ac_cv_fc_freeform"
  fi
  $1
fi
AC_LANG_POP([Fortran])dnl
])# AC_FC_FREEFORM


# AC_FC_FIXEDFORM([ACTION-IF-SUCCESS], [ACTION-IF-FAILURE = FAILURE])
# ------------------------------------------------------------------
# Look for a compiler flag to make the Fortran (FC) compiler accept
# fixed-format source code, and adds it to FCFLAGS.  Call
# ACTION-IF-SUCCESS (defaults to nothing) if successful (i.e. can
# compile code using new extension) and ACTION-IF-FAILURE (defaults to
# failing with an error message) if not.  (Defined via DEFUN_ONCE to
# prevent flag from being added to FCFLAGS multiple times.)
#
# The known flags are:
#       -ffixed-form: GNU g77, gfortran, g95
#             -fixed: Intel compiler (ifort), Sun compiler (f95)
#            -qfixed: IBM compiler (xlf*)
#            -Mfixed: Portland Group compiler
#         -fixedform: SGI compiler
#           -f fixed: Absoft Fortran
#      +source=fixed: HP Fortran
#    (-)-fix, -Fixed: Lahey/Fujitsu Fortran
#             -fixed: NAGWare
# Since compilers may accept fixed form based on file name extension,
# but users may want to use it with others as well, call AC_FC_SRCEXT
# with the respective source extension before calling this macro.
AC_DEFUN_ONCE([AC_FC_FIXEDFORM],
[AC_LANG_PUSH([Fortran])dnl
AC_CACHE_CHECK([for Fortran flag needed to accept fixed-form source],
	       [ac_cv_fc_fixedform],
[ac_cv_fc_fixedform=unknown
ac_fc_fixedform_FCFLAGS_save=$FCFLAGS
for ac_flag in none -ffixed-form -fixed -qfixed -Mfixed -fixedform "-f fixed" \
	       +source=fixed -fix --fix -Fixed
do
  test "x$ac_flag" != xnone && FCFLAGS="$ac_fc_fixedform_FCFLAGS_save $ac_flag"
  AC_COMPILE_IFELSE([[
C     This comment should confuse free-form compilers.
      program main
      end]],
		    [ac_cv_fc_fixedform=$ac_flag; break])
done
rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
FCFLAGS=$ac_fc_fixedform_FCFLAGS_save
])
if test "x$ac_cv_fc_fixedform" = xunknown; then
  m4_default([$2],
	     [AC_MSG_ERROR([Fortran does not accept fixed-form source], 77)])
else
  if test "x$ac_cv_fc_fixedform" != xnone; then
    FCFLAGS="$FCFLAGS $ac_cv_fc_fixedform"
  fi
  $1
fi
AC_LANG_POP([Fortran])dnl
])# AC_FC_FIXEDFORM


# AC_FC_LINE_LENGTH([LENGTH], [ACTION-IF-SUCCESS],
#		    [ACTION-IF-FAILURE = FAILURE])
# ------------------------------------------------
# Look for a compiler flag to make the Fortran (FC) compiler accept long lines
# in the current (free- or fixed-format) source code, and adds it to FCFLAGS.
# The optional LENGTH may be 80, 132 (default), or `unlimited' for longer
# lines.  Note that line lengths above 254 columns are not portable, and some
# compilers (hello ifort) do not accept more than 132 columns at least for
# fixed format.  Call ACTION-IF-SUCCESS (defaults to nothing) if successful
# (i.e. can compile code using new extension) and ACTION-IF-FAILURE (defaults
# to failing with an error message) if not.  (Defined via DEFUN_ONCE to
# prevent flag from being added to FCFLAGS multiple times.)
# You should call AC_FC_FREEFORM or AC_FC_FIXEDFORM to set the desired format
# prior to using this macro.
#
# The known flags are:
# -f{free,fixed}-line-length-N with N 72, 80, 132, or 0 or none for none.
# -ffree-line-length-none: GNU gfortran
# -ffree-line-length-huge: g95 (also -ffixed-line-length-N as above)
#       -qfixed=132 80 72: IBM compiler (xlf)
#                -Mextend: Cray
#            -132 -80 -72: Intel compiler (ifort)
#                          Needs to come before -extend_source because ifort
#                          accepts that as well with an optional parameter and
#                          doesn't fail but only warns about unknown arguments.
#          -extend_source: SGI compiler
#  -W, -WNN (132, 80, 72): Absoft Fortran
#     +es, +extend_source: HP Fortran (254 in either form, default is 72 fixed,
#			   132 free)
#            -w, (-)-wide: Lahey/Fujitsu Fortran (255 cols in fixed form)
#                      -e: Sun Fortran compiler (132 characters)
#                    -132: NAGWare
#         -72, -f, -Wf,-f: f2c (a weak form of "free-form" and long lines).
#                  /XLine: Open Watcom
AC_DEFUN_ONCE([AC_FC_LINE_LENGTH],
[AC_LANG_PUSH([Fortran])dnl
m4_case(m4_default([$1], [132]),
  [unlimited], [ac_fc_line_len_string=unlimited
	               ac_fc_line_len=0
                       ac_fc_line_length_test='
      subroutine longer_than_132(arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,'\
'arg9,arg10,arg11,arg12,arg13,arg14,arg15,arg16,arg17,arg18,arg19)'],
  [132],            [ac_fc_line_len=132
		       ac_fc_line_length_test='
      subroutine longer_than_80(arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,'\
'arg10)'],
  [80],             [ac_fc_line_len=80
		       ac_fc_line_length_test='
      subroutine longer_than_72(arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9)'],
  [m4_warning([Invalid length argument `$1'])])
: ${ac_fc_line_len_string=$ac_fc_line_len}
AC_CACHE_CHECK(
[for Fortran flag needed to accept $ac_fc_line_len_string column source lines],
	       [ac_cv_fc_line_length],
[ac_cv_fc_line_length=unknown
ac_fc_line_length_FCFLAGS_save=$FCFLAGS
for ac_flag in none \
	       -ffree-line-length-none -ffixed-line-length-none \
	       -ffree-line-length-huge \
	       -ffree-line-length-$ac_fc_line_len \
	       -ffixed-line-length-$ac_fc_line_len \
	       -qfixed=$ac_fc_line_len -Mextend \
	       -$ac_fc_line_len -extend_source \
	       -W$ac_fc_line_len -W +extend_source +es -wide --wide -w -e \
               -f -Wf,-f -xline
do
  test "x$ac_flag" != xnone && FCFLAGS="$ac_fc_line_length_FCFLAGS_save $ac_flag"
  AC_COMPILE_IFELSE([[$ac_fc_line_length_test
      end subroutine]],
		    [ac_cv_fc_line_length=$ac_flag; break])
done
rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
FCFLAGS=$ac_fc_line_length_FCFLAGS_save
])
if test "x$ac_cv_fc_line_length" = xunknown; then
  m4_default([$3],
	     [AC_MSG_ERROR([Fortran does not accept long source lines], 77)])
else
  if test "x$ac_cv_fc_line_length" != xnone; then
    FCFLAGS="$FCFLAGS $ac_cv_fc_line_length"
  fi
  $2
fi
AC_LANG_POP([Fortran])dnl
])# AC_FC_LINE_LENGTH


# AC_FC_CHECK_BOUNDS([ACTION-IF-SUCCESS], [ACTION-IF-FAILURE = FAILURE])
# ----------------------------------------------------------------------
# Look for a compiler flag to turn on array bounds checking for the
# Fortran (FC) compiler, and adds it to FCFLAGS.  Call
# ACTION-IF-SUCCESS (defaults to nothing) if successful (i.e. can
# compile code using new extension) and ACTION-IF-FAILURE (defaults to
# failing with an error message) if not.  (Defined via DEFUN_ONCE to
# prevent flag from being added to FCFLAGS multiple times.)
#
# The known flags are:
# -fcheck=all, -fbounds-check: gfortran
#     -fbounds-check: g77, g95
# -CB, -check bounds: Intel compiler (icc, ecc, ifort)
#                 -C: Sun/Oracle compiler (f95)
#        -C, -qcheck: IBM compiler (xlf)
#           -Mbounds: Portland Group compiler
#       -C ,-Mbounds: Cray
#  -C, -check_bounds: SGI compiler
# -check_bounds, +check=all: HP Fortran
#        -C, -Rb -Rc: Absoft (-Rb: array boundaries, -Rc: array conformance)
# --chk e,s -chk (e,s): Lahey
#          -C -C=all: NAGWare
# -C, -ffortran-bounds-check: PathScale pathf90
#                 -C: f2c
#            -BOunds: Open Watcom
AC_DEFUN_ONCE([AC_FC_CHECK_BOUNDS],
[AC_LANG_PUSH([Fortran])dnl
AC_CACHE_CHECK([for Fortran flag to enable array-bounds checking],
               [ac_cv_fc_check_bounds],
[ac_cv_fc_check_bounds=unknown
ac_fc_check_bounds_FCFLAGS_save=$FCFLAGS
for ac_flag in -fcheck=bounds -fbounds-check -check_bounds -Mbounds -qcheck \
               '-check bounds' +check=all --check '-Rb -Rc' -CB -C=all -C \
               -ffortran-bounds-check "--chk e,s" "-chk e -chk s" -bounds
do
  FCFLAGS="$ac_fc_check_bounds_FCFLAGS_save $ac_flag"
  # We should be able to link a correct program.
  AC_LINK_IFELSE([AC_LANG_PROGRAM([], [])],
    [AC_LINK_IFELSE([[
      subroutine sub(a)
      integer a(:)
      a(8) = 0
      end subroutine

      program main
      integer a(1:7)
      interface
         subroutine sub(a)
         integer a(:)
         end subroutine
      end interface

      call sub(a)
      end program]],
       [# If we can run the program, require failure at run time.
	# In cross-compiling mode, we rely on the compiler not accepting
	# unknown options.
	AS_IF([test "$cross_compiling" = yes],
	  [ac_cv_fc_check_bounds=$ac_flag; break],
	  [AS_IF([_AC_DO_TOKENS(./conftest$ac_exeext)],
	     [],
	     [ac_cv_fc_check_bounds=$ac_flag; break])])])])
done
rm -f conftest$ac_exeext conftest.err conftest.$ac_objext conftest.$ac_ext
FCFLAGS=$ac_fc_check_bounds_FCFLAGS_save
])
if test "x$ac_cv_fc_check_bounds" = xunknown; then
  m4_default([$2],
             [AC_MSG_ERROR([no Fortran flag for bounds checking found], 77)])
else
  if test "x$ac_cv_fc_check_bounds" != xnone; then
    FCFLAGS="$FCFLAGS $ac_cv_fc_check_bounds"
  fi
  $1
fi
AC_LANG_POP([Fortran])dnl
])# AC_FC_CHECK_BOUNDS


# _AC_FC_IMPLICIT_NONE([ACTION-IF-SUCCESS], [ACTION-IF-FAILURE = FAILURE])
# ------------------------------------------------------------------------
# Look for a flag to disallow implicit declarations, and add it to FCFLAGS.
# Call ACTION-IF-SUCCESS (defaults to nothing) if successful and
# ACTION-IF-FAILURE (defaults to failing with an error message) if not.
#
# Known flags:
# GNU gfortran, g95: -fimplicit-none, g77: -Wimplicit
# Intel: -u, -implicitnone; might also need '-warn errors' to turn into error.
# Sun/Oracle: -u
# HP: +implicit_none
# IBM: -u, -qundef
# SGI: -u
# Compaq: -u, -warn declarations
# NAGWare: -u
# Lahey: -in, --in, -AT
# Cray: -Mdclchk -e I
# PGI: -Mcdlchk
# f2c: -u
AC_DEFUN([_AC_FC_IMPLICIT_NONE],
[_AC_FORTRAN_ASSERT()dnl
AC_CACHE_CHECK([for flag to disallow _AC_LANG implicit declarations],
               [ac_cv_[]_AC_LANG_ABBREV[]_implicit_none],
[ac_cv_[]_AC_LANG_ABBREV[]_implicit_none=unknown
ac_fc_implicit_none_[]_AC_LANG_PREFIX[]FLAGS_save=$[]_AC_LANG_PREFIX[]FLAGS
for ac_flag in none -fimplicit-none -u -Wimplicit -implicitnone +implicit_none \
               -qundef "-warn declarations" -in --in -AT "-e I" -Mdclchk \
               "-u -warn errors"
do
  if test "x$ac_flag" != xnone; then
    _AC_LANG_PREFIX[]FLAGS="$ac_fc_implicit_none_[]_AC_LANG_PREFIX[]FLAGS_save $ac_flag"
  fi
  AC_COMPILE_IFELSE([AC_LANG_PROGRAM([], [])],
    [AC_COMPILE_IFELSE([AC_LANG_PROGRAM([], [[
      i = 0
      print *, i]])],
       [],
       [ac_cv_[]_AC_LANG_ABBREV[]_implicit_none=$ac_flag; break])])
done
rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
_AC_LANG_PREFIX[]FLAGS=$ac_fc_implicit_none_[]_AC_LANG_PREFIX[]FLAGS_save
])
if test "x$ac_cv_[]_AC_LANG_ABBREV[]_implicit_none" = xunknown; then
  m4_default([$3],
    [AC_MSG_ERROR([no Fortran flag to disallow implicit declarations found], 77)])
else
  if test "x$ac_cv_[]_AC_LANG_ABBREV[]_implicit_none" != xnone; then
    _AC_LANG_PREFIX[]FLAGS="$_AC_LANG_PREFIX[]FLAGS $ac_cv_[]_AC_LANG_ABBREV[]_implicit_none"
  fi
  $2
fi
])# _AC_FC_IMPLICIT_NONE


# AC_F77_IMPLICIT_NONE([ACTION-IF-SUCCESS], [ACTION-IF-FAILURE = FAILURE])
# ------------------------------------------------------------------------
AC_DEFUN([AC_F77_IMPLICIT_NONE],
[AC_LANG_PUSH([Fortran 77])dnl
_AC_FC_IMPLICIT_NONE($@)
AC_LANG_POP([Fortran 77])dnl
])# AC_F77_IMPLICIT_NONE


# AC_FC_IMPLICIT_NONE([ACTION-IF-SUCCESS], [ACTION-IF-FAILURE = FAILURE])
# -----------------------------------------------------------------------
AC_DEFUN([AC_FC_IMPLICIT_NONE],
[AC_LANG_PUSH([Fortran])dnl
_AC_FC_IMPLICIT_NONE($@)
AC_LANG_POP([Fortran])dnl
])# AC_FC_IMPLICIT_NONE


# AC_FC_MODULE_EXTENSION
# ----------------------
# Find the Fortran 90 module file extension.  The module extension is stored
# in the variable FC_MODEXT and empty if it cannot be determined.  The result
# or "unknown" is cached in the cache variable ac_cv_fc_module_ext.
AC_DEFUN([AC_FC_MODULE_EXTENSION],
[AC_CACHE_CHECK([Fortran 90 module extension], [ac_cv_fc_module_ext],
[AC_LANG_PUSH(Fortran)
mkdir conftest.dir
cd conftest.dir
ac_cv_fc_module_ext=unknown
AC_COMPILE_IFELSE([[
      module conftest_module
      contains
      subroutine conftest_routine
      write(*,'(a)') 'gotcha!'
      end subroutine
      end module]],
  [ac_cv_fc_module_ext=`ls | sed -n 's,conftest_module\.,,p'`
   if test x$ac_cv_fc_module_ext = x; then
dnl Some F90 compilers use upper case characters for the module file name.
     ac_cv_fc_module_ext=`ls | sed -n 's,CONFTEST_MODULE\.,,p'`
   fi])
cd ..
rm -rf conftest.dir
AC_LANG_POP(Fortran)
])
FC_MODEXT=$ac_cv_fc_module_ext
if test "$FC_MODEXT" = unknown; then
  FC_MODEXT=
fi
AC_SUBST([FC_MODEXT])dnl
])


# AC_FC_MODULE_FLAG([ACTION-IF-SUCCESS], [ACTION-IF-FAILURE = FAILURE])
# ---------------------------------------------------------------------
# Find a flag to include Fortran 90 modules from another directory.
# If successful, run ACTION-IF-SUCCESS (defaults to nothing), otherwise
# run ACTION-IF-FAILURE (defaults to failing with an error message).
# The module flag is cached in the ac_cv_fc_module_flag variable.
# It may contain significant trailing whitespace.
#
# Known flags:
# gfortran: -Idir, -I dir (-M dir, -Mdir (deprecated), -Jdir for writing)
# g95: -I dir (-fmod=dir for writing)
# SUN: -Mdir, -M dir (-moddir=dir for writing;
#                     -Idir for includes is also searched)
# HP: -Idir, -I dir (+moddir=dir for writing)
# IBM: -Idir (-qmoddir=dir for writing)
# Intel: -Idir -I dir (-mod dir for writing)
# Absoft: -pdir
# Lahey: -Idir (-Mdir or -mod dir for writing)
# Cray: -module dir, -p dir (-J dir for writing)
#       -e m is needed to enable writing .mod files at all
# Compaq: -Idir
# NAGWare: -I dir
# PathScale: -I dir  (but -module dir is looked at first)
# Portland: -module dir (first -module also names dir for writing)
# Fujitsu: -Am -Idir (-Mdir for writing is searched first, then '.', then -I)
#                    (-Am indicates how module information is saved)
AC_DEFUN([AC_FC_MODULE_FLAG],[
AC_CACHE_CHECK([Fortran 90 module inclusion flag], [ac_cv_fc_module_flag],
[AC_LANG_PUSH([Fortran])
ac_cv_fc_module_flag=unknown
mkdir conftest.dir
cd conftest.dir
AC_COMPILE_IFELSE([[
      module conftest_module
      contains
      subroutine conftest_routine
      write(*,'(a)') 'gotcha!'
      end subroutine
      end module]],
  # For Lahey -M will also write module and object files to that directory
  # make it read-only so that lahey fails over to -I
  [chmod -w .
   cd ..
   ac_fc_module_flag_FCFLAGS_save=$FCFLAGS
   # Flag ordering is significant for gfortran and Sun.
   for ac_flag in -M -I '-I ' '-M ' -p '-mod ' '-module ' '-Am -I'; do
     # Add the flag twice to prevent matching an output flag.
     FCFLAGS="$ac_fc_module_flag_FCFLAGS_save ${ac_flag}conftest.dir ${ac_flag}conftest.dir"
     AC_COMPILE_IFELSE([[
      module conftest_main
      use conftest_module
      contains
      subroutine conftest
      call conftest_routine
      end subroutine
      end module]],
       [ac_cv_fc_module_flag="$ac_flag"])
     if test "$ac_cv_fc_module_flag" != unknown; then
       break
     fi
   done
   FCFLAGS=$ac_fc_module_flag_FCFLAGS_save
])
chmod +w conftest.dir
rm -rf conftest.dir
AC_LANG_POP([Fortran])
])
if test "$ac_cv_fc_module_flag" != unknown; then
  FC_MODINC=$ac_cv_fc_module_flag
  $1
else
  FC_MODINC=
  m4_default([$2],
    [AC_MSG_ERROR([unable to find compiler flag for module search path])])
fi
AC_SUBST([FC_MODINC])
# Ensure trailing whitespace is preserved in a Makefile.
AC_SUBST([ac_empty], [""])
AC_CONFIG_COMMANDS_PRE([case $FC_MODINC in #(
  *\ ) FC_MODINC=$FC_MODINC'${ac_empty}' ;;
esac])dnl
])


# AC_FC_MODULE_OUTPUT_FLAG([ACTION-IF-SUCCESS], [ACTION-IF-FAILURE = FAILURE])
# ----------------------------------------------------------------------------
# Find a flag to write Fortran 90 module information to another directory.
# If successful, run ACTION-IF-SUCCESS (defaults to nothing), otherwise
# run ACTION-IF-FAILURE (defaults to failing with an error message).
# The module flag is cached in the ac_cv_fc_module_output_flag variable.
# It may contain significant trailing whitespace.
#
# For known flags, see the documentation of AC_FC_MODULE_FLAG above.
AC_DEFUN([AC_FC_MODULE_OUTPUT_FLAG],[
AC_CACHE_CHECK([Fortran 90 module output flag], [ac_cv_fc_module_output_flag],
[AC_LANG_PUSH([Fortran])
mkdir conftest.dir conftest.dir/sub
cd conftest.dir
ac_cv_fc_module_output_flag=unknown
ac_fc_module_output_flag_FCFLAGS_save=$FCFLAGS
# Flag ordering is significant: put flags late which some compilers use
# for the search path.
for ac_flag in -J '-J ' -fmod= -moddir= +moddir= -qmoddir= '-mod ' \
	      '-module ' -M '-Am -M' '-e m -J '; do
  FCFLAGS="$ac_fc_module_output_flag_FCFLAGS_save ${ac_flag}sub"
  AC_COMPILE_IFELSE([[
      module conftest_module
      contains
      subroutine conftest_routine
      write(*,'(a)') 'gotcha!'
      end subroutine
      end module]],
    [cd sub
     AC_COMPILE_IFELSE([[
      program main
      use conftest_module
      call conftest_routine
      end program]],
       [ac_cv_fc_module_output_flag="$ac_flag"])
     cd ..
     if test "$ac_cv_fc_module_output_flag" != unknown; then
       break
     fi])
done
FCFLAGS=$ac_fc_module_output_flag_FCFLAGS_save
cd ..
rm -rf conftest.dir
AC_LANG_POP([Fortran])
])
if test "$ac_cv_fc_module_output_flag" != unknown; then
  FC_MODOUT=$ac_cv_fc_module_output_flag
  $1
else
  FC_MODOUT=
  m4_default([$2],
    [AC_MSG_ERROR([unable to find compiler flag to write module information to])])
fi
AC_SUBST([FC_MODOUT])
# Ensure trailing whitespace is preserved in a Makefile.
AC_SUBST([ac_empty], [""])
AC_CONFIG_COMMANDS_PRE([case $FC_MODOUT in #(
  *\ ) FC_MODOUT=$FC_MODOUT'${ac_empty}' ;;
esac])dnl
])

# _AC_FC_LIBRARY_LDFLAGS
# ----------------------
#
# Determine the linker flags (e.g. "-L" and "-l") for the Fortran
# intrinsic and runtime libraries that are required to successfully
# link a Fortran program or shared library.  The output variable
# FLIBS/FCLIBS is set to these flags.
#
# This macro is intended to be used in those situations when it is
# necessary to mix, e.g. C++ and Fortran, source code into a single
# program or shared library.
#
# For example, if object files from a C++ and Fortran compiler must
# be linked together, then the C++ compiler/linker must be used for
# linking (since special C++-ish things need to happen at link time
# like calling global constructors, instantiating templates, enabling
# exception support, etc.).
#
# However, the Fortran intrinsic and runtime libraries must be
# linked in as well, but the C++ compiler/linker doesn't know how to
# add these Fortran libraries.  Hence, the macro
# "AC_F77_LIBRARY_LDFLAGS" was created to determine these Fortran
# libraries.
#
# This macro was packaged in its current form by Matthew D. Langston.
# However, nearly all of this macro came from the "OCTAVE_FLIBS" macro
# in "octave-2.0.13/aclocal.m4", and full credit should go to John
# W. Eaton for writing this extremely useful macro.  Thank you John.
AC_DEFUN([_AC_FC_LIBRARY_LDFLAGS],
[_AC_FORTRAN_ASSERT()dnl
_AC_PROG_FC_V
AC_CACHE_CHECK([for _AC_LANG libraries of $[]_AC_FC[]], ac_cv_[]_AC_LANG_ABBREV[]_libs,
[if test "x$[]_AC_LANG_PREFIX[]LIBS" != "x"; then
  ac_cv_[]_AC_LANG_ABBREV[]_libs="$[]_AC_LANG_PREFIX[]LIBS" # Let the user override the test.
else

_AC_PROG_FC_V_OUTPUT

ac_cv_[]_AC_LANG_ABBREV[]_libs=

# Save positional arguments (if any)
ac_save_positional="$[@]"

set X $ac_[]_AC_LANG_ABBREV[]_v_output
while test $[@%:@] != 1; do
  shift
  ac_arg=$[1]
  case $ac_arg in
	[[\\/]]*.a | ?:[[\\/]]*.a)
	  _AC_LIST_MEMBER_IF($ac_arg, $ac_cv_[]_AC_LANG_ABBREV[]_libs, ,
	      ac_cv_[]_AC_LANG_ABBREV[]_libs="$ac_cv_[]_AC_LANG_ABBREV[]_libs $ac_arg")
	  ;;
	-bI:*)
	  _AC_LIST_MEMBER_IF($ac_arg, $ac_cv_[]_AC_LANG_ABBREV[]_libs, ,
	     [_AC_LINKER_OPTION([$ac_arg], ac_cv_[]_AC_LANG_ABBREV[]_libs)])
	  ;;
	  # Ignore these flags.
	-lang* | -lcrt*.o | -lc | -lgcc* | -lSystem | -libmil | -little \
	  |-LANG:=* | -LIST:* | -LNO:* | -link | -list | -lnuma )
	  ;;
	-lkernel32)
	  test x"$CYGWIN" != xyes && ac_cv_[]_AC_LANG_ABBREV[]_libs="$ac_cv_[]_AC_LANG_ABBREV[]_libs $ac_arg"
	  ;;
	-[[LRuYz]])
	  # These flags, when seen by themselves, take an argument.
	  # We remove the space between option and argument and re-iterate
	  # unless we find an empty arg or a new option (starting with -)
	  case $[2] in
	     "" | -*);;
	     *)
		ac_arg="$ac_arg$[2]"
		shift; shift
		set X $ac_arg "$[@]"
		;;
	  esac
	  ;;
	-YP,*)
	  for ac_j in `AS_ECHO(["$ac_arg"]) | sed -e 's/-YP,/-L/;s/:/ -L/g'`; do
	    _AC_LIST_MEMBER_IF($ac_j, $ac_cv_[]_AC_LANG_ABBREV[]_libs, ,
			       [ac_arg="$ac_arg $ac_j"
			       ac_cv_[]_AC_LANG_ABBREV[]_libs="$ac_cv_[]_AC_LANG_ABBREV[]_libs $ac_j"])
	  done
	  ;;
	-[[lLR]]*)
	  _AC_LIST_MEMBER_IF($ac_arg, $ac_cv_[]_AC_LANG_ABBREV[]_libs, ,
			     ac_cv_[]_AC_LANG_ABBREV[]_libs="$ac_cv_[]_AC_LANG_ABBREV[]_libs $ac_arg")
	  ;;
	-zallextract*| -zdefaultextract)
	  ac_cv_[]_AC_LANG_ABBREV[]_libs="$ac_cv_[]_AC_LANG_ABBREV[]_libs $ac_arg"
	  ;;
	  # Ignore everything else.
  esac
done
# restore positional arguments
set X $ac_save_positional; shift

# We only consider "LD_RUN_PATH" on Solaris systems.  If this is seen,
# then we insist that the "run path" must be an absolute path (i.e. it
# must begin with a "/").
case `(uname -sr) 2>/dev/null` in
   "SunOS 5"*)
      ac_ld_run_path=`AS_ECHO(["$ac_[]_AC_LANG_ABBREV[]_v_output"]) |
			sed -n 's,^.*LD_RUN_PATH *= *\(/[[^ ]]*\).*$,-R\1,p'`
      test "x$ac_ld_run_path" != x &&
	_AC_LINKER_OPTION([$ac_ld_run_path], ac_cv_[]_AC_LANG_ABBREV[]_libs)
      ;;
esac
fi # test "x$[]_AC_LANG_PREFIX[]LIBS" = "x"
])
[]_AC_LANG_PREFIX[]LIBS="$ac_cv_[]_AC_LANG_ABBREV[]_libs"
AC_SUBST([]_AC_LANG_PREFIX[]LIBS)
])# _AC_FC_LIBRARY_LDFLAGS


# AC_F77_LIBRARY_LDFLAGS
# ----------------------
AC_DEFUN([AC_F77_LIBRARY_LDFLAGS],
[AC_REQUIRE([AC_PROG_F77])dnl
AC_LANG_PUSH(Fortran 77)dnl
_AC_FC_LIBRARY_LDFLAGS
AC_LANG_POP(Fortran 77)dnl
])# AC_F77_LIBRARY_LDFLAGS


# AC_FC_LIBRARY_LDFLAGS
# ---------------------
AC_DEFUN([AC_FC_LIBRARY_LDFLAGS],
[AC_REQUIRE([AC_PROG_FC])dnl
AC_LANG_PUSH(Fortran)dnl
_AC_FC_LIBRARY_LDFLAGS
AC_LANG_POP(Fortran)dnl
])# AC_FC_LIBRARY_LDFLAGS
