## This is the automake file to build the PIO Fortran library.
# Ed Hartnett 3/19/19

# Turn off parallel builds in this directory.
.NOTPARALLEL:

# The library we are building.
lib_LTLIBRARIES = libpiof.la

# These linker flags specify libtool version info.
# See http://www.gnu.org/software/libtool/manual/libtool.html#Libtool-versioning
# for information regarding incrementing `-version-info`.
libpiof_la_LDFLAGS = -version-info 4:0:0

# The library soure files.
libpiof_la_LIBADD = libpio_nf.la libpio_kinds.la libpio_support.la	\
libpiodarray.la libpionfatt.la libpionfget.la libpionfput.la		\
libpiolib_mod.la

if NETCDF_INTEGRATION
libpiof_la_LIBADD += libncint_mod.la
endif
libpiof_la_LIBADD +=  libpio.la

libpiof_la_SOURCES = pio_types.F90

# Build these uninstalled convenience libraries.
noinst_LTLIBRARIES = libpio_kinds.la libpio_types.la		\
libpio_support.la libpio_nf.la libpiodarray.la libpionfatt.la	\
libpionfget.la libpionfput.la libpiolib_mod.la libpio.la
if NETCDF_INTEGRATION
noinst_LTLIBRARIES += libncint_mod.la
endif

# The convenience libraries depends on their source.
libpio_kinds_la_SOURCES = pio_kinds.F90
libpio_types_la_SOURCES = pio_types.F90
libpio_support_la_SOURCES = pio_support.F90
libpio_nf_la_SOURCES = pio_nf.F90
libpiodarray_la_SOURCES = piodarray.F90
libpionfatt_la_SOURCES = pionfatt_mod.F90
libpionfget_la_SOURCES = pionfget_mod.F90
libpionfput_la_SOURCES = pionfput_mod.F90
libpiolib_mod_la_SOURCES = piolib_mod.F90
libncint_mod_la_SOURCES = ncint_mod.F90
libpio_la_SOURCES = pio.F90

# These F90 files are generated from .F90.in files, using the script
# genf90.pl.
piodarray.F90: piodarray.F90.in
	${top_srcdir}/scripts/genf90.pl $< > $@
pionfatt_mod.F90: pionfatt_mod.F90.in
	${top_srcdir}/scripts/genf90.pl $< > $@
pionfget_mod.F90: pionfget_mod.F90.in
	${top_srcdir}/scripts/genf90.pl $< > $@
pionfput_mod.F90: pionfput_mod.F90.in
	${top_srcdir}/scripts/genf90.pl $< > $@

# Each mod file depends on the .o file.
pio_kinds.mod: pio_kinds.lo
pio_types.mod: pio_types.lo
pio_support.mod: pio_support.lo
pio_nf.mod: pio_nf.lo
piodarray.mod: piodarray.F90 piodarray.lo
pionfatt_mod.mod: pionfatt_mod.F90 pionfatt_mod.lo
pionfget_mod.mod: pionfget_mod.F90 pionfget_mod.lo
pionfput_mod.mod: pionfput_mod.F90 pionfput_mod.lo
piolib_mod.mod: piolib_mod.lo
ncint_mod.mod: ncint_mod.lo
pio.mod: pio.lo

# Some mod files depend on other mod files.
DEPEND_FILES = pio_kinds.mod piolib_mod.mod pio_types.mod piodarray.mod \
pio_nf.mod pionfatt_mod.mod pionfget_mod.mod pionfput_mod.mod pio_support.mod
if NETCDF_INTEGRATION
DEPEND_FILES += ncint_mod.mod
endif
pio.lo: $(DEPEND_FILES)

# Mod files are built and then installed as headers.
MODFILES = pio_kinds.mod pio_types.mod pio_support.mod pio_nf.mod	\
piodarray.mod pionfatt_mod.mod pionfget_mod.mod pionfput_mod.mod	\
piolib_mod.mod pio.mod
if NETCDF_INTEGRATION
MODFILES += ncint_mod.mod
endif
BUILT_SOURCES = $(MODFILES)
include_HEADERS = $(MODFILES)

# Doxygen does not cope well with pre-processor use in Fortran. So
# create .f90 files from .F90 files by running the C
# pre-processor. These will only be used by doxygen when --enable-docs
# is used at configure.
if BUILD_DOCS
BUILT_SOURCES += piodarray.f90 piolib_mod.f90 pionfatt_mod.f90 pionfget_mod.f90 \
pionfput_mod.f90 pionfatt_mod_2.f90 pionfget_mod_2.f90
piodarray.f90: piodarray.F90
	$(CC) -I../.. $(AM_CPPFLAGS) -E $< > $@
piolib_mod.f90: piolib_mod.F90
	$(CC) -I../.. $(AM_CPPFLAGS) -E $< > $@
pionfatt_mod.f90: pionfatt_mod.F90
	$(CC) -I../.. $(AM_CPPFLAGS) -E $< > $@
pionfget_mod.f90: pionfget_mod.F90
	$(CC) -I../.. $(AM_CPPFLAGS) -E $< > $@
pionfput_mod.f90: pionfput_mod.F90
	$(CC) -I../.. $(AM_CPPFLAGS) -E $< > $@

