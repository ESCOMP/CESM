!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: cpl.F90,v 1.25 2007-12-18 00:02:05 jacob Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !ROUTINE: cpl  -- coupler for unit tester
!
! !DESCRIPTION:
! A coupler subroutine to test functionality of MCT.
!
! !INTERFACE:
!
      subroutine cpl (CPL_World)
!
! !USES:
!
      use MPH_all
!---Field Storage DataType and associated methods
      use m_AttrVect,only    : MCT_AtrVt_init => init
      use m_AttrVect,only    : MCT_AtrVt_clean => clean
      use m_AttrVect,only    : MCT_AtrVt_nreals => nRAttr
      use m_AttrVect,only    : MCT_AtrVt_nints => nIAttr
      use m_AttrVect,only    : MCT_AtrVt_lsize => lsize
      use m_AttrVect,only    : AttrVect
      use m_AttrVect,only    : AttrVect_exportIListToChar =>exportIListToChar
      use m_AttrVect,only    : AttrVect_exportRListToChar =>exportRListToChar
      use m_AttrVect,only    : AttrVect_Copy => Copy
!---AttrVect Communication methods
      use m_AttrVectComms,only    : AttrVect_Send => send
      use m_AttrVectComms,only    : AttrVect_Recv => recv
      use m_AttrVectComms,       only : AttrVect_gather => gather
!---AttrVect Reduction methods
      use m_AttrVectReduce,only   : AttrVect_LocalReduce => LocalReduce
      use m_AttrVectReduce,only   : AttrVect_LocalReduceRAttr => &
                                         LocalReduceRAttr
      use m_AttrVectReduce,only   : AttrVectSUM, AttrVectMIN, AttrVectMAX
!---Coordinate Grid DataType and associated methods
      use m_GeneralGrid,only: GeneralGrid
      use m_GeneralGrid,only: MCT_GGrid_clean => clean
      use m_GeneralGrid,only : MCT_GGrid_lsize => lsize
      use m_GeneralGridComms,only: MCT_GGrid_recv => recv
      use m_GeneralGridComms,only: MCT_GGrid_scatter => scatter
      use m_GeneralGridComms,only: MCT_GGrid_gather => gather
      use m_GeneralGridComms,only: MCT_GGrid_bcast => bcast
!---MCT Spatial Integral services...
      use m_SpatialIntegral,only : MCT_PairedSpatialIntegrals => &
	                                      PairedSpatialIntegrals
      use m_SpatialIntegral,only : MCT_PairedSpatialAverages => &
	                                      PairedSpatialAverages
      use m_SpatialIntegral,only : MCT_PairedMaskedSpatialIntegral => &
	                                      PairedMaskedSpatialIntegrals
      use m_SpatialIntegral,only : MCT_PairedMaskedSpatialAverages => &
	                                      PairedMaskedSpatialAverages
!---Domain Decomposition Descriptor DataType and associated methods
      use m_GlobalSegMap,only: MCT_GSMap_init => init
      use m_GlobalSegMap,only: MCT_GSMap_copy => copy   ! rml
      use m_GlobalSegMap,only: MCT_GSMap_clean => clean
      use m_GlobalSegMap,only: MCT_GSMap_gsize => gsize
      use m_GlobalSegMap,only: MCT_GSMap_lsize => lsize
      use m_GlobalSegMap,only: MCT_GSMap_ngseg => ngseg
      use m_GlobalSegMap,only: MCT_GSMap_nlseg => nlseg
      use m_GlobalSegMap,only: GlobalSegMap
      use m_GlobalMap,only : GlobalMap
      use m_GlobalMap,only : GlobalMap_init => init
      use m_GlobalMap,only : GlobalMap_init_remote => init_remote
      use m_GlobalMap,only : GlobalMap_clean => clean
!---GlobalSegMap Communication Methods
      use m_GlobalSegMapComms,only: GlobalSegMap_bcast => bcast
      use m_GlobalSegMapComms,only: GlobalSegMap_send => send
      use m_GlobalSegMapComms,only: GlobalSegMap_recv => recv
      use m_GlobalSegMapComms,only: GlobalSegMap_isend => isend
!---Methods for Exchange of GlobalMapping Objects
      use m_ExchangeMaps,only: ExchangeMap
!---Convert between GlobalSegMap and GlobalMap
      use m_ConvertMaps,only:GlobalSegMapToGlobalMap
!---Global-to-Local indexing services
      use m_GlobalToLocal,only: MCT_GStoL => GlobalToLocalIndices
!---Component Model Registry
      use m_MCTWorld,only: ThisMCTWorld
      use m_MCTWorld,only: MCTComponentRootRank => ComponentRootRank
      use m_MCTWorld,only: MCTWorld_initialized => initialized
      use m_MCTWorld,only: MCTWorld_init => init
      use m_MCTWorld,only: MCTWorld_clean => clean
!---Intercomponent communications scheduler
      use m_Router,only: Router
      use m_Router,only: MCT_Router_init => init
      use m_Router,only: MCT_Router_print => print    ! rml
      use m_Router,only: MCT_Router_clean => clean
      use m_Transfer,only: MCT_Send => send
      use m_Transfer,only: MCT_Recv => recv
!---Sparse Matrix DataType and associated methods
      use m_SparseMatrix, only : SparseMatrix
      use m_SparseMatrix, only : SparseMatrix_clean => clean
      use m_SparseMatrix, only : SparseMatrix_lsize => lsize
      use m_SparseMatrix, only : SMatrix_exportGlobalRowIndices => &
                                                        exportGlobalRowIndices
      use m_SparseMatrix, only : SMatrix_exportGlobalColumnInd => &
                                                        exportGlobalColumnIndices
      use m_SparseMatrix, only : SMatrix_exportMatrixElements => &
                                                        exportMatrixElements

      use m_SparseMatrixComms, only: SparseMatrix_ScatterByRow => ScatterByRow
      use m_SparseMatrixComms, only: SparseMatrix_gather => gather
      use m_SparseMatrixComms, only: SparseMatrix_bcast => bcast
      use m_SparseMatrixDecomp, only : SparseMatrixDecompByRow => ByRow
!---SparseMatrixPlus DataType and associated methods
      use m_SparseMatrixPlus, only : SparseMatrixPlus
      use m_SparseMatrixPlus, only : SparseMatrixPlus_init => init
      use m_SparseMatrixPlus, only : SparseMatrixPlus_clean => clean
      use m_SparseMatrixPlus, only : SparseMatrixPlus_initialized => initialized
      use m_SparseMatrixPlus, only : Xonly ! Decompose matrix by column
      use m_SparseMatrixPlus, only : Yonly ! Decompose matrix by row
      use m_SparseMatrixPlus, only : XandY ! Arbitrary row/column decomp
