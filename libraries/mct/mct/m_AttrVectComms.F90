!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_AttrVectComms - MPI Communications Methods for the AttrVect
!
! !DESCRIPTION:
!
! This module defines the communications methods for the {\tt AttrVect}
! datatype (see the module {\tt m\_AttrVect} for more information about
! this class and its methods).  MCT's communications are implemented
! in terms of the Message Passing Interface (MPI) standard, and we have
! as best as possible, made the interfaces to these routines appear as
! similar as possible to the corresponding MPI routines.  For the
! { \tt AttrVect}, we supply {\em blocking} point-to-point send and
! receive operations.  We also supply the following collective
! operations: broadcast, gather, and scatter.  The gather and scatter
! operations rely on domain decomposition descriptors that are defined
! elsewhere in MCT:  the {\tt GlobalMap}, which is a one-dimensional
! decomposition (see the MCT module {\tt m\_GlobalMap} for more details);
! and the {\tt GlobalSegMap}, which is a segmented decomposition capable
! of supporting multidimensional domain decompositions (see the MCT module
! {\tt m\_GlobalSegMap} for more details).
!
! !INTERFACE:
 module m_AttrVectComms
!
! !USES:
!
      use m_AttrVect ! AttrVect class and its methods

      implicit none

      private	! except

      public :: gather		! gather all local vectors to the root
      public :: scatter		! scatter from the root to all PEs
      public :: bcast		! bcast from root to all PEs
      public :: send		! send an AttrVect
      public :: recv		! receive an AttrVect

    interface gather ; module procedure &
	      GM_gather_, &
	      GSM_gather_
    end interface
    interface scatter ; module procedure &
	      GM_scatter_, &
	      GSM_scatter_
    end interface
    interface bcast  ; module procedure bcast_  ; end interface
    interface send  ; module procedure send_  ; end interface
    interface recv  ; module procedure recv_  ; end interface

! !REVISION HISTORY:
! 27Oct00 - J.W. Larson <larson@mcs.anl.gov> - relocated routines
!           from m_AttrVect to create this module.
! 15Jan01 - J.W. Larson <larson@mcs.anl.gov> - Added APIs for
!           GSM_gather_() and GSM_scatter_().
!  9May01 - J.W. Larson <larson@mcs.anl.gov> - Modified GM_scatter_
!           so its communication model agrees with MPI_scatter().
!           Also tidied up prologues in all module routines.
!  7Jun01 - J.W. Larson <larson@mcs.anl.gov> - Added send()
!           and recv().
!  3Aug01 - E.T. Ong <eong@mcs.anl.gov> - in GSM_scatter, call
!           GlobalMap_init with actual shaped array to satisfy
!           Fortran 90 standard. See comment in subroutine.
! 23Aug01 - E.T. Ong <eong@mcs.anl.gov> - replaced assignment(=)
!           with copy for list type to avoid compiler bugs in pgf90.
!           Added more error checking in gsm scatter. Fixed minor bugs
!          in gsm and gm gather.
! 13Dec01 - E.T. Ong <eong@mcs.anl.gov> - GSM_scatter, allow users
!           to scatter with a haloed GSMap. Fixed some bugs in
!           GM_scatter.
! 19Dec01 - E.T. Ong <eong@mcs.anl.gov> - allow bcast of an AttrVect
!           with only an integer or real attribute.
! 27Mar02 - J.W. Larson <larson@mcs.anl.gov> - Corrected usage of
!           m_die routines throughout this module.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_AttrVectComms'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: send_ - Point-to-point Send of an AttrVect
!
! !DESCRIPTION:  This routine takes an input {\tt AttrVect} argument
! {\tt inAV} and sends it to processor {\tt dest} on the communicator
! associated with the Fortran {\tt INTEGER} MPI communicator handle
! {\tt comm}.  The overalll message is tagged by the input {\tt INTEGER}
! argument {\tt TagBase}.  The success (failure) of this operation is
! reported in the zero (nonzero) optional output argument {\tt status}.
!
! {\bf N.B.}:  One must avoid assigning elsewhere the MPI tag values
! between {\tt TagBase} and {\tt TagBase+7}, inclusive.  This is
! because {\tt send\_()} performs the send of the {\tt AttrVect} as
! a series of eight send operations.
!
! !INTERFACE:

 subroutine send_(inAV, dest, TagBase, comm, status)
!
! !USES:
!
      use m_stdio
      use m_mpif90
      use m_die

      use m_List, only : List
      use m_List, only : List_allocated => allocated
      use m_List, only : List_nitem => nitem
      use m_List, only : List_send => send

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),     intent(in)  :: inAV
      integer,            intent(in)  :: dest
      integer,            intent(in)  :: TagBase
      integer,            intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      integer, optional,  intent(out) :: status

! !REVISION HISTORY:
!  7Jun01 - J.W. Larson - initial version.
! 13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize status
!           (if present).
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::send_'

 logical :: ListAssoc(2)
 integer :: ierr
 integer :: AVlength

      ! Initialize status (if present)

  if(present(status)) status = 0


       ! Step 1. Are inAV%iList and inAV%rList filled?  Store
       ! the answers in the LOGICAL array ListAssoc and send.

  ListAssoc(1) = List_allocated(inAV%iList)
  ListAssoc(2) = List_allocated(inAV%rList)

  if(.NOT. (ListAssoc(1).or.ListAssoc(2)) ) then
     call die(myname_,"inAV has not been initialized")
  endif

  call MPI_SEND(ListAssoc, 2, MP_LOGICAL, dest, TagBase, comm, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,':: MPI_SEND(ListAssoc...',ierr)
  endif


       ! Step 2. Send non-blank inAV%iList and inAV%rList.

  if(ListAssoc(1)) then
    call List_send(inAV%iList, dest, TagBase+1, comm, ierr)
    if(ierr /= 0) then
       if(present(status)) then
	  write(stderr,*) myname_,':: call List_send(inAV%iList...'
	  status = ierr
	  return
       else
	  call die(myname_,':: call List_send(inAV%iList...',ierr)
       endif
    endif
  endif

  if(ListAssoc(2)) then
    call List_send(inAV%rList, dest, TagBase+3, comm, ierr)
    if(ierr /= 0) then
       if(present(status)) then
	  write(stderr,*) myname_,':: call List_send(inAV%rList...'
	  status = ierr
	  return
       else
	  call die(myname_,':: call List_send(inAV%rList...',ierr)
       endif
    endif
  endif

       ! Step 3. Determine and send the lengths of inAV%iAttr(:,:)
       ! and inAV%rAttr(:,:).

  AVlength = AttrVect_lsize(inAV)

  if(AVlength<=0) then
     call die(myname_,"Size of inAV <= 0",AVLength)
  endif

  call MPI_SEND(AVlength, 1, MP_type(AVlength), dest, TagBase+5, &
                comm, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,':: call MPI_SEND(AVlength...',ierr)
  endif

       ! Step 4. If AVlength > 0, we may have INTEGER and REAL
       ! data to send.  Send as needed.

  if(AVlength > 0) then

     if(ListAssoc(1)) then

       ! Send the INTEGER data stored in inAV%iAttr(:,:)

	call MPI_SEND(inAV%iAttr(1,1), AVlength*List_nitem(inAV%iList), &
                      MP_type(inAV%iAttr(1,1)), dest, TagBase+6,   &
                      comm, ierr)
	if(ierr /= 0) then
	   call MP_perr_die(myname_,':: call MPI_SEND(inAV%iAttr...',ierr)
	endif

     endif ! if(associated(inAV%rList))

     if(ListAssoc(2)) then

       ! Send the REAL data stored in inAV%rAttr(:,:)

	call MPI_SEND(inAV%rAttr(1,1), AVlength*List_nitem(inAV%rList), &
                      MP_type(inAV%rAttr(1,1)), dest, TagBase+7,   &
                      comm, ierr)
	if(ierr /= 0) then
	   call MP_perr_die(myname_,':: call MPI_SEND(inAV%rAttr...',ierr)
	endif

     endif ! if(associated(inAV%rList))

  endif ! if (AVlength > 0)

 end subroutine send_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: recv_ - Point-to-point Receive of an AttrVect
