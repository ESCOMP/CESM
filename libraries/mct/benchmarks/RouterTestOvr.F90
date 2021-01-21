
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
!BOP -------------------------------------------------------------------
!
! !PROGRAM: RouterTestOvr - Test building a router.
!
!
! !DESCRIPTION:  Test building a router from output GSMaps on
! overlapping processors
!
program RouterTestOvr

!
! !USES:
!

  use m_GlobalSegMap,only: GlobalSegMap
  use m_GlobalSegMap,only: GSMap_init => init
  use m_GlobalSegMap,only: GSMap_lsize => lsize

  use m_Router,only:  Router
  use m_Router,only:  Router_init => init

  use m_MCTWorld,only: MCTWorld_init => init
  use m_ioutil,       only : luavail
  use m_stdio,        only : stdout,stderr
  use m_die,          only : die
  use m_mpif90

  implicit none

  include "mpif.h"

!
!EOP -------------------------------------------------------------------

!     local variables

  character(len=*), parameter :: myname_='RouterTestOvr'

  integer :: ncomps = 2   ! Must know total number of
                         ! components in coupled system

  integer,dimension(:),pointer :: comps  ! array with component ids

  type(GlobalSegMap) :: comp1GSMap
  type(GlobalSegMap) :: comp2GSMap
  type(Router)       :: myRout

! other variables
  integer :: comm1, comm2, rank, nprocs,compid, myID, ier,color
  integer :: mdev1, mdev2, nprocs1,nprocs2,ngseg,gsize
  character*24 :: filename1, filename2
  integer :: lrank,newcomm,n,junk
  integer, dimension(:), allocatable :: root_start, root_length, root_pe_loc

!-----------------------------------------------------------------------
! The Main program.
!
! This main program initializes MCT

! Initialize MPI
  call MPI_INIT(ier)

! Get basic MPI information
  call MPI_COMM_SIZE(MPI_COMM_WORLD,nprocs,ier)
  call MPI_COMM_RANK(MPI_COMM_WORLD,rank,ier)

  filename1="gx1.8pR"
  filename2="gx1.8pC"

! open up the two files with the GSMap information.
! and read the total number of processors needed

  if(rank == 0) then
   mdev1 = luavail()
   open(mdev1,file=trim(filename1),status='old')

   mdev2 = luavail()
   open(mdev2,file=trim(filename2),status='old')


   read(mdev1,*) nprocs1
   read(mdev2,*) nprocs2


!  Need to have enough processors.
   if(nprocs .lt. max(nprocs1,nprocs2)) then
     write(0,*)"Wrong processor count for 2 overlapping communicators."
     write(0,*)"Need",max(nprocs1,nprocs2),"got",nprocs
     call die("main","nprocs check")
   endif
   close(mdev1)
   close(mdev2)
  endif

  call MPI_BCAST(nprocs1,1,MP_INTEGER,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(nprocs2,1,MP_INTEGER,0,MPI_COMM_WORLD,ier)

  call mpi_comm_dup(MPI_COMM_WORLD,comm1,ier)
  call mpi_comm_dup(MPI_COMM_WORLD,comm2,ier)

! Initialize MCT
  allocate(comps(ncomps),stat=ier)
  comps(1)=1
  comps(2)=2
  call MCTWorld_init(ncomps,MPI_COMM_WORLD,comm1,myids=comps)



! *******************************
!  Component 1
! *******************************
  call MPI_COMM_RANK(comm1,lrank,ier)

! on non-root proccessors, allocate with length 1
    if(lrank .ne. 0) then

     allocate(root_start(1), root_length(1), &
             root_pe_loc(1), stat=ier)
     if (ier /= 0) then
     call die(myname_, 'allocate((non)root_start...',ier)
     endif
    endif

    if(lrank == 0) then
      mdev1 = luavail()
      open(mdev1,file=trim(filename1),status='old')
      read(mdev1,*) junk
      read(mdev1,*) junk
      read(mdev1,*) ngseg
      read(mdev1,*) gsize
      allocate(root_start(ngseg), root_length(ngseg), &
             root_pe_loc(ngseg), stat=ier)
      if (ier /= 0) then
        call die(myname_, 'allocate((non)root_start...',ier)
      endif
      do n=1,ngseg
        read(mdev1,*) root_start(n),root_length(n), &
                         root_pe_loc(n)
      enddo
    endif

! initalize the GSMap from root
   call GSMap_init(comp1GSMap, ngseg, root_start, root_length, &
              root_pe_loc, 0, comm1, 1)

   deallocate(root_start,root_length,root_pe_loc)

! *******************************
!  Component 2
! *******************************
    call MPI_COMM_RANK(comm2,lrank,ier)

! on non-root proccessors, allocate with length 1
    if(lrank .ne. 0) then

     allocate(root_start(1), root_length(1), &
             root_pe_loc(1), stat=ier)
     if (ier /= 0) then
     call die(myname_, 'allocate((non)root_start...',ier)
     endif
    endif

    if(lrank == 0) then
      mdev2 = luavail()
      open(mdev2,file=trim(filename2),status='old')
      read(mdev2,*) junk
      read(mdev2,*) junk
      read(mdev2,*) ngseg
      read(mdev2,*) gsize
      allocate(root_start(ngseg), root_length(ngseg), &
             root_pe_loc(ngseg), stat=ier)
      if (ier /= 0) then
        call die(myname_, 'allocate((non)root_start...',ier)
      endif
      do n=1,ngseg
        read(mdev2,*) root_start(n),root_length(n), &
                         root_pe_loc(n)
      enddo
    endif

! initalize the GSMap from root
    call GSMap_init(comp2GSMap, ngseg, root_start, root_length, &
              root_pe_loc, 0, comm2, 2)

! now initialize the Router
  call Router_init(comp1GSMap,comp2GSMap,comm1,myRout,"Over")


  call MPI_Finalize(ier)

end program RouterTestOvr
