# This is part of PIO. It creates the Makefile for the src directory.

# Ed Hartnett

# Does the user want to build fortran?
if BUILD_FORTRAN
FLIB = flib
endif # BUILD_FORTRAN

# Are we building with the GPTL timing library?
if USE_GPTL
GPTL = gptl
endif

# Are we building with netCDF integration?
if BUILD_NCINT
NCINT = ncint
endif # BUILD_NCINT

# Build these subdirectories.
SUBDIRS = ${NCINT} clib ${GPTL} $(FLIB)

EXTRA_DIST = CMakeLists.txt