!
! !DESCRIPTION:  This routine receives the output {\tt AttrVect} argument
! {\tt outAV} from processor {\tt source} on the communicator associated
! with the Fortran {\tt INTEGER} MPI communicator handle {\tt comm}.  The
! overall message is tagged by the input {\tt INTEGER} argument
! {\tt TagBase}.  The success (failure) of this operation is reported in
! the zero (nonzero) optional output argument {\tt status}.
!
! {\bf N.B.}:  One must avoid assigning elsewhere the MPI tag values
! between {\tt TagBase} and {\tt TagBase+7}, inclusive.  This is
! because {\tt recv\_()} performs the receive of the {\tt AttrVect} as
! a series of eight receive operations.
!
! !INTERFACE:

 subroutine recv_(outAV, dest, TagBase, comm, status)
!
! !USES:
!
      use m_stdio
      use m_mpif90
      use m_die

      use m_List, only : List
      use m_List, only : List_nitem => nitem
      use m_List, only : List_recv => recv

      use m_AttrVect, only : AttrVect

      implicit none

! !INPUT PARAMETERS:
!
      integer,            intent(in)  :: dest
      integer,            intent(in)  :: TagBase
      integer,            intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      type(AttrVect),     intent(out) :: outAV
      integer, optional,  intent(out) :: status

! !REVISION HISTORY:
!  7Jun01 - J.W. Larson - initial working version.
! 13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize status
!           (if present).
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::recv_'

 logical :: ListAssoc(2)
 integer :: ierr
 integer :: AVlength
 integer :: MPstatus(MP_STATUS_SIZE)

      ! Initialize status (if present)

  if(present(status)) status = 0


       ! Step 1. Are outAV%iList and outAV%rList filled?  TRUE
       ! entries in the LOGICAL array ListAssoc(:) correspond
       ! to Non-blank Lists...that is:
       !
       ! ListAssoc(1) = .TRUE. <==> associated(outAV%iList%bf)
       ! ListAssoc(2) = .TRUE. <==> associated(outAV%rList%bf)

  call MPI_RECV(ListAssoc, 2, MP_LOGICAL, dest, TagBase, comm, &
                MPstatus, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,':: MPI_RECV(ListAssoc...',ierr)
  endif


       ! Step 2. Receive non-blank outAV%iList and outAV%rList.

  if(ListAssoc(1)) then
    call List_recv(outAV%iList, dest, TagBase+1, comm, ierr)
    if(ierr /= 0) then
       if(present(status)) then
	  write(stderr,*) myname_,':: call List_recv(outAV%iList...'
	  status = ierr
	  return
       else
	  call die(myname_,':: call List_recv(outAV%iList...',ierr)
       endif
    endif
  endif

  if(ListAssoc(2)) then
    call List_recv(outAV%rList, dest, TagBase+3, comm, ierr)
    if(ierr /= 0) then
       if(present(status)) then
	  write(stderr,*) myname_,':: call List_recv(outAV%rList...'
	  status = ierr
	  return
       else
	  call die(myname_,':: call List_recv(outAV%rList...',ierr)
       endif
    endif
  endif

       ! Step 3. Receive the lengths of outAV%iAttr(:,:) and outAV%rAttr(:,:).

  call MPI_RECV(AVlength, 1, MP_type(AVlength), dest, TagBase+5, &
                comm, MPstatus, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,':: call MPI_RECV(AVlength...',ierr)
  endif

       ! Step 4. If AVlength > 0, we may have to receive INTEGER
       ! and/or REAL data.  Receive as needed.

  if(AVlength > 0) then

     if(ListAssoc(1)) then

       ! Allocate outAV%iAttr(:,:)

        allocate(outAV%iAttr(List_nitem(outAV%iList),AVlength), stat=ierr)
        if(ierr/=0) call die(myname_,"allocate(outAV%iAttr)",ierr)

       ! Receive the INTEGER data to outAV%iAttr(:,:)

	call MPI_RECV(outAV%iAttr(1,1), AVlength*List_nitem(outAV%iList), &
                      MP_type(outAV%iAttr(1,1)), dest, TagBase+6,   &
                      comm, MPstatus, ierr)
	if(ierr /= 0) then
	   call MP_perr_die(myname_,':: call MPI_RECV(outAV%iAttr...',ierr)
	endif

     endif ! if(associated(outAV%rList))

     if(ListAssoc(2)) then

       ! Allocate outAV%rAttr(:,:)

        allocate(outAV%rAttr(List_nitem(outAV%rList),AVlength), stat=ierr)
        if(ierr/=0) call die(myname_,"allocate(outAV%rAttr)",ierr)

       ! Receive the REAL data to outAV%rAttr(:,:)

	call MPI_RECV(outAV%rAttr(1,1), AVlength*List_nitem(outAV%rList), &
                      MP_type(outAV%rAttr(1,1)), dest, TagBase+7,   &
                      comm, MPstatus, ierr)
	if(ierr /= 0) then
	   call MP_perr_die(myname_,':: call MPI_RECV(outAV%rAttr...',ierr)
	endif

     endif ! if(associated(outAV%rList))

  endif ! if (AVlength > 0)

 end subroutine recv_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GM_gather_ - Gather an AttrVect Distributed by a GlobalMap
