!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: m_chars - a module for character class object operations
!
! !DESCRIPTION:
!
! !INTERFACE:

	module m_chars
	implicit none
	private

	public	:: operator (.upper.)	! convert a string to uppercase
	public	:: uppercase

	public	:: operator (.lower.)	! convert a string to lowercase
	public	:: lowercase

	interface operator (.upper.)
	  module procedure upper_case
	end interface
	interface uppercase
	  module procedure upper_case
	end interface

	interface operator (.lower.)
	  module procedure lower_case
	end interface
	interface lowercase
	  module procedure lower_case
	end interface

! !REVISION HISTORY:
! 	16Jul96 - J. Guo	- (to do)
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname='MCT(MPEU)::m_chars'

contains
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: upper_case - convert lowercase letters to uppercase.
!
! !DESCRIPTION:
!
! !INTERFACE:

  function upper_case(str) result(ustr)
    implicit none
  character(len=*), intent(in) :: str
  character(len=len(str))      :: ustr

! !REVISION HISTORY:
! 	13Aug96 - J. Guo	- (to do)
!EOP
!_______________________________________________________________________
    integer i
    integer,parameter :: il2u=ichar('A')-ichar('a')

    ustr=str
    do i=1,len_trim(str)
      if(str(i:i).ge.'a'.and.str(i:i).le.'z')	&
      	ustr(i:i)=char(ichar(str(i:i))+il2u)
    end do
  end function upper_case

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: lower_case - convert uppercase letters to lowercase.
!
! !DESCRIPTION:
!
! !INTERFACE:

  function lower_case(str) result(lstr)
    implicit none
    character(len=*), intent(in) :: str
    character(len=len(str))      :: lstr

! !REVISION HISTORY:
! 	13Aug96 - J. Guo	- (to do)
!EOP
!_______________________________________________________________________
    integer i
    integer,parameter :: iu2l=ichar('a')-ichar('A')

    lstr=str
    do i=1,len_trim(str)
      if(str(i:i).ge.'A'.and.str(i:i).le.'Z')	&
      	lstr(i:i)=char(ichar(str(i:i))+iu2l)
    end do
  end function lower_case

end module m_chars
!.
