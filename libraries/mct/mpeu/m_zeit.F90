!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: m_zeit - a multi-timer of process times and wall-clock times
!
! !DESCRIPTION:
!
! !INTERFACE:

    module m_zeit
      implicit none
      private	! except

      public :: zeit_ci		! push a new name to the timer
      public :: zeit_co		! pop the current name on the timer
      public :: zeit_flush	! print per PE timing
      public :: zeit_allflush	! print all PE timing
      public :: zeit_reset	! reset the timers to its initial state

	! Flags of all printable timers

      public ::  MWTIME	! MPI_Wtime() wall-clock time
      public ::  XWTIME	! times() wall-clock time
      public ::  PUTIME	! times() process user time
      public ::  PSTIME	! times() process system time
      public ::  CUTIME	! times() user time of all child-processes
      public ::  CSTIME	! times() system time of all child-processes
      public :: ALLTIME	! all of above
      public ::  UWRATE ! (putime+cutime)/xwtime

      interface zeit_ci;    module procedure ci_;    end interface
      interface zeit_co;    module procedure co_;    end interface
      interface zeit_flush; module procedure flush_; end interface
      interface zeit_allflush; module procedure allflush_; end interface
      interface zeit_reset; module procedure reset_; end interface

! !REVISION HISTORY:
!
! 	22Jan01 - Jay Larson <larson@mcs.anl.gov> - Minor correction in
!                 write statements in the routines sp_balances_() and
!                 mp_balances_():  replaced x (single-space) descriptor
!                 with 1x.  This is apparently strict adherance to the
!                 f90 standard (though the first of many, many compilers
!                 where it has arisen).  This was for the SunOS platform.
! 	05Mar98 - Jing Guo <guo@thunder>	-
!		. rewritten for possible MPI applications, with
!		  additional functionalities and new performance
!		  analysis information.
!		. Interface names have been redefined to ensure all
!		  use cases to be verified.
!		. removed the type(pzeit) data structure, therefore,
!		  limited to single _instance_ applications.
!		. added additional data components for more detailed
!		  timing analysis.
!		. used times() for the XPG4 standard conforming
!		  timing functions.
!		. used MPI_Wtime() for the MPI standard conforming
!		  high-resolution timing functions.
!
! 	20Feb97 - Jing Guo <guo@eramus>		-
!		. rewritten in Fortran 90 as the first modular
!		  version, with a type(pzeit) data structure.
!
!	10may96 - Jing G. -	Add _TZEITS macro for the testing code
!	09may96 - Jing G. -	Changed output format also modifed
!				comments
!	11Oct95 - Jing G. -	Removed earlier way of letting clock
!				timing (clkknt and clktot) to be no less
!				then the CPU timing, following a
!				suggestion by James Abeles from Cray.
!				This way, users may use the routings to
!				timing multitasking speedup as well.
!	12May95	- Jing G. -	Merged zeitCRAY.f and zeitIRIS.f.
!	Before	- ?	  -	See zeitCRAY.f and zeitIRIS.f for more
!				information.  Authors of those files are
!				not known to me.
!
! !DESIGN ISSUES:
!
!	05Mar98	- Jing Guo <guo@thunder>	-
!		. Removing the data structure may be consider as a
!		  limitation to future changes to multiple _instance_
!		  applications.  However, it is unlikely there will be
!		  any neccessary multi-_intance_ application soon, if
!		  ever for this module.
!		. Without an additional layer with the derived
!		  datatype, one may worry less the tricky performance
!		  issues associated with ci_/co_.
!		. Performance issue with the flush_() calls are not
!		  considered.
!
!	20Feb97	- Jing Guo <guo@eramus>		-
!		. Currently a single threaded module.  May be easily
!		  extended to multi-threaded module by adding the name
!		  of an instance of the class to the argument list.  It
!		  requires some but very limited interface extensions.
!		  Right now, the backward compatibility is the main
!		  issue.
!
! 10may96 - Jing Guo <guo@eramus>		-
!
!     + This zeit subroutine collection replaces original zeit files
!	used in PSAS on both systems, UNICOS and IRIX, with following
!	changes:
!
!	      +	Removed the some bugs in zeitCRAY.f that overite the
!		first user defined name entry in a special situation
!		(but not being able to correct in zeitCRAY.f).
!
!	      + Unified both zeitCRAY.f and zeitIRIS.f in to one file
!		(this file), that handles system dependency in only
!		one subroutine syszeit_() with a couple of lines of
!		differences.
!
!	      + Added system CPU time counts for system supporting
!		the function.
!
!	      + Added some error checking and reporting functions.
!
!	      + According to zeitCRAY.f, "zeit" is "time" in Germen.
!		The name is used through the code as another name for
!		"time".
!
!	      + This version does not work for parallelized processes.
!
!     + Elapsed time records since the first call are used.  Although
!	it may loose accuracy when the values of the time records
!	become large, it will keep the total time values conserved.
!
!     +	The accuracy of the elapsed times at a IEEE real*4 accuracy
!	(ffrac = 2^23 ~= 1.19e-7) should be no worse than +- 1 second
!	in 97 days, if only the numerical accuracy is considered.
!
!     +	The precision of "wall clock" time returned by syszeit_() is
!	only required to be reliable upto seconds.
!
!     +	The wall clock time for individual name tag (clkknt) is
!	accumulated by adding the differences between two integer
!	values, iclk and iclksv.  Care must be taken to compute the
!	differences of iclk and iclksv first.  That is, doing
!
!		clkknt()=clkknt() + (iclk-iclksv)
!
!	not
!
!		clkknt()=clkknt() + iclk-iclksv
!
!	The latter statement may ignore the difference between the two
!	integer values (iclk and iclksv).
!
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname='MCT(MPEU)::m_zeit'

  integer,parameter ::  MWTIME =  1
  integer,parameter ::  XWTIME =  2
  integer,parameter ::  PUTIME =  4
  integer,parameter ::  PSTIME =  8
  integer,parameter ::  CUTIME = 16
  integer,parameter ::  CSTIME = 32
  integer,parameter :: ALLTIME = MWTIME + XWTIME + PUTIME +	&
				 PSTIME + CUTIME + CSTIME
  integer,parameter ::  UWRATE = 64

  integer,parameter :: MASKS(0:5) =	&
	(/ MWTIME,XWTIME,PUTIME,PSTIME,CUTIME,CSTIME /)

  character(len=*),parameter :: ZEIT='.zeit.'
  character(len=8),parameter :: HEADER(0:5) =	&
    (/	'[MWTIME]','[XWTIME]','[PUTIME]',	&
	'[PSTIME]','[CUTIME]','[CSTIME]'	/)
  character(len=8),parameter :: UWRHDR = '[UWRATE]'

  integer,parameter :: MXN= 250	! the size of a name list
