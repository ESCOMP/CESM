!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_Accumulator - Time Averaging/Accumlation Buffer
!
! !DESCRIPTION:
!
! An {\em accumulator} is a data class used for computing running sums
! and/or time averages of {\tt AttrVect} class data.
! The period of time over which data are accumulated/averaged is the
! {\em accumulation cycle}, which is defined by the total number
! of accumulation steps (the component {\tt Accumulator\%num\_steps}).  When
! the accumulation routine {\tt accumulate\_} is invoked, the number
! of accumulation cycle steps (the component
! {\tt Accumulator\%steps\_done})is incremented, and compared with
! the number of steps in the accumulation cycle to determine if the
! accumulation cycle has been completed.  The accumulation buffers
! of the {\tt Accumulator} are stored in an {\tt AttrVect} (namely
! the component {\tt Accumulator\%data}), which allows the user to
! define the number of variables and their names at run-time.
! Finally, one can define for each field
! being accumulated the specific accumulation {\em action}.  Currently,
! there are two options:  Time Averaging and Time Summation.  The
! user chooses the specific action by setting an integer action
! flag for each attribute being accumulated.  The supported options
! are defined by the public data member constants {\tt MCT\_SUM} and
! {\tt MCT\_AVG}.
! \\
! This module also supports a simple usage of accumulator where all
! the actions are SUM ({\tt inits\_} and {\tt initavs\_}) and the user
! must call {\tt average\_} to calculate the average from the current
! value of {\tt Accumulator\%steps\_done}.  {\tt Accumulator\%num\_steps}
! is ignored in this case.
!
! !INTERFACE:

 module m_Accumulator
!
! !USES:
!
      use m_List, only : List
      use m_AttrVect, only : AttrVect
      use m_realkinds,only : SP,DP,FP

      implicit none

      private	! except

! !PUBLIC TYPES:

      public :: Accumulator ! The class data structure

    Type Accumulator
#ifdef SEQUENCE
      sequence
#endif
      integer :: num_steps      ! total number of accumulation steps
      integer :: steps_done     ! number of accumulation steps performed
      integer, pointer, dimension(:) :: iAction ! index of integer actions
      integer, pointer, dimension(:) :: rAction ! index of real actions
      type(AttrVect) :: data    ! accumulated sum field storage
    End Type Accumulator

! !PUBLIC MEMBER FUNCTIONS:
!
      public :: init            ! creation method
      public :: initp           ! partial creation method (MCT USE ONLY)
      public :: clean		! destruction method
      public :: initialized     ! check if initialized
      public :: lsize		! local length of the data arrays
      public :: NumSteps        ! number of steps in a cycle
      public :: StepsDone       ! number of steps completed in the
                                ! current cycle
      public :: nIAttr		! number of integer fields
      public :: nRAttr		! number of real fields
      public :: indexIA		! index the integer fields
      public :: indexRA		! index the real fields
      public :: getIList	! Return tag from INTEGER
                                ! attribute list
      public :: getRList	! Return tag from REAL attribute
                                ! list
      public :: exportIAttr  ! Return INTEGER attribute as a vector
      public :: exportRAttr  ! Return REAL attribute as a vector
      public :: importIAttr  ! Insert INTEGER vector as attribute
      public :: importRAttr  ! Insert REAL vector as attribute
      public :: zero         ! Clear an accumulator
      public :: SharedAttrIndexList ! Returns the number of shared
				    ! attributes, and lists of the
				    ! respective locations of these
				    ! shared attributes
      public :: accumulate   ! Add AttrVect data into an Accumulator
      public :: average      ! Calculate an average in an Accumulator

! Definition of interfaces for the methods for the Accumulator:

    interface init   ; module procedure	&
       init_,	&
       inits_,	&
       initv_,  &
       initavs_
    end interface
    interface initp  ; module procedure	initp_ ; end interface
    interface clean  ; module procedure clean_  ; end interface
    interface initialized; module procedure initialized_ ; end interface
    interface lsize  ; module procedure lsize_  ; end interface
    interface NumSteps  ; module procedure NumSteps_  ; end interface
    interface StepsDone  ; module procedure StepsDone_  ; end interface
    interface nIAttr ; module procedure nIAttr_ ; end interface
    interface nRAttr ; module procedure nRAttr_ ; end interface
    interface indexIA; module procedure indexIA_; end interface
    interface indexRA; module procedure indexRA_; end interface
    interface getIList; module procedure getIList_; end interface
    interface getRList; module procedure getRList_; end interface
    interface exportIAttr ; module procedure exportIAttr_ ; end interface
    interface exportRAttr ; module procedure &
         exportRAttrSP_, &
         exportRAttrDP_
    end interface
    interface importIAttr ; module procedure importIAttr_ ; end interface
    interface importRAttr ; module procedure &
         importRAttrSP_, &
         importRAttrDP_
    end interface
    interface zero ; module procedure zero_ ; end interface
    interface SharedAttrIndexList ; module procedure   &
       aCaCSharedAttrIndexList_,  &
       aVaCSharedAttrIndexList_
    end interface
    interface accumulate ; module procedure accumulate_ ; end interface
    interface average ; module procedure average_ ; end interface

! !PUBLIC DATA MEMBERS:
!
      public :: MCT_SUM
      public :: MCT_AVG

    integer, parameter :: MCT_SUM = 1
    integer, parameter :: MCT_AVG = 2

! !REVISION HISTORY:
!  7Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
!  7Feb01 - Jay Larson <larson@mcs.anl.gov> - Public interfaces
!           to getIList() and getRList().
!  9Aug01 - E.T. Ong <eong@mcs.anl.gov> - added initialized and
!           initp_ routines. Added 'action' in Accumulator type.
!  6May02 - Jay Larson <larson@mcs.anl.gov> - added import/export
!            routines.
!  26Aug02 - E.T. Ong <eong@mcs.anl.gov> - thourough code revision;
!            no added routines
!  10Jan08 - R. Jacob <jacob@mcs.anl.gov> - add simple accumulator
!            use support and check documentation.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_Accumulator'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: init_ - Initialize an Accumulator and its Registers
!
! !DESCRIPTION:
! This routine allocates space for the output {\tt Accumulator} argument
! {\tt aC}, and at a minimum sets the number of time steps in an
! accumulation cycle (defined by the input {\tt INTEGER} argument
! {\tt num\_steps}), and the {\em length} of the {\tt Accumulator}
! register buffer (defined by the input {\tt INTEGER} argument {\tt
! lsize}).  If one wishes to accumulate integer fields, the list of
! these fields is defined by the input {\tt CHARACTER} argument
! {\tt iList}, which is specified as a colon-delimited set of
! substrings (further information regarding this is available in the
! routine {\tt init\_()} of the module {\tt m\_AttrVect}).  If no
! value of {\tt iList} is supplied, no integer attribute accumulation
! buffers will be allocated.  The accumulation action on each of the
! integer attributes can be defined by supplying the input {\tt INTEGER}
! array argument {\tt iAction(:)} (whose length must correspond to the
! number of items in {\tt iList}).  The values of the elements of
! {\tt iAction(:)} must be one of the values among the public data
! members defined in the declaration section of this module.  If the
! integer attributes are to be accumulated (i.e. one supplies {\tt iList}),
! but {\tt iAction(:)} is not specified, the default action for all
! integer accumulation operations will be summation.  The input arguments
! {\tt rList} and {\tt rAction(:)} define the names of the real variables
! to be accumulated and the accumulation action for each.  The arguments
! {\tt rList} and {\tt rAction(:)} are related to each other the same
! way as {\tt iList} and {\tt iAction(:)}.  Finally, the user can
! manually set the number of completed steps in an accumulation cycle
! (e.g. for restart purposes) by supplying a value for the optional
! input {\tt INTEGER} argument {\tt steps\_done}.
!
! !INTERFACE:

 subroutine init_(aC, iList, iAction, rList, rAction, lsize, &
                  num_steps,steps_done)
!
! !USES:
!
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero

      use m_List, only: List
      use m_List, only: List_nullify => nullify
      use m_List, only: List_init => init
      use m_List, only: List_nitem => nitem
      use m_List, only: List_clean => clean

      use m_stdio
      use m_die

      implicit none

! !INPUT PARAMETERS:
!
      character(len=*),      optional, intent(in)  :: iList
      integer, dimension(:), optional, intent(in)  :: iAction
      character(len=*),      optional, intent(in)  :: rList
      integer, dimension(:), optional, intent(in)  :: rAction
      integer,                         intent(in)  :: lsize
      integer,                         intent(in)  :: num_steps
      integer,               optional, intent(in)  :: steps_done

! !OUTPUT PARAMETERS:
!
      type(Accumulator),               intent(out) :: aC

