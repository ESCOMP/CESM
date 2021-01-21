!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_SparseMatrixComms -- sparse matrix communications methods.
!
! !DESCRIPTION:
! The {\tt SparseMatrix} datatype provides sparse matrix storage for
! the parallel matrix-vector multiplication ${\bf y} = {\bf M} {\bf x}$.
! This module provides communications services for the {\tt SparseMatrix}
! type.  These services include scattering matrix elements based on row or
! column decompositions, gathering of matrix elements to the root, and
! broadcasting from the root.
!
! {\bf N.B.:}  These routines will not communicate the vector portion
! of a {\tt SparseMatrix}, if it has been initialized.  A WARNING will
! be issued in most cases.  In general, do communication first,  then
! call {\tt vecinit}.
!
! !INTERFACE:

 module m_SparseMatrixComms

      private   ! except

! !PUBLIC MEMBER FUNCTIONS:
!
      public :: ScatterByColumn
      public :: ScatterByRow
      public :: Gather
      public :: Bcast

    interface ScatterByColumn ; module procedure &
         ScatterByColumnGSMap_
    end interface

    interface ScatterByRow ; module procedure &
         ScatterByRowGSMap_
    end interface

    interface Gather ; module procedure &
	 GM_gather_, &
	 GSM_gather_
    end interface

    interface Bcast ; module procedure Bcast_ ; end interface

! !REVISION HISTORY:
! 13Apr01 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
!           and API specifications.
! 10May01 - J.W. Larson <larson@mcs.anl.gov> - added GM_gather_
!           and cleaned up prologues.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_SparseMatrixComms'

 contains

!-------------------------------------------------------------------------
!     Math + Computer Science Division / Argonne National Laboratory     !
!-------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  ScatterByColumnGSMap_ - Column-based scatter for SparseMatrix.
!
! !DESCRIPTION: This routine scatters the input {\tt SparseMatrix}
! argument {\tt GsMat} (valid only on the root) to a distributed
! {\tt SparseMatrix} variable {\tt LsMat} across all the processes
! present on the communicator associated with the integer handle
! {\tt comm}.  The decomposition defining the scatter is supplied by the
! input {\tt GlobalSegMap} argument {\tt columnGSMap}.  The optional
! output {\tt INTEGER} flag {\tt stat} signifies a successful (failed)
! operation if it is returned with value zero (nonzero).
!
! {\bf N.B.:}  This routine returns an allocated {\tt SparseMatrix}
! variable {\tt LsMat}.  The user must destroy this variable when it
! is no longer needed by invoking {\tt SparseMatrix\_Clean()}.
!
! !INTERFACE:

 subroutine ScatterByColumnGSMap_(columnGSMap, GsMat, LsMat, root, comm, stat)
!
! !USES:
!

   use m_die, only : MP_perr_die,die
   use m_stdio
   use m_mpif90

   use m_List, only: List
   use m_List, only: List_init => init
   use m_List, only: List_clean => clean

   use m_GlobalSegMap, only : GlobalSegMap
   use m_GlobalSegMap, only : GlobalSegMap_clean => clean

   use m_SparseMatrix, only : SparseMatrix
   use m_SparseMatrix, only : SparseMatrix_nRows => nRows
   use m_SparseMatrix, only : SparseMatrix_nCols => nCols
   use m_SparseMatrix, only : SparseMatrix_SortPermute => SortPermute

   use m_SparseMatrixDecomp, only : SparseMatrixDecompByColumn => ByColumn

   use m_AttrVectComms, only : AttrVect_Scatter => scatter

   implicit none

! !INPUT PARAMETERS:
!
   type(GlobalSegMap), intent(in)    :: columnGSMap
   integer,            intent(in)    :: root
   integer,            intent(in)    :: comm

! !INPUT/OUTPUT PARAMETERS:
!
   type(SparseMatrix), intent(inout) :: GsMat

