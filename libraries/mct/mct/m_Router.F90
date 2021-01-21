!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_Router -- Router class
!
! !DESCRIPTION:
! The Router data type contains all the information needed
! to send an AttrVect between a component on M MPI-processes and a component
! on N MPI-processes.   This module defines the Router datatype and provides
! methods to create and destroy one.
!
! !INTERFACE:

 module m_Router

      use m_realkinds, only : FP
      use m_zeit

      implicit none

      private   ! except

! !declare a private pointer structure for the real data
      type :: rptr
#ifdef SEQUENCE
        sequence
#endif
        real(FP),dimension(:),pointer :: pr
      end type

! !declare a private pointer structure for the integer data
      type :: iptr
#ifdef SEQUENCE
        sequence
#endif
        integer,dimension(:),pointer :: pi
      end type

! !PUBLIC TYPES:
      public :: Router	        ! The class data structure

      public :: rptr,iptr       ! pointer types used in Router
!\end{verbatim}
!% On return, pe_list is the processor ranks of the other
!% component to receive from/send to.  num_segs is the
!% number of segments out of my local AttrVect which must
!% be sent/received.  (In general, these wont coincide exactly
!% with the segments used to define the GlobalMap)
!% seg_start is the start *in the local AttrVect* of each segment
!%  (start goes from 1 to lsize(GSMap))
!% and seg_lengths is the length.
!\begin{verbatim}

    type Router
#ifdef SEQUENCE
      sequence
#endif
      integer :: comp1id                           ! myid
      integer :: comp2id                           ! id of second component
      integer :: nprocs	                           ! number of procs to talk to
      integer :: maxsize                           ! maximum amount of data going to a processor
      integer :: lAvsize                           ! The local size of AttrVect which can be
                                                   ! used with this Router in MCT_Send/MCT_Recv
      integer :: numiatt                           ! Number of integer attributes currently in use
      integer :: numratt                           ! Number of real attributes currently in use
      integer,dimension(:),pointer   :: pe_list    ! processor ranks of send/receive in MCT_comm
      integer,dimension(:),pointer   :: num_segs   ! number of segments to send/receive
      integer,dimension(:),pointer   :: locsize    ! total of seg_lengths for a proc
      integer,dimension(:),pointer   :: permarr    ! possible permutation array
      integer,dimension(:,:),pointer :: seg_starts ! starting index
      integer,dimension(:,:),pointer :: seg_lengths! total length
      type(rptr),dimension(:),pointer :: rp1       ! buffer to hold real data
      type(iptr),dimension(:),pointer :: ip1       ! buffer to hold integer data
      integer,dimension(:),pointer   :: ireqs,rreqs  ! buffer for MPI_Requests
      integer,dimension(:,:),pointer :: istatus,rstatus  ! buffer for MPI_Status
    end type Router

! !PUBLIC MEMBER FUNCTIONS:
      public :: init            ! Create a Router
      public :: clean           ! Destroy a Router
      public :: print           ! Print info about a Router


    interface init  ; module procedure  &
        initd_, &       ! initialize a Router between two seperate components
        initp_ 	        ! initialize a Router locally with two GSMaps
    end interface
    interface clean ; module procedure clean_ ; end interface
    interface print ; module procedure print_ ; end interface

