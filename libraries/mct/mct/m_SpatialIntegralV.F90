!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_SpatialIntegralV - Spatial Integrals and Averages using vectors of weights
!
! !DESCRIPTION:  This module provides spatial integration and averaging
! services for the MCT similar to those in {\tt m\_SpatialIntegral} except
! the weights are provided by an input vector instead of through a
! {\tt GeneralGrid}.  See the description for {\tt m\_SpatialIntegral} for
! more information
!
!
! Paired masked spatial integrals and averages have not yet been implemented in
! vector form.
!
! !INTERFACE:

 module m_SpatialIntegralV

      implicit none

      private	! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: SpatialIntegralV        ! Spatial Integral
      public :: SpatialAverageV         ! Spatial Area Average

      public :: MaskedSpatialIntegralV  ! Masked Spatial Integral
      public :: MaskedSpatialAverageV   ! MaskedSpatial Area Average

      public :: PairedSpatialIntegralsV ! A Pair of Spatial
                                      ! Integrals

      public :: PairedSpatialAveragesV  ! A Pair of Spatial
                                      ! Area Averages

      interface SpatialIntegralV ; module procedure &
	   SpatialIntegralRAttrVSP_, &
	   SpatialIntegralRAttrVDP_
      end interface
      interface SpatialAverageV ; module procedure &
	   SpatialAverageRAttrVSP_, &
	   SpatialAverageRAttrVDP_
      end interface
      interface MaskedSpatialIntegralV ; module procedure &
	   MaskedSpatialIntegralRAttrVSP_, &
	   MaskedSpatialIntegralRAttrVDP_
      end interface
      interface MaskedSpatialAverageV ; module procedure &
	   MaskedSpatialAverageRAttrVSP_, &
	   MaskedSpatialAverageRAttrVDP_
      end interface
      interface PairedSpatialIntegralsV ; module procedure &
	    PairedSpatialIntegralRAttrVSP_, &
	    PairedSpatialIntegralRAttrVDP_
      end interface
      interface PairedSpatialAveragesV ; module procedure &
	    PairedSpatialAverageRAttrVSP_, &
	    PairedSpatialAverageRAttrVDP_
      end interface

! !REVISION HISTORY:
! 	4Jan04 - R.Jacob <jacob@mcs.anl.gov> - move Vector versions of routines
!                 from m_SpatialIntegral to this file.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_SpatialIntegralV'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: SpatialIntegralRAttrVSP_ - Compute spatial integral.
!
! !DESCRIPTION:
! This routine computes spatial integrals of the {\tt REAL} attributes
! of the {\tt REAL} attributes of the input {\tt AttrVect} argument
! {\tt inAv}.  {\tt SpatialIntegralRAttrV\_()} takes the input
! {\tt AttrVect} argument {\tt inAv} and computes the spatial
! integral using weights stored in the input {\tt REAL} array argument
! {\tt Weights}.  The integral of each {\tt REAL} attribute is returned
! in the output {\tt AttrVect} argument {\tt outAv}. If
! {\tt SpatialIntegralRAttrV\_()} is invoked with the optional {\tt LOGICAL}
! input argument {\tt SumWeights} set as {\tt .TRUE.}, then the weights
! are also summed and stored in {\tt outAv} (and can be referenced with
! the attribute name {\tt WeightTag}.  If {\tt SpatialIntegralRAttrV\_()} is
! invoked with the optional {\tt INTEGER} argument {\tt comm} (a Fortran
! MPI communicator handle), the summation operations for the integral are
! completed on the local process, then reduced across the communicator,
! with all processes receiving the result.
!
! {\bf N.B.:  } The local lengths of the {\tt AttrVect} argument {\tt inAv}
! and the input array {\tt Weights} must be equal.  That is, there must be
! a one-to-one correspondence between the field point values stored
! in {\tt inAv} and the point weights stored in {\tt Weights}.
!
! {\bf N.B.:  }  If {\tt SpatialIntegralRAttrV\_()} is invoked with the
! optional {\tt LOGICAL} input argument {\tt SumWeights} set as {\tt .TRUE.}.
! In this case, the none of {\tt REAL} attribute tags in {\tt inAv} may be
! named the same as the string contained in {\tt WeightTag}, which is an
! attribute name reserved for the sum of the weights in the output {\tt AttrVect}
! {\tt outAv}.
!
! {\bf N.B.:  } The output {\tt AttrVect} argument {\tt outAv} is an
! allocated data structure.  The user must deallocate it using the routine
! {\tt AttrVect\_clean()} when it is no longer needed.  Failure to do so
! will result in a memory leak.
!
! !INTERFACE:

 subroutine SpatialIntegralRAttrVSP_(inAv, outAv, Weights, SumWeights, &
                                  WeightTag, comm)

! ! USES:

      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : SP

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize

      use m_AttrVectReduce, only : AttrVect_GlobalWeightedSumRAttr => &
	                                         GlobalWeightedSumRAttr
      use m_AttrVectReduce, only : AttrVect_LocalWeightedSumRAttr => &
	                                         LocalWeightedSumRAttr

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),               intent(IN) :: inAv
      real(SP), dimension(:),       pointer    :: Weights
      logical,            optional, intent(IN) :: SumWeights
      character(len=*),   optional, intent(IN) :: WeightTag
      integer,            optional, intent(IN) :: comm

! !OUTPUT PARAMETERS:

      type(AttrVect),    intent(OUT) :: outAv

! !REVISION HISTORY:
! 	07Jun02 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::SpatialIntegralRAttrVSP_'

  integer :: ierr, length
  logical :: mySumWeights

       ! Argument Validity Checks

  if(AttrVect_lsize(inAv) /= size(Weights)) then
     ierr = AttrVect_lsize(inAv) - size(Weights)
     write(stderr,'(3a,i8,a,i8)') myname_, &
	  ':: inAv / Weights array length mismatch:  ', &
	  ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	  ' size(Weights) = ',size(Weights)
     call die(myname_)
  endif

  if(present(SumWeights)) then
     mySumWeights = SumWeights
     if(.not. present(WeightTag)) then
	write(stderr,'(3a)') myname_,':: FATAL--If the input argument SumWeights=.TRUE.,', &
                        ' then the argument WeightTag must be provided.'
	call die(myname_)
     endif
  else
     mySumWeights = .FALSE.
  endif

       ! Compute the sum

  if(present(comm)) then ! compute distributed AllReduce-style sum:

     if(mySumWeights) then ! return the spatial sum of the weights in outAV
	call AttrVect_GlobalWeightedSumRAttr(inAV, outAV, Weights, &
 	                                     comm, WeightTag)
     else
	call AttrVect_GlobalWeightedSumRAttr(inAV, outAV, Weights, comm)
     endif

  else ! compute local sum:

     if(mySumWeights) then ! return the spatial sum of the weights in outAV
	call AttrVect_LocalWeightedSumRAttr(inAV, outAV, Weights, &
                                            WeightTag)
     else
	call AttrVect_LocalWeightedSumRAttr(inAV, outAV, Weights)
     endif

  endif ! if(present(comm))...

 end subroutine SpatialIntegralRAttrVSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
! -------------------------------------------------------------------
!
! !IROUTINE: SpatialIntegralRAttrVDP_ - Compute spatial integral.
!
! !DESCRIPTION:
! Double precision version of SpatialIntegralRAttrVSP_
!
! !INTERFACE:

 subroutine SpatialIntegralRAttrVDP_(inAv, outAv, Weights, SumWeights, &
                                  WeightTag, comm)

! ! USES:

      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : DP

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize

      use m_AttrVectReduce, only : AttrVect_GlobalWeightedSumRAttr => &
	                                         GlobalWeightedSumRAttr
      use m_AttrVectReduce, only : AttrVect_LocalWeightedSumRAttr => &
	                                         LocalWeightedSumRAttr

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),               intent(IN) :: inAv
      real(DP), dimension(:),       pointer    :: Weights
      logical,            optional, intent(IN) :: SumWeights
      character(len=*),   optional, intent(IN) :: WeightTag
      integer,            optional, intent(IN) :: comm

! !OUTPUT PARAMETERS:

      type(AttrVect),    intent(OUT) :: outAv

