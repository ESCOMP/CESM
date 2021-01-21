!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: m_GlobalSegMap.F90,v 1.56 2009-03-17 16:51:49 jacob Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !MODULE: m_GlobalSegMap - a nontrivial 1-D decomposition of an array.
!
! !DESCRIPTION:
! Consider the problem of the 1-dimensional decomposition of an array
! across multiple processes.  If each process owns only one contiguous
! segment, then the {\tt GlobalMap} (see {\tt m\_GlobalMap} or details)
! is sufficient to describe the decomposition.  If, however, each
! process owns multiple, non-adjacent segments of the array, a more
! sophisticated approach is needed.   The {\tt GlobalSegMap} data type
! allows one to describe a one-dimensional decomposition of an array
! with each process owning multiple, non-adjacent segments of the array.
!
! In the current implementation of the {\tt GlobalSegMap}, there is no
! santity check to guarantee that
!$${\tt GlobalSegMap\%gsize} = \sum_{{\tt i}=1}^{\tt ngseg}
! {\tt GlobalSegMap\%length(i)} . $$
! The reason we have not implemented such a check is to allow the user
! to use the {\tt GlobalSegMap} type to support decompositions of both
! {\em haloed} and {\em masked} data.
!
! !INTERFACE:

 module m_GlobalSegMap

      implicit none

      private	! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: GlobalSegMap    ! The class data structure
      public :: init            ! Create
      public :: clean           ! Destroy
      public :: comp_id         ! Return component ID number
      public :: gsize           ! Return global vector size (excl. halos)
      public :: GlobalStorage   ! Return total number of points in map,
                                ! including halo points (if present).
      public :: ProcessStorage  ! Return local storage on a given process.
      public :: OrderedPoints   ! Return grid points of a given process in
                                ! MCT-assumed order.
      public :: lsize           ! Return local--that is, on-process--storage
                                ! size (incl. halos)
      public :: ngseg           ! Return global number of segments
      public :: nlseg           ! Return local number of segments
      public :: max_nlseg       ! Return max local number of segments
      public :: active_pes      ! Return number of pes with at least 1
                                ! datum, and if requested, a list of them.
      public :: peLocs          ! Given an input list of point indices,
                                ! return its (unique) process ID.
      public :: haloed          ! Is the input GlobalSegMap haloed?
      public :: rank            ! Rank which process owns a datum
      public :: Sort            ! compute index permutation to re-order
                                ! GlobalSegMap%start, GlobalSegMap%length,
                                ! and GlobalSegMap%pe_loc
      public :: Permute         ! apply index permutation to re-order
                                ! GlobalSegMap%start, GlobalSegMap%length,
                                ! and GlobalSegMap%pe_loc
      public :: SortPermute     ! compute index permutation and apply it to
                                ! re-order the GlobalSegMap components
                                ! GlobalSegMap%start, GlobalSegMap%length,
                                ! and GlobalSegMap%pe_loc
      public :: increasing      ! Are the indices for each pe strictly
                                ! increasing?
      public :: copy            ! Copy the gsmap
      public :: print           ! Print the contents of the GSMap

! !PUBLIC TYPES:

    type GlobalSegMap
#ifdef SEQUENCE
      sequence
#endif
      integer :: comp_id			! Component ID number
      integer :: ngseg				! No. of Global segments
      integer :: gsize				! No. of Global elements
      integer,dimension(:),pointer :: start	! global seg. start index
      integer,dimension(:),pointer :: length	! segment lengths
      integer,dimension(:),pointer :: pe_loc	! PE locations
    end type GlobalSegMap

    interface init ; module procedure	&
        initd_,	&       ! initialize from all PEs
        initr_, &       ! initialize from the root
        initp_,	&       ! initialize in parallel from replicated arrays
        initp1_, &      ! initialize in parallel from 1 replicated array
        initp0_, &      ! null constructor using replicated data
        init_index_     ! initialize from local index arrays
    end interface

    interface clean   ; module procedure clean_   ; end interface
    interface comp_id ; module procedure comp_id_ ; end interface
    interface gsize   ; module procedure gsize_   ; end interface
    interface GlobalStorage ; module procedure &
       GlobalStorage_
    end interface
    interface ProcessStorage ; module procedure &
       ProcessStorage_
    end interface
    interface OrderedPoints ; module procedure &
       OrderedPoints_
    end interface
    interface lsize ; module procedure lsize_ ; end interface
    interface ngseg ; module procedure ngseg_ ; end interface
    interface nlseg ; module procedure nlseg_ ; end interface
    interface max_nlseg ; module procedure max_nlseg_ ; end interface
    interface active_pes ; module procedure active_pes_ ; end interface
    interface peLocs ; module procedure peLocs_ ; end interface
    interface haloed ; module procedure haloed_ ; end interface
    interface rank  ; module procedure &
	rank1_ , &      ! single rank case
	rankm_	        ! degenerate (multiple) ranks for halo case
    end interface
    interface Sort ; module procedure Sort_ ; end interface
    interface Permute ; module procedure &
	PermuteInPlace_
    end interface
    interface SortPermute ; module procedure &
	SortPermuteInPlace_
    end interface
    interface increasing ; module procedure increasing_ ; end interface
    interface copy ; module procedure copy_ ; end interface
    interface print ; module procedure &
          print_ ,&
	  printFromRootnp_
    end interface


! !REVISION HISTORY:
! 	28Sep00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
! 	26Jan01 - J.W. Larson <larson@mcs.anl.gov> - replaced the component
!                 GlobalSegMap%comm with GlobalSegMap%comp_id.
! 	06Feb01 - J.W. Larson <larson@mcs.anl.gov> - removed the
!                 GlobalSegMap%lsize component.  Also, added the
!                 GlobalStorage query function.
! 	24Feb01 - J.W. Larson <larson@mcs.anl.gov> - Added the replicated
!                 initialization routines initp_() and initp1().
! 	25Feb01 - J.W. Larson <larson@mcs.anl.gov> - Added the routine
!                 ProcessStorage_().
! 	18Apr01 - J.W. Larson <larson@mcs.anl.gov> - Added the routine
!                 peLocs().
! 	26Apr01 - R. Jacob <jacob@mcs.anl.gov> - Added the routine
!                 OrderedPoints_().
!       03Aug01 - E. Ong <eong@mcs.anl.gov> - In initd_, call initr_
!                 with actual shaped arguments on non-root processes to satisfy
!                 F90 standard. See comments in initd.
! 	18Oct01 - J.W. Larson <larson@mcs.anl.gov> - Added the routine
!                 bcast(), and also cleaned up prologues.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='m_GlobalSegMap'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initd_ - define the map from distributed data
!
! !DESCRIPTION:
! This routine takes the {\em scattered} input {\tt INTEGER} arrays
! {\tt start}, {\tt length}, and {\tt pe\_loc}, gathers these data to
! the {\tt root} process, and from them creates a {\em global} set of
! segment information for the output {\tt GlobalSegMap} argument
! {\tt GSMap}.  The input {\tt INTEGER} arguments {\tt comp\_id},
! {\tt gsize} provide the {\tt GlobalSegMap} component ID number and
! global grid size, respectively.  The input argument {\tt my\_comm} is
! the F90 {\tt INTEGER} handle for the MPI communicator.  If the input
! arrays are overdimensioned, optional argument {\em numel} can be
! used to specify how many elements should be used.
!
!
! !INTERFACE:

 subroutine initd_(GSMap, start, length, root, my_comm, &
                   comp_id, pe_loc, gsize, numel)

!
! !USES:
!
      use m_mpif90
      use m_die
      use m_stdio
      use m_FcComms, only : fc_gather_int, fc_gatherv_int

      implicit none

! !INPUT PARAMETERS:

      integer,dimension(:),intent(in) :: start          ! segment local start
                                                        ! indices
      integer,dimension(:),intent(in) :: length         ! segment local lengths
      integer,intent(in)              :: root           ! root on my_com
      integer,intent(in)              :: my_comm        ! local communicatior
      integer,intent(in)              :: comp_id        ! component model ID
      integer,dimension(:), pointer, optional :: pe_loc ! process location
      integer,intent(in), optional    :: gsize          ! global vector size
                                                        ! (optional).  It can
                                                        ! be computed by this
                                                        ! routine if no haloing
                                                        ! is assumed.
      integer,intent(in), optional    :: numel          ! specify number of elements
							! to use in start, length

! !OUTPUT PARAMETERS:

      type(GlobalSegMap),intent(out)  :: GSMap   ! Output GlobalSegMap

