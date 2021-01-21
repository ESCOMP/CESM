!
! !INTERFACE:

 module m_MCTWORLDTEST
!
! !USES:
!
      implicit none

      private	! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: testall

    interface testall
       module procedure testMCTWorld_
    end interface


! !REVISION HISTORY:
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='m_MCTWORLDTEST'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: aVtest_ - Test the functions in the AttrVect module
!
! !DESCRIPTION:
! This routine writes diagnostic information about the input
! {\tt AttrVect}. Each line of the output will be preceded by the
! character argument {\tt identifier}. The output device is specified
! by the integer argument {\tt device}.
!
! !INTERFACE:

 subroutine testMCTWorld_(identifier, device)

!
! !USES:
!
      use m_MCTWorld         ! Use all of MCTWorld
      use m_stdio
      use m_die
      use m_mpif90

      implicit none

! !INPUT PARAMETERS:

      character(len=*),           intent(in)  :: identifier
      integer,                    intent(in)  :: device

! !REVISION HISTORY:
! 23Sep02 - E.T. Ong <eong@mcs.anl.gov> - initial prototype.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::testMCTWorld_'
  integer :: i,j,k
  integer :: mySize,ierr

  write(device,*) identifier, ":: TYPE CHECK:"

  write(device,*) identifier, ":: MCT_comm = ", ThisMCTWorld%MCT_comm
  write(device,*) identifier, ":: ncomps = ", ThisMCTWorld%ncomps
  write(device,*) identifier, ":: mygrank = ", ThisMCTWorld%mygrank

  if(associated(ThisMCTWorld%nprocspid).and.associated(ThisMCTWorld%idGprocid)) then

     write(device,*) identifier, ":: nprocspid = &
          &(compid , nprocspid(compid)) "

     do i=1,size(ThisMCTWorld%nprocspid)
        write(device,*) identifier, i, ThisMCTWorld%nprocspid(i)
     enddo

     write(device,*) identifier, "::idGprocid = &
          &(compid , local_PID, idGprocid(compid,local_PID)) "

     do i=1,size(ThisMCTWorld%idGprocid,1)
        do j=0,size(ThisMCTWorld%idGprocid,2)-1
           write(device,*) identifier, i, j, ThisMCTWorld%idGprocid(i,j)
        enddo
     enddo

  else

     call die(myname_, "MCTWorld pointer components are not associated!")

  endif

  write(device,*) identifier, ":: NumComponents = ", NumComponents(ThisMCTWorld)
  write(device,*) identifier, ":: ComponentNumProcs = &
       &(compid, ComponentNumProcs(compid)) = "
  do i=1,ThisMCTWorld%ncomps
     write(device,*) identifier, i, ComponentNumProcs(ThisMCTWorld, i)
  enddo

  write(device,*) identifier, ":: ComponentToWorldRank = &
       &(compid, local_PID, ComponentToWorldRank(local_PID,compid))"
  do i=1,ThisMCTWorld%ncomps
     do j=0,ThisMCTWorld%nprocspid(i)-1
        write(device,*) identifier, i, j, ComponentToWorldRank(j,i,ThisMCTWorld)
     enddo
  enddo

  write(device,*) identifier, ":: ComponentRootRank = (compid, &
       &ComponentRootRank(compid)"

  do i=1,ThisMCTWorld%ncomps
     write(device,*) identifier, i, ComponentRootRank(i,ThisMCTWorld)
  enddo

end subroutine testMCTWorld_

end module m_MCTWORLDTEST
