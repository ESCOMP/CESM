!
! !INTERFACE:

 module m_GGRIDTEST
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
       module procedure testGGrid_
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

  character(len=*),parameter :: myname='m_GGridTest'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: testGGRID_ - Test the functions in the GeneralGrid module
!
! !DESCRIPTION:
! This routine writes diagnostic information about the input
! {\tt GeneralGrid}. Each line of the output will be preceded by the
! character argument {\tt identifier}. The output device is specified
! by the integer argument {\tt device}.
!
! !INTERFACE:

 subroutine testGGrid_(GGrid, identifier, device)

!
! !USES:
!
      use m_GeneralGrid, only: GeneralGrid,init,clean,dims,lsize         ! Use all GeneralGrid routines
      use m_List, only : ListExportToChar => exportToChar
      use m_List, only : List_allocated => allocated
      use m_AttrVect, only : AttrVect_copy => copy
      use m_stdio
      use m_die

      implicit none

! !INPUT PARAMETERS:

      type(GeneralGrid),          intent(in)  :: GGrid
      character(len=*),           intent(in)  :: identifier
      integer,                    intent(in)  :: device

! !REVISION HISTORY:
! 23Sep02 - E.T. Ong <eong@mcs.anl.gov> - initial prototype.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GGridtest_'
  type(GeneralGrid) :: GGridExactCopy1, GGridExactCopy2
  integer :: i,j,k
  logical :: calledinitl_

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::WRITE OUT INFO ABOUT THE ATTRVECT:::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  write(device,*) identifier, ":: TYPE CHECK"

  if(List_allocated(GGrid%coordinate_list)) then
     write(device,*) identifier, ":: COORDINATE_LIST = ", &
          ListExportToChar(GGrid%coordinate_list)
  else
     call die(myname_,"COORDINATE_LIST IS NOT INITIALIZED!")
  endif

  if(List_allocated(GGrid%coordinate_sort_order)) then
     write(device,*) identifier, ":: COORDINATE_SORT_ORDER = ", &
          ListExportToChar(GGrid%coordinate_sort_order)
  else
     write(device,*) identifier, ":: COORDINATE_SORT_ORDER NOT INITIALIZED"
  endif

  if(associated(GGrid%descend)) then
     write(device,*) identifier, ":: DESCEND = ", &
          size(GGrid%descend), GGrid%descend
  else
     write(device,*) identifier, ":: DESCEND NOT ASSOCIATED"
  endif

  if(List_allocated(GGrid%weight_list)) then
     write(device,*) identifier, ":: WEIGHT_LIST = ", &
          ListExportToChar(GGrid%weight_list)
  else
     write(device,*) identifier, ":: WEIGHT_LIST NOT INITIALIZED"
  endif

  if(List_allocated(GGrid%other_list)) then
     write(device,*) identifier, ":: OTHER_LIST = ", &
          ListExportToChar(GGrid%other_list)
  else
     write(device,*) identifier, ":: OTHER_LIST NOT INITIALIZED"
  endif

  if(List_allocated(GGrid%index_list)) then
     write(device,*) identifier, ":: INDEX_LIST = ", &
          ListExportToChar(GGrid%index_list)
  else
     write(device,*) identifier, ":: INDEX_LIST NOT INITIALIZED"
  endif

  if(List_allocated(GGrid%data%iList)) then
     write(device,*) identifier, ":: DATA%ILIST = ", &
          ListExportToChar(GGrid%data%iList)
  else
    write(device,*) identifier, ":: DATA%ILIST NOT INITIALIZED"
  endif

  if(List_allocated(GGrid%data%rList)) then
     write(device,*) identifier, ":: DATA%RLIST = ", &
          ListExportToChar(GGrid%data%rList)
  else
     write(device,*) identifier, ":: DATA%RLIST NOT INITIALIZED"
  endif

  write(device,*) identifier, ":: DIMS = ", dims(GGrid)
  write(device,*) identifier, ":: LSIZE = ", lsize(GGrid)

  call init(GGridExactCopy1,GGrid,lsize(GGrid))
  call AttrVect_copy(aVin=GGrid%data,aVout=GGridExactCopy1%data)

  calledinitl_=.false.

  if( ((((List_allocated(GGrid%coordinate_sort_order).AND.&
       List_allocated(GGrid%weight_list)).AND.&
       List_allocated(GGrid%other_list)).AND.&
       List_allocated(GGrid%index_list)).AND.&
       ASSOCIATED(GGrid%descend)) ) then
     calledinitl_=.true.
     call init(GGrid=GGridExactCopy2,&
          CoordList=GGrid%coordinate_list, &
          CoordSortOrder=GGrid%coordinate_sort_order, &
          descend=GGrid%descend, &
          WeightList=GGrid%weight_list, &
          OtherList=GGrid%other_list, &
          IndexList=GGrid%index_list, &
          lsize=lsize(GGrid))
     call AttrVect_copy(aVin=GGrid%data,aVout=GGridExactCopy2%data)
  else
     write(device,*) identifier, ":: NOT TESTING INIL_. PLEASE &
          &CONSULT SOURCE CODE."
  endif

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::TESTING INDEXIA AND GETILIST::::::::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  call IndexTest_(GGrid,identifier,device)