! !REVISION HISTORY:
! 	07Jun02 - J.W. Larson <larson@mcs.anl.gov> - initial version
! ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::SpatialIntegralRAttrVDP_'

  integer :: ierr, length
  logical :: mySumWeights

       ! Argument Validity Checks

  if(AttrVect_lsize(inAv) /= size(Weights)) then
     ierr = AttrVect_lsize(inAv) - size(Weights)
     write(stderr,'(3a,i8,a,i8)') myname_, &
	  ':: inAv / Weights array length mismatch:  ', &
	  ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	  ' size(Weights) = ',size(Weights)
     call die(myname_)
  endif

  if(present(SumWeights)) then
     mySumWeights = SumWeights
     if(.not. present(WeightTag)) then
	write(stderr,'(3a)') myname_,':: FATAL--If the input argument SumWeights=.TRUE.,', &
                        ' then the argument WeightTag must be provided.'
	call die(myname_)
     endif
  else
     mySumWeights = .FALSE.
  endif

       ! Compute the sum

  if(present(comm)) then ! compute distributed AllReduce-style sum:

     if(mySumWeights) then ! return the spatial sum of the weights in outAV
	call AttrVect_GlobalWeightedSumRAttr(inAV, outAV, Weights, &
 	                                     comm, WeightTag)
     else
	call AttrVect_GlobalWeightedSumRAttr(inAV, outAV, Weights, comm)
     endif

  else ! compute local sum:

     if(mySumWeights) then ! return the spatial sum of the weights in outAV
	call AttrVect_LocalWeightedSumRAttr(inAV, outAV, Weights, &
                                            WeightTag)
     else
	call AttrVect_LocalWeightedSumRAttr(inAV, outAV, Weights)
     endif

  endif ! if(present(comm))...

 end subroutine SpatialIntegralRAttrVDP_


!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: SpatialAverageRAttrVSP_ - Compute spatial average.
!
! !DESCRIPTION:
! This routine computes spatial averages of the {\tt REAL} attributes
! of the input {\tt AttrVect} argument {\tt inAv}.
! {\tt SpatialAverageRAttrV\_()} takes the input {\tt AttrVect} argument
! {\tt inAv} and computes the spatial average using weights
! stored in the {\tt REAL} array {\tt Weights}.  The average of each
! {\tt REAL} attribute is returned in the output {\tt AttrVect} argument
! {\tt outAv}.  If {\tt SpatialAverageRAttrV\_()} is invoked with the
! optional {\tt INTEGER} argument {\tt comm} (a Fortran MPI communicator
! handle), the summation operations for the average are completed on the
! local process, then reduced across the communicator, with all processes
! receiving the result.
!
! {\bf N.B.:  } The local lengths of the {\tt AttrVect} argument {\tt inAv}
! and the input array {\tt Weights} must be equal.  That is, there must
! be a one-to-one correspondence between the field point values stored
! in {\tt inAv} and the point weights stored in {\tt Weights}.
!
! {\bf N.B.:  } The output {\tt AttrVect} argument {\tt outAv} is an
! allocated data structure.  The user must deallocate it using the routine
! {\tt AttrVect\_clean()} when it is no longer needed.  Failure to do so
! will result in a memory leak.
!
! !INTERFACE:

 subroutine SpatialAverageRAttrVSP_(inAv, outAv, Weights, comm)

! ! USES:

      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : SP, FP

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero
      use m_AttrVect, only : AttrVect_clean => clean
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : AttrVect_indexRA => indexRA

      use m_List, only : List
      use m_List, only : List_nullify => nullify

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),     intent(IN)  :: inAv
      real(SP), dimension(:), pointer :: Weights
      integer, optional,  intent(IN)  :: comm

! !OUTPUT PARAMETERS:

      type(AttrVect),     intent(OUT) :: outAv

! !REVISION HISTORY:
! 	10Jun02 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::SpatialAverageRAtttrVSP_'

  type(AttrVect) :: integratedAv
  type(List) :: nullIList
  integer :: i, ierr, iweight

       ! Compute the spatial integral:

  if(present(comm)) then
     call SpatialIntegralV(inAv, integratedAv, Weights, &
	                         .TRUE., 'weights', comm)
  else
     call SpatialIntegralV(inAv, integratedAv, Weights, .TRUE., 'weights')
  endif

       ! Check value of summed weights (to avoid division by zero):

  iweight = AttrVect_indexRA(integratedAv, 'weights')
  if(integratedAv%rAttr(iweight, 1) == 0._FP) then
     write(stderr,'(2a)') myname_, &
	  '::ERROR--Global sum of grid weights is zero.'
     call die(myname_)
  endif

       ! Initialize output AttrVect outAv:

  call List_nullify(nullIList)
  call AttrVect_init(outAv, iList=nullIList, rList=inAv%rList, lsize=1)
  call AttrVect_zero(outAv)

       ! Divide by global weight sum to compute spatial averages from
       ! spatial integrals.

  do i=1,AttrVect_nRAttr(outAv)
     outAv%rAttr(i,1) = integratedAv%rAttr(i,1) &
	                               / integratedAv%rAttr(iweight,1)
  end do

       ! Clean up temporary AttrVect:

  call AttrVect_clean(integratedAv)

 end subroutine SpatialAverageRAttrVSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
! -------------------------------------------------------------------
!
! !IROUTINE: SpatialAverageRAttrVDP_ - Compute spatial average.
!
! !DESCRIPTION:
! Double pecision version of SpatialAverageRAttrVSP
!
! !INTERFACE:

 subroutine SpatialAverageRAttrVDP_(inAv, outAv, Weights, comm)

! ! USES:

      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : DP, FP

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero
      use m_AttrVect, only : AttrVect_clean => clean
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : AttrVect_indexRA => indexRA

      use m_List, only : List
      use m_List, only : List_nullify => nullify

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),     intent(IN)  :: inAv
      real(DP), dimension(:), pointer :: Weights
      integer, optional,  intent(IN)  :: comm

! !OUTPUT PARAMETERS:

      type(AttrVect),     intent(OUT) :: outAv

! !REVISION HISTORY:
! 	10Jun02 - J.W. Larson <larson@mcs.anl.gov> - initial version
! ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::SpatialAverageRAtttrVDP_'

  type(AttrVect) :: integratedAv
  type(List) :: nullIList
  integer :: i, ierr, iweight

       ! Compute the spatial integral:

  if(present(comm)) then
     call SpatialIntegralV(inAv, integratedAv, Weights, &
	                         .TRUE., 'weights', comm)
  else
     call SpatialIntegralV(inAv, integratedAv, Weights, .TRUE., 'weights')
  endif

       ! Check value of summed weights (to avoid division by zero):

  iweight = AttrVect_indexRA(integratedAv, 'weights')
  if(integratedAv%rAttr(iweight, 1) == 0._FP) then
     write(stderr,'(2a)') myname_, &
	  '::ERROR--Global sum of grid weights is zero.'
     call die(myname_)
  endif

       ! Initialize output AttrVect outAv:

  call List_nullify(nullIList)
  call AttrVect_init(outAv, iList=nullIList, rList=inAv%rList, lsize=1)
  call AttrVect_zero(outAv)

       ! Divide by global weight sum to compute spatial averages from
       ! spatial integrals.

  do i=1,AttrVect_nRAttr(outAv)
     outAv%rAttr(i,1) = integratedAv%rAttr(i,1) &
	                               / integratedAv%rAttr(iweight,1)
  end do

       ! Clean up temporary AttrVect:

  call AttrVect_clean(integratedAv)

 end subroutine SpatialAverageRAttrVDP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: MaskedSpatialIntegralRAttrVSP_ - Masked spatial integral.
