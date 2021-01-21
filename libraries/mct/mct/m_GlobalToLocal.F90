!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_GlobalToLocal - Global to Local Index Translation
!
! !DESCRIPTION:
! This module contains routines for translating global array indices
! into their local counterparts (that is, the indices into the local
! data structure holding a given process' chunk of a distributed array).
! The MCT domain decomposition descriptors {\tt GlobalMap} and
! {\tt GlobalSegMap} are both supported.   Indices can be translated
! one-at-a-time using the {\tt GlobalToLocalIndex} routine or many
! at once using the {\tt GlobalToLocalIndices} routine.
!
! This module also provides facilities for setting the local row and
! column indices for a {\tt SparseMatrix} through the
! {\tt GlobalToLocalMatrix} routines.
!
! !INTERFACE:

 module m_GlobalToLocal

! !USES:
! No external modules are used in the declaration section of this module.

      implicit none

      private   ! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: GlobalToLocalIndex   ! Translate Global to Local index
                                     ! (i.e. recover local index for a
                                     ! point from its global index).

      public :: GlobalToLocalIndices ! Translate Global to Local indices
                                     ! (i.e. recover local starts/lengths
                                     ! of distributed data segments).

      public :: GlobalToLocalMatrix  ! Re-indexing of row or column
                                     ! indices for a SparseMatrix

    interface GlobalToLocalIndices ; module procedure   &
       GlobalSegMapToIndices_,  &   ! local arrays of starts/lengths
       GlobalSegMapToNavigator_, &  ! return local indices as Navigator
       GlobalSegMapToIndexArr_
    end interface

    interface GlobalToLocalIndex ; module procedure &
       GlobalSegMapToIndex_, &
       GlobalMapToIndex_
    end interface

    interface GlobalToLocalMatrix ; module procedure &
       GlobalSegMapToLocalMatrix_
    end interface


! !SEE ALSO:
!
! The MCT modules {\tt m\_GlobalMap} and {m\_GlobalSegMap} for more
! information regarding MCT's domain decomposition descriptors.
!
! The MCT module {\tt m\_SparseMatrix} for more information regarding
! the {\tt SparseMatrix} datatype.
!
! !REVISION HISTORY:
!  2Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_GlobalToLocal'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GlobalSegMapToIndices_ - Return _local_ indices in arrays.
!
! !DESCRIPTION:  {\tt GlobalSegMapToIndices\_()} takes a user-supplied
! {\tt GlobalSegMap} data type {\tt GSMap}, which desribes a decomposition
! on the input MPI communicator corresponding to the Fortran {\tt INTEGER}
! handle {\tt comm} to translate the global directory of segment locations
! into local indices for referencing the on-pe storage of the mapped
! distributed data.
!
! {\bf N.B.:}  This routine returns two allocated arrays---{\tt start(:)}
! and {\tt length(:)}---which must be deallocated once the user no longer
! needs them.  Failure to do this will create a memory leak.
!
! !INTERFACE:

 subroutine GlobalSegMapToIndices_(GSMap, comm, start, length)

!
! !USES:
!
      use m_mpif90
      use m_die,          only : MP_perr_die, die, warn
      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_ngseg => ngseg
      use m_GlobalSegMap, only : GlobalSegMap_nlseg => nlseg

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),   intent(in) :: GSMap ! Output GlobalSegMap
      integer,              intent(in) :: comm  ! communicator handle

! !OUTPUT PARAMETERS:

      integer,dimension(:), pointer :: start  ! local segment start indices
      integer,dimension(:), pointer :: length ! local segment sizes

