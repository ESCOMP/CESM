!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_GeneralGridComms - Communications for the GeneralGrid type.
!
! !DESCRIPTION:
!
! In this module, we define communications methods specific to the
! {\tt GeneralGrid} class (see the module {\tt m\_GeneralGrid} for more
! information about this class and its methods).
!
! !INTERFACE:
 module m_GeneralGridComms
!
! !USES:
!
      use m_GeneralGrid ! GeneralGrid class and its methods


      implicit none

      private   ! except

      public :: gather          ! gather all local vectors to the root
      public :: scatter         ! scatter from the root to all PEs
      public :: bcast           ! bcast from root to all PEs
      public :: send            ! Blocking SEND
      public :: recv            ! Blocking RECEIVE

    interface gather ; module procedure &
              GM_gather_, &
              GSM_gather_
    end interface
    interface scatter ; module procedure &
              GM_scatter_, &
              GSM_scatter_
    end interface
    interface bcast ; module procedure bcast_ ; end interface
    interface send  ; module procedure send_  ; end interface
    interface recv  ; module procedure recv_  ; end interface

! !REVISION HISTORY:
!       27Apr01 - J.W. Larson <larson@mcs.anl.gov> - Initial module/APIs
!       07Jun01 - J.W. Larson <larson@mcs.anl.gov> - Added point-to-point
!       27Mar02 - J.W. Larson <larson@mcs.anl.gov> - Overhaul of error
!                 handling calls throughout this module.
!       05Aug02 - E. Ong <eong@mcs.anl.gov> - Added buffer association
!                 error checks to avoid making bad MPI calls
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_GeneralGridComms'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: send_ - Point-to-point blocking send for the GeneralGrid.
!
! !DESCRIPTION:  The point-to-point send routine {\tt send\_()} sends
! the input {\tt GeneralGrid} argument {\tt iGGrid} to component
! {\tt comp\_id}.
! The message is identified by the tag defined by the {\tt INTEGER}
! argument {\tt TagBase}.  The value of {\tt TagBase} must match the
! value used in the call to {\tt recv\_()} on process {\tt dest}.  The
! success (failure) of this operation corresponds to a zero (nonzero)
! value for the output {\tt INTEGER} flag {\tt status}.
! The argument will be sent to the local root of the component.
!
! {\bf N.B.}:  One must avoid assigning elsewhere the MPI tag values
! between {\tt TagBase} and {\tt TagBase+20}, inclusive.  This is
! because {\tt send\_()} performs one send operation set up the header
! transfer, up to five {\tt List\_send} operations (two {\tt MPI\_SEND}
! calls in each), two send operations to transfer {\tt iGGrid\%descend(:)},
! and finally the send of the {\tt AttrVect} component {\tt iGGrid\%data}
! (which comprises eight {\tt MPI\_SEND} operations).
!
! !INTERFACE:

 subroutine send_(iGGrid, comp_id, TagBase, status)

!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_init => init
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      use m_MCTWorld, only : ComponentToWorldRank
      use m_MCTWorld, only : ThisMCTWorld

      use m_AttrVectComms,only : AttrVect_send => send

      use m_List, only : List_send => send
      use m_List, only : List_allocated => allocated

      implicit none

! !INPUT PARAMETERS:
!
      type(GeneralGrid), intent(in) :: iGGrid
      integer,           intent(in) :: comp_id
      integer,           intent(in) :: TagBase

! !OUTPUT PARAMETERS:
!
      integer, optional, intent(out) :: status

