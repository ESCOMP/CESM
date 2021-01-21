!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_AccumulatorComms - MPI Communication Methods for the Accumulator
!
!
! !DESCRIPTION:
!
! This module contains communications methods for the {\tt Accumulator}
! datatype (see {\tt m\_Accumulator} for details).  MCT's communications
! are implemented in terms of the Message Passing Interface (MPI) standard,
! and we have as best as possible, made the interfaces to these routines
! appear as similar as possible to the corresponding MPI routines.  For the
! { \tt Accumulator}, we currently support only the following collective
! operations: broadcast, gather, and scatter.  The gather and scatter
! operations rely on domain decomposition descriptors that are defined
! elsewhere in MCT:  the {\tt GlobalMap}, which is a one-dimensional
! decomposition (see the MCT module {\tt m\_GlobalMap} for more details);
! and the {\tt GlobalSegMap}, which is a segmented decomposition capable
! of supporting multidimensional domain decompositions (see the MCT module
! {\tt m\_GlobalSegMap} for more details).
!
! !INTERFACE:

 module m_AccumulatorComms
!
! !USES:
!
! No external modules are used in the declaration section of this module.

      implicit none

      private	! except

! !PUBLIC MEMBER FUNCTIONS:
!
! List of communications Methods for the Accumulator class

      public :: gather		! gather all local vectors to the root
      public :: scatter		! scatter from the root to all PEs
      public :: bcast		! bcast from root to all PEs

! Definition of interfaces for the communication methods for
! the Accumulator:

    interface gather ; module procedure &
              GM_gather_, &
              GSM_gather_
    end interface
    interface scatter ; module procedure &
              GM_scatter_, &
              GSM_scatter_
    end interface
    interface bcast  ; module procedure bcast_  ; end interface

! !REVISION HISTORY:
! 31Oct00 - Jay Larson <larson@mcs.anl.gov> - initial prototype--
!           These routines were separated from the module m_Accumulator
! 15Jan01 - Jay Larson <larson@mcs.anl.gov> - Specification of
!           APIs for the routines GSM_gather_() and GSM_scatter_().
! 10May01 - Jay Larson <larson@mcs.anl.gov> - Changes in the
!           comms routine to match the MPI model for collective
!           communications, and general clean-up of prologues.
!  9Aug01 - E.T. Ong <eong@mcs.anl.gov> - Added private routine
!           bcastp_. Used new Accumulator routines initp_ and
!           initialized_ to simplify the routines.
!  26Aug02 - E.T. Ong <eong@mcs.anl.gov> - thourough code revision;
!            no added routines
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_AccumulatorComms'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GM_gather_ - Gather Accumulator Distributed by a GlobalMap
!
! !DESCRIPTION:  {\tt GM\_gather()} takes a distributed (across the
! communicator associated with the handle {\tt comm}) input
! {\tt Accumulator} argument {\tt iC} and gathers its data to the
! {\tt Accumulator} {\tt oC} on the {\tt root}.  The decomposition of
! {\tt iC} is described by the input {\tt GlobalMap} argument {\tt Gmap}.
! The success (failure) of this operation is signified by the zero (nonzero)
! value of the optional output argument {\tt stat}.
!
! !INTERFACE:

 subroutine GM_gather_(iC, oC, GMap, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_GlobalMap, only : GlobalMap
      use m_AttrVect, only : AttrVect_clean => clean
      use m_Accumulator, only : Accumulator
      use m_Accumulator, only : Accumulator_initialized => initialized
      use m_Accumulator, only : Accumulator_initv => init
      use m_AttrVectComms, only : AttrVect_gather => gather

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator), intent(in)  :: iC
      type(GlobalMap) ,  intent(in)  :: GMap
      integer,           intent(in)  :: root
      integer,           intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      type(Accumulator), intent(out) :: oC
      integer, optional,intent(out)  :: stat