! !REVISION HISTORY:
!  2Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GlobalSegMapToIndices_'

  integer :: myID, ierr, ngseg, nlseg, n, count

          ! determine local process id myID

  call MP_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) call MP_perr_die(myname_,'MP_COMM_RANK',ierr)

          ! determine number of global segments ngseg:

  ngseg = GlobalSegMap_ngseg(GSMap)

          ! determine number of local segments on process myID nlseg:

  nlseg = GlobalSegMap_nlseg(GSMap, myID)

          ! allocate arrays start(:) and length(:) to store local
          ! segment information.

  allocate(start(nlseg), length(nlseg), stat=ierr)
  if(ierr /= 0) call die(myname_,'allocate(start...',ierr)

          ! Loop over GlobalSegMap%pe_loc(:) values to isolate
          ! global index values of local data.  Record number of
          ! matches in the INTEGER count.

  count = 0
  do n=1, ngseg
     if(GSMap%pe_loc(n) == myID) then
        count = count + 1
        if(count > nlseg) then
           ierr = 2
           call die(myname_,'too many pe matches',ierr)
	endif
	start(count) = GSMap%start(n)
	length(count) = GSMap%length(n)
     endif
  end do

  if(count < nlseg) then
     ierr = 3
     call die(myname_,'too few pe matches',ierr)
  endif

          ! translate global start indices to their local
          ! values, based on their storage order and number
          ! of elements in each segment

  do n=1, count
     if(n == 1) then
	start(n) = 1
     else
	start(n) = start(n-1) + length(n-1)
     endif
  end do

 end subroutine GlobalSegMapToIndices_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GlobalSegMapToIndex_ - Global to Local Index Translation
!
! !DESCRIPTION:  This {\tt INTEGER} query function takes a user-supplied
! {\tt GlobalSegMap} data type {\tt GSMap}, which desribes a decomposition
! on the input MPI communicator corresponding to the Fortran {\tt INTEGER}
! handle {\tt comm}, and the input global index value {\tt i\_g}, and
! returns a positive local index value if the datum {\tt i\_g}.   If
! the datum {\tt i\_g} is not stored on the local process ID, a value
! of {\tt -1} is returned.
!
! !INTERFACE:


 integer function GlobalSegMapToIndex_(GSMap, i_g, comm)

!
! !USES:
!
      use m_mpif90
      use m_die,          only : MP_perr_die, die, warn
      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_ngseg => ngseg
      use m_GlobalSegMap, only : GlobalSegMap_nlseg => nlseg

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap), intent(in)  :: GSMap ! Output GlobalSegMap
      integer,            intent(in)  :: i_g   ! global index
      integer,            intent(in)  :: comm  ! communicator handle

! !REVISION HISTORY:
!  2Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GlobalSegMapToIndex_'

  integer :: myID
  integer :: count, ierr, ngseg, nlseg, n
  integer :: lower_bound, upper_bound
  integer :: local_start, local_index
  logical :: found

  ! Determine local process id myID:

  call MP_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) call MP_perr_die(myname_,'MP_COMM_RANK()',ierr)

  ! Extract the global number of segments in GSMap

  ngseg = GlobalSegMap_ngseg(GSMap)

  ! Extract the global number of segments in GSMap for myID

  nlseg = GlobalSegMap_nlseg(GSMap, myID)

  ! set the counter count, which records the number of times myID
  ! matches entries in GSMap%pe_loc(:)

  count = 0

  ! set local_start, which is the current local storage segment
  ! starting position

  local_start = 1

  ! set logical flag found to signify we havent found i_g:

  found = .false.

  n = 0

  SEARCH_LOOP: do

     n = n+1
     if (n > ngseg) EXIT

     if(GSMap%pe_loc(n) == myID) then

  ! increment / check the pe_loc match counter

        count = count + 1
        if(count > nlseg) then
           ierr = 2
           call die(myname_,'too many pe matches',ierr)
	endif

  ! is i_g in this segment?

        lower_bound = GSMap%start(n)
        upper_bound = GSMap%start(n) + GSMap%length(n) - 1

        if((lower_bound <= i_g) .and. (i_g <= upper_bound)) then
	   local_index = local_start + (i_g - GSMap%start(n))
	   found = .true.
	   EXIT
	else
	   local_start = local_start + GSMap%length(n)
        endif

     endif
  end do SEARCH_LOOP

  ! We either found the local index, or have exhausted our options.

  if(found) then
     GlobalSegMapToIndex_ = local_index
  else
     GlobalSegMapToIndex_ = -1
  endif

 end function GlobalSegMapToIndex_



