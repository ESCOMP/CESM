!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_Permuter - permute/unpermute
!
! !DESCRIPTION:
!
! !INTERFACE:

    module m_Permuter
      implicit none
      private	! except

      public :: permute
      public :: unpermute

    interface permute; module procedure	&
	permutei_,	&	! integer in place
	permuteio_,	&	! integer with an output
	permutei1_,	&	! integer in place
	permuteio1_,	&	! integer with an output
	permuter_,	&	! real in place
	permutero_,	&	! real with an output
	permuter1_,	&	! real in place
	permutero1_,	&	! real with an output
	permuted_,	&	! dble in place
	permutedo_,	&	! dble with an output
	permuted1_,	&	! dble in place
	permutedo1_,	&	! dble with an output
	permutel_,	&	! logical in place
	permutelo_,	&	! logical with an output
	permutel1_,	&	! logical in place
	permutelo1_		! logical with an output
    end interface

    interface unpermute; module procedure	&
	unpermutei_,	&	! integer in place
	unpermuteio_,	&	! integer with an output
	unpermutei1_,	&	! integer in place
	unpermuteio1_,	&	! integer with an output
	unpermuter_,	&	! real in place
	unpermutero_,	&	! real with an output
	unpermuter1_,	&	! real in place
	unpermutero1_,	&	! real with an output
	unpermuted_,	&	! dble in place
	unpermutedo_,	&	! dble with an output
	unpermuted1_,	&	! dble in place
	unpermutedo1_,	&	! dble with an output
	unpermutel_,	&	! logical in place
	unpermutelo_,	&	! logical with an output
	unpermutel1_,	&	! logical in place
	unpermutelo1_		! logical with an output
    end interface

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT(MPEU)::m_Permuter'

contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permutei_ - permute an integer array according to indx[]
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permutei_(ary,indx,n)
      use m_die
      implicit none
      integer,dimension(:),intent(inout) :: ary
      integer,dimension(:),intent(in)    :: indx
      integer,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permutei_'

  integer,allocatable,dimension(:) :: wk
  integer :: i,ier

  allocate(wk(n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call permuteio_(wk,ary,indx,n)

  do i=1,n
    ary(i)=wk(i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine permutei_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permuteio_ - permute an integer array according to indx[]
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permuteio_(aout,ary,indx,n)
      implicit none
      integer,dimension(:),intent(inout) :: aout
      integer,dimension(:),intent(in ) :: ary
      integer,dimension(:),intent(in)  :: indx
      integer,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permuteio_'

  integer :: i,l

  do i=1,n
    l=indx(i)
    aout(i)=ary(l)
  end do

end subroutine permuteio_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermutei_ - unpermute a _permuted_ integer array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermutei_(ary,indx,n)
      use m_die
      implicit none
      integer,dimension(:),intent(inout) :: ary
      integer,dimension(:),intent(in)    :: indx
      integer,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermutei_'

  integer,allocatable,dimension(:) :: wk
  integer :: i,ier

  allocate(wk(n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call unpermuteio_(wk,ary,indx,n)

  do i=1,n
    ary(i)=wk(i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine unpermutei_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermuteio_ - unpermute a _permuted_ integer array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermuteio_(aout,ary,indx,n)
      implicit none
      integer,dimension(:),intent(inout) :: aout
      integer,dimension(:),intent(in)  :: ary
      integer,dimension(:),intent(in)  :: indx
      integer,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermuteio_'

  integer :: i,l

  do i=1,n
    l=indx(i)
    aout(l)=ary(i)
  end do

end subroutine unpermuteio_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permuter_ - permute a real array according to indx[]
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permuter_(ary,indx,n)
      use m_die
      use m_realkinds,only : SP
      implicit none
      real(SP),dimension(:),intent(inout) :: ary
      integer ,dimension(:),intent(in)    :: indx
      integer ,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permuter_'

  real(kind(ary)),allocatable,dimension(:) :: wk
  integer :: i,ier

  allocate(wk(n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call permutero_(wk,ary,indx,n)

  do i=1,n
    ary(i)=wk(i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine permuter_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permutero_ - permute a real array according to indx[]
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permutero_(aout,ary,indx,n)
      use m_realkinds,only : SP
      implicit none
      real(SP),dimension(:),intent(inout) :: aout
      real(SP),dimension(:),intent(in)  :: ary
      integer ,dimension(:),intent(in)  :: indx
      integer ,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permutero_'

  integer :: i,l

  do i=1,n
    l=indx(i)
    aout(i)=ary(l)
  end do

end subroutine permutero_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermuter_ - unpermute a _permuted_ real array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermuter_(ary,indx,n)
      use m_die
      use m_realkinds,only : SP
      implicit none
      real(SP),dimension(:),intent(inout) :: ary
      integer ,dimension(:),intent(in)    :: indx
      integer ,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermuter_'

  real(kind(ary)),allocatable,dimension(:) :: wk
  integer :: i,ier

  allocate(wk(n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call unpermutero_(wk,ary,indx,n)

  do i=1,n
    ary(i)=wk(i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine unpermuter_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermutero_ - unpermute a _permuted_ real array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermutero_(aout,ary,indx,n)
      use m_realkinds,only : SP
      implicit none
      real(SP),dimension(:),intent(inout) :: aout
      real(SP),dimension(:),intent(in)  :: ary
      integer ,dimension(:),intent(in)  :: indx
      integer ,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermutero_'

  integer :: i,l

  do i=1,n
    l=indx(i)
    aout(l)=ary(i)
  end do

end subroutine unpermutero_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permuted_ - permute a double precision array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permuted_(ary,indx,n)
      use m_die
      use m_realkinds,only : DP
      implicit none
      real(DP),dimension(:),intent(inout) :: ary
      integer ,dimension(:),intent(in)    :: indx
      integer ,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permuted_'

  real(kind(ary)),allocatable,dimension(:) :: wk
  integer :: i,ier

  allocate(wk(n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call permutedo_(wk,ary,indx,n)

  do i=1,n
    ary(i)=wk(i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine permuted_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permutedo_ - permute a double precision array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permutedo_(aout,ary,indx,n)
      use m_realkinds,only : DP
      implicit none
      real(DP),dimension(:),intent(inout) :: aout
      real(DP),dimension(:),intent(in)  :: ary
      integer ,dimension(:),intent(in)  :: indx
      integer ,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permutedo_'

  integer :: i,l

  do i=1,n
    l=indx(i)
    aout(i)=ary(l)
  end do

end subroutine permutedo_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermuted_ - unpermute a double precision array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermuted_(ary,indx,n)
      use m_die
      use m_realkinds,only : DP
      implicit none
      real(DP),dimension(:),intent(inout) :: ary
      integer ,dimension(:),intent(in)    :: indx
      integer ,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermuted_'

  real(kind(ary)),allocatable,dimension(:) :: wk
  integer :: i,ier

  allocate(wk(n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call unpermutedo_(wk,ary,indx,n)

  do i=1,n
    ary(i)=wk(i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine unpermuted_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermutedo_ - unpermute a double precision array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermutedo_(aout,ary,indx,n)
      use m_realkinds,only : DP
      implicit none
      real(DP),dimension(:),intent(inout) :: aout
      real(DP),dimension(:),intent(in)  :: ary
      integer ,dimension(:),intent(in)  :: indx
      integer ,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermutedo_'

  integer :: i,l

  do i=1,n
    l=indx(i)
    aout(l)=ary(i)
  end do

end subroutine unpermutedo_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permutel_ - permute a real array according to indx[]
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permutel_(ary,indx,n)
      use m_die
      implicit none
      logical,dimension(:),intent(inout) :: ary
      integer,dimension(:),intent(in)    :: indx
      integer,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permutel_'

  logical,allocatable,dimension(:) :: wk
  integer :: i,ier

  allocate(wk(n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call permutelo_(wk,ary,indx,n)

  do i=1,n
    ary(i)=wk(i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine permutel_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permutelo_ - permute a real array according to indx[]
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permutelo_(aout,ary,indx,n)
      implicit none
      logical,dimension(:),intent(inout) :: aout
      logical,dimension(:),intent(in)  :: ary
      integer,dimension(:),intent(in)  :: indx
      integer,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permutelo_'

  integer :: i,l

  do i=1,n
    l=indx(i)
    aout(i)=ary(l)
  end do

end subroutine permutelo_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermutel_ - unpermute a _permuted_ logical array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermutel_(ary,indx,n)
      use m_die
      implicit none
      logical,dimension(:),intent(inout) :: ary
      integer,dimension(:),intent(in)    :: indx
      integer,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermutel_'

  logical,allocatable,dimension(:) :: wk
  integer :: i,ier

  allocate(wk(n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call unpermutelo_(wk,ary,indx,n)

  do i=1,n
    ary(i)=wk(i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine unpermutel_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermutelo_ - unpermute a _permuted_ logical array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermutelo_(aout,ary,indx,n)
      implicit none
      logical,dimension(:),intent(inout) :: aout
      logical,dimension(:),intent(in)  :: ary
      integer,dimension(:),intent(in)  :: indx
      integer,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermutelo_'

  integer :: i,l

  do i=1,n
    l=indx(i)
    aout(l)=ary(i)
  end do

end subroutine unpermutelo_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permutei1_ - permute an integer array according to indx[]
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permutei1_(ary,indx,n)
      use m_die
      implicit none
      integer,dimension(:,:),intent(inout) :: ary
      integer,dimension(:),intent(in)    :: indx
      integer,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permutei1_'

  integer,allocatable,dimension(:,:) :: wk
  integer :: i,l,ier

  l=size(ary,1)
  allocate(wk(l,n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call permuteio1_(wk,ary,indx,n)

  do i=1,n
    ary(:,i)=wk(:,i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine permutei1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permuteio1_ - permute an integer array according to indx[]
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permuteio1_(aout,ary,indx,n)
      implicit none
      integer,dimension(:,:),intent(inout) :: aout
      integer,dimension(:,:),intent(in ) :: ary
      integer,dimension(:),intent(in)  :: indx
      integer,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permuteio1_'

  integer :: i,l,m

  m=min(size(aout,1),size(ary,1))
  do i=1,n
    l=indx(i)
    aout(1:m,i)=ary(1:m,l)
  end do

end subroutine permuteio1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermutei1_ - unpermute a _permuted_ integer array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermutei1_(ary,indx,n)
      use m_die
      implicit none
      integer,dimension(:,:),intent(inout) :: ary
      integer,dimension(:),intent(in)    :: indx
      integer,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermutei1_'

  integer,allocatable,dimension(:,:) :: wk
  integer :: i,l,ier

  l=size(ary,1)
  allocate(wk(l,n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call unpermuteio1_(wk,ary,indx,n)

  do i=1,n
    ary(:,i)=wk(:,i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine unpermutei1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermuteio1_ - unpermute a _permuted_ integer array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermuteio1_(aout,ary,indx,n)
      implicit none
      integer,dimension(:,:),intent(inout) :: aout
      integer,dimension(:,:),intent(in)  :: ary
      integer,dimension(:),intent(in)  :: indx
      integer,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermuteio1_'

  integer :: i,l,m

  m=min(size(aout,1),size(ary,1))
  do i=1,n
    l=indx(i)
    aout(1:m,l)=ary(1:m,i)
  end do

end subroutine unpermuteio1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permuter1_ - permute a real array according to indx[]
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permuter1_(ary,indx,n)
      use m_die
      use m_realkinds,only : SP
      implicit none
      real(SP),dimension(:,:),intent(inout) :: ary
      integer ,dimension(:),intent(in)    :: indx
      integer ,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permuter1_'

  real(kind(ary)),allocatable,dimension(:,:) :: wk
  integer :: i,l,ier

  l=size(ary,1)
  allocate(wk(l,n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call permutero1_(wk,ary,indx,n)

  do i=1,n
    ary(:,i)=wk(:,i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine permuter1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permutero1_ - permute a real array according to indx[]
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permutero1_(aout,ary,indx,n)
      use m_realkinds,only : SP
      implicit none
      real(SP),dimension(:,:),intent(inout) :: aout
      real(SP),dimension(:,:),intent(in)  :: ary
      integer ,dimension(:),intent(in)  :: indx
      integer ,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permutero1_'

  integer :: i,l,m

  m=min(size(aout,1),size(ary,1))
  do i=1,n
    l=indx(i)
    aout(1:m,i)=ary(1:m,l)
  end do

end subroutine permutero1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermuter1_ - unpermute a _permuted_ real array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermuter1_(ary,indx,n)
      use m_die
      use m_realkinds,only : SP
      implicit none
      real(SP),dimension(:,:),intent(inout) :: ary
      integer ,dimension(:),intent(in)    :: indx
      integer ,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermuter1_'

  real(kind(ary)),allocatable,dimension(:,:) :: wk
  integer :: i,l,ier

  l=size(ary,1)
  allocate(wk(l,n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call unpermutero1_(wk,ary,indx,n)

  do i=1,n
    ary(:,i)=wk(:,i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine unpermuter1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermutero1_ - unpermute a _permuted_ real array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermutero1_(aout,ary,indx,n)
      use m_realkinds,only : SP
      implicit none
      real(SP),dimension(:,:),intent(inout) :: aout
      real(SP),dimension(:,:),intent(in)  :: ary
      integer ,dimension(:),intent(in)  :: indx
      integer ,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermutero1_'

  integer :: i,l,m

  m=min(size(aout,1),size(ary,1))
  do i=1,n
    l=indx(i)
    aout(1:m,l)=ary(1:m,i)
  end do

end subroutine unpermutero1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permuted1_ - permute a double precision array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permuted1_(ary,indx,n)
      use m_die
      use m_realkinds,only : DP
      implicit none
      real(DP),dimension(:,:),intent(inout) :: ary
      integer ,dimension(:),intent(in)    :: indx
      integer ,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permuted1_'

  real(kind(ary)),allocatable,dimension(:,:) :: wk
  integer :: i,l,ier

  l=size(ary,1)
  allocate(wk(l,n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call permutedo1_(wk,ary,indx,n)

  do i=1,n
    ary(:,i)=wk(:,i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine permuted1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permutedo1_ - permute a double precision array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permutedo1_(aout,ary,indx,n)
      use m_realkinds,only : DP
      implicit none
      real(DP),dimension(:,:),intent(inout) :: aout
      real(DP),dimension(:,:),intent(in)  :: ary
      integer ,dimension(:),intent(in)  :: indx
      integer ,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permutedo1_'

  integer :: i,l,m

  m=min(size(aout,1),size(ary,1))
  do i=1,n
    l=indx(i)
    aout(1:m,i)=ary(1:m,l)
  end do

end subroutine permutedo1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermuted1_ - unpermute a double precision array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermuted1_(ary,indx,n)
      use m_die
      use m_realkinds,only : DP
      implicit none
      real(DP),dimension(:,:),intent(inout) :: ary
      integer ,dimension(:),intent(in)    :: indx
      integer ,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermuted1_'

  real(kind(ary)),allocatable,dimension(:,:) :: wk
  integer :: i,l,ier

  l=size(ary,1)
  allocate(wk(l,n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call unpermutedo1_(wk,ary,indx,n)

  do i=1,n
    ary(:,i)=wk(:,i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine unpermuted1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermutedo1_ - unpermute a double precision array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermutedo1_(aout,ary,indx,n)
      use m_realkinds,only : DP
      implicit none
      real(DP),dimension(:,:),intent(inout) :: aout
      real(DP),dimension(:,:),intent(in)  :: ary
      integer ,dimension(:),intent(in)  :: indx
      integer ,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermutedo1_'

  integer :: i,l,m

  m=min(size(aout,1),size(ary,1))
  do i=1,n
    l=indx(i)
    aout(1:m,l)=ary(1:m,i)
  end do

end subroutine unpermutedo1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permutel1_ - permute a real array according to indx[]
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permutel1_(ary,indx,n)
      use m_die
      implicit none
      logical,dimension(:,:),intent(inout) :: ary
      integer,dimension(:),intent(in)    :: indx
      integer,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permutel1_'

  logical,allocatable,dimension(:,:) :: wk
  integer :: i,l,ier

  l=size(ary,1)
  allocate(wk(l,n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call permutelo1_(wk,ary,indx,n)

  do i=1,n
    ary(:,i)=wk(:,i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine permutel1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: permutelo1_ - permute a real array according to indx[]
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine permutelo1_(aout,ary,indx,n)
      implicit none
      logical,dimension(:,:),intent(inout) :: aout
      logical,dimension(:,:),intent(in)  :: ary
      integer,dimension(:),intent(in)  :: indx
      integer,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::permutelo1_'

  integer :: i,l,m

  m=min(size(aout,1),size(ary,1))
  do i=1,n
    l=indx(i)
    aout(1:m,i)=ary(1:m,l)
  end do

end subroutine permutelo1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermutel1_ - unpermute a _permuted_ logical array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermutel1_(ary,indx,n)
      use m_die
      implicit none
      logical,dimension(:,:),intent(inout) :: ary
      integer,dimension(:),intent(in)    :: indx
      integer,             intent(in)    :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermutel1_'

  logical,allocatable,dimension(:,:) :: wk
  integer :: i,l,ier

  l=size(ary,1)
  allocate(wk(l,n),stat=ier)
	if(ier/=0) call perr_die(myname_,'allocate()',ier)

  call unpermutelo1_(wk,ary,indx,n)

  do i=1,n
    ary(:,i)=wk(:,i)
  end do

  deallocate(wk,stat=ier)
	if(ier/=0) call perr_die(myname_,'deallocate()',ier)

end subroutine unpermutel1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: unpermutelo1_ - unpermute a _permuted_ logical array
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine unpermutelo1_(aout,ary,indx,n)
      implicit none
      logical,dimension(:,:),intent(inout) :: aout
      logical,dimension(:,:),intent(in)  :: ary
      integer,dimension(:),intent(in)  :: indx
      integer,             intent(in)  :: n

! !REVISION HISTORY:
! 	25Aug99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::unpermutelo1_'

  integer :: i,l,m

  m=min(size(aout,1),size(ary,1))
  do i=1,n
    l=indx(i)
    aout(1:m,l)=ary(1:m,i)
  end do

end subroutine unpermutelo1_

end module m_Permuter
