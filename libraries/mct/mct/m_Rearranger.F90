!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_Rearranger -- Remaps an AttrVect within a group of processes
!
! !DESCRIPTION:
! This module provides routines and datatypes for rearranging data
! between two {\tt Attribute Vectors} defined on the same grid but
! with two different {\tt GlobalSegMaps}.  ''Rearrange'' is a
! generalized form of a parallel matrix transpose.
! A parallel matrix transpose can take advantage of symmetry in the
! data movement algorithm.  An MCT Rearranger makes no assumptions
! about symmetry.
!
! When data needs to move between two components and the components
! share any processors, use m\_Rearranger.  If the components are on
! distinct sets of processors, use m\_Transfer.
!
! !SEE ALSO:
!  m_Transfer
!
!
! !INTERFACE:

 module m_Rearranger

!
! !USES:

      use m_Router, only : Router

      implicit none

      private	! except

! !PUBLIC DATA MEMBERS:

      public :: Rearranger  ! The class data structure

      type :: Rearranger
#ifdef SEQUENCE
         sequence
#endif
         private
         type(Router) :: SendRouter
         type(Router) :: RecvRouter
         integer,dimension(:,:),pointer :: LocalPack
         integer :: LocalSize
      end type Rearranger

! !PRIVATE DATA MEMBERS:
      integer :: max_nprocs  ! size of MPI_COMM_WORLD used for generation of
                             ! local automatic arrays

! !PUBLIC MEMBER FUNCTIONS:

      public :: init         ! creation method

      public :: rearrange    ! the rearrange routine

      public :: clean        ! destruction method
      public :: print        ! print out comm info

      interface init      ; module procedure init_      ; end interface
      interface Rearrange ; module procedure Rearrange_ ; end interface
      interface clean     ; module procedure clean_     ; end interface
      interface print     ; module procedure print_     ; end interface

! !DEFINED PARAMETERS:

  integer,parameter                    :: DefaultTag = 500


! !REVISION HISTORY:
! 31Jan02 - E.T. Ong <eong@mcs.anl.gov> - initial prototype
! 04Jun02 - E.T. Ong <eong@mcs.anl.gov> - changed local copy structure to
!           LocalSize. Made myPid a global process in MCTWorld.
! 27Sep02 - R. Jacob <jacob@mcs.anl.gov> - Remove SrcAVsize and TrgAVsize
!           and use Router%lAvsize instead for sanity check.
! 25Jan08 - R. Jacob <jacob@mcs.anl.gov> - Add ability to handle unordered
!           gsmaps.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_Rearranger'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: Init_ - Initialize a Rearranger
!
! !DESCRIPTION:
! This routine takes two {\tt GlobalSegMap} inputs, {\tt SourceGSMap}
! and {\tt TargetGSMap} and build a Rearranger {\tt OutRearranger}
! between them. {\tt myComm} is used for the internal communication.
!
! {\bf N.B.} The two {\tt GlolbalSegMap} inputs must be initialized so
! that the index values on a processor are in ascending order.
!
! !INTERFACE:

 subroutine init_(SourceGSMap,TargetGSMap,myComm,OutRearranger)

!
! !USES:
!

   use m_MCTWorld,     only : ThisMCTWorld
   use m_GlobalSegMap, only : GlobalSegMap
   use m_GlobalSegMap, only : GSMap_lsize => lsize
   use m_GlobalSegMap, only : GSMap_increasing => increasing
   use m_Router,       only : Router
   use m_Router,       only : Router_init => init
   use m_mpif90
   use m_die
   use m_stdio

   implicit none

! !INPUT PARAMETERS:
!
   type(GlobalSegMap), intent(in)            :: SourceGSMap, TargetGSMap
   integer,            intent(in)            :: myComm

! !OUTPUT PARAMETERS:
!
   type(Rearranger),   intent(out)           :: OutRearranger