! !REVISION HISTORY:
! 11Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
! 27JUL01 - E.T. Ong <eong@mcs.anl.gov> - added iAction, rAction,
!           niAction, and nrAction to accumulator type. Also defined
!           MCT_SUM and MCT_AVG for accumulator module.
!EOP ___________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::init_'
  integer :: my_steps_done, nIAttr, nRAttr, ierr
  integer, dimension(:), pointer :: my_iAction, my_rAction
  logical :: status
  type(List) :: temp_iList, temp_rList

  nullify(my_iAction)
  nullify(my_rAction)

  call List_nullify(temp_iList)
  call List_nullify(temp_rList)

        ! Argument consistency checks:

        ! 1) Terminate with error message if optional argument iAction (rAction)
        ! is supplied but optional argument iList (rList) is not.

  if(present(iAction) .and. (.not. present(iList))) then
     write(stderr,'(2a)') myname_,'::FATAL--Argument iAction supplied but action iList absent!'
     call die(myname_)
  endif

  if(present(rAction) .and. (.not. present(rList))) then
     write(stderr,'(2a)') myname_,'::FATAL--Argument rAction supplied but action rList absent!'
     call die(myname_)
  endif

        ! 2) For iList and rList, generate temporary List data structures to facilitate
        ! attribute counting.

  if(present(iList)) then ! create temp_iList
     call List_init(temp_iList, iList)
     nIAttr = List_nitem(temp_iList)
  endif

  if(present(rList)) then ! create temp_iList
     call List_init(temp_rList, rList)
     nRAttr = List_nitem(temp_rList)
  endif

        ! 3) Terminate with error message if optional arguments iAction (rAction)
        ! and iList (rList) are supplied but the size of iAction (rAction) does not
        ! match the number of items in iList (rList).

  if(present(iAction) .and.  present(iList)) then
     if(size(iAction) /= nIAttr) then
        write(stderr,'(2a,2(a,i8))') myname_, &
             '::FATAL--Size mismatch between iAction and iList!  ', &
             'size(iAction)=',size(iAction),', ','No. items in iList=',nIAttr
        call die(myname_)
     endif
  endif

  if(present(rAction) .and.  present(rList)) then
     if(size(rAction) /= nRAttr) then
        write(stderr,'(2a,2(a,i8))') myname_, &
             '::FATAL--Size mismatch between rAction and rList!  ', &
             'size(rAction)=',size(rAction),', ','No items in rList=',nRAttr
        call die(myname_)
     endif
  endif

        ! Initialize the Accumulator components.

        ! steps_done:

  if(present(steps_done)) then
     my_steps_done = steps_done
  else
     my_steps_done = 0
  endif

        ! my_iAction (if iList is present)

  if(present(iList)) then ! set up my_iAction

     allocate(my_iAction(nIAttr), stat=ierr)
     if(ierr /= 0) then
        write(stderr,'(2a,i8)') myname_, &
           '::FATAL: allocate(my_iAction) failed with ierr=',ierr
        call die(myname_)
     endif

     if(present(iAction)) then ! use its values
        my_iAction = iAction
     else ! go with default summation by assigning value MCT_SUM
        my_iAction = MCT_SUM
     endif

  endif

        ! my_rAction (if rList is present)

  if(present(rList)) then ! set up my_rAction

     allocate(my_rAction(nRAttr), stat=ierr)
     if(ierr /= 0) then
        write(stderr,'(2a,i8)') myname_, &
           '::FATAL: allocate(my_rAction) failed with ierr=',ierr
        call die(myname_)
     endif

     if(present(rAction)) then ! use its values
        my_rAction = rAction
     else ! go with default summation by assigning value MCT_SUM
        my_rAction = MCT_SUM
     endif

  endif

        ! Build the Accumulator aC minus its data component:

  if(present(iList) .and. present(rList)) then ! Both REAL and INTEGER registers

     call initp_(aC,my_iAction,my_rAction,num_steps,my_steps_done)

     deallocate(my_iAction, my_rAction, stat=ierr)
     if(ierr /= 0) then
        write(stderr,'(2a,i8)') myname_, &
           '::FATAL: deallocate(my_iAction, my_rAction) failed with ierr=',ierr
        call die(myname_)
     endif

  else ! Either only REAL or only INTEGER registers in aC

     if(present(iList)) then ! Only  INTEGER REGISTERS

	call initp_(aC=aC, iAction=my_iAction, num_steps=num_steps, &
	            steps_done=my_steps_done)

        deallocate(my_iAction, stat=ierr)
        if(ierr /= 0) then
           write(stderr,'(2a,i8)') myname_, &
                '::FATAL: deallocate(my_iAction) failed with ierr=',ierr
           call die(myname_)
        endif

     endif

     if(present(rList)) then ! Only  REAL REGISTERS

	call initp_(aC=aC, rAction=my_rAction, num_steps=num_steps, &
	            steps_done=my_steps_done)

        deallocate(my_rAction, stat=ierr)
        if(ierr /= 0) then
           write(stderr,'(2a,i8)') myname_, &
                '::FATAL: deallocate(my_rAction) failed with ierr=',ierr
           call die(myname_)
        endif

     endif

  endif

        ! Initialize the AttrVect data component for aC:

  if(present(iList) .and. present(rList)) then
     call AttrVect_init(aC%data,iList,rList,lsize)
  else
     if(present(iList)) then
	call AttrVect_init(aV=aC%data,iList=iList,lsize=lsize)
     endif
     if(present(rList)) then
	call AttrVect_init(aV=aC%data,rList=rList,lsize=lsize)
     endif
  endif

  call AttrVect_zero(aC%data)

        ! Clean up

  if(present(iList)) call List_clean(temp_iList)
  if(present(rList)) call List_clean(temp_rList)

        ! Check that aC has been properly initialized

  status = initialized_(aC=aC,die_flag=.true.,source_name=myname_)

 end subroutine init_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: inits_ - Initialize a simple Accumulator and its Registers
!
! !DESCRIPTION:
! This routine allocates space for the output simple {\tt Accumulator} argument
! {\tt aC}, and sets the {\em length} of the {\tt Accumulator}
! register buffer (defined by the input {\tt INTEGER} argument {\tt
! lsize}).  If one wishes to accumulate integer fields, the list of
! these fields is defined by the input {\tt CHARACTER} argument
! {\tt iList}, which is specified as a colon-delimited set of
! substrings (further information regarding this is available in the
! routine {\tt init\_()} of the module {\tt m\_AttrVect}).  If no
! value of {\tt iList} is supplied, no integer attribute accumulation
! buffers will be allocated.   The input argument {\tt rList} define
! the names of the real variables  to be accumulated. Finally, the user can
! manually set the number of completed steps in an accumulation cycle
! (e.g. for restart purposes) by supplying a value for the optional
! input {\tt INTEGER} argument {\tt steps\_done}.
! Its default value is zero.
!
! In a simple accumulator, the action is always SUM.
!
!
! !INTERFACE:

 subroutine inits_(aC, iList, rList, lsize,steps_done)
!
! !USES:
!
      use m_List, only : List_init => init
      use m_List, only : List_clean => clean
      use m_List, only : List_nitem => nitem
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_zero => zero
      use m_die

      implicit none

! !INPUT PARAMETERS:
!
      character(len=*),      optional, intent(in)  :: iList
      character(len=*),      optional, intent(in)  :: rList
      integer,                         intent(in)  :: lsize
      integer,               optional, intent(in)  :: steps_done

! !OUTPUT PARAMETERS:
!
      type(Accumulator),               intent(out) :: aC

! !REVISION HISTORY:
! 10Jan08 - R. Jacob <jacob@mcs.anlgov> - initial version based on init_
!
!EOP ___________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::inits_'
  type(List) :: tmplist
  integer :: my_steps_done,ier,i,actsize
  logical :: status

        ! Initialize the Accumulator components.

  if(present(steps_done)) then
     my_steps_done = steps_done
  else
     my_steps_done = 0
  endif

  aC%num_steps = -1   ! special value for simple aC
  aC%steps_done = my_steps_done

  nullify(aC%iAction,aC%rAction)

  if(present(iList)) then
     call List_init(tmplist,iList)
     actsize=List_nitem(tmplist)
     allocate(aC%iAction(actsize),stat=ier)
     if(ier /= 0) call die(myname_,"iAction allocate",ier)
     do i=1,lsize
       aC%iAction=MCT_SUM
     enddo
     call List_clean(tmplist)
  endif

  if(present(rList)) then
     call List_init(tmplist,rList)
     actsize=List_nitem(tmpList)
     allocate(aC%rAction(actsize),stat=ier)
     if(ier /= 0) call die(myname_,"rAction allocate",ier)
     do i=1,lsize
       aC%rAction=MCT_SUM
     enddo
     call List_clean(tmplist)
  endif

        ! Initialize the AttrVect component aC:

  if(present(iList) .and. present(rList)) then
     call AttrVect_init(aC%data,iList,rList,lsize)
  else
     if(present(iList)) then
	call AttrVect_init(aV=aC%data,iList=iList,lsize=lsize)
     endif
     if(present(rList)) then
	call AttrVect_init(aV=aC%data,rList=rList,lsize=lsize)
     endif
  endif

  call AttrVect_zero(aC%data)

        ! Check that aC has been properly initialized

  status = initialized_(aC=aC,die_flag=.true.,source_name=myname_)

 end subroutine inits_


