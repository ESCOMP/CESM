# This is part of PIO. It creates the doc Makefile.

# Ed Hartnett 4/1/19

# Run doxygen, then confirm warning log file is empty.
all:
	doxygen Doxyfile
	cat doxywarn.log
	[ ! -s doxywarn.log ]

check: all

# Include these subdirs to include the documention files in the
# distribution.
SUBDIRS = source images

CLEANFILES = *.log

EXTRA_DIST = CMakeLists.txt customdoxygen.css Doxyfile.in	\
DoxygenLayout.xml doxygen.sty