! !OUTPUT PARAMETERS:
!
   type(SparseMatrix), intent(out) :: LsMat
   integer, optional,  intent(out) :: stat

! !REVISION HISTORY:
!
! 13Apr01 - J.W. Larson <larson@mcs.anl.gov> - initial API spec.
! 10May01 - J.W. Larson <larson@mcs.anl.gov> - cleaned up prologue.
! 13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Made status flag stat
!           optional, and ititilaze it to zero if it is present.
! 09Jul03 - E.T. Ong <eong@mcs.anl.gov> - added sorting to distributed
!           matrix elements
!EOP
!-------------------------------------------------------------------------

  character(len=*),parameter :: myname_=myname//'ScatterByColumnGSMap_'
! GlobalSegMap used to create column decomposition of GsMat
  type(GlobalSegMap) :: MatGSMap
! Storage for the number of rows and columns in the SparseMatrix
  integer :: NumRowsColumns(2)
! List storage for sorting keys
  type(List) :: sort_keys
! Process ID
  integer :: myID
! Error flag
  integer :: ierr

       ! Initialize stat if present

  if(present(stat)) stat = 0

       ! Which process am I?

  call MPI_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) then
	call MP_perr_die(myname_,"MPI_COMM_RANK() failed",ierr)
  endif

       ! can't scatter vector parts.
  if((myID.eq.root) .and. GsMat%vecinit) then
      write(stderr,*) myname_,&
      "WARNING: will not scatter vector parts of GsMat"
  endif

       ! Create from columnGSMap the corresponding GlobalSegMap
       ! that will decompose GsMat by column the same way.

  call SparseMatrixDecompByColumn(columnGSMap, GsMat, MatGSMap, root, comm)

       ! Broadcast the resulting GlobalSegMap across the communicator

       ! Scatter the matrix element data GsMat%data accordingly

  call AttrVect_Scatter(GsMat%data, LsMat%data, MatGSMap, root, comm, ierr)

  if(ierr /= 0) then
     if(present(stat)) then
	write(stderr,*) myname_,"::  AttrVect_Scatter(GsMat%data) failed--stat=", &
	     ierr
	stat = ierr
	return
     else
	call die(myname_,"call AttrVect_Scatter(GsMat%data,..",ierr)
     endif
  endif

       ! Now, distribute to all the processes the number of Rows and
       ! columns in GsMat (which are valid on the root only at this point)

  if(myID == root) then
     NumRowsColumns(1) = SparseMatrix_nRows(GsMat)
     NumRowsColumns(2) = SparseMatrix_nCols(GsMat)
  endif

  call MPI_Bcast(NumRowsColumns, 2, MP_INTEGER, root, comm, ierr)

  if(ierr /= 0) then
	call MP_perr_die(myname_,"MPI_Bcast(NumRowsColumns...",ierr)
  endif

       ! Unpack NumRowsColumns

  LsMat%nrows = NumRowsColumns(1)
  LsMat%ncols = NumRowsColumns(2)

       ! Set the value of vecinit
  LsMat%vecinit = .FALSE.

       ! Finally, lets sort the distributed local matrix elements

       ! Sort the matrix entries in sMat by column, then row.
       ! First, create the key list...

  call List_init(sort_keys,'gcol:grow')

       ! Now perform the sort/permute...
  call SparseMatrix_SortPermute(LsMat, sort_keys)

       ! Cleanup

  call List_clean(sort_keys)
  call GlobalSegMap_clean(MatGSMap)

 end subroutine ScatterByColumnGSMap_