!
! !DESCRIPTION:
! This routine computes masked spatial integrals of the {\tt REAL}
! attributes of the input {\tt AttrVect} argument {\tt inAv}, returning
! the masked integrals in the output {\tt AttrVect} argument {\tt outAv}.
! The masked integral is computed using weights stored in the input
! {\tt REAL} array argument {\tt SpatialWeights}.  Integer masking (if
! desired) is provided in the optional input {\tt INTEGER} array {\tt iMask},
! and real masking (if desired) is provided in the optional input {\tt REAL}
! array {\tt rMask}.  If {\tt SpatialIntegralRAttrV\_()} is invoked with the
! optional {\tt LOGICAL} input argument {\tt SumWeights} set as {\tt .TRUE.},
! then the weights are also summed and stored in {\tt outAv} (and can be
! referenced with the attribute name defined by the optional input
! {\tt CHARACTER} argument {\tt WeightSumTag}.  If
! {\tt SpatialIntegralRAttrV\_()} is invoked with the optional {\tt INTEGER}
! argument {\tt comm} (a Fortran MPI communicator handle), the summation
! operations for the integral are completed on the local process, then
! reduced across the communicator, with all processes receiving the result.
! Otherwise, the integral is assumed to be local (or equivalent to a global
! address space).
!
! {\bf N.B.:  } The local lengths of the {\tt AttrVect} argument {\tt inAv}
! and the input array {\tt Weights} must be equal.  That is, there must be
! a one-to-one correspondence between the field point values stored
! in {\tt inAv} and the point weights stored in {\tt SpatialWeights}.
!
! {\bf N.B.:  }  If {\tt SpatialIntegralRAttrV\_()} is invoked with the
! optional {\tt LOGICAL} input argument {\tt SumWeights} set as {\tt .TRUE.}.
! In this case, the none of {\tt REAL} attribute tags in {\tt inAv} may be
! named the same as the string contained in {\tt WeightSumTag}, which is an
! attribute name reserved for the sum of the weights in the output {\tt AttrVect}
! {\tt outAv}.
!
! {\bf N.B.:  } The output {\tt AttrVect} argument {\tt outAv} is an
! allocated data structure.  The user must deallocate it using the routine
! {\tt AttrVect\_clean()} when it is no longer needed.  Failure to do so
! will result in a memory leak.
!
! !INTERFACE:

 subroutine MaskedSpatialIntegralRAttrVSP_(inAv, outAv, SpatialWeights, iMask, &
                                        rMask, UseFastMethod, SumWeights, &
                                        WeightSumTag, comm)

! ! USES:

      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : SP, FP

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize

      use m_AttrVectReduce, only : AttrVect_GlobalWeightedSumRAttr => &
	                                         GlobalWeightedSumRAttr
      use m_AttrVectReduce, only : AttrVect_LocalWeightedSumRAttr => &
	                                         LocalWeightedSumRAttr
      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),                  intent(IN) :: inAv
      real(SP),dimension(:),           pointer    :: SpatialWeights
      integer, dimension(:), optional, pointer    :: iMask
      real(SP),dimension(:), optional, pointer    :: rMask
      logical,                         intent(IN) :: UseFastMethod
      logical,               optional, intent(IN) :: SumWeights
      character(len=*),      optional, intent(IN) :: WeightSumTag
      integer,               optional, intent(IN) :: comm

! !OUTPUT PARAMETERS:

      type(AttrVect),                  intent(OUT) :: outAv

