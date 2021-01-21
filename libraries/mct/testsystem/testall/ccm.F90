!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: ccm.F90,v 1.13 2004-06-02 22:22:51 eong Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !ROUTINE: ccm3  -- dummy atmosphere model for unit tester
!
! !DESCRIPTION:
! An atmosphere model subroutine to test functionality of MPH and MCT.
!
! !INTERFACE:
      subroutine ccm3 (CCM_World)
!
! !USES:
!
      use MPH_all
!---Field Storage DataType and associated methods
#ifndef SYSOSF1
      use m_AttrVect,only    : AttrVect_exportIListToChar => exportIListToChar
      use m_AttrVect,only    : AttrVect_exportRListToChar => exportRListToChar
#endif
      use m_AttrVect,only    : MCT_AtrVt_init => init
      use m_AttrVect,only    : MCT_AtrVt_clean => clean
      use m_AttrVect,only    : MCT_AtrVt_lsize => lsize
      use m_AttrVect,only    : MCT_AtrVt_nReal => nRAttr
      use m_AttrVect,only    : MCT_AtrVt_nInteger => nIAttr
      use m_AttrVect,only    : AttrVect_zero => zero
      use m_AttrVect,only    : AttrVect_Copy => Copy
      use m_AttrVect,only    : AttrVect
!---Coordinate Grid DataType and associated methods
      use m_GeneralGrid,only : GeneralGrid
      use m_GeneralGrid,only : MCT_GGrid_init => init
      use m_GeneralGrid,only : MCT_GGrid_cart => initCartesian
      use m_GeneralGrid,only : MCT_GGrid_clean => clean
      use m_GeneralGrid,only : MCT_GGrid_dims => dims
      use m_GeneralGrid,only : MCT_GGrid_lsize => lsize
      use m_GeneralGrid,only : MCT_GGrid_indexIA => indexIA
      use m_GeneralGrid,only : MCT_GGrid_indexRA => indexRA
      use m_GeneralGrid,only : MCT_GGrid_exportIAttr => exportIAttr
      use m_GeneralGrid,only : MCT_GGrid_importIAttr => importIAttr
      use m_GeneralGrid,only : MCT_GGrid_exportRAttr => exportRAttr
      use m_GeneralGrid,only : MCT_GGrid_importRAttr => importRAttr
      use m_GeneralGrid,only : MCT_GGrid_SortPermute => sortpermute
      use m_GeneralGridComms,only: MCT_GGrid_send => send
      use m_GeneralGridComms,only: MCT_GGrid_scatter => scatter
!---MCT Spatial Integral services...
      use m_SpatialIntegral,only : MCT_SpatialIntegral => SpatialIntegral
      use m_SpatialIntegral,only : MCT_SpatialAverage => SpatialAverage
      use m_SpatialIntegral,only : MCT_MaskedSpatialIntegral => &
	                                              MaskedSpatialIntegral
      use m_SpatialIntegral,only : MCT_MaskedSpatialAverage => &
	                                              MaskedSpatialAverage
!---Domain Decomposition Descriptor DataType and associated methods
      use m_GlobalSegMap,only: MCT_GSMap_init => init
      use m_GlobalSegMap,only: MCT_GSMap_clean => clean
      use m_GlobalSegMap,only: MCT_GSMap_gsize => gsize
      use m_GlobalSegMap,only: MCT_GSMap_lsize => lsize
      use m_GlobalSegMap,only: MCT_GSMap_ngseg => ngseg
      use m_GlobalSegMap,only: MCT_GSMap_nlseg => nlseg
      use m_GlobalSegMap,only: GlobalSegMap
!---Global-to-Local indexing services
      use m_GlobalToLocal,only: MCT_GStoL => GlobalToLocalIndices
      use m_GlobalToLocal,only: MCT_GStoLI => GlobalToLocalIndex
!---Component Model Registry
      use m_MCTWorld,only: ThisMCTWorld
      use m_MCTWorld,only: MCTComponentRootRank => ComponentRootRank
      use m_MCTWorld,only: MCTWorld_init => init
      use m_MCTWorld,only: MCTWorld_clean => clean
!---Intercomponent communications scheduler
      use m_Router,only: Router
      use m_Router,only: MCT_Router_init => init
      use m_Router,only: MCT_Router_clean => clean
      use m_Transfer,only: MCT_Send => send
!---mpeu List datatype
      use m_List, only : List
      use m_List, only : List_clean => clean
      use m_List, only : List_copy => copy
      use m_List, only : List_exportToChar => exportToChar
!---mpeu routines for MPI communications
      use m_mpif90
