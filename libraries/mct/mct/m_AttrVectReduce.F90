!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_AttrVectReduce - Local/Distributed AttrVect Reduction Ops.
!
! !DESCRIPTION:  This module provides routines to perform reductions on
! the {\tt AttrVect} datatype.  These reductions can either be the types
! of operations supported by MPI (currently, summation, minimum and
! maximum are available) that are applied either to all the attributes
! (both integer and real), or specific reductions applicable only to the
! real attributes of an {\tt AttrVect}.  This module provides services
! for both local (i.e., one address space) and global (distributed)
! reductions.  The type of reduction is defined through use of one of
! the public data members of this module:
!\begin{table}[htbp]
!\begin{center}
!\begin{tabular}{|c|c|}
!\hline
!{\bf Value} & {\bf Action} \\
!\hline
!{\tt AttrVectSUM} & Sum \\
!\hline
!{\tt AttrVectMIN} & Minimum \\
!\hline
!{\tt AttrVectMAX} & Maximum \\
!\hline
!\end{tabular}
!\end{center}
!\end{table}
!
! !INTERFACE:

 module m_AttrVectReduce
!
! !USES:
!
!     No modules are used in the declaration section of this module.

      implicit none

      private	! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: LocalReduce            ! Local reduction of all attributes
      public :: LocalReduceRAttr       ! Local reduction of REAL attributes
      public :: AllReduce              ! AllReduce for distributed AttrVect
      public :: GlobalReduce           ! Local Reduce followed by AllReduce
      public :: LocalWeightedSumRAttr  ! Local weighted sum of
                                       ! REAL attributes
      public :: GlobalWeightedSumRAttr ! Global weighted sum of REAL
                                       ! attributes for a distrubuted
                                       ! AttrVect

    interface LocalReduce ; module procedure LocalReduce_ ; end interface
    interface LocalReduceRAttr
       module procedure LocalReduceRAttr_
    end interface
    interface AllReduce
       module procedure AllReduce_
    end interface
    interface GlobalReduce
       module procedure GlobalReduce_
    end interface
    interface LocalWeightedSumRAttr; module procedure &
       LocalWeightedSumRAttrSP_, &
       LocalWeightedSumRAttrDP_
    end interface
    interface GlobalWeightedSumRAttr; module procedure &
       GlobalWeightedSumRAttrSP_, &
       GlobalWeightedSumRAttrDP_
    end interface

! !PUBLIC DATA MEMBERS:

    public :: AttrVectSUM
    public :: AttrVectMIN
    public :: AttrVectMAX

    integer, parameter :: AttrVectSUM = 1
    integer, parameter :: AttrVectMIN = 2
    integer, parameter :: AttrVectMAX = 3

! !REVISION HISTORY:
!
!  7May02 - J.W. Larson <larson@mcs.anl.gov> - Created module
!           using routines originally prototyped in m_AttrVect.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_AttrVectReduce'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: LocalReduce_ - Local Reduction of INTEGER and REAL Attributes
!
! !DESCRIPTION:
!
! The subroutine {\tt LocalReduce\_()} takes the input {\tt AttrVect}
! argument {\tt inAV}, and reduces each of its integer and real
! attributes, returning them in the output {\tt AttrVect} argument
! {\tt outAV}  (which is created by this routine).  The type of
! reduction is defined by the input {\tt INTEGER} argument {\tt action}.
!  Allowed values for action are defined as public data members to this
!  module, and are summarized below:
!
!\begin{table}[htbp]
!\begin{center}
!\begin{tabular}{|c|c|}
!\hline
!{\bf Value} & {\bf Action} \\
!\hline
!{\tt AttrVectSUM} & Sum \\
!\hline
!{\tt AttrVectMIN} & Minimum \\
!\hline
!{\tt AttrVectMAX} & Maximum \\
!\hline
!\end{tabular}
!\end{center}
!\end{table}
!
! {\bf N.B.}:  The output {\tt AttrVect} argument {\tt outAV} is
! allocated memory, and must be destroyed by invoking the routine
! {\tt AttrVect\_clean()} when it is no longer needed.  Failure to
! do so will result in a memory leak.
!
! !INTERFACE:

 subroutine LocalReduce_(inAV, outAV, action)
!
! !USES:
!
      use m_realkinds,     only : FP
      use m_die ,          only : die
      use m_stdio ,        only : stderr
      use m_AttrVect,      only : AttrVect
      use m_AttrVect,      only : AttrVect_init => init
      use m_AttrVect,      only : AttrVect_zero => zero
      use m_AttrVect,      only : AttrVect_nIAttr => nIAttr
      use m_AttrVect,      only : AttrVect_nRAttr => nRAttr
      use m_AttrVect,      only : AttrVect_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),  intent(IN)  :: inAV
      integer,         intent(IN)  :: action

