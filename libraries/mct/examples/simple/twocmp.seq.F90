!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: twocmp.seq.F90,v 1.6 2006-07-25 17:09:42 jacob Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !ROUTINE:  twocomponent.sequential
!
!
! !DESCRIPTION:  Provide a simple example of using MCT to connect
! two components executing in sequence in a single executable.
!
! Data is passed between models by using input/output arguments
! in the run method.  Compare with twocmp.seqNB.F90
!
! !INTERFACE:
!
      program twoseq
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
      integer ier,nprocs
      integer,dimension(:),pointer :: myids
      integer :: comm1,comm2,asize,mysize,i,myproc
      integer,dimension(1) :: start1,length1
      integer,dimension(:),pointer :: start2,length2
!-----------------------------------------------------------------------
!  The Main program.
! We are implementing a single-executable, sequential-execution system.
! In this example, communication occurs through main using
! arguments.  Both components share the same processors.

      type(GlobalSegMap) :: GSmap1,GSmap2
      type(AttrVect) :: av1,av2
      type(Rearranger) :: Rearr
!-----------------------------------------------------------------------

      call MPI_init(ier)

      call mpi_comm_size(MPI_COMM_WORLD, mysize,ier)
      if(mysize .gt. 4) then
        write(6,*)"The small problem size in this example &
	&requires ", ngy,"or fewer processors."
        stop
      endif
      call mpi_comm_rank(MPI_COMM_WORLD, myproc,ier)

      call mpi_comm_dup(MPI_COMM_WORLD,comm1,ier)
      call mpi_comm_dup(MPI_COMM_WORLD,comm2,ier)

      allocate(myids(2))
      myids(1)=1
      myids(2)=2

      call MCTWorld_init(2,MPI_COMM_WORLD,comm1,myids=myids)

!  set up a grid and decomposition
! first gsmap is the grid decomposed by rows
! theres 1 segment per processor
      length1(1)= ngx * (ngy/mysize)
      start1(1)= myproc * length1(1) + 1

       write(6,*)'gsmap1', myproc,length1(1),start1(1)
      call MCT_GSMap_init(GSMap1,start1,length1,0,comm1,1)

! second gsmap is the grid decomposed by columns
      allocate(length2(ngy),start2(ngy))

      do i=1,ngy
       length2(i)=ngx/mysize
       start2(i)= (i-1)*ngx + 1 + myproc*length2(i)
       write(6,*) 'gsmap2',myproc,i,length2(i),start2(i)
      enddo


      call MCT_GSMap_init(GSMap2,start2,length2,0,comm2,2)

      call MCT_AtrVt_init(av1,rList="field1:field2",lsize=MCT_GSMap_lsize(GSMap1,comm1))

      call MCT_AtrVt_init(av2,rList="field1:field2",lsize=MCT_GSMap_lsize(GSMap2,comm2))


! create a rearranger
      call MCT_Rearranger_init(GSMap1,GSMap2,MPI_COMM_WORLD,Rearr)

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
      call model2(comm2,av2)


! all done
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
      write(6,*)"model1 size",mysize


      avsize = MCT_AtrVt_lsize(mod1av)
      write(6,*)"model 1 av size", avsize

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
      write(6,*)"model2 size",mysize

      asize = MCT_AtrVt_lsize(mod2av)
      write(6,*)"model 2 av size", asize

!  print out Av data
      do i=1,asize
        write(6,*) "model 2 data after", myproc,i,mod2av%rAttr(1,i),mod2av%rAttr(2,i)
      enddo


      end subroutine model2

      end
