!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: m_mpif90 - a Fortran 90 style MPI module interface.
!
! !DESCRIPTION:
!
!   By wrapping \verb'include "mpif.h"' into a module, \verb"m_mpif()"
!   provides an easy way to
!\begin{itemize}
!  \item avoid the problem with {\sl fixed} or {\sl free} formatted
!	Fortran 90 files;
!  \item provide protections with only a limited set of \verb"PUBLIC"
!	variables; and
!  \item be extended to a MPI Fortran 90 binding.
!\end{itemize}
!
! !INTERFACE:

    module m_mpif90
      use m_mpif, only : MP_INTEGER	=> MPI_INTEGER
      use m_mpif, only : MP_REAL	=> MPI_REAL
      use m_mpif, only : MP_DOUBLE_PRECISION	&
					=> MPI_DOUBLE_PRECISION
      use m_mpif, only : MP_LOGICAL	=> MPI_LOGICAL
      use m_mpif, only : MP_CHARACTER	=> MPI_CHARACTER

      use m_mpif, only : MP_REAL4	=> MPI_REAL4
      use m_mpif, only : MP_REAL8	=> MPI_REAL8

      use m_mpif, only : MP_COMM_WORLD	=> MPI_COMM_WORLD
      use m_mpif, only : MP_COMM_NULL	=> MPI_COMM_NULL
      use m_mpif, only : MP_SUM		=> MPI_SUM
      use m_mpif, only : MP_PROD	=> MPI_PROD
      use m_mpif, only : MP_MIN 	=> MPI_MIN
      use m_mpif, only : MP_MAX 	=> MPI_MAX
      use m_mpif, only : MP_MAX_ERROR_STRING	&
					=> MPI_MAX_ERROR_STRING
      use m_mpif, only : MP_STATUS_SIZE => MPI_STATUS_SIZE
      use m_mpif, only : MP_ANY_SOURCE	=> MPI_ANY_SOURCE

      implicit none
      private

      public :: MP_type

      public :: MP_INTEGER
      public :: MP_REAL
      public :: MP_DOUBLE_PRECISION
      public :: MP_LOGICAL
      public :: MP_CHARACTER

      public :: MP_REAL4
      public :: MP_REAL8

      public :: MP_COMM_WORLD
      public :: MP_COMM_NULL

      public :: MP_SUM
      public :: MP_PROD
      public :: MP_MIN
      public :: MP_MAX

      public :: MP_ANY_SOURCE

      public :: MP_MAX_ERROR_STRING

      public :: MP_init
      public :: MP_initialized
      public :: MP_finalize
      public :: MP_abort

      public :: MP_wtime
      public :: MP_wtick

      public :: MP_comm_size
      public :: MP_comm_rank
      public :: MP_comm_dup
      public :: MP_comm_free

      public :: MP_cart_create
      public :: MP_dims_create
      public :: MP_cart_coords
      public :: MP_cart_rank

      public :: MP_error_string

      public :: MP_perr

      public :: MP_STATUS_SIZE
      public :: MP_status

      public :: MP_log2

! !REVISION HISTORY:
! 	09Dec97 - Jing Guo <guo@thunder> - initial prototyping/coding.
!		. started with everything public, without any interface
!		  declaration.
!		. Then limited to only variables current expected to
!		  be used.
!
!EOP
!_______________________________________________________________________

integer,dimension(MP_STATUS_SIZE) :: MP_status

	!----------------------------------------

interface MP_init
  subroutine MPI_init(ier)
    integer :: ier
  end subroutine MPI_init
end interface

interface MP_initialized
  subroutine MPI_initialized(flag,ier)
    logical :: flag
    integer :: ier
  end subroutine MPI_initialized
end interface

interface MP_finalize
  subroutine MPI_finalize(ier)
    integer :: ier
  end subroutine MPI_finalize
end interface

interface MP_error_string
  subroutine MPI_error_string(ierror,cerror,ln,ier)
    integer :: ierror
    character(len=*) :: cerror
    integer :: ln
    integer :: ier
  end subroutine MPI_error_string
end interface

