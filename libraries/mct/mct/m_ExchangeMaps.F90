!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_ExchangeMaps - Exchange of Global Mapping Objects.
!
! !DESCRIPTION:
! This module contains routines that support the exchange of domain
! decomposition descriptors (DDDs) between two MCT components.  There is
! support for {\em handshaking} between the two components to determine
! the types of domain decomposition descriptors they employ, {\em loading}
! of data contained within domain decomposition descriptors, and {\em
! map exchange}, resulting in the creation of a remote component's domain
! decomposition descriptor for use by a local component.  These routines
! are largely used by MCT's {\tt Router} to create intercomponent
! communications scheduler, and normally should not be used by an MCT
! user.
!
! Currently, the types of map exchange supported by the public routine
! {\tt ExchangeMap()} are summarized in the table below.  The first column
! lists the type of DDD used locally on the component invoking
! {\tt ExchangeMap()} (i.e., the input DDD).  The second comlumn lists
! the DDD type used on the remote component (i.e., the output DDD).
!\begin{table}[htbp]
!\begin{center}
!\begin{tabular}{|c|c|}
!\hline
!{\bf Local DDD Type} & {\bf Remote DDD Type} \\
!\hline
!{\tt GlobalMap} & {\tt GlobalSegMap} \\
!\hline
!{\tt GlobalSegMap} & {\tt GlobalSegMap} \\
!\hline
!\end{tabular}
!\end{center}
!\end{table}
!
! Currently, we do not support intercomponent map exchange where a
! {\tt GlobalMap} is output.  The rationale for this is that any {\tt GlobalMap}
! may always be expressed as a {\tt GlobalSegMap}.
!
! !INTERFACE:

 module m_ExchangeMaps

! !USES:
! No external modules are used in the declaration section of this module.

      implicit none

      private   ! except
!
! !PUBLIC MEMBER FUNCTIONS:
!
      public :: ExchangeMap

      interface ExchangeMap ; module procedure   &
           ExGSMapGSMap_, &  ! GlobalSegMap for GlobalSegMap
           ExGMapGSMap_
      end interface

! !SEE ALSO:
! The MCT module m_ConvertMaps for more information regarding the
! relationship between the GlobalMap and GlobalSegMap types.
! The MCT module m_Router to see where these services are used to
! create intercomponent communications schedulers.
!
! !REVISION HISTORY:
!  3Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial module
!  3Aug01 - E.T. Ong <eong@mcs.anl.gov> - in ExGSMapGSMap,
!           call GlobalSegMap_init with actual shaped arrays
!           for non-root processes to satisfy Fortran 90 standard.
!           See comments in subroutine.
! 15Feb02 - R. Jacob <jacob@mcs.anl.gov> - use MCT_comm instead of
!           MP_COMM_WORLD
!EOP ___________________________________________________________________
!
  character(len=*),parameter :: myname='MCT::m_ExchangeMaps'

! Map Handshaking Parameters:  Map handshaking occurs via
! exchange of an array of INTEGER flags.

  ! Number of Handshaking Parameters; i.e.size of exhcanged parameters array

  integer, parameter :: NumHandshakePars = 4

  ! ComponentIDIndex defines the storage location of the  flag
  ! signifying the component number in MCTWorld

  integer, parameter :: ComponentIDIndex = 1

  ! MapTypeIndex defines the storage location in the handshake array
  ! of the type of map offered for exchange

  integer, parameter :: MapTypeIndex = 2

          ! NumMapTypes is the number of legitimate MapTypeIndex Values:

  integer, parameter :: NumMapTypes = 2

          ! Recognized MapTypeIndex Values:

  integer, parameter :: GlobalMapFlag = 1
  integer, parameter :: GlobalSegMapFlag = 2

  ! GsizeIndex defines the location of the grid size (number of points)
  ! for the map.  This size is

  integer, parameter :: GsizeIndex = 3

  ! NumSegIndex defines the location of the number of segments in the
  ! map.  For a GlobalMap, this is the number of processes in the map.
  ! For a GlobalSegMap, this is the number of global segments (ngseg).

  integer, parameter :: NumSegIndex = 4

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: MapHandshake_ - Exchange Map descriptors.
!
! !DESCRIPTION:
! This routine takes input Map descriptors stored in the {\tt INTEGER}
! array {\tt LocalMapPars}, the local communicator on which this map is
! defined ({\tt LocalComm}), and the remote component ID
! {\tt RemoteCompID}, and effects an exchange of map descriptors with
! the remote component, which are returned in the {\tt INTEGER} array
! {\tt RemoteMapPars}.
!
! {\bf N.B.: } The values present in {\tt LocalMapPars} need to be valid
! only on the root of {\tt LocalComm}.  Likewise, the returned values in
! {\tt RemoteMapPars} will be valid on the root of {\tt LocalComm}.
!
! !INTERFACE:

 subroutine MapHandshake_(LocalMapPars, LocalComm, RemoteCompID, &
                          RemoteMapPars)

