.NOTPARALLEL:
# MACHINE AND COMPILER FLAGS

include ../Makefile.conf

VPATH = $(SRCDIR)/mpeu
SHELL           = /bin/sh

INCPATH += $(INCFLAG). $(INCFLAG)../

# SOURCE FILES

MODULE		= mpeu

SRCS_F90	= m_IndexBin_char.F90		\
		  m_IndexBin_integer.F90	\
		  m_IndexBin_logical.F90	\
		  m_List.F90			\
		  m_MergeSorts.F90		\
		  m_Filename.F90		\
		  m_FcComms.F90                 \
		  m_Permuter.F90		\
		  m_SortingTools.F90		\
		  m_String.F90			\
		  m_StrTemplate.F90		\
		  m_chars.F90			\
		  m_die.F90			\
		  m_dropdead.F90		\
                  m_FileResolv.F90		\
		  m_flow.F90			\
		  m_inpak90.F90			\
		  m_ioutil.F90			\
		  m_mall.F90			\
		  m_mpif.F90			\
		  m_mpif90.F90			\
		  m_mpout.F90			\
		  m_rankMerge.F90		\
		  m_realkinds.F90		\
		  m_stdio.F90			\
		  m_TraceBack.F90		\
		  m_zeit.F90

SRCS_C		= get_zeits.c

OBJS_ALL	= $(SRCS_C:.c=.o)  \
		  $(SRCS_F90:.F90=.o)


# TARGETS

all:	lib$(MODULE).a

lib$(MODULE).a:	$(OBJS_ALL)
	$(RM) $@
	$(AR) $@ $(OBJS_ALL)
	$(RANLIB) $@

# ADDITIONAL FLAGS SPECIFIC FOR MPEU COMPILATION

MPEUFLAGS =

# RULES

.SUFFIXES:
.SUFFIXES: .F90 .c .o

.c.o:
	$(CC) -c $(CPPDEFS) $(CFLAGS) $(INCPATH) $<

.F90.o:
	$(FC) -c $(INCPATH) $(FPPDEFS) $(FCFLAGS) $(MPEUFLAGS) $<

clean:
	${RM} *.o *.mod lib$(MODULE).a

install: all
	$(MKINSTALLDIRS) $(libdir) $(includedir)
	$(INSTALL) lib$(MODULE).a -m 644 $(libdir)
	@for modfile in *.mod; do                         \
	  echo $(INSTALL) $$modfile -m 644 $(includedir); \
	  $(INSTALL) $$modfile -m 644 $(includedir);      \
	done

# DEPENDENCIES

m_IndexBin_char.o: m_die.o m_stdio.o
m_IndexBin_integer.o: m_die.o m_stdio.o
m_IndexBin_logical.o: m_die.o m_stdio.o
m_List.o: m_String.o m_die.o m_mall.o
m_MergeSorts.o: m_die.o m_realkinds.o m_stdio.o
m_Filename.o:
m_Permuter.o: m_die.o m_realkinds.o
m_SortingTools.o: m_IndexBin_char.o m_IndexBin_integer.o m_IndexBin_logical.o m_MergeSorts.o m_Permuter.o m_rankMerge.o
m_String.o: m_die.o m_mall.o m_mpif90.o
m_StrTemplate.o: m_chars.o m_die.o m_stdio.o
m_chars.o:
m_die.o: m_dropdead.o m_flow.o m_mpif90.o m_mpout.o m_stdio.o
m_dropdead.o: m_mpif90.o m_stdio.o
m_flow.o: m_chars.o
m_inpak90.o: m_die.o m_ioutil.o m_mall.o m_mpif90.o m_realkinds.o m_stdio.o
m_ioutil.o: m_stdio.o
m_mall.o: m_chars.o m_die.o m_ioutil.o m_realkinds.o m_stdio.o
m_mpif.o:
m_mpif90.o: m_mpif.o m_realkinds.o m_stdio.o
m_mpout.o: m_dropdead.o m_ioutil.o m_mpif90.o m_stdio.o
m_rankMerge.o:
m_realkinds.o:
m_stdio.o:
m_zeit.o: m_SortingTools.o m_die.o m_ioutil.o m_mpif90.o m_stdio.o get_zeits.o
get_zeits.o:
m_FileResolv.o: m_die.o m_StrTemplate.o
m_TraceBack.o:	m_die.o m_stdio.o m_String.o