! !REVISION HISTORY:
! 	29Sep00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
! 	14Nov00 - J.W. Larson <larson@mcs.anl.gov> - final working version
! 	09Jan01 - J.W. Larson <larson@mcs.anl.gov> - repaired:  a subtle
!                 bug concerning the usage of the argument pe_loc (result
!                 was the new pointer variable my_pe_loc); a mistake in
!                 the tag arguments to MPI_IRECV; a bug in the declaration
!                 of the array status used by MPI_WAITALL.
! 	26Jan01 - J.W. Larson <larson@mcs.anl.gov> - replaced optional
!                 argument gsm_comm with required argument comp_id.
!       23Sep02 - Add optional argument numel to allow start, length
!                 arrays to be overdimensioned.
!       31Jan09 - P.H. Worley <worleyph@ornl.gov> - replaced irecv/send/waitall
!                 logic with calls to flow controlled gather routines
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initd_'
  integer :: nPEs, myID, ier, l, i
  integer :: ngseg  ! number of global segments
  integer :: nlseg  ! number of local segments
  integer :: nlseg_tmp(1) ! workaround for explicit interface expecting an array

        ! arrays allocated on the root to which data are gathered
  integer, dimension(:), allocatable :: root_start, root_length, root_pe_loc
        ! arrays allocated on the root to coordinate gathering of
        ! data and non-blocking receives by the root
  integer, dimension(:), allocatable :: counts, displs
        ! data and non-blocking receives by the root
  integer, dimension(:), pointer :: my_pe_loc

        ! Determine local process ID:

  call MP_COMM_RANK(my_comm, myID, ier)

  if(ier /= 0) call MP_perr_die(myname_,'MP_comm_rank()',ier)


        ! Check consistency of sizes of input arrays:

  if(size(length) /= size(start)) then
     ier = -1
     call die(myname_,'length/start array size mismatch',ier)
  endif

  if(present(pe_loc)) then
     if(size(pe_loc) /= size(start)) then
	ier = -1
	call die(myname_,'pe_loc/start array size mismatch',ier)
     endif
  endif

        ! Store in the variable nlseg the local size
        ! array start(:)

  if(present(numel)) then
    nlseg=numel
  else
    nlseg = size(start)
  endif

        ! If the argument pe_loc is not present, then we are
        ! initializing the GlobalSegMap on the communicator
        ! my_comm.  We will need pe_loc to be allocated and
        ! with local size given by the input value of nlseg,
        ! and then initialize it with the local process id myID.

  if(present(pe_loc)) then
     my_pe_loc => pe_loc
  else
     allocate(my_pe_loc(nlseg), stat=ier)
     if(ier /= 0) call die(myname_,'allocate(my_pe_loc)',ier)
     my_pe_loc = myID
  endif

  call MPI_COMM_SIZE(my_comm, npes, ier)
  if(ier /= 0) call MP_perr_die(myname_,'MPI_COMM_SIZE()',ier)

        ! Allocate an array of displacements (displs) and counts
        ! to hold the local values of nlseg on the root

  if(myID == root) then
     allocate(counts(0:npes-1), displs(0:npes-1), stat=ier)
     if (ier /= 0) then
	call die(myname_, 'allocate(counts,...',ier)
     endif
  else
     allocate(counts(1), displs(1), stat=ier)
     if (ier /= 0) then
	call die(myname_, 'allocate(counts,...',ier)
     endif
  endif

        ! Send local number of segments to the root.

  nlseg_tmp(1) = nlseg
  call fc_gather_int(nlseg_tmp, 1, MP_INTEGER, counts, 1, MP_INTEGER, &
                     root, my_comm)

        ! On the root compute the value of ngseg, along with
        ! the entries of counts and displs.

  if(myID == root) then
     ngseg = 0
     do i=0,npes-1
	ngseg = ngseg + counts(i)
        if(i == 0) then
	   displs(i) = 0
	else
	   displs(i) = displs(i-1) + counts(i-1)
	endif
     end do
  endif

        ! Now only the root has the correct value of ngseg.

        ! On the root, allocate memory for the arrays root_start,
        ! and root_length.  If the argument pe_loc is present,
        ! allocate root_pe_loc, too.

        ! Non-root processes call initr_ with root_start, root_length,
        ! and root_pe_loc, although these arguments are not used in the
        ! subroutine. Since these correspond to dummy shaped array arguments
        ! in initr_, the Fortran 90 standard dictates that the actual
        ! arguments must contain complete shape information. Therefore,
        ! these array arguments must be allocated on all processes.

  if(myID == root) then

     allocate(root_start(ngseg), root_length(ngseg), &
	      root_pe_loc(ngseg), stat=ier)
     if (ier /= 0) then
	call die(myname_, 'allocate(root_start...',ier)
     endif

  else

     allocate(root_start(1), root_length(1), &
	      root_pe_loc(1), stat=ier)
     if (ier /= 0) then
	call die(myname_, 'allocate((non)root_start...',ier)
     endif

  endif

        ! Now, each process sends its values of start(:) to fill in
        ! the appropriate portion of root_start(:y) on the root.

  call fc_gatherv_int(start, nlseg, MP_INTEGER, &
                      root_start, counts, displs, MP_INTEGER, &
                      root, my_comm)

        ! Next, each process sends its values of length(:) to fill in
        ! the appropriate portion of root_length(:) on the root.

  call fc_gatherv_int(length, nlseg, MP_INTEGER, &
                      root_length, counts, displs, MP_INTEGER, &
                      root, my_comm)

        ! Finally, if the argument pe_loc is present, each process sends
        ! its values of pe_loc(:) to fill in the appropriate portion of
        ! root_pe_loc(:) on the root.

  call fc_gatherv_int(my_pe_loc, nlseg, MP_INTEGER, &
                      root_pe_loc, counts, displs, MP_INTEGER, &
                      root, my_comm)

  call MPI_BARRIER(my_comm, ier)
  if(ier /= 0) call MP_perr_die(myname_,'MPI_BARRIER my_pe_loc',ier)

        ! Now, we have everything on the root needed to call initr_().

  if(present(gsize)) then
     call initr_(GSMap, ngseg, root_start, root_length, &
                 root_pe_loc, root, my_comm, comp_id, gsize)
  else
     call initr_(GSMap, ngseg, root_start, root_length, &
                 root_pe_loc, root, my_comm, comp_id)
  endif


        ! Clean up the array pe_loc(:) if it was allocated

  if(present(pe_loc)) then
     nullify(my_pe_loc)
  else
     deallocate(my_pe_loc, stat=ier)
     if(ier /= 0) call die(myname_, 'deallocate(my_pe_loc)', ier)
  endif

        ! Clean up the arrays root_start(:), et cetera...

  deallocate(root_start, root_length, root_pe_loc, stat=ier)
  if(ier /= 0) then
     call die(myname_, 'deallocate(root_start,...)', ier)
  endif

        ! Clean up the arrays counts(:) and displs(:)

   deallocate(counts, displs, stat=ier)
   if(ier /= 0) then
     call die(myname_, 'deallocate(counts,...)', ier)
   endif

 end subroutine initd_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initr_ initialize the map from the root
!
! !DESCRIPTION:
! This routine takes the input {\tt INTEGER} arrays {\tt start},
! {\tt length}, and {\tt pe\_loc} (all valid only on the {\tt root}
! process), and from them creates a {\em global} set of segment
! information for the output {\tt GlobalSegMap} argument
! {\tt GSMap}.  The input {\tt INTEGER} arguments {\tt ngseg},
! {\tt comp\_id}, {\tt gsize} (again, valid only on the {\tt root}
! process) provide the {\tt GlobalSegMap} global segment count, component
! ID number, and global grid size, respectively.  The input argument
! {\tt my\_comm} is the F90 {\tt INTEGER} handle for the MPI communicator.
!
! !INTERFACE:

 subroutine initr_(GSMap, ngseg, start, length, pe_loc, root,  &
                   my_comm, comp_id, gsize)
!
! !USES:
!
      use m_mpif90
      use m_die
      use m_stdio

      implicit none

! !INPUT PARAMETERS:

      integer, intent(in)             :: ngseg   ! no. of global segments
      integer,dimension(:),intent(in) :: start   ! segment local start index
      integer,dimension(:),intent(in) :: length  ! the distributed sizes
      integer,dimension(:),intent(in) :: pe_loc  ! process location
      integer,intent(in)              :: root    ! root on my_com
      integer,intent(in)              :: my_comm ! local communicatior
      integer,intent(in)              :: comp_id ! component id number
      integer,intent(in), optional    :: gsize   ! global vector size
                                                 ! (optional).  It can
                                                 ! be computed by this
                                                 ! routine if no haloing
                                                 ! is assumed.

! !OUTPUT PARAMETERS:

      type(GlobalSegMap),intent(out)  :: GSMap   ! Output GlobalSegMap

! !REVISION HISTORY:
! 	29Sep00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
! 	09Nov00 - J.W. Larson <larson@mcs.anl.gov> - final working version
! 	10Jan01 - J.W. Larson <larson@mcs.anl.gov> - minor bug fix
! 	12Jan01 - J.W. Larson <larson@mcs.anl.gov> - minor bug fix regarding
!                                                    disparities in ngseg on
!                                                    the root and other
!                                                    processes
! 	26Jan01 - J.W. Larson <larson@mcs.anl.gov> - replaced optional
!                 argument gsm_comm with required argument comp_id.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initr_'
  integer :: myID,ier,l,i

        ! Determine the local process ID myID:

  call MPI_COMM_RANK(my_comm, myID, ier)
  if(ier/=0) call MP_perr_die(myname_,'MPI_COMM_RANK()',ier)

        ! Argument checking:  check to make sure the arrays
        ! start, length, and pe_loc each have ngseg elements.
        ! If not, stop with an error.  This is done on the
        ! root process since it owns the initialization data.

  if(myID == root) then
    if( size(start(:)) /= ngseg ) then
      write(stderr,'(2a,2(a,i4))') myname_,	&
	': _root_ argument error',		&
	', size(start) =',size(start),	&
	', ngseg =',ngseg
      call die(myname_)
    endif
    if( size(length(:)) /= ngseg ) then
      write(stderr,'(2a,2(a,i4))') myname_,	&
	': _root_ argument error',		&
	', size(length) =',size(length),	&
	', ngseg =',ngseg
      call die(myname_)
    endif
    if( size(pe_loc(:)) /= ngseg ) then
      write(stderr,'(2a,2(a,i4))') myname_,	&
	': _root_ argument error',		&
	', size(pe_loc) =',size(pe_loc),	&
	', ngseg =',ngseg
      call die(myname_)
    endif
  endif

        ! Initialize GSMap%ngseg and GSMap%comp_id on the root:

  if(myID == root) then
     GSMap%ngseg = ngseg
     GSMap%comp_id = comp_id
  endif

        ! Broadcast the value of GSMap%ngseg

  call MPI_BCAST(GSMap%ngseg, 1, MP_INTEGER, root, my_comm, ier)
  if(ier/=0) call MP_perr_die(myname_,'MPI_BCAST(GSmap%ngseg)',ier)

        ! Broadcast the value of GSMap%comp_id

  call MPI_BCAST(GSMap%comp_id, 1, MP_INTEGER, root, my_comm, ier)
  if(ier/=0) call MP_perr_die(myname_,'MPI_BCAST(GSmap%comp_id)',ier)

        ! Allocate the components GSMap%start(:), GSMap%length(:),
        ! and GSMap%pe_loc(:)

  allocate(GSMap%start(GSMap%ngseg), GSMap%length(GSMap%ngseg), &
           GSMap%pe_loc(GSMap%ngseg), stat = ier)
  if(ier/=0) call die(myname_,'allocate(GSmap%start(:),...',ier)

