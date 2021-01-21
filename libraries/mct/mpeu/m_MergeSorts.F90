!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_MergeSorts - Tools for incremental indexed-sorting
!
! !DESCRIPTION:
!
!   This tool module contains basic sorting procedures, that in
!   addition to a couple of standard Fortran 90 statements in the
!   array syntex, allow a full range sort or unsort operations.
!   The main characteristics of the sorting algorithm used in this
!   module are, a) stable, and b) index sorting.
!
! !INTERFACE:

    module m_MergeSorts
      implicit none
      private	! except

      public :: IndexSet

      public :: IndexSort

      integer,parameter :: I8 = selected_int_kind (13)

      interface IndexSet
	module procedure setn_
	module procedure set_
      end interface
      interface IndexSort
	module procedure iSortn_
	module procedure i8Sortn_
	module procedure rSortn_
	module procedure dSortn_
	module procedure cSortn_
	module procedure iSort_
	module procedure i8Sort_
	module procedure rSort_
	module procedure dSort_
	module procedure cSort_
	module procedure iSort1_
	module procedure i8Sort1_
	module procedure rSort1_
	module procedure dSort1_
	module procedure cSort1_
      end interface

! !EXAMPLES:
!
!	...
!	integer, intent(in) :: No
!	type(Observations), dimension(No), intent(inout) :: obs
!
!	integer, dimension(No) :: indx	! automatic array
!
!	call IndexSet(No,indx)
!	call IndexSort(No,indx,obs(1:No)%lev,descend=.false.)
!	call IndexSort(No,indx,obs(1:No)%lon,descend=.false.)
!	call IndexSort(No,indx,obs(1:No)%lat,descend=.false.)
!	call IndexSort(No,indx,obs(1:No)%kt,descend=.false.)
!	call IndexSort(No,indx,obs(1:No)%ks,descend=.false.)
!	call IndexSort(No,indx,obs(1:No)%kx,descend=.false.)
!	call IndexSort(No,indx,obs(1:No)%kr,descend=.false.)
!
!		! Sorting
!	obs(1:No) = obs( (/ (indx(i),i=1,No) /) )
!     	...
!		! Unsorting
!	obs( (/ (indx(i),i=1,No) /) ) = obs(1:No)
!
! !REVISION HISTORY:
! 23Mar15 - Steve Goldhaber (goldy@ucar.edu)
!   . Added interface to perform index sort on 8-byte integers
!	15Mar00	- Jing Guo
!		. Added interfaces without the explicit size
!		. Added interfaces for two dimensional arrays
!	02Feb99 - Jing Guo <guo@thunder> - Added if(present(stat)) ...
! 	04Jan99 - Jing Guo <guo@thunder> - revised
! 	09Sep97 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*), parameter :: myname='MCT(MPEU)::m_MergeSorts'

contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: setn_ - Initialize an array of data location indices
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine setn_(n,indx)
      implicit none
      integer, intent(in) :: n			! size of indx(:)
      integer, dimension(n), intent(out) :: indx	! indices

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. initial prototype/prolog/code
!		. redefined for the original interface
!EOP ___________________________________________________________________

  call set_(indx(1:n))
end subroutine setn_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: set_ - Initialize an array of data location indices
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine set_(indx)
      implicit none
      integer, dimension(:), intent(out) :: indx	! indices

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. Modified the interface, by removing the explicit size
! 	09Sep97 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 	04Jan99 - Jing Guo <guo@thunder> - revised prolog format
!EOP ___________________________________________________________________

  integer :: i

  do i=1,size(indx)
    indx(i)=i
  end do

end subroutine set_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: iSortn_ - A stable merge index sorting of INTs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine iSortn_(n,indx,keys,descend,stat)
      implicit none

      integer,intent(in) :: n
      integer, dimension(n), intent(inout) :: indx
      integer, dimension(n), intent(in) :: keys
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. initial prototype/prolog/code
!		. redefined for the original interface
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::iSortn_'

  call iSort_(indx(1:n),keys(1:n),descend,stat)