! !REVISION HISTORY:
! 15Jan01 - R. Jacob <jacob@mcs.anl.gov> - initial prototype
! 08Feb01 - R. Jacob <jacob@mcs.anl.gov> add locsize and maxsize
!           to Router type
! 25Sep02 - R. Jacob <jacob@mcs.anl.gov> Remove type string.  Add lAvsize
! 23Jul03 - R. Jacob <jacob@mcs.anl.gov> Add status and reqs arrays used
!           in send/recv to the Router datatype.
! 24Jul03 - R. Jacob <jacob@mcs.anl.gov> Add real and integer buffers
!           for send/recv to the Router datatype.
! 22Jan08 - R. Jacob <jacob@mcs.anl.gov> Add ability to handle an unordered
!           GSMap by creating a new, ordered one and building Router from
!           that.  Save permutation info in Router datatype.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_Router'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initd_ - initialize a Router between two seperate components
!
! !DESCRIPTION:
! The routine {\tt initd\_()} exchanges the {\tt GSMap} with the
! component identified by {\tt othercomp} and then calls {\tt initp\_()}
! to build a Router {\tt Rout} between them.
!
! {\bf N.B.} The  {\tt GSMap} argument must be declared so that the index values
! on a processor are in ascending order.
!
! !INTERFACE:

 subroutine initd_(othercomp,GSMap,mycomm,Rout,name )
!
! !USES:
!
      use m_GlobalSegMap, only :GlobalSegMap
      use m_ExchangeMaps,only: MCT_ExGSMap => ExchangeMap
      use m_mpif90
      use m_die

      implicit none

! !INPUT PARAMETERS:
!
      integer, intent(in)	       :: othercomp
      integer, intent(in)	       :: mycomm
      type(GlobalSegMap),intent(in)    :: GSMap     ! of the calling comp
      character(len=*), intent(in),optional     :: name

! !OUTPUT PARAMETERS:
!
      type(Router), intent(out)        :: Rout

! !REVISION HISTORY:
! 15Jan01 - R. Jacob <jacob@mcs.anl.gov> - initial prototype
! 06Feb01 - R. Jacob <jacob@mcs.anl.gov> - Finish initialization
!           of the Router.  Router now works both ways.
! 25Apr01 - R. Jacob <jacob@mcs.anl.gov> - Eliminate early
!           custom code to exchange GSMap components and instead
!           the more general purpose routine in m_ExchangeMaps.
!           Use new subroutine OrderedPoints in m_GlobalSegMap
!           to construct the vector of local and remote GSMaps.
!           Clean-up code a little.
! 03May01 - R. Jacob <jacob@mcs.anl.gov> - rename to initd and
!           move most of code to new initp routine
!
!EOP ___________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::initd_'
  character(len=40) :: tagname

  type(GlobalSegMap)    :: RGSMap  !  the other GSMap
  integer ::		   ier

!--------------------------begin code-----------------------

!!!!!!!!!!!!!!!!!Exchange of global map data

  if(present(name)) then
    tagname='01'//name//'ExGSMap'

    call zeit_ci(trim(tagname))
    call MCT_ExGSMap(GSMap,mycomm,RGSMap,othercomp,ier)
    if(ier /= 0) call die(myname_,'ExGSMap',ier)
    call zeit_co(trim(tagname))

!!!!!!!!!!!!!!!!!Begin comparison of globalsegmaps

    call initp_(GSMap,RGSMap, mycomm, Rout,name)
  else
    call MCT_ExGSMap(GSMap,mycomm,RGSMap,othercomp,ier)
    call initp_(GSMap,RGSMap, mycomm, Rout)
  endif

 end subroutine initd_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initp_ - initialize a Router from two GlobalSegMaps
!
! !DESCRIPTION:
!
! Given two GlobalSegmentMaps {\tt GSMap} and {\tt RGSMap}, intialize a
! Router {\tt Rout} between them.  Use local communicator {\tt mycomm}.
!
! {\bf N.B.} The two {\tt GSMap} arguments must be declared so that the index values
! on a processor are in ascending order.
!
! !INTERFACE:

 subroutine initp_(inGSMap,inRGSMap,mycomm,Rout,name )