!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initp_ - Initialize an Accumulator but not its Registers
!
! !DESCRIPTION:
! This routine is an internal service routine for use by the other
! initialization routines in this module.  It sets up some---but not
! all---of the components of the output {\tt Accumulator} argument
! {\tt aC}.  This routine can set up the following components of
! {\tt aC}:
! \begin{enumerate}
! \item {\tt aC\%iAction}, the array of accumlation actions for the
! integer attributes of {\tt aC} (if the input {\tt INTEGER} array
! argument {\tt iAction(:)} is supplied);
! \item {\tt aC\%rAction}, the array of accumlation actions for the
! real attributes of {\tt aC} (if the input {\tt INTEGER} array
! argument {\tt rAction(:)} is supplied);
! \item {\tt aC\%num\_steps}, the number of steps in an accumulation
! cycle (if the input {\tt INTEGER} argument {\tt num\_steps} is
! supplied); and
! \item {\tt aC\%steps\_done}, the number of steps completed so far
! in an accumulation cycle (if the input {\tt INTEGER} argument
! {\tt steps\_done} is supplied).
! \end{enumerate}
!
! !INTERFACE:

 subroutine initp_(aC, iAction, rAction, num_steps, steps_done)

!
! !USES:
!
      use m_die

      implicit none

! !INPUT PARAMETERS:
!
      integer, dimension(:), optional, intent(in)  :: iAction
      integer, dimension(:), optional, intent(in)  :: rAction
      integer,                         intent(in)  :: num_steps
      integer,               optional, intent(in)  :: steps_done

! !OUTPUT PARAMETERS:
!
      type(Accumulator),               intent(out) :: aC

! !REVISION HISTORY:
! 11Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
! 27JUL01 - E.T. Ong <eong@mcs.anl.gov> - added iAction, rAction,
!           niAction, and nrAction to accumulator type. Also defined
!           MCT_SUM and MCT_AVG for accumulator module.
!EOP ___________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::initp_'
  integer :: i,ier
  integer :: steps_completed

        ! if the argument steps_done is not present, assume
        ! the accumulator is starting at step zero, that is,
        ! set steps_completed to zero

  steps_completed = 0
  if(present(steps_done)) steps_completed = steps_done

        ! Set the stepping info:

  aC%num_steps = num_steps
  aC%steps_done = steps_completed


        ! Assign iAction and niAction components

  nullify(aC%iAction,aC%rAction)

  if(present(iAction)) then

     if(size(iAction)>0) then

	allocate(aC%iAction(size(iAction)),stat=ier)
	if(ier /= 0) call die(myname_,"iAction allocate",ier)

	do i=1,size(iAction)
	   aC%iAction(i) = iAction(i)
	enddo

     endif

  endif

  if(present(rAction)) then

     if(size(rAction)>0) then

	allocate(aC%rAction(size(rAction)),stat=ier)
	if(ier /= 0) call die(myname_,"iAction allocate",ier)

	do i=1,size(rAction)
	   aC%rAction(i) = rAction(i)
	enddo

     endif

  endif

 end subroutine initp_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initv_ - Initialize One Accumulator using Another
!
! !DESCRIPTION:
! This routine takes the integer and real attribute information (including
! accumulation action settings for each attribute) from a previously
! initialized {\tt Accumulator} (the input argument {\tt bC}), and uses
! it to create another {\tt Accumulator} (the output argument {\tt aC}).
! In the absence of the {\tt INTEGER} input arguments {\tt lsize},
! {\tt num\_steps}, and {\tt steps\_done}, {\tt aC} will inherit from
! {\tt bC} its length, the number of steps in its accumulation cycle, and
! the number of steps completed in its present accumulation cycle,
! respectively.
!
! !INTERFACE:

 subroutine initv_(aC, bC, lsize, num_steps, steps_done)
!
! !USES:
!
      use m_List,   only : List
      use m_List,   only : ListExportToChar => exportToChar
      use m_List,   only : List_copy        => copy
      use m_List,   only : List_allocated   => allocated
      use m_List,   only : List_clean       => clean
      use m_die

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator),           intent(in)  :: bC
      integer,           optional, intent(in)  :: lsize
      integer,           optional, intent(in)  :: num_steps
      integer,           optional, intent(in)  :: steps_done

! !OUTPUT PARAMETERS:
!
      type(Accumulator),           intent(out) :: aC

! !REVISION HISTORY:
! 11Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
! 17May01 - R. Jacob <jacob@mcs.anl.gov> - change string_get to
!           list_get
! 27JUL01 - E.T. Ong <eong@mcs.anl.gov> - added iaction,raction
!           compatibility
!  2Aug02 - J. Larson <larson@mcs.anl.gov> made argument num_steps
!           optional
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initv_'

  type(List) :: temp_iList, temp_rList
  integer :: myNumSteps, myStepsDone
  integer :: aC_lsize
  integer :: niActions, nrActions
  integer, dimension(:), allocatable :: iActionArray, rActionArray
  integer :: i,ier
  logical :: status

        ! Check that bC has been initialized

  status = initialized(aC=bC,die_flag=.true.,source_name=myname_)

        ! If the argument steps_done is present, set myStepsDone
        ! to this value; otherwise, set it to zero

  if(present(num_steps)) then ! set it manually
     myNumSteps = num_steps
  else ! inherit it from bC
     myNumSteps = bC%num_steps
  endif

        ! If the argument steps_done is present, set myStepsDone
        ! to this value; otherwise, set it to zero

  if(present(steps_done)) then ! set it manually
     myStepsDone= steps_done
  else ! inherit it from bC
     myStepsDone = bC%steps_done
  endif

        ! If the argument lsize is present,
        ! set aC_lsize to this value; otherwise, set it to the lsize of bC

  if(present(lsize)) then  ! set it manually
     aC_lsize = lsize
  else ! inherit it from bC
     aC_lsize = lsize_(bC)
  endif

	! Convert the two Lists to two Strings

  niActions = 0
  nrActions = 0

  if(List_allocated(bC%data%iList)) then
     call List_copy(temp_iList,bC%data%iList)
     niActions = nIAttr_(bC)
  endif

  if(List_allocated(bC%data%rList)) then
     call List_copy(temp_rList,bC%data%rList)
     nrActions = nRAttr_(bC)
  endif

        ! Convert the pointers to arrays

  allocate(iActionArray(niActions),rActionArray(nrActions),stat=ier)
  if(ier /= 0) call die(myname_,"iActionArray/rActionArray allocate",ier)

  if( niActions>0 ) then
     do i=1,niActions
	iActionArray(i)=bC%iAction(i)
     enddo
  endif

  if( nrActions>0 ) then
     do i=1,nrActions
	rActionArray(i)=bC%rAction(i)
     enddo
  endif

        ! Call init with present arguments

  if( (niActions>0) .and. (nrActions>0) ) then

     call init_(aC, iList=ListExportToChar(temp_iList), &
                iAction=iActionArray,                   &
	        rList=ListExportToChar(temp_rList),     &
		rAction=rActionArray,                   &
                lsize=aC_lsize,                         &
                num_steps=myNumSteps,                   &
                steps_done=myStepsDone)

  else

     if( niActions>0 ) then

	call init_(aC, iList=ListExportToChar(temp_iList), &
	           iAction=iActionArray,                   &
                   lsize=aC_lsize,                         &
		   num_steps=myNumSteps,                   &
                   steps_done=myStepsDone)

     endif

     if( nrActions>0 ) then

	call init_(aC, rList=ListExportToChar(temp_rList), &
	           rAction=rActionArray,                   &
		   lsize=aC_lsize,                         &
		   num_steps=myNumSteps,                   &
                   steps_done=myStepsDone)
     endif

  endif

  if(List_allocated(bC%data%iList)) call List_clean(temp_iList)
  if(List_allocated(bC%data%rList)) call List_clean(temp_rList)

  deallocate(iActionArray,rActionArray,stat=ier)
  if(ier /= 0) call die(myname_,"iActionArray/rActionArray deallocate",ier)

  ! Check that aC as been properly initialized

  status = initialized(aC=aC,die_flag=.true.,source_name=myname_)

 end subroutine initv_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initavs_ - Initialize a simple Accumulator from an AttributeVector
!
! !DESCRIPTION:
! This routine takes the integer and real attribute information (including
! from a previously initialized {\tt AttributeVector} (the input argument {\tt aV}), and uses
! it to create a simple (sum only) {\tt Accumulator} (the output argument {\tt aC}).
! In the absence of the {\tt INTEGER} input argument {\tt lsize},
! {\tt aC} will inherit from {\tt Av} its length.  In the absence of the
! optional INTEGER argument, {\tt steps\_done} will be set to zero.
!
! !INTERFACE:

 subroutine initavs_(aC, aV, acsize, steps_done)
!
! !USES:
!
      use m_AttrVect, only: AttrVect_lsize => lsize
      use m_AttrVect, only: AttrVect_nIAttr => nIAttr
      use m_AttrVect, only: AttrVect_nRAttr => nRAttr
      use m_AttrVect, only: AttrVect_exIL2c => exportIListToChar
      use m_AttrVect, only: AttrVect_exRL2c => exportRListToChar
      use m_die

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),           intent(in)     :: aV
      integer,           optional, intent(in)  :: acsize
      integer,           optional, intent(in)  :: steps_done

! !OUTPUT PARAMETERS:
!
      type(Accumulator),           intent(out) :: aC

