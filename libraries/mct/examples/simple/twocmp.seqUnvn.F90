!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: twocmp.seqUnvn.F90,v 1.6 2007-12-19 17:13:17 rloy Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !ROUTINE:  twocomponentUneven.sequential
!
! !DESCRIPTION:  Provide a simple example of using MCT to connect two components
!   In this case the models are running sequentialy but the second model
!   is only running on 1 processor.
!
! !INTERFACE:
!
      program twosequn
!
! !USES:
!
!--- Get only the things needed from MCT
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

      use m_Rearranger,only: Rearranger
      use m_Rearranger,only: MCT_Rearranger_init => init
      use m_Rearranger,only: MCT_Rearrange => Rearrange

      implicit none

      include 'mpif.h'

      integer,parameter :: ngx = 6   ! points in x-direction
      integer,parameter :: ngy = 4   ! points in y-direction

      integer ier,world_group,model2_group,myrank2,myrank3
      integer,dimension(:),pointer :: myids,mycomms,peloc2
      integer,dimension(:,:),pointer :: GlobalId
      integer :: comm1,comm2,asize,mysize,i,myproc
      integer :: commsize
      integer,dimension(1) :: start1,length1,ranks
      integer,dimension(:),allocatable :: start2,length2
!-----------------------------------------------------------------------
!  The Main program.
! We are implementing a single-executable, sequential-execution system.
! Because its sequential, communication occurs through the main using
! arguments.  The second component is only running on 1 processor

      type(GlobalSegMap) :: GSmap1,GSmap2
      type(AttrVect) :: av1,av2
      type(Rearranger) :: Rearr

      call MPI_init(ier)

      call mpi_comm_size(MPI_COMM_WORLD, mysize,ier)
      if(mysize .gt. 12) then
        write(6,*)"Must run on less than 12 processors"
        stop
      endif
      call mpi_comm_rank(MPI_COMM_WORLD, myproc,ier)

!  the first model is running on all the processors so give
!  it a dubplicate of MPI_COMM_WORLD for its communicator
      call mpi_comm_dup(MPI_COMM_WORLD,comm1,ier)

!  the second model is only running on one processor
!  so use mpi_groups methods to define its communicator
      call mpi_comm_group(MPI_COMM_WORLD,world_group,ier)

! need a communicator that only has the first processor
      ranks(1)=0
! define the group
      call mpi_group_incl(world_group,1,ranks,model2_group,ier)
! now define the communicator
      ! first initialize it
      comm2=MPI_COMM_NULL
      call mpi_comm_create(MPI_COMM_WORLD,model2_group,comm2,ier)

! don't need the groups anymore
      call mpi_group_free(world_group,ier)
      call mpi_group_free(model2_group,ier)

!  allocate arrays for the ids and comms
      allocate(myids(2),mycomms(2))

! Set the arrays to their values.
      myids(1)=1
      myids(2)=2
      mycomms(1)=comm1
      mycomms(2)=comm2

! now call the initm_ version of MCTWorld_init
      call MCTWorld_init(2,MPI_COMM_WORLD,mycomms,myids)


! first gsmap is the grid decomposed in one dimension
! there is 1 segment per processor
      length1(1)= (ngx * ngy)/mysize
      start1(1)= myproc * length1(1) + 1

      write(6,*)'gsmap1', myproc,length1(1),start1(1)
      call MCT_GSMap_init(GSMap1,start1,length1,0,comm1,1)

! second gsmap is the grid on one processor

! for GSMap init to work, the size of the start and length arrays
! must equal the number of local segments.  So I must allocate
! size zero arrays on the other processors.
      if(myproc .eq. 0) then
       allocate(start2(1),length2(1))
       length2(1) = ngx*ngy
       start2(1) = 1
      else
       allocate(start2(0),length2(0))
      endif

      call MCT_GSMap_init(GSMap2,start2,length2,0,comm1,2)
      write(6,*)'gsmap2', myproc,GSMap2%ngseg,GSmap2%gsize,GSmap2%start(1), &
                  GSmap2%pe_loc(1),GSmap2%length(1)


! initialize an Av on each GSMap
      call MCT_AtrVt_init(av1,rList="field1:field2",lsize=MCT_GSMap_lsize(GSMap1,comm1))

!  Use comm1 because lsize of GSMap2 on comm1 will return 0 on non-root processors.
!  We need av2 to be full-sized on proc 0 and 0 size on other processors.
      call MCT_AtrVt_init(av2,rList="field1:field2",lsize=MCT_GSMap_lsize(GSMap2,comm1))


! create a rearranger.  Use the communicator which contains all processors
! involved in the rearrangement, comm1
      call MCT_Rearranger_init(GSMap1,GSMap2,comm1,Rearr)

!-------------end of initialization steps


! Start up model1 which fills av1 with data.
      call model1(comm1,av1)

!  print out Av data
      do i=1,MCT_AtrVt_lsize(av1)
        write(6,*) "model 1 data", myproc,i,av1%rAttr(1,i),av1%rAttr(2,i)
      enddo

! rearrange data from model1 so that model2 can use it.
      call MCT_Rearrange(av1,av2,Rearr)

! pass data to model2 (which will print it out)
! model2 should only run on one processor.
      if(myproc .eq. 0) then
        call model2(comm2,av2)
      endif


! all done
      call MPI_Barrier(MPI_COMM_WORLD,ier)
      if (myproc==0) write(6,*) 'All Done'

      call mpi_finalize(ier)

      contains

!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
! !ROUTINE:
      subroutine model1(comm1,mod1av)   ! the first model

      implicit none

      integer :: comm1,mysize,ier,asize,myproc
      integer :: fieldindx,avsize,i
      integer,dimension(1) :: start,length
      real,pointer :: testarray(:)

      type(GlobalSegMap) :: GSmap
      type(AttrVect) :: mod1av
!---------------------------

!  find local rank and size
      call mpi_comm_size(comm1,mysize,ier)
      call mpi_comm_rank(comm1,myproc,ier)
      write(6,*)"model1 myproc,mysize",myproc,mysize


      avsize = MCT_AtrVt_lsize(mod1av)
      write(6,*)"model 1 myproc, av size", myproc,avsize

!  Fill Av with some data
!  fill first attribute the direct way
      fieldindx = MCT_AtrVt_indexRA(mod1av,"field1")
      do i=1,avsize
        mod1av%rAttr(fieldindx,i) = float(i+ 20*myproc)
      enddo

!  fill second attribute using Av import function
      allocate(testarray(avsize))
      do i=1,avsize
        testarray(i)= cos((float(i+ 20*myproc)/24.) * 3.14)
      enddo
      call MCT_AtrVt_importRA(mod1av,"field2",testarray)


      end subroutine model1

!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
! !ROUTINE:
      subroutine model2(comm2,mod2av)

      implicit none

      integer :: comm2,mysize,ier,asize,myproc
      integer :: i
      type(AttrVect) :: mod2av
!---------------------------

!  find local rank and size
      call mpi_comm_size(comm2,mysize,ier)
      call mpi_comm_rank(comm2,myproc,ier)
      write(6,*)"model2 myproc,mysize",myproc,mysize

      asize = MCT_AtrVt_lsize(mod2av)
      write(6,*)"model 2 myproc, av size", myproc,asize

!  print out Av data
      do i=1,asize
        write(6,*) "model 2 data after", myproc,i,mod2av%rAttr(1,i),mod2av%rAttr(2,i)
      enddo


      end subroutine model2

      end