#ifdef MALL_ON
	call mall_ci(size(transfer(GSMap%start,(/1/))),myname_)
	call mall_ci(size(transfer(GSMap%length,(/1/))),myname_)
	call mall_ci(size(transfer(GSMap%pe_loc,(/1/))),myname_)
#endif

        ! On the root process, initialize GSMap%start(:), GSMap%length(:),
        ! and GSMap%pe_loc(:) with the data contained in start(:),
        ! length(:) and pe_loc(:), respectively

  if(myID == root) then
     GSMap%start(1:GSMap%ngseg) = start(1:GSMap%ngseg)
     GSMap%length(1:GSMap%ngseg) = length(1:GSMap%ngseg)
     GSMap%pe_loc(1:GSMap%ngseg) = pe_loc(1:GSMap%ngseg)
  endif

        ! Broadcast the root values of GSMap%start(:), GSMap%length(:),
        ! and GSMap%pe_loc(:)

  call MPI_BCAST(GSMap%start, GSMap%ngseg, MP_INTEGER, root, my_comm, ier)
  if(ier/=0) call MP_perr_die(myname_,'MPI_BCAST(GSMap%start)',ier)

  call MPI_BCAST(GSMap%length, GSMap%ngseg, MP_INTEGER, root, my_comm, ier)
  if(ier/=0) call MP_perr_die(myname_,'MPI_BCAST(GSMap%length)',ier)

  call MPI_BCAST(GSMap%pe_loc, GSMap%ngseg, MP_INTEGER, root, my_comm, ier)
  if(ier/=0) call MP_perr_die(myname_,'MPI_BCAST(GSMap%pe_loc)',ier)

        ! If the argument gsize is present, use the root value to
        ! set GSMap%gsize and broadcast it.  If it is not present,
        ! this will be computed by summing the entries of GSM%length(:).
        ! Again, note that if one is storing halo points, the sum will
        ! produce a result larger than the actual global vector.  If
        ! halo points are to be used in the mapping we advise strongly
        ! that the user specify the value gsize as an argument.

  if(present(gsize)) then
     if(myID == root) then
	GSMap%gsize = gsize
     endif
     call MPI_BCAST(GSMap%gsize, 1, MP_INTEGER, root, my_comm, ier)
     if(ier/=0) call MP_perr_die(myname_, 'MPI_BCAST(GSMap%gsize)', ier)
  else
     GSMap%gsize = 0
     do i=1,GSMap%ngseg
	GSMap%gsize = GSMap%gsize + GSMap%length(i)
     end do
  endif

 end subroutine initr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initp_ - define the map from replicated data.
!
! !DESCRIPTION:
!
! The routine {\tt initp\_()} takes the input {\em replicated} arguments
! {\tt comp\_id}, {\tt ngseg}, {\tt gsize}, {\tt start(:)},
! {\tt length(:)}, and {\tt pe\_loc(:)}, and uses them to initialize an
! output {\tt GlobalSegMap} {\tt GSMap}.  This routine operates on the
! assumption that these data are replicated across the communicator on
! which the {\tt GlobalSegMap} is being created.
!
! !INTERFACE:

 subroutine initp_(GSMap, comp_id, ngseg, gsize, start, length, pe_loc)

!
! !USES:
!
      use m_mpif90
      use m_die, only : die
      use m_stdio

      implicit none

! !INPUT PARAMETERS:

      integer,intent(in)              :: comp_id ! component model ID
      integer,intent(in)              :: ngseg   ! global number of segments
      integer,intent(in)              :: gsize   ! global vector size
      integer,dimension(:),intent(in) :: start   ! segment local start index
      integer,dimension(:),intent(in) :: length  ! the distributed sizes
      integer,dimension(:),intent(in) :: pe_loc  ! process location

! !OUTPUT PARAMETERS:

      type(GlobalSegMap),intent(out)  :: GSMap   ! Output GlobalSegMap

! !REVISION HISTORY:
! 	24Feb01 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initp_'
  integer :: ierr, n

       ! Argument Checks -- Is comp_id positive?

  if(comp_id <= 0) then
     call die(myname_,'non-positive value of comp_id',comp_id)
  endif

       ! Is gsize positive?

  if(gsize <= 0) then
     call die(myname_,'non-positive value of gsize',gsize)
  endif


       ! Is ngseg positive?

  if(ngseg <= 0) then
     call die(myname_,'non-positive value of ngseg',ngseg)
  endif

       ! Are the arrays start(:), length(:), and pe_loc(:) the
       !correct size?

  if(size(start) /= ngseg) then
     call die(myname_,'start(:)/ngseg size mismatch',ngseg)
  endif
  if (size(length) /= ngseg) then
     call die(myname_,'length(:)/ngseg size mismatch',ngseg)
  endif
  if (size(pe_loc) /= ngseg) then
     call die(myname_,'pe_loc(:)/ngseg size mismatch',ngseg)
  endif

       ! Allocate index and location arrays for GSMap:

  allocate(GSMap%start(ngseg), GSMap%length(ngseg), GSMap%pe_loc(ngseg), &
           stat = ierr)
  if (ierr /= 0) then
     call die(myname_,'allocate(GSMap%start...',ngseg)
  endif

       ! Assign the components of GSMap:

  GSMap%comp_id = comp_id
  GSMap%ngseg = ngseg
  GSMap%gsize = gsize

  do n=1,ngseg
     GSMap%start(n) = start(n)
     GSMap%length(n) = length(n)
     GSMap%pe_loc(n) = pe_loc(n)
  end do

  end subroutine initp_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initp1_ - define the map from replicated data using 1 array.
!
! !DESCRIPTION:
!
! The routine {\tt initp1\_()} takes the input {\em replicated} arguments
! {\tt comp\_id}, {\tt ngseg}, {\tt gsize}, and {\tt all\_arrays(:)},
! and uses them to initialize an output {\tt GlobalSegMap} {\tt GSMap}.
! This routine operates on the assumption that these data are replicated
! across the communicator on which the {\tt GlobalSegMap} is being created.
! The input array {\tt all\_arrays(:)} should be of length {\tt 2 * ngseg},
! and is packed so that
! $$ {\tt all\_arrays(1:ngseg)} = {\tt GSMap\%start(1:ngseg)} $$
! $$ {\tt all\_arrays(ngseg+1:2*ngseg)} = {\tt GSMap\%length(1:ngseg)} $$
! $$ {\tt all\_arrays(2*ngseg+1:3*ngseg)} = {\tt GSMap\%pe\_loc(1:ngseg)} .$$
!
! !INTERFACE:

 subroutine initp1_(GSMap, comp_id, ngseg, gsize, all_arrays)

!
! !USES:
!
      use m_mpif90
      use m_die, only : die
      use m_stdio

      implicit none

! !INPUT PARAMETERS:

      integer,intent(in)              :: comp_id    ! component model ID
      integer,intent(in)              :: ngseg      ! global no. of segments
      integer,intent(in)              :: gsize      ! global vector size
      integer,dimension(:),intent(in) :: all_arrays ! packed array of length
                                                    ! 3*ngseg containing (in
                                                    ! this order):  start(:),
                                                    ! length(:), and pe_loc(:)

! !OUTPUT PARAMETERS:

      type(GlobalSegMap),intent(out)  :: GSMap      ! Output GlobalSegMap

! !REVISION HISTORY:
! 	24Feb01 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initp1_'
  integer :: ierr, n

       ! Argument Checks -- Is comp_id positive?

  if(comp_id <= 0) then
     call die(myname_,'non-positive value of comp_id',comp_id)
  endif

       ! Is gsize positive?

  if(gsize <= 0) then
     call die(myname_,'non-positive value of gsize',gsize)
  endif


       ! Is ngseg positive?

  if(ngseg <= 0) then
     call die(myname_,'non-positive value of ngseg',ngseg)
  endif

       ! Is the array all_arrays(:) the right length?

  if(size(all_arrays) /= 3*ngseg) then
     call die(myname_,'all_arrays(:)/3*ngseg size mismatch',ngseg)
  endif

       ! Allocate index and location arrays for GSMap:

  allocate(GSMap%start(ngseg), GSMap%length(ngseg), GSMap%pe_loc(ngseg), &
           stat = ierr)
  if (ierr /= 0) then
     call die(myname_,'allocate(GSMap%start...',ngseg)
  endif

       ! Assign the components of GSMap:

  GSMap%comp_id = comp_id
  GSMap%ngseg = ngseg
  GSMap%gsize = gsize

  do n=1,ngseg
     GSMap%start(n) = all_arrays(n)
     GSMap%length(n) = all_arrays(ngseg + n)
     GSMap%pe_loc(n) = all_arrays(2*ngseg + n)
  end do

  end subroutine initp1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initp0_ - Null Constructor Using Replicated Data