interface MP_type; module procedure	&
  typeI_,	& ! MPI_INTEGER
  typeL_,	& ! MPI_LOGICAL
  typeC_,	& ! MPI_CHARACTER
  typeSP_,	& ! MPI_REAL
  typeDP_,	& ! MPI_DOUBLE_PRECISION
  typeI1_,	& ! MPI_INTEGER
  typeL1_,	& ! MPI_LOGICAL
  typeC1_,	& ! MPI_CHARACTER
  typeSP1_,	& ! MPI_REAL
  typeDP1_,	& ! MPI_DOUBLE_PRECISION
  typeI2_,	& ! MPI_INTEGER
  typeL2_,	& ! MPI_LOGICAL
  typeC2_,	& ! MPI_CHARACTER
  typeSP2_,	& ! MPI_REAL
  typeDP2_	  ! MPI_DOUBLE_PRECISION
end interface

interface MP_perr; module procedure perr_; end interface

interface MP_abort
  subroutine MPI_abort(comm,errorcode,ier)
    integer :: comm
    integer :: errorcode
    integer :: ier
  end subroutine MPI_abort
end interface

	!----------------------------------------
interface MP_wtime
  function MPI_wtime()
    double precision :: MPI_wtime
  end function MPI_wtime
end interface

interface MP_wtick
  function MPI_wtick()
    double precision :: MPI_wtick
  end function MPI_wtick
end interface

	!----------------------------------------
interface MP_comm_size
  subroutine MPI_comm_size(comm,size,ier)
    integer :: comm
    integer :: size
    integer :: ier
  end subroutine MPI_comm_size
end interface

interface MP_comm_rank
  subroutine MPI_comm_rank(comm,rank,ier)
    integer :: comm
    integer :: rank
    integer :: ier
  end subroutine MPI_comm_rank
end interface

interface MP_comm_dup
  subroutine MPI_comm_dup(comm,newcomm,ier)
    integer :: comm
    integer :: newcomm
    integer :: ier
  end subroutine MPI_comm_dup
end interface

interface MP_comm_free
  subroutine MPI_comm_free(comm,ier)
    integer :: comm
    integer :: ier
  end subroutine MPI_comm_free
end interface

	!----------------------------------------
interface MP_cart_create
  subroutine MPI_cart_create(comm_old,ndims,dims,periods,	&
  	reorder,comm_cart,ier)
    integer :: comm_old
    integer :: ndims
    integer,dimension(*) :: dims
    logical,dimension(*) :: periods
    logical :: reorder
    integer :: comm_cart
    integer :: ier
  end subroutine MPI_cart_create
end interface

interface MP_dims_create
  subroutine MPI_dims_create(nnodes,ndims,dims,ier)
    integer :: nnodes
    integer :: ndims
    integer,dimension(*) :: dims
    integer :: ier
  end subroutine MPI_dims_create
end interface

interface MP_cart_coords
  subroutine MPI_cart_coords(comm,rank,maxdims,coords,ier)
    integer :: comm
    integer :: rank
    integer :: maxdims
    integer,dimension(*) :: coords
    integer :: ier
  end subroutine MPI_cart_coords
end interface

interface MP_cart_rank
  subroutine MPI_cart_rank(comm,coords,rank,ier)
    integer :: comm
    integer,dimension(*) :: coords
    integer :: rank
    integer :: ier
  end subroutine MPI_cart_rank
end interface
	!----------------------------------------

  character(len=*),parameter :: myname='m_mpif90'
contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeI_ - return MPI datatype of INTEGER
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeI_(ival)
      implicit none
      integer,intent(in) :: ival
      integer :: typeI_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeI_'

  typeI_=MP_INTEGER

end function typeI_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeL_ - return MPI datatype of LOGICAL
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeL_(lval)
      implicit none
      logical,intent(in) :: lval
      integer :: typeL_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeL_'

  typeL_=MP_LOGICAL

end function typeL_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeC_ - return MPI datatype of CHARACTER
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeC_(cval)
      implicit none
      character(len=*),intent(in) :: cval
      integer :: typeC_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeC_'

  typeC_=MP_CHARACTER

end function typeC_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeSP_ - return MPI datatype of single precision REAL
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeSP_(rval)
      use m_realkinds,only : SP
      implicit none
      real(SP),intent(in) :: rval
      integer :: typeSP_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeSP_'

  typeSP_=MP_REAL

end function typeSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeDP_ - return MPI datatype of double precision REAL
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeDP_(rval)
      use m_realkinds,only : DP
      implicit none
      real(DP),intent(in) :: rval
      integer :: typeDP_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeDP_'

  typeDP_=MP_DOUBLE_PRECISION

