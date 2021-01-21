!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: twocmp.seqNB.F90,v 1.4 2004-06-24 21:07:01 eong Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !ROUTINE:  twocmp.seqNB
!
! !DESCRIPTION:  Provide a simple example of using MCT to connect to
!  components executing sequentially in a single executable using
!  the non-blocking communications to transfer data.
!
!
! !INTERFACE:
!
      program twocmpseqNB
!
! !USES:
!
!--- Use only the things needed from MCT
      use m_MCTWorld,only: MCTWorld_init => init

      use m_GlobalSegMap,only: GlobalSegMap
      use m_GlobalSegMap,only: MCT_GSMap_init => init
      use m_GlobalSegMap,only: MCT_GSMap_lsize => lsize
      use m_GlobalSegMapComms,only: MCT_GSMap_recv => recv
      use m_GlobalSegMapComms,only: MCT_GSMap_isend => isend
      use m_GlobalSegMapComms,only: MCT_GSMap_bcast => bcast

      use m_AttrVect,only    : AttrVect
      use m_AttrVect,only    : MCT_AtrVt_init => init
      use m_AttrVect,only    : MCT_AtrVt_zero => zero
      use m_AttrVect,only    : MCT_AtrVt_lsize => lsize
      use m_AttrVect,only    : MCT_AtrVt_indexRA => indexRA
      use m_AttrVect,only    : MCT_AtrVt_importRA => importRAttr

      use m_Router,only: Router
      use m_Router,only: MCT_Router_init => init

      use m_Transfer,only : MCT_ISend => isend
      use m_Transfer,only : MCT_Recv => recv

      implicit none

      include 'mpif.h'

      integer,parameter :: npoints = 24  ! total number of grid points
      integer ier,nprocs,i
      integer color,myrank,comm1,comm2
      integer,dimension(:),pointer :: myids
      integer,dimension(:),pointer :: req1,req2
!-----------------------------------------------------------------------
!  The Main program.
! We are implementing a single-executable, seqeuntial-execution system.
! This small main program sets up MCTWorld, calls each "init" method
! and then calls each component in turn.

      type(GlobalSegMap) :: GSMap1,GSMap2
      type(AttrVect) :: Av1,Av2

      call MPI_init(ier)

      call mpi_comm_size(MPI_COMM_WORLD, nprocs,ier)
      call mpi_comm_rank(MPI_COMM_WORLD, myrank,ier)

! Duplicate MPI_COMM_WORLD into a communicator for each model
      call mpi_comm_dup(MPI_COMM_WORLD,comm1,ier)
      call mpi_comm_dup(MPI_COMM_WORLD,comm2,ier)

      allocate(myids(2))
      myids(1)=1
      myids(2)=2

! Initialize MCT world
      call MCTWorld_init(2,MPI_COMM_WORLD,comm1,myids=myids)

! Initialize the models, pass in the communicators
      call model1init(comm1,req1,GSMap1,Av1)
      call model2init(comm2,req2,GSMap2,Av2)

!-----------------end of initialization phase ------
! Run the models, pass in the communicators
      do i=1,5
       write(6,*) " "
       write(6,*) "Step ",i
       call model1(comm1,GSMap1,Av1)
       call model2(comm2,GSMap2,Av2)
      enddo

! Models are finished.
      call mpi_finalize(ier)

      contains

!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
! !ROUTINE:
      subroutine model1init(comm1,req1,GSmap,av1)   ! init the first model

      implicit none

      integer :: comm1,mysize,ier,asize,myproc
      integer :: fieldindx,avsize,i
      integer,dimension(1) :: start,length
      real,pointer :: testarray(:)
      integer,pointer :: req1(:)

      type(GlobalSegMap) :: GSmap
      type(AttrVect) :: av1
!---------------------------

!  find local rank and size
      call mpi_comm_size(comm1,mysize,ier)
      call mpi_comm_rank(comm1,myproc,ier)
      write(6,*)myproc,"model1 size",mysize

!  set up a grid and decomposition
      asize =  npoints/mysize

      start(1)= (myproc*asize) +1
      length(1)=asize

!  describe decomposition with MCT GSmap type
      call MCT_GSMap_init(GSMap,start,length,0,comm1,1)

      write(6,*)myproc,"model 1 GSMap ngseg",GSMap%ngseg,start(1)

      if(myproc .eq. 0) call MCT_GSMap_Isend(GSMap,2,100,req1)

!  Initialize an Attribute Vector
      call MCT_AtrVt_init(av1,rList="field1:field2",lsize=MCT_GSMap_lsize(GSMap,comm1))
      write(6,*)myproc,"model1 got an aV"

      avsize = MCT_AtrVt_lsize(av1)
      write(6,*)myproc,"model 1 av size", avsize

      end subroutine model1init