!-------------------------------------------------------------------------
!     Math + Computer Science Division / Argonne National Laboratory     !
!-------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  ScatterByRowGSMap_ -Row-based scatter for SparseMatrix.
!
! !DESCRIPTION: This routine scatters the input  {\tt SparseMatrix}
! argument {\tt GsMat} (valid only on the root) to a distributed
! {\tt SparseMatrix} variable {\tt LsMat} across all the processes
! present on the communicator associated with the integer handle
! {\tt comm}.  The decomposition defining the scatter is supplied by the
! input {\tt GlobalSegMap} argument {\tt rowGSMap}.  The output integer
! flag {\tt stat} signifies a successful (failed) operation if it is
! returned with value zero (nonzero).
!
! {\bf N.B.:}  This routine returns an allocated {\tt SparseMatrix}
! variable {\tt LsMat}.  The user must destroy this variable when it
! is no longer needed by invoking {\tt SparseMatrix\_Clean()}.
!
! !INTERFACE:

 subroutine ScatterByRowGSMap_(rowGSMap, GsMat, LsMat, root, comm, stat)
!
! !USES:
!
   use m_die, only : MP_perr_die,die
   use m_stdio
   use m_mpif90

   use m_List, only: List
   use m_List, only: List_init => init
   use m_List, only: List_clean => clean

   use m_GlobalSegMap, only : GlobalSegMap
   use m_GlobalSegMap, only : GlobalSegMap_clean => clean

   use m_SparseMatrix, only : SparseMatrix
   use m_SparseMatrix, only : SparseMatrix_nRows => nRows
   use m_SparseMatrix, only : SparseMatrix_nCols => nCols
   use m_SparseMatrix, only : SparseMatrix_SortPermute => SortPermute

   use m_SparseMatrixDecomp, only : SparseMatrixDecompByRow => ByRow

   use m_AttrVectComms, only : AttrVect_Scatter => scatter

   implicit none

! !INPUT PARAMETERS:
!
   type(GlobalSegMap), intent(in)    :: rowGSMap
   integer,            intent(in)    :: root
   integer,            intent(in)    :: comm

! !INPUT/OUTPUT PARAMETERS:
!
   type(SparseMatrix), intent(inout) :: GsMat

! !OUTPUT PARAMETERS:
!
   type(SparseMatrix), intent(out) :: LsMat
   integer, optional,  intent(out) :: stat

! !REVISION HISTORY:
!
! 13Apr01 - J.W. Larson <larson@mcs.anl.gov> - initial API spec.
! 26Apr01 - R.L. Jacob  <jacob@mcs.anl.gov> - fix use statement
!           from SMDecomp so it points to ByRow
! 13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Made status flag stat
!           optional, and initialize it to zero if it is present.
! 09Jul03 - E.T. Ong <eong@mcs.anl.gov> - Added sorting to distributed
!           matrix elements.
!EOP
!-------------------------------------------------------------------------

  character(len=*),parameter :: myname_=myname//'ScatterByRowGSMap_'
! GlobalSegMap used to create row decomposition of GsMat
  type(GlobalSegMap) :: MatGSMap
! Storage for the number of rows and columns in the SparseMatrix
  integer :: NumRowsColumns(2)
! List storage for sorting keys
  type(List) :: sort_keys
! Process ID
  integer :: myID
