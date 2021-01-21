!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: m_ioutil - a F90 module for several convenient I/O functions
!
! !DESCRIPTION:
!
!	m\_ioutil is a module containing several portable interfaces for
!	some highly system dependent, but frequently used I/O functions.
!
! !INTERFACE:

	module m_ioutil
	implicit none
	private	! except

	public	:: opntext,clstext ! open/close a text file
	public	:: opnieee,clsieee ! open/close a binary sequential file
	public	:: luavail	   ! return a free logical unit
	public	:: luflush	   ! flush the buffer of a given unit
	!public	:: MX_LU

! !REVISION HISTORY:
! 	16Jul96 - J. Guo	- (to do)
! 	02Apr97 - Jing Guo <guo@eramus> - finished the coding
!	11Feb97 - Jing Guo <guo@thunder> - added luflush()
!       08Nov01  - Jace A Mogill <mogill@cray.com>  FORTRAN only defines
!                 99 units, three units below unit 10 are often used for
!                 stdin, stdout, and stderr.  Be far more conservative
!                 and stay within FORTRAN standard.
!
!EOP
!_______________________________________________________________________

	character(len=*),parameter :: myname="MCT(MPEU)::m_ioutil"
	integer,parameter :: MX_LU=99

contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: opnieee - portablly open an IEEE format file
!
! !DESCRIPTION:
!
!	Open a file in IEEE format.
!
!	IEEE format is refered as a FORTRAN "unformatted" file with
!	"sequantial" access and variable record lengths.  Under common
!	Unix, it is only a file with records packed with a leading 4-
!	byte word and a trailing 4-byte word indicating the size of
!	the record in bytes.  However, under UNICOS, it is also assumed
!	to have numerical data representations represented according to
!	the IEEE standard corresponding KIND conversions.  Under a DEC
!	machine, it means that compilations of the source code should
!	have the "-bigendian" option specified.
!
! !INTERFACE:

    subroutine opnieee(lu,fname,status,ier,recl)
      use m_stdio,only : stderr
      implicit none

      integer,         intent(in) :: lu     ! logical unit number
      character(len=*),intent(in) :: fname  ! filename to be opended
      character(len=*),intent(in) :: status ! the value for STATUS=
      integer,         intent(out):: ier    ! the status
      integer,optional,intent(in) :: recl   ! record length

! !REVISION HISTORY:
!	02Feb95 - Jing G. - First version included in PSAS.  It is not
!		used in the libpsas.a calls, since no binary data input/
!		output is to be handled.
!
! 	09Oct96 - J. Guo  - Check for any previous assign() call under
!		UNICOS.
!EOP
!_______________________________________________________________________

#ifdef _UNICOS
	character(len=128) :: attr
#endif

		! local parameter
	character(len=*),parameter :: myname_=myname//'::opnieee'

	integer,parameter :: iA=ichar('a')
	integer,parameter :: mA=ichar('A')
	integer,parameter :: iZ=ichar('z')

	logical :: direct
	character(len=16) :: clen
	character(len=len(status)) :: Ustat
	integer :: i,ic

! Work-around for absoft 9.0 f90, which has trouble understanding that
! ier is an output argument from the write() call below.

	ier = 0

	direct=.false.
	if(present(recl)) then
	  if(recl<0) then
	    clen='****************'
	    write(clen,'(i16)',iostat=ier) recl
	    write(stderr,'(3a)') myname_,	&
		': invalid recl, ',trim(adjustl(clen))
	    ier=-1
	    return
	  endif
	  direct = recl>0
	endif

#ifdef _UNICOS
	call asnqunit(lu,attr,ier)	! test the unit

	if(ier.eq.-1) then		! the unit is not used
	  if(direct) then
	    call asnunit(lu,'-N ieee -F null',ier)
	  else
	    call asnunit(lu,'-N ieee -F f77',ier)
	  endif
	  ier=0

	elseif(ier.ge.0) then		! the unit is already assigned
	  ier=-1
	endif
	if(ier.ne.0) return
#endif

	do i=1,len(status)
	  ic=ichar(status(i:i))
	  if(ic >= iA .and. ic <= iZ) ic=ic+(mA-iA)
	  Ustat(i:i)=char(ic)
	end do

	select case(Ustat)

	case ('APPEND')

	  if(direct) then
	    write(stderr,'(2a)') myname_,		&
		': invalid arguments, (status=="APPEND",recl>0)'
	    ier=1
	    return
	  endif

	  open(				&
	    unit	=lu,		&
	    file	=fname,		&
	    form	='unformatted',	&
	    access	='sequential',	&
	    status	='unknown',	&
	    position	='append',	&
	    iostat	=ier		)

	case default

	  if(direct) then
	    open(			&
	      unit	=lu,		&
	      file	=fname,		&
	      form	='unformatted',	&
	      access	='direct',	&
	      status	=status,	&
	      recl	=recl,		&
	      iostat	=ier		)

	  else
	    open(			&
	      unit	=lu,		&
	      file	=fname,		&
	      form	='unformatted',	&
	      access	='sequential',	&
	      status	=status,	&
	      position	='asis',	&
	      iostat	=ier		)
	  endif

	end select

	end subroutine opnieee
