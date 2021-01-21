
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: master.F90,v 1.5 2009-02-23 23:22:47 jacob Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !PROGRAM: master  -- driver for sequential coupled model example
!
! !DESCRIPTION:  Provide a simple example of using MCT to connect to
!  components executing sequentially in a single executable.
!
program master

!
! !USES:
!

  use m_AttrVect,only    : AttrVect
  use m_GlobalSegMap,only: GlobalSegMap
  use m_MCTWorld,only: MCTWorld_init => init

  use srcmodel
  use dstmodel
  use coupler

  implicit none

  include "mpif.h"

!
!EOP -------------------------------------------------------------------

!     local variables

  character(len=*), parameter :: mastername='master.F90'

  integer :: ncomps = 3   ! Must know total number of
                         ! components in coupled system

  integer,dimension(:),pointer :: comps  ! array with component ids


  type(AttrVect) :: srcImp,srcExp   ! import and export states for src and
  type(AttrVect) :: dstImp,dstExp   ! destination models

  type(GlobalSegMap) :: srcGSMap    ! decomposition descriptors for src and
  type(GlobalSegMap) :: dstGSMap    ! desitnation models

! other variables
  integer :: comm1, comm2, rank, nprocs,compid, myID, ier,color
  integer :: anprocs,cnprocs

!-----------------------------------------------------------------------
! The Main program.
! We are implementing a single-executable, sequential-execution system.
!
! This main program initializes MCT  and runs the whole model.

! Initialize MPI
  call MPI_INIT(ier)

! Get basic MPI information
  call MPI_COMM_SIZE(MPI_COMM_WORLD,nprocs,ier)
  call MPI_COMM_RANK(MPI_COMM_WORLD,rank,ier)

! Get communicators for each model
  call mpi_comm_dup(MPI_COMM_WORLD,comm1,ier)
  call mpi_comm_dup(MPI_COMM_WORLD,comm2,ier)

! Initialize MCT
  allocate(comps(ncomps),stat=ier)
  comps(1)=1
  comps(2)=2
  comps(3)=3
  call MCTWorld_init(ncomps,MPI_COMM_WORLD,comm1,myids=comps)


! Initialize the model
  call srcinit(srcGSMap,srcImp,srcExp,comm1,1)
  call dstinit(dstGSMap,dstImp,dstExp,comm2,2)
  call cplinit(srcGSMap,dstGSMap,comm1,3)

! Run the model

! source does something with srcImp and produces export
  call srcrun(srcImp,srcExp)

! map the source model's Export to the destination model's Import
  call cplrun(srcExp,dstImp)

! destination model does something with dstImp
  call dstrun(dstImp,dstExp)

! Finalize
  call srcfin(srcImp,srcExp,srcGSMap)
  call dstfin(dstImp,dstExp,dstGSMap)
  call cplfin

  call MPI_FINALIZE(ier)

end program master