! !REVISION HISTORY:
!       04Jun01 - J.W. Larson <larson@mcs.anl.gov> - API Specification.
!       07Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!       10Jun01 - J.W. Larson <larson@mcs.anl.gov> - Bug fixes--now works.
!       11Jun01 - R. Jacob <jacob@mcs.anl.gov> use component id as input
!                 argument.
!       13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize status
!                 (if present).
!       15Feb02 - J.W. Larson <larson@mcs.anl.gov> - Made input argument
!                 comm optional.
!       13Jun02 - J.W. Larson <larson@mcs.anl.gov> - Removed the argument
!                 comm.  This routine is now explicitly for intercomponent
!                 communications only.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::send_'

  integer :: ierr
  integer :: dest
  logical :: HeaderAssoc(6)

      ! Initialize status (if present)

  if(present(status)) status = 0

  dest = ComponentToWorldRank(0, comp_id, ThisMCTWorld)

      ! Step 1. Check elements of the GeneralGrid header to see
      ! which components of it are allocated.  Load the results
      ! into HeaderAssoc(:), and send it to process dest.

  HeaderAssoc(1) = List_allocated(iGGrid%coordinate_list)
  HeaderAssoc(2) = List_allocated(iGGrid%coordinate_sort_order)
  HeaderAssoc(3) = associated(iGGrid%descend)
  HeaderAssoc(4) = List_allocated(iGGrid%weight_list)
  HeaderAssoc(5) = List_allocated(iGGrid%other_list)
  HeaderAssoc(6) = List_allocated(iGGrid%index_list)

  call MPI_SEND(HeaderAssoc, 6, MP_LOGICAL, dest, TagBase, ThisMCTWorld%MCT_comm, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,':: MPI_SEND(HeaderAssoc...',ierr)
  endif

       ! Step 2.  If iGGrid%coordinate_list is defined, send it.

  if(HeaderAssoc(1)) then
    call List_send(iGGrid%coordinate_list, dest, TagBase+1, ThisMCTWorld%MCT_comm, ierr)
    if(ierr /= 0) then
       write(stderr,*) myname_,':: call List_send(iGGrid%coordinate_list...', &
	    'Error flag ierr = ',ierr
       if(present(status)) then
          status = ierr
          return
       else
          call die(myname_,':: call List_send(iGGrid%coordinate_list...',ierr)
       endif
    endif
  else  ! This constitutes an error, as a GeneralGrid must have coordinates

     if(present(status)) then
	write(stderr,*) myname_,':: Error.  GeneralGrid%coordinate_list undefined.'
	status = -1
	return
     else
	call die(myname_,'::  Error.  GeneralGrid%coordinate_list undefined.',-1)
     endif

  endif ! if(HeaderAssoc(1))...

       ! Step 3.  If iGGrid%coordinate_sort_order is defined, send it.

  if(HeaderAssoc(2)) then
    call List_send(iGGrid%coordinate_sort_order, dest, TagBase+3, ThisMCTWorld%MCT_comm, ierr)
    if(ierr /= 0) then
       if(present(status)) then
          write(stderr,*) myname_,':: call List_send(iGGrid%coordinate_sort_order...'
          status = ierr
          return
       else
          call die(myname_,':: call List_send(iGGrid%coordinate_sort_order...',ierr)
       endif
    endif

  endif ! if(HeaderAssoc(2))...

       ! Step 4.  If iGGrid%descend is allocated, determine its size,
       ! send this size, and then send the elements of iGGrid%descend.

  if(HeaderAssoc(3)) then

     if(size(iGGrid%descend)<=0) call die(myname_,'size(iGGrid%descend)<=0')

     call MPI_SEND(size(iGGrid%descend), 1, MP_type(size(iGGrid%descend)), &
                   dest, TagBase+5, ThisMCTWorld%MCT_comm, ierr)
     if(ierr /= 0) then
	call MP_perr_die(myname_,':: call MPI_SEND(size(iGGrid%descend)...',ierr)
     endif

     call MPI_SEND(iGGrid%descend, size(iGGrid%descend), MP_type(iGGrid%descend(1)), &
                   dest, TagBase+6, ThisMCTWorld%MCT_comm, ierr)
     if(ierr /= 0) then
	call MP_perr_die(myname_,':: call MPI_SEND(iGGrid%descend...',ierr)
     endif

  endif ! if(HeaderAssoc(3))...

       ! Step 5.  If iGGrid%weight_list is defined, send it.

  if(HeaderAssoc(4)) then

    call List_send(iGGrid%weight_list, dest, TagBase+7, ThisMCTWorld%MCT_comm, ierr)
    if(ierr /= 0) then
       if(present(status)) then
          write(stderr,*) myname_,':: call List_send(iGGrid%weight_list...'
          status = ierr
          return
       else
          call die(myname_,':: call List_send(iGGrid%weight_list...',ierr)
       endif
    endif

  endif ! if(HeaderAssoc(4))...

       ! Step 6.  If iGGrid%other_list is defined, send it.

  if(HeaderAssoc(5)) then

    call List_send(iGGrid%other_list, dest, TagBase+9, ThisMCTWorld%MCT_comm, ierr)
    if(ierr /= 0) then
       if(present(status)) then
          write(stderr,*) myname_,':: call List_send(iGGrid%other_list...'
          status = ierr
          return
       else
          call die(myname_,':: call List_send(iGGrid%other_list...',ierr)
       endif
    endif

  endif ! if(HeaderAssoc(5))...

       ! Step 7.  If iGGrid%index_list is defined, send it.

  if(HeaderAssoc(6)) then

    call List_send(iGGrid%index_list, dest, TagBase+11, ThisMCTWorld%MCT_comm, ierr)
    if(ierr /= 0) then
       if(present(status)) then
          write(stderr,*) myname_,':: call List_send(iGGrid%index_list...'
          status = ierr
          return
       else
          call die(myname_,':: call List_send(iGGrid%index_list...',ierr)
       endif
    endif

  else  ! This constitutes an error, as a GeneralGrid must at a minimum
        ! contain the index GlobGridNum

     if(present(status)) then
	write(stderr,*) myname_,':: Error.  GeneralGrid%index_list undefined.'
	status = -2
	return
     else
	call die(myname_,'::  Error.  GeneralGrid%index_list undefined.',-2)
     endif

  endif ! if(HeaderAssoc(6))...

       ! Step 8.  Finally, send the AttrVect iGGrid%data.

  call AttrVect_send(iGGrid%data, dest, TagBase+13, ThisMCTWorld%MCT_comm, ierr)
  if(ierr /= 0) then
     if(present(status)) then
	write(stderr,*) myname_,':: call AttrVect_send(iGGrid%data...'
	status = ierr
	return
     else
	call die(myname_,':: call AttrVect_send(iGGrid%data...',ierr)
     endif
  endif

       ! The GeneralGrid send is now complete.

 end subroutine send_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: recv_ - Point-to-point blocking recv for the GeneralGrid.
!
! !DESCRIPTION:  The point-to-point receive routine {\tt recv\_()}
! receives the output {\tt GeneralGrid} argument {\tt oGGrid} from component
! {\tt comp\_id}.  The message is identified by the tag defined by the
! {\tt INTEGER} argument {\tt TagBase}.  The value of {\tt TagBase} must
! match the value used in the call to {\tt send\_()} on the other component.
! The success (failure) of this operation corresponds to a zero (nonzero)
! value for the output {\tt INTEGER} flag {\tt status}.
!
! {\bf N.B.}:  This routine assumes that the {\tt GeneralGrid} argument
! {\tt oGGrid} is uninitialized on input; that is, all the {\tt List}
! components are blank, the {\tt LOGICAL} array {\tt oGGrid\%descend} is
! unallocated, and the {\tt AttrVect} component {\tt oGGrid\%data} is
! uninitialized.  The {\tt GeneralGrid} {\tt oGGrid} represents allocated
! memory.  When the user no longer needs {\tt oGGrid}, it should be
! deallocated by invoking {\tt GeneralGrid\_clean()} (see
! {\tt m\_GeneralGrid} for further details).
!
! {\bf N.B.}:  One must avoid assigning elsewhere the MPI tag values
! between {\tt TagBase} and {\tt TagBase+20}, inclusive.  This is
! because {\tt recv\_()} performs one receive operation set up the header
! transfer, up to five {\tt List\_recv} operations (two {\tt MPI\_RECV}
! calls in each), two receive operations to transfer {\tt iGGrid\%descend(:)},
! and finally the receive of the {\tt AttrVect} component {\tt iGGrid\%data}
! (which comprises eight {\tt MPI\_RECV} operations).
!
! !INTERFACE:

 subroutine recv_(oGGrid, comp_id, TagBase, status)