!
! !DESCRIPTION:
!
! The routine {\tt initp0\_()} takes the input {\em replicated} arguments
! {\tt comp\_id}, {\tt ngseg}, {\tt gsize}, and uses them perform null
! construction of the output {\tt GlobalSegMap} {\tt GSMap}.  This is a
! null constructor in the sense that we are not filling in the segment
! information arrays.  This routine operates on the assumption that these
! data are replicated across the communicator on which the
! {\tt GlobalSegMap} is being created.
!
! !INTERFACE:

 subroutine initp0_(GSMap, comp_id, ngseg, gsize)

!
! !USES:
!
      use m_die, only : die
      use m_stdio

      implicit none

! !INPUT PARAMETERS:

      integer,intent(in)              :: comp_id ! component model ID
      integer,intent(in)              :: ngseg   ! global number of segments
      integer,intent(in)              :: gsize   ! global vector size

! !OUTPUT PARAMETERS:

      type(GlobalSegMap),intent(out)  :: GSMap   ! Output GlobalSegMap

! !REVISION HISTORY:
! 13Aug03 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initp0_'

  integer :: ierr

  nullify(GSMap%start)
  nullify(GSMap%length)
  nullify(GSMap%pe_loc)

  GSMap%comp_id = comp_id
  GSMap%ngseg = ngseg
  GSMap%gsize = gsize

  allocate(GSMap%start(ngseg), GSMap%length(ngseg), GSMap%pe_loc(ngseg), &
           stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(3a,i8)') myname_, &
	  ':: FATAL--allocate of segment information storage space failed.', &
	  '  ierr = ',ierr
     call die(myname_)
  endif

 end subroutine initp0_



!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: init_index_ - initialize GSM from local index arrays
!
! !DESCRIPTION:
!
! The routine {\tt init\_index\_()} takes a local array of indices
! {\tt lindx} and uses them to create a {\tt GlobalSegMap}.
! {\tt lindx} is parsed to determine the lengths of the runs, and
! then a call is made to {\tt initd\_}.  The optional argument
! {\tt lsize} can be used if only the first {\tt lsize} number
! of elements of {\tt lindx} are valid.  The optional argument
! {\tt gsize} is used to specify the global number of unique points
! if this can not be determined from the collective {\tt lindx}.
!
!
! !INTERFACE:

    subroutine init_index_(GSMap, lindx, my_comm, comp_id, lsize, gsize)

!
! !USES:
!

!  use m_GlobalSegMap,only: GlobalSegMap
!  use m_GlobalSegMap,only: MCT_GSMap_init => init

!  use shr_sys_mod

  use m_die
  implicit none

! !INPUT PARAMETERS:

     integer , dimension(:),intent(in) :: lindx   ! index buffer
     integer , intent(in) :: my_comm         ! mpi communicator group (mine)
     integer , intent(in) :: comp_id         ! component id (mine)

     integer , intent(in),optional :: lsize  ! size of index buffer
     integer , intent(in),optional :: gsize  ! global vector size

! !OUTPUT PARAMETERS:

     type(GlobalSegMap),intent(out) :: GSMap ! Output GlobalSegMap


! !REVISION HISTORY:
!       30Jul02 - T. Craig - initial version in cpl6.
!       17Nov05 - R. Loy <rloy@mcs.anl.gov> - install into MCT
!       18Nov05 - R. Loy <rloy@mcs.anl.gov> - make lsize optional
!       25Jul06 - R. Loy <rloy@mcs.anl.gov> - error check on lindex/alloc/dealloc
!EOP ___________________________________________________________________


     !--- local ---

     character(len=*),parameter :: myname_=myname//'::init_index_'

     integer             :: i,j,k,n      ! generic indicies
     integer             :: nseg         ! counts number of segments for GSMap
     integer,allocatable :: start(:)     ! used to init GSMap
     integer,allocatable :: count(:)     ! used to init GSMap
     integer,parameter   :: pid0=0       ! mpi process id for root pe
     integer,parameter   :: debug=0      !

     integer rank,ierr
     integer mysize


     if (present(lsize)) then
       mysize=lsize
     else
       mysize=size(lindx)
     endif

     if (mysize<0) call die(myname_, &
        'lindx size is negative (you may have run out of points)')

!!
!! Special case if this processor doesn't have any data indices
!!
   if (mysize==0) then
     allocate(start(0),count(0),stat=ierr)
     if(ierr/=0) call die(myname_,'allocate(start,count)',ierr)

     nseg=0
   else

     call MPI_COMM_RANK(my_comm,rank, ierr)

     ! compute segment's start indicies and length counts

     ! first pass - count how many runs of consecutive numbers

     nseg=1
     do n = 2,mysize
        i = lindx(n-1)
        j = lindx(n)
        if ( j-i /= 1) nseg=nseg+1
     end do

     allocate(start(nseg),count(nseg),stat=ierr)
     if(ierr/=0) call die(myname_,'allocate(start,count)',ierr)

     ! second pass - determine how long each run is

     nseg = 1
     start(nseg) = lindx(1)
     count(nseg) = 1
     do n = 2,mysize
        i = lindx(n-1)
        j = lindx(n)
        if ( j-i /= 1) then
            nseg = nseg+1
            start(nseg) = lindx(n)
            count(nseg) = 1
         else
            count(nseg) = count(nseg)+1
         end if
     end do

   endif ! if mysize==0


     if (debug.ne.0) then
	write(6,*) rank,'init_index: SIZE ',nseg

	do n=1,nseg
          write(6,*) rank,'init_index: START,COUNT ',start(n),count(n)
	end do
     endif


      if (present(gsize)) then
        call initd_( GSMap, start, count, pid0, my_comm,  &
                     comp_id, gsize=gsize)
      else
        call initd_( GSMap, start, count, pid0, my_comm,  &
  	             comp_id)
      endif


      deallocate(start, count, stat=ierr)
      if(ierr/=0) call warn(myname_,'deallocate(start,count)',ierr)


   end subroutine init_index_



!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: clean_ - clean the map
!
! !DESCRIPTION:
! This routine deallocates the array components of the {\tt GlobalSegMap}
! argument {\tt GSMap}: {\tt GSMap\%start}, {\tt GSMap\%length}, and
! {\tt GSMap\%pe\_loc}.  It also zeroes out the values of the integer
! components {\tt GSMap\%ngseg}, {\tt GSMap\%comp\_id}, and
! {\tt GSMap\%gsize}.
!
! !INTERFACE:

    subroutine clean_(GSMap,stat)
!
! !USES:
!
      use m_die

      implicit none

! !INPUT/OUTPUT PARAMETERS:

      type(GlobalSegMap), intent(inout) :: GSMap
      integer, optional,  intent(out)   :: stat

! !REVISION HISTORY:
! 	29Sep00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
!       01Mar02 - E.T. Ong <eong@mcs.anl.gov> - added stat argument.
!                 Removed dies to prevent crashing.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::clean_'
  integer :: ier

#ifdef MALL_ON

  if( (associated(GSMap%start) .and. associated(GSMap%length)) &
       .and. associated(GSMap%pe_loc) )
     call mall_co(size(transfer(GSMap%start,(/1/))),myname_)
     call mall_co(size(transfer(GSMap%length,(/1/))),myname_)
     call mall_co(size(transfer(GSMap%pe_loc,(/1/))),myname_)
  endif

#endif

  deallocate(GSMap%start, GSMap%length, GSMap%pe_loc, stat=ier)

  if(present(stat)) then
     stat=ier
  else
     if(ier /= 0) call warn(myname_,'deallocate(GSMap%start,...)',ier)
  endif

  GSMap%ngseg = 0
  GSMap%comp_id  = 0
  GSMap%gsize = 0

 end subroutine clean_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ngseg_ - Return the global number of segments from the map
!
! !DESCRIPTION:
! The function {\tt ngseg\_()} returns the global number of vector
! segments in the {\tt GlobalSegMap} argument {\tt GSMap}.  This is
! merely the value of {\tt GSMap\%ngseg}.
!
! !INTERFACE:

 integer function ngseg_(GSMap)

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),intent(in) :: GSMap

! !REVISION HISTORY:
! 	29Sep00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ngseg_'

  ngseg_=GSMap%ngseg

 end function ngseg_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: nlseg_ - Return the local number of segments from the map
!
! !DESCRIPTION:
! The function {\tt nlseg\_()} returns the number of vector segments
! in the {\tt GlobalSegMap} argument {\tt GSMap} that reside on the
! process specified by the input argument {\tt pID}.  This is the
! number of entries {\tt GSMap\%pe\_loc} whose value equals {\tt pID}.
!
! !INTERFACE:

 integer function nlseg_(GSMap, pID)

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),intent(in) :: GSMap
      integer,           intent(in) :: pID

! !REVISION HISTORY:
! 	29Sep00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
! 	14Jun01 - J.W. Larson <larson@mcs.anl.gov> - Bug fix in lower
!                 limit of loop over elements of GSMap%pe_loc(:).  The
!                 original code had this lower limit set to 0, which
!                 was out-of-bounds (but uncaught).  The correct lower
!                 index is 1.  This bug was discovered by Everest Ong.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::nlseg_'
  integer :: i, nlocseg

        ! Initialize the number of segments residing on pID, nlocseg

  nlocseg = 0

        ! Compute the number of segments residing on pID, nlocseg

  do i=1,GSMap%ngseg
     if(GSMap%pe_loc(i) == pID) then
	nlocseg = nlocseg + 1
     endif
  end do

        ! Return the total

  nlseg_ = nlocseg

 end function nlseg_



