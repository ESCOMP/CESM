!
! !INTERFACE:

 module m_ACTEST
!
! !USES:
!
      implicit none

      private	! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: testall
      public :: IndexAttr
      public :: Copy
      public :: ImportExport
      public :: Identical

    interface testall
       module procedure testaC_
    end interface
    interface IndexAttr
       module procedure IndexTest_
    end interface
    interface Copy
       module procedure CopyTest_
    end interface
    interface ImportExport
       module procedure ImportExportTest_
    end interface
    interface Identical
       module procedure Identical_
    end interface


! !REVISION HISTORY:
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='m_ACTEST'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: aCtest_ - Test the functions in the Accumulator module
!
! !DESCRIPTION:
! This routine writes diagnostic information about the input
! {\tt Accumulator}. Each line of the output will be preceded by the
! character argument {\tt identifier}. The output device is specified
! by the integer argument {\tt device}.
!
! !INTERFACE:

 subroutine testaC_(aC, identifier, device)

!
! !USES:
!

      use m_Accumulator, only : Accumulator
      use m_Accumulator, only : accumulate
      use m_Accumulator, only : MCT_SUM, MCT_AVG
      use m_Accumulator, only : nIAttr, nRAttr
      use m_Accumulator, only : lsize
      use m_Accumulator, only : clean
      use m_Accumulator, only : Accumulator_init => init
      use m_AttrVect, only    : AttrVect
      use m_AttrVect, only    : AttrVect_init => init
      use m_AttrVect, only    : AttrVect_clean => clean
      use m_AttrVect, only    : AttrVect_copy => Copy
      use m_List,     only    : List_allocated => allocated
      use m_List,     only    : ListExportToChar => exporttoChar
      use m_stdio
      use m_die

      implicit none

! !INPUT PARAMETERS:

      type(Accumulator),          intent(in)  :: aC
      character(len=*),           intent(in)  :: identifier
      integer,                    intent(in)  :: device