! integer,parameter :: NSZ= 32	! the size of a name
! LPC jun/6/2000
  integer,parameter :: NSZ= 36	! the size of a name
  integer,parameter :: MXS= 64	! the depth of the timer stack

  integer,save :: nreset=0
  logical,save :: started=.false.
  logical,save :: balanced=.false.

  character(len=NSZ),	&
	  save :: ciname=' '
  character(len=NSZ),	&
	  save :: coname=' '

  integer,save :: mxdep=0	! the maximum ndep value recorded
  integer,save :: ndep=-1	! depth, number of net ci_()
  integer,save :: lnk_n(0:MXS)	! name index of the depth

  integer,save			:: nname=-1	! number of accounts
  character(len=NSZ),	&
	  save,dimension(0:MXN) :: name_l	! the accounts
  integer,save,dimension(0:MXN)	:: knt_l	! counts of ci_() calls
  integer,save,dimension(0:MXN) :: level_l	! remaining ci_() counts

  real*8,save,dimension(0:5)	   :: zts_sv	! the last timings

  real*8,save,dimension(0:5,0:MXN) ::  zts_l	! credited to a name
  real*8,save,dimension(0:5,0:MXN) :: szts_l	! all under the name
  real*8,save,dimension(0:5,0:MXN) :: szts_sv	! the last ci_ timings