!---Accumulation data type and methods
      use m_Accumulator, only : Accumulator
      use m_Accumulator, only : accumulate
      use m_Accumulator, only : MCT_Accumulator_init => init
      use m_Accumulator, only : MCT_Accumulator_clean => clean
      use m_Accumulator, only : Accumulator_lsize => lsize
      use m_Accumulator, only : MCT_SUM
      use m_Accumulator, only : MCT_AVG
      use m_AccumulatorComms,only : MCT_Acc_scatter => scatter
      use m_AccumulatorComms,only : MCT_Acc_gather => gather
      use m_AccumulatorComms,only : MCT_Acc_bcast => bcast
!---Matrix-Vector multiply methods
      use m_MatAttrVectMul, only: MCT_MatVecMul => sMatAvMult
!---mpeu file reading routines
      use m_inpak90
!---mpeu routines for MPI communications
      use m_mpif90
!---mpeu timers
      use m_zeit
!---mpeu stdout/stderr
      use m_stdio
      use m_ioutil, only: luavail
!---mpeu error handling
      use m_die
!---mpeu reals
      use m_realkinds

!---Tester Modules
      use m_ACTEST, only : Accumulator_test => testall
      use m_ACTEST, only : Accumulator_identical => identical
      use m_AVTEST, only : AttrVect_test => testall
      use m_AVTEST, only : AttrVect_identical => Identical
      use m_AVTEST, only : AttrVect_ReduceTest => Reduce
      use m_GGRIDTEST, only : GGrid_test      => testall
      use m_GGRIDTEST, only : GGrid_identical => Identical
      use m_GMAPTEST, only : GMap_test => testall
      use m_GSMAPTEST, only : GSMap_test => testall
      use m_GSMAPTEST, only : GSMap_identical => Identical
      use m_MCTWORLDTEST, only : MCTWorld_test => testall
      use m_ROUTERTEST, only : Router_test => testall
      use m_SMATTEST, only : sMat_test => testall
      use m_SMATTEST, only : sMat_identical   => Identical
      use m_List, only : ListExportToChar => ExportToChar

      implicit none

! !INPUT PARAMETERS:

      integer,intent(in) :: CPL_World  ! communicator for coupler

! !REVISION HISTORY:
!        Oct00 - Yun (Helen) He and Chris Ding, NERSC/LBNL - initial MPH-only version
!      19Nov00 - R. Jacob <jacob@mcs.anl.gov> -- interface with mct
!      06Feb01 - J. Larson <larson@mcs.anl.gov> - slight mod to
!                accomodate new interface to MCT_GSMap_lsize().
!      08Feb01 - R. Jacob <jacob@mcs.anl.gov> -- use MCT_Recv, new interface
!                to MCT_GSMap_lsize().
!      23Feb01 - R. Jacob <jacob@mcs.anl.gov> -- add check for transfer
!                expand size of AttrVect
!      25Feb01 - R. Jacob <jacob@mcs.anl.gov> - add mpe and mpeu
!      22Mar01 - R. Jacob <jacob@mcs.anl.gov> - use new router init
!      27Apr01 - R. Jacob <jacob@mcs.anl.gov> - use SparseMatrix
!      02May01 - R. Jacob <jacob@mcs.anl.gov> - Router is now built
!		 between atmosphere model and sparsematrix-defined
!                atmosphere globalsegmap.  Recv data in aV and check.
!                Add new argument to MCT_Smat2xGSMap.
!      16May01 - Larson/Jacob <jacob@mcs.anl.gov> - only root
!                needs to call ReadSparseMatrix with new Comms
!      17May01 - R. Jacob <jacob@mcs.anl.gov> - perfrom the sparse
!                matrix multiply on the received dummy data and check
!      19May01 - R. Jacob <jacob@mcs.anl.gov> - verify that matrix
!                multiply works on constant data
!      11Jun01 - Larson/Jacob - receive atmosphere's general grid from
!                the atmosphere.
!      15Feb02 - R. Jacob <jacob@mcs.anl.gov> New MCTWorld argument
!      28Mar02 - R. Jacob <jacob@mcs.anl.gov> Use Rearranger
!      12Jun02 - J. Larson <larson@mcs.anl.gov> - Use SparseMatrix
!                export routines.
!
!EOP ___________________________________________________________________

      character(len=*), parameter :: cplname='cpl.F90'

!----------------------- MPH vars
      integer :: myProc, myProc_global
      integer :: Global_World
      integer :: atmo_id, ocn_id
      integer :: ncomps,mycompid,mySize

!----------------------- MCT and dummy model vars

      logical :: initialized
      integer :: root,stat,status
      integer, dimension(:,:),pointer :: sendstatus
      integer, dimension(:),pointer :: sendrequest
      integer, dimension(2) :: sMat_src_dims, sMat_dst_dims

!  SparseMatrix dimensions and Processor Layout
      integer :: Nax, Nay                     ! Atmosphere lons, lats
      integer :: Nox, Noy                     ! Ocean lons, lats
      integer :: NPROCS_LATA, NPROCS_LONA     ! Processor layout

!  Arrays used to initialize the MCT GlobalSegMap
      integer :: asize,asize2,i,j,k
      integer :: osize,osize2
      integer,dimension(1) :: start,length
!     integer,dimension(:),pointer :: lstart,llength

!  Number of accumulation steps and accumulator dummy variables
      integer :: steps
      integer, parameter :: nsteps = 10
      character*64 :: ACCA2O_rList
      integer, dimension(:), allocatable :: ACCA2O_rAction

! Dummy arrays used for testing SparseMatrix export routines:
      integer :: Num
      integer, dimension(:), pointer :: DummyI
      real,    dimension(:), pointer :: DummyR

!  Atmosphere and Ocean GSMap
      type(GlobalSegMap) :: testAGSMap                 ! rml
      type(GlobalSegMap) :: AGSMap,OGSMap, DAGSMap

!  GSMap for testing GlobalSegMapComms
      type(GlobalSegMap) :: inGSMap

!  Ocean GlobalSegMap from ocean
      type(GlobalSegMap) :: OCN_OGSMap

!  Ocean GlobalMap from ocean
      type(GlobalMap) :: OCN_OGMap

!  Remote GlobalMap for testing
      type(GlobalMap) :: rOGMap

!  GlobalMap for Testing Accumulator Comms
      type(GlobalMap) :: OGMap

! Router from Atm to Cpl
      type(Router)	 :: Atm2Cpl

! Router from Cpl to Ocn
      type(Router)	 :: Cpl2Ocn

! Accumulator for data from atmosphere to ocean
      type(Accumulator) :: ACCA2O

! Accumulator for testing scatter and gather routines
      type(Accumulator) :: scatterAcc, GgatherAcc, GSgatherAcc

! AttrVect for data from the atm
      type(AttrVect) :: fromatm

! AttrVect for data from the atm on the ocean grid
      type(AttrVect) :: fromatm_ocn

! Coupler AttrVect for data from process 1 to process 0
      type(AttrVect) :: fromP1

! AttrVect for data from the ocn
      type(AttrVect) :: fromocn

! AttrVect for data from the ocn on the atmosphere's grid
      type(AttrVect) :: fromocn_atm