! !REVISION HISTORY:
! 10Jan08 - R. Jacob <jacob@mcs.anl.gov> - initial version based on initv_
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initavs_'

  integer :: myNumSteps, myStepsDone
  integer :: aC_lsize
  integer :: i,ier
  integer :: nIatt,nRatt
  logical :: status


        ! If the argument steps_done is present, set myStepsDone
        ! to this value; otherwise, set it to zero

  if(present(steps_done)) then ! set it manually
     myStepsDone= steps_done
  else ! set it to zero
     myStepsDone = 0
  endif

        ! If the argument acsize is present,
        ! set aC_lsize to this value; otherwise, set it to the lsize of bC

  if(present(acsize)) then  ! set it manually
     aC_lsize = acsize
  else ! inherit it from bC
     aC_lsize = AttrVect_lsize(aV)
  endif
  nIatt=AttrVect_nIAttr(aV)
  nRatt=AttrVect_nRAttr(aV)

  if((nIAtt>0) .and. (nRatt>0)) then
     call inits_(aC,AttrVect_exIL2c(aV),AttrVect_exRL2c(aV), &
                  aC_lsize,myStepsDone)
  else
     if(nIatt>0) then
        call inits_(aC,iList=AttrVect_exIL2c(aV),lsize=aC_lsize, &
                    steps_done=myStepsDone)
     endif
     if(nRatt>0) then
        call inits_(aC,rList=AttrVect_exRL2c(aV),lsize=aC_lsize, &
                    steps_done=myStepsDone)
     endif
  endif


  ! Check that aC as been properly initialized

  status = initialized(aC=aC,die_flag=.true.,source_name=myname_)

 end subroutine initavs_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: clean_ - Destroy an Accumulator
!
! !DESCRIPTION:
! This routine deallocates all allocated memory structures associated
! with the input/output {\tt Accumulator} argument {\tt aC}.  The
! success (failure) of this operation is signified by the zero (non-zero)
! value of the optional {\tt INTEGER} output argument {\tt stat}.  If
! {\tt clean\_()} is invoked with {\tt stat} present, it is the user's
! obligation to check this return code and act accordingly.  If {\tt stat}
! is not supplied and any of the deallocation operations fail, this
! routine will terminate execution with an error statement.
!
! !INTERFACE:

 subroutine clean_(aC, stat)
!
! !USES:
!
      use m_mall
      use m_stdio
      use m_die
      use m_AttrVect, only : AttrVect_clean => clean

      implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      type(Accumulator), intent(inout) :: aC

! !OUTPUT PARAMETERS:
!
      integer, optional, intent(out)   :: stat

! !REVISION HISTORY:
! 11Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
! 27JUL01 - E.T. Ong <eong@mcs.anl.gov> - deallocate pointers iAction
!           and rAction.
!  1Mar02 - E.T. Ong <eong@mcs.anl.gov> removed the die to prevent
!           crashes and added stat argument.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::clean_'
  integer :: ier

  if(present(stat)) then
     stat=0
     call AttrVect_clean(aC%data,stat)
  else
     call AttrVect_clean(aC%data)
  endif

  if( associated(aC%iAction) )  then

      deallocate(aC%iAction,stat=ier)

      if(ier /= 0) then
	 if(present(stat)) then
	    stat=ier
	 else
	    call warn(myname_,'deallocate(aC%iAction)',ier)
	 endif
      endif

   endif

  if( associated(aC%rAction) ) then

     deallocate(aC%rAction,stat=ier)

      if(ier /= 0) then
	 if(present(stat)) then
	    stat=ier
	 else
	    call warn(myname_,'deallocate(aC%rAction)',ier)
	 endif
      endif

  endif

 end subroutine clean_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initialized_ - Check if an Accumulator is Initialized
!
! !DESCRIPTION:
! This logical function returns a value of {\tt .TRUE.} if the input
! {\tt Accumulator} argument {\tt aC}  is initialized correctly.  The
! term "correctly initialized" means there is internal consistency
! between the number of integer and real attributes in {\tt aC}, and
! their respective data structures for accumulation registers, and
! accumulation action flags.  The optional {\tt LOGICAL} input argument
! {\tt die\_flag}  if present, can result in messages written to
! {\tt stderr}:
! \begin {itemize}
! \item if {\tt die\_flag} is true and {\tt aC} is correctly initialized,
! and
! \item if {\tt die\_flag} is false and {\tt aC} is incorrectly
! initialized.
! \end{itemize}
! Otherwise, inconsistencies in how {\tt aC} is set up will result in
! termination with an error message.
! The optional {\tt CHARACTER} input argument {\tt source\_name} allows
! the user to, in the event of error, generate traceback information
! (e.g., the name of the routine that invoked this one).
!
! !INTERFACE:

 logical function initialized_(aC, die_flag, source_name)
!
! !USES:
!

   use m_stdio
   use m_die
   use m_List, only : List
   use m_List, only : List_allocated => allocated

   use m_AttrVect, only : AttrVect
   use m_AttrVect, only : Attr_nIAttr => nIAttr
   use m_AttrVect, only : Attr_nRAttr => nRAttr

   implicit none

! !INPUT PARAMETERS:
!
   type(Accumulator),          intent(in) :: aC
   logical,          optional, intent(in) :: die_flag
   character(len=*), optional, intent(in) :: source_name

! !REVISION HISTORY:
!  7AUG01 - E.T. Ong <eong@mcs.anl.gov> - initital prototype
!
!EOP ___________________________________________________________________

   character(len=*),parameter :: myname_=myname//'::initialized_'
   integer :: i
   logical :: kill
   logical :: aC_associated

   if(present(die_flag)) then
      kill = .true.
   else
      kill = .false.
   endif

          ! Initial value
   initialized_ = .true.
   aC_associated = .true.

          ! Check the association status of pointers in aC

   if( associated(aC%iAction) .or. associated(aC%rAction) ) then
      aC_associated = .true.
   else
      initialized_ = .false.
      aC_associated = .false.
      if(kill) then
	 if(present(source_name)) write(stderr,*) source_name, myname_, &
	      ":: ERROR, Neither aC%iAction nor aC%rAction are associated"
	 call die(myname_,"Neither aC%iAction nor aC%rAction are associated")
      endif
   endif

   if( List_allocated(aC%data%iList) .or. List_allocated(aC%data%rList) ) then
      aC_associated = .true.
   else
      initialized_ = .false.
      aC_associated = .false.
      if(kill) then
	 if(present(source_name)) write(stderr,*) source_name, myname_, &
	      ":: ERROR, Neither aC%data%iList nor aC%data%rList are allocated"
	 call die(myname_,"Neither aC%data%iList nor aC%data%rList are allocated")
      endif
   endif

           ! Make sure iAction and rAction sizes are greater than zero

   if(associated(aC%iAction)) then
      if(size(aC%iAction)<=0) then
	 initialized_ = .false.
	 aC_associated = .false.
	 if(kill) then
	    if(present(source_name)) write(stderr,*) source_name, myname_, &
		 ":: ERROR, size(aC%iAction<=0), size = ", size(aC%iAction)
	    call die(myname_,"size(aC%iAction<=0), size = ", size(aC%iAction))
	 endif
      endif
   endif

   if(associated(aC%rAction)) then
      if(size(aC%rAction)<=0) then
	 initialized_ = .false.
	 aC_associated = .false.
	 if(kill) then
	    if(present(source_name)) write(stderr,*) source_name, myname_, &
		 ":: ERROR, size(aC%rAction<=0), size = ", size(aC%rAction)
	    call die(myname_,"size(aC%rAction<=0), size = ", size(aC%rAction))
	 endif
      endif
   endif

          ! More sanity checking...

   if( aC_associated ) then

      if( (Attr_nIAttr(aC%data) == 0) .and. (Attr_nRAttr(aC%data) == 0) ) then
	 initialized_ = .false.
	 if(kill) then
	    if(present(source_name)) write(stderr,*) source_name, myname_, &
		 ":: ERROR, No attributes found in aC%data"
	    call die(myname_,"No attributes found in aC%data")
	 endif
      endif

      if(Attr_nIAttr(aC%data) > 0) then

	 if( size(aC%iAction) /=  Attr_nIAttr(aC%data) ) then
	    initialized_ = .false.
	    if(kill) then
	       if(present(source_name)) write(stderr,*) source_name, myname_, &
		    ":: ERROR, size(aC%iAction) /= nIAttr(aC%data)"
	       call die(myname_,"size(aC%iAction) /= nIAttr(aC%data)")
	    endif
	 endif

	 do i=1,Attr_nIAttr(aC%data)
	    if( (aC%iAction(i) /= MCT_SUM) .and. &
                (aC%iAction(i) /= MCT_AVG) ) then
	       initialized_ = .false.
	       if(kill) then
		  if(present(source_name)) write(stderr,*) source_name, &
		       myname_, ":: ERROR, Invalid value found in aC%iAction"
		  call die(myname_,"Invalid value found in aC%iAction", &
		       aC%iAction(i))
	       endif
	    endif
	 enddo

      endif ! if(Attr_nIAttr(aC%data) > 0)

      if(Attr_nRAttr(aC%data) > 0) then

	 if( size(aC%rAction) /=  Attr_nRAttr(aC%data) ) then
	    initialized_ = .false.
	    if(kill) then
	      if(present(source_name)) write(stderr,*) source_name, &
		   myname_, ":: ERROR, size(aC%rAction) /= nRAttr(aC%data)"
	      call die(myname_,"size(aC%rAction) /= nRAttr(aC%data)")
	    endif
	 endif

	 do i=1,Attr_nRAttr(aC%data)
	    if( (aC%rAction(i) /= MCT_SUM) .and. &
                (aC%rAction(i) /= MCT_AVG) ) then
	       initialized_ = .false.
	       if(kill) then
		  if(present(source_name)) write(stderr,*) source_name, &
		       myname_, ":: ERROR, Invalid value found in aC%rAction", &
		       aC%rAction(i)
		  call die(myname_,"Invalid value found in aC%rAction", &
		       aC%iAction(i))
	       endif
	    endif
	 enddo

      endif ! if(Attr_nRAttr(aC%data) > 0)

   endif  ! if (aC_associated)

 end function initialized_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: lsize_ - Length of an Accumulator