!=======================================================================
contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: ci_ - push an entry into the timer
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine ci_(name)
      use m_stdio, only : stderr
      use m_die, only : die
      use m_mpif90,only : MP_wtime
      implicit none
      character(len=*), intent(in) :: name

! !REVISION HISTORY:
! 	05Mar98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::ci_'

	! Local variables

  real*8,dimension(0:5) :: zts
  integer :: lname,iname
  integer :: i

	! Encountered a limitation.  Programming is required

  if(ndep >= MXS) then
    write(stderr,'(2a,i4)') myname_,	&
	': stack overflow with "'//trim(name)//'", ndep =',ndep
    call die(myname_)
  endif

	!--------------------------------------------------------
	! Initialize the stack if it is called the first time.

  if(.not.started) call reset_()

	! Get the current _zeits_

  call get_zeits(zts(1))
  zts(0)=MP_wtime()

	!--------------------------------------------------------
	! Charge the ticks since the last co_() to the current level

  lname=lnk_n(ndep)

  do i=0,5
    zts_l(i,lname)=zts_l(i,lname) + zts(i)-zts_sv(i)
  end do

  do i=0,5
    zts_sv(i)=zts(i)		! update the record
  end do

	!--------------------------------------------------------
	! Is the name already in the list?  Case sensitive and
	! space maybe sensitive if they are inbeded between non-
	! space characters.
	!
	! If the name is already in the list, the index of the
	! table entry is given.
	!
	! If the name is not in the list, a new entry will be added
	! to the list, if 1) there is room, and 2)

  iname=lookup_(name)

	!--------------------------------------------------------
	! push up the stack level

  ndep=ndep+1
  if(mxdep <= ndep) mxdep=ndep

  lnk_n(ndep)=iname
  knt_l(iname)=knt_l(iname)+1

	! Recording the check-in time, if there is no remaining
	! levels for the same name.  This is used to handle
	! recursive ci_() calls for the same name.

  if(level_l(iname) == 0) then
    do i=0,5
      szts_sv(i,iname)=zts_sv(i)
    end do
  endif

	! open a level

  level_l(iname)=level_l(iname)+1

end subroutine ci_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: co_ - pop the current level
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine co_(name,tms)
      use m_stdio, only : stderr
      use m_die, only : die
      use m_mpif90,only : MP_wtime
      implicit none
      character(len=*), intent(in) :: name	! account name
      real*8,optional,dimension(0:5,0:1),intent(out) :: tms ! timings

