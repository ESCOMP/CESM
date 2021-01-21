!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_Merge - Merge flux and state data from multiple sources.
!
! !DESCRIPTION:  This module supports {\em merging} of state and flux
! data from multiple components with overlapping spatial domains for use
! by another component.  For example, let the vectors ${\bf a}$ and
! ${\bf b}$ be data from Components $A$ and $B$ that have been
! interpolated onto the physical grid of another component $C$.  We wish
! to combine the data from $A$ and $B$ to get a vector ${\bf c}$, which
! represents the merged data on the grid of component $C$.  This merge
! process is an element-by-element masked weighted average:
! $$ c_i = {{{{\prod_{j=1}^J} M_{i}^j} {{\prod_{k=1}^K} F_{i}^k} a_i +
! {{\prod_{p=1}^P} N_{i}^p} {{\prod_{q=1}^Q} G_{i}^q} b_i} \over
! {{{\prod_{j=1}^J} M_{i}^j} {{\prod_{k=1}^K} F_{i}^k} +
! {{\prod_{p=1}^P} N_{i}^p} {{\prod_{q=1}^Q} G_{i}^q}}}, $$
! Where ${M_{i}^j}$ and ${N_{i}^p}$ are {\em integer masks} (which have
! value either $0$ or $1$), and ${F_{i}^k}$ and ${G_{i}^q}$ are {\em real
! masks} (which are in the closed interval $[0,1]$).
!
! Currently, we assume that the integer and real masks are stored in
! the same {\tt GeneralGrid} datatype.  We also assume--and this is of
! critical importance to the user--that the attributes to be merged are
! the same for all the inputs and output.  If the user violates this
! assumption, incorrect merges will occur for any attributes that are
! present in only some (that is not all) of the inputs.
!
! This module supports explicitly the merging data from two, three, and
! four components.  There is also a routine named {\tt MergeInData} that
! allows the user to construct other merging schemes.
!
! !INTERFACE:

 module m_Merge

!
! !USES:
!
!     No other modules used in the declaration section of this module.

      implicit none

      private   ! except

! !PUBLIC TYPES:

!     None.

! !PUBLIC MEMBER FUNCTIONS:

      public :: MergeTwo      ! Merge Output from two components
                              ! for use by a third.
      public :: MergeThree    ! Merge Output from three components
                              ! for use by a fourth.
      public :: MergeFour     ! Merge Output from four components
                              ! for use by a fifth.
      public :: MergeInData   ! Merge in data from a single component.

    interface MergeTwo ; module procedure &
         MergeTwoGGSP_, &
         MergeTwoGGDP_
    end interface
    interface MergeThree ; module procedure &
         MergeThreeGGSP_, &
	 MergeThreeGGDP_
    end interface
    interface MergeFour ; module procedure &
         MergeFourGGSP_, &
         MergeFourGGDP_
    end interface
    interface MergeInData ; module procedure &
         MergeInDataGGSP_, &
         MergeInDataGGDP_
    end interface

! !PUBLIC DATA MEMBERS:

!     None.

! !REVISION HISTORY:
!       19Jun02 - J.W. Larson <larson@mcs.anl.gov> - Initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_Merge'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: MergeTwoGGSP_ - Merge Data from Two Sources
!
! !DESCRIPTION:  This routine merges {\tt REAL} attribute data from
! two input {\tt AttrVect} arguments {\tt inAv1} and {\tt inAv2} to
! a third {\tt AttrVect} {\tt outAv}.  The attributes to be merged are
! determined entirely by the real attributes of {\tt outAv}.  If
! {\tt outAv} shares one or more attributes with either of the inputs
! {\tt inAv1} or {\tt inAv2}, a merge is performed on the individual
! {\em intersections} of attributes between the pairs $({\tt outAv},
! {\tt inAv1})$ and $({\tt outAv},{\tt inAv1})$.  Currently, it is assumed
! that these pairwise intersections are all equal.  This assumption is of
! critical importance to the user.  If the user violates this
! assumption, incorrect merges of attributes that are present in some
! (but not all) of the inputs will result.
!
! The merge operatrion is a masked
! weighted element-by-element sum, as outlined in the following example.
! Let the vectors ${\bf a}$ and ${\bf b}$ be data from Components $A$
! and $B$ that have been interpolated onto the physical grid of another
! component $C$.  We wish to combine the data from $A$ and $B$ to get
! a vector ${\bf c}$, which represents the merged data on the grid of
! component $C$.  The merge relation to obtain the $i$th element of
! {\bf c} is
! $$ c_i = {1 \over {W_i}} \bigg\{ {{\prod_{j=1}^J} \kappa_{i}^j}
! {{\prod_{k=1}^K} \alpha_{i}^k} {a_i} + {{\prod_{l=1}^L} \lambda_{i}^l}
! {{\prod_{m=1}^M} \beta_{i}^m} {b_i} \bigg\} , $$
! where
! $$ {W_i} = {{\prod_{j=1}^J} \kappa_{i}^j} {{\prod_{k=1}^K} \alpha_{i}^k} +
! {{\prod_{l=1}^L} \lambda_{i}^l} {{\prod_{m=1}^M} \beta_{i}^m}. $$
! The quantities ${\kappa_{i}^j}$ and ${\lambda_{i}^l}$ are {\em integer
! masks} (which have value either $0$ or $1$), and ${\alpha_{i}^k}$ and
! ${\beta_{i}^m}$ are {\em real masks} (which are in the closed interval
! $[0,1]$).
!
! The integer and real masks are stored as attributes to the same input
! {\tt GeneralGrid} argument {\tt GGrid}.  The mask attribute names are
! stored as substrings to the colon-separated strings contained in the
! input {\tt CHARACTER} arguments {\tt iMaskTags1}, {\tt iMaskTags2},
! {\tt rMaskTags1}, and {\tt rMaskTags2}.  The {\tt LOGICAL} input
! argument {\tt CheckMasks} governs how the masks are applied.  If
! ${\tt CheckMasks} = {\tt .TRUE.}$, the entries are checked to ensure
! they meet the definitions of real and integer masks.  If
! ${\tt CheckMasks} = {\tt .TRUE.}$ then the masks are multiplied
! together on an element-by-element basis with no validation of their
! entries (this option results in slightly higher performance).
!
! This routine returns the sume of the masked weights as a diagnostic.
! This quantity is returned in the output {\tt REAL} array {\tt WeightSum}.
!
! The correspondence between the quantities in the above merge relation
! and the arguments to this routine are summarized in the table.
! \begin{center}
! \begin{tabular}{|l|l|l|}\hline
! {\bf Quantity} & {\bf Stored in} & {\bf Referenced by}  \\
!  & {\bf Argument}    & {\bf Argument} \\
! \hline
! \hline
! $ {a_i} $ & {\tt inAv1} & \\
! \hline
! $ {b_i} $ & {\tt inAv2} & \\
! \hline
! $ {c_i} $ & {\tt outAv} & \\
! \hline
! $ {\kappa_i^j}, j=1,\ldots,J $ & {\tt GGrid} & {\tt iMaskTags1}\\
! & & ($J$ items) \\
! \hline
! $ {\alpha_i^k}, k=1,\ldots,K $ & {\tt GGrid} & {\tt rMaskTags1}\\
! & & ($K$ items) \\
! \hline
! $ {\lambda_i^l}, l=1,\ldots,L $ & {\tt GGrid} & {\tt iMaskTags2}\\
! & & ($L$ items) \\
! \hline
! $ {\beta_i^m}, m=1,\ldots,M $ & {\tt GGrid} & {\tt rMaskTags2}\\
! & & ($M$ items) \\
! \hline
! $ {W_i} $ & {\tt WeightSum} & \\
! \hline
! \end{tabular}
! \end{center}
!
! !INTERFACE:

 subroutine MergeTwoGGSP_(inAv1, iMaskTags1, rMaskTags1, &
                        inAv2, iMaskTags2, rMaskTags2, &
                        GGrid, CheckMasks, outAv, WeightSum)
!
! !USES:
!
      use m_stdio
      use m_die

      use m_realkinds, only : SP, FP

      use m_List, only : List
      use m_List, only : List_allocated => allocated

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)    :: inAv1
      character(len=*),   optional, intent(IN)    :: iMaskTags1
      character(len=*),   optional, intent(IN)    :: rMaskTags1
      type(AttrVect),               intent(IN)    :: inAv2
      character(len=*),   optional, intent(IN)    :: iMaskTags2
      character(len=*),   optional, intent(IN)    :: rMaskTags2
      type(GeneralGrid),            intent(IN)    :: GGrid
      logical,                      intent(IN)    :: CheckMasks

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(INOUT) :: outAv
      real(SP),       dimension(:), pointer       :: WeightSum

