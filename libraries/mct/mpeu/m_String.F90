!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_String - The String Datatype
!
! !DESCRIPTION:
! The {\tt String} datatype is an encapsulated pointer to a one-dimensional
! array of single characters.  This allows one to define variable-length
! strings, and arrays of variable-length strings.
!
! !INTERFACE:

 module m_String

! !USES:
! No external modules are used in the declaration section of this module.

      implicit none

      private	! except

! !PUBLIC TYPES:

      public :: String		! The class data structure

    Type String
#ifdef SEQUENCE
      sequence
#endif
      character(len=1),dimension(:),pointer :: c
    End Type String

! !PUBLIC MEMBER FUNCTIONS:

      public :: toChar
      public :: char		! convert to a CHARACTER(*)

      public :: String_init
      public :: init		! set a CHARACTER(*) type to a String

      public :: String_clean
      public :: clean		! Deallocate memory occupied by  a String

      public :: String_len
      public :: len		! length of a String

      public :: String_bcast
      public :: bcast		! Broadcast a String

      public :: String_mci      ! Track memory used to store a String
      public :: String_mco

      public :: ptr_chars       ! Assign a pointer to a String's
                                ! character buffer

  interface char;  module procedure	&
	str2ch0_,	&
	ch12ch0_
  end interface

  interface toChar;  module procedure	&
	str2ch0_,	&
	ch12ch0_
  end interface

  interface String_init;  module procedure	&
	initc_,		&
	initc1_,	&
	inits_
  end interface

  interface init;  module procedure	&
	initc_,		&
	initc1_,	&
	inits_
  end interface

  interface String_clean; module procedure clean_; end interface
  interface clean; module procedure clean_; end interface
  interface String_len; module procedure len_; end interface
  interface len; module procedure len_; end interface
  interface String_bcast; module procedure bcast_; end interface
  interface bcast; module procedure bcast_; end interface

  interface String_mci; module procedure	&
    mci0_,	&
    mci1_,	&
    mci2_,	&
    mci3_
  end interface

  interface String_mco; module procedure	&
    mco0_,	&
    mco1_,	&
    mco2_,	&
    mco3_
  end interface

  interface ptr_chars; module procedure	&
    ptr_chars_
  end interface

! !REVISION HISTORY:
! 	22Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT(MPEU)::m_String'

contains
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: str2ch0_ - Convert a String to a CHARACTER
!
! !DESCRIPTION:
! This function returns the contents of the character buffer of the
! input {\tt String} argument {\tt str} as a {\tt CHARCTER} suitable
! for printing.
!
! !INTERFACE:

 function str2ch0_(str)

! !USES:
!
! No external modules are used by this function.

     implicit none

! !INPUT PARAMETERS:
!
     type(String),              intent(in) :: str

! !OUTPUT PARAMETERS:
!
     character(len=size(str%c,1))            :: str2ch0_

! !REVISION HISTORY:
! 	23Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::str2ch0_'
  integer :: i

  do i=1,size(str%c)
    str2ch0_(i:i)=str%c(i)
  end do

 end function str2ch0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ch12ch0_ - Convert a CHARACTER(:) to a CHARACTER(*)
!
! !DESCRIPTION:
! This function takes an input one-dimensional array of single characters
! and returns a single character string.
!
! !INTERFACE:

 function ch12ch0_(ch1)

! !USES:
!
! No external modules are used by this function.

      implicit none

! !INPUT PARAMETERS:
!
      character(len=1), dimension(:), intent(in) :: ch1

! !OUTPUT PARAMETERS:
!
      character(len=size(ch1,1))                   :: ch12ch0_

! !REVISION HISTORY:
! 	22Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ch12ch0_'
  integer :: i

  do i=1,size(ch1)
    ch12ch0_(i:i)=ch1(i)
  end do

 end function ch12ch0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initc_ - Create a String using a CHARACTER
!
! !DESCRIPTION:
! This routine takes an input scalar {\tt CHARACTER} argument {\tt chr},
! and uses it to create the output {\tt String} argument {\tt str}.
!
! !INTERFACE:

 subroutine initc_(str, chr)

! !USES:
!
      use m_die, only : die,perr
      use m_mall,only : mall_mci,mall_ison

      implicit none

! !INPUT PARAMETERS:
!
      character(len=*), intent(in)  :: chr

! !OUTPUT PARAMETERS:
!
      type(String),     intent(out) :: str

! !REVISION HISTORY:
! 	23Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initc_'
  integer :: ln,ier,i

  ln=len(chr)
  allocate(str%c(ln),stat=ier)
  if(ier /= 0) then
    call perr(myname_,'allocate()',ier)
    call die(myname_)
  endif

	if(mall_ison()) call mall_mci(str%c,myname)

  do i=1,ln
    str%c(i)=chr(i:i)
  end do

 end subroutine initc_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initc1_ - Create a String using a CHARACTER array