!
! !DESCRIPTION:
! This routine gathers a {\em distributed} {\tt AttrVect} {\tt iV} to
! the {\tt root} process, and returns it in the output {\tt AttrVect}
! argument {\tt oV}.  The decomposition of {\tt iV} is described by
! the input {\tt GlobalMap} argument {\tt GMap}.  The input {\tt INTEGER}
! argument {\tt comm} is the Fortran integer MPI communicator handle.
! The success (failure) of this operation corresponds to a zero (nonzero)
! value of the optional output {\tt INTEGER} argument {\tt stat}.
!
! !INTERFACE:

 subroutine GM_gather_(iV, oV, GMap, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : FP
      use m_GlobalMap, only : GlobalMap
      use m_GlobalMap, only : GlobalMap_lsize => lsize
      use m_GlobalMap, only : GlobalMap_gsize => gsize
      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nIAttr => nIAttr
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : AttrVect_clean => clean
      use m_FcComms,  only : fc_gatherv_int, fc_gatherv_fp

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),           intent(in)  :: iV
      type(GlobalMap),          intent(in)  :: GMap
      integer,                  intent(in)  :: root
      integer,                  intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      type(AttrVect),           intent(out) :: oV
      integer,        optional, intent(out) :: stat

! !REVISION HISTORY:
! 15Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 27Oct00 - J.W. Larson <larson@mcs.anl.gov> - relocated from
!           m_AttrVect
! 15Jan01 - J.W. Larson <larson@mcs.anl.gov> - renamed GM_gather_
!  9May01 - J.W. Larson <larson@mcs.anl.gov> - tidied up prologue
! 18May01 - R.L. Jacob <jacob@mcs.anl.gov> - use MP_Type function
!           to determine type for mpi_gatherv
! 31Jan09 - P.H. Worley <worleyph@ornl.gov> - replaced call to
!           MPI_gatherv with call to flow controlled gather routines
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GM_gather_'
  integer :: nIA,nRA,niV,noV,ier
  integer :: myID
  integer :: mp_type_Av
  type(AttrVect) :: nonRootAV

  if(present(stat)) stat=0

  call MP_comm_rank(comm, myID, ier)
  if(ier /= 0) then
     call MP_perr_die(myname_,':: call MP_COMM_RANK()',ier)
  endif

	! Verify the input: a _scatterd_ vector

  niV=GlobalMap_lsize(GMap)
  noV=AttrVect_lsize(iV)

  if(niV /= noV) then
     write(stderr,'(2a,i4,a,i4,a,i4)') myname_,	&
	  ': invalid input, lsize(GMap) =',niV,	&
	  ', lsize(iV) =',noV, 'myID =', myID
     if(.not.present(stat)) call die(myname_)
     stat=-1
     return
  endif

  noV=GlobalMap_gsize(GMap) ! the gathered local size, as for the output

  if(myID == root) then
     call AttrVect_init(oV,iV,noV)
     call AttrVect_zero(oV)
  else
     call AttrVect_init(nonRootAV,iV,1)
     call AttrVect_zero(nonRootAV)
  endif

  niV=GlobalMap_lsize(GMap) ! the scattered local size, as for the input

  nIA=AttrVect_nIAttr(iV)	! number of INTEGER attributes
  nRA=AttrVect_nRAttr(iV)	! number of REAL attributes

  mp_type_Av = MP_Type(1._FP)   ! set mpi type to same as AV%rAttr

  if(nIA > 0) then

     if(myID == root) then

        call fc_gatherv_int(iV%iAttr,niV*nIA,MP_INTEGER,		&
             oV%iAttr,GMap%counts*nIA,GMap%displs*nIA,             &
             MP_INTEGER,root,comm)

     else

        call fc_gatherv_int(iV%iAttr,niV*nIA,MP_INTEGER,		&
             nonRootAV%iAttr,GMap%counts*nIA,GMap%displs*nIA,      &
             MP_INTEGER,root,comm)

     endif  ! if(myID == root)

  endif  ! if(nIA > 0)

  if(nRA > 0) then

     if(myID == root) then

        call fc_gatherv_fp(iV%rAttr,niV*nRA,mp_type_Av,	        &
             oV%rAttr,GMap%counts*nRA,GMap%displs*nRA,             &
             mp_type_Av,root,comm)

     else

        call fc_gatherv_fp(iV%rAttr,niV*nRA,mp_type_Av,	        &
             nonRootAV%rAttr,GMap%counts*nRA,GMap%displs*nRA,      &
             mp_type_Av,root,comm)

     endif  ! if(myID == root)

  endif  ! if(nRA > 0)



  if(myID /= root) then
     call AttrVect_clean(nonRootAV,ier)
     if(ier /= 0) then
        write(stderr,'(2a,i4)') myname_,	&
             ':: AttrVect_clean(nonRootAV) failed for non-root &
             &process: myID = ', myID
        call die(myname_,':: AttrVect_clean failed &
             &for nonRootAV off of root',ier)
     endif
  endif

 end subroutine GM_gather_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GSM_gather_ - Gather an AttrVect Distributed by a GlobalSegMap
!
! !DESCRIPTION:
! The routine {\tt GSM\_gather\_()} takes a distributed input
! {\tt AttrVect} argument {\tt iV}, whose decomposition is described
! by the input {\tt GlobalSegMap} argument {\tt GSMap}, and gathers
! it to the output {\tt AttrVect} argument {\tt oV}.  The gathered
! {\tt AttrVect} {\tt oV} is valid only on the root process specified
! by the input argument {\tt root}.  The communicator used to gather
! the data is specified by the argument {\tt comm}.  The success (failure)
! is reported in the zero (non-zero) value of the output argument
! {\tt stat}.
!
! {\tt GSM\_gather\_()} converts the problem of gathering data
! according to a {\tt GlobalSegMap} into the simpler problem of
! gathering data as specified by a {\tt GlobalMap}.  The {\tt GlobalMap}
! variable {\tt GMap} is created based on the local storage requirements
! for each distributed piece of {\tt iV}.  On the root, a complete
! (including halo points) gathered copy of {\tt iV} is collected into
! the temporary {\tt AttrVect} variable {\tt workV} (the length of
! {\tt workV} is the larger of {\tt GlobalSegMap\_GlobalStorage(GSMap)} or
! {\tt GlobalSegMap\_GlobalSize(GSMap)}).  The
! variable {\tt workV} is segmented by process, and segments are
! copied into it by process, but ordered in the same order the segments
! appear in {\tt GSMap}.  Once {\tt workV} is loaded, the data are
! copied segment-by-segment to their appropriate locations in the output
! {\tt AttrVect} {\tt oV}.
!
! !INTERFACE:

 subroutine GSM_gather_(iV, oV, GSMap, root, comm, stat, rdefault, idefault)
!
! !USES:
!
! Message-passing environment utilities (mpeu) modules:
      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only: FP
! GlobalSegMap and associated services:
      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_comp_id => comp_id
      use m_GlobalSegMap, only : GlobalSegMap_ngseg => ngseg
      use m_GlobalSegMap, only : GlobalSegMap_lsize => lsize
      use m_GlobalSegMap, only : GlobalSegMap_gsize => gsize
      use m_GlobalSegMap, only : GlobalSegMap_haloed => haloed
      use m_GlobalSegMap, only : GlobalSegMap_GlobalStorage => GlobalStorage
! AttrVect and associated services:
      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nIAttr => nIAttr
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : AttrVect_clean => clean
! GlobalMap and associated services:
      use m_GlobalMap, only : GlobalMap
      use m_GlobalMap, only : GlobalMap_init => init
      use m_GlobalMap, only : GlobalMap_clean => clean

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),            intent(in)  :: iV
      type(GlobalSegMap),        intent(in)  :: GSMap
      integer,                   intent(in)  :: root
      integer,                   intent(in)  :: comm
      real(FP), optional,        intent(in)  :: rdefault
      integer, optional,         intent(in)  :: idefault

