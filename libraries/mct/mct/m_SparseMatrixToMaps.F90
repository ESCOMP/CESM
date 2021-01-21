!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_SparseMatrixToMaps -- Maps from the Sparse Matrix
!
! !DESCRIPTION:
! The {\tt SparseMatrix} provides consolidated (on one process) or
! distributed sparse matrix storage for the operation
! ${\bf y} = {\bf M} {\bf x}$, where {\bf x} and {\bf y} are vectors,
! and {\bf M} is a matrix.  In performing parallel matrix-vector
! multiplication, one has numerous options regarding the decomposition
! of the matrix {\bf M}, and the vectors {\bf y} and {\bf x}.
! This module provides services to generate mct mapping components---the
! {\tt GlobalMap} and {\tt GlobalSegMap} for the vectors {\bf y} and/or
! {\bf x} based on the decomposition of the sparse matrix {\bf M}.
!
! !INTERFACE:

 module m_SparseMatrixToMaps
!
! !USES:
!
      use m_SparseMatrix, only : SparseMatrix

      implicit none

      private   ! except

      public :: SparseMatrixToXGlobalSegMap
      public :: SparseMatrixToYGlobalSegMap

    interface SparseMatrixToXGlobalSegMap ; module procedure &
	 SparseMatrixToXGlobalSegMap_
    end interface

    interface SparseMatrixToYGlobalSegMap ; module procedure &
	 SparseMatrixToYGlobalSegMap_
    end interface

! !REVISION HISTORY:
! 13Apr01 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
!           and API specifications.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_SparseMatrixToMaps'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: SparseMatrixToXGlobalSegMap_ - Generate X GlobalSegmap.
!
! !DESCRIPTION:  Given an input {\tt SparseMatrix} argument {\tt sMat},
! this routine generates an output {\tt GlobalSegMap} variable
! {\tt xGSMap}, which describes the domain decomposition of the vector
! {\bf x} in the distributed matrix-vector multiplication
! $${\bf y} = {\bf M} {\bf x}.$$
!
! !INTERFACE:

 subroutine SparseMatrixToXGlobalSegMap_(sMat, xGSMap, root, comm, comp_id)
!
! !USES:
!
      use m_stdio, only : stderr
      use m_die,   only : die
      use m_mpif90

      use m_List, only : List
      use m_List, only : List_init => init
      use m_List, only : List_clean => clean

      use m_SparseMatrix, only : SparseMatrix
      use m_SparseMatrix, only : SparseMatrix_nCols => nCols
      use m_SparseMatrix, only : SparseMatrix_lsize => lsize
      use m_SparseMatrix, only : SparseMatrix_indexIA => indexIA
      use m_SparseMatrix, only : SparseMatrix_SortPermute => SortPermute

      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_init => init

      implicit none

! !INPUT PARAMETERS:
!
      integer,            intent(in)    :: root    ! communicator root
      integer,            intent(in)    :: comm    ! communicator handle
      integer,            intent(in)    :: comp_id ! component id

! !INPUT/OUTPUT PARAMETERS:
!
      type(SparseMatrix), intent(inout) :: sMat    ! input SparseMatrix

! !OUTPUT PARAMETERS:
!
      type(GlobalSegMap), intent(out)   :: xGSMap  ! segmented decomposition
                                                   ! for x
! !REVISION HISTORY:
! 13Apr01 - J.W. Larson <larson@mcs.anl.gov> - API specification.
! 25Apr01 - J.W. Larson <larson@mcs.anl.gov> - First version.
! 27Apr01 - J.W. Larson <larson@mcs.anl.gov> - Bug fix--intent of
!           argument sMat changed from (IN) to (INOUT)
! 27Apr01 - R.L. Jacob <jacob@mcs.anl.gov> - bug fix-- add use
!           statement for SortPermute
! 01May01 - R.L. Jacob <jacob@mcs.anl.gov> - make comp_id an
!           input argument
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::SparseMatrixToXGlobalSegMap_'

! SparseMatrix attributes:
  integer :: lsize
! GlobalSegMap input attributes:
  integer :: gsize, ngseg
  integer, dimension(:), pointer :: starts, lengths
! Temporary array for identifying each matrix element column and
! process ID destination
  integer, dimension(:), allocatable :: gCol, element_pe_locs
! Index to identify the gcol attribute in sMat:
  integer :: igCol
! Matrix element sorting keys list:
  type(List) :: sort_keys