!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: max_nlseg_ - Return the max number of segments over all procs
!
! !DESCRIPTION:
! The function {\tt max\_nlseg\_()} returns the maximum number
! over all processors of the vector
! segments in the {\tt GlobalSegMap} argument {\tt gsap}
! E.g. max\_p(nlseg(gsmap,p)) but computed more efficiently
!
! !INTERFACE:

        integer function max_nlseg_(gsmap)

! !USES:

        use m_MCTWorld,      only :ThisMCTWorld
        use m_mpif90
        use m_die

        use m_stdio    ! rml

        implicit none

! !INPUT PARAMETERS:

        type(GlobalSegMap), intent(in) :: gsmap


! !REVISION HISTORY:
! 	17Jan07 - R. Loy <rloy@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________



! Local variables

        character(len=*),parameter :: myname_=myname//'::max_local_segs'

        integer i
        integer this_comp_id
        integer nprocs

        integer, allocatable::  segcount(:)  ! segments on proc i
        integer ier

        integer this_ngseg
        integer segment_pe
        integer max_segcount


! Start of routine

        this_comp_id = comp_id(gsmap)
        nprocs=ThisMCTWorld%nprocspid(this_comp_id)

        allocate( segcount(nprocs), stat=ier )
        if (ier/=0) call die(myname_,'allocate segcount')

        segcount=0

        this_ngseg=ngseg(gsmap)

        do i=1,this_ngseg

          segment_pe = gsmap%pe_loc(i) + 1     ! want value 1..nprocs

          if (segment_pe < 1 .OR. segment_pe > nprocs) then
            call die(myname_,'bad segment location',segment_pe)
          endif

          segcount(segment_pe) = segcount(segment_pe) + 1
        enddo

        max_segcount=0
        do i=1,nprocs
          max_segcount= max( max_segcount, segcount(i) )
        enddo

        deallocate(segcount, stat=ier)
        if (ier/=0) call die(myname_,'deallocate segcount')


        max_nlseg_=max_segcount

        end function max_nlseg_


!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: comp_id_ - Return the commponent ID from the GlobalSegMap.
!
! !DESCRIPTION:
! The function {\tt comp\_id\_()} returns component ID number stored in
! {\tt GSMap\%comp\_id}.
!
! !INTERFACE:

 integer function comp_id_(GSMap)

! !USES:

      use m_die,only: die
      use m_stdio, only :stderr

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),intent(in) :: GSMap

! !REVISION HISTORY:
! 	29Sep00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
! 	26Jan01 - J.W. Larson <larson@mcs.anl.gov> - renamed comp_id_
!                 to fit within MCT_World component ID context.
!       01May01 - R.L. Jacob  <jacob@mcs.anl.gov> - make sure GSMap
!                 is defined.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::comp_id_'

  if(.not.associated(GSMap%start) ) then
    write(stderr,'(2a)') myname_, &
    ' MCTERROR:  GSMap argument not initialized...exiting'
    call die(myname_)
  endif

  comp_id_ = GSMap%comp_id

 end function comp_id_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: gsize_ - Return the global vector size from the GlobalSegMap.
!
! !DESCRIPTION:
! The function {\tt gsize\_()} takes the input {\tt GlobalSegMap}
! arguement {\tt GSMap} and returns the global vector length stored
! in {\tt GlobalSegMap\%gsize}.
!
! !INTERFACE:

 integer function gsize_(GSMap)

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),intent(in) :: GSMap

! !REVISION HISTORY:
! 	29Sep00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::gsize_'

  gsize_=GSMap%gsize

 end function gsize_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GlobalStorage_ - Return global storage space required.
!
! !DESCRIPTION:
! The function {\tt GlobalStorage\_()} takes the input {\tt GlobalSegMap}
! arguement {\tt GSMap} and returns the global storage space required
! ({\em i.e.}, the vector length) to hold all the data specified by
! {\tt GSMap}.
!
! {\bf N.B.:  } If {\tt GSMap} contains halo or masked points, the value
! by {\tt GlobalStorage\_()} may differ from {\tt GSMap\%gsize}.
!
! !INTERFACE:

 integer function GlobalStorage_(GSMap)

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),intent(in) :: GSMap

! !REVISION HISTORY:
! 	06Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GlobalStorage_'

  integer :: global_storage, ngseg, n

      ! Return global number of segments:

  ngseg = ngseg_(GSMap)

      ! Initialize global_storage (the total number of points in the
      ! GlobalSegMap:

  global_storage = 0

      ! Add up the number of points present in the GlobalSegMap:

  do n=1,ngseg
     global_storage = global_storage + GSMap%length(n)
  end do

  GlobalStorage_ = global_storage

 end function GlobalStorage_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ProcessStorage_ - Number of points on a given process.
!
! !DESCRIPTION:
! The function {\tt ProcessStorage\_()} takes the input {\tt GlobalSegMap}
! arguement {\tt GSMap} and returns the storage space required by process
! {\tt PEno} ({\em i.e.}, the vector length) to hold all the data specified
! by {\tt GSMap}.
!
! !INTERFACE:

 integer function ProcessStorage_(GSMap, PEno)

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),intent(in) :: GSMap
      integer,           intent(in) :: PEno

! !REVISION HISTORY:
! 	06Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ProcessStorage_'

  integer :: pe_storage, ngseg, n

      ! Return global number of segments:

  ngseg = ngseg_(GSMap)

      ! Initialize pe_storage (the total number of points on process
      ! PEno in the GlobalSegMap):

  pe_storage = 0

      ! Add up the number of points on process PEno in the GlobalSegMap:

  do n=1,ngseg
     if(GSMap%pe_loc(n) == PEno) then
	pe_storage = pe_storage + GSMap%length(n)
     endif
  end do

  ProcessStorage_ = pe_storage

 end function ProcessStorage_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: OrderedPoints_ - The grid points on a given process
!				returned in the assumed MCT order.
!
! !DESCRIPTION:
! The function {\tt OrderedPoints\_()} takes the input {\tt GlobalSegMap}
! arguement {\tt GSMap} and returns a vector of the points owned by
! {\tt PEno}.  {\tt Points} is allocated here.  The calling process
! is responsible for deallocating the space.
!
! !INTERFACE:

    subroutine OrderedPoints_(GSMap, PEno, Points)

!
! !USES:
!
      use m_die,only: die

      implicit none

 ! !INPUT PARAMETERS:

      type(GlobalSegMap), intent(in) :: GSMap   ! input GlobalSegMap
      integer,            intent(in) :: PEno	! input process number
      integer,dimension(:),pointer   :: Points  ! the vector of points

! !REVISION HISTORY:
! 	25Apr01 - R. Jacob <jacob@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::OrderedPoints_'
  integer :: nlsegs,mysize,ier,i,j,k
  integer,dimension(:),allocatable :: mystarts,mylengths

  nlsegs = nlseg(GSMap,PEno)
  mysize=ProcessStorage(GSMap,PEno)

  allocate(mystarts(nlsegs),mylengths(nlsegs), &
      Points(mysize),stat=ier)
  if(ier/=0) call die(myname_,'allocate(mystarts,..)',ier)

! pull out the starts and lengths that PEno owns in the order
! they appear in the GSMap.
  j=1
  do i=1,GSMap%ngseg
    if(GSMap%pe_loc(i)==PEno) then
      mystarts(j)=GSMap%start(i)
      mylengths(j)=GSMap%length(i)
      j=j+1
    endif
  enddo

! now recalculate the values of the grid point numbers
! based on the starts and lengths
! form one long vector which is all local GSMap points
  i=1
  do j=1,nlsegs
    do k=1,mylengths(j)
     Points(i)=mystarts(j)+k-1
     i=i+1
    enddo
  enddo

  deallocate(mystarts,mylengths, stat=ier)
  if(ier/=0) call die(myname_,'deallocate(mystarts,..)',ier)

 end subroutine OrderedPoints_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: lsize_ - find the local storage size from the map
!
! !DESCRIPTION:
! This function returns the number of points owned by the local process,
! as defined by the input {\tt GlobalSegMap} argument {\tt GSMap}.  The
! local process ID is determined through use of the input {\tt INTEGER}
! argument {\tt comm}, which is the Fortran handle for the MPI
! communicator.
!
! !INTERFACE:

 integer function lsize_(GSMap, comm)
!
! !USES:
!
      use m_mpif90
      use m_die ,          only : MP_perr_die

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap), intent(in) :: GSMap
      integer,            intent(in) :: comm


! !REVISION HISTORY:
! 	29Sep00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
! 	06Feb01 - J.W. Larson <larson@mcs.anl.gov> - Computed directly
!                 from the GlobalSegMap, rather than returning a hard-
!                 wired local attribute. This required the addition of
!                 the communicator argument.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::lsize_'
  integer :: ierr, local_size, myID, n, ngseg

        ! Determine local rank myID:

  call MP_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) call MP_perr_die(myname_,'MP_COMM_RANK',ierr)

        ! Determine global number of segments:

  ngseg = ngseg_(GSMap)

        ! Compute the local size of the distributed vector by summing
        ! the entries of GSMap%length(:) whose corresponding values in
        ! GSMap%pe_loc(:) equal the local process ID.  This automatically
        ! takes into account haloing (if present).

  local_size = 0

  do n=1,ngseg
     if(GSMap%pe_loc(n) == myID) then
	local_size = local_size + GSMap%length(n)
     endif
  end do

  lsize_ = local_size

 end function lsize_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: rank1_ - rank which process owns a datum with given global