!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GlobalSegMapToIndexArr_ - Global to Local Index Array Translation
!
! !DESCRIPTION:  Given a {\tt GlobalSegMap} data type {\tt GSMap}
! and MPI communicator corresponding to the Fortran {\tt INTEGER}
! handle {\tt comm}, convert an array of global index values
! {\tt i\_global()} to an array of local index values {\tt i\_local()}.  If
! the datum {\tt i\_global(j)} is not stored on the local process ID,
! then {\tt i\_local(j)} will be set to {\tt -1}/
!
! !INTERFACE:


subroutine GlobalSegMapToIndexArr_(GSMap, i_global, i_local, nindex, comm)

!
! !USES:
!
      use m_stdio
      use m_mpif90
      use m_die,          only : MP_perr_die, die, warn
      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_ngseg => ngseg
      use m_GlobalSegMap, only : GlobalSegMap_nlseg => nlseg

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap), intent(in)  :: GSMap ! Output GlobalSegMap
      integer,            intent(in)  :: i_global(:)   ! global index
      integer,            intent(out) :: i_local(:)    ! local index
      integer,            intent(in)  :: nindex          ! size of i_global()
      integer,            intent(in)  :: comm  ! communicator handle

! !REVISION HISTORY:
!  12-apr-2006   R. Loy <rloy@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GlobalSegMapToIndexArr_'

  integer :: myID
  integer :: count, ierr, ngseg, nlseg
  integer,allocatable  :: mygs_lb(:),mygs_ub(:),mygs_len(:),mygs_lstart(:)

  integer :: i,j,n,startj

  ! Determine local process id myID:

  call MP_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) call MP_perr_die(myname_,'MP_COMM_RANK()',ierr)


  ngseg = GlobalSegMap_ngseg(GSMap)
  nlseg = GlobalSegMap_nlseg(GSMap, myID)

  if (nlseg <= 0) return;

  allocate( mygs_lb(nlseg), mygs_ub(nlseg), mygs_len(nlseg) )
  allocate( mygs_lstart(nlseg) )


!!
!! determine the global segments on this processor
!! just once, so the info be used repeatedly below
!!

  n = 0
  do i=1,ngseg
    if (GSMap%pe_loc(i) == myID ) then
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

  mygs_lstart(1)=1
  do j=2,nlseg
    mygs_lstart(j)=mygs_lstart(j-1)+mygs_len(j-1)
  enddo


!!
!! this loop is optimized for the case that the indices in iglobal()
!! are in the same order that they appear in the global segments,
!! which seems usually (always?) to be the case.
!!
!! note that the j loop exit condition is only executed when the index
!! is not found in the current segment, which saves a factor of 2
!! since many consecutive indices are in the same segment.
!!


  j=1
  do i=1,nindex

    i_local(i)= -1

    startj=j
    SEARCH_LOOP: do

      if ( (mygs_lb(j) <= i_global(i)) .and. &
           (i_global(i) <= mygs_ub(j))) then
        i_local(i) = mygs_lstart(j) + (i_global(i) - mygs_lb(j))
        EXIT SEARCH_LOOP
      else
        j=j+1
        if (j > nlseg) j=1                      ! wrap around
        if (j == startj) EXIT SEARCH_LOOP
      endif

    end do SEARCH_LOOP

  end do

!!!! this version vectorizes (outer loop)
!!!! performance for in-order input is slightly slower than the above
!!!! but performance on out-of-order input is probably much better
!!!! at the moment we are going on the assumption that caller is
!!!! likely providing in-order, so we won't use this version.
!!
!!  do i=1,nindex
!!
!!    i_local(i)= -1
!!
!!    SEARCH_LOOP: do j=1,nlseg
!!
!!      if ( (mygs_lb(j) <= i_global(i)) .and. &
!!           (i_global(i) <= mygs_ub(j))) then
!!        i_local(i) = mygs_lstart(j) + (i_global(i) - mygs_lb(j))
!!      endif
!!
!!    end do SEARCH_LOOP
!!
!!  end do


  deallocate( mygs_lb, mygs_ub, mygs_len, mygs_lstart )

 end subroutine GlobalSegMapToIndexArr_





