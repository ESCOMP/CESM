!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: pop.F90,v 1.15 2004-03-04 20:04:17 eong Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !ROUTINE: pop2_2  -- dummy ocean model for unit tester
!
! !DESCRIPTION:
! An ocean model subroutine to test functionality of MPH and MCT.
!
! !INTERFACE:
      subroutine pop2_2 (POP_World)
!
! !USES:
!
      use MPH_all
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
      use m_Transfer,only: MCT_Recv => recv
!---Field Storage DataType and associated methods
      use m_AttrVect,only    : AttrVect
      use m_AttrVect,only    : MCT_AtrVt_init => init
      use m_AttrVect,only    : MCT_AtrVt_clean => clean
      use m_AttrVect,only    : MCT_AtrVt_lsize => lsize
      use m_AttrVect,only    : MCT_AtrVt_nReal => nRAttr
      use m_AttrVect,only    : MCT_AtrVt_nInteger => nIAttr
      use m_AttrVect,only    : AttrVect_zero => zero
      use m_AttrVect,only    : AttrVect_Copy => Copy
      use m_AttrVectComms,only : AttrVect_gather => gather
!---Domain Decomposition Descriptor DataType and associated methods
      use m_GlobalSegMap,only: GlobalSegMap
      use m_GlobalSegMap,only: MCT_GSMap_init => init
      use m_GlobalSegMap,only: MCT_GSMap_clean => clean
      use m_GlobalSegMap,only: MCT_GSMap_gsize => gsize
      use m_GlobalSegMap,only: MCT_GSMap_lsize => lsize
      use m_GlobalSegMap,only: MCT_GSMap_ngseg => ngseg
      use m_GlobalSegMap,only: MCT_GSMap_nlseg => nlseg
      use m_GlobalMap,only   : GlobalMap
      use m_GlobalMap,only   : GlobalMap_init => init
      use m_GlobalMap,only   : GlobalMap_clean => clean
!---GlobalSegMap Communication Methods
      use m_GlobalSegMapComms,only: GlobalSegMap_bcast => bcast
      use m_GlobalSegMapComms,only: GlobalSegMap_send => send
      use m_GlobalSegMapComms,only: GlobalSegMap_recv => recv
      use m_GlobalSegMapComms,only: GlobalSegMap_isend => isend
!---Methods for Exchange of GlobalMapping Objects
      use m_ExchangeMaps,only: ExchangeMap
!---Coordinate Grid DataType and associated methods
      use m_GeneralGrid,only : GeneralGrid
      use m_GeneralGrid,only : MCT_GGrid_init => init
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
      use m_GeneralGridComms,only: MCT_GGrid_gather => gather
!---Spatial Integral DataType and associated methods
      use m_SpatialIntegral,only : MCT_SpatialIntegral => SpatialIntegral
      use m_SpatialIntegral,only : MCT_SpatialAverage => SpatialAverage
      use m_SpatialIntegral,only : MCT_MaskedSpatialIntegral => &
	                                              MaskedSpatialIntegral
      use m_SpatialIntegral,only : MCT_MaskedSpatialAverage => &
	                                              MaskedSpatialAverage

!---mpeu List datatype
      use m_List, only : List
      use m_List, only : List_clean => clean
      use m_List, only : List_exportToChar => exportToChar
!---mpeu routines for MPI communications
      use m_mpif90
!---mpeu timers
      use m_zeit

      use m_stdio
      use m_ioutil, only: luavail
      use m_die

!---Tester Modules
      use m_ACTEST, only : Accumulator_test => testall
      use m_AVTEST, only : AttrVect_test => testall
      use m_AVTEST, only : AttrVect_identical => Identical
      use m_GGRIDTEST, only : GGrid_test      => testall
      use m_GGRIDTEST, only : GGrid_identical => Identical
      use m_GMAPTEST, only : GMap_test => testall
      use m_GSMAPTEST, only : GSMap_test => testall
      use m_GSMAPTEST, only : GSMap_identical => Identical
      use m_MCTWORLDTEST, only : MCTWorld_test => testall
      use m_ROUTERTEST, only : Router_test => testall
      use m_SMATTEST, only : sMat_test => testall
      use m_SMATTEST, only : sMat_identical   => Identical

