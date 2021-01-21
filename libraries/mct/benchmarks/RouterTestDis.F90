
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
!BOP -------------------------------------------------------------------
!
! !PROGRAM: RouterTestDis - Test building a router.
!
!
! !DESCRIPTION:  Test building a router from output GSMaps on
! 2 disjoint sets of processors.
!
program RouterTestDis

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
  use m_zeit

  implicit none

  include "mpif.h"

!
!EOP -------------------------------------------------------------------

!     local variables

  character(len=*), parameter :: myname_='RouterTestDis'

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

  filename1="T42.8pR"
  filename2="T42.8pC"

! open up the two files with the GSMap information.

  if(rank == 0) then
   mdev1 = luavail()
   open(mdev1,file=trim(filename1),status='old')

   mdev2 = luavail()
   open(mdev2,file=trim(filename2),status='old')


   read(mdev1,*) nprocs1
   read(mdev2,*) nprocs2


!  This is the disjoint test so need to have enough processors.
   if(nprocs1+nprocs2 .ne. nprocs) then
     write(0,*)"Wrong processor count for exactly 2 disjoint communicators."
     write(0,*)"Need",nprocs1+nprocs2,"got",nprocs
     call die("main","nprocs check")
   endif
   close(mdev1)
   close(mdev2)
  endif

  call MPI_BCAST(nprocs1,1,MP_INTEGER,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(nprocs2,1,MP_INTEGER,0,MPI_COMM_WORLD,ier)

! Split world into 2 pieces for each component
  color=0
  if(rank < nprocs1) color=1

  call MPI_COMM_SPLIT(MPI_COMM_WORLD,color,rank,newcomm,ier)

! *******************************
!  Component 1
! *******************************
  if(color == 0) then
    call MPI_COMM_RANK(newcomm,lrank,ier)

!  build an MCTWorld with 2 components
    call MCTWorld_init(2,MPI_COMM_WORLD,newcomm,1)

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
              root_pe_loc, 0, newcomm, 1)


! initalize the Router with component 2
   call Router_init(2,comp1GSMap,newcomm,myRout,"Dis1")
   call zeit_allflush(newcomm,0,6)

! *******************************
!  Component 2
! *******************************
  else
    call MPI_COMM_RANK(newcomm,lrank,ier)

!  build an MCTWorld with 2 components
    call MCTWorld_init(2,MPI_COMM_WORLD,newcomm,2)
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
              root_pe_loc, 0, newcomm, 2)

! initalize the Router with component 1
   call Router_init(1,comp2GSMap,newcomm,myRout,"Dis2")
   call zeit_allflush(newcomm,0,6)
  endif

  call MPI_Finalize(ier)

end program RouterTestDis