!---mpeu timers
      use m_zeit
!---mpeu error handling
      use m_die
!---mpeu stderr/stdout handling
      use m_stdio
!---Tester Modules
      use m_ACTEST, only : Accumulator_test => testall
      use m_ACTEST, only : Accumulator_identical => identical
      use m_AVTEST, only : AttrVect_test => testall
      use m_AVTEST, only : AttrVect_identical => Identical
      use m_GGRIDTEST, only : GGrid_test      => testall
      use m_GGRIDTEST, only : GGrid_identical => Identical
      use m_GMAPTEST, only : GMap_test => testall
      use m_GSMAPTEST, only : GSMap_test => testall
      use m_MCTWORLDTEST, only : MCTWorld_test => testall
      use m_ROUTERTEST, only : Router_test => testall
      use m_SMATTEST, only : sMat_test => testall
      use m_SMATTEST, only : sMat_identical   => Identical

      implicit none

! !INPUT PARAMETERS:

      integer,intent(in) :: CCM_World  ! communicator for ccm

!
! !REVISION HISTORY:
!        Oct00 - Yun (Helen) He and Chris Ding, NERSC/LBNL - initial MPH-only version
!      19Nov00 - R. Jacob <jacob@mcs.anl.gov> -- interface with mct
!      06Feb01 - J. Larson <larson@mcs.anl.gov> - slight mod to
!                accomodate new interface to MCT_GSMap_lsize().
!      08Feb01 - R. Jacob <jacob@mcs.anl.gov> -- use MCT_Send
!      23Feb01 - R. Jacob <jacob@mcs.anl.gov> -- expand size of AtrVect
!                and add a check for transfer.
!      08Jun01 - R. Jacob <jacob@mcs.anl.gov> initialize a General Grid
!      11Jun01 - Jacob/Larson <jacob@mcs.anl.gov> Send a General Grid to cpl
!      15Feb02 - R.Jacob <jacob@mcs.anl.gov> -- new MCTWorld_init interface.
!      13Jun02 - J. Larson <larson@mcs.anl.gov> - More GeneralGrid usage,
!                including import/export of attributes, and sorting by
!                coordinate.  Also added mpeu error handling and stdout/stderr.
!      18Jun02 - J. Larson <larson@mcs.anl.gov> - Introduction of Spatial
!                Integral/Average services.
!      18Jul02 - E. Ong <eong@mcs.anl.gov> - Use a gaussian atmosphere grid
!EOP ___________________________________________________________________
      character(len=*), parameter :: ccmname='ccm3'

!----------------------- MPH vars
      integer :: myProc, myProc_global, root
      integer :: Global_World
      integer :: coupler_id
      integer :: mySize, ncomps, mycompid

!----------------------- MCT and dummy model vars
      integer :: i,j,n,k,ier

!  SparseMatrix dimensions and Processor Layout
      integer :: Nax, Nay                     ! Atmosphere lons, lats
      integer :: Nox, Noy                     ! Ocean lons, lats
      integer :: NPROCS_LATA, NPROCS_LONA     ! Processor layout

!  Number of steps to send to coupler

      integer :: steps
      integer, parameter :: nsteps = 10

!  Arrays used to initialize the MCT GlobalSegMap
      integer,dimension(:),pointer :: starts
      integer,dimension(:),pointer :: lengths
      integer,dimension(:,:),pointer :: myglobalmap
!     integer,dimension(:),pointer :: lstart,llength

!  Arrays used to test MCT import/export routines
      integer, dimension(:), pointer :: dummyI
      real,    dimension(:), pointer :: dummyR
      integer :: latindx,lonindx,gridindx,status
      integer :: length

!  Index to AtmGrid area element dA
      integer :: dAindx

!  Set the value of pi
      real, parameter :: pi =  3.14159265359

!  Atmosphere GSMap
      type(GlobalSegMap) :: GSMap
!  Router from Atm to Cpl
      type(Router) :: Atm2Cpl
!  AttrVect for atm data
      type(AttrVect) :: a2coupler
!  AttrVect for atm data used to test spatial integration services
      type(AttrVect) :: a2coupler2, integratedA2CaV
!  The atmosphere's grid
      type(GeneralGrid) :: AtmGrid, dAtmGrid