! Error flag
  integer :: ierr

       ! Initialize stat to zero (if present)

  if(present(stat)) stat = 0

       ! Which process are we?

  call MPI_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,"MPI_COMM_RANK() failed",ierr)
  endif

       ! can't scatter vector parts.
  if((myID.eq.root) .and. GsMat%vecinit) then
      write(stderr,*) myname_,&
      "WARNING: will not scatter vector parts of GsMat."
  endif

       ! Create from rowGSMap the corresponding GlobalSegMap
       ! that will decompose GsMat by row the same way.

  call SparseMatrixDecompByRow(rowGSMap, GsMat, MatGSMap, root, comm)

       ! Scatter the matrix element data GsMat%data accordingly

  call AttrVect_Scatter(GsMat%data, LsMat%data, MatGSMap, root, comm, ierr)
  if(ierr /= 0) then
     if(present(stat)) then
        write(stderr,*) myname_,"::  AttrVect_Scatter(GsMat%data) failed--stat=", &
             ierr
        stat = ierr
        return
     else
        call die(myname_,"call AttrVect_Scatter(GsMat%data,..",ierr)
     endif
  endif

       ! Now, distribute to all the processes the number of rows and
       ! columns in GsMat (which are valid on the root only at this point)

  if(myID == root) then
     NumRowsColumns(1) = SparseMatrix_nRows(GsMat)
     NumRowsColumns(2) = SparseMatrix_nCols(GsMat)
  endif

  call MPI_Bcast(NumRowsColumns, 2, MP_INTEGER, root, comm, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,"MPI_Bcast(NumRowsColumns...",ierr)
  endif

       ! Unpack NumRowsColumns

  LsMat%nrows = NumRowsColumns(1)
  LsMat%ncols = NumRowsColumns(2)

       ! Set the value of vecinit
  LsMat%vecinit = .FALSE.

       ! Sort the matrix entries in sMat by row, then column.
       ! First, create the key list...

  call List_init(sort_keys,'grow:gcol')

       ! Now perform the sort/permute...
  call SparseMatrix_SortPermute(LsMat, sort_keys)

       ! Cleanup

  call List_clean(sort_keys)
  call GlobalSegMap_clean(MatGSMap)

 end subroutine ScatterByRowGSMap_

!-------------------------------------------------------------------------
!     Math + Computer Science Division / Argonne National Laboratory     !
!-------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  GM_gather_ - Gather a distributed SparseMatrix to the root.
!
! !DESCRIPTION: This routine gathers the input distributed
! {\tt SparseMatrix} argument {\tt LsMat} to the {\tt SparseMatrix}
! variable {\tt GsMat} on the root.  The decomposition defining the gather
! is supplied by the input {\tt GlobalMap} argument {\tt GMap}.  The
! status flag {\tt stat} has value zero (nonzero) if the operation has
! succeeded (failed).
!
! {\bf N.B.:}  This routine returns an allocated {\tt SparseMatrix}
! variable {\tt GsMat}.  The user must destroy this variable when it
! is no longer needed by invoking {\tt SparseMatrix\_Clean()}.
!
! !INTERFACE:

 subroutine GM_gather_(LsMat, GsMat, GMap, root, comm, stat)
!
! !USES:
!
   use m_stdio
   use m_die, only : die

   use m_GlobalMap, only: GlobalMap

   use m_SparseMatrix, only: SparseMatrix
   use m_SparseMatrix, only: SparseMatrix_nRows => nRows
   use m_SparseMatrix, only: SparseMatrix_nCols => nCols

   use m_AttrVectComms, only : AttrVect_gather => gather

   implicit none

! !INPUT PARAMETERS:
!
   type(SparseMatrix), intent(in) :: LsMat
   type(GlobalMap),    intent(in) :: GMap
   integer,            intent(in) :: root
   integer,            intent(in) :: comm

! !OUTPUT PARAMETERS:
!
   type(SparseMatrix), intent(out) :: GsMat
   integer, optional,  intent(out) :: stat

! !REVISION HISTORY:
!
! 13Apr01 - J.W. Larson <larson@mcs.anl.gov> - initial API spec.
! 10May01 - J.W. Larson <larson@mcs.anl.gov> - initial routine and
!           prologue
! 13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Made status flag stat
!           optional, and ititilaze it to zero if it is present.
!EOP
!-------------------------------------------------------------------------

  character(len=*),parameter :: myname_=myname//'GM_gather_'
  integer :: ierr

       ! if stat is present, initialize its value to zero (success)

  if(present(stat))  stat = 0

  if(LsMat%vecinit) then
      write(stderr,*) myname_,&
      "WARNING: will not gather vector parts of LsMat."
  endif

  call AttrVect_gather(LsMat%data, GsMat%data, GMap, root, comm, ierr)
  if(ierr /= 0) then
     if(present(stat)) then
        write(stderr,*) myname_,"::  AttrVect_Gather(LsMat%data...) failed--stat=", &
             ierr
        stat = ierr
        return
     else
        call die(myname_,"call AttrVect_Scatter(LsMat%data...) failed",ierr)
     endif
  endif

       ! For now, the GsMat inherits the number of rows and columns from
       ! the corresponding values of LsMat on the root (this should be
       ! checked in future versions).

  GsMat%nrows = SparseMatrix_nRows(LsMat)
  GsMat%ncols = SparseMatrix_nCols(LsMat)

  GsMat%vecinit = .FALSE.

 end subroutine GM_gather_

