!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_List - A List Manager
!
! !DESCRIPTION:  A {\em List} is a character buffer comprising
! substrings called {\em items} separated by colons, combined with
! indexing information describing (1) the starting point in the character
! buffer of each substring, and  (2) the length of each substring.  The
! only constraints on the valid list items are (1) the value of an
! item does not contain the ``\verb":"'' delimitter, and (2) leading
! and trailing blanks are stripped from any character string presented
! to define a list item (although any imbeded blanks are retained).
!
! {\bf Example:}  Suppose we wish to define a List containing the
! items {\tt 'latitude'}, {\tt 'longitude'}, and {\tt 'pressure'}.
! The character buffer of the List containing these items will be the
! 27-character string
! \begin{verbatim}
! 'latitude:longitude:pressure'
! \end{verbatim}
! and the indexing information is summarized in the table below.
!
!\begin{table}[htbp]
!\begin{center}
!\begin{tabular}{|c|c|c|}
!\hline
!{\bf Item} & {\bf Starting Point in Buffer} & {\bf Length} \\
!\hline
!{\tt latitude} & 1 & 8 \\
!\hline
!{\tt longitude} & 9 & 9 \\
!\hline
!{\tt pressure} & 20 & 8\\
!\hline
!\end{tabular}
!\end{center}
!\end{table}
!
! One final note:  All operations for the {\tt List} datatype are
! {\bf case sensitive}.
!
! !INTERFACE:

 module m_List

! !USES:
!
! No other Fortran modules are used.

      implicit none

      private	! except

! !PUBLIC TYPES:

      public :: List		! The class data structure

      Type List
#ifdef SEQUENCE
     sequence
#endif
	 character(len=1),dimension(:),pointer :: bf
	 integer,       dimension(:,:),pointer :: lc
      End Type List

! !PUBLIC MEMBER FUNCTIONS:

      public :: init
      public :: clean
      public :: nullify
      public :: index
      public :: get_indices
      public :: test_indices
      public :: nitem
      public :: get
      public :: identical
      public :: assignment(=)
      public :: allocated
      public :: copy
      public :: exportToChar
      public :: exportToString
      public :: CharBufferSize
      public :: append
      public :: concatenate
      public :: bcast
      public :: send
      public :: recv
      public :: GetSharedListIndices

  interface init ; module procedure	&
      init_,		&
      initStr_,	&
      initstr1_
  end interface
  interface clean; module procedure clean_; end interface
  interface nullify; module procedure nullify_; end interface
  interface index; module procedure	&
      index_,     &
      indexStr_
  end interface
  interface get_indices; module procedure get_indices_; end interface
  interface test_indices; module procedure test_indices_; end interface
  interface nitem; module procedure nitem_; end interface
  interface get  ; module procedure	&
      get_,		&
      getall_,	&
      getrange_
  end interface
  interface identical; module procedure identical_; end interface
  interface assignment(=)
    module procedure copy_
  end interface
  interface allocated ; module procedure &
       allocated_
  end interface
  interface copy ; module procedure copy_ ;  end interface
  interface exportToChar ; module procedure &
       exportToChar_
  end interface
  interface exportToString ; module procedure &
       exportToString_
  end interface
  interface CharBufferSize ; module procedure &
      CharBufferSize_
  end interface
  interface append ; module procedure append_ ; end interface
  interface concatenate ; module procedure concatenate_ ; end interface
  interface bcast; module procedure bcast_; end interface
  interface send; module procedure send_; end interface
  interface recv; module procedure recv_; end interface
  interface GetSharedListIndices; module procedure &
      GetSharedListIndices_
  end interface

! !REVISION HISTORY:
! 22Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 16May01 - J. Larson <larson@mcs.anl.gov> - Several changes / fixes:
!           public interface for copy_(), corrected version of copy_(),
!           corrected version of bcast_().
! 15Oct01 - J. Larson <larson@mcs.anl.gov> - Added the LOGICAL
!           function identical_().
! 14Dec01 - J. Larson <larson@mcs.anl.gov> - Added the LOGICAL
!           function allocated_().
! 13Feb02 - J. Larson <larson@mcs.anl.gov> - Added the List query
!           functions exportToChar() and CharBufferLength().
! 13Jun02-  R.L. Jacob <jacob@mcs.anl.gov> - Move GetSharedListIndices
!           from mct to this module.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT(MPEU)::m_List'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: init_ - Initialize a List from a CHARACTER String
!
! !DESCRIPTION:
!
! A list is a string in the form of ``\verb"Larry:Moe:Curly"'',
! or ``\verb"lat:lon:lev"'', combined with substring location and
! length information.  Through the initialization call, the
! items delimited by ``\verb":"'' are stored as an array of sub-
! strings of a long string, accessible through an array of substring
! indices.  The only constraints now on the valid list entries are,
! (1) the value of an entry does not contain ``\verb":"'', and (2)
! The leading and the trailing blanks are insignificant, although
! any imbeded blanks are.  For example,
!
! \begin{verbatim}
! call init_(aList, 'batman  :SUPERMAN:Green Lantern:  Aquaman')
! \end{verbatim}
! will result in {\tt aList} having four items:  'batman', 'SUPERMAN',
! 'Green Lantern', and 'Aquaman'.  That is
! \begin{verbatim}
! aList%bf =  'batman:SUPERMAN:Green Lantern:Aquaman'
! \end{verbatim}
!
! !INTERFACE:

 subroutine init_(aList,Values)

! !USES:
!
      use m_die,only : die
      use m_mall,only : mall_mci,mall_ison

      implicit none

! !INPUT PARAMETERS:
!
      character(len=*),intent(in) :: Values ! ":" delimited names

! !OUTPUT PARAMETERS:
!
      type(List),intent(out)	  :: aList  ! an indexed string values


! !REVISION HISTORY:
! 22Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::init_'
  character(len=1) :: c
  integer :: ib,ie,id,lb,le,ni,i,ier

	! Pass 1, getting the sizes
  le=0
  ni=0
  ib=1
  ie=0
  id=0
  do i=1,len(Values)
    c=Values(i:i)
    select case(c)
    case(' ')
      if(ib==i) ib=i+1	! moving ib up, starting from the next
    case(':')
      if(ib<=ie) then
	ni=ni+1
	id=1		! mark a ':'
      endif
      ib=i+1		! moving ib up, starting from the next
    case default
      ie=i
      if(id==1) then	! count an earlier marked ':'
	id=0
	le=le+1
      endif
      le=le+1
    end select
  end do
  if(ib<=ie) ni=ni+1

  ! COMPILER MAY NOT SIGNAL AN ERROR IF
  ! ALIST HAS ALREADY BEEN INITIALIZED.
  ! PLEASE CHECK FOR PREVIOUS INITIALIZATION

  allocate(aList%bf(le),aList%lc(0:1,ni),stat=ier)
  if(ier /= 0) call die(myname_,'allocate()',ier)

	if(mall_ison()) then
	  call mall_mci(aList%bf,myname)
	  call mall_mci(aList%lc,myname)
	endif

	! Pass 2, copy the value and assign the pointers
  lb=1
  le=0
  ni=0
  ib=1
  ie=0
  id=0
  do i=1,len(Values)
    c=Values(i:i)

    select case(c)
    case(' ')
      if(ib==i) ib=i+1	! moving ib up, starting from the next
    case(':')
      if(ib<=ie) then
	ni=ni+1
	aList%lc(0:1,ni)=(/lb,le/)
	id=1		! mark a ':'
      endif

      ib=i+1		! moving ib up, starting from the next
      lb=le+2		! skip to the next non-':' and non-','
    case default
      ie=i
      if(id==1) then	! copy an earlier marked ':'
	id=0
	le=le+1
        aList%bf(le)=':'
      endif

      le=le+1
      aList%bf(le)=c
    end select
  end do
  if(ib<=ie) then
    ni=ni+1
    aList%lc(0:1,ni)=(/lb,le/)
  endif

 end subroutine init_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initStr_ - Initialize a List Using the String Type
