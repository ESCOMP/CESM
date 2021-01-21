!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_GlobalSegMapComms - GlobalSegMap Communications Support
!
! !DESCRIPTION:
!
! This module provides communications support for the {\tt GlobalSegMap}
! datatype.  Both blocking and non-blocking point-to-point communications
! are provided for send (analogues to {\tt MPI\_SEND()/MPI\_ISEND()})
! A receive and broadcast method is also supplied.
!
! !INTERFACE:

 module m_GlobalSegMapComms

      implicit none

      private   ! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: send
      public :: recv
      public :: isend
      public :: bcast

      interface bcast ; module procedure bcast_ ; end interface
      interface send  ; module procedure send_  ; end interface
      interface recv  ; module procedure recv_  ; end interface
      interface isend ; module procedure isend_ ; end interface

! !REVISION HISTORY:
! 11Aug03 - J.W. Larson <larson@mcs.anl.gov> - initial version
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_GlobalSegMapComms'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: send_ - Point-to-point blocking Send of a GlobalSegMap
!
! !DESCRIPTION:
! This routine performs a blocking send of a {\tt GlobalSegMap} (the
! input argument {\tt outgoingGSMap}) to the root processor on component
! {\tt comp\_id}. The input {\tt INTEGER} argument {\tt TagBase}
! is used to generate tags for the messages associated with this operation;
! there are six messages involved, so the user should avoid using tag
! values {\tt TagBase} and {\tt TagBase + 5}.  All six messages are blocking.
! The success (failure) of this operation is reported in the zero
! (non-zero) value of the optional {\tt INTEGER} output variable {\tt status}.
!
! !INTERFACE:

 subroutine send_(outgoingGSMap, comp_id, TagBase, status)

!
! !USES:
!
      use m_mpif90
      use m_die, only : MP_perr_die,die
      use m_stdio

      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_ngseg => ngseg
      use m_GlobalSegMap, only : GlobalSegMap_comp_id => comp_ID
      use m_GlobalSegMap, only : GlobalSegMap_gsize => gsize

      use m_MCTWorld, only : ComponentToWorldRank
      use m_MCTWorld, only : ThisMCTWorld

      implicit none

! !INPUT PARAMETERS:

  type(GlobalSegMap),    intent(IN)  :: outgoingGSMap
  integer,               intent(IN)  :: comp_id
  integer,               intent(IN)  :: TagBase

! !OUTPUT PARAMETERS:

  integer, optional,     intent(OUT) :: status