! !REVISION HISTORY:
! 31Jan02 - E.T. Ong <eong@mcs.anl.gov> - initial prototype
! 20Mar02 - E.T. Ong <eong@mcs.anl.gov> - working code
! 05Jun02 - E.T. Ong <eong@mcs.anl.gov> - Use LocalPack
! 30Mar06 - P. Worley <worleyph@ornl.gov> - added max_nprocs,
!           used in communication optimizations in rearrange
!EOP ___________________________________________________________________
   character(len=*),parameter :: myname_=myname//'::init_'
   integer,dimension(:,:),pointer :: temp_seg_starts,temp_seg_lengths
   integer,dimension(:),pointer :: temp_pe_list,temp_numsegs,temp_locsize
   integer :: temp_maxsize,temp_nprocs,maxsegcount
   integer :: procindex,nprocs,nseg,len,myPid
   integer :: src_seg_start,src_seg_length,trg_seg_start,trg_seg_length
   integer :: i,j,k,l,m,n,ier
   logical :: SendingToMyself,ReceivingFromMyself


   ! Initialize Router component of Rearranger
   call Router_init(SourceGSMap,TargetGSMap,myComm,OutRearranger%SendRouter)
   call Router_init(TargetGSMap,SourceGSMap,myComm,OutRearranger%RecvRouter)

   call MP_comm_size(MP_COMM_WORLD,max_nprocs,ier)
   if(ier/=0) call MP_perr_die(myname_,'MP_comm_size',ier)

   ! SANITY CHECK: Make sure that if SendRouter is sending to self, then,
   ! by definition, RecvRouter is also receiving from self. If this is not
   ! true, then write to stderr and die.

   call MP_comm_rank(ThisMCTWorld%MCT_comm,myPid,ier)
   if(ier/=0) call MP_perr_die(myname_,'MP_comm_rank',ier)

   SendingToMyself = .false.
   ReceivingFromMyself = .false.

   do i=1,OutRearranger%SendRouter%nprocs
      if(OutRearranger%SendRouter%pe_list(i) == myPid) then
	 SendingToMyself = .true.
      endif
   enddo

   do i=1,OutRearranger%RecvRouter%nprocs
      if(OutRearranger%RecvRouter%pe_list(i) == myPid) then
	 ReceivingFromMyself = .true.
      endif
   enddo

   if( SendingToMyself.or.ReceivingFromMyself ) then
      if( .not. (SendingToMyself.and.ReceivingFromMyself) ) then
	 call die(myname_,"SendRouter is not compatible with RecvRouter")
      endif
   endif


   ! If not sending to nor receiving from own processor then initialize
   ! the rearranger so that no local copy can be made. Then end the routine.

   if( .not. (SendingToMyself.or.ReceivingFromMyself) ) then
      nullify(OutRearranger%LocalPack)
      allocate(OutRearranger%LocalPack(0,0),stat=ier)
      if(ier/=0) call die(myname_,'allocate(OutRearranger%LocalPack(0,0))',ier)
      OutRearranger%LocalSize=0
   endif


   ! Start the process of Router modification: Router information for
   ! the local processor is extracted out and put into the local copy
   ! structure- Rearranger%LocalPack. Router structures are then reassigned
   ! to exclude the local copy information.


   ! Operate on SendRouter and create local copy structures.

   if( SendingToMyself.and.ReceivingFromMyself ) then

   temp_nprocs = OutRearranger%SendRouter%nprocs-1
   maxsegcount = SIZE(OutRearranger%SendRouter%seg_starts,2)

   ! Allocate temporary Router structures to be used for modifying SendRouter
   nullify(temp_seg_starts,temp_seg_lengths,temp_pe_list, &
           temp_numsegs,temp_locsize)
   allocate(temp_seg_starts(temp_nprocs,maxsegcount), &
            temp_seg_lengths(temp_nprocs,maxsegcount), &
	    temp_pe_list(temp_nprocs), &
            temp_numsegs(temp_nprocs), &
            temp_locsize(temp_nprocs), stat=ier)
   if(ier/=0) call die(myname_,'allocate(temp_seg_starts...)',ier)

   temp_maxsize=0
   procindex=0
   nullify(OutRearranger%LocalPack)

   ! Start assigning Rearranger copy structures and
   ! non-local Router components
   do i=1,OutRearranger%SendRouter%nprocs

      ! Gather local copy information
      if(OutRearranger%SendRouter%pe_list(i) == myPid) then

	 ! Allocate Rearranger copy structure
	 allocate(OutRearranger%LocalPack(2, &
                  OutRearranger%SendRouter%locsize(i)),stat=ier)
	 if(ier/=0) call die(myname_,'allocate(OutRearranger%LocalPack)',ier)
	 OutRearranger%LocalPack = 0

	 m=0
	 do nseg = 1,OutRearranger%SendRouter%num_segs(i)
	    src_seg_start = OutRearranger%SendRouter%seg_starts(i,nseg)
	    src_seg_length = OutRearranger%SendRouter%seg_lengths(i,nseg)-1
	    do len=0,src_seg_length
	       m=m+1
	       OutRearranger%LocalPack(2,m) = src_seg_start+len
	    enddo
	 enddo

      else

	 ! Gather non-local Router information
	 procindex = procindex+1
	 temp_seg_starts(procindex,1:maxsegcount) = &
            OutRearranger%SendRouter%seg_starts(i,1:maxsegcount)
	 temp_seg_lengths(procindex,1:maxsegcount) = &
            OutRearranger%SendRouter%seg_lengths(i,1:maxsegcount)
	 temp_pe_list(procindex) = OutRearranger%SendRouter%pe_list(i)
	 temp_numsegs(procindex) = OutRearranger%SendRouter%num_segs(i)
	 temp_locsize(procindex) = OutRearranger%SendRouter%locsize(i)
	 temp_maxsize = max(temp_locsize(procindex),temp_maxsize)

      endif

   enddo

   ! Copy SendRouter components back in

   ! Deallocate existing SendRouter components
   deallocate(OutRearranger%SendRouter%seg_starts,&
              OutRearranger%SendRouter%seg_lengths, &
	      OutRearranger%SendRouter%pe_list, &
              OutRearranger%SendRouter%num_segs, &
              OutRearranger%SendRouter%locsize,stat=ier)
   if(ier/=0) call die(myname_, &
                  'deallocate(OutRearranger%SendRouter%seg_starts...)',ier)

   ! Re-allocate SendRouter components
   allocate(OutRearranger%SendRouter%seg_starts(temp_nprocs,maxsegcount), &
            OutRearranger%SendRouter%seg_lengths(temp_nprocs,maxsegcount), &
	    OutRearranger%SendRouter%pe_list(temp_nprocs), &
	    OutRearranger%SendRouter%num_segs(temp_nprocs), &
            OutRearranger%SendRouter%locsize(temp_nprocs),stat=ier)
   if(ier/=0) call die(myname_, &
                   'allocate(OutRearranger%SendRouter%seg_starts...)',ier)

   ! Copy back in the spliced router information
   OutRearranger%SendRouter%nprocs = temp_nprocs
   OutRearranger%SendRouter%seg_starts(1:temp_nprocs,1:maxsegcount) = &
      temp_seg_starts(1:temp_nprocs,1:maxsegcount)
   OutRearranger%SendRouter%seg_lengths(1:temp_nprocs,1:maxsegcount) = &
      temp_seg_lengths(1:temp_nprocs,1:maxsegcount)
   OutRearranger%SendRouter%pe_list(1:temp_nprocs) = &
      temp_pe_list(1:temp_nprocs)
   OutRearranger%SendRouter%num_segs(1:temp_nprocs) = &
      temp_numsegs(1:temp_nprocs)
   OutRearranger%SendRouter%locsize(1:temp_nprocs) = &
      temp_locsize(1:temp_nprocs)
   OutRearranger%SendRouter%maxsize = temp_maxsize

   deallocate(temp_seg_starts,temp_seg_lengths,temp_pe_list, &
              temp_numsegs,temp_locsize,stat=ier)
   if(ier/=0) call die(myname_,'deallocate(temp_seg_starts...)',ier)


   ! :::::::::::::::::::::::::::::::::::::::::::::::::::::::


   ! Operate on RecvRouter and create local copy structures.

   temp_nprocs = OutRearranger%RecvRouter%nprocs-1
   maxsegcount = SIZE(OutRearranger%RecvRouter%seg_starts,2)

  ! Allocate temporary Router structures to be used for modifying RecvRouter
   nullify(temp_seg_starts,temp_seg_lengths,temp_pe_list, &
           temp_numsegs,temp_locsize)
   allocate(temp_seg_starts(temp_nprocs,maxsegcount), &
            temp_seg_lengths(temp_nprocs,maxsegcount), &
	    temp_pe_list(temp_nprocs),temp_numsegs(temp_nprocs), &
            temp_locsize(temp_nprocs),stat=ier)
   if(ier/=0) call die(myname_,'allocate(temp_seg_starts...)',ier)

   temp_maxsize=0
   procindex = 0

   ! Start assigning Rearranger copy structures and
   ! non-local Router components
   do i=1,OutRearranger%RecvRouter%nprocs

      ! Gather local copy information
      if(OutRearranger%RecvRouter%pe_list(i) == myPid) then

	 ! Senity Check for Router%locsize
	 if( (SIZE(OutRearranger%LocalPack,2) /= &
              OutRearranger%RecvRouter%locsize(i)) ) then
	    call die(myname_, &
                     'Router Error: Local RecvRouter%locsize(myPid) /=  &
                     & Local SendRouter%locsize(myPid)')
	 endif

	 OutRearranger%LocalSize = OutRearranger%RecvRouter%locsize(i)

	 m=0
	 do nseg = 1,OutRearranger%RecvRouter%num_segs(i)
	    trg_seg_start = OutRearranger%RecvRouter%seg_starts(i,nseg)
	    trg_seg_length = OutRearranger%RecvRouter%seg_lengths(i,nseg)-1
	    do len=0,trg_seg_length
	       m=m+1
	       OutRearranger%LocalPack(1,m) = trg_seg_start+len
	    enddo
	 enddo

      else

	 ! Gather non-local Router information
	 procindex = procindex+1
	 temp_seg_starts(procindex,1:maxsegcount) = &
	    OutRearranger%RecvRouter%seg_starts(i,1:maxsegcount)
	 temp_seg_lengths(procindex,1:maxsegcount) = &
            OutRearranger%RecvRouter%seg_lengths(i,1:maxsegcount)
	 temp_pe_list(procindex) = OutRearranger%RecvRouter%pe_list(i)
	 temp_numsegs(procindex) = OutRearranger%RecvRouter%num_segs(i)
	 temp_locsize(procindex) = OutRearranger%RecvRouter%locsize(i)
	 temp_maxsize = max(temp_locsize(procindex),temp_maxsize)

      endif

   enddo

   ! Copy RecvRouter components back in

   ! Deallocate existing SendRouter components
   deallocate(OutRearranger%RecvRouter%seg_starts, &
              OutRearranger%RecvRouter%seg_lengths, &
	      OutRearranger%RecvRouter%pe_list, &
              OutRearranger%RecvRouter%num_segs, &
              OutRearranger%RecvRouter%locsize,stat=ier)
   if(ier/=0) call die(myname_, &
                   'deallocate(OutRearranger%RecvRouter%seg_starts...)',ier)

   ! Re-allocate RecvRouter components
   allocate(OutRearranger%RecvRouter%seg_starts(temp_nprocs,maxsegcount), &
            OutRearranger%RecvRouter%seg_lengths(temp_nprocs,maxsegcount), &
	    OutRearranger%RecvRouter%pe_list(temp_nprocs), &
	    OutRearranger%RecvRouter%num_segs(temp_nprocs), &
            OutRearranger%RecvRouter%locsize(temp_nprocs),stat=ier)
   if(ier/=0) call die(myname_, &
                   'allocate(OutRearranger%RecvRouter%seg_starts...)',ier)

    ! Copy back in the spliced router information
   OutRearranger%RecvRouter%nprocs = temp_nprocs
   OutRearranger%RecvRouter%seg_starts(1:temp_nprocs,1:maxsegcount) =  &
      temp_seg_starts(1:temp_nprocs,1:maxsegcount)
   OutRearranger%RecvRouter%seg_lengths(1:temp_nprocs,1:maxsegcount) = &
      temp_seg_lengths(1:temp_nprocs,1:maxsegcount)
   OutRearranger%RecvRouter%pe_list(1:temp_nprocs) = &
      temp_pe_list(1:temp_nprocs)
   OutRearranger%RecvRouter%num_segs(1:temp_nprocs) = &
      temp_numsegs(1:temp_nprocs)
   OutRearranger%RecvRouter%locsize(1:temp_nprocs) = &
      temp_locsize(1:temp_nprocs)
   OutRearranger%RecvRouter%maxsize = temp_maxsize

   deallocate(temp_seg_starts,temp_seg_lengths,temp_pe_list, &
              temp_numsegs,temp_locsize,stat=ier)
   if(ier/=0) call die(myname_,'deallocate(temp_seg_starts...)',ier)

   endif

 end subroutine init_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: clean_ - Clean a Rearranger
!
! !DESCRIPTION:
! This routine deallocates allocated memory associated with the
! input/output {\tt Rearranger} argument {\tt ReArr}.  The success
! (failure) of this operation is reported in the zero (nonzero) value of
! the optional output {\tt INTEGER} argument {\tt status}.
!
! !INTERFACE:

 subroutine clean_(ReArr, status)

!
! !USES:
!
   use m_Router,only : Router
   use m_Router,only : Router_clean => clean
   use m_mpif90
   use m_die
   use m_stdio

   implicit none

! !INPUT/OUTPUT PARAMETERS:
!
   type(Rearranger),    intent(inout)           :: ReArr

! !OUTPUT PARAMETERS:
!
   integer, optional,   intent(out)             :: status

! !REVISION HISTORY:
! 31Jan02 - E.T. Ong <eong@mcs.anl.gov> - initial prototype
! 20Mar02 - E.T. Ong <eong@mcs.anl.gov> - working code
!EOP ___________________________________________________________________
   character(len=*),parameter :: myname_=myname//'::clean_'
   integer :: ier

        ! Set output status flag (if present) to zero, which assumes
        ! success.

   if(present(status)) status = 0

        ! Clean up send and receive Routers:

   call Router_clean(ReArr%SendRouter,ier)
   if(ier /= 0) then
      if(present(status)) then
	 status = ier
	 return
      else
         write(stderr,'(2a,i8)') myname_, &
	   ':: ERROR--Router_clean(ReArr%SendRouter) failed with ier=',ier
      endif
   endif

   call Router_clean(ReArr%RecvRouter,ier)
   if(ier /= 0) then
      if(present(status)) then
	 status = ier
	 return
      else
         write(stderr,'(2a,i8)') myname_, &
	   ':: ERROR--Router_clean(ReArr%RecvRouter) failed with ier=',ier
      endif
   endif

       ! Clean up Local on-PE copy buffer:

   if(associated(ReArr%LocalPack)) then
      deallocate(ReArr%LocalPack, stat=ier)
      if(ier /= 0) then
	 if(present(status)) then
	    status=ier
	 else
	    write(stderr,'(2a,i8)') myname_, &
	      ':: ERROR--deallocate(ReArr%LocalPack) failed with stat=',ier
	 endif
      endif
   endif

 end subroutine clean_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: rearrange_ - Rearrange data between two Attribute Vectors
!
! !DESCRIPTION:
! This subroutine will take data in the {\tt SourceAv} Attribute
! Vector and rearrange it to match the GlobalSegMap used to define
! the {\tt TargetAv} Attribute Vector using the Rearrnger
! {\tt InRearranger}.
!
! The optional argument {\tt Tag} can be used to set the tag value used in
! the rearrangement.  DefaultTag will be used otherwise.
!
! If the optional argument {\tt Sum} is present and true, data for the same
! physical point coming from two or more processes will be summed.
! Otherwise, data is overwritten.
!
! If the optional argument {\tt Vector} is present and true,
! vector architecture-friendly parts of this routine will be invoked.
!
! If the optional argument {\tt AlltoAll} is present and true,
! the communication will be done with an alltoall call instead of
! individual sends and receives.
!
! The size of the {\tt SourceAv} and {\tt TargetAv}
! argument must match those stored in the {\tt InRearranger} or
! and error will result.
!
! {\bf N.B.:} {\tt SourceAv} and {\tt TargetAv} are
! assumed to have exactly the same attributes
! in exactly the same order.
!
! !INTERFACE:

 subroutine rearrange_(SourceAVin,TargetAV,InRearranger,Tag,Sum,&
                       Vector,AlltoAll,HandShake,ISend,MaxReq)

!
! !USES:
!

   use m_MCTWorld,only :MCTWorld
   use m_MCTWorld,only :ThisMCTWorld
   use m_AttrVect,  only : AttrVect
   use m_AttrVect,  only : AttrVect_init => init
   use m_AttrVect,  only : AttrVect_lsize => lsize
   use m_AttrVect,  only : AttrVect_copy => copy
   use m_AttrVect,  only : AttrVect_clean => clean
   use m_AttrVect,  only : AttrVect_zero => zero
   use m_AttrVect,  only : nIAttr,nRAttr
   use m_AttrVect,  only : Permute,Unpermute
   use m_Router,    only : Router
   use m_SPMDutils, only : m_swapm_int, m_swapm_FP
   use m_realkinds, only : FP
   use m_mpif90
   use m_die
   use m_stdio

   implicit none

! !INPUT/OUTPUT PARAMETERS:
!
   type(AttrVect),             intent(inout)   :: TargetAV

! !INPUT PARAMETERS:
!
   type(AttrVect),   target,   intent(in)      :: SourceAVin
   type(Rearranger), target,   intent(in)      :: InRearranger
   integer,          optional, intent(in)      :: Tag
   logical,          optional, intent(in)      :: Sum
   logical,          optional, intent(in)      :: Vector
   logical,          optional, intent(in)      :: AlltoAll
   logical,          optional, intent(in)      :: HandShake
   logical,          optional, intent(in)      :: ISend
   integer,          optional, intent(in)      :: MaxReq

! !REVISION HISTORY:
! 31Jan02 - E.T. Ong <eong@mcs.anl.gov> - initial prototype
! 20Mar02 - E.T. Ong <eong@mcs.anl.gov> - working code
! 08Jul02 - E.T. Ong <eong@mcs.anl.gov> - change intent of Target,Source
! 29Oct03 - R. Jacob <jacob@mcs.anl.gov> - add optional argument vector
!           to control use of vector-friendly mods provided by Fujitsu.
! 30Mar06 - P. Worley <worleyph@ornl.gov> - added alltoall option and
!           reordered send/receive order to improve communication
!           performance.  Also remove replace allocated arrays with
!           automatic.
! 14Oct06 - R. Jacob <jacob@mcs.anl.gov> - check value of Sum argument.
! 25Jan08 - R. Jacob <jacob@mcs.anl.gov> - Permute/unpermute if the internal
!           routers permarr is defined.
! 29Sep16 - P. Worley <worleyph@gmail.com> - added swapm variant of
!           alltoall option
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::Rearrange_'
  integer ::	numi,numr,i,j,k,ier
  integer ::    VectIndex,AttrIndex,seg_start,seg_end
  integer ::    localindex,SrcVectIndex,TrgVectIndex,IAttrIndex,RAttrIndex
  integer ::    proc,numprocs,nseg,pe,pe_shift,max_pe,myPid
  integer ::    mp_Type_rp
  integer ::    mytag
  integer ::    ISendSize, RSendSize, IRecvSize, RRecvSize
  logical ::    usevector, usealltoall, useswapm
  logical ::    DoSum
  logical ::    Sendunordered
  logical ::    Recvunordered
  real(FP)::    realtyp
!-----------------------------------------------------------------------

   ! DECLARE STRUCTURES FOR MPI ARGUMENTS.

   ! declare arrays mapping from all processes to those sending to
   ! or receiving from
   integer :: SendList(0:max_nprocs-1)
   integer :: RecvList(0:max_nprocs-1)

   ! declare arrays to hold count and locations where data is to be sent from
   integer :: ISendLoc(max_nprocs)
   integer :: RSendLoc(max_nprocs)

   integer :: ISendCnts(0:max_nprocs-1)
   integer :: RSendCnts(0:max_nprocs-1)

   integer :: ISdispls(0:max_nprocs-1)
   integer :: RSdispls(0:max_nprocs-1)

   ! declare arrays to hold data to be sent
   integer,dimension(:),allocatable  :: ISendBuf
   real(FP),dimension(:),allocatable :: RSendBuf

   ! declare arrays to hold count and locations where data is to be received into
   integer :: IRecvLoc(max_nprocs)
   integer :: RRecvLoc(max_nprocs)

   integer :: IRecvCnts(0:max_nprocs-1)
   integer :: RRecvCnts(0:max_nprocs-1)

   integer :: IRdispls(0:max_nprocs-1)
   integer :: RRdispls(0:max_nprocs-1)

   ! declare arrays to hold data to be received
   integer,dimension(:),allocatable  :: IRecvBuf
   real(FP),dimension(:),allocatable :: RRecvBuf

   ! declare arrays to hold MPI data types for m_swapm_XXX calls
   integer :: ITypes(0:max_nprocs-1)
   integer :: RTypes(0:max_nprocs-1)

   ! Structure to hold MPI request information for sends
   integer :: send_ireqs(max_nprocs)
   integer :: send_rreqs(max_nprocs)

   ! Structure to hold MPI request information for sends
   integer :: recv_ireqs(max_nprocs)
   integer :: recv_rreqs(max_nprocs)

   ! Structure to hold MPI status information for sends
   integer :: send_istatus(MP_STATUS_SIZE,max_nprocs)
   integer :: send_rstatus(MP_STATUS_SIZE,max_nprocs)

   ! Structure to hold MPI status information for sends
   integer :: recv_istatus(MP_STATUS_SIZE,max_nprocs)
   integer :: recv_rstatus(MP_STATUS_SIZE,max_nprocs)

   ! Pointer structure to make Router access simpler
   type(Router), pointer :: SendRout, RecvRout
   type(AttrVect),pointer :: SourceAv
   type(AttrVect),target  :: SourceAvtmp

   ! local swapm protocol variables and defaults
   logical,parameter :: DEF_SWAPM_HS     = .true.
   logical swapm_hs

   logical,parameter :: DEF_SWAPM_ISEND  = .false.
   logical swapm_isend

   integer,parameter :: DEF_SWAPM_MAXREQ = 512
   integer swapm_maxreq

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

   Sendunordered=associated(InRearranger%SendRouter%permarr)
   Recvunordered=associated(InRearranger%RecvRouter%permarr)

   if(Sendunordered) then
      call AttrVect_init(SourceAvtmp,SourceAvin,AttrVect_lsize(SourceAvin))
      call AttrVect_copy(SourceAvin, SourceAvtmp)
      call Permute(SourceAvtmp,InRearranger%SendRouter%permarr)
      SourceAv => SourceAvtmp
   else
      SourceAv => SourceAvin
   endif

   if(Recvunordered) call Permute(TargetAv,InRearranger%RecvRouter%permarr)

   ! CHECK ARGUMENTS

   ! Check the size of the Source AttrVect
   if(InRearranger%SendRouter%lAvsize /= AttrVect_lsize(SourceAV)) then
      call warn(myname_,"SourceAV size is not appropriate for this Rearranger")
      call die(myname_,"InRearranger%SendRouter%lAvsize",InRearranger%SendRouter%lAvsize, &
	        "AttrVect_lsize(SourceAV)", AttrVect_lsize(SourceAV))
   endif

   ! Check the size of the Target AttrVect
   if(InRearranger%RecvRouter%lAvsize /= AttrVect_lsize(TargetAV)) then
      call warn(myname_,"TargetAV size is not appropriate for this Rearranger")
      call die(myname_,"InRearranger%RecvRouter%lAvsize",InRearranger%RecvRouter%lAvsize, &
	        "AttrVect_lsize(TargetAV)", AttrVect_lsize(TargetAV))
   endif

   ! Check the number of integer attributes
   if(nIAttr(SourceAV) /= nIAttr(TargetAV)) then
      call warn(myname_, &
                "Number of attributes in SourceAV and TargetAV do not match")
      call die(myname_,"nIAttr(SourceAV)", nIAttr(SourceAV), &
                        "nIAttr(TargetAV)", nIAttr(TargetAV))
   endif

   ! Check the number of real attributes
   if(nRAttr(SourceAV) /= nRAttr(TargetAV)) then
      call warn(myname_, &
      "Number of attributes in SourceAV and TargetAV do not match")
      call die(myname_,"nRAttr(SourceAV)", nRAttr(SourceAV), &
                        "nRAttr(TargetAV)", nRAttr(TargetAV))
   endif

   usevector=.false.
   if(present(Vector)) then
    if(Vector) usevector=.true.
   endif

   usealltoall=.false.
   if(present(AlltoAll)) then
    if(AlltoAll) usealltoall=.true.
   endif

   useswapm=.false.
   if (usealltoall) then
    ! if any swapm-related optional parameters are present,
    ! enable swapm variant of alltoall

    swapm_hs = DEF_SWAPM_HS
    if(present(HandShake)) then
     if(HandShake) swapm_hs=.true.
     useswapm=.true.
    endif

    swapm_isend = DEF_SWAPM_ISEND
    if(present(ISend)) then
     if(ISend) swapm_isend=.true.
     useswapm=.true.
    endif

    swapm_maxreq = DEF_SWAPM_MAXREQ
    if(present(MaxReq)) then
     swapm_maxreq=MaxReq
     useswapm=.true.
    endif

   endif

   DoSum=.false.
   if(present(Sum)) then
    if(Sum) DoSum=.true.
   endif

   ! ASSIGN VARIABLES


   ! Get the number of integer and real attributes
   numi = nIAttr(SourceAV)
   numr = nRAttr(SourceAV)

   ! Assign the pointers
   nullify(SendRout,RecvRout)
   SendRout => InRearranger%SendRouter
   RecvRout => InRearranger%RecvRouter

   mp_Type_rp=MP_Type(realtyp)

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  ! ALLOCATE DATA STRUCTURES !

  ! IF SENDING OR RECEIVING INTEGER DATA
  if (numi .ge. 1) then

     ! allocate buffer to hold all outgoing data
     ISendSize = 1
     do proc=1,SendRout%nprocs
        ISendLoc(proc) = ISendSize
        ISendSize = ISendSize + SendRout%locsize(proc)*numi
     enddo
     if (ISendSize > 1) ISendSize = ISendSize - 1
     allocate(ISendBuf(ISendSize),stat=ier)
     if (ier/=0) call die(myname_,'allocate(ISendBuf)',ier)

     ! allocate buffer to hold all incoming data
     IRecvSize = 1
     do proc=1,RecvRout%nprocs
        IRecvLoc(proc) = IRecvSize
        IRecvSize = IRecvSize + RecvRout%locsize(proc)*numi
     enddo
     if (IRecvSize > 1) IRecvSize = IRecvSize - 1
     allocate(IRecvBuf(IRecvSize),stat=ier)
     if(ier/=0) call die(myname_,'allocate(IRecvBuf)',ier)

  endif

  ! IF SENDING OR RECEIVING REAL DATA
  if (numr .ge. 1) then

     ! allocate buffer to hold all outgoing data
     RSendSize = 1
     do proc=1,SendRout%nprocs
        RSendLoc(proc) = RSendSize
        RSendSize = RSendSize + SendRout%locsize(proc)*numr
     enddo
     if (RSendSize > 1) RSendSize = RSendSize - 1
     allocate(RSendBuf(RSendSize),stat=ier)
     if (ier/=0) call die(myname_,'allocate(RSendBuf)',ier)

     ! allocate buffer to hold all incoming data
     RRecvSize = 1
     do proc=1,RecvRout%nprocs
        RRecvLoc(proc) = RRecvSize
        RRecvSize = RRecvSize + RecvRout%locsize(proc)*numr
     enddo
     if (RRecvSize > 1) RRecvSize = RRecvSize - 1
     allocate(RRecvBuf(RRecvSize),stat=ier)
     if(ier/=0) call die(myname_,'allocate(RRecvBuf)',ier)

  endif

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  ! INVERT PE LIST !
  call MP_comm_rank(ThisMCTWorld%MCT_comm,myPid,ier)
  if(ier/=0) call MP_perr_die(myname_,'MP_comm_rank',ier)

  call MP_comm_size(ThisMCTWorld%MCT_comm, max_pe, ier)
  if(ier/=0) call MP_perr_die(myname_,'MP_comm_size',ier)

  SendList(:) = -1
  do proc = 1,SendRout%nprocs
     SendList(SendRout%pe_list(proc)) = proc
  enddo

  RecvList(:) = -1
  do proc = 1,RecvRout%nprocs
     RecvList(RecvRout%pe_list(proc)) = proc
  enddo

  if (usealltoall) then
     ! CONSTRUCT CNTS AND DISPLS FOR ALLTOALLV !
     ISendCnts(:) = 0
     ISdispls(:)  = 0
     RSendCnts(:) = 0
     RSdispls(:)  = 0
     IRecvCnts(:) = 0
     IRdispls(:)  = 0
     RRecvCnts(:) = 0
     RRdispls(:)  = 0
     do pe = 0,max_pe-1
        proc = SendList(pe)
        if (proc .ne. -1) then
           ISendCnts(pe) = SendRout%locsize(proc)*numi
           ISdispls(pe)  = ISendLoc(proc) - 1

           RSendCnts(pe) = SendRout%locsize(proc)*numr
           RSdispls(pe)  = RSendLoc(proc) - 1
        endif

        proc = RecvList(pe)
        if (proc .ne. -1) then
           IRecvCnts(pe) = RecvRout%locsize(proc)*numi
           IRdispls(pe)  = IRecvLoc(proc) - 1

           RRecvCnts(pe) = RecvRout%locsize(proc)*numr
           RRdispls(pe)  = RRecvLoc(proc) - 1
        endif
     enddo

     ! SET MPI DATA TYPES
     ITypes(:) = MP_INTEGER
     RTypes(:) = mp_Type_rp
  endif

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
if (usealltoall) then

  ! Load data going to each processor
  do proc = 1,SendRout%nprocs
     j=0
     k=0

     ! load the correct pieces of the integer and real vectors
     do nseg = 1,SendRout%num_segs(proc)
        seg_start = SendRout%seg_starts(proc,nseg)
        seg_end = seg_start + SendRout%seg_lengths(proc,nseg)-1
        do VectIndex = seg_start,seg_end
           do AttrIndex = 1,numi
              ISendBuf(ISendLoc(proc)+j) = SourceAV%iAttr(AttrIndex,VectIndex)
              j=j+1
           enddo
           do AttrIndex = 1,numr
              RSendBuf(RSendLoc(proc)+k) = SourceAV%rAttr(AttrIndex,VectIndex)
              k=k+1
           enddo
        enddo
     enddo
  enddo

else
  ! POST MPI_IRECV

  ! Load data coming from each processor
  do pe_shift = 1,max_pe
   proc = RecvList(mod(myPid+pe_shift,max_pe))
    if (proc .ne. -1) then

     ! receive the integer data
     if(numi .ge. 1) then

        ! set tag
        mytag = DefaultTag
        if(present(Tag)) mytag=Tag

	if( (RecvRout%num_segs(proc) > 1) .or. DoSum ) then

	   call MPI_IRECV(IRecvBuf(IRecvLoc(proc)),                 &
		          RecvRout%locsize(proc)*numi,MP_INTEGER,   &
			  RecvRout%pe_list(proc),mytag,             &
			  ThisMCTWorld%MCT_comm,recv_ireqs(proc),ier)

	else

	   call MPI_IRECV(TargetAV%iAttr(1,RecvRout%seg_starts(proc,1)), &
		          RecvRout%locsize(proc)*numi,MP_INTEGER,        &
                          RecvRout%pe_list(proc),mytag,                  &
                          ThisMCTWorld%MCT_comm,recv_ireqs(proc),ier)

	endif

	if(ier /= 0) call MP_perr_die(myname_,'MPI_IRECV(ints)',ier)

     endif

     ! receive the real data
     if(numr .ge. 1) then

        ! set tag
        mytag = DefaultTag + 1
        if(present(Tag)) mytag=Tag +1

	if( (RecvRout%num_segs(proc) > 1) .or. DoSum ) then

	   call MPI_IRECV(RRecvBuf(RRecvLoc(proc)),                 &
		          RecvRout%locsize(proc)*numr,mp_Type_rp,   &
			  RecvRout%pe_list(proc),mytag,             &
			  ThisMCTWorld%MCT_comm,recv_rreqs(proc),ier)

	else

	   call MPI_IRECV(TargetAV%rAttr(1,RecvRout%seg_starts(proc,1)), &
		          RecvRout%locsize(proc)*numr,mp_Type_rp,        &
			  RecvRout%pe_list(proc),mytag,                  &
			  ThisMCTWorld%MCT_comm,recv_rreqs(proc),ier)

	endif

	if(ier /= 0) call MP_perr_die(myname_,'MPI_IRECV(reals)',ier)

     endif
    endif
  enddo

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  ! POST MPI_ISEND

  ! Load data going to each processor
  do pe_shift = max_pe,1,-1
   proc = SendList(mod(myPid+pe_shift,max_pe))
    if (proc .ne. -1) then

     if( SendRout%num_segs(proc) > 1 ) then

	j=0
	k=0

	! load the correct pieces of the integer and real vectors
	do nseg = 1,SendRout%num_segs(proc)
	   seg_start = SendRout%seg_starts(proc,nseg)
	   seg_end = seg_start + SendRout%seg_lengths(proc,nseg)-1
	   do VectIndex = seg_start,seg_end
	      do AttrIndex = 1,numi
		 ISendBuf(ISendLoc(proc)+j) = SourceAV%iAttr(AttrIndex,VectIndex)
		 j=j+1
	      enddo
	      do AttrIndex = 1,numr
		 RSendBuf(RSendLoc(proc)+k) = SourceAV%rAttr(AttrIndex,VectIndex)
		 k=k+1
	      enddo
	   enddo
	enddo

     endif

     ! send the integer data
     if(numi .ge. 1) then

        ! set tag
        mytag = DefaultTag
        if(present(Tag)) mytag=Tag

	if( SendRout%num_segs(proc) > 1 ) then

	   call MPI_ISEND(ISendBuf(ISendLoc(proc)),                 &
		          SendRout%locsize(proc)*numi,MP_INTEGER,   &
			  SendRout%pe_list(proc),mytag,             &
			  ThisMCTWorld%MCT_comm,send_ireqs(proc),ier)

	else

	   call MPI_ISEND(SourceAV%iAttr(1,SendRout%seg_starts(proc,1)), &
		          SendRout%locsize(proc)*numi,MP_INTEGER,        &
                          SendRout%pe_list(proc),mytag,                  &
                          ThisMCTWorld%MCT_comm,send_ireqs(proc),ier)

	endif

	if(ier /= 0) call MP_perr_die(myname_,'MPI_ISEND(ints)',ier)

     endif

     ! send the real data
     if(numr .ge. 1) then

        ! set tag
        mytag = DefaultTag +1
        if(present(Tag)) mytag=Tag +1

	if( SendRout%num_segs(proc) > 1 ) then

	   call MPI_ISEND(RSendBuf(RSendLoc(proc)),                 &
		          SendRout%locsize(proc)*numr,mp_Type_rp,   &
			  SendRout%pe_list(proc),mytag,             &
			  ThisMCTWorld%MCT_comm,send_rreqs(proc),ier)

	else

	   call MPI_ISEND(SourceAV%rAttr(1,SendRout%seg_starts(proc,1)), &
		          SendRout%locsize(proc)*numr,mp_Type_rp,        &
			  SendRout%pe_list(proc),mytag,                    &
			  ThisMCTWorld%MCT_comm,send_rreqs(proc),ier)

	endif

	if(ier /= 0) call MP_perr_die(myname_,'MPI_ISEND(reals)',ier)

     endif
    endif
  enddo
endif  ! end of else for if(usealltoall)
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  ! ZERO TARGETAV WHILE WAITING FOR MESSAGES TO COMPLETE

  if(DoSum) call AttrVect_zero(TargetAV)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  ! LOAD THE LOCAL PIECES OF THE INTEGER AND REAL VECTOR

  if(usevector) then
!$OMP PARALLEL DO PRIVATE(IAttrIndex,localindex,TrgVectIndex,SrcVectIndex)
     do IAttrIndex=1,numi
!CDIR SELECT(VECTOR)
!DIR$ CONCURRENT
!DIR$ PREFERVECTOR
     do localindex=1,InRearranger%LocalSize
        TrgVectIndex = InRearranger%LocalPack(1,localindex)
        SrcVectIndex = InRearranger%LocalPack(2,localindex)
        TargetAV%iAttr(IAttrIndex,TrgVectIndex) = &
             SourceAV%iAttr(IAttrIndex,SrcVectIndex)
      enddo
    enddo
!$OMP PARALLEL DO PRIVATE(RAttrIndex,localindex,TrgVectIndex,SrcVectIndex)
    do RAttrIndex=1,numr
!CDIR SELECT(VECTOR)
!DIR$ CONCURRENT
!DIR$ PREFERVECTOR
     do localindex=1,InRearranger%LocalSize
        TrgVectIndex = InRearranger%LocalPack(1,localindex)
        SrcVectIndex = InRearranger%LocalPack(2,localindex)
        TargetAV%rAttr(RAttrIndex,TrgVectIndex) = &
             SourceAV%rAttr(RAttrIndex,SrcVectIndex)
     enddo
    enddo

  else
!$OMP PARALLEL DO PRIVATE(localindex,TrgVectIndex,SrcVectIndex,IAttrIndex,RAttrIndex)
    do localindex=1,InRearranger%LocalSize
     TrgVectIndex = InRearranger%LocalPack(1,localindex)
     SrcVectIndex = InRearranger%LocalPack(2,localindex)
     do IAttrIndex=1,numi
	TargetAV%iAttr(IAttrIndex,TrgVectIndex) = &
	     SourceAV%iAttr(IAttrIndex,SrcVectIndex)
     enddo
     do RAttrIndex=1,numr
	TargetAV%rAttr(RAttrIndex,TrgVectIndex) = &
	     SourceAV%rAttr(RAttrIndex,SrcVectIndex)
     enddo
    enddo
  endif

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

if (usealltoall) then

 if (useswapm) then

  if (numi .ge. 1) then
     call m_swapm_int(max_pe, myPid,                                    &
                      ISendBuf, ISendSize, ISendCnts, ISdispls, ITypes, &
                      IRecvBuf, IRecvSize, IRecvCnts, IRdispls, ITypes, &
                      ThisMCTWorld%MCT_comm,                            &
                      swapm_hs, swapm_isend, swapm_maxreq               )
  endif

  if (numr .ge. 1) then
     call m_swapm_FP (max_pe, myPid,                                    &
                      RSendBuf, RSendSize, RSendCnts, RSdispls, RTypes, &
                      RRecvBuf, RRecvSize, RRecvCnts, RRdispls, RTypes, &
                      ThisMCTWorld%MCT_comm,                            &
                      swapm_hs, swapm_isend, swapm_maxreq               )
  endif

 else

  if (numi .ge. 1) then
     call MPI_Alltoallv(ISendBuf, ISendCnts, ISdispls, MP_INTEGER, &
                        IRecvBuf, IRecvCnts, IRdispls, MP_INTEGER, &
                        ThisMCTWorld%MCT_comm,ier)
  endif

  if (numr .ge. 1) then
     call MPI_Alltoallv(RSendBuf, RSendCnts, RSdispls, mp_Type_rp, &
                        RRecvBuf, RRecvCnts, RRdispls, mp_Type_rp, &
                        ThisMCTWorld%MCT_comm,ier)
  endif

 endif

else

  ! WAIT FOR THE NONBLOCKING SENDS TO COMPLETE

  if(SendRout%nprocs > 0) then

     if(numi .ge. 1) then

	call MPI_WAITALL(SendRout%nprocs,send_ireqs,send_istatus,ier)
	if(ier /= 0) call MP_perr_die(myname_,'MPI_WAITALL(ints)',ier)

     endif

     if(numr .ge. 1) then

	call MPI_WAITALL(SendRout%nprocs,send_rreqs,send_rstatus,ier)
	if(ier /= 0) call MP_perr_die(myname_,'MPI_WAITALL(reals)',ier)

     endif

  endif

endif
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  ! WAIT FOR THE NONBLOCKING RECEIVES TO COMPLETE AND UNPACK BUFFER

  do numprocs = 1,RecvRout%nprocs

     if(numi .ge. 1) then

if (usealltoall) then
        proc = numprocs
else
        if(DoSum) then
           proc = numprocs
	   call MPI_WAIT(recv_ireqs(proc),recv_istatus,ier)
        else
	   call MPI_WAITANY(RecvRout%nprocs,recv_ireqs,proc,recv_istatus,ier)
        endif
endif

	if(DoSum) then

	   ! load the correct pieces of the integer vectors
           j=0
	   do nseg = 1,RecvRout%num_segs(proc)
	      seg_start = RecvRout%seg_starts(proc,nseg)
	      seg_end = seg_start + RecvRout%seg_lengths(proc,nseg)-1
	      do VectIndex = seg_start,seg_end
		 do AttrIndex = 1,numi
		    TargetAV%iAttr(AttrIndex,VectIndex)= &
                    TargetAV%iAttr(AttrIndex,VectIndex) + IRecvBuf(IRecvLoc(proc)+j)
		    j=j+1
		 enddo
	      enddo
	   enddo

	else

	   if (( RecvRout%num_segs(proc) > 1 ) .or. (usealltoall)) then

	      ! load the correct pieces of the integer vectors
              j=0
	      do nseg = 1,RecvRout%num_segs(proc)
		 seg_start = RecvRout%seg_starts(proc,nseg)
		 seg_end = seg_start + RecvRout%seg_lengths(proc,nseg)-1
		 do VectIndex = seg_start,seg_end
		    do AttrIndex = 1,numi
		       TargetAV%iAttr(AttrIndex,VectIndex)=IRecvBuf(IRecvLoc(proc)+j)
		       j=j+1
		    enddo
		 enddo
	      enddo

	   endif

	endif ! end of if DoSum

     endif  ! end of in numi>1

     if(numr .ge. 1) then

if (usealltoall) then
        proc = numprocs
else
	if(DoSum) then
           proc = numprocs
	   call MPI_WAIT(recv_rreqs(proc),recv_rstatus,ier)
        else
	   call MPI_WAITANY(RecvRout%nprocs,recv_rreqs,proc,recv_rstatus,ier)
        endif
endif

	if(DoSum) then

	   ! load the correct pieces of the integer vectors
           k=0
	   do nseg = 1,RecvRout%num_segs(proc)
	      seg_start = RecvRout%seg_starts(proc,nseg)
	      seg_end = seg_start + RecvRout%seg_lengths(proc,nseg)-1
	      do VectIndex = seg_start,seg_end
		 do AttrIndex = 1,numr
		    TargetAV%rAttr(AttrIndex,VectIndex) = &
                    TargetAV%rAttr(AttrIndex,VectIndex) + RRecvBuf(RRecvLoc(proc)+k)
		    k=k+1
		 enddo
	      enddo
	   enddo

	else

	   if (( RecvRout%num_segs(proc) > 1 ) .or. (usealltoall)) then

	      ! load the correct pieces of the integer vectors
              k=0
	      do nseg = 1,RecvRout%num_segs(proc)
		 seg_start = RecvRout%seg_starts(proc,nseg)
		 seg_end = seg_start + RecvRout%seg_lengths(proc,nseg)-1
		 do VectIndex = seg_start,seg_end
		    do AttrIndex = 1,numr
		       TargetAV%rAttr(AttrIndex,VectIndex)=RRecvBuf(RRecvLoc(proc)+k)
		       k=k+1
		    enddo
		 enddo
	      enddo

	   endif

	endif  ! end if DoSum

     endif  ! endif if numr>1

  enddo

  if(Sendunordered) then
    call AttrVect_clean(SourceAvtmp)
    nullify(SourceAv)
  else
    nullify(SourceAv)
  endif

  if(Recvunordered) call Unpermute(TargetAv,RecvRout%permarr)

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  ! DEALLOCATE ALL STRUCTURES

  if (numi .ge. 1) then

     ! Deallocate the send buffer
     deallocate(ISendBuf,stat=ier)
     if(ier/=0) call die(myname_,'deallocate(ISendBuf)',ier)

     ! Deallocate the receive buffer
     deallocate(IRecvBuf,stat=ier)
     if(ier/=0) call die(myname_,'deallocate(IRecvBuf)',ier)

  endif

  if (numr .ge. 1) then

     ! Deallocate the send buffer
     deallocate(RSendBuf,stat=ier)
     if(ier/=0) call die(myname_,'deallocate(RSendBuf)',ier)

     ! Deallocate the receive buffer
     deallocate(RRecvBuf,stat=ier)
     if(ier/=0) call die(myname_,'deallocate(RRecvBuf)',ier)

  endif

  nullify(SendRout,RecvRout)

 end subroutine rearrange_




!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: print_ - Print rearranger communication info
!
! !DESCRIPTION:
! Print out communication info for both routers in a
! rearranger.  Print out on unit number 'lun'
! e.g. (source,destination,length)
!
! !INTERFACE:

    subroutine print_(rearr,mycomm,lun)
!
! !USES:
!
      use m_die
      use m_Router, only: router_print => print

      implicit none

!INPUT/OUTPUT PARAMETERS:
      type(Rearranger),      intent(in) :: rearr
      integer, intent(in)           :: mycomm
      integer, intent(in)           :: lun

! !REVISION HISTORY:
! 27Jul07 - R. Loy <rloy@mcs.anl.gov>  initial version
!EOP ___________________________________________________________________


      call router_print(rearr%SendRouter,mycomm,lun)
      call router_print(rearr%RecvRouter,mycomm,lun)

  end subroutine print_


end module m_Rearranger