!
! !DESCRIPTION: This routine initializes a {\tt List} datatype given
! an input {\tt String} datatype (see {\tt m\_String} for more
! information regarding the {\tt String} type).  The contents of the
! input {\tt String} argument {\tt pstr} must adhere to the restrictions
! stated for character input stated in the prologue of the routine
! {\tt init\_()} in this module.
!
! !INTERFACE:

 subroutine initStr_(aList, pstr)

! !USES:
!
      use m_String, only : String,toChar

      implicit none

! !INPUT PARAMETERS:
!
      type(String),intent(in)	  :: pstr

! !OUTPUT PARAMETERS:
!
      type(List),intent(out)	  :: aList  ! an indexed string values


! !REVISION HISTORY:
! 23Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initStr_'

  call init_(aList,toChar(pstr))

 end subroutine initStr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initStr1_ - Initialize a List Using an Array of Strings
!
! !DESCRIPTION: This routine initializes a {\tt List} datatype given
! as input array of {\tt String} datatypes (see {\tt m\_String} for more
! information regarding the {\tt String} type).  The contents of each
! {\tt String} element of the input array {\tt strs} must adhere to the
! restrictions stated for character input stated in the prologue of the
! routine {\tt init\_()} in this module.  Specifically, no element in
! {\tt strs} may contain the colon \verb':' delimiter, and any
! leading or trailing blanks will be stripped (though embedded blank
! spaces will be retained).  For example, consider an invocation of
! {\tt initStr1\_()} where the array {\tt strs(:)} contains four entries:
! {\tt strs(1)='John'}, {\tt strs(2)=' Paul'},
! {\tt strs(3)='George '}, and {\tt strs(4)='  Ringo'}.  The resulting
! {\tt List} output {\tt aList} will have
! \begin{verbatim}
! aList%bf =  'John:Paul:George:Ringo'
! \end{verbatim}
! !INTERFACE:

 subroutine initStr1_(aList, strs)

! !USES:
!
      use m_String, only : String,toChar
      use m_String, only : len
      use m_String, only : ptr_chars
      use m_die,only : die

      implicit none

! !INPUT PARAMETERS:
!
      type(String),dimension(:),intent(in)	  :: strs

! !OUTPUT PARAMETERS:
!
      type(List),intent(out)	  :: aList  ! an indexed string values


! !REVISION HISTORY:
! 23Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initStr1_'
  character(len=1),allocatable,dimension(:) :: ch1
  integer :: ier
  integer :: n,i,lc,le

  n=size(strs)
  le=0
  do i=1,n
    le=le+len(strs(i))
  end do
  le=le+n-1	! for n-1 ":"s

	allocate(ch1(le),stat=ier)
		if(ier/=0) call die(myname_,'allocate()',ier)

  le=0
  do i=1,n
    if(i>1) then
      le=le+1
      ch1(le)=':'
    endif

    lc=le+1
    le=le+len(strs(i))
    ch1(lc:le)=ptr_chars(strs(i))
  end do

  call init_(aList,toChar(ch1))

	deallocate(ch1,stat=ier)
		if(ier/=0) call die(myname_,'deallocate()',ier)

 end subroutine initStr1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: clean_ - Deallocate Memory Used by a List
!
! !DESCRIPTION:  This routine deallocates the allocated memory components
! of the input/output {\tt List} argument {\tt aList}.  Specifically, it
! deallocates {\tt aList\%bf} and {\tt aList\%lc}.  If the optional
! output {\tt INTEGER} arguemnt {\tt stat} is supplied, no warning will
! be printed if the Fortran intrinsic {\tt deallocate()} returns with an
! error condition.
!
! !INTERFACE:

 subroutine clean_(aList, stat)

! !USES:
!
      use m_die,  only : warn
      use m_mall, only : mall_mco,mall_ison

      implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      type(List),        intent(inout) :: aList

! !OUTPUT PARAMETERS:
!
      integer, optional, intent(out)   :: stat

! !REVISION HISTORY:
! 22Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!  1Mar02 - E.T. Ong <eong@mcs.anl.gov> - added stat argument and
!           removed die to prevent crashes.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::clean_'
  integer :: ier

  if(mall_ison()) then
     if(associated(aList%bf)) call mall_mco(aList%bf,myname_)
     if(associated(aList%lc)) call mall_mco(aList%lc,myname_)
  endif

  if(associated(aList%bf) .and. associated(aList%lc)) then

     deallocate(aList%bf, aList%lc, stat=ier)

     if(present(stat)) then
	stat=ier
     else
	if(ier /= 0) call warn(myname_,'deallocate(aList%...)',ier)
     endif

  endif

 end subroutine clean_

!--- -------------------------------------------------------------------
!     Math + Computer Science Division / Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: nullify_ - Nullify Pointers in a List
!
! !DESCRIPTION:  In Fortran 90, pointers may have three states:
! (1) {\tt ASSOCIATED}, that is the pointer is pointing at a target,
! (2) {\tt UNASSOCIATED}, and (3) {\tt UNINITIALIZED}.  On some
! platforms, the Fortran intrinsic function {\tt associated()}
! will view uninitialized pointers as {\tt UNASSOCIATED} by default.
! This is not always the case.  It is good programming practice to
! nullify pointers if they are not to be used.  This routine nullifies
! the pointers present in the {\tt List} datatype.
!
! !INTERFACE:

 subroutine nullify_(aList)

! !USES:
!
      use m_die,only : die

      implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      type(List),intent(inout) :: aList

! !REVISION HISTORY:
! 18Jun01 - J.W. Larson - <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::nullify_'

  nullify(aList%bf)
  nullify(aList%lc)

 end subroutine nullify_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: nitem_ - Return the Number of Items in a List
!
! !DESCRIPTION:
! This function enumerates the number of items in the input {\tt List}
! argument {\tt aList}.  For example, suppose
! \begin{verbatim}
!  aList%bf = 'John:Paul:George:Ringo'
! \end{verbatim}
!  Then,
! $${\tt nitem\_(aList)} = 4 .$$
!
! !INTERFACE:

 integer function nitem_(aList)

! !USES:
!
      implicit none

! !INPUT PARAMETERS:
!
      type(List),intent(in) :: aList