!
! !REVISION HISTORY:
!        Oct00 - Yun (Helen) He and Chris Ding, NERSC/LBNL - initial version
!      19Nov00 - R. Jacob <jacob@mcs.anl.gov> - interface with mct
!      09Feb01 - R. Jacob <jacob@mcs.anl.gov> - add MPI_Barrier
!      25Feb01 - R. Jacob <jacob@mcs.anl.gov> - mpeu timing and MPE
!      15Feb02 - R. Jacob <jacob@mcs.anl.gov> - new MCTWorld_init interface
!      13Jul02 - E. Ong <eong@mcs.anl.gov> - introduce a POP grid
!EOP ___________________________________________________________________

      implicit none

      character(len=*), parameter :: popname='pop2_2'

!----------------------- MPH vars

      integer myProc, myProc_global, mySize, root
      integer Global_World, POP_World
      integer ncomps, mycompid, coupler_id

!  SparseMatrix dimensions and Processor Layout
      integer :: Nax, Nay                     ! Atmosphere lons, lats
      integer :: Nox, Noy                     ! Ocean lons, lats
      integer :: NPROCS_LATA, NPROCS_LONA     ! Processor layout

!----------------------- MCT vars

      ! Variables used for GlobalSegMap
      integer,dimension(1) :: starts,lengths
      integer :: osize,osize2
      integer :: i,j,k,n

      ! Arrays used to test MCT import/export routines
      integer,dimension(:),pointer :: MaskVector
      integer, dimension(:), pointer :: dummyI
      real,    dimension(:), pointer :: dummyR
      integer :: latindx,lonindx,gridindx,status
      integer :: length
      integer :: dAindx
      real :: pi

      ! Ocean GeneralGrid
      type(GeneralGrid) :: POPGrid, dPOPGrid

      ! Test grid for scatter,gather
      type(GeneralGrid) :: scatterGGrid, gatherGGrid

      !  Ocean GlobalSegMap
      type(GlobalSegMap) :: OGSMap

      !  Ocean GlobalSegMap from coupler
      type(GlobalSegMap) :: CPL_OGSMap

      !  GSMap for testing GlobalSegMapComms
      type(GlobalSegMap) :: inGSMap

      !  Ocean GlobalMap
      type(GlobalMap) :: OGMap

      !  Router from Cpl to Ocn
      type(Router) :: Cpl2Ocn

      ! Ocean Inputs from the Coupler and Integral
      type(AttrVect) :: OinputAV, IntegratedOinputAV

      ! Ocean Outputs to the Coupler
      type(AttrVect) :: OoutputAV

      ! Temporary Vars for hmv tests
      type(AttrVect) :: gatherAV_ocn
      integer :: unit

#ifdef MPE
#include "mpe.h"
#endif

! Set the value of pi:
  pi = acos(-1.0)

!-------------------------begin code

  call MPI_COMM_DUP (MPI_COMM_WORLD, Global_World, ierr)
  call MPI_COMM_RANK (Global_World, myProc_global, ierr)
  call MPI_COMM_RANK (POP_World, myProc, ierr)
  call MPI_COMM_SIZE(POP_World,mySize,ierr)

  if (myProc==0) call MPH_redirect_output ('pop')
! write(*,*) myProc, ' in pop === ', myProc_global, ' in global'
! write(*,*) 'MPH_local_proc_id_ME_SE()=', MPH_local_proc_id_ME_SE()
! write(*,*) 'MPH_global_proc_id()=', MPH_global_proc_id()


!-------------------------------------------------------
!  Begin attempts to use MCT
#ifdef MPE
  call mpe_logging_init(myProc_global,init_s,init_e,gsmi_s,gsmi_e, &
    atri_s,atri_e,routi_s,routi_e,send_s,send_e,recv_s,recv_e, &
    clean_s,clean_e)
