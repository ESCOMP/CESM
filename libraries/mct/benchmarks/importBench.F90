! Av import/export benchmark
!
 program importBench

  use m_MCTWorld,only : MCTWorld_init => init
  use m_MCTWorld,only : MCTWorld_clean => clean
  use m_MCTWorld,only : ThisMCTWorld
  use m_AttrVect,only : AttrVect
  use m_AttrVect,only : AttrVect_init => init
  use m_AttrVect,only : AttrVect_nRattr => nRattr
  use m_AttrVect,only : AttrVect_nIattr => nIattr
  use m_AttrVect,only : AttrVect_size => lsize
  use m_AttrVect,only : AttrVect_indexRA => indexRA
  use m_AttrVect,only : AttrVect_importRA => importRAttr
  use m_AttrVect,only : AttrVect_exportRA => exportRAttr

  use m_mpif90
  use m_ioutil, only : luavail

  implicit none

! declarations
  include 'mpif.h'

  character(len=*), parameter :: myname='MCT_importBench'

  integer, parameter :: nTrials=1000 ! Number of timing measurements
                                     ! per test.  Keep high WRT
                                     ! value of MaxNumAtts to ensure
                                     ! timings are representative

  integer, parameter :: lmax = 17 ! Maximum AV length = 2**(lmax-1)
                                  ! Don't increase--segv on login.mcs
                                  ! for larger values!

  integer, parameter :: MaxNumAtts = 26 ! maximum number of
                                        ! attributes used in
                                        ! timing tests.  Leave
                                        ! fixed for now!

  character(len=2*MaxNumAtts-1) :: dummyAList ! character array for
                                              ! synthetic attribute
                                              ! lists

  integer comm1, mysize,myproc,ier,i

  real*8, dimension(:), pointer :: inputData(:)
  real*8, dimension(:), pointer :: outputData(:)

  integer :: currLength, k, l, n
  integer :: colInd, lettInd, attInd, charInd

  real*8 :: startTime, finishTime
  real*8, dimension(:), pointer :: impTimings
  real*8, dimension(:), pointer :: expTimings
  real*8 :: impMeanTime, expMeanTime
  real*8 :: impStdDevTime, expStdDevTime

  integer :: impAvD, impMinD, impMaxD, impSDD
  integer :: expAvD, expMinD, expMaxD, expSDD

  type(AttrVect) :: myAV

!
! Initialize MPI and copy MPI_COMM_WORLD...
!
  call MPI_init(ier)

  call mpi_comm_size(MPI_COMM_WORLD, mysize,ier)
  call mpi_comm_rank(MPI_COMM_WORLD, myproc,ier)
  write(0,*) myproc, "MPI size proc", mysize

  call mpi_comm_dup(MPI_COMM_WORLD,comm1,ier)

  myproc = 0

! create storage impTimings(:) and expTimings(:)
!
  allocate(impTimings(nTrials), expTimings(nTrials), stat=ier)
  write(0,'(a,2(a,i8))') myname,':: nTrials = ',nTrials,' ier=',ier

! set up files for timing statistics and open them
!
  impAvD = luavail()
  open(impAvD, file='benchAV_importAvgTime.d',status='new')
  impMinD = luavail()
  open(impMinD, file='benchAV_importMinTime.d',status='new')
  impMaxD = luavail()
  open(impMaxD, file='benchAV_importMaxTime.d',status='new')
  impSDD = luavail()
  open(impSDD, file='benchAV_importStdDevTime.d',status='new')
  expAvD = luavail()
  open(expAvD, file='benchAV_exportAvgTime.d',status='new')
  expMinD = luavail()
  open(expMinD, file='benchAV_exportMinTime.d',status='new')
  expMaxD = luavail()
  open(expMaxD, file='benchAV_exportMaxTime.d',status='new')
  expSDD = luavail()
  open(expSDD, file='benchAV_exportStdDevTime.d',status='new')

! Initialize MCTWorld
  call MCTWorld_init(1,MPI_COMM_WORLD,comm1,1)

  dummyAList = ''
  do k=1,MaxNumAtts

    ! construct dummy attribute list AttrVect_init() invoked with
    ! trim(dummyAList) as a string literal argument for rList (see below)
    if(k == 1) then ! bootstrap the process with just a single attribute
      dummyAList(k:k) = achar(65) ! the letter 'A'
    else
      colInd = 2 * (k-1)
      lettInd = 2*k - 1
      dummyAList(colInd:colInd) = achar(58) ! a colon ':'
      dummyAList(lettInd:lettInd) = achar(64+k)
    endif

    do l=1,lmax
