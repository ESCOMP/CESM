
SHELL           = /bin/sh

# SOURCE FILES

SRCS_F90	= importBench.F90 RouterTestDis.F90 RouterTestOvr.F90

OBJS_ALL	= $(SRCS_F90:.F90=.o)

# MACHINE AND COMPILER FLAGS

include ../Makefile.conf

# ADDITIONAL FLAGS SPECIFIC FOR UTMCT COMPILATION

MCTLIBS    = -L$(MPEUPATH) -L$(MCTPATH) -lmct -lmpeu
UTLDFLAGS  = $(REAL8)
UTCMPFLAGS = $(REAL8) $(INCFLAG)$(MPEUPATH) $(INCFLAG)$(MCTPATH)

# TARGETS

all: importBench RouterTestDis RouterTestOvr

importBench: importBench.o
	$(FC) -o $@ importBench.o $(FCFLAGS) $(UTLDFLAGS) $(MCTLIBS) $(MPILIBS)

RouterTestDis: RouterTestDis.o
	$(FC) -o $@ RouterTestDis.o $(FCFLAGS) $(UTLDFLAGS) $(MCTLIBS) $(MPILIBS)

RouterTestOvr: RouterTestOvr.o
	$(FC) -o $@ RouterTestOvr.o $(FCFLAGS) $(UTLDFLAGS) $(MCTLIBS) $(MPILIBS)

# RULES

.SUFFIXES:
.SUFFIXES: .F90 .o

.F90.o:
	$(FC) -c $(INCPATH) $(FPPDEFS) $(FCFLAGS) $(MCTFLAGS) $(UTCMPFLAGS) $<


clean:
	${RM} *.o *.mod importBench RouterTestDis RouterTestOvr

# DEPENDENCIES:

$(OBJS_ALL): $(MCTPATH)/libmct.a