! !REVISION HISTORY:
! 13Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
! 31Oct00 - Jay Larson <larson@mcs.anl.gov> - relocated to the
!           module m_AccumulatorComms
! 15Jan01 - Jay Larson <larson@mcs.anl.gov> - renamed GM_gather_
! 10May01 - Jay Larson <larson@mcs.anl.gov> - revamped comms
!           model to match MPI comms model, and cleaned up prologue
!  9Aug01 - E.T. Ong <eong@mcs.anl.gov> - 2nd prototype. Used the
!           intiialized_ and accumulator init routines.
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::GM_gather_'
 integer :: myID, ier, i
 logical :: status

        ! Initialize status flag (if present)

  if(present(stat)) stat=0

  call MP_comm_rank(comm, myID, ier)
  if(ier /= 0) call MP_perr_die(myname_,'MP_comm_rank()',ier)

        ! Argument check of iC: kill if iC is not initialized
        ! on all processes

  status = Accumulator_initialized(iC,die_flag=.true.,source_name=myname_)

        ! NOTE: removed argument check for oC on the root.
        ! Is there any good way to check if an accumulator is NOT initialized?

        ! Initialize oC from iC. Clean oC%data - we don't want this av.

  if(myID == root) then

     call Accumulator_initv(oC,iC,lsize=1, &
                            num_steps=iC%num_steps,steps_done=iC%steps_done)
     call AttrVect_clean(oC%data)

  endif

       ! Initialize oC%data. Gather distributed iC%data to oC%data on the root

  call AttrVect_gather(iC%data, oC%data, GMap, root, comm, ier)

  if(ier /= 0) then
    call perr(myname_,'AttrVect_gather(iC%data, oC%data...',ier)
    if(.not.present(stat)) call die(myname_)
    stat=ier
    return
  endif

        ! Check oC to see if its valid

  if(myID == root) then
     status = Accumulator_initialized(oC,die_flag=.true.,source_name=myname_)
  endif

 end subroutine GM_gather_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GSM_gather_ - Gather Accumulator Distributed by a GlobalSegMap
!
! !DESCRIPTION:  This routine takes the distrubuted (on the communcator
! associated with the handle {\tt comm}) input {\tt Accumulator}
! argument {\tt iC} gathers it to the the {\tt Accumulator} argument
! {\tt oC} (valid only on the {\tt root}).  The decompositon of {\tt iC}
! is contained in the input {\tt GlobalSegMap} argument {\tt GSMap}.
! The success (failure) of this operation is signified by the zero
! (nonzero) returned value of the {\tt INTEGER} flag {\tt stat}.
!
! !INTERFACE:

 subroutine GSM_gather_(iC, oC, GSMap, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_GlobalSegMap, only : GlobalSegMap
      use m_AttrVect, only : AttrVect_clean => clean
      use m_Accumulator, only : Accumulator
      use m_Accumulator, only : Accumulator_initv => init
      use m_Accumulator,   only : Accumulator_initialized => initialized
      use m_AttrVectComms, only : AttrVect_gather => gather

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator),  intent(in) :: iC
      type(GlobalSegMap), intent(in) :: GSMap
      integer,            intent(in) :: root
      integer,            intent(in) :: comm

! !OUTPUT PARAMETERS:
!
      type(Accumulator), intent(out) :: oC
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
! 	15Jan01 - Jay Larson <larson@mcs.anl.gov> - API specification.
! 	10May01 - Jay Larson <larson@mcs.anl.gov> - Initial code and
!                 cleaned up prologue.
!       09Aug01 - E.T. Ong <eong@mcs.anl.gov> - 2nd prototype. Used the
!                 intiialized_ and accumulator init routines.
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::GSM_gather_'
 integer :: myID, ier, i
 logical :: status

        ! Initialize status flag (if present)

  if(present(stat)) stat=0

  call MP_comm_rank(comm, myID, ier)
  if(ier /= 0) call MP_perr_die(myname_,'MP_comm_rank()',ier)

        ! Argument check of iC

  status = Accumulator_initialized(iC,die_flag=.true.,source_name=myname_)

        ! NOTE: removed argument check for oC on the root.
        ! Is there any good way to check if an accumulator is NOT initialized?

        ! Initialize oC from iC. Clean oC%data - we don't want this av.

  if(myID == root) then
     call Accumulator_initv(oC,iC,lsize=1, &
                            num_steps=iC%num_steps,steps_done=iC%steps_done)
     call AttrVect_clean(oC%data)
  endif

       ! Gather distributed iC%data to oC%data on the root

  call AttrVect_gather(iC%data, oC%data, GSMap, root, comm, ier)

  if(ier /= 0) then
    call perr(myname_,'AttrVect_gather(iC%data, oC%data...',ier)
    if(.not.present(stat)) call die(myname_)
    stat=ier
    return
  endif

        ! Check oC to see if its valid

  if(myID == root) then
     status = Accumulator_initialized(oC,die_flag=.true.,source_name=myname_)
  endif


 end subroutine GSM_gather_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GM_scatter_ - Scatter an Accumulator using a GlobalMap