!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_init => init
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      use m_MCTWorld, only : ComponentToWorldRank
      use m_MCTWorld, only : ThisMCTWorld

      use m_AttrVectComms,only : AttrVect_recv => recv

      use m_List,only : List_recv => recv
      use m_List,only : List_nullify => nullify

      implicit none

! !INPUT PARAMETERS:
!
      integer,           intent(in) :: comp_id
      integer,           intent(in) :: TagBase

! !OUTPUT PARAMETERS:
!
      type(GeneralGrid), intent(out) :: oGGrid
      integer, optional, intent(out) :: status

! !REVISION HISTORY:
!       04Jun01 - J.W. Larson <larson@mcs.anl.gov> - API Specification.
!       07Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!       10Jun01 - J.W. Larson <larson@mcs.anl.gov> - Bug fixes--now works.
!       11Jun01 - R. Jacob <jacob@mcs.anl.gov> use component id as input
!                 argument.
!       13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize status
!                 (if present).
!       13Jun02 - J.W. Larson <larson@mcs.anl.gov> - Removed the argument
!                 comm.  This routine is now explicitly for intercomponent
!                 communications only.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::recv_'

  integer :: ierr
  integer :: source
  integer :: MPstatus(MP_STATUS_SIZE), DescendSize
  logical :: HeaderAssoc(6)

! for now, assume the components root is the source.
  source = ComponentToWorldRank(0, comp_id, ThisMCTWorld)

      ! Step 1. Receive the elements of the LOGICAL flag array
      ! HeaderAssoc.  TRUE entries in this array correspond to
      ! Check elements of the GeneralGrid header that are not
      ! blank, and are being sent by process source.
      !
      ! The significance of the entries of HeaderAssoc has been
      ! defined in send_().  Here are the definitions of these
      ! values:
      !
      !  HeaderAssoc(1) = List_allocated(oGGrid%coordinate_list)
      !  HeaderAssoc(2) = List_allocated(oGGrid%coordinate_sort_order)
      !  HeaderAssoc(3) = associated(oGGrid%descend)
      !  HeaderAssoc(4) = List_allocated(oGGrid%weight_list)
      !  HeaderAssoc(5) = List_allocated(oGGrid%other_list)
      !  HeaderAssoc(6) = List_allocated(oGGrid%index_list)

      ! Initialize status (if present)

  if(present(status)) status = 0

      ! Step 1.  Nullify oGGrid components, set HeaderAssoc(:) to .FALSE.,
      ! then receive incoming HeaderAssoc(:) data

  call List_nullify(oGGrid%coordinate_list)
  call List_nullify(oGGrid%coordinate_sort_order)
  call List_nullify(oGGrid%weight_list)
  call List_nullify(oGGrid%other_list)
  call List_nullify(oGGrid%index_list)
  nullify(oGGrid%descend)

  HeaderAssoc = .FALSE.

  call MPI_RECV(HeaderAssoc, 6, MP_LOGICAL, source, TagBase, ThisMCTWorld%MCT_comm, MPstatus, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,':: MPI_RECV(HeaderAssoc...',ierr)
  endif

       ! Step 2.  If oGGrid%coordinate_list is defined, receive it.

  if(HeaderAssoc(1)) then
    call List_recv(oGGrid%coordinate_list, source, TagBase+1, ThisMCTWorld%MCT_comm, ierr)
    if(ierr /= 0) then
       if(present(status)) then
          write(stderr,*) myname_,':: call List_recv(oGGrid%coordinate_list...'
          status = ierr
          return
       else
          call die(myname_,':: call List_recv(oGGrid%coordinate_list...',ierr)
       endif
    endif
  else  ! This constitutes an error, as a GeneralGrid must have coordinates

     if(present(status)) then
	write(stderr,*) myname_,':: Error.  GeneralGrid%coordinate_list undefined.'
	status = -1
	return
     else
	call die(myname_,'::  Error.  GeneralGrid%coordinate_list undefined.',-1)
     endif

  endif ! if(HeaderAssoc(1))...

       ! Step 3.  If oGGrid%coordinate_sort_order is defined, receive it.

  if(HeaderAssoc(2)) then
     call List_recv(oGGrid%coordinate_sort_order, source, TagBase+3, ThisMCTWorld%MCT_comm, ierr)
     if(ierr /= 0) then
	if(present(status)) then
	   write(stderr,*) myname_,':: Error calling ',&
		'List_recv(oGGrid%coordinate_sort_order...'
	   status = ierr
	   return
	else
	   call die(myname_,':: call List_recv(oGGrid%coordinate_sort_order...', ierr)
	endif
     endif
  endif ! if(HeaderAssoc(2))...

       ! Step 4.  If oGGrid%descend is allocated, determine its size,
       ! receive this size, allocate oGGrid%descend, and then receive
       ! the elements of oGGrid%descend.

  if(HeaderAssoc(3)) then

     call MPI_RECV(DescendSize, 1, MP_type(DescendSize), &
                   source, TagBase+5, ThisMCTWorld%MCT_comm, MPstatus, ierr)
     if(ierr /= 0) then
	   call MP_perr_die(myname_,':: call MPI_RECV(size(oGGrid%descend)...',ierr)
     endif

     allocate(oGGrid%descend(DescendSize), stat=ierr)
     if(ierr /= 0) then
	if(present(status)) then
	   write(stderr,*) myname_,':: allocate(oGGrid%descend...'
	   status = ierr
	   return
	else
	   call die(myname_,':: allocate(oGGrid%descend... failed.',ierr)
	endif
     endif

     call MPI_RECV(oGGrid%descend, DescendSize, MP_type(oGGrid%descend(1)), &
                   source, TagBase+6, ThisMCTWorld%MCT_comm, MPstatus, ierr)
     if(ierr /= 0) then
	   call MP_perr_die(myname_,':: call MPI_RECV(oGGrid%descend...',ierr)
     endif

  endif ! if(HeaderAssoc(3))...

       ! Step 5.  If oGGrid%weight_list is defined, receive it.

  if(HeaderAssoc(4)) then

    call List_recv(oGGrid%weight_list, source, TagBase+7, ThisMCTWorld%MCT_comm, ierr)
    if(ierr /= 0) then
       if(present(status)) then
          write(stderr,*) myname_,':: call List_recv(oGGrid%weight_list...'
          status = ierr
          return
       else
          call die(myname_,':: call List_recv(oGGrid%weight_list...',ierr)
       endif
    endif

  endif ! if(HeaderAssoc(4))...

       ! Step 6.  If oGGrid%other_list is defined, receive it.

  if(HeaderAssoc(5)) then

    call List_recv(oGGrid%other_list, source, TagBase+9, ThisMCTWorld%MCT_comm, ierr)
    if(ierr /= 0) then
       if(present(status)) then
          write(stderr,*) myname_,':: call List_recv(oGGrid%other_list...'
          status = ierr
          return
       else
          call die(myname_,':: call List_recv(oGGrid%other_list...',ierr)
       endif
    endif

  endif ! if(HeaderAssoc(5))...

       ! Step 7.  If oGGrid%index_list is defined, receive it.

  if(HeaderAssoc(6)) then

    call List_recv(oGGrid%index_list, source, TagBase+11, ThisMCTWorld%MCT_comm, ierr)
    if(ierr /= 0) then
       if(present(status)) then
          write(stderr,*) myname_,':: call List_recv(oGGrid%index_list...'
          status = ierr
          return
       else
          call die(myname_,':: call List_recv(oGGrid%index_list...',ierr)
       endif
    endif

  else  ! This constitutes an error, as a GeneralGrid must at a minimum
        ! contain the index GlobGridNum

     if(present(status)) then
	write(stderr,*) myname_,':: Error.  GeneralGrid%index_list undefined.'
	status = -2
	return
     else
	call die(myname_,'::  Error.  GeneralGrid%index_list undefined.',-2)
     endif

  endif ! if(HeaderAssoc(6))...

       ! Step 8.  Finally, receive the AttrVect oGGrid%data.

  call AttrVect_recv(oGGrid%data, source, TagBase+13, ThisMCTWorld%MCT_comm, ierr)
  if(ierr /= 0) then
     if(present(status)) then
	write(stderr,*) myname_,':: call AttrVect_recv(oGGrid%data...'
	status = ierr
	return
     else
	call die(myname_,':: call AttrVect_recv(oGGrid%data...',ierr)
     endif
  endif

       ! The GeneralGrid receive is now complete.

 end subroutine recv_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GM_gather_ - gather a GeneralGrid using input GlobalMap.
