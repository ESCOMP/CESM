.NOTPARALLEL:
SHELL           = /bin/sh
VPATH=$(SRCDIR)/mct
# SOURCE FILES

MODULE		= mct

SRCS_F90	= m_MCTWorld.F90		\
		  m_AttrVect.F90		\
		  m_GlobalMap.F90	        \
		  m_GlobalSegMap.F90		\
		  m_GlobalSegMapComms.F90	\
		  m_Accumulator.F90		\
		  m_SparseMatrix.F90      	\
		  m_Navigator.F90		\
		  m_AttrVectComms.F90		\
		  m_AttrVectReduce.F90		\
		  m_AccumulatorComms.F90  	\
		  m_GeneralGrid.F90		\
		  m_GeneralGridComms.F90	\
		  m_SpatialIntegral.F90		\
		  m_SpatialIntegralV.F90	\
		  m_MatAttrVectMul.F90    	\
		  m_Merge.F90			\
		  m_GlobalToLocal.F90		\
		  m_ExchangeMaps.F90		\
		  m_ConvertMaps.F90		\
		  m_SparseMatrixDecomp.F90	\
		  m_SparseMatrixToMaps.F90	\
		  m_SparseMatrixComms.F90 	\
		  m_SparseMatrixPlus.F90	\
		  m_Router.F90			\
		  m_Rearranger.F90        	\
		  m_SPMDutils.F90               \
		  m_Transfer.F90

OBJS_ALL	= $(SRCS_F90:.F90=.o)

# MACHINE AND COMPILER FLAGS

include ../Makefile.conf

# TARGETS

all: 	lib$(MODULE).a

lib$(MODULE).a:	$(OBJS_ALL)
	$(RM) $@
	$(AR) $@ $(OBJS_ALL)
	$(RANLIB) $@

# ADDITIONAL FLAGS SPECIFIC FOR MCT COMPILATION

MCTFLAGS = $(INCFLAG)$(MPEUPATH)

# RULES

.SUFFIXES:
.SUFFIXES: .F90 .o

.F90.o:
	$(FC) -c $(INCPATH) $(FPPDEFS) $(FCFLAGS) $(MCTFLAGS) $<


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

$(OBJS_ALL): $(MPEUPATH)/libmpeu.a

m_AttrVect.o:
m_Accumulator.o: m_AttrVect.o
m_GlobalMap.o:
m_GlobalSegMap.o:
m_GlobalSegMapComms.o: m_GlobalSegMap.o
m_Navigator.o:
m_SPMDutils.o:
m_AttrVectComms.o: m_AttrVect.o m_GlobalMap.o
m_AttrVectReduce.o: m_AttrVect.o
m_AccumulatorComms.o: m_AttrVect.o m_GlobalMap.o m_AttrVectComms.o
m_SparseMatrix.o: m_AttrVect.o m_GlobalMap.o m_AttrVectComms.o
m_GeneralGrid.o: m_AttrVect.o
m_GeneralGridComms.o: m_AttrVect.o m_GeneralGrid.o m_AttrVectComms.o m_GlobalMap.o m_GlobalSegMap.o
m_MatAttrVectMul.o: m_AttrVect.o m_SparseMatrix.o m_GlobalMap.o m_GlobalSegMap.o m_SparseMatrixPlus.o m_Rearranger.o
m_Merge.o: m_AttrVect.o m_GeneralGrid.o
m_Router.o: m_GlobalToLocal.o m_MCTWorld.o m_GlobalSegMap.o m_ExchangeMaps.o
m_Rearranger.o: m_Router.o m_MCTWorld.o m_GlobalSegMap.o m_AttrVect.o m_SPMDutils.o
m_GlobalToLocal.o: m_GlobalSegMap.o
m_ExchangeMaps.o: m_GlobalMap.o m_GlobalSegMap.o m_MCTWorld.o m_ConvertMaps.o
m_ConvertMaps.o: m_GlobalMap.o m_GlobalSegMap.o m_MCTWorld.o
m_SparseMatrixDecomp.o: m_SparseMatrix.o m_GlobalSegMap.o
m_SparseMatrixToMaps.o: m_SparseMatrix.o m_GlobalSegMap.o
m_SparseMatrixComms.o:	m_SparseMatrix.o m_SparseMatrixDecomp.o m_GlobalSegMap.o m_AttrVectComms.o
accumulate.o: m_AttrVect.o m_Accumulator.o
m_SpatialIntegral.o: m_SpatialIntegralV.o m_GeneralGrid.o m_AttrVect.o m_AttrVectReduce.o
m_SpatialIntegralV.o: m_AttrVect.o m_AttrVectReduce.o
m_Transfer.o: m_AttrVect.o m_Router.o m_MCTWorld.o
m_SparseMatrixPlus.o: m_GlobalSegMap.o m_Rearranger.o m_SparseMatrix.o m_SparseMatrixComms.o m_SparseMatrixToMaps.o m_GlobalToLocal.o