!
! !DESCRIPTION:  This routine takes the input {\tt Accumulator} argument
! {\tt iC} (valid only on the {\tt root}), and scatters it to the
! distributed {\tt Accumulator} argument {\tt oC} on the processes
! associated with the communicator handle {\tt comm}.  The decompositon
! used to scatter the data is contained in the input {\tt GlobalMap}
! argument {\tt GMap}.  The success (failure) of this operation is
! signified by the zero (nonzero) returned value of the {\tt INTEGER}
! flag {\tt stat}.
!
! !INTERFACE:

 subroutine GM_scatter_(iC, oC, GMap, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_GlobalMap,   only : GlobalMap
      use m_Accumulator, only : Accumulator
      use m_Accumulator, only : Accumulator_initv => init
      use m_Accumulator, only : Accumulator_initialized => initialized
      use m_AttrVect, only : AttrVect_clean => clean
      use m_AttrVectComms, only : AttrVect_scatter => scatter

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator), intent(in)  :: iC
      type(GlobalMap),   intent(in)  :: GMap
      integer,           intent(in)  :: root
      integer,           intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      type(Accumulator), intent(out) :: oC
      integer, optional, intent(out) :: stat

! !REVISION HISTORY:
! 	14Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
! 	31Oct00 - Jay Larson <larson@mcs.anl.gov> - moved from the module
!                 m_Accumulator to m_AccumulatorComms
! 	15Jan01 - Jay Larson <larson@mcs.anl.gov> - renamed GM_scatter_.
!       10May01 - Jay Larson <larson@mcs.anl.gov> - revamped code to fit
!                 MPI-like comms model, and cleaned up prologue.
!       09Aug01 - E.T. Ong <eong@mcs.anl.gov> - 2nd prototype. Used the
!                 initialized_, Accumulator init_, and bcastp_ routines.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GM_scatter_'

  integer :: myID, ier
  logical :: status

        ! Initialize status flag (if present)

  if(present(stat)) stat=0

  call MP_comm_rank(comm, myID, ier)
  if(ier /= 0) call MP_perr_die(myname_,'MP_comm_rank()',ier)

        ! Argument check of iC

  if(myID==root) then
     status = Accumulator_initialized(iC,die_flag=.true.,source_name=myname_)
  endif

        ! NOTE: removed argument check for oC on all processes.
        ! Is there any good way to check if an accumulator is NOT initialized?

        ! Copy accumulator from iC to oC
        ! Clean up oC%data on root.

  if(myID == root) then
     call Accumulator_initv(oC,iC,lsize=1,num_steps=iC%num_steps, &
                            steps_done=iC%steps_done)
     call AttrVect_clean(oC%data)
  endif

        ! Broadcast oC (except for oC%data)

  call bcastp_(oC, root, comm, stat)

	! Scatter the AttrVect component of iC

  call AttrVect_scatter(iC%data, oC%data, GMap, root, comm, ier)

  if(ier /= 0) then
    call perr(myname_,'AttrVect_scatter(iC%data, oC%data...',ier)
    if(.not.present(stat)) call die(myname_)
    stat=ier
    return
  endif

        ! Check oC to see if its valid

  status = Accumulator_initialized(oC,die_flag=.true.,source_name=myname_)

 end subroutine GM_scatter_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: GSM_scatter_ - Scatter an Accumulator using a GlobalSegMap