! index.
!
! !DESCRIPTION:
! This routine assumes that there is one process that owns the datum with
! a given global index.  It should not be used when the input
! {\tt GlobalSegMap} argument {\tt GSMap} has been built to incorporate
! halo points.
!
! !INTERFACE:

    subroutine rank1_(GSMap, i_g, rank)

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap), intent(in)  :: GSMap   ! input GlobalSegMap
      integer,            intent(in)  :: i_g	 ! a global index

! !OUTPUT PARAMETERS:

      integer,            intent(out) :: rank    ! the pe on which this
                                                 ! element resides
! !REVISION HISTORY:
! 	29Sep00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::rank1_'
  integer :: i,ilc,ile

        ! Initially, set the rank to -1 (invalid).
  rank=-1

  do i=1,size(GSMap%start)
    ilc = GSMap%start(i)
    ile = ilc + GSMap%length(i) - 1

		! If i_g in [ilc,ile].  Note that i_g := [1:..]

    if(ilc <= i_g .and. i_g <= ile) then
      rank = GSMap%pe_loc(i)
      return
    endif
  end do

 end subroutine rank1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: rankm_ - rank which processes own a datum with given global
! index.
!
! !DESCRIPTION:
! This routine assumes that there may be more than one process that owns
! the datum with a given global index.  This routine should  be used when
! the input {\tt GlobalSegMap} argument {\tt GSMap} has been built to
! incorporate ! halo points.  {\em Nota Bene}:  The output array {\tt rank}
! is allocated in this routine and must be deallocated by the routine calling
! {\tt rankm\_()}.  Failure to do so could result in a memory leak.
!
! !INTERFACE:

    subroutine rankm_(GSMap, i_g, num_loc, rank)

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap), intent(in)  :: GSMap   ! input GlobalSegMap
      integer,            intent(in)  :: i_g	 ! a global index

! !OUTPUT PARAMETERS:

      integer,            intent(out) :: num_loc ! the number of processes
                                                 ! which own element i_g
      integer, dimension(:), pointer  :: rank    ! the process(es) on which
                                                 ! element i_g resides
! !REVISION HISTORY:
! 	29Sep00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::rankm_'
  integer :: i, ilc, ile, ier, n

        ! First sweep:  determine the number of processes num_loc
        ! that own the given datum:

  num_loc = 0

  do i=1,size(GSMap%start)

    ilc = GSMap%start(i)
    ile = ilc + GSMap%length(i) - 1

		! If i_g in [ilc,ile].  Note that i_g := [1:..]

    if(ilc <= i_g .and. i_g <= ile) then
      num_loc = num_loc + 1
    endif

  end do

  if(num_loc == 0) then

        ! If i_g is nowhere to be found in GSMap, set num_loc to
        ! unity and return a null value for rank

     num_loc = 1
     allocate(rank(num_loc), stat=ier)
     rank = -1	! null value
     return

  else
        ! Allocate output array rank(1:num_loc)

     allocate(rank(num_loc), stat=ier)

        ! Second sweep:  fill in the entries to rank(:)

     n = 0 ! counter

     do i=1,size(GSMap%start)

	ilc = GSMap%start(i)
	ile = ilc + GSMap%length(i) - 1

	! If i_g in [ilc,ile].  Note that i_g := [1:..]

	if(ilc <= i_g .and. i_g <= ile) then
	   n = n + 1
	   rank(n) = GSMap%pe_loc(i)
	endif

     end do

  endif

 end subroutine rankm_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: active_pes_ - number of processes that own data.
! index.
!
! !DESCRIPTION:
! This routine scans the pe location list of the input {\tt GlobalSegMap}
! {\tt GSMap\%pe\_loc(:)}, and counts the number of pe locations that
! own at least one datum.  This value is returned in the {\tt INTEGER}
! argument {\tt n\_active}.  If the optional {\tt INTEGER} array argument
! {\tt list} is included in the call, a sorted list (in ascending order) of
! the active processes will be returned.
!
! {\bf N.B.:} If {\tt active\_pes\_()} is invoked with the optional argument
! {\tt pe\_list} included, this routine will allocate and return this array.
! The user must deallocate this array once it is no longer needed.  Failure
! to do so will result in a memory leak.
!
! !INTERFACE:

    subroutine active_pes_(GSMap, n_active, pe_list)
!
! !USES:
!
      use m_die ,          only : die

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),    intent(in)        :: GSMap

! !OUTPUT PARAMETERS:

      integer,               intent(out)       :: n_active
      integer, dimension(:), pointer, optional :: pe_list

! !REVISION HISTORY:
! 	03Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::active_pes_'

  integer :: count, i, n, ngseg, ierr
  integer :: max_activepe, p
  logical, dimension(:), allocatable :: process_list

        ! retrieve total number of segments in the map:

  ngseg = ngseg_(GSMap)

        ! retrieve maximum active process id in the map:

  max_activepe = maxval(GSMap%pe_loc(:))

        ! allocate workspace to tally process id list:

  allocate(process_list(0:max_activepe), stat=ierr)
  if(ierr /= 0) call die(myname_,'allocate(process_list)',ierr)

        ! initialize process_list to false (i.e. no active pes)

  process_list = .false.

        ! initialize the distinct active process count:

  count = 0

        ! scan entries of GSMap%pe_loc to count active processes:

  do n=1,ngseg
     if(GSMap%pe_loc(n) >= 0) then ! a legitimate pe_location

        if (.not. process_list(GSMap%pe_loc(n))) then
           process_list(GSMap%pe_loc(n)) = .true.
           count = count + 1
        endif

     else  ! a negative entry in GSMap%pe_loc(n)
	ierr = 2
	call die(myname_,'negative value of GSMap%pe_loc',ierr)
     endif
  end do

        ! If the argument pe_list is present, we must allocate this
        ! array and fill it

  if(present(pe_list)) then

        ! allocate pe_list

     allocate(pe_list(count), stat=ierr)
     if (ierr /= 0) then
	call die(myname_,'allocate(pe_list)',ierr)
     endif

     i = 0
     do p=0,max_activepe
        if (process_list(p)) then
           i = i+1
           if (i > count) exit
           pe_list(i) = p
        endif
     enddo

     if (i > count) then
       call die(myname_,'pe_list fill error',count)
     endif

  endif ! if(present(pe_list))...

        ! deallocate work array process_list...

  deallocate(process_list, stat=ierr)
  if (ierr /= 0) then
     call die(myname_,'deallocate(process_list)',ierr)
  endif

        ! finally, store the active process count in output variable
        ! n_active:

  n_active = count

 end subroutine active_pes_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: peLocs_ - process ID locations for distributed points.
! index.
!
! !DESCRIPTION:
! This routine takes an input {\tt INTEGER} array of point indices
! {\tt points(:)}, compares them with an input {\tt GlobalSegMap}
! {\tt pointGSMap}, and returns the {\em unique} process ID location
! for each point.  Note the emphasize on unique.  The assumption here
! (which is tested) is that {\tt pointGSMap} is not haloed.  The process
! ID locations for the points is returned in the array {\tt pe\_locs(:)}.
!
! {\bf N.B.:} The test of {\tt pointGSMap} for halo points, and the
! subsequent search for the process ID for each point is very slow.  This
! first version of the routine is serial.  A parallel version of this
! routine will need to be developed.
!
! !INTERFACE:

 subroutine peLocs_(pointGSMap, npoints, points, pe_locs)
!
! !USES:
!
      use m_die ,          only : die

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),    intent(in)   :: pointGSMap
      integer,               intent(in)   :: npoints
      integer, dimension(:), intent(in)   :: points

! !OUTPUT PARAMETERS:

      integer, dimension(:), intent(out)  :: pe_locs

! !REVISION HISTORY:
! 	18Apr01 - J.W. Larson <larson@mcs.anl.gov> - initial version.
!       18Oct16 - P. Worley <worleyph@gmail.com> - added algorithm options:
!                 new default changes complexity from O(npoints*ngseg) to
!                 O(gsize + ngseg) (worst case), and much better in current
!                 usage. Worst case memory requirements are O(gsize), but
!                 not seen in current usage. Other new algorithm is a little
!                 slower in practice, and worst case memory requirement is
!                 O(ngseg), which is also not seen in current usage.
!                 Original algorithm is recovered if compiled with
!                 LOW_MEMORY_PELOCS defined. Otherwise nondefault new
!                 algorithm is enabled if compiled with MEDIUM_MEMORY_PELOCS
!                 defined.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::peLocs_'
  integer :: ierr
  integer :: iseg, ngseg, ipoint
  integer :: lower_index, upper_index
  integer :: min_points_index, max_points_index
#if defined MEDIUM_MEMORY_PELOCS
  integer :: ifseg, nfseg
  integer, dimension(:), allocatable :: feasible_seg
#else
  integer, dimension(:), allocatable :: pindices_to_pes
#endif

! Input argument checks:

  if (npoints < 1) then
     return
  endif

  if(size(points) < npoints) then
     ierr = size(points)
     call die(myname_,'input points list array too small',ierr)
  endif

  if(size(pe_locs) < npoints) then
     ierr = size(pe_locs)
     call die(myname_,'output pe_locs array too small',ierr)
  endif

  if(haloed_(pointGSMap)) then
     ierr = 1
     call die(myname_,'input pointGSMap haloed--not valid',ierr)
  endif

