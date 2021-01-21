!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: m_mall - A bookkeeper of user allocated memories
!
! !DESCRIPTION:
!
! !INTERFACE:

    module m_mall
      implicit none
      private	! except

      public :: mall_ci
      public :: mall_co
      public :: mall_mci
      public :: mall_mco
      public :: mall_flush
      public :: mall_reset

		! mall_ activity controls

      public :: mall_ison
      public :: mall_set

      interface mall_ci;    module procedure ci_; end interface
      interface mall_co;    module procedure co_; end interface

      interface mall_mci;    module procedure	&
	ciI0_,	&
	ciI1_,	&
	ciI2_,	&
	ciI3_,	&
	ciR0_,	&
	ciR1_,	&
	ciR2_,	&
	ciR3_,	&
	ciD0_,	&
	ciD1_,	&
	ciD2_,	&
	ciD3_,	&
	ciL0_,	&
	ciL1_,	&
	ciL2_,	&
	ciL3_,	&
	ciC0_,	&
	ciC1_,	&
	ciC2_,	&
	ciC3_
      end interface

      interface mall_mco;    module procedure	&
	coI0_,	&
	coI1_,	&
	coI2_,	&
	coI3_,	&
	coR0_,	&
	coR1_,	&
	coR2_,	&
	coR3_,	&
	coD0_,	&
	coD1_,	&
	coD2_,	&
	coD3_,	&
	coL0_,	&
	coL1_,	&
	coL2_,	&
	coL3_,	&
	coC0_,	&
	coC1_,	&
	coC2_,	&
	coC3_
      end interface

      interface mall_flush; module procedure flush_; end interface
      interface mall_reset; module procedure reset_; end interface

      interface mall_ison; module procedure ison_; end interface
      interface mall_set;  module procedure set_;  end interface

! !REVISION HISTORY:
! 	13Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname='MCT(MPEU)::m_mall'

#if SYSUNICOS || SYSIRIX64 || _R8_
  integer,parameter :: NBYTE_PER_WORD = 8
#else
  integer,parameter :: NBYTE_PER_WORD = 4
#endif

  integer,parameter :: NSZ= 32
  integer,parameter :: MXL=250

  integer, save :: nreset = 0		! number of reset_() calls
  logical, save :: started = .false.	! the module is in use

  integer, save :: n_ =0		! number of accouting bins.
  character(len=NSZ),dimension(MXL),save :: name_

  ! integer, dimension(1) :: mall
					! names of the accouting bins

  logical,save :: mall_on=.false.	! mall activity switch

  integer,save :: mci
  integer,dimension(MXL),save :: mci_	! maximum ci_() calls
  integer,save :: nci
  integer,dimension(MXL),save :: nci_	! net ci_() calls
  integer,save :: hwm
  integer,dimension(MXL),save :: hwm_	! high-water-mark of allocate()
  integer,save :: nwm
  integer,dimension(MXL),save :: nwm_	! net-water-mark of allocate()

contains
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ison_ -
!
! !DESCRIPTION:
!
! !INTERFACE:

    function ison_()
      implicit none
      logical :: ison_

! !REVISION HISTORY:
! 	25Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ison_'

  ison_=mall_on

end function ison_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: set_ - set the switch on
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine set_(on)
      implicit none
      logical,optional,intent(in) :: on

! !REVISION HISTORY:
! 	25Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::set_'

  mall_on=.true.
  if(present(on)) mall_on=on

end subroutine set_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciI0_ - check in as an integer scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciI0_(marg,thread)
      implicit none
      integer,intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciI0_'

  if(mall_on) call ci_(1,thread)

