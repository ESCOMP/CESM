!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_rankMerge - A merging tool through ranking
!
! !DESCRIPTION:
!
! !INTERFACE:

    module m_rankMerge
      implicit none
      private	! except

      public :: rankSet		! set inital ranks
      public :: rankMerge	! merge two ranks
      public :: IndexedRankMerge ! index-merge two array segments

      interface rankSet; module procedure set_; end interface

      interface rankMerge; module procedure	&
	imerge_,	&	! rank-merging two integer arrays
	rmerge_,	&	! rank-merging two real arrays
	dmerge_,	&	! rank-merging two dble arrays
	uniq_			! merging to rank arrays
      end interface

      interface IndexedRankMerge; module procedure	&
	iindexmerge_,	&	! merging two index arrays of integers
	rindexmerge_,	&	! merging two index arrays of reals
	dindexmerge_		! merging two index arrays of dbles
      end interface

! !REVISION HISTORY:
! 	13Mar00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT(MPEU)::m_rankMerge'

contains
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: set_ - set initial ranking
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine set_(rank)
      implicit none
      integer,dimension(:),intent(out) :: rank

! !REVISION HISTORY:
! 	13Mar00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::set_'
  integer :: i

  do i=1,size(rank)
    rank(i)=0
  end do

end subroutine set_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: imerge_ - merge two sorted integer arrays by ranking
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine imerge_(value_i,value_j,krank_i,krank_j,descend)
      implicit none

      integer,dimension(:),intent(in)    :: value_j	! value of j-vec
      integer,dimension(:),intent(in)    :: value_i	! value of i-vec

      integer,dimension(:),intent(inout) :: krank_i	! rank of i-vec
      integer,dimension(:),intent(inout) :: krank_j	! rank of j-vec

      logical,optional,intent(in) :: descend

! !REVISION HISTORY:
! 	13Mar00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::imerge_'

  integer :: ni,nj
  logical :: descend_
  logical :: geti
  integer :: value_sv,value
  integer :: krank
  integer :: i,j

  descend_=.false.
  if(present(descend)) descend_=descend

  ni=size(krank_i)
  nj=size(krank_j)

  i=1
  j=1
  krank=0		! a preset rank value
  value_sv=0

  do
        geti=j>nj
        if(geti) then		! .eqv. j>nj
          if(i>ni) exit		! i>ni
          value = value_i(i)
        else			! .eqv. j<=nj
          geti = i<=ni
          if(geti) then         ! .eqv. i<=ni
            value = value_i(i)
            geti = krank_i(i) <= krank_j(j)
            if(krank_i(i)==krank_j(j)) then
              geti = value_i(i)<=value_j(j)
              if(descend_) geti = value_i(i)>=value_j(j)
            endif
          endif
          if(.not.geti) value = value_j(j)
        endif

        if(krank==0 .or. value /= value_sv) then
          krank=krank+1		! the next rank value
          value_sv=value
        endif

        if(geti) then
          krank_i(i)=krank
          i=i+1
        else
          krank_j(j)=krank
          j=j+1
        endif
  end do

end subroutine imerge_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: rmerge_ - merge two sorted real arrays by ranking
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine rmerge_(value_i,value_j,krank_i,krank_j,descend)
      use m_realkinds, only : SP
      implicit none

      real(SP),dimension(:),intent(in)    :: value_i	! value of i-vec
      real(SP),dimension(:),intent(in)    :: value_j	! value of j-vec

      integer,dimension(:),intent(inout) :: krank_i	! rank of i-vec
      integer,dimension(:),intent(inout) :: krank_j	! rank of j-vec

      logical,optional,intent(in) :: descend

! !REVISION HISTORY:
! 	13Mar00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::rmerge_'

  integer :: ni,nj
  logical :: descend_
  logical :: geti
  real(SP)    :: value_sv,value
  integer :: krank
  integer :: i,j

  descend_=.false.
  if(present(descend)) descend_=descend

  ni=size(krank_i)
  nj=size(krank_j)

  i=1
  j=1
  krank=0		! a preset rank value
  value_sv=0

  do
        geti=j>nj
        if(geti) then		! .eqv. j>nj
          if(i>ni) exit		! i>ni
          value = value_i(i)
        else			! .eqv. j<=nj
          geti = i<=ni
          if(geti) then         ! .eqv. i<=ni
            value = value_i(i)
            geti = krank_i(i) <= krank_j(j)
            if(krank_i(i)==krank_j(j)) then
              geti = value_i(i)<=value_j(j)
              if(descend_) geti = value_i(i)>=value_j(j)
            endif
          endif
          if(.not.geti) value = value_j(j)
        endif

        if(krank==0 .or. value /= value_sv) then
          krank=krank+1		! the next rank value
          value_sv=value
        endif

        if(geti) then
          krank_i(i)=krank
          i=i+1
        else
          krank_j(j)=krank
          j=j+1
        endif
  end do