! Brute-force indexing...no assumptions regarding sorting of points(:)
! or pointGSMap%start(:)

! Number of segments in pointGSMap:

  ngseg = ngseg_(pointGSMap)

#if defined LOW_MEMORY_PELOCS

  do ipoint=1,npoints ! loop over points

     do iseg=1,ngseg  ! loop over segments

        lower_index = pointGSMap%start(iseg)
        upper_index = lower_index + pointGSMap%length(iseg) - 1

        if((points(ipoint) >= lower_index) .and. &
           (points(ipoint) <= upper_index)) then
           pe_locs(ipoint) = pointGSMap%pe_loc(iseg)

           exit

        endif

     end do ! do iseg=1, ngseg

  end do ! do ipoint=1,npoints

#elif defined MEDIUM_MEMORY_PELOCS

! Determine index range for points vector
  max_points_index = 0
  min_points_index = pointGSMap%gsize + 1
  do ipoint=1,npoints ! loop over points

     max_points_index = max(points(ipoint), max_points_index)
     min_points_index = min(points(ipoint), min_points_index)

  end do ! do ipoint=1,npoints

! Determine number of segments that need to be examined
  nfseg = 0
  do iseg=1,ngseg  ! loop over segments

     lower_index = pointGSMap%start(iseg)
     upper_index = lower_index + pointGSMap%length(iseg) - 1

     if ((lower_index <= max_points_index) .and. &
         (upper_index >= min_points_index)       ) then

        nfseg = nfseg + 1

     endif

  end do ! do iseg=1, ngseg

  if(nfseg < 1) then
     ierr = nfseg
     call die(myname_,'no feasible segments',ierr)
  endif

  ! Allocate temporary array
  allocate(feasible_seg(nfseg), stat=ierr)
  if (ierr /= 0) then
     call die(myname_,'allocate(feasible_seg)',ierr)
  endif

  ! Determine segments that need to be examined
  feasible_seg(:) = 1
  nfseg = 0
  do iseg=1,ngseg  ! loop over segments

     lower_index = pointGSMap%start(iseg)
     upper_index = lower_index + pointGSMap%length(iseg) - 1

     if ((lower_index <= max_points_index) .and. &
         (upper_index >= min_points_index)       ) then

        nfseg = nfseg + 1
        feasible_seg(nfseg) = iseg

     endif

  end do ! do iseg=1, ngseg

  ! Calculate map from local points to pes
  do ipoint=1,npoints ! loop over points

     do ifseg=1,nfseg  ! loop over feasible segments

        iseg = feasible_seg(ifseg)
        lower_index = pointGSMap%start(iseg)
        upper_index = lower_index + pointGSMap%length(iseg) - 1

        if((points(ipoint) >= lower_index) .and. &
           (points(ipoint) <= upper_index)       ) then
           pe_locs(ipoint) = pointGSMap%pe_loc(iseg)
           exit
        endif

     end do ! do ifseg=1,nfseg
  end do ! do ipoint=1,npoints

  ! Clean up
  deallocate(feasible_seg, stat=ierr)
  if (ierr /= 0) then
     call die(myname_,'deallocate(feasible_seg)',ierr)
  endif

#else

! Determine index range for points assigned to points vector
  max_points_index = 0
  min_points_index = pointGSMap%gsize + 1
  do ipoint=1,npoints ! loop over points

     max_points_index = max(points(ipoint), max_points_index)
     min_points_index = min(points(ipoint), min_points_index)

  end do ! do ipoint=1,npoints

! Allocate temporary array
  allocate(pindices_to_pes(min_points_index:max_points_index), stat=ierr)
  if (ierr /= 0) then
     call die(myname_,'allocate(pindices_to_pes)',ierr)
  endif

! Calculate map from (global) point indices to pes
  do iseg=1,ngseg  ! loop over segments

     lower_index = pointGSMap%start(iseg)
     upper_index = lower_index + pointGSMap%length(iseg) - 1

     lower_index = max(lower_index, min_points_index)
     upper_index = min(upper_index, max_points_index)

     if (lower_index <= upper_index) then
        do ipoint=lower_index,upper_index
           pindices_to_pes(ipoint) = pointGSMap%pe_loc(iseg)
        enddo
     endif

  end do ! do iseg=1, ngseg

! Calculate map from local point indices to pes
  do ipoint=1,npoints ! loop over points

     pe_locs(ipoint) = pindices_to_pes(points(ipoint))

  end do ! do ipoint=1,npoints

! Clean up
  deallocate(pindices_to_pes, stat=ierr)
  if (ierr /= 0) then
     call die(myname_,'deallocate(pindices_to_pes)',ierr)
  endif

#endif

 end subroutine peLocs_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: haloed_ - test GlobalSegMap for presence of halo points.
! index.
!
! !DESCRIPTION:
! This {\tt LOGICAL} function tests the input {\tt GlobalSegMap}
! {\tt GSMap} for the presence of halo points.  Halo points are points
! that appear in more than one segment of a {\tt GlobalSegMap}.  If
! {\em any} halo point is found, the function {\tt haloed\_()} returns
! immediately with value {\tt .TRUE.}  If, after an exhaustive search
! of the map has been completed, no halo points are found, the function
! {\tt haloed\_()} returns with value {\tt .FALSE.}
!
! The search algorithm is:
!
! \begin{enumerate}
! \item Extract the segment start and length information from
! {\tt GSMap\%start} and {\tt GSMap\%length} into the temporary
! arrays {\tt start(:)} and {\tt length(:)}.
! \item Sort these arrays in {\em ascending order} keyed by {\tt start}.
! \item Scan the arrays {\tt start} and{\tt length}.  A halo point is
! present if for at least one value of the index
! $1 \leq {\tt n} \leq {\tt GSMap\%ngseg}$
! $${\tt start(n)} + {\tt length(n)} - 1 \geq {\tt start(n+1)}$$.
! \end{enumerate}
!
! {\bf N.B.:} Beware that the search for halo points is potentially
! expensive.
!
! !INTERFACE:

    logical function haloed_(GSMap)
!
! !USES:
!
      use m_die ,          only : die
      use m_SortingTools , only : IndexSet
      use m_SortingTools , only : IndexSort
      use m_SortingTools , only : Permute

      implicit none

 ! !INPUT PARAMETERS:

     type(GlobalSegMap), intent(in)           :: GSMap

! !REVISION HISTORY:
! 	08Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version.
! 	26Apr01 - J.W. Larson <larson@mcs.anl.gov> - Bug fix.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::haloed_'

! Error Flag

  integer :: ierr

! Loop index and storage for number of segments in GSMap

  integer :: n, ngseg

! Temporary storage for GSMap%start, GSMap%length, and index
! permutation array:

  integer, dimension(:), allocatable :: start, length, perm

! Logical flag indicating segment overlap

  logical :: overlap

       ! How many segments in GSMap?

  ngseg = ngseg_(GSMap)

       ! allocate temporary arrays:

  allocate(start(ngseg), length(ngseg), perm(ngseg), stat=ierr)
  if (ierr /= 0) then
     call die(myname_,'allocate(start...',ierr)
  endif

       ! Fill the temporary arrays start(:) and length(:)

  do n=1,ngseg
     start(n) = GSMap%start(n)
     length(n) = GSMap%length(n)
  end do

       ! Initialize the index permutation array:

  call IndexSet(perm)

       ! Create the index permutation that will order the data so the
       ! entries of start(:) appear in ascending order:

  call IndexSort(ngseg, perm, start, descend=.false.)

       ! Permute the data so the entries of start(:) are now in
       ! ascending order:

  call Permute(start,perm,ngseg)

       ! Apply this same permutation to length(:)

  call Permute(length,perm,ngseg)

       ! Set LOGICAL flag indicating segment overlap to .FALSE.

  overlap = .FALSE.

       ! Now, scan the segments, looking for overlapping segments.  Upon
       ! discovery of the first overlapping pair of segments, set the
       ! flag overlap to .TRUE. and exit.

  n = 0

  SCAN_LOOP: do
     n = n + 1
     if(n == ngseg) EXIT ! we are finished, and there were no halo pts.
     if((start(n) + length(n) - 1) >= start(n+1)) then ! found overlap
	overlap = .TRUE.
	EXIT
     endif
  end do SCAN_LOOP

       ! Clean up allocated memory:

  deallocate(start, length, perm, stat=ierr)
  if (ierr /= 0) then
     call die(myname_,'deallocate(start...',ierr)
  endif

       ! Assign function return value:

 haloed_ = overlap

 end function haloed_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: Sort_ - generate index permutation for GlobalSegMap.
!
! !DESCRIPTION:
! {\tt Sort\_()} uses the supplied keys {\tt key1} and {\tt key2} to
! generate a permutation {\tt perm} that will put the entries of the
! components {\tt GlobalSegMap\%start}, {\tt GlobalSegMap\%length} and
! {\tt GlobalSegMap\%pe\_loc} in {\em ascending} lexicographic order.
!
! {\bf N.B.:} {\tt Sort\_()} returns an allocated array {\tt perm(:)}.  It
! the user must deallocate this array once it is no longer needed.  Failure
! to do so could create a memory leak.
!
! !INTERFACE:

    subroutine Sort_(GSMap, key1, key2, perm)
!
! !USES:
!
      use m_die ,          only : die
      use m_SortingTools , only : IndexSet
      use m_SortingTools , only : IndexSort

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),    intent(in)           :: GSMap ! input GlobalSegMap
      integer, dimension(:), intent(in)           :: key1  ! first sort key
      integer, dimension(:), intent(in), optional :: key2  ! second sort key