!
! !USES:
!
      use m_mpif90
      use m_die,      only : MP_perr_die
      use m_stdio
      use m_MCTWorld, only : ThisMCTWorld
      use m_MCTWorld, only : ComponentRootRank

      implicit none
!
! !INPUT PARAMETERS:
!
      integer, intent(in)  :: LocalMapPars(NumHandshakePars)
      integer, intent(in)  :: LocalComm
      integer, intent(in)  :: RemoteCompID
!
! !OUTPUT PARAMETERS:
!
      integer, intent(out) :: RemoteMapPars(NumHandshakePars)

! !REVISION HISTORY:
!  6Feb01 - J.W. Larson <larson@mcs.anl.gov> - API specification.
! 20Apr01 - R.L. Jacob  <jacob@mcs.anl.gov> - add status argument
!           to MPI_RECV
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::MapHandshake_'

  integer :: ierr, myID, RemoteRootID, SendTag, RecvTag
  integer,dimension(MP_STATUS_SIZE) :: status

  call MP_COMM_RANK(LocalComm, myID, ierr)
  if(ierr /= 0) call MP_perr_die(myname_,'call MP_COMM_RANK()',ierr)

  RemoteRootID = ComponentRootRank(RemoteCompID, ThisMCTWorld)

  if(myID == 0) then ! I am the root on LocalComm

      ! Compute send/receive tags:

     SendTag = 10 * LocalMapPars(ComponentIDIndex) + RemoteCompID
     RecvTag = LocalMapPars(ComponentIDIndex) + 10 * RemoteCompID

      ! Post send to RemoteRootID:

     call MPI_SEND(LocalMapPars, NumHandshakePars, MP_INTEGER, &
	           RemoteRootID, SendTag, ThisMCTWorld%MCT_comm, ierr)
     if(ierr /= 0) call MP_perr_die(myname_,'call MPI_SEND()',ierr)

      ! Post receive from RemoteRootID:

     call MPI_RECV(RemoteMapPars, NumHandshakePars, MP_INTEGER, &
	           RemoteRootID, RecvTag, ThisMCTWorld%MCT_comm, status, ierr)
     if(ierr /= 0) call MP_perr_die(myname_,'call MPI_RECV()',ierr)

  endif ! if(myID == 0)

 end subroutine MapHandshake_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: LoadGlobalMapPars_ - Load GlobalMap descriptors.
!
! !DESCRIPTION:
! This routine takes an input {\tt GlobalMap} variable {\tt Gmap}, and
! loads its descriptors the output {\tt INTEGER} array {\tt MapPars}.
! The dimensions of this array, and loading order are all defined in
! the declaration section of this module.
!
! !INTERFACE:

 subroutine LoadGlobalMapPars_(GMap, MapPars)

!
! !USES:
!
      use m_mpif90
      use m_die
      use m_stdio
      use m_GlobalMap, only : GlobalMap
      use m_GlobalMap, only : GlobalMap_comp_id => comp_id
      use m_GlobalMap, only : GlobalMap_gsize => gsize
!      use m_GlobalMap, only : GlobalMap_nprocs => nprocs

      implicit none
!
! !INPUT PARAMETERS:
!
      type(GlobalMap), intent(in)  :: GMap
!
! !OUTPUT PARAMETERS:
!
      integer,         intent(out) :: MapPars(NumHandshakePars)

! !REVISION HISTORY:
!  6Feb01 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::LoadGlobalMapPars_'

  MapPars(ComponentIDIndex) = GlobalMap_comp_id(GMap)
  MapPars(MapTypeIndex) = GlobalMapFlag
  MapPars(GsizeIndex) = GlobalMap_gsize(GMap)
!  MapPars(NumSegIndex) = GlobalMap_nprocs(GSMap)

 end subroutine LoadGlobalMapPars_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: LoadGlobalSegMapPars_ - Load GlobalSegMap descriptors.