! !REVISION HISTORY:
!       19Jun02 - Jay Larson <larson@mcs.anl.gov> - Interface spec.
!        3Jul02 - Jay Larson <larson@mcs.anl.gov> - Implementation.
!       10Jul02 - J. Larson <larson@mcs.anl.gov> - Improved argument
!                 checking.
!EOP ___________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::MergeTwoGGSP_'

  integer :: i, j
  real(FP) :: invWeightSum

       ! Begin argument sanity checks...

       ! Have the input arguments been allocated?

  if(.not.(List_allocated(inAv1%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv1 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(inAv2%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv2 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(outaV%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUTPUT argument outAv has no real attributes!'
     call die(myname_)
  endif

  if(present(iMaskTags1) .or. present(iMaskTags2)) then
     if(.not.(List_allocated(GGrid%data%iList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Integer masking requested, but input argument GGrid ', &
	     'has no integer attributes!'
	call die(myname_)
     endif
  endif

  if(present(rMaskTags1) .or. present(rMaskTags2)) then
     if(.not.(List_allocated(GGrid%data%rList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Real masking requested, but input argument GGrid ', &
	     'has no real attributes!'
	call die(myname_)
     endif
  endif

  if(.not.(associated(WeightSum))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUPUT argument WeightSum has not been allocated!'
     call die(myname_)
  endif

       ! Do the vector lengths match?

  if(AttrVect_lsize(inAv1) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv1 and outAv must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv2) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv2 and outAv must match.', &
	  'AttrVect_lsize(inAv2) = ',AttrVect_lsize(inAv2), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv1) /= GeneralGrid_lsize(GGrid)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv1 and GGrid must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'AttrVect_lsize(outAv) = ',GeneralGrid_lsize(GGrid)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv1) /= size(WeightSum)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv1 and WeightSum must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'size(WeightSum) = ',size(WeightSum)
     call die(myname_)
  endif

       ! ...end argument sanity checks.

       ! Initialize the elements of WeightSum(:) to zero:

  do i=1,size(WeightSum)
     WeightSum(i) = 0._FP
  end do

       ! Process the incoming data one input AttrVect and mask tag
       ! combination at a time.

       ! First input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags1 and
       ! rMaskTags1.

  if(present(iMaskTags1)) then

     if(present(rMaskTags1)) then ! both real and integer masks
	call MergeInDataGGSP_(inAv1, iMaskTags1, rMaskTags1, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGSP_(inAv1, iMaskTags=iMaskTags1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags1)) then ! only real masks
	call MergeInDataGGSP_(inAv1, rMaskTags=rMaskTags1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGSP_(inAv1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags1))...

       ! Second input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags2 and
       ! rMaskTags2.

  if(present(iMaskTags2)) then

     if(present(rMaskTags2)) then ! both real and integer masks
	call MergeInDataGGSP_(inAv2, iMaskTags2, rMaskTags2, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGSP_(inAv2, iMaskTags=iMaskTags2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags2)) then ! only real masks
	call MergeInDataGGSP_(inAv2, rMaskTags=rMaskTags2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGSP_(inAv2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags2))...

       ! Now we must renormalize the entries in outAv by dividing
       ! element-by-element by the sums of the merge weights, which
       ! were accumulated in WeightSum(:)

  do i=1,AttrVect_lsize(outAv)

     if(WeightSum(i) /= 0._FP) then
	invWeightSum = 1._FP / WeightSum(i)
     else
	write(stderr,'(2a,i8,a)') myname_,':: FATAL--WeightSum(', &
	                          i,') is zero!'
	call die(myname_)
     endif

     do j=1,AttrVect_nRAttr(outAv)
	outAv%rAttr(j,i) = invWeightSum * outAv%rAttr(j,i)
     end do

  end do

       ! The merge is now complete.

 end subroutine MergeTwoGGSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
!
! !IROUTINE: MergeTwoGGDP_ - merge data from two components.
!
! !DESCRIPTION:
! Double precision version of MergeTwoGGSP_
!
! !INTERFACE:

 subroutine MergeTwoGGDP_(inAv1, iMaskTags1, rMaskTags1, &
                        inAv2, iMaskTags2, rMaskTags2, &
                        GGrid, CheckMasks, outAv, WeightSum)
!
! !USES:
!
      use m_stdio
      use m_die

      use m_realkinds, only : DP, FP

      use m_List, only : List
      use m_List, only : List_allocated => allocated

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)    :: inAv1
      character(len=*),   optional, intent(IN)    :: iMaskTags1
      character(len=*),   optional, intent(IN)    :: rMaskTags1
      type(AttrVect),               intent(IN)    :: inAv2
      character(len=*),   optional, intent(IN)    :: iMaskTags2
      character(len=*),   optional, intent(IN)    :: rMaskTags2
      type(GeneralGrid),            intent(IN)    :: GGrid
      logical,                      intent(IN)    :: CheckMasks

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(INOUT) :: outAv
      real(DP),       dimension(:), pointer       :: WeightSum

! !REVISION HISTORY:
!       19Jun02 - Jay Larson <larson@mcs.anl.gov> - Interface spec.
!        3Jul02 - Jay Larson <larson@mcs.anl.gov> - Implementation.
!       10Jul02 - J. Larson <larson@mcs.anl.gov> - Improved argument
!                 checking.
!_______________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::MergeTwoGGDP_'

  integer :: i, j
  real(FP) :: invWeightSum

       ! Begin argument sanity checks...

       ! Have the input arguments been allocated?

  if(.not.(List_allocated(inAv1%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv1 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(inAv2%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv2 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(outaV%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUTPUT argument outAv has no real attributes!'
     call die(myname_)
  endif

  if(present(iMaskTags1) .or. present(iMaskTags2)) then
     if(.not.(List_allocated(GGrid%data%iList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Integer masking requested, but input argument GGrid ', &
	     'has no integer attributes!'
	call die(myname_)
     endif
  endif

  if(present(rMaskTags1) .or. present(rMaskTags2)) then
     if(.not.(List_allocated(GGrid%data%rList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Real masking requested, but input argument GGrid ', &
	     'has no real attributes!'
	call die(myname_)
     endif
  endif

  if(.not.(associated(WeightSum))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUPUT argument WeightSum has not been allocated!'
     call die(myname_)
  endif

       ! Do the vector lengths match?

  if(AttrVect_lsize(inAv1) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv1 and outAv must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv2) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv2 and outAv must match.', &
	  'AttrVect_lsize(inAv2) = ',AttrVect_lsize(inAv2), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv1) /= GeneralGrid_lsize(GGrid)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv1 and GGrid must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'AttrVect_lsize(outAv) = ',GeneralGrid_lsize(GGrid)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv1) /= size(WeightSum)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv1 and WeightSum must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'size(WeightSum) = ',size(WeightSum)
     call die(myname_)
  endif

       ! ...end argument sanity checks.

       ! Initialize the elements of WeightSum(:) to zero:

  do i=1,size(WeightSum)
     WeightSum(i) = 0._FP
  end do

       ! Process the incoming data one input AttrVect and mask tag
       ! combination at a time.

       ! First input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags1 and
       ! rMaskTags1.

  if(present(iMaskTags1)) then

     if(present(rMaskTags1)) then ! both real and integer masks
	call MergeInDataGGDP_(inAv1, iMaskTags1, rMaskTags1, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGDP_(inAv1, iMaskTags=iMaskTags1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags1)) then ! only real masks
	call MergeInDataGGDP_(inAv1, rMaskTags=rMaskTags1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGDP_(inAv1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags1))...

       ! Second input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags2 and
       ! rMaskTags2.

  if(present(iMaskTags2)) then

     if(present(rMaskTags2)) then ! both real and integer masks
	call MergeInDataGGDP_(inAv2, iMaskTags2, rMaskTags2, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGDP_(inAv2, iMaskTags=iMaskTags2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags2)) then ! only real masks
	call MergeInDataGGDP_(inAv2, rMaskTags=rMaskTags2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGDP_(inAv2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags2))...

       ! Now we must renormalize the entries in outAv by dividing
       ! element-by-element by the sums of the merge weights, which
       ! were accumulated in WeightSum(:)

  do i=1,AttrVect_lsize(outAv)

     if(WeightSum(i) /= 0._FP) then
	invWeightSum = 1._FP / WeightSum(i)
     else
	write(stderr,'(2a,i8,a)') myname_,':: FATAL--WeightSum(', &
	                          i,') is zero!'
	call die(myname_)
     endif

     do j=1,AttrVect_nRAttr(outAv)
	outAv%rAttr(j,i) = invWeightSum * outAv%rAttr(j,i)
     end do

  end do

       ! The merge is now complete.

 end subroutine MergeTwoGGDP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: MergeThreeGGSP_ - Merge Data from Three Sources
!
! !DESCRIPTION:  This routine merges {\tt REAL} attribute data from
! three input {\tt AttrVect} arguments {\tt inAv1} , {\tt inAv2}, and
! {\tt inAv3} to a fourth {\tt AttrVect} {\tt outAv}.  The attributes to
! be merged are determined entirely by the real attributes of {\tt outAv}.
!   If {\tt outAv} shares one or more attributes with any of the inputs
! {\tt inAv1}, {\tt inAv2}, or {\tt inAv3}, a merge is performed on the
! individual {\em intersections} of attributes between the pairs
! $({\tt outAv},{\tt inAv1})$,  $({\tt outAv},{\tt inAv2})$,
! and $({\tt outAv},{\tt inAv3})$.  Currently, it is assumed that these
! pairwise intersections are all equal.  This assumption is of
! critical importance to the user.  If the user violates this
! assumption, incorrect merges of any attributes present only in some
! (but not all) inputs will result.
!
! The merge operatrion is a masked
! weighted element-by-element sum, as outlined in the following example.
! Let the vectors ${\bf a}$,${\bf b}$, and ${\bf c}$ be data from
! Components $A$, $B$, and $C$ that have been interpolated onto the
! physical grid of another component $D$.  We wish to combine the data
! from $A$, $B$ and $C$ to get a vector ${\bf d}$, which represents the
! merged data on the grid of component $D$.  The merge relation to obtain
! the $i$th element of ${\bf d}$ is
! $$ d_i = {1 \over {W_i}} \bigg\{ {{\prod_{j=1}^J} \kappa_{i}^j}
! {{\prod_{k=1}^K} \alpha_{i}^k} {a_i} + {{\prod_{l=1}^L} \lambda_{i}^l}
! {{\prod_{m=1}^M} \beta_{i}^m} {b_i} + {{\prod_{p=1}^P} \mu_{i}^p}
! {{\prod_{q=1}^Q} \gamma_{i}^q} {c_i} \bigg\} , $$
! where
! $$ {W_i} = {{\prod_{j=1}^J} \kappa_{i}^j} {{\prod_{k=1}^K} \alpha_{i}^k} +
! {{\prod_{l=1}^L} \lambda_{i}^l} {{\prod_{m=1}^M} \beta_{i}^m} +
! {{\prod_{p=1}^P} \mu_{i}^p} {{\prod_{q=1}^Q} \gamma_{i}^q}. $$
! The quantities ${\kappa_{i}^j}$, ${\lambda_{i}^p}$, and ${\mu_{i}^p}$ are
! {\em integer masks} (which have value either $0$ or $1$), and
! ${\alpha_{i}^k}$, ${\beta_{i}^m}$, and ${\gamma_{i}^q}$ are {\em real
! masks} (which are in the closed interval $[0,1]$).
!
! The integer and real masks are stored as attributes to the same input
! {\tt GeneralGrid} argument {\tt GGrid}.  The mask attribute names are
! stored as substrings to the colon-separated strings contained in the
! input {\tt CHARACTER} arguments {\tt iMaskTags1}, {\tt iMaskTags2},
! {\tt iMaskTags3}, {\tt rMaskTags1}, {\tt rMaskTags2}, and
! {\tt rMaskTags3}.  The {\tt LOGICAL} input argument {\tt CheckMasks}
! governs how the masks are applied.  If ${\tt CheckMasks} = {\tt .TRUE.}$,
! the entries are checked to ensure they meet the definitions of real
! and integer masks.  If ${\tt CheckMasks} = {\tt .FALSE.}$ then the masks
! are multiplied together on an element-by-element basis with no validation
! of their entries (this option results in slightly higher performance).
!
! This routine returns the sum of the masked weights as a diagnostic.
! This quantity is returned in the output {\tt REAL} array {\tt WeightSum}.
!
! The correspondence between the quantities in the above merge relation
! and the arguments to this routine are summarized in the table.
! \begin{center}
! \begin{tabular}{|l|l|l|}\hline
! {\bf Quantity} & {\bf Stored in} & {\bf Referenced by}  \\
!  & {\bf Argument}    & {\bf Argument} \\
! \hline
! \hline
! $ {a_i} $ & {\tt inAv1} & \\
! \hline
! $ {b_i} $ & {\tt inAv2} & \\
! \hline
! $ {c_i} $ & {\tt inAv3} & \\
! \hline
! $ {d_i} $ & {\tt outAv} & \\
! \hline
! $ {\kappa_i^j}, j=1,\ldots,J $ & {\tt GGrid} & {\tt iMaskTags1}\\
! & & ($J$ items) \\
! \hline
! $ {\alpha_i^k}, k=1,\ldots,K $ & {\tt GGrid} & {\tt rMaskTags1}\\
! & & ($K$ items) \\
! \hline
! $ {\lambda_i^l}, l=1,\ldots,L $ & {\tt GGrid} & {\tt iMaskTags2}\\
! & & ($L$ items) \\
! \hline
! $ {\beta_i^m}, m=1,\ldots,M $ & {\tt GGrid} & {\tt rMaskTags2}\\
! & & ($M$ items) \\
! \hline
! $ {\mu_i^p}, p=1,\ldots,P $ & {\tt GGrid} & {\tt iMaskTags3}\\
! & & ($L$ items) \\
! \hline
! $ {\gamma_i^q}, q=1,\ldots,Q $ & {\tt GGrid} & {\tt rMaskTags3}\\
! & & ($M$ items) \\
! \hline
! $ {W_i} $ & {\tt WeightSum} & \\
! \hline
! \end{tabular}
! \end{center}
!
! !INTERFACE:

 subroutine MergeThreeGGSP_(inAv1, iMaskTags1, rMaskTags1, &
                            inAv2, iMaskTags2, rMaskTags2, &
                            inAv3, iMaskTags3, rMaskTags3, &
                            GGrid, CheckMasks, outAv, WeightSum)
!
! !USES:
!
      use m_stdio
      use m_die

      use m_realkinds, only : SP, FP

      use m_List, only : List
      use m_List, only : List_allocated => allocated

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)    :: inAv1
      character(len=*),   optional, intent(IN)    :: iMaskTags1
      character(len=*),   optional, intent(IN)    :: rMaskTags1
      type(AttrVect),               intent(IN)    :: inAv2
      character(len=*),   optional, intent(IN)    :: iMaskTags2
      character(len=*),   optional, intent(IN)    :: rMaskTags2
      type(AttrVect),               intent(IN)    :: inAv3
      character(len=*),   optional, intent(IN)    :: iMaskTags3
      character(len=*),   optional, intent(IN)    :: rMaskTags3
      type(GeneralGrid),            intent(IN)    :: GGrid
      logical,                      intent(IN)    :: CheckMasks

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(INOUT) :: outAv
      real(SP),       dimension(:), pointer       :: WeightSum

! !REVISION HISTORY:
!       19Jun02 - Jay Larson <larson@mcs.anl.gov> - Interface spec.
!        3Jul02 - Jay Larson <larson@mcs.anl.gov> - Implementation.
!       10Jul02 - J. Larson <larson@mcs.anl.gov> - Improved argument
!                 checking.
!EOP ___________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::MergeThreeGGSP_'

  integer :: i, j
  real(FP) :: invWeightSum

       ! Begin argument sanity checks...

       ! Have the input arguments been allocated?

  if(.not.(List_allocated(inAv1%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv1 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(inAv2%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv2 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(inAv3%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv3 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(outaV%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUTPUT argument outAv has no real attributes!'
     call die(myname_)
  endif

  if(present(iMaskTags1) .or. present(iMaskTags2) .or. present(iMaskTags3)) then
     if(.not.(List_allocated(GGrid%data%iList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Integer masking requested, but input argument GGrid ', &
	     'has no integer attributes!'
	call die(myname_)
     endif
  endif

  if(present(rMaskTags1) .or. present(rMaskTags2) .or. present(rMaskTags3)) then
     if(.not.(List_allocated(GGrid%data%rList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Real masking requested, but input argument GGrid ', &
	     'has no real attributes!'
	call die(myname_)
     endif
  endif

  if(.not.(associated(WeightSum))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUPUT argument WeightSum has not been allocated!'
     call die(myname_)
  endif

       ! Do the vector lengths match?

  if(AttrVect_lsize(inAv1) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv1 and outAv must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv2) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv2 and outAv must match.', &
	  'AttrVect_lsize(inAv2) = ',AttrVect_lsize(inAv2), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv3) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv3 and outAv must match.', &
	  'AttrVect_lsize(inAv3) = ',AttrVect_lsize(inAv3), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv1) /= GeneralGrid_lsize(GGrid)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv1 and GGrid must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'AttrVect_lsize(outAv) = ',GeneralGrid_lsize(GGrid)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv1) /= size(WeightSum)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv1 and WeightSum must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'size(WeightSum) = ',size(WeightSum)
     call die(myname_)
  endif

       ! ...end argument sanity checks.

       ! Initialize the elements of WeightSum(:) to zero:

  do i=1,size(WeightSum)
     WeightSum(i) = 0._FP
  end do

       ! Process the incoming data one input AttrVect and mask tag
       ! combination at a time.

       ! First input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags1 and
       ! rMaskTags1.

  if(present(iMaskTags1)) then

     if(present(rMaskTags1)) then ! both real and integer masks
	call MergeInDataGGSP_(inAv1, iMaskTags1, rMaskTags1, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGSP_(inAv1, iMaskTags=iMaskTags1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags1)) then ! only real masks
	call MergeInDataGGSP_(inAv1, rMaskTags=rMaskTags1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGSP_(inAv1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags1))...

       ! Second input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags2 and
       ! rMaskTags2.

  if(present(iMaskTags2)) then

     if(present(rMaskTags2)) then ! both real and integer masks
	call MergeInDataGGSP_(inAv2, iMaskTags2, rMaskTags2, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGSP_(inAv2, iMaskTags=iMaskTags2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags2)) then ! only real masks
	call MergeInDataGGSP_(inAv2, rMaskTags=rMaskTags2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGSP_(inAv2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags2))...

       ! Third input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags3 and
       ! rMaskTags3.

  if(present(iMaskTags3)) then

     if(present(rMaskTags3)) then ! both real and integer masks
	call MergeInDataGGSP_(inAv3, iMaskTags3, rMaskTags3, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGSP_(inAv3, iMaskTags=iMaskTags3, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags3)) then ! only real masks
	call MergeInDataGGSP_(inAv3, rMaskTags=rMaskTags3, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGSP_(inAv3, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags3))...

       ! Now we must renormalize the entries in outAv by dividing
       ! element-by-element by the sums of the merge weights, which
       ! were accumulated in WeightSum(:)

  do i=1,AttrVect_lsize(outAv)

     if(WeightSum(i) /= 0._FP) then
	invWeightSum = 1._FP / WeightSum(i)
     else
	write(stderr,'(2a,i8,a)') myname_,':: FATAL--WeightSum(', &
	                          i,') is zero!'
	call die(myname_)
     endif

     do j=1,AttrVect_nRAttr(outAv)
	outAv%rAttr(j,i) = invWeightSum * outAv%rAttr(j,i)
     end do

  end do

       ! The merge is now complete.

 end subroutine MergeThreeGGSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
!
! !IROUTINE: MergeThreeGGDP_ - merge data from three components.
!
! !DESCRIPTION:
! Double precision version of MergeThreeGGSP_
!
! !INTERFACE:

 subroutine MergeThreeGGDP_(inAv1, iMaskTags1, rMaskTags1, &
                            inAv2, iMaskTags2, rMaskTags2, &
                            inAv3, iMaskTags3, rMaskTags3, &
                            GGrid, CheckMasks, outAv, WeightSum)
!
! !USES:
!
      use m_stdio
      use m_die

      use m_realkinds, only : DP, FP

      use m_List, only : List
      use m_List, only : List_allocated => allocated

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)    :: inAv1
      character(len=*),   optional, intent(IN)    :: iMaskTags1
      character(len=*),   optional, intent(IN)    :: rMaskTags1
      type(AttrVect),               intent(IN)    :: inAv2
      character(len=*),   optional, intent(IN)    :: iMaskTags2
      character(len=*),   optional, intent(IN)    :: rMaskTags2
      type(AttrVect),               intent(IN)    :: inAv3
      character(len=*),   optional, intent(IN)    :: iMaskTags3
      character(len=*),   optional, intent(IN)    :: rMaskTags3
      type(GeneralGrid),            intent(IN)    :: GGrid
      logical,                      intent(IN)    :: CheckMasks

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(INOUT) :: outAv
      real(DP),       dimension(:), pointer       :: WeightSum

! !REVISION HISTORY:
!       19Jun02 - Jay Larson <larson@mcs.anl.gov> - Interface spec.
!        3Jul02 - Jay Larson <larson@mcs.anl.gov> - Implementation.
!       10Jul02 - J. Larson <larson@mcs.anl.gov> - Improved argument
!                 checking.
!_______________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::MergeThreeGGDP_'

  integer :: i, j
  real(FP) :: invWeightSum

       ! Begin argument sanity checks...

       ! Have the input arguments been allocated?

  if(.not.(List_allocated(inAv1%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv1 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(inAv2%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv2 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(inAv3%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv3 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(outaV%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUTPUT argument outAv has no real attributes!'
     call die(myname_)
  endif

  if(present(iMaskTags1) .or. present(iMaskTags2) .or. present(iMaskTags3)) then
     if(.not.(List_allocated(GGrid%data%iList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Integer masking requested, but input argument GGrid ', &
	     'has no integer attributes!'
	call die(myname_)
     endif
  endif

  if(present(rMaskTags1) .or. present(rMaskTags2) .or. present(rMaskTags3)) then
     if(.not.(List_allocated(GGrid%data%rList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Real masking requested, but input argument GGrid ', &
	     'has no real attributes!'
	call die(myname_)
     endif
  endif

  if(.not.(associated(WeightSum))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUPUT argument WeightSum has not been allocated!'
     call die(myname_)
  endif

       ! Do the vector lengths match?

  if(AttrVect_lsize(inAv1) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv1 and outAv must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv2) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv2 and outAv must match.', &
	  'AttrVect_lsize(inAv2) = ',AttrVect_lsize(inAv2), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv3) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv3 and outAv must match.', &
	  'AttrVect_lsize(inAv3) = ',AttrVect_lsize(inAv3), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv1) /= GeneralGrid_lsize(GGrid)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv1 and GGrid must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'AttrVect_lsize(outAv) = ',GeneralGrid_lsize(GGrid)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv1) /= size(WeightSum)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv1 and WeightSum must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'size(WeightSum) = ',size(WeightSum)
     call die(myname_)
  endif

       ! ...end argument sanity checks.

       ! Initialize the elements of WeightSum(:) to zero:

  do i=1,size(WeightSum)
     WeightSum(i) = 0._FP
  end do

       ! Process the incoming data one input AttrVect and mask tag
       ! combination at a time.

       ! First input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags1 and
       ! rMaskTags1.

  if(present(iMaskTags1)) then

     if(present(rMaskTags1)) then ! both real and integer masks
	call MergeInDataGGDP_(inAv1, iMaskTags1, rMaskTags1, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGDP_(inAv1, iMaskTags=iMaskTags1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags1)) then ! only real masks
	call MergeInDataGGDP_(inAv1, rMaskTags=rMaskTags1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGDP_(inAv1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags1))...

       ! Second input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags2 and
       ! rMaskTags2.

  if(present(iMaskTags2)) then

     if(present(rMaskTags2)) then ! both real and integer masks
	call MergeInDataGGDP_(inAv2, iMaskTags2, rMaskTags2, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGDP_(inAv2, iMaskTags=iMaskTags2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags2)) then ! only real masks
	call MergeInDataGGDP_(inAv2, rMaskTags=rMaskTags2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGDP_(inAv2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags2))...

       ! Third input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags3 and
       ! rMaskTags3.

  if(present(iMaskTags3)) then

     if(present(rMaskTags3)) then ! both real and integer masks
	call MergeInDataGGDP_(inAv3, iMaskTags3, rMaskTags3, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGDP_(inAv3, iMaskTags=iMaskTags3, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags3)) then ! only real masks
	call MergeInDataGGDP_(inAv3, rMaskTags=rMaskTags3, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGDP_(inAv3, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags3))...

       ! Now we must renormalize the entries in outAv by dividing
       ! element-by-element by the sums of the merge weights, which
       ! were accumulated in WeightSum(:)

  do i=1,AttrVect_lsize(outAv)

     if(WeightSum(i) /= 0._FP) then
	invWeightSum = 1._FP / WeightSum(i)
     else
	write(stderr,'(2a,i8,a)') myname_,':: FATAL--WeightSum(', &
	                          i,') is zero!'
	call die(myname_)
     endif

     do j=1,AttrVect_nRAttr(outAv)
	outAv%rAttr(j,i) = invWeightSum * outAv%rAttr(j,i)
     end do

  end do

       ! The merge is now complete.

 end subroutine MergeThreeGGDP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: MergeFourGGSP_ - Merge Data from Four Sources
!
! !DESCRIPTION:  This routine merges {\tt REAL} attribute data from
! four input {\tt AttrVect} arguments {\tt inAv1} , {\tt inAv2},
! {\tt inAv3}, and {\tt inAv4} to a fifth {\tt AttrVect} {\tt outAv}.  The
! attributes to be merged are determined entirely by the real attributes
! of {\tt outAv}.  If {\tt outAv} shares one or more attributes with any of
! the inputs {\tt inAv1}, {\tt inAv2}, {\tt inAv3}, or {\tt inAv4}, a merge
! is performed on the individual {\em intersections} of attributes between
! the pairs $({\tt outAv},{\tt inAv1})$,  $({\tt outAv},{\tt inAv2})$,
! $({\tt outAv},{\tt inAv3})$, and $({\tt outAv},{\tt inAv3})$.  Currently,
! it is assumed that these pairwise intersections are all equal.  This
! assumption is of critical importance to the user.  If the user violates
! this assumption, incorrect merges of any attributes present only in some
! (but not all) the inputs will result.
!
! The merge operatrion is a masked
! weighted element-by-element sum, as outlined in the following example.
! Let the vectors ${\bf a}$,${\bf b}$, ${\bf c}$ and ${\bf d}$ be data from
! Components $A$, $B$, $C$, and $D$ that have been interpolated onto the
! physical grid of another component $E$.  We wish to combine the data
! from $A$, $B$, $C$, and $D$ to get a vector ${\bf e}$, which represents the
! merged data on the grid of component $E$.  The merge relation to obtain
! the $i$th element of {\bf e} is
! $$ e_i = {1 \over {W_i}} \bigg\{ {{\prod_{j=1}^J} \kappa_{i}^j}
! {{\prod_{k=1}^K} \alpha_{i}^k} {a_i} + {{\prod_{l=1}^L} \lambda_{i}^l}
! {{\prod_{m=1}^M} \beta_{i}^m} {b_i} + {{\prod_{p=1}^P} \mu_{i}^p}
! {{\prod_{q=1}^Q} \gamma_{i}^q} {c_i} +
! {{\prod_{r=1}^R} \nu_{i}^r} {{\prod_{s=1}^S} \delta_{i}^s} {d_i} \bigg\} , $$
! where
! $$ {W_i} = {{\prod_{j=1}^J} \kappa_{i}^j} {{\prod_{k=1}^K} \alpha_{i}^k} +
! {{\prod_{l=1}^L} \lambda_{i}^l} {{\prod_{m=1}^M} \beta_{i}^m} +
! {{\prod_{p=1}^P} \mu_{i}^p} {{\prod_{q=1}^Q} \gamma_{i}^q} +
! {{\prod_{r=1}^R} \nu_{i}^r} {{\prod_{s=1}^S} \delta_{i}^s}. $$
! The quantities ${\kappa_{i}^j}$, ${\lambda_{i}^p}$, ${\mu_{i}^p}$, and
! ${\nu_{i}^r}$ are {\em integer masks} (which have value either $0$ or $1$),
! and ${\alpha_{i}^k}$, ${\beta_{i}^m}$, ${\gamma_{i}^q}$, and ${\delta_{i}^s}$
! are {\em real masks} (which are in the closed interval $[0,1]$).
!
! The integer and real masks are stored as attributes to the same input
! {\tt GeneralGrid} argument {\tt GGrid}.  The mask attribute names are
! stored as substrings to the colon-separated strings contained in the
! input {\tt CHARACTER} arguments {\tt iMaskTags1}, {\tt iMaskTags2},
! {\tt iMaskTags3}, {\tt iMaskTags4}, {\tt rMaskTags1}, and {\tt rMaskTags2},
! {\tt rMaskTags3}, and {\tt rMaskTags4}, .  The {\tt LOGICAL} input
! argument {\tt CheckMasks} governs how the masks are applied.    If
! ${\tt CheckMasks} = {\tt .TRUE.}$, the entries are checked to ensure
! they meet the definitions of real and integer masks.  If ${\tt CheckMasks}
! = {\tt .FALSE.}$ then the masks are multiplied together on an
! element-by-element basis with no validation of their entries (this option
! results in slightly higher performance).
!
! This routine returns the sume of the masked weights as a diagnostic.
! This quantity is returned in the output {\tt REAL} array {\tt WeightSum}.
!
! The correspondence between the quantities in the above merge relation
! and the arguments to this routine are summarized in the table.
! \begin{center}
! \begin{tabular}{|l|l|l|}\hline
! {\bf Quantity} & {\bf Stored in} & {\bf Referenced by}  \\
!  & {\bf Argument}    & {\bf Argument} \\
! \hline
! \hline
! $ {a_i} $ & {\tt inAv1} & \\
! \hline
! $ {b_i} $ & {\tt inAv2} & \\
! \hline
! $ {c_i} $ & {\tt inAv3} & \\
! \hline
! $ {d_i} $ & {\tt inAv4} & \\
! \hline
! $ {e_i} $ & {\tt outAv} & \\
! \hline
! $ {\kappa_i^j}, j=1,\ldots,J $ & {\tt GGrid} & {\tt iMaskTags1}\\
! & & ($J$ items) \\
! \hline
! $ {\alpha_i^k}, k=1,\ldots,K $ & {\tt GGrid} & {\tt rMaskTags1}\\
! & & ($K$ items) \\
! \hline
! $ {\lambda_i^l}, l=1,\ldots,L $ & {\tt GGrid} & {\tt iMaskTags2}\\
! & & ($L$ items) \\
! \hline
! $ {\beta_i^m}, m=1,\ldots,M $ & {\tt GGrid} & {\tt rMaskTags2}\\
! & & ($M$ items) \\
! \hline
! $ {\mu_i^p}, p=1,\ldots,P $ & {\tt GGrid} & {\tt iMaskTags3}\\
! & & ($L$ items) \\
! \hline
! $ {\gamma_i^q}, q=1,\ldots,Q $ & {\tt GGrid} & {\tt rMaskTags3}\\
! & & ($M$ items) \\
! \hline
! $ {\nu_i^r}, r=1,\ldots,R $ & {\tt GGrid} & {\tt iMaskTags4}\\
! & & ($L$ items) \\
! \hline
! $ {\delta_i^s}, s=1,\ldots,S $ & {\tt GGrid} & {\tt rMaskTags4}\\
! & & ($M$ items) \\
! \hline
! $ {W_i} $ & {\tt WeightSum} & \\
! \hline
! \end{tabular}
! \end{center}
!
! !INTERFACE:

 subroutine MergeFourGGSP_(inAv1, iMaskTags1, rMaskTags1, &
                           inAv2, iMaskTags2, rMaskTags2, &
                           inAv3, iMaskTags3, rMaskTags3, &
                           inAv4, iMaskTags4, rMaskTags4, &
                           GGrid, CheckMasks, outAv, WeightSum)
!
! !USES:
!
      use m_stdio
      use m_die

      use m_realkinds, only : SP, FP

      use m_List, only : List
      use m_List, only : List_allocated => allocated

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)    :: inAv1
      character(len=*),   optional, intent(IN)    :: iMaskTags1
      character(len=*),   optional, intent(IN)    :: rMaskTags1
      type(AttrVect),               intent(IN)    :: inAv2
      character(len=*),   optional, intent(IN)    :: iMaskTags2
      character(len=*),   optional, intent(IN)    :: rMaskTags2
      type(AttrVect),               intent(IN)    :: inAv3
      character(len=*),   optional, intent(IN)    :: iMaskTags3
      character(len=*),   optional, intent(IN)    :: rMaskTags3
      type(AttrVect),               intent(IN)    :: inAv4
      character(len=*),   optional, intent(IN)    :: iMaskTags4
      character(len=*),   optional, intent(IN)    :: rMaskTags4
      type(GeneralGrid),            intent(IN)    :: GGrid
      logical,                      intent(IN)    :: CheckMasks

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(INOUT) :: outAv
      real(SP),       dimension(:), pointer       :: WeightSum

! !REVISION HISTORY:
!       19Jun02 - Jay Larson <larson@mcs.anl.gov> - Interface spec.
!        3Jul02 - Jay Larson <larson@mcs.anl.gov> - Implementation.
!       10Jul02 - J. Larson <larson@mcs.anl.gov> - Improved argument
!                 checking.
!EOP ___________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::MergeFourGGSP_'

  integer :: i, j
  real(FP) :: invWeightSum

       ! Begin argument sanity checks...

       ! Have the input arguments been allocated?

  if(.not.(List_allocated(inAv1%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv1 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(inAv2%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv2 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(inAv3%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv3 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(inAv4%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv4 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(outaV%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUTPUT argument outAv has no real attributes!'
     call die(myname_)
  endif

  if(present(iMaskTags1) .or. present(iMaskTags2) .or. &
                        present(iMaskTags3) .or. present(iMaskTags4)) then
     if(.not.(List_allocated(GGrid%data%iList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Integer masking requested, but input argument GGrid ', &
	     'has no integer attributes!'
	call die(myname_)
     endif
  endif

  if(present(rMaskTags1) .or. present(rMaskTags2) .or. &
                        present(rMaskTags3) .or. present(rMaskTags4)) then
     if(.not.(List_allocated(GGrid%data%rList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Real masking requested, but input argument GGrid ', &
	     'has no real attributes!'
	call die(myname_)
     endif
  endif

  if(.not.(associated(WeightSum))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUPUT argument WeightSum has not been allocated!'
     call die(myname_)
  endif

       ! Do the vector lengths match?

  if(AttrVect_lsize(inAv1) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv1 and outAv must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv2) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv2 and outAv must match.', &
	  'AttrVect_lsize(inAv2) = ',AttrVect_lsize(inAv2), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv3) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv3 and outAv must match.', &
	  'AttrVect_lsize(inAv3) = ',AttrVect_lsize(inAv3), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv4) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv4 and outAv must match.', &
	  'AttrVect_lsize(inAv4) = ',AttrVect_lsize(inAv4), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv1) /= GeneralGrid_lsize(GGrid)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv1 and GGrid must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'AttrVect_lsize(outAv) = ',GeneralGrid_lsize(GGrid)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv1) /= size(WeightSum)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv1 and WeightSum must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'size(WeightSum) = ',size(WeightSum)
     call die(myname_)
  endif

       ! ...end argument sanity checks.

       ! Initialize the elements of WeightSum(:) to zero:

  do i=1,size(WeightSum)
     WeightSum(i) = 0._FP
  end do

       ! Process the incoming data one input AttrVect and mask tag
       ! combination at a time.

       ! First input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags1 and
       ! rMaskTags1.

  if(present(iMaskTags1)) then

     if(present(rMaskTags1)) then ! both real and integer masks
	call MergeInDataGGSP_(inAv1, iMaskTags1, rMaskTags1, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGSP_(inAv1, iMaskTags=iMaskTags1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags1)) then ! only real masks
	call MergeInDataGGSP_(inAv1, rMaskTags=rMaskTags1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGSP_(inAv1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags1))...

       ! Second input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags2 and
       ! rMaskTags2.

  if(present(iMaskTags2)) then

     if(present(rMaskTags2)) then ! both real and integer masks
	call MergeInDataGGSP_(inAv2, iMaskTags2, rMaskTags2, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGSP_(inAv2, iMaskTags=iMaskTags2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags2)) then ! only real masks
	call MergeInDataGGSP_(inAv2, rMaskTags=rMaskTags2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGSP_(inAv2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags2))...

       ! Third input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags3 and
       ! rMaskTags3.

  if(present(iMaskTags3)) then

     if(present(rMaskTags3)) then ! both real and integer masks
	call MergeInDataGGSP_(inAv3, iMaskTags3, rMaskTags3, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGSP_(inAv3, iMaskTags=iMaskTags3, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags3)) then ! only real masks
	call MergeInDataGGSP_(inAv3, rMaskTags=rMaskTags3, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGSP_(inAv3, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags3))...

       ! Fourth input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags4 and
       ! rMaskTags4.

  if(present(iMaskTags4)) then

     if(present(rMaskTags4)) then ! both real and integer masks
	call MergeInDataGGSP_(inAv4, iMaskTags4, rMaskTags4, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGSP_(inAv4, iMaskTags=iMaskTags4, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags4)) then ! only real masks
	call MergeInDataGGSP_(inAv4, rMaskTags=rMaskTags4, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGSP_(inAv4, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags4))...

       ! Now we must renormalize the entries in outAv by dividing
       ! element-by-element by the sums of the merge weights, which
       ! were accumulated in WeightSum(:)

  do i=1,AttrVect_lsize(outAv)

     if(WeightSum(i) /= 0._FP) then
	invWeightSum = 1._FP / WeightSum(i)
     else
	write(stderr,'(2a,i8,a)') myname_,':: FATAL--WeightSum(', &
	                          i,') is zero!'
	call die(myname_)
     endif

     do j=1,AttrVect_nRAttr(outAv)
	outAv%rAttr(j,i) = invWeightSum * outAv%rAttr(j,i)
     end do

  end do

       ! The merge is now complete.

 end subroutine MergeFourGGSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
!
! !IROUTINE: MergeFourGGDP_ - merge data from four components.
!
! !DESCRIPTION:
! Double precision versions of MergeFourGGSP_
!
! !INTERFACE:

 subroutine MergeFourGGDP_(inAv1, iMaskTags1, rMaskTags1, &
                           inAv2, iMaskTags2, rMaskTags2, &
                           inAv3, iMaskTags3, rMaskTags3, &
                           inAv4, iMaskTags4, rMaskTags4, &
                           GGrid, CheckMasks, outAv, WeightSum)
!
! !USES:
!
      use m_stdio
      use m_die

      use m_realkinds, only : DP, FP

      use m_List, only : List
      use m_List, only : List_allocated => allocated

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)    :: inAv1
      character(len=*),   optional, intent(IN)    :: iMaskTags1
      character(len=*),   optional, intent(IN)    :: rMaskTags1
      type(AttrVect),               intent(IN)    :: inAv2
      character(len=*),   optional, intent(IN)    :: iMaskTags2
      character(len=*),   optional, intent(IN)    :: rMaskTags2
      type(AttrVect),               intent(IN)    :: inAv3
      character(len=*),   optional, intent(IN)    :: iMaskTags3
      character(len=*),   optional, intent(IN)    :: rMaskTags3
      type(AttrVect),               intent(IN)    :: inAv4
      character(len=*),   optional, intent(IN)    :: iMaskTags4
      character(len=*),   optional, intent(IN)    :: rMaskTags4
      type(GeneralGrid),            intent(IN)    :: GGrid
      logical,                      intent(IN)    :: CheckMasks

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(INOUT) :: outAv
      real(DP),       dimension(:), pointer       :: WeightSum

! !REVISION HISTORY:
!       19Jun02 - Jay Larson <larson@mcs.anl.gov> - Interface spec.
!        3Jul02 - Jay Larson <larson@mcs.anl.gov> - Implementation.
!       10Jul02 - J. Larson <larson@mcs.anl.gov> - Improved argument
!                 checking.
!_______________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::MergeFourGGDP_'

  integer :: i, j
  real(FP) :: invWeightSum

       ! Begin argument sanity checks...

       ! Have the input arguments been allocated?

  if(.not.(List_allocated(inAv1%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv1 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(inAv2%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv2 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(inAv3%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv3 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(inAv4%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv4 has no real attributes!'
     call die(myname_)
  endif

  if(.not.(List_allocated(outaV%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUTPUT argument outAv has no real attributes!'
     call die(myname_)
  endif

  if(present(iMaskTags1) .or. present(iMaskTags2) .or. &
                        present(iMaskTags3) .or. present(iMaskTags4)) then
     if(.not.(List_allocated(GGrid%data%iList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Integer masking requested, but input argument GGrid ', &
	     'has no integer attributes!'
	call die(myname_)
     endif
  endif

  if(present(rMaskTags1) .or. present(rMaskTags2) .or. &
                        present(rMaskTags3) .or. present(rMaskTags4)) then
     if(.not.(List_allocated(GGrid%data%rList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Real masking requested, but input argument GGrid ', &
	     'has no real attributes!'
	call die(myname_)
     endif
  endif

  if(.not.(associated(WeightSum))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUPUT argument WeightSum has not been allocated!'
     call die(myname_)
  endif

       ! Do the vector lengths match?

  if(AttrVect_lsize(inAv1) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv1 and outAv must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv2) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv2 and outAv must match.', &
	  'AttrVect_lsize(inAv2) = ',AttrVect_lsize(inAv2), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv3) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv3 and outAv must match.', &
	  'AttrVect_lsize(inAv3) = ',AttrVect_lsize(inAv3), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv4) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv4 and outAv must match.', &
	  'AttrVect_lsize(inAv4) = ',AttrVect_lsize(inAv4), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv1) /= GeneralGrid_lsize(GGrid)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv1 and GGrid must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'AttrVect_lsize(outAv) = ',GeneralGrid_lsize(GGrid)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv1) /= size(WeightSum)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv1 and WeightSum must match.', &
	  'AttrVect_lsize(inAv1) = ',AttrVect_lsize(inAv1), &
	  'size(WeightSum) = ',size(WeightSum)
     call die(myname_)
  endif

       ! ...end argument sanity checks.

       ! Initialize the elements of WeightSum(:) to zero:

  do i=1,size(WeightSum)
     WeightSum(i) = 0._FP
  end do

       ! Process the incoming data one input AttrVect and mask tag
       ! combination at a time.

       ! First input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags1 and
       ! rMaskTags1.

  if(present(iMaskTags1)) then

     if(present(rMaskTags1)) then ! both real and integer masks
	call MergeInDataGGDP_(inAv1, iMaskTags1, rMaskTags1, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGDP_(inAv1, iMaskTags=iMaskTags1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags1)) then ! only real masks
	call MergeInDataGGDP_(inAv1, rMaskTags=rMaskTags1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGDP_(inAv1, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags1))...

       ! Second input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags2 and
       ! rMaskTags2.

  if(present(iMaskTags2)) then

     if(present(rMaskTags2)) then ! both real and integer masks
	call MergeInDataGGDP_(inAv2, iMaskTags2, rMaskTags2, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGDP_(inAv2, iMaskTags=iMaskTags2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags2)) then ! only real masks
	call MergeInDataGGDP_(inAv2, rMaskTags=rMaskTags2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGDP_(inAv2, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags2))...

       ! Third input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags3 and
       ! rMaskTags3.

  if(present(iMaskTags3)) then

     if(present(rMaskTags3)) then ! both real and integer masks
	call MergeInDataGGDP_(inAv3, iMaskTags3, rMaskTags3, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGDP_(inAv3, iMaskTags=iMaskTags3, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags3)) then ! only real masks
	call MergeInDataGGDP_(inAv3, rMaskTags=rMaskTags3, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGDP_(inAv3, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags3))...

       ! Fourth input AttrVect/mask combination...must work through
       ! all the possible cases for optional arguments iMaskTags4 and
       ! rMaskTags4.

  if(present(iMaskTags4)) then

     if(present(rMaskTags4)) then ! both real and integer masks
	call MergeInDataGGDP_(inAv4, iMaskTags4, rMaskTags4, GGrid, &
                            CheckMasks, outAv, WeightSum)
     else ! only integer masks
	call MergeInDataGGDP_(inAv4, iMaskTags=iMaskTags4, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  else

     if(present(rMaskTags4)) then ! only real masks
	call MergeInDataGGDP_(inAv4, rMaskTags=rMaskTags4, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     else ! no masks at all
	call MergeInDataGGDP_(inAv4, GGrid=GGrid, &
                            CheckMasks=CheckMasks, outAv=outAv, &
			    WeightSum=WeightSum)
     endif

  endif ! if(present(iMaskTags4))...

       ! Now we must renormalize the entries in outAv by dividing
       ! element-by-element by the sums of the merge weights, which
       ! were accumulated in WeightSum(:)

  do i=1,AttrVect_lsize(outAv)

     if(WeightSum(i) /= 0._FP) then
	invWeightSum = 1._FP / WeightSum(i)
     else
	write(stderr,'(2a,i8,a)') myname_,':: FATAL--WeightSum(', &
	                          i,') is zero!'
	call die(myname_)
     endif

     do j=1,AttrVect_nRAttr(outAv)
	outAv%rAttr(j,i) = invWeightSum * outAv%rAttr(j,i)
     end do

  end do

       ! The merge is now complete.

 end subroutine MergeFourGGDP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: MergeInDataGGSP_ - Add Data into a Merge
!
! !DESCRIPTION:  This routine takes input field data from the input
! {\tt AttrVect} argument {\tt inAv}, and merges the real attributes it
! shares with the input/output {\tt AttrVect} argument {\tt outAv}.
! The merge is a masked merge of the form
! $$ c_i = c_i + {{\prod_{j=1}^J} M_{i}^j} {{\prod_{k=1}^K} F_{i}^k}
! a_i , $$
! where ${c_i}$ represents one element of one of the real attributes of
! {\tt outAv}, and ${a_i}$ represents one element of one of the real
! attributes of {\tt inAv}.  The ${M_{i}^j}$ are {\em integer masks} which
! have value either $0$ or $1$, and are integer attributes of the input
! {\tt GeneralGrid} argument {\tt GGrid}.  The ${F_{i}^k}$ are {\em real
! masks} whose values are in the closed interval $[0,1]$, and are real
! attributes of the input {\tt GeneralGrid} argument {\tt GGrid}.  The
! input {\tt CHARACTER} argument {\tt iMaskTags} is a string of colon-
! delimited strings that name the integer attributes in {\tt GGrid}
! that are used as the masks ${M_{i}^j}$.  The input {\tt CHARACTER}
! argument {\tt rMaskTags} is a string of colon-delimited strings
! that name the real attributes in {\tt GGrid} that are used as the
! masks ${F_{i}^k}$.  The output {\tt REAL} array {\tt WeightSum} is
! used to store a running sum of the product of the masks.  The
! {\tt LOGICAL} input argument {\tt CheckMasks} governs how the masks
! are applied.  If ${\tt CheckMasks} = {\tt .TRUE.}$, the entries are
! checked to ensure they meet the definitions of real and integer masks.
! If ${\tt CheckMasks} = {\tt .FALSE.}$ then the masks are multiplied
! together on an element-by-element basis with no validation of their
! entries (this option results in slightly higher performance).
!
! {\tt N.B.:}  The lengths of the {\tt AttrVect} arguments {\tt inAv}
! and {\tt outAv} must be equal, and this length must also equal the
! lengths of {\tt GGrid} and {\tt WeightSum}.
!
! {\tt N.B.:}  This algorithm assumes the {\tt AttrVect} argument
! {\tt outAv} has been created, and its real attributes have been
! initialized.
!
! {\tt N.B.:}  This algorithm assumes that the array {\tt WeightSum}
! has been created and initialized.
!
! !INTERFACE:

 subroutine MergeInDataGGSP_(inAv, iMaskTags, rMaskTags, GGrid, &
                             CheckMasks, outAv, WeightSum)
!
! !USES:
!
      use m_stdio
      use m_die

      use m_realkinds, only : SP, FP

      use m_String, only : String
      use m_String, only : String_clean => clean
      use m_String, only : String_ToChar => toChar

      use m_List, only : List
      use m_List, only : List_init => init
      use m_List, only : List_clean => clean
      use m_List, only : List_nitem => nitem
      use m_List, only : List_get => get
      use m_List, only : List_identical => identical
      use m_List, only : List_allocated => allocated

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : SharedAttrIndexList

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize
      use m_GeneralGrid, only : GeneralGrid_exportIAttr => exportIAttr
      use m_GeneralGrid, only : GeneralGrid_exportRAttr => exportRAttr

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)    :: inAv
      character(len=*),   optional, intent(IN)    :: iMaskTags
      character(len=*),   optional, intent(IN)    :: rMaskTags
      type(GeneralGrid),            intent(IN)    :: GGrid
      logical,                      intent(IN)    :: CheckMasks

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(INOUT) :: outAv
      real(SP),       dimension(:), pointer       :: WeightSum

! !REVISION HISTORY:
!       19Jun02 - Jay Larson <larson@mcs.anl.gov> - initial verson.
!       10Jul02 - J. Larson <larson@mcs.anl.gov> - Improved argument
!                 checking.
!EOP ___________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::MergeInDataGGSP_'

  integer :: i, ierr, j, length
  type(String) :: DummStr
  type(List) :: iMaskList, rMaskList
  integer,  dimension(:), pointer :: iMask,iDummy ! INTEGER mask workspace
  real(FP), dimension(:), pointer :: rMask,rDummy ! REAL mask workspace

  logical :: RAttrIdentical ! flag to identify identical REAL attribute
                            ! lists in inAv and outAv
  integer :: NumSharedRAttr ! number of REAL attributes shared by inAv,outAv
       ! Cross-index storage for shared REAL attributes of inAv,outAv
  integer, dimension(:), pointer :: inAvIndices, outAvIndices

       ! Begin argument sanity checks...

       ! Have the input arguments been allocated?

  if(.not.(List_allocated(inAv%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv has no real attributes.'
     call die(myname_)
  endif

  if(.not.(List_allocated(outaV%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUTPUT argument outAv has no real attributes.'
     call die(myname_)
  endif

  if(present(iMaskTags)) then
     if(.not.(List_allocated(GGrid%data%iList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Integer masking requested, but input argument GGrid ', &
	     'has no integer attributes.'
	call die(myname_)
     endif
  endif

  if(present(rMaskTags)) then
     if(.not.(List_allocated(GGrid%data%rList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Real masking requested, but input argument GGrid ', &
	     'has no real attributes.'
	call die(myname_)
     endif
  endif

  if(.not.(associated(WeightSum))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUPUT argument WeightSum has not been allocated.'
     call die(myname_)
  endif

       ! Do the vector lengths match?

  if(AttrVect_lsize(inAv) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv and outAv must match.', &
	  'AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv) /= GeneralGrid_lsize(GGrid)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv and GGrid must match.', &
	  'AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	  'AttrVect_lsize(outAv) = ',GeneralGrid_lsize(GGrid)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv) /= size(WeightSum)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv and WeightSum must match.', &
	  'AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	  'size(WeightSum) = ',size(WeightSum)
     call die(myname_)
  endif

       ! ...end argument sanity checks.

       ! Check for INTEGER masks.  If they are present, retrieve
       ! them and combine them into a single integer mask iMask(:)

  if(present(iMaskTags)) then

       ! allocate two arrays:  iMask (the final product),
       ! and iDummy (storage space for each mask as it is retrieved)

     allocate(iMask(AttrVect_lsize(inAv)), iDummy(AttrVect_lsize(inAv)), &
	      stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: allocate(iMask(...)...) failed with ierr = ',ierr
	call die(myname_)
     endif

       ! Initialize all the elements of iMask to unity:
     iMask = 1

       ! turn the colon-delimited string of tags into a List:
     call List_init(iMaskList,iMaskTags)

       ! Loop over the items in iMaskList, retrieving each mask
       ! into the array iDummy, checking it (if CheckMasks=.TRUE.),
       ! and multiplying it element-by-element into the array iMask.

     do i=1,List_nitem(iMaskList)
       ! grab item as a String
	call List_get(DummStr, i, iMaskList)
       ! use this String to identify an INTEGER GeneralGrid attribute
       ! for export to iDummy(:)
	call GeneralGrid_exportIAttr(GGrid, String_ToChar(DummStr), &
	                             iDummy, length)

	if(.not.(CheckMasks)) then ! Merely multiply iMask by iDummy:
	   do j=1,length
	      iMask(j) = iMask(j) * iDummy(j)
	   end do
	else ! check mask elements and include their effect on iMask
	   do j=1,length
	      select case(iDummy(j))
	      case(0) ! zeroes out iMask(j)
		 iMask(j) = 0
	      case(1) ! leaves iMask(j) untouched
	      case default ! shut down with an error
		 write(stderr,'(5a,i8,a,i8)') myname_, &
		      ':: ERROR--illegal mask value (must be 0 or 1).', &
		      'Illegal value stored in mask ', &
		      String_ToChar(DummStr),'(',j,')=',iDummy(j)
		 call die(myname_)
	      end select
	   end do
	endif ! if(CheckMasks)...
       ! clean up dummy String DummStr
	call String_clean(DummStr)
     end do ! do i=1,List_nitem(iMaskList)...

  endif ! if(present(iMaskTags))...

       ! Check for REAL masks.  If they are present, retrieve
       ! them and combine them into a single real mask rMask(:)

  if(present(rMaskTags)) then

       ! allocate two arrays:  rMask (the final product),
       ! and rDummy (storage space for each mask as it is retrieved)

     allocate(rMask(AttrVect_lsize(inAv)), rDummy(AttrVect_lsize(inAv)), &
	      stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: allocate(rMask(...)...) failed with ierr = ',ierr
	call die(myname_)
     endif

       ! Initialize all the elements of rMask to unity:
     rMask = 1._FP

       ! turn the colon-delimited string of tags into a List:
     call List_init(rMaskList,rMaskTags)

       ! Loop over the items in rMaskList, retrieving each mask
       ! into the array rDummy, checking it (if CheckMasks=.TRUE.),
       ! and multiplying it element-by-element into the array rMask.

     do i=1,List_nitem(rMaskList)
       ! grab item as a String
	call List_get(DummStr, i, rMaskList)
       ! use this String to identify an INTEGER GeneralGrid attribute
       ! for export to rDummy(:)
	call GeneralGrid_exportRAttr(GGrid, String_ToChar(DummStr), &
	                             rDummy, length)

	if(.not.(CheckMasks)) then ! Merely multiply rMask by rDummy:
	   do j=1,length
	      rMask(j) = rMask(j) * rDummy(j)
	   end do
	else ! check mask elements and include their effect on rMask
	   do j=1,length
	      if((iDummy(j) >= 0.) .and. (iDummy(j) <= 1.)) then ! in [0,1]
		 rMask(j) = rMask(j) * rDummy(j)
	      else
		 write(stderr,'(5a,i8,a,i8)') myname_, &
		      ':: ERROR--illegal mask value (must be in [0.,1.]).', &
		      'Illegal value stored in mask ', &
		      String_ToChar(DummStr),'(',j,')=',rDummy(j)
		 call die(myname_)
	      endif
	   end do
	endif ! if(CheckMasks)...
       ! clean up dummy String DummStr
	call String_clean(DummStr)
     end do ! do i=1,List_nitem(rMaskList)...

  endif ! if(present(rMaskTags))...

       ! Now we have (at most) a single INTEGER mask iMask(:) and
       ! a single REAL mask rMask(:).  Before we perform the merge,
       ! we must tackle one more issue:  are the REAL attributes
       ! of inAv and outAv identical and in the same order?  If they
       ! are, the merge is a straightforward double loop over the
       ! elements and over all the attributes.  If the attribute lists
       ! differ, we must cross-reference common attributes, and store
       ! their indices.

  RAttrIdentical = List_identical(inAv%rList, outAv%rList)
  if(.not.(RAttrIdentical)) then
       ! Determine the number of shared REAL attributes NumSharedRAttr,
       ! and form cross-index tables inAvIndices, outAvIndices.
     call SharedAttrIndexList(inAv, outAv, 'REAL', NumSharedRAttr, &
                              inAvIndices, outAvIndices)
  endif

  if(present(rMaskTags)) then ! REAL masking stored in rMask(:)

     if(present(iMaskTags)) then ! also INTEGER mask iMask(:)

	if(RAttrIdentical) then ! straight masked multiply
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,AttrVect_nRAttr(inAv)
		 outAv%rAttr(j,i) = outAv%rAttr(j,i) + &
		      rMask(i) * iMask(i) * inAv%rAttr(j,i)
	      end do ! do j=1,AttrVect_nRAttr(inAv)
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + iMask(i) * rMask(i)
	   end do ! do i=1,AttrVect_lsize(inAv)...
	else ! use previously generated cross-indices
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,NumSharedRAttr
		 outAv%rAttr(outAVIndices(j),i) = &
		      		 outAv%rAttr(outAvIndices(j),i) + &
		      		 rMask(i) * iMask(i) * &
				 inAv%rAttr(inAvIndices(j),i)
	      end do ! do j=1,NumSharedRAttr
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + iMask(i) * rMask(i)
	   end do ! do i=1,AttrVect_lsize(inAv)...
	endif ! if(RAttrIdentical)...

     else ! rMask(:), but no iMask(:)

	if(RAttrIdentical) then ! straight masked multiply
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,AttrVect_nRAttr(inAv)
		 outAv%rAttr(j,i) = outAv%rAttr(j,i) + &
		                    rMask(i) * inAv%rAttr(j,i)
	      end do ! do j=1,AttrVect_nRAttr(inAv)
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + rMask(i)
	   end do ! do i=1,AttrVect_lsize(inAv)...
	else ! use previously generated cross-indices
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,NumSharedRAttr
		 outAv%rAttr(outAVIndices(j),i) = &
		      		 outAv%rAttr(outAvIndices(j),i) + &
		      		 rMask(i) * inAv%rAttr(inAvIndices(j),i)
	      end do ! do j=1,NumSharedRAttr
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + rMask(i)
	   end do ! do i=1,AttrVect_lsize(inAv)...
	endif ! if(RAttrIdentical)

     endif ! if(present(iMaskTags))...

  else ! No REAL Mask

     if(present(iMaskTags)) then ! Have iMask(:), but no rMask(:)

	if(RAttrIdentical) then ! straight masked multiply
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,AttrVect_nRAttr(inAv)
		 outAv%rAttr(j,i) = outAv%rAttr(j,i) + &
		                    iMask(i) * inAv%rAttr(j,i)
	      end do ! do j=1,AttrVect_nRAttr(inAv)
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + iMask(i)
	   end do ! do i=1,AttrVect_lsize(inAv)...
	else ! use previously generated cross-indices
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,NumSharedRAttr
		 outAv%rAttr(outAVIndices(j),i) = &
		      		 outAv%rAttr(outAvIndices(j),i) + &
		      		 iMask(i) * inAv%rAttr(inAvIndices(j),i)
	      end do ! do j=1,NumSharedRAttr
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + iMask(i)
	   end do ! do i=1,AttrVect_lsize(inAv)...
	endif ! if(RAttrIdentical)

     else ! Neither iMask(:) nor rMask(:)--all elements weighted by unity

	if(RAttrIdentical) then ! straight masked multiply
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,AttrVect_nRAttr(inAv)
		 outAv%rAttr(j,i) = outAv%rAttr(j,i) + inAv%rAttr(j,i)
	      end do ! do j=1,AttrVect_nRAttr(inAv)
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + 1._FP
	   end do ! do i=1,AttrVect_lsize(inAv)...
	else ! use previously generated cross-indices
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,NumSharedRAttr
		 outAv%rAttr(outAVIndices(j),i) = &
		      		 outAv%rAttr(outAvIndices(j),i) + &
		      		         inAv%rAttr(inAvIndices(j),i)
	      end do ! do j=1,NumSharedRAttr
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + 1._FP
	   end do ! do i=1,AttrVect_lsize(inAv)...
	endif ! if(RAttrIdentical)

     endif ! if(present(iMaskTags))...

  endif ! if(present(rMaskTags))...

       ! At this point the merge has been completed.  Now clean
       ! up all allocated structures and temporary arrays.

  if(present(iMaskTags)) then ! clean up integer mask work space
     deallocate(iMask, iDummy, stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: deallocate(iMask,...) failed with ierr = ',ierr
	call die(myname_)
     endif
     call List_clean(iMaskList)
  endif

  if(present(rMaskTags)) then ! clean up real mask work space
     deallocate(rMask, rDummy, stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: deallocate(rMask,...) failed with ierr = ',ierr
	call die(myname_)
     endif
     call List_clean(rMaskList)
  endif

  if(.not.(RAttrIdentical)) then ! clean up cross-reference tables
     deallocate(inAvIndices, outAvIndices, stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: deallocate(inAvIndices,...) failed with ierr = ',ierr
	call die(myname_)
     endif
  endif

 end subroutine MergeInDataGGSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
!
! !IROUTINE: MergeInDataGGDP_ - merge in data from a component.
!
! !DESCRIPTION:
! Double precision version of MergeInDataGGSP_
!
! !INTERFACE:

 subroutine MergeInDataGGDP_(inAv, iMaskTags, rMaskTags, GGrid, &
                             CheckMasks, outAv, WeightSum)
!
! !USES:
!
      use m_stdio
      use m_die

      use m_realkinds, only : DP, FP

      use m_String, only : String
      use m_String, only : String_clean => clean
      use m_String, only : String_ToChar => toChar

      use m_List, only : List
      use m_List, only : List_init => init
      use m_List, only : List_clean => clean
      use m_List, only : List_nitem => nitem
      use m_List, only : List_get => get
      use m_List, only : List_identical => identical
      use m_List, only : List_allocated => allocated

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : SharedAttrIndexList

      use m_GeneralGrid, only : GeneralGrid
      use m_GeneralGrid, only : GeneralGrid_lsize => lsize
      use m_GeneralGrid, only : GeneralGrid_exportIAttr => exportIAttr
      use m_GeneralGrid, only : GeneralGrid_exportRAttr => exportRAttr

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),               intent(IN)    :: inAv
      character(len=*),   optional, intent(IN)    :: iMaskTags
      character(len=*),   optional, intent(IN)    :: rMaskTags
      type(GeneralGrid),            intent(IN)    :: GGrid
      logical,                      intent(IN)    :: CheckMasks

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),               intent(INOUT) :: outAv
      real(DP),       dimension(:), pointer       :: WeightSum

! !REVISION HISTORY:
!       19Jun02 - Jay Larson <larson@mcs.anl.gov> - initial verson.
!       10Jul02 - J. Larson <larson@mcs.anl.gov> - Improved argument
!                 checking.
!_______________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::MergeInDataGGDP_'

  integer :: i, ierr, j, length
  type(String) :: DummStr
  type(List) :: iMaskList, rMaskList
  integer,  dimension(:), pointer :: iMask,iDummy ! INTEGER mask workspace
  real(FP), dimension(:), pointer :: rMask,rDummy ! REAL mask workspace

  logical :: RAttrIdentical ! flag to identify identical REAL attribute
                            ! lists in inAv and outAv
  integer :: NumSharedRAttr ! number of REAL attributes shared by inAv,outAv
       ! Cross-index storage for shared REAL attributes of inAv,outAv
  integer, dimension(:), pointer :: inAvIndices, outAvIndices

       ! Begin argument sanity checks...

       ! Have the input arguments been allocated?

  if(.not.(List_allocated(inAv%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT argument inAv has no real attributes.'
     call die(myname_)
  endif

  if(.not.(List_allocated(outaV%rList))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUTPUT argument outAv has no real attributes.'
     call die(myname_)
  endif

  if(present(iMaskTags)) then
     if(.not.(List_allocated(GGrid%data%iList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Integer masking requested, but input argument GGrid ', &
	     'has no integer attributes.'
	call die(myname_)
     endif
  endif

  if(present(rMaskTags)) then
     if(.not.(List_allocated(GGrid%data%rList))) then
	write(stderr,'(3a)') myname_, &
	     'ERROR--Real masking requested, but input argument GGrid ', &
	     'has no real attributes.'
	call die(myname_)
     endif
  endif

  if(.not.(associated(WeightSum))) then
     write(stderr,'(2a)') myname_, &
	  'ERROR--INPUT/OUPUT argument WeightSum has not been allocated.'
     call die(myname_)
  endif

       ! Do the vector lengths match?

  if(AttrVect_lsize(inAv) /= AttrVect_lsize(outAv)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of AttrVect arguments inAv and outAv must match.', &
	  'AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	  'AttrVect_lsize(outAv) = ',AttrVect_lsize(outAv)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv) /= GeneralGrid_lsize(GGrid)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv and GGrid must match.', &
	  'AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	  'AttrVect_lsize(outAv) = ',GeneralGrid_lsize(GGrid)
     call die(myname_)
  endif

  if(AttrVect_lsize(inAv) /= size(WeightSum)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: ERROR--Lengths of arguments inAv and WeightSum must match.', &
	  'AttrVect_lsize(inAv) = ',AttrVect_lsize(inAv), &
	  'size(WeightSum) = ',size(WeightSum)
     call die(myname_)
  endif

       ! ...end argument sanity checks.

       ! Check for INTEGER masks.  If they are present, retrieve
       ! them and combine them into a single integer mask iMask(:)

  if(present(iMaskTags)) then

       ! allocate two arrays:  iMask (the final product),
       ! and iDummy (storage space for each mask as it is retrieved)

     allocate(iMask(AttrVect_lsize(inAv)), iDummy(AttrVect_lsize(inAv)), &
	      stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: allocate(iMask(...)...) failed with ierr = ',ierr
	call die(myname_)
     endif

       ! Initialize all the elements of iMask to unity:
     iMask = 1

       ! turn the colon-delimited string of tags into a List:
     call List_init(iMaskList,iMaskTags)

       ! Loop over the items in iMaskList, retrieving each mask
       ! into the array iDummy, checking it (if CheckMasks=.TRUE.),
       ! and multiplying it element-by-element into the array iMask.

     do i=1,List_nitem(iMaskList)
       ! grab item as a String
	call List_get(DummStr, i, iMaskList)
       ! use this String to identify an INTEGER GeneralGrid attribute
       ! for export to iDummy(:)
	call GeneralGrid_exportIAttr(GGrid, String_ToChar(DummStr), &
	                             iDummy, length)

	if(.not.(CheckMasks)) then ! Merely multiply iMask by iDummy:
	   do j=1,length
	      iMask(j) = iMask(j) * iDummy(j)
	   end do
	else ! check mask elements and include their effect on iMask
	   do j=1,length
	      select case(iDummy(j))
	      case(0) ! zeroes out iMask(j)
		 iMask(j) = 0
	      case(1) ! leaves iMask(j) untouched
	      case default ! shut down with an error
		 write(stderr,'(5a,i8,a,i8)') myname_, &
		      ':: ERROR--illegal mask value (must be 0 or 1).', &
		      'Illegal value stored in mask ', &
		      String_ToChar(DummStr),'(',j,')=',iDummy(j)
		 call die(myname_)
	      end select
	   end do
	endif ! if(CheckMasks)...
       ! clean up dummy String DummStr
	call String_clean(DummStr)
     end do ! do i=1,List_nitem(iMaskList)...

  endif ! if(present(iMaskTags))...

       ! Check for REAL masks.  If they are present, retrieve
       ! them and combine them into a single real mask rMask(:)

  if(present(rMaskTags)) then

       ! allocate two arrays:  rMask (the final product),
       ! and rDummy (storage space for each mask as it is retrieved)

     allocate(rMask(AttrVect_lsize(inAv)), rDummy(AttrVect_lsize(inAv)), &
	      stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: allocate(rMask(...)...) failed with ierr = ',ierr
	call die(myname_)
     endif

       ! Initialize all the elements of rMask to unity:
     rMask = 1._FP

       ! turn the colon-delimited string of tags into a List:
     call List_init(rMaskList,rMaskTags)

       ! Loop over the items in rMaskList, retrieving each mask
       ! into the array rDummy, checking it (if CheckMasks=.TRUE.),
       ! and multiplying it element-by-element into the array rMask.

     do i=1,List_nitem(rMaskList)
       ! grab item as a String
	call List_get(DummStr, i, rMaskList)
       ! use this String to identify an INTEGER GeneralGrid attribute
       ! for export to rDummy(:)
	call GeneralGrid_exportRAttr(GGrid, String_ToChar(DummStr), &
	                             rDummy, length)

	if(.not.(CheckMasks)) then ! Merely multiply rMask by rDummy:
	   do j=1,length
	      rMask(j) = rMask(j) * rDummy(j)
	   end do
	else ! check mask elements and include their effect on rMask
	   do j=1,length
	      if((iDummy(j) >= 0.) .and. (iDummy(j) <= 1.)) then ! in [0,1]
		 rMask(j) = rMask(j) * rDummy(j)
	      else
		 write(stderr,'(5a,i8,a,i8)') myname_, &
		      ':: ERROR--illegal mask value (must be in [0.,1.]).', &
		      'Illegal value stored in mask ', &
		      String_ToChar(DummStr),'(',j,')=',rDummy(j)
		 call die(myname_)
	      endif
	   end do
	endif ! if(CheckMasks)...
       ! clean up dummy String DummStr
	call String_clean(DummStr)
     end do ! do i=1,List_nitem(rMaskList)...

  endif ! if(present(rMaskTags))...

       ! Now we have (at most) a single INTEGER mask iMask(:) and
       ! a single REAL mask rMask(:).  Before we perform the merge,
       ! we must tackle one more issue:  are the REAL attributes
       ! of inAv and outAv identical and in the same order?  If they
       ! are, the merge is a straightforward double loop over the
       ! elements and over all the attributes.  If the attribute lists
       ! differ, we must cross-reference common attributes, and store
       ! their indices.

  RAttrIdentical = List_identical(inAv%rList, outAv%rList)
  if(.not.(RAttrIdentical)) then
       ! Determine the number of shared REAL attributes NumSharedRAttr,
       ! and form cross-index tables inAvIndices, outAvIndices.
     call SharedAttrIndexList(inAv, outAv, 'REAL', NumSharedRAttr, &
                              inAvIndices, outAvIndices)
  endif

  if(present(rMaskTags)) then ! REAL masking stored in rMask(:)

     if(present(iMaskTags)) then ! also INTEGER mask iMask(:)

	if(RAttrIdentical) then ! straight masked multiply
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,AttrVect_nRAttr(inAv)
		 outAv%rAttr(j,i) = outAv%rAttr(j,i) + &
		      rMask(i) * iMask(i) * inAv%rAttr(j,i)
	      end do ! do j=1,AttrVect_nRAttr(inAv)
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + iMask(i) * rMask(i)
	   end do ! do i=1,AttrVect_lsize(inAv)...
	else ! use previously generated cross-indices
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,NumSharedRAttr
		 outAv%rAttr(outAVIndices(j),i) = &
		      		 outAv%rAttr(outAvIndices(j),i) + &
		      		 rMask(i) * iMask(i) * &
				 inAv%rAttr(inAvIndices(j),i)
	      end do ! do j=1,NumSharedRAttr
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + iMask(i) * rMask(i)
	   end do ! do i=1,AttrVect_lsize(inAv)...
	endif ! if(RAttrIdentical)...

     else ! rMask(:), but no iMask(:)

	if(RAttrIdentical) then ! straight masked multiply
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,AttrVect_nRAttr(inAv)
		 outAv%rAttr(j,i) = outAv%rAttr(j,i) + &
		                    rMask(i) * inAv%rAttr(j,i)
	      end do ! do j=1,AttrVect_nRAttr(inAv)
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + rMask(i)
	   end do ! do i=1,AttrVect_lsize(inAv)...
	else ! use previously generated cross-indices
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,NumSharedRAttr
		 outAv%rAttr(outAVIndices(j),i) = &
		      		 outAv%rAttr(outAvIndices(j),i) + &
		      		 rMask(i) * inAv%rAttr(inAvIndices(j),i)
	      end do ! do j=1,NumSharedRAttr
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + rMask(i)
	   end do ! do i=1,AttrVect_lsize(inAv)...
	endif ! if(RAttrIdentical)

     endif ! if(present(iMaskTags))...

  else ! No REAL Mask

     if(present(iMaskTags)) then ! Have iMask(:), but no rMask(:)

	if(RAttrIdentical) then ! straight masked multiply
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,AttrVect_nRAttr(inAv)
		 outAv%rAttr(j,i) = outAv%rAttr(j,i) + &
		                    iMask(i) * inAv%rAttr(j,i)
	      end do ! do j=1,AttrVect_nRAttr(inAv)
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + iMask(i)
	   end do ! do i=1,AttrVect_lsize(inAv)...
	else ! use previously generated cross-indices
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,NumSharedRAttr
		 outAv%rAttr(outAVIndices(j),i) = &
		      		 outAv%rAttr(outAvIndices(j),i) + &
		      		 iMask(i) * inAv%rAttr(inAvIndices(j),i)
	      end do ! do j=1,NumSharedRAttr
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + iMask(i)
	   end do ! do i=1,AttrVect_lsize(inAv)...
	endif ! if(RAttrIdentical)

     else ! Neither iMask(:) nor rMask(:)--all elements weighted by unity

	if(RAttrIdentical) then ! straight masked multiply
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,AttrVect_nRAttr(inAv)
		 outAv%rAttr(j,i) = outAv%rAttr(j,i) + inAv%rAttr(j,i)
	      end do ! do j=1,AttrVect_nRAttr(inAv)
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + 1._FP
	   end do ! do i=1,AttrVect_lsize(inAv)...
	else ! use previously generated cross-indices
	   do i=1, AttrVect_lsize(inAv)
	      do j=1,NumSharedRAttr
		 outAv%rAttr(outAVIndices(j),i) = &
		      		 outAv%rAttr(outAvIndices(j),i) + &
		      		         inAv%rAttr(inAvIndices(j),i)
	      end do ! do j=1,NumSharedRAttr
       ! add in mask contribution to total of merge weights
	      WeightSum(i) = WeightSum(i) + 1._FP
	   end do ! do i=1,AttrVect_lsize(inAv)...
	endif ! if(RAttrIdentical)

     endif ! if(present(iMaskTags))...

  endif ! if(present(rMaskTags))...

       ! At this point the merge has been completed.  Now clean
       ! up all allocated structures and temporary arrays.

  if(present(iMaskTags)) then ! clean up integer mask work space
     deallocate(iMask, iDummy, stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: deallocate(iMask,...) failed with ierr = ',ierr
	call die(myname_)
     endif
     call List_clean(iMaskList)
  endif

  if(present(rMaskTags)) then ! clean up real mask work space
     deallocate(rMask, rDummy, stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: deallocate(rMask,...) failed with ierr = ',ierr
	call die(myname_)
     endif
     call List_clean(rMaskList)
  endif

  if(.not.(RAttrIdentical)) then ! clean up cross-reference tables
     deallocate(inAvIndices, outAvIndices, stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: deallocate(inAvIndices,...) failed with ierr = ',ierr
	call die(myname_)
     endif
  endif

 end subroutine MergeInDataGGDP_

 end module m_Merge