!-------------------------------------------------------------------------
!     Math + Computer Science Division / Argonne National Laboratory     !
!-------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  GSM_gather_ - Gather a distributed SparseMatrix to the root.
!
! !DESCRIPTION: This routine gathers the input distributed
! {\tt SparseMatrix} argument {\tt LsMat} to the {\tt SparseMatrix}
! variable {\tt GsMat} on the root.  The decomposition defining the gather
! is supplied by the input {\tt GlobalSegMap} argument {\tt GSMap}.  The
! status flag {\tt stat} has value zero (nonzero) if the operation has
! succeeded (failed).
!
! {\bf N.B.:}  This routine returns an allocated {\tt SparseMatrix}
! variable {\tt GsMat}.  The user must destroy this variable when it
! is no longer needed by invoking {\tt SparseMatrix\_Clean()}.
!
! !INTERFACE:

 subroutine GSM_gather_(LsMat, GsMat, GSMap, root, comm, stat)
!
! !USES:
!
   use m_stdio
   use m_die, only : die

   use m_GlobalSegMap, only: GlobalSegMap

   use m_SparseMatrix, only: SparseMatrix
   use m_SparseMatrix, only: SparseMatrix_nRows => nRows
   use m_SparseMatrix, only: SparseMatrix_nCols => nCols

   use m_AttrVectComms, only : AttrVect_gather => gather

   implicit none

! !INPUT PARAMETERS:
!
   type(SparseMatrix), intent(in) :: LsMat
   type(GlobalSegMap), intent(in) :: GSMap
   integer,            intent(in) :: root
   integer,            intent(in) :: comm

! !OUTPUT PARAMETERS:
!
   type(SparseMatrix), intent(out) :: GsMat
   integer, optional,  intent(out) :: stat

! !REVISION HISTORY:
!
! 13Apr01 - J.W. Larson <larson@mcs.anl.gov> - initial API spec.
! 13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Made status flag stat
!           optional, and ititilaze it to zero if it is present.
!EOP
!-------------------------------------------------------------------------

  character(len=*),parameter :: myname_=myname//'GSM_gather_'
  integer :: ierr

       ! if stat is present, initialize its value to zero (success)

  if(present(stat))  stat = 0

  if(LsMat%vecinit) then
      write(stderr,*) myname_,&
      "WARNING: will not gather vector parts of LsMat."
  endif

       ! Gather the AttrVect component of LsMat to GsMat...

  call AttrVect_gather(LsMat%data, GsMat%data, GSMap, root, comm, ierr)
  if(ierr /= 0) then
     if(present(stat)) then
        write(stderr,*) myname_,"::  AttrVect_Gather(LsMat%data...) failed--stat=", &
             ierr
        stat = ierr
        return
     else
        call die(myname_,"call AttrVect_Gather(LsMat%data...)",ierr)
     endif
  endif

       ! For now, the GsMat inherits the number of rows and columns from
       ! the corresponding values of LsMat on the root (this should be
       ! checked in future versions).

  GsMat%nrows = SparseMatrix_nRows(LsMat)
  GsMat%ncols = SparseMatrix_nCols(LsMat)

  GsMat%vecinit = .FALSE.

 end subroutine GSM_gather_

