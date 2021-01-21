!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!-----------------------------------------------------------------------
!BOP
!
! !MODULE: m_mpif - a portable interface to the MPI "mpif.h" COMMONs.
!
! !DESCRIPTION:
!
!   The purpose of \verb"m_mpif" module is to provide a portable
!   interface of \verb"mpif.h" with different MPI implementation.
!   By combining module \verb"m_mpif" and \verb"m_mpif90", it may be
!   possible to build a Fortran 90 MPI binding module graduately.
!
!   Although it is possible to use \verb'include "mpif.h"' directly
!   in individual modules, it has several problems:
!   \begin{itemize}
!   \item It may conflict with either the source code of a {\sl fixed}
!	format or the code of a {\sl free} format;
!   \item It does not provide the protection and the safety of using
!	these variables as what a \verb"MODULE" would provide.
!   \end{itemize}
!
!   More information may be found in the module \verb"m_mpif90".
!
! !INTERFACE:

	module m_mpif
	  implicit none
	  private	! except

	  public :: MPI_INTEGER
	  public :: MPI_REAL
	  public :: MPI_DOUBLE_PRECISION
	  public :: MPI_LOGICAL
	  public :: MPI_CHARACTER

	  public :: MPI_REAL4
	  public :: MPI_REAL8

	  public :: MPI_COMM_WORLD
	  public :: MPI_COMM_NULL

	  public :: MPI_SUM
	  public :: MPI_PROD
	  public :: MPI_MIN
  	  public :: MPI_MAX

	  public :: MPI_MAX_ERROR_STRING
	  public :: MPI_STATUS_SIZE
	  public :: MPI_ANY_SOURCE

#ifdef MPICH_
	  public :: MPIPRIV	! the common block name
#endif

	  include "mpif.h"

! !REVISION HISTORY:
! 	01Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP
!_______________________________________________________________________
	character(len=*),parameter :: myname='MCT(MPEU)::m_mpif'

	end module m_mpif
!.