! !OUTPUT PARAMETERS:
!
      type(AttrVect),            intent(out) :: oV
      integer,        optional,  intent(out) :: stat

! !REVISION HISTORY:
! 15Jan01 - J.W. Larson <larson@mcs.anl.gov> - API specification.
! 25Feb01 - J.W. Larson <larson@mcs.anl.gov> - Prototype code.
! 26Apr01 - R.L. Jacob <jacob@mcs.anl.gov> - add use statement for
!           AttVect_clean
!  9May01 - J.W. Larson <larson@mcs.anl.gov> - tidied up prologue
! 13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize stat
!           (if present).
! 20Aug01 - E.T. Ong <eong@mcs.anl.gov> - Added error checking for
!           matching processors in gsmap and comm. Corrected
!           current_pos assignment.
! 23Nov01 - R. Jacob <jacob@mcs.anl.gov> - zero the oV before copying in
!           gathered data.
! 27Jul07 - R. Loy <rloy@mcs.anl.gov> - add Tony's suggested improvement
!           for a default value in the output AV
! 11Aug08 - R. Jacob <jacob@mcs.anl.gov> - add Pat Worley's faster way
!           to initialize lns
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GSM_gather_'

! Temporary workspace AttrVect:
  type(AttrVect) :: workV
! Component ID and number of segments for GSMap:
  integer :: comp_id, ngseg, iseg
! Total length of GSMap segments laid end-to-end:
  integer :: global_storage
! Error Flag
  integer :: ierr
! Number of processes on communicator, and local rank:
  integer :: NumProcs, myID
! Total local storage on each pe according to GSMap:
  integer, dimension(:), allocatable :: lns
! Temporary GlobalMap used to scatter the segmented (by pe) data
  type(GlobalMap) :: workGMap
! Loop counters and temporary indices:
  integer :: m, n, ilb, iub, olb, oub, pe
! workV segment tracking index array:
  integer, dimension(:), allocatable :: current_pos
! workV sizes
  integer :: gssize, gstorage

      ! Initialize stat (if present)

  if(present(stat)) stat = 0

       ! Initial Check:  If GSMap contains halo points, die

  if(GlobalSegMap_haloed(GSMap)) then
     ierr = 1
     call die(myname_,"Input GlobalSegMap haloed--not allowed",ierr)
  endif

       ! Which process am I?

  call MPI_COMM_RANK(comm, myID, ierr)

  if(ierr /= 0) then
	call MP_perr_die(myname_,':: call MPI_COMM_RANK()',ierr)
  endif
       ! How many processes are there on this communicator?

  call MPI_COMM_SIZE(comm, NumProcs, ierr)

  if(ierr /= 0) then
     call MP_perr_die(myname_,':: call MPI_COMM_SIZE()',ierr)
  endif

       ! Processor Check: Do the processors on GSMap match those in comm?

  if(MAXVAL(GSMap%pe_loc) > (NumProcs-1)) then
     stat=2
     write(stderr,*) myname_, &
       ":: Procs in GSMap%pe_loc do not match procs in communicator ", &
       NumProcs-1, MAXVAL(GSMap%pe_loc)
     call die(myname_, &
	  "Procs in GSMap%pe_loc do not match procs in communicator",stat)
  endif

  if(myID == root) then

       ! Allocate a precursor to a GlobalMap accordingly...

     allocate(lns(0:NumProcs-1), stat=ierr)

       ! And Load it...

     lns(:)=0
     do iseg=1,GSMap%ngseg
        n = GSMap%pe_loc(iseg)
	lns(n) = lns(n) + GSMap%length(iseg)
     end do

  else

     allocate(lns(0)) ! This conforms to F90 standard for shaped arguments.

  endif ! if(myID == root)

       ! Determine the component id of GSMap:

  comp_id = GlobalSegMap_comp_id(GSMap)

       ! Create working GlobalMap workGMap (used for the gather):

  call GlobalMap_init(workGMap, comp_id, lns, root, comm)

       ! Gather the Data process-by-process to workV...
       ! do not include stat argument; bypass an argument check in gm_gather.

  call GM_gather_(iV, workV, workGMap, root, comm, stat)

       ! On the root, initialize oV, and load the contents of
       !workV into it...

  if(myID == root) then

! bug fix:  gstorage will be bigger than gssize if GSmap is
! haloed.  But gstorage may be smaller than gsize if GSmap
! is masked.  So take the maximum.  RLJ
     gstorage = GlobalSegMap_GlobalStorage(GSMap)
     gssize = GlobalSegMap_gsize(GSMap)
     global_storage = MAX(gstorage,gssize)

     call AttrVect_init(oV,iV,global_storage)
     call AttrVect_zero(oV)

     if (present(rdefault)) then
       if (AttrVect_nRAttr(oV) > 0) oV%rAttr=rdefault
     endif
     if (present(idefault)) then
       if (AttrVect_nIAttr(oV) > 0) oV%iAttr=idefault
     endif

       ! On the root, allocate current position index for
       ! each process chunk:

     allocate(current_pos(0:NumProcs-1), stat=ierr)

     if(ierr /= 0) then
	write(stderr,*) myname_,':: allocate(current_pos(..) failed,', &
	     'stat = ',ierr
	if(present(stat)) then
	   stat=ierr
	else
	   call die(myname_,'allocate(current_pos(..) failed.' )
	endif
     endif

       ! Initialize current_pos(:) using GMap%displs(:)

     do n=0,NumProcs-1
	current_pos(n) = workGMap%displs(n) + 1
     end do

       ! Load each segment of iV into its appropriate segment
       ! of workV:

     ngseg = GlobalSegMap_ngseg(GSMap)

     do n=1,ngseg

       ! Determine which process owns segment n:

	pe = GSMap%pe_loc(n)

       ! Input map (lower/upper indicess) of segment of iV:

	ilb = current_pos(pe)
	iub = current_pos(pe) + GSMap%length(n) - 1

       ! Output map of (lower/upper indicess) segment of workV:

	olb = GSMap%start(n)
	oub = GSMap%start(n) + GSMap%length(n) - 1

       ! Increment current_pos(n) for next time:

	current_pos(pe) = current_pos(pe) + GSMap%length(n)

       ! Now we are equipped to do the copy:

	do m=1,AttrVect_nIAttr(iV)
   	   oV%iAttr(m,olb:oub) = workV%iAttr(m,ilb:iub)
	end do

	do m=1,AttrVect_nRAttr(iV)
   	   oV%rAttr(m,olb:oub) = workV%rAttr(m,ilb:iub)
	end do

     end do ! do n=1,ngseg

       ! Clean up current_pos, which was only allocated on the root

     deallocate(current_pos, stat=ierr)
     if(ierr /= 0) then
	write(stderr,*) myname_,'error in deallocate(current_pos), stat=',ierr
	if(present(stat)) then
	   stat=ierr
	else
	   call die(myname_)
	endif
     endif
  endif ! if(myID == root)

       ! At this point, we are finished.  The data have been gathered
       ! to oV

       ! Finally, clean up allocated structures:

  if(myID == root) call AttrVect_clean(workV)
  call GlobalMap_clean(workGMap)

  deallocate(lns, stat=ierr)

  if(ierr /= 0) then
    write(stderr,*) myname_,'error in deallocate(lns), stat=',ierr
    if(present(stat)) then
       stat=ierr
    else
       call die(myname_)
    endif
  endif

 end subroutine GSM_gather_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GM_scatter_ - Scatter an AttrVect Using a GlobalMap