!
! !USES:
!
      use m_GlobalSegMap,  only :GlobalSegMap
      use m_GlobalSegMap,  only :ProcessStorage
      use m_GlobalSegMap,  only :GSMap_comp_id => comp_id
      use m_GlobalSegMap,  only :GSMap_increasing => increasing
      use m_GlobalSegMap,  only :GlobalSegMap_copy => copy
      use m_GlobalSegMap,  only :GlobalSegMap_init => init
      use m_GlobalSegMap,  only :GlobalSegMap_clean => clean
      use m_GlobalSegMap,  only :GlobalSegMap_OPoints => OrderedPoints
      use m_GlobalSegMap,  only :GlobalSegMap_ngseg => ngseg  ! rml
      use m_GlobalSegMap,  only :GlobalSegMap_nlseg => nlseg  ! rml
      use m_GlobalSegMap,  only :GlobalSegMap_max_nlseg => max_nlseg  ! rml

      use m_GlobalToLocal, only :GlobalToLocalIndex
      use m_MCTWorld,      only :MCTWorld
      use m_MCTWorld,      only :ThisMCTWorld

      use m_Permuter      ,only:Permute
      use m_MergeSorts    ,only:IndexSet
      use m_MergeSorts    ,only:IndexSort

      use m_mpif90
      use m_die

!      use m_zeit


      use m_stdio    ! rml
!      use shr_timer_mod        ! rml timers

      implicit none

! !INPUT PARAMETERS:
!
      type(GlobalSegMap), intent(in)	:: inGSMap
      type(GlobalSegMap), intent(in)	:: inRGSMap
      integer	     ,    intent(in)	:: mycomm
      character(len=*), intent(in),optional     :: name

! !OUTPUT PARAMETERS:
!
      type(Router),      intent(out)	:: Rout