! !REVISION HISTORY:
! 22Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 10Oct01 - J.W. Larson <larson@mcs.anl.gov> - modified routine to
!           check pointers aList%bf and aList%lc using  the f90
!           intrinsic ASSOCIATED before proceeding with the item
!           count.  If these pointers are UNASSOCIATED, an item
!           count of zero is returned.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::nitem_'
  integer :: NumItems

       ! Initialize item count to zero

  NumItems = 0

       ! If the List pointers are ASSOCIATED, perform item count:

  if(ASSOCIATED(aList%bf) .and. ASSOCIATED(aList%lc)) then
     NumItems = size(aList%lc,2)
  endif

  nitem_ = NumItems

 end function nitem_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: index_ - Return Rank in a List of a Given Item (CHARACTER)
!
! !DESCRIPTION:
! This function returns the rank of an item (defined by the
! {\tt CHARACTER} argument {\tt item}) in the input {\tt List} argument
! {\tt aList}.  If {\tt item} is not present in {\tt aList}, then zero
! is returned.  For example, suppose
! \begin{verbatim}
!  aList%bf = 'Bob:Carol:Ted:Alice'
! \end{verbatim}
!  Then, ${\tt index\_(aList, 'Ted')}=3$, ${\tt index\_(aList, 'Carol')}=2$,
! and ${\tt index\_(aList, 'The Dude')}=0.$
!
! !INTERFACE:

 integer function index_(aList, item)

! !USES:
!
      use m_String, only : toChar

      implicit none

! !INPUT PARAMETERS:
!
      type(List),      intent(in) :: aList	! a List of names
      character(len=*),intent(in) :: item	! a given item name

! !REVISION HISTORY:
! 22Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::index_'
  integer :: i,lb,le
  integer :: itemLength, length, nMatch, j

       ! How long is the input item name?

  itemLength = len(item)

       ! Set output to zero (no item match) value:

  index_=0

       ! Now, go through the aList one item at a time

  ITEM_COMPARE: do i=1,size(aList%lc,2)		! == nitem_(aList)

       ! Compute some stats for the current item in aList:

    lb=aList%lc(0,i) ! starting index of item in aList%bf
    le=aList%lc(1,i) ! ending index item in aList%bf

    length = le -lb + 1 ! length of the current item
    if(length /= itemLength) then ! this list item can't match input item

       CYCLE ! that is, jump to the next item in aList...

    else ! compare one character at a time...

       ! Initialize number of matching characters in the two strings

       nMatch = 0

       ! Now, compare item to the current item in aList one character
       ! at a time:

       CHAR_COMPARE: do j=1,length
	  if(aList%bf(lb+j-1) == item(j:j)) then ! a match for this character
	     nMatch = nMatch + 1
	  else
	     EXIT
	  endif
       end do CHAR_COMPARE

       ! Check the number of leading characters in the current item in aList
       ! that match the input item.  If it is equal to the item length, then
       ! we have found a match and are finished.  Otherwise, we cycle on to
       ! the next item in aList.

       if(nMatch == itemLength) then
	  index_ = i
	  EXIT
       endif

! Old code that does not work with V. of the IBM
!    if(item==toChar(aList%bf(lb:le))) then
!      index_=i
!      exit
    endif
  end do ITEM_COMPARE

 end function index_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: indexStr_ - Return Rank in a List of a Given Item (String)
!
! !DESCRIPTION:
! This function performs the same operation as the function
! {\tt index\_()}, but the item to be indexed is instead presented in
! the form of a {\tt String} datatype (see the module {\tt m\_String}
! for more information about the {\tt String} type).  This routine
! searches through the input {\tt List} argument {\tt aList} for an
! item that matches the item defined by {\tt itemStr}, and if a match
! is found, the rank of the item in the list is returned (see also the
! prologue for the routine {\tt index\_()} in this module).  If no match
! is found, a value of zero is returned.
!
! !INTERFACE:

 integer function indexStr_(aList, itemStr)

! !USES:
!
      use m_String,only : String,toChar

      implicit none

! !INPUT PARAMETERS:
!
      type(List),      intent(in) :: aList	! a List of names
      type(String),    intent(in) :: itemStr

! !REVISION HISTORY:
! 22Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 25Oct02 - R. Jacob <jacob@mcs.anl.gov> - just call index_ above
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::indexStr_'

  indexStr_=0
  indexStr_=index_(aList,toChar(itemStr))

 end function indexStr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: allocated_ - Check Pointers in a List for Association Status
!
! !DESCRIPTION:
! This function checks the input {\tt List} argument {\tt inList} to
! determine whether or not it has been allocated.  It does this by
! invoking the Fortran90 intrinsic function {\tt associated()} on the
! pointers {\tt inList\%bf} and {\tt inList\%lc}.  If both of these
! pointers are associated, the return value is {\tt .TRUE.}.
!
! {\bf N.B.:}  In Fortran90, pointers have three different states:
! {\tt ASSOCIATED}, {\tt UNASSOCIATED}, and {\tt UNDEFINED}.
!  If a pointer is {\tt UNDEFINED}, this function may return either
! {\tt .TRUE.} or {\tt .FALSE.} values, depending on the Fortran90
! compiler.  To avoid such problems, we advise that users invoke the
! {\tt List} method {\tt nullify()} to nullify any {\tt List} pointers
! for {\tt List} variables that are not initialized.
!
! !INTERFACE:

 logical function allocated_(inList)

! !USES:

      use m_die,only : die

      implicit none

! !INPUT PARAMETERS:

      type(List), intent(in) :: inList

! !REVISION HISTORY:
! 14Dec01 - J. Larson <larson@mcs.anl.gov> - inital version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::allocated_'

  allocated_ = associated(inList%bf) .and. associated(inList%lc)

 end function allocated_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: copy_ - Copy a List
!
! !DESCRIPTION:
! This routine copies the contents of the input {\tt List} argument
! {\tt xL} into the output {\tt List} argument {\tt yL}.
!
! !INTERFACE:

 subroutine copy_(yL,xL)	! yL=xL

! !USES:
!
      use m_die,only : die
      use m_stdio
      use m_String ,only : String
      use m_String ,only : String_clean
      use m_mall,only : mall_mci,mall_ison

      implicit none

! !INPUT PARAMETERS:
!
      type(List),intent(in)  :: xL

! !OUTPUT PARAMETERS:
!
      type(List),intent(out) :: yL


! !REVISION HISTORY:
! 22Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 16May01 - J. Larson <larson@mcs.anl.gov> - simpler, working
!           version that exploits the String datatype (see m_String)
!  1Aug02 - Larson/Ong - Added logic for correct copying of blank
!           Lists.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::copy_'
  type(String) DummStr

  if(size(xL%lc,2) > 0) then

       ! Download input List info from xL to String DummStr

     call getall_(DummStr,xL)

       ! Initialize yL from DummStr

     call initStr_(yL,DummStr)

     call String_clean(DummStr)

  else
     if(size(xL%lc,2) < 0) then ! serious error...
	write(stderr,'(2a,i8)') myname_, &
	     ':: FATAL size(xL%lc,2) = ',size(xL%lc,2)
     endif
       ! Initialize yL as a blank list
     call init_(yL, ' ')
  endif

 end subroutine copy_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: exportToChar_ - Export List to a CHARACTER