!-----------------------------------------------------------------------
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: clsieee - Close a logical unit opened by opnieee()
!
! !DESCRIPTION:
!
!	The reason for a paired clsieee() for opnieee() instead of a
!	simple close(), is for the portability reason.  For example,
!	under UNICOS, special system calls may be need to set up the
!	unit right, and the status of the unit should be restored upon
!	close.
!
! !INTERFACE:

	subroutine clsieee(lu,ier)
	  implicit none
	  integer, intent(in)  :: lu	! the unit used by opnieee()
	  integer, intent(out) :: ier	! the status

! !REVISION HISTORY:
! 	10Oct96 - J. Guo	- (to do)
!EOP
!_______________________________________________________________________
	  close(lu,iostat=ier)
#ifdef _UNICOS
	  if(ier==0) call asnunit(lu,'-R',ier) ! remove attributes
#endif

	end subroutine clsieee

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: opntext - portablly open a text file
!
! !DESCRIPTION:
!
!	Open a text (ASCII) file.  Under FORTRAN, it is defined as
!	"formatted" with "sequential" access.
!
! !INTERFACE:

    subroutine opntext(lu,fname,status,ier)
      implicit none

      integer,         intent(in) :: lu     ! logical unit number
      character(len=*),intent(in) :: fname  ! filename to be opended
      character(len=*),intent(in) :: status ! the value for STATUS=<>
      integer,         intent(out):: ier    ! the status


! !REVISION HISTORY:
!
!	02Feb95 - Jing G. - First version included in PSAS and libpsas.a
! 	09Oct96 - J. Guo  - modified to allow assign() call under UNICOS
!			  = and now, it is a module in Fortran 90.
!EOP
!_______________________________________________________________________

		! local parameter
	character(len=*),parameter :: myname_=myname//'::opntext'

	integer,parameter :: iA=ichar('a')
	integer,parameter :: mA=ichar('A')
	integer,parameter :: iZ=ichar('z')

	character(len=len(status)) :: Ustat
	integer :: i,ic

#ifdef _UNICOS
	call asnunit(lu,'-R',ier)	! remove any set attributes
	if(ier.ne.0) return		! let the parent handle it
#endif

	do i=1,len(status)
	  ic=ichar(status(i:i))
	  if(ic >= iA .and. ic <= iZ) ic=ic+(mA-iA)
	  Ustat(i:i)=char(ic)
	end do

	select case(Ustat)

	case ('APPEND')

	  open(				&
	    unit	=lu,		&
	    file	=fname,		&
	    form	='formatted',	&
	    access	='sequential',	&
	    status	='unknown',	&
	    position	='append',	&
	    iostat	=ier		)

	case default

	  open(				&
	    unit	=lu,		&
	    file	=fname,		&
	    form	='formatted',	&
	    access	='sequential',	&
	    status	=status,	&
	    position	='asis',	&
	    iostat	=ier		)

	end select

	end subroutine opntext

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: clstext - close a text file opend with an opntext() call
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine clstext(lu,ier)
      implicit none

      integer, intent(in)  :: lu  ! a logical unit to close
      integer, intent(out) :: ier ! the status

! !REVISION HISTORY:
! 	09Oct96 - J. Guo	- (to do)
!EOP
!_______________________________________________________________________

	close(lu,iostat=ier)
#ifdef _UNICOS
	if(ier == 0) call asnunit(lu,'-R',ier)	! remove any attributes
#endif

	end subroutine clstext

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: luavail - locate the next available unit
!
! !DESCRIPTION:
!
!    luavail() Look for an available (not opened and not statically
!    assigned to any I/O attributes to) logical unit.
!
! !INTERFACE:

	function luavail()
	  use m_stdio
	  implicit none
	  integer :: luavail	! result

! !REVISION HISTORY:
! 	23Apr98 - Jing Guo <guo@thunder> - new prototype/prolog/code
!			- with additional unit constraints for SunOS.
!
! 	: Jing Guo, [09-Oct-96]
! 		+ Checking also Cray assign() attributes, with some
! 		  changes to the code.  See also other routines.
!
! 	: Jing Guo, [01-Apr-94]
! 		+ Initial code.
!   2001-11-08  - Jace A Mogill <mogill@cray.com>  clean up
!		  logic for finding lu.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::luavail'

	integer lu,ios
	logical inuse

	lu=10
	ios=0
	inuse=.true.

	do while(ios.eq.0 .and. inuse .and. lu.le.MX_LU)
	  lu=lu+1
	  inquire(unit=lu,opened=inuse,iostat=ios)
	end do

	if(ios.ne.0) lu=-1
	luavail=lu
end function luavail

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: luflush - a uniform interface of system flush()
!
! !DESCRIPTION:
!
!	Flush() calls available on many systems are often implementation
!	dependent.  This subroutine provides a uniform interface.  It
!	also ignores invalid logical unit value.
!
! !INTERFACE:

    subroutine luflush(unit)
      use m_stdio, only : stdout
#ifdef CPRNAG
      use F90_UNIX_IO,only : flush
#endif
      implicit none
      integer,optional,intent(in) :: unit

! !REVISION HISTORY:
! 	13Mar98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!       08Jul02 - E. Ong <eong@mcs.anl.gov> - added flush support for nag95
!  2001-11-08  Jace A Mogill <mogill@cray.com>  - Flush is not part of
!              the F90 standard.  Default is NO unit flush.
!  2020-08-03 - J. Edwards - flush is now supported by all fortran compilers 
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::luflush'

  integer :: ier
  integer :: lu

	! Which logical unit number?

  lu=stdout
  if(present(unit)) lu=unit
  if(lu < 0) return

  flush(lu)

end subroutine luflush
!-----------------------------------------------------------------------
end module m_ioutil
!.
