!
! !INTERFACE:

 module m_AVTEST
!
! !USES:
!
      implicit none

      private	! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: testall
      public :: IndexAttr
      public :: SortPermute
      public :: Copy
      public :: ImportExport
      public :: Reduce
      public :: Identical

    interface testall
       module procedure testaV_
    end interface
    interface IndexAttr
       module procedure IndexTest_
    end interface
    interface SortPermute
       module procedure SortPermuteTest_
    end interface
    interface Copy
       module procedure CopyTest_
    end interface
    interface ImportExport
       module procedure ImportExportTest_
    end interface
    interface Reduce
       module procedure ReduceTest_
    end interface
    interface Identical
       module procedure Identical_
    end interface

! !REVISION HISTORY:
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='m_AVTest'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: aVtest_ - Test the functions in the AttrVect module
!
! !DESCRIPTION:
! This routine writes diagnostic information about the input
! {\tt AttrVect}. Each line of the output will be preceded by the
! character argument {\tt identifier}. The output device is specified
! by the integer argument {\tt device}.
!
! !INTERFACE:

 subroutine testaV_(aV, identifier, device)

!
! !USES:
!
      use m_AttrVect         ! Use all AttrVect routines
      use m_stdio
      use m_die

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),             intent(in)  :: aV
      character(len=*),           intent(in)  :: identifier
      integer,                    intent(in)  :: device

! !REVISION HISTORY:
! 23Sep02 - E.T. Ong <eong@mcs.anl.gov> - initial prototype.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::aVtest_'
  type(AttrVect) :: aVExactCopy

!::::MAKE A COPY::::!

  call init(aVExactCopy,aV,lsize(aV))
  call Copy(aVin=aV,aVout=aVExactCopy)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::WRITE OUT INFO ABOUT THE ATTRVECT:::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  write(device,*) identifier, ":: lsize = ", lsize(aV)
  write(device,*) identifier, ":: nIAttr = ", nIAttr(aV)
  write(device,*) identifier, ":: nRAttr = ", nRAttr(aV)

  if(nIAttr(aV)>0) then
     write(device,*) identifier, ":: exportIListToChar = ", &
                                      exportIListToChar(aV)
  endif

  if(nRAttr(aV)>0) then
     write(device,*) identifier, ":: exportRListToChar = ", &
                                      exportRListToChar(aV)
  endif

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::TESTING INDEXIA AND GETILIST::::::::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  call IndexTest_(aV,identifier,device)


!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TESTING SORT AND PERMUTE:::::::::::::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

! NOTE: THIS IS NOT A CHECK FOR CORRECTNESS, JUST A CHECK FOR CONSISTENCY

  call SortPermuteTest_(aV,identifier,device)

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TESTING COPY AND SHAREDATTRINDEXLIST:::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

  call CopyTest_(aV,identifier,device)

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TESTING EXPORT AND IMPORT FUNCTIONS::::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

  call ImportExportTest_(aV,identifier,device)

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TESTING LOCAL REDUCE FUNCTIONS:::::::::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

  call ReduceTest_(aV,identifier,device)


  ! Check that aV is unchanged!

  if(.NOT.Identical_(aV,aVExactCopy,1e-5)) then
     call die(myname_,"aV has been unexpectedly altered!!!")
  endif

  call clean(aVExactCopy)

