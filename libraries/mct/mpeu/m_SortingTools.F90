!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_SortingTools - A collection of different sorting tools
!
! !DESCRIPTION:
!
!	This module contains a collection of sorting utilities.  The
!   utilities are accessed through three generic interfaces, IndexSet(),
!   IndexSort(), and IndexBin().
!
!	Note that, a version of IndexBin() for real arguments is not
!   implemented due to the difficulty of comparing two real values as
!   being equal.  For example, a bin for real values may be specified
!   as a single number, a range of two numbers, a number with an
!   absolute error-bar, or a number with a relative error-bar.
!
!	In general, one may have to map both keys(:) and bins(:) to
!   integer indices by the a given rule, then use the integer version
!   of IndexBin() with the two integer index arrays to do the sorting.
!   This mapping rule, however, is application dependent.
!
!	Also note that, in principle, it is possible to use both
!   IndexSort() and IndexBin() in the same sorting task.
!
! !INTERFACE:

    module m_SortingTools

      use m_MergeSorts		!only : IndexSet,IndexSort
      use m_IndexBin_integer	!only : IndexBin
      use m_IndexBin_char	!only : IndexBin
      use m_IndexBin_logical	!only : IndexBin
      use m_rankMerge		!only : RankSet,RankMerge,IndexedRankMerge
      use m_Permuter		!only : Permute, Unpermute

      implicit none

      private	! except

      public :: IndexSet	 ! define an initial list of indices
      public :: IndexSort	 ! index for a new rank out of the old
      public :: IndexBin	 ! index for sorting bins
      public :: RankSet		 ! define an initial list of ranks
      public :: RankMerge	 ! merge two arrays by re-ranking
      public :: IndexedRankMerge ! index-merge two array segments
      public :: Permute          ! permute array entries
      public :: Unpermute        ! invert permutation

! !EXAMPLES:
!
!	- An example of using IndexSet()/IndexSort() in combination with
!   the convenience of the Fortran 90 array syntex can be found in the
!   prolog of m_MergeSorts.
!
!	- An example of using IndexSet()/IndexBin(): Copying all "good"
!   data to another array.
!
!	integer :: indx(n)
!	call IndexSet(n,indx)
!	call IndexBin(n,indx,allObs(:)%qcflag,GOOD,ln0=ln_GOOD)
!
!		! Copy all "good" data to another array
!	goodObs(1:ln_GOOD)=allObs( indx(1:ln_GOOD) )
!
!		! Refill all "good" data back to their original places
!	allObs( indx(1:ln_GOOD) ) = goodObs(1:ln_GOOD)
!
!	- Similarily, multiple keys may be used in an IndexBin() call
!   to selectively sort the data.  The following code will move data
!   with kt = kt_Us,kt_U,kt_Vs,kt_V up to the front:
!
!	call IndexBin(n,indx,allObs(:)%kt,(/kt_Us,kt_U,kt_Vs,kt_V/))
!	allObs(1:n) = allObs( indx(1:n) )
!
!	- Additional applications can also be implemented with other
!   argument combinations.
!
! !REVISION HISTORY:
!	15Mar00	- Jing Guo
!		. Added m_rankMerge module interface
!	20Apr99 - Jing Guo
!		- Commented "only" in use m_IndexBin_xxx to avoid an
!		  apperent compiler bug on DEC/OSF1
! 	17Feb99 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 	19Oct00 - J.W. Larson <larson@mcs.anl.gov> - added Permuter and
!                 Unpermuter to list of public functions.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT(MPEU)::m_SortingTools'

end module m_SortingTools
