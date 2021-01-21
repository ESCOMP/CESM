!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: m_mpout - a multiple but mergable parallel output module
!
! !DESCRIPTION:
!
! !INTERFACE:

    module m_mpout
      use m_stdio, only : stdout,LEN_FILENAME
      implicit none
      private	! except

      public :: mpout	! The file handle as a Fortran logical unit

      public :: mpout_open	! open the multiple output streams
      public :: mpout_close	! close the multiple output streams
      public :: mpout_sync	! sync. the multiple output streams
      public :: mpout_flush	! flush the multople output streams
      public :: mpout_ison	! verify if mpout is proper defined
      public :: mpout_log	! write a message to mpout

      interface mpout_open;  module procedure open_;  end interface
      interface mpout_close; module procedure close_; end interface
      interface mpout_sync;  module procedure sync_;  end interface
      interface mpout_flush; module procedure flush_; end interface
      interface mpout_ison;  module procedure ison_;  end interface
      interface mpout_log
          module procedure log1_
          module procedure log2_
      end interface

! !REVISION HISTORY:
! 	25Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!	28Sep99 - Jing Guo <guo@thunder>
!		- Added additional calls to support the "Violet" system
!		  development.
!
! !DESIGN ISSUES:
! \begin{itemize}
!
! \item	It might be considered useful to implement this module to be
!	applicable to a given {\sl communicator}.   The argument
!	taken now is to only have one multiple output stream handle
!	per excution.  This is consistent with \verb"stdout" in the
!	traditional sense. (Jing Guo, 25Feb98)
!
! \item \verb"mpout_log()" is implemented in a way producing output
!	only if \verb"mpout_ison()" (being \verb".true.").  The reason
!	of not implementing a default output such as \verb"stdout", is
!	hoping to provent too many unexpected output when the system is
!	switched to a multiple PE system.  The design principle for
!	this module is that \verb"mpout" is basically {\sl not} the same
!	module as \verb"stdout". (Jing Guo, 28Sep99)
!
! \end{itemize}
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname='MCT(MPEU)::m_mpout'

  character(len=*),parameter :: def_pfix='mpout'

  integer,save :: isec=-1
  integer,save :: mpout=stdout
  logical,save :: mpout_set=.false.
  character(len=LEN_FILENAME-4),save :: upfix=def_pfix
  integer,parameter :: mpout_MASK=3	! every four PEs

contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: open_ - open a multiple files with the same name prefix
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine open_(mask,pfix)
      use m_stdio, only : stderr,stdout
      use m_ioutil, only : luavail,opntext
      use m_dropdead, only : die
      use m_mpif90, only : MP_comm_WORLD
      use m_mpif90, only : MP_comm_rank
      use m_mpif90, only : MP_perr
      implicit none
      integer,optional,intent(in) :: mask
      character(len=*),optional,intent(in) :: pfix

! !EXAMPLES:
!
!   Examples of using mpout_MASK or mask:
!
!	If the mask has all "1" in every bit, there will be no output
!   on every PE, except the PE of rank 0.
!
!	If the mask is 3 or "11"b, any PE of rank with any "dirty" bit
!   in its rank value will not have output.
!
! !REVISION HISTORY:
! 	25Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::open_'
  integer :: lu
  character(len=4) :: sfix
  integer :: irank
  integer :: ier
  integer :: umask

	! Set the filename prefix

  upfix=def_pfix
  if(present(pfix)) upfix=pfix

	! Set the mask of the PEs with mpout

  umask=mpout_MASK
  if(present(mask)) umask=mask

	! If a check is not in place, sent the outputs to stdout

  mpout=stdout
  mpout_set=.false.

  call MP_comm_rank(MP_comm_world,irank,ier)
  if(ier /= 0) then
    call MP_perr(myname_,'MP_comm_rank()',ier)
    call die(myname_)
  endif

  if(iand(irank,umask) == 0) then

    lu=luavail()
    if(lu > 0) mpout=lu

    write(sfix,'(a,z3.3)') '.',irank
    call opntext(mpout,trim(upfix)//sfix,'unknown',ier)
    if(ier /= 0) then
      write(stderr,'(4a,i4)') myname_,	&
	': opntext("',trim(upfix)//sfix,'") error, ier =',ier
      call die(myname_)
    endif

    mpout_set=.true.

    isec=0
    write(mpout,'(a,z8.8,2a)') '.BEGIN.  ',isec,' ',trim(upfix)
  endif

end subroutine open_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: close_ - close the unit opened by open_
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine close_()
      use m_stdio,  only : stderr
      use m_ioutil, only : clstext, luflush
      use m_dropdead, only : die
      implicit none

! !REVISION HISTORY:
! 	25Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::close_'
  integer :: ier

  if(mpout_set) then
    call luflush(mpout)

    isec=isec+1
    write(mpout,'(a,z8.8,2a)') '.END.    ',isec,' ',trim(upfix)
    endfile(mpout)

    call clstext(mpout,ier)
    if(ier /= 0) then
      write(stderr,'(2a,i3.3,a,i4)') myname_,	&
	': clstext("',mpout,'") error, ier =',ier
      call die(myname_)
    endif
    mpout=stdout
    mpout_set=.false.
  endif

  isec=-1

end subroutine close_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: sync_ - write a mark for posible later file merging
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine sync_(tag)
      use m_stdio,    only : stderr
      use m_dropdead, only : die
      implicit none
      character(len=*),intent(in) :: tag

! !REVISION HISTORY:
! 	25Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!
! !DESIGN ISSUES:
! \begin{itemize}
!
! \item	Should the variable \verb"tag" be implemented as an optional
!	argument?  Because the current implementation does not require
!	actual synchronization between all threads of the multiple
!	output streams, forcing the user to supply a unique \verb"tag"
!	would make the final multi-stream merging verifiable.  However,
!	since the \verb"tag"s have not been forced to be unique, the
!	synchronization operations are still symbolic.
!
! \{itemize}
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::sync_'

  if(mpout_set) then
    isec=isec+1
    write(mpout,'(a,z8.8,2a)') '.SYNC.   ',isec,' ',trim(tag)
  endif

end subroutine sync_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: flush_ - flush the multiple output streams
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine flush_()
      use m_stdio, only : stderr
      use m_ioutil, only : luflush
      use m_dropdead, only : die
      implicit none

! !REVISION HISTORY:
! 	27Feb98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::flush_'

  if(mpout_set) call luflush(mpout)

end subroutine flush_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ison_ - decide if the current PE has a defined mpout
!
! !DESCRIPTION:
!
!   It needs to be checked to avoid undesired output.
!
! !INTERFACE:

    function ison_()
      implicit none
      logical :: ison_

! !REVISION HISTORY:
! 	14Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ison_'

  ison_=mpout_set

end function ison_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       ANL/MCS  Mathematics and Computer Science Division             !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: log1_ - write a message to mpout
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine log1_(message)
      implicit none
      character(len=*),intent(in) :: message

! !REVISION HISTORY:
! 	07Jan02	- R. Jacob (jacob@mcs.anl.gov)
!		- based on log2_.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::log1_'

  if(mpout_set) write(mpout,'(3a)') message

end subroutine log1_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: log2_ - write a message to mpout with a where
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine log2_(where,message)
      implicit none
      character(len=*),intent(in) :: where
      character(len=*),intent(in) :: message

! !REVISION HISTORY:
! 	14Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
! 	07Jan02	- R. Jacob (jacob@mcs.anl.gov)
!               - change name to log2_
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::log2_'

  if(mpout_set) write(mpout,'(3a)') where,': ',message

end subroutine log2_
end module m_mpout
!.