! !REVISION HISTORY:
! 23Sep02 - E.T. Ong <eong@mcs.anl.gov> - initial prototype.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::aCtest_'

  type(Accumulator) :: aCCopy1, aCCopy2, aCExactCopy
  type(AttrVect) :: aVDummy
  integer :: i,j,k

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::WRITE OUT INFO ABOUT THE ATTRVECT:::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  write(device,*) identifier, ":: TYPE CHECK "
  write(device,*) identifier, ":: NUM_STEPS = ", aC%num_steps
  write(device,*) identifier, ":: STEPS_DONE = ", aC%steps_done

  if(associated(aC%iAction)) then
     write(device,*) identifier, ":: IACTION (SIZE,VALUES) = ", &
          size(aC%iAction), aC%iAction
  else
     write(device,*) identifier, ":: IACTION NOT ASSOCIATED"
  endif

  if(associated(aC%rAction)) then
     write(device,*) identifier, ":: RACTION (SIZE,VALUES) = ", &
          size(aC%rAction), aC%rAction
  else
     write(device,*) identifier, ":: RACTION NOT ASSOCIATED"
  endif

  if(List_allocated(aC%data%iList)) then
     write(device,*) identifier, ":: data%ILIST = ", &
          ListExportToChar(aC%data%iList)
  else
     write(device,*) identifier, ":: data%ILIST NOT INITIALIZED"
  endif

  if(List_allocated(aC%data%rList)) then
     write(device,*) identifier, ":: data%RLIST = ", &
          ListExportToChar(aC%data%rList)
  else
     write(device,*) identifier, ":: data%RLIST NOT INITIALIZED"
  endif

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::TESTING ACCUMULATION::::::::::::::::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  call Accumulator_init(aC=aCExactCopy, bC=aC, lsize=lsize(aC), &
                        num_steps=aC%num_steps, steps_done=aC%steps_done)

  call AttrVect_copy(aVin=aC%data,aVout=aCExactCopy%data)

  call Accumulator_init(aC=aCCopy1, bC=aC, lsize=100, &
                        num_steps=aC%num_steps, steps_done=0)

  call Accumulator_init(aC=aCCopy2, bC=aC, lsize=100, &
                        num_steps=aC%num_steps, steps_done=0)

  call AttrVect_init(aV=aVDummy, bV=aC%data, lsize=100)

  if(nIAttr(aC)>0) then
     aCCopy1%iAction=MCT_AVG
     aCCopy2%iAction=MCT_SUM
     aVDummy%iAttr = 1
  endif

  if(nRAttr(aC)>0) then
     aCCopy1%rAction=MCT_AVG
     aCCopy2%rAction=MCT_SUM
     aVDummy%rAttr = 1.
  endif

  do i=1,aC%num_steps
     call accumulate(aVDummy,ACCopy1)
     call accumulate(aVDummy,ACCopy2)
  enddo

  call accumulate(aVDummy,ACCopy1)
  call accumulate(aVDummy,ACCopy2)

  if(.NOT. (aCCopy1%num_steps == aC%num_steps)) then
     call die(myname_,"SEVERE: aCCopy1 num_steps value has changed!")
  endif

  if(.NOT. (aCCopy2%num_steps == aC%num_steps)) then
     call die(myname_,"SEVERE: aCCopy2 num_steps value has changed!")
  endif

  if(.NOT. (aCCopy1%steps_done == aC%num_steps+1)) then
     call die(myname_,"SEVERE: aCCopy1 stesp_done value is incorrect!")
  endif

  if(.NOT. (aCCopy2%steps_done == aC%num_steps+1)) then
     call die(myname_,"SEVERE: aCCopy2 stesp_done value is incorrect!")
  endif

  do i=1,lsize(ACCopy1)
     do j=1,nRAttr(aC)
        if( (aCCopy1%data%rAttr(j,i) < 1.9) .or. &
             (aCCopy1%data%rAttr(j,i) > 2.1) ) then
           call die(myname_,"Averaging Reals failed")
        endif
        if( (aCCopy2%data%rAttr(j,i) < aC%num_steps+0.9) .or. &
             (aCCopy2%data%rAttr(j,i) > aC%num_steps+1.1) ) then
           call die(myname_,"Summing Reals failed")
        endif
     enddo
  enddo

  do i=1,lsize(aCCopy1)
     do j=1,nIAttr(aC)
        if( aCCopy1%data%iAttr(j,i) /= 2 ) then
           call die(myname_,"Averaging Ints failed",aCCopy1%data%iAttr(j,i))
        endif
        if( aCCopy2%data%iAttr(j,i) /= aC%num_steps+1 ) then
           call die(myname_,"Summing Ints failed",aCCopy1%data%iAttr(j,i))
        endif
     enddo
  enddo

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::TESTING INDEXIA AND GETILIST::::::::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  call IndexTest_(aC,identifier,device)

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TESTING COPY AND SHAREDATTRINDEXLIST:::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

  call CopyTest_(aC,identifier,device)

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TESTING EXPORT AND IMPORT FUNCTIONS:::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
  call ImportExportTest_(aC,identifier,device)

  ! Check that aC is unchanged!

  if(.not.Identical_(ACC1=aC,ACC2=aCExactCopy,Range=1e-5)) then
     call die(myname_,"aC has been unexpectedly modified!!!")
  endif

  call clean(aCCopy1)
  call clean(aCCopy2)
  call clean(aCExactCopy)
  call AttrVect_clean(aVDummy)