!     The returned variable tms(0:5,0:1) contains two sets of timing
!   information.  tms(0:5,0) is the NET timing data charged under the
!   account name only, and tms(0:5,1) is the SCOPE timing data since
!   the last ci() with the same account name and at the out most level.
!
! !REVISION HISTORY:
! 	11Oct99 - J.W. Larson - <jlarson@dao> explicit definition of
!                 tms as real*8
! 	05Mar98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::co_'

  real*8 :: tms0,tms1
  real*8,dimension(0:5) :: zts
  integer :: lname
  integer :: i

	! Encountered a limitation.  Programming is required

  if(ndep <= 0) then
    write(stderr,'(2a,i4)') myname_,	&
	': stack underflow with "'//trim(name)//'", ndep =',ndep
    call die(myname_)
  endif

	!--------------------------------------------------------
	! Initialize the stack if it is called the first time.

  if(.not.started) call reset_()

	! Get the current _zeits_

  call get_zeits(zts(1))
  zts(0)=MP_wtime()

	! need special handling if ndep is too large or too small.

  lname=lnk_n(ndep)
  level_l(lname)=level_l(lname)-1	! close a level

  do i=0,5
      tms0=zts(i)- zts_sv(i)		! NET by the _account_
      tms1=zts(i)-szts_sv(i,lname)	! within its SCOPE

      zts_l(i,lname)= zts_l(i,lname) + tms0

      if(level_l(lname) == 0)		&
        szts_l(i,lname)=szts_l(i,lname) + tms1

      zts_sv(i)=zts(i)

      if(present(tms)) then

	! Return the timings of the current call segment
	!
	!   tms(:,0) is for the NET timing data, that have been charged
	!	to this account.
	!
	!   tms(:,1) is for the SCOPE timing data since the ci() of the
	!	same account name at the out most level.
	!

        tms(i,0)=tms0
        tms(i,1)=tms1	! only the sub-segments
      endif
  end do

	! Record the unbalanced ci/co.  Name .void. is supplied for
	! backward compartible calls of pzeitend()

  if(name /= '.void.'.and.balanced) then
    balanced = lname == MXN .or. name == name_l(lname)
    if(.not.balanced) then
      ciname=name_l(lname)
      coname=name
    endif
  endif

	! pop (need special handling of ndep too large or too small.

  ndep=ndep-1

end subroutine co_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: reset_ - reset module m_zeit to an initial state
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine reset_()
      use m_mpif90,only : MP_wtime
      implicit none

! !REVISION HISTORY:
! 	04Mar98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::reset_'
  integer :: i

	! keep tracking the number of reset_() calls

  nreset=nreset+1
  started=.true.
  balanced=.true.

	! Start timing

  call get_zeits(zts_sv(1))
  zts_sv(0)=MP_wtime()

	! Sign in the module name for the overheads (.eqv. ci_(ZEIT))

  nname=0
  name_l(nname)=ZEIT
  knt_l(nname)=1

  ndep =0
  lnk_n(ndep)=nname

	! Initialize the timers.

  do i=0,5
     zts_l(i,nname)=0.
    szts_l(i,nname)=0.
    szts_sv(i,nname)=zts_sv(i)
  end do
  level_l(nname)=1

end subroutine reset_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: lookup_ search/insert a name
!
! !DESCRIPTION:
!
! !INTERFACE:

    function lookup_(name)
      implicit none
      character(len=*),intent(in) :: name
      integer :: lookup_

! !REVISION HISTORY:
! 	04Mar98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::lookup_'

  logical :: found
  integer :: ith
  integer :: i

  ith=-1
  found=.false.
  do while(.not.found.and. ith < min(nname,MXN))
    ith=ith+1
    found = name == name_l(ith)
  end do

  if(.not.found) then

    found = nname >= MXN	! Can not handle too many accounts?
    ith=MXN			! Then use the account for ".foo."

    if(.not.found) then		! Otherwise, add a new account.
      nname=nname+1
      ith=nname

      name_l(ith)=name
      if(ith==MXN) name_l(ith)='.foo.'

	! Initialize a new account

      do i=0,5
         zts_l(i,ith)=0.
	szts_l(i,ith)=0.
      end do
      level_l(ith)=0

    endif
  endif

  lookup_=ith

end function lookup_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: flush_ - print the timing data
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine flush_(lu,umask)
      use m_stdio, only : stderr
      use m_ioutil, only : luflush
      use m_die, only : die
      use m_mpif90,only : MP_wtime
      implicit none
      integer,intent(in) :: lu	! logical unit for the output
      integer,optional,intent(in) :: umask

! !REVISION HISTORY:
! 	05Mar98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::flush_'
  integer :: imask

  real*8,dimension(0:5) :: zts
  integer :: i,ier

	! specify which timer to print

  imask=MWTIME
  if(present(umask)) imask=umask

	! write a <newline>

  write(lu,*,iostat=ier)
  if(ier /= 0) then
    write(stderr,'(2a,i3)') myname_,': can not write(), unit =',lu
    call die(myname_)
  endif

  if(.not.balanced) write(lu,'(5a)') myname_,	&
	': ci/co unbalanced, ',trim(ciname),'/',trim(coname)

  call luflush(lu)

	! latest times, but not closing on any entry

  call get_zeits(zts(1))
  zts(0)=MP_wtime()

	! Print selected tables

  do i=0,5
    if(iand(MASKS(i),imask) /= 0)	&
      call sp_balances_(lu,i,zts(i))
  end do
#ifdef TODO
  if(iand(UWRATE,imask) /= 0) call sp_rate_(lu,zts)
#endif

  call luflush(lu)

end subroutine flush_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: sp_balances_ - print a table of a given timer
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine sp_balances_(lu,itm,zti)
      implicit none
      integer,intent(in) :: lu
      integer,intent(in) :: itm
      real*8,intent(in) :: zti

! !REVISION HISTORY:
! 	06Mar98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 	22Jan01 - Jay Larson <larson@mcs.anl.gov> - Minor correction in
!                 A write statement:  replaced x (single-space) descriptor
!                 with 1x.  This is apparently strict adherance to the
!                 f90 standard (though the first of many, many compilers
!                 where it has arisen).  This was for the SunOS platform.
! 	24Feb01 - Jay Larson <larson@mcs.anl.gov> - Extra decimal place in
!                 timing numbers (some reformatting will be necessary).
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::sp_balances_'

  real*8,parameter :: res=.001	! (sec)

  integer,parameter :: lnmax=12
  character(len=max(NSZ,lnmax)) :: name

  character(len=1) :: tag
  character(len=4) :: num

  integer :: zt_min,zt_sec
  integer :: sz_min,sz_sec
  integer :: l,i,ln

  real*8 :: sz0
  real*8 :: zt,zt_percent,zt_percall
  real*8 :: sz,sz_percent

	! The total time is given in the ZEIT bin

  sz0=szts_l(itm,0)
  if(level_l(0) /= 0) sz0=sz0 + zti - szts_sv(itm,0)
  sz0=max(res,sz0)

  write(lu,'(a,t14,a,t21,a,t31,a,t52,a)')	&
    HEADER(itm), 'counts','period',	&
      'NET    m:s      %',		&
    'SCOPE    m:s      %'

!23.|....1....|....2....|....3....|....4....|....5....|....6....|....7..
![MWTIME]    counts period    NET    m:s      %    SCOPE    m:s      %
!-----------------------------------------------------------------------
!zeit.      (  3s  3d  3)   333.3   33:33   3.3+   333.3   33:33   3.3+
!sub           333   33.3   333.3   33:33   3.3%   333.3   33:33   3.3%

  write(lu,'(80a)') ('-',i=1,72)
  do l=0,min(MXN,nname)

    zt= zts_l(itm,l)
    sz=szts_l(itm,l)
    tag='%'
    if(level_l(l) /= 0) then
      zt=zt + zti -  zts_sv(itm)
      sz=sz + zti - szts_sv(itm,l)
      tag='+'
    endif

    zt_percall=zt/max(1,knt_l(l))

    zt_percent=100.*zt/sz0
    sz_percent=100.*sz/sz0

    zt_sec=nint(zt)
    zt_min=    zt_sec/60
    zt_sec=mod(zt_sec,60)

    sz_sec=nint(sz)
    sz_min=    sz_sec/60
    sz_sec=mod(sz_sec,60)

    name=name_l(l)
    ln=max(len_trim(name),lnmax)

    select case(l)
      case(0)
	write(num,'(i4)') mxdep
!	write(lu,'(2(a,i3),2a,t26,2(1x,f7.1,1x,i4.2,a,i2.2,1x,f5.1,a))')&
	write(lu,'(2(a,i3),2a,t26,2(1x,f8.2,1x,i4.2,a,i2.2,1x,f6.2,a))')&
	  name(1:ln),nreset,'s',ndep,'/',num,		&
	  zt,zt_min,':',zt_sec,zt_percent,tag,		&
	  sz,sz_min,':',sz_sec,sz_percent,tag

!	write(lu,'(2a,3(i3,a),t26,2(x,f7.1,x,i4.2,a,i2.2,x,f5.1,a))')&
!	  name(1:ln),'(',nreset,'s',ndep,'d',mxdep,')',	&

      case default
        if(len_trim(name) < lnmax)then
!          write(lu,'(a,1x,i5,1x,f6.1,2(1x,f7.1,1x,i4.2,a,i2.2,1x,f5.1,a))') &
          write(lu,'(a,1x,i5,1x,f7.2,2(1x,f8.2,1x,i4.2,a,i2.2,1x,f6.2,a))') &
	  name(1:ln),knt_l(l),zt_percall,	&
	  zt,zt_min,':',zt_sec,zt_percent,tag,	&
	  sz,sz_min,':',sz_sec,sz_percent,tag
        else
          write(lu,'(a)')name(1:ln)
!          write(lu,'(13x,i5,1x,f6.1,2(1x,f7.1,1x,i4.2,a,i2.2,1x,f5.1,a))') &
          write(lu,'(13x,i5,1x,f7.2,2(1x,f8.2,1x,i4.2,a,i2.2,1x,f6.2,a))') &
          knt_l(l),zt_percall,       &
	  zt,zt_min,':',zt_sec,zt_percent,tag,	&
	  sz,sz_min,':',sz_sec,sz_percent,tag
        endif
    end select

  end do
  write(lu,'(80a)') ('-',i=1,72)

end subroutine sp_balances_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: allflush_ - print a summary of all PEs.
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine allflush_(comm,root,lu,umask)
      use m_stdio, only : stderr
      use m_ioutil, only : luflush
      use m_die, only : die
      use m_mpif90,only : MP_wtime,MP_type
      use m_mpif90,only : MP_comm_size,MP_comm_rank
      use m_SortingTools,only : IndexSet,IndexSort
      implicit none
      integer,intent(in) :: comm
      integer,intent(in) :: root
      integer,intent(in) :: lu
      integer,optional,intent(in) :: umask

! !REVISION HISTORY:
! 	09Mar98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::allflush_'
  integer myID,nPE
  integer :: imask
  real*8,dimension(0:5)		  :: zts
  real*8,dimension(0:5,0:1,0:MXN) :: ztbf
  real*8,dimension(:,:,:,:),allocatable :: ztmp
  integer,dimension(0:MXN) :: indx_
  integer :: mnm

  integer :: i,l
  integer :: nbf,ier
  integer :: mp_Type_ztbf

  mp_Type_ztbf=MP_type(ztbf(0,0,0))

  imask=MWTIME
  if(present(umask)) imask=umask

  if(imask==0) return

  call get_zeits(zts(1))
  zts(0)=MP_wtime()

	! Update the accounts and prepare for the messages

  mnm=min(MXN,nname)
  do l=0,mnm
    do i=0,5
      ztbf(i,0,l)= zts_l(i,l)
      ztbf(i,1,l)=szts_l(i,l)
    end do

    if(level_l(l) /= 0) then
		! Update the current accounts.
      do i=0,5
	ztbf(i,0,l)=ztbf(i,0,l) + zts(i) - zts_sv(i  )
	ztbf(i,1,l)=ztbf(i,1,l) + zts(i) -szts_sv(i,l)
      end do
    endif
  end do
  nbf=size(ztbf(0:5,0:1,0:mnm))

  call MP_comm_rank(comm,myID,ier)
  if(ier /= 0) then
    write(stderr,'(2a,i3)') myname_,	&
	': MP_comm_rank() error, ier =',ier
    call die(myname_)
  endif

	! An urgent hack for now.  Need to be fixed later.  J.G.
  indx_(0)=0
  call IndexSet( nname,indx_(1:mnm))
  call IndexSort(nname,indx_(1:mnm),name_l(1:mnm))

  if(myID /= root) then

    call MPI_gather((ztbf(0:5,0:1,indx_(0:mnm))),nbf,mp_Type_ztbf, &
		    ztbf,nbf,mp_Type_ztbf,root,comm,ier	)
    if(ier /= 0) then
      write(stderr,'(2a,i3)') myname_,	&
	': MPI_gather(!root) error, ier =',ier
      call die(myname_)
    endif

  else

    call MP_comm_size(comm,nPE,ier)
    if(ier /= 0) then
      write(stderr,'(2a,i3)') myname_,	&
	': MP_comm_size() error, ier =',ier
      call die(myname_)
    endif

    allocate(ztmp(0:5,0:1,0:mnm,0:nPE-1),stat=ier)
    if(ier /= 0) then
      write(stderr,'(2a,i4)') myname_,	&
	': allocate(zts) error, stat =',ier
      call die(myname_)
    endif

    call MPI_gather((ztbf(0:5,0:1,indx_(0:mnm))),nbf,mp_Type_ztbf, &
		    ztmp,nbf,mp_Type_ztbf,root,comm,ier	)
    if(ier /= 0) then
      write(stderr,'(2a,i3)') myname_,	&
	': MPI_gather(root) error, ier =',ier
      call die(myname_)
    endif

	! write a <newline>

    write(lu,*,iostat=ier)
    if(ier /= 0) then
      write(stderr,'(2a,i3)') myname_,': can not write(), unit =',lu
      call die(myname_)
    endif

    call luflush(lu)

    do i=0,5
      if(iand(MASKS(i),imask) /= 0)	&
	call mp_balances_(lu,i,nPE,ztmp,indx_)
    end do
#ifdef  TODO
    if(iand(UWRATE,imask) /= 0) call mp_rate_(lu,nPE,ztmp)
#endif

    deallocate(ztmp,stat=ier)
    if(ier /= 0) then
      write(stderr,'(2a,i4)') myname_,	&
	  ': deallocate(zts) error, stat =',ier
      call die(myname_)
    endif
  endif

   call luflush(lu)
end subroutine allflush_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: mp_balances_ - summarize the timing data of all PEs
!
! !DESCRIPTION:
!
! \newcommand{\tb}{\overline{t}}
!
!	\verb"mp_balances_"() summarizes the timing data of all PEs
!   with quantified load balancing measures:
!   \begin{eqnarray*}
!	x &=& \frac{\max(t) - \tb}{N\tb}	\times 100\%	\\
!	i &=& \frac{\max(t) - \tb}{\max(t)}	\times 100\%	\\
!	r &=& \frac{1}{N\tb} \sum^{t>\tb}{(t-\tb)}
!		\times 100\%
!   \end{eqnarray*}
!   where
!   \begin{center}
!     \begin{tabular}{rl}
!       $t$: & time by any process element			\\
!     $\tb$: & mean time by all process elements		\\
!	$x$: & the ma{\bf x}imum percentage load deviation	\\
!	$i$: & percentage {\bf i}dle process-time or
!					load {\bf i}mbalance	\\
!	$r$: & percentage {\bf r}elocatable loads		\\
!	$N$: & {\bf n}umber of process elements
!     \end{tabular}
!   \end{center}
!
! !INTERFACE:

    subroutine mp_balances_(lu,itm,nPE,ztmp,indx)
      implicit none
      integer,intent(in) :: lu
      integer,intent(in) :: itm
      integer,intent(in) :: nPE
      real*8,dimension(0:,0:,0:,0:),intent(in) :: ztmp
      integer,dimension(0:),intent(in) :: indx

! !REVISION HISTORY:
! 	10Mar98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 	22Jan01 - Jay Larson <larson@mcs.anl.gov> - Minor correction in
!                 A write statement:  replaced x (single-space) descriptor
!                 with 1x.  This is apparently strict adherance to the
!                 f90 standard (though the first of many, many compilers
!                 where it has arisen).  This was for the SunOS platform.
!       25Feb01 - R. Jacob <jacob@mcs.anl.gov> change number of
!                 decimal places from 1 to 4.
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::mp_balances_'

  real*8,parameter :: res=.001	! (sec)

  integer,parameter :: lnmax=12
  character(len=max(NSZ,lnmax)) :: name
  character(len=4) :: num

  integer :: i,k,l,ln,lx

	! NET times
  integer :: ix_o
  real*8  :: zts_o,zta_o,ztm_o,ztr_o
  integer :: x_o,i_o,r_o

	! SCOPE times
  integer :: ix_s
  real*8  :: zts_s,zta_s,ztm_s,ztr_s
  integer :: x_s,i_s,r_s

  write(num,'(i4)') nPE
  write(lu,'(3a,t18,a,t58,a)')	&
    HEADER(itm),'x',adjustl(num),	&
    'NET avg        max    imx x% r% i%',	&
    'SCP avg        max    imx x% r% i%'

!23.|....1....|....2....|....3....|....4....|....5....|....6....|....7..

!MWTIME]x3    NET avg     max imx x% r% i%  SCP avg     max imx x% r% i%
!-----------------------------------------------------------------------
!zeit.       333333.3 33333.3 333 33 33 33 333333.3 33333.3 333 33 33 33

