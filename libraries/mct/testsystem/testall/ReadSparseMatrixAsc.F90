!-------------------------------------------------------------------------
!     Math + Computer Science Division / Argonne National Laboratory     !
!-------------------------------------------------------------------------
! CVS $Id: ReadSparseMatrixAsc.F90,v 1.4 2004-06-15 19:16:08 eong Exp $
! CVS $Name:  $
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE:  ReadSparseMatrixAsc - Read in a SparseMatrix
!
! !INTERFACE:
 subroutine ReadSparseMatrixAsc(sMat, fileID, src_dims, dst_dims)
!
! !USES:

      use m_inpak90,      only : I90_LoadF
      use m_inpak90,      only : I90_Label
      use m_inpak90,      only : I90_Gstr
      use m_inpak90,      only : I90_Release
      use m_ioutil,       only : luavail
      use m_stdio,        only : stdout,stderr
      use m_die,          only : die

      use m_List,         only : List
      use m_List,         only : List_init => init
      use m_List,         only : List_clean => clean

      use m_AttrVect,     only : Attrvect_zero => zero
      use m_SparseMatrix, only : SparseMatrix
      use m_SparseMatrix, only : SparseMatrix_Init => init
      use m_SparseMatrix, only : SparseMatrix_Clean => clean
      use m_SparseMatrix, only : SparseMatrix_indexIA => indexIA
      use m_SparseMatrix, only : SparseMatrix_indexRA => indexRA
      use m_SparseMatrix, only : SparseMatrix_lsize => lsize
      use m_SparseMatrix, only : SparseMatrix_SortPermute => SortPermute
      use m_SparseMatrix, only : SMatrix_importGlobalRowInd => &
                                                      importGlobalRowIndices
      use m_SparseMatrix, only : SMatrix_importGlobalColumnInd => &
                                                      importGlobalColumnIndices
      use m_SparseMatrix, only : SMatrix_importMatrixElements => &
                                                           importMatrixElements

      implicit none
!
! !DESCRIPTION: This is the reader/tester driver for the Model
! Coupling Toolkit (mct) {\tt SparseMatrix} datatype.
!
! !INPUT PARAMETERS:

      character(len=*),   intent(in)  :: fileID

! !OUTPUT PARAMETERS:

      type(SparseMatrix),    intent(out) :: sMat
      integer, dimension(2), intent(out) :: src_dims
      integer, dimension(2), intent(out) :: dst_dims

!
!
! !BUGS:
!
! !SYSTEM ROUTINES:
!
! !FILES USED:
!
! !REVISION HISTORY:
!
!EOP
!-------------------------------------------------------------------------
!
 character(len=*), parameter :: myname = 'ReadSparseMatrixAsc'

 integer :: n,ierr

 integer :: mdev
 character*1024 :: filename, data_dir

 integer :: num_elements, nRows, nColumns
 integer, dimension(:), pointer :: rows, columns
 real, dimension(:),    pointer :: weights

! VARIABLES FOR TESTING !

! SparseMatrix attribute indices:
 integer :: igrow, igcol, iwgt
! SparseMatrix sorting key list:
 type(List) :: sort_keys
! Descending order flag array for SparseMatrix Sort test 2a.
 logical :: descending(2)

!------------------------------------------------
! Use mpeu resource file utilities to read in the name of the
! file with the weights
!
     call I90_LoadF("ut_SparseMatrix.rc", ierr)

     write(stdout,*) myname, ":: loaded ut_SparseMatrix.rc"

     call I90_Label("Data_Directory:", ierr)
     call I90_Gstr(data_dir, ierr)

     call I90_Label(trim(fileID), ierr)
     call I90_Gstr(filename, ierr)

     filename = trim(data_dir) // "/" // trim(filename)

     write(stdout,*) myname,":: remapfile path = ", trim(filename)

     call I90_Release(ierr)

     write(stdout,*) myname, ":: unloaded ut_SparseMatrix.rc"