!
! !DESCRIPTION:  This function returns the character buffer portion of
! the input {\tt List} argument {\tt inList}---that is, the contents of
! {\tt inList\%bf}---as a {\tt CHARACTER} (suitable for printing).  An
! example of the use of this function is:
! \begin{verbatim}
!           write(stdout,'(1a)') exportToChar(inList)
! \end{verbatim}
! which writes the contents of {\tt inList\%bf} to the Fortran device
! {\tt stdout}.
!
! !INTERFACE:

 function exportToChar_(inList)

! !USES:
!
      use m_die,    only : die
      use m_stdio,  only : stderr
      use m_String, only : String
      use m_String, only : String_ToChar => toChar
      use m_String, only : String_clean

      implicit none

! ! INPUT PARAMETERS:

      type(List),        intent(in)  :: inList

! ! OUTPUT PARAMETERS:

      character(len=size(inList%bf,1)) :: exportToChar_

! !REVISION HISTORY:
! 13Feb02 - J. Larson <larson@mcs.anl.gov> - initial version.
! 06Jun03 - R. Jacob <jacob@mcs.anl.gov> - return blank if List is not allocated
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::exportToChar_'
  type(String) DummStr

       ! Download input List info from inList to String DummStr
  if(allocated_(inList)) then
     call getall_(DummStr,inList)
     exportToChar_ = String_ToChar(DummStr)
     call String_clean(DummStr)
  else
     exportToChar_ = ''
  endif

 end function exportToChar_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: exportToString_ - Export List to a String
!
! !DESCRIPTION:  This function returns the character buffer portion of
! the input {\tt List} argument {\tt inList}---that is, the contents of
! {\tt inList\%bf}---as a {\tt String} (see the mpeu module m\_String
! for more information regarding the {\tt String} type).  This function
! was created to circumvent problems with implementing inheritance of
! the function {\tt exportToChar\_()} to other datatypes build on top
! of the {\tt List} type.
!
! !INTERFACE:

 function exportToString_(inList)

! !USES:
!
      use m_die,    only : die
      use m_stdio,  only : stderr

      use m_String, only : String
      use m_String, only : String_init => init

      implicit none

! ! INPUT PARAMETERS:

      type(List),       intent(in) :: inList

! ! OUTPUT PARAMETERS:

      type(String)                 :: exportToString_

! !REVISION HISTORY:
! 14Aug02 - J. Larson <larson@mcs.anl.gov> - initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::exportToString_'

  if(allocated_(inList)) then
     call getall_(exportToString_, inList)
  else
     call String_init(exportToString_, 'NOTHING')
  endif

 end function exportToString_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: CharBufferSize_ - Return size of a List's Character Buffer
!
! !DESCRIPTION:  This function returns the length of the character
! buffer portion of the input {\tt List} argument {\tt inList} (that
! is, the number of characters stored in {\tt inList\%bf}) as an
! {\tt INTEGER}.  Suppose for the sake of argument that {\tt inList}
! was created using the following call to {\tt init\_()}:
! \begin{verbatim}
!  call init_(inList, 'Groucho:Harpo:Chico:Zeppo')
! \end{verbatim}
! Then, using the above example value of {\tt inList}, we can use
! {\tt CharBufferSize\_()} as follows:
! \begin{verbatim}
! integer :: BufferLength
! BufferLength = CharBufferSize(inList)
! \end{verbatim}
! and the resulting value of {\tt BufferLength} will be 25.
!
! !INTERFACE:

 integer function CharBufferSize_(inList)

! !USES:
!
      use m_die,    only : die
      use m_stdio,  only : stderr

      implicit none

! ! INPUT PARAMETERS:

      type(List),         intent(in) :: inList

! !REVISION HISTORY:
! 13Feb02 - J. Larson <larson@mcs.anl.gov> - initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::CharBufferSize_'

  if(allocated_(inList)) then
     CharBufferSize_ = size(inList%bf)
  else
     write(stderr,'(2a)') myname_,":: Argument inList not allocated."
     call die(myname_)
  endif

 end function CharBufferSize_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: get_ - Retrieve a Numbered Item from a List as a String
!
! !DESCRIPTION:
! This routine retrieves a numbered item (defined by the input
! {\tt INTEGER} argument {\tt ith}) from the input {\tt List} argument
! {\tt aList}, and returns it in the output {\tt String} argument
! {\tt itemStr} (see the module {\tt m\_String} for more information
! about the {\tt String} type).  If the argument {\tt ith} is nonpositive,
! or greater than the number of items in {\tt aList}, a String containing
! one blank space is returned.
!
! !INTERFACE:

 subroutine get_(itemStr, ith, aList)

! !USES:
!
      use m_String, only : String, init, toChar

      implicit none

! !INPUT PARAMETERS:
!
      integer,     intent(in)  :: ith
      type(List),  intent(in)  :: aList

! !OUTPUT PARAMETERS:
!
      type(String),intent(out) :: itemStr


! !REVISION HISTORY:
! 23Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 14May07 - Larson, Jacob - add space to else case string so function
!                           matches documentation.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::get_'
  integer :: lb,le

  if(ith>0 .and. ith <= size(aList%lc,2)) then
    lb=aList%lc(0,ith)
    le=aList%lc(1,ith)
    call init(itemStr,toChar(aList%bf(lb:le)))
  else
    call init(itemStr,' ')
  endif

 end subroutine get_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: getall_ - Return all Items from a List as one String
!
! !DESCRIPTION:
! This routine returns all the items from the input {\tt List} argument
! {\tt aList} in the output {\tt String} argument {\tt itemStr} (see
! the module {\tt m\_String} for more information about the {\tt String}
! type).  The contents of the character buffer in {\tt itemStr} will
! be the all of the items in {\tt aList}, separated by the colon delimiter.
!
! !INTERFACE:

 subroutine getall_(itemStr, aList)

! !USES:
!
      use m_String, only : String, init, toChar

      implicit none

! !INPUT PARAMETERS:
!
      type(List),   intent(in)  :: aList

! !OUTPUT PARAMETERS:
!
      type(String), intent(out) :: itemStr


! !REVISION HISTORY:
! 23Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::getall_'
  integer :: lb,le,ni

  ni=size(aList%lc,2)
  lb=aList%lc(0,1)
  le=aList%lc(1,ni)
  call init(itemStr,toChar(aList%bf(lb:le)))

 end subroutine getall_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: getrange_ - Return a Range of Items from a List as one String
!
! !DESCRIPTION:
! This routine returns all the items ranked {\tt i1} through {\tt i2}
! from the input {\tt List} argument {\tt aList} in the output
! {\tt String} argument {\tt itemStr} (see the module {\tt m\_String}
! for more information about the {\tt String} type).  The contents of
! the character buffer in {\tt itemStr} will be items in {\tt i1} through
! {\tt i2} {\tt aList}, separated by the colon delimiter.
!
! !INTERFACE:

 subroutine getrange_(itemStr, i1, i2, aList)

