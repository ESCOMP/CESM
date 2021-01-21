###############################

#
# test programs Makefile
#

# Parent dir Makefile.conf has all necessary vars
include ../Makefile.conf

TINC    = -I..
LDFLAGS = -L..
MYLIBS    = $(LIBS) -l$(MODULE)
MYF90FLAGS=$(INCPATH) $(DEFS) $(FCFLAGS)  $(MPEUFLAGS)

runtests: all
	./ctest
	@echo
	./ftest
	@echo

all: ctest ftest

ctest: ctest.c
	$(CC) $(DEFS) $(TINC) $(ALLCFLAGS) -o $@ ctest.c $(LDFLAGS) $(MYLIBS)

ftest: ftest.F90
	$(FC) $(DEFS) $(TINC) $(MYF90FLAGS) -o $@ ftest.F90 $(LDFLAGS) $(MYLIBS)

ctest2: ctest_old.c
	$(CC) $(DEFS) $(TINC) $(ALLCFLAGS) -o $@ ctest_old.c $(LDFLAGS) $(MYLIBS)

ftest2: ftest_old.F90
	$(FC) $(DEFS) $(TINC) $(MYF90FLAGS) -o $@ ftest_old.F90 $(LDFLAGS) $(MYLIBS)

stest: stest.F90 stest2.o
	$(FC) $(DEFS) $(TINC) $(MYF90FLAGS) -o $@ stest.F90 stest2.o $(LDFLAGS) $(MYLIBS)


clean:
	rm -f ctest ftest ctest2 ftest2
	rm -f *.o