write(lu,'(91a)') ('-',i=1,91)
do l=0,min(MXN,nname)

	! sum() of all processes

  zts_o=0.
  zts_s=0.

	! indices of max() of all processes

  ix_o=0
  ix_s=0
  do k=0,nPE-1

    zts_o=zts_o+ztmp(itm,0,l,k)		! compute sum()
    zts_s=zts_s+ztmp(itm,1,l,k)		! compute sum()

    if(ztmp(itm,0,l,ix_o) < ztmp(itm,0,l,k)) ix_o=k
    if(ztmp(itm,1,l,ix_s) < ztmp(itm,1,l,k)) ix_s=k

  end do

  zta_o=zts_o/max(1,nPE)		! compute mean()
  zta_s=zts_s/max(1,nPE)		! compute mean()

  ztr_o=0.
  ztr_s=0.
  do k=0,nPE-1
    if(ztmp(itm,0,l,k) > zta_o) ztr_o=ztr_o+ztmp(itm,0,l,k)-zta_o
    if(ztmp(itm,1,l,k) > zta_s) ztr_s=ztr_s+ztmp(itm,1,l,k)-zta_s
  end do

  ztm_o=ztmp(itm,0,l,ix_o)
  ztm_s=ztmp(itm,1,l,ix_s)

  lx=indx(l)
  name=name_l(lx)
  ln=max(len_trim(name),lnmax)

  x_o=nint(100.*(ztm_o-zta_o)/max(zts_o,res))
  r_o=nint(100.* ztr_o       /max(zts_o,res))
  i_o=nint(100.*(ztm_o-zta_o)/max(ztm_o,res))

  x_s=nint(100.*(ztm_s-zta_s)/max(zts_s,res))
  r_s=nint(100.* ztr_s       /max(zts_s,res))
  i_s=nint(100.*(ztm_s-zta_s)/max(ztm_s,res))

  write(lu,'(a,2(3x,f10.6,3x,f10.6,1x,z3.3,3i3,1x))')           &
	name(1:ln),				&
	zta_o,ztm_o,ix_o,x_o,r_o,i_o,		&
	zta_s,ztm_s,ix_s,x_s,r_s,i_s

end do
write(lu,'(91a)') ('-',i=1,91)
end subroutine mp_balances_

!=======================================================================
end module m_zeit
!.