end subroutine rmerge_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: dmerge_ - merge two sorted real arrays by ranking
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine dmerge_(value_i,value_j,krank_i,krank_j,descend)
      use m_realkinds, only : DP
      implicit none

      real(DP),dimension(:),intent(in)    :: value_i	! value of i-vec
      real(DP),dimension(:),intent(in)    :: value_j	! value of j-vec

      integer,dimension(:),intent(inout) :: krank_i	! rank of i-vec
      integer,dimension(:),intent(inout) :: krank_j	! rank of j-vec

      logical,optional,intent(in) :: descend

! !REVISION HISTORY:
! 	13Mar00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::dmerge_'

  integer :: ni,nj
  logical :: descend_
  logical :: geti
  real(DP):: value_sv,value
  integer :: krank
  integer :: i,j

  descend_=.false.
  if(present(descend)) descend_=descend

  ni=size(krank_i)
  nj=size(krank_j)

  i=1
  j=1
  krank=0		! a preset rank value
  value_sv=0

  do
        geti=j>nj
        if(geti) then		! .eqv. j>nj
          if(i>ni) exit		! i>ni
          value = value_i(i)
        else			! .eqv. j<=nj
          geti = i<=ni
          if(geti) then         ! .eqv. i<=ni
            value = value_i(i)
            geti = krank_i(i) <= krank_j(j)
            if(krank_i(i)==krank_j(j)) then
              geti = value_i(i)<=value_j(j)
              if(descend_) geti = value_i(i)>=value_j(j)
            endif
          endif
          if(.not.geti) value = value_j(j)
        endif

        if(krank==0 .or. value /= value_sv) then
          krank=krank+1		! the next rank value
          value_sv=value
        endif

        if(geti) then
          krank_i(i)=krank
          i=i+1
        else
          krank_j(j)=krank
          j=j+1
        endif
  end do

end subroutine dmerge_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: iindexmerge_ - merge two sorted integer arrays by ranking
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine iindexmerge_(indx_i,indx_j,value,krank_i,krank_j,descend)
      implicit none

      integer,dimension(:),intent(in)    :: indx_i	! of the i-vec
      integer,dimension(:),intent(in)    :: indx_j	! of the j-vec
      integer,dimension(:),intent(in)    :: value	! of the full

      integer,dimension(:),intent(inout) :: krank_i	! rank of i-vec
      integer,dimension(:),intent(inout) :: krank_j	! rank of j-vec

      logical,optional,intent(in) :: descend

! !REVISION HISTORY:
! 	13Mar00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::iindexmerge_'

  integer :: ni,nj
  logical :: descend_
  logical :: geti
  integer :: value_sv,value_
  integer :: krank
  integer :: i,j,li,lj

  descend_=.false.
  if(present(descend)) descend_=descend

  ni=size(krank_i)
  nj=size(krank_j)

  i=1
  j=1
  krank=0		! a preset rank value
  value_sv=0

  do
        geti=j>nj
        if(geti) then		! .eqv. j>nj
          if(i>ni) exit		! i>ni
	  li=indx_i(i)
          value_ = value(li)
        else			! .eqv. j<=nj
	  lj=indx_j(j)
          geti = i<=ni
          if(geti) then         ! .eqv. i<=ni
	    li=indx_i(i)
            value_ = value(li)
            geti = krank_i(i) <= krank_j(j)
            if(krank_i(i)==krank_j(j)) then
              geti = value(li)<=value(lj)
              if(descend_) geti = value(li)>=value(lj)
            endif
          endif
          if(.not.geti) value_ = value(lj)
        endif

        if(krank==0 .or. value_ /= value_sv) then
          krank=krank+1		! the next rank value
          value_sv=value_
        endif

        if(geti) then
          krank_i(i)=krank
          i=i+1
        else
          krank_j(j)=krank
          j=j+1
        endif
  end do

end subroutine iindexmerge_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: rindexmerge_ - merge two sorted real arrays by ranking
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine rindexmerge_(indx_i,indx_j,value,krank_i,krank_j,descend)
      use m_realkinds,only : SP
      implicit none

      integer,dimension(:),intent(in)    :: indx_i	! of the i-vec
      integer,dimension(:),intent(in)    :: indx_j	! of the j-vec
      real(SP),dimension(:),intent(in)    :: value	! of the full

      integer,dimension(:),intent(inout) :: krank_i	! rank of i-vec
      integer,dimension(:),intent(inout) :: krank_j	! rank of j-vec

      logical,optional,intent(in) :: descend