!
! !DESCRIPTION:
! This {\tt INTEGER} query function returns the number of data points
! for which the input {\tt Accumulator} argument {\tt aC} is performing
! accumulation.  This value corresponds to the length of the {\tt AttrVect}
! component {\tt aC\%data} that stores the accumulation registers.
!
! !INTERFACE:

 integer function lsize_(aC)
!
! !USES:
!
      use m_AttrVect, only : AttrVect_lsize => lsize

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator), intent(in) :: aC

! !REVISION HISTORY:
! 12Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::lsize_'


	! The function AttrVect_lsize is called to return
        ! its local size data

  lsize_=AttrVect_lsize(aC%data)

 end function lsize_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: NumSteps_ - Number of Accumulation Cycle Time Steps
!
! !DESCRIPTION:
! This {\tt INTEGER} query function returns the number of time steps in an
! accumulation cycle for the input {\tt Accumulator} argument {\tt aC}.
!
! !INTERFACE:

 integer function NumSteps_(aC)
!
! !USES:
!
      use m_die,   only : die
      use m_stdio, only : stderr

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator), intent(in) :: aC

! !REVISION HISTORY:
!  7Aug02 - Jay Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::NumSteps_'

  integer :: myNumSteps


	! Retrieve the number of cycle steps from aC:

  myNumSteps = aC%num_steps

  if(myNumSteps <= 0) then
     write(stderr,'(2a,i8)') myname_, &
	  ':: FATAL--illegal number of steps in an accumulation cycle = ',&
	  myNumSteps
     call die(myname_)
  endif

  NumSteps_ = myNumSteps

 end function NumSteps_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: StepsDone_ - Number of Completed Steps in the Current Cycle
!
! !DESCRIPTION:
! This {\tt INTEGER} query function returns the of time steps that have
! been completed in the current accumulation cycle for the input
! {\tt Accumulator} argument {\tt aC}.
!
! !INTERFACE:

 integer function StepsDone_(aC)
!
! !USES:
!
      use m_die,   only : die
      use m_stdio, only : stderr

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator), intent(in) :: aC

! !REVISION HISTORY:
!  7Aug02 - Jay Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::StepsDone_'

  integer :: myStepsDone

	! Retrieve the number of completed steps from aC:

  myStepsDone = aC%steps_done

  if(myStepsDone < 0) then
     write(stderr,'(2a,i8)') myname_, &
	  ':: FATAL--illegal number of completed steps = ',&
	  myStepsDone
     call die(myname_)
  endif

  StepsDone_ = myStepsDone

 end function StepsDone_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: nIAttr_ - Return the Number of INTEGER Attributes
!
! !DESCRIPTION:
! This {\tt INTEGER} query function returns the number of integer
! attributes that are stored in the input {\tt Accumulator} argument
! {\tt aC}.  This value is equal to the number of integer attributes
! in the {\tt AttrVect} component {\tt aC\%data} that stores the
! accumulation registers.
!
! !INTERFACE:

 integer function nIAttr_(aC)
!
! !USES:
!
      use m_AttrVect, only : AttrVect_nIAttr => nIAttr

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator),intent(in) :: aC

! !REVISION HISTORY:
! 12Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::nIAttr_'

	! The function AttrVect_nIAttr is called to return the
        ! number of integer fields

  nIAttr_=AttrVect_nIAttr(aC%data)

 end function nIAttr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: nRAttr_ - number of REAL fields stored in the Accumulator.
!
! !DESCRIPTION:
! This {\tt INTEGER} query function returns the number of real
! attributes that are stored in the input {\tt Accumulator} argument
! {\tt aC}.  This value is equal to the number of real attributes
! in the {\tt AttrVect} component {\tt aC\%data} that stores the
! accumulation registers.
!
! !INTERFACE:

 integer function nRAttr_(aC)
!
! !USES:
!
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator),intent(in) :: aC

! !REVISION HISTORY:
! 12Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::nRAttr_'

	! The function AttrVect_nRAttr is called to return the
        ! number of real fields

  nRAttr_=AttrVect_nRAttr(aC%data)

 end function nRAttr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: getIList_ - Retrieve a Numbered INTEGER Attribute Name
!
! !DESCRIPTION:
! This routine returns as a {\tt String} (see the mpeu module
! {\tt m\_String} for information) the name of the {\tt ith} item in
! the integer registers of the {\tt Accumulator} argument {\tt aC}.
!
! !INTERFACE:

 subroutine getIList_(item, ith, aC)
!
! !USES:
!
      use m_AttrVect, only : AttrVect_getIList => getIList
      use m_String,   only : String

      implicit none

! !INPUT PARAMETERS:
!
      integer,           intent(in)  :: ith
      type(Accumulator), intent(in)  :: aC

! !OUTPUT PARAMETERS:
!
      type(String),      intent(out) :: item

! !REVISION HISTORY:
! 12Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::getIList_'

  call AttrVect_getIList(item,ith,aC%data)

 end subroutine getIList_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: getRList_ - Retrieve a Numbered REAL Attribute Name
!
! !DESCRIPTION:
! This routine returns as a {\tt String} (see the mpeu module
! {\tt m\_String} for information) the name of the {\tt ith} item in
! the real registers of the {\tt Accumulator} argument {\tt aC}.
!
! !INTERFACE:

 subroutine getRList_(item, ith, aC)
!
! !USES:
!
      use m_AttrVect, only : AttrVect_getRList => getRList
      use m_String,   only : String

      implicit none

! !INPUT PARAMETERS:
!
      integer,          intent(in)  :: ith
      type(Accumulator),intent(in)  :: aC

! !OUTPUT PARAMETERS:
!
      type(String),     intent(out) :: item

! !REVISION HISTORY:
! 12Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::getRList_'

  call AttrVect_getRList(item,ith,aC%data)

 end subroutine getRList_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: indexIA_ - Index an INTEGER Attribute
!
! !DESCRIPTION:
! This {\tt INTEGER} query function returns the index in the integer
! accumulation register buffer of the {\tt Accumulator} argument {\tt aC}
! the attribute named by the {\tt CHARACTER} argument {\tt item}.  That
! is, all the accumulator running tallies for the attribute named
! {\tt item} reside in
!\begin{verbatim}
! aC%data%iAttr(indexIA_(aC,item),:).
!\end{verbatim}
! The user may request traceback information (e.g., the name of the
! routine from which this one is called) by providing values for either
! of the optional {\tt CHARACTER} arguments {\tt perrWith} or {\tt dieWith}
! In the event {\tt indexIA\_()} can not find {\tt item} in {\tt aC},
! the routine behaves as follows:
! \begin{enumerate}
! \item if neither {\tt perrWith} nor {\tt dieWith} are present,
! {\tt indexIA\_()} returns a value of zero;
! \item if {\tt perrWith} is present, but {\tt dieWith} is not, an error
! message is written to {\tt stderr} incorporating user-supplied traceback
! information stored in the argument {\tt perrWith};
! \item if {\tt dieWith} is present, execution terminates with an error
! message written to {\tt stderr} that incorporates user-supplied traceback
! information stored in the argument {\tt dieWith}.
! \end{enumerate}
! !INTERFACE:

 integer function indexIA_(aC, item, perrWith, dieWith)
!
! !USES:
!
      use m_AttrVect, only : AttrVect_indexIA => indexIA
      use m_die,  only : die
      use m_stdio,only : stderr

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator),          intent(in) :: aC
      character(len=*),           intent(in) :: item
      character(len=*), optional, intent(in) :: perrWith
      character(len=*), optional, intent(in) :: dieWith

! !REVISION HISTORY:
! 14Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::indexIA_'

  indexIA_=AttrVect_indexIA(aC%data,item)

	if(indexIA_==0) then
	  if(.not.present(dieWith)) then
	    if(present(perrWith)) write(stderr,'(4a)') perrWith, &
		'" indexIA_() error, not found "',trim(item),'"'
	  else
	    write(stderr,'(4a)') dieWith,	&
		'" indexIA_() error, not found "',trim(item),'"'
	    call die(dieWith)
	  endif
	endif

 end function indexIA_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: indexRA_ - index the Accumulator real attribute list.