!-------------------------------------------------------------------------
!     Math + Computer Science Division / Argonne National Laboratory     !
!-------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  Bcast_ - Broadcast a SparseMatrix.
!
! !DESCRIPTION: This routine broadcasts the {\tt SparseMatrix} argument
! {\tt sMat} from the root to all processes on the communicator associated
! with the communicator handle {\tt comm}.  The status flag {\tt stat}
! has value zero if the operation has succeeded.
!
! {\bf N.B.:}  This routine returns an allocated {\tt SparseMatrix}
! variable {\tt sMat}.  The user must destroy this variable when it
! is no longer needed by invoking {\tt SparseMatrix\_Clean()}.
!
! {\bf N.B.:}  This routine will exit with an error if the vector portion
! of {\tt sMat} has been initialized prior to broadcast.
!
! !INTERFACE:

 subroutine Bcast_(sMat, root, comm, stat)

!
! !USES:
!

   use m_die, only : MP_perr_die,die
   use m_stdio
   use m_mpif90

   use m_GlobalSegMap, only: GlobalSegMap

   use m_AttrVectComms, only : AttrVect_bcast => bcast

   use m_SparseMatrix, only: SparseMatrix
   use m_SparseMatrix, only: SparseMatrix_nRows => nRows
   use m_SparseMatrix, only: SparseMatrix_nCols => nCols

   implicit none

! !INPUT PARAMETERS:
!
   integer,            intent(in) :: root
   integer,            intent(in) :: comm

! !INPUT/OUTPUT PARAMETERS:
!
   type(SparseMatrix), intent(inout) :: sMat

! !OUTPUT PARAMETERS:
!
   integer, optional,  intent(out) :: stat

! !REVISION HISTORY:
!
! 13Apr01 - J.W. Larson <larson@mcs.anl.gov> - initial API spec/code
! 13Jun01 - J.W. Larson <larson@mcs.anl.gov> - Made status flag stat
!           optional, and ititilaze it to zero if it is present.
! 17Jul02 - J.W. Larson <larson@mcs.anl.gov> - Bug fix--local
!           process ID myID was uninitialized.
!EOP
!-------------------------------------------------------------------------

  character(len=*),parameter :: myname_=myname//'Bcast_'

! Storage for the number of rows and columns in the SparseMatrix
  integer :: NumRowsColumns(2)
! Process ID number
  integer :: myID
! Error flag
  integer :: ierr

       ! Initialize stat if present

  if(present(stat)) stat = 0

       ! Determine local process ID myID:

  call MPI_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,"MPI_COMM_RANK() failed",ierr)
  endif

  if((myID.eq.root) .and. sMat%vecinit) then
      write(stderr,*) myname_,&
      "Cannot broadcast SparseMatrix with initialized vector parts."
      call die(myname_,"Gather SparseMatrix with vecinit TRUE.")
  endif

       ! Broadcast sMat%data from the root

  call AttrVect_bcast(sMat%data, root, comm, ierr)
  if(ierr /= 0) then
     if(present(stat)) then
        write(stderr,*) myname_,"::  AttrVect_bcast(sMat%data...failed--stat=", &
             ierr
        stat = ierr
        return
     else
        call die(myname_,"call AttrVect_bcast(sMat%data...) failed",ierr)
     endif
  endif

  if(myID == root) then
     NumRowsColumns(1) = SparseMatrix_nRows(sMat)
     NumRowsColumns(2) = SparseMatrix_nCols(sMat)
  endif

  call MPI_Bcast(NumRowsColumns, 2, MP_INTEGER, root, comm, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,"MPI_Bcast(NumRowsColumns...",ierr)
  endif

       ! Unpack NumRowsColumns on broadcast destination processes

  if(myID /= root) then
     sMat%nrows = NumRowsColumns(1)
     sMat%ncols = NumRowsColumns(2)
  endif

  sMat%vecinit = .FALSE.

 end subroutine Bcast_

 end module m_SparseMatrixComms
