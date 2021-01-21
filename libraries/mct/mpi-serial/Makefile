SHELL		= /bin/sh
###############################
include Makefile.conf

VPATH=$(SRCDIR)/mpi-serial
# SOURCE FILES

MODULE		= mpi-serial

SRCS_F90	= fort.F90 \
                  mpif.F90

SRCS_C		= mpi.c \
		  send.c \
		  recv.c \
		  collective.c \
		  req.c \
		  list.c \
		  handles.c \
                  comm.c \
		  error.c \
                  ic_merge.c \
                  group.c \
                  time.c \
                  pack.c \
                  type.c \
                  type_const.c \
                  copy.c \
                  op.c \
                  cart.c \
                  getcount.c \
                  probe.c \
                  info.c


OBJS_ALL	= $(SRCS_C:.c=.o) \
		  $(SRCS_F90:.F90=.o)


INCPATH:= -I .


###############################

# TARGETS

default: lib$(MODULE).a


fort.o: mpif.h


lib$(MODULE).a: $(OBJS_ALL)
	echo $(OBJS_ALL)
	$(RM) $@
	$(AR) $@ $(OBJS_ALL)
	$(RANLIB) $@


LIB	= lib$(MODULE).a


###############################
#RULES

.SUFFIXES:
.SUFFIXES: .F90 .c .o

.c.o:
	$(CC) -c $(INCPATH) $(DEFS) $(CPPDEFS) $(CFLAGS) $<

.F90.o:
	$(FC) -c $(INCFLAG) . $(INCPATH) $(DEFS) $(FPPDEFS) $(FCFLAGS) $(MPEUFLAGS) $<

MYF90FLAGS=$(INCPATH) $(DEFS) $(FCFLAGS)  $(MPEUFLAGS)

.PHONY: clean tests install

clean:
	/bin/rm -f *.o ctest ftest $(LIB) mpi.mod config.log config.status
	cd tests ; $(MAKE) clean

tests:
	cd tests; make

install: lib
	$(MKINSTALLDIRS) $(libdir) $(includedir)
	$(INSTALL) lib$(MODULE).a -m 644 $(libdir)
	$(INSTALL) mpi.h -m 644 $(includedir)
	$(INSTALL) mpif.h -m 644 $(includedir)