! AttrVects for PairedSpatialIntegral services
      type(AttrVect) :: IntegratedAVect, IntegratedOVect

!  Spatial Integral Temporary Variables
      integer :: VectorLength

! AttrVects for testing mapping
      type(AttrVect) :: gatherAV_ocn,gatherAV_atm
      integer :: unit, unit1, unit2

! a2o SparseMatrix elements on root
      type(SparseMatrix) :: DummySMat

! a2o distributed SparseMatrix elements
      type(SparseMatrix) :: dMat, dMat_test

! Test sMat for gather
      type(SparseMatrix) :: gathersMat

! Test GlobalSegMap for sMat gather
      type(GlobalSegMap) :: MatGSMap

! a2o and o2a distributed SparseMatrixPlus variables
      type(SparseMatrixPlus) :: A2OMatPlus, O2AMatPlus

! The atmosphere's grid recieved from the atmosphere
      type(GeneralGrid) :: AtmGrid

! The atmosphere's distributed grid
      type(GeneralGrid) :: dAtmGrid

! The ocean's grid recieved from the ocean
      type(GeneralGrid) :: OcnGrid

! The ocean's distributed grid
      type(GeneralGrid) :: dOcnGrid

! Test grid for scatter,gather,bcast
      type(GeneralGrid) :: scatterGGrid, gatherGGrid

!::DEFINE POP REMAP MATRIX DIMENSIONS::

#ifdef MPE
#include "mpe.h"
#endif


!------------------------------------Begin code

  call MPI_COMM_DUP (MPI_COMM_WORLD, Global_World, ierr)

  call MPI_COMM_RANK (MPI_COMM_WORLD, myProc_global, ierr)
  call MPI_COMM_RANK (CPL_World, myProc, ierr)
! write(*,*) myProc, ' in cpl === ', myProc_global, ' in global'
! write(*,*) 'MPH_local_proc_id()=', MPH_local_proc_id_ME_SE()
! write(*,*) 'MPH_global_proc_id()=', MPH_global_proc_id()

  call MPI_COMM_SIZE(CPL_World,mySize,ierr)
  if (myProc==0) call MPH_redirect_output ('cpl')
  ncomps=MPH_total_components()
  mycompid=MPH_component_id_ME_SE()

! Get the atmosphere's component id
  atmo_id = MPH_get_component_id("atmosphere")

! Get the ocean's component id
  ocn_id = MPH_get_component_id("ocean")

!-------------------------------------------------------
!  Begin attempts to use MCT

#ifdef MPE
  call mpe_logging_init(myProc_global,init_s,init_e,gsmi_s,gsmi_e, &
   atri_s,atri_e,routi_s,routi_e,send_s,send_e,recv_s,recv_e, &
   clean_s,clean_e)
#endif

  initialized= MCTWorld_initialized()
  if (myProc==0)write(stdout,*) cplname, &
     ":: MCTWorld initialized=",initialized
  if(initialized) call die(cplname, "mct already initialized")

  if(myProc==0)write(stdout,*) cplname, ":: Initializing MCTWorld"
  call zeit_ci('Cworldinit')
   call MCTWorld_init(ncomps,MPI_COMM_WORLD,CPL_World,mycompid)
  call zeit_co('Cworldinit')

  initialized= MCTWorld_initialized()
  if (myProc==0)write(stdout,*) cplname, &
     ":: MCTWorld initialized=",initialized
  if(.not. initialized) call die(cplname, "mct not initialized")

  call MCTWorld_test("CPL::MCTWorld",6000+myProc)