!
! !DESCRIPTION:
! The routine {\tt GM\_scatter\_} takes an input {\tt AttrVect} type
! {\tt iV} (valid only on the root), and scatters it to a distributed
! {\tt AttrVect} {\tt oV}.  The input {\tt GlobalMap} argument
! {\tt GMap} dictates how {\tt iV} is scattered to {\tt oV}.  The
! success (failure) of this routine is reported in the zero (non-zero)
! value of the output argument {\tt stat}.
!
! {\bf N.B.}:  The output {\tt AttrVect} argument {\tt oV} represents
! dynamically allocated memory.  When it is no longer needed, it should
! be deallocated by invoking {\tt AttrVect\_clean()} (see the module
! {\tt m\_AttrVect} for more details).
!
! !INTERFACE:

 subroutine GM_scatter_(iV, oV, GMap, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : FP

      use m_List, only : List
      use m_List, only : List_copy => copy
      use m_List, only : List_bcast => bcast
      use m_List, only : List_clean => clean
      use m_List, only : List_nullify => nullify
      use m_List, only : List_nitem => nitem

      use m_GlobalMap, only : GlobalMap
      use m_GlobalMap, only : GlobalMap_lsize => lsize
      use m_GlobalMap, only : GlobalMap_gsize => gsize

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nIAttr => nIAttr
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : AttrVect_clean => clean

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),           intent(in)  :: iV
      type(GlobalMap),          intent(in)  :: GMap
      integer,                  intent(in)  :: root
      integer,                  intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      type(AttrVect),           intent(out) :: oV
      integer,        optional, intent(out) :: stat