! !REVISION HISTORY:
! 	10Jun02 - J.W. Larson <larson@mcs.anl.gov> - initial version
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::MaskedSpatialIntegralRAttrVSP_'

  integer :: i, ierr, length
  logical :: mySumWeights
  real(FP), dimension(:), pointer :: Weights

       ! Argument Validity Checks

  if(AttrVect_lsize(inAv) /= size(SpatialWeights)) then
     ierr = AttrVect_lsize(inAv) - size(SpatialWeights)
     write(stderr,'(3a,i8,a,i8)') myname_, &
	  ':: inAv / SpatialWeights array length mismatch:  ', &
	  ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	  ' size(SpatialWeights) = ',size(SpatialWeights)
     call die(myname_)
  endif

  if(present(iMask)) then ! make sure it is the right length
     if(AttrVect_lsize(inAv) /= size(iMask)) then
	ierr = AttrVect_lsize(inAv) - size(iMask)
	write(stderr,'(3a,i8,a,i8)') myname_, &
	     ':: inAv / iMask array length mismatch:  ', &
	     ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	     ' size(iMask) = ',size(iMask)
	call die(myname_)
     endif
  endif

  if(present(rMask)) then ! make sure it is the right length
     if(AttrVect_lsize(inAv) /= size(rMask)) then
	ierr = AttrVect_lsize(inAv) - size(rMask)
	write(stderr,'(3a,i8,a,i8)') myname_, &
	     ':: inAv / rMask array length mismatch:  ', &
	     ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	     ' size(rMask) = ',size(rMask)
	call die(myname_)
     endif
  endif

  if(present(SumWeights)) then
     mySumWeights = SumWeights
     if(.not. present(WeightSumTag)) then
	write(stderr,'(3a)') myname_,':: FATAL--If the input argument SumWeights=.TRUE.,', &
                        ' then the argument WeightSumTag must be provided.'
	call die(myname_)
     endif
  else
     mySumWeights = .FALSE.
  endif

       ! Create a common Weights(:) array...

  length = AttrVect_lsize(inAv)

  allocate(Weights(length), stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(3a,i8)') myname_,':: allocate(Weights(...) failed,', &
	  ' ierr=',ierr
     call die(myname_)
  endif

       ! Combine weights and masks into a common Weights(:) array...

  if(UseFastMethod) then ! form the product of iMask, rMask, and SpatialWeights

     if(present(rMask)) then ! use it to form Weights(:)
	if(present(iMask)) then ! use it and rMask to form Weights(:)
	   do i=1,length
	      Weights(i) = rMask(i) * SpatialWeights(i) * iMask(i)
	   end do
	else
	   do i=1,length
	      Weights(i) = rMask(i) * SpatialWeights(i)
	   end do
	endif ! if(present(iMask))...
     else
	if(present(iMask)) then
	   do i=1,length
	      Weights(i) = SpatialWeights(i) * iMask(i)
	   end do
	else
	   do i=1,length
	      Weights(i) = SpatialWeights(i)
	   end do
	endif ! if(present(iMask))...
     endif ! if(present(rMask))...


  else ! Scan iMask and rMask carefully and set Weights(i) to zero
       ! when iMask(i) or rMask(i) is zero.  This avoids round-off
       ! effects from products and promotion of integers to reals.

     if(present(rMask)) then ! use it to form Weights(:)
	if(present(iMask)) then ! use it and rMask to form Weights(:)
	   do i=1,length
	      select case(iMask(i))
	      case(0)
		 Weights(i) = 0._FP
	      case(1)
		 if(rMask(i) == 1._FP) then
		    Weights(i) = SpatialWeights(i)
		 elseif(rMask(i) == 0._FP) then
		    Weights(i) = 0._FP
		 elseif((rMask(i) > 0._FP) .and. (rMask(i) < 1._FP)) then
		    Weights(i) = rMask(i) * SpatialWeights(i)
		 else ! rMask(i) < 0. or rMask(i) > 1.
		    write(stderr,'(3a,i8,a,f10.7)') myname_, &
			 ':: invalid value for real', &
			 'mask entry rMask(',i,') = ',rMask(i)
		    call die(myname_)
                 endif
	      case default
		 write(stderr,'(3a,i8,a,i8)') myname_, &
		      ':: invalid value for integer', &
		      'mask entry iMask(',i,') = ',iMask(i)
		 call die(myname_)
	      end select
	   end do
	else
	   do i=1,length
	      if(rMask(i) == 1._FP) then
		 Weights(i) = SpatialWeights(i)
	      elseif(rMask(i) == 0._FP) then
		 Weights(i) = 0._FP
	      elseif((rMask(i) > 0._FP) .and. (rMask(i) < 1._FP)) then
		 Weights(i) = rMask(i) * SpatialWeights(i)
	      else ! rMask(i) < 0. or rMask(i) > 1.
		 write(stderr,'(3a,i8,a,e10.6)') myname_, &
		      ':: invalid value for real', &
		      'mask entry rMask(',i,') = ',rMask(i)
		 call die(myname_)
	      endif
	   end do
	endif ! if(present(iMask))...
     else ! no rMask present...
	if(present(iMask)) then ! check iMask entries...
	   do i=1,length
	      select case(iMask(i))
	      case(0)
		 Weights(i) = 0._FP
	      case(1)
		 Weights(i) = SpatialWeights(i)
	      case default
		 write(stderr,'(3a,i8,a,i8)') myname_, &
		      ':: invalid value for integer', &
		      'mask entry iMask(',i,') = ',iMask(i)
		 call die(myname_)
	      end select
	   end do
	else ! straight assignment of SpatialWeights(:)
	   do i=1,length
		 Weights(i) = SpatialWeights(i)
	   end do
	endif ! if(present(iMask))...
     endif ! if(present(rMask))...


  endif ! if(UseFastMethod)

       ! Now that the weights are combined into a common Weights(:),
       ! compute the masked weighted sum:

  if(present(comm)) then ! compute distributed AllReduce-style sum:

     if(mySumWeights) then ! return the global sum of the weights in outAV
	call AttrVect_GlobalWeightedSumRAttr(inAV, outAV, Weights, &
   	                                     comm, WeightSumTag)
     else
	call AttrVect_GlobalWeightedSumRAttr(inAV, outAV, Weights, comm)
     endif

  else ! compute local sum:

     if(mySumWeights) then ! return the global sum of the weights in outAV
	call AttrVect_LocalWeightedSumRAttr(inAV, outAV, Weights, &
	                                    WeightSumAttr=WeightSumTag)
     else
	call AttrVect_LocalWeightedSumRAttr(inAV, outAV, Weights)
     endif

  endif ! if(present(comm))...

       ! Clean up the allocated Weights(:) array

  deallocate(Weights, stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(3a,i8)') myname_,':: deallocate(Weights(...) failed,', &
	  ' ierr=',ierr
     call die(myname_)
  endif

 end subroutine MaskedSpatialIntegralRAttrVSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
! -------------------------------------------------------------------
!
! !IROUTINE: MaskedSpatialIntegralRAttrVDP_ - Masked spatial integral.
!
! !DESCRIPTION:
! Double precision version of MaskedSpatialIntegralRAttrVSP_
!
! !INTERFACE:

 subroutine MaskedSpatialIntegralRAttrVDP_(inAv, outAv, SpatialWeights, iMask, &
                                        rMask, UseFastMethod, SumWeights, &
                                        WeightSumTag, comm)

! ! USES:

      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : DP, FP

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize

      use m_AttrVectReduce, only : AttrVect_GlobalWeightedSumRAttr => &
	                                         GlobalWeightedSumRAttr
      use m_AttrVectReduce, only : AttrVect_LocalWeightedSumRAttr => &
	                                         LocalWeightedSumRAttr
      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),                  intent(IN) :: inAv
      real(DP),dimension(:),           pointer    :: SpatialWeights
      integer, dimension(:), optional, pointer    :: iMask
      real(DP),dimension(:), optional, pointer    :: rMask
      logical,                         intent(IN) :: UseFastMethod
      logical,               optional, intent(IN) :: SumWeights
      character(len=*),      optional, intent(IN) :: WeightSumTag
      integer,               optional, intent(IN) :: comm

! !OUTPUT PARAMETERS:

      type(AttrVect),                  intent(OUT) :: outAv

! !REVISION HISTORY:
! 	10Jun02 - J.W. Larson <larson@mcs.anl.gov> - initial version
! ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::MaskedSpatialIntegralRAttrVDP_'

  integer :: i, ierr, length
  logical :: mySumWeights
  real(FP), dimension(:), pointer :: Weights

       ! Argument Validity Checks

  if(AttrVect_lsize(inAv) /= size(SpatialWeights)) then
     ierr = AttrVect_lsize(inAv) - size(SpatialWeights)
     write(stderr,'(3a,i8,a,i8)') myname_, &
	  ':: inAv / SpatialWeights array length mismatch:  ', &
	  ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	  ' size(SpatialWeights) = ',size(SpatialWeights)
     call die(myname_)
  endif

  if(present(iMask)) then ! make sure it is the right length
     if(AttrVect_lsize(inAv) /= size(iMask)) then
	ierr = AttrVect_lsize(inAv) - size(iMask)
	write(stderr,'(3a,i8,a,i8)') myname_, &
	     ':: inAv / iMask array length mismatch:  ', &
	     ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	     ' size(iMask) = ',size(iMask)
	call die(myname_)
     endif
  endif

  if(present(rMask)) then ! make sure it is the right length
     if(AttrVect_lsize(inAv) /= size(rMask)) then
	ierr = AttrVect_lsize(inAv) - size(rMask)
	write(stderr,'(3a,i8,a,i8)') myname_, &
	     ':: inAv / rMask array length mismatch:  ', &
	     ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	     ' size(rMask) = ',size(rMask)
	call die(myname_)
     endif
  endif

  if(present(SumWeights)) then
     mySumWeights = SumWeights
     if(.not. present(WeightSumTag)) then
	write(stderr,'(3a)') myname_,':: FATAL--If the input argument SumWeights=.TRUE.,', &
                        ' then the argument WeightSumTag must be provided.'
	call die(myname_)
     endif
  else
     mySumWeights = .FALSE.
  endif

       ! Create a common Weights(:) array...

  length = AttrVect_lsize(inAv)

  allocate(Weights(length), stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(3a,i8)') myname_,':: allocate(Weights(...) failed,', &
	  ' ierr=',ierr
     call die(myname_)
  endif

       ! Combine weights and masks into a common Weights(:) array...

  if(UseFastMethod) then ! form the product of iMask, rMask, and SpatialWeights

     if(present(rMask)) then ! use it to form Weights(:)
	if(present(iMask)) then ! use it and rMask to form Weights(:)
	   do i=1,length
	      Weights(i) = rMask(i) * SpatialWeights(i) * iMask(i)
	   end do
	else
	   do i=1,length
	      Weights(i) = rMask(i) * SpatialWeights(i)
	   end do
	endif ! if(present(iMask))...
     else
	if(present(iMask)) then
	   do i=1,length
	      Weights(i) = SpatialWeights(i) * iMask(i)
	   end do
	else
	   do i=1,length
	      Weights(i) = SpatialWeights(i)
	   end do
	endif ! if(present(iMask))...
     endif ! if(present(rMask))...


  else ! Scan iMask and rMask carefully and set Weights(i) to zero
       ! when iMask(i) or rMask(i) is zero.  This avoids round-off
       ! effects from products and promotion of integers to reals.

     if(present(rMask)) then ! use it to form Weights(:)
	if(present(iMask)) then ! use it and rMask to form Weights(:)
	   do i=1,length
	      select case(iMask(i))
	      case(0)
		 Weights(i) = 0._FP
	      case(1)
		 if(rMask(i) == 1._FP) then
		    Weights(i) = SpatialWeights(i)
		 elseif(rMask(i) == 0._FP) then
		    Weights(i) = 0._FP
		 elseif((rMask(i) > 0._FP) .and. (rMask(i) < 1._FP)) then
		    Weights(i) = rMask(i) * SpatialWeights(i)
		 else ! rMask(i) < 0. or rMask(i) > 1.
		    write(stderr,'(3a,i8,a,f10.7)') myname_, &
			 ':: invalid value for real', &
			 'mask entry rMask(',i,') = ',rMask(i)
		    call die(myname_)
                 endif
	      case default
		 write(stderr,'(3a,i8,a,i8)') myname_, &
		      ':: invalid value for integer', &
		      'mask entry iMask(',i,') = ',iMask(i)
		 call die(myname_)
	      end select
	   end do
	else
	   do i=1,length
	      if(rMask(i) == 1._FP) then
		 Weights(i) = SpatialWeights(i)
	      elseif(rMask(i) == 0._FP) then
		 Weights(i) = 0._FP
	      elseif((rMask(i) > 0._FP) .and. (rMask(i) < 1._FP)) then
		 Weights(i) = rMask(i) * SpatialWeights(i)
	      else ! rMask(i) < 0. or rMask(i) > 1.
		 write(stderr,'(3a,i8,a,e10.6)') myname_, &
		      ':: invalid value for real', &
		      'mask entry rMask(',i,') = ',rMask(i)
		 call die(myname_)
	      endif
	   end do
	endif ! if(present(iMask))...
     else ! no rMask present...
	if(present(iMask)) then ! check iMask entries...
	   do i=1,length
	      select case(iMask(i))
	      case(0)
		 Weights(i) = 0._FP
	      case(1)
		 Weights(i) = SpatialWeights(i)
	      case default
		 write(stderr,'(3a,i8,a,i8)') myname_, &
		      ':: invalid value for integer', &
		      'mask entry iMask(',i,') = ',iMask(i)
		 call die(myname_)
	      end select
	   end do
	else ! straight assignment of SpatialWeights(:)
	   do i=1,length
		 Weights(i) = SpatialWeights(i)
	   end do
	endif ! if(present(iMask))...
     endif ! if(present(rMask))...


  endif ! if(UseFastMethod)

       ! Now that the weights are combined into a common Weights(:),
       ! compute the masked weighted sum:

  if(present(comm)) then ! compute distributed AllReduce-style sum:

     if(mySumWeights) then ! return the global sum of the weights in outAV
	call AttrVect_GlobalWeightedSumRAttr(inAV, outAV, Weights, &
   	                                     comm, WeightSumTag)
     else
	call AttrVect_GlobalWeightedSumRAttr(inAV, outAV, Weights, comm)
     endif

  else ! compute local sum:

     if(mySumWeights) then ! return the global sum of the weights in outAV
	call AttrVect_LocalWeightedSumRAttr(inAV, outAV, Weights, &
	                                    WeightSumAttr=WeightSumTag)
     else
	call AttrVect_LocalWeightedSumRAttr(inAV, outAV, Weights)
     endif

  endif ! if(present(comm))...

       ! Clean up the allocated Weights(:) array

  deallocate(Weights, stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(3a,i8)') myname_,':: deallocate(Weights(...) failed,', &
	  ' ierr=',ierr
     call die(myname_)
  endif

 end subroutine MaskedSpatialIntegralRAttrVDP_


!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: MaskedSpatialAverageRAttrVSP_ - Masked spatial average.
!
! !DESCRIPTION: [NEEDS **LOTS** of work...]
! This routine computes spatial integrals of the {\tt REAL} attributes
! of the {\tt REAL} attributes of the input {\tt AttrVect} argument
! {\tt inAv}.  {\tt SpatialIntegralRAttrV\_()} takes the input
! {\tt AttrVect} argument {\tt inAv} and computes the spatial
! integral using weights stored in the input {\tt REAL} array argument
! {\tt Weights}.  The integral of each {\tt REAL} attribute is returned
! in the output {\tt AttrVect} argument {\tt outAv}. If
! {\tt SpatialIntegralRAttrV\_()} is invoked with the optional {\tt LOGICAL}
! input argument {\tt SumWeights} set as {\tt .TRUE.}, then the weights
! are also summed and stored in {\tt outAv} (and can be referenced with
! the attribute name {\tt WeightTag}.  If {\tt SpatialIntegralRAttrV\_()} is
! invoked with the optional {\tt INTEGER} argument {\tt comm} (a Fortran
! MPI communicator handle), the summation operations for the integral are
! completed on the local process, then reduced across the communicator,
! with all processes receiving the result.
!
! {\bf N.B.:  } The local lengths of the {\tt AttrVect} argument {\tt inAv}
! and the input array {\tt Weights} must be equal.  That is, there must be
! a one-to-one correspondence between the field point values stored
! in {\tt inAv} and the point weights stored in {\tt Weights}.
!
! {\bf N.B.:  }  If {\tt SpatialIntegralRAttrV\_()} is invoked with the
! optional {\tt LOGICAL} input argument {\tt SumWeights} set as {\tt .TRUE.}.
! In this case, the none of {\tt REAL} attribute tags in {\tt inAv} may be
! named the same as the string contained in {\tt WeightTag}, which is an
! attribute name reserved for the sum of the weights in the output {\tt AttrVect}
! {\tt outAv}.
!
! {\bf N.B.:  } The output {\tt AttrVect} argument {\tt outAv} is an
! allocated data structure.  The user must deallocate it using the routine
! {\tt AttrVect\_clean()} when it is no longer needed.  Failure to do so
! will result in a memory leak.
!
! !INTERFACE:

 subroutine MaskedSpatialAverageRAttrVSP_(inAv, outAv, SpatialWeights, iMask, &
                                       rMask, UseFastMethod, comm)

! ! USES:

      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : SP, FP

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero
      use m_AttrVect, only : AttrVect_clean => clean
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : AttrVect_indexRA => indexRA

      use m_List, only : List
      use m_List, only : List_nullify => nullify

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),                  intent(IN) :: inAv
      real(SP),  dimension(:),         pointer    :: SpatialWeights
      integer, dimension(:), optional, pointer    :: iMask
      real(SP),dimension(:), optional, pointer    :: rMask
      logical,                         intent(IN) :: UseFastMethod
      integer,               optional, intent(IN) :: comm

! !OUTPUT PARAMETERS:

      type(AttrVect),                  intent(OUT) :: outAv

! !REVISION HISTORY:
! 	11Jun02 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::MaskedSpatialAverageRAttrVSP_'

  type(AttrVect) :: integratedAv
  type(List) :: nullIList

  integer :: i, ierr, length, iweight
  logical :: mySumWeights

       ! Argument Validity Checks

  if(AttrVect_lsize(inAv) /= size(SpatialWeights)) then
     ierr = AttrVect_lsize(inAv) - size(SpatialWeights)
     write(stderr,'(3a,i8,a,i8)') myname_, &
	  ':: inAv / SpatialWeights array length mismatch:  ', &
	  ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	  ' size(SpatialWeights) = ',size(SpatialWeights)
     call die(myname_)
  endif

  if(present(iMask)) then ! make sure it is the right length
     if(AttrVect_lsize(inAv) /= size(iMask)) then
	ierr = AttrVect_lsize(inAv) - size(iMask)
	write(stderr,'(3a,i8,a,i8)') myname_, &
	     ':: inAv / iMask array length mismatch:  ', &
	     ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	     ' size(iMask) = ',size(iMask)
	call die(myname_)
     endif
  endif

  if(present(rMask)) then ! make sure it is the right length
     if(AttrVect_lsize(inAv) /= size(rMask)) then
	ierr = AttrVect_lsize(inAv) - size(rMask)
	write(stderr,'(3a,i8,a,i8)') myname_, &
	     ':: inAv / rMask array length mismatch:  ', &
	     ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	     ' size(rMask) = ',size(rMask)
	call die(myname_)
     endif
  endif

       ! Compute the masked weighted sum, including the sum of the
       ! masked weights.

  if(present(comm)) then ! communicator handle present

     if(present(iMask)) then

	if(present(rMask)) then
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            iMask, rMask, UseFastMethod, .TRUE., &
					    'MaskedWeightsSum', comm)
	else ! no rMask
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            iMask=iMask, UseFastMethod=UseFastMethod, &
                                            SumWeights=.TRUE., &
					    WeightSumTag='MaskedWeightsSum', &
					    comm=comm)
	endif ! if(present(rMask))...

     else ! no iMask present...

	if(present(rMask)) then
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            rMask=rMask, UseFastMethod=UseFastMethod, &
					    SumWeights=.TRUE., &
					    WeightSumTag='MaskedWeightsSum', &
					    comm=comm)
	else ! neither rMask nor iMask present:
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            UseFastMethod=UseFastMethod, &
					    SumWeights=.TRUE., &
					    WeightSumTag='MaskedWeightsSum', &
					    comm=comm)
	endif ! if(present(rMask))...

     endif ! if(present(iMask))...

  else ! no communicator handle present

     if(present(iMask)) then

	if(present(rMask)) then
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            iMask, rMask, UseFastMethod, .TRUE., &
					    'MaskedWeightsSum')
	else ! no rMask
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            iMask=iMask, UseFastMethod=UseFastMethod, &
                                            SumWeights=.TRUE., &
					    WeightSumTag='MaskedWeightsSum')
	endif ! if(present(rMask))...

     else ! no iMask present...

	if(present(rMask)) then
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            rMask=rMask, UseFastMethod=UseFastMethod, &
					    SumWeights=.TRUE., &
					    WeightSumTag='MaskedWeightsSum')
	else ! neither rMask nor iMask present:
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            UseFastMethod=UseFastMethod, &
					    SumWeights=.TRUE., &
					    WeightSumTag='MaskedWeightsSum')
	endif ! if(present(rMask))...

     endif ! if(present(iMask))...

  endif ! if(present(comm))...

       ! At this point, integratedAv containes the masked spatial integrals
       ! of the REAL attributes of inAv, along with the sum of the weights.
       ! to compute the masked spatial average

       ! Check value of summed weights (to avoid division by zero):

  iweight = AttrVect_indexRA(integratedAv, 'MaskedWeightsSum')
  if(integratedAv%rAttr(iweight, 1) == 0._FP) then
     write(stderr,'(2a)') myname_, &
	  '::ERROR--Global sum of grid weights is zero.'
     call die(myname_)
  endif

       ! Initialize output AttrVect outAv:

  call List_nullify(nullIList)
  call AttrVect_init(outAv, iList=nullIList, rList=inAv%rList, lsize=1)
  call AttrVect_zero(outAv)

       ! Divide by global weight sum to compute spatial averages from
       ! spatial integrals.

  do i=1,AttrVect_nRAttr(outAv)
     outAv%rAttr(i,1) = integratedAv%rAttr(i,1) &
	                               / integratedAv%rAttr(iweight,1)
  end do

       ! Clean up temporary AttrVect:

  call AttrVect_clean(integratedAv)

 end subroutine MaskedSpatialAverageRAttrVSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
