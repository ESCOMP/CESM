!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: coupler.F90,v 1.6 2006-10-17 21:46:35 jacob Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !ROUTINE: coupler -- coupler for sequential model example
!
! !DESCRIPTION:
! A coupler subroutine for sequential climate model example.
!
! !INTERFACE:
!
module coupler
!
! !USES:
!
! Get the things needed from MCT by "Use,only" with renaming:
!
!---Domain Decomposition Descriptor DataType and associated methods
use m_GlobalSegMap,only: GlobalSegMap

!---Field Storage DataType and associated methods
use m_AttrVect,only    : AttrVect

!---Sparse Matrix DataType and associated methods
use m_SparseMatrix, only : SparseMatrix
use m_SparseMatrix, only : SparseMatrix_clean => clean
use m_SparseMatrix, only : SparseMatrix_init => init
use m_SparseMatrix, only : SparseMatrix_importGRowInd => &
                              importGlobalRowIndices
use m_SparseMatrix, only : SparseMatrix_importGColInd => &
                                    importGlobalColumnIndices
use m_SparseMatrix, only : SparseMatrix_importMatrixElts => &
                                   importMatrixElements
use m_SparseMatrixPlus, only : SparseMatrixPlus
use m_SparseMatrixPlus, only : SparseMatrixPlus_init => init
use m_SparseMatrixPlus, only : SparseMatrixPlus_clean => clean
use m_SparseMatrixPlus, only : Xonly ! Decompose matrix by row
!---Matrix-Vector multiply methods
use m_MatAttrVectMul, only: MCT_MatVecMul => sMatAvMult

!---MPEU I/O utilities
use m_stdio
use m_ioutil

implicit none

private

! !PUBLIC MEMBER FUNCTIONS:

public cplinit
public cplrun
public cplfin

! !PRIVATE DATA MEMBERS
type(SparseMatrixPlus) :: Src2DstMatPlus   ! the mapping weights

character(len=*), parameter :: cplname='coupler.F90'
integer :: rank

!EOP ___________________________________________________________________

contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: cplinit - initialize the coupler
!
! !INTERFACE:

subroutine cplinit(SrcGSMap,DstGSMap,comm,compid)

! !INPUT PARAMETERS:

  type(GlobalSegMap),intent(in) :: SrcGSMap,DstGSMap  ! GSmaps for source and dst
  integer,intent(in) :: comm    !  local MPI communicator
  integer,intent(in) :: compid  ! coupler's component ID
!
!EOP ___________________________________________________________________

!     Local variables
  character(len=100),parameter :: &
        RemapMatrixFile='../../data/t42_to_popx1_c_mat.asc'

! Loop indicies
  integer :: i,j,k,n

! MPI variables
  integer :: nprocs, root, ierr
! SparseMatrix variables
  integer :: mdev
  integer :: num_elements, nRows, nColumns
  integer, dimension(2) :: src_dims, dst_dims
  integer, dimension(:), pointer :: rows, columns
  real, dimension(:), pointer :: weights
! SparseMatrix elements on root
  type(SparseMatrix) :: sMat
! _____________________________________________________________________

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   INITIALIZATION PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


  ! LOCAL RANK AND SIZE
  call MPI_COMM_RANK(comm,rank,ierr)
  call MPI_COMM_SIZE(comm,nprocs,ierr)
  root = 0

  if(rank==0) write(6,*) cplname,' init start'
  if(rank==0) write(6,*) cplname,' MyID ', compid
  if(rank==0) write(6,*) cplname,' Num procs ', nprocs

  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! Read matrix weights for interpolation from a file.
  if (rank == root) then
     mdev = luavail()
     open(mdev, file=trim(RemapMatrixFile), status="old")
     read(mdev,*) num_elements
     read(mdev,*) src_dims(1), src_dims(2)
     read(mdev,*) dst_dims(1), dst_dims(2)

     allocate(rows(num_elements), columns(num_elements), &
          weights(num_elements), stat=ierr)

     do n=1, num_elements
        read(mdev,*) rows(n), columns(n), weights(n)
     end do

     close(mdev)

     ! Initialize a Sparsematrix
     nRows = dst_dims(1) * dst_dims(2)
     nColumns = src_dims(1) * src_dims(2)
     call SparseMatrix_init(sMat,nRows,nColumns,num_elements)
     call SparseMatrix_importGRowInd(sMat, rows, size(rows))
     call SparseMatrix_importGColInd(sMat, columns, size(columns))
     call SparseMatrix_importMatrixElts(sMat, weights, size(weights))

     deallocate(rows, columns, weights, stat=ierr)

  endif
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! Build a SparseMatrixPlus for doing the interpolation
  ! Specify matrix decomposition to be by row.
  ! following the atmosphere's decomposition.
  call SparseMatrixPlus_init(Src2DstMatPlus, sMat, SrcGSMap, DstGSMap, &
       Xonly, root, comm, compid)

  ! no longer need the matrix defined on root
  if(rank==0) call SparseMatrix_clean(sMat)
  if(rank==0) write(6,*) cplname, ' init done'


!!! END OF INIT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end subroutine cplinit

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   RUN PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: cplrun - coupler's run method

subroutine cplrun(IMPORT,EXPORT)

! !INPUT PARAMETERS:
  type(AttrVect),intent(in) :: IMPORT
  type(AttrVect),intent(out) :: EXPORT
!EOP -------------------------------------------------------------------

  if(rank==0) write(6,*) cplname, ' run start'

  ! Interpolate by doing a parallel sparsematrix-attrvect multiply
  ! Note:  this will interpolate all fields with the same names

  call MCT_MatVecMul(IMPORT, Src2DstMatPlus, EXPORT)

  ! possibly do more calculations

  if(rank==0) write(6,*) cplname, ' run done'
!!! END OF RUN  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end subroutine cplrun


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   FINALIZE PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: cplfin - coupler's finalize method

subroutine cplfin

!
!EOP -------------------------------------------------------------------

      call SparseMatrixPlus_clean(Src2DstMatPlus)
      if(rank==0) write(6,*) cplname, " done"
end subroutine cplfin

end module coupler