! !REVISION HISTORY:
! 	13Mar00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::rindexmerge_'

  integer :: ni,nj
  logical :: descend_
  logical :: geti
  real(SP):: value_sv,value_
  integer :: krank
  integer :: i,j,li,lj

  descend_=.false.
  if(present(descend)) descend_=descend

  ni=size(krank_i)
  nj=size(krank_j)

  i=1
  j=1
  krank=0		! a preset rank value
  value_sv=0

  do
        geti=j>nj
        if(geti) then		! .eqv. j>nj
          if(i>ni) exit		! i>ni
	  li=indx_i(i)
          value_ = value(li)
        else			! .eqv. j<=nj
	  lj=indx_j(j)
          geti = i<=ni
          if(geti) then         ! .eqv. i<=ni
	    li=indx_i(i)
            value_ = value(li)
            geti = krank_i(i) <= krank_j(j)
            if(krank_i(i)==krank_j(j)) then
              geti = value(li)<=value(lj)
              if(descend_) geti = value(li)>=value(lj)
            endif
          endif
          if(.not.geti) value_ = value(lj)
        endif

        if(krank==0 .or. value_ /= value_sv) then
          krank=krank+1		! the next rank value
          value_sv=value_
        endif

        if(geti) then
          krank_i(i)=krank
          i=i+1
        else
          krank_j(j)=krank
          j=j+1
        endif
  end do

end subroutine rindexmerge_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: dindexmerge_ - merge two sorted real arrays by ranking
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine dindexmerge_(indx_i,indx_j,value,krank_i,krank_j,descend)
      use m_realkinds,only : DP
      implicit none

      integer,dimension(:),intent(in)    :: indx_i	! of the i-vec
      integer,dimension(:),intent(in)    :: indx_j	! of the j-vec
      real(DP),dimension(:),intent(in)    :: value	! of the full

      integer,dimension(:),intent(inout) :: krank_i	! rank of i-vec
      integer,dimension(:),intent(inout) :: krank_j	! rank of j-vec

      logical,optional,intent(in) :: descend

! !REVISION HISTORY:
! 	13Mar00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::dindexmerge_'

  integer :: ni,nj
  logical :: descend_
  logical :: geti
  real(DP):: value_sv,value_
  integer :: krank
  integer :: i,j,li,lj

  descend_=.false.
  if(present(descend)) descend_=descend

  ni=size(krank_i)
  nj=size(krank_j)

  i=1
  j=1
  krank=0		! a preset rank value
  value_sv=0

  do
        geti=j>nj
        if(geti) then		! .eqv. j>nj
          if(i>ni) exit		! i>ni
	  li=indx_i(i)
          value_ = value(li)
        else			! .eqv. j<=nj
	  lj=indx_j(j)
          geti = i<=ni
          if(geti) then         ! .eqv. i<=ni
	    li=indx_i(i)
            value_ = value(li)
            geti = krank_i(i) <= krank_j(j)
            if(krank_i(i)==krank_j(j)) then
              geti = value(li)<=value(lj)
              if(descend_) geti = value(li)>=value(lj)
            endif
          endif
          if(.not.geti) value_ = value(lj)
        endif

        if(krank==0 .or. value_ /= value_sv) then
          krank=krank+1		! the next rank value
          value_sv=value_
        endif

        if(geti) then
          krank_i(i)=krank
          i=i+1
        else
          krank_j(j)=krank
          j=j+1
        endif
  end do

end subroutine dindexmerge_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: uniq_ - merge two rank arrays with unique rank values
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine uniq_(krank_i,krank_j)
      implicit none
      integer,dimension(:),intent(inout) :: krank_i	! rank of i-vec
      integer,dimension(:),intent(inout) :: krank_j	! rank of j-vec

! !REVISION HISTORY:
! 	13Mar00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::uniq_'

  integer :: ni,nj
  integer :: i,j
  integer :: krank
  logical :: geti

  ni=size(krank_i)
  nj=size(krank_j)

  i=1
  j=1
  krank=0
  do
        geti=j>nj
        if(geti) then		! .eqv. j>nj
          if(i>ni) exit		! i>ni
        else			! .eqv. j<=nj
          geti = i<=ni
          if(geti) geti = krank_i(i) <= krank_j(j)	! if(i<=ni) ..
        endif

        krank=krank+1		! the next rank value

	if(geti) then
	  krank_i(i)=krank
	  i=i+1
	else
	  krank_j(j)=krank
	  j=j+1
	endif
  end do

end subroutine uniq_

end module m_rankMerge