! !REVISION HISTORY:
! 21Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 27Oct00 - J.W. Larson <larson@mcs.anl.gov> - relocated from
!           m_AttrVect
! 15Jan01 - J.W. Larson <larson@mcs.anl.gov> - renamed  GM_scatter_
!  8Feb01 - J.W. Larson <larson@mcs.anl.gov> - add logic to prevent
!           empty calls (i.e. no data in buffer) to MPI_SCATTERV()
! 27Apr01 - R.L. Jacob <jacob@mcs.anl.gov> - small bug fix to
!           integer attribute scatter
!  9May01 - J.W. Larson <larson@mcs.anl.gov> - Re-vamped comms model
!           to reflect MPI comms model for the scatter.  Tidied up
!           the prologue, too.
! 18May01 - R.L. Jacob <jacob@mcs.anl.gov> - use MP_Type function
!           to determine type for mpi_scatterv
!  8Aug01 - E.T. Ong <eong@mcs.anl.gov> - replace list assignment(=)
!           with list copy to avoid compiler errors in pgf90.
! 13Dec01 - E.T. Ong <eong@mcs.anl.gov> - allow scatter with an
!           AttrVect containing only an iList or rList.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GM_scatter_'
  integer :: nIA,nRA,niV,noV,ier
  integer :: myID
  integer :: mp_type_Av
  type(List) :: iList, rList
  type(AttrVect) :: nonRootAV

  if(present(stat)) stat=0

  call MP_comm_rank(comm,myID,ier)
  if(ier /= 0) then
    call MP_perr_die(myname_,'MP_comm_rank()',ier)
  endif

	! Verify the input: a _gathered_ vector

  if(myID == root) then

     niV = GlobalMap_gsize(GMap)  ! the _gathered_ local size
     noV = AttrVect_lsize(iV)     ! the length of the input AttrVect iV

     if(niV /= noV) then
        write(stderr,'(2a,i5,a,i8,a,i8)') myname_,	&
             ': myID = ',myID,'.  Invalid input on root, gsize(GMap) =',&
             niV,', lsize(iV) =',noV
        if(present(stat)) then
           stat=-1
        else
           call die(myname_)
        endif
     endif

  endif

        ! On the root, read the integer and real attribute
        ! lists off of iV.

  call List_nullify(iList)
  call List_nullify(rList)

  if(myID == root) then

     ! Count the number of real and integer attributes

     nIA = AttrVect_nIAttr(iV)	! number of INTEGER attributes
     nRA = AttrVect_nRAttr(iV)	! number of REAL attributes

     if(nIA > 0) then
	call List_copy(iList,iV%iList)
     endif

     if(nRA > 0) then
	call List_copy(rList,iV%rList)
     endif

  endif

        ! From the root, broadcast iList and rList

  call MPI_BCAST(nIA,1,MP_INTEGER,root,comm,ier)
  if(ier /= 0) call MP_perr(myname_,'MPI_BCAST(nIA)',ier)

  call MPI_BCAST(nRA,1,MP_INTEGER,root,comm,ier)
  if(ier /= 0) call MP_perr(myname_,'MPI_BCAST(nRA)',ier)

  if(nIA>0) call List_bcast(iList, root, comm)
  if(nRA>0) call List_bcast(rList, root, comm)

  noV = GlobalMap_lsize(GMap) ! the _scatterd_ local size

        ! On all processes, use List data and noV to initialize oV

  call AttrVect_init(oV, iList, rList, noV)
  call AttrVect_zero(oV)

        ! Initialize a dummy AttrVect for non-root MPI calls

  if(myID/=root) then
    call AttrVect_init(nonRootAV,oV,1)
    call AttrVect_zero(nonRootAV)
  endif


  if(nIA > 0) then

     if(myID == root) then

        call MPI_scatterv(iV%iAttr,GMap%counts*nIA, &
             GMap%displs*nIA,MP_INTEGER,oV%iAttr,   &
             noV*nIA,MP_INTEGER,root,comm,ier )
        if(ier /= 0) then
           call MP_perr_die(myname_,'MPI_scatterv(iAttr) on root',ier)
        endif

     else

        call MPI_scatterv(nonRootAV%iAttr,GMap%counts*nIA, &
             GMap%displs*nIA,MP_INTEGER,oV%iAttr,          &
             noV*nIA,MP_INTEGER,root,comm,ier )
        if(ier /= 0) then
           call MP_perr_die(myname_,'MPI_scatterv(iAttr) off root',ier)
        endif

     endif   ! if(myID == root)

     call List_clean(iList)

  endif   ! if(nIA > 0)

  mp_type_Av = MP_Type(1._FP)   ! set mpi type to same as AV%rAttr

  if(nRA > 0) then

     if(myID == root) then


        call MPI_scatterv(iV%rAttr,GMap%counts*nRA, &
             GMap%displs*nRA,mp_type_Av,oV%rAttr,   &
             noV*nRA,mp_type_Av,root,comm,ier )
        if(ier /= 0) then
           call MP_perr_die(myname_,'MPI_scatterv(rAttr) on root',ier)
        endif

     else


        call MPI_scatterv(nonRootAV%rAttr,GMap%counts*nRA, &
             GMap%displs*nRA,mp_type_Av,oV%rAttr,          &
             noV*nRA,mp_type_Av,root,comm,ier )
        if(ier /= 0) then
           call MP_perr_die(myname_,'MPI_scatterv(rAttr) off root',ier)
        endif

     endif

     call List_clean(rList)

  endif

  if(myID /= root) then
     call AttrVect_clean(nonRootAV,ier)
     if(ier /= 0) then
        write(stderr,'(2a,i4)') myname_,	&
             ':: AttrVect_clean(nonRootAV) failed for non-root &
             &process: myID = ', myID
        call die(myname_,':: AttrVect_clean failed &
             &for nonRootAV off of root',ier)
     endif
  endif

 end subroutine GM_scatter_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GSM_scatter_ - Scatter an AttrVect using a GlobalSegMap
!
! !DESCRIPTION:
! The routine {\tt GSM\_scatter\_} takes an input {\tt AttrVect} type
! {\tt iV} (valid only on the root), and scatters it to a distributed
! {\tt AttrVect} {\tt oV}.  The input {\tt GlobalSegMap} argument
! {\tt GSMap} dictates how {\tt iV} is scattered to {\tt oV}.  The
! success (failure) of this routine is reported in the zero (non-zero)
! value of the output argument {\tt stat}.
!
! {\tt GSM\_scatter\_()} converts the problem of scattering data
! according to a {\tt GlobalSegMap} into the simpler problem of
! scattering data as specified by a {\tt GlobalMap}.  The {\tt GlobalMap}
! variable {\tt GMap} is created based on the local storage requirements
! for each distributed piece of {\tt iV}.  On the root, a complete
! (including halo points) copy of {\tt iV} is stored in
! the temporary {\tt AttrVect} variable {\tt workV} (the length of
! {\tt workV} is {\tt GlobalSegMap\_GlobalStorage(GSMap)}).  The
! variable {\tt workV} is segmented by process, and segments are
! copied into it by process, but ordered in the same order the segments
! appear in {\tt GSMap}.  Once {\tt workV} is loaded, the data are
! scattered to the output {\tt AttrVect} {\tt oV} by a call to the
! routine {\tt GM\_scatter\_()} defined in this module, with {\tt workV}
! and {\tt GMap} as the input arguments.
!
! {\bf N.B.:}  This algorithm  assumes that memory access times are much
! shorter than message-passing transmission times.
!
! {\bf N.B.}:  The output {\tt AttrVect} argument {\tt oV} represents
! dynamically allocated memory.  When it is no longer needed, it should
! be deallocated by invoking {\tt AttrVect\_clean()} (see the module
! {\tt m\_AttrVect} for more details).
!
! !INTERFACE:

 subroutine GSM_scatter_(iV, oV, GSMap, root, comm, stat)
!
! !USES:
!
! Environment utilities from mpeu:

      use m_stdio
      use m_die
      use m_mpif90

      use m_List, only : List_nullify => nullify

! GlobalSegMap and associated services:
      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_comp_id => comp_id
      use m_GlobalSegMap, only : GlobalSegMap_ngseg => ngseg
      use m_GlobalSegMap, only : GlobalSegMap_lsize => lsize
      use m_GlobalSegMap, only : GlobalSegMap_gsize => gsize
      use m_GlobalSegMap, only : GlobalSegMap_GlobalStorage => GlobalStorage
! AttrVect and associated services:
      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero
      use m_AttrVect,  only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nIAttr => nIAttr
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : AttrVect_clean => clean
! GlobalMap and associated services:
      use m_GlobalMap, only : GlobalMap
      use m_GlobalMap, only : GlobalMap_init => init
      use m_GlobalMap, only : GlobalMap_clean => clean

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),            intent(in)  :: iV
      type(GlobalSegMap),        intent(in)  :: GSMap
      integer,                   intent(in)  :: root
      integer,                   intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      type(AttrVect),            intent(out) :: oV
      integer,        optional,  intent(out) :: stat

! !REVISION HISTORY:
! 15Jan01 - J.W. Larson <larson@mcs.anl.gov> - API specification.
!  8Feb01 - J.W. Larson <larson@mcs.anl.gov> - Initial code.
! 25Feb01 - J.W. Larson <larson@mcs.anl.gov> - Bug fix--replaced
!           call to GlobalSegMap_lsize with call to the new fcn.
!           GlobalSegMap_ProcessStorage().
! 26Apr01 - R.L. Jacob <jacob@mcs.anl.gov> - add use statement for
!           AttVect_clean
! 26Apr01 - J.W. Larson <larson@mcs.anl.gov> - bug fixes--data
!           misalignment in use of the GlobalMap to compute the
!           memory map into workV, and initialization of workV
!           on all processes.
!  9May01 - J.W. Larson <larson@mcs.anl.gov> - tidied up prologue
! 15May01 - Larson / Jacob <larson@mcs.anl.gov> - stopped initializing
!           workV on off-root processes (no longer necessary).
! 13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize stat
!           (if present).
! 20Jun01 - J.W. Larson <larson@mcs.anl.gov> - Fixed a subtle bug
!           appearing on AIX regarding the fact workV is uninitial-
!           ized on non-root processes.  This is fixed by nullifying
!           all the pointers in workV for non-root processes.
! 20Aug01 - E.T. Ong <eong@mcs.anl.gov> - Added argument check
!           for matching processors in gsmap and comm.
! 13Dec01 - E.T. Ong <eong@mcs.anl.gov> - got rid of restriction
!           GlobalStorage(GSMap)==AttrVect_lsize(AV) to allow for
!           GSMap to be haloed.
! 11Aug08 - R. Jacob <jacob@mcs.anl.gov> - remove call to ProcessStorage
!           and replace with faster algorithm provided by Pat Worley
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GSM_scatter_'

