!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: model.F90,v 1.8 2004-04-23 20:56:23 jacob Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !ROUTINE: model -- generic model for unit tester
!
! !DESCRIPTION:
! A generic model subroutine to test functionality of MCT.
!
! !INTERFACE:
!
      subroutine model (comm,ncomps,compid)
!
! !USES:
!
! Get the things needed from MCT by "Use,only" with renaming:
!
!---Component Model Registry
      use m_MCTWorld,only: MCTWorld_init => init
      use m_MCTWorld,only: MCTWorld_clean => clean
!---Domain Decomposition Descriptor DataType and associated methods
      use m_GlobalSegMap,only: GlobalSegMap
      use m_GlobalSegMap,only: GlobalSegMap_init => init
      use m_GlobalSegMap,only: GlobalSegMap_lsize => lsize
      use m_GlobalSegMap,only: GlobalSegMap_clean => clean
      use m_GlobalSegMap,only: GlobalSegMap_Ordpnts => OrderedPoints
!---Field Storage DataType and associated methods
      use m_AttrVect,only    : AttrVect
      use m_AttrVect,only    : AttrVect_init => init
      use m_AttrVect,only    : AttrVect_clean => clean
      use m_AttrVect,only    : AttrVect_indxR => indexRA
      use m_AttrVect,only    : AttrVect_importRAttr => importRAttr
!---Intercomponent communications scheduler
      use m_Router,only: Router
      use m_Router,only: Router_init => init
      use m_Router,only: Router_clean => clean
!---Intercomponent transfer
      use m_Transfer,only : MCT_Send => send
      use m_Transfer,only : MCT_Recv => recv
!---Stored Grid data

      implicit none

      include "mpif.h"

! !INPUT PARAMETERS:

      integer,intent(in) :: comm    ! MPI communicator for this component
      integer,intent(in) :: ncomps  ! total number of models in coupled system
      integer,intent(in) :: compid  ! the integer id of this model
!
!EOP ___________________________________________________________________

!     local variables

!     parameters for this model
      character(len=*), parameter :: modelname='model.F90'
      integer,parameter :: nxa = 128  ! number of points in x-direction
      integer,parameter :: nya = 64   ! number of points in y-direction

      integer :: i,j,k

!     note decleration of instances of MCT defined types.
! MPI variables
      integer :: rank, nprocs, root, CplID, ierr
! Grid variables
      integer :: localsize
! GlobalSegMap variables
      type(GlobalSegMap)   :: GSMap             ! MCT defined type
      integer,dimension(1) :: start,length
      integer, dimension(:), pointer :: points
! AttrVect variables
      type(AttrVect) :: AV                      ! MCT defined type
      real, dimension(:), pointer :: avdata
      integer :: avsize
! Router variables
      type(Router) :: Rout                      ! MCT defined type
! _____________________________________________________________________


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   INITIALIZATION PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      ! Get local rank and size
      call MPI_COMM_RANK (comm,rank, ierr)
      call MPI_COMM_SIZE(comm,nprocs,ierr)
      root = 0

      if(rank==0) write(6,*) modelname,' MyID ', compid
      if(rank==0) write(6,*) modelname,' Num procs ', nprocs

      ! Initialize MCTworld
      call MCTWorld_init(ncomps,MPI_COMM_WORLD,comm,compid)


      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Initialize a Global Segment Map

      ! set up a 1-d decomposition.
      ! there is just 1 segment per processor
      localsize = nxa*nya / nprocs

      ! we'll use the distributed init of GSMap so
      ! initialize start and length arrays for this processor
      start(1) = (rank*localsize) + 1
      length(1) = localsize

      ! initialize the GSMap
      call GlobalSegMap_init(GSMap,start,length,root,comm,compid)
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


      ! Use a GSMap function:
      ! return the points local to this processor
      ! in their assumed order.
      call GlobalSegMap_Ordpnts(GSMap,rank,points)


      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Initialize an Attribute vector

      ! size is the number of grid point on this processor
      avsize = GlobalSegMap_lsize(GSMap,comm)
      if(rank==0) write(6,*) modelname, ' localsize ', avsize

      ! initialize Av with two real attributes.
      call AttrVect_init(AV,rList="field1:field2",lsize=avsize)
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Initialize a router to the coupler component.
      !
      ! Need to know the integer ID of the coupler.
      CplID = 2
      call Router_init(CplID,GSMap,comm,Rout)

      !  create an array used in RUN
      allocate(avdata(avsize),stat=ierr)
!!! END OF INIT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   RUN PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


      do j=1,10    ! "timestep" loop


        ! model calculations


        ! load data into aV
        ! load the first field using "import" method.
        ! First field will be a constant real number.
        avdata=30.0
        call AttrVect_importRAttr(AV,"field1",avdata)

        ! Load the second field using direct access
        ! Second field will be the indicies of each grid point
        ! in the grid point numbering scheme.
        do i=1,avsize
           AV%rAttr(AttrVect_indxR(AV,"field2"),i) = points(i)
        enddo

        ! Send the data
        !  this is a synchronization point between the coupler and
        !   this model.
        if(rank==0) write(6,*) modelname,' sending data step ',j
        call MCT_Send(AV,Rout)


        ! more model calculations


      enddo

!!! END OF RUN  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   FINALIZE PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! clean up
      call Router_clean(Rout)
      call AttrVect_clean(AV)
      call GlobalSegMap_clean(GSMap)
      call MCTWorld_clean()
      if(rank==0) write(6,*) modelname,' done'
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    end subroutine model