! -------------------------------------------------------------------
!
! !IROUTINE: MaskedSpatialAverageRAttrVDP_ - Masked spatial average.
!
! !DESCRIPTION: [NEEDS **LOTS** of work...]
! Double precision interface version of MaskedSpatialAverageRAttrVSP_.
!
! !INTERFACE:

 subroutine MaskedSpatialAverageRAttrVDP_(inAv, outAv, SpatialWeights, iMask, &
                                       rMask, UseFastMethod, comm)

! ! USES:

      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : DP, FP

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero
      use m_AttrVect, only : AttrVect_clean => clean
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : AttrVect_indexRA => indexRA

      use m_List, only : List
      use m_List, only : List_nullify => nullify

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),                  intent(IN) :: inAv
      real(DP),  dimension(:),         pointer    :: SpatialWeights
      integer, dimension(:), optional, pointer    :: iMask
      real(DP),dimension(:), optional, pointer    :: rMask
      logical,                         intent(IN) :: UseFastMethod
      integer,               optional, intent(IN) :: comm

! !OUTPUT PARAMETERS:

      type(AttrVect),                  intent(OUT) :: outAv

! !REVISION HISTORY:
! 	11Jun02 - J.W. Larson <larson@mcs.anl.gov> - initial version
! ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::MaskedSpatialAverageRAttrVDP_'

  type(AttrVect) :: integratedAv
  type(List) :: nullIList

  integer :: i, ierr, length, iweight
  logical :: mySumWeights

       ! Argument Validity Checks

  if(AttrVect_lsize(inAv) /= size(SpatialWeights)) then
     ierr = AttrVect_lsize(inAv) - size(SpatialWeights)
     write(stderr,'(3a,i8,a,i8)') myname_, &
	  ':: inAv / SpatialWeights array length mismatch:  ', &
	  ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	  ' size(SpatialWeights) = ',size(SpatialWeights)
     call die(myname_)
  endif

  if(present(iMask)) then ! make sure it is the right length
     if(AttrVect_lsize(inAv) /= size(iMask)) then
	ierr = AttrVect_lsize(inAv) - size(iMask)
	write(stderr,'(3a,i8,a,i8)') myname_, &
	     ':: inAv / iMask array length mismatch:  ', &
	     ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	     ' size(iMask) = ',size(iMask)
	call die(myname_)
     endif
  endif

  if(present(rMask)) then ! make sure it is the right length
     if(AttrVect_lsize(inAv) /= size(rMask)) then
	ierr = AttrVect_lsize(inAv) - size(rMask)
	write(stderr,'(3a,i8,a,i8)') myname_, &
	     ':: inAv / rMask array length mismatch:  ', &
	     ' AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	     ' size(rMask) = ',size(rMask)
	call die(myname_)
     endif
  endif

       ! Compute the masked weighted sum, including the sum of the
       ! masked weights.

  if(present(comm)) then ! communicator handle present

     if(present(iMask)) then

	if(present(rMask)) then
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            iMask, rMask, UseFastMethod, .TRUE., &
					    'MaskedWeightsSum', comm)
	else ! no rMask
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            iMask=iMask, UseFastMethod=UseFastMethod, &
                                            SumWeights=.TRUE., &
					    WeightSumTag='MaskedWeightsSum', &
					    comm=comm)
	endif ! if(present(rMask))...

     else ! no iMask present...

	if(present(rMask)) then
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            rMask=rMask, UseFastMethod=UseFastMethod, &
					    SumWeights=.TRUE., &
					    WeightSumTag='MaskedWeightsSum', &
					    comm=comm)
	else ! neither rMask nor iMask present:
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            UseFastMethod=UseFastMethod, &
					    SumWeights=.TRUE., &
					    WeightSumTag='MaskedWeightsSum', &
					    comm=comm)
	endif ! if(present(rMask))...

     endif ! if(present(iMask))...

  else ! no communicator handle present

     if(present(iMask)) then

	if(present(rMask)) then
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            iMask, rMask, UseFastMethod, .TRUE., &
					    'MaskedWeightsSum')
	else ! no rMask
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            iMask=iMask, UseFastMethod=UseFastMethod, &
                                            SumWeights=.TRUE., &
					    WeightSumTag='MaskedWeightsSum')
	endif ! if(present(rMask))...

     else ! no iMask present...

	if(present(rMask)) then
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            rMask=rMask, UseFastMethod=UseFastMethod, &
					    SumWeights=.TRUE., &
					    WeightSumTag='MaskedWeightsSum')
	else ! neither rMask nor iMask present:
	   call MaskedSpatialIntegralV(inAv, integratedAv, SpatialWeights,  &
		                            UseFastMethod=UseFastMethod, &
					    SumWeights=.TRUE., &
					    WeightSumTag='MaskedWeightsSum')
	endif ! if(present(rMask))...

     endif ! if(present(iMask))...

  endif ! if(present(comm))...

       ! At this point, integratedAv containes the masked spatial integrals
       ! of the REAL attributes of inAv, along with the sum of the weights.
       ! to compute the masked spatial average

       ! Check value of summed weights (to avoid division by zero):

  iweight = AttrVect_indexRA(integratedAv, 'MaskedWeightsSum')
  if(integratedAv%rAttr(iweight, 1) == 0._FP) then
     write(stderr,'(2a)') myname_, &
	  '::ERROR--Global sum of grid weights is zero.'
     call die(myname_)
  endif

       ! Initialize output AttrVect outAv:

  call List_nullify(nullIList)
  call AttrVect_init(outAv, iList=nullIList, rList=inAv%rList, lsize=1)
  call AttrVect_zero(outAv)

       ! Divide by global weight sum to compute spatial averages from
       ! spatial integrals.

  do i=1,AttrVect_nRAttr(outAv)
     outAv%rAttr(i,1) = integratedAv%rAttr(i,1) &
	                               / integratedAv%rAttr(iweight,1)
  end do

       ! Clean up temporary AttrVect:

  call AttrVect_clean(integratedAv)

 end subroutine MaskedSpatialAverageRAttrVDP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: PairedSpatialIntegralRAttrVSP_ - Do two spatial integrals at once.
