!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_ConvertMaps - Conversion Between MCT Domain Decomposition Descriptors
!
! !DESCRIPTION:
!
! This module contains routines to convert between the {\tt GlobalMap}
! and {\tt GlobalSegMap} types.  Since the {\tt GlobalMap} is a 1-D
! decomposition with one contiguous segment per process, it is always
! possible to create a {\tt GlobalSegMap} containing the same decomposition
! information.  In the unusual case that a {\tt GlobalSegMap} contains
! {\em at most} one segment per process, and no two segments overlap, it
! is possible to create a {\tt GlobalMap} describing the same decomposition.
!
! !INTERFACE:

 module m_ConvertMaps
!
! !USES:
!
      use m_GlobalMap,    only : GlobalMap
      use m_GlobalSegMap, only : GlobalSegMap

      implicit none

      private   ! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: GlobalMapToGlobalSegMap
      public :: GlobalSegMapToGlobalMap


    interface GlobalMapToGlobalSegMap ; module procedure &
        GlobalMapToGlobalSegMap_
    end interface
    interface GlobalSegMapToGlobalMap ; module procedure &
        GlobalSegMapToGlobalMap_
    end interface

! !REVISION HISTORY:
! 12Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial module
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_ConvertMap'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GlobalMapToGlobalSegMap_ - Convert GlobalMap to GlobalSegMap
!
! !DESCRIPTION:
! This routine takes an input {\tt GlobalMap} argument {\tt GMap}, and
! converts its decomposition information into the output {\tt GlobalSegMap}
! argument {\tt GSMap}.  Since the {\tt GlobalMap} is a very special case
! of the more general {\tt GlobalSegMap} decomposition, this conversion is
! always possible.
!
! The motivation of this routine is the fact that the majority of the
! APIs for MCT services require the user to supply a {\tt GlobalSegMap}
! as a domain decomposition descriptor argument.  This routine is the
! means by which the user can enjoy the convenience and simplicity of
! the {\tt GlobalMap} datatype (where it is appropriate), but still
! access all of the MCT's functionality.
!
! {\bf N.B.:}  This routine creates an allocated structure {\tt GSMap}.
! The user is responsible for deleting this structure using the {\tt clean()}
! method for the {\tt GlobalSegMap} when {\tt GSMap} is no longer needed.
! Failure to do so will create a memory leak.
!
! !INTERFACE:

 subroutine GlobalMapToGlobalSegMap_(GMap, GSMap)

!
! !USES:
!
      use m_stdio, only : stderr
      use m_die,   only : MP_perr_die, die, warn

      use m_GlobalMap,    only : GlobalMap

      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_init => init

      use m_MCTWorld, only : ThisMCTWorld
      use m_MCTWorld, only : MCTWorld_ComponentNumProcs => ComponentNumProcs

      implicit none

! !INPUT PARAMETERS:

      type(GlobalMap),    intent(in)  :: GMap

! !OUTPUT PARAMETERS:

      type(GlobalSegMap), intent(out) :: GSMap

! !REVISION HISTORY:
! 12Feb01 - J.W. Larson <larson@mcs.anl.gov> - Prototype code.
! 24Feb01 - J.W. Larson <larson@mcs.anl.gov> - Finished code.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GlobalMapToGlobalSegMap_'

  integer :: ierr, n, NumProcs
  integer, dimension(:), allocatable :: start, length, pe_loc

       ! Sanity Check -- is GMap the right size?

  NumProcs = MCTWorld_ComponentNumProcs(ThisMCTWorld, GMap%comp_id)
  if(NumProcs /= size(GMap%displs)) then
     call warn(myname_,"component/GlobalMap size mismatch")
     call die(myname_,":: Size mismatch-NumProcs = ", &
	  NumProcs,"size(GMap%displs) = ",size(GMap%displs))
  endif

       ! Allocate space for process location

  allocate(start(NumProcs), length(NumProcs), pe_loc(NumProcs), stat=ierr)
  if(ierr /= 0) call die(myname_,"allocate(start(NumProcs...",ierr)

       ! Load the arrays:

  do n=1,NumProcs
     start(n) = GMap%displs(n-1) + 1
     length(n) = GMap%counts(n-1)
     pe_loc(n) = n-1
  end do

  call GlobalSegMap_init(GSMap, GMap%comp_id, NumProcs, GMap%gsize, &
                         start, length, pe_loc)

       ! Clean up...

  deallocate(start, length, pe_loc, stat=ierr)
  if(ierr /= 0) call die(myname_,"deallocate(start,...",ierr)

 end subroutine GlobalMapToGlobalSegMap_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GlobalSegMapToGlobalMap_ - Convert GlobalSegMap to GlobalMap