!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GlobalMapToIndex_ - Global to Local Index Translation
!
! !DESCRIPTION:
! This {\tt INTEGER} query function takes as its input a user-supplied
! {\tt GlobalMap} data type {\tt GMap}, which desribes a decomposition
! on the input MPI communicator corresponding to the Fortran {\tt INTEGER}
! handle {\tt comm}, and the input global index value {\tt i\_g}, and
! returns a positive local index value if the datum {\tt i\_g}.   If
! the datum {\tt i\_g} is not stored on the local process ID, a value
! of {\tt -1} is returned.
!
! !INTERFACE:


 integer function GlobalMapToIndex_(GMap, i_g, comm)

!
! !USES:
!
      use m_mpif90
      use m_die,          only : MP_perr_die, die, warn
      use m_GlobalMap,    only : GlobalMap

      implicit none

! !INPUT PARAMETERS:

      type(GlobalMap), intent(in)  :: GMap  ! Input GlobalMap
      integer,         intent(in)  :: i_g   ! global index
      integer,         intent(in)  :: comm  ! communicator handle

! !REVISION HISTORY:
!  2Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GlobalMapToIndex_'

  integer :: myID
  integer :: count, ierr, ngseg, nlseg, n
  integer :: lower_bound, upper_bound
  integer :: local_start, local_index
  logical :: found

  ! Determine local process id myID:

  call MP_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) call MP_perr_die(myname_,'MP_COMM_RANK()',ierr)

  ! Initialize logical "point located" flag found as false

  found = .false.

  lower_bound = GMap%displs(myID) + 1
  upper_bound = GMap%displs(myID) + GMap%counts(myID)

  if((lower_bound <= i_g) .and. (i_g <= upper_bound)) then
     found = .true.
     local_index = i_g - lower_bound + 1
  endif

  if(found) then
     GlobalMapToIndex_ = local_index
  else
     GlobalMapToIndex_ = -1
  endif

 end function GlobalMapToIndex_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GlobalSegMapToNavigator_ - Return Navigator to Local Segments
!
! !DESCRIPTION:
! This routine takes as its input takes a user-supplied
! {\tt GlobalSegMap} data type {\tt GSMap}, which desribes a decomposition
! on the input MPI communicator corresponding to the Fortran {\tt INTEGER}
! handle {\tt comm}, and returns the local segment start index and length
! information for referencing the on-pe storage of the mapped distributed
! data.  These data are returned in the form of the output {\tt Navigator}
! argument {Nav}.
!
! {\bf N.B.:}  This routine returns a {\tt Navigator} variable {\tt Nav},
! which must be deallocated once the user no longer needs it.  Failure to
! do this will create a memory leak.
!
! !INTERFACE:

 subroutine GlobalSegMapToNavigator_(GSMap, comm, oNav)

!
! !USES:
!
      use m_mpif90
      use m_die,          only : MP_perr_die, die, warn
      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_ngseg => ngseg
      use m_GlobalSegMap, only : GlobalSegMap_nlseg => nlseg
      use m_Navigator, only    : Navigator
      use m_Navigator, only    : Navigator_init => init

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap), intent(in)  :: GSMap ! Input GlobalSegMap
      integer,            intent(in)  :: comm  ! communicator handle

! !OUTPUT PARAMETERS:

      type(Navigator),    intent(out) :: oNav   ! Output Navigator

! !REVISION HISTORY:
!  2Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GlobalSegMapToNavigator_'

  integer :: myID, ierr, ngseg, nlseg, n, count

          ! determine local process id myID

  call MP_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) call MP_perr_die(myname_,'MP_COMM_RANK',ierr)

          ! determine number of global segments ngseg:

  ngseg = GlobalSegMap_ngseg(GSMap)

          ! determine number of local segments on process myID nlseg:

  nlseg = GlobalSegMap_nlseg(GSMap, myID)

          ! Allocate space for the Navigator oNav:

  call Navigator_init(oNav, nlseg, ierr)
  if(ierr /= 0) call die(myname_,'Navigator_init',ierr)

  call GlobalSegMapToIndices_(GSMap, comm, oNav%displs, oNav%counts)

 end subroutine GlobalSegMapToNavigator_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GlobalSegMapToLocalMatrix_ - Set Local SparseMatrix Indices