!
! !DESCRIPTION:
! This {\tt INTEGER} query function returns the index in the real
! accumulation register buffer of the {\tt Accumulator} argument {\tt aC}
! the attribute named by the {\tt CHARACTER} argument {\tt item}.  That
! is, all the accumulator running tallies for the attribute named
! {\tt item} reside in
!\begin{verbatim}
! aC%data%rAttr(indexRA_(aC,item),:).
!\end{verbatim}
! The user may request traceback information (e.g., the name of the
! routine from which this one is called) by providing values for either
! of the optional {\tt CHARACTER} arguments {\tt perrWith} or {\tt dieWith}
! In the event {\tt indexRA\_()} can not find {\tt item} in {\tt aC},
! the routine behaves as follows:
! \begin{enumerate}
! \item if neither {\tt perrWith} nor {\tt dieWith} are present,
! {\tt indexRA\_()} returns a value of zero;
! \item if {\tt perrWith} is present, but {\tt dieWith} is not, an error
! message is written to {\tt stderr} incorporating user-supplied traceback
! information stored in the argument {\tt perrWith};
! \item if {\tt dieWith} is present, execution terminates with an error
! message written to {\tt stderr} that incorporates user-supplied traceback
! information stored in the argument {\tt dieWith}.
! \end{enumerate}
!
! !INTERFACE:

 integer function indexRA_(aC, item, perrWith, dieWith)
!
! !USES:
!
      use m_AttrVect, only : AttrVect_indexRA => indexRA
      use m_die,  only : die
      use m_stdio,only : stderr

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator),          intent(in) :: aC
      character(len=*),           intent(in) :: item
      character(len=*), optional, intent(in) :: perrWith
      character(len=*), optional, intent(in) :: dieWith

! !REVISION HISTORY:
! 	14Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::indexRA_'

  indexRA_=AttrVect_indexRA(aC%data,item)

	if(indexRA_==0) then
	  if(.not.present(dieWith)) then
	    if(present(perrWith)) write(stderr,'(4a)') perrWith, &
		'" indexRA_() error, not found "',trim(item),'"'
	  else
	    write(stderr,'(4a)') dieWith,	&
		'" indexRA_() error, not found "',trim(item),'"'
	    call die(dieWith)
	  endif
	endif

 end function indexRA_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: exportIAttr_ - Export INTEGER Attribute to a Vector
!
! !DESCRIPTION:
! This routine extracts from the input {\tt Accumulator} argument
! {\tt aC} the integer attribute corresponding to the tag defined in
! the input {\tt CHARACTER} argument {\tt AttrTag}, and returns it in
! the {\tt INTEGER} output array {\tt outVect}, and its length in the
! output {\tt INTEGER} argument {\tt lsize}.
!
! {\bf N.B.:}  This routine will fail if the {\tt AttrTag} is not in
! the {\tt Accumulator} {\tt List} component {\tt aC\%data\%iList}.
!
! {\bf N.B.:}  The flexibility of this routine regarding the pointer
! association status of the output argument {\tt outVect} means the
! user must invoke this routine with care.  If the user wishes this
! routine to fill a pre-allocated array, then obviously this array
! must be allocated prior to calling this routine.  If the user wishes
! that the routine {\em create} the output argument array {\tt outVect},
! then the user must ensure this pointer is not allocated (i.e. the user
! must nullify this pointer) at the time this routine is invoked.
!
! {\bf N.B.:}  If the user has relied on this routine to allocate memory
! associated with the pointer {\tt outVect}, then the user is responsible
! for deallocating this array once it is no longer needed.  Failure to
! do so will result in a memory leak.
!
! !INTERFACE:

 subroutine exportIAttr_(aC, AttrTag, outVect, lsize)
!
! !USES:
!
      use m_die
      use m_stdio

      use m_AttrVect,      only : AttrVect_exportIAttr => exportIAttr

      implicit none

! !INPUT PARAMETERS:

      type(Accumulator),      intent(in)  :: aC
      character(len=*),       intent(in)  :: AttrTag

! !OUTPUT PARAMETERS:

      integer,  dimension(:), pointer     :: outVect
      integer,  optional,     intent(out) :: lsize

! !REVISION HISTORY:

!  6May02 - J.W. Larson <larson@mcs.anl.gov> - initial prototype.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::exportIAttr_'

       ! Export the data (inheritance from AttrVect)
  if(present(lsize)) then
     call AttrVect_exportIAttr(aC%data, AttrTag, outVect, lsize)
  else
     call AttrVect_exportIAttr(aC%data, AttrTag, outVect)
  endif

 end subroutine exportIAttr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: exportRAttrSP_ - Export REAL Attribute to a Vector
!
! !DESCRIPTION:
! This routine extracts from the input {\tt Accumulator} argument
! {\tt aC} the real attribute corresponding to the tag defined in
! the input {\tt CHARACTER} argument {\tt AttrTag}, and returns it in
! the {\tt REAL} output array {\tt outVect}, and its length in the
! output {\tt INTEGER} argument {\tt lsize}.
!
! {\bf N.B.:}  This routine will fail if the {\tt AttrTag} is not in
! the {\tt Accumulator} {\tt List} component {\tt aC\%data\%iList}.
!
! {\bf N.B.:}  The flexibility of this routine regarding the pointer
! association status of the output argument {\tt outVect} means the
! user must invoke this routine with care.  If the user wishes this
! routine to fill a pre-allocated array, then obviously this array
! must be allocated prior to calling this routine.  If the user wishes
! that the routine {\em create} the output argument array {\tt outVect},
! then the user must ensure this pointer is not allocated (i.e. the user
! must nullify this pointer) at the time this routine is invoked.
!
! {\bf N.B.:}  If the user has relied on this routine to allocate memory
! associated with the pointer {\tt outVect}, then the user is responsible
! for deallocating this array once it is no longer needed.  Failure to
! do so will result in a memory leak.
!
! !INTERFACE:

 subroutine exportRAttrSP_(aC, AttrTag, outVect, lsize)
!
! !USES:
!
      use m_die
      use m_stdio

      use m_AttrVect,      only : AttrVect_exportRAttr => exportRAttr

      implicit none

! !INPUT PARAMETERS:

      type(Accumulator),      intent(in)  :: aC
      character(len=*),       intent(in)  :: AttrTag

! !OUTPUT PARAMETERS:

      real(SP), dimension(:), pointer     :: outVect
      integer,  optional,     intent(out) :: lsize

! !REVISION HISTORY:
!  6May02 - J.W. Larson <larson@mcs.anl.gov> - initial prototype.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::exportRAttrSP_'

       ! Export the data (inheritance from AttrVect)

  if(present(lsize)) then
     call AttrVect_exportRAttr(aC%data, AttrTag, outVect, lsize)
  else
     call AttrVect_exportRAttr(aC%data, AttrTag, outVect)
  endif

 end subroutine exportRAttrSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
! ----------------------------------------------------------------------
!
! !IROUTINE: exportRAttrDP_ - Export REAL Attribute to a Vector
!
! !DESCRIPTION:
! Double precision version of exportRAttrSP_
!
! !INTERFACE:

 subroutine exportRAttrDP_(aC, AttrTag, outVect, lsize)
!
! !USES:
!
      use m_die
      use m_stdio

      use m_AttrVect,      only : AttrVect_exportRAttr => exportRAttr

      implicit none

! !INPUT PARAMETERS:

      type(Accumulator),      intent(in)  :: aC
      character(len=*),       intent(in)  :: AttrTag

! !OUTPUT PARAMETERS:

      real(DP), dimension(:), pointer     :: outVect
      integer,  optional,    intent(out) :: lsize

! !REVISION HISTORY:
!  6May02 - J.W. Larson <larson@mcs.anl.gov> - initial prototype.
!
! ______________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::exportRAttrDP_'

       ! Export the data (inheritance from AttrVect)

  if(present(lsize)) then
     call AttrVect_exportRAttr(aC%data, AttrTag, outVect, lsize)
  else
     call AttrVect_exportRAttr(aC%data, AttrTag, outVect)
  endif

 end subroutine exportRAttrDP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: importIAttr_ - Import INTEGER Attribute from a Vector
!
! !DESCRIPTION:
! This routine imports data provided in the input {\tt INTEGER} vector
! {\tt inVect} into the {\tt Accumulator} argument {\tt aC}, storing
! it as the integer attribute corresponding to the tag defined in
! the input {\tt CHARACTER} argument {\tt AttrTag}.  The input
! {\tt INTEGER} argument {\tt lsize} is used to ensure there is
! sufficient space in the {\tt Accumulator} to store the data.
!
! {\bf N.B.:}  This routine will fail if the {\tt AttrTag} is not in
! the {\tt Accumulator} {\tt List} component {\tt aC\%data\%rList}.
!
! !INTERFACE:

 subroutine importIAttr_(aC, AttrTag, inVect, lsize)
!
! !USES:
!
      use m_die
      use m_stdio ,        only : stderr

      use m_AttrVect,      only : AttrVect_importIAttr => importIAttr

      implicit none