!
! !DESCRIPTION:  {\tt GM\_gather\_()} takes an input {\tt GeneralGrid}
! argument {\tt iG} whose decomposition on the communicator associated
! with the F90 handle {\tt comm} is described by the {\tt GlobalMap}
! argument {\tt GMap}, and gathers it to the {\tt GeneralGrid} output
! argument {\tt oG} on the {\tt root}.  The success (failure) of this
! operation is reported as a zero (nonzero) value in the optional
! {\tt INTEGER} output argument {\tt stat}.

! {\bf N.B.}:  An important assumption made here is that the distributed
! {\tt GeneralGrid} {\tt iG} has been initialized with the same
! coordinate system, sort order, other real attributes, and the same
! indexing attributes for all processes on {\tt comm}.
!
! {\bf N.B.}:  Once the gridpoint data of the {\tt GeneralGrid} are assembled
! on the {\tt root}, they are stored in the order determined by the input
! {\tt GlobalMap} {\tt GMap}.  The user may need to sorted these gathered
! data to order them in  accordance with the {\tt coordinate\_sort\_order}
! attribute of {\tt iG}.
!
! {\bf N.B.}:  The output {\tt GeneralGrid} {\tt oG} represents allocated
! memory on the {\tt root}.  When the user no longer needs {\tt oG} it
! should be deallocated using {\tt GeneralGrid\_clean()} to avoid a memory
! leak
!
! !INTERFACE:
!
 subroutine GM_gather_(iG, oG, GMap, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_GlobalMap, only : GlobalMap
      use m_GlobalMap, only : GlobalMap_gsize => gsize

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_init => init

      use m_AttrVectComms,only : AttrVect_Gather => gather

      implicit none

! !INPUT PARAMETERS:
!
      type(GeneralGrid), intent(in)  :: iG
      type(GlobalMap),   intent(in)  :: GMap
      integer,           intent(in)  :: root
      integer,           intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      type(GeneralGrid), intent(out) :: oG
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!       27Apr01 - J.W. Larson <larson@mcs.anl.gov> - API Specification.
!       02May01 - J.W. Larson <larson@mcs.anl.gov> - Initial code.
!       13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize stat
!                 (if present).
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::GM_gather_'
!Process ID
 integer :: myID
!Error flag
 integer :: ierr
!Number of points on the _Gathered_ grid:
 integer :: length

      ! Initialize stat (if present)

  if(present(stat)) stat = 0

       ! Which process am I?

  call MPI_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) then
    call MP_perr_die(myname_,'call MPI_COMM_RANK()',ierr)
  endif

  if(myID == root) then ! prepare oG:

       ! The length of the _gathered_ GeneralGrid oG is determined by
       ! the GlobalMap function GlobalMap_gsize()

     length = GlobalMap_gsize(GMap)

       ! Initialize attributes of oG from iG
     call copyGeneralGridHeader_(iG,oG)

  endif

       ! Gather gridpoint data in iG%data to oG%data

  call AttrVect_Gather(iG%data, oG%data, GMap, root, comm, ierr)

  if(ierr /= 0) then
     write(stderr,*) myname_,':: Error--call AttrVect_Gather() failed.', &
	  ' ierr = ',ierr
     if(present(stat)) then
	stat=ierr
	return
     else
	call die(myname_,'call AttrVect_Gather(ig%data...',ierr)
     endif
  endif

 end subroutine GM_gather_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GSM_gather_ - gather a GeneralGrid using input GlobalSegMap.