!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TESTING SORT AND PERMUTE:::::::::::::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

! NOTE: THIS IS NOT A CHECK FOR CORRECTNESS, JUST A CHECK FOR CONSISTENCY

  call SortPermuteTest_(GGrid,identifier,device)

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TESTING EXPORT AND IMPORT FUNCTIONS::::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

  call ImportExportTest_(GGrid,identifier,device)

  ! Check that GGrid is unchanged!

  if(.NOT.Identical_(GGrid,GGridExactCopy1,1e-5)) then
     call die(myname_,"GGrid has been unexpectedly altered!!!")
  endif

  call clean(GGridExactCopy1)

  if(calledinitl_) then
     if(.NOT.Identical_(GGrid,GGridExactCopy2,1e-5)) then
        call die(myname_,"GGrid has been unexpectedly altered!!!")
     endif
     call clean(GGridExactCopy2)
  endif

end subroutine testGGrid_

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::TEST FOR INDEXIA AND GETILIST::::::::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  subroutine IndexTest_(GGrid,identifier,device)

    use m_GeneralGrid, only: GeneralGrid,indexIA,indexRA
    use m_AttrVect, only : getIList, getRList
    use m_AttrVect, only : nIAttr,nRAttr
    use m_List,   only: List_allocated   => allocated
    use m_String, only: String
    use m_String, only: StringToChar     => toChar
    use m_String, only: String_clean     => clean
    use m_stdio
    use m_die

    implicit none

    type(GeneralGrid),          intent(in)  :: GGrid
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::IndexTest_'
    type(String) :: ItemStr
    integer :: i,j,k,ierr

    if(nIAttr(GGrid%data)>0) then
       write(device,*) identifier, ":: Testing indexIA and getIList::"
    else
       if(List_allocated(GGrid%data%iList)) then
          call die(myname_,"iList has been allocated, :&
               &but there are no atttributes. :&
               &Please do not initialize a blank list.")
       end if
       if(associated(GGrid%data%iAttr)) then
          if(size(GGrid%data%iAttr,1) /= 0) then
             call die(myname_,"iAttr contains no attributes, &
                  &yet its size /= 0",size(GGrid%data%iAttr,1))
          endif
       endif
    end if

    do i=1,nIAttr(GGrid%data)

       call getIList(ItemStr,i,GGrid%data)
       j = indexIA(GGrid,StringToChar(ItemStr))
       if(i/=j) call die(myname_,"Function indexIA failed!")
       write(device,*) identifier, &
            ":: GGrid Index = ", j,      &
            ":: Attribute Name = ", StringToChar(ItemStr)
       call String_clean(ItemStr)

    enddo

    if(nRAttr(GGrid%data)>0) then
       write(device,*) identifier, ":: Testing indexRA and getRList::"
    else
       if(List_allocated(GGrid%data%rList)) then
          call die(myname_,"rList has been allocated, :&
               &but there are no atttributes. :&
               &Please do not initialize a blank list.")
       end if
       if(associated(GGrid%data%rAttr)) then
          if(size(GGrid%data%rAttr,1) /= 0) then
             call die(myname_,"rAttr contains no attributes, &
                  &yet its size /= 0",size(GGrid%data%rAttr,1))
          endif
       endif
    end if

    do i=1,nRAttr(GGrid%data)

       call getRList(ItemStr,i,GGrid%data)
       j = indexRA(GGrid,StringToChar(ItemStr))
       if(i/=j) call die(myname_,"Function indexIA failed!")
       write(device,*) identifier,   &
            "::GGrid Index = ", j,      &
            "::Attribute Name = ", StringToChar(ItemStr)
       call String_clean(ItemStr)

    enddo

  end subroutine IndexTest_

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TEST FOR SORT AND PERMUTE:::::::::::::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

! NOTE: THIS IS NOT A CHECK FOR CORRECTNESS, JUST A CHECK FOR CONSISTENCY

  subroutine SortPermuteTest_(GGrid,identifier,device)

    use m_GeneralGrid
    use m_AttrVect, only: nIAttr, nRAttr, Zero
    use m_stdio
    use m_die

    use m_realkinds, only : FP

    implicit none

    type(GeneralGrid),          intent(in)  :: GGrid
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::SortPermuteTest_'
    type(GeneralGrid) :: GGRIDCOPY1, GGRIDCOPY2
    logical,dimension(:), pointer :: descend
    integer,dimension(:), pointer :: perm
    integer :: i,j,k,ierr
    real :: r

    if( associated(GGrid%descend) ) then

    write(device,*) identifier, ":: Testing Sort and Permute"

    call init(oGGrid=GGRIDCOPY1,iGGrid=GGrid,lsize=100)
    call init(oGGrid=GGRIDCOPY2,iGGrid=GGrid,lsize=100)

    call Zero(GGRIDCOPY1%data)
    call Zero(GGRIDCOPY2%data)

    if(nIAttr(GGRIDCOPY1%data)>0) then

       k=0
       do i=1,nIAttr(GGRIDCOPY1%data)
          do j=1,lsize(GGRIDCOPY1)
             k=k+1
             GGRIDCOPY1%data%iAttr(i,j) = k
             GGRIDCOPY2%data%iAttr(i,j) = k
          enddo
       enddo
    endif
    if(nRAttr(GGRIDCOPY1%data)>0) then

       r=0.
       do i=1,nRAttr(GGRIDCOPY1%data)
          do j=1,lsize(GGRIDCOPY1)
             r=r+1.29
             GGRIDCOPY1%data%rAttr(i,j) = r
             GGRIDCOPY2%data%rAttr(i,j) = r
          enddo
       enddo
    endif

    call Sort(GGrid=GGRIDCOPY1,key_List=GGRIDCOPY1%coordinate_sort_order,perm=perm,descend=GGrid%descend)
    call Permute(GGrid=GGRIDCOPY1,perm=perm)

    call SortPermute(GGrid=GGRIDCOPY2)

    deallocate(perm,stat=ierr)
    if(ierr /= 0) call die(myname_,"deallocate(perm)")

    if(nIAttr(GGRIDCOPY1%data)>0) then

       do i=1,nIAttr(GGRIDCOPY1%data)
          do j=1,lsize(GGRIDCOPY1)
             if(GGRIDCOPY1%data%iAttr(i,j) /= GGRIDCOPY2%data%iAttr(i,j)) then
                call die(myname_,"Sort Testing FAILED!")
             endif
          enddo
       enddo

       write(device,*) identifier, ":: INTEGER GGRID%DATA IN ", GGrid%descend, &
            " ORDER:: ", GGRIDCOPY1%data%iAttr(1,1:5)

    endif

    if(nRAttr(GGRIDCOPY1%data)>0) then

       do i=1,nRAttr(GGRIDCOPY1%data)
          do j=1,lsize(GGRIDCOPY1)
             if(GGRIDCOPY1%data%rAttr(i,j) /= GGRIDCOPY2%data%rAttr(i,j)) then
                call die(myname_,"Sort Testing FAILED!")
             endif
          enddo
       enddo

       write(device,*) identifier, ":: REAL GGRID%DATA IN ", GGrid%descend, &
            " ORDER:: ", GGRIDCOPY1%data%rAttr(1,1:5)

    endif

    call clean(GGRIDCOPY1)
    call clean(GGRIDCOPY2)
    else
    write(device,*) identifier, ":: NOT TESTING SORTING AND PERMUTING. CONSULT &
         &SOURCE CODE TO ENABLE TESTING."
    endif

  end subroutine SortPermuteTest_

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TEST FOR EXPORT AND IMPORT FUNCTIONS:::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

  subroutine ImportExportTest_(GGrid,identifier,device)

    use m_GeneralGrid
    use m_AttrVect, only   : exportIList, exportRList
    use m_AttrVect, only   : AttrVect_zero    => zero
    use m_AttrVect, only   : nIAttr, nRAttr
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

    type(GeneralGrid),             intent(in)  :: GGrid
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::ImportExportTest_'
    type(GeneralGrid) :: importGGrid
    type(List) :: OutIList, OutRList
    type(String) :: ItemStr
    integer,dimension(:),pointer :: OutIVect
    real(FP), dimension(:),pointer :: OutRVect
    integer :: exportsize
    integer :: i,j,k,ierr

    write(device,*) identifier, ":: Testing import and export functions"

    if(nIAttr(GGrid%data)>0) then

       call exportIList(aV=GGrid%data,outIList=outIList)

       if(.NOT. List_identical(GGrid%data%iList,outIList)) then
          call die(myname_, "Function exportIList failed!")
       endif

       call List_get(ItemStr=ItemStr,ith=nIAttr(GGrid%data),aList=GGrid%data%iList)

       allocate(outIVect(lsize(GGrid)),stat=ierr)
       if(ierr/=0) call die(myname_,"allocate(outIVect)")

       call exportIAttr(GGrid=GGrid,AttrTag=StringToChar(ItemStr), &
            outVect=OutIVect,lsize=exportsize)

       if(exportsize /= lsize(GGrid)) then
          call die(myname_,"(exportsize /= lsize(GGrid))")
       endif

       do i=1,exportsize
          if(GGrid%data%iAttr(nIAttr(GGrid%data),i) /= outIVect(i)) then
             call die(myname_,"Function exportIAttr failed!")
          endif
       enddo

       call init(oGGrid=importGGrid,iGGrid=GGrid,lsize=exportsize)
       call AttrVect_zero(importGGrid%data)

       call importIAttr(GGrid=importGGrid,AttrTag=StringToChar(ItemStr), &
            inVect=outIVect,lsize=exportsize)

       j=indexIA(importGGrid,StringToChar(ItemStr))
       if(j<=0) call die(myname_,"indexIA(importGGrid,StringToChar(ItemStr))")
       do i=1,exportsize
          if(importGGrid%data%iAttr(j,i) /= outIVect(i)) then
             call die(myname_,"Function importIAttr failed!")
          endif
       enddo

       call clean(importGGrid)
       call List_clean(outIList)
       call String_clean(ItemStr)

       deallocate(outIVect,stat=ierr)
       if(ierr/=0) call die(myname_,"deallocate(outIVect)")

    endif

    if(nRAttr(GGrid%data)>0) then

       call exportRList(aV=GGrid%data,outRList=outRList)

       if(.NOT. List_identical(GGrid%data%rList,outRList)) then
          call die(myname_, "Function exportRList failed!")
       endif

       call List_get(ItemStr=ItemStr,ith=nRAttr(GGrid%data),aList=GGrid%data%rList)

       allocate(outRVect(lsize(GGrid)),stat=ierr)
       if(ierr/=0) call die(myname_,"allocate(outRVect)")

       call exportRAttr(GGrid=GGrid,AttrTag=StringToChar(ItemStr), &
            outVect=OutRVect,lsize=exportsize)

       if(exportsize /= lsize(GGrid)) then
          call die(myname_,"(exportsize /= lsize(GGrid))")
       endif

       do i=1,exportsize
          if(GGrid%data%rAttr(nRAttr(GGrid%data),i) /= outRVect(i)) then
             call die(myname_,"Function exportRAttr failed!")
          endif
       enddo

       call init(oGGrid=importGGrid,iGGrid=GGrid,lsize=exportsize)
       call AttrVect_zero(importGGrid%data)

       call importRAttr(GGrid=importGGrid,AttrTag=StringToChar(ItemStr), &
            inVect=outRVect,lsize=exportsize)

       j=indexRA(importGGrid,StringToChar(ItemStr))
       if(j<=0) call die(myname_,"indexRA(importGGrid,StringToChar(ItemStr))")
       do i=1,exportsize
          if(importGGrid%data%rAttr(j,i) /= outRVect(i)) then
             call die(myname_,"Function importRAttr failed!")
          endif
       enddo

       call clean(importGGrid)
       call List_clean(outRList)
       call String_clean(ItemStr)

       deallocate(outRVect,stat=ierr)
       if(ierr/=0) call die(myname_,"deallocate(outRVect)")

    endif

  end subroutine ImportExportTest_

  logical function Identical_(GGrid1,GGrid2,Range)

    use m_GeneralGrid, only: GeneralGrid
    use m_AVTEST,only: AttrVect_identical => Identical
    use m_List,only : List_allocated => allocated
    use m_List,only : List_identical => identical
    use m_stdio
    use m_die

    use m_realkinds, only : FP

    implicit none

    type(GeneralGrid), intent(in) :: GGrid1
    type(GeneralGrid), intent(in) :: GGrid2
    real, optional,    intent(in) :: Range

    integer :: i,j,k

    Identical_=.true.

    if(present(Range)) then
       if(.NOT. AttrVect_identical(GGrid1%data,GGrid2%data,Range)) then
          Identical_=.false.
       endif
    else
       if(.NOT. AttrVect_identical(GGrid1%data,GGrid2%data)) then
          Identical_=.false.
       endif
    endif

    if(.NOT. List_identical(GGrid1%coordinate_list, &
         GGrid2%coordinate_list) ) then
       Identical_=.false.
    endif

    if( List_allocated(GGrid1%coordinate_sort_order) .or. &
         List_allocated(GGrid2%coordinate_sort_order) ) then
       if(.NOT. List_identical(GGrid1%coordinate_sort_order, &
            GGrid2%coordinate_sort_order) ) then
          Identical_=.false.
       endif
    endif

    if( List_allocated(GGrid1%weight_list) .or. &
         List_allocated(GGrid2%weight_list) ) then
       if(.NOT. List_identical(GGrid1%weight_list, &
            GGrid2%weight_list) ) then
          Identical_=.false.
       endif
    endif

    if( List_allocated(GGrid1%other_list) .or. &
         List_allocated(GGrid2%other_list) ) then
       if(.NOT. List_identical(GGrid1%other_list, &
            GGrid2%other_list) ) then
          Identical_=.false.
       endif
    endif

    if( List_allocated(GGrid1%index_list) .or. &
         List_allocated(GGrid2%index_list) ) then
       if(.NOT. List_identical(GGrid1%index_list, &
            GGrid2%index_list) ) then
          Identical_=.false.
       endif
    endif

    if(associated(GGrid1%descend) .and. &
         associated(GGrid2%descend)) then

       if(size(GGrid1%descend) == size(GGrid2%descend)) then
          do i=1,size(GGrid1%descend)
             if(GGrid1%descend(i).neqv.GGrid2%descend(i)) then
                Identical_=.false.
             endif
          enddo
       else
          Identical_=.false.
       endif

    endif

     if((associated(GGrid1%descend).and..NOT.associated(GGrid2%descend)).or.&
          (.NOT.associated(GGrid1%descend).and.associated(GGrid2%descend)))then
        Identical_=.false.
     endif

  end function Identical_


end module m_GGRIDTEST
