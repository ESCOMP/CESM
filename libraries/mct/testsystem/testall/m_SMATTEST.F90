!
! !INTERFACE:

 module m_SMATTEST
!
! !USES:
!
      implicit none

      private	! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: testall
      public :: IndexAttr
      public :: SortPermute
      public :: ImportExport
      public :: Identical

    interface testall
       module procedure testsMat_
    end interface
    interface IndexAttr
       module procedure IndexTest_
    end interface
    interface SortPermute
       module procedure SortPermuteTest_
    end interface
    interface ImportExport
       module procedure ImportExportTest_
    end interface
    interface Identical
       module procedure Identical_
    end interface


! !REVISION HISTORY:
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='m_SMATTEST'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: sMattest_ - Test the functions in the SparseMatrix module
!
! !DESCRIPTION:
! This routine writes diagnostic information about the input
! {\tt SparseMatrix}. Each line of the output will be preceded by the
! character argument {\tt identifier}. The output device is specified
! by the integer argument {\tt device}.
!
! !INTERFACE:

 subroutine testsMat_(sMat, identifier, device, mycomm)

!
! !USES:
!
      use m_SparseMatrix         ! Use all SparseMatrix routines
      use m_stdio
      use m_die

      use m_realkinds, only : FP

      implicit none

! !INPUT PARAMETERS:

      type(SparseMatrix),         intent(in)  :: sMat
      character(len=*),           intent(in)  :: identifier
      integer,                    intent(in)  :: device
      integer, optional,          intent(in)  :: mycomm

! !REVISION HISTORY:
! 23Sep02 - E.T. Ong <eong@mcs.anl.gov> - initial prototype.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::sMattest_'
  integer :: i,j,k,ierr
  integer :: numrows, start, end
  real :: sparsity
  real, dimension(:), pointer     :: sums
  real, dimension(:), allocatable :: validsums
  logical :: rowsumcheck
  type(SparseMatrix) :: sMatExactCopy

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::MAKE A COPY:::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  call Copy(sMat=sMat,sMatCopy=sMatExactCopy)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::WRITE OUT INFO ABOUT THE ATTRVECT:::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  write(device,*) identifier, ":: Testing SparseMatrix Routines"
  write(device,*) identifier, ":: lsize = ", lsize(sMat)
  write(device,*) identifier, ":: nRows = ", nRows(sMat)
  write(device,*) identifier, ":: nCols = ", nCols(sMat)
  write(device,*) identifier, ":: vecinit = ", sMat%vecinit

  ! Add vecinit to smat_identical
  call CheckBounds(sMat,ierr)
  write(device,*) identifier, ":: CheckBounds ierror = ", ierr

  call local_row_range(sMat,start,end)

  write(device,*) identifier, ":: local_row_range (start_row, end_row) = ", &
       start,end

  call local_col_range(sMat,start,end)

  write(device,*) identifier, ":: local_col_ramge (start_col, end_col) = ", &
       start,end

  if(present(mycomm)) then

     write(device,*) identifier, ":: SINCE THE COMMUNICATOR ARGUMENT WAS &
          &PROVIDED, PLEASE ENSURE THAT THIS TEST IS BEING CALLED ON &
          &ALL PROCESSORS OF THIS COMPONENT AND THAT THE SPARSEMATRIX HAS&
          & BEEN SCATTERED."

     write(device,*) identifier, ":: GlobalNumElements = ", &
          GlobalNumElements(sMat,mycomm)

     call ComputeSparsity(sMat,sparsity,mycomm)
     write(device,*) identifier, ":: ComputeSparsity = ", sparsity

     call global_row_range(sMat,mycomm,start,end)

     write(device,*) identifier,":: global_row_range (start_row, end_row) = ",&
          start,end

     call global_col_range(sMat,mycomm,start,end)

     write(device,*) identifier,":: global_col_range (start_col, end_col) = ",&
          start,end

     call row_sum(sMat,numrows,sums,mycomm)
     write(device,*) identifier, ":: row_sum (size(sums),numrows,&
          &first,last,min,max) = ", &
          size(sums), numrows, sums(1), sums(size(sums)), &
          MINVAL(sums), MAXVAL(sums)

     allocate(validsums(2),stat=ierr)
     if(ierr/=0) call die(myname_,"allocate(validsums)",ierr)

     validsums(1)=0.
     validsums(2)=1.

     call row_sum_check(sMat=sMat,comm=mycomm,num_valid=2, &
                        valid_sums=validsums,abs_tol=1e-5,valid=rowsumcheck)

     write(device,*) identifier,":: row_sum_check = ", rowsumcheck

     deallocate(sums,validsums, stat=ierr)
     if(ierr/=0) call die(myname_,"deallocate(sums,validsums)",ierr)

  endif

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::TESTING INDEXIA AND GETILIST::::::::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  call IndexTest_(sMat,identifier,device)