end subroutine testaC_

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!:::::TEST FOR INDEXIA AND GETILIST::::::::::::::::::::::::::::::::::::::
!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

  subroutine IndexTest_(aC,identifier,device)

    use m_Accumulator, only: nIAttr, nRAttr, getIList, getRList, indexIA, indexRA, Accumulator
    use m_List,   only: List_allocated   => allocated
    use m_String, only: String
    use m_String, only: StringToChar     => toChar
    use m_String, only: String_clean     => clean
    use m_stdio
    use m_die

    implicit none

    type(Accumulator),          intent(in)  :: aC
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::IndexTest_'
    type(String) :: ItemStr
    integer :: i,j,k,ierr

    if(nIAttr(aC)>0) then
       write(device,*) identifier, ":: Testing indexIA and getIList::"
    else
       if(List_allocated(aC%data%iList)) then
          call die(myname_,"iList has been allocated, :&
               &but there are no atttributes. :&
               &Please do not initialize a blank list.")
       end if
       if(associated(aC%data%iAttr)) then
          if(size(aC%data%iAttr,1) /= 0) then
             call die(myname_,"iAttr contains no attributes, &
                  &yet its size /= 0",size(aC%data%iAttr,1))
          endif
       endif
    end if

    do i=1,nIAttr(aC)

       call getIList(ItemStr,i,aC)
       j = indexIA(aC,StringToChar(ItemStr))
       if(i/=j) call die(myname_,"Function indexIA failed!")
       write(device,*) identifier, &
            ":: aC Index = ", j,      &
            ":: Attribute Name = ", StringToChar(ItemStr)
       call String_clean(ItemStr)

    enddo

    if(nRAttr(aC)>0) then
       write(device,*) identifier, ":: Testing indexRA and getRList::"
    else
       if(List_allocated(aC%data%rList)) then
          call die(myname_,"rList has been allocated, :&
               &but there are no atttributes. :&
               &Please do not initialize a blank list.")
       end if
       if(associated(aC%data%rAttr)) then
          if(size(aC%data%rAttr,1) /= 0) then
             call die(myname_,"rAttr contains no attributes, &
                  &yet its size /= 0",size(aC%data%rAttr,1))
          endif
       endif
    end if

    do i=1,nRAttr(aC)

       call getRList(ItemStr,i,aC)
       j = indexRA(aC,StringToChar(ItemStr))
       if(i/=j) call die(myname_,"Function indexIA failed!")
       write(device,*) identifier,   &
            "::aC Index = ", j,      &
            "::Attribute Name = ", StringToChar(ItemStr)
       call String_clean(ItemStr)

    enddo

  end subroutine IndexTest_

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TEST FOR COPY AND SHAREDATTRINDEXLIST:::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

! NOTE: SO FOR ONLY TESTING SHAREDATTRINDEX for reals

  subroutine CopyTest_(aC,identifier,device)

    use m_AttrVect, only : copy
    use m_AttrVect, only : exportIListToChar,exportRListToChar
    use m_AttrVect, only : AttrVect_init => init
    use m_Accumulator
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

    type(Accumulator),          intent(in)  :: aC
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::CopyTest_'
    type(String) :: ItemStr1, ItemStr2
    type(Accumulator) :: aCExactCopy
    integer,dimension(:), pointer :: aCaCIndices1, aCaCIndices2
    integer,dimension(:), pointer :: aVaCIndices1, aVaCIndices2
    integer :: aCaCNumShared, aVaCNumShared
    integer :: i,j,k,ierr

    if( (nRAttr(aC)>0) ) then

       write(device,*) identifier, ":: Testing Copy and SharedAttrIndexList ::"
       write(device,*) identifier, ":: FIRST AV ATTRIBUTES::", &
            " RATTR = ", exportRListToChar(aC%data)
       call init(aCExactCopy,aC,lsize(aC))
       write(device,*) identifier, ":: SECOND AV ATTRIBUTES::", &
            " RATTR = ", exportRListToChar(aCExactCopy%data)
       call zero(aCExactCopy)
       call copy(aVin=aC%data, aVout=aCExactCopy%data)
       call SharedAttrIndexList(aC,aCExactCopy,"REAL   ", &
            aCaCNumShared,aCaCIndices1,aCaCIndices2)
       call SharedAttrIndexList(aC%data,aCExactCopy,"REAL   ", &
            aVaCNumShared,aVaCIndices1,aVaCIndices2)

       if(aCaCNumShared/=aVaCNumShared) then
          call die(myname_,"aCaCNumShared/=aVaCNumShared")
       endif

       do i=1,aCaCNumShared
          if(aCaCIndices1(i)/=aVaCIndices1(i)) then
             call die(myname_,"aCaCIndices1(i)/=aVaCIndices1(i)")
          endif
          if(aCaCIndices2(i)/=aVaCIndices2(i)) then
             call die(myname_,"aCaCIndices2(i)/=aVaCIndices2(i)")
          endif
       enddo

       write(device,*) identifier, ":: Indices1 :: Indices2 :: &
            &Attribute1 :: Attribute2"
       do i=1,aCaCNumShared
          call getRList(ItemStr1,aCaCIndices1(i),aC)
          call getRList(ItemStr2,aCaCIndices2(i),aCExactCopy)
          write(device,*) identifier,":: ", aCaCIndices1(i), "::", &
               aCaCIndices2(i), "::", StringToChar(ItemStr1), "::", &
               StringToChar(ItemStr2)
          call String_clean(ItemStr1)
          call String_clean(ItemStr2)
       enddo

       do i=1,aCaCNumShared
          do j=1,lsize(aC)
             if(aC%data%rAttr(aCaCIndices1(i),j) /= &
                  aCExactCopy%data%rAttr(aCaCIndices2(i),j)) then
                write(device,*) identifier,aCaCIndices1(i),aCaCIndices2(i), j
                call die(myname_,"Copy function is MALFUNCTIONING", ierr)
             endif
          enddo
       enddo

       deallocate(aCaCIndices1,aCaCIndices2,aVaCIndices1,aVaCIndices2,stat=ierr)
       if(ierr/=0) call die(myname_,"deallocate(aCaCIndices,aVaCIndices)",ierr)

       call clean(aCExactCopy)

    else

       write(device,*) identifier, &
            ":: NOT Testing Copy and SharedAttrIndexList ::", &
            ":: Consult m_ACTest.F90 to enable this function::"
    endif

  end subroutine CopyTest_

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::TEST FOR EXPORT AND IMPORT FUNCTIONS:::::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

  subroutine ImportExportTest_(aC,identifier,device)

    use m_Accumulator
    use m_AttrVect, only   : exportIList, exportRList
    use m_AttrVect, only   : exportIListToChar, exportRListToChar
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

    type(Accumulator),          intent(in)  :: aC
    character(len=*),           intent(in)  :: identifier
    integer,                    intent(in)  :: device

    character(len=*),parameter :: myname_=myname//'::ImportExportTest_'
    type(Accumulator) :: importAC
    type(List) :: OutIList, OutRList
    type(String) :: ItemStr
    integer,dimension(:),pointer :: OutIVect
    real(FP), dimension(:),pointer :: OutRVect
    integer :: exportsize
    integer :: i,j,k,ierr

    write(device,*) identifier, ":: Testing import and export functions"

    if(nIAttr(aC)>0) then

       call exportIList(aV=aC%data,outIList=outIList)

       if(.NOT. List_identical(aC%data%iList,outIList)) then
          call die(myname_, "Function exportIList failed!")
       endif

       call List_get(ItemStr=ItemStr,ith=nIAttr(aC),aList=aC%data%iList)

       allocate(outIVect(lsize(aC)),stat=ierr)
       if(ierr/=0) call die(myname_,"allocate(outIVect)")

       call exportIAttr(aC=aC,AttrTag=StringToChar(ItemStr), &
            outVect=OutIVect,lsize=exportsize)

       if(exportsize /= lsize(aC)) then
          call die(myname_,"(exportsize /= lsize(aC))")
       endif

       do i=1,exportsize
          if(aC%data%iAttr(nIAttr(aC),i) /= outIVect(i)) then
             call die(myname_,"Function exportIAttr failed!")
          endif
       enddo

       call init(aC=importAC,bC=aC,lsize=exportsize)
       call zero(importAC)

       call importIAttr(aC=importAC,AttrTag=StringToChar(ItemStr), &
            inVect=outIVect,lsize=exportsize)

       j=indexIA(importAC,StringToChar(ItemStr))
       if(j<=0) call die(myname_,"indexIA(importAC,StringToChar(ItemStr))")
       do i=1,exportsize
          if(importAC%data%iAttr(j,i) /= outIVect(i)) then
             call die(myname_,"Function importIAttr failed!")
          endif
       enddo

       call clean(importAC)
       call List_clean(outIList)
       call String_clean(ItemStr)

       deallocate(outIVect,stat=ierr)
       if(ierr/=0) call die(myname_,"deallocate(outIVect)")

    endif

    if(nRAttr(aC)>0) then

       call exportRList(aV=aC%data,outRList=outRList)

       if(.NOT. List_identical(aC%data%rList,outRList)) then
          call die(myname_, "Function exportRList failed!")
       endif

       call List_get(ItemStr=ItemStr,ith=nRAttr(aC),aList=aC%data%rList)

       allocate(outRVect(lsize(aC)),stat=ierr)
       if(ierr/=0) call die(myname_,"allocate(outRVect)")

       call exportRAttr(aC=aC,AttrTag=StringToChar(ItemStr), &
            outVect=OutRVect,lsize=exportsize)

       if(exportsize /= lsize(aC)) then
          call die(myname_,"(exportsize /= lsize(aC))")
       endif

       do i=1,exportsize
          if(aC%data%rAttr(nRAttr(aC),i) /= outRVect(i)) then
             call die(myname_,"Function exportRAttr failed!")
          endif
       enddo

       call init(aC=importAC,bC=aC,lsize=exportsize)
       call zero(importAC)

       call importRAttr(aC=importAC,AttrTag=StringToChar(ItemStr), &
            inVect=outRVect,lsize=exportsize)

       j=indexRA(importAC,StringToChar(ItemStr))
       if(j<=0) call die(myname_,"indexRA(importAC,StringToChar(ItemStr))")
       do i=1,exportsize
          if(importAC%data%rAttr(j,i) /= outRVect(i)) then
             call die(myname_,"Function importRAttr failed!")
          endif
       enddo

       call clean(importAC)
       call List_clean(outRList)
       call String_clean(ItemStr)

       deallocate(outRVect,stat=ierr)
       if(ierr/=0) call die(myname_,"deallocate(outRVect)")

    endif

  end subroutine ImportExportTest_

  logical function Identical_(ACC1,ACC2,Range)

    use m_Accumulator
    use m_AVTEST,only: AttrVect_identical => Identical
    use m_stdio
    use m_die

    use m_realkinds, only : FP

    implicit none

    type(Accumulator), intent(in) :: ACC1
    type(Accumulator), intent(in) :: ACC2
    real, optional,    intent(in) :: Range

    character(len=*),parameter :: myname_=myname//'::Identical_'
    integer :: i,j,k

    Identical_=.true.

    if(present(Range)) then
       if(.NOT. AttrVect_identical(ACC1%data,ACC2%data,Range)) then
          Identical_=.false.
       endif
    else
       if(.NOT. AttrVect_identical(ACC1%data,ACC2%data)) then
          Identical_=.false.
       endif
    endif

    if(ACC1%num_steps/=ACC2%num_steps) then
       Identical_=.false.
    endif

    if(ACC1%steps_done/=ACC2%steps_done) then
       Identical_=.false.
    endif

    j=0
    k=0

    if(associated(ACC1%iAction).or.associated(ACC2%iAction)) then
       if(size(ACC1%iAction) /= size(ACC2%iAction)) then
          Identical_=.FALSE.
       endif
       j=size(ACC1%iAction)
    endif

    if(associated(ACC1%rAction).or.associated(ACC2%rAction)) then
       if(size(ACC1%rAction) /= size(ACC2%rAction)) then
          Identical_=.FALSE.
       endif
       k=size(ACC2%rAction)
    endif

    do i=1,j
       if(ACC1%iAction(i)/=ACC2%iAction(i)) then
          Identical_=.FALSE.
       endif
    enddo

    do i=1,k
       if(ACC1%rAction(i)/=ACC2%rAction(i)) then
          Identical_=.FALSE.
       endif
    enddo

  end function Identical_


end module m_ACTEST