!
! !DESCRIPTION:  {\tt GMS\_gather\_()} takes an input {\tt GeneralGrid}
! argument {\tt iG} whose decomposition on the communicator associated
! with the F90 handle {\tt comm} is described by the {\tt GlobalSegMap}
! argument {\tt GSMap}, and gathers it to the {\tt GeneralGrid} output
! argument {\tt oG} on the {\tt root}.  The success (failure) of this
! operation is reported as a zero (nonzero) value in the optional
! {\tt INTEGER} output argument {\tt stat}.
!
! {\bf N.B.}:  An important assumption made here is that the distributed
! {\tt GeneralGrid} {\tt iG} has been initialized with the same
! coordinate system, sort order, other real attributes, and the same
! indexing attributes for all processes on {\tt comm}.
!
! {\bf N.B.}:  Once the gridpoint data of the {\tt GeneralGrid} are assembled
! on the {\tt root}, they are stored in the order determined by the input
! {\tt GlobalSegMap} {\tt GSMap}.  The user may need to sorted these gathered
! data to order them in  accordance with the {\tt coordinate\_sort\_order}
! attribute of {\tt iG}.
!
! {\bf N.B.}:  The output {\tt GeneralGrid} {\tt oG} represents allocated
! memory on the {\tt root}.  When the user no longer needs {\tt oG} it
! should be deallocated using {\tt GeneralGrid\_clean()} to avoid a memory
! leak
!
! !INTERFACE:

 subroutine GSM_gather_(iG, oG, GSMap, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_lsize => lsize
      use m_GlobalSegMap, only : GlobalSegMap_gsize => gsize

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_init => init
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      use m_AttrVectComms,only : AttrVect_Gather => gather

      implicit none

! !INPUT PARAMETERS:
!
      type(GeneralGrid),  intent(in)  :: iG
      type(GlobalSegMap), intent(in)  :: GSMap
      integer,            intent(in)  :: root
      integer,            intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      type(GeneralGrid),  intent(out) :: oG
      integer, optional,  intent(out) :: stat

! !REVISION HISTORY:
!       27Apr01 - J.W. Larson <larson@mcs.anl.gov> - API Specification.
!       01May01 - J.W. Larson <larson@mcs.anl.gov> - Working Version.
!       13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize stat
!                 (if present).
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GSM_gather_'

!Process ID
 integer :: myID
!Error flag
 integer :: ierr
!Number of points on the _Gathered_ grid:
 integer :: length

      ! Initialize stat (if present)

  if(present(stat)) stat = 0

       ! Which process am I?

  call MPI_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) then
    call MP_perr_die(myname_,'MPI_COMM_RANK()',ierr)
  endif

  if(myID == root) then ! prepare oG:

       ! The length of the _gathered_ GeneralGrid oG is determined by
       ! the GlobalMap function GlobalSegMap_gsize()

     length = GlobalSegMap_gsize(GSMap)

       ! Initialize attributes of oG from iG
     call copyGeneralGridHeader_(iG,oG)

  endif

       ! Gather gridpoint data in iG%data to oG%data

  call AttrVect_Gather(iG%data, oG%data, GSMap, root, comm, ierr)
  if(ierr /= 0) then
     write(stderr,*) myname_,':: ERROR--call AttrVect_Gather() failed.', &
	  ' ierr = ',ierr
    if(present(stat)) then
       stat=ierr
       return
    else
       call die(myname_)
    endif
  endif

 end subroutine GSM_gather_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GM_scatter_ - scatter a GeneralGrid using input GlobalMap.
!
! !DESCRIPTION:  {\tt GM\_scatter\_()} takes an input {\tt GeneralGrid}
! argument {\tt iG} (valid only on the {\tt root} process), and scatters
! it to the distributed {\tt GeneralGrid} variable {\tt oG}.  The
! {\tt GeneralGrid} {\tt oG} is distributed on the communicator
! associated with the F90  handle {\tt comm} using the domain
! decomposition described by the {\tt GlobalMap} argument {\tt GMap}.
! The success (failure) of this operation is reported as a zero (nonzero)
! value in the optional {\tt INTEGER} output argument {\tt stat}.
!
! {\bf N.B.}:  The output {\tt GeneralGrid} {\tt oG} represents allocated
! memory on the {\tt root}.  When the user no longer needs {\tt oG} it
! should be deallocated using {\tt GeneralGrid\_clean()} to avoid a memory
! leak.
!
! !INTERFACE:

 subroutine GM_scatter_(iG, oG, GMap, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_GlobalMap, only : GlobalMap
      use m_GlobalMap, only : GlobalMap_lsize => lsize
      use m_GlobalMap, only : GlobalMap_gsize => gsize

      use m_AttrVectComms, only : AttrVect_scatter => scatter

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_init => init
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(GeneralGrid), intent(in)  :: iG
      type(GlobalMap),   intent(in)  :: GMap
      integer,           intent(in)  :: root
      integer,           intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      type(GeneralGrid), intent(out) :: oG
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!       27Apr01 - J.W. Larson <larson@mcs.anl.gov> - API Specification.
!       04Jun01 - J.W. Larson <larson@mcs.anl.gov> - Changed comms model
!                 to MPI-style (i.e. iG valid on root only).
!       13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize stat
!                 (if present).
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GM_scatter_'

  logical :: DescendAssoc
  integer :: DescendSize
  integer :: ierr, myID

      ! Initialize status (if present)

  if(present(stat)) stat = 0

       ! Step 1.  Determine process ID number myID

  call MPI_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,'MPI_COMM_RANK(comm...',ierr)
  endif

       ! Step 2.  On the root, initialize the List and LOGICAL
       ! attributes of the GeneralGrid variable iG to oG.

  if(myID == root) then
     call copyGeneralGridHeader_(iG, oG)
  endif

       ! Step 3.  Broadcast from the root the List and LOGICAL
       ! attributes of the GeneralGrid variable oG.

  call bcastGeneralGridHeader_(oG, root, comm, ierr)
  if(ierr /= 0) then
     write(stderr,*) myname_,':: Error calling bcastGeneralGridHeader_().',&
	  ' ierr = ',ierr
     if(present(stat)) then
	stat = ierr
	return
     else
	call die(myname_,'call bcastGeneralGridHeader_(oG...',ierr)
     endif
  endif


       ! Step 4.  Using the GeneralMap GMap, scatter the AttrVect
       ! portion of the input GeneralGrid iG to the GeneralGrid oG.

  call AttrVect_scatter(iG%data, oG%data, GMap, root, comm, ierr)
  if(ierr /= 0) then
     write(stderr,*) myname_,':: Error calling AttrVect_scatter(iG%data...',&
	  ' ierr = ',ierr
     if(present(stat)) then
	stat = ierr
	return
     else
	call die(myname_,'call AttrVect_scatter(iG%data...',ierr)
     endif
  endif

       ! The GeneralGrid scatter is now complete.

 end subroutine GM_scatter_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GSM_scatter_ - scatter a GeneralGrid using input GlobalSegMap.
