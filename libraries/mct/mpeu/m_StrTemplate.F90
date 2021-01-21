!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_StrTemplate - A template formatting a string with variables
!
! !DESCRIPTION:
!
!	A template resolver formatting a string with a string variable
!   and time variables.  The format descriptors are similar to those
!   used in the GrADS.
!
!	"%y4"	substitute with a 4 digit year
!	"%y2"	a 2 digit year
!	"%m1"	a 1 or 2 digit month
!	"%m2"	a 2 digit month
!	"%mc"	a 3 letter month in lower cases
!	"%Mc"	a 3 letter month with a leading letter in upper case
!	"%MC"	a 3 letter month in upper cases
!	"%d1"	a 1 or 2 digit day
!	"%d2"	a 2 digit day
!	"%h1"	a 1 or 2 digit hour
!	"%h2"	a 2 digit hour
!	"%h3"	a 3 digit hour (?)
!	"%n2"	a 2 digit minute
!	"%s"	a string variable
!	"%%"	a "%"
!
! !INTERFACE:

    module m_StrTemplate
      implicit none
      private	! except

      public :: StrTemplate	! Substitute variables in a template

      interface StrTemplate
	module procedure strTemplate_
      end interface

! !REVISION HISTORY:
! 	01Jun99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
! 	19Jan01	- Jay Larson <larson@mcs.anl.gov> - removed numerous
!                 double-quote characters appearing inside single-quote
!                 blocks.  This was done to comply with pgf90.  Also,
!                 numerous double-quote characters were removed from
!                 within comment blocks because pgf90 kept trying to
!                 interpret them (spooky).
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT(MPEU)::m_StrTemplate'

  character(len=3),parameter,dimension(12) :: mon_lc =	(/	&
	'jan','feb','mar','apr','may','jun',	&
	'jul','aug','sep','oct','nov','dec'	/)

  character(len=3),parameter,dimension(12) :: mon_wd =	(/	&
	'Jan','Feb','Mar','Apr','May','Jun',	&
	'Jul','Aug','Sep','Oct','Nov','Dec'	/)

  character(len=3),parameter,dimension(12) :: mon_uc =	(/	&
	'JAN','FEB','MAR','APR','MAY','JUN',	&
	'JUL','AUG','SEP','OCT','NOV','DEC'	/)

contains
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: strTemplate_ - expanding a format template to a string
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine strTemplate_(str,tmpl,class,xid,nymd,nhms,stat)
      use m_chars, only : uppercase
      use m_stdio, only : stderr
      use m_die,   only : die
      implicit none

      character(len=*),intent(out) :: str	! the output

      character(len=*),intent(in ) :: tmpl	! a "format"

      character(len=*),intent(in ),optional :: class
			! choose a UNIX or a GrADS(defulat) type format

      character(len=*),intent(in ),optional :: xid
			! a string substituting a '%s'.  Trailing
			! spaces will be ignored

      integer,intent(in ),optional :: nymd
			! yyyymmdd, substituting '%y4', '%y2', '%m1',
			! '%m2', '%mc', '%Mc', and '%MC'

      integer,intent(in ),optional :: nhms
			! hhmmss, substituting '%h1', '%h2', '%h3',
			! and '%n2'

      integer,intent(out),optional :: stat
			! error code

! !REVISION HISTORY:
! 	03Jun99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!       08Jan03 - R. Jacob <jacob@mcs.anl.gov>  Small change to get
!          around IBM compiler bug.  Cant have character valued functions
!          in case statements.  Fix found by Everest Ong.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::strTemplate_'
  character(len=16) :: tmpl_class
  character(len=16) :: tmp_upper

  tmpl_class="GX"
  if(present(class)) tmpl_class=class

  tmp_upper = uppercase(tmpl_class)
  select case(tmp_upper)

  case("GX","GRADS")
    call GX_(str,tmpl,xid,nymd,nhms,stat)

  !case("UX","UNIX")	! yet to be implemented
  !  call UX_(str,tmpl,xid,nymd,nhms,stat)

  case default
    write(stderr,'(4a)') myname_,': unknown class:  ',	&
	trim(tmpl_class),'.'
    if(.not.present(stat)) call die(myname_)
    stat=-1
    return
  end select

