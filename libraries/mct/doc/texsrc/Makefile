#!/bin/make

TEXFILES	=
include SRCS_tex.mk

PROTEXLOC	= ../../protex/protex

PROTEX          = perl $(PROTEXLOC) -b # bare mode--no TOC

#-----------------------------------------------------------------------
# Documentation
all:
	cp ../../mct/*.F90 .
	cp ../../mpeu/m_String.F90 .
	cp ../../mpeu/m_List.F90 .
	make doc

doc: $(TEXFILES)

clean:
	rm -f *.F90
	rm -f *.tex

.SUFFIXES: .F90 .tex

.F90.tex:
	$(PROTEX) $*.F90 > $*.tex

#.