! !REVISION HISTORY:
! 13Aug03 - J.W. Larson <larson@mcs.anl.gov> - API and initial version.
! 26Aug03 - R. Jacob <jacob@mcs.anl.gov> - use same method as isend_
! 05Mar04 - R. Jacob <jacob@mcs.anl.gov> - match new isend_ method.
!EOP ___________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::send_'

  integer :: ierr
  integer :: destID
  integer :: nsegs

  if(present(status)) status = 0 ! the success value

  destID = ComponentToWorldRank(0, comp_id, ThisMCTWorld)

       ! Next, send the buffer size to destID so it can prepare a
       ! receive buffer of the correct size.
  nsegs = GlobalSegMap_ngseg(outgoingGSMap)

  call MPI_SEND(outgoingGSMap%comp_id, 1, MP_Type(outgoingGSMap%comp_id), destID, &
                TagBase, ThisMCTWorld%MCT_comm, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Send compid failed',ierr)
  endif

  call MPI_SEND(outgoingGSMap%ngseg, 1, MP_Type(outgoingGSMap%ngseg), destID, &
                TagBase+1, ThisMCTWorld%MCT_comm, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Send ngseg failed',ierr)
  endif

  call MPI_SEND(outgoingGSMap%gsize, 1, MP_Type(outgoingGSMap%gsize), destID, &
                TagBase+2, ThisMCTWorld%MCT_comm, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Send gsize failed',ierr)
  endif


       ! Send segment information data (3 messages)

  call MPI_SEND(outgoingGSMap%start, nsegs, &
                MP_Type(outgoingGSMap%start(1)), &
                destID, TagBase+3, ThisMCTWorld%MCT_comm, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Send outgoingGSMap%start failed',ierr)
  endif

  call MPI_SEND(outgoingGSMap%length, nsegs, &
                MP_Type(outgoingGSMap%length(1)), &
                destID, TagBase+4, ThisMCTWorld%MCT_comm, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Send outgoingGSMap%length failed',ierr)
  endif

  call MPI_SEND(outgoingGSMap%pe_loc, nsegs, &
                MP_Type(outgoingGSMap%pe_loc(1)), &
                destID, TagBase+5, ThisMCTWorld%MCT_comm, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Send outgoingGSMap%pe_loc failed',ierr)
  endif

 end subroutine send_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: isend_ - Point-to-point Non-blocking Send of a GlobalSegMap
!
! !DESCRIPTION:
! This routine performs a non-blocking send of a {\tt GlobalSegMap} (the
! input argument {\tt outgoingGSMap}) to the root processor on component
! {\tt comp\_id}  The input {\tt INTEGER} argument {\tt TagBase}
! is used to generate tags for the messages associated with this operation;
! there are six messages involved, so the user should avoid using tag
! values {\tt TagBase} and {\tt TagBase + 5}.  All six messages are non-
! blocking, and the request handles for them are returned in the output
! {\tt INTEGER} array {\tt reqHandle}, which can be checked for completion
! using any of MPI's wait functions.  The success (failure) of
! this operation is reported in the zero (non-zero) value of the optional
! {\tt INTEGER} output variable {\tt status}.
!
! {\bf N.B.}:  Data is sent directly out of {\tt outgoingGSMap} so it
! must not be deleted until the send has completed.
!
! {\bf N.B.}:  The array {\tt reqHandle} represents allocated memory that
! must be deallocated when it is no longer needed.  Failure to do so will
! create a memory leak.
!
! !INTERFACE:

 subroutine isend_(outgoingGSMap, comp_id, TagBase, reqHandle, status)

!
! !USES:
!
      use m_mpif90
      use m_die, only : MP_perr_die,die
      use m_stdio

      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_ngseg => ngseg

      use m_MCTWorld, only : ComponentToWorldRank
      use m_MCTWorld, only : ThisMCTWorld

      implicit none

! !INPUT PARAMETERS:

  type(GlobalSegMap),    intent(IN)  :: outgoingGSMap
  integer,               intent(IN)  :: comp_id
  integer,               intent(IN)  :: TagBase

! !OUTPUT PARAMETERS:

  integer, dimension(:), pointer     :: reqHandle
  integer, optional,     intent(OUT) :: status

! !REVISION HISTORY:
! 13Aug03 - J.W. Larson <larson@mcs.anl.gov> - API and initial version.
! 05Mar04 - R. Jacob <jacob@mcs.anl.gov> - Send everything directly out
!           of input GSMap.  Don't use a SendBuffer.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::isend_'

  integer :: ierr,destID,nsegs

  if(present(status)) status = 0 ! the success value

  destID = ComponentToWorldRank(0, comp_id, ThisMCTWorld)

  allocate(reqHandle(6), stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8)') myname_, &
	  'FATAL--allocation of send buffer failed with ierr=',ierr
     call die(myname_)
  endif

       ! Next, send the buffer size to destID so it can prepare a
       ! receive buffer of the correct size (3 messages).
  nsegs = GlobalSegMap_ngseg(outgoingGSMap)

  call MPI_ISEND(outgoingGSMap%comp_id, 1, MP_Type(outgoingGSMap%comp_id), destID, &
                TagBase, ThisMCTWorld%MCT_comm, reqHandle(1), ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Send compid failed',ierr)
  endif

  call MPI_ISEND(outgoingGSMap%ngseg, 1, MP_Type(outgoingGSMap%ngseg), destID, &
                TagBase+1, ThisMCTWorld%MCT_comm, reqHandle(2), ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Send ngseg failed',ierr)
  endif

  call MPI_ISEND(outgoingGSMap%gsize, 1, MP_Type(outgoingGSMap%gsize), destID, &
                TagBase+2, ThisMCTWorld%MCT_comm, reqHandle(3), ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Send gsize failed',ierr)
  endif

       ! Send segment information data (3 messages)

  call MPI_ISEND(outgoingGSMap%start, nsegs, &
                MP_Type(outgoingGSMap%start(1)), &
                destID, TagBase+3, ThisMCTWorld%MCT_comm, reqHandle(4), ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Send outgoingGSMap%start failed',ierr)
  endif

  call MPI_ISEND(outgoingGSMap%length, nsegs, &
                MP_Type(outgoingGSMap%length(1)), &
                destID, TagBase+4, ThisMCTWorld%MCT_comm, reqHandle(5), ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Send outgoingGSMap%length failed',ierr)
  endif

  call MPI_ISEND(outgoingGSMap%pe_loc, nsegs, &
                MP_Type(outgoingGSMap%pe_loc(1)), &
                destID, TagBase+5, ThisMCTWorld%MCT_comm, reqHandle(6), ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Send outgoingGSMap%pe_loc failed',ierr)
  endif

 end subroutine isend_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: recv_ - Point-to-point blocking Receive of a GlobalSegMap
!
! !DESCRIPTION:
! This routine performs a blocking receive of a {\tt GlobalSegMap} (the
! input argument {\tt outgoingGSMap}) from the root processor on component
! {\tt comp\_id}. The input {\tt INTEGER} argument {\tt TagBase}
! is used to generate tags for the messages associated with this operation;
! there are six messages involved, so the user should avoid using tag
! values {\tt TagBase} and {\tt TagBase + 5}. The success (failure) of this
! operation is reported in the zero (non-zero) value of the optional {\tt INTEGER}
! output variable {\tt status}.
!
! !INTERFACE:

 subroutine recv_(incomingGSMap, comp_id, TagBase, status)

!
! !USES:
!
      use m_mpif90
      use m_die, only : MP_perr_die, die
      use m_stdio

      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_init => init

      use m_MCTWorld, only : ComponentToWorldRank
      use m_MCTWorld, only : ThisMCTWorld

      implicit none

! !INPUT PARAMETERS:

  integer,               intent(IN)  :: comp_id
  integer,               intent(IN)  :: TagBase

! !OUTPUT PARAMETERS:

  type(GlobalSegMap),    intent(OUT) :: incomingGSMap
  integer, optional,     intent(OUT) :: status

! !REVISION HISTORY:
! 13Aug03 - J.W. Larson <larson@mcs.anl.gov> - API and initial version.
! 25Aug03 - R.Jacob <larson@mcs.anl.gov> - rename to recv_.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::recv_'

  integer :: ierr,sourceID
  integer :: MPstatus(MP_STATUS_SIZE)
  integer :: RecvBuffer(3)

  if(present(status)) status = 0 ! the success value

  sourceID = ComponentToWorldRank(0, comp_id, ThisMCTWorld)

       ! Receive the GlobalSegMap's basic constants:  component id,
       ! grid size, and number of segments.  The number of segments
       ! is needed to construct the arrays into which segment
       ! information will be received.  Thus, this receive blocks.

  call MPI_RECV(RecvBuffer(1), 1, MP_Type(RecvBuffer(1)), sourceID, &
                TagBase, ThisMCTWorld%MCT_comm, MPstatus, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Receive of compid failed',ierr)
  endif
  call MPI_RECV(RecvBuffer(2), 1, MP_Type(RecvBuffer(2)), sourceID, &
                TagBase+1, ThisMCTWorld%MCT_comm, MPstatus, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Receive of ngseg failed',ierr)
  endif
  call MPI_RECV(RecvBuffer(3), 1, MP_Type(RecvBuffer(3)), sourceID, &
                TagBase+2, ThisMCTWorld%MCT_comm, MPstatus, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Receive of gsize failed',ierr)
  endif

       ! Create Empty GlobaSegMap into which segment information
       ! will be received

  call GlobalSegMap_init(incomingGSMap, RecvBuffer(1), RecvBuffer(2), &
                         RecvBuffer(3))

       ! Receive segment information data (3 messages)

  call MPI_RECV(incomingGSMap%start, RecvBuffer(2), &
                MP_Type(incomingGSMap%start(1)), &
                sourceID, TagBase+3, ThisMCTWorld%MCT_comm, MPstatus, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Recv incomingGSMap%start failed',ierr)
  endif

  call MPI_RECV(incomingGSMap%length, RecvBuffer(2), &
                MP_Type(incomingGSMap%length(1)), &
                sourceID, TagBase+4, ThisMCTWorld%MCT_comm, MPstatus, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Recv incomingGSMap%length failed',ierr)
  endif

  call MPI_RECV(incomingGSMap%pe_loc, RecvBuffer(2), &
                MP_Type(incomingGSMap%pe_loc(1)), &
                sourceID, TagBase+5, ThisMCTWorld%MCT_comm, MPstatus, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_, 'Recv incomingGSMap%pe_loc failed',ierr)
  endif

 end subroutine recv_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: bcast_ - broadcast a GlobalSegMap object
!
! !DESCRIPTION:
!
! The routine {\tt bcast\_()} takes the input/output {\em GlobalSegMap}
! argument {\tt GSMap} (on input valid only on the {\tt root} process,
! on output valid on all processes) and broadcasts it to all processes
! on the communicator associated with the F90 handle {\tt comm}.  The
! success (failure) of this operation is returned as a zero (non-zero)
! value of the optional output {\tt INTEGER} argument {\tt status}.
!
! !INTERFACE:

 subroutine bcast_(GSMap, root, comm, status)

!
! !USES:
!
      use m_mpif90
      use m_die, only : MP_perr_die,die
      use m_stdio

      use m_GlobalSegMap, only : GlobalSegMap

      implicit none

! !INPUT PARAMETERS:

      integer,            intent(in)     :: root
      integer,            intent(in)     :: comm

! !INPUT/OUTPUT PARAMETERS:

      type(GlobalSegMap), intent(inout)  :: GSMap  ! Output GlobalSegMap

! !OUTPUT PARAMETERS:

      integer, optional,  intent(out)    :: status ! global vector size

! !REVISION HISTORY:
! 17Oct01 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
! 11Aug03 - J.W. Larson <larson@mcs.anl.gov> - Relocated from original
!           location in m_GlobalSegMap.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::bcast_'

  integer :: myID, ierr, n
  integer, dimension(:), allocatable :: IntBuffer

       ! Step One:  which process am I?

  call MP_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) call MP_perr_die(myname_,'MP_comm_rank()',ierr)

       ! Step Two:  Broadcast the scalar bits of the GlobalSegMap from
       ! the root.

  allocate(IntBuffer(3), stat=ierr) ! allocate buffer space (all PEs)
  if(ierr /= 0) then
    if(.not. present(status)) then
       call die(myname_,'allocate(IntBuffer)',ierr)
    else
       write(stderr,*) myname_,':: error during allocate(IntBuffer)'
       status = 2
       return
    endif
  endif

  if(myID == root) then ! pack the buffer
     IntBuffer(1) = GSMap%comp_id
     IntBuffer(2) = GSMap%ngseg
     IntBuffer(3) = GSMap%gsize
  endif

  call MPI_BCAST(IntBuffer, 3, MP_type(IntBuffer(1)), root, comm, ierr)
  if(ierr /= 0) call MP_perr_die(myname_,'MPI_BCAST(IntBuffer)',ierr)

  if(myID /= root) then ! unpack from buffer to GSMap
     GSMap%comp_id = IntBuffer(1)
     GSMap%ngseg = IntBuffer(2)
     GSMap%gsize = IntBuffer(3)
  endif

  deallocate(IntBuffer, stat=ierr) ! deallocate buffer space
  if(ierr /= 0) then
    if(.not. present(status)) then
       call die(myname_,'deallocate(IntBuffer)',ierr)
    else
       write(stderr,*) myname_,':: error during deallocate(IntBuffer)'
       status = 4
       return
    endif
  endif

       ! Step Three:  Broadcast the vector bits of GSMap from the root.
       ! Pack them into one big array to save latency costs associated
       ! with multiple broadcasts.

  allocate(IntBuffer(3*GSMap%ngseg), stat=ierr) ! allocate buffer space (all PEs)
  if(ierr /= 0) then
    if(.not. present(status)) then
       call die(myname_,'second allocate(IntBuffer)',ierr)
    else
       write(stderr,*) myname_,':: error during second allocate(IntBuffer)'
       status = 5
       return
    endif
  endif

  if(myID == root) then ! pack outgoing broadcast buffer
     do n=1,GSMap%ngseg
	IntBuffer(n) = GSMap%start(n)
	IntBuffer(GSMap%ngseg+n) = GSMap%length(n)
	IntBuffer(2*GSMap%ngseg+n) = GSMap%pe_loc(n)
     end do
  endif

  call MPI_BCAST(IntBuffer, 3*GSMap%ngseg, MP_Type(IntBuffer(1)), root, comm, ierr)
  if(ierr /= 0) call MP_perr_die(myname_,'Error in second MPI_BCAST(IntBuffer)',ierr)

  if(myID /= root) then ! Allocate GSMap%start, GSMap%length,...and fill them

     allocate(GSMap%start(GSMap%ngseg), GSMap%length(GSMap%ngseg), &
	      GSMap%pe_loc(GSMap%ngseg), stat=ierr)
     if(ierr /= 0) then
	if(.not. present(status)) then
	   call die(myname_,'off-root allocate(GSMap%start...)',ierr)
	else
	   write(stderr,*) myname_,':: error during off-root allocate(GSMap%start...)'
	   status = 7
	   return
	endif
     endif

     do n=1,GSMap%ngseg ! unpack the buffer into the GlobalSegMap
	GSMap%start(n) = IntBuffer(n)
	GSMap%length(n) = IntBuffer(GSMap%ngseg+n)
	GSMap%pe_loc(n) = IntBuffer(2*GSMap%ngseg+n)
     end do

  endif

       ! Clean up buffer space:

  deallocate(IntBuffer, stat=ierr)
  if(ierr /= 0) then
    if(.not. present(status)) then
       call die(myname_,'second deallocate(IntBuffer)',ierr)
    else
       write(stderr,*) myname_,':: error during second deallocate(IntBuffer)'
       status = 8
       return
    endif
  endif

 end subroutine bcast_

 end module m_GlobalSegMapComms