!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
      subroutine model1(comm1,GSmap,av1)   ! run the first model

      implicit none

      integer :: comm1,mysize,ier,asize,myproc
      integer :: fieldindx,avsize,i
      integer,dimension(1) :: start,length
      real,pointer :: testarray(:)

      type(GlobalSegMap) :: GSmap,GSmap2
      type(AttrVect) :: av1
      type(Router),save :: Rout
      logical,save :: firsttime=.FALSE.

      call mpi_comm_rank(comm1,myproc,ier)

      if(.not.firsttime) then
!  get other GSMap
        if(myproc .eq. 0) call MCT_GSMap_recv(GSmap2,2,110)
	call MCT_GSMap_bcast(GSmap2,0,comm1)
! initialize a router
        call MCT_Router_init(GSMap,GSmap2,comm1,Rout)
      endif
      firsttime=.TRUE.

      avsize = MCT_AtrVt_lsize(av1)

!  Fill Av with some data
!  fill first attribute the direct way
      fieldindx = MCT_AtrVt_indexRA(av1,"field1")
      do i=1,avsize
        av1%rAttr(fieldindx,i) = float(i +20*myproc)
      enddo

!  fill second attribute using Av import function
      allocate(testarray(avsize))
      do i=1,avsize
        testarray(i)= cos((float(i+ 20*myproc)/npoints) * 3.14)
      enddo
      call MCT_AtrVt_importRA(av1,"field2",testarray)

!  print out Av data
      do i=1,avsize
        write(6,*)myproc, "model 1 data", i,av1%rAttr(1,i),av1%rAttr(2,i)
      enddo

!  send the data
      call MCT_ISend(av1,Rout)



      end subroutine model1

!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
! !ROUTINE:
      subroutine model2init(comm2,req2,GSmap,av1)  ! init model 2

      implicit none

      integer :: comm2,mysize,ier,asize,myproc
      integer :: i
      integer,dimension(1) :: start,length
      type(GlobalSegMap) :: GSmap
      type(AttrVect) :: av1
      integer,pointer :: req2(:)
!---------------------------

!  find local rank and size
      call mpi_comm_size(comm2,mysize,ier)
      call mpi_comm_rank(comm2,myproc,ier)
      write(6,*)myproc,"model2 size",mysize

!  set up a grid and decomposition
      asize =  npoints/mysize

      start(1)= (myproc*asize) +1
      length(1)=asize

!  describe decomposition with MCT GSmap type
      call MCT_GSMap_init(GSMap,start,length,0,comm2,2)

      write(6,*)myproc, "model 2 GSMap ngseg",GSMap%ngseg,start(1)

      if(myproc .eq. 0) call MCT_GSMap_Isend(GSMap,1,110,req2)

!  Initialize an Attribute Vector
      call MCT_AtrVt_init(av1,rList="field1:field2",lsize=MCT_GSMap_lsize(GSMap,comm2))
      write(6,*)myproc,"model2 got an aV"

      write(6,*)myproc, "model 2 av size", MCT_AtrVt_lsize(av1)

      end subroutine model2init

!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
! !ROUTINE:
      subroutine model2(comm2,GSmap,av1)

      implicit none

      integer :: comm2,mysize,ier,avsize,myproc
      integer :: i
      integer,dimension(1) :: start,length
      type(GlobalSegMap) :: GSmap,GSmap2
      type(AttrVect) :: av1
      type(Router),save   :: Rout
      logical,save :: firsttime=.FALSE.
!---------------------------

! initialize Av to be zero everywhere
      call MCT_AtrVt_zero(av1)

      call mpi_comm_rank(comm2,myproc,ier)
      if(.not.firsttime) then
! receive other GSMap
        if(myproc .eq. 0) call MCT_GSMap_recv(GSmap2,1,100)
	call MCT_GSMap_bcast(GSmap2,0,comm2)
!  initialize a Router
        call MCT_Router_init(GSMap,GSmap2,comm2,Rout)
      endif
      firsttime=.TRUE.

      avsize = MCT_AtrVt_lsize(av1)

!  print out Av data before Recv
      do i=1,avsize
        write(6,*) myproc,"model 2 data", i,av1%rAttr(1,i),av1%rAttr(2,i)
      enddo

!  Recv the data
      call MCT_Recv(av1,Rout)

!  print out Av data after Recv.
      do i=1,avsize
        write(6,*) myproc,"model 2 data after", i,av1%rAttr(1,i),av1%rAttr(2,i)
      enddo


      end subroutine model2

      end