#endif

  !  Get the coupler's component id
  coupler_id = MPH_get_component_id("coupler")

  ! Initialize MCTWorld
  ncomps=MPH_total_components()
  mycompid=MPH_component_id_ME_SE()
  call zeit_ci('Oworldinit')
  call MCTWorld_init(ncomps,MPI_COMM_WORLD,POP_World,mycompid)
  call zeit_co('Oworldinit')

  call MCTWorld_test("POP::MCTWorld",6200+myProc)

  ! Get the Sparse Matrix dimensions and processor layout
  root = MCTComponentRootRank(coupler_id,ThisMCTWorld)
  call MPI_BCAST(Nax,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(Nay,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(Nox,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(Noy,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(NPROCS_LATA,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)
  call MPI_BCAST(NPROCS_LONA,1,MP_INTEGER,root,MPI_COMM_WORLD,ierr)


  ! Load a POP grid on the ROOT PROCESS

if(myProc==0) then

   write(*,*) popname, ":: Initializing Ocean General Grid"

! NOTE: Since POP grids already have a predefined order,
!       do not impose a sorting order upon initialization

   call convertPOPT(POPGrid, &
	     "../../data/grid.320x384.da", &
	     "../../data/kmt_full_40.da", Nox, Noy)

   call GGrid_test(POPGrid,"POP::POPGrid",3400+myProc)

! Write out the basic things we initialized

  write(stdout,'(3a,i1)') popname, ":: Initialized POP GeneralGrid variable POPGrid.", &
                  "Number of dimensions = ",MCT_GGrid_dims(POPGrid)
  write(stdout,'(2a,i8)') popname, ":: Number of grid points in POPGrid=", &
                          MCT_GGrid_lsize(POPGrid)
  write(stdout,'(2a,i8)') popname, ":: Number of latitudes Noy=", Noy
  write(stdout,'(2a,i8)') popname, ":: Number of longitudes Nox=", Nox
  write(stdout,'(2a,i8)') popname, ":: Number of grid points Nox*Nox=", Noy*Nox
  write(stdout,'(3a)') popname, ":: POPGrid%coordinate_list = ", &
                       List_exportToChar(POPGrid%coordinate_list)
!  write(stdout,'(3a)') popname, ":: POPGrid%coordinate_sort_order = ", &
!                       List_exportToChar(POPGrid%coordinate_sort_order)
  write(stdout,'(3a)') popname, ":: POPGrid%weight_list = ", &
                       List_exportToChar(POPGrid%weight_list)
  write(stdout,*) popname, ":: POPGrid%other_list = ", &
                       ! * is used for SUPER_UX compatibility
                       List_exportToChar(POPGrid%other_list)
  write(stdout,'(3a)') popname, ":: POPGrid%index_list = ", &
                       List_exportToChar(POPGrid%index_list)
  write(stdout,'(2a,i3)') popname, ":: Number of integer attributes stored in POPGrid=", &
                          MCT_AtrVt_nInteger(POPGrid%data)
  write(stdout,'(2a,i3)') popname, ":: Total Number of real attributes stored in POPGrid=", &
                          MCT_AtrVt_nReal(POPGrid%data)

! Get POPGrid attribute indicies
 latindx=MCT_GGrid_indexRA(POPGrid,'grid_center_lat')
 lonindx=MCT_GGrid_indexRA(POPGrid,'grid_center_lon')

! NOTE: The integer attribute GlobGridNum is automatically
! appended to any General Grid.  Store the grid numbering
! scheme (used in the GlobalSegMap) here.
 gridindx=MCT_GGrid_indexIA(POPGrid,'GlobGridNum')

 do i=1,MCT_GGrid_lsize(POPGrid)
    POPGrid%data%iAttr(gridindx,i)=i
 enddo

! Check the weight values of the grid_area attribute

  dAindx = MCT_GGrid_indexRA(POPGrid, 'grid_area')

  write(stdout,'(2a)') popname, &
       ':: Various checks of GeneralGrid POPGrid Weight data...'
  write(stdout,'(2a,f12.6)') popname, &
       ':: direct ref--POPGrid 1st dA entry=.', &
       POPGrid%data%rAttr(dAindx,1)
  write(stdout,'(2a,f12.6)') popname, &
       ':: direct ref--POPGrid last dA entry=.', &
       POPGrid%data%rAttr(dAindx,MCT_GGrid_lsize(POPGrid))
  write(stdout,'(2a,f12.6)') popname, &
       ':: Sum of dA(1,...,Nox*Noy)=.', sum(POPGrid%data%rAttr(dAindx,:))
  write(stdout,'(2a,f12.6)') popname, &
       ':: Unit Sphere area 4 * pi=.', 4.*pi

! Check on coordinate values (and check some export functions, too...)

  allocate(dummyR(MCT_GGrid_lsize(POPGrid)), stat=ierr)
  if(ierr/=0) call die(popname, "allocate(dummyR)", ierr)

  call MCT_GGrid_exportRAttr(POPGrid, 'grid_center_lat', dummyR, length)

  write(stdout,'(2a)') popname, &
       ':: Various checks of GeneralGrid POPGrid coordinate data...'
  write(stdout,'(2a,i8)') popname, &
       ':: No. exported POPGrid latitude values =.',length
  write(stdout,'(2a,f12.6)') popname, &
       ':: export--POPGrid 1st latitude=.',dummyR(1)
  write(stdout,'(2a,f12.6)') popname, &
       ':: export--POPGrid last latitude=.',dummyR(length)
  write(stdout,'(2a,f12.6)') popname, &
       ':: direct ref--POPGrid 1st latitude=.', &
       POPGrid%data%rAttr(latindx,1)
  write(stdout,'(2a,f12.6)') popname, &
       ':: direct ref--POPGrid last latitude=.', &
       POPGrid%data%rAttr(latindx,length)
  write(stdout,'(2a,f12.6)') popname, &
       ':: direct ref--POPGrid 1st longitude=.', &
       POPGrid%data%rAttr(lonindx,1)
  write(stdout,'(2a,f12.6)') popname, &
       ':: direct ref--POPGrid last longitude=.', &
       POPGrid%data%rAttr(lonindx,MCT_GGrid_lsize(POPGrid))
  write(stdout,'(2a)') popname, &
       ':: End checks of GeneralGrid POPGrid coordinate data.'

! Check the GlobalGridNum values:

 allocate(dummyI(MCT_GGrid_lsize(POPGrid)), stat=ierr)
 if(ierr/=0) call die(popname, "allocate(dummyI)", ierr)

 call MCT_GGrid_exportIAttr(POPGrid, 'GlobGridNum', dummyI, length)

  write(stdout,'(2a,i8)') popname, &
       ':: No. exported POPGrid GlobalGridNum values =.',length
  write(stdout,'(2a,i8)') popname, &
       ':: export--POPGrid 1st GlobalGridNum =.', dummyI(1)
  write(stdout,'(2a,i8)') popname, &
       ':: export--POPGrid last GlobalGridNum =.', dummyI(length)
  write(stdout,'(2a,i8)') popname, &
       ':: direct ref--POPGrid 1st GlobalGridNum =.', &
       POPGrid%data%iAttr(gridindx,1)
  write(stdout,'(2a,i8)') popname, &
       ':: direct ref--POPGrid last GlobalGridNum =.', &
       POPGrid%data%iAttr(gridindx,length)

! Clean temporary structures

  deallocate(dummyI, dummyR, stat=ierr)
  if(ierr/=0) call die(popname, "deallocate(dummyI...)", ierr)

endif   ! if(myProc==0)

! send the ocean's grid from the ocean's root to the
! coupler's root.  2800 is the randomly chosen tag base.
if(myProc==0) call MCT_GGrid_send(POPGrid,coupler_id,2800,ierr)

!::::::::::::::::::::::::::::::::::::::::::::::::::::

  !  Describe OGSMap, the ocean grid decomposition

  ! number of local oceanpoints
  osize = (Noy * Nox)/mySize
  osize2 = osize

  ! (Noy *Nox)/mySize isnt an integer, give extra points to last proc.
  if(myProc == mySize - 1) then
    osize = osize + mod(Noy*Nox,mySize)
  endif

  ! find starting point in the numbering scheme
  ! numbering scheme is same as that used in ocean model.
  starts(1) = (myProc * osize2) +1
  lengths(1) = osize

  ! describe this information in a Global Map for the ocean.
  call zeit_ci('OGSMapinit')
   call MCT_GSMap_init(OGSMap,starts,lengths,0,POP_World,mycompid)
  call zeit_co('OGSMmapinit')

!!! test some GlobalSegMap functions
! write(*,*)myProc,'number of global segs is',MCT_GSMap_ngseg(OGSMap)
! write(*,*)myProc,'local size is',MCT_GSMap_lsize(OGSMap,CPL_World)
! write(*,*)myProc,'global size is',MCT_GSMap_gsize(OGSMap)

  ! make a sample GlobalMap based on the local sizes of the GlobalSegMap
  call GlobalMap_init(OGMap,mycompid,MCT_GSMap_lsize(OGSMap,POP_World), &
                      POP_World)
  call GMap_test(GMap=OGMap,Identifier="POP::OGMap", &
       mycomm=POP_World,device=4200+myProc)

  ! lets exchange maps with the coupler
  call ExchangeMap(OGMap,POP_World,CPL_OGSMap,coupler_id,ierr)
  if(ierr/=0) call die(popname,"call ExchangeMap")

  call GMap_test(GMap=OGMap,Identifier="POP::OGMap", &
       mycomm=POP_World,device=4300+myProc)
  call GSMap_test(CPL_OGSMap,"POP::CPL_OGSMap",POP_World,5200+myProc)

  ! Compare this to sending and recieving maps
  if(myProc==0) then

     call GlobalSegMap_recv(inGSMap,coupler_id,777)
     if (.NOT.(GSMap_identical(inGSMap,CPL_OGSMap))) then
        call die(popname,"GSMap_identical(inGSMap,CPL_OGSMap)")
     endif
     call MCT_GSMap_clean(inGSMap)

     call GlobalSegMap_recv(inGSMap,coupler_id,888)
     if (.NOT.(GSMap_identical(inGSMap,CPL_OGSMap))) then
        call die(popname,"GSMap_identical(inGSMap,CPL_OGSMap)")
     endif
     call MCT_GSMap_clean(inGSMap)

  endif

!:::::::GGRID COMMUNICATIONS TESTING:::::::!

  call MCT_GGrid_scatter(POPGrid,scatterGGrid,OGMap,0,POP_World)
  call MCT_GGrid_gather(scatterGGrid,gatherGGrid,OGMap,0,POP_World)

  if(myProc==0) then
     if(.NOT. GGrid_identical(POPGrid,gatherGGrid,0.1) ) then
        call die(popname,"GGrid Comms test failed")
     endif
  endif

!  declare an attrvect to hold all ocean model inputs
!  NOTE:  the size of the AttrVect is set to be the local
!  size of the GSMap.

  call zeit_ci('OInputAVinit')

  call MCT_AtrVt_init(OinputAV,    &
       rList=&
!  net solar radiation
       "solrad:&
! downward direct visible radiation
       &dirvis:&
! downward diffuse visible radiation
       &difvis:&
! downward direct near-infrared radiation
       &dirnif:&
! downward diffuse near-infrared radiation
       &difnif:&
! convective precip
       &precc:&
! large-scale precip
       &precl",&
       lsize=MCT_GSMap_lsize(OGSMap, POP_World))

  call zeit_co('OinputAVinit')

!  declare an attrvect to hold all ocean model outputs
!  NOTE:  the size of the AttrVect is set to be the local
!  size of the GSMap.

  call zeit_ci('OoutputAVinit')

  call MCT_AtrVt_init(OoutputAV,    &
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
       lsize=MCT_GSMap_lsize(OGSMap, POP_World))

  call zeit_co('OoutputAVinit')

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!--Build Router
!
! Intialize router between atmosphere and coupler using AGSMap.
! This call must be paired with a similar call in cp
  call zeit_ci('OCplRouterInit')
   call MCT_Router_init(coupler_id,OGSMap,POP_World,Cpl2Ocn)
  call zeit_co('OCplRouterInit')

  call Router_test(Cpl2Ocn,"POP::Cpl2Ocn",7200+myProc)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  ! Lets prepare to do some neat integrals using MCT.
  ! First, we must scatter the Ocean Grid:

  call MCT_GGrid_scatter(POPGrid, dPOPGrid, OGSMap, 0, POP_World)

  ! Then, receive the accumulated and interpolated attrvect from the coupler
  if(myProc == 0) write(stdout,*) popname,':: Before MCT_RECV from CPL.'
  call zeit_ci('OinputAVrecv')
  call MCT_Recv(OinputAV,Cpl2Ocn)
  call zeit_co('OinputAVrecv')
  call AttrVect_test(OinputAV,"POP::OinputAV",2600)
  if(myProc == 0) write(stdout,*) popname,':: After MCT_RECV from CPL.'

  ! Lets check the values to make sure our asci matrix file
  ! corresponds to the imask in our GeneralGrid.
  allocate(MaskVector(MCT_GGrid_lsize(dPOPGrid)), stat=ierr)
  if(ierr/=0) call die(popname, "allocate(dPOPGrid)", ierr)

  call MCT_GGrid_exportIAttr(dPOPGrid,"grid_imask",MaskVector,k)

  if(MCT_GGrid_lsize(dPOPGrid)/=k) then
     call die(popname,"MCT_GGrid_exportIAttr failed")
  endif

  do i=1,k
     if(MaskVector(i)==0) then
        if(abs(OinputAV%rAttr(1,i)-MaskVector(i)) > 1e-4) then
           call die(popname,"GeneralGrid Mask does not match &
                    &matrix file mask")
        endif
     endif
  enddo

  deallocate(MaskVector,stat=ierr)
  if(ierr/=0) call die(popname,"deallocate(MaskVector)",ierr)

  ! TEST MAPPING FOR HMV

  call AttrVect_gather(OinputAV,gatherAV_ocn,OGSMap, &
                       0,POP_World,ierr)

  if(myProc == 0) then
     unit = luavail() + 9000
     write(unit,*) Nox, Noy
     k=0
     do i=1,Nox
        do j=1,Noy
           k=k+1
           write(unit,*) gatherAV_ocn%rAttr(1,k)
        enddo
     enddo
     call MCT_AtrVt_clean(gatherAV_ocn)
  endif

  ! Now, Test the MCT Spatial Integration/Averaging Services...
  if(myProc==0)write(stdout,'(3a)') popname,':: on-Root test of MCT Spatial ', &
       'Integration Services...'

  ! simple unmasked integral case:

  call MCT_SpatialIntegral(OinputAV, integratedOinputAV, dPOPGrid, 'grid_area', &
                          comm=POP_World)

  if(myProc==0)then
     do i=1,MCT_AtrVt_nReal(integratedOinputAV)
	write(stdout,'(3a,i2,a,f12.6)') popname,':: Unmasked distributed MCT ', &
	     'integral:  integratedOinputAV%rAttr(',i,',1)=', &
	     integratedOinputAV%rAttr(i,1)
     end do
  endif

  call MCT_AtrVt_clean(integratedOinputAV)

  ! simple unmasked average case:
  call MCT_SpatialAverage(OinputAV, integratedOinputAV, dPOPGrid, 'grid_area', &
                         comm=POP_World)

if(myProc==0)then
  do i=1,MCT_AtrVt_nReal(integratedOinputAV)
      write(stdout,'(3a,i2,a,f12.6)') popname,':: Unmasked distributed MCT ', &
   	   'average:  averagedOinputAV%rAttr(',i,',1)=', &
	   integratedOinputAV%rAttr(i,1)
  end do
endif
  call MCT_AtrVt_clean(integratedOinputAV)

  ! masked average case...

  call MCT_MaskedSpatialAverage(inAv=OinputAV, outAv=integratedOinputAV, &
                                GGrid=dPOPGrid, SpatialWeightTag='grid_area', &
                                iMaskTags='grid_imask', UseFastMethod=.TRUE., &
				comm=POP_World)

if(myProc==0)then
  do i=1,MCT_AtrVt_nReal(integratedOinputAV)
     write(stdout,'(3a,i2,a,f12.6)') popname,':: Masked distributed MCT ',  &
     'average (both iMask & rMask = unity): averagedOinputAV%rAttr(',i,',1)=', &
 	  integratedOinputAV%rAttr(i,1)
  end do
endif
  call MCT_AtrVt_clean(integratedOinputAV)

  call GGrid_test(dPOPGrid,"POP::dPOPGrid",3500+myProc)

  ! Fill the Ocean's output with test values:
  ! the first attribute will be constant, while
  ! the rest will contain interolated values from OinputAV
  call AttrVect_copy(aVin=OinputAV,aVout=OoutputAV, &
       rList=List_exportToChar(OinputAV%rList),  &
       TrList=List_exportToChar(OoutputAV%rList))

  OoutputAV%rAttr(1,:) = 30.

  ! Now, send the Ocean's output to the Coupler...
  if(myProc == 0) write(stdout,*) popname,':: Before MCT_SEND to CPL.'
  call zeit_ci('OoutputAVsend')
  call MCT_Send(OoutputAV,Cpl2Ocn)
  call zeit_co('OoutputAVsend')
  if(myProc == 0) write(stdout,*) popname,':: After MCT_SEND to CPL.'

  ! All Done
  call zeit_ci('Ocleanup')

  ! Clean MCT datatypes
  if(myProc==0) then
   call MCT_GGrid_clean(POPGrid)
   call MCT_GGrid_clean(gatherGGrid)
  endif

  call MCT_GGrid_clean(scatterGGrid)
  call MCT_GGrid_clean(dPOPGrid)
  call MCT_AtrVt_clean(OinputAV)
  call MCT_AtrVt_clean(OoutputAV)
  call MCT_GSMap_clean(OGSMap)
  call MCT_GSMap_clean(CPL_OGSMap)
  call GlobalMap_clean(OGMap)
  call MCT_Router_clean(Cpl2Ocn)
  call MCTWorld_clean()

  call zeit_co('Ocleanup')

! write out timing info to fortran unit 47
  call zeit_allflush(POP_World,0,47)


end subroutine









