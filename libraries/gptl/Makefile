.SUFFIXES:
.SUFFIXES: .F90 .o .c .f90
# name of macros file - but default this is generic

VPATH := $(GPTL_DIR)

ifndef MOD_SUFFIX
   MOD_SUFFIX := mod
endif
ifeq ($(strip $(SMP)),TRUE)
  CPPDEFS +=  -DTHREADED_OMP
  compile_threaded=TRUE
endif

ifeq ($(strip $(MACFILE)),)
   MACFILE  := Macros.make
endif

# Machine specific macros file
# This must be included before any settings are overwritten
# But must be AFTER any definitions it uses are defined.
# So be careful if moving this either earlier or later in the makefile!!!
include $(MACFILE)
ifdef COMP_INTERFACE
  UPVAR := $(shell echo $(COMP_INTERFACE) | tr a-z A-Z)
  CPPDEFS+=-D$(UPVAR)_INTERFACE
  ifeq ("$(COMP_INTERFACE)", "nuopc")
    # Set esmf.mk location with ESMF_LIBDIR having precedence over ESMFMKFILE
    CIME_ESMFMKFILE := undefined_ESMFMKFILE
    ifdef ESMFMKFILE
       CIME_ESMFMKFILE := $(ESMFMKFILE)
    endif
    ifdef ESMF_LIBDIR
       CIME_ESMFMKFILE := $(ESMF_LIBDIR)/esmf.mk
    endif
    -include $(CIME_ESMFMKFILE)
    FFLAGS += $(ESMF_F90COMPILEPATHS)
  endif
endif
ifdef DEBUG
  ifeq ("$(DEBUG)", "TRUE")
    CPPDEFS+=-DDEBUG
  endif
endif
ifdef GPTL_CPPDEFS
  CPPDEFS+=$(GPTL_CPPDEFS) -D$(OS) -DCPR$(shell echo $(COMPILER) | tr a-z A-z)
endif
INCLDIR += -I$(GPTL_DIR)

ifeq ($(strip $(MPILIB)), mpi-serial)
  CC      := $(SCC)
  FC      := $(SFC)
  MPIFC   := $(SFC)
  MPICC   := $(SCC)
  INCLDIR += -I$(GPTL_LIBDIR)/../mct/mpi-serial
else
  CC := $(MPICC)
  FC := $(MPIFC)
  CPPDEFS += -DHAVE_MPI
endif
ifdef CPRE
  FPPDEFS := $(patsubst -D%,$(CPRE)%,$(CPPDEFS))
else
  FPPDEFS := $(CPPDEFS)
endif



OBJS = gptl.o GPTLutil.o GPTLget_memusage.o GPTLprint_memusage.o \
       gptl_papi.o f_wrappers.o perf_mod.o perf_utils.o

AR ?= ar
ARFLAGS ?= ruv

libgptl.a: $(OBJS)
	$(AR) $(ARFLAGS) $@ $(OBJS)



.c.o:
	$(CC) -c $(INCLDIR) $(INCS) $(CFLAGS) $(CPPDEFS) $<
.F.o:
	$(FC) -c $(INCLDIR) $(INCS) $(FFLAGS) $(FPPDEFS) $(FIXEDFLAGS) $<
.f90.o:
	$(FC) -c $(INCLDIR) $(INCS) $(FFLAGS) $(FREEFLAGS)  $<
.F90.o:
	$(FC) -c $(INCLDIR) $(INCS) $(FFLAGS) $(FPPDEFS) $(FREEFLAGS)  $<

mostlyclean:
	$(RM) -f *.f *.f90

clean:
	$(RM) -f *.f *.f90 *.d *.$(MOD_SUFFIX) $(OBJS)


install: libgptl.a
	cp -p $(GPTL_DIR)/gptl.h $(SHAREDPATH)/include
	cp -p *.$(MOD_SUFFIX) $(SHAREDPATH)/include
	cp -p libgptl.a $(SHAREDPATH)/lib


perf_mod.o: perf_utils.o
f_wrappers.o: gptl.h private.h
f_wrappers_pmpi.o: gptl.h private.h
gptl.o: gptl.h private.h
util.o: gptl.h private.h
gptl_papi.o: gptl.h private.h
pmpi.o: gptl.h private.h