!
! !DESCRIPTION:  {\tt GM\_scatter\_()} takes an input {\tt GeneralGrid}
! argument {\tt iG} (valid only on the {\tt root} process), and scatters
! it to the distributed {\tt GeneralGrid} variable {\tt oG}.  The
! {\tt GeneralGrid} {\tt oG} is distributed on the communicator
! associated with the F90  handle {\tt comm} using the domain
! decomposition described by the {\tt GlobalSegMap} argument {\tt GSMap}.
! The success (failure) of this operation is reported as a zero (nonzero)
! value in the optional {\tt INTEGER} output argument {\tt stat}.
!
! {\bf N.B.}:  The output {\tt GeneralGrid} {\tt oG} represents allocated
! memory on the {\tt root}.  When the user no longer needs {\tt oG} it
! should be deallocated using {\tt GeneralGrid\_clean()} to avoid a memory
! leak.
!
! !INTERFACE:

 subroutine GSM_scatter_(iG, oG, GSMap, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_lsize => lsize
      use m_GlobalSegMap, only : GlobalSegMap_gsize => gsize

      use m_AttrVectComms, only : AttrVect_scatter => scatter

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_init => init
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(GeneralGrid),  intent(in)  :: iG
      type(GlobalSegMap), intent(in)  :: GSMap
      integer,            intent(in)  :: root
      integer,            intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      type(GeneralGrid),  intent(out) :: oG
      integer, optional,  intent(out) :: stat

! !REVISION HISTORY:
!       27Apr01 - J.W. Larson <larson@mcs.anl.gov> - API Specification.
!       04Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initial code.
!       13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize stat
!                 (if present).
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GSM_scatter_'

  integer :: ierr, myID

      ! Initialize stat (if present)

  if(present(stat)) stat = 0

       ! Step 1.  Determine process ID number myID

  call MPI_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,'MPI_COMM_RANK(comm...',ierr)
  endif

       ! Step 2.  On the root, initialize the List and LOGICAL
       ! attributes of the GeneralGrid variable iG to oG.

  if(myID == root) then
     call copyGeneralGridHeader_(iG, oG)
  endif

       ! Step 3.  Broadcast from the root the List and LOGICAL
       ! attributes of the GeneralGrid variable oG.

  call bcastGeneralGridHeader_(oG, root, comm, ierr)
  if(ierr /= 0) then
     write(stderr,*) myname_,':: Error calling bcastGeneralGridHeader_(...',&
	  ' ierr = ',ierr
     if(present(stat)) then
	stat = ierr
	return
     else
	call die(myname_,'bcastGeneralGridHeader_(oG...',ierr)
     endif
  endif

       ! Step 4.  Using the GeneralSegMap GSMap, scatter the AttrVect
       ! portion of the input GeneralGrid iG to the GeneralGrid oG.

  call AttrVect_scatter(iG%data, oG%data, GSMap, root, comm, ierr)
  if(ierr /= 0) then
     write(stderr,*) myname_,':: Error calling AttrVect_scatter(iG%data...',&
	  ' ierr = ',ierr
     if(present(stat)) then
	stat = ierr
	return
     else
	call die(myname_,'call AttrVect_scatter(iG%data...',ierr)
     endif
  endif

       ! The GeneralGrid scatter is now complete.

 end subroutine GSM_scatter_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: bcast_ - Broadcast a GeneralGrid.
!
! !DESCRIPTION:  {\tt bcast\_()} takes an input {\tt GeneralGrid}
! argument {\tt ioG} (valid only on the {\tt root} process), and
! broadcasts it to all processes on the communicator associated with the
! F90  handle {\tt comm}.  The success (failure) of this operation is
! reported as a zero (nonzero) value in the optional {\tt INTEGER}
! output argument {\tt stat}.
!
! {\bf N.B.}:  On the non-root processes, the output {\tt GeneralGrid}
! {\tt ioG} represents allocated memory.  When the user no longer needs
! {\tt ioG} it should be deallocated by invoking {\tt GeneralGrid\_clean()}.
! Failure to do so risks a memory leak.
!
! !INTERFACE:

 subroutine bcast_(ioG, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_lsize => lsize
      use m_GlobalSegMap, only : GlobalSegMap_gsize => gsize

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_init => init
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      use m_AttrVectComms,only : AttrVect_bcast => bcast

      implicit none

! !INPUT PARAMETERS:
!
      integer,           intent(in)    :: root
      integer,           intent(in)    :: comm

! !INPUT/OUTPUT PARAMETERS:
!
      type(GeneralGrid), intent(inout) :: ioG

! !OUTPUT PARAMETERS:
!
      integer, optional, intent(out)   :: stat

! !REVISION HISTORY:
!       27Apr01 - J.W. Larson <larson@mcs.anl.gov> - API Specification.
!       02May01 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!       13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize stat
!                 (if present).
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::bcast_'

  integer :: ierr, myID

      ! Initialize status (if present)

  if(present(stat)) stat = 0

       ! Step 1.  Determine process ID number myID

  call MPI_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,'MPI_COMM_RANK(comm...',ierr)
  endif

       ! Step 2.  Broadcast from the root the List and LOGICAL
       ! attributes of the GeneralGrid variable ioG.

  call bcastGeneralGridHeader_(ioG, root, comm, ierr)
  if(ierr /= 0) then
     write(stderr,*) myname_,':: Error calling bcastGeneralGridHeader_(...',&
	  ' ierr = ',ierr
     if(present(stat)) then
	stat = ierr
	return
     else
	call die(myname_)
     endif
  endif

       ! Step 3.  Broadcast ioG%data from the root.

  call AttrVect_bcast(ioG%data, root, comm, ierr)
  if(ierr /= 0) then
     write(stderr,*) myname_,':: Error calling AttrVect_scatter(iG%data...',&
	  ' ierr = ',ierr
     if(present(stat)) then
	stat = ierr
	return
     else
	call die(myname_)
     endif
  endif

       ! The GeneralGrid broadcast is now complete.

 end subroutine bcast_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: bcastGeneralGridHeader_ - Broadcast the GeneralGrid Header.