! !REVISION HISTORY:
! 03May01 - R.L. Jacob <jacob@mcs.anl.gov> - Initial code brought
!           in from old init routine.
! 31Jul01 - Jace A Mogill <mogill@cray.com>
!           Rewrote to reduce number of loops and temp storage
! 26Apr06 - R. Loy <rloy@mcs.anl.gov> - recode the search through
!           the remote GSMap to improve efficiency
! 05Jan07 - R. Loy <rloy@mcs.anl.gov> - improved bound on size of
!           tmpsegcount and tmpsegstart
! 15May07 - R. Loy <rloy@mcs.anl.gov> - improved bound on size of
!           rgs_lb and rgs_ub
! 25Jan08 - R. Jacob <jacob@mcs.anl.gov> - Dont die if GSMap is not
!           increasing.  Instead, permute it to increasing and proceed.
! 07Sep12 - T. Craig <tcraig@ucar.edu> - Replace a double loop with a single
!           to improve speed for large proc and segment counts.
! 12Nov16 - P. Worley <worleyph@gmail.com> - eliminate iterations in nested
!           loop that can be determined to be unnecessary
!EOP -------------------------------------------------------------------

  character(len=*),parameter :: myname_=myname//'::initp_'
  integer			     :: ier,i,j,k,m,n
  integer			     :: mysize,myPid,othercomp
  integer			     :: lmaxsize,totallength
  integer                            :: maxsegcount,count
  logical, dimension(:), allocatable :: tmppe_list
  integer, dimension(:,:), pointer   :: tmpsegcount,tmpsegstart


  integer :: my_left        ! Left point in local segment (global memory)
  integer :: my_right       ! Right point in local segment (global memory)
  integer :: my_leftmost    ! Leftmost point in local segments (global memory)
  integer :: my_rightmost   ! Rightmost point in local segments (global memory)
  integer :: r_left         ! Left point in remote segment (global memory)
  integer :: r_right        ! Right point in remote segment (global memory)
  integer :: r_leftmost     ! Leftmost point and rightmost point
  integer :: r_rightmost    !  in remote segments in given process (global memory)
  integer :: nsegs_overlap  ! Number of segments that overlap between two procs


  integer :: ngseg, nlseg
  integer :: myseg, rseg
  integer :: rseg_leftbase, rseg_start
  integer :: prev_right     ! Rightmost local point in previous overlapped segment
  integer :: local_left, local_right
  integer,allocatable  :: mygs_lb(:),mygs_ub(:),mygs_len(:),mygs_lstart(:)
  integer :: r_ngseg
  integer,allocatable  :: rgs_count(:),rgs_lb(:,:),rgs_ub(:,:)
  integer,allocatable  :: nsegs_overlap_arr(:)

  integer :: overlap_left, overlap_right, overlap_diff

  integer :: proc, nprocs
  integer :: feas_proc, feas_nprocs
  integer,allocatable  :: feas_procs(:), inv_feas_procs(:)

  integer :: max_rgs_count, max_overlap_segs
  type(GlobalSegMap)	:: GSMap
  type(GlobalSegMap)	:: RGSMap
  integer, dimension(:), pointer   :: gpoints
  integer, dimension(:), pointer   :: permarr
  integer, dimension(:), pointer   :: rpermarr
  integer  :: gmapsize
  character(len=40) :: tagname


  integer,save  :: t_initialized=0   ! rml timers
  integer,save  :: t_loop            ! rml timers
  integer,save  :: t_loop2            ! rml timers
  integer,save  :: t_load            ! rml timers

  call MP_comm_rank(mycomm,myPid,ier)
  if(ier/=0) call MP_perr_die(myname_,'MP_comm_rank',ier)

  nullify(Rout%permarr)

  if(present(name)) then
    tagname='02'//name//'incheck'
    call zeit_ci(trim(tagname))
  endif
  if (.not. GSMap_increasing(inGSMap)) then
    if(myPid == 0) call warn(myname_,'GSMap indices not increasing...Will correct')
    call GlobalSegMap_OPoints(inGSMap,myPid,gpoints)
    gmapsize=ProcessStorage(inGSMap,myPid)
    allocate(permarr(gmapsize), stat=ier)
    if(ier/=0) call die(myname_,'allocate permarr',ier)
    call IndexSet(permarr)
    call IndexSort(permarr,gpoints)
    call Permute(gpoints,permarr,gmapsize)
    call GlobalSegMap_init(GSMap,gpoints,mycomm,inGSMap%comp_id,gsize=inGSMap%gsize)

    allocate(Rout%permarr(gmapsize),stat=ier)
    if(ier/=0) call die(myname_,'allocate Router%permarr',ier)
    Rout%permarr(:)=permarr(:)

    deallocate(gpoints,permarr, stat=ier)
    if(ier/=0) call die(myname_,'deallocate gpoints,permarr',ier)

  else
    call GlobalSegMap_copy(inGSMap,GSMap)
  endif

  if (.not. GSMap_increasing(inRGSMap)) then
    if(myPid == 0) call warn(myname_,'RGSMap indices not increasing...Will correct')
    call GlobalSegMap_OPoints(inRGSMap,myPid,gpoints)
    gmapsize=ProcessStorage(inRGSMap,myPid)
    allocate(rpermarr(gmapsize), stat=ier)
    if(ier/=0) call die(myname_,'allocate rpermarr',ier)
    call IndexSet(rpermarr)
    call IndexSort(rpermarr,gpoints)
    call Permute(gpoints,rpermarr,gmapsize)

    call GlobalSegMap_init(RGSMap,gpoints,mycomm,inRGSMap%comp_id,gsize=inRGSMap%gsize)

    deallocate(gpoints,rpermarr, stat=ier)
    if(ier/=0) call die(myname_,'deallocate gpoints,rpermarr',ier)
  else
    call GlobalSegMap_copy(inRGSMap,RGSMap)
  endif
  if(present(name)) then
    call zeit_co(trim(tagname))
  endif


  mysize = ProcessStorage(GSMap,myPid)
  othercomp = GSMap_comp_id(RGSMap)


!.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .



!!
!! determine the global segments on this processor
!! just once, so the info be used repeatedly below
!! same code was used in m_GlobalToLocal - should make a subroutine...
!!
  if(present(name)) then
    tagname='03'//name//'lloop'
    call zeit_ci(trim(tagname))
  endif

  ngseg = GlobalSegMap_ngseg(GSMap)
  nlseg = GlobalSegMap_nlseg(GSMap, myPid)

  allocate( mygs_lb(nlseg), mygs_ub(nlseg), mygs_len(nlseg), &
            mygs_lstart(nlseg), stat=ier )
  if(ier/=0) call die(myname_,'allocate mygs',ier)

  n = 0
  do i=1,ngseg
    if (GSMap%pe_loc(i) == myPid ) then
      n=n+1
      mygs_lb(n)=GSMap%start(i)
      mygs_ub(n)=GSMap%start(i) + GSMap%length(i) -1
      mygs_len(n)=GSMap%length(i)
    endif
  enddo

  if (n .ne. nlseg) then
    write(stderr,*) myname_,"mismatch nlseg",n,nlseg
    call die(myname)
  endif

  if (nlseg > 0) mygs_lstart(1)=1
  do i=2,nlseg
    mygs_lstart(i)=mygs_lstart(i-1)+mygs_len(i-1)
  enddo
  if(present(name)) then
    call zeit_co(trim(tagname))
  endif

!!
!! determine the possibly overlapping segments
!! in RGSMap that are local to each proc
!!
  nprocs=ThisMCTWorld%nprocspid(othercomp)
  r_ngseg = GlobalSegMap_ngseg(RGSMap)

  if (nlseg > 0) then
    my_leftmost  = mygs_lb(1)
    my_rightmost = mygs_ub(nlseg)

!!
!!  count number of potentially overlapping remote segments
!!  and which and how many processes hold these
!!
    if(present(name)) then
      tagname='04'//name//'rloop'
      call zeit_ci(trim(tagname))
    endif

    !! number of potentially overlapping segments in RGSMap local to proc
    !! and mapping from processes that hold these to actual process id
    allocate( rgs_count(nprocs), feas_procs(nprocs), &
              inv_feas_procs(nprocs), stat=ier )
    if(ier/=0) call die(myname_,'allocate rgs_count, feas_procs',ier)

    rgs_count = 0
    do i=1,r_ngseg
      r_left  = RGSMap%start(i)
      r_right = RGSMap%start(i) + RGSMap%length(i) - 1

      if (.not. (my_rightmost < r_left   .or.          & ! potential overlap
                 my_leftmost  > r_right       ) ) then
        proc = RGSMap%pe_loc(i) + 1
!        if (proc < 1 .or. proc > nprocs) then
!          write(stderr,*) myname_,"proc pe_loc error",i,proc
!          call die(myname_,'pe_loc error',0)
!        endif
        rgs_count(proc) = rgs_count(proc) + 1
      endif

    enddo

    feas_nprocs   = 0
    feas_procs    = -1
    inv_feas_procs = -1
    do proc=1,nprocs
      if (rgs_count(proc) > 0) then
        feas_nprocs = feas_nprocs + 1
        feas_procs(feas_nprocs) = proc
        inv_feas_procs(proc) = feas_nprocs
      endif
    enddo