! !USES:
!
      use m_die,    only : die
      use m_stdio,  only : stderr
      use m_String, only : String,init,toChar

      implicit none

! !INPUT PARAMETERS:
!
      integer,     intent(in)  :: i1
      integer,     intent(in)  :: i2
      type(List),  intent(in)  :: aList

! !OUTPUT PARAMETERS:
!
      type(String),intent(out) :: itemStr

! !REVISION HISTORY:
! 23Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 26Jul02 - J. Larson - Added argument checks.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::getrange_'
  integer :: lb,le,ni

       ! Argument Sanity Checks:

  if(.not. allocated_(aList)) then
     write(stderr,'(2a)') myname_, &
	  ':: FATAL--List argument aList is not initialized.'
     call die(myname_)
  endif

       ! is i2 >= i1 as we assume?

  if(i1 > i2) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: FATAL.  Starting/Ending item ranks are out of order; ', &
	  'i2 must be greater or equal to i1.  i1 =',i1,' i2 = ',i2
     call die(myname_)
  endif

  ni=size(aList%lc,2) ! the number of items in aList...

       ! is i1 or i2 too big?

  if(i1 > ni) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: FATAL--i1 is greater than the number of items in ', &
	  'The List argument aList: i1 =',i1,' ni = ',ni
     call die(myname_)
  endif

  if(i2 > ni) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: FATAL--i2 is greater than the number of items in ', &
	  'The List argument aList: i2 =',i2,' ni = ',ni
     call die(myname_)
  endif

       ! End of Argument Sanity Checks.

  lb=aList%lc(0,max(1,i1))
  le=aList%lc(1,min(ni,i2))
  call init(itemStr,toChar(aList%bf(lb:le)))

 end subroutine getrange_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: identical_ - Compare Two Lists for Equality
!
! !DESCRIPTION:
! This function compares the string buffer and indexing information in
! the two input {\tt List} arguments {\tt yL} and {\tt xL}.  If the
! string buffers and index buffers of {\tt yL} and {\tt xL} match, this
! function returns a value of {\tt .TRUE.}  Otherwise, it returns a
! value of {\tt .FALSE.}
!
! !INTERFACE:

 logical function identical_(yL, xL)

! !USES:
!
      use m_die,only : die
      use m_String ,only : String
      use m_String ,only : String_clean

      implicit none

! !INPUT PARAMETERS:
!
      type(List), intent(in) :: yL
      type(List), intent(in) :: xL

! !REVISION HISTORY:
! 14Oct01 - J. Larson <larson@mcs.anl.gov> - original version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::identical_'

  logical :: myIdentical
  type(String) :: DummStr
  integer :: n, NumItems

       ! Compare the number of the items in the Lists xL and yL.
       ! If they differ, myIdentical is set to .FALSE. and we are
       ! finished.  If both Lists sport the same number of items,
       ! we must compare them one-by-one...

  myIdentical = .FALSE.

  if(nitem_(yL) == nitem_(xL)) then

     NumItems = nitem_(yL)

     COMPARE_LOOP:  do n=1,NumItems

	call get_(DummStr, n, yL)  ! retrieve nth tag as a String

	if( indexStr_(xL, Dummstr) /= n ) then ! a discrepency spotted.
	   call String_clean(Dummstr)
	   myIdentical = .FALSE.
	   EXIT
	else
	   call String_clean(Dummstr)
	endif

	   myIdentical = .TRUE.   ! we survived the whole test process.

     end do COMPARE_LOOP

  endif

  identical_ = myIdentical

 end function identical_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: get_indices_ - Index Multiple Items in a List
!
! !DESCRIPTION:  This routine takes as input a {\tt List} argument
! {\tt aList}, and a {\tt CHARACTER} string {Values}, which is a colon-
! delimited string of items, and returns an {\tt INTEGER} array
! {\tt indices(:)}, which contain the rank of each item in {\tt aList}.
! For example, suppose {\tt aList} was created from the character string
! \begin{verbatim}
! 'happy:sleepy:sneezey:grumpy:dopey::bashful:doc'
! \end{verbatim}
! and get\_indices\_() is invoked as follows:
! \begin{verbatim}
! call get_indices_(indices, aList, 'sleepy:grumpy:bashful:doc')
! \end{verbatim}
! The array {\tt indices(:)} will be returned with 4 entries:
! ${\tt indices(1)}=2$, ${\tt indices(2)}=4$, ${\tt indices(3)}=6$, and
! ${\tt indices(4)}=7$.
!
! {\bf N.B.}:  This routine operates on the assumption that each of the
! substrings in the colon-delimited string {\tt Values} is an item in
! {\tt aList}.  If this assumption is invalid, this routine terminates
! execution with an error message.
!
! {\bf N.B.}:  The pointer {\tt indices} must be {\tt UNASSOCIATED} on entry
! to this routine, and will be {\tt ASSOCIATED} upon return.  After this pointer
! is no longer needed, it should be deallocated.  Failure to do so will result
! in a memory leak.
!
! !INTERFACE:

 subroutine get_indices_(indices, aList, Values)

! !USES:
!
      use m_stdio
      use m_die
      use m_String, only : String
      use m_String, only : String_clean => clean
      use m_String, only : String_toChar => toChar

      implicit none

! !INPUT PARAMETERS:
!
      type(List),            intent(in)	:: aList  ! an indexed string values
      character(len=*),      intent(in) :: Values ! ":" delimited names

! !OUTPUT PARAMETERS:
!
      integer, dimension(:), pointer    :: indices

! !REVISION HISTORY:
! 31May98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 12Feb03 - J. Larson <larson@mcs.anl.gov> Working refactored version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::get_indices_'
  type(List)   :: tList
  type(String) :: tStr
  integer :: i, ierr, n

       ! Create working list based on input colon-delimited string

  call init_(tList, values)


       ! Count items in tList and allocate indices(:) accordingly

  n = nitem_(tList)

  if(n > nitem_(aList)) then
     write(stderr,'(5a,2(i8,a))') myname_, &
	  ':: FATAL--more items in argument Values than aList!  Input string', &
	  'Values = "',Values,'" has ',n,' items.  aList has ',nitem_(aList),  &
	  ' items.'
     call die(myname_)
  endif
  allocate(indices(n), stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8,a)') myname_, &
	  ':: FATAL--allocate(indices(...) failed with stat=',ierr,&
	  '.  On entry to this routine, this pointer must be NULL.'
     call die(myname_)
  endif

       ! Retrieve each item from tList as a String and index it

  do i=1,n
    call get_(tStr,i,tList)
    indices(i) = indexStr_(aList,tStr)
    if(indices(i) == 0) then ! ith item not present in aList!
       write(stderr,'(4a)') myname_, &
	    ':: FATAL--item "',String_toChar(tStr),'" not found.'
       call die(myname_)
    endif
    call String_clean(tStr)
  end do

       ! Clean up temporary List tList

  call clean_(tList)

 end subroutine get_indices_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: test_indices_ - Test/Index Multiple Items in a List