!
! !DESCRIPTION:  This routine broadcasts the header information from
! the input {\tt GeneralGrid} argument {\tt ioGGrid} (on input valid
! on the {\tt root} only).  This broadcast is from the {\tt root} to
! all processes on the communicator associated with the fortran 90
! {\tt INTEGER} handle {\tt comm}.  The success (failure) of this operation
! corresponds to a zero (nonzero) value for the output {\tt INTEGER} flag
! {\tt stat}.
!
! The {\em header information} in a {\tt GeneralGrid} variable comprises
! all the non-{\tt AttrVect} components of the {\tt GeneralGrid}; that
! is, everything except the gridpoint coordinate, geometry, and index
! data stored in {\tt iGGrid\%data}.  This information includes:
! \begin{enumerate}
! \item The coordinates in {\tt iGGrid\%coordinate\_list}
! \item The coordinate sort order in {\tt iGGrid\%coordinate\_sort\_order}
! \item The area/volume weights in {\tt iGGrid\%weight\_list}
! \item Other {\tt REAL} geometric information in {\tt iGGrid\%other\_list}
! \item Indexing information in {\tt iGGrid\%index\_list}
! \item The {\tt LOGICAL} descending/ascending order sort flags in
! {\tt iGGrid\%descend(:)}.
! \end{enumerate}
!
! !INTERFACE:

 subroutine bcastGeneralGridHeader_(ioGGrid, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_lsize => lsize
      use m_GlobalSegMap, only : GlobalSegMap_gsize => gsize

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_init => init
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      use m_List, only : List
      use m_List, only : List_allocated => allocated
      use m_List, only : List_nullify => nullify
      use m_List, only : List_bcast => bcast

      implicit none

! !INPUT PARAMETERS:
!
      integer,           intent(in)    :: root
      integer,           intent(in)    :: comm

! !INPUT/OUTPUT PARAMETERS:
!
      type(GeneralGrid), intent(inout) :: ioGGrid

! !OUTPUT PARAMETERS:
!
      integer, optional, intent(out)   :: stat

! !REVISION HISTORY:
!       05Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initial code.
!       13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize stat
!                 (if present).
!       05Aug02 - E. Ong <eong@mcs.anl.gov> - added association checking
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::bcastGeneralGridHeader_'

! Process ID
  integer :: myID
! Error flag
  integer :: ierr
! Size of array ioGGrid%descend(:)
  integer :: DescendSize
! Header-Assocation array
  logical :: HeaderAssoc(6)

      ! Initialize stat (if present)

  if(present(stat)) stat = 0

       ! Determine process ID number myID

  call MPI_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,'MPI_COMM_RANK(comm...',ierr)
  endif

       ! Step 0.5. Check elements of the GeneralGrid header to see
       ! which components of it are allocated.  Load the results
       ! into HeaderAssoc(:), and broadcast it.

  if(myID == root) then

     HeaderAssoc(1) = List_allocated(ioGGrid%coordinate_list)
     HeaderAssoc(2) = List_allocated(ioGGrid%coordinate_sort_order)
     HeaderAssoc(3) = List_allocated(ioGGrid%weight_list)
     HeaderAssoc(4) = List_allocated(ioGGrid%other_list)
     HeaderAssoc(5) = List_allocated(ioGGrid%index_list)
     HeaderAssoc(6) = associated(ioGGrid%descend)

  else

     call List_nullify(ioGGrid%coordinate_list)
     call List_nullify(ioGGrid%coordinate_sort_order)
     call List_nullify(ioGGrid%weight_list)
     call List_nullify(ioGGrid%other_list)
     call List_nullify(ioGGrid%index_list)
     nullify(ioGGrid%descend)

  endif

  call MPI_BCAST(HeaderAssoc,6,MP_LOGICAL,root,comm,ierr)

       ! Step 1. Broadcast List attributes of the GeneralGrid.

  if(HeaderAssoc(1)) then
     call List_bcast(ioGGrid%coordinate_list, root, comm, ierr)
     if(ierr /= 0) then
        write(stderr,*) myname_,'List_bcast(ioGGrid%coordinate_list... failed.',&
             ' ierr = ',ierr
        if(present(stat)) then
           stat = ierr
           return
        else
           call die(myname_)
        endif
     endif
  endif

  if(HeaderAssoc(2)) then
     call List_bcast(ioGGrid%coordinate_sort_order, root, comm, ierr)
     if(ierr /= 0) then
        write(stderr,*) myname_,'List_bcast(ioGGrid%coordinate_sort_order... failed', &
             ' ierr = ',ierr
        if(present(stat)) then
           stat = ierr
           return
        else
           call die(myname_)
        endif
     endif
  endif

  if(HeaderAssoc(3)) then
     call List_bcast(ioGGrid%weight_list, root, comm, ierr)
     if(ierr /= 0) then
        write(stderr,*) myname_,'List_bcast(ioGGrid%weight_list... failed',&
             ' ierr = ',ierr
        if(present(stat)) then
           stat = ierr
           return
        else
           call die(myname_)
        endif
     endif
  endif

  if(HeaderAssoc(4)) then
     call List_bcast(ioGGrid%other_list, root, comm, ierr)
     if(ierr /= 0) then
        write(stderr,*) myname_,'List_bcast(ioGGrid%other_list... failed',&
             ' ierr = ',ierr
        if(present(stat)) then
           stat = ierr
           return
        else
           call die(myname_)
        endif
     endif
  endif

  if(HeaderAssoc(5)) then
     call List_bcast(ioGGrid%index_list, root, comm, ierr)
     if(ierr /= 0) then
        write(stderr,*) myname_,'List_bcast(ioGGrid%index_list... failed',&
             ' ierr = ',ierr
        if(present(stat)) then
           stat = ierr
           return
        else
           call die(myname_)
        endif
     endif
  endif

       ! If ioGGrid%descend is associated on the root, prepare and
       ! execute its broadcast

  if(HeaderAssoc(6)) then

       ! On the root, get the size of ioGGrid%descend(:)

     if(myID == root) then
        DescendSize = size(ioGGrid%descend)
        if(DescendSize<=0) call die(myname_,'size(ioGGrid%descend)<=0')
     endif

       ! Broadcast the size of ioGGrid%descend(:) from the root.

     call MPI_BCAST(DescendSize, 1, MP_INTEGER, root, comm, ierr)
     if(ierr /= 0) then
        call MP_perr_die(myname_,'MPI_BCAST(DescendSize...',ierr)
     endif

       ! Off the root, allocate ioGGrid%descend(:)

     if(myID /= root) then
        allocate(ioGGrid%descend(DescendSize), stat=ierr)
        if(ierr /= 0) then
           write(stderr,*) myname_,':: ERROR in allocate(ioGGrid%descend...',&
                ' ierr = ',ierr
           call die(myname_)
        endif
     endif

      ! Finally, broadcast ioGGrid%descend(:) from the root

     call MPI_BCAST(ioGGrid%descend, DescendSize, MP_LOGICAL, root, &
                    comm, ierr)
     if(ierr /= 0) then
        call MP_perr_die(myname_,'MPI_BCAST(ioGGrid%descend...',ierr)
     endif

  endif

       ! The broadcast of the GeneralGrid Header from the &
       ! root is complete.


 end subroutine bcastGeneralGridHeader_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: copyGeneralGridHeader_ - Copy the GeneralGrid Header.