! !OUTPUT PARAMETERS:
!
      type(AttrVect),  intent(OUT) :: outAV

! !REVISION HISTORY:
! 16Apr02 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::LocalReduce_'

  integer :: i,j

        ! First Step:  create outAV from inAV (but with one element)

  call AttrVect_init(outAV, inAV, lsize=1)

  call AttrVect_zero(outAV)

  select case(action)
  case(AttrVectSUM) ! sum up each attribute...

        ! Compute INTEGER and REAL attribute sums:

     do j=1,AttrVect_lsize(inAV)
	do i=1,AttrVect_nIAttr(outAV)
	   outAV%iAttr(i,1) = outAV%iAttr(i,1) + inAV%iAttr(i,j)
	end do
     end do

     do j=1,AttrVect_lsize(inAV)
	do i=1,AttrVect_nRAttr(outAV)
	   outAV%rAttr(i,1) = outAV%rAttr(i,1) + inAV%rAttr(i,j)
	end do
     end do

  case(AttrVectMIN) ! find the minimum of each attribute...

        ! Initialize INTEGER and REAL attribute minima:

     do i=1,AttrVect_nIAttr(outAV)
	outAV%iAttr(i,1) = inAV%iAttr(i,1)
     end do

     do i=1,AttrVect_nRAttr(outAV)
	outAV%rAttr(i,1) = inAV%rAttr(i,1)
     end do

        ! Compute INTEGER and REAL attribute minima:

     do j=1,AttrVect_lsize(inAV)
	do i=1,AttrVect_nIAttr(outAV)
	   if(inAV%iAttr(i,j) < outAV%iAttr(i,1)) then
	      outAV%iAttr(i,1) = inAV%iAttr(i,j)
	   endif
	end do
     end do

     do j=1,AttrVect_lsize(inAV)
	do i=1,AttrVect_nRAttr(outAV)
	   if(inAV%rAttr(i,j) < outAV%rAttr(i,1)) then
	      outAV%rAttr(i,1) = inAV%rAttr(i,j)
	   endif
	end do
     end do

  case(AttrVectMAX) ! find the maximum of each attribute...

        ! Initialize INTEGER and REAL attribute maxima:

     do i=1,AttrVect_nIAttr(outAV)
	outAV%iAttr(i,1) = inAV%iAttr(i,1)
     end do

     do i=1,AttrVect_nRAttr(outAV)
	outAV%rAttr(i,1) = inAV%rAttr(i,1)
     end do

        ! Compute INTEGER and REAL attribute maxima:

     do j=1,AttrVect_lsize(inAV)
	do i=1,AttrVect_nIAttr(outAV)
	   if(inAV%iAttr(i,j) > outAV%iAttr(i,1)) then
	      outAV%iAttr(i,1) = inAV%iAttr(i,j)
	   endif
	end do
     end do

     do j=1,AttrVect_lsize(inAV)
	do i=1,AttrVect_nRAttr(outAV)
	   if(inAV%rAttr(i,j) > outAV%rAttr(i,1)) then
	      outAV%rAttr(i,1) = inAV%rAttr(i,j)
	   endif
	end do
     end do

  case default

     write(stderr,'(2a,i8)') myname_,':: unrecognized action = ',action
     call die(myname_)

  end select

 end subroutine LocalReduce_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: LocalReduceRAttr_ - Local Reduction of REAL Attributes