end subroutine iSortn_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: i8Sortn_ - A stable merge index sorting of 8-byte INTs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine i8Sortn_(n,indx,keys,descend,stat)
      implicit none

      integer,intent(in) :: n
      integer, dimension(n), intent(inout) :: indx
      integer(i8), dimension(n), intent(in) :: keys
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
! 23Mar15 - Steve Goldhaber (goldy@ucar.edu)
!   . Added interface to perform index sort on 8-byte integers
!	15Mar00	- Jing Guo
!		. initial prototype/prolog/code
!		. redefined for the original interface
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::i8Sortn_'

  call i8Sort_(indx(1:n),keys(1:n),descend,stat)
end subroutine i8Sortn_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: rSortn_ - A stable merge index sorting REALs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine rSortn_(n,indx,keys,descend,stat)
      use m_realkinds,only : SP
      implicit none

      integer,intent(in) :: n
      integer, dimension(n), intent(inout) :: indx
      real(SP),dimension(n), intent(in) :: keys
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. initial prototype/prolog/code
!		. redefined for the original interface
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::rSortn_'

  call rSort_(indx(1:n),keys(1:n),descend,stat)
end subroutine rSortn_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: dSortn_ - A stable merge index sorting DOUBLEs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine dSortn_(n,indx,keys,descend,stat)
      use m_realkinds,only : DP
      implicit none

      integer,intent(in) :: n
      integer, dimension(n), intent(inout) :: indx
      real(DP), dimension(n), intent(in) :: keys
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. initial prototype/prolog/code
!		. redefined for the original interface
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::dSortn_'

  call dSort_(indx(1:n),keys(1:n),descend,stat)
end subroutine dSortn_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: cSortn_ - A stable merge index sorting of CHAR(*)s.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine cSortn_(n,indx,keys,descend,stat)
      implicit none

      integer,intent(in) :: n
      integer, dimension(n), intent(inout) :: indx
      character(len=*), dimension(n), intent(in) :: keys
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. initial prototype/prolog/code
!		. redefined for the original interface
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::cSortn_'

  call cSort_(indx(1:n),keys(1:n),descend,stat)