!
! !DESCRIPTION:
! This routine takes as its input a user-supplied {\tt GlobalSegMap}
! domain decomposition {\tt GSMap}, which describes the decomposition of
! either the rows or columns of the input/output {\tt SparseMatrix}
! argument {\tt sMat} on the communicator associated with the {\tt INTEGER}
! handle {\tt comm}, and to translate the global row or column indices
! of {\tt sMat} into their local counterparts.  The choice of either row
! or column is governed by the value of the input {\tt CHARACTER}
! argument {\tt RCFlag}.  One sets this variable to either {\tt 'ROW'} or
! {\tt 'row'} to specify row re-indexing (which are stored in
! {\tt sMat} and retrieved by indexing the attribute {\tt lrow}), and
! {\tt 'COLUMN'} or {\tt 'column'} to specify column re-indexing (which
! are stored in {\tt sMat} and retrieved by indexing the {\tt SparseMatrix}
! attribute {\tt lcol}).
!
! !INTERFACE:

 subroutine GlobalSegMapToLocalMatrix_(sMat, GSMap, RCFlag, comm)

!
! !USES:
!
      use m_stdio
      use m_die,          only : die

      use m_SparseMatrix, only : SparseMatrix
      use m_SparseMatrix, only : SparseMatrix_indexIA => indexIA
      use m_SparseMatrix, only : SparseMatrix_lsize => lsize

      use m_GlobalSegMap, only : GlobalSegMap


      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap), intent(in)    :: GSMap  ! Input GlobalSegMap
      character(len=*),   intent(in)    :: RCFlag ! 'row' or 'column'
      integer,            intent(in)    :: comm   ! communicator handle

! !INPUT/OUTPUT PARAMETERS:

      type(SparseMatrix), intent(inout) :: sMat

! !SEE ALSO:
! The MCT module m_SparseMatrix for more information about the
! SparseMatrix type and its storage of global and local row-and
! column indices.
!
! !REVISION HISTORY:
!  3May01 - J.W. Larson <larson@mcs.anl.gov> - initial version, which
!           is _extremely_ slow, but safe.  This must be re-examined
!           later.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GlobalSegMapToLocalMatrix_'


  integer :: i, GlobalIndex, gindex, lindex, lsize

   integer, allocatable :: temp_gindex(:)  !! rml
   integer, allocatable :: temp_lindex(:)  !! rml


       ! What are we re-indexing, rows or columns?

  select case(RCFlag)
  case('ROW','row')
     gindex = SparseMatrix_indexIA(sMat, 'grow', dieWith=myname_)
     lindex = SparseMatrix_indexIA(sMat,'lrow', dieWith=myname_)
  case('COLUMN','column')
     gindex = SparseMatrix_indexIA(sMat,'gcol', dieWith=myname_)
     lindex = SparseMatrix_indexIA(sMat,'lcol', dieWith=myname_)
  case default
     write(stderr,'(3a)') myname_,":: unrecognized value of RCFLag ",RCFlag
     call die(myname)
  end select


       ! How many matrix elements are there?

  lsize = SparseMatrix_lsize(sMat)


  !! rml new code from here down - do the mapping all in one
  !! function call which has been tuned for speed

  allocate( temp_gindex(lsize) )
  allocate( temp_lindex(lsize) )


  do i=1,lsize
     temp_gindex(i) = sMat%data%iAttr(gindex,i)
  end do

  call GlobalSegMapToIndexArr_(GSMap, temp_gindex, temp_lindex, lsize, comm)

  do i=1,lsize
    sMat%data%iAttr(lindex,i) = temp_lindex(i)
  end do


  deallocate(temp_gindex)  ! rml
  deallocate(temp_lindex)  ! rml


 end subroutine	GlobalSegMapToLocalMatrix_

 end module m_GlobalToLocal
