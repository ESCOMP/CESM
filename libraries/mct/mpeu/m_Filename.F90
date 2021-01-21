!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_Filename - Filename manipulation routines
!
! !DESCRIPTION:
!
! !INTERFACE:

    module m_Filename
      implicit none
      private	! except

      public :: Filename_base		! basename()
      public :: Filename_dir		! dirname()

      interface Filename_base; module procedure base_; end interface
      interface Filename_dir;  module procedure dir_;  end interface

! !REVISION HISTORY:
! 	14Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT(MPEU)::m_Filename'

contains
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: base_ - basename
!
! !DESCRIPTION:
!
! !INTERFACE:

    function base_(cstr,sfx)
      implicit none
      character(len=*)         ,intent(in) :: cstr
      character(len=*),optional,intent(in) :: sfx
      character(len=len(cstr)) :: base_

! !REVISION HISTORY:
! 	14Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::base_'
  integer :: l,lb,le

  l =index(cstr,'/',back=.true.)
  lb=l+1		! correct either a '/' is in the string or not.
  le=len_trim(cstr)

  if(present(sfx)) then

    l=le-len_trim(sfx)
    if(sfx==cstr(l+1:le)) le=l

  endif

  base_=cstr(lb:le)

end function base_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: dir_ - dirname
!
! !DESCRIPTION:
!
! !INTERFACE:

    function dir_(cstr)
      implicit none
      character(len=*),intent(in) :: cstr
      character(len=len(cstr)) :: dir_

! !REVISION HISTORY:
! 	14Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::dir_'
  integer :: l

  l =index(cstr,'/',back=.true.)
  select case(l)
  case(0)
    dir_='.'
  case(1)
    dir_='/'
  case default
    dir_=cstr(1:l-1)
  end select

end function dir_

end module m_Filename