end function typeDP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeI1_ - return MPI datatype of INTEGER
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeI1_(ival)
      implicit none
      integer,dimension(:),intent(in) :: ival
      integer :: typeI1_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeI1_'

  typeI1_=MP_INTEGER

end function typeI1_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeL1_ - return MPI datatype of LOGICAL
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeL1_(lval)
      implicit none
      logical,dimension(:),intent(in) :: lval
      integer :: typeL1_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeL1_'

  typeL1_=MP_LOGICAL

end function typeL1_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeC1_ - return MPI datatype of CHARACTER
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeC1_(cval)
      implicit none
      character(len=*),dimension(:),intent(in) :: cval
      integer :: typeC1_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeC1_'

  typeC1_=MP_CHARACTER

end function typeC1_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeSP1_ - return MPI datatype of single precision REAL
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeSP1_(rval)
      use m_realkinds,only : SP
      implicit none
      real(SP),dimension(:),intent(in) :: rval
      integer :: typeSP1_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeSP1_'

  typeSP1_=MP_REAL

end function typeSP1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeDP1_ - return MPI datatype of double precision REAL
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeDP1_(rval)
      use m_realkinds,only : DP
      implicit none
      real(DP),dimension(:),intent(in) :: rval
      integer :: typeDP1_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeDP1_'

  typeDP1_=MP_DOUBLE_PRECISION

end function typeDP1_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeI2_ - return MPI datatype of INTEGER
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeI2_(ival)
      implicit none
      integer,dimension(:,:),intent(in) :: ival
      integer :: typeI2_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeI2_'

  typeI2_=MP_INTEGER

end function typeI2_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeL2_ - return MPI datatype of LOGICAL
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeL2_(lval)
      implicit none
      logical,dimension(:,:),intent(in) :: lval
      integer :: typeL2_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeL2_'

  typeL2_=MP_LOGICAL

end function typeL2_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeC2_ - return MPI datatype of CHARACTER
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeC2_(cval)
      implicit none
      character(len=*),dimension(:,:),intent(in) :: cval
      integer :: typeC2_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeC2_'

  typeC2_=MP_CHARACTER

end function typeC2_
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeSP2_ - return MPI datatype of single precision REAL
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeSP2_(rval)
      use m_realkinds,only : SP
      implicit none
      real(SP),dimension(:,:),intent(in) :: rval
      integer :: typeSP2_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeSP2_'

  typeSP2_=MP_REAL

end function typeSP2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: typeDP2_ - return MPI datatype of double precision REAL
!
! !DESCRIPTION:
!
! !INTERFACE:

    function typeDP2_(rval)
      use m_realkinds,only : DP
      implicit none
      real(DP),dimension(:,:),intent(in) :: rval
      integer :: typeDP2_

! !REVISION HISTORY:
! 	28Sep99	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::typeDP2_'

  typeDP2_=MP_DOUBLE_PRECISION

end function typeDP2_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: perr_ - MPI error information hanlder
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine perr_(proc,MP_proc,ierror)
      use m_stdio, only : stderr
      implicit none
      character(len=*),intent(in) :: proc
      character(len=*),intent(in) :: MP_proc
      integer,intent(in) :: ierror

! !REVISION HISTORY:
! 	21Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::perr_'

  character(len=MP_MAX_ERROR_STRING) :: estr
  integer :: ln,ier

  call MP_error_string(ierror,estr,ln,ier)
  if(ier /= 0 .or. ln<=0) then
    write(stderr,'(4a,i4)') proc,': ',	&
	MP_proc,' error, ierror =',ierror
  else
    write(stderr,'(6a)') proc,': ',	&
	MP_proc,' error, "',estr(1:ln),'"'
  endif

end subroutine perr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: MP_log2 - The smallest integer its power of 2 is >= nPE
!
! !DESCRIPTION:
!
! !INTERFACE:

    function MP_log2(nPE)
      implicit none
      integer,intent(in) :: nPE
      integer :: MP_log2

! !REVISION HISTORY:
! 	01Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::MP_log2'

  integer :: n2

  MP_log2=0
  n2=1
  do while(n2<nPE)
    MP_log2 = MP_log2+1
    n2 = n2+n2
  end do

end function MP_log2

end module m_mpif90
!.