# Unfortunately the genf90.pl script which generates these fortran
# files has no way of handling doxygen documentation. So use sed to
# insert some documentation lines to suppress warnings.
pionfatt_mod_2.f90: pionfatt_mod.f90
	sed -e '/^  integer function put_att_desc_real.*/i !> put real att' \
            -e '/^  integer function put_att_desc_double.*/i !> put double att' \
            -e '/^  integer function put_att_desc_int.*/i !> put int att' \
            -e '/^  integer function put_att_desc_short.*/i !> put short att' \
            -e '/^  integer function put_att_vid_text.*/i !> put text att' \
            -e '/^  integer function put_att_vid_real.*/i !> put real att' \
            -e '/^  integer function put_att_vid_double.*/i !> put double att' \
            -e '/^  integer function put_att_vid_int.*/i !> put int att' \
            -e '/^  integer function put_att_vid_short.*/i !> put int att' \
            -e '/^  integer function put_att_id_int.*/i !> put int att' \
            -e '/^  integer function put_att_id_short.*/i !> put short att' \
            -e '/^  integer function put_att_id_real.*/i !> put att' \
            -e '/^  integer function put_att_id_double.*/i !> put att' \
            -e '/^  integer function put_att_id_text.*/i !> put att' \
            -e '/^  integer function put_att_id_short.*/i !> put att' \
            -e '/^  integer function put_att_1d_id_text.*/i !> put att' \
            -e '/^  integer function put_att_1d_id_text_internal.*/i !> put att' \
            -e '/^  integer function put_att_1d_id_short_internal.*/i !> put att' \
            -e '/^  integer function get_att_id_text.*/i !> get att' \
            -e '/^  integer function put_att_1d_id_internal_real.*/i !> att' \
            -e '/^  integer function put_att_1d_id_internal_double.*/i !> att' \
            -e '/^  integer function put_att_1d_id_internal_int.*/i !> att' \
            -e '/^  integer function put_att_1d_id_internal_short.*/i !> att' \
            -e '/^  integer function put_att_1d_vid_text.*/i !> att' \
            -e '/^  integer function put_att_1d_vid_real.*/i !> att' \
            -e '/^  integer function put_att_1d_vid_double.*/i !> att' \
            -e '/^  integer function put_att_1d_vid_int.*/i !> att' \
            -e '/^  integer function put_att_1d_vid_short.*/i !> att' \
            -e '/^  integer function get_att_desc_real.*/i !> att' \
            -e '/^  integer function get_att_desc_double.*/i !> att' \
            -e '/^  integer function get_att_desc_int.*/i !> att' \
            -e '/^  integer function get_att_desc_short.*/i !> att' \
            -e '/^  integer function get_att_desc_1d_real.*/i !> att' \
            -e '/^  integer function get_att_desc_1d_short.*/i !> att' \
            -e '/^  integer function get_att_desc_1d_double.*/i !> att' \
            -e '/^  integer function get_att_id_real.*/i !> att' \
            -e '/^  integer function get_att_id_double.*/i !> att' \
            -e '/^  integer function get_att_id_short.*/i !> att' \
            -e '/^  integer function get_att_text.*/i !> att' \
            -e '/^  integer function get_att_real.*/i !> att' \
            -e '/^  integer function get_att_double.*/i !> att' \
            -e '/^  integer function get_att_int.*/i !> att' \
            -e '/^  integer function get_att_short.*/i !> att' \
            -e '/^  integer function get_att_1d_id_real.*/i !> att' \
            -e '/^  integer function get_att_1d_id_int.*/i !> att' \
            -e '/^  integer function get_att_1d_id_double.*/i !> att' \
            -e '/^  integer function get_att_1d_id_short.*/i !> att' \
            -e '/^     integer(C_INT) function PIOc_get_att_double.*/i !> att' \
            -e '/^  integer function pioc_get_att_float.*/i !> att' \
            -e '/^  integer function pioc_get_att_int.*/i !> att' \
            -e '/^  integer function pioc_get_att_text.*/i !> att' \
            -e '/^  integer function pioc_put_att_double.*/i !> att' \
            -e '/^  integer function pioc_put_att_float.*/i !> att' \
            -e '/^  integer function pioc_put_att_int.*/i !> att' \
            -e '/^  integer function pioc_put_att_text.*/i !> att' \
            $< > $@
pionfget_mod_2.f90: pionfget_mod.f90
	sed -e '/^  integer function get_var1_id_real.*/i !> var' \
            -e '/^  integer function get_var1_id_double.*/i !> var' \
            -e '/^  integer function get_var1_id_text.*/i !> var' \
            -e '/^  integer function get_var1_id_short.*/i !> var' \
            -e '/^  integer function get_var_0d_real.*/i !> var' \
            -e '/^  integer function get_var_0d_double.*/i !> var' \
            -e '/^  integer function get_var_0d_short.*/i !> var' \
            -e '/^  integer function get_var_1d_text.*/i !> var' \
            -e '/^  integer function get_var_1d_short.*/i !> var' \
            -e '/^  integer function get_vara_real_internal.*/i !> var' \
            -e '/^  integer function get_vara_double_internal.*/i !> var' \
            -e '/^  integer function get_vara_text_internal.*/i !> var' \
            -e '/^  integer function get_vara_short_internal.*/i !> var' \
            -e '/^  integer function get_var_1d_int.*/i !> var' \
            $< > $@
endif

CLEANFILES = *.mod piodarray.F90 pionfatt_mod.F90 pionfget_mod.F90	\
pionfput_mod.F90 *.f90

EXTRA_DIST = CMakeLists.txt piodarray.F90.in pionfatt_mod.F90.in	\
pionfget_mod.F90.in pionfput_mod.F90.in