!
! !DESCRIPTION:
!
! The subroutine {\tt LocalReduceRAttr\_()} takes the input
! {\tt AttrVect} argument {\tt inAV}, and reduces each of its {\tt REAL}
! attributes, returning them in the output {\tt AttrVect} argument
! {\tt outAV} (which is created by this routine).  The type of reduction
! is defined by the input {\tt INTEGER} argument {\tt action}.  Allowed
! values for action are defined as public data members to this module
! (see the declaration section of {\tt m\_AttrVect}, and are summarized below:
!
!\begin{table}[htbp]
!\begin{center}
!\begin{tabular}{|c|c|}
!\hline
!{\bf Value} & {\bf Action} \\
!\hline
!{\tt AttrVectSUM} & Sum \\
!\hline
!{\tt AttrVectMIN} & Minimum \\
!\hline
!{\tt AttrVectMAX} & Maximum \\
!\hline
!\end{tabular}
!\end{center}
!\end{table}
!
! {\bf N.B.}:  The output {\tt AttrVect} argument {\tt outAV} is
! allocated memory, and must be destroyed by invoking the routine
! {\tt AttrVect\_clean()} when it is no longer needed.  Failure to
! do so will result in a memory leak.
!
! !INTERFACE:
!
 subroutine LocalReduceRAttr_(inAV, outAV, action)

!
! !USES:
!
      use m_realkinds,     only : FP

      use m_die ,          only : die
      use m_stdio ,        only : stderr

      use m_List,          only : List
      use m_List,          only : List_copy => copy
      use m_List,          only : List_exportToChar => exportToChar
      use m_List,          only : List_clean => clean

      use m_AttrVect,      only : AttrVect
      use m_AttrVect,      only : AttrVect_init => init
      use m_AttrVect,      only : AttrVect_zero => zero
      use m_AttrVect,      only : AttrVect_nIAttr => nIAttr
      use m_AttrVect,      only : AttrVect_nRAttr => nRAttr
      use m_AttrVect,      only : AttrVect_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)  :: inAV
      integer,                      intent(IN)  :: action

! !OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(OUT) :: outAV

! !REVISION HISTORY:
! 16Apr02 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
!  6May02 - J.W. Larson <larson@mcs.anl.gov> - added optional
!           argument weights(:)
!  8May02 - J.W. Larson <larson@mcs.anl.gov> - modified interface
!           to return it to being a pure reduction operation.
!  9May02 - J.W. Larson <larson@mcs.anl.gov> - renamed from
!           LocalReduceReals_() to LocalReduceRAttr_() to make
!           the name more consistent with other module procedure
!           names in this module.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::LocalReduceRAttr_'

  integer :: i,j
  type(List) :: rList_copy


        ! First Step:  create outAV from inAV (but with one element)

        ! Superflous list copy circumvents SGI compiler bug
  call List_copy(rList_copy,inAV%rList)
  call AttrVect_init(outAV, rList=List_exportToChar(rList_copy), lsize=1)
  call AttrVect_zero(outAV)
  call List_clean(rList_copy)

  select case(action)
  case(AttrVectSUM) ! sum up each attribute...

        ! Compute REAL attribute sums:

     do j=1,AttrVect_lsize(inAV)
	do i=1,AttrVect_nRAttr(outAV)
	   outAV%rAttr(i,1) = outAV%rAttr(i,1) + inAV%rAttr(i,j)
	end do
     end do

  case(AttrVectMIN) ! find the minimum of each attribute...

        ! Initialize REAL attribute minima:

     do i=1,AttrVect_nRAttr(outAV)
	outAV%rAttr(i,1) = inAV%rAttr(i,1)
     end do

        ! Compute REAL attribute minima:

     do j=1,AttrVect_lsize(inAV)
	do i=1,AttrVect_nRAttr(outAV)
	   if(inAV%rAttr(i,j) < outAV%rAttr(i,1)) then
	      outAV%rAttr(i,1) = inAV%rAttr(i,j)
	   endif
	end do
     end do

  case(AttrVectMAX) ! find the maximum of each attribute...

        ! Initialize REAL attribute maxima:

     do i=1,AttrVect_nRAttr(outAV)
	outAV%rAttr(i,1) = inAV%rAttr(i,1)
     end do

        ! Compute REAL attribute maxima:

     do j=1,AttrVect_lsize(inAV)
	do i=1,AttrVect_nRAttr(outAV)
	   if(inAV%rAttr(i,j) > outAV%rAttr(i,1)) then
	      outAV%rAttr(i,1) = inAV%rAttr(i,j)
	   endif
	end do
     end do

  case default

     write(stderr,'(2a,i8)') myname_,':: unrecognized action = ',action
     call die(myname_)

  end select

 end subroutine LocalReduceRAttr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: AllReduce_ - Reduction of INTEGER and REAL Attributes
!
! !DESCRIPTION:
!
! The subroutine {\tt AllReduce\_()} takes the distributed input
! {\tt AttrVect} argument {\tt inAV}, and performs a global reduction
! of all its attributes across the MPI communicator associated with
! the Fortran90 {\tt INTEGER} handle {\tt comm}, and returns these
! reduced values to all processes in the {\tt AttrVect} argument
! {\tt outAV} (which is created by this routine).  The reduction
! operation is specified by the user, and must have one of the values
! listed in the table below:
!\begin{table}[htbp]
!\begin{center}
!\begin{tabular}{|c|c|}
!\hline
!{\bf Value} & {\bf Action} \\
!\hline
!{\tt AttrVectSUM} & Sum \\
!\hline
!{\tt AttrVectMIN} & Minimum \\
!\hline
!{\tt AttrVectMAX} & Maximum \\
!\hline
!\end{tabular}
!\end{center}
!\end{table}
!
! {\bf N.B.}:  The output {\tt AttrVect} argument {\tt outAV} is
! allocated memory, and must be destroyed by invoking the routine
! {\tt AttrVect\_clean()} when it is no longer needed.  Failure to
! do so will result in a memory leak.
!
! !INTERFACE:
!

 subroutine AllReduce_(inAV, outAV, ReductionOp, comm, ierr)

