#AX_FC_VERSION_OUTPUT([FLAG = $ac_cv_prog_fc_version])
# -------------------------------------------------
# Link a trivial Fortran program, compiling with a version output FLAG
# (which default value, $ac_cv_prog_fc_version, is computed by
# AX_FC_VERSION), and return the output in $ac_fc_version_output.
AC_DEFUN([AX_FC_VERSION_OUTPUT],
[AC_REQUIRE([AC_PROG_FC])dnl
AC_LANG_PUSH(Fortran)dnl

AC_LANG_CONFTEST([AC_LANG_PROGRAM([])])

# Compile and link our simple test program by passing a flag (argument
# 1 to this macro) to the Fortran 90 compiler in order to get "version" output
ac_save_FCFLAGS=$FCFLAGS
FCFLAGS="$FCFLAGS m4_default([$1], [$ac_cv_prog_fc_version])"
(eval echo $as_me:__oline__: \"$ac_link\") >&AS_MESSAGE_LOG_FD
ac_fc_version_output=`eval $ac_link AS_MESSAGE_LOG_FD>&1 2>&1 | grep -v 'Driving:'`
echo "$ac_fc_version_output" >&AS_MESSAGE_LOG_FD
FCFLAGS=$ac_save_FCFLAGS

rm -f conftest.*
AC_LANG_POP(Fortran)dnl

])# AX_FC_VERSION_OUTPUT

# AX_FC_VERSION
# --------------
#
AC_DEFUN([AX_FC_VERSION],
[AC_CACHE_CHECK([how to get the version output from $FC],
                [ac_cv_prog_fc_version],
[AC_LANG_ASSERT(Fortran)
AC_COMPILE_IFELSE([AC_LANG_PROGRAM()],
[ac_cv_prog_fc_version=
# Try some options frequently used verbose output
for ac_version in -V -version --version +version -qversion; do
  AX_FC_VERSION_OUTPUT($ac_version)
  # look for "copyright" constructs in the output
  for ac_arg in $ac_fc_version_output; do
     case $ac_arg in
        COPYRIGHT | copyright | Copyright | '(c)' | '(C)' | Compiler | Compilers | Version | Version:)
          ac_cv_prog_fc_version=$ac_version
          break 2 ;;
     esac
  done
done
if test -z "$ac_cv_prog_fc_version"; then
   AC_MSG_WARN([cannot determine how to obtain version information from $FC])
fi],
                  [AC_MSG_WARN([compilation failed])])
])])# AX_FC_VERSION