!
! !DESCRIPTION:  This routine takes the input {\tt Accumulator} argument
! {\tt iC} (valid only on the {\tt root}), and scatters it to the
! distributed {\tt Accumulator} argument {\tt oC} on the processes
! associated with the communicator handle {\tt comm}.  The decompositon
! used to scatter the data is contained in the input {\tt GlobalSegMap}
! argument {\tt GSMap}.  The success (failure) of this operation is
! signified by the zero (nonzero) returned value of the {\tt INTEGER}
! flag {\tt stat}.
!
! !INTERFACE:

 subroutine GSM_scatter_(iC, oC, GSMap, root, comm, stat)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_GlobalSegMap, only : GlobalSegMap
      use m_Accumulator, only : Accumulator
      use m_Accumulator, only : Accumulator_initv => init
      use m_Accumulator, only : Accumulator_initialized => initialized
      use m_AttrVect, only : AttrVect_clean => clean
      use m_AttrVectComms, only : AttrVect_scatter => scatter

      implicit none

! !INPUT PARAMETERS:
!
      type(Accumulator),  intent(in)  :: iC
      type(GlobalSegMap), intent(in)  :: GSMap
      integer,            intent(in)  :: root
      integer,            intent(in)  :: comm

! !OUTPUT PARAMETERS:
!
      type(Accumulator),  intent(out) :: oC
      integer, optional,  intent(out) :: stat

! !REVISION HISTORY:
! 	15Jan01 - Jay Larson <larson@mcs.anl.gov> - API specification.
! 	10May01 - Jay Larson <larson@mcs.anl.gov> - Initial code/prologue
!       09Aug01 - E.T. Ong <eong@mcs.anl.gov> 2nd prototype. Used the
!                 initialized and accumulator init routines.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::GSM_scatter_'

  integer :: myID, ier
  logical :: status

        ! Initialize status flag (if present)

  if(present(stat)) stat=0

  call MP_comm_rank(comm, myID, ier)
  if(ier /= 0) call MP_perr_die(myname_,'MP_comm_rank()',ier)

        ! Argument check of iC

  if(myID == root) then
     status = Accumulator_initialized(iC,die_flag=.true.,source_name=myname_)
  endif

        ! NOTE: removed argument check for oC on all processes.
        ! Is there any good way to check if an accumulator is NOT initialized?

        ! Copy accumulator from iC to oC
        ! Clean up oC%data on root.

  if(myID == root) then
     call Accumulator_initv(oC,iC,lsize=1,num_steps=iC%num_steps, &
                            steps_done=iC%steps_done)
     call AttrVect_clean(oC%data)
  endif

        ! Broadcast oC (except for oC%data)

  call bcastp_(oC, root, comm, stat)

	! Scatter the AttrVect component of aC

  call AttrVect_scatter(iC%data, oC%data, GSMap, root, comm, ier)

  if(ier /= 0) then
    call perr(myname_,'AttrVect_scatter(iC%data, oC%data...',ier)
    if(.not.present(stat)) call die(myname_)
    stat=ier
    return
  endif

        ! Check oC if its valid

  status = Accumulator_initialized(oC,die_flag=.true.,source_name=myname_)


 end subroutine GSM_scatter_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: bcast_ - Broadcast an Accumulator
!
! !DESCRIPTION:  This routine takes the input {\tt Accumulator} argument
! {\tt aC} (on input valid only on the {\tt root}), and broadcasts it
! to all the processes associated with the communicator handle
! {\tt comm}.  The success (failure) of this operation is signified by
! the zero (nonzero) returned value of the {\tt INTEGER} flag {\tt stat}.
!
! !INTERFACE:
!
 subroutine bcast_(aC, root, comm, stat)

!
! !USES:
!
      use m_die
      use m_mpif90
      use m_AttrVectComms, only : AttrVect_bcast => bcast

      use m_Accumulator, only : Accumulator
      use m_Accumulator, only : Accumulator_initialized => initialized

      implicit none

! !INPUT PARAMETERS:
!
      integer,intent(in) :: root
      integer,intent(in) :: comm

! !INPUT/OUTPUT PARAMETERS:
!
      type(Accumulator), intent(inout) :: aC ! (IN) on root, (OUT) elsewhere

! !OUTPUT PARAMETERS:
!
      integer, optional, intent(out)   :: stat