!
! !DESCRIPTION:  This routine takes as input a {\tt List} argument
! {\tt aList}, and a {\tt CHARACTER} string {Values}, which is a colon-
! delimited string of items, and returns an {\tt INTEGER} array
! {\tt indices(:)}, which contain the rank of each item in {\tt aList}.
! For example, suppose {\tt aList} was created from the character string
! \begin{verbatim}
! 'happy:sleepy:sneezey:grumpy:dopey::bashful:doc'
! \end{verbatim}
! and {\tt test\_indices\_()} is invoked as follows:
! \begin{verbatim}
! call test_indices_(indices, aList, 'sleepy:grumpy:bashful:doc')
! \end{verbatim}
! The array {\tt indices(:)} will be returned with 4 entries:
! ${\tt indices(1)}=2$, ${\tt indices(2)}=4$, ${\tt indices(3)}=6$, and
! ${\tt indices(4)}=7$.
!
! Now suppose {\tt test\_indices\_()} is invoked as follows:
! \begin{verbatim}
! call test_indices_(indices, aList, 'sleepy:grumpy:bashful:Snow White')
! \end{verbatim}
! The array {\tt indices(:)} will be returned with 4 entries:
! ${\tt indices(1)}=2$, ${\tt indices(2)}=4$, ${\tt indices(3)}=6$, and
! ${\tt indices(4)}=0$.
!
! {\bf N.B.}:  This routine operates on the assumption that one or more
! of the substrings in the colon-delimited string {\tt Values} is may not
! be an item in {\tt aList}.  If an item in {\tt Values} is {\em not} in
! {\tt aList}, its corresponding entry in {\tt indices(:)} is set to zero.
!
! {\bf N.B.}:  The pointer {\tt indices} must be {\tt UNASSOCIATED} on entry
! to this routine, and will be {\tt ASSOCIATED} upon return.  After this pointer
! is no longer needed, it should be deallocated.  Failure to do so will result
! in a memory leak.
!
! !INTERFACE:

 subroutine test_indices_(indices, aList, Values)

! !USES:
!
      use m_stdio
      use m_die
      use m_String, only : String
      use m_String, only : String_clean => clean
      use m_String, only : String_toChar => toChar

      implicit none

! !INPUT PARAMETERS:
!
      type(List),            intent(in)	:: aList  ! an indexed string values
      character(len=*),      intent(in) :: Values ! ":" delimited names

! !OUTPUT PARAMETERS:
!
      integer, dimension(:), pointer    :: indices

! !REVISION HISTORY:
! 12Feb03 - J. Larson <larson@mcs.anl.gov> Working refactored version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::test_indices_'
  type(List)   :: tList
  type(String) :: tStr
  integer :: i, ierr, n

       ! Create working list based on input colon-delimited string

  call init_(tList, values)


       ! Count items in tList and allocate indices(:) accordingly

  n = nitem_(tList)
  allocate(indices(n), stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8,a)') myname_, &
	  ':: FATAL--allocate(indices(...) failed with stat=',ierr,&
	  '.  On entry to this routine, this pointer must be NULL.'
     call die(myname_)
  endif

       ! Retrieve each item from tList as a String and index it

  do i=1,n
    call get_(tStr,i,tList)
    indices(i) = indexStr_(aList,tStr)
    call String_clean(tStr)
  end do

       ! Clean up temporary List tList

  call clean_(tList)

 end subroutine test_indices_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: append_ - Append One List Onto the End of Another
!
! !DESCRIPTION:  This routine takes two {\tt List} arguments
! {\tt iList1} and {\tt iList2}, and appends {\tt List2} onto
! the end of {\tt List1}.
!
! {\bf N.B.}:  There is no check for shared items in the arguments
! {\tt List1} and {\tt List2}.  It is the user's responsibility to
! ensure {\tt List1} and {\tt List2} share no items.  If this routine
! is invoked in such a manner that {\tt List1} and {\tt List2} share
! common items, the resultant value of {\tt List1} will produce
! ambiguous results for some of the {\tt List} query functions.
!
! {\bf N.B.}:  The outcome of this routine is order dependent.  That is,
! the entries of {\tt iList2} will follow the {\em input} entries in
! {\tt iList1}.
!
! !INTERFACE:

    subroutine append_(iList1, iList2)
!
! !USES:
!
      use m_stdio
      use m_die, only : die

      use m_mpif90

      use m_String, only:  String
      use m_String, only:  String_toChar => toChar
      use m_String, only:  String_len
      use m_String, only:  String_clean => clean

      implicit none

! !INPUT PARAMETERS:
!
      type(List),         intent(in)    :: iList2

! !INPUT/OUTPUT PARAMETERS:
!
      type(List),         intent(inout) :: iList1

! !REVISION HISTORY:
!  6Aug02 - J. Larson - Initial version
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::append_'

  type(List) :: DummyList

  call copy_(DummyList, iList1)
  call clean_(iList1)
  call concatenate(DummyList, iList2, iList1)
  call clean_(DummyList)

 end subroutine append_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: concatenate_ - Concatenates two Lists to form a Third List.
!
! !DESCRIPTION:  This routine takes two input {\tt List} arguments
! {\tt iList1} and {\tt iList2}, and concatenates them, producing an
! output {\tt List} argument {\tt oList}.
!
! {\bf N.B.}:  The nature of this routine is such that one must
! {\bf never} supply as the actual value of {\tt oList} the same
! value supplied for either {\tt iList1} or {\tt iList2}.
!
! {\bf N.B.}:  The outcome of this routine is order dependent.  That is,
! the entries of {\tt iList2} will follow {\tt iList1}.
!
! !INTERFACE:

    subroutine concatenate_(iList1, iList2, oList)
!
! !USES:
!
      use m_stdio
      use m_die, only : die

      use m_mpif90

      use m_String, only:  String
      use m_String, only:  String_init => init
      use m_String, only:  String_clean => clean

      implicit none

! !INPUT PARAMETERS:
!
      type(List),         intent(in)  :: iList1
      type(List),         intent(in)  :: iList2

! !OUTPUT PARAMETERS:
!
      type(List),         intent(out) :: oList

