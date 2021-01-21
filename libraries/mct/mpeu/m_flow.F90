!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: m_flow - tracing the program calling tree
!
! !DESCRIPTION:
!
! !INTERFACE:

    module m_flow
      implicit none
      private	! except

      public :: flow_ci
      public :: flow_co
      public :: flow_flush
      public :: flow_reset

      interface flow_ci;    module procedure ci_;    end interface
      interface flow_co;    module procedure co_;    end interface
      interface flow_flush; module procedure flush_; end interface
      interface flow_reset; module procedure reset_; end interface

! !REVISION HISTORY:
! 	26Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname='MCT(MPEU)::m_flow'

  integer,parameter :: MX_TNAME= 64
  integer,parameter :: LN_TNAME= 32

  integer,save :: mxdep= 0
  integer,save :: iname=-1
  character(len=LN_TNAME),save,dimension(0:MX_TNAME-1) :: tname

  character(len=LN_TNAME),save :: ciname=' '
  character(len=LN_TNAME),save :: coname=' '
  logical,save :: balanced=.true.

contains
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: ci_ - checking in a level
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ci_(name)
      implicit none
      character(len=*),intent(in) :: name

! !REVISION HISTORY:
! 	26Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::ci_'

	! Push in an entry in to a circulated list storage to save
	! only the last MX_TNAME entries.

  iname=iname+1
  tname(modulo(iname,MX_TNAME)) = name

  if(mxdep < iname+1) mxdep=iname+1
end subroutine ci_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: co_ - checking out a level
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine co_(name)
      use m_chars, only : uppercase
      implicit none
      character(len=*),intent(in) :: name

! !REVISION HISTORY:
! 	26Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::co_'
  character(len=LN_TNAME) :: uname

  if(balanced) then
    uname='?'
    balanced=iname >= 0
    if(balanced) then
      uname=tname(modulo(iname,MX_TNAME))
      balanced = uname == ' ' .or. uppercase(uname) == uppercase(name)
    endif
    if(.not.balanced) then
      ciname=uname
      coname= name
    endif
  endif

	! Pop out an entry

  tname(modulo(iname,MX_TNAME))=' '
  iname=iname-1

end subroutine co_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: flush_ - print all remaining entries in the list
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine flush_(lu)
      implicit none
      integer,intent(in) :: lu

! !REVISION HISTORY:
! 	26Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::flush_'
  integer :: i

	! Nothing to show

  if(mxdep == 0 .and. iname == -1) return

  write(lu,'(2a,i4)',advance='no') myname,': depth =',mxdep

  if(.not.balanced .or. iname < -1) then

    write(lu,'(4a)',advance='no') &
	', ci/co unbalanced at ',trim(ciname),'/',trim(coname)

    write(lu,'(a,i4)') ', level =',iname+1
    return

  endif

  if(iname >= 0) then
    write(lu,'(a)',advance='no') ', '
    do i=0,iname-1
      write(lu,'(2a)',advance='no') trim(tname(modulo(i,MX_TNAME))),'>'
    end do
    write(lu,'(a)',advance='no') trim(tname(modulo(iname,MX_TNAME)))
  endif
  write(lu,*)

end subroutine flush_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: reset_ - set the stack to empty
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine reset_()
      implicit none

! !REVISION HISTORY:
! 	26Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::reset_'
  integer :: i

  mxdep=0
  iname=-1
  tname(0:MX_TNAME-1)=' '

  ciname=' '
  coname=' '
  balanced=.true.

end subroutine reset_
end module m_flow