!
! !DESCRIPTION:  This routine copies the header information from the
! input {\tt GeneralGrid} argument {\tt iGGrid} to the output
! {\tt GeneralGrid} argument {\tt oGGrid}.  The {\em header information}
! in a {\tt GeneralGrid} variable comprises all the non-{\tt AttrVect}
! components of the {\tt GeneralGrid}; that is, everything except the
! gridpoint coordinate, geometry, and index data stored in
! {\tt iGGrid\%data}.  This information includes:
! \begin{enumerate}
! \item The coordinates in {\tt iGGrid\%coordinate\_list}
! \item The coordinate sort order in {\tt iGGrid\%coordinate\_sort\_order}
! \item The area/volume weights in {\tt iGGrid\%weight\_list}
! \item Other {\tt REAL} geometric information in {\tt iGGrid\%other\_list}
! \item Indexing information in {\tt iGGrid\%index\_list}
! \item The {\tt LOGICAL} descending/ascending order sort flags in
! {\tt iGGrid\%descend(:)}.
! \end{enumerate}
!
! !INTERFACE:

 subroutine copyGeneralGridHeader_(iGGrid, oGGrid)
!
! !USES:
!
      use m_stdio
      use m_die

      use m_List, only : List
      use m_List, only : List_copy => copy
      use m_List, only : List_allocated => allocated
      use m_List, only : List_nullify => nullify

      use m_GeneralGrid, only : GeneralGrid

      implicit none

! !INPUT PARAMETERS:
!
      type(GeneralGrid), intent(in)  :: iGGrid

! !OUTPUT PARAMETERS:
!
      type(GeneralGrid), intent(out) :: oGGrid

! !REVISION HISTORY:
!       05Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initial code.
!       08Aug01 - E.T. Ong <eong@mcs.anl.gov> - changed list assignments(=)
!                 to list copy.
!       05Aug02 - E. Ong <eong@mcs.anl.gov> - added association checking
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::copyGeneralGridHeader_'

  logical :: DescendAssoc
  integer :: DescendSize, i, ierr

       ! Step 1. Copy GeneralGrid List attributes from iGGrid
       ! to oGGrid.

  call List_nullify(oGGrid%coordinate_list)
  call List_nullify(oGGrid%coordinate_sort_order)
  call List_nullify(oGGrid%weight_list)
  call List_nullify(oGGrid%other_list)
  call List_nullify(oGGrid%index_list)
  nullify(oGGrid%descend)

  if(List_allocated(iGGrid%coordinate_list)) then
     call List_copy(oGGrid%coordinate_list,iGGrid%coordinate_list)
  endif

  if(List_allocated(iGGrid%coordinate_sort_order)) then
     call List_copy(oGGrid%coordinate_sort_order,iGGrid%coordinate_sort_order)
  endif

  if(List_allocated(iGGrid%weight_list)) then
     call List_copy(oGGrid%weight_list,iGGrid%weight_list)
  endif

  if(List_allocated(iGGrid%other_list)) then
     call List_copy(oGGrid%other_list,iGGrid%other_list)
  endif

  if(List_allocated(iGGrid%index_list)) then
     call List_copy(oGGrid%index_list,iGGrid%index_list)
  endif

  DescendAssoc = associated(iGGrid%descend)
  if(DescendAssoc) then

     DescendSize = size(iGGrid%descend)
     allocate(oGGrid%descend(DescendSize), stat=ierr)
     if(ierr /= 0) then
	write(stderr,*) myname_,':: ERROR--allocate(iGGrid%descend(... failed.',&
	     ' ierr = ', ierr, 'DescendSize = ', DescendSize
        call die(myname_)
     endif
     do i=1,DescendSize
	oGGrid%descend(i) = iGGrid%descend(i)
     end do

  endif

       ! The GeneralGrid header copy is now complete.

 end subroutine copyGeneralGridHeader_

 end module m_GeneralGridComms
























