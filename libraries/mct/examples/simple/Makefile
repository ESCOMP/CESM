
SHELL           = /bin/sh

# SOURCE FILES

SRCS_F90	= twocmp.con.F90		\
		  twocmp.seq.F90		\
		  twocmp.seqUnvn.F90		\
		  twocmp.seqNB.F90		\

OBJS_ALL	= $(SRCS_F90:.F90=.o)

# MACHINE AND COMPILER FLAGS

include ../../Makefile.conf

# ADDITIONAL DEFINITIONS SPECIFIC FOR UTMCT COMPILATION

MCTLIBS    = -L$(MPEUPATH) -L$(MCTPATH) -lmct -lmpeu
UTLDFLAGS  = $(REAL8)
UTCMPFLAGS = $(REAL8) $(INCFLAG)$(MPEUPATH) $(INCFLAG)$(MCTPATH)

# TARGETS

all:	twocon twoseq twosequn twoseqNB

twocon:  twocmp.con.o
	$(FC) -o $@ twocmp.con.o $(FCFLAGS) $(UTLDFLAGS) $(MCTLIBS) $(MPILIBS)

twoseq:  twocmp.seq.o
	$(FC) -o $@ twocmp.seq.o $(FCFLAGS) $(UTLDFLAGS) $(MCTLIBS) $(MPILIBS)

twosequn:  twocmp.seqUnvn.o
	$(FC) -o $@ twocmp.seqUnvn.o $(FCFLAGS) $(UTLDFLAGS) $(MCTLIBS) $(MPILIBS)

twoseqNB:  twocmp.seqNB.o
	$(FC) -o $@ twocmp.seqNB.o $(FCFLAGS) $(MCTLIBS) $(MPILIBS)

# RULES

.SUFFIXES:
.SUFFIXES: .F90 .o

.F90.o:
	$(FC) -c $(INCPATH) $(FPPDEFS) $(FCFLAGS) $(MCTFLAGS) $(UTCMPFLAGS) $<


clean:
	${RM} *.o *.mod twocon twoseq twosequn twoseqNB

# DEPENDENCIES:

$(OBJS_ALL): $(MCTPATH)/libmct.a