!
! Set current AV length currLength, create inputData(:) and outputData(:),
! and initialize entries of inputData(:)...
!
      currLength = 2 ** (l-1)
      ! write(0,'(a,2(a,i8))') myname,":: l = ",l," currLength = ",currLength

      allocate(inputData(currLength), outputData(currLength),stat=ier)
      do i=1,currLength
       	inputData(i)=real(i)
      end do

      ! create an Av with k attributes
      call AttrVect_init(myAV, rList=trim(dummyAList), lsize=currLength)

      ! Import/Export timing tests:
      impMeanTime = 0.
      expMeanTime = 0.
      do n=1,nTrials
        ! circulate through the k attributes so that we get more-or-less
        ! equal representation of the attributes among the import/export
	! calls.  Setting nTrials to a large number ensures the disparities
	! among how frequently the attributes are called will be minimal.
	attInd = mod(n,k)
	charInd = 65 + attInd ! offset from "A"
 	startTime = MPI_WTIME()
        call AttrVect_importRA(myAV, achar(charInd), inputData, currLength)
	finishTime = MPI_WTIME()
        impTimings(n) = finishTime - startTime
	impMeanTime = impMeanTime + impTimings(n)

        startTime = MPI_WTIME()
	call AttrVect_exportRA(myAV, achar(charInd), outputData, currLength)
        finishTime = MPI_WTIME()
	expTimings(n) = finishTime - startTime
        expMeanTime = expMeanTime + expTimings(n)

     end do
     impMeanTime = impMeanTime / float(nTrials)
     expMeanTime = expMeanTime / float(nTrials)
     ! Compute Standard Deviation for timings
     impStdDevTime = 0.
     expStdDevTime = 0.
     do n=1,nTrials
       impStdDevTime = impStdDevTime + (impTimings(n) - impMeanTime)**2
       expStdDevTime = expStdDevTime + (expTimings(n) - expMeanTime)**2
     end do
     impStdDevTime = sqrt(impStdDevTime / float(nTrials-1))
     expStdDevTime = sqrt(expStdDevTime / float(nTrials-1))

     write(*,'(a,2(a,i8),4(a,g12.6))') myname, &
                ":: Import timings for k=",k,"attributes.  AV length=", &
                currLength," elements: Mean = ",impMeanTime," Min= ", &
                minval (impTimings)," Max = ",maxval(impTimings), &
		" Std. Dev. = ",impStdDevTime

     write(*,'(a,2(a,i8),4(a,g12.6))') myname, &
                ":: Export timings for k=",k,"attributes.  AV length=", &
                currLength," elements: Mean = ",expMeanTime," Min = ", &
                minval(expTimings)," Max = ",maxval(expTimings), &
		" Std. Dev. = ",impStdDevTime

     ! Write statistics to individual files for subsequent
     !  visualization:
     write(impAvD,'(2(i8,2x),g12.6)') l-1, k, impMeanTime
     write(impMinD,'(2(i8,2x),g12.6)') l-1, k, minval(impTimings)
     write(impMaxD,'(2(i8,2x),g12.6)') l-1, k, maxval(impTimings)
     write(impSDD,'(2(i8,2x),g12.6)') l-1, k, impStdDevTime
     write(expAvD,'(2(i8,2x),g12.6)') l-1, k, expMeanTime
     write(expMinD,'(2(i8,2x),g12.6)') l-1, k, minval(expTimings)
     write(expMaxD,'(2(i8,2x),g12.6)') l-1, k, maxval(expTimings)
     write(expSDD,'(2(i8,2x),g12.6)') l-1, k, expStdDevTime

     ! Clean up for this value of l:
!     write(*,'(2a,i8)') myname,':: cleaning up for l = ',l
     deallocate(inputData, outputData,stat=ier)

     end do ! l=1,lmax
  end do ! k=1,MaxNumAtts

! Close output files:
  close(impAvD)
  close(impMinD)
  close(impMaxD)
  close(impSDD)
  close(expAvD)
  close(expMinD)
  close(expMaxD)
  close(expSDD)

  call MCTWorld_clean
!  write(*,'(2a,i8)') myname,':: clean up completed for l = ',l

!  call MPI_FINALIZE(MPI_COMM_WORLD, ier)

 end program importBench

