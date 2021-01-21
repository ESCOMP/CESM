
SHELL           = /bin/sh

# SOURCE FILES

MODULE		= testall

SRCS_F90	= mph.F90 m_AVTEST.F90 m_ACTEST.F90  \
	          m_GGRIDTEST.F90 m_GMAPTEST.F90 \
	          m_GSMAPTEST.F90 m_MCTWORLDTEST.F90 \
	          m_ROUTERTEST.F90 m_SMATTEST.F90 \
	          master.F90 convertgauss.F90 convertPOPT.F90 \
	          cpl.F90 ccm.F90 pop.F90 \
                  ReadSparseMatrixAsc.F90


OBJS_ALL	= $(SRCS_F90:.F90=.o)

# MACHINE AND COMPILER FLAGS

include ../../Makefile.conf

# TARGETS

all:    testall

testall: $(OBJS_ALL)
	$(FC) -o $@ $(OBJS_ALL) $(UTLDFLAGS) $(MCTLIBS) $(MPILIBS)

# ADDITIONAL FLAGS SPECIFIC FOR UTMCT COMPILATION

MCTLIBS    = -L$(MPEUPATH) -L$(MCTPATH) -lmct -lmpeu
UTLDFLAGS  = $(REAL8)
UTCMPFLAGS = $(PROGFCFLAGS) $(REAL8) $(INCFLAG)$(MPEUPATH) $(INCFLAG)$(MCTPATH)

# RULES

.SUFFIXES:
.SUFFIXES: .F90 .o

.F90.o:
	$(FC) -c $(INCPATH) $(FPPDEFS) $(FCFLAGS) $(MCTFLAGS) $(UTCMPFLAGS) $<

clean:
	${RM} *.o *.mod testall

# DEPENDENCIES:

$(OBJS_ALL): $(MCTPATH)/libmct.a