!
! !DESCRIPTION:
! This routine computes spatial integrals of the {\tt REAL} attributes
! of the {\tt REAL} attributes of the input {\tt AttrVect} arguments
! {\tt inAv1} and {\tt inAv2}, returning the integrals in the output
! {\tt AttrVect} arguments {\tt outAv1} and {\tt outAv2}, respectively .
! The integrals of {\tt inAv1} and {\tt inAv2} are computed using
! spatial weights stored in the input {\tt REAL} array arguments
! {\tt Weights1} and {\tt Weights2}, respectively.
! If {\tt SpatialIntegralRAttrV\_()} is invoked with the optional
! {\tt LOGICAL} input argument
! {\tt SumWeights} set as {\tt .TRUE.}, then the weights are also summed
! and stored in {\tt outAv1} and {\tt outAv2}, and can be referenced with
! the attribute tags defined by the arguments {\tt WeightName1} and
! {\tt WeightName2}, respectively.  This paired integral is implicitly a
! distributed operation (the whole motivation for pairing the integrals is
! to reduce communication latency costs), and the Fortran MPI communicator
! handle is defined by the input {\tt INTEGER} argument {\tt comm}.  The
! summation is an AllReduce operation, with all processes receiving the
! global sum.
!
! {\bf N.B.:  } The local lengths of the {\tt AttrVect} argument {\tt inAv1}
! and the input {\tt REAL} array {\tt Weights1} must be equal.  That is, there
! must be a one-to-one correspondence between the field point values stored
! in {\tt inAv1} and the point weights stored in {\tt Weights}.  The same
! relationship must apply between {\tt inAv2} and {\tt Weights2}.
!
! {\bf N.B.:  }  If {\tt SpatialIntegralRAttrV\_()} is invoked with the
! optional {\tt LOGICAL} input argument {\tt SumWeights} set as {\tt .TRUE.},
! then the value of {\tt WeightName1} must not conflict with any of the
! {\tt REAL} attribute tags in {\tt inAv1} and the value of {\tt WeightName2}
! must not conflict with any of the {\tt REAL} attribute tags in {\tt inAv2}.
!
! {\bf N.B.:  } The output {\tt AttrVect} arguments {\tt outAv1} and
! {\tt outAv2} are allocated data structures.  The user must deallocate them
!  using the routine {\tt AttrVect\_clean()} when they are no longer needed.
! Failure to do so will result in a memory leak.
!
! !INTERFACE:

 subroutine PairedSpatialIntegralRAttrVSP_(inAv1, outAv1, Weights1, WeightName1, &
                                        inAv2, outAv2, Weights2, WeightName2, &
                                        SumWeights, comm)
! ! USES:

      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : SP, FP

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr

      use m_AttrVectReduce, only : AttrVect_LocalWeightedSumRAttr => &
	                                         LocalWeightedSumRAttr

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),     intent(IN)  :: inAv1
      real(SP),dimension(:),pointer   :: Weights1
      character(len=*),   intent(IN)  :: WeightName1
      type(AttrVect),     intent(IN)  :: inAv2
      real(SP),dimension(:),pointer   :: Weights2
      character(len=*),   intent(IN)  :: WeightName2
      logical, optional,  intent(IN)  :: SumWeights
      integer,            intent(IN)  :: comm