!!
!!  build list of potentially overlapping remote segments
!!
    !! original size of rgs_lb()/ub() was (r_ngseg,nprocs)
    !! at the cost of looping to compute it (within GlobalSegMap_max_nlseg),
    !!   reduced size to (r_max_nlseg,nprocs)
    !! then further reduced to (max_rgs_count,feas_nprocs)

    max_rgs_count=0
    do proc=1,nprocs
      max_rgs_count = max( max_rgs_count, rgs_count(proc) )
    enddo

    allocate( rgs_lb(max_rgs_count,feas_nprocs), &
              rgs_ub(max_rgs_count,feas_nprocs), &
              nsegs_overlap_arr(feas_nprocs), stat=ier )
    if(ier/=0) call die(myname_,'allocate rgs, nsegs',ier)

    !! (note: redefining rgs_count to be indexed as 1:feas_nprocs
    !!  instead of as 1:nprocs)
    rgs_count = 0
    do i=1,r_ngseg
      r_left  = RGSMap%start(i)
      r_right = RGSMap%start(i) + RGSMap%length(i) -1

      if (.not. (my_rightmost < r_left   .or.  &     ! potential overlap
                 my_leftmost  > r_right)     ) then
        proc = RGSMap%pe_loc(i) + 1
        feas_proc = inv_feas_procs(proc)
        rgs_count(feas_proc) = rgs_count(feas_proc) + 1
        rgs_lb( rgs_count(feas_proc) , feas_proc ) = RGSMap%start(i)
        rgs_ub( rgs_count(feas_proc) , feas_proc ) = RGSMap%start(i) + RGSMap%length(i) -1
      endif

    enddo

    deallocate(inv_feas_procs,stat=ier)
    if(ier/=0) call die(myname_,'deallocate inv_feas_procs',ier)

    if(present(name)) then
      call zeit_co(trim(tagname))
    endif

  else

    max_rgs_count = 0
    feas_nprocs = 0

  endif

!!!!!!!!!!!!!!!!!!

! allocate space for searching
!   overlap segments to a given remote proc cannot be more than
!   the max of the local segments and the remote segments

  if(present(name)) then
    tagname='06'//name//'loop2'
    call zeit_ci(trim(tagname))
  endif

  max_overlap_segs = max(nlseg,max_rgs_count)

  allocate(tmpsegcount(feas_nprocs, max_overlap_segs),&
           tmpsegstart(feas_nprocs, max_overlap_segs),&
 	   tmppe_list(feas_nprocs),stat=ier)
  if(ier/=0)  &
    call die( myname_,'allocate tmpsegcount etc. size ', &
              feas_nprocs, ' by ',max_overlap_segs)

  if (feas_nprocs > 0) then
    tmpsegcount=0
    tmpsegstart=0
  endif
  count =0
  maxsegcount=0

!!!!!!!!!!!!!!!!!!

  do feas_proc = 1, feas_nprocs
    nsegs_overlap = 0
    tmppe_list(feas_proc) = .FALSE.          ! no overlaps with proc yet

    r_leftmost  = rgs_lb(1,feas_proc)
    r_rightmost = rgs_ub(rgs_count(feas_proc),feas_proc)

    rseg_leftbase = 0
    do myseg = 1, nlseg                      ! loop over local segs on 'myPID'

      my_left = mygs_lb(myseg)
      my_right= mygs_ub(myseg)

      ! determine whether any overlap
      if (.not. (my_right < r_leftmost   .or.  &
                 my_left  > r_rightmost)       ) then

        rseg_start = rseg_leftbase + 1       ! rseg loop index to start searching from

        ! loop over candidate overlapping remote segs on 'feas_proc'
        do rseg = rseg_start, rgs_count(feas_proc)

          r_right = rgs_ub(rseg,feas_proc)
          if (r_right < my_left ) then       ! to the left
            rseg_leftbase = rseg             ! remember to start to the right of
                                             !  this for next myseg
            cycle                            ! try the next remote segment
          endif

          r_left  = rgs_lb(rseg,feas_proc)
          if (r_left  > my_right) exit       ! to the right, so no more segments
                                             !  need to be examined

          ! otherwise, overlaps
          if (nsegs_overlap == 0) then       ! first overlap w/this proc
            count = count + 1
            tmppe_list(feas_proc) = .TRUE.
            prev_right = -9999
          else
            prev_right = local_right
          endif

          overlap_left=max(my_left, r_left)
          overlap_right=min(my_right, r_right)
          overlap_diff= overlap_right - overlap_left

          local_left  = mygs_lstart(myseg) + (overlap_left - my_left)
          local_right = local_left + overlap_diff

          ! non-contiguous w/prev one
          if (local_left /= (prev_right+1) ) then
            nsegs_overlap = nsegs_overlap + 1
            tmpsegstart(count, nsegs_overlap) = local_left
          endif

          tmpsegcount(count, nsegs_overlap) = &
            tmpsegcount(count, nsegs_overlap) + overlap_diff + 1

        enddo

      endif

    enddo

    nsegs_overlap_arr(feas_proc)=nsegs_overlap
  enddo

  !! pull this out of the loop to vectorize
  do feas_proc = 1, feas_nprocs
    maxsegcount=max(maxsegcount,nsegs_overlap_arr(feas_proc))
  enddo

  if (maxsegcount > max_overlap_segs) &
    call die( myname_,'overran max_overlap_segs =', &
              max_overlap_segs, ' count = ',maxsegcount)