!
! !DESCRIPTION:
! This routine takes an input {\tt GlobalSegMap} variable {\tt Gmap}, and
! loads its descriptors the output {\tt INTEGER} array {\tt MapPars}.
! The dimensions of this array, and loading order are all defined in
! the declaration section of this module.
!
! !INTERFACE:

 subroutine LoadGlobalSegMapPars_(GSMap, MapPars)

!
! !USES:
!
      use m_mpif90
      use m_die
      use m_stdio
      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_comp_id => comp_id
      use m_GlobalSegMap, only : GlobalSegMap_gsize => gsize
      use m_GlobalSegMap, only : GlobalSegMap_ngseg => ngseg


      implicit none
!
! !INPUT PARAMETERS:
!
      type(GlobalSegMap), intent(in)  :: GSMap
!
! !OUTPUT PARAMETERS:
!
      integer,            intent(out) :: MapPars(NumHandshakePars)

! !REVISION HISTORY:
!  6Feb01 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::LoadGlobalSegMapPars_'

  MapPars(ComponentIDIndex) = GlobalSegMap_comp_id(GSMap)
  MapPars(MapTypeIndex) = GlobalSegMapFlag
  MapPars(GsizeIndex) = GlobalSegMap_gsize(GSMap)
  MapPars(NumSegIndex) = GlobalSegMap_ngseg(GSMap)

 end subroutine LoadGlobalSegMapPars_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ExGSMapGSMap_ - Trade of GlobalSegMap structures.
!
! !DESCRIPTION:
! This routine effects the exchange between two components of their
! data decomposition descriptors, each of which is a {\tt GlobalSegMap}.
! The component invoking this routine provides its domain decomposition
! in the form of the input {\tt GlobalSegMap} argument {\tt LocalGSMap}.
! The component with which map exchange takes place is specified by the
! MCT integer component identification number defined by the input
! {\tt INTEGER} argument {\tt RemoteCompID}.  The
! !INTERFACE:

 subroutine ExGSMapGSMap_(LocalGSMap, LocalComm, RemoteGSMap, &
                          RemoteCompID, ierr)

!
! !USES:
!
      use m_mpif90
      use m_die
      use m_stdio
      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_init => init

      use m_MCTWorld, only : ThisMCTWorld
      use m_MCTWorld, only : ComponentRootRank

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap), intent(in)  :: LocalGSMap   ! Local GlobalSegMap
      integer,            intent(in)  :: LocalComm    ! Local Communicator
      integer        ,    intent(in)  :: RemoteCompID ! Remote component id

! !OUTPUT PARAMETERS:

      type(GlobalSegMap), intent(out) :: RemoteGSMap ! Remote GlobalSegMap
      integer,            intent(out) :: ierr        ! Error Flag

! !REVISION HISTORY:
!  3Feb01 - J.W. Larson <larson@mcs.anl.gov> - API specification.
!  7Feb01 - J.W. Larson <larson@mcs.anl.gov> - First full version.
! 20Apr01 - R.L. Jacob  <jacob@mcs.anl.gov> - add status argument
!           to MPI_RECV
! 25Apr01 - R.L. Jacob  <jacob@mcs.anl.gov> - set SendTag and
!           RecvTag values
!  3May01 - R.L. Jacob <jacob@mcs.anl.gov> - change MPI_SEND to
!           MPI_ISEND to avoid possible buffering problems seen
!           on IBM SP.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ExGSMapGSMap_'

! root ID on local communicator:
  integer, parameter :: root = 0
! Storage for local and remote map descriptors:
  integer :: LocalMapPars(NumHandshakePars)
  integer :: RemoteMapPars(NumHandshakePars)
! Send and Receive Buffers
  integer, dimension(:), allocatable :: SendBuf
  integer, dimension(:), allocatable :: RecvBuf
! Send and Receive Tags
  integer :: SendTag, RecvTag