! Test Grids and test dummy vars
      type(GeneralGrid) :: AtmGridExactCopy, dAtmGridExactCopy
      type(GeneralGrid) :: AtmCartGrid
      type(List) :: cartlist,cartindex,cartother,cartweight
      integer,dimension(:),pointer :: cartdims
      real,dimension(:),pointer :: dummyatmlats, dummyatmlons
      real,dimension(:),pointer :: dummycartlats, dummycartlons
      real,dimension(:,:),pointer :: cartaxis
      real,dimension(:),allocatable :: gauss_wgt, gauss_lat
      logical,dimension(:),pointer :: cartdescend
      integer :: axlength,aylength,cxlength,cylength
      real :: dlon

!  Spatial Integral Temporary Variables

#ifdef MPE
#include "mpe.h"
#endif

!-------------------------------------------------------

  call MPI_COMM_DUP (MPI_COMM_WORLD, Global_World, ierr)
  call MPI_COMM_RANK (MPI_COMM_WORLD, myProc_global, ierr)
  call MPI_COMM_RANK (CCM_World, myProc, ierr)
  if (myProc==0) call MPH_redirect_output ('ccm')
! write(*,*) myProc, ' in ccm === ', myProc_global, ' in global'
! write(*,*) 'MPH_local_proc_id()=', MPH_local_proc_id_ME_SE()
! write(*,*) 'MPH_global_proc_id()=', MPH_global_proc_id()
! write(*,*) 'MPH_component_id()=', MPH_component_id_ME_SE()

! if profiling with the MPE lib
#ifdef MPE
  call mpe_logging_init(myProc_global,init_s,init_e,gsmi_s,gsmi_e,&
        atri_s,atri_e,routi_s,routi_e,send_s,send_e,recv_s,recv_e,&
     	clean_s,clean_e)
#endif

!  Get the coupler's component id
  coupler_id = MPH_get_component_id("coupler")

!-------------------------------------------------------
!  Begin using MCT

!!!!!!!!!!!!!!!!!----------MCTWorld
! initialize the MCTWorld
  ncomps=MPH_total_components()
  mycompid=MPH_component_id_ME_SE()