! !OUTPUT PARAMETERS:

      type(AttrVect),     intent(OUT) :: outAv1
      type(AttrVect),     intent(OUT) :: outAv2

! !REVISION HISTORY:
! 	10Jun02 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::PairedSpatialIntegralRAttrVSP_'

       ! Argument Sanity Checks:

  integer :: ierr, length1, length2, PairedBufferLength
  integer :: nRA1, nRA2
  logical :: mySumWeights
  real(FP), dimension(:), pointer :: PairedBuffer, OutPairedBuffer

       ! Argument Validity Checks

  if(AttrVect_lsize(inAv1) /= size(Weights1)) then
     ierr = AttrVect_lsize(inAv1) - size(Weights1)
     write(stderr,'(3a,i8,a,i8)') myname_, &
	  ':: inAv1 / Weights1 length mismatch:  ', &
	  ' AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  ' size(Weights1) = ',size(Weights1)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv2) /= size(Weights2)) then
     ierr = AttrVect_lsize(inAv2) - size(Weights2)
     write(stderr,'(3a,i8,a,i8)') myname_, &
	  ':: inAv2 / Weights2 length mismatch:  ', &
	  ' AttrVect_lsize(inAv2) = ',AttrVect_lsize(inAv2), &
	  ' size(Weights2) = ',size(Weights2)
     call die(myname_)
  endif

        ! Are we summing the integration weights?

  if(present(SumWeights)) then
     mySumWeights = SumWeights
  else
     mySumWeights = .FALSE.
  endif

       ! Compute the local contributions to the two integrals:

  if(mySumWeights) then
     call AttrVect_LocalWeightedSumRAttr(inAv1, outAv1, Weights1, WeightName1)
     call AttrVect_LocalWeightedSumRAttr(inAv2, outAv2, Weights2, WeightName2)
  else
     call AttrVect_LocalWeightedSumRAttr(inAv1, outAv1, Weights1)
     call AttrVect_LocalWeightedSumRAttr(inAv2, outAv2, Weights2)
  endif

       ! Create the paired buffer for the Global Sum

  nRA1 = AttrVect_nRAttr(outAv1)
  nRA2 = AttrVect_nRAttr(outAv2)

  PairedBufferLength =  nRA1 + nRA2
  allocate(PairedBuffer(PairedBufferLength), OutPairedBuffer(PairedBufferLength), &
           stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8)') myname_, &
	  ':: Fatal error--allocate(PairedBuffer...failed, ierr = ',ierr
     call die(myname_)
  endif

       ! Load the paired buffer

  PairedBuffer(1:nRA1) = outAv1%rAttr(1:nRA1,1)
  PairedBuffer(nRA1+1:PairedBufferLength) = outAv2%rAttr(1:nRA2,1)

       ! Perform the global sum on the paired buffer

  call MPI_AllReduce(PairedBuffer, OutPairedBuffer, PairedBufferLength, &
                        MP_Type(PairedBuffer(1)), MP_SUM, comm, ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8)') myname_, &
  	      ':: Fatal Error--MPI_ALLREDUCE() failed with ierror = ',ierr
     call MP_perr_die(myname_,'MPI_ALLREDUCE() failed',ierr)
  endif

       ! Unload OutPairedBuffer into outAv1 and outAv2:

  outAv1%rAttr(1:nRA1,1) = OutPairedBuffer(1:nRA1)
  outAv2%rAttr(1:nRA2,1) = OutPairedBuffer(nRA1+1:PairedBufferLength)

       ! Clean up allocated arrays:

  deallocate(PairedBuffer, OutPairedBuffer, stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8)') myname_, &
	  'ERROR--deallocate(PairedBuffer,...) failed, ierr = ',ierr
     call die(myname_)
  endif

 end subroutine PairedSpatialIntegralRAttrVSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
! -------------------------------------------------------------------
!
! !IROUTINE: PairedSpatialIntegralRAttrVDP_ - Two spatial integrals.
!
! !DESCRIPTION:
! Double precision interface version of PairedSpatialIntegralRAttrVSP_.
!
! !INTERFACE:

 subroutine PairedSpatialIntegralRAttrVDP_(inAv1, outAv1, Weights1, WeightName1, &
                                        inAv2, outAv2, Weights2, WeightName2, &
                                        SumWeights, comm)
! ! USES:

      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : DP, FP

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr

      use m_AttrVectReduce, only : AttrVect_LocalWeightedSumRAttr => &
	                                         LocalWeightedSumRAttr

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),     intent(IN)  :: inAv1
      real(DP),dimension(:),pointer   :: Weights1
      character(len=*),   intent(IN)  :: WeightName1
      type(AttrVect),     intent(IN)  :: inAv2
      real(DP),dimension(:),pointer   :: Weights2
      character(len=*),   intent(IN)  :: WeightName2
      logical, optional,  intent(IN)  :: SumWeights
      integer,            intent(IN)  :: comm

! !OUTPUT PARAMETERS:

      type(AttrVect),     intent(OUT) :: outAv1
      type(AttrVect),     intent(OUT) :: outAv2

! !REVISION HISTORY:
! 	10Jun02 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!
! ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::PairedSpatialIntegralRAttrVDP_'

       ! Argument Sanity Checks:

  integer :: ierr, length1, length2, PairedBufferLength
  integer :: nRA1, nRA2
  logical :: mySumWeights
  real(FP), dimension(:), pointer :: PairedBuffer, OutPairedBuffer

       ! Argument Validity Checks

  if(AttrVect_lsize(inAv1) /= size(Weights1)) then
     ierr = AttrVect_lsize(inAv1) - size(Weights1)
     write(stderr,'(3a,i8,a,i8)') myname_, &
	  ':: inAv1 / Weights1 length mismatch:  ', &
	  ' AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  ' size(Weights1) = ',size(Weights1)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv2) /= size(Weights2)) then
     ierr = AttrVect_lsize(inAv2) - size(Weights2)
     write(stderr,'(3a,i8,a,i8)') myname_, &
	  ':: inAv2 / Weights2 length mismatch:  ', &
	  ' AttrVect_lsize(inAv2) = ',AttrVect_lsize(inAv2), &
	  ' size(Weights2) = ',size(Weights2)
     call die(myname_)
  endif

        ! Are we summing the integration weights?

  if(present(SumWeights)) then
     mySumWeights = SumWeights
  else
     mySumWeights = .FALSE.
  endif

       ! Compute the local contributions to the two integrals:

  if(mySumWeights) then
     call AttrVect_LocalWeightedSumRAttr(inAv1, outAv1, Weights1, WeightName1)
     call AttrVect_LocalWeightedSumRAttr(inAv2, outAv2, Weights2, WeightName2)
  else
     call AttrVect_LocalWeightedSumRAttr(inAv1, outAv1, Weights1)
     call AttrVect_LocalWeightedSumRAttr(inAv2, outAv2, Weights2)
  endif

       ! Create the paired buffer for the Global Sum

  nRA1 = AttrVect_nRAttr(outAv1)
  nRA2 = AttrVect_nRAttr(outAv2)

  PairedBufferLength =  nRA1 + nRA2
  allocate(PairedBuffer(PairedBufferLength), OutPairedBuffer(PairedBufferLength), &
           stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8)') myname_, &
	  ':: Fatal error--allocate(PairedBuffer...failed, ierr = ',ierr
     call die(myname_)
  endif

       ! Load the paired buffer

  PairedBuffer(1:nRA1) = outAv1%rAttr(1:nRA1,1)
  PairedBuffer(nRA1+1:PairedBufferLength) = outAv2%rAttr(1:nRA2,1)

       ! Perform the global sum on the paired buffer

  call MPI_AllReduce(PairedBuffer, OutPairedBuffer, PairedBufferLength, &
                        MP_Type(PairedBuffer(1)), MP_SUM, comm, ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8)') myname_, &
  	      ':: Fatal Error--MPI_ALLREDUCE() failed with ierror = ',ierr
     call MP_perr_die(myname_,'MPI_ALLREDUCE() failed',ierr)
  endif

       ! Unload OutPairedBuffer into outAv1 and outAv2:

  outAv1%rAttr(1:nRA1,1) = OutPairedBuffer(1:nRA1)
  outAv2%rAttr(1:nRA2,1) = OutPairedBuffer(nRA1+1:PairedBufferLength)

       ! Clean up allocated arrays:

  deallocate(PairedBuffer, OutPairedBuffer, stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8)') myname_, &
	  'ERROR--deallocate(PairedBuffer,...) failed, ierr = ',ierr
     call die(myname_)
  endif

 end subroutine PairedSpatialIntegralRAttrVDP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: PairedSpatialAverageRAttrVSP_ - Do two spatial averages at once.