! !BUGS:  For now, the List concatenate algorithm relies on fixed-length
! CHARACTER variables as intermediate storage.  The lengths of these
! scratch variables is hard-wired to 10000, which should be large enough
! for most applications.  This undesirable feature should be corrected
! ASAP.
!
! !REVISION HISTORY:
!  8May01 - J.W. Larson - initial version.
! 17May01 - J.W. Larson - Re-worked and tested successfully.
! 17Jul02 - E. Ong - fixed the bug mentioned above
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::concatenate_'

 character, dimension(:), allocatable :: CatBuff
 integer :: CatBuffLength, i, ierr, Length1, Length2
 type(String) :: CatString

       ! First, handle the case of either iList1 and/or iList2 being
       ! null

  if((nitem_(iList1) == 0) .or. (nitem_(iList2) == 0)) then

     if((nitem_(iList1) == 0) .and. (nitem_(iList2) == 0)) then
	call init_(oList,'')
     else
	if((nitem_(iList1) == 0) .and. (nitem_(iList2) > 0)) then
	   call copy_(oList, iList2)
	endif
	if((nitem_(iList1) > 0) .and. (nitem_(iList2) == 0)) then
	   call copy_(oList,iList1)
	endif
     endif

  else ! both lists are non-null

       ! Step one:  Get lengths of character buffers of iList1 and iList2:

     Length1 = CharBufferSize_(iList1)
     Length2 = CharBufferSize_(iList2)

       ! Step two:  create CatBuff(:) as workspace

     CatBuffLength =  Length1 + Length2 + 1
     allocate(CatBuff(CatBuffLength), stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: FATAL--allocate(CatBuff(...) failed.  ierr=',ierr
	call die(myname_)
     endif

       ! Step three:  concatenate CHARACTERs with the colon separator
       ! into CatBuff(:)

     do i=1,Length1
	CatBuff(i) = iList1%bf(i)
     end do

     CatBuff(Length1 + 1) = ':'

     do i=1,Length2
	CatBuff(Length1 + 1 + i) = iList2%bf(i)
     end do

       ! Step four:  initialize a String CatString:

     call String_init(CatString, CatBuff)

       ! Step five:  initialize oList:

     call  initStr_(oList, CatString)

       ! The concatenation is complete.  Now, clean up

     call String_clean(CatString)

     deallocate(CatBuff,stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: FATAL--deallocate(CatBuff) failed.  ierr=',ierr
	call die(myname_)
     endif

  endif

 end subroutine concatenate_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: bcast_ - MPI Broadcast for the List Type
!
! !DESCRIPTION:  This routine takes an input {\tt List} argument
! {\tt iList} (on input, valid on the root only), and broadcasts it.
!
! {\bf N.B.}:  The outcome of this routine, {\tt ioList} on non-root
! processes, represents allocated memory.  When this {\tt List} is
! no longer needed, it must be deallocated by invoking the routine
! {\tt List\_clean()}.  Failure to do so will cause a memory leak.
!
! !INTERFACE:

    subroutine bcast_(ioList, root, comm, status)
!
! !USES:
!
      use m_stdio,  only : stderr
      use m_die, only : MP_perr_die, die

      use m_String, only:  String
      use m_String, only:  String_bcast => bcast
      use m_String, only:  String_clean => clean

      use m_mpif90

      implicit none

! !INPUT PARAMETERS:
!
      integer,            intent(in)     :: root
      integer,            intent(in)     :: comm

! !INPUT/OUTPUT PARAMETERS:
!
      type(List),         intent(inout)  :: ioList


! !OUTPUT PARAMETERS:
!
      integer, optional,  intent(out)    :: status

! !REVISION HISTORY:
!  7May01 - J.W. Larson - initial version.
! 14May01 - R.L. Jacob - fix error checking
! 16May01 - J.W. Larson - new, simpler String-based algorigthm
!           (see m_String for details), which works properly on
!           the SGI platform.
! 13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize status
!           (if present).
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::bcast_'
 integer :: myID, ierr
 type(String) :: DummStr

      ! Initialize status (if present)

  if(present(status)) status = 0

       ! Which process am I?

  call MPI_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) then
   if(present(status)) then
     status = ierr
     write(stderr,'(2a,i4)') myname_,":: MPI_COMM_RANK(), ierr=",ierr
     return
   else
     call MP_perr_die(myname_,"MPI_COMM_RANK()",ierr)
   endif
  endif

       ! on the root, convert ioList into the String variable DummStr

  if(myID == root) then
     if(CharBufferSize_(ioList) <= 0) then
	call die(myname_, 'Attempting to broadcast an empty list!',&
	     CharBufferSize_(ioList))
     endif
     call getall_(DummStr, ioList)
  endif

       ! Broadcast DummStr

  call String_bcast(DummStr, root, comm, ierr)
  if(ierr /= 0) then
   if(present(status)) then
     status = ierr
     write(stderr,'(2a,i4)') myname_,":: call String_bcast(), ierr=",ierr
     return
   else
     call MP_perr_die(myname_,"String_bcast() failed, stat=",ierr)
   endif
  endif

       ! Initialize ioList off the root using DummStr

  if(myID /= root) then
     call initStr_(ioList, DummStr)
  endif

       ! And now, the List broadcast is complete.

  call String_clean(DummStr)

 end subroutine bcast_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: send_ - MPI Point-to-Point Send for the List Type
!
! !DESCRIPTION:  This routine takes an input {\tt List} argument
! {\tt inList} and sends it to processor {\tt dest} on the communicator
! associated with the fortran 90 {\tt INTEGER} handle {\tt comm}.  The
! message is tagged by the input {\tt INTEGER} argument {\tt TagBase}.
! The success (failure) of this operation is reported in the zero
! (nonzero) optional output argument {\tt status}.
!
! {\bf N.B.}:  One must avoid assigning elsewhere the MPI tag values
! {\tt TagBase} and {\tt TagBase+1}.  This is because {\tt send\_()}
! performs the send of the {\tt List} as a pair of operations.  The
! first send is the number of characters in {\tt inList\%bf}, and is
! given MPI tag value {\tt TagBase}.  The second send is the
! {\tt CHARACTER} data present in {\tt inList\%bf}, and is given MPI
! tag value {\tt TagBase+1}.
!
! !INTERFACE:

    subroutine send_(inList, dest, TagBase, comm, status)
!
! !USES:
!
      use m_stdio
      use m_die, only : MP_perr_die

      use m_mpif90

      use m_String, only:  String
      use m_String, only:  String_toChar => toChar
      use m_String, only:  String_len
      use m_String, only:  String_clean => clean

      implicit none

! !INPUT PARAMETERS:
!
      type(List),         intent(in)  :: inList
      integer,            intent(in)  :: dest
      integer,            intent(in)  :: TagBase
      integer,            intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      integer, optional,  intent(out) :: status

! !REVISION HISTORY:
!  6Jun01 - J.W. Larson - initial version.
! 13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize status
!           (if present).
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::send_'

 type(String) :: DummStr
 integer :: ierr, length

       ! Set status flag to zero (success) if present:

 if(present(status)) status = 0

       ! Step 1.  Extract CHARACTER buffer from inList and store it
       ! in String variable DummStr, determine its length.

 call getall_(DummStr, inList)
 length = String_len(DummStr)

       ! Step 2.  Send Length of String DummStr to process dest.

 call MPI_SEND(length, 1, MP_type(length), dest, TagBase, comm, ierr)
  if(ierr /= 0) then
     if(present(status)) then
        write(stderr,'(2a,i8)') myname_, &
	     ':: MPI_SEND(length...) failed.  ierror=', ierr
        status = ierr
        return
     else
        call MP_perr_die(myname_,':: MPI_SEND(length...) failed',ierr)
     endif
  endif

       ! Step 3.  Send CHARACTER portion of String DummStr
       ! to process dest.

 call MPI_SEND(DummStr%c(1), length, MP_CHARACTER, dest, TagBase+1, &
               comm, ierr)
  if(ierr /= 0) then
     if(present(status)) then
        write(stderr,'(2a,i8)') myname_, &
	     ':: MPI_SEND(DummStr%c...) failed.  ierror=', ierr
        status = ierr
        return
     else
        call MP_perr_die(myname_,':: MPI_SEND(DummStr%c...) failed',ierr)
     endif
  endif

 end subroutine send_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: recv_ - MPI Point-to-Point Receive for the List Type
!
! !DESCRIPTION:  This routine receives the output {\tt List} argument
! {\tt outList} from processor {\tt source} on the communicator associated
! with the fortran 90 {\tt INTEGER} handle {\tt comm}.  The message is
! tagged by the input {\tt INTEGER} argument {\tt TagBase}.  The success
! (failure) of this operation is reported in the zero (nonzero) optional
! output argument {\tt status}.
!
! {\bf N.B.}:  One must avoid assigning elsewhere the MPI tag values
! {\tt TagBase} and {\tt TagBase+1}.  This is because {\tt recv\_()}
! performs the receive of the {\tt List} as a pair of operations.  The
! first receive is the number of characters in {\tt outList\%bf}, and
! is given MPI tag value {\tt TagBase}.  The second receive is the
! {\tt CHARACTER} data present in {\tt outList\%bf}, and is given MPI
! tag value {\tt TagBase+1}.
!
! !INTERFACE:

    subroutine recv_(outList, source, TagBase, comm, status)
!
! !USES:
!
      use m_stdio, only : stderr
      use m_die,   only : MP_perr_die

      use m_mpif90

      use m_String, only : String

      implicit none

! !INPUT PARAMETERS:
!
      integer,            intent(in)  :: source
      integer,            intent(in)  :: TagBase
      integer,            intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      type(List),         intent(out) :: outList
      integer, optional,  intent(out) :: status

! !REVISION HISTORY:
!  6Jun01 - J.W. Larson - initial version.
! 11Jun01 - R. Jacob - small bug fix; status in MPI_RECV
! 13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Initialize status
!           (if present).
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::recv_'

 integer :: ierr, length
 integer :: MPstatus(MP_STATUS_SIZE)
 type(String) :: DummStr

       ! Initialize status to zero (success), if present.

  if(present(status)) status = 0

       ! Step 1.  Receive Length of String DummStr from process source.

 call MPI_RECV(length, 1, MP_type(length), source, TagBase, comm, &
               MPstatus, ierr)
  if(ierr /= 0) then
     if(present(status)) then
        write(stderr,'(2a,i8)') myname_, &
	     ':: MPI_RECV(length...) failed.  ierror=', ierr
        status = ierr
        return
     else
        call MP_perr_die(myname_,':: MPI_RECV(length...) failed',ierr)
     endif
  endif

 allocate(DummStr%c(length), stat=ierr)

       ! Step 2.  Send CHARACTER portion of String DummStr
       ! to process dest.

 call MPI_RECV(DummStr%c(1), length, MP_CHARACTER, source, TagBase+1, &
               comm, MPstatus, ierr)
  if(ierr /= 0) then
     if(present(status)) then
        write(stderr,'(2a,i8)') myname_, &
	     ':: MPI_RECV(DummStr%c...) failed.  ierror=', ierr
        status = ierr
        return
     else
        call MP_perr_die(myname_,':: MPI_RECV(DummStr%c...) failed',ierr)
     endif
  endif

       ! Step 3.  Initialize outList.

 call initStr_(outList, DummStr)

 end subroutine recv_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GetSharedListIndices_ - Index Shared Items for Two Lists
!
! !DESCRIPTION:  {\tt GetSharedListIndices\_()} compares two user-
! supplied {\tt List} arguments {\tt List1} and {\tt Lis2} to determine:
! the number of shared items {\tt NumShared}, and arrays of the locations
! {\tt Indices1} and {\tt Indices2} in {\tt List1} and {\tt List2},
! respectively.
!
! {\bf N.B.:}  This routine returns two allocated arrays:  {\tt Indices1(:)}
! and {\tt Indices2(:)}.  Both of these arrays must be deallocated once they
! are no longer needed.  Failure to do this will create a memory leak.
!
! !INTERFACE:

 subroutine GetSharedListIndices_(List1, List2, NumShared, Indices1, &
                                   Indices2)

!
! !USES:
!
      use m_die,  only : MP_perr_die, die, warn

      use m_String, only : String
      use m_String, only : String_clean => clean

      implicit none

! !INPUT PARAMETERS:
!
      type(List),    intent(in)  :: List1
      type(List),    intent(in)  :: List2

! !OUTPUT PARAMETERS:
!
      integer,           intent(out) :: NumShared

      integer,dimension(:), pointer  :: Indices1
      integer,dimension(:), pointer  :: Indices2

! !REVISION HISTORY:
!  7Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GetSharedListIndices_'

! Error flag
  integer :: ierr

! number of items in List1 and List2, respectively:
  integer :: nitem1, nitem2

! MAXIMUM number of matches possible:
  integer :: NumSharedMax

! Temporary storage for a string tag retrieved from a list:
  type(String) :: tag

! Loop counters / temporary indices:
  integer :: n1, n2

       ! Determine the number of items in each list:

  nitem1 = nitem_(List1)
  nitem2 = nitem_(List2)

       ! The maximum number of list item matches possible
       ! is the minimum(nitem1,nitem2):

  NumSharedMax = min(nitem1,nitem2)

       ! Allocate sufficient space for the matches we may find:

  allocate(Indices1(NumSharedMax), Indices2(NumSharedMax), stat=ierr)
  if(ierr /= 0) call die(myname_,'allocate() Indices1 and 2',ierr)

       ! Initialize the counter for the number of matches found:

  NumShared = 0

       ! Scan through the two lists.  For the sake of speed, loop
       ! over the shorter of the two lists...

  if(nitem1 <= nitem2) then ! List1 is shorter--scan it...

     do n1=1,NumSharedMax

       ! Retrieve string tag n1 from List1:
        call get_(tag, n1, List1)

       ! Index this tag WRT List2--a nonzero value signifies a match
        n2 = indexStr_(List2, tag)

       ! Clear out tag for the next iteration...
        call String_clean(tag)

       ! If we have a hit, update NumShared, and load the indices
       ! n1 and n2 in Indices1 and Indices2, respectively...

        if((0 < n2) .and. (n2 <= nitem2)) then
           NumShared = NumShared + 1
           Indices1(NumShared) = n1
           Indices2(NumShared) = n2
        endif

     end do ! do n1=1,NumSharedMax

  else ! List1 is shorter--scan it...

     do n2=1,NumSharedMax

       ! Retrieve string tag n2 from List2:
        call get_(tag, n2, List2)

       ! Index this tag WRT List1--a nonzero value signifies a match
        n1 = indexStr_(List1, tag)

       ! Clear out tag for the next iteration...
        call String_clean(tag)

       ! If we have a hit, update NumShared, and load the indices
       ! n1 and n2 in Indices1 and Indices2, respectively...

        if((0 < n1) .and. (n1 <= nitem1)) then
           NumShared = NumShared + 1
           Indices1(NumShared) = n1
           Indices2(NumShared) = n2
        endif

     end do ! do n2=1,NumSharedMax

  endif ! if(nitem1 <= nitem2)...

 end subroutine GetSharedListIndices_

 end module m_List
!.