! !INPUT PARAMETERS:

      character(len=*),       intent(in)    :: AttrTag
      integer, dimension(:),  pointer       :: inVect
      integer,                intent(in)    :: lsize

! !INPUT/OUTPUT PARAMETERS:

      type(Accumulator),      intent(inout) :: aC

! !REVISION HISTORY:
!  6May02 - J.W. Larson <larson@mcs.anl.gov> - initial prototype.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::importIAttr_'

       ! Argument Check:

  if(lsize > lsize_(aC)) then
     write(stderr,*) myname_,':: ERROR, lsize > lsize_(aC).', &
          'lsize = ',lsize,'lsize_(aC) = ',lsize_(ac)
     call die(myname_)
  endif

       ! Import the data (inheritance from AttrVect)

  call AttrVect_importIAttr(aC%data, AttrTag, inVect, lsize)

 end subroutine importIAttr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: importRAttrSP_ - Import REAL Attribute from a Vector
!
! !DESCRIPTION:
! This routine imports data provided in the input {\tt REAL} vector
! {\tt inVect} into the {\tt Accumulator} argument {\tt aC}, storing
! it as the real attribute corresponding to the tag defined in
! the input {\tt CHARACTER} argument {\tt AttrTag}.  The input
! {\tt INTEGER} argument {\tt lsize} is used to ensure there is
! sufficient space in the {\tt Accumulator} to store the data.
!
! {\bf N.B.:}  This routine will fail if the {\tt AttrTag} is not in
! the {\tt Accumulator} {\tt List} component {\tt aC\%data\%rList}.
!
! !INTERFACE:

 subroutine importRAttrSP_(aC, AttrTag, inVect, lsize)
!
! !USES:
!
      use m_die
      use m_stdio ,        only : stderr

      use m_AttrVect,      only : AttrVect_importRAttr => importRAttr

      implicit none

! !INPUT PARAMETERS:

      character(len=*),       intent(in)    :: AttrTag
      real(SP), dimension(:), pointer       :: inVect
      integer,                intent(in)    :: lsize

! !INPUT/OUTPUT PARAMETERS:

      type(Accumulator),      intent(inout) :: aC

! !REVISION HISTORY:
!  6May02 - J.W. Larson <larson@mcs.anl.gov> - initial prototype.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::importRAttrSP_'

       ! Argument Check:

  if(lsize > lsize_(aC)) then
     write(stderr,*) myname_,':: ERROR, lsize > lsize_(aC).', &
          'lsize = ',lsize,'lsize_(aC) = ',lsize_(ac)
     call die(myname_)
  endif

       ! Import the data (inheritance from AttrVect)

  call AttrVect_importRAttr(aC%data, AttrTag, inVect, lsize)

 end subroutine importRAttrSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
! ----------------------------------------------------------------------
!
! !IROUTINE: importRAttrDP_ - Import REAL Attribute from a Vector
!
! !DESCRIPTION:
! Double precision version of importRAttrSP_
!
! !INTERFACE:

 subroutine importRAttrDP_(aC, AttrTag, inVect, lsize)
!
! !USES:
!
      use m_die
      use m_stdio ,        only : stderr

      use m_AttrVect,      only : AttrVect_importRAttr => importRAttr

      implicit none

! !INPUT PARAMETERS:

      character(len=*),       intent(in)    :: AttrTag
      real(DP), dimension(:), pointer       :: inVect
      integer,                intent(in)    :: lsize

! !INPUT/OUTPUT PARAMETERS:

      type(Accumulator),      intent(inout) :: aC

! !REVISION HISTORY:
!  6May02 - J.W. Larson <larson@mcs.anl.gov> - initial prototype.
! ______________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::importRAttrDP_'

       ! Argument Check:

  if(lsize > lsize_(aC)) then
     write(stderr,*) myname_,':: ERROR, lsize > lsize_(aC).', &
          'lsize = ',lsize,'lsize_(aC) = ',lsize_(ac)
     call die(myname_)
  endif

       ! Import the data (inheritance from AttrVect)

  call AttrVect_importRAttr(aC%data, AttrTag, inVect, lsize)

 end subroutine importRAttrDP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: zero_ - Zero an Accumulator
!
! !DESCRIPTION:
! This subroutine clears the the {\tt Accumulator} argument {\tt aC}.
! This is accomplished by setting the number of completed steps in the
! accumulation cycle to zero, and zeroing out all of the accumlation
! registers.
!
! !INTERFACE:

 subroutine zero_(aC)
!
! !USES:
!
      use m_AttrVect, only : AttrVect_zero => zero

      implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      type(Accumulator), intent(inout) :: aC

! !REVISION HISTORY:
!  7Aug02 - Jay Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::zero_'

	! Set number of completed cycle steps to zero:

  aC%steps_done = 0

	! Zero out the accumulation registers:

  call AttrVect_zero(aC%data)

 end subroutine zero_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: aCaCSharedAttrIndexList_ - Cross-index Two Accumulators
!
! !DESCRIPTION:  {\tt aCaCSharedAttrIndexList\_()} takes a pair of
! user-supplied {\tt Accumulator} variables {\tt aC1} and {\tt aC2},
! and for choice of either {\tt REAL} or {\tt INTEGER} attributes (as
! specified literally in the input {\tt CHARACTER} argument {\tt attrib})
! returns the number of shared attributes {\tt NumShared}, and arrays of
! indices {\tt Indices1} and {\tt Indices2} to their storage locations
! in {\tt aC1} and {\tt aC2}, respectively.
!
! {\bf N.B.:}  This routine returns two allocated arrays---{\tt Indices1(:)}
! and {\tt Indices2(:)}---which must be deallocated once the user no longer
! needs them.  Failure to do this will create a memory leak.
!
! !INTERFACE:

 subroutine aCaCSharedAttrIndexList_(aC1, aC2, attrib, NumShared, &
                                     Indices1, Indices2)

!
! !USES:
!
      use m_stdio
      use m_die,         only : MP_perr_die, die, warn

      use m_List,     only : GetSharedListIndices

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator),    intent(in)  :: aC1
      type(Accumulator),    intent(in)  :: aC2
      character*7,          intent(in)  :: attrib

! !OUTPUT PARAMETERS:
!
      integer,              intent(out) :: NumShared
      integer,dimension(:), pointer     :: Indices1
      integer,dimension(:), pointer     :: Indices2

! !REVISION HISTORY:
!  7Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::aCaCSharedAttrIndexList_'

  integer :: ierr

       ! Based on the value of the argument attrib, pass the
       ! appropriate pair of Lists for comparison...

  select case(trim(attrib))
  case('REAL','real')
     call GetSharedListIndices(aC1%data%rList, aC2%data%rList, NumShared, &
                                 Indices1, Indices2)
  case('INTEGER','integer')
     call GetSharedListIndices(aC1%data%iList, aC2%data%iList, NumShared, &
                                 Indices1, Indices2)
  case default
     write(stderr,'(4a)') myname_,":: value of argument attrib=",attrib, &
          " not recognized.  Allowed values: REAL, real, INTEGER, integer"
     ierr = 1
     call die(myname_, 'invalid value for attrib', ierr)
  end select

 end subroutine aCaCSharedAttrIndexList_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: aVaCSharedAttrIndexList_ - Cross-index with an AttrVect
!
! !DESCRIPTION:  {\tt aVaCSharedAttrIndexList\_()} a user-supplied
! {\tt AttrVect} variable {\tt aV} and an {\tt Accumulator} variable
! {\tt aC}, and for choice of either {\tt REAL} or {\tt INTEGER}
! attributes (as ! specified literally in the input {\tt CHARACTER}
! argument {\tt attrib}) returns the number of shared attributes
! {\tt NumShared}, and arrays of indices {\tt Indices1} and {\tt Indices2}
! to their storage locations in {\tt aV} and {\tt aC}, respectively.
!
! {\bf N.B.:}  This routine returns two allocated arrays---{\tt Indices1(:)}
! and {\tt Indices2(:)}---which must be deallocated once the user no longer
! needs them.  Failure to do this will create a memory leak.
!
! !INTERFACE:

 subroutine aVaCSharedAttrIndexList_(aV, aC, attrib, NumShared, &
                                     Indices1, Indices2)

!
! !USES:
!
      use m_stdio
      use m_die,         only : MP_perr_die, die, warn

      use m_AttrVect,    only : AttrVect

      use m_List,     only : GetSharedListIndices


      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),       intent(in)  :: aV
      type(Accumulator),    intent(in)  :: aC
      character(len=*),     intent(in)  :: attrib

! !OUTPUT PARAMETERS:
!
      integer,              intent(out) :: NumShared
      integer,dimension(:), pointer     :: Indices1
      integer,dimension(:), pointer     :: Indices2

! !REVISION HISTORY:
!  7Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::aVaCSharedAttrIndexList_'

  integer :: ierr

       ! Based on the value of the argument attrib, pass the
       ! appropriate pair of Lists for comparison...

  select case(trim(attrib))
  case('REAL','real')
     call GetSharedListIndices(aV%rList, aC%data%rList, NumShared, &
                                 Indices1, Indices2)
  case('INTEGER','integer')
     call GetSharedListIndices(aV%iList, aC%data%iList, NumShared, &
                                 Indices1, Indices2)
  case default
     write(stderr,'(4a)') myname_,":: value of argument attrib=",attrib, &
          " not recognized.  Allowed values: REAL, real, INTEGER, integer"
     ierr = 1
     call die(myname_, 'invalid value for attrib', ierr)
  end select

 end subroutine aVaCSharedAttrIndexList_