! Temporary workspace AttrVect:
  type(AttrVect) :: workV
! Component ID and number of segments for GSMap:
  integer :: comp_id, ngseg, iseg
! Total length of GSMap segments laid end-to-end:
  integer :: global_storage
! Error Flag
  integer :: ierr
! Number of processes on communicator, and local rank:
  integer :: NumProcs, myID
! Total local storage on each pe according to GSMap:
  integer, dimension(:), allocatable :: lns
! Temporary GlobalMap used to scatter the segmented (by pe) data
  type(GlobalMap) :: GMap
! Loop counters and temporary indices:
  integer :: m, n, ilb, iub, olb, oub, pe
! workV segment tracking index array:
  integer, dimension(:), allocatable :: current_pos

      ! Initialize stat (if present)

  if(present(stat)) stat = 0

       ! Which process am I?

  call MPI_COMM_RANK(comm, myID, ierr)

  if(ierr /= 0) then
     call MP_perr_die(myname_,'MPI_COMM_RANK',ierr)
  endif

  if(myID == root) then

     if(GSMap%gsize > AttrVect_lsize(iV)) then
	write(stderr,'(2a,i5,a,i8,a,i8)') myname_,	&
	     ': myID = ',myID,'.  Invalid input, GSMap%gsize =',&
	     GSMap%gsize, ', lsize(iV) =',AttrVect_lsize(iV)
	if(present(stat)) then
	   stat=-1
	else
	   call die(myname_)
	endif
     endif

  endif

       ! On the root, initialize a work AttrVect type of the
       ! above length, and with the same attribute lists as iV.
       ! on other processes, initialize workV only with the
       ! attribute information, but no storage.

  if(myID == root) then

     global_storage = GlobalSegMap_GlobalStorage(GSMap)
     call AttrVect_init(workV, iV, global_storage)
     call AttrVect_zero(workV)

  else
       ! nullify workV just to be safe

     call List_nullify(workV%iList)
     call List_nullify(workV%rList)
     nullify(workV%iAttr)
     nullify(workV%rAttr)

  endif

       ! Return to processing on the root to load workV:

       ! How many processes are there on this communicator?

  call MPI_COMM_SIZE(comm, NumProcs, ierr)

  if(ierr /= 0) then
     call MP_perr_die(myname_,'MPI_COMM_SIZE',ierr)
  endif

       ! Processor Check: Do the processors on GSMap match those in comm?

  if(MAXVAL(GSMap%pe_loc) > (NumProcs-1)) then
     write(stderr,*) myname_, &
          ":: Procs in GSMap%pe_loc do not match procs in communicator ", &
          NumProcs-1, MAXVAL(GSMap%pe_loc)
     if(present(stat)) then
	stat=1
	return
     else
	call die(myname_)
     endif
  endif

  if(myID == root) then

       ! Allocate a precursor to a GlobalMap accordingly...

     allocate(lns(0:NumProcs-1), stat=ierr)
     if(ierr /= 0) then
	write(stderr,*) myname_,':: allocate(lns...) failed, stat=',ierr
	if(present(stat)) then
	   stat=ierr
	else
	   call die(myname_,'allocate(lns)',ierr)
	endif
     endif

       ! And Load it...

     lns(:)=0
     do iseg=1,GSMap%ngseg
        n = GSMap%pe_loc(iseg)
	lns(n) = lns(n) + GSMap%length(iseg)
     end do

  endif ! if(myID == root)

        ! Non-root processes call GlobalMap_init with lns,
        ! although this argument is not used in the
        ! subroutine. Since it correspond to a dummy shaped array arguments
        ! in GlobslMap_init, the Fortran 90 standard dictates that the actual
        ! argument must contain complete shape information. Therefore,
        ! the array argument must be allocated on all processes.

  if(myID /= root) then

     allocate(lns(1),stat=ierr)
     if(ierr /= 0) then
	write(stderr,*) myname_,':: allocate(lns...) failed, stat=',ierr
	if(present(stat)) then
	   stat=ierr
	   return
	else
	   call die(myname_,'allocate(lns(1))',ierr)
	endif
     endif

  endif ! if(myID /= root)...

       ! Create a GlobalMap describing the 1-D decomposition
       ! of workV:

  comp_id = GlobalSegMap_comp_id(GSMap)

  call GlobalMap_init(GMap, comp_id, lns, root, comm)

       ! On the root, load workV:

  if(myID == root) then

       ! On the root, allocate current position index for
       ! each process chunk:

     allocate(current_pos(0:NumProcs-1), stat=ierr)
     if(ierr /= 0) then
	write(stderr,*) myname_,':: allocate(current_pos..) failed, stat=', &
	     ierr
	if(present(stat)) then
	   stat=ierr
	   return
	else
	   call die(myname_,'allocate(current_pos)',ierr)
	endif
     endif

       ! Initialize current_pos(:) using GMap%displs(:)

     do n=0,NumProcs-1
	current_pos(n) = GMap%displs(n) + 1
     end do

       ! Load each segment of iV into its appropriate segment
       ! of workV:

     ngseg = GlobalSegMap_ngseg(GSMap)

     do n=1,ngseg

       ! Determine which process owns segment n:

	pe = GSMap%pe_loc(n)

       ! Input map (lower/upper indicess) of segment of iV:

	ilb = GSMap%start(n)
	iub = GSMap%start(n) + GSMap%length(n) - 1

       ! Output map of (lower/upper indicess) segment of workV:

	olb = current_pos(pe)
	oub = current_pos(pe) + GSMap%length(n) - 1

       ! Increment current_pos(n) for next time:

	current_pos(pe) = current_pos(pe) + GSMap%length(n)

       ! Now we are equipped to do the copy:

	do m=1,AttrVect_nIAttr(iV)
   	   workV%iAttr(m,olb:oub) = iV%iAttr(m,ilb:iub)
	end do

	do m=1,AttrVect_nRAttr(iV)
   	   workV%rAttr(m,olb:oub) = iV%rAttr(m,ilb:iub)
	end do

     end do ! do n=1,ngseg

       ! Clean up current_pos, which was only allocated on the root

     deallocate(current_pos, stat=ierr)
     if(ierr /= 0) then
	write(stderr,*) myname_,':: deallocate(current_pos) failed.  ', &
	     'stat = ',ierr
	if(present(stat)) then
	   stat=ierr
	   return
	else
	   call die(myname_,'deallocate(current_pos)',ierr)
	endif
     endif

  endif ! if(myID == root)

       ! Now we are in business...we have:  1) an AttrVect laid out
       ! in contiguous segments, each segment corresponding to a
       ! process, and in the same order dictated by GSMap;
       ! 2) a GlobalMap telling us which segment of workV goes to
       ! which process.  Thus, we can us GM_scatter_() to achieve
       ! our goal.

  call GM_scatter_(workV, oV, GMap, root, comm, ierr)
  if(ierr /= 0) then
     write(stderr,*) myname,':: ERROR in return from GM_scatter_(), ierr=',&
	  ierr
     if(present(stat)) then
	stat = ierr
	return
     else
	call die(myname_,'ERROR returning from GM_scatter_()',ierr)
     endif
  endif

       ! Finally, clean up allocated structures:

  if(myID == root) then
     call AttrVect_clean(workV)
  endif

  call GlobalMap_clean(GMap)

  deallocate(lns, stat=ierr)
  if(ierr /= 0) then
     write(stderr,*) myname_,':: ERROR in deallocate(lns), ierr=',ierr
     if(present(stat)) then
	stat=ierr
	return
     else
	call die(myname_,'deallocate(lns)',ierr)
     endif
  endif

 end subroutine GSM_scatter_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: bcast_ - Broadcast an AttrVect