! all components must call this
! if(myProc==0)write(stdout,*)"Initializing MCTWorld"

  call zeit_ci('Aworldinit')
   call MCTWorld_init(ncomps,MPI_COMM_WORLD,CCM_World,mycompid)
  call zeit_co('Aworldinit')

  call MCTWorld_test("CCM::MCTWorld",6100+myProc)

  ! Get the Sparse Matrix dimensions and processor layout
  root = MCTComponentRootRank(coupler_id,ThisMCTWorld)
  call MPI_BCAST(Nax,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(Nay,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(Nox,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(Noy,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(NPROCS_LATA,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(NPROCS_LONA,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)

  ! check to see if there are enough processors
  call MPI_COMM_SIZE(CCM_World, mySize, ierr)
  if (mySize /= NPROCS_LATA*NPROCS_LONA) then
      write(*,*)'ERROR: wrong number of processors'
      write(*,*)'found ',mySize,' Needed',NPROCS_LATA*NPROCS_LONA
       stop
  endif

! Number the grid 1 to Nax*Nay, starting
! in the South Pole and proceeding along a latitude and
! then from south to north.
! NOTE:  This may not look like much but its very important.
! This is where the numbering scheme for each grid point,
! on which all of MCT is based, is defined.  The points
! are numbered from 1 to Nax*Nay starting at the south
! pole (j=1) and moving west to east and south to north

  allocate(myglobalmap(Nax,Nay),stat=ierr)
  if(ierr/=0) call die(ccmname, "allocate(myglobalmap)", ierr)
  n=0
  do j=1,Nay
    do i= 1,Nax
      n=n+1
      myglobalmap(i,j) = n
     enddo
  enddo

!!!!!!!!!!!!!!!!!----------General Grid

! Load a Gaussian atmosphere general grid
! Note: The following block of code is for the root process.

if(myProc==0) then

  write(*,*) ccmname, ":: Initializing Atm General Grid"

  call convertgauss(AtmGrid, Nax, Nay)


  call GGrid_test(AtmGrid,"CCM::AtmGrid",3300+myProc)

  ! Set up a copy for later on...
  call MCT_GGrid_init(AtmGridExactCopy,AtmGrid,MCT_GGrid_lsize(AtmGrid))
  call AttrVect_Copy(aVin=AtmGrid%data,aVout=AtmGridExactCopy%data)

!::::::::::::::::::::::::::::::::::::!
!:::::TEST INITCARTESIAN:::::::::::::!
!::::::::::::::::::::::::::::::::::::!

  ! Test initCartesian from AtmGrid values

  call List_copy(cartlist,AtmGrid%coordinate_list)
  call List_copy(cartweight,AtmGrid%weight_list)
  call List_copy(cartother,AtmGrid%other_list)
  call List_copy(cartindex,AtmGrid%index_list)

  allocate(cartdims(2),cartaxis(MAX(Nay,Nax),2), &
             gauss_wgt(Nay),gauss_lat(Nay),cartdescend(2),stat=ierr)
  if(ierr/=0) call die(ccmname,"allocate(cart...)",ierr)

  cartdims(1) = Nay
  cartdims(2) = Nax

  ! Obtain the gaussian latitudes and longitudes from convertgauss.F90
  call gquad(Nay,gauss_lat,gauss_wgt)
  do i=1,Nay
     cartaxis(i,1) = (0.5*pi - gauss_lat(Nay+1-i)) * 180./pi
  enddo

  dlon = 360./Nax
  do i=1,Nax
     cartaxis(i,2) = (i-1)*dlon
  enddo

  cartdescend=.false.

  call MCT_GGrid_cart(GGrid=AtmCartGrid, &
       CoordChars=List_exportToChar(cartlist), &
       CoordSortOrder="grid_center_lat:grid_center_lon", &
       descend=cartdescend, &
       WeightChars=List_exportToChar(cartweight), &
       OtherChars=List_exportToChar(cartother), &
       IndexChars=List_exportToChar(cartindex), &
       Dims=cartdims, &
       AxisData=cartaxis)

  call GGrid_test(AtmCartGrid,"CCM::AtmCartGrid",3600+myProc)

  call MCT_GGrid_SortPermute(AtmCartGrid)
  call MCT_GGrid_SortPermute(AtmGrid)

  allocate(dummycartlats(MCT_GGrid_lsize(AtmCartGrid)), &
           dummycartlons(MCT_GGrid_lsize(AtmCartGrid)), &
           dummyatmlats(MCT_GGrid_lsize(AtmGrid)), &
           dummyatmlons(MCT_GGrid_lsize(AtmGrid)), &
           stat=ierr)
  if(ierr/=0) call die(ccmname, "allocate(dummy...)", ierr)

  call MCT_GGrid_exportRAttr(AtmCartGrid, 'grid_center_lat', &
                             dummycartlats,cylength)
  call MCT_GGrid_exportRAttr(AtmCartGrid, 'grid_center_lon', &
                             dummycartlons,cxlength)
  call MCT_GGrid_exportRAttr(AtmGrid, 'grid_center_lat', &
                             dummyatmlats, aylength)
  call MCT_GGrid_exportRAttr(AtmGrid, 'grid_center_lon', &
                             dummyatmlons, axlength)

  if((aylength/=cylength).or.(axlength/=cxlength)) then
     call die(ccmname,"Atmosphere GeneralGrid failed the first LENGTH test")
  endif

  if((aylength/=Nay*Nax).or.(axlength/=Nax*Nay)) then
     call die(ccmname,"Atmosphere GeneralGrid failed the second LENGTH test")
  endif

  ! The lowest limit I have found for this is 1e-5 on the Absoft compiler
  ! This is not as precise as the lons because of round off
  do i=1,Nay*Nax
     if( abs(dummycartlats(i)-dummyatmlats(i)) > 1e-5 ) then
        call die(ccmname,"GeneralGrid INITCARTESIAN failed the LAT test")
     endif
  enddo
  do i=1,Nax*Nay
     if( abs(dummycartlons(i)-dummyatmlons(i)) > 1e-8 ) then
        call die(ccmname,"GeneralGrid INITCARTESIAN failed the LON test")
     endif
  enddo

  deallocate(cartdims,cartaxis,cartdescend,dummycartlats,dummycartlons, &
             dummyatmlats,dummyatmlons,gauss_wgt,gauss_lat,stat=ierr)
  if(ierr/=0) call die(ccmname,"deallocate(cart...)",ierr)

  call List_clean(cartlist)
  call List_clean(cartweight)
  call List_clean(cartindex)
  call List_clean(cartother)
!::::::::::::::::::::::::::::::::::::!
!:::::DONE WITH INITCARTESIAN::::::::!
!::::::::::::::::::::::::::::::::::::!

! Write out the basic things we initialized

  write(stdout,'(3a,i1)') ccmname, &
       ":: Initialized Atm GeneralGrid variable AtmGrid.", &
       "Number of dimensions = ", MCT_GGrid_dims(AtmGrid)
  write(stdout,'(2a,i8)') ccmname, &
       ":: Number of grid points in AtmGrid=", &
       MCT_GGrid_lsize(AtmGrid)
  write(stdout,'(2a,i8)') ccmname, &
       ":: Number of latitudes Nay=", Nay
  write(stdout,'(2a,i8)') ccmname, &
       ":: Number of longitudes Nax=", Nax
  write(stdout,'(2a,i8)') ccmname, &
       ":: Number of grid points Nax*Nax=", Nay*Nax
  write(stdout,'(3a)') ccmname, &
       ":: AtmGrid%coordinate_list = ", &
       List_exportToChar(AtmGrid%coordinate_list)
  write(stdout,'(3a)') ccmname, &
       ":: AtmGrid%weight_list = ", &
       List_exportToChar(AtmGrid%weight_list)
  write(stdout,*) ccmname, &                 ! * is used for SUPER_UX compatibility
       ":: AtmGrid%other_list = ", &
       List_exportToChar(AtmGrid%other_list)
  write(stdout,'(3a)') ccmname, &
       ":: AtmGrid%index_list = ", &
       List_exportToChar(AtmGrid%index_list)
  write(stdout,'(2a,i3)') ccmname, &
       ":: Number of integer attributes stored in AtmGrid=", &
       MCT_AtrVt_nInteger(AtmGrid%data)
  write(stdout,'(2a,i3)') ccmname, &
       ":: Total Number of real attributes stored in AtmGrid=", &
       MCT_AtrVt_nReal(AtmGrid%data)

! Get AtmGrid attribute indicies
 latindx=MCT_GGrid_indexRA(AtmGrid,'grid_center_lat')
 lonindx=MCT_GGrid_indexRA(AtmGrid,'grid_center_lon')

! NOTE: The integer attribute GlobGridNum is automatically
! appended to any General Grid.  Store the grid numbering
! scheme (used in the GlobalSegMap) here.
 gridindx=MCT_GGrid_indexIA(AtmGrid,'GlobGridNum')

 do j=1,Nay
  do i=1,Nax
     n=myglobalmap(i,j)
     AtmGrid%data%iAttr(gridindx,n)=n
  enddo
 enddo

! Check the weight values of the grid_area attribute

  dAindx = MCT_GGrid_indexRA(AtmGrid, 'grid_area')

  write(stdout,'(2a)') ccmname, &
       ':: Various checks of GeneralGrid AtmGrid Weight data...'
  write(stdout,'(2a,f12.6)') ccmname, &
       ':: direct ref--AtmGrid 1st dA entry=.', &
       AtmGrid%data%rAttr(dAindx,1)
  write(stdout,'(2a,f12.6)') ccmname, &
       ':: direct ref--AtmGrid last dA entry=.', &
       AtmGrid%data%rAttr(dAindx,MCT_GGrid_lsize(AtmGrid))
  write(stdout,'(2a,f12.6)') ccmname, &
       ':: Sum of dA(1,...,Nax*Nay)=.', &
       sum(AtmGrid%data%rAttr(dAindx,:))
  write(stdout,'(2a,f12.6)') ccmname, &
       ':: Unit Sphere area 4 * pi=.', 4.*pi

! Check on coordinate values (and check some export functions, too...)

  allocate(dummyR(MCT_GGrid_lsize(AtmGrid)), stat=ierr)
  if(ierr/=0) call die(ccmname, "allocate(myglobalmap)", ierr)

  call MCT_GGrid_exportRAttr(AtmGrid, 'grid_center_lat', dummyR, length)

  write(stdout,'(2a)') ccmname, &
       ':: Various checks of GeneralGrid AtmGrid coordinate data...'
  write(stdout,'(2a,i8)') ccmname, &
       ':: No. exported AtmGrid latitude values =.',length
  write(stdout,'(2a,f12.6)') ccmname, &
       ':: export--AtmGrid 1st latitude=.',dummyR(1)
  write(stdout,'(2a,f12.6)') ccmname, &
       ':: export--AtmGrid last latitude=.',dummyR(length)
  write(stdout,'(2a,f12.6)') ccmname, &
       ':: direct ref--AtmGrid 1st latitude=.', &
       AtmGrid%data%rAttr(latindx,1)
  write(stdout,'(2a,f12.6)') ccmname, &
       ':: direct ref--AtmGrid last latitude=.', &
       AtmGrid%data%rAttr(latindx,length)
  write(stdout,'(2a,f12.6)') ccmname, &
       ':: direct ref--AtmGrid 1st longitude=.', &
       AtmGrid%data%rAttr(lonindx,1)
  write(stdout,'(2a,f12.6)') ccmname, &
       ':: direct ref--AtmGrid last longitude=.', &
       AtmGrid%data%rAttr(lonindx,MCT_GGrid_lsize(AtmGrid))
  write(stdout,'(2a)') ccmname, &
       ':: End checks of GeneralGrid AtmGrid coordinate data.'

! Check the GlobalGridNum values:

 allocate(dummyI(MCT_GGrid_lsize(AtmGrid)), stat=ierr)
 if(ierr/=0) call die(ccmname, "allocate(dummyI)", ierr)

 call MCT_GGrid_exportIAttr(AtmGrid, 'GlobGridNum', dummyI, length)

  write(stdout,'(2a,i8)') ccmname, &
       ':: No. exported AtmGrid GlobalGridNum values =.',length
  write(stdout,'(2a,i8)') ccmname, &
       ':: export--AtmGrid 1st GlobalGridNum =.', dummyI(1)
  write(stdout,'(2a,i8)') ccmname, &
       ':: export--AtmGrid last GlobalGridNum =.', dummyI(length)
  write(stdout,'(2a,i8)') ccmname, &
       ':: direct ref--AtmGrid 1st GlobalGridNum =.', &
       AtmGrid%data%iAttr(gridindx,1)
  write(stdout,'(2a,i8)') ccmname, &
       ':: direct ref--AtmGrid last GlobalGridNum =.', &
       AtmGrid%data%iAttr(gridindx,length)

! send the atmosphere's grid from the atmosphere's root to the
! coupler's root.  1400 is the randomly chosen tag base.
  call MCT_GGrid_send(AtmGrid,coupler_id,1400,status=status)

! Clean up arrays used for GGrid tests:

  deallocate(dummyI, dummyR, stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8)') ccmname, &
     ':: ERROR--deallocate(dummyI,dummyR) failed with ierr=', ierr
     call die(ccmname)
  endif

endif    ! if(myProc==0)

!!!!!!!!!!!!!!!!!----------GlobalSegMap
! Get ready to initialize the GlobalSegMap
!
!
! Go and define the starts and lengths according to the
! decomposition we want

  call FoldOverDecomp(myglobalmap,starts,lengths,Nax,Nay)

! now put the information in a GlobalSegMap.
! if(myProc==0)write(*,*)"Inializing GSMap"
  call zeit_ci('Agsmapinit')
   call MCT_GSMap_init(GSMap,starts,lengths,0,CCM_World,mycompid)
  call zeit_co('Agsmapinit')

! Try using some GSMap functions.
! write(*,*)myProc,'number of global segs is',MCT_GSMap_ngseg(GSMap)
! write(*,*)myProc,'number of local segs is', MCT_GSMap_nlseg(GSMap,myProc)
! write(*,*)myProc,'local size is',MCT_GSMap_lsize(GSMap,CCM_World)
! write(*,*)myProc,'global size is',MCT_GSMap_gsize(GSMap)

! call MCT_GStoL(GSMap,CCM_World,lstart,llength)
! if(myProc==0) then
!   do i=1,GSMap%ngseg
!    write(*,*)i,GSMap%start(i),GSMap%pe_loc(i)
!      if(myProc==GSMap%pe_loc(i)) then
!  	point = GSMap%start(i)
!  	write(*,*)"MCTGStoLI",MCT_GStoLI(GSMap,point,CCM_World)
!      endif
!   enddo
! endif


!!!!!!!!!!!!!!!!!----------Attribute Vector
! intialize an attribute vector
! if(myProc==0)write(*,*)"Initializing Attrvect"

  call zeit_ci('Aatvecinit')
!  declare an attrvect to hold all atm model outputs
!  an identical decleration needs to be made in the coupler
!  NOTE:  the size of the AttrVect is set to be the local
!  size of the GSMap.
  call MCT_AtrVt_init(a2coupler, &
       iList='gsindex',		&! local GSMap values
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
       lsize=MCT_GSMap_lsize(GSMap, CCM_World))
  call zeit_co('Aatvecinit')

! create a second attribute vector to test copying
  call MCT_AtrVt_init(a2coupler2, rList="conpre:precl:uwind:vwind", &
                      lsize=MCT_GSMap_lsize(GSMap,CCM_World))
  call AttrVect_zero(a2coupler2)

if(myProc==0)then
#ifndef SYSOSF1
  write(stdout,*) ccmname,':: a2coupler%rList = ', &
       AttrVect_exportRListToChar(a2coupler)
  write(stdout,*) ccmname,':: a2coupler%iList = ', &
       AttrVect_exportIListToChar(a2coupler)
#endif
  write(stdout,'(2a,i8)') ccmname, &
       ':: a2coupler length = ', MCT_AtrVt_lsize(a2coupler)
  write(stdout,'(2a,i8)') ccmname, &
       ':: MCT_GSMap_lsize = ', MCT_GSMap_lsize(GSMap, CCM_World)
endif

! load the local values of the GSMap into gsindex for checking
  j=1
  do i=1,MCT_GSMap_ngseg(GSMap)
    if(myProc==GSMap%pe_loc(i)) then
     do k=1,GSMap%length(i)
	a2coupler%iAttr(1,j)=GSMap%start(i)+k-1
	j=j+1
     enddo
    endif
  enddo

! put some data in the Attribute Vector
  do j=1,MCT_AtrVt_nReal(a2coupler)
    do i=1,MCT_GSMap_lsize(GSMap, CCM_World)
       a2coupler%rAttr(j,i)=30.
    enddo
  enddo

! test Attribute vector copying
if(myProc==0)write(stdout,'(2a)') ccmname,':: Test aV copy services'
if(myProc==0)write(stdout,*) ccmname, ':: initial values', &
     a2coupler2%rAttr(1,1), a2coupler2%rAttr(2,1), &
     a2coupler2%rAttr(3,1), a2coupler2%rAttr(4,1)

! copy all shared attributes
call AttrVect_Copy(a2coupler,a2coupler2)
if(myProc==0)write(stdout,*) ccmname, ':: copy shared', &
     a2coupler2%rAttr(1,1), a2coupler2%rAttr(2,1), &
     a2coupler2%rAttr(3,1), a2coupler2%rAttr(4,1)
call AttrVect_zero(a2coupler2)

! copy only one attribute
call AttrVect_Copy(a2coupler,a2coupler2,"precl")
if(myProc==0)write(stdout,*) ccmname, ':: copy one real', &
     a2coupler2%rAttr(1,1), a2coupler2%rAttr(2,1), &
     a2coupler2%rAttr(3,1),a2coupler2%rAttr(4,1)
call AttrVect_zero(a2coupler2)

! copy two with a translation
call AttrVect_Copy(a2coupler,a2coupler2,"precc:vwind","conpre:vwind")
if(myProc==0)write(stdout,*) ccmname, ':: copy two real, translate', &
     a2coupler2%rAttr(1,1), a2coupler2%rAttr(2,1), &
     a2coupler2%rAttr(3,1),a2coupler2%rAttr(4,1)


! Remember AtmGrid?  This was created only on the root.  To do
! some neat integrals, we must scatter it using MCT onto the
! same decomposition as a2coupler:

  call MCT_GGrid_scatter(AtmGrid, dAtmGrid, GSMap, 0, CCM_World)
  call MCT_GGrid_scatter(AtmGridExactCopy,dAtmGridExactCopy,GSMap,0,CCM_World)

  if(myProc==0) then
     if(.NOT.GGrid_identical(AtmGrid,AtmGridExactCopy,1e-5)) then
        call die(ccmname,"AtmGrid unexpectedly altered!!!")
     endif
  endif

  if(.NOT.GGrid_identical(dAtmGrid,dAtmGridExactCopy,1e-5)) then
     call die(ccmname,"dAtmGrid unexpectedly altered!!!")
  endif

! Now, Test the MCT Spatial Integration/Averaging Services...
  if(myProc==0)write(stdout,'(3a)') ccmname, &
       ':: on-Root test of MCT Spatial Integration Services...'

! simple unmasked integral case:
  call MCT_SpatialIntegral(a2coupler, integratedA2CaV, &
                           dAtmGrid, 'grid_area', comm=CCM_World)

if(myProc==0)then
  do i=1,MCT_AtrVt_nReal(integratedA2CaV)
     write(stdout,'(3a,i2,a,f12.6)') ccmname, &
	  ':: Unmasked distributed MCT ', &
	  'integral:  integratedA2CaV%rAttr(',i,',1)=', &
	  integratedA2CaV%rAttr(i,1)
  end do
endif

  call MCT_AtrVt_clean(integratedA2CaV)

! simple unmasked average case:
  call MCT_SpatialAverage(a2coupler, integratedA2CaV, &
                          dAtmGrid, 'grid_area', comm=CCM_World)

if(myProc==0)then
  do i=1,MCT_AtrVt_nReal(integratedA2CaV)
      write(stdout,'(3a,i2,a,f12.6)') ccmname, &
	   ':: Unmasked distributed MCT ', &
   	   'average:  averagedA2CaV%rAttr(',i,',1)=', &
	   integratedA2CaV%rAttr(i,1)
  end do
endif

  call MCT_AtrVt_clean(integratedA2CaV)

! not-so-simple masked average cases...
  call MCT_MaskedSpatialAverage(inAv=a2coupler, &
                                outAv=integratedA2CaV, &
                                GGrid=dAtmGrid, &
                                SpatialWeightTag='grid_area', &
                                imaskTags='grid_imask', &
				UseFastMethod=.TRUE., &
				comm=CCM_World)

if(myProc==0)then
  do i=1,MCT_AtrVt_nReal(integratedA2CaV)
     write(stdout,'(3a,i2,a,f12.6)') ccmname, &
     ':: Masked distributed MCT ',  &
     'average: averagedA2CaV%rAttr(',i,',1)=', &
     integratedA2CaV%rAttr(i,1)
  end do
endif

  call MCT_AtrVt_clean(integratedA2CaV)

!!!!!!!!!!!!!!!!!----------Router
! intialize a Router to the Coupler.  Call it Atm2Cpl
 if(myProc==0)write(*,*) ccmname,":: Initializing Router"
  call zeit_ci('Arouterinit')
   call MCT_Router_init(coupler_id,GSMap,CCM_World,Atm2Cpl)
  call zeit_co('Arouterinit')
 if(myProc==0)write(*,*) ccmname,":: Done Initializing Router"

  call Router_test(Atm2Cpl,"CCM::Atm2Cpl",7300+myProc)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Endof initialization phase
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!!!!!!!!!!!!!!!!!----------MCT_Send
! send data to the coupler.
 if(myProc==0)write(*,*) ccmname,":: Doing Distributed Send"

  call AttrVect_test(a2coupler,"CCM::a2coupler",2000+myProc)
  do steps=1,nsteps
     call zeit_ci('Amctsend')
     call MCT_Send(a2coupler,Atm2Cpl)
     call zeit_co('Amctsend')
  enddo

 if(myProc==0)write(*,*) ccmname,":: Done with Send"


!!!!!!!!!!!!!!!!!---------- all done
  call zeit_ci('Acleanup')

  ! Clean MCT datatypes
  if(myProc==0) then
     call MCT_GGrid_clean(AtmGrid)
     call MCT_GGrid_clean(AtmCartGrid)
     call MCT_GGrid_clean(AtmGridExactCopy)
  endif

  call MCT_GGrid_clean(dAtmGrid)
  call MCT_GGrid_clean(dAtmGridExactCopy)
  call MCT_GSMap_clean(GSMap)
  call MCT_Router_clean(Atm2Cpl)
  call MCT_AtrVt_clean(a2coupler)
  call MCT_AtrVt_clean(a2coupler2)
  call MCTWorld_clean()

  ! Clean temporary structures

  deallocate(starts, lengths, myglobalmap, stat=ierr)
  if(ierr/=0) call die(ccmname, "deallocate(starts,lengths..)", ierr)

  call zeit_co('Acleanup')

! write out timing info to fortran unit 45
  call zeit_allflush(CCM_World,0,45)

contains

    subroutine  FoldOverDecomp(myglobalmap,starts,lengths,nx,ny)

      integer,dimension(:,:),intent(in)  :: myglobalmap
      integer,dimension(:),pointer   :: starts,lengths
      integer, intent(in) :: nx,ny
      integer :: i,j,n,row,col,plat,plon
!  For this example, we will do a fold-over-the-equator
!  mapping of our grid onto the cartesian processor topology:
!  each row of processors handles latitudes from
!  the northern and southern hemispheres.

!
!  For each processor, each seglength is plon
!
! the value of the global index at the start of each
! segment can be found from myglobalmap

! set local latitude and longitude size
  plat = ny / NPROCS_LATA
  plon = nx / NPROCS_LONA

! define a Cartesian topology by assigning
! row and column indicies to each processor.
! processor with rank 0 is (0,0)
  row = myProc / NPROCS_LONA
  col = mod(myProc,NPROCS_LONA)

  allocate(starts(plat),lengths(plat),stat=ierr)
  if(ierr/=0) call die(ccmname, "allocate(starts..)", ierr)

! the fist plat/2 latitudes are from the southern hemisphere
  do j=1,plat/2
     starts(j)= myglobalmap(col*plon + 1,(plat/2 * row) + j)
     lengths(j)=plon
  enddo

! the next plat/2 latitudes are from the northern hemisphere
  n=1
  do j=plat/2 + 1,plat
    starts(j)=myglobalmap(col*plon + 1,(ny - (plat/2 * (row+1))) + n)
    lengths(j)=plon
    n=n+1
  enddo

end subroutine FoldOverDecomp

end subroutine ccm3