!
! !DESCRIPTION:
! This routine takes an input {\tt CHARACTER(:)} argument {\tt chr},
! and uses it to create the output {\tt String} argument {\tt str}.
!
! !INTERFACE:

 subroutine initc1_(str, chr)

! !USES:
!
      use m_die, only : die,perr
      use m_mall,only : mall_mci,mall_ison

      implicit none

! !INPUT PARAMETERS:
!
      character,     dimension(:), intent(in)  :: chr

! !OUTPUT PARAMETERS:
!
      type(String),                intent(out) :: str

! !REVISION HISTORY:
!  2Aug02 - J. Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initc1_'
  integer :: ln,ier,i

  ln=size(chr)
  allocate(str%c(ln),stat=ier)
  if(ier /= 0) then
    call perr(myname_,'allocate()',ier)
    call die(myname_)
  endif

	if(mall_ison()) call mall_mci(str%c,myname)

  do i=1,ln
    str%c(i)=chr(i)
  end do

 end subroutine initc1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: inits_ - Initialization of a String from another String
!
! !DESCRIPTION:
! This routine takes an input {\tt String} argument {\tt iStr} and
! creates an output {\tt String} argument {\tt oStr}.  In other words,
! it copies {\tt iStr} to {\tt oStr}.
!
! !INTERFACE:

 subroutine inits_(oStr, iStr)

! !USES:
!
      use m_die, only : die
      use m_mall,only : mall_mci,mall_ison

      implicit none

! !INPUT PARAMETERS:
!
      type(String),  intent(in)  :: iStr

! !OUTPUT PARAMETERS:
!
      type(String),  intent(out) :: oStr

! !REVISION HISTORY:
! 	07Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::inits_'
  integer :: ln,ier,i

  ln=size(iStr%c)

	allocate(oStr%c(ln),stat=ier)
		if(ier /= 0) call die(myname_,'allocate()',ier)

	if(mall_ison()) call mall_mci(oStr%c,myname)

  do i=1,ln
    oStr%c(i)=iStr%c(i)
  end do

 end subroutine inits_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: clean_ - Deallocate Memory Occupied by a String
!
! !DESCRIPTION:
! This routine deallocates memory associated with the input/output
! {\tt String} argument {\tt str}.  This amounts to deallocating
! {\tt str\%c}.
!
! !INTERFACE:

 subroutine clean_(str)

! !USES:
!
      use m_die, only : die,perr
      use m_mall,only : mall_mco,mall_ison

      implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      type(String), intent(inout) :: str

! !REVISION HISTORY:
! 	23Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::clean_'
  integer :: ier

	if(mall_ison()) call mall_mco(str%c,myname)

  deallocate(str%c,stat=ier)
  if(ier /= 0) then
    call perr(myname_,'deallocate()',ier)
    call die(myname_)
  endif

 end subroutine clean_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: bcast_ - MPI Broadcast of a rank-0 String
!
! !DESCRIPTION:
! This routine performs an MPI broadcast of the input/output {\tt String}
! argument {\tt Str} on a communicator associated with the Fortran integer
! handle {\tt comm}.  The broadcast originates from the process with rank
! given by {\tt root} on {\tt comm}.  The {\tt String} argument {\tt Str}
! is on entry valid only on the {\tt root} process, and is valid on exit
! on all processes on the communicator {\tt comm}.  The success (failure)
! is signified by a zero (non-zero) value of the optional {\tt INTEGER}
! output argument {\tt stat}.
!
! !INTERFACE:

 subroutine bcast_(Str, root, comm, stat)

! !USES:
!
      use m_mpif90
      use m_die, only : perr,die
      use m_mall,only : mall_mci,mall_ison

      implicit none

! !INPUT PARAMETERS:
!
      integer,           intent(in)    :: root
      integer,           intent(in)    :: comm

! !INPUT/OUTPUT PARAMETERS:
!
      type(String),      intent(inout) :: Str ! (IN) on the root,
                                              ! (OUT) elsewhere

! !OUTPUT PARAMETERS:
!
      integer, optional, intent(out)   :: stat

! !REVISION HISTORY:
! 	27Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::bcast_'
  integer :: ln,ier,myID

  if(present(stat)) stat=0

  call MP_comm_rank(comm,myID,ier)
  if(ier /= 0) then
    call MP_perr(myname_,'MP_comm_rank()',ier)
    if(.not.present(stat)) call die(myname_)
    stat=ier
    return
  endif

  if(myID==root) then
     ln=size(Str%c)
     if(ln<=0) call die(myname_,'size(Str%c) <= 0')
  endif

  call MPI_bcast(ln,1,MP_INTEGER,root,comm,ier)
  if(ier/=0) then
    call MP_perr(myname_,'MPI_bcast(ln)',ier)
    if(.not.present(stat)) call die(myname_)
    stat=ier
    return
  endif

  if(myID /= root) then

    allocate(Str%c(ln),stat=ier)
    if(ier /= 0) then
      call perr(myname_,'allocate()',ier)
      if(.not.present(stat)) call die(myname_)
      stat=ier
      return
    endif

	if(mall_ison()) call mall_mci(Str%c,myname)
  endif

  call MPI_bcast(Str%c(1),ln,MP_CHARACTER,root,comm,ier)
  if(ier/=0) then
    call MP_perr(myname_,'MPI_bcast(Str%c)',ier)
    if(.not.present(stat)) call die(myname_)
    stat=ier
    return
  endif

 end subroutine bcast_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: mci0_ - checking in a String scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

 subroutine mci0_(marg,thread)