!      First Activity:  Input of matrix elements from a file.
!------------------------------------------------
!  Go and actually read the weights.

       ! Find an empty f90 i/o device number

  mdev = luavail()

       ! Open the matrix file

  open(mdev, file=trim(filename), status='old')

       ! LINE 1:
       ! Read in the number of matrix elements, and allocate
       ! input buffer space:

  read(mdev,*) num_elements

  allocate(rows(num_elements), columns(num_elements), &
       weights(num_elements), stat=ierr)
  if(ierr /= 0) call die(myname,"allocate(row,col... failed",ierr)

       ! LINE 2:
       ! Read in the source grid dimensions

  read(mdev,*) src_dims(1), src_dims(2)

       ! LINE 3:
       ! Read in the destination grid dimensions

  read(mdev,*) dst_dims(1), dst_dims(2)


       ! Read in the row, column, and weight data:

  write(stdout,'(2a)')myname,":: Reading elements from file"
  do n=1, num_elements
     read(mdev,*) rows(n), columns(n), weights(n)
  end do
  write(stdout,'(2a)')myname,":: Done reading from file"

       ! Initialize sMat:
  nRows = dst_dims(1) * dst_dims(2)
  nColumns = src_dims(1) * src_dims(2)
  call SparseMatrix_init(sMat, nRows, nColumns, num_elements)
  call AttrVect_zero(sMat%data)

       ! ...and store them.

  call SMatrix_importGlobalRowInd(sMat, rows, size(rows))
  call SMatrix_importGlobalColumnInd(sMat, columns, size(columns))
  call SMatrix_importMatrixElements(sMat, weights, size(weights))

  deallocate(rows, columns, weights, stat=ierr)
  if(ierr/=0) call die(myname,':: deallocate(rows... failed',ierr)

!------------------------------------------------



!------------------------------------------------
!  Test features of the SparseMatrix module
!
!      Was everything read without incident?
!      You can answer this question by comparing the sample
!      values printed below with the results of a head and tail
!      on the ascii matrix file.

     igrow = SparseMatrix_indexIA(sMat, 'grow')
     igcol = SparseMatrix_indexIA(sMat, 'gcol')
     iwgt  = SparseMatrix_indexRA(sMat, 'weight')

     num_elements = SparseMatrix_lsize(sMat)

     write(stdout,*) myname, ":: Number of sMat elements= ",num_elements

     write(stdout,*) myname, ":: sMat%data%iAttr(igrow,1) = ",sMat%data%iAttr(igrow,1)
     write(stdout,*) myname, ":: sMat%data%iAttr(igcol,1) = ",sMat%data%iAttr(igcol,1)
     write(stdout,*) myname, ":: sMat%data%rAttr(iwgt,1) = ",sMat%data%rAttr(iwgt,1)


     write(stdout,*) myname, ":: sMat%data%iAttr(igrow,num_elements) = ", &
 	  sMat%data%iAttr(igrow,num_elements)
     write(stdout,*) myname, ":: sMat%data%iAttr(igcol,num_elements) = ", &
   sMat%data%iAttr(igcol,num_elements)
     write(stdout,*) myname, ":: sMat%data%rAttr(iwgt,num_elements) = ", &
 	  sMat%data%rAttr(iwgt,num_elements)

!      Second Activity:  Sorting

     call List_init(sort_keys,"grow:gcol")

     call SparseMatrix_SortPermute(sMat, sort_keys, descending)

!      Second Test Part a):  Did it work?

     write(stdout,*) myname, ":: Index sorting test results--descending:"

     write(stdout,*) myname, ":: sMat%data%iAttr(igrow,1) = ",sMat%data%iAttr(igrow,1)
     write(stdout,*) myname, ":: sMat%data%iAttr(igcol,1) = ",sMat%data%iAttr(igcol,1)

     write(stdout,*) myname, ":: sMat%data%iAttr(igrow,num_elements) = ", &
   sMat%data%iAttr(igrow,num_elements)
     write(stdout,*) myname, ":: sMat%data%iAttr(igcol,num_elements) = ", &
   sMat%data%iAttr(igcol,num_elements)

     write(stdout,*) myname, ":: End index sorting test results part a."


     call SparseMatrix_SortPermute(sMat,sort_keys)

!       Second Test Partb:  Did it work?

     write(stdout,*) myname, ":: Index sorting test results:--ascending"

     write(stdout,*) myname, ":: sMat%data%iAttr(igrow,1) = ",sMat%data%iAttr(igrow,1)
     write(stdout,*) myname, ":: sMat%data%iAttr(igcol,1) = ",sMat%data%iAttr(igcol,1)

     write(stdout,*) myname, ":: sMat%data%iAttr(igrow,num_elements) = ", &
   sMat%data%iAttr(igrow,num_elements)
     write(stdout,*) myname, ":: sMat%data%iAttr(igcol,num_elements) = ", &
   sMat%data%iAttr(igcol,num_elements)

     write(stdout,*) myname, ":: End index sorting test results."

     call List_clean(sort_keys)

! done testing
!------------------------------------------------

 end subroutine ReadSparseMatrixAsc