!
! !DESCRIPTION:
! This routine takes an input {\tt GlobalSegMap} argument {\tt GSMap},
! and examines it to determine whether or not it may be expressed in
! {\tt GlobalMap} form.  A {\tt GlobalSegMap} can be converted to a
! {\tt GlobalMap} if and only if:
! \begin{enumerate}
! \item Each process on the communicator covered by the
! {\tt GlobalSegMap} contains {\em at most one} segment;
! \item The {\tt GlobalSegMap} is {\em not} haloed (that is, none of
! the segments overlap); and
! \item The start indices of the segments are in the same order as their
! respective process ID numbers.
! \end{enumerate}
! If these conditions are satisfied, {\tt GlobalSegMapToGlobalMap\_()}
! creates an output {\tt GlobalMap} argument {\tt GMap} describing the
! same decomposition as {\tt GSMap}.  If these conditions are not satisfied,
! map conversion can not occur, and {\tt GlobalSegMapToGlobalMap\_()}
! has one of two outcomes:
! \begin{enumerate}
! \item If the optional output {\tt INTEGER} argument {\tt status} is
! provided, {\tt GlobalSegMapToGlobalMap\_()} returns without creating
! {\tt GMap}, and returns a non-zero value for {\tt status}.
! \item If the optional output {\tt INTEGER} argument {\tt status} is
! not provided, execution will terminate with an error message.
! \end{enumerate}
!
! The optional output {\tt INTEGER} argument {\tt status}, if provided
! will be returned from {\tt GlobalSegMapToGlobalMap\_()} with a value
! explained by the table below:
!\begin{table}[htbp]
!\begin{center}
!\begin{tabular}{|c|c|}
!\hline
!{\bf Value of {\tt status}} & {\bf Significance} \\
!\hline
!{\tt 0} & Map Conversion Successful \\
!\hline
!{\tt 1} & Unsuccessful--more than one segment per process, \\
! & or a negative numer of segments (ERROR) \\
!\hline
!{\tt 2} & Unsuccessful--{\tt GSMap} haloed \\
!\hline
!{\tt 3} & Unsuccessful--{\tt GSMap} segments out-of-order \\
! & with respect to resident process ID ranks \\
!\hline
!\end{tabular}
!\end{center}
!\end{table}
!
! {\bf N.B.:}  This routine creates an allocated structure {\tt GMap}.
! The user is responsible for deleting this structure using the {\tt clean()}
! method for the {\tt GlobalMap} when {\tt GMap} is no longer needed.
! Failure to do so will create a memory leak.
!
! !INTERFACE:

 subroutine GlobalSegMapToGlobalMap_(GSMap, GMap, status)
!
! !USES:
!
      use m_stdio, only : stderr
      use m_die,   only : MP_perr_die, die

      use m_SortingTools , only : IndexSet
      use m_SortingTools , only : IndexSort
      use m_SortingTools , only : Permute

      use m_MCTWorld, only : MCTWorld
      use m_MCTWorld, only : ThisMCTWorld
      use m_MCTWorld, only : ComponentNumProcs

      use m_GlobalSegMap, only : GlobalSegMap
      use m_GlobalSegMap, only : GlobalSegMap_comp_id => comp_id
      use m_GlobalSegMap, only : GlobalSegMap_gsize => gsize
      use m_GlobalSegMap, only : GlobalSegMap_haloed => haloed
      use m_GlobalSegMap, only : GlobalSegMap_ngseg => ngseg
      use m_GlobalSegMap, only : GlobalSegMap_nlseg => nlseg
      use m_GlobalSegMap, only : GlobalSegMap_active_pes => active_pes

      use m_GlobalMap,    only : GlobalMap

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),           intent(in)  :: GSMap

! !OUTPUT PARAMETERS:

      type(GlobalMap),              intent(out) :: GMap
      integer,            optional, intent(out) :: status

