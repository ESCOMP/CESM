## This is the automake file to build the PIO netCDF integration
## layer.
# Ed Hartnett 7/3/19

# Find pio.h.
AM_CPPFLAGS = -I$(top_srcdir)/src/clib

# This is our output. The ncint convenience library.
noinst_LTLIBRARIES = libncint.la

# The source files.
libncint_la_SOURCES = ncintdispatch.c ncintdispatch.h ncint_pio.c	\
nc_put_vard.c nc_get_vard.c