! Storage arrays for Remote GlobalSegMap data:
  integer, dimension(:), allocatable :: start, length, pe_loc

  integer :: myID, ngseg, remote_root,req
  integer :: local_ngseg, remote_ngseg
  integer,dimension(MP_STATUS_SIZE) :: status,wstatus

      ! Determine rank on local communicator:

  call MP_COMM_RANK(LocalComm, myID, ierr)
  if(ierr /= 0) call MP_perr_die(myname_,'call MP_COMM_RANK()',ierr)

      ! If the root, exchange map handshake descriptors,
      ! and information needed to initialize the remote map
      ! on the local communicator.

  if(myID == root) then

     call LoadGlobalSegMapPars_(LocalGSMap, LocalMapPars)

     call MapHandshake_(LocalMapPars, LocalComm, RemoteCompID, &
                        RemoteMapPars)

      ! Consistency Checks between LocalMapPars and RemoteMapPars:

     if(LocalMapPars(MapTypeIndex) /= RemoteMapPars(MapTypeIndex)) then
	ierr = 2
	write(stderr,*) myname_,":: MCTERROR, Map Type mismatch ", &
	"LocalMap Type = ",LocalMapPars(MapTypeIndex)," RemoteMap Type = ", &
	RemoteMapPars(MapTypeIndex)
	call die(myname_,'Map Type mismatch',ierr)
     endif

     if(LocalMapPars(GsizeIndex) /= RemoteMapPars(GsizeIndex)) then
	ierr = 3
	write(stderr,*) myname_,":: MCTERROR, Grid Size mismatch ", &
	"LocalMap Gsize = ",LocalMapPars(GsizeIndex)," RemoteMap Gsize = ", &
	RemoteMapPars(GsizeIndex)
	call die(myname_,'Map Grid Size mismatch',ierr)
     endif

     if(RemoteCompID /= RemoteMapPars(ComponentIDIndex)) then
	ierr = 4
	write(stderr,*) myname_,":: MCTERROR, Component ID mismatch ", &
	"RemoteCompID = ",RemoteCompID," RemoteMap CompID = ", &
	RemoteMapPars(ComponentIDIndex)
	call die(myname_,'Component ID mismatch',ierr)
     endif

      ! SendBuf will hold the arrays LocalGSMap%start, LocalGSMap%length,
      ! and LocalGSMap%pe_loc in that order.

     allocate(SendBuf(3*LocalMapPars(NumSegIndex)), stat=ierr)
     if(ierr /= 0) call die(myname_,'allocate(SendBuf...)',ierr)

      ! RecvBuf will hold the arrays RemoteGSMap%start, RemoteGSMap%length,
      ! and RemoteGSMap%pe_loc in that order.

     allocate(RecvBuf(3*RemoteMapPars(NumSegIndex)), stat=ierr)
     if(ierr /= 0) call die(myname_,'allocate(RecvBuf...)',ierr)

      ! Load SendBuf in the order described above:
     local_ngseg = LocalMapPars(NumSegIndex)
     SendBuf(1:local_ngseg) = &
	                  LocalGSMap%start(1:local_ngseg)
     SendBuf(local_ngseg+1:2*local_ngseg) = &
	                  LocalGSMap%length(1:local_ngseg)
     SendBuf(2*local_ngseg+1:3*local_ngseg) = &
	                  LocalGSMap%pe_loc(1:local_ngseg)

      ! Determine the remote component root:

     remote_root = ComponentRootRank(RemoteMapPars(ComponentIDIndex), &
	                             ThisMCTWorld)

     SendTag = 10 * LocalMapPars(ComponentIDIndex) + RemoteCompID
     RecvTag = LocalMapPars(ComponentIDIndex) + 10 * RemoteCompID

      ! Send off SendBuf to the remote component root:

     call MPI_ISEND(SendBuf(1), 3*LocalMapPars(NumSegIndex), MP_INTEGER, &
	           remote_root, SendTag, ThisMCTWorld%MCT_comm, req, ierr)
     if(ierr /= 0) call MP_perr_die(myname_,'MPI_SEND(SendBuf...',ierr)

      ! Receive RecvBuf from the remote component root:

     call MPI_RECV(RecvBuf, 3*RemoteMapPars(NumSegIndex), MP_INTEGER, &
	           remote_root, RecvTag, ThisMCTWorld%MCT_comm, status, ierr)
     if(ierr /= 0) call MP_perr_die(myname_,'MPI_Recv(RecvBuf...',ierr)

     call MPI_WAIT(req,wstatus,ierr)
     if(ierr /= 0) call MP_perr_die(myname_,'MPI_WAIT(SendBuf..',ierr)

      ! Allocate arrays start(:), length(:), and pe_loc(:)

     allocate(start(RemoteMapPars(NumSegIndex)),  &
	      length(RemoteMapPars(NumSegIndex)), &
	      pe_loc(RemoteMapPars(NumSegIndex)), stat=ierr)
     if(ierr /= 0) call die(myname_,'allocate(start...',ierr)

      ! Unpack RecvBuf into arrays start(:), length(:), and pe_loc(:)
     remote_ngseg = RemoteMapPars(NumSegIndex)
     start(1:remote_ngseg) = RecvBuf(1:remote_ngseg)
     length(1:remote_ngseg) = &
                        RecvBuf(remote_ngseg+1:2*remote_ngseg)
     pe_loc(1:remote_ngseg) = &
                        RecvBuf(2*remote_ngseg+1:3*remote_ngseg)

  endif ! if(myID == root)

        ! Non-root processes call GlobalSegMap_init with start,
        ! length, and pe_loc, although these arguments are
        ! not used in the subroutine. Since these correspond to dummy
        ! shaped array arguments in GlobalSegMap_init, the Fortran 90
        ! standard dictates that the actual arguments must contain
        ! complete shape information. Therefore, these array arguments
        ! must be allocated on all processes.

  if(myID /= root) then

      allocate(start(1), length(1), pe_loc(1), stat=ierr)
      if(ierr /= 0) call die(myname_,'non-root allocate(start...',ierr)

  endif


      ! Initialize the Remote GlobalSegMap RemoteGSMap

  call GlobalSegMap_init(RemoteGSMap, RemoteMapPars(NumSegIndex), &
                         start, length, pe_loc, root, LocalComm,  &
			 RemoteCompID, RemoteMapPars(GsizeIndex))


      ! Deallocate allocated arrays

  deallocate(start, length, pe_loc, stat=ierr)
  if(ierr /= 0) then
     call die(myname_,'deallocate(start...',ierr)
  endif

      ! Deallocate allocated arrays on the root:

  if(myID == root) then

     deallocate(SendBuf, RecvBuf, stat=ierr)
     if(ierr /= 0) then
	call die(myname_,'deallocate(SendBuf...',ierr)
     endif

  endif ! if(myID == root)

 end subroutine ExGSMapGSMap_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ExGMapGSMap_ - Trade of GlobalMap for GlobalSegMap.
