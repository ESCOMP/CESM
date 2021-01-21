# This is part of PIO. It creates the main Makefile.

# Ed Hartnett

# Look in the m4 directory for autotools stuff.
ACLOCAL_AMFLAGS= -I m4

# Does the user want to build fortran?
if BUILD_DOCS
DOC = doc
endif

# Build in each of these subdirs.
SUBDIRS = src tests examples ${DOC} scripts cmake

# Add these files to the distribution.
EXTRA_DIST = CMakeLists.txt COPYRIGHT cmake_config.h.in	\
libpio.settings.in