!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TESTING SORT AND PERMUTE:::::::::::::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

! NOTE: THIS IS NOT A CHECK FOR CORRECTNESS, JUST A CHECK FOR CONSISTENCY

  call SortPermuteTest_(sMat,identifier,device)

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TESTING EXPORT AND IMPORT FUNCTIONS:::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
  call ImportExportTest_(sMat,identifier,device)

  ! Check that sMat is unchanged!

  if(.NOT.Identical(sMat,sMatExactCopy,1e-5)) then
     call die(myname_,"sMat unexpectedly altered!!!")
  endif

  call clean(sMatExactCopy)

end subroutine testsMat_

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::TEST FOR INDEXIA AND GETILIST::::::::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  subroutine IndexTest_(sMat,identifier,device)

    use m_SparseMatrix
    use m_AttrVect, only: getIList, getRList
    use m_AttrVect, only: nIAttr, nRAttr
    use m_List,   only: List_allocated   => allocated
    use m_String, only: String
    use m_String, only: StringToChar     => toChar
    use m_String, only: String_clean     => clean
    use m_stdio
    use m_die

    implicit none

    type(SparseMatrix),         intent(in)  :: sMat
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::IndexTest_'
    type(String) :: ItemStr
    integer :: i,j,k,ierr

    if(nIAttr(sMat%data)>0) then
       write(device,*) identifier, ":: Testing indexIA ::"
    else
       if(List_allocated(sMat%data%iList)) then
          call die(myname_,"iList has been allocated, :&
               &but there are no atttributes. :&
               &Please do not initialize a blank list.")
       end if
       if(associated(sMat%data%iAttr)) then
          if(size(sMat%data%iAttr,1) /= 0) then
             call die(myname_,"iAttr contains no attributes, &
                  &yet its size /= 0",size(sMat%data%iAttr,1))
          endif
       endif
    end if

    do i=1,nIAttr(sMat%data)

       call getIList(ItemStr,i,sMat%data)
       j = indexIA(sMat,StringToChar(ItemStr))
       if(i/=j) call die(myname_,"Function indexIA failed!")
       write(device,*) identifier, &
            ":: sMat Index = ", j,      &
            ":: Attribute Name = ", StringToChar(ItemStr)
       call String_clean(ItemStr)

    enddo

    if(nRAttr(sMat%data)>0) then
       write(device,*) identifier, ":: Testing indexRA::"
    else
       if(List_allocated(sMat%data%rList)) then
          call die(myname_,"rList has been allocated, :&
               &but there are no atttributes. :&
               &Please do not initialize a blank list.")
       end if
       if(associated(sMat%data%rAttr)) then
          if(size(sMat%data%rAttr,1) /= 0) then
             call die(myname_,"rAttr contains no attributes, &
                  &yet its size /= 0",size(sMat%data%rAttr,1))
          endif
       endif
    end if

    do i=1,nRAttr(sMat%data)

       call getRList(ItemStr,i,sMat%data)
       j = indexRA(sMat,StringToChar(ItemStr))
       if(i/=j) call die(myname_,"Function indexIA failed!")
       write(device,*) identifier,   &
            "::sMat Index = ", j,      &
            "::Attribute Name = ", StringToChar(ItemStr)
       call String_clean(ItemStr)

    enddo

  end subroutine IndexTest_

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TEST FOR SORT AND PERMUTE:::::::::::::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

! NOTE: THIS IS NOT A CHECK FOR CORRECTNESS, JUST A CHECK FOR CONSISTENCY

  subroutine SortPermuteTest_(sMat,identifier,device)

    use m_SparseMatrix
    use m_AttrVect, only : nIAttr, nRAttr, Zero
    use m_stdio
    use m_die

    use m_realkinds, only : FP

    implicit none

    type(SparseMatrix),         intent(in)  :: sMat
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::SortPermuteTest_'
    type(SparseMatrix) :: SMATCOPY1, SMATCOPY2
    logical,dimension(:), pointer :: descend
    integer,dimension(:), pointer :: perm
    integer :: i,j,k,ierr
    real :: r

    write(device,*) identifier, ":: Testing Sort and Permute"

    call init(SMATCOPY1,sMat%nrows,sMat%ncols,lsize(sMat))
    call init(SMATCOPY2,sMat%nrows,sMat%ncols,lsize(sMat))

    if( (nIAttr(SMATCOPY1%data)>0) .or. &
         (nRAttr(SMATCOPY1%data)>0) ) then

    if(nIAttr(SMATCOPY1%data)>0) then

       allocate(descend(nIAttr(SMATCOPY1%data)),stat=ierr)
       if(ierr /= 0) call die(myname_,"allocate(descend)")

       call Zero(SMATCOPY1%data)
       call Zero(SMATCOPY2%data)

       k=0
       do i=1,nIAttr(SMATCOPY1%data)
          do j=1,lsize(SMATCOPY1)
             k=k+1
             SMATCOPY1%data%iAttr(i,j) = k
             SMATCOPY2%data%iAttr(i,j) = k
          enddo
       enddo

       descend=.true.
       call Sort(sMat=SMATCOPY1,key_list=SMATCOPY1%data%iList,perm=perm,descend=descend)
       call Permute(sMat=SMATCOPY1,perm=perm)

       call SortPermute(sMat=SMATCOPY2,key_list=SMATCOPY2%data%iList,descend=descend)

       do i=1,nIAttr(SMATCOPY1%data)
          do j=1,lsize(SMATCOPY1)
             if(SMATCOPY1%data%iAttr(i,j) /= SMATCOPY2%data%iAttr(i,j)) then
                call die(myname_,"Sort Testing FAILED!")
             endif
          enddo
       enddo

       write(device,*) identifier, ":: Integer SparseMatrix data IN DESCENDING ORDER:: ", &
            SMATCOPY1%data%iAttr(1,1:5)

       deallocate(perm,stat=ierr)
       if(ierr /= 0) call die(myname_,"deallocate(perm)")

       deallocate(descend,stat=ierr)
       if(ierr /= 0) call die(myname_,"deallocate(descend)")

    endif

    if(nRAttr(SMATCOPY1%data)>0) then

       allocate(descend(nRAttr(SMATCOPY1%data)),stat=ierr)
       if(ierr /= 0) call die(myname_,"allocate(descend)")

       call Zero(SMATCOPY1%data)
       call Zero(SMATCOPY2%data)

       r=0.
       do i=1,nRAttr(SMATCOPY1%data)
          do j=1,lsize(SMATCOPY1)
             r=r+1.29
             SMATCOPY1%data%rAttr(i,j) = r
             SMATCOPY2%data%rAttr(i,j) = r
          enddo
       enddo

       descend=.true.
       call Sort(sMat=SMATCOPY1,key_list=SMATCOPY1%data%rList,perm=perm,descend=descend)
       call Permute(sMat=SMATCOPY1,perm=perm)

       call SortPermute(sMat=SMATCOPY2,key_list=SMATCOPY2%data%rList,descend=descend)

       do i=1,nRAttr(SMATCOPY1%data)
          do j=1,lsize(SMATCOPY1)
             if(SMATCOPY1%data%rAttr(i,j) /= SMATCOPY2%data%rAttr(i,j)) then
                call die(myname_,"Sort Testing FAILED!")
             endif
          enddo
       enddo

       write(device,*) identifier, ":: REAL SparseMatrix data IN DESCENDING ORDER:: ", &
            SMATCOPY1%data%rAttr(1,1:5)

       deallocate(perm,stat=ierr)
       if(ierr /= 0) call die(myname_,"deallocate(perm)")

       deallocate(descend,stat=ierr)
       if(ierr /= 0) call die(myname_,"deallocate(descend)")

    endif
    else
    write(device,*) identifier, ":: NOT TESTING SORTING AND PERMUTING. CONSULT &
         &SOURCE CODE TO ENABLE TESTING."
    endif

    call clean(SMATCOPY1)
    call clean(SMATCOPY2)

  end subroutine SortPermuteTest_


!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TEST FOR EXPORT AND IMPORT FUNCTIONS:::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

  subroutine ImportExportTest_(sMat,identifier,device)

    use m_SparseMatrix

    use m_List,     only   : List
    use m_List,     only   : List_identical   => identical
    use m_List,     only   : List_get         => get
    use m_List,     only   : List_clean       => clean
    use m_String,   only   : String
    use m_String,   only   : StringToChar     => toChar
    use m_String,   only   : String_clean     => clean
    use m_stdio
    use m_die

    use m_realkinds, only : FP

    implicit none

    type(SparseMatrix),         intent(in)  :: sMat
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::ImportExportTest_'
    integer :: i,j,k,ierr
    real :: r

    type(SparseMatrix) :: sMatCopy
    integer :: size
    integer, dimension(:), pointer :: GlobalRows, GlobalColumns
    integer, dimension(:), pointer :: LocalRows, LocalColumns
    integer, dimension(:), pointer :: importIVect
    real(FP), dimension(:), pointer :: importRVect
    real(FP), dimension(:), pointer :: MatrixElements

    write(device,*) identifier, ":: Testing import and export functions"

    nullify(GlobalRows)
    nullify(GlobalColumns)
    nullify(LocalRows)
    nullify(LocalColumns)
    nullify(MatrixElements)
    nullify(importIVect)
    nullify(importRVect)

    call exportGlobalRowIndices(sMat,GlobalRows,size)
    if(.NOT.aVEqualsMat_(sMat=sMat,ivector=GlobalRows,attribute="grow")) then
       call die(myname_,"exportGlobalRowIndices failed")
    endif

    call exportGlobalColumnIndices(sMat,GlobalColumns,size)
    if(.NOT.aVEqualsMat_(sMat=sMat,ivector=GlobalColumns,attribute="gcol")) then
       call die(myname_,"exportGlobalColumnIndices failed")
    endif

    call exportLocalRowIndices(sMat,LocalRows,size)
    if(.NOT.aVEqualsMat_(sMat=sMat,ivector=LocalRows,attribute="lrow")) then
       call die(myname_,"exportLocalRowIndices failed")
    endif

    call exportLocalColumnIndices(sMat,LocalColumns,size)
    if(.NOT.aVEqualsMat_(sMat=sMat,ivector=LocalColumns,attribute="lcol")) then
       call die(myname_,"exportLocalColumnIndices failed")
    endif

    call exportMatrixElements(sMat,MatrixElements,size)
    if(.NOT.aVEqualsMat_(sMat=sMat,rvector=MatrixElements,attribute="weight")) then
       call die(myname_,"exportMatrixElements failed")
    endif

    call init(sMatCopy,sMat%nrows,sMat%ncols,lsize(sMat))

    allocate(importIVect(lsize(sMat)),importRVect(lsize(sMat)),stat=ierr)
    if(ierr/=0) call die(myname_,"llocate(importVect)",ierr)

    r=0.
    do i=1,lsize(sMat)
       r=r+1.1
       importIVect(i) = i
       importRVect(i) = r
    enddo

    call importGlobalRowIndices(sMatCopy,importIVect,lsize(sMat))
    if(.NOT.aVEqualsMat_(sMat=sMatCopy,ivector=importIVect,attribute="grow")) then
       call die(myname_,"importGlobalRowIndices failed")
    endif

    call importGlobalColumnIndices(sMatCopy,importIVect,lsize(sMat))
    if(.NOT.aVEqualsMat_(sMat=sMatCopy,ivector=importIVect,attribute="gcol")) then
       call die(myname_,"importGlobalColumnIndices failed")
    endif

    call importLocalRowIndices(sMatCopy,importIVect,lsize(sMat))
    if(.NOT.aVEqualsMat_(sMat=sMatCopy,ivector=importIVect,attribute="lrow")) then
       call die(myname_,"importLocalRowIndices failed")
    endif

    call importLocalColumnIndices(sMatCopy,importIVect,lsize(sMat))
    if(.NOT.aVEqualsMat_(sMat=sMatCopy,ivector=importIVect,attribute="lcol")) then
       call die(myname_,"importLocalColumnIndices failed")
    endif

    call importMatrixElements(sMatCopy,importRVect,lsize(sMat))
    if(.NOT.aVEqualsMat_(sMat=sMatCopy,rvector=importRVect,attribute="weight")) then
       call die(myname_,"importMatrixElements failed")
    endif

    call clean(sMatCopy)

    deallocate(GlobalRows,GlobalColumns,LocalRows,LocalColumns, &
         importIVect, importRVect,MatrixElements,stat=ierr)
    if(ierr/=0) call die(myname_,"deallocate(Global....)",ierr)

  contains

    logical function aVEqualsMat_(sMat,ivector,rvector,attribute)

      use m_SparseMatrix
      use m_stdio
      use m_die

      use m_realkinds, only : FP

      implicit none

      type(SparseMatrix),         intent(in)   :: sMat
      integer, dimension(:), pointer, optional :: ivector
      real(FP), dimension(:), pointer, optional    :: rvector
      character(len=*),           intent(in)   :: attribute

      integer :: i, attribute_index

      aVEqualsMat_ = .TRUE.

      if(present(ivector)) then

         attribute_index = indexIA(sMat,trim(attribute))

         do i=1,lsize(sMat)
            if(sMat%data%iAttr(attribute_index,i) /= ivector(i)) then
               aVEqualsMat_ = .FALSE.
               EXIT
            endif
         enddo

      else

         if(present(rvector)) then

            attribute_index = indexRA(sMat,trim(attribute))

            do i=1,lsize(sMat)
               if(sMat%data%rAttr(attribute_index,i) /= rvector(i)) then
                  aVEqualsMat_ = .FALSE.
                  EXIT
               endif
            enddo

         else

            call die("aVEqualsMat_::","ivector or rvector must be present")

         endif

      endif

    end function aVEqualsMat_

  end subroutine ImportExportTest_

  logical function Identical_(SMAT1,SMAT2,Range)

    use m_SparseMatrix
    use m_AVTEST,only: AttrVect_identical => Identical
    use m_List,only : List_allocated => allocated
    use m_List,only : List_identical => identical
    use m_stdio
    use m_die

    use m_realkinds, only : FP

    implicit none

    type(SparseMatrix), intent(in) :: SMAT1
    type(SparseMatrix), intent(in) :: SMAT2
    real, optional,     intent(in) :: Range

    integer :: i,j,k

    Identical_=.true.

    if(present(Range)) then
       if(.NOT. AttrVect_identical(SMAT1%data,SMAT2%data,Range)) then
          Identical_=.false.
       endif
    else
       if(.NOT. AttrVect_identical(SMAT1%data,SMAT2%data)) then
          Identical_=.false.
       endif
    endif

    if(SMAT1%nrows /= SMAT2%nrows) then
       Identical_=.false.
    endif

    if(SMAT1%ncols /= SMAT2%ncols) then
       Identical_=.false.
    endif

    if(SMAT1%vecinit .neqv. SMAT2%vecinit) then
       Identical_=.false.
    endif

  end function Identical_

end module m_SMATTEST