! Read in Sparse Matrix dimensions and processor layout

  if(myProc==0) then

     ! Read in SparseMatrix dimensions for atmosphere and ocean
     call I90_LoadF("ut_SparseMatrix.rc", ierr)

     call I90_Label("atmosphere_dimensions:", ierr)
     Nax = I90_GInt(ierr)
     Nay = I90_GInt(ierr)

     call I90_Label("ocean_dimensions:", ierr)
     Nox = I90_GInt(ierr)
     Noy = I90_GInt(ierr)

     call I90_Release(ierr)

     ! Read in processor layout information for atmosphere and ocean
     call I90_LoadF("./processors_map.in", ierr)

     call I90_Label("NPROCS_ATM", ierr)
     NPROCS_LATA = I90_GInt(ierr)
     NPROCS_LONA = I90_GInt(ierr)

     call I90_Release(ierr)

  endif

  root = MCTComponentRootRank(mycompid,ThisMCTWorld)
  call MPI_BCAST(Nax,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(Nay,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(Nox,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(Noy,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(NPROCS_LATA,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(NPROCS_LONA,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)

!::::Receive the Atmosphere's General Grid on the root process

 if(myProc==0) then
    write(stdout,*) cplname, ":: Receiving Grid from atmosphere"

    call MCT_GGrid_recv(AtmGrid, atmo_id, 1400, status)

    call GGrid_test(AtmGrid,"CPL::Root AtmGrid",3000+myProc)

! check that we can make inquiries about the atmosphere's grid.
    write(stdout,*) cplname, ':: AtmGrid%coordinate_list%bf = ', &
	  AtmGrid%coordinate_list%bf
    write(stdout,*) cplname, ':: AtmGrid%index_list%bf = ', &
	  AtmGrid%index_list%bf
    write(stdout,*) cplname, ':: AtmGrid%data%iList%bf = ', &
	 AttrVect_exportIListToChar(AtmGrid%data)
    write(stdout,*) cplname, ':: size(AtmGrid%data%iAttr) = ', &
	  size(AtmGrid%data%iAttr)
    write(stdout,*) cplname, ':: AtmGrid%data%rList%bf = ', &
	 AttrVect_exportRListToChar(AtmGrid%data)
    write(stdout,*) cplname, ':: size(AtmGrid%data%rAttr) = ', &
	  size(AtmGrid%data%rAttr)

!!!!!!!!!!!!! Receive the Ocean's General Grid
!
    write(stdout,*) cplname, ":: Receiving Grid from ocean"

    call MCT_GGrid_recv(OcnGrid, ocn_id, 2800, status)

    call GGrid_test(OcnGrid,"CPL::Root OcnGrid",3100+myProc)

! check that we can make inquiries about the atmosphere's grid.
    write(stdout,*) cplname, ':: OcnGrid%coordinate_list%bf = ', &
	  OcnGrid%coordinate_list%bf
    write(stdout,*) cplname, ':: OcnGrid%index_list%bf = ', &
	  OcnGrid%index_list%bf
    write(stdout,*) cplname, ':: OcnGrid%data%iList%bf = ', &
	 AttrVect_exportIListToChar(OcnGrid%data)
    write(stdout,*) cplname, ':: size(OcnGrid%data%iAttr) = ', &
	  size(OcnGrid%data%iAttr)
    write(stdout,*) cplname, ':: OcnGrid%data%rList%bf = ', &
	 AttrVect_exportRListToChar(OcnGrid%data)
    write(stdout,*) cplname, ':: size(OcnGrid%data%rAttr) = ', &
	  size(OcnGrid%data%rAttr)
 endif



!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Set a decomposition of the atmosphere in the coupler "by hand"
! For this example, the coupler will split atmosphere points
! evenly between processors.
!
! number of local atmosphere points

  asize = (Nay * Nax)/mySize
  asize2 = asize

! (Nay *Nax)/mySize isnt an integer, give extra points to last proc.
  if(myProc == mySize - 1) then
    asize = asize + mod(Nay*Nax,mySize)
  endif

! find starting point in the numbering scheme
! numbering scheme is same as that used in atmosphere model.
  start(1) = (myProc * asize2) +1
  length(1) = asize

! write(stdout,*)myProc,asize2,asize,start(1)

! describe this information in a Global Map for the atmosphere.
  if(myProc==0)write(stdout,*) cplname, ":: Inializing AGSMap"
  call zeit_ci('Cagsmapinit')
! rml test of the copy
   call MCT_GSMap_init(testAGSMap,start,length,0,CPL_World,mycompid)
   call MCT_GSMap_copy(testAGSMap,AGSMap)
   call MCT_GSMap_clean(testAGSMap)
   print *,'Copied AGSMap'
  call zeit_co('Cagsmapinit')

! Test GlobalSegMapComms:

! Test GlobalSegMap broadcast:

  if(myProc==0) then

     DAGSMap%comp_id = AGSMap%comp_id
     DAGSMap%ngseg = AGSMap%ngseg
     DAGSMap%gsize = AGSMap%gsize

     allocate(DAGSMap%start(DAGSMap%ngseg),DAGSMap%length(DAGSMap%ngseg), &
	  DAGSMap%pe_loc(DAGSMap%ngseg), stat=ierr)
     if(ierr/=0) call die(cplname, "allocate(DAGSMap%start...)", ierr)

     do i=1,DAGSMap%ngseg
	DAGSMap%start(i) = AGSMap%start(i)
	DAGSMap%length(i) = AGSMap%length(i)
	DAGSMap%pe_loc(i) = AGSMap%pe_loc(i)
     end do

  endif

  call GlobalSegMap_bcast(DAGSMap, 0, CPL_World)

  if (.NOT.(GSMap_identical(DAGSMap,AGSMap))) then
     call die(cplname,"GSMap_identical(DAGSMap,AGSMap)")
  endif

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!  Describe OGSMap, the ocean grid decomposed in the coupler

! number of local oceanpoints
  osize = (Noy * Nox)/mySize
  osize2 = osize

! (Noy *Nox)/mySize isnt an integer, give extra points to last proc.
  if(myProc == mySize - 1) then
    osize = osize + mod(Noy*Nox,mySize)
  endif
! find starting point in the numbering scheme
! numbering scheme is same as that used in ocean model.
  start(1) = (myProc * osize2) +1
  length(1) = osize

! describe this information in a Global Map for the ocean.
  if(myProc==0)write(stdout,*) cplname, ":: Inializing OGSMap"
  call zeit_ci('Cogsmapinit')
   call MCT_GSMap_init(OGSMap,start,length,0,CPL_World,mycompid)
  call zeit_co('Cogsmapinit')
  call GSMap_test(OGSMap,"CPL::OGSMap",CPL_World,5000+myProc)

  ! lets exchange maps with the ocean
  call ExchangeMap(OGSMap,CPL_World,OCN_OGSMap,ocn_id,ierr)
  if(ierr/=0) call die(cplname,"call ExchangeMap")
  call GSMap_test(OCN_OGSMap,"CPL::OCN_OGSMap",CPL_World,5100+myProc)

  ! Compare this to sending and recieving maps
  if(myProc==0) then

     call GlobalSegMap_send(OGSMap,ocn_id,777)

     call GlobalSegMap_isend(OGSMap,ocn_id,888,sendrequest,ierr)
     if(ierr/=0) call die(cplname,"call GlobalSegMap_isend")

     ! Careful: sendrequest gets allocated with length 6 inside GSMap_isend
     allocate(sendstatus(MP_STATUS_SIZE,6),stat=ierr)
     if(ierr/=0) call die(cplname,"allocate(sendstatus)")

     call MPI_WAITALL(6,sendrequest,sendstatus,ierr)
     if(ierr/=0) call MP_Perr_die(cplname,"call MPI_WAITALL(sendrequest)",&
          ierr)

     deallocate(sendrequest,sendstatus,stat=ierr)
     if(ierr/=0) call die(cplname,"deallocate(sendrequest)")

  endif

  call GlobalSegMapToGlobalMap(OCN_OGSMap,OCN_OGMap,ierr)
  if(ierr/=0) call die(cplname,"GlobalSegMapToGlobalMap(OCN_OGSMap,OCN_OGMap)")
  call GMap_test(GMap=OCN_OGMap,Identifier="CPL->OCN_OGMap",device=4000+myProc)

  call GlobalMap_init_remote(rOGMap,OCN_OGMap%counts,&
       size(OCN_OGMap%counts),0,CPL_World,OCN_OGMap%comp_id)
  call GMap_test(GMap=rOGMap,Identifier="CPL::rOGMap",device=4100+myProc)

!!! test some GlobalSegMap functions
! write(*,*)myProc,'number of global segs is',MCT_GSMap_ngseg(OGSMap)
! write(*,*)myProc,'local size is',MCT_GSMap_lsize(OGSMap,CPL_World)
! write(*,*)myProc,'global size is',MCT_GSMap_gsize(OGSMap)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if(myProc==0) write(*,*) cplname, ":: Test GeneralGridComms"
call MCT_GGrid_bcast(AtmGrid,0,CPL_World)
call GGrid_test(AtmGrid,"CPL::Broadcast AtmGrid",3200+myProc)

call MCT_GGrid_scatter(OcnGrid,scatterGGrid,OGSMap,0,CPL_World)
call MCT_GGrid_gather(scatterGGrid,gatherGGrid,OGSMap,0,CPL_World)

if(myProc==0) then
   if(.NOT. GGrid_identical(OcnGrid,gatherGGrid,0.1) ) then
      call die(cplname,"GGrid Comms test failed")
   endif
   call MCT_GGrid_clean(gatherGGrid)
endif

   call MCT_GGrid_clean(scatterGGrid)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!SparseMatrix Read
! read in the SparseMatrix elements onto root
!
! This example reads in a2o
!
  if(myProc==0)write(stdout,*)" "
  if(myProc==0)write(stdout,*) cplname, ":: Reading SparseMatrix elements"
  if(myProc==0)write(stdout,*)" "
  call zeit_ci('CsmatReadnTest')
if(myProc==0) then
! NOTE: this is a custom routine, will not be part of MCT
   call ReadSparseMatrixAsc(DummySMat,"atmosphere_to_ocean_remap_file:", &
                            sMat_src_dims, sMat_dst_dims)
! Check that the values in the SparseMatrix match the values of the
! POP grid and the Gaussian grid
   if(sMat_src_dims(1) /= Nax) call die(cplname, &
        "sMat_src_dims(1) does not match Nax")
   if(sMat_src_dims(2) /= Nay) call die(cplname, &
        "sMat_src_dims(2) does not match Nay")
   if(sMat_dst_dims(1) /= Nox) call die(cplname, &
        "sMat_dst_dims(1) does not match Nox")
   if(sMat_dst_dims(2) /= Noy) call die(cplname, &
        "sMat_dst_dims(2) does not match Noy")

   nullify(DummyI) ! let first export routine create this
   Num = SparseMatrix_lsize(DummySMat)+1
   allocate(DummyR(Num), stat=ierr) ! try this one pre-created
   if(ierr /= 0) then
      write(stderr,'(2a,i8)') cplname,':: allocate(DummyR(...) failed, ierr=',ierr
      call die(cplname)
   endif

   write(stdout,'(2a)') cplname,' SparseMatrix export tests.  Compare with'
   call SMatrix_exportGlobalRowIndices(DummySMat, DummyI, Num)
   write(stdout,'(2a,i8)') cplname,':: exportGlobalRowIndices(): Num=',Num
   write(stdout,'(2a,i8)') cplname,':: SparseMatrix_lsize(DummySMat)=',&
	                   SparseMatrix_lsize(DummySMat)
   write(stdout,'(2a,i8)') cplname,':: exportGlobalRowIndices() 1st Row=',DummyI(1)
   write(stdout,'(2a,i8)') cplname,':: exportGlobalRowIndices() last Row=',DummyI(Num)

   call SMatrix_exportGlobalColumnInd(DummySMat, DummyI, Num)
   write(stdout,'(2a,i8)') cplname,':: exportGlobalColumnIndices(): Num=',Num
   write(stdout,'(2a,i8)') cplname,':: SparseMatrix_lsize(DummySMat)=',&
	                   SparseMatrix_lsize(DummySMat)
   write(stdout,'(2a,i8)') cplname,':: exportGlobalColumnIndices() 1st Col=',DummyI(1)
   write(stdout,'(2a,i8)') cplname,':: exportGlobalColumnIndices() last Col=',DummyI(Num)

   call SMatrix_exportMatrixElements(DummySMat, DummyR, Num)
   write(stdout,'(2a,i8)') cplname,':: exportMatrixElements(): Num=',Num
   write(stdout,'(2a,i8)') cplname,':: SparseMatrix_lsize(DummySMat)=',&
	                   SparseMatrix_lsize(DummySMat)
   write(stdout,'(2a,f10.8)') cplname,':: exportMatrixElements() 1st wgt=',&
	DummyR(1)
   write(stdout,'(2a,f10.8)') cplname,':: exportMatrixElements() last wgt=', &
	DummyR(Num)

   deallocate(DummyI, DummyR, stat=ierr)
   if(ierr /= 0) then
      write(stderr,'(2a,i8)') cplname,':: deallocate(DummyR(...) failed, ierr=',&
	                      ierr
      call die(cplname)
   endif

endif

  call zeit_co('CsmatReadnTest')
  if(myProc==0)write(stdout,*) cplname, ":: Done Reading elements"

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!FOR TESTING ONLY::::::
! now scatter the SparseMatrix from root to other coupler nodes
! according to the decomposition of the ocean grid (the Y)
!
  root=0
  if(myProc==0)write(stdout,*) cplname, ":: Testing SparseMatrix Gather"

   ! Testing GSMap scatter and gather
   call SparseMatrix_ScatterByRow(OGSMap, DummySMat, dMat, root, CPL_World, stat)
   call SparseMatrixDecompByRow(OGSMap, DummySMat, MatGSMap, root, CPL_World)
   call SparseMatrix_gather(dMat,gathersMat,MatGSMap,root,CPL_World)

   call MCT_GSMap_clean(MatGSMap)

   if(myProc==root) then
      if(.not. sMat_identical(DummySMat,gathersMat,1e-5)) then
         call die(cplname,"SMAT GATHER TEST FAILED!")
      endif
      call SparseMatrix_clean(gathersMat)
   endif

   ! Testing broadcast
   call SparseMatrix_bcast(DummySMat,root,CPL_World)

   call sMat_test(sMat=DummySMat,Identifier="CPL::Broadcast DummySMat-a2o", &
        device=8000+myProc)
   call sMat_test(sMat=dMat,Identifier="CPL::dMat-a2o",device=8100+myProc, &
        mycomm=CPL_World)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Build A2OMatPlus from root-centric sMat.  Specify matrix decomposition
! to be by row, following the ocean's GlobalSegMap (OGSMap)

  if(SparseMatrixPlus_initialized(A2OMatPlus)) then
     call die(cplname,"SparseMatrixPlus_initialized failed!")
  endif

  ! TESTING INIT_DISTRIBUTED:
  call SparseMatrixPlus_init(A2OMatPlus, dMat, AGSMap, OGSMap, &
                             root, CPL_World, mycompid)

  if(.NOT.SparseMatrixPlus_initialized(A2OMatPlus)) then
     call die(cplname,"SparseMatrixPlus_initialized failed!")
  endif

  call SparseMatrix_ScatterByRow(OGSMap, DummySMat, dMat_test, root, CPL_World, stat)

  if(.not. sMat_identical(dMat,dMat_test,1e-5)) then
     call die(cplname,"dMat has been unexpectedly altered by &
          &SparseMatrixPlus_init!")
  endif

  ! Clean the SparseMatrix
  call SparseMatrix_clean(DummySMat)
  call SparseMatrix_clean(dMat)
  call SparseMatrix_clean(dMat_test)

  if(myProc==0) write(stdout,*) cplname,':: Reading in O2A on root.'

! On the root, read in O2A ascii file into DummySMat:
  if(myProc==0) then
     call ReadSparseMatrixAsc(DummySMat,"ocean_to_atmosphere_remap_file:", &
                              sMat_src_dims, sMat_dst_dims)
     if(sMat_src_dims(1) /= Nox) call die(cplname, &
          "sMat_src_dims(1) does not match Nox")
     if(sMat_src_dims(2) /= Noy) call die(cplname, &
          "sMat_src_dims(2) does not match Noy")
     if(sMat_dst_dims(1) /= Nax) call die(cplname, &
          "sMat_dst_dims(1) does not match Nax")
     if(sMat_dst_dims(2) /= Nay) call die(cplname, &
          "sMat_dst_dims(2) does not match Nay")
  endif

  if(myProc==0) write(stdout,*) cplname,':: Finished reading in O2A on root.'

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Build O2AMatPlus from root-centric sMat.  Specify matrix decomposition
! to be by column, following the ocean's GlobalSegMap (OGSMap)

  call SparseMatrixPlus_init(O2AMatPlus, DummySMat, OGSMap, AGSMap, Yonly, &
                             root, CPL_World, mycompid)

  if(.NOT.SparseMatrixPlus_initialized(A2OMatPlus)) then
     call die(cplname,"O2AMatPlus has not been initialized!")
  endif

  if(myProc==root) then
     call sMat_test(sMat=DummySMat,Identifier="CPL::DummySMat-o2a", &
          device=8300+myProc)
     call SparseMatrix_clean(DummySMat)
  endif

!!!!!!!!!!!!!!!!!----------Attribute Vector for incoming Atmosphere data
! Build an Attribute Vector to hold data coming in from Atmosphere's
! decomposition to AGSMap
!
  if(myProc==0)write(stdout,*) cplname, ":: Initializing Attrvect"
  call zeit_ci('Catvecinit')
   call MCT_AtrVt_init(fromatm, &
       iList='gsindex',         &! local GSMap values
       rList=&
! height of first atm level
       "alevh:&
!  u wind
       &uwind:&
!  v wind
       &vwind:&
!  potential temp
       &pottem:&
!  specific humidity
       &s_hum:&
!  density
       &rho:&
!  barometric pressure
       &barpres:&
! surface pressure
       &surfp:&
!  net solar radiation
       &solrad:&
! downward direct visible radiation
       &dirvis:&
! downward diffuse visible radiation
       &difvis:&
! downward direct near-infrared radiation
       &dirnif:&
! downward diffuse near-infrared radiation
       &difnif:&
! downward longwave radiation
       &lngwv:&
! convective precip
       &precc:&
! large-scale precip
       &precl",&
       lsize=MCT_GSMap_lsize(AGSMap, Cpl_World))
  call zeit_co('Catvecinit')

!!! declare an AttrVect to hold atmosphere data on the ocean grid
! use AtrVect already declared so that it has the same Attributes
!
if(myProc==0)write(stdout,*) cplname, ":: Init output AtrVect"
  call MCT_AtrVt_init(fromatm_ocn, fromatm,MCT_GSMap_lsize(OGSMap, Cpl_World))
if(myProc==0)write(stdout,*) cplname, ":: Done with init of output vector"


!!!!!!!!!!!!!!!!!----------Attribute Vector for incoming Ocean data
! Build an Attribute Vector to hold data coming in from Ocean's Decomp
! decomposition to OGSMap
!
  if(myProc==0)write(stdout,*)cplname,":: Initializing Incoming Ocean Attrvect"

  call zeit_ci('fromocnAVinit')

  call MCT_AtrVt_init(fromocn,    &
       rList=&
!  East-West Gradient of Ocean Surface Height
       "dhdx:&
!  North-South Gradient of Ocean Surface Height
       &dhdy:&
!  Heat of Fusion of Ocean Water
       &Qfusion:&
!  Sea Surface Temperature
       &SST:&
!  Salinity
       &salinity:&
! East Component of the Surface Current
       &Uocean:&
! East Component of the Surface Current
       &Vocean",&
       lsize=MCT_GSMap_lsize(OGSMap, CPL_World))

  call zeit_co('fromocnAVinit')

!!!!!!!!!!!!!!!!!----------Attribute Vector for Ocean data on ATM grid

  call MCT_AtrVt_init(fromocn_atm,    &
       rList=&
!  East-West Gradient of Ocean Surface Height
       "dhdx:&
!  North-South Gradient of Ocean Surface Height
       &dhdy:&
!  Heat of Fusion of Ocean Water
       &Qfusion:&
!  Sea Surface Temperature
       &SST:&
!  Salinity
       &salinity:&
! East Component of the Surface Current
       &Uocean:&
! East Component of the Surface Current
       &Vocean",&
       lsize=MCT_GSMap_lsize(AGSMap, CPL_World))

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!--Build Router
!
! Intialize 2 routers:
! 1.) Between atmosphere and coupler using AGSMap.
! 2.) Between coupler and ocean using OGSMap

! These calls must be paired with similar calls in atm and ocn
!
  if(myProc==0)write(stdout,*) cplname, ":: Initializing Routers"

  call zeit_ci('CAtmRouterInit')
   call MCT_Router_init(atmo_id,AGSMap,CPL_World,Atm2Cpl)
  call zeit_co('CAtmRouterInit')

  call zeit_ci('COcnRouterInit')
   call MCT_Router_init(ocn_id,OGSMap,CPL_World,Cpl2Ocn)
  call zeit_co('COcnRouterInit')

! rml print router info
  if(myProc==0)call MCT_Router_print(Atm2Cpl,CPL_World,90)
  close(90)

  call Router_test(Atm2Cpl,"CPL::Atm2Cpl",7000+myProc)
  call Router_test(Cpl2Ocn,"CPL::Cpl2Ocn",7100+myProc)

  if(myProc==0)write(stdout,*) cplname, ":: Done Initializing Routers"

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!--Build Accumulator
  ACCA2O_rList="solrad:dirvis:difvis:dirnif:difnif:precc:precl"

  allocate(ACCA2O_rAction(7),stat=ierr)
  if(ierr/=0) call die(cplname,"allocate(ACCA20_rAction)",ierr)

  ACCA2O_rAction = (/MCT_SUM,MCT_AVG,MCT_AVG,MCT_AVG, &
                     MCT_AVG,MCT_AVG,MCT_AVG/)

  call MCT_Accumulator_init(aC=ACCA2O,          &
       rList=trim(ACCA2O_rList),                &
       rAction=ACCA2O_rAction,                  &
       lsize=MCT_GSMap_lsize(OGSMap,Cpl_World), &
       num_steps=nsteps)

  call Accumulator_test(ACCA2O,"CPL::ACCA2O",1000+myProc)

  deallocate(ACCA2O_rAction,stat=ierr)
  if(ierr/=0) call die(cplname,"deallocate(ACCA20_rAction)",ierr)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!		Done with Initialization Phase
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!:::::::BEGIN REMAPPING DATA FROM ATMOSPHERE::::::::!

do steps = 1,nsteps

!!!!!!!!!!!!!!!!!----------MCT_Recv
! Receive data into AGSMap associated aV fromatm
!
if((myProc==0).and.(steps==1)) then
   write(stdout,*) cplname, ":: Doing Distributed Recv"
endif
  call zeit_ci('Cmctrecv')
   call MCT_Recv(fromatm,Atm2Cpl)
  call zeit_co('Cmctrecv')
if((myProc==0).and.(steps==1)) then
   write(stdout,*) cplname, ":: Done with Recv"
endif
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!  Do the parallel A2O SparseMatrix-AttrVect multiply
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if((myProc==0).and.(steps==1)) then
   write(stdout,*) cplname, ":: Begin A2O sparsematrix mul"
endif
  call zeit_ci('CMatMul')
   call MCT_MatVecMul(fromatm, A2OMatPlus, fromatm_ocn)
  call zeit_co('CMatMul')
if((myProc==0).and.(steps==1)) then
   write(stdout,*) cplname, ":: Completed A2O sparsematrix mul"
endif
! Perform Accumulation
call accumulate(fromatm_ocn,ACCA2O)

enddo
call AttrVect_test(fromatm,"CPL::fromatm",2100+myProc)
call AttrVect_test(fromatm_ocn,"CPL::fromatm_ocn",2200+myProc)

if(myProc==1)write(stdout,*) cplname, ":: Testing point to point send and recv"

if(mySize>1) then

   if(myProc==1) then
      call AttrVect_Send(inAV=fromatm,dest=0,TagBase=123,comm=CPL_World,status=ierr)
      if(ierr/=0) call die(cplname,"AttrVect_Send- p1",ierr)

      call AttrVect_Recv(outAV=fromP1,dest=0,TagBase=124,comm=CPL_World,status=ierr)
      if(ierr/=0) call die(cplname,"AttrVect_Recv- p1",ierr)

      if(.not.AttrVect_identical(fromatm,fromP1,0.1)) then
         call die(cplname, "point to point comms failed")
      endif

      call MCT_AtrVt_clean(fromP1)

   endif
   if(myProc==0) then
      call AttrVect_Recv(outAV=fromP1,dest=1,TagBase=123,comm=CPL_World,status=ierr)
      if(ierr/=0) call die(cplname,"AttrVect_Recv- p0",ierr)

      call AttrVect_Send(inAV=fromP1,dest=1,TagBase=124,comm=CPL_World,status=ierr)
      if(ierr/=0) call die(cplname,"AttrVect_Send- p0",ierr)

      call MCT_AtrVt_clean(fromP1)

   endif

endif

 ! Send the accumulator registers to the ocean
 call zeit_ci('Cmctsend')
  call MCT_Send(ACCA2O%data,Cpl2Ocn)
 call zeit_co('Cmctsend')

 ! Check received globalmap values against expected ones
 j=1
 do i=1,MCT_GSMap_ngseg(AGSMap)
  if(myProc==AGSMap%pe_loc(i)) then
   do k=1,AGSMap%length(i)
      if(fromatm%iAttr(1,j) /= AGSMap%start(i)+k-1) then
         write(*,*) cplname, ':: MCT GSMap mismatch. Expected', &
          AGSMap%start(i)+k-1,'got ',fromatm%iAttr(1,j)
      endif
      j=j+1
   enddo
  endif
 enddo

 !::::::TESTING ACCUMULATOR COMM FUNCTIONS:::::!
 if(myProc==0) write(stdout,*) cplname,":: TESTING ACCUMULATOR_COMMS"

 call GlobalMap_init(OGMap,mycompid,MCT_GSMap_lsize(OGSMap,CPL_World), &
                      CPL_World)

 call MCT_Acc_gather(ACCA2O,GSgatherAcc,OGSMap,0,CPL_World,ierr)
 if(ierr/=0) call die(cplname,"call MCT_Acc_gather #1")

 ! TESTING COMMS USING GMAP
 call MCT_Acc_scatter(GSgatherAcc,scatterAcc,OGMap,0,CPL_World,ierr)
 if(ierr/=0) call die(cplname,"call MCT_Acc_scatter #2")

 call MCT_Acc_gather(scatterAcc,GgatherAcc,OGMap,0,CPL_World,ierr)
 if(ierr/=0) call die(cplname,"call MCT_Acc_gather #3")

 if(myProc==0) then
    if(.NOT.Accumulator_identical(GSgatherAcc,GgatherAcc,0.1)) then
       call die(cplname,"ACCUMULATOR SCATTER/GATHER #4 FAILED!")
    endif
 endif

 call MCT_Accumulator_clean(scatterAcc)
 ! DONE TESTING COMMS USING GMAP

 call MCT_Acc_scatter(GSgatherAcc,scatterAcc,OGSMap,0,CPL_World,ierr)
 if(ierr/=0) call die(cplname,"call MCT_Acc_scatter #5")

 if(.NOT.Accumulator_identical(ACCA2O,scatterAcc,0.1)) then
    call die(cplname,"ACCUMULATOR SCATTER/GATHER #6 FAILED!")
 endif

 call MCT_Acc_bcast(GSgatherAcc,0,CPL_World,ierr)
 if(ierr/=0) call die(cplname,"call MCT_Acc_bcast")

 call Accumulator_test(GSgatherAcc,"CPL::bcastAcc",1100+myProc)

 call AttrVect_test(ACCA2O%data,"CPL::ACCA2O%data",2300+myProc)

!::::::::DONE TESTING ACCUMULATOR COMMS:::::::::::::::::!

!::::::::TEST LOCAL REDUCE::::::::!
 call AttrVect_ReduceTest(GSgatherAcc%data,"GSgatherAcc%data on Root",2700)

 ! Lets prepare to do some neat integrals using MCT.
 ! First, we scatter both of the General Grids.
 call MCT_GGrid_scatter(AtmGrid, dAtmGrid, AGSMap, 0, CPL_World)
 call MCT_GGrid_scatter(OcnGrid, dOcnGrid, OGSMap, 0, CPL_World)

 if(myProc==0) call AttrVect_test(OcnGrid%data,"CPL::OcnGrid%data",2400+myProc)

 ! unmasked paired integral:
 call MCT_PairedSpatialIntegrals(inAv1=fromatm, outAv1=integratedAVect,    &
                                 GGrid1=dAtmGrid,WeightTag1="grid_area",   &
				 inAv2=fromatm_ocn, outAv2=integratedOVect,&
				 GGrid2=dOcnGrid, WeightTag2="grid_area",  &
				 SumWeights=.true., comm=CPL_World)
 if(myProc==0)then

    j=MCT_AtrVt_nreals(integratedAVect)
    do i=1,j,j-1
       write(stdout,'(3a,i2,a,f12.6)') cplname,':: Paired MCT ', &
	     'integral:  integratedAVect%rAttr(',i,',1)=', &
	     integratedAVect%rAttr(i,1)
    enddo

    k=MCT_AtrVt_nreals(integratedOVect)
    do i=1,k,k-1
	write(stdout,'(3a,i2,a,f12.6)') cplname,':: Paired MCT ', &
	     'integral:  integratedOVect%rAttr(',i,',1)=', &
	     integratedOVect%rAttr(i,1)
     end do
  endif

  call MCT_AtrVt_clean(integratedAVect)
  call MCT_AtrVt_clean(integratedOVect)

  ! unmasked paired average:
  call MCT_PairedSpatialAverages(inAv1=fromatm, outAv1=integratedAVect,    &
                                 GGrid1=dAtmGrid,WeightTag1="grid_area",   &
				 inAv2=fromatm_ocn, outAv2=integratedOVect,&
				 GGrid2=dOcnGrid, WeightTag2="grid_area",  &
				 comm=CPL_World)

if(myProc==0)then

   i=1
   write(stdout,'(3a,i2,a,f12.6)') cplname,':: Paired MCT ',&
	'average:  averagedAVect%rAttr(',i,',1)=', &
	integratedAVect%rAttr(i,1)

   write(stdout,'(3a,i2,a,f12.6)') cplname,':: Paired MCT ',&
	'average:  averagedOVect%rAttr(',i,',1)=', &
	integratedOVect%rAttr(i,1)

endif

 call MCT_AtrVt_clean(integratedAVect)
 call MCT_AtrVt_clean(integratedOVect)

 ! masked paired integral:
 call MCT_PairedMaskedSpatialIntegral(inAv1=fromatm, &
                           outAv1=integratedAVect,    &
                           GGrid1=dAtmGrid, &
			   SpatialWeightTag1="grid_area",   &
			   iMaskTags1="grid_imask", &
			   inAv2=fromatm_ocn, &
			   outAv2=integratedOVect, &
			   GGrid2=dOcnGrid, &
			   SpatialWeightTag2="grid_area", &
			   iMaskTags2="grid_imask", &
			   UseFastMethod=.true., &
			   SumWeights=.true., &
			   comm=CPL_World)

if(myProc==0)then

  j=MCT_AtrVt_nreals(integratedAVect)
  do i=1,j,j-1
     write(stdout,'(3a,i2,a,f12.6)') cplname,':: Paired masked MCT ',  &
     'integral: integratedAVect%rAttr(',i,',1)=', &
 	  integratedAVect%rAttr(i,1)
  end do

  k=MCT_AtrVt_nreals(integratedOVect)
  do i=1,k,k-1
     write(stdout,'(3a,i2,a,f12.6)') cplname,':: Paired masked MCT ',  &
     'integral: integratedOVect%rAttr(',i,',1)=', &
 	  integratedOVect%rAttr(i,1)
  end do

endif

 call MCT_AtrVt_clean(integratedAVect)
 call MCT_AtrVt_clean(integratedOVect)

 ! Masked paired average:
 call MCT_PairedMaskedSpatialAverages(inAv1=fromatm, &
                           outAv1=integratedAVect,    &
                           GGrid1=dAtmGrid, &
			   SpatialWeightTag1="grid_area",   &
			   iMaskTags1="grid_imask", &
			   inAv2=fromatm_ocn, &
			   outAv2=integratedOVect, &
			   GGrid2=dOcnGrid, &
			   SpatialWeightTag2="grid_area", &
			   iMaskTags2="grid_imask", &
			   UseFastMethod=.true., &
			   comm=CPL_World)

if(myProc==0)then

   i=1
   write(stdout,'(3a,i2,a,f12.6)') cplname,':: Paired masked MCT ',  &
	'average : averagedAVect%rAttr(',i,',1)=', &
	integratedAVect%rAttr(i,1)

   write(stdout,'(3a,i2,a,f12.6)') cplname,':: Paired masked MCT ',  &
	'average : averagedOVect%rAttr(',i,',1)=', &
	integratedOVect%rAttr(i,1)

endif

 call AttrVect_test(integratedAVect,"CPL::integratedAVect",myProc+2500)

 call MCT_AtrVt_clean(integratedAVect)
 call MCT_AtrVt_clean(integratedOVect)

 ! Now, receive Input AV from ocean (fromocn)
  if(myProc==0) write(stdout,*) cplname,':: Before MCT_RECV from ocean'
  call zeit_ci('RecvFromOcn')
  call MCT_Recv(fromocn,Cpl2Ocn)
  call zeit_co('RecvFromOcn')
  if(myProc==0) write(stdout,*) cplname,':: After MCT_RECV from ocean'

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!  Do the parallel O2A SparseMatrix-AttrVect multiply
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  if(myProc==0) write(stdout,*) cplname,":: Commencing O2A sparsematrix mul"
   call zeit_ci('O2AMatMul')
   call MCT_MatVecMul(fromocn, O2AMatPlus, fromocn_atm)
   call zeit_co('O2AMatMul')
  if(myProc==0) write(stdout,*) cplname,":: Completed O2A sparsematrix mul"

  ! Check the interpolated values
  do i=2,MCT_AtrVt_nreals(fromocn_atm)
     do j=1,MCT_AtrVt_lsize(fromocn_atm)
        if(abs(fromocn_atm%rAttr(1,j)-fromocn_atm%rAttr(i,j)) > 1e-4) then
           write(stderr,*)  cplname, ":: Interpolation Error", &
                fromocn_atm%rAttr(1,j), fromocn_atm%rAttr(i,j), i, j
           call die(cplname,"Interpolation Error")
        endif
     enddo
  enddo

  ! TEST MAPPING FOR HMV

!  call AttrVect_gather(fromocn_atm,gatherAV_atm,AGSMap, &
!                      0,CPL_World,ierr)
  call AttrVect_gather(fromocn_atm,gatherAV_atm,AGSMap, &
                      0,CPL_World,ierr,99.0_FP)                ! rml test

  if(myProc == 0) then
     unit = luavail() + 9500
     write(unit,*) Nax, Nay
     k=0
     do i=1,Nax
        do j=1,Nay
           k=k+1
           write(unit,*) gatherAV_atm%rAttr(1,k)
        enddo
     enddo
     call MCT_AtrVt_clean(gatherAV_atm)
  endif

if(myProc==0)write(stdout,*) cplname, ":: All Done, cleanup"
  call zeit_ci('Ccleanup')

  ! Clean MCT datatypes
  if(myProc==0) then
     call MCT_GGrid_clean(AtmGrid)
     call MCT_GGrid_clean(OcnGrid)
     call MCT_Accumulator_clean(GgatherAcc)
  endif

  call MCT_Accumulator_clean(GSgatherAcc)
  call MCT_Accumulator_clean(scatterAcc)
  call GlobalMap_clean(rOGMap)
  call GlobalMap_clean(OCN_OGMap)
  call GlobalMap_clean(OGMap)
  call MCT_GGrid_clean(dAtmGrid)
  call MCT_GGrid_clean(dOcnGrid)
  call MCT_GSMap_clean(AGSMap)
  call MCT_GSMap_clean(OGSMap)
  call MCT_GSMap_clean(DAGSMap)
  call MCT_GSMap_clean(OCN_OGSMap)
  call MCT_Router_clean(Atm2Cpl)
  call MCT_Router_clean(Cpl2Ocn)
  call SparseMatrixPlus_clean(A2OMatPlus)
  call SparseMatrixPlus_clean(O2AMatPlus)
  call MCT_Accumulator_clean(ACCA2O)
  call MCT_AtrVt_clean(fromatm)
  call MCT_AtrVt_clean(fromatm_ocn)
  call MCT_AtrVt_clean(fromocn)
  call MCT_AtrVt_clean(fromocn_atm)
  call MCTWorld_clean()

  call zeit_co('Ccleanup')

  call zeit_allflush(CPL_World,0,46)

  initialized= MCTWorld_initialized()
  if (myProc==0)write(stdout,*) cplname, &
     ":: MCTWorld initialized=",initialized
  if(initialized) call die(cplname, "mct still initialized")


end subroutine