!  write(stderr,*) 'max_overlap_segs =', max_overlap_segs, &
!                  'maxsegcount =',maxsegcount, &
!                  'mysize =',mysize


  deallocate( mygs_lb, mygs_ub, mygs_len, mygs_lstart, stat=ier)
  if(ier/=0) call die(myname_,'deallocate mygs,nsegs',ier)

  if (nlseg > 0) then
    deallocate( rgs_count, rgs_lb, rgs_ub, &
                nsegs_overlap_arr, stat=ier)
    if(ier/=0) call die(myname_,'deallocate p_rgs, nsegs',ier)
  endif

!  call shr_timer_stop(t_loop2)    ! rml timers
  if(present(name)) then
    call zeit_co(trim(tagname))
  endif


!.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .


!!!!!!!!!!!!!!!!!!!!end of search through remote GSMap

! start loading up the Router with data

  if(present(name)) then
    tagname='07'//name//'load'
    call zeit_ci(trim(tagname))
  endif

  Rout%comp1id = GSMap_comp_id(GSMap)
  Rout%comp2id = othercomp
  Rout%nprocs = count
  Rout%numiatt = 0
  Rout%numratt = 0

  allocate(Rout%pe_list(count),Rout%num_segs(count), &
    Rout%seg_starts(count,maxsegcount), &
    Rout%seg_lengths(count,maxsegcount), &
    Rout%locsize(count),stat=ier)
  if(ier/=0) call die(myname_,'allocate(Rout..)',ier)

  allocate(Rout%istatus(MP_STATUS_SIZE,count), &
             Rout%rstatus(MP_STATUS_SIZE,count), &
	     Rout%rreqs(count),Rout%ireqs(count),stat=ier)
  if(ier/=0) call die(myname_,'allocate(status,reqs,...)',ier)

! allocate the number of pointers needed
  allocate(Rout%ip1(count),stat=ier)
  if(ier/=0) call die(myname_,'allocate(ip1)',ier)

! allocate the number of pointers needed
  allocate(Rout%rp1(count),stat=ier)
  if(ier/=0) call die(myname_,'allocate(rp1)',ier)

  m=0
  do i=1,feas_nprocs
    if(tmppe_list(i))then
      m=m+1
      ! load processor rank in MCT_comm
      proc = feas_procs(i)
      Rout%pe_list(m)=ThisMCTWorld%idGprocid(othercomp,proc-1)
    endif
  enddo

  lmaxsize=0
  do i=1,count
    totallength=0
    do j=1,maxsegcount
      if(tmpsegcount(i,j) /= 0) then
	Rout%num_segs(i)=j
 	Rout%seg_starts(i,j)=tmpsegstart(i,j)
	Rout%seg_lengths(i,j)=tmpsegcount(i,j)
	totallength=totallength+Rout%seg_lengths(i,j)
      endif
    enddo
    Rout%locsize(i)=totallength
    lmaxsize=MAX(lmaxsize,totallength)
  enddo

  Rout%maxsize=lmaxsize
  Rout%lAvsize=mysize

  if (nlseg > 0) then
    deallocate(feas_procs,stat=ier)
    if(ier/=0) call die(myname_,'deallocate feas_procs',ier)
  endif

  deallocate(tmpsegstart,tmpsegcount,tmppe_list,stat=ier)
  if(ier/=0) call die(myname_,'deallocate tmp',ier)

  call GlobalSegMap_clean(RGSMap)
  call GlobalSegMap_clean(GSMap)

  if(present(name)) then
    call zeit_co(trim(tagname))
  endif

 end subroutine initp_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: clean_ - Destroy a Router