!
! !DESCRIPTION:  This routine takes an {\tt AttrVect} argument {\tt aV}
! (at input, valid on the root only), and broadcasts it to all the
! processes associated with the communicator handle {\tt comm}.  The
! success (failure) of this routine is reported in the zero (non-zero)
! value of the output argument {\tt stat}.
!
! {\bf N.B.}:  The output (on non-root processes) {\tt AttrVect} argument
! {\tt aV} represents dynamically allocated memory.  When it is no longer
! needed, it should be deallocated by invoking {\tt AttrVect\_clean()}
! (see the module {\tt m\_AttrVect} for details).
!
! !INTERFACE:

 subroutine bcast_(aV, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90
      use m_String, only : String,bcast,char,String_clean
      use m_String, only : String_bcast => bcast
      use m_List, only : List_get => get
      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nIAttr => nIAttr
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr

      implicit none

! !INPUT PARAMETERS:
!
      integer,                  intent(in)    :: root
      integer,                  intent(in)    :: comm

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),           intent(inout) :: aV ! (IN) on the root,
                                                    ! (OUT) elsewhere

! !OUTPUT PARAMETERS:
!
      integer,        optional, intent(out)   :: stat

! !REVISION HISTORY:
! 27Apr98 - Jing Guo <guo@thunder> - initial prototype/prologue/code
! 27Oct00 - J.W. Larson <larson@mcs.anl.gov> - relocated from
!           m_AttrVect
!  9May01 - J.W. Larson <larson@mcs.anl.gov> - tidied up prologue
! 18May01 - R.L. Jacob <jacob@mcs.anl.gov> - use MP_Type function
!           to determine type for bcast
! 19Dec01 - E.T. Ong <eong@mcs.anl.gov> - adjusted for case of AV with
!           only integer or real attribute
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::bcast_'
  type(String) :: iLStr,rLStr
  integer :: nIA, nRA, lsize
  integer :: myID
  integer :: ier
  integer :: mp_Type_aV

  if(present(stat)) stat=0

  call MP_comm_rank(comm,myID,ier)
  if(ier /= 0) then
    call MP_perr_die(myname_,'MP_comm_rank()',ier)
  endif

       ! Broadcaast to all PEs

  if(myID == root) then
     nIA = AttrVect_nIAttr(aV)
     nRA = AttrVect_nRAttr(aV)
     lsize = AttrVect_lsize(aV)
  endif

  call MPI_bcast(nIA,1,MP_INTEGER,root,comm,ier)
  if(ier /= 0) then
    call MP_perr_die(myname_,'MPI_bcast(nIA)',ier)
  endif

  call MPI_bcast(nRA,1,MP_INTEGER,root,comm,ier)
  if(ier /= 0) then
    call MP_perr_die(myname_,'MPI_bcast(nRA)',ier)
  endif

  call MPI_bcast(lsize,1,MP_INTEGER,root,comm,ier)
  if(ier /= 0) then
    call MP_perr_die(myname_,'MPI_bcast(lsize)',ier)
  endif

	! Convert the two Lists to two Strings

  if(nIA>0) then

     if(myID == root) call List_get(iLStr,aV%iList)

     call String_bcast(iLStr,root,comm,stat=ier)	! bcast.String()

     if(ier /= 0) then
	write(stderr,*) myname_,'bcast.String(iLstr), ier=',ier
	if(present(stat)) then
	   stat=ier
	   return
	else
	   call die(myname_,'String_bcast(iLStr) failed',ier)
	endif
     endif ! if(ier /= 0)...

  endif ! if(nIA > 0)...


  if(nRA>0) then

     if(myID == root) call List_get(rLStr,aV%rList)

     call String_bcast(rLStr,root,comm,stat=ier)	! bcast.String()
     if(ier /= 0) then
	write(stderr,*) myname_,'bcast.String(iLstr), ier=',ier
	if(present(stat)) then
	   stat=ier
	   return
	else
	   call die(myname_,'String_bcast(iLStr) failed',ier)
	endif
     endif ! if(ier /= 0)...

  endif ! if(nRA > 0)...

  if(myID /= root) then

     if( (nIA>0) .and. (nRA>0) ) then
	call AttrVect_init(aV,iList=char(iLStr),rList=char(rLStr), &
	                   lsize=lsize)
     endif

     if( (nIA>0) .and. (nRA<=0) ) then
	call AttrVect_init(aV,iList=char(iLStr),lsize=lsize)
     endif

     if( (nIA<=0) .and. (nRA>0) ) then
	call AttrVect_init(aV,rList=char(rLStr),lsize=lsize)
     endif

     if( (nIA<=0) .and. (nRA<=0) ) then
	write(stderr,*) myname_,':: Nonpositive numbers of both ',&
	     'real AND integer attributes.  nIA =',nIA,' nRA=',nRA
	if(present(stat)) then
	   stat = -1
	   return
	else
	   call die(myname_,'AV has not been initialized',-1)
	endif
     endif ! if((nIA<= 0) .and. (nRA<=0))...

     call AttrVect_zero(aV)


  endif ! if(myID /= root)...

  if(nIA > 0) then

     mp_Type_aV=MP_Type(av%iAttr)
     call MPI_bcast(aV%iAttr,nIA*lsize,mp_Type_aV,root,comm,ier)
     if(ier /= 0) then
	call MP_perr_die(myname_,'MPI_bcast(iAttr) failed.',ier)
     endif

     call String_clean(iLStr)

  endif

  if(nRA > 0) then

     mp_Type_aV=MP_Type(av%rAttr)
     call MPI_bcast(aV%rAttr,nRA*lsize,mp_Type_aV,root,comm,ier)
     if(ier /= 0) then
	call MP_perr_die(myname_,'MPI_bcast(rAttr) failed.',ier)
     endif

     call String_clean(rLStr)

  endif

 end subroutine bcast_

 end module m_AttrVectComms



