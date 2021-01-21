## This is the automake file to build the PIO C library.
# Ed Hartnett 8/19/17

# The library we are building.
lib_LTLIBRARIES = libpioc.la

# Are we building with netCDF integration?
if BUILD_NCINT
libpioc_la_LIBADD = ../ncint/libncint.la
libpioc_la_CPPFLAGS = -I${top_srcdir}/src/ncint
endif # BUILD_NCINT

# These linker flags specify libtool version info.
# See http://www.gnu.org/software/libtool/manual/libtool.html#Libtool-versioning
# for information regarding incrementing `-version-info`.
libpioc_la_LDFLAGS = -version-info 5:0:0

# The library header file will be installed in include dir.
include_HEADERS = pio.h uthash.h pio_meta.h

# The library soure files.
libpioc_la_SOURCES = pioc_sc.c pio_darray.c pio_file.c			\
pio_getput_int.c pio_msg.c pio_nc.c pio_rearrange.c pioc.c		\
pioc_support.c pio_darray_int.c pio_get_nc.c pio_lists.c pio_nc4.c	\
pio_put_nc.c pio_spmd.c pio_get_vard.c pio_put_vard.c pio_error.c	\
pio_internal.h uthash.h pio_error.h

EXTRA_DIST = CMakeLists.txt topology.c pio_meta.h.in