!
! !DESCRIPTION:
! Deallocate Router internal data structures and set integer parts to zero.
!
! !INTERFACE:

    subroutine clean_(Rout,stat)
!
! !USES:
!
      use m_die

      implicit none

!INPUT/OUTPUT PARAMETERS:
      type(Router),      intent(inout) :: Rout

!OUTPUT PARAMETERS:
      integer, optional, intent(out)   :: stat

! !REVISION HISTORY:
! 15Jan01 - R. Jacob <jacob@mcs.anl.gov> - initial prototype
! 08Feb01 - R. Jacob <jacob@mcs.anl.gov> - add code to clean
!           the maxsize and locsize
! 01Mar02 - E.T. Ong <eong@mcs.anl.gov> removed the die to prevent
!           crashes and added stat argument.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::clean_'
  integer :: ier

  deallocate(Rout%pe_list,Rout%num_segs,Rout%seg_starts, &
  Rout%locsize,Rout%seg_lengths,stat=ier)
  if(present(stat)) then
     stat=ier
  else
     if(ier /= 0) call warn(myname_,'deallocate(Rout%pe_list,...)',ier)
  endif

  deallocate(Rout%rreqs,Rout%ireqs,Rout%rstatus,&
   Rout%istatus,stat=ier)
  if(present(stat)) then
     stat=ier
  else
     if(ier /= 0) call warn(myname_,'deallocate(Rout%rreqs,...)',ier)
  endif

  deallocate(Rout%ip1,Rout%rp1,stat=ier)
  if(present(stat)) then
     stat=ier
  else
     if(ier /= 0) call warn(myname_,'deallocate(Rout%ip1,...)',ier)
  endif

  if(associated(Rout%permarr)) then
     deallocate(Rout%permarr,stat=ier)
     if(present(stat)) then
        stat=ier
     else
        if(ier /= 0) call warn(myname_,'deallocate(Rout%ip1,...)',ier)
     endif
  endif

  Rout%comp1id = 0
  Rout%comp2id = 0
  Rout%nprocs = 0
  Rout%maxsize = 0
  Rout%lAvsize = 0
  Rout%numiatt = 0
  Rout%numratt = 0


 end subroutine clean_


!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: print_ - Print router info
!
! !DESCRIPTION:
! Print out communication info about router on unit number 'lun'
! e.g. (source,destination,length)
!
! !INTERFACE:

    subroutine print_(rout,mycomm,lun)
!
! !USES:
!
      use m_die
      use m_mpif90

      implicit none

!INPUT/OUTPUT PARAMETERS:
      type(Router),      intent(in) :: Rout
      integer, intent(in)           :: mycomm
      integer, intent(in)           :: lun

! !REVISION HISTORY:
! 27Jul07 - R. Loy <rloy@mcs.anl.gov>  initial version
!EOP ___________________________________________________________________


    integer iproc
    integer myrank
    integer ier
    character(len=*),parameter :: myname_=myname//'::print_'

    call MP_comm_rank(mycomm,myrank,ier)
    if(ier/=0) call MP_perr_die(myname_,'MP_comm_rank',ier)


    do iproc=1,rout%nprocs
      if (rout%num_segs(iproc) > 0) then
        write(lun,*) myrank,rout%pe_list(iproc),rout%locsize(iproc)
      endif
    end do


  end subroutine print_


 end module m_Router