end subroutine ciI0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciI1_ - check in as an integer rank 1 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciI1_(marg,thread)
      implicit none
      integer,dimension(:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciI1_'

  if(mall_on) call ci_(size(marg),thread)

end subroutine ciI1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciI2_ - check in as an integer rank 2 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciI2_(marg,thread)
      implicit none
      integer,dimension(:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciI2_'

  if(mall_on) call ci_(size(marg),thread)

end subroutine ciI2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciI3_ - check in as an integer rank 3 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciI3_(marg,thread)
      implicit none
      integer,dimension(:,:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciI3_'

  if(mall_on) call ci_(size(marg),thread)

end subroutine ciI3_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciR0_ - check in as a real(SP) scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciR0_(marg,thread)
      use m_realkinds, only : SP
      implicit none
      real(SP),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciR0_'

  if(mall_on) call ci_(1,thread)

end subroutine ciR0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciR1_ - check in as a real(SP) rank 1 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciR1_(marg,thread)
      use m_realkinds, only : SP
      implicit none
      real(SP),dimension(:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciR1_'

  if(mall_on) call ci_(size(marg),thread)

end subroutine ciR1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciR2_ - check in as a real(SP) rank 2 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciR2_(marg,thread)
      use m_realkinds, only : SP
      implicit none
      real(SP),dimension(:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciR2_'

  if(mall_on) call ci_(size(marg),thread)

end subroutine ciR2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciR3_ - check in as a real(SP) rank 3 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciR3_(marg,thread)
      use m_realkinds, only : SP
      implicit none
      real(SP),dimension(:,:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciR3_'

  if(mall_on) call ci_(size(marg),thread)

end subroutine ciR3_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciD0_ - check in as a real(DP) scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciD0_(marg,thread)
      use m_realkinds, only : DP
      implicit none
      real(DP),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciD0_'

  if(mall_on) call ci_(2,thread)

end subroutine ciD0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciD1_ - check in as a real(DP) rank 1 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciD1_(marg,thread)
      use m_realkinds, only : DP
      implicit none
      real(DP),dimension(:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciD1_'

  if(mall_on) call ci_(2*size(marg),thread)

end subroutine ciD1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciD2_ - check in as a real(DP) rank 2 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciD2_(marg,thread)
      use m_realkinds, only : DP
      implicit none
      real(DP),dimension(:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciD2_'

  if(mall_on) call ci_(2*size(marg),thread)

end subroutine ciD2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciD3_ - check in as a real(DP) rank 3 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciD3_(marg,thread)
      use m_realkinds, only : DP
      implicit none
      real(DP),dimension(:,:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciD3_'

  if(mall_on) call ci_(2*size(marg),thread)

end subroutine ciD3_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciL0_ - check in as a logical scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciL0_(marg,thread)
      implicit none
      logical,intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciL0_'

  if(mall_on) call ci_(1,thread)

end subroutine ciL0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciL1_ - check in as a logical rank 1 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciL1_(marg,thread)
      implicit none
      logical,dimension(:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciL1_'

  if(mall_on) call ci_(size(marg),thread)

end subroutine ciL1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciL2_ - check in as a logical rank 2 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciL2_(marg,thread)
      implicit none
      logical,dimension(:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciL2_'

  if(mall_on) call ci_(size(marg),thread)

end subroutine ciL2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciL3_ - check in as a logical rank 3 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciL3_(marg,thread)
      implicit none
      logical,dimension(:,:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciL3_'

  if(mall_on) call ci_(size(marg),thread)

end subroutine ciL3_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciC0_ - check in as a character scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciC0_(marg,thread)
      implicit none
      character(len=*),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciC0_'
  integer :: nw

  if(.not.mall_on) return
  nw=(len(marg)+NBYTE_PER_WORD-1)/NBYTE_PER_WORD
  call ci_(nw,thread)

end subroutine ciC0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciC1_ - check in as a character rank 1 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciC1_(marg,thread)
      implicit none
      character(len=*),dimension(:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciC1_'
  integer :: nw

  if(.not.mall_on) return
  nw=(len(marg(1))+NBYTE_PER_WORD-1)/NBYTE_PER_WORD
  call ci_(size(marg)*nw,thread)

end subroutine ciC1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciC2_ - check in as a character rank 2 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciC2_(marg,thread)
      implicit none
      character(len=*),dimension(:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciC2_'
  integer :: nw

  if(.not.mall_on) return
  nw=(len(marg(1,1))+NBYTE_PER_WORD-1)/NBYTE_PER_WORD
  call ci_(size(marg)*nw,thread)

end subroutine ciC2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ciC3_ - check in as a character rank 3 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ciC3_(marg,thread)
      implicit none
      character(len=*),dimension(:,:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ciC3_'
  integer :: nw

  if(.not.mall_on) return
  nw=(len(marg(1,1,1))+NBYTE_PER_WORD-1)/NBYTE_PER_WORD
  call ci_(size(marg)*nw,thread)

end subroutine ciC3_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: ci_ - check-in allocate activity
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ci_(nword,thread)
      use m_stdio, only : stderr
      use m_die, only : die
      implicit none
      integer,intent(in) :: nword
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	13Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::ci_'
  integer :: ith

  if(.not.mall_on) return

  if(nword < 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': invalide argument, nword = ',nword
    call die(myname_)
  endif

  ith=lookup_(thread)

	! update the account

  nci_(ith)=nci_(ith)+1
  mci_(ith)=mci_(ith)+1
  nwm_(ith)=nwm_(ith)+nword
  if(hwm_(ith).lt.nwm_(ith)) hwm_(ith)=nwm_(ith)

	! update the total budget

  nci=nci+1
  mci=mci+1
  nwm=nwm+nword
  if(hwm.lt.nwm) hwm=nwm

end subroutine ci_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coI0_ - check in as an integer scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coI0_(marg,thread)
      implicit none
      integer,intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coI0_'

  if(mall_on) call co_(1,thread)

end subroutine coI0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coI1_ - check in as an integer rank 1 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coI1_(marg,thread)
      implicit none
      integer,dimension(:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coI1_'

  if(mall_on) call co_(size(marg),thread)

end subroutine coI1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coI2_ - check in as an integer rank 2 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coI2_(marg,thread)
      implicit none
      integer,dimension(:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coI2_'

  if(mall_on) call co_(size(marg),thread)

end subroutine coI2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coI3_ - check in as an integer rank 3 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coI3_(marg,thread)
      implicit none
      integer,dimension(:,:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coI3_'

  if(mall_on) call co_(size(marg),thread)

end subroutine coI3_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coR0_ - check in as a real(SP) scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coR0_(marg,thread)
      use m_realkinds, only : SP
      implicit none
      real(SP),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coR0_'

  if(mall_on) call co_(1,thread)

end subroutine coR0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coR1_ - check in as a real(SP) rank 1 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coR1_(marg,thread)
      use m_realkinds, only : SP
      implicit none
      real(SP),dimension(:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coR1_'

  if(mall_on) call co_(size(marg),thread)

end subroutine coR1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coR2_ - check in as a real(SP) rank 2 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coR2_(marg,thread)
      use m_realkinds, only : SP
      implicit none
      real(SP),dimension(:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coR2_'

  if(mall_on) call co_(size(marg),thread)

end subroutine coR2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coR3_ - check in as a real(SP) rank 3 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coR3_(marg,thread)
      use m_realkinds, only : SP
      implicit none
      real(SP),dimension(:,:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coR3_'

  if(mall_on) call co_(size(marg),thread)

end subroutine coR3_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coD0_ - check in as a real(DP) scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coD0_(marg,thread)
      use m_realkinds, only : DP
      implicit none
      real(DP),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coD0_'

  if(mall_on) call co_(2,thread)

end subroutine coD0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coD1_ - check in as a real(DP) rank 1 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coD1_(marg,thread)
      use m_realkinds, only : DP
      implicit none
      real(DP),dimension(:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coD1_'

  if(mall_on) call co_(2*size(marg),thread)

end subroutine coD1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coD2_ - check in as a real(DP) rank 2 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coD2_(marg,thread)
      use m_realkinds, only : DP
      implicit none
      real(DP),dimension(:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coD2_'

  if(mall_on) call co_(2*size(marg),thread)

end subroutine coD2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coD3_ - check in as a real(DP) rank 3 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coD3_(marg,thread)
      use m_realkinds, only : DP
      implicit none
      real(DP),dimension(:,:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coD3_'

  if(mall_on) call co_(2*size(marg),thread)

end subroutine coD3_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coL0_ - check in as a logical scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coL0_(marg,thread)
      implicit none
      logical,intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coL0_'

  if(mall_on) call co_(1,thread)

end subroutine coL0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coL1_ - check in as a logical rank 1 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coL1_(marg,thread)
      implicit none
      logical,dimension(:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coL1_'

  if(mall_on) call co_(size(marg),thread)

end subroutine coL1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coL2_ - check in as a logical rank 2 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coL2_(marg,thread)
      implicit none
      logical,dimension(:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coL2_'

  if(mall_on) call co_(size(marg),thread)

end subroutine coL2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coL3_ - check in as a logical rank 3 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coL3_(marg,thread)
      implicit none
      logical,dimension(:,:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coL3_'

  if(mall_on) call co_(size(marg),thread)

end subroutine coL3_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coC0_ - check in as a character scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coC0_(marg,thread)
      implicit none
      character(len=*),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coC0_'
  integer :: nw

  if(.not.mall_on) return
  nw=(len(marg)+NBYTE_PER_WORD-1)/NBYTE_PER_WORD
  call co_(nw,thread)

end subroutine coC0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coC1_ - check in as a character rank 1 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coC1_(marg,thread)
      implicit none
      character(len=*),dimension(:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coC1_'
  integer :: nw

  if(.not.mall_on) return
  nw=(len(marg(1))+NBYTE_PER_WORD-1)/NBYTE_PER_WORD
  call co_(size(marg)*nw,thread)

end subroutine coC1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coC2_ - check in as a character rank 2 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coC2_(marg,thread)
      implicit none
      character(len=*),dimension(:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coC2_'
  integer :: nw

  if(.not.mall_on) return
  nw=(len(marg(1,1))+NBYTE_PER_WORD-1)/NBYTE_PER_WORD
  call co_(size(marg)*nw,thread)

end subroutine coC2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: coC3_ - check in as a character rank 3 array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine coC3_(marg,thread)
      implicit none
      character(len=*),dimension(:,:,:),intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	21Oct99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::coC3_'
  integer :: nw

  if(.not.mall_on) return
  nw=(len(marg(1,1,1))+NBYTE_PER_WORD-1)/NBYTE_PER_WORD
  call co_(size(marg)*nw,thread)

end subroutine coC3_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: co_ - check-out allocate activity
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine co_(nword,thread)
      use m_stdio, only : stderr
      use m_die, only : die
      implicit none
      integer,intent(in) :: nword
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	13Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::co_'
  integer :: ith

  if(.not.mall_on) return

  if(nword < 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': invalide argument, nword = ',nword
    call die(myname_)
  endif

	! if the thread is "unknown", it would be treated as a
	! new thread with net negative memory activity.

  ith=lookup_(thread)

	! update the account

  nci_(ith)=nci_(ith)-1
  nwm_(ith)=nwm_(ith)-nword

	! update the total budget

  nci=nci-1
  nwm=nwm-nword

end subroutine co_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: cix_ - handling macro ALLOC_() error
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine cix_(thread,stat,fnam,line)
      use m_stdio, only : stderr
      use m_die, only : die
      implicit none
      character(len=*),intent(in) :: thread
      integer,intent(in) :: stat
      character(len=*),intent(in) :: fnam
      integer,intent(in) :: line


! !REVISION HISTORY:
! 	13Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::cix_'

  write(stderr,'(2a,i4)') trim(thread),	&
	': ALLOC_() error, stat =',stat
  call die('ALLOC_',fnam,line)

end subroutine cix_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: cox_ - handling macro DEALLOC_() error
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine cox_(thread,stat,fnam,line)
      use m_stdio, only : stderr
      use m_die, only : die
      implicit none
      character(len=*),intent(in) :: thread
      integer,intent(in) :: stat
      character(len=*),intent(in) :: fnam
      integer,intent(in) :: line

! !REVISION HISTORY:
! 	13Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::cox_'

  write(stderr,'(2a,i4)') trim(thread),	&
	': DEALLOC_() error, stat =',stat
  call die('DEALLOC_',fnam,line)

end subroutine cox_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: flush_ - balancing the up-to-date ci/co calls
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine flush_(lu)
      use m_stdio, only : stderr
      use m_ioutil, only : luflush
      use m_die, only : die
      implicit none
      integer,intent(in) :: lu

! !REVISION HISTORY:
! 	17Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::flush_'

  integer,parameter :: lnmax=38
  character(len=max(lnmax,NSZ)) :: name

  character(len=6) :: hwm_wd,nwm_wd
  character(len=1) :: flag_ci,flag_wm
  integer :: i,ier,ln

  if(.not.mall_on) return

  if(.not.started) call reset_()

  write(lu,'(72a/)',iostat=ier) ('_',i=1,72)
  if(ier /= 0) then
    write(stderr,'(2a,i3)') myname_,': can not write(), unit =',lu
    call die(myname_)
  endif

  write(lu,'(a,t39,4(2x,a))',iostat=ier) '[MALL]',	&
  		'max-ci','net-ci ','max-wm','net-wm'
  if(ier /= 0) then
    write(stderr,'(2a,i4)') myname_,': can not write(), unit =',lu
    call die(myname_)
  endif

  call luflush(lu)

!23.|....1....|....2....|....3....|....4....|....5....|....6....|....7..
!_______________________________________________________________________
!
![MALL]                                 max_ci  net-ci   max-wm  net-wm
!-----------------------------------------------------------------------
!total.                                 ...333  ...333*  ..333M  ..333i*
!_______________________________________________________________________

  write(lu,'(72a)') ('-',i=1,72)

  do i=1,min(n_,MXL)
    call wcount_(hwm_(i),hwm_wd)
    call wcount_(nwm_(i),nwm_wd)

    flag_ci=' '
    if(nci_(i) /= 0) flag_ci='*'

    flag_wm=' '
    if(nwm_(i) /= 0) flag_wm='*'

    name=name_(i)
    ln=max(len_trim(name),lnmax)
    write(lu,'(a,2(2x,i6),a,2(2x,a6),a)') name(1:ln),	&
	mci_(i),nci_(i),flag_ci,hwm_wd,nwm_wd,flag_wm
  end do

  call wcount_(hwm,hwm_wd)
  call wcount_(nwm,nwm_wd)

  flag_ci=' '
  if(nci /= 0) flag_ci='*'
  flag_wm=' '
  if(nwm /= 0) flag_wm='*'

  name='.total.'
  ln=max(len_trim(name),lnmax)
  write(lu,'(a,2(2x,i6),a,2(2x,a6),a)') name(1:ln),	&
	mci,nci,flag_ci,hwm_wd,nwm_wd,flag_wm

  write(lu,'(72a/)') ('_',i=1,72)

  if(nreset /= 1) write(lu,'(2a,i3,a)') myname_,	&
	': reset_ ',nreset,' times'

  call luflush(lu)
end subroutine flush_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: wcount_ - generate word count output with unit
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine wcount_(wknt,cknt)
      implicit none

      integer,         intent(in)  :: wknt ! given an integer value
      character(len=6),intent(out) :: cknt ! return a string value

! !REVISION HISTORY:
! 	17Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::wcount_'

character(len=1) :: cwd
integer,parameter :: KWD=1024
integer,parameter :: MWD=1024*1024
integer,parameter :: GWD=1024*1024*1024

integer :: iwd

if(wknt < 0) then
  cknt='------'
else
  cwd='i'
  iwd=wknt
  if(iwd > 9999) then
    cwd='K'
    iwd=(wknt+KWD-1)/KWD
  endif
  if(iwd > 9999) then
    cwd='M'
    iwd=(wknt+MWD-1)/MWD
  endif
  if(iwd > 9999) then
    cwd='G'
    iwd=(wknt+GWD-1)/GWD
  endif
  write(cknt,'(i5,a)') iwd,cwd
endif
end subroutine wcount_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: lookup_ - search/insert a name in a list
!
! !DESCRIPTION:
!
! !INTERFACE:

    function lookup_(thread)
      use m_chars, only : uppercase
      implicit none
      character(len=*),intent(in) :: thread
      integer :: lookup_

! !REVISION HISTORY:
! 	17Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::lookup_'

  logical :: found
  integer :: ith

  if(.not.started) call reset_()

!----------------------------------------
ith=0
found=.false.
do while(.not.found .and. ith < min(n_,MXL))
  ith=ith+1
  found= uppercase(thread) == uppercase(name_(ith))
end do

if(.not.found) then
  if(n_==0) then
    nci=0
    mci=0
    nwm=0
    hwm=0
  endif

  n_=n_+1
  if(n_ == MXL) then
    ith=MXL
    name_(ith)='.overflow.'
  else
    ith=n_
    name_(ith)=thread
  endif

  nci_(ith)=0
  mci_(ith)=0
  nwm_(ith)=0
  hwm_(ith)=0
endif

lookup_=ith

end function lookup_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: reset_ - initialize the module data structure
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine reset_()
      implicit none

! !REVISION HISTORY:
! 	16Mar98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::reset_'

  if(.not.mall_on) return

  nreset=nreset+1
  started=.true.

  name_(1:n_)=' '

  mci_(1:n_)=0
  nci_(1:n_)=0
  hwm_(1:n_)=0
  nwm_(1:n_)=0

  n_ =0

  mci=0
  nci=0
  hwm=0
  nwm=0

end subroutine reset_
!=======================================================================
end module m_mall