!
! !USES:
!
      use m_die
      use m_stdio ,        only : stderr
      use m_mpif90

      use m_List,          only : List
      use m_List,          only : List_exportToChar => exportToChar
      use m_List,          only : List_allocated => allocated

      use m_AttrVect,      only : AttrVect
      use m_AttrVect,      only : AttrVect_init => init
      use m_AttrVect,      only : AttrVect_zero => zero
      use m_AttrVect,      only : AttrVect_lsize => lsize
      use m_AttrVect,      only : AttrVect_nIAttr => nIAttr
      use m_AttrVect,      only : AttrVect_nRAttr => nRAttr

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)  :: inAV
      integer,                      intent(IN)  :: ReductionOp
      integer,                      intent(IN)  :: comm

! !OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(OUT) :: outAV
      integer,        optional,     intent(OUT) :: ierr

! !REVISION HISTORY:
!  8May02 - J.W. Larson <larson@mcs.anl.gov> - initial version.
!  9Jul02 - J.W. Larson <larson@mcs.anl.gov> - slight modification;
!           use List_allocated() to determine if there is attribute
!           data to be reduced (this patch is to support the Sun
!           F90 compiler).
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::AllReduce_'

  integer :: BufferSize, myID, ier

       ! Initialize ierr (if present) to "success" value
  if(present(ierr)) ierr = 0

  call MPI_COMM_RANK(comm, myID, ier)
  if(ier /= 0) then
     write(stderr,'(2a)') myname_,':: MPI_COMM_RANK() failed.'
     call MP_perr_die(myname_, 'MPI_COMM_RANK() failed.', ier)
  endif

  call AttrVect_init(outAV, inAV, lsize=AttrVect_lsize(inAV))
  call AttrVect_zero(outAV)

  if(List_allocated(inAV%rList)) then ! invoke MPI_AllReduce() for the real
                                      ! attribute data.
     BufferSize = AttrVect_lsize(inAV) * AttrVect_nRAttr(inAV)

     select case(ReductionOp)
     case(AttrVectSUM)
	call MPI_AllReduce(inAV%rAttr, outAV%rAttr, BufferSize, &
	                   MP_Type(inAV%rAttr(1,1)), MP_SUM, &
	                   comm, ier)
     case(AttrVectMIN)
	call MPI_AllReduce(inAV%rAttr, outAV%rAttr, BufferSize, &
                           MP_Type(inAV%rAttr(1,1)), MP_MIN, &
                           comm, ier)
     case(AttrVectMAX)
	call MPI_AllReduce(inAV%rAttr, outAV%rAttr, BufferSize, &
                           MP_Type(inAV%rAttr(1,1)), MP_MAX, &
                           comm, ier)
     case default
	write(stderr,'(2a,i8,a)') myname_, &
                                  '::FATAL ERROR--value of RedctionOp=', &
                                  ReductionOp,' not supported.'
     end select

     if(ier /= 0) then
	write(stderr,*) myname_, &
	     ':: Fatal Error in MPI_AllReduce(), myID = ',myID
	call MP_perr_die(myname_, 'MPI_AllReduce() failed.', ier)
     endif

  endif ! if(List_allocated(inAV%rList))...

  if(List_allocated(inAV%iList)) then ! invoke MPI_AllReduce() for the
                                      ! integer attribute data.

     BufferSize = AttrVect_lsize(inAV) * AttrVect_nIAttr(inAV)

     select case(ReductionOp)
     case(AttrVectSUM)
	call MPI_AllReduce(inAV%iAttr, outAV%iAttr, BufferSize, &
	                   MP_Type(inAV%iAttr(1,1)), MP_SUM, &
	                   comm, ier)
     case(AttrVectMIN)
	call MPI_AllReduce(inAV%iAttr, outAV%iAttr, BufferSize, &
                           MP_Type(inAV%iAttr(1,1)), MP_MIN, &
                           comm, ier)
     case(AttrVectMAX)
	call MPI_AllReduce(inAV%iAttr, outAV%iAttr, BufferSize, &
                           MP_Type(inAV%iAttr(1,1)), MP_MAX, &
                           comm, ier)
     case default
	write(stderr,'(2a,i8,a)') myname_, &
                                  '::FATAL ERROR--value of RedctionOp=', &
                                  ReductionOp,' not supported.'
     end select

     if(ierr /= 0) then
	write(stderr,*) myname_, &
	     ':: Fatal Error in MPI_AllReduce(), myID = ',myID
	call MP_perr_die(myname_, 'MPI_AllReduce() failed.', ier)
     endif
  endif ! if(List_allocated(inAV%iList))...

  if(present(ierr)) ierr = ier

 end subroutine AllReduce_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GlobalReduce_ - Reduction of INTEGER and REAL Attributes