! !REVISION HISTORY:
! 	14Sep00 - Jay Larson <larson@mcs.anl.gov> - initial prototype
! 	31Oct00 - Jay Larson <larson@mcs.anl.gov> - moved from the module
!                 m_Accumulator to m_AccumulatorComms
!       09May01 - Jay Larson <larson@mcs.anl.gov> - cleaned up prologue
!       09Aug01 - E.T. Ong <eong@mcs.anl.gov> - 2nd prototype. Made use of
!                 bcastp_ routine. Also more argument checks.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::bcast_'

  integer :: myID
  integer :: ier
  logical :: status

  if(present(stat)) stat=0

  call MP_comm_rank(comm,myID,ier)
  if(ier /= 0) call MP_perr_die(myname_,'MP_comm_rank()',ier)

        ! Argument check : Kill if the root aC is not initialized,
        ! or if the non-root aC is initialized

  if(myID == root) then
     status = Accumulator_initialized(aC,die_flag=.true.,source_name=myname_)
  endif

        ! NOTE: removed argument check for aC on all non-root processes.
        ! Is there any good way to check if an accumulator is NOT initialized?

  call bcastp_(aC, root, comm, stat)


	! Broadcast the root value of aC%data

  call AttrVect_bcast(aC%data, root, comm, ier)

  if(ier /= 0) then
    call perr(myname_,'AttrVect_bcast(aC%data)',ier)
    if(.not.present(stat)) call die(myname_)
    stat=ier
    return
  endif

        ! Check that aC on all processes are initialized

  status = Accumulator_initialized(aC,die_flag=.true.,source_name=myname_)


 end subroutine bcast_


!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: bcastp_ - Broadcast an Accumulator (but Not its Registers)
!
! !DESCRIPTION:  This routine broadcasts all components of the accumulator
!                aC except for aC%data. This is a private routine, only meant
!                to be used by accumulator scatter and gather routines.
!
!
! !INTERFACE:
!
 subroutine bcastp_(aC, root, comm, stat)

!
! !USES:
!
      use m_die
      use m_mpif90
      use m_AttrVectComms, only : AttrVect_bcast => bcast
      use m_Accumulator, only : Accumulator
      use m_Accumulator, only : Accumulator_initp => initp
      use m_Accumulator, only : Accumulator_nIAttr => nIAttr
      use m_Accumulator, only : Accumulator_nRAttr => nRAttr

      implicit none

! !INPUT PARAMETERS:
!
      integer,intent(in) :: root
      integer,intent(in) :: comm

! !INPUT/OUTPUT PARAMETERS:
!
      type(Accumulator), intent(inout) :: aC ! (IN) on root, (OUT) elsewhere

! !OUTPUT PARAMETERS:
!
      integer, optional, intent(out)   :: stat