!
! !DESCRIPTION:
! This routine allows a component to report its domain decomposition
! using a {\tt GlobalMap} (the input argument {\tt LocalGMap}), and
! receive the domain decomposition of a remote component in the form
! of a {\tt GlobalSegMap} (the output argument {\tt RemoteGSMap}.  The
! component with which map exchange occurs is defined by its component
! ID number (the input {\tt INTEGER} argument {\tt RemoteCompID}).
! Currently, this operation is implemented as an exchange of maps between
! the root nodes of each component's communicator, and then propagated
! across the local component's communicator.  This requires the user to
! provide the local communicator (the input {\tt INTEGER} argument
! {\tt LocalComm}).  The success (failure) of this operation is reported
! in the zero (nonzero) value of the output {\tt INTEGER} argument
! {\tt ierr}.
!
! !INTERFACE:

 subroutine ExGMapGSMap_(LocalGMap, LocalComm, RemoteGSMap, &
                         RemoteCompID, ierr)

!
! !USES:
!
      use m_mpif90
      use m_die
      use m_stdio

      use m_GlobalMap, only : GlobalMap

      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_init => init
      use m_GlobalSegMap, only : GlobalSegMap_clean => clean

      use m_ConvertMaps, only : GlobalMapToGlobalSegMap

      implicit none

! !INPUT PARAMETERS:

      type(GlobalMap),    intent(in)  :: LocalGMap    ! Local GlobalMap
      integer,            intent(in)  :: LocalComm    ! Local Communicator
      integer,            intent(in)  :: RemoteCompID ! Remote component id


! !OUTPUT PARAMETERS:

      type(GlobalSegMap), intent(out) :: RemoteGSMap ! Remote GlobalSegMap
      integer,            intent(out) :: ierr        ! Error Flag

! !REVISION HISTORY:
!  3Feb01 - J.W. Larson <larson@mcs.anl.gov> - API specification.
! 26Sep02 - J.W. Larson <larson@mcs.anl.gov> - Implementation.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ExGMapGSMap_'
  type(GlobalSegMap) :: LocalGSMap

       ! Convert LocalGMap to a GlobalSegMap

  call GlobalMapToGlobalSegMap(LocalGMap, LocalGSMap)

       ! Exchange local decomposition in GlobalSegMap form with
       ! the remote component:

  call ExGSMapGSMap_(LocalGSMap, LocalComm, RemoteGSMap, &
                     RemoteCompID, ierr)

       ! Destroy LocalGSMap

  call GlobalSegMap_clean(LocalGSMap)

 end subroutine ExGMapGSMap_

 end module m_ExchangeMaps