!
! !DESCRIPTION:
!
! The subroutine {\tt GlobalReduce\_()} takes the distributed input
! {\tt AttrVect} argument {\tt inAV}, and performs a local reduction of
! all its integer and real attributes, followed by a an {\tt AllReduce}
! of all the result of the local reduction across the MPI communicator
! associated with the Fortran90 {\tt INTEGER} handle {\tt comm}, and
! returns these reduced values to all processes in the {\tt AttrVect}
! argument {\tt outAV} (which is created by this routine).  The reduction
! operation is specified by the user, and must have one of the values
! listed in the table below:
!\begin{table}[htbp]
!\begin{center}
!\begin{tabular}{|c|c|}
!\hline
!{\bf Value} & {\bf Action} \\
!\hline
!{\tt AttrVectSUM} & Sum \\
!\hline
!{\tt AttrVectMIN} & Minimum \\
!\hline
!{\tt AttrVectMAX} & Maximum \\
!\hline
!\end{tabular}
!\end{center}
!\end{table}
!
! {\bf N.B.}:  The output {\tt AttrVect} argument {\tt outAV} is
! allocated memory, and must be destroyed by invoking the routine
! {\tt AttrVect\_clean()} when it is no longer needed.  Failure to
! do so will result in a memory leak.
!
! !INTERFACE:
!

 subroutine GlobalReduce_(inAV, outAV, ReductionOp, comm, ierr)

!
! !USES:
!
      use m_die
      use m_stdio ,        only : stderr
      use m_mpif90

      use m_AttrVect,      only : AttrVect
      use m_AttrVect,      only : AttrVect_clean => clean

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)  :: inAV
      integer,                      intent(IN)  :: ReductionOp
      integer,                      intent(IN)  :: comm

! !OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(OUT) :: outAV
      integer,        optional,     intent(OUT) :: ierr

! !REVISION HISTORY:
!  6May03 - J.W. Larson <larson@mcs.anl.gov> - initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GlobalReduce_'
  type(AttrVect) :: LocalResult

  ! Step One:  On-PE reduction

  call LocalReduce_(inAV, LocalResult, ReductionOp)

  ! Step Two:  An AllReduce on the distributed local reduction results

  if(present(ierr)) then
     call AllReduce_(LocalResult, outAV, ReductionOp, comm, ierr)
  else
     call AllReduce_(LocalResult, outAV, ReductionOp, comm)
  endif

  ! Step Three:  Clean up and return.

  call AttrVect_clean(LocalResult)

 end subroutine GlobalReduce_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: LocalWeightedSumRAttrSP_ - Local Weighted Sum of REAL Attributes
!
! !DESCRIPTION:
!
! The subroutine {\tt LocalWeightedSumRAttr\_()} takes the input
! {\tt AttrVect} argument {\tt inAV}, and performs a weighted sum
! of  each of its {\tt REAL} attributes, returning them in the output
! {\tt AttrVect} argument {\tt outAV} (which is created by this routine
! and  will contain {\em no} integer attributes).  The weights used
! for the summation are provided by the user in the input argument
! {\tt Weights(:)}.  If the sum of the weights is desired, this can be
! returned as an attribute in {\tt outAV} if the optional {\tt CHARACTER}
! argument {\tt WeightSumAttr} is provided (which will be concatenated
! onto the list of real attributes in {\tt inAV}).
!
! {\bf N.B.}:  The argument {\tt WeightSumAttr} must not be identical
! to any of the real attribute names in {\tt inAV}.
!
! {\bf N.B.}:  The output {\tt AttrVect} argument {\tt outAV} is
! allocated memory, and must be destroyed by invoking the routine
! {\tt AttrVect\_clean()} when it is no longer needed.  Failure to
! do so will result in a memory leak.
!
! !INTERFACE:
!
 subroutine LocalWeightedSumRAttrSP_(inAV, outAV, Weights, WeightSumAttr)