!BOP -------------------------------------------------------------------
!
! !IROUTINE: accumulate_--Acumulate from an AttrVect to an Accumulator.
!
! !DESCRIPTION:
! This routine performs time {\em accumlation} of data present in an
! MCT field data {\tt AttrVect} variable {\tt aV} and combines it with
! the running tallies stored in the MCT {\tt Accumulator} variable {\tt aC}.
! This routine automatically identifies which
! fields are held in common by {\tt aV} and {\tt aC} and uses the
! accumulation action information stored in {\tt aC} to decide how
! each field in {\tt aV} is to be combined into its corresponding
! running tally in {\tt aC}.  The accumulation operations currently
! supported are:
! \begin {itemize}
! \item {\tt MCT\_SUM}:  Add the current values in the {\tt Av} to the current values in {\tt Ac}.
! \item {\tt MCT\_AVG}:  Same as {\tt MCT\_SUM} except when {\tt steps\_done} is equal
! to {\tt num\_steps} then perform one more sum and replaced with average.
! \end {itemize}
!
! This routine also automatically increments the counter in {\tt aC}
! signifying the number of steps completed in the accumulation cycle.
!
! NOTE:  The user must reset (zero) the {\tt Accumulator} after the average
! has been formed or the next call to {\tt accumulate} will add to the average.
!
! !INTERFACE:

 subroutine accumulate_(aV, aC)

!
! !USES:
!
      use m_stdio, only : stdout,stderr
      use m_die,   only : die

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nIAttr => nIAttr
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : AttrVect_indexRA => indexRA
      use m_AttrVect, only : AttrVect_indexIA => indexIA

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),     intent(in)    :: aV      ! Input AttrVect

! !INPUT/OUTPUT PARAMETERS:
!
      type(Accumulator),  intent(inout) :: aC      ! Output Accumulator

! !REVISION HISTORY:
! 18Sep00 - J.W. Larson <larson@mcs.anl.gov> -- initial version.
!  7Feb01 - J.W. Larson <larson@mcs.anl.gov> -- General version.
! 10Jun01 - E.T. Ong -- fixed divide-by-zero problem in integer
!           attribute accumulation.
! 27Jul01 - E.T. Ong <eong@mcs.anl.gov> -- removed action argument.
!           Make compatible with new Accumulator type.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::accumulate_'

! Overlapping attribute index number
  integer :: num_indices

! Overlapping attribute index storage arrays:
  integer, dimension(:), pointer :: aCindices, aVindices
  integer :: aCindex, aVindex

! Error flag and loop indices
  integer :: ierr, l, n

! Averaging time-weighting factor:
  real(FP) :: step_weight
  integer :: num_steps

! Character variable used as a data type flag:
  character*7 :: data_flag

        ! Sanity check of arguments:

  if(lsize_(aC) /= AttrVect_lsize(aV)) then
     write(stderr,'(2a,i8,a,i8)') myname_, &
     ':: Mismatched Accumulator/AttrVect lengths. AttrVect_lsize(aV) = ',&
     AttrVect_lsize(aV), 'lsize_(aC) = ',lsize_(aC)
     call die(myname_)
  endif

  if(aC%num_steps == 0) then
     write(stderr,'(2a)') myname,':: FATAL--Zero steps in accumulation cycle.'
     call die(myname_)
  endif

        ! Set num_steps from aC:

  num_steps = aC%num_steps

        ! Accumulation of REAL attribute data:

  if( associated(aC%rAction) ) then   ! if summing or avergaging reals...

        ! Accumulate only if fields are present

     data_flag = 'REAL'
     call aVaCSharedAttrIndexList_(aV, aC, data_flag, num_indices, &
                                   aVindices, aCindices)

     if(num_indices > 0) then
        do n=1,num_indices
           aVindex = aVindices(n)
           aCindex = aCindices(n)

           ! Accumulate if the action is MCT_SUM or MCT_AVG
           if( (aC%rAction(aCindex) == MCT_SUM).or. &
               (aC%rAction(aCindex) == MCT_AVG) ) then
              do l=1,AttrVect_lsize(aV)
                 aC%data%rAttr(aCindex,l) = aC%data%rAttr(aCindex,l) + &
                      aV%rAttr(aVindex,l)
              end do
           endif
        end do

        deallocate(aVindices, aCindices, stat=ierr)
        if(ierr /= 0) then
	   write(stderr,'(2a,i8)') myname_, &
		':: Error in first deallocate(aVindices...), ierr = ',ierr
	   call die(myname_)
	endif

     endif ! if(num_indices > 0)

  endif ! if( associated(aC%rAction) )


        ! Accumulation of INTEGER attribute data:

  if( associated(aC%iAction) ) then    ! if summing or avergaging ints...

        ! Accumulate only if fields are present


     data_flag = 'INTEGER'
     call aVaCSharedAttrIndexList_(aV, aC, data_flag, num_indices, &
                                   aVindices, aCindices)

     if(num_indices > 0) then

        do n=1,num_indices
           aVindex = aVindices(n)
           aCindex = aCindices(n)

           ! Accumulate if the action is MCT_SUM or MCT_AVG
           if( (aC%iAction(aCindex) == MCT_SUM) .or. &
               (aC%iAction(aCindex) == MCT_AVG) ) then
              do l=1,AttrVect_lsize(aV)
                 aC%data%iAttr(aCindex,l) = aC%data%iAttr(aCindex,l) + &
                      aV%iAttr(aVindex,l)
              end do
           endif
        end do

        deallocate(aVindices, aCindices, stat=ierr)
        if(ierr /= 0) then
	   write(stderr,'(2a,i8)') myname_, &
		':: Error in second deallocate(aVindices...), ierr = ',ierr
	   call die(myname_)
	endif

     endif ! if(num_indices > 0)

  endif ! if( associated(aC%iAction) )

        ! Increment aC%steps_done:

  aC%steps_done = aC%steps_done + 1

        ! If we are at the end of an averaging period, compute the
        ! average (if desired).

  if(aC%steps_done == num_steps) then

     step_weight = 1.0_FP / REAL(num_steps,FP)
     do n=1,nRAttr_(aC)
        if( aC%rAction(n) == MCT_AVG ) then
           do l=1,lsize_(aC)
              aC%data%rAttr(n,l) = step_weight * aC%data%rAttr(n,l)
           enddo
        endif
     enddo

     do n=1,nIAttr_(aC)
        if( aC%iAction(n) == MCT_AVG ) then
           do l=1,lsize_(aC)
              aC%data%iAttr(n,l) = aC%data%iAttr(n,l) / num_steps
           enddo
        endif
     enddo

  endif

 end subroutine accumulate_

!BOP -------------------------------------------------------------------
!
! !IROUTINE: average_ -- Force an average to be taken on an Accumulator
!
! !DESCRIPTION:
! This routine will compute the average of the current values in an
! {\tt Accumulator} using the current value of {\tt steps\_done}
! in the {\tt Accumulator}
!
! !INTERFACE:

 subroutine average_(aC)

!
! !USES:
!
      use m_stdio, only : stdout,stderr
      use m_die,   only : die

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_nIAttr => nIAttr
      use m_AttrVect, only : AttrVect_nRAttr => nRAttr
      use m_AttrVect, only : AttrVect_indexRA => indexRA
      use m_AttrVect, only : AttrVect_indexIA => indexIA

      implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      type(Accumulator),  intent(inout) :: aC      ! Output Accumulator

! !REVISION HISTORY:
! 11Jan08 - R.Jacob <jacob@mcs.anl.gov> -- initial version based on accumulate_
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::average_'

! Overlapping attribute index number
  integer :: num_indices

! Overlapping attribute index storage arrays:
  integer, dimension(:), pointer :: aCindices, aVindices
  integer :: aCindex, aVindex

! Error flag and loop indices
  integer :: ierr, l, n

! Averaging time-weighting factor:
  real(FP) :: step_weight
  integer :: steps_done


  if(aC%num_steps == 0) then
     write(stderr,'(2a)') myname_,':: FATAL--Zero steps in accumulation cycle.'
     call die(myname_)
  endif

  if(aC%steps_done == 0) then
     write(stderr,'(2a)') myname_,':: FATAL--Zero steps completed in accumulation cycle.'
     call die(myname_)
  endif

        ! Set num_steps from aC:

  steps_done = aC%steps_done


   step_weight = 1.0_FP / REAL(steps_done,FP)
   do n=1,nRAttr_(aC)
      do l=1,lsize_(aC)
         aC%data%rAttr(n,l) = step_weight * aC%data%rAttr(n,l)
      enddo
   enddo

   do n=1,nIAttr_(aC)
       do l=1,lsize_(aC)
          aC%data%iAttr(n,l) = aC%data%iAttr(n,l) / steps_done
       enddo
   enddo


 end subroutine average_

 end module m_Accumulator