! !REVISION HISTORY:
! 12Feb01 - J.W. Larson <larson@mcs.anl.gov> - API / first prototype.
! 21Sep02 - J.W. Larson <larson@mcs.anl.gov> - Near-complete Implementation,
!           still, do not call!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GlobalSegMapToGlobalMap_'

  integer :: i, ierr, n
  integer :: nlseg, NumActive, NumProcs, NumPEs, NGSegs
  integer, dimension(:), pointer :: NumSegs
  integer, dimension(:), pointer :: GSMstarts, GSMlengths, GSMpe_locs, perm
  logical :: convertible

       ! If the status flag is present, set it to the "success" value:

  if(present(status)) then
     status = 0
  endif

       ! How many segments are there in GSMap?  If the number of
       ! segments is greater than the number of processes on the
       ! GlobalSegMap's native communicator conversion to a
       ! GlobalMap is not possible.  If the number of segments is
       ! fewer than the number of PEs, further checks are necessary
       ! to determine whether map conversion is possible.

  NumPEs = ComponentNumProcs(ThisMCTWorld, GlobalSegMap_comp_id(GSMap))
  NGSegs = GlobalSegMap_ngseg(GSMap)

  if(NGSegs > NumPEs) then
     write(stderr,'(3a,i8,a,i8,2a)') myname_, &
	  ':: Conversion of input GlobalSegMap to GlobalMap not possible.', &
	  '  Number of segments is greater than number of PEs.  NumPEs = ', &
	  NumPEs,' NGSegs = ', NGSegs,'.  See MCT API Document for more', &
	  ' information.'
     if(present(status)) then
	status = 1
	return
     else
	call die(myname_)
     endif
  endif

       ! Is GSMap haloed?  If it is, map conversion is impossible

  if(GlobalSegMap_haloed(GSMap)) then
     write(stderr,'(3a)') myname_, &
	  ':: input GlobalSegMap is haloed.  Conversion to GlobalMap ', &
	  ' type not possible.  See MCT API Document for details.'
     if(present(status)) then
	status = 2
	return
     else
	call die(myname_)
     endif
  endif

       ! At this point, we've done the easy tests.

       ! Return to the first condition:  at most one segment per PE.
       ! We've eliminated the obvious case of more segments than PEs.
       ! Now, we examine the case of fewer segments than PEs, to see
       ! if any single PE has more than one segment.

  allocate(NumSegs(0:NumPes-1), stat=ierr)
  if(ierr /= 0) call die(myname_,'allocate(NumSegs(1:NumPes-1))=',ierr)

  do n=0,NumPes-1

       ! Is there at most one segment per process?  If not, then
       ! map conversion is impossible.

     NumSegs(n) = GlobalSegMap_nlseg(GSMap, n)

     if((NumSegs(n) > 1) .or. (NumSegs(n) < 0)) then ! fails GMap
	write(stderr,'(3a,i8,a,i8)') myname_, &
	     ':: ERROR:  Map conversion not possible due to ', &
	     'inappropriate number of segments on PE number ', &
	     n,'.  Number of segments = ',NumSegs(n)
	deallocate(NumSegs, stat=ierr)
	if(ierr /= 0) then ! problem cleaning up
	   write(stderr,'(3a)') myname_, &
		':: Encountered error deallocating NumSegs ', &
		'while exiting.'
	endif
	if(present(status)) then ! return with error code
	   status = 1
	   return
	else
	   call die(myname_)
	endif
     endif

  end do ! do n=0,NumPes-1

  deallocate(NumSegs, stat=ierr)
  if(ierr /= 0) call die(myname_,'deallocate(NumSegs,...)',ierr)

       ! If execution has reached this point in the code, GSMap has
       ! satisfied the first two criteria for conversion to a GlobalMap.
       ! The final test is whether or not the global start indices for
       ! the segments (which we know by now are at most one per PE) are
       ! in the same order as their resident process ID ranks.

       ! Extract start, length, and PE location arrays from GSMap:

  allocate(GSMstarts(NGSegs), GSMlengths(NGSegs), GSMpe_locs(NGSegs), &
           perm(NGSegs), stat=ierr)
  if(ierr /= 0) call die(myname_,'allocate(GSMstarts,...)=',ierr)

  do i=1,NGSegs
     GSMstarts(i) = GSMap%start(i)
     GSMlengths(i) = GSMap%length(i)
     GSMpe_locs(i) = GSMap%pe_loc(i)
  end do

       ! Begin sorting process.  First, set index permutation.
  call IndexSet(perm)
       ! Generate sort permutation keyed by PE location
  call IndexSort(NGSegs, perm, GSMpe_locs, descend=.false.)
       ! Permute segment info arrays using perm(:)
  call Permute(GSMstarts, perm, NGSegs)
  call Permute(GSMlengths, perm, NGSegs)
  call Permute(GSMpe_locs, perm, NGSegs)

       ! Now that these arrays are ordered by PE location, we
       ! can check the segment start ordering to see if it is
       ! the same.  Start with the assumption they are in order,
       ! corrsponding to convertible=.TRUE.

  convertible = .TRUE.
  ORDER_TEST: do i=1,NGSegs-1
     if(GSMstarts(i) <= GSMstarts(i+1)) then
	CYCLE
     else
	convertible = .FALSE.
	EXIT
     endif
  end do ORDER_TEST

  if(convertible) then ! build output GlobalMap GMAP

       ! Integer components:

     GMap%comp_id = GlobalSegMap_comp_id(GSMap)
     GMap%gsize = GlobalSegMap_gsize(GSMap)

       ! lsize is not defined in this case!!! -ETO
!     GMap%lsize = GlobalSegMap_lsize(GSMap)
     GMap%lsize = -1

       ! Indexing components:

     allocate(GMap%displs(0:NumPEs-1), GMap%counts(0:NumPEs-1), stat=ierr)

       ! Set the counts(:) values to zero, then copy in the non-zero
       ! segment length values

     GMap%counts = 0
     do i=1,NGSegs
	GMap%counts(GSMpe_locs(i)) = GSMlengths(i)
     end do

       ! From counts(:), build displs(:)
	GMap%displs(0) = 0
     do i=1,NumPEs-1
	GMap%displs(i) = GMap%displs(i-1) + GMap%counts(i-1)
     end do

  else ! Nullify it

     GMap%comp_id = -1
     GMap%gsize = -1
     GMap%lsize = -1
     nullify(GMap%displs)
     nullify(GMap%counts)

  endif

  deallocate(GSMstarts, GSMlengths, GSMpe_locs, perm, stat=ierr)
  if(ierr /= 0) call die(myname_,'deallocate(GSMstarts,...)=',ierr)

 end subroutine GlobalSegMapToGlobalMap_

 end module m_ConvertMaps