!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr
      use m_realkinds,     only : SP, FP

      use m_List,          only : List
      use m_List,          only : List_init => init
      use m_List,          only : List_clean => clean
      use m_List,          only : List_exportToChar => exportToChar
      use m_List,          only : List_concatenate => concatenate

      use m_AttrVect,      only : AttrVect
      use m_AttrVect,      only : AttrVect_init => init
      use m_AttrVect,      only : AttrVect_zero => zero
      use m_AttrVect,      only : AttrVect_nIAttr => nIAttr
      use m_AttrVect,      only : AttrVect_nRAttr => nRAttr
      use m_AttrVect,      only : AttrVect_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)  :: inAV
      real(SP), dimension(:),       pointer     :: Weights
      character(len=*),   optional, intent(IN)  :: WeightSumAttr

! !OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(OUT) :: outAV

! !REVISION HISTORY:
!  8May02 - J.W. Larson <larson@mcs.anl.gov> - initial version.
! 14Jun02 - J.W. Larson <larson@mcs.anl.gov> - bug fix regarding
!           accumulation of weights when invoked with argument
!           weightSumAttr.  Now works in MCT unit tester.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::LocalWeightedSumRAttrSP_'

  integer :: i,j
  type(List) dummyList1, dummyList2

        ! Check for consistencey between inAV and the weights array

  if(size(weights) /= AttrVect_lsize(inAV)) then
     write(stderr,'(4a)') myname_,':: ERROR--mismatch in lengths of ', &
	  'input array array argument weights(:) and input AttrVect ',&
	  'inAV.'
     write(stderr,'(2a,i8)') myname_,':: size(weights)=',size(weights)
     write(stderr,'(2a,i8)') myname_,':: length of inAV=', &
	  AttrVect_lsize(inAV)
     call die(myname_)
  endif

        ! First Step:  create outAV from inAV (but with one element)

  if(present(WeightSumAttr)) then
     call List_init(dummyList1,WeightSumAttr)
     call List_concatenate(inAV%rList, dummyList1, dummyList2)
     call AttrVect_init(outAV, rList=List_exportToChar(dummyList2), &
	                lsize=1)
     call List_clean(dummyList1)
     call List_clean(dummyList2)
  else
     call AttrVect_init(outAV, rList=List_exportToChar(inAV%rList), lsize=1)
  endif

        ! Initialize REAL attribute sums:
  call AttrVect_zero(outAV)

        ! Compute REAL attribute sums:

  if(present(WeightSumAttr)) then ! perform weighted sum AND sum weights

     do j=1,AttrVect_lsize(inAV)

	do i=1,AttrVect_nRAttr(inAV)
	   outAV%rAttr(i,1) = outAV%rAttr(i,1) + inAV%rAttr(i,j) * weights(j)
	end do
        ! The final attribute is the sum of the weights
	outAV%rAttr(AttrVect_nRAttr(outAV),1) = &
	                   outAV%rAttr(AttrVect_nRAttr(outAV),1) + weights(j)
     end do

  else ! only perform weighted sum

     do j=1,AttrVect_lsize(inAV)
	do i=1,AttrVect_nRAttr(inAV)
	   outAV%rAttr(i,1) = outAV%rAttr(i,1) + inAV%rAttr(i,j) * weights(j)
	end do
     end do

  endif ! if(present(WeightSumAttr))...

 end subroutine LocalWeightedSumRAttrSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
! ----------------------------------------------------------------------
!
! !IROUTINE: LocalWeightedSumRAttrDP_ - Local Weighted Sum of REAL Attributes
!
! !DESCRIPTION:
! Double precision version of LocalWeightedSumRAttrSP_
!
! !INTERFACE:
!
 subroutine LocalWeightedSumRAttrDP_(inAV, outAV, Weights, WeightSumAttr)

!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr
      use m_realkinds,     only : DP, FP

      use m_List,          only : List
      use m_List,          only : List_init => init
      use m_List,          only : List_clean => clean
      use m_List,          only : List_exportToChar => exportToChar
      use m_List,          only : List_concatenate => concatenate

      use m_AttrVect,      only : AttrVect
      use m_AttrVect,      only : AttrVect_init => init
      use m_AttrVect,      only : AttrVect_zero => zero
      use m_AttrVect,      only : AttrVect_nIAttr => nIAttr
      use m_AttrVect,      only : AttrVect_nRAttr => nRAttr
      use m_AttrVect,      only : AttrVect_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)  :: inAV
      real(DP), dimension(:),       pointer     :: Weights
      character(len=*),   optional, intent(IN)  :: WeightSumAttr

