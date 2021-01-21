#!/bin/make
#-----------------------------------------------------------------------
# Documentation
all:
	cd texsrc; make
	make apis

html:
	latex2html -white -toc_depth 5 -split 4 -show_section_numbers \
	-address "<A HREF="mailto:jacob@mcs.anl.gov">jacob@mcs.anl.gov</A>" \
	mct_APIs.tex
apis:
	cd texsrc; make
	make apisdvi

apisdvi: mct_APIs.dvi

clean:
	cd texsrc; make clean
	rm -f *.dvi *.log *.bbl *.blg *.aux *.toc

.SUFFIXES: .dvi .tex

.tex.dvi:
	latex $*.tex

#.