end subroutine testaV_

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::TEST FOR INDEXIA AND GETILIST::::::::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  subroutine IndexTest_(aV,identifier,device)

    use m_AttrVect, only: AttrVect, nIattr, nRattr,getIList, getRList,indexIa,indexRA
    use m_List,   only: List_allocated   => allocated
    use m_String, only: String
    use m_String, only: StringToChar     => toChar
    use m_String, only: String_clean     => clean
    use m_stdio
    use m_die

    implicit none

    type(AttrVect),             intent(in)  :: aV
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::IndexTest_'
    type(String) :: ItemStr
    integer :: i,j,k,ierr

    if(nIAttr(aV)>0) then
       write(device,*) identifier, ":: Testing indexIA and getIList::"
    else
       if(List_allocated(aV%iList)) then
          call die(myname_,"iList has been allocated, :&
               &but there are no atttributes. :&
               &Please do not initialize a blank list.")
       end if
       if(associated(aV%iAttr)) then
          if(size(aV%iAttr,1) /= 0) then
             call die(myname_,"iAttr contains no attributes, &
                  &yet its size /= 0",size(aV%iAttr,1))
          endif
       endif
    end if

    do i=1,nIAttr(aV)

       call getIList(ItemStr,i,aV)
       j = indexIA(aV,StringToChar(ItemStr))
       if(i/=j) call die(myname_,"Function indexIA failed!")
       write(device,*) identifier, &
            ":: aV Index = ", j,      &
            ":: Attribute Name = ", StringToChar(ItemStr)
       call String_clean(ItemStr)

    enddo

    if(nRAttr(aV)>0) then
       write(device,*) identifier, ":: Testing indexRA and getRList::"
    else
       if(List_allocated(aV%rList)) then
          call die(myname_,"rList has been allocated, :&
               &but there are no atttributes. :&
               &Please do not initialize a blank list.")
       end if
       if(associated(aV%rAttr)) then
          if(size(aV%rAttr,1) /= 0) then
             call die(myname_,"rAttr contains no attributes, &
                  &yet its size /= 0",size(aV%rAttr,1))
          endif
       endif
    end if

    do i=1,nRAttr(aV)

       call getRList(ItemStr,i,aV)
       j = indexRA(aV,StringToChar(ItemStr))
       if(i/=j) call die(myname_,"Function indexIA failed!")
       write(device,*) identifier,   &
            "::aV Index = ", j,      &
            "::Attribute Name = ", StringToChar(ItemStr)
       call String_clean(ItemStr)

    enddo

  end subroutine IndexTest_

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TEST FOR SORT AND PERMUTE:::::::::::::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

! NOTE: THIS IS NOT A CHECK FOR CORRECTNESS, JUST A CHECK FOR CONSISTENCY

  subroutine SortPermuteTest_(aV,identifier,device)

    use m_AttrVect
    use m_stdio
    use m_die

    implicit none

    type(AttrVect),             intent(in)  :: aV
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::SortPermuteTest_'
    type(AttrVect) :: AVCOPY1, AVCOPY2
    logical,dimension(:), pointer :: descend
    integer,dimension(:), pointer :: perm
    integer :: i,j,k,ierr
    real :: r

    write(device,*) identifier, ":: Testing Sort and Permute"

    call init(aV=AVCOPY1,bV=aV,lsize=100)
    call init(av=AVCOPY2,bV=aV,lsize=100)

    if( (nIAttr(AVCOPY1)>0) .or. (nRAttr(AVCOPY1)>0) ) then

    if(nIAttr(AVCOPY1)>0) then

       allocate(descend(nIAttr(AVCOPY1)),stat=ierr)
       if(ierr /= 0) call die(myname_,"allocate(descend)")

       call zero(AVCOPY1)
       call zero(AVCOPY2)

       k=0
       do i=1,nIAttr(AVCOPY1)
          do j=1,lsize(AVCOPY1)
             k=k+1
             AVCOPY1%iAttr(i,j) = k
             AVCOPY2%iAttr(i,j) = k
          enddo
       enddo

       descend=.true.
       call Sort(aV=AVCOPY1,key_list=AVCOPY1%iList,perm=perm,descend=descend)
       call Permute(aV=AVCOPY1,perm=perm)

       call SortPermute(aV=AVCOPY2,key_list=AVCOPY2%iList,descend=descend)

       do i=1,nIAttr(AVCOPY1)
          do j=1,lsize(AVCOPY1)
             if(AVCOPY1%iAttr(i,j) /= AVCOPY2%iAttr(i,j)) then
                call die(myname_,"Sort Testing FAILED!")
             endif
          enddo
       enddo

       write(device,*) identifier, ":: INTEGER AV IN DESCENDING ORDER:: ", &
            AVCOPY1%iAttr(1,1:5)

       deallocate(perm,stat=ierr)
       if(ierr /= 0) call die(myname_,"deallocate(perm)")

       deallocate(descend,stat=ierr)
       if(ierr /= 0) call die(myname_,"deallocate(descend)")

    endif

    if(nRAttr(AVCOPY1)>0) then

       allocate(descend(nRAttr(AVCOPY1)),stat=ierr)
       if(ierr /= 0) call die(myname_,"allocate(descend)")

       call zero(AVCOPY1)
       call zero(AVCOPY2)

       r=0.
       do i=1,nRAttr(AVCOPY1)
          do j=1,lsize(AVCOPY1)
             r=r+1.29
             AVCOPY1%rAttr(i,j) = r
             AVCOPY2%rAttr(i,j) = r
          enddo
       enddo

       descend=.true.
       call Sort(aV=AVCOPY1,key_list=AVCOPY1%rList,perm=perm,descend=descend)
       call Permute(aV=AVCOPY1,perm=perm)

       call SortPermute(aV=AVCOPY2,key_list=AVCOPY2%rList,descend=descend)

       do i=1,nRAttr(AVCOPY1)
          do j=1,lsize(AVCOPY1)
             if(AVCOPY1%rAttr(i,j) /= AVCOPY2%rAttr(i,j)) then
                call die(myname_,"Sort Testing FAILED!")
             endif
          enddo
       enddo

       write(device,*) identifier, ":: REAL AV IN DESCENDING ORDER:: ", &
            AVCOPY1%rAttr(1,1:5)

       deallocate(perm,stat=ierr)
       if(ierr /= 0) call die(myname_,"deallocate(perm)")

       deallocate(descend,stat=ierr)
       if(ierr /= 0) call die(myname_,"deallocate(descend)")

    endif
    else
    write(device,*) identifier, ":: NOT TESTING SORTING AND PERMUTING. CONSULT &
         &SOURCE CODE TO ENABLE TESTING."
    endif

    call clean(AVCOPY1)
    call clean(AVCOPY2)

  end subroutine SortPermuteTest_

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TEST FOR COPY AND SHAREDATTRINDEXLIST:::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

! NOTE: SO FOR ONLY TESTING SHAREDATTRINDEX for reals

  subroutine CopyTest_(aV,identifier,device)

    use m_AttrVect
    use m_List,     only   : List
    use m_List,     only   : List_init        => init
    use m_List,     only   : List_copy        => copy
    use m_List,     only   : List_append      => append
    use m_List,     only   : ListexportToChar => exportToChar
    use m_List,     only   : List_clean       => clean
    use m_String,   only   : String
    use m_String,   only   : StringToChar     => toChar
    use m_String,   only   : String_clean     => clean
    use m_stdio
    use m_die

    implicit none

    type(AttrVect),             intent(in)  :: aV
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::CopyTest_'
    type(String) :: ItemStr1, ItemStr2
    type(List) :: OneIList, HalfIList, FullIList
    type(List) :: OneRList, HalfRList, FullRList
    type(AttrVect) :: aVExactCopy, aVPartialCopy, aVOtherCopy
    type(AttrVect) :: HalfAV
    integer,dimension(:), pointer :: Indices1, Indices2
    integer :: NumShared
    integer :: i,j,k,ierr

    if( (nIAttr(aV)>0) .and. (nRAttr(aV)>0) ) then

       !:::INITIALIZE LISTS FOR USE IN COPY TESTS:::!
       do i=1,nIAttr(aV)

          call getIList(ItemStr1,i,aV)

          if(i==1) then
             call List_init(HalfIList,ItemStr1)
             call List_init(FullIList,ItemStr1)
          else
             if(mod(i,2) == 0) then ! if EVEN
                call List_init(OneIList,'REPLACE_'//ACHAR(64+i))
                call List_append(FullIList,OneIList)
                call List_clean(OneIList)
             else                   ! if ODD
                call List_init(OneIList,ItemStr1)
                call List_append(HalfIList,OneIList)
                call List_append(FullIList,OneIList)
                call List_clean(OneIList)
             endif
          endif

          call String_clean(ItemStr1)

       enddo

       do i=1,nRAttr(aV)

          call getRList(ItemStr1,i,aV)

          if(i==1) then
             call List_init(OneRList,'REPLACE_'//ACHAR(64+i))
             call List_copy(FullRList,OneRList)
             call List_clean(OneRList)
          else
             if(mod(i,2) == 0) then ! IF EVEN
                call List_init(OneRList,ItemStr1)
                if(i==2) then
                   call List_init(HalfRList,ItemStr1)
                else
                   call List_append(HalfRList,OneRList)
                endif
                call List_append(FullRList,OneRList)
                call List_clean(OneRList)
             else                   ! IF ODD
                call List_init(OneRList,'REPLACE_'//ACHAR(64+i))
                call List_append(FullRList,OneRList)
                call List_clean(OneRList)
             endif
          endif

          call String_clean(ItemStr1)

       enddo

       write(device,*) identifier, ":: Testing Copy and SharedAttrIndexList ::"
       write(device,*) identifier, ":: FIRST AV ATTRIBUTES::", &
            "IATTR = ", exportIListToChar(aV), &
            " RATTR = ", exportRListToChar(aV)
       call init(aVExactCopy,aV,lsize(aV))
       write(device,*) identifier, ":: SECOND AV ATTRIBUTES::", &
            "IATTR = ", exportIListToChar(aVExactCopy), &
            " RATTR = ", exportRListToChar(aVExactCopy)
       call zero(aVExactCopy)
       call copy(aVin=aV, aVout=aVExactCopy)
       !     call copy(aVin=aV,rList=exportRListToChar(aV), &
       !          iList=exportIListToChar(aV),aVout=aVExactCopy)
       call SharedAttrIndexList(aV,aVExactCopy,"REAL   ", &
            NumShared,Indices1,Indices2)
       write(device,*) identifier, ":: Indices1 :: Indices2 :: &
            &Attribute1 :: Attribute2"
       do i=1,NumShared
          call getRList(ItemStr1,Indices1(i),aV)
          call getRList(ItemStr2,Indices2(i),aVExactCopy)
          write(device,*) identifier,":: ", Indices1(i), "::", Indices2(i), &
               "::", StringToChar(ItemStr1), "::", StringToChar(ItemStr2)
          call String_clean(ItemStr1)
          call String_clean(ItemStr2)
       enddo

       do i=1,NumShared
          do j=1,lsize(aV)
             if(aV%rAttr(Indices1(i),j) /= &
                  aVExactCopy%rAttr(Indices2(i),j)) then
                call die(myname_,"Copy function is MALFUNCTIONING", ierr)
             endif
          enddo
       enddo

       deallocate(Indices1,Indices2,stat=ierr)
       if(ierr/=0) call die(myname_,"deallocate(Indices1,Indices2)",ierr)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

       call init(aVPartialCopy,aV,lsize(aV))
       write(device,*) identifier, ":: FIRST AV ATTRIBUTES::", &
            "IATTR = ", exportIListToChar(aVPartialCopy), &
            " RATTR = ", exportRListToChar(aVPartialCopy)
       call zero(aVPartialCopy)
       call copy(aVin=aV,rList=ListexportToChar(HalfRList), &
            iList=ListexportToChar(HalfIList),aVout=aVPartialCopy)
       call init(aV=HalfAV,iList=HalfIList,rList=HalfRList,lsize=1)
       write(device,*) identifier, ":: SECOND AV ATTRIBUTES::", &
            "IATTR = ", exportIListToChar(HalfAV), &
            " RATTR = ", exportRListToChar(HalfAV)
       call SharedAttrIndexList(aV,HalfAV,"REAL   ", &
            NumShared,Indices1,Indices2)
       write(device,*) identifier, ":: Indices1 :: Indices2 :: &
            &Attribute1 :: Attribute2"
       do i=1,NumShared
          call getRList(ItemStr1,Indices1(i),aV)
          call getRList(ItemStr2,Indices2(i),HalfAV)
          write(device,*) identifier,":: ", Indices1(i), "::", Indices2(i), &
               "::", StringToChar(ItemStr1), "::", StringToChar(ItemStr2)
          call String_clean(ItemStr1)
          call String_clean(ItemStr2)
       enddo

       do i=1,NumShared
          do j=1,lsize(aV)
             if(aV%rAttr(Indices1(i),j) /= &
                  aVPartialCopy%rAttr(Indices1(i),j)) then
                call die(myname_,"Copy function is MALFUNCTIONING", ierr)
             endif
          enddo
       enddo

       call List_clean(HalfIList)
       call List_clean(HalfRList)

       deallocate(Indices1,Indices2,stat=ierr)
       if(ierr/=0) call die(myname_,"deallocate(Indices1,Indices2)",ierr)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

       call init(aVOtherCopy,FullIList,FullRList,lsize(aV))
       write(device,*) identifier, ":: FIRST AV ATTRIBUTES::", &
            "IATTR = ", exportIListToChar(aV), &
            " RATTR = ", exportRListToChar(aV)
       write(device,*) identifier, ":: SECOND AV ATTRIBUTES::", &
            "IATTR = ", exportIListToChar(aVOtherCopy), &
            " RATTR = ", exportRListToChar(aVOtherCopy)
       call zero(aVOtherCopy)
       call copy(aV,rList=exportRListToChar(aV), &
            TrList=ListexportToChar(FullRList), &
            iList=exportIListToChar(aV), &
            TiList=ListexportToChar(FullIList), &
            aVout=aVOtherCopy)
       call SharedAttrIndexList(aV,aVOtherCopy,"REAL", &
            NumShared,Indices1,Indices2)
       write(device,*) identifier, ":: Indices1 :: Indices2 :: &
            &Attribute1 :: Attribute2"
       do i=1,NumShared
          call getRList(ItemStr1,Indices1(i),aV)
          call getRList(ItemStr2,Indices2(i),aVOtherCopy)
          write(device,*) identifier,":: ", Indices1(i), "::", Indices2(i), &
               "::", StringToChar(ItemStr1), "::", StringToChar(ItemStr2)
          call String_clean(ItemStr1)
          call String_clean(ItemStr2)
       enddo

       do i=1,NumShared
          do j=1,lsize(aV)
             if(aV%rAttr(Indices1(i),j) /= &
                  aVOtherCopy%rAttr(Indices2(i),j)) then
                write(device,*) identifier,Indices1(i),Indices2(i), j
                call die(myname_,"Copy function is MALFUNCTIONING", ierr)
             endif
          enddo
       enddo

       call List_clean(FullIList)
       call List_clean(FullRList)

       deallocate(Indices1,Indices2,stat=ierr)
       if(ierr/=0) call die(myname_,"deallocate(Indices1,Indices2)",ierr)

       call clean(aVExactCopy)
       call clean(aVPartialCopy)
       call clean(aVOtherCopy)
       call clean(HalfAV)

    else

       write(device,*) identifier, &
            ":: NOT Testing Copy and SharedAttrIndexList ::", &
            ":: Consult m_MCTTest.F90 to enable this function::"
    endif

  end subroutine CopyTest_

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TEST FOR EXPORT AND IMPORT FUNCTIONS:::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

  subroutine ImportExportTest_(aV,identifier,device)

    use m_AttrVect
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

    type(AttrVect),             intent(in)  :: aV
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::ImportExportTest_'
    type(AttrVect) :: importAV
    type(List) :: OutIList, OutRList
    type(String) :: ItemStr
    integer,dimension(:),pointer :: OutIVect
    real(FP), dimension(:),pointer :: OutRVect
    integer :: exportsize
    integer :: i,j,k,ierr

    write(device,*) identifier, ":: Testing import and export functions"

    if(nIAttr(aV)>0) then

       call exportIList(aV=aV,outIList=outIList)

       if(.NOT. List_identical(aV%iList,outIList)) then
          call die(myname_, "Function exportIList failed!")
       endif

       call List_get(ItemStr=ItemStr,ith=nIAttr(aV),aList=aV%iList)

       allocate(outIVect(lsize(aV)),stat=ierr)
       if(ierr/=0) call die(myname_,"allocate(outIVect)")

       call exportIAttr(aV=aV,AttrTag=StringToChar(ItemStr), &
            outVect=OutIVect,lsize=exportsize)

       if(exportsize /= lsize(aV)) then
          call die(myname_,"(exportsize /= lsize(aV))")
       endif

       do i=1,exportsize
          if(aV%iAttr(nIAttr(aV),i) /= outIVect(i)) then
             call die(myname_,"Function exportIAttr failed!")
          endif
       enddo

       call init(aV=importAV,iList=exportIListToChar(aV),lsize=exportsize)
       call zero(importAV)

       call importIAttr(aV=importAV,AttrTag=StringToChar(ItemStr), &
            inVect=outIVect,lsize=exportsize)

       j=indexIA(importAV,StringToChar(ItemStr))
       if(j<=0) call die(myname_,"indexIA(importAV,StringToChar(ItemStr))")
       do i=1,exportsize
          if(importAV%iAttr(j,i) /= outIVect(i)) then
             call die(myname_,"Function importIAttr failed!")
          endif
       enddo

       call clean(importAV)
       call List_clean(outIList)
       call String_clean(ItemStr)

       deallocate(outIVect,stat=ierr)
       if(ierr/=0) call die(myname_,"deallocate(outIVect)")

    endif

    if(nRAttr(aV)>0) then

       call exportRList(aV=aV,outRList=outRList)

       if(.NOT. List_identical(aV%rList,outRList)) then
          call die(myname_, "Function exportRList failed!")
       endif

       call List_get(ItemStr=ItemStr,ith=nRAttr(aV),aList=aV%rList)

       allocate(outRVect(lsize(aV)),stat=ierr)
       if(ierr/=0) call die(myname_,"allocate(outRVect)")

       call exportRAttr(aV=aV,AttrTag=StringToChar(ItemStr), &
            outVect=OutRVect,lsize=exportsize)

       if(exportsize /= lsize(aV)) then
          call die(myname_,"(exportsize /= lsize(aV))")
       endif

       do i=1,exportsize
          if(aV%rAttr(nRAttr(aV),i) /= outRVect(i)) then
             call die(myname_,"Function exportRAttr failed!")
          endif
       enddo

       call init(aV=importAV,rList=exportRListToChar(aV),lsize=exportsize)
       call zero(importAV)

       call importRAttr(aV=importAV,AttrTag=StringToChar(ItemStr), &
            inVect=outRVect,lsize=exportsize)

       j=indexRA(importAV,StringToChar(ItemStr))
       if(j<=0) call die(myname_,"indexRA(importAV,StringToChar(ItemStr))")
       do i=1,exportsize
          if(importAV%rAttr(j,i) /= outRVect(i)) then
             call die(myname_,"Function importRAttr failed!")
          endif
       enddo

       call clean(importAV)
       call List_clean(outRList)
       call String_clean(ItemStr)

       deallocate(outRVect,stat=ierr)
       if(ierr/=0) call die(myname_,"deallocate(outRVect)")

    endif

  end subroutine ImportExportTest_

  subroutine ReduceTest_(aV,identifier,device)

    use m_AttrVectReduce
    use m_AttrVect
    use m_List, only : ListExportToChar => ExportToChar
    use m_stdio
    use m_die

    implicit none

    type(AttrVect),             intent(in)  :: aV
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::ReduceTest_'
    integer :: i,j,k,ierr
    type(AttrVect) :: reducedAVsum, reducedAVmin, reducedAVmax
    type(AttrVect) :: reducedAVRsum, reducedAVRmin, reducedAVRmax

    if( (nIAttr(aV)==0).and.(nRAttr(aV)>0) ) then

       call LocalReduce(aV,reducedAVsum,AttrVectSUM)
       call LocalReduce(aV,reducedAVmin,AttrVectMIN)
       call LocalReduce(aV,reducedAVmax,AttrVectMAX)

       call LocalReduceRAttr(aV,reducedAVRsum,AttrVectSUM)
       call LocalReduceRAttr(aV,reducedAVRmin,AttrVectMIN)
       call LocalReduceRAttr(aV,reducedAVRmax,AttrVectMAX)

       if(.NOT.Identical_(reducedAVsum,reducedAVRsum,1e-4)) then
          call die(myname_,"LocalReduce -SUM- functions produced inconsistent &
               &results!")
       endif

       if(.NOT.Identical_(reducedAVmin,reducedAVRmin,1e-4)) then
          call die(myname_,"LocalReduce -MIN- functions produced inconsistent &
               &results!")
       endif

       if(.NOT.Identical_(reducedAVmax,reducedAVRmax,1e-4)) then
          call die(myname_,"LocalReduce -MAX- functions produced inconsistent &
               &results!")
       endif

       write(device,*) identifier,":: RESULTS OF ATTRVECT LOCAL REDUCE :: &
            &(Name, rList, Values)"
       write(device,*) identifier,":: REDUCEDAVSUM = ", &
            ListExportToChar(reducedAVsum%rList), &
            reducedAVsum%rAttr
       write(device,*) identifier,":: REDUCEDAVMIN = ", &
            ListExportToChar(reducedAVmin%rList), &
            reducedAVmin%rAttr
       write(device,*) identifier,":: REDUCEDAVMAX = ", &
            ListExportToChar(reducedAVmax%rList), &
            reducedAVmax%rAttr

       call clean(reducedAVsum)
       call clean(reducedAVmin)
       call clean(reducedAVmax)
       call clean(reducedAVRsum)
       call clean(reducedAVRmin)
       call clean(reducedAVRmax)

    else

       write(device,*) identifier,":: NOT TESTING LOCAL REDUCE. &
            &PLEASE CONSULT SOURCE CODE."

    endif

  end subroutine ReduceTest_

  logical function Identical_(aV1,aV2,Range)

    use m_AttrVect
    use m_stdio
    use m_die

    use m_realkinds, only : FP

    implicit none

    type(AttrVect), intent(in) :: aV1
    type(AttrVect), intent(in) :: aV2
    real, optional, intent(in) :: Range

    integer :: i,j,k,AVSize

    Identical_=.true.

    AVSize = lsize(aV1)

    if(lsize(aV1) /= lsize(aV2)) then
       AVSize=0
       Identical_=.false.
    endif

    do i=1,AVSize
       do j=1,nIAttr(aV1)
          if(AV1%iAttr(j,i) /= AV2%iAttr(j,i)) then
             Identical_=.false.
          endif
       enddo
    enddo

    if(present(Range)) then

       do i=1,AVSize
          do j=1,nRAttr(aV1)
             if( ABS(AV1%rAttr(j,i)-AV2%rAttr(j,i)) > Range ) then
                Identical_=.false.
             endif
          enddo
       enddo

    else

       do i=1,AVSize
          do j=1,nRAttr(aV1)
             if(AV1%rAttr(j,i) /= AV2%rAttr(j,i)) then
                Identical_=.false.
             endif
          enddo
       enddo

    endif

  end function Identical_

end module m_AVTEST