! !OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(OUT) :: outAV

! !REVISION HISTORY:
!  8May02 - J.W. Larson <larson@mcs.anl.gov> - initial version.
! 14Jun02 - J.W. Larson <larson@mcs.anl.gov> - bug fix regarding
!           accumulation of weights when invoked with argument
!           weightSumAttr.  Now works in MCT unit tester.
! ______________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::LocalWeightedSumRAttrDP_'

  integer :: i,j
  type(List) dummyList1, dummyList2

        ! Check for consistencey between inAV and the weights array

  if(size(weights) /= AttrVect_lsize(inAV)) then
     write(stderr,'(4a)') myname_,':: ERROR--mismatch in lengths of ', &
	  'input array array argument weights(:) and input AttrVect ',&
	  'inAV.'
     write(stderr,'(2a,i8)') myname_,':: size(weights)=',size(weights)
     write(stderr,'(2a,i8)') myname_,':: length of inAV=', &
	  AttrVect_lsize(inAV)
     call die(myname_)
  endif

        ! First Step:  create outAV from inAV (but with one element)

  if(present(WeightSumAttr)) then
     call List_init(dummyList1,WeightSumAttr)
     call List_concatenate(inAV%rList, dummyList1, dummyList2)
     call AttrVect_init(outAV, rList=List_exportToChar(dummyList2), &
	                lsize=1)
     call List_clean(dummyList1)
     call List_clean(dummyList2)
  else
     call AttrVect_init(outAV, rList=List_exportToChar(inAV%rList), lsize=1)
  endif

        ! Initialize REAL attribute sums:
  call AttrVect_zero(outAV)

        ! Compute REAL attribute sums:

  if(present(WeightSumAttr)) then ! perform weighted sum AND sum weights

     do j=1,AttrVect_lsize(inAV)

	do i=1,AttrVect_nRAttr(inAV)
	   outAV%rAttr(i,1) = outAV%rAttr(i,1) + inAV%rAttr(i,j) * weights(j)
	end do
        ! The final attribute is the sum of the weights
	outAV%rAttr(AttrVect_nRAttr(outAV),1) = &
	                   outAV%rAttr(AttrVect_nRAttr(outAV),1) + weights(j)
     end do

  else ! only perform weighted sum

     do j=1,AttrVect_lsize(inAV)
	do i=1,AttrVect_nRAttr(inAV)
	   outAV%rAttr(i,1) = outAV%rAttr(i,1) + inAV%rAttr(i,j) * weights(j)
	end do
     end do

  endif ! if(present(WeightSumAttr))...

 end subroutine LocalWeightedSumRAttrDP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GlobalWeightedSumRAttrSP_ - Global Weighted Sum of REAL Attributes
!
! !DESCRIPTION:
!
! The subroutine {\tt GlobalWeightedSumRAttr\_()} takes the
! distributed input {\tt AttrVect} argument {\tt inAV}, and performs
! a weighted global sum across the MPI communicator associated with
! the Fortran90 {\tt INTEGER} handle {\tt comm} of each of its
! {\tt REAL} attributes, returning the sums to each process in the
! {\tt AttrVect} argument {\tt outAV} (which is created by this routine
! and will contain {\em no} integer attributes).  The weights used for
! the summation are provided by the user in the input argument
! {\tt weights(:)}.  If the sum of the weights is desired, this can be
! returned as an attribute in {\tt outAV} if the optional {\tt CHARACTER}
! argument {\tt WeightSumAttr} is provided (which will be concatenated
! onto the list of real attributes in {\tt inAV} to form the list of
! real attributes for {\tt outAV}).
!
! {\bf N.B.}:  The argument {\tt WeightSumAttr} must not be identical
! to any of the real attribute names in {\tt inAV}.
!
! {\bf N.B.}:  The output {\tt AttrVect} argument {\tt outAV} is
! allocated memory, and must be destroyed by invoking the routine
! {\tt AttrVect\_clean()} when it is no longer needed.  Failure to
! do so will result in a memory leak.
!
! !INTERFACE:
!
 subroutine GlobalWeightedSumRAttrSP_(inAV, outAV, Weights, comm, &
                                    WeightSumAttr)