end subroutine strTemplate_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GX_ - evaluate a GrADS style string template
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine GX_(str,tmpl,xid,nymd,nhms,stat)
      use m_stdio,only : stderr
      use m_die,  only : die,perr
      implicit none
      character(len=*),intent(out) :: str
      character(len=*),intent(in ) :: tmpl
      character(len=*),optional,intent(in) :: xid
      integer,optional,intent(in)  :: nymd
      integer,optional,intent(in)  :: nhms
      integer,optional,intent(out) :: stat

! !REVISION HISTORY:
! 	01Jun99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!       19Jan01 - Jay Larson <larson@mcs.anl.gov> - added
!                 variable c1c2, to store c1//c2, which pgf90
!                 would not allow as an argument to the 'select case'
!                 statement.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GX_'

  integer :: iy4,iy2,imo,idy
  integer :: ihr,imn
  integer :: i,i1,i2,m,k
  integer :: ln_tmpl,ln_str
  integer :: istp,kstp

  character(len=1) :: c0,c1,c2
  character(len=2) :: c1c2
  character(len=4) :: sbuf
!________________________________________
	! Determine iyr, imo, and idy
  iy4=-1
  iy2=-1
  imo=-1
  idy=-1
  if(present(nymd)) then
	if(nymd < 0) then
	  call perr(myname_,'nymd < 0',nymd)
	  if(.not.present(stat)) call die(myname_)
	  stat=1
	  return
	endif

    i=nymd
    iy4=i/10000
    iy2=mod(iy4,100)
      i=mod(i,10000)
    imo=i/100
      i=mod(i,100)
    idy=i
  endif
!________________________________________
	! Determine ihr and imn
  ihr=-1
  imn=-1
  if(present(nhms)) then
	if(nhms < 0) then
	  call perr(myname_,'nhms < 0',nhms)
	  if(.not.present(stat)) call die(myname_)
	  stat=1
	  return
	endif

    i=nhms
    ihr=i/10000
      i=mod(i,10000)
    imn=i/100
  endif
!________________________________________

  ln_tmpl=len_trim(tmpl)	! size of the format template
  ln_str =len(str)		! size of the output string
!________________________________________

  if(present(stat)) stat=0

str=""

i=0; istp=1
k=1; kstp=1

