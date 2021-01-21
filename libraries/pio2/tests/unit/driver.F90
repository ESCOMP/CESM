!>
!! @file
!! @brief The driver for PIO unit tests
!<
#include "config.h"

Program pio_unit_test_driver
  use pio
  use global_vars
  use basic_tests
  use ncdf_tests
#ifdef TIMING
  use perf_mod
#endif
  Implicit None

  ! local variables
  character(len=str_len) :: err_msg
  integer :: fail_cnt, test_cnt, ios, test_id, ierr
  logical :: ltest_netcdf, ltest_pnetcdf
  logical :: ltest_netcdf4p, ltest_netcdf4c
  namelist/piotest_nml/  ltest_netcdf,     &
       ltest_netcdf4p,     &
       ltest_netcdf4c,     &
       ltest_pnetcdf,    &
       stride
  integer ret_val
  character(len=pio_max_name) :: errmsg
  character(len=pio_max_name) :: expected

  ! Set up MPI
  call MPI_Init(ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, my_rank, ierr)
  call MPI_Comm_size(MPI_COMM_WORLD, ntasks , ierr)
#ifdef TIMING
  call t_initf('gptl.nl')
#endif

  !! call MPI_Errhandler_set(MPI_COMM_WORLD, MPI_ERRORS_RETURN, ierr)
  master_task = my_rank.eq.0

  if (master_task) then
     ltest_netcdf     = .false.
     ltest_netcdf4p     = .false.
     ltest_netcdf4c     = .false.
     ltest_pnetcdf    = .false.
     stride           = 1

     open(615, file="input.nl")
     read(615, nml=piotest_nml, iostat=ios)
     if (ios.ne.0) then
        print*, "ERROR reading input.nl, exiting!"
     end if
     close(615)

     write(*,"(A,1x,I0,1x,A,1x,I0)") "Running unit tests with", ntasks, &
          "MPI tasks and stride of", stride

     if (stride.gt.ntasks) then
        stride = ntasks
        write(*,"(A,1x,A,I0)") "WARNING: stride value in namelist is larger than", &
             "number of MPI tasks, reducing stride to ", stride
     end if

     ! Ignore namelist values if PIO not built with correct options
     ! (i.e. don't test pnetcdf if not built with pnetcdf)

#ifndef _NETCDF4
     if (ltest_netcdf4p) then
        write(*,"(A,1x,A)") "WARNING: can not test netcdf4p files because PIO", &
             "was not compiled with -D_NETCDF4"
        ltest_netcdf4p     = .false.
     end if
     if (ltest_netcdf4c) then
        write(*,"(A,1x,A)") "WARNING: can not test netcdf4c files because PIO", &
             "was not compiled with -D_NETCDF4"
        ltest_netcdf4c     = .false.
     end if
#endif
#ifndef _PNETCDF
     if (ltest_pnetcdf) then
        write(*,"(A,1x,A)") "WARNING: can not test pnetcdf files because PIO", &
             "was not compiled with -D_PNETCDF"
        ltest_pnetcdf    = .false.
     end if
#endif
     write(*,"(A)") "------"

     ltest(NETCDF)  = ltest_netcdf
     ltest(NETCDF4P)  = ltest_netcdf4p
     ltest(NETCDF4C)  = ltest_netcdf4c
     ltest(PNETCDF) = ltest_pnetcdf

  end if

  call MPI_Bcast(ios,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
  if (ios.ne.0) then
     call MPI_Abort(MPI_COMM_WORLD, 0, ierr)
  end if

  call MPI_Bcast(ltest,ntest,MPI_LOGICAL,0,MPI_COMM_WORLD,ierr)
  call MPI_Bcast(stride,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
  niotasks = ntasks/stride

  ! Set up PIO
  call PIO_init(my_rank,        & ! MPI rank
       MPI_COMM_WORLD, & ! MPI communicator
       niotasks,       & ! Number of iotasks (ntasks/stride)
       0,              & ! num_aggregator (?)
       stride,         & ! Stride
       PIO_rearr_subset,  & ! rearr
       pio_iosystem, base=1)     ! iosystem

  call PIO_seterrorhandling(pio_iosystem, PIO_RETURN_ERROR)
  call PIO_seterrorhandling(PIO_DEFAULT, PIO_RETURN_ERROR)

  fail_cnt = 0
  test_cnt = 0

  ! Test pio_strerror.
  ret_val = PIO_strerror(-33, errmsg);
  print *, 'errcode =', -33, ' strerror = ', errmsg
  expected = 'NetCDF: Not a valid ID'
  if (trim(errmsg) .ne. expected) then
     err_msg = 'expected ' // trim(expected) // ' and got ' // trim(errmsg)
     print *, err_msg
     call parse(err_msg, fail_cnt)
  end if

  do test_id=1,ntest
     if (ltest(test_id)) then
        ! Make sure i is a valid test number
        select case (test_id)
        case (NETCDF4P)
           if (master_task) &
                write(*,"(A)") "Testing PIO's netcdf4 parallel input / output:"
        case (NETCDF4C)
           if (master_task) &
                write(*,"(A)") "Testing PIO's netcdf4 compressed input / output:"
        case (NETCDF)
           if (master_task) &
                write(*,"(A)") "Testing PIO's netcdf input / output:"
        case (PNETCDF)
           if (master_task) &
                write(*,"(A)") "Testing PIO's pnetcdf input / output:"
        case DEFAULT
           if (master_task) &
                write(*,"(A,I0)") "Error, not configured for test #", test_id
           call MPI_Abort(MPI_COMM_WORLD, 0, ierr)
        end select

        ! test_create()
        if (master_task) write(*,"(3x,A,1x)") "testing PIO_createfile..."
        call test_create(test_id, err_msg)
        call parse(err_msg, fail_cnt)

        ! test_open()

        if (master_task) write(*,"(3x,A,I3)", advance="no") "testing PIO_openfile...",test_id
        call test_open(test_id, err_msg)
        call parse(err_msg, fail_cnt)

        call mpi_barrier(mpi_comm_world,ierr)
        ! netcdf-specific tests
        if (is_netcdf(iotypes(test_id))) then

           if (master_task) write(*,"(3x,A,1x)", advance="no") "testing PIO_redef..."
           call test_redef(test_id, err_msg)
           call parse(err_msg, fail_cnt)

           if (master_task) write(*,"(3x,A,1x)", advance="no") "testing PIO_enddef..."
           call test_enddef(test_id, err_msg)
           print *, 'err_msg =', err_msg, ' fail_cnt = ', fail_cnt
           call parse(err_msg, fail_cnt)

           if (master_task) write(*,"(3x,A,1x)", advance="no") "testing PIO netCDF-4 functions..."
           print *, 'err_msg =', err_msg, ' fail_cnt = ', fail_cnt
           call test_nc4(test_id, err_msg)
           print *, 'err_msg =', err_msg, ' fail_cnt = ', fail_cnt
           call parse(err_msg, fail_cnt)
        end if


        if (master_task) write(*,*) ""

     end if ! ltest(test_id)

  end do

  if (master_task) then
     write(*,"(A,I0)") "Total failure count: ", fail_cnt
     if (fail_cnt.eq.0) then
        write(*,"(A)") "PASSED unit testing."
     else
        write(*,"(A)") "FAILED unit testing."
     end if
  end if

  call PIO_finalize(pio_iosystem, ierr)
#ifdef TIMING
  call t_finalizef()
#endif
  call MPI_Finalize(ierr)
  if(fail_cnt>0) then
     stop 1
  else
     stop 0
  endif
Contains

  Subroutine parse(err_msg, fail_counter)

    character(len=*), intent(in)    :: err_msg
    integer,          intent(inout) :: fail_counter
    logical                         :: test_passed

    if (master_task) then
       test_passed = (trim(err_msg).eq."no_error")
       if (test_passed) then
          write(*,"(A)") "success!"
       else
          write(*,"(A)") "FAILURE: " // trim(err_msg)
          fail_counter = fail_counter+1
       end if
    end if

  End Subroutine parse

End Program pio_unit_test_driver