!
! !USES:
!
      use m_die
      use m_stdio ,        only : stderr
      use m_mpif90
      use m_realkinds,     only : SP

      use m_List,          only : List
      use m_List,          only : List_exportToChar => exportToChar

      use m_AttrVect,      only : AttrVect
      use m_AttrVect,      only : AttrVect_clean => clean
      use m_AttrVect,      only : AttrVect_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)  :: inAV
      real(SP), dimension(:),       pointer     :: Weights
      integer,                      intent(IN)  :: comm
      character(len=*),   optional, intent(IN)  :: WeightSumAttr

! !OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(OUT) :: outAV

! !REVISION HISTORY:
!  8May02 - J.W. Larson <larson@mcs.anl.gov> - initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GlobalWeightedSumRAttrSP_'

  type(AttrVect) :: LocallySummedAV
  integer :: myID, ierr

        ! Get local process rank (for potential error reporting purposes)

  call MPI_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,':: MPI_COMM_RANK() error.',ierr)
  endif

        ! Check for consistencey between inAV and the weights array

  if(size(weights) /= AttrVect_lsize(inAV)) then
     write(stderr,'(2a,i8,3a)') myname_,':: myID=',myID, &
	  'ERROR--mismatch in lengths of ', &
	  'input array array argument weights(:) and input AttrVect ',&
	  'inAV.'
     write(stderr,'(2a,i8)') myname_,':: size(weights)=',size(weights)
     write(stderr,'(2a,i8)') myname_,':: length of inAV=', &
	  AttrVect_lsize(inAV)
     call die(myname_)
  endif

  if(present(WeightSumAttr)) then
     call LocalWeightedSumRAttrSP_(inAV, LocallySummedAV, Weights, &
	                         WeightSumAttr)
  else
     call LocalWeightedSumRAttrSP_(inAV, LocallySummedAV, Weights)
  endif

  call AllReduce_(LocallySummedAV, outAV, AttrVectSUM, comm, ierr)

       ! Clean up intermediate local sums

  call AttrVect_clean(LocallySummedAV)

 end subroutine GlobalWeightedSumRAttrSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
! ----------------------------------------------------------------------
!
! !IROUTINE: GlobalWeightedSumRAttrDP_ - Global Weighted Sum of REAL Attributes
!
! !DESCRIPTION:
! Double precision version of GlobalWeightedSumRAttrSP_
!
! !INTERFACE:
!
 subroutine GlobalWeightedSumRAttrDP_(inAV, outAV, Weights, comm, &
                                    WeightSumAttr)

!
! !USES:
!
      use m_die
      use m_stdio ,        only : stderr
      use m_mpif90
      use m_realkinds,     only : DP

      use m_List,          only : List
      use m_List,          only : List_exportToChar => exportToChar

      use m_AttrVect,      only : AttrVect
      use m_AttrVect,      only : AttrVect_clean => clean
      use m_AttrVect,      only : AttrVect_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)  :: inAV
      real(DP), dimension(:),       pointer     :: Weights
      integer,                      intent(IN)  :: comm
      character(len=*),   optional, intent(IN)  :: WeightSumAttr

! !OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(OUT) :: outAV

! !REVISION HISTORY:
!  8May02 - J.W. Larson <larson@mcs.anl.gov> - initial version.
! ______________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GlobalWeightedSumRAttrDP_'

  type(AttrVect) :: LocallySummedAV
  integer :: myID, ierr

        ! Get local process rank (for potential error reporting purposes)

  call MPI_COMM_RANK(comm, myID, ierr)
  if(ierr /= 0) then
     call MP_perr_die(myname_,':: MPI_COMM_RANK() error.',ierr)
  endif

        ! Check for consistencey between inAV and the weights array

  if(size(weights) /= AttrVect_lsize(inAV)) then
     write(stderr,'(2a,i8,3a)') myname_,':: myID=',myID, &
	  'ERROR--mismatch in lengths of ', &
	  'input array array argument weights(:) and input AttrVect ',&
	  'inAV.'
     write(stderr,'(2a,i8)') myname_,':: size(weights)=',size(weights)
     write(stderr,'(2a,i8)') myname_,':: length of inAV=', &
	  AttrVect_lsize(inAV)
     call die(myname_)
  endif

  if(present(WeightSumAttr)) then
     call LocalWeightedSumRAttrDP_(inAV, LocallySummedAV, Weights, &
	                         WeightSumAttr)
  else
     call LocalWeightedSumRAttrDP_(inAV, LocallySummedAV, Weights)
  endif

  call AllReduce_(LocallySummedAV, outAV, AttrVectSUM, comm, ierr)

       ! Clean up intermediate local sums

  call AttrVect_clean(LocallySummedAV)

 end subroutine GlobalWeightedSumRAttrDP_

 end module m_AttrVectReduce
!.