! Loop index and error flag:
  integer :: i, ierr

       ! Determine he local number of matrix elements lsize

  lsize = SparseMatrix_lsize(sMat)

       ! The value of gsize is taken from the number of columns in sMat:

  gsize = SparseMatrix_nCols(sMat)

       ! Sort SparseMatrix entries by global column index gcol, then
       ! global row index.

       ! Create Sort keys list

  call List_init(sort_keys,'gcol:grow')

       ! Sort and permute the entries of sMat into lexicographic order
       ! by global column, then global row.

  call SparseMatrix_SortPermute(sMat, sort_keys)

       ! Clean up sort keys list

  call List_clean(sort_keys)

       ! Allocate storage space for matrix element column indices and
       ! process ID destinations

  allocate(gCol(lsize), stat=ierr)

  if(ierr /= 0) then
     call die(myname_,'allocate(gCol...',ierr)
  endif

       ! Extract global column information and place in array gCol

  igCol = SparseMatrix_indexIA(sMat, 'gcol', dieWith=myname_)

  do i=1, lsize
     gCol(i) = sMat%data%iAttr(igCol,i)
  end do

       ! Scan sorted entries of gCol to count segments (ngseg), and
       ! their starting indices and lengths (returned in the arrays
       ! starts(:) and lengths(:), respectively)

  call ComputeSegments_(gCol, lsize, ngseg, starts, lengths)

       ! Now we have sufficient data to call the GlobalSegMap
       ! initialization using distributed data:

  call GlobalSegMap_init(xGSMap, starts, lengths, root, comm, &
                         comp_id, gsize=gsize)

       ! clean up temporary arrays gCol(:), starts(:) and lengths(:),
       ! (the latter two were allocated in the call to the routine
       ! ComputeSegments_())

  deallocate(gCol, starts, lengths, stat=ierr)

  if(ierr /= 0) then
     call die(myname_,'deallocate(gCol...',ierr)
  endif

 end subroutine SparseMatrixToXGlobalSegMap_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: SparseMatrixToYGlobalSegMap_ - Generate Y GlobalSegmap.
!
! !DESCRIPTION:  Given an input {\tt SparseMatrix} argument {\tt sMat},
! this routine generates an output {\tt GlobalSegMap} variable
! {\tt yGSMap}, which describes the domain decomposition of the vector
! {\bf y} in the distributed matrix-vector multiplication
! ${\bf y} = {\bf M} {\bf x}$.
!
! !INTERFACE:

 subroutine SparseMatrixToYGlobalSegMap_(sMat, yGSMap, root, comm, comp_id)
!
! !USES:
!
      use m_stdio, only : stderr
      use m_die,   only : die

      use m_List, only : List
      use m_List, only : List_init => init
      use m_List, only : List_clean => clean

      use m_SparseMatrix, only : SparseMatrix
      use m_SparseMatrix, only : SparseMatrix_nRows => nRows
      use m_SparseMatrix, only : SparseMatrix_lsize => lsize
      use m_SparseMatrix, only : SparseMatrix_indexIA => indexIA
      use m_SparseMatrix, only : SparseMatrix_SortPermute => SortPermute

      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_init => init

      implicit none

! !INPUT PARAMETERS:
!
      integer,            intent(in)    :: root    ! communicator root
      integer,            intent(in)    :: comm    ! communicator handle
      integer,            intent(in)    :: comp_id ! component id

! !INPUT/OUTPUT PARAMETERS:
!
      type(SparseMatrix), intent(inout) :: sMat    ! input SparseMatrix

! !OUTPUT PARAMETERS:
!
      type(GlobalSegMap), intent(out)   :: yGSMap  ! segmented decomposition
                                                   ! for y
! !REVISION HISTORY:
! 13Apr01 - J.W. Larson <larson@mcs.anl.gov> - API specification.
! 25Apr01 - J.W. Larson <larson@mcs.anl.gov> - initial code.
! 27Apr01 - J.W. Larson <larson@mcs.anl.gov> - Bug fix--intent of
!           argument sMat changed from (IN) to (INOUT)
! 27Apr01 - R.L. Jacob <jacob@mcs.anl.gov> - bug fix-- add use
!           statement for SortPermute
! 01May01 - R.L. Jacob <jacob@mcs.anl.gov> - make comp_id an
!           input argument
! 07May02 - J.W. Larson <larson@mcs.anl.gov> - Changed interface to
!           make it consistent with SparseMatrixToXGlobalSegMap_().
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::SparseMatrixToYGlobalSegMap_'

! SparseMatrix attributes:
  integer :: lsize
! GlobalSegMap input attributes:
  integer :: gsize, ngseg
  integer, dimension(:), pointer :: starts, lengths
! Temporary array for identifying each matrix element column and
! process ID destination
  integer, dimension(:), allocatable :: gRow, element_pe_locs
! Index to identify the gRow attribute in sMat:
  integer :: igRow
! Matrix element sorting keys list:
  type(List) :: sort_keys