!
! !DESCRIPTION:
! This routine computes spatial averages of the {\tt REAL} attributes
! of the {\tt REAL} attributes of the input {\tt AttrVect} arguments
! {\tt inAv1} and {\tt inAv2}, returning the integrals in the output
! {\tt AttrVect} arguments {\tt outAv1} and {\tt outAv2}, respectively .
! The averages of {\tt inAv1} and {\tt inAv2} are computed using
! spatial weights stored in the input {\tt REAL} array arguments
! {\tt Weights1} and {\tt Weights2}, respectively.  This paired average
! is implicitly a
! distributed operation (the whole motivation for pairing the integrals is
! to reduce communication latency costs), and the Fortran MPI communicator
! handle is defined by the input {\tt INTEGER} argument {\tt comm}.  The
! summation is an AllReduce operation, with all processes receiving the
! global sum.
!
! {\bf N.B.:  } The local lengths of the {\tt AttrVect} argument {\tt inAv1}
! and the array {\tt Weights} must be equal.  That is, there must be a
! one-to-one correspondence between the field point values stored
! in {\tt inAv1} and the spatial weights stored in {\tt Weights}
!
! {\bf N.B.:  } The output {\tt AttrVect} arguments {\tt outAv1} and
! {\tt outAv2} are allocated data structures.  The user must deallocate them
!  using the routine {\tt AttrVect\_clean()} when they are no longer needed.
! Failure to do so will result in a memory leak.
!
! !INTERFACE:

 subroutine PairedSpatialAverageRAttrVSP_(inAv1, outAv1, Weights1, inAv2, &
                                       outAv2, Weights2, comm)
! ! USES:

      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : SP, FP

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero
      use m_AttrVect, only : AttrVect_clean => clean
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : AttrVect_indexRA => indexRA

      use m_AttrVectReduce, only : AttrVect_LocalWeightedSumRAttr => &
	                                         LocalWeightedSumRAttr

      use m_List, only : List
      use m_List, only : List_nullify => nullify

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),     intent(IN) :: inAv1
      real(SP),dimension(:),pointer  :: Weights1
      type(AttrVect),     intent(IN) :: inAv2
      real(SP),dimension(:),pointer  :: Weights2
      integer,            intent(IN) :: comm

! !OUTPUT PARAMETERS:

      type(AttrVect),    intent(OUT) :: outAv1
      type(AttrVect),    intent(OUT) :: outAv2

! !REVISION HISTORY:
! 	09May02 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::PairedSpatialAverageRAttrVSP_'

  type(AttrVect) :: integratedAv1, integratedAv2
  type(List) :: nullIList
  integer :: i, ierr, iweight1, iweight2

       ! weight tags used to keep track of spatial weight sums
  character*8, parameter :: WeightName1='WeightSum1'
  character*8, parameter :: WeightName2='WeightSum2'

       ! Compute the paired spatial integral, including spatial weights:

  call PairedSpatialIntegralsV(inAv1, integratedAv1, Weights1, WeightName1, &
                                   inAv2, integratedAv2, Weights2, WeightName2, &
                                   .TRUE., comm)

       ! Check value of summed weights (to avoid division by zero):

  iweight1 = AttrVect_indexRA(integratedAv1, WeightName1)
  if(integratedAv1%rAttr(iweight1, 1) == 0._FP) then
     write(stderr,'(2a)') myname_, &
	  '::ERROR--Global sum of grid weights in first integral is zero.'
     call die(myname_)
  endif

  iweight2 = AttrVect_indexRA(integratedAv2, WeightName2)
  if(integratedAv2%rAttr(iweight2, 1) == 0._FP) then
     write(stderr,'(2a)') myname_, &
	  '::ERROR--Global sum of grid weights in second integral is zero.'
     call die(myname_)
  endif

       ! Initialize output AttrVects outAv1 and outAv2:

  call List_nullify(nullIList)
  call AttrVect_init(outAv1, iList=nullIList, rList=inAv1%rList, lsize=1)
  call AttrVect_zero(outAv1)
  call AttrVect_init(outAv2, iList=nullIList, rList=inAv2%rList, lsize=1)
  call AttrVect_zero(outAv2)

       ! Divide by global weight sum to compute spatial averages from
       ! spatial integrals.

  do i=1,AttrVect_nRAttr(outAv1)
     outAv1%rAttr(i,1) = integratedAv1%rAttr(i,1) &
	                               / integratedAv1%rAttr(iweight1,1)
  end do

  do i=1,AttrVect_nRAttr(outAv2)
     outAv2%rAttr(i,1) = integratedAv2%rAttr(i,1) &
	                               / integratedAv2%rAttr(iweight2,1)
  end do

       ! Clean up temporary AttrVects:

  call AttrVect_clean(integratedAv1)
  call AttrVect_clean(integratedAv2)

 end subroutine PairedSpatialAverageRAttrVSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
! ----------------------------------------------------------------------
!
! !IROUTINE: PairedSpatialAverageRAttrVDP_ - Two spatial averages.
!
! !DESCRIPTION:
! Double precision version of PairedSpatialAverageRAttrVSP_
!
! !INTERFACE:

 subroutine PairedSpatialAverageRAttrVDP_(inAv1, outAv1, Weights1, inAv2, &
                                       outAv2, Weights2, comm)
! ! USES:

      use m_stdio
      use m_die
      use m_mpif90
      use m_realkinds, only : DP, FP

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero
      use m_AttrVect, only : AttrVect_clean => clean
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : AttrVect_indexRA => indexRA

      use m_AttrVectReduce, only : AttrVect_LocalWeightedSumRAttr => &
	                                         LocalWeightedSumRAttr

      use m_List, only : List
      use m_List, only : List_nullify => nullify

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),     intent(IN) :: inAv1
      real(DP),dimension(:),pointer  :: Weights1
      type(AttrVect),     intent(IN) :: inAv2
      real(DP),dimension(:),pointer  :: Weights2
      integer,            intent(IN) :: comm

! !OUTPUT PARAMETERS:

      type(AttrVect),    intent(OUT) :: outAv1
      type(AttrVect),    intent(OUT) :: outAv2

! !REVISION HISTORY:
! 	09May02 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!
! ______________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::PairedSpatialAverageRAttrVDP_'

  type(AttrVect) :: integratedAv1, integratedAv2
  type(List) :: nullIList
  integer :: i, ierr, iweight1, iweight2

       ! weight tags used to keep track of spatial weight sums
  character*8, parameter :: WeightName1='WeightSum1'
  character*8, parameter :: WeightName2='WeightSum2'

       ! Compute the paired spatial integral, including spatial weights:

  call PairedSpatialIntegralsV(inAv1, integratedAv1, Weights1, WeightName1, &
                                   inAv2, integratedAv2, Weights2, WeightName2, &
                                   .TRUE., comm)

       ! Check value of summed weights (to avoid division by zero):

  iweight1 = AttrVect_indexRA(integratedAv1, WeightName1)
  if(integratedAv1%rAttr(iweight1, 1) == 0._FP) then
     write(stderr,'(2a)') myname_, &
	  '::ERROR--Global sum of grid weights in first integral is zero.'
     call die(myname_)
  endif

  iweight2 = AttrVect_indexRA(integratedAv2, WeightName2)
  if(integratedAv2%rAttr(iweight2, 1) == 0._FP) then
     write(stderr,'(2a)') myname_, &
	  '::ERROR--Global sum of grid weights in second integral is zero.'
     call die(myname_)
  endif

       ! Initialize output AttrVects outAv1 and outAv2:

  call List_nullify(nullIList)
  call AttrVect_init(outAv1, iList=nullIList, rList=inAv1%rList, lsize=1)
  call AttrVect_zero(outAv1)
  call AttrVect_init(outAv2, iList=nullIList, rList=inAv2%rList, lsize=1)
  call AttrVect_zero(outAv2)

       ! Divide by global weight sum to compute spatial averages from
       ! spatial integrals.

  do i=1,AttrVect_nRAttr(outAv1)
     outAv1%rAttr(i,1) = integratedAv1%rAttr(i,1) &
	                               / integratedAv1%rAttr(iweight1,1)
  end do

  do i=1,AttrVect_nRAttr(outAv2)
     outAv2%rAttr(i,1) = integratedAv2%rAttr(i,1) &
	                               / integratedAv2%rAttr(iweight2,1)
  end do

       ! Clean up temporary AttrVects:

  call AttrVect_clean(integratedAv1)
  call AttrVect_clean(integratedAv2)

 end subroutine PairedSpatialAverageRAttrVDP_

 end module m_SpatialIntegralV