! !REVISION HISTORY:
!       09Aug01 - E.T. Ong <eong@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::bcastp_'

  integer :: myID
  integer :: ier, i
  integer :: aC_num_steps, aC_steps_done, aC_nIAttr, aC_nRAttr
  integer :: FirstiActionIndex, LastiActionIndex
  integer :: FirstrActionIndex, LastrActionIndex
  integer :: AccBuffSize
  integer :: nIAttr, nRAttr
  integer, dimension(:), allocatable :: AccBuff, aC_iAction, aC_rAction
  logical :: status

  if(present(stat)) stat=0

  call MP_comm_rank(comm,myID,ier)
  if(ier /= 0) call MP_perr_die(myname_,'MP_comm_rank()',ier)

        ! STEP 1: Pack broadcast buffer.

        ! On the root, load up the Accumulator Buffer: Buffer Size =
        ! num_steps {1} + steps_done {1} + nIAttr {1} + nRAttr {1} +
        ! iAction {nIAttr} + rAction {nRAttr}


  if(myID == root) then

     if(associated(aC%iAction)) then
	nIAttr = size(aC%iAction)
     else
	nIAttr = 0
     endif

     if(associated(aC%rAction)) then
	nRAttr = size(aC%rAction)
     else
	nRAttr = 0
     endif

     AccBuffSize = 4+nIAttr+nRAttr

  endif

        ! Use AccBuffSize to initialize AccBuff on all processes

  call MPI_BCAST(AccBuffSize, 1, MP_INTEGER, root, comm, ier)

  if(ier /= 0) call MP_perr_die(myname_,'AttrVect_bcast(AccBuffSize)',ier)

  allocate(AccBuff(AccBuffSize),stat=ier)
  if(ier /= 0) call MP_perr_die(myname_,"AccBuff allocate",ier)

  if(myID == root) then

        ! load up iC%num_steps and iC%steps_done

     AccBuff(1) = aC%num_steps
     AccBuff(2) = aC%steps_done

        ! Load up nIAttr and nRAttr

     AccBuff(3) = nIAttr
     AccBuff(4) = nRAttr

        ! Load up aC%iAction (pointer copy)

     do i=1,nIAttr
	AccBuff(4+i) = aC%iAction(i)
     enddo

        ! Load up aC%rAction (pointer copy)

     do i=1,nRAttr
	AccBuff(4+nIAttr+i) = aC%rAction(i)
     enddo
  endif

        ! STEP 2: Broadcast

	! Broadcast the root value of AccBuff

  call MPI_BCAST(AccBuff, AccBuffSize, MP_INTEGER, root, comm, ier)

  if(ier /= 0) call MP_perr_die(myname_,'MPI_bcast(AccBuff...',ier)


        ! STEP 3: Unpack broadcast buffer.

        ! On all processes  unload aC_num_steps, aC_steps_done
        ! aC_nIAttr, and aC_nRAttr from StepBuff

  aC_num_steps  = AccBuff(1)
  aC_steps_done = AccBuff(2)
  aC_nIAttr = AccBuff(3)
  aC_nRAttr = AccBuff(4)

        ! Unload iC%iAction and iC%rAction

  if(aC_nIAttr > 0) then
     allocate(aC_iAction(aC_nIAttr),stat=ier)
     if(ier /= 0) call die(myname_,"allocate aC_iAction",ier)

     FirstiActionIndex = 5
     LastiActionIndex = 4+aC_nIAttr
     aC_iAction(1:aC_nIAttr) = AccBuff(FirstiActionIndex:LastiActionIndex)

  endif

  if(aC_nRAttr > 0) then
     allocate(aC_rAction(aC_nRAttr),stat=ier)
     if(ier /= 0) call die(myname_,"allocate aC_rAction",ier)

     FirstrActionIndex = 5+aC_nIAttr
     LastrActionIndex = 4+aC_nIAttr+aC_nRAttr
     aC_rAction(1:aC_nRAttr) = AccBuff(FirstrActionIndex:LastrActionIndex)

  endif

	! Initialize aC on non-root processes

  if( (aC_nIAttr > 0).and.(aC_nRAttr > 0) ) then

     if(myID /= root) then
	call Accumulator_initp(aC,iAction=aC_iAction,rAction=aC_rAction, &
                               num_steps=aC_num_steps, &
                               steps_done=aC_steps_done)
     endif

     deallocate(aC_iAction,aC_rAction,stat=ier)
     if(ier /= 0) call die(myname_,"deallocate aC_iAction...",ier)

  else

     if (aC_nIAttr > 0) then
	if(myID /= root) then
	   call Accumulator_initp(aC,iAction=aC_iAction, &
                                  num_steps=aC_num_steps, &
                                  steps_done=aC_steps_done)
	endif
	deallocate(aC_iAction,stat=ier)
	if(ier /= 0) call die(myname_,"deallocate aC_iAction...",ier)
     endif

     if (aC_nRAttr > 0) then
	if(myID /= root) then
	   call Accumulator_initp(aC,rAction=aC_rAction, &
                                  num_steps=aC_num_steps, &
                                  steps_done=aC_steps_done)
	endif
	deallocate(aC_rAction,stat=ier)
	if(ier /= 0) call die(myname_,"deallocate aC_iAction...",ier)
     endif

  endif

  ! Clean up allocated arrays

  deallocate(AccBuff,stat=ier)
  if(ier /= 0) call die(myname_,"deallocate(AccBuff)",ier)


 end subroutine bcastp_


 end module m_AccumulatorComms







