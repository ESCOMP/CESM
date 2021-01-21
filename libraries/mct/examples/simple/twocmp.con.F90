!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: twocmp.con.F90,v 1.4 2006-07-25 22:31:34 jacob Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !ROUTINE:  twocomponent.concurrent
!
! !DESCRIPTION:  Provide a simple example of using MCT to connect two
!  components executing concurrently in a single executable.
!
!
! !INTERFACE:
!
      program twocon
!
! !USES:
!
!--- Use only the things needed from MCT
      use m_MCTWorld,only: MCTWorld_init => init

      use m_GlobalSegMap,only: GlobalSegMap
      use m_GlobalSegMap,only: MCT_GSMap_init => init
      use m_GlobalSegMap,only: MCT_GSMap_lsize => lsize

      use m_AttrVect,only    : AttrVect
      use m_AttrVect,only    : MCT_AtrVt_init => init
      use m_AttrVect,only    : MCT_AtrVt_zero => zero
      use m_AttrVect,only    : MCT_AtrVt_lsize => lsize
      use m_AttrVect,only    : MCT_AtrVt_indexRA => indexRA
      use m_AttrVect,only    : MCT_AtrVt_importRA => importRAttr

      use m_Router,only: Router
      use m_Router,only: MCT_Router_init => init

      use m_Transfer,only : MCT_Send => send
      use m_Transfer,only : MCT_Recv => recv

      implicit none

      include 'mpif.h'
!-----------------------------------------------------------------------
      ! Local variables

      integer,parameter :: npoints = 24  ! number of grid points

      integer ier,nprocs
      integer color,myrank,mycomm
!-----------------------------------------------------------------------
!  The Main program.
! We are implementing a single-executable, concurrent-execution system.
! This small main program carves up MPI_COMM_WORLD and then starts
! each component on its own processor set.

      call MPI_init(ier)

      call mpi_comm_size(MPI_COMM_WORLD, nprocs,ier)
      call mpi_comm_rank(MPI_COMM_WORLD, myrank,ier)

      if((nprocs .gt. 14).or.(nprocs .lt. 3)) then
        write(6,*)"The small problem size in this example &
        &requires between 3 and 14 processors."
	write(6,*)"nprocs =",nprocs
        stop
      endif


!  Force the model1 to run on the first 2 processors
      color =1
      if (myrank .lt. 2) then
        color = 0
      endif

! Split MPI_COMM_WORLD into a communicator for each model
      call mpi_comm_split(MPI_COMM_WORLD,color,0,mycomm,ier)

! Start up the the models, pass in the communicators
      if(color .eq. 0) then
       call model1(mycomm)
      else
       call model2(mycomm)
      endif

! Models are finished.
      call mpi_finalize(ier)

      contains

!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
! !ROUTINE:
      subroutine model1(comm1)   ! the first model

      implicit none

      integer :: comm1,mysize,ier,asize,myproc
      integer :: fieldindx,avsize,i
      integer,dimension(1) :: start,length
      real,pointer :: testarray(:)

      type(GlobalSegMap) :: GSmap
      type(AttrVect) :: av1
      type(Router) :: Rout
!---------------------------

!  find local rank and size
      call mpi_comm_size(comm1,mysize,ier)
      call mpi_comm_rank(comm1,myproc,ier)
      write(6,*)"model1 size",mysize

!  initialize ThisMCTWorld
      call MCTWorld_init(2,MPI_COMM_WORLD,comm1,1)

!  set up a grid and decomposition
      asize =  npoints/mysize

      start(1)= (myproc*asize) +1
      length(1)=asize

!  describe decomposition with MCT GSmap type
      call MCT_GSMap_init(GSMap,start,length,0,comm1,1)

      write(6,*)"model 1 GSMap ngseg",myproc,GSMap%ngseg,start(1)

!  Initialize an Attribute Vector
      call MCT_AtrVt_init(av1,rList="field1:field2",lsize=MCT_GSMap_lsize(GSMap,comm1))

      avsize = MCT_AtrVt_lsize(av1)
      write(6,*)"model 1 av size", avsize

!  Fill Av with some data
!  fill first attribute the direct way
      fieldindx = MCT_AtrVt_indexRA(av1,"field1")
      do i=1,avsize
        av1%rAttr(fieldindx,i) = float(i)
      enddo

!  fill second attribute using Av import function
      allocate(testarray(avsize))
      do i=1,avsize
        testarray(i)= cos((float(i)/npoints) * 3.14)
      enddo
      call MCT_AtrVt_importRA(av1,"field2",testarray)

!  initialize a Router
      call MCT_Router_init(2,GSMap,comm1,Rout)

!  print out Av data
      do i=1,asize
        write(6,*) "model 1 data", myproc,i,av1%rAttr(1,i),av1%rAttr(2,i)
      enddo

!  send the data
      call MCT_Send(av1,Rout)



      end subroutine model1

!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
! !ROUTINE:
      subroutine model2(comm2)

      implicit none

      integer :: comm2,mysize,ier,asize,myproc
      integer :: i
      integer,dimension(1) :: start,length
      type(GlobalSegMap) :: GSmap
      type(AttrVect) :: av1
      type(Router)   :: Rout
!---------------------------

!  find local rank and size
      call mpi_comm_size(comm2,mysize,ier)
      call mpi_comm_rank(comm2,myproc,ier)
      write(6,*)"model2 size",mysize

!  initialize ThisMCTWorld
      call MCTWorld_init(2,MPI_COMM_WORLD,comm2,2)

!  set up a grid and decomposition
      asize =  npoints/mysize

      start(1)= (myproc*asize) +1
      length(1)=asize

!  describe decomposition with MCT GSmap type
      call MCT_GSMap_init(GSMap,start,length,0,comm2,2)

      write(6,*)"model 2 GSMap ngseg",myproc,GSMap%ngseg,start(1)

!  Initialize an Attribute Vector
      call MCT_AtrVt_init(av1,rList="field1:field2",lsize=MCT_GSMap_lsize(GSMap,comm2))

      write(6,*)"model 2 av size", MCT_AtrVt_lsize(av1)

! initialize Av to be zero everywhere
      call MCT_AtrVt_zero(av1)

!  initialize a Router
      call MCT_Router_init(1,GSMap,comm2,Rout)

!  print out Av data before Recv
      do i=1,asize
        write(6,*) "model 2 data", myproc,i,av1%rAttr(1,i),av1%rAttr(2,i)
      enddo

!  Recv the data
      call MCT_Recv(av1,Rout)

!  print out Av data after Recv.
      do i=1,asize
        write(6,*) "model 2 data after", myproc,i,av1%rAttr(1,i),av1%rAttr(2,i)
      enddo


      end subroutine model2

      end