do while( i+istp <= ln_tmpl )	! A loop over all tokens in (tmpl)

  if(k>ln_Str) exit	! truncate the output here.

  i=i+istp
  c0=tmpl(i:i)

  select case(c0)
  case ("%")
	!________________________________________

    c1=""
    i1=i+1
    if(i1 <= ln_Tmpl) c1=tmpl(i1:i1)
	!________________________________________

    select case(c1)

    case("s")
      if(.not.present(xid)) then
	write(stderr,'(2a)') myname_,	&
		': optional argument expected, "xid="'
	if(.not.present(stat)) call die(myname_)
	stat=1
	return
      endif

      istp=2
      m=min(k+len_trim(xid)-1,ln_str)
      str(k:m)=xid
      k=m+1
      cycle

    case("%")

      istp=2
      str(k:k)="%"
      k=k+1	! kstp=1
      cycle

    case default

      c2=""
      i2=i+2
      if(i2 <= ln_Tmpl) c2=tmpl(i2:i2)
	!________________________________________

      c1c2 = c1 // c2
      select case(c1c2)

      case("y4","y2","m1","m2","mc","Mc","MC","d1","d2")
        if(.not.present(nymd)) then
	  write(stderr,'(2a)') myname_,	&
		': optional argument expected, "nymd="'
	  if(.not.present(stat)) call die(myname_)
	  stat=1
	  return
        endif
        istp=3

      case("h1","h2","h3","n2")
        if(.not.present(nhms)) then
	  write(stderr,'(2a)') myname_,	&
		': optional argument expected, "nhms="'
	  if(.not.present(stat)) call die(myname_)
	  stat=1
	  return
        endif
        istp=3

      case default

        write(stderr,'(4a)') myname_,	&
	  ': invalid template entry:  ',trim(tmpl(i:)),'.'
        if(.not.present(stat)) call die(myname_)
        stat=2
        return

      end select	  ! case(c1//c2)
    end select		! case(c1)
	!________________________________________

    select case(c1)

    case("y")
      select case(c2)
      case("2")
	write(sbuf,'(i2.2)') iy2
	kstp=2
      case("4")
	write(sbuf,'(i4.4)') iy4
	kstp=4
      case default
	write(stderr,'(4a)') myname_,	&
	  ': invalid template entry:  ',trim(tmpl(i:)),'.'
	if(.not.present(stat)) call die(myname_)
	stat=2
	return
      end select

    case("m")
      select case(c2)
      case("1")
	if(imo < 10) then
	  write(sbuf,'(i1)') imo
	  kstp=1
	else
	  write(sbuf,'(i2)') imo
	  kstp=2
	endif
      case("2")
	write(sbuf,'(i2.2)') imo
	kstp=2
      case("c")
	sbuf=mon_lc(imo)
	kstp=3
      case default
	write(stderr,'(4a)') myname_,	&
	  ': invalid template entry:  ',trim(tmpl(i:)),'.'
	if(.not.present(stat)) call die(myname_)
	stat=2
	return
      end select

    case("M")
      select case(c2)
      case("c")
	sbuf=mon_wd(imo)
	kstp=3
      case("C")
	sbuf=mon_uc(imo)
	kstp=3
      case default
	write(stderr,'(4a)') myname_,	&
	  ': invalid template entry:  ',trim(tmpl(i:)),'.'
	if(.not.present(stat)) call die(myname_)
	stat=2
	return
      end select

    case("d")
      select case(c2)
      case("1")
	if(idy < 10) then
	  write(sbuf,'(i1)') idy
	  kstp=1
	else
	  write(sbuf,'(i2)') idy
	  kstp=2
	endif
      case("2")
	write(sbuf,'(i2.2)') idy
	kstp=2
      case default
	write(stderr,'(4a)') myname_,	&
	  ': invalid template entry:  ',trim(tmpl(i:)),'.'
	if(.not.present(stat)) call die(myname_)
	stat=2
	return
      end select

    case("h")
      select case(c2)
      case("1")
	if(ihr < 10) then
	  write(sbuf,'(i1)') ihr
	  kstp=1
	else
	  write(sbuf,'(i2)') ihr
	  kstp=2
	endif
      case("2")
	write(sbuf,'(i2.2)') ihr
	kstp=2
      case("3")
	write(sbuf,'(i3.3)') ihr
	kstp=3
      case default
	write(stderr,'(4a)') myname_,	&
	  ': invalid template entry:  ',trim(tmpl(i:)),'.'
	if(.not.present(stat)) call die(myname_)
	stat=2
	return
      end select

    case("n")
      select case(c2)
      case("2")
	write(sbuf,'(i2.2)') imn
	kstp=2
      case default
	write(stderr,'(4a)') myname_,	&
	  ': invalid template entry:  ',trim(tmpl(i:)),'.'
	if(.not.present(stat)) call die(myname_)
	stat=2
	return
      end select

    case default
	write(stderr,'(4a)') myname_,	&
	  ': invalid template entry:  ',trim(tmpl(i:)),'.'
	if(.not.present(stat)) call die(myname_)
	stat=2
      return
    end select	! case(c1)

    m=min(k+kstp-1,ln_Str)
    str(k:m)=sbuf
    k=m+1

  case default

    istp=1
    str(k:k)=tmpl(i:i)
    k=k+1

  end select	! case(c0)
end do

end subroutine GX_
end module m_StrTemplate