end subroutine cSortn_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: iSort_ - A stable merge index sorting of INTs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine iSort_(indx,keys,descend,stat)
      use m_stdio, only : stderr
      use m_die,   only : die
      implicit none

      integer, dimension(:), intent(inout) :: indx
      integer, dimension(:), intent(in) :: keys
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. Modified the interface, by removing the explicit size
!	02Feb99 - Jing Guo <guo@thunder> - Added if(present(stat)) ...
! 	04Jan99 - Jing Guo <guo@thunder> - revised the prolog
! 	09Sep97 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  logical :: dsnd
  integer :: ierr
  integer, dimension(:),allocatable :: mtmp
  integer :: n

  character(len=*),parameter :: myname_=myname//'::iSort_'

  if(present(stat)) stat=0

  n=size(indx)

  allocate(mtmp(n),stat=ierr)
  if(ierr /= 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': allocate(mtmp(:)) error, stat =',ierr
    if(.not.present(stat)) call die(myname_)
    stat=ierr
    return
  endif

  dsnd=.false.
  if(present(descend)) dsnd=descend

  call MergeSort_()

  deallocate(mtmp)

contains
subroutine MergeSort_()
  implicit none
  integer :: mstep,lstep
  integer :: lb,lm,le

  mstep=1
  do while(mstep < n)
    lstep=mstep*2

    lb=1
    do while(lb < n)
      lm=lb+mstep
      le=min(lm-1+mstep,n)

      call merge_(lb,lm,le)
      indx(lb:le)=mtmp(lb:le)
      lb=le+1
    end do

    mstep=lstep
  end do
end subroutine MergeSort_

subroutine merge_(lb,lm,le)
  integer,intent(in) :: lb,lm,le
  integer :: l1,l2,l

  l1=lb
  l2=lm
  do l=lb,le
    if(l2.gt.le) then
      mtmp(l)=indx(l1)
      l1=l1+1
    elseif(l1.ge.lm) then
      mtmp(l)=indx(l2)
      l2=l2+1
    else
      if(dsnd) then
        if(keys(indx(l1)) .ge. keys(indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      else
        if(keys(indx(l1)) .le. keys(indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      endif
    endif
  end do
end subroutine merge_

end subroutine iSort_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: i8Sort_ - A stable merge index sorting of 8-byte INTs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine i8Sort_(indx,keys,descend,stat)
      use m_stdio, only : stderr
      use m_die,   only : die
      implicit none

      integer, dimension(:), intent(inout) :: indx
      integer(i8), dimension(:), intent(in) :: keys
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!   17Dec14 - goldy@ucar.edu - Added 8-byte version
!	15Mar00	- Jing Guo
!		. Modified the interface, by removing the explicit size
!	02Feb99 - Jing Guo <guo@thunder> - Added if(present(stat)) ...
! 	04Jan99 - Jing Guo <guo@thunder> - revised the prolog
! 	09Sep97 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  logical :: dsnd
  integer :: ierr
  integer, dimension(:),allocatable :: mtmp
  integer :: n

  character(len=*),parameter :: myname_=myname//'::i8Sort_'

  if(present(stat)) stat=0

  n=size(indx)

  allocate(mtmp(n),stat=ierr)
  if(ierr /= 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': allocate(mtmp(:)) error, stat =',ierr
    if(.not.present(stat)) call die(myname_)
    stat=ierr
    return
  endif

  dsnd=.false.
  if(present(descend)) dsnd=descend

  call MergeSort_()

  deallocate(mtmp)

contains
subroutine MergeSort_()
  implicit none
  integer :: mstep,lstep
  integer :: lb,lm,le

  mstep=1
  do while(mstep < n)
    lstep=mstep*2

    lb=1
    do while(lb < n)
      lm=lb+mstep
      le=min(lm-1+mstep,n)

      call merge_(lb,lm,le)
      indx(lb:le)=mtmp(lb:le)
      lb=le+1
    end do

    mstep=lstep
  end do
end subroutine MergeSort_

subroutine merge_(lb,lm,le)
  integer,intent(in) :: lb,lm,le
  integer :: l1,l2,l

  l1=lb
  l2=lm
  do l=lb,le
    if(l2.gt.le) then
      mtmp(l)=indx(l1)
      l1=l1+1
    elseif(l1.ge.lm) then
      mtmp(l)=indx(l2)
      l2=l2+1
    else
      if(dsnd) then
        if(keys(indx(l1)) .ge. keys(indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      else
        if(keys(indx(l1)) .le. keys(indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      endif
    endif
  end do
end subroutine merge_

end subroutine i8Sort_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: rSort_ - A stable merge index sorting REALs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine rSort_(indx,keys,descend,stat)
      use m_stdio, only : stderr
      use m_die,   only : die
      use m_realkinds,only : SP
      implicit none

      integer, dimension(:), intent(inout) :: indx
      real(SP),dimension(:), intent(in) :: keys
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. Modified the interface, by removing the explicit size
!	02Feb99 - Jing Guo <guo@thunder> - Added if(present(stat)) ...
! 	04Jan99 - Jing Guo <guo@thunder> - revised the prolog
! 	09Sep97 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  logical :: dsnd
  integer :: ierr
  integer, dimension(:),allocatable :: mtmp
  integer :: n

  character(len=*),parameter :: myname_=myname//'::rSort_'

  if(present(stat)) stat=0

  n=size(indx)

  allocate(mtmp(n),stat=ierr)
  if(ierr /= 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': allocate(mtmp(:)) error, stat =',ierr
    if(.not.present(stat)) call die(myname_)
    stat=ierr
    return
  endif

  dsnd=.false.
  if(present(descend)) dsnd=descend

  call MergeSort_()

  deallocate(mtmp)

contains
subroutine MergeSort_()
  implicit none
  integer :: mstep,lstep
  integer :: lb,lm,le

  mstep=1
  do while(mstep < n)
    lstep=mstep*2

    lb=1
    do while(lb < n)
      lm=lb+mstep
      le=min(lm-1+mstep,n)

      call merge_(lb,lm,le)
      indx(lb:le)=mtmp(lb:le)
      lb=le+1
    end do

    mstep=lstep
  end do
end subroutine MergeSort_

subroutine merge_(lb,lm,le)
  integer,intent(in) :: lb,lm,le
  integer :: l1,l2,l

  l1=lb
  l2=lm
  do l=lb,le
    if(l2.gt.le) then
      mtmp(l)=indx(l1)
      l1=l1+1
    elseif(l1.ge.lm) then
      mtmp(l)=indx(l2)
      l2=l2+1
    else
      if(dsnd) then
        if(keys(indx(l1)) .ge. keys(indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      else
        if(keys(indx(l1)) .le. keys(indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      endif
    endif
  end do
end subroutine merge_

end subroutine rSort_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: dSort_ - A stable merge index sorting DOUBLEs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine dSort_(indx,keys,descend,stat)
      use m_stdio, only : stderr
      use m_die,   only : die
      use m_realkinds,only : DP
      implicit none

      integer, dimension(:), intent(inout) :: indx
      real(DP), dimension(:), intent(in) :: keys
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. Modified the interface, by removing the explicit size
!	02Feb99 - Jing Guo <guo@thunder> - Added if(present(stat)) ...
! 	04Jan99 - Jing Guo <guo@thunder> - revised the prolog
! 	09Sep97 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  logical :: dsnd
  integer :: ierr
  integer, dimension(:),allocatable :: mtmp
  integer :: n

  character(len=*),parameter :: myname_=myname//'::dSort_'

  if(present(stat)) stat=0

  n=size(indx)

  allocate(mtmp(n),stat=ierr)
  if(ierr /= 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': allocate(mtmp(:)) error, stat =',ierr
    if(.not.present(stat)) call die(myname_)
    stat=ierr
    return
  endif

  dsnd=.false.
  if(present(descend)) dsnd=descend

  call MergeSort_()

  deallocate(mtmp)

contains
subroutine MergeSort_()
  implicit none
  integer :: mstep,lstep
  integer :: lb,lm,le

  mstep=1
  do while(mstep < n)
    lstep=mstep*2

    lb=1
    do while(lb < n)
      lm=lb+mstep
      le=min(lm-1+mstep,n)

      call merge_(lb,lm,le)
      indx(lb:le)=mtmp(lb:le)
      lb=le+1
    end do

    mstep=lstep
  end do
end subroutine MergeSort_

subroutine merge_(lb,lm,le)
  integer,intent(in) :: lb,lm,le
  integer :: l1,l2,l

  l1=lb
  l2=lm
  do l=lb,le
    if(l2.gt.le) then
      mtmp(l)=indx(l1)
      l1=l1+1
    elseif(l1.ge.lm) then
      mtmp(l)=indx(l2)
      l2=l2+1
    else
      if(dsnd) then
        if(keys(indx(l1)) .ge. keys(indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      else
        if(keys(indx(l1)) .le. keys(indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      endif
    endif
  end do
end subroutine merge_

end subroutine dSort_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: cSort_ - A stable merge index sorting of CHAR(*)s.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine cSort_(indx,keys,descend,stat)
      use m_stdio, only : stderr
      use m_die,   only : die
      implicit none

      integer, dimension(:), intent(inout) :: indx
      character(len=*), dimension(:), intent(in) :: keys
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. Modified the interface, by removing the explicit size
!	02Feb99 - Jing Guo <guo@thunder> - Added if(present(stat)) ...
! 	04Jan99 - Jing Guo <guo@thunder> - revised the prolog
! 	09Sep97 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  logical :: dsnd
  integer :: ierr
  integer, dimension(:),allocatable :: mtmp
  integer :: n

  character(len=*),parameter :: myname_=myname//'::cSort_'

  if(present(stat)) stat=0

  n=size(indx)

  allocate(mtmp(n),stat=ierr)
  if(ierr /= 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': allocate(mtmp(:)) error, stat =',ierr
    if(.not.present(stat)) call die(myname_)
    stat=ierr
    return
  endif

  dsnd=.false.
  if(present(descend)) dsnd=descend

  call MergeSort_()

  deallocate(mtmp)

contains
subroutine MergeSort_()
  implicit none
  integer :: mstep,lstep
  integer :: lb,lm,le

  mstep=1
  do while(mstep < n)
    lstep=mstep*2

    lb=1
    do while(lb < n)
      lm=lb+mstep
      le=min(lm-1+mstep,n)

      call merge_(lb,lm,le)
      indx(lb:le)=mtmp(lb:le)
      lb=le+1
    end do

    mstep=lstep
  end do
end subroutine MergeSort_

subroutine merge_(lb,lm,le)
  integer,intent(in) :: lb,lm,le
  integer :: l1,l2,l

  l1=lb
  l2=lm
  do l=lb,le
    if(l2.gt.le) then
      mtmp(l)=indx(l1)
      l1=l1+1
    elseif(l1.ge.lm) then
      mtmp(l)=indx(l2)
      l2=l2+1
    else
      if(dsnd) then
        if(keys(indx(l1)) .ge. keys(indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      else
        if(keys(indx(l1)) .le. keys(indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      endif
    endif
  end do
end subroutine merge_

end subroutine cSort_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: iSort1_ - A stable merge index sorting of INTs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine iSort1_(indx,keys,ikey,descend,stat)
      use m_stdio, only : stderr
      use m_die,   only : die
      implicit none

      integer, dimension(:), intent(inout) :: indx
      integer, dimension(:,:), intent(in) :: keys
      integer,intent(in) :: ikey
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. initial prototype/prolog/code
!		. Copied code from iSort_
!		. Extended the interface and the algorithm to handle
!		  2-d arrays with an index.
!EOP ___________________________________________________________________

  logical :: dsnd
  integer :: ierr
  integer, dimension(:),allocatable :: mtmp
  integer :: n

  character(len=*),parameter :: myname_=myname//'::i8Sort1_'

  if(present(stat)) stat=0

  n=size(indx)

  allocate(mtmp(n),stat=ierr)
  if(ierr /= 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': allocate(mtmp(:)) error, stat =',ierr
    if(.not.present(stat)) call die(myname_)
    stat=ierr
    return
  endif

  dsnd=.false.
  if(present(descend)) dsnd=descend

  call MergeSort_()

  deallocate(mtmp)

contains
subroutine MergeSort_()
  implicit none
  integer :: mstep,lstep
  integer :: lb,lm,le

  mstep=1
  do while(mstep < n)
    lstep=mstep*2

    lb=1
    do while(lb < n)
      lm=lb+mstep
      le=min(lm-1+mstep,n)

      call merge_(lb,lm,le)
      indx(lb:le)=mtmp(lb:le)
      lb=le+1
    end do

    mstep=lstep
  end do
end subroutine MergeSort_

subroutine merge_(lb,lm,le)
  integer,intent(in) :: lb,lm,le
  integer :: l1,l2,l

  l1=lb
  l2=lm
  do l=lb,le
    if(l2.gt.le) then
      mtmp(l)=indx(l1)
      l1=l1+1
    elseif(l1.ge.lm) then
      mtmp(l)=indx(l2)
      l2=l2+1
    else
      if(dsnd) then
        if(keys(ikey,indx(l1)) .ge. keys(ikey,indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      else
        if(keys(ikey,indx(l1)) .le. keys(ikey,indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      endif
    endif
  end do
end subroutine merge_

end subroutine iSort1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: i8Sort1_ - A stable merge index sorting of 8-byte INTs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine i8Sort1_(indx,keys,ikey,descend,stat)
      use m_stdio, only : stderr
      use m_die,   only : die
      implicit none

      integer, dimension(:), intent(inout) :: indx
      integer(i8), dimension(:,:), intent(in) :: keys
      integer,intent(in) :: ikey
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!   17Dec14 - goldy@ucar.edu - Added 8-byte version
!	15Mar00	- Jing Guo
!		. initial prototype/prolog/code
!		. Copied code from iSort_
!		. Extended the interface and the algorithm to handle
!		  2-d arrays with an index.
!EOP ___________________________________________________________________

  logical :: dsnd
  integer :: ierr
  integer, dimension(:),allocatable :: mtmp
  integer :: n

  character(len=*),parameter :: myname_=myname//'::i8Sort1_'

  if(present(stat)) stat=0

  n=size(indx)

  allocate(mtmp(n),stat=ierr)
  if(ierr /= 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': allocate(mtmp(:)) error, stat =',ierr
    if(.not.present(stat)) call die(myname_)
    stat=ierr
    return
  endif

  dsnd=.false.
  if(present(descend)) dsnd=descend

  call MergeSort_()

  deallocate(mtmp)

contains
subroutine MergeSort_()
  implicit none
  integer :: mstep,lstep
  integer :: lb,lm,le

  mstep=1
  do while(mstep < n)
    lstep=mstep*2

    lb=1
    do while(lb < n)
      lm=lb+mstep
      le=min(lm-1+mstep,n)

      call merge_(lb,lm,le)
      indx(lb:le)=mtmp(lb:le)
      lb=le+1
    end do

    mstep=lstep
  end do
end subroutine MergeSort_

subroutine merge_(lb,lm,le)
  integer,intent(in) :: lb,lm,le
  integer :: l1,l2,l

  l1=lb
  l2=lm
  do l=lb,le
    if(l2.gt.le) then
      mtmp(l)=indx(l1)
      l1=l1+1
    elseif(l1.ge.lm) then
      mtmp(l)=indx(l2)
      l2=l2+1
    else
      if(dsnd) then
        if(keys(ikey,indx(l1)) .ge. keys(ikey,indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      else
        if(keys(ikey,indx(l1)) .le. keys(ikey,indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      endif
    endif
  end do
end subroutine merge_

end subroutine i8Sort1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: rSort1_ - A stable merge index sorting REALs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine rSort1_(indx,keys,ikey,descend,stat)
      use m_stdio, only : stderr
      use m_die,   only : die
      use m_realkinds,only : SP
      implicit none

      integer, dimension(:), intent(inout) :: indx
      real(SP),dimension(:,:), intent(in) :: keys
      integer,intent(in) :: ikey
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. initial prototype/prolog/code
!		. Copied code from rSort_
!		. Extended the interface and the algorithm to handle
!		  2-d arrays with an index.
!EOP ___________________________________________________________________

  logical :: dsnd
  integer :: ierr
  integer, dimension(:),allocatable :: mtmp
  integer :: n

  character(len=*),parameter :: myname_=myname//'::rSort1_'

  if(present(stat)) stat=0

  n=size(indx)

  allocate(mtmp(n),stat=ierr)
  if(ierr /= 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': allocate(mtmp(:)) error, stat =',ierr
    if(.not.present(stat)) call die(myname_)
    stat=ierr
    return
  endif

  dsnd=.false.
  if(present(descend)) dsnd=descend

  call MergeSort_()

  deallocate(mtmp)

contains
subroutine MergeSort_()
  implicit none
  integer :: mstep,lstep
  integer :: lb,lm,le

  mstep=1
  do while(mstep < n)
    lstep=mstep*2

    lb=1
    do while(lb < n)
      lm=lb+mstep
      le=min(lm-1+mstep,n)

      call merge_(lb,lm,le)
      indx(lb:le)=mtmp(lb:le)
      lb=le+1
    end do

    mstep=lstep
  end do
end subroutine MergeSort_

subroutine merge_(lb,lm,le)
  integer,intent(in) :: lb,lm,le
  integer :: l1,l2,l

  l1=lb
  l2=lm
  do l=lb,le
    if(l2.gt.le) then
      mtmp(l)=indx(l1)
      l1=l1+1
    elseif(l1.ge.lm) then
      mtmp(l)=indx(l2)
      l2=l2+1
    else
      if(dsnd) then
        if(keys(ikey,indx(l1)) .ge. keys(ikey,indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      else
        if(keys(ikey,indx(l1)) .le. keys(ikey,indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      endif
    endif
  end do
end subroutine merge_

end subroutine rSort1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: dSort1_ - A stable merge index sorting DOUBLEs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine dSort1_(indx,keys,ikey,descend,stat)
      use m_stdio, only : stderr
      use m_die,   only : die
      use m_realkinds,only : DP
      implicit none

      integer, dimension(:), intent(inout) :: indx
      real(DP), dimension(:,:), intent(in) :: keys
      integer,intent(in) :: ikey
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. initial prototype/prolog/code
!		. Copied code from dSort_
!		. Extended the interface and the algorithm to handle
!		  2-d arrays with an index.
!EOP ___________________________________________________________________

  logical :: dsnd
  integer :: ierr
  integer, dimension(:),allocatable :: mtmp
  integer :: n

  character(len=*),parameter :: myname_=myname//'::dSort1_'

  if(present(stat)) stat=0

  n=size(indx)

  allocate(mtmp(n),stat=ierr)
  if(ierr /= 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': allocate(mtmp(:)) error, stat =',ierr
    if(.not.present(stat)) call die(myname_)
    stat=ierr
    return
  endif

  dsnd=.false.
  if(present(descend)) dsnd=descend

  call MergeSort_()

  deallocate(mtmp)

contains
subroutine MergeSort_()
  implicit none
  integer :: mstep,lstep
  integer :: lb,lm,le

  mstep=1
  do while(mstep < n)
    lstep=mstep*2

    lb=1
    do while(lb < n)
      lm=lb+mstep
      le=min(lm-1+mstep,n)

      call merge_(lb,lm,le)
      indx(lb:le)=mtmp(lb:le)
      lb=le+1
    end do

    mstep=lstep
  end do
end subroutine MergeSort_

subroutine merge_(lb,lm,le)
  integer,intent(in) :: lb,lm,le
  integer :: l1,l2,l

  l1=lb
  l2=lm
  do l=lb,le
    if(l2.gt.le) then
      mtmp(l)=indx(l1)
      l1=l1+1
    elseif(l1.ge.lm) then
      mtmp(l)=indx(l2)
      l2=l2+1
    else
      if(dsnd) then
        if(keys(ikey,indx(l1)) .ge. keys(ikey,indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      else
        if(keys(ikey,indx(l1)) .le. keys(ikey,indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      endif
    endif
  end do
end subroutine merge_

end subroutine dSort1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: cSort1_ - A stable merge index sorting of CHAR(*)s.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine cSort1_(indx,keys,ikey,descend,stat)
      use m_stdio, only : stderr
      use m_die,   only : die
      implicit none

      integer, dimension(:), intent(inout) :: indx
      character(len=*), dimension(:,:), intent(in) :: keys
      integer,intent(in) :: ikey
      logical, optional, intent(in)  :: descend
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. initial prototype/prolog/code
!		. Copied code from cSort_
!		. Extended the interface and the algorithm to handle
!		  2-d arrays with an index.
!EOP ___________________________________________________________________

  logical :: dsnd
  integer :: ierr
  integer, dimension(:),allocatable :: mtmp
  integer :: n

  character(len=*),parameter :: myname_=myname//'::cSort1_'

  if(present(stat)) stat=0

  n=size(indx)

  allocate(mtmp(n),stat=ierr)
  if(ierr /= 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': allocate(mtmp(:)) error, stat =',ierr
    if(.not.present(stat)) call die(myname_)
    stat=ierr
    return
  endif

  dsnd=.false.
  if(present(descend)) dsnd=descend

  call MergeSort_()

  deallocate(mtmp)

contains
subroutine MergeSort_()
  implicit none
  integer :: mstep,lstep
  integer :: lb,lm,le

  mstep=1
  do while(mstep < n)
    lstep=mstep*2

    lb=1
    do while(lb < n)
      lm=lb+mstep
      le=min(lm-1+mstep,n)

      call merge_(lb,lm,le)
      indx(lb:le)=mtmp(lb:le)
      lb=le+1
    end do

    mstep=lstep
  end do
end subroutine MergeSort_

subroutine merge_(lb,lm,le)
  integer,intent(in) :: lb,lm,le
  integer :: l1,l2,l

  l1=lb
  l2=lm
  do l=lb,le
    if(l2.gt.le) then
      mtmp(l)=indx(l1)
      l1=l1+1
    elseif(l1.ge.lm) then
      mtmp(l)=indx(l2)
      l2=l2+1
    else
      if(dsnd) then
        if(keys(ikey,indx(l1)) .ge. keys(ikey,indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      else
        if(keys(ikey,indx(l1)) .le. keys(ikey,indx(l2))) then
          mtmp(l)=indx(l1)
          l1=l1+1
        else
          mtmp(l)=indx(l2)
          l2=l2+1
        endif
      endif
    endif
  end do
end subroutine merge_

end subroutine cSort1_
!-----------------------------------------------------------------------
end module m_MergeSorts
!.
