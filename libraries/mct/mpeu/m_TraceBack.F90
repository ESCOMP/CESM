!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_TraceBack - Generation of Traceback Information
!
! !DESCRIPTION:
! This module supports the generation of traceback information for
! a given routine.
!
!
! !INTERFACE:

 module m_TraceBack

! !USES:
! No external modules are used in the declaration section of this module.

      implicit none

      private   ! except

! !PUBLIC TYPES:
! No public types are declared in this module.


! !PUBLIC MEMBER FUNCTIONS:

      public :: GenTraceBackString

      interface GenTraceBackString; module procedure &
	 GenTraceBackString1, &
	 GenTraceBackString2
      end interface

! !PUBLIC DATA MEMBERS:
! No public data member constants are declared in this module.


! !REVISION HISTORY:
!  5 Aug02 - J. Larson <larson@mcs.anl.gov> - Initial version.
!EOP ___________________________________________________________________

! Parameters local to this module:

  character(len=*),parameter :: myname='MCT(MPEU)::m_TraceBackString'

  character(len=len('|X|')), parameter :: StartChar = '|X|'
  character(len=len('->')), parameter :: ArrowChar = '->'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GenTraceBackString1 - Start a TraceBack with One Routine Name
!
! !DESCRIPTION:
! This routine takes in CHARACTER form the names of the calling routine
! (the input argument {\tt RoutineName} and returns a {\tt String}
! (the output argument {\tt TraceBackString}) that portrays this routine
! as the starting point of a downwards procedural trace.  The contents
! of {\tt TraceBackString} is merely an {\tt '|X|'}, followed immediately
! by the value of {\tt RoutineName}.
!
! !INTERFACE:

 subroutine GenTraceBackString1(TraceBackString, RoutineName)
!
! !USES:
!
      use m_stdio
      use m_die

      use m_String, only : String
      use m_String, only : String_init => init

      implicit none

! !INPUT PARAMETERS:
!
      character(len=*), intent(in)  :: RoutineName

! !OUTPUT PARAMETERS:
!
      type(String),     intent(out) :: TraceBackString

! !REVISION HISTORY:
!  5Aug02 - J. Larson <larson@mcs.anl.gov> - Initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GenTraceBackString1'
  integer :: i, ierr
  integer :: RoutineNameLength, ScratchBufferLength
  character, dimension(:), allocatable :: ScratchBuffer

       ! Note:  The value of ArrowChar is inherited
       ! from the declaration section of this module.

       ! Determine the lengths of ParentName and ChildName

  RoutineNameLength = len(RoutineName)

       ! Set up ScratchBuffer:

  ScratchBufferLength = len(StartChar) + RoutineNameLength

  allocate(ScratchBuffer(ScratchBufferLength), stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8)') myname_, &
	  ':: Allocate(ScratchBuffer...) failed.  ierr = ',ierr
     call die(myname_)
  endif

       ! Load ScratchBuffer:


  do i=1,len(StartChar) ! Load the '|X|'...
     ScratchBuffer(i) = StartChar(i:i)
  end do

  do i=1,RoutineNameLength
     ScratchBuffer(len(StartChar)+i) = RoutineName(i:i)
  end do

       ! Create TraceBackString

  call String_init(TraceBackString, ScratchBuffer)

       ! Clean up:

  deallocate(ScratchBuffer, stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8)') myname_, &
	  ':: Deallocate(ScratchBuffer...) failed.  ierr = ',ierr
     call die(myname_)
  endif

 end subroutine GenTraceBackString1

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GenTraceBackString2 - Connect Two Routine Names in a TraceBack
!
! !DESCRIPTION:
! This routine takes in CHARACTER form the names of the parent and
! child routines (the input arguments {\tt ParentName} and
! {\tt ChildName}, repsectively), and returns a {\tt String} (the output
! argument {\tt TraceBackString}) that portrays their procedural
! relationship.  The contents of {\tt TraceBackString} is merely
! {\tt ParentName}, followe by an arrow ({\tt "->"}), followed by
! {\tt ChildName}.
!
! !INTERFACE:

 subroutine GenTraceBackString2(TraceBackString, ParentName, ChildName)
!
! !USES:
!
      use m_stdio
      use m_die

      use m_String, only : String
      use m_String, only : String_init => init

      implicit none

! !INPUT PARAMETERS:
!
      character(len=*), intent(in)  :: ParentName
      character(len=*), intent(in)  :: ChildName

! !OUTPUT PARAMETERS:
!
      type(String),     intent(out) :: TraceBackString

! !REVISION HISTORY:
!  5Aug02 - J. Larson <larson@mcs.anl.gov> - Initial version.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GenTraceBackString2'
  integer :: i, ierr
  integer :: ParentNameLength, ChildNameLength, ScratchBufferLength
  character, dimension(:), allocatable :: ScratchBuffer

       ! Note:  The value of ArrowChar is inherited
       ! from the declaration section of this module.

       ! Determine the lengths of ParentName and ChildName

  ParentNameLength = len(ParentName)
  ChildNameLength = len(ChildName)

       ! Set up ScratchBuffer:

  ScratchBufferLength = ParentNameLength + ChildNameLength + &
                        len(ArrowChar)
  allocate(ScratchBuffer(ScratchBufferLength), stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8)') myname_, &
	  ':: Allocate(ScratchBuffer...) failed.  ierr = ',ierr
     call die(myname_)
  endif

       ! Load ScratchBuffer:

  do i=1,ParentNameLength ! Load the Parent Routine Name...
     ScratchBuffer(i) = ParentName(i:i)
  end do

  do i=1,len(ArrowChar) ! Load the Arrow...
     ScratchBuffer(ParentNameLength+i) = ArrowChar(i:i)
  end do

  do i=1,ChildNameLength
     ScratchBuffer(ParentNameLength+len(ArrowChar)+i) = ChildName(i:i)
  end do

       ! Create TraceBackString

  call String_init(TraceBackString, ScratchBuffer)

       ! Clean up:

  deallocate(ScratchBuffer, stat=ierr)
  if(ierr /= 0) then
     write(stderr,'(2a,i8)') myname_, &
	  ':: Deallocate(ScratchBuffer...) failed.  ierr = ',ierr
     call die(myname_)
  endif

 end subroutine GenTraceBackString2

 end module m_TraceBack