! !USES:
!
      use m_mall, only : mall_ci

      implicit none

! !INPUT PARAMETERS:
!
      type(String),     intent(in) :: marg
      character(len=*), intent(in) :: thread

! !REVISION HISTORY:
! 	07Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::mci0_'

  call mall_ci(1,thread)

 end subroutine mci0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: mco0_ - checking out a String scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

 subroutine mco0_(marg,thread)

! !USES:
!
      use m_mall, only : mall_co

      implicit none

      type(String),    intent(in) :: marg
      character(len=*),intent(in) :: thread

! !REVISION HISTORY:
! 	07Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::mco0_'

  call mall_co(1,thread)

 end subroutine mco0_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: mci1_ - checking in a String scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

 subroutine mci1_(marg,thread)

! !USES:
!
      use m_mall, only : mall_ci

      implicit none

! !INPUT PARAMETERS:
!
      type(String),     dimension(:), intent(in) :: marg
      character(len=*),               intent(in) :: thread

! !REVISION HISTORY:
! 	07Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::mci1_'

  call mall_ci(size(marg),thread)

 end subroutine mci1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: mco1_ - checking out a String scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

 subroutine mco1_(marg,thread)

! !USES:
!
      use m_mall, only : mall_co

      implicit none

! !INPUT PARAMETERS:
!
      type(String),     dimension(:), intent(in) :: marg
      character(len=*),               intent(in) :: thread

! !REVISION HISTORY:
! 	07Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::mco1_'

  call mall_co(size(marg),thread)

 end subroutine mco1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: mci2_ - checking in a String scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

 subroutine mci2_(marg, thread)

! !USES:
!
      use m_mall, only : mall_ci

      implicit none

! !INPUT PARAMETERS:
!
      type(String),     dimension(:,:), intent(in) :: marg
      character(len=*),                 intent(in) :: thread

! !REVISION HISTORY:
! 	07Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::mci2_'

  call mall_ci(size(marg),thread)

 end subroutine mci2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: mco2_ - checking out a String scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

 subroutine mco2_(marg,thread)

! !USES:
!
      use m_mall, only : mall_co

      implicit none

! !INPUT PARAMETERS:
!
      type(String),     dimension(:,:), intent(in) :: marg
      character(len=*),                 intent(in) :: thread

! !REVISION HISTORY:
! 	07Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::mco2_'

  call mall_co(size(marg),thread)

 end subroutine mco2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: mci3_ - checking in a String scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

 subroutine mci3_(marg,thread)

! !USES:
!
      use m_mall, only : mall_ci

      implicit none

! !INPUT PARAMETERS:
!
      type(String),     dimension(:,:,:), intent(in) :: marg
      character(len=*),                   intent(in) :: thread

! !REVISION HISTORY:
! 	07Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::mci3_'

  call mall_ci(size(marg),thread)

 end subroutine mci3_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: mco3_ - checking out a String scalar
!
! !DESCRIPTION:
!
! !INTERFACE:

 subroutine mco3_(marg,thread)

! !USES:
!
      use m_mall, only : mall_co

      implicit none

! !INPUT PARAMETERS:
!
      type(String),     dimension(:,:,:), intent(in) :: marg
      character(len=*),                   intent(in) :: thread

! !REVISION HISTORY:
! 	07Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::mco3_'

  call mall_co(size(marg),thread)

  end subroutine mco3_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: len_ = len of a String
!
! !DESCRIPTION:
!
! !INTERFACE:

 integer function len_(str)

! !USES:
!
! No external modules are used by this function.

      implicit none

! !INPUT PARAMETERS:
!
      type(String),intent(in) :: str

! !REVISION HISTORY:
! 	10Apr00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::len_'

  len_=size(str%c)

 end function len_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ptr_chars_ - direct
!
! !DESCRIPTION:
! This pointer-valued function provides a direct interface to the
! character buffer in the input {\tt String} argument {\tt str}.  That
! is, {\tt ptr\_chars\_ => str\%c}.
!
! !INTERFACE:

 function ptr_chars_(str)

! !USES:
!
! No external modules are used by this function.

      implicit none

! !INPUT PARAMETERS:
!
      type(String),                   intent(in) :: str

! !OUTPUT PARAMETERS:
!
      character(len=1), dimension(:), pointer    :: ptr_chars_

! !REVISION HISTORY:
! 	10Apr00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ptr_chars_'

  ptr_chars_ => str%c

 end function ptr_chars_

 end module m_String