! Loop index and error flag:
  integer :: i, ierr

       ! Determine he local number of matrix elements lsize

  lsize = SparseMatrix_lsize(sMat)

       ! The value of gsize is taken from the number of columns in sMat:

  gsize = SparseMatrix_nRows(sMat)

       ! Sort SparseMatrix entries by global column index grow, then
       ! global row index.

       ! Create Sort keys list

  call List_init(sort_keys,'grow:gcol')

       ! Sort and permute the entries of sMat into lexicographic order
       ! by global column, then global row.

  call SparseMatrix_SortPermute(sMat, sort_keys)

       ! Clean up sort keys list

  call List_clean(sort_keys)

       ! Allocate storage space for matrix element column indices and
       ! process ID destinations

  allocate(gRow(lsize), stat=ierr)

  if(ierr /= 0) then
     call die(myname_,'allocate(gRow...',ierr)
  endif

       ! Extract global column information and place in array gRow

  igRow = SparseMatrix_indexIA(sMat,'grow', dieWith=myname_)

  do i=1, lsize
     gRow(i) = sMat%data%iAttr(igRow,i)
  end do

       ! Scan sorted entries of gRow to count segments (ngseg), and
       ! their starting indices and lengths (returned in the arrays
       ! starts(:) and lengths(:), respectively)

  call ComputeSegments_(gRow, lsize, ngseg, starts, lengths)

       ! Now we have sufficient data to call the GlobalSegMap
       ! initialization using distributed data:

  call GlobalSegMap_init(yGSMap, starts, lengths, root, comm, &
                         comp_id, gsize=gsize)

       ! clean up temporary arrays gRow(:), starts(:) and lengths(:),
       ! (the latter two were allocated in the call to the routine
       ! ComputeSegments_())

  deallocate(gRow, starts, lengths, stat=ierr)

  if(ierr /= 0) then
     call die(myname_,'deallocate(gRow...',ierr)
  endif

 end subroutine SparseMatrixToYGlobalSegMap_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: CreateSegments_ - Generate segment information.
!
! !DESCRIPTION:  This routine examines an input {\tt INTEGER} list of
! numbers {\tt indices} (of length {\tt num\_indices}), determines the
! number of segments of consecutive numbers (or runs) {\tt nsegs}.  The
! starting indices for each run, and their lengths are returned in the
! {\tt INTEGER} arrays {\tt starts(:)} and {\tt lengths(:)}, respectively.
!
! !INTERFACE:

 subroutine ComputeSegments_(indices, num_indices, nsegs, starts, lengths)

!
! !USES:
!
      use m_stdio, only : stderr
      use m_die,   only : die

      implicit none
!
! !INPUT PARAMETERS:
!

      integer, dimension(:), intent(in)  :: indices
      integer,               intent(in)  :: num_indices
!
! !OUTPUT PARAMETERS:
!
      integer,               intent(out) :: nsegs
      integer, dimension(:), pointer     :: starts
      integer, dimension(:), pointer     :: lengths


! !REVISION HISTORY:
! 19Apr01 - J.W. Larson <larson@mcs.anl.gov> - API specification.
! 25Apr01 - J.W. Larson <larson@mcs.anl.gov> - Initial code.
! 27Apr01 - J.W. Larson <larson@mcs.anl.gov> - Bug fix--error in
!           computation of segment starts/lengths.
! 27Nov01 - E.T. Ong <eong@mcs.anl.gov> - Bug fix--initialize
!           nsegs=0 in case num_indices=0.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ComputeSegments_'

  integer :: i, ierr

       ! First pass:  count the segments

  nsegs = 0

  do i=1,num_indices

     if(i == 1) then ! bootstrap segment counting process

	nsegs = 1

     else

	if(indices(i) > indices(i-1) + 1) then ! new segment
	   nsegs = nsegs + 1
	endif

     endif ! if(i==1)

  end do ! do i=1, num_indices

       ! Allocate storage space for starts(:) and lengths(:)

  allocate(starts(nsegs), lengths(nsegs), stat=ierr)

  if(ierr /= 0) then
     call die(myname_,'allocate(starts...',ierr)
  endif

       ! Second pass:  compute segment start/length info

  do i=1,num_indices

     select case(i)
     case(1)  ! bootstrap segment counting process
	nsegs = 1
	starts(nsegs) = indices(i)
! rml patch
        lengths(nsegs) = 1
     case default

	if(i == num_indices) then ! last point
	   if(indices(i) > indices(i-1) + 1) then ! new segment with 1 pt.
       ! first, close the books on the penultimate segment:
	      lengths(nsegs) = indices(i-1) - starts(nsegs) + 1
	      nsegs = nsegs + 1
	      starts(nsegs) = indices(i)
	      lengths(nsegs) = 1  ! (just one point)
	   else
	      lengths(nsegs) = indices(i) - starts(nsegs) + 1
	   endif
	else
	   if(indices(i) > indices(i-1) + 1) then ! new segment
	      lengths(nsegs) = indices(i-1) - starts(nsegs) + 1
	      nsegs = nsegs + 1
	      starts(nsegs) = indices(i)
	   endif
	endif

     end select ! select case(i)

  end do ! do i=1, num_indices

 end subroutine ComputeSegments_

 end  module m_SparseMatrixToMaps