! !OUTPUT PARAMETERS:

      integer, dimension(:), pointer :: perm    ! output index permutation

! !REVISION HISTORY:
! 	02Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::Sort_'

  integer :: ierr, length

  length = ngseg_(GSMap)

        ! Argument checking.  are key1 and key2 (if supplied) the
        ! same length as the components of GSMap?  If not, stop with
        ! an error.

  ierr = 0

  if(size(key1) /= length) then
     ierr = 1
     call die(myname_,'key1 GSMap size mismatch',ierr)
  endif

  if(present(key2)) then
     if(size(key2) /= length) then
        ierr = 2
	call die(myname_,'key2 GSMap size mismatch',ierr)
     endif
     if(size(key1) /= size(key2)) then
        ierr = 3
	call die(myname_,'key1 key2 size mismatch',ierr)
     endif
  endif

        ! allocate space for permutation array perm(:)

  allocate(perm(length), stat=ierr)
  if(ierr /= 0) call die(myname_,'allocate(perm)',ierr)

        ! Initialize perm(i)=i, for i=1,length

  call IndexSet(perm)

        ! Index permutation is achieved by successive calls to IndexSort(),
        ! with the keys supplied one at a time in the order reversed from
        ! the desired sort order.

  if(present(key2)) then
     call IndexSort(length, perm, key2, descend=.false.)
  endif

  call IndexSort(length, perm, key1, descend=.false.)

        ! Yes, it is that simple.  The desired index permutation is now
        ! stored in perm(:)

 end subroutine Sort_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: PermuteInPlace_ - apply index permutation to GlobalSegMap.
!
! !DESCRIPTION:
! {\tt PermuteInPlace\_()} uses a supplied index permutation {\tt perm}
! to re-order {\tt GlobalSegMap\%start}, {\tt GlobalSegMap\%length} and
! {\tt GlobalSegMap\%pe\_loc}.
!
! !INTERFACE:

    subroutine PermuteInPlace_(GSMap, perm)
!
! !USES:
!
      use m_die ,          only : die
      use m_SortingTools , only : Permute

      implicit none

! !INPUT PARAMETERS:

      integer, dimension(:), intent(in) :: perm

! !INPUT/OUTPUT PARAMETERS:

      type(GlobalSegMap), intent(inout) :: GSMap

! !REVISION HISTORY:
!       02Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::PermuteInPlace_'

  integer :: length, ierr

  length = ngseg_(GSMap)

        ! Argument checking.  Do the components of GSMap
        ! (e.g. GSMap%start) have the same length as the
        ! permutation array perm?  If not, stop with an error.

  ierr = 0

  if(size(perm) /= length) then
     ierr = 1
     call die(myname_,'perm GSMap size mismatch',ierr)
  endif

        ! In-place index permutation using perm(:) :

  call Permute(GSMap%start,perm,length)
  call Permute(GSMap%length,perm,length)
  call Permute(GSMap%pe_loc,perm,length)

        ! Now, the components of GSMap are ordered according to
        ! perm(:).

 end subroutine PermuteInPlace_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: SortPermuteInPlace_ - Sort in-place GlobalSegMap components.
!
! !DESCRIPTION:
! {\tt SortPermuteInPlace\_()} uses a the supplied key(s) to generate
! and apply an index permutation that will place the {\tt GlobalSegMap}
! components {\tt GlobalSegMap\%start}, {\tt GlobalSegMap\%length} and
! {\tt GlobalSegMap\%pe\_loc} in lexicographic order.
!
! !INTERFACE:

    subroutine SortPermuteInPlace_(GSMap, key1, key2)
!
! !USES:
!
      use m_die ,          only : die

      implicit none

! !INPUT PARAMETERS:

      integer, dimension(:), intent(in)           :: key1
      integer, dimension(:), intent(in), optional :: key2

! !INPUT/OUTPUT PARAMETERS:

      type(GlobalSegMap),    intent(inout)        :: GSMap

! !REVISION HISTORY:
!       02Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::SortPermuteInPlace_'

  integer :: length, ierr
  integer, dimension(:), pointer :: perm

   length = ngseg_(GSMap)

        ! Argument checking.  are key1 and key2 (if supplied) the
        ! same length as the components of GSMap?  If not, stop with
        ! an error.
  ierr = 0
  if(size(key1) /= length) then
     ierr = 1
     call die(myname_,'key1 GSMap size mismatch',ierr)
  endif

  if(present(key2)) then
     if(size(key2) /= length) then
        ierr = 2
	call die(myname_,'key2 GSMap size mismatch',ierr)
     endif
     if(size(key1) /= size(key2)) then
        ierr = 3
	call die(myname_,'key1 key2 size mismatch',ierr)
     endif
  endif

        ! Generate desired index permutation:

  if(present(key2)) then
     call Sort_(GSMap, key1, key2, perm)
  else
     call Sort_(GSMap, key1=key1, perm=perm)
  endif

        ! Apply index permutation:

  call PermuteInPlace_(GSMap, perm)

        ! Now the components of GSMap have been re-ordered.
        ! Deallocate the index permutation array perm(:)

  deallocate(perm, stat=ierr)
  if(ierr /= 0) call die(myname_,'deallocate(perm...)',ierr)

 end subroutine SortPermuteInPlace_


!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: increasing_ - Return .TRUE. if GSMap has increasing indices
!
! !DESCRIPTION:
! The function {\tt increasing\_()} returns .TRUE. if each proc's
! indices in the {\tt GlobalSegMap} argument {\tt GSMap} have
! strictly increasing indices.  I.e. the proc's segments have indices
! in ascending order and are non-overlapping.
!
! !INTERFACE:

 logical function increasing_(gsmap)

! !USES:
      use m_MCTWorld, only: ThisMCTWorld
      use m_die

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),intent(in) :: gsmap

! !REVISION HISTORY:
! 	06Jun07 - R. Loy <rloy@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::increasing_'

  integer comp_id
  integer nprocs
  integer i
  integer this_ngseg
  integer ier
  integer, allocatable:: last_index(:)
  integer pe_loc

  comp_id = gsmap%comp_id
  nprocs=ThisMCTWorld%nprocspid(comp_id)

  allocate( last_index(nprocs), stat=ier )
  if (ier/=0) call die(myname_,'allocate last_index')

  last_index= -1
  increasing_ = .TRUE.
  this_ngseg=ngseg(gsmap)

  iloop: do i=1,this_ngseg
    pe_loc=gsmap%pe_loc(i)+1  ! want value 1..nprocs
    if (gsmap%start(i) <= last_index(pe_loc)) then
      increasing_ = .FALSE.
      exit iloop
    endif
    last_index(pe_loc)=gsmap%start(i)+gsmap%length(i)-1
  enddo iloop

  deallocate( last_index, stat=ier )
  if (ier/=0) call die(myname_,'deallocate last_index')

 end function increasing_


!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: copy_ - Copy the gsmap to a new gsmap
!
! !DESCRIPTION:
! Make a copy of a gsmap.
! Note this is a deep copy of all arrays.
!
! !INTERFACE:

  subroutine copy_(src,dest)

! !USES:
      use m_MCTWorld, only: ThisMCTWorld
      use m_die

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),intent(in) :: src

! !OUTPUT PARAMETERS:

      type(GlobalSegMap),intent(out) :: dest


! !REVISION HISTORY:
! 	27Jul07 - R. Loy <rloy@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________


    call initp_( dest, src%comp_id, src%ngseg, src%gsize, &
                 src%start, src%length, src%pe_loc )

  end subroutine copy_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: print_ - Print GSMap info
!
! !DESCRIPTION:
! Print out contents of GSMAP on unit number 'lun'
!
! !INTERFACE:

    subroutine print_(gsmap,lun)
!
! !USES:
!
      use m_die

      implicit none

!INPUT/OUTPUT PARAMETERS:
      type(GlobalSegMap),      intent(in) :: gsmap
      integer, intent(in)           :: lun

! !REVISION HISTORY:
! 06Jul12 - R. Jacob <jacob@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________


    integer n
    character(len=*),parameter :: myname_=myname//'::print_'

    write(lun,*) gsmap%comp_id
    write(lun,*) gsmap%ngseg
    write(lun,*) gsmap%gsize
    do n=1,gsmap%ngseg
        write(lun,*) gsmap%start(n),gsmap%length(n),gsmap%pe_loc(n)
    end do

  end subroutine print_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: printFromRoot_ - Print GSMap info
!
! !DESCRIPTION:
! Print out contents of GSMAP on unit number 'lun'
!
! !INTERFACE:

    subroutine printFromRootnp_(gsmap,mycomm,lun)
!
! !USES:
!
      use m_MCTWorld,      only : printnp
      use m_die
      use m_mpif90

      implicit none

!INPUT/OUTPUT PARAMETERS:
      type(GlobalSegMap),      intent(in) :: gsmap
      integer, intent(in)           :: mycomm
      integer, intent(in)           :: lun

! !REVISION HISTORY:
! 06Jul12 - R. Jacob <jacob@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________


    integer myrank
    integer ier
    character(len=*),parameter :: myname_=myname//'::print_'

    call MP_comm_rank(mycomm,myrank,ier)
    if(ier/=0) call MP_perr_die(myname_,'MP_comm_rank',ier)

    if (myrank == 0) then
      call printnp(gsmap%comp_id,lun)
      call print_(gsmap,lun)
    endif

  end subroutine printFromRootnp_




 end module m_GlobalSegMap

