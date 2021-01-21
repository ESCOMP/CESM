# This file is part of PIO. It generates the Makefiles for the tests
# directory.

# Ed Hartnett

# Does the user want to build fortran? If so, there are two additional
# test directories.
if BUILD_FORTRAN
UNIT = unit
GENERAL = general
# If GPTL us used, also add the performance directory.
if USE_GPTL
PERFORMANCE = performance
endif # USE_GPTL
endif # BUILD_FORTRAN

# Are we building with netCDF integration?
if BUILD_NCINT
NCINT = ncint
if BUILD_FORTRAN
FNCINT = fncint
endif # BUILD_FORTRAN
endif # BUILD_NCINT

# Build in these subdirs.
SUBDIRS = cunit ${UNIT} ${NCINT} ${GENERAL} ${PERFORMANCE} ${FNCINT}

EXTRA_DIST = CMakeLists.txt
