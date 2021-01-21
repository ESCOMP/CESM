! PIO Testing framework utilities module
MODULE pio_tutil
  USE pio
  IMPLICIT NONE
  ! Error/Return values
  INTEGER ::  pio_tf_nerrs_total_
  INTEGER ::  pio_tf_retval_utest_
  INTEGER, PARAMETER :: PIO_TF_ERR = 1

  ! IO Processing stuff
  INTEGER, PARAMETER :: MAX_STDIN_ARG_LEN=100
  ENUM, BIND(C)
    ENUMERATOR  ::  IARG_STRIDE_SIDX = 1
    ENUMERATOR  ::  IARG_NUM_IO_TASKS_SIDX
    ENUMERATOR  ::  IARG_NUM_AGGREGATORS_SIDX
    ENUMERATOR  ::  IARG_LOG_LEVEL_SIDX
    ! Unfortunately since fortran starts with index 1 we need the
    ! hack below. Don't forget to update when adding more argvs
    ENUMERATOR  ::  NUM_IARGS = IARG_LOG_LEVEL_SIDX
    ENUMERATOR  ::  IARG_MAX_SIDX = NUM_IARGS
  END ENUM

  ! PIO specific info
  INTEGER :: pio_tf_stride_, pio_tf_num_io_tasks_, pio_tf_num_aggregators_
  TYPE(iosystem_desc_t), save :: pio_tf_iosystem_

  ! MPI info
  INTEGER ::  pio_tf_world_rank_, pio_tf_world_sz_
  INTEGER :: pio_tf_tmp_comm_rank_, pio_tf_tmp_comm_sz_
  INTEGER :: pio_tf_comm_

  ! REAL types
  INTEGER, PARAMETER, PUBLIC :: fc_real   = selected_real_kind(6)
  INTEGER, PARAMETER, PUBLIC :: fc_double = selected_real_kind(13)

  ! integer types
  INTEGER, PARAMETER, PUBLIC :: fc_short   = selected_int_kind(4)
  INTEGER, PARAMETER, PUBLIC :: fc_int     = selected_int_kind(6)

  ! Misc constants
  INTEGER, PARAMETER :: PIO_TF_MAX_STR_LEN=100

  ! Logging
  INTEGER :: pio_tf_log_level_
  ! PIO_TF_TEST_RES_FMT is used for formatted test result output
  ! -- Useful for writes like
  ! HEADER_STRING, TEST_DESC, FOOTER_STRING, TEST_STATUS
  ! "PIO_TF: Test no: 12", "Test name, desc etc", "-----", "PASSED"
  CHARACTER(LEN=*), PARAMETER :: PIO_TF_TEST_RES_FMT = "(A20,T22,A40,T64,A6,T72,A6)"
  ! -- Useful for writes like
  ! HEADER_STRING, NUMBER_OF_TESTS, FOOTER_STRING, TEST_STATUS
  ! "PIO_TF: [", 3, "] -----", "FAILED"
  CHARACTER(LEN=*), PARAMETER :: PIO_TF_TEST_RES_FMT2 = "(A20,T22,I5,T28,A10,T62,A16)"
  CHARACTER(LEN=PIO_TF_MAX_STR_LEN) :: pio_tf_tmp_log_str_

  ! Access modifiers
  ! Public variables
  PUBLIC  :: pio_tf_nerrs_total_, pio_tf_retval_utest_
  PUBLIC  :: pio_tf_iosystem_
  PUBLIC  :: pio_tf_world_rank_, pio_tf_world_sz_
  PUBLIC  :: pio_tf_log_level_
  PUBLIC  :: PIO_TF_TEST_RES_FMT
  PUBLIC  :: pio_tf_tmp_log_str_
  PUBLIC  :: PIO_TF_MAX_STR_LEN
  ! Public functions
  PUBLIC  :: PIO_TF_Init_, PIO_TF_Finalize_, PIO_TF_Passert_
  PUBLIC  :: PIO_TF_Is_netcdf
  PUBLIC  :: PIO_TF_Get_nc_iotypes, PIO_TF_Get_undef_nc_iotypes
  PUBLIC  :: PIO_TF_Get_iotypes, PIO_TF_Get_undef_iotypes
  PUBLIC  :: PIO_TF_Get_data_types
  PUBLIC  :: PIO_TF_Check_val_
  ! Private functions
  PRIVATE :: PIO_TF_Check_int_arr_arr_
  PRIVATE :: PIO_TF_Check_int_arr_val, PIO_TF_Check_int_arr_arr
  PRIVATE :: PIO_TF_Check_int_arr_arr_tol
  PRIVATE :: PIO_TF_Check_2d_int_arr_arr
  PRIVATE :: PIO_TF_Check_3d_int_arr_arr
  PRIVATE :: PIO_TF_Check_real_arr_val, PIO_TF_Check_real_arr_arr
  PRIVATE :: PIO_TF_Check_real_arr_arr_tol_
  PRIVATE :: PIO_TF_Check_real_arr_arr_tol
  PRIVATE :: PIO_TF_Check_2d_real_arr_arr
  PRIVATE :: PIO_TF_Check_3d_real_arr_arr
  PRIVATE :: PIO_TF_Check_double_arr_val, PIO_TF_Check_double_arr_arr
  PRIVATE :: PIO_TF_Check_double_arr_arr_tol_
  PRIVATE :: PIO_TF_Check_double_arr_arr_tol
  PRIVATE :: PIO_TF_Check_2d_double_arr_arr
  PRIVATE :: PIO_TF_Check_3d_double_arr_arr
  PRIVATE :: PIO_TF_Check_char_str_str
  PRIVATE :: PIO_TF_Get_idx_from_1d_idx

  ! Note that the tolerance value provided is ignored when comparing two
  ! integer arrays
  INTERFACE PIO_TF_Check_val_
    MODULE PROCEDURE                  &
        PIO_TF_Check_int_val_val,     &
        PIO_TF_Check_short_val_val,     &
        PIO_TF_Check_real_val_val,     &
        PIO_TF_Check_double_val_val,     &
        PIO_TF_Check_int_arr_val,     &
        PIO_TF_Check_int_arr_arr,     &
        PIO_TF_Check_int_arr_arr_tol, &
        PIO_TF_Check_2d_int_arr_arr,  &
        PIO_TF_Check_3d_int_arr_arr,  &
        PIO_TF_Check_short_arr_val,     &
        PIO_TF_Check_short_arr_arr,     &
        PIO_TF_Check_short_arr_arr_tol, &
        PIO_TF_Check_2d_short_arr_arr,  &
        PIO_TF_Check_3d_short_arr_arr,  &
        PIO_TF_Check_real_arr_val,    &
        PIO_TF_Check_real_arr_arr,    &
        PIO_TF_Check_2d_real_arr_arr, &
        PIO_TF_Check_3d_real_arr_arr, &
        PIO_TF_Check_real_arr_arr_tol,&
        PIO_TF_Check_double_arr_val,  &
        PIO_TF_Check_double_arr_arr,  &
        PIO_TF_Check_2d_double_arr_arr,&
        PIO_TF_Check_3d_double_arr_arr,&
        PIO_TF_Check_double_arr_arr_tol,&
        PIO_TF_Check_char_str_str
  END INTERFACE

CONTAINS
  ! Initialize Testing framework - Internal (Not directly used by unit tests)
  SUBROUTINE  PIO_TF_Init_(rearr)
#ifdef TIMING
   use perf_mod
#endif
#ifndef NO_MPIMOD
    use mpi
#else
    include 'mpif.h'
#endif
    INTEGER, INTENT(IN) :: rearr
    INTEGER ierr

    CALL MPI_COMM_DUP(MPI_COMM_WORLD, pio_tf_comm_, ierr);
    CALL MPI_COMM_RANK(pio_tf_comm_, pio_tf_world_rank_, ierr)
    CALL MPI_COMM_SIZE(pio_tf_comm_, pio_tf_world_sz_, ierr)
#ifdef TIMING
    call t_initf('gptl.nl')
#endif



    pio_tf_log_level_ = 0
    pio_tf_num_aggregators_ = 0
    pio_tf_num_io_tasks_ = 0
    pio_tf_stride_ = 1
    ! Now read input args from rank 0 and bcast it
    ! Args supported are --num-io-tasks, --num-aggregators,
    !   --stride

    CALL Read_input()
    IF (pio_tf_world_sz_ < pio_tf_num_io_tasks_) THEN
       pio_tf_num_io_tasks_ = pio_tf_world_sz_
    END IF
    IF (pio_tf_num_io_tasks_ <= 1 .AND. pio_tf_stride_ > 1) THEN
       pio_tf_stride_ = 1
    END IF
    IF (pio_tf_num_io_tasks_ == 0) THEN
      pio_tf_num_io_tasks_ = pio_tf_world_sz_ / pio_tf_stride_
      IF (pio_tf_num_io_tasks_ < 1) pio_tf_num_io_tasks_ = 1
    END IF
    !IF (pio_tf_world_rank_ == 0) THEN
    !  PRINT *, "PIO_TF: stride=", pio_tf_stride_, ", io_tasks=",&
    !    pio_tf_num_io_tasks_, ", no of aggregators=", &
    !    pio_tf_num_aggregators_
    !END IF

    ! FIXME: Do we need to test with different types of aggregators?
    ! Initialize PIO
    CALL PIO_init(pio_tf_world_rank_, &
          pio_tf_comm_,               &
          pio_tf_num_io_tasks_,       &
          pio_tf_num_aggregators_,    &
          pio_tf_stride_,             &
          rearr,                      &
          pio_tf_iosystem_,           &
          base=0)

    ! Set PIO to bcast error
    CALL PIO_seterrorhandling(pio_tf_iosystem_, PIO_BCAST_ERROR)

    ! Set PIO logging level
    ierr = PIO_set_log_level(pio_tf_log_level_)
    if(ierr /= PIO_NOERR) then
      PRINT *, "PIO_TF: Error setting PIO logging level"
    end if
  END SUBROUTINE PIO_TF_Init_

  ! Finalize Testing framework - Internal (Not directly used by unit tests)
  SUBROUTINE  PIO_TF_Finalize_
#ifdef TIMING
   use perf_mod
#endif
#ifndef NO_MPIMOD
    use mpi
#else
    include 'mpif.h'
#endif
    INTEGER ierr
    IF (pio_tf_world_rank_ == 0) THEN
      CALL MPI_REDUCE(MPI_IN_PLACE, pio_tf_nerrs_total_, 1, MPI_INTEGER, MPI_MAX, 0, pio_tf_comm_, ierr)
    ELSE
      CALL MPI_REDUCE(pio_tf_nerrs_total_, pio_tf_nerrs_total_, 1, MPI_INTEGER, MPI_MAX, 0, pio_tf_comm_, ierr)
    END IF

    ! Finalize PIO
    CALL PIO_finalize(pio_tf_iosystem_, ierr);
    CALL MPI_COMM_FREE(pio_tf_comm_, ierr);

#ifdef TIMING
    call t_finalizef()
#endif
  END SUBROUTINE PIO_TF_Finalize_

  ! Collective assert - Internal (Not directly used by unit tests)
  ! Each processes passes in its local assert condition and the function
  ! returns the global assert condition
  LOGICAL FUNCTION PIO_TF_Passert_(local_result, comm)
#ifndef NO_MPIMOD
    use mpi
#else
    include 'mpif.h'
#endif
    LOGICAL, INTENT(IN) ::  local_result
    INTEGER, INTENT(IN) ::  comm
    LOGICAL :: global_result
    LOGICAL :: failed, all_failed
    INTEGER :: rank, ierr
    LOGICAL, DIMENSION(:), ALLOCATABLE :: failed_ranks

    CALL MPI_COMM_RANK(comm, pio_tf_tmp_comm_rank_, ierr)
    CALL MPI_COMM_SIZE(comm, pio_tf_tmp_comm_sz_, ierr)

    CALL MPI_ALLREDUCE(local_result, global_result, 1, MPI_LOGICAL, MPI_LAND, comm, ierr)
    IF (.NOT. global_result) THEN
      failed = .NOT. local_result
!      IF (pio_tf_world_rank_ == 0) THEN
        ALLOCATE(failed_ranks(pio_tf_tmp_comm_sz_))
!      END IF
      ! Gather the ranks where assertion failed
      CALL MPI_GATHER(failed, 1, MPI_LOGICAL, failed_ranks, 1, MPI_LOGICAL, 0, comm, ierr)

      ! Display the ranks where the assertion failed
      IF (pio_tf_tmp_comm_rank_ == 0) THEN
        all_failed = .TRUE.
        DO rank=1,pio_tf_tmp_comm_sz_
          IF (.NOT. failed_ranks(rank)) THEN
            all_failed = .FALSE.
            ! Thank you - f90
            EXIT
          END IF
        END DO
        IF (all_failed) THEN
          PRINT *, "PIO_TF: Fatal Error: Assertion failed on ALL processes"
        ELSE
          PRINT *, "PIO_TF: Fatal Error: Assertion failed on following processes: "
          WRITE(*,"(A8)",ADVANCE="NO") "PIO_TF: "
          DO rank=1,pio_tf_tmp_comm_sz_
            IF (failed_ranks(rank)) THEN
              WRITE(*,"(I5,A)",ADVANCE="NO") rank-1, ","
            END IF
          END DO
          PRINT *, ""
        END IF
      END IF
      DEALLOCATE(failed_ranks)
    END IF
    PIO_TF_Passert_ = global_result
  END FUNCTION PIO_TF_Passert_

  ! Returns true if iotype is a netcdf type, false otherwise
  LOGICAL FUNCTION PIO_TF_Is_netcdf(iotype)
    INTEGER,  INTENT(IN)  :: iotype
    PIO_TF_Is_netcdf = (iotype == PIO_iotype_netcdf) .or. &
                        (iotype == PIO_iotype_netcdf4p) .or. &
                        (iotype == PIO_iotype_netcdf4c) .or. &
                        (iotype == PIO_iotype_pnetcdf)

  END FUNCTION PIO_TF_Is_netcdf

  ! Returns a list of defined netcdf iotypes
  ! iotypes : After the routine returns contains a list of defined
  !             netcdf types
  ! iotype_descs : After the routine returns contains description of
  !                 the netcdf types returned in iotypes
  ! num_iotypes : After the routine returns contains the number of
  !                 of defined netcdf types, i.e., size of iotypes and
  !                 iotype_descs arrays
  SUBROUTINE PIO_TF_Get_nc_iotypes(iotypes, iotype_descs, num_iotypes)
    INTEGER, DIMENSION(:), ALLOCATABLE, INTENT(OUT) :: iotypes
    CHARACTER(LEN=*), DIMENSION(:), ALLOCATABLE, INTENT(OUT) :: iotype_descs
    INTEGER, INTENT(OUT) :: num_iotypes
    INTEGER :: i

    num_iotypes = 0
    ! First find the number of io types
#ifdef _NETCDF4
      ! netcdf, netcdf4p, netcdf4c
      num_iotypes = num_iotypes + 3
#else
      ! netcdf is always present.
      num_iotypes = num_iotypes + 1
#endif
#ifdef _PNETCDF
      ! pnetcdf
      num_iotypes = num_iotypes + 1
#endif

    ! ALLOCATE with 0 elements ok?
    ALLOCATE(iotypes(num_iotypes))
    ALLOCATE(iotype_descs(num_iotypes))

    i = 1
#ifdef _PNETCDF
      ! pnetcdf
      iotypes(i) = PIO_iotype_pnetcdf
      iotype_descs(i) = "PNETCDF"
      i = i + 1
#endif
#ifdef _NETCDF4
      ! netcdf, netcdf4p, netcdf4c
      iotypes(i) = PIO_iotype_netcdf
      iotype_descs(i) = "NETCDF"
      i = i + 1
      iotypes(i) = PIO_iotype_netcdf4c
      iotype_descs(i) = "NETCDF4C"
      i = i + 1
      iotypes(i) = PIO_iotype_netcdf4p
      iotype_descs(i) = "NETCDF4P"
      i = i + 1
#else
      ! netcdf is always present.
      iotypes(i) = PIO_iotype_netcdf
      iotype_descs(i) = "NETCDF"
      i = i + 1
#endif
  END SUBROUTINE

  ! Returns a list of undefined netcdf iotypes
  ! e.g. This list could be used by a test to make sure that PIO
  !       fails gracefully for undefined types
  ! iotypes : After the routine returns contains a list of undefined
  !             netcdf types
  ! iotype_descs : After the routine returns contains description of
  !                 the netcdf types returned in iotypes
  ! num_iotypes : After the routine returns contains the number of
  !                 of undefined netcdf types, i.e., size of iotypes and
  !                 iotype_descs arrays
  SUBROUTINE PIO_TF_Get_undef_nc_iotypes(iotypes, iotype_descs, num_iotypes)
    INTEGER, DIMENSION(:), ALLOCATABLE, INTENT(OUT) :: iotypes
    CHARACTER(LEN=*), DIMENSION(:), ALLOCATABLE, INTENT(OUT) :: iotype_descs
    INTEGER, INTENT(OUT) :: num_iotypes
    INTEGER :: i

    num_iotypes = 0
    ! First find the number of io types
#ifndef _PNETCDF
      ! pnetcdf
      num_iotypes = num_iotypes + 1
#endif

    ! ALLOCATE with 0 elements ok?
    ALLOCATE(iotypes(num_iotypes))
    ALLOCATE(iotype_descs(num_iotypes))

    i = 1
#ifndef _PNETCDF
      ! pnetcdf
      iotypes(i) = PIO_iotype_pnetcdf
      iotype_descs(i) = "PNETCDF"
      i = i + 1
#endif
  END SUBROUTINE

  ! Returns a list of defined iotypes
  ! iotypes : After the routine returns contains a list of defined
  !             types
  ! iotype_descs : After the routine returns contains description of
  !                 the types returned in iotypes
  ! num_iotypes : After the routine returns contains the number of
  !                 of defined types, i.e., size of iotypes and
  !                 iotype_descs arrays
  SUBROUTINE PIO_TF_Get_iotypes(iotypes, iotype_descs, num_iotypes)
    INTEGER, DIMENSION(:), ALLOCATABLE, INTENT(OUT) :: iotypes
    CHARACTER(LEN=*), DIMENSION(:), ALLOCATABLE, INTENT(OUT) :: iotype_descs
    INTEGER, INTENT(OUT) :: num_iotypes
    INTEGER :: i

    ! First find the number of io types
    num_iotypes = 0
#ifdef _NETCDF4
      ! netcdf, netcdf4p, netcdf4c
    num_iotypes = num_iotypes + 3
#else
    ! netcdf is always present.
    num_iotypes = num_iotypes + 1
#endif
#ifdef _PNETCDF
      ! pnetcdf
      num_iotypes = num_iotypes + 1
#endif

    ! ALLOCATE with 0 elements ok?
    ALLOCATE(iotypes(num_iotypes))
    ALLOCATE(iotype_descs(num_iotypes))

    i = 1
#ifdef _PNETCDF
      ! pnetcdf
      iotypes(i) = PIO_iotype_pnetcdf
      iotype_descs(i) = "PNETCDF"
      i = i + 1
#endif
#ifdef _NETCDF4
      ! netcdf, netcdf4p, netcdf4c
      iotypes(i) = PIO_iotype_netcdf
      iotype_descs(i) = "NETCDF"
      i = i + 1
      iotypes(i) = PIO_iotype_netcdf4c
      iotype_descs(i) = "NETCDF4C"
      i = i + 1
      iotypes(i) = PIO_iotype_netcdf4p
      iotype_descs(i) = "NETCDF4P"
      i = i + 1
#else
      ! netcdf is always present.
      iotypes(i) = PIO_iotype_netcdf
      iotype_descs(i) = "NETCDF"
      i = i + 1
#endif
  END SUBROUTINE

  ! Returns a list of undefined iotypes
  ! e.g. This list could be used by a test to make sure that PIO
  !       fails gracefully for undefined types
  ! iotypes : After the routine returns contains a list of undefined
  !             types
  ! iotype_descs : After the routine returns contains description of
  !                 the types returned in iotypes
  ! num_iotypes : After the routine returns contains the number of
  !                 of undefined types, i.e., size of iotypes and
  !                 iotype_descs arrays
  SUBROUTINE PIO_TF_Get_undef_iotypes(iotypes, iotype_descs, num_iotypes)
    INTEGER, DIMENSION(:), ALLOCATABLE, INTENT(OUT) :: iotypes
    CHARACTER(LEN=*), DIMENSION(:), ALLOCATABLE, INTENT(OUT) :: iotype_descs
    INTEGER, INTENT(OUT) :: num_iotypes
    INTEGER :: i

    ! First find the number of io types
    num_iotypes = 0
#ifndef _PNETCDF
      ! pnetcdf
      num_iotypes = num_iotypes + 1
#endif

    ! ALLOCATE with 0 elements ok?
    ALLOCATE(iotypes(num_iotypes))
    ALLOCATE(iotype_descs(num_iotypes))

    i = 1
  END SUBROUTINE

  ! Returns a list of PIO base types
  SUBROUTINE PIO_TF_Get_data_types(data_types, data_type_descs, num_data_types)
    INTEGER, DIMENSION(:), ALLOCATABLE, INTENT(OUT) :: data_types
    CHARACTER(LEN=*), DIMENSION(:), ALLOCATABLE, INTENT(OUT) :: data_type_descs
    INTEGER, INTENT(OUT) :: num_data_types

    !num_data_types = 4
    num_data_types = 3
    ALLOCATE(data_types(4))
    ALLOCATE(data_type_descs(4))

    data_types(1) = PIO_double
    data_type_descs(1) = "PIO_double"
    data_types(2) = PIO_real
    data_type_descs(2) = "PIO_real"
    data_types(3) = PIO_int
    data_type_descs(3) = "PIO_int"
    ! FIXME: Check why some PIO functions don't support the char type
    !data_types(4) = PIO_char
    !data_type_descs(4) = "PIO_char"

  END SUBROUTINE PIO_TF_Get_data_types

  ! Get original (multi-d) index string from 1d (reshaped) index
  SUBROUTINE PIO_TF_Get_idx_from_1d_idx(idx_1d, arr_shape, idx_str)
    INTEGER, INTENT(IN) :: idx_1d
    INTEGER, DIMENSION(:), INTENT(IN) :: arr_shape
    CHARACTER(LEN=*), INTENT(OUT) :: idx_str

    CHARACTER(LEN=PIO_TF_MAX_STR_LEN) :: fmt_str
    ! Number of elems in that dim in "1D view"
    INTEGER, DIMENSION(:), ALLOCATABLE :: dim_wgt
    INTEGER, DIMENSION(:), ALLOCATABLE :: idx_md
    INTEGER :: tmp_idx
    INTEGER :: i, sz

    idx_str = ""

    sz = SIZE(arr_shape)
    ALLOCATE(dim_wgt(sz))
    ALLOCATE(idx_md(sz))

    ! Assign place weights = num of elems in that dim in "1D view"
    dim_wgt = 1
    DO i=2,sz
      dim_wgt(i) = dim_wgt(i-1) * arr_shape(i-1)
    END DO

    ! Convert 1d reshaped index to original multi-d index
    tmp_idx = idx_1d - 1
    idx_md = 0
    DO i=sz,1,-1
      idx_md(i) = tmp_idx / dim_wgt(i) + 1
      tmp_idx = MOD(tmp_idx, dim_wgt(i))
    END DO

    IF(sz == 1) THEN
      WRITE(fmt_str, *) "(",sz,"(I5)", ")"
    ELSE
      WRITE(fmt_str, *) "(",sz,"(I5,',')", ")"
    END IF
    WRITE(idx_str,fmt_str) idx_md

    DEALLOCATE(idx_md)
    DEALLOCATE(dim_wgt)

  END SUBROUTINE PIO_TF_Get_idx_from_1d_idx

  LOGICAL FUNCTION PIO_TF_Check_int_arr_arr_(arr, exp_arr, arr_shape)
#ifndef NO_MPIMOD
    USE mpi
#else
    include 'mpif.h'
#endif
    INTEGER, DIMENSION(:), INTENT(IN) :: arr
    INTEGER, DIMENSION(:), INTENT(IN) :: exp_arr
    INTEGER, DIMENSION(:), INTENT(IN) :: arr_shape
    CHARACTER(LEN=PIO_TF_MAX_STR_LEN) :: idx_str
    INTEGER :: arr_sz, i, ierr
    ! Not equal at id = nequal_idx
    INTEGER :: nequal_idx
    ! Local and global equal bools
    LOGICAL :: lequal, gequal
    TYPE failed_info
      SEQUENCE
      INTEGER :: idx
      INTEGER :: val
      INTEGER :: exp_val
    END TYPE failed_info
    TYPE (failed_info) :: lfail_info
    TYPE (failed_info), DIMENSION(:), ALLOCATABLE :: gfail_info

    arr_sz = SIZE(arr)
    lequal = .TRUE.;
    gequal = .TRUE.;
    nequal_idx = -1;
    IF (arr_sz /= SIZE(exp_arr)) THEN
      PRINT *, "PIO_TF: Unable to compare arrays of different sizes", arr_sz, " and", SIZE(exp_arr)
    END IF
    DO i=1, arr_sz
      IF (arr(i) /= exp_arr(i)) THEN
        lequal = .FALSE.
        nequal_idx = i
      END IF
    END DO
    CALL MPI_ALLREDUCE(lequal, gequal, 1, MPI_LOGICAL, MPI_LAND, pio_tf_comm_, ierr)
    IF (.NOT. gequal) THEN
      lfail_info % idx = nequal_idx
      IF (nequal_idx /= -1) THEN
        lfail_info % val     = arr(nequal_idx)
        lfail_info % exp_val = exp_arr(nequal_idx)
      END IF
      ALLOCATE(gfail_info(pio_tf_world_sz_))
      ! Gather the ranks where assertion failed
      CALL MPI_GATHER(lfail_info, 3, MPI_INTEGER, gfail_info, 3, MPI_INTEGER, 0, pio_tf_comm_, ierr)
      IF (pio_tf_world_rank_ == 0) THEN
         DO i=1,pio_tf_world_sz_
            IF(gfail_info(i) % idx /= -1) THEN
               CALL PIO_TF_Get_idx_from_1d_idx(gfail_info(i) % idx, arr_shape, idx_str)
               PRINT *, "PIO_TF: Fatal Error: rank =", i, ", Val[",&
                    trim(idx_str), "]=",&
                    gfail_info(i) % val, ", Expected = ", gfail_info(i) % exp_val
            END IF
         END DO
      END IF
      deallocate(gfail_info)
   end if
    PIO_TF_Check_int_arr_arr_ = gequal
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_int_arr_arr(arr, exp_arr)
    INTEGER, DIMENSION(:), INTENT(IN) :: arr
    INTEGER, DIMENSION(:), INTENT(IN) :: exp_arr

    PIO_TF_Check_int_arr_arr = PIO_TF_Check_int_arr_arr_(arr, exp_arr, SHAPE(arr))
  END FUNCTION

  ! Note that the tolerance value is ignored when comparing two integer arrays
  ! We have this interface to make it easier to generate common code for
  ! comparing ints, reals and doubles
  LOGICAL FUNCTION PIO_TF_Check_int_arr_arr_tol(arr, exp_arr, tol)
    INTEGER, DIMENSION(:), INTENT(IN) :: arr
    INTEGER, DIMENSION(:), INTENT(IN) :: exp_arr
    REAL, INTENT(IN) :: tol
    if (tol /= 0) continue ! to suppress warning

    PIO_TF_Check_int_arr_arr_tol = PIO_TF_Check_int_arr_arr(arr, exp_arr)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_int_val_val(val1, val2)
    INTEGER, INTENT(IN) :: val1, val2

    PIO_TF_Check_int_val_val = val1 == val2
  END FUNCTION
  LOGICAL FUNCTION PIO_TF_Check_short_val_val(val1, val2)
    INTEGER(kind=fc_short), INTENT(IN) :: val1, val2

    PIO_TF_Check_short_val_val = val1 == val2
  END FUNCTION
  LOGICAL FUNCTION PIO_TF_Check_real_val_val(val1, val2)
    real(kind=fc_real), INTENT(IN) :: val1, val2

    PIO_TF_Check_real_val_val = val1 == val2
  END FUNCTION
  LOGICAL FUNCTION PIO_TF_Check_double_val_val(val1, val2)
    real(kind=fc_double), INTENT(IN) :: val1, val2

    PIO_TF_Check_double_val_val = val1 == val2
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_int_arr_val(arr, val)
    INTEGER, DIMENSION(:), INTENT(IN) :: arr
    INTEGER, INTENT(IN) :: val
    INTEGER, DIMENSION(:), ALLOCATABLE :: arr_val

    ALLOCATE(arr_val(SIZE(arr)))
    arr_val = val
    PIO_TF_Check_int_arr_val = PIO_TF_Check_int_arr_arr(arr, arr_val)
    DEALLOCATE(arr_val)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_2d_int_arr_arr(arr, exp_arr)
    INTEGER, DIMENSION(:,:), INTENT(IN) :: arr
    INTEGER, DIMENSION(:,:), INTENT(IN) :: exp_arr

    INTEGER, DIMENSION(:), ALLOCATABLE :: arr_val
    INTEGER, DIMENSION(:), ALLOCATABLE :: exp_arr_val
    INTEGER, PARAMETER :: NDIMS = 2

    ALLOCATE(arr_val(SIZE(arr)))
    ALLOCATE(exp_arr_val(SIZE(exp_arr)))
    arr_val = RESHAPE(arr,(/SIZE(arr)/))
    exp_arr_val = RESHAPE(exp_arr,(/SIZE(exp_arr)/))

    PIO_TF_Check_2d_int_arr_arr = PIO_TF_Check_int_arr_arr_(arr_val, exp_arr_val,&
                                    SHAPE(arr))
    DEALLOCATE(arr_val)
    DEALLOCATE(exp_arr_val)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_3d_int_arr_arr(arr, exp_arr)
    INTEGER, DIMENSION(:,:,:), INTENT(IN) :: arr
    INTEGER, DIMENSION(:,:,:), INTENT(IN) :: exp_arr

    INTEGER, DIMENSION(:), ALLOCATABLE :: arr_val
    INTEGER, DIMENSION(:), ALLOCATABLE :: exp_arr_val
    INTEGER, PARAMETER :: NDIMS = 2

    ALLOCATE(arr_val(SIZE(arr)))
    ALLOCATE(exp_arr_val(SIZE(exp_arr)))
    arr_val = RESHAPE(arr,(/SIZE(arr)/))
    exp_arr_val = RESHAPE(exp_arr,(/SIZE(exp_arr)/))

    PIO_TF_Check_3d_int_arr_arr = PIO_TF_Check_int_arr_arr_(arr_val, exp_arr_val,&
                                    SHAPE(arr))
    DEALLOCATE(arr_val)
    DEALLOCATE(exp_arr_val)
  END FUNCTION


  LOGICAL FUNCTION PIO_TF_Check_short_arr_arr_(arr, exp_arr, arr_shape)
#ifndef NO_MPIMOD
    USE mpi
#else
    include 'mpif.h'
#endif
    INTEGER(FC_SHORT), DIMENSION(:), INTENT(IN) :: arr
    INTEGER(FC_SHORT), DIMENSION(:), INTENT(IN) :: exp_arr
    INTEGER, DIMENSION(:), INTENT(IN) :: arr_shape
    CHARACTER(LEN=PIO_TF_MAX_STR_LEN) :: idx_str
    INTEGER :: arr_sz, i, ierr
    ! Not equal at id = nequal_idx
    INTEGER :: nequal_idx
    ! Local and global equal bools
    LOGICAL :: lequal, gequal
    TYPE failed_info
      SEQUENCE
      INTEGER :: idx
      INTEGER :: val
      INTEGER :: exp_val
    END TYPE failed_info
    TYPE (failed_info) :: lfail_info
    TYPE (failed_info), DIMENSION(:), ALLOCATABLE :: gfail_info

    arr_sz = SIZE(arr)
    lequal = .TRUE.;
    gequal = .TRUE.;
    nequal_idx = -1;
    IF (arr_sz /= SIZE(exp_arr)) THEN
      PRINT *, "PIO_TF: Unable to compare arrays of different sizes", arr_sz, " and", SIZE(exp_arr)
    END IF
    DO i=1, arr_sz
      IF (arr(i) /= exp_arr(i)) THEN
        lequal = .FALSE.
        nequal_idx = i
      END IF
    END DO
    CALL MPI_ALLREDUCE(lequal, gequal, 1, MPI_LOGICAL, MPI_LAND, pio_tf_comm_, ierr)
    IF (.NOT. gequal) THEN
      lfail_info % idx = nequal_idx
      IF (nequal_idx /= -1) THEN
        lfail_info % val     = arr(nequal_idx)
        lfail_info % exp_val = exp_arr(nequal_idx)
      END IF
      ALLOCATE(gfail_info(pio_tf_world_sz_))
      ! Gather the ranks where assertion failed
      CALL MPI_GATHER(lfail_info, 3, MPI_INTEGER, gfail_info, 3, MPI_INTEGER, 0, pio_tf_comm_, ierr)
      IF (pio_tf_world_rank_ == 0) THEN
         DO i=1,pio_tf_world_sz_
            IF(gfail_info(i) % idx /= -1) THEN
               CALL PIO_TF_Get_idx_from_1d_idx(gfail_info(i) % idx, arr_shape, idx_str)
               PRINT *, "PIO_TF: Fatal Error: rank =", i, ", Val[",&
                    trim(idx_str), "]=",&
                    gfail_info(i) % val, ", Expected = ", gfail_info(i) % exp_val
            END IF
         END DO
      END IF
      deallocate(gfail_info)
   end if
    PIO_TF_Check_short_arr_arr_ = gequal
  END FUNCTION PIO_TF_Check_short_arr_arr_

  LOGICAL FUNCTION PIO_TF_Check_short_arr_arr(arr, exp_arr)
    INTEGER(FC_SHORT), DIMENSION(:), INTENT(IN) :: arr
    INTEGER(FC_SHORT), DIMENSION(:), INTENT(IN) :: exp_arr

    PIO_TF_Check_short_arr_arr = PIO_TF_Check_short_arr_arr_(arr, exp_arr, SHAPE(arr))
  END FUNCTION PIO_TF_Check_short_arr_arr

  ! Note that the tolerance value is ignored when comparing two integer arrays
  ! We have this interface to make it easier to generate common code for
  ! comparing ints, reals and doubles
  LOGICAL FUNCTION PIO_TF_Check_short_arr_arr_tol(arr, exp_arr, tol)
    INTEGER(FC_SHORT), DIMENSION(:), INTENT(IN) :: arr
    INTEGER(FC_SHORT), DIMENSION(:), INTENT(IN) :: exp_arr
    REAL, INTENT(IN) :: tol
    if (tol /= 0) continue ! to suppress warning

    PIO_TF_Check_short_arr_arr_tol = PIO_TF_Check_short_arr_arr(arr, exp_arr)
  END FUNCTION PIO_TF_Check_short_arr_arr_tol

  LOGICAL FUNCTION PIO_TF_Check_short_arr_val(arr, val)
    INTEGER(FC_SHORT), DIMENSION(:), INTENT(IN) :: arr
    INTEGER(FC_SHORT), INTENT(IN) :: val
    INTEGER(fc_short), DIMENSION(:), ALLOCATABLE :: arr_val

    ALLOCATE(arr_val(SIZE(arr)))
    arr_val = val
    PIO_TF_Check_short_arr_val = PIO_TF_Check_short_arr_arr(arr, arr_val)
    DEALLOCATE(arr_val)
  END FUNCTION PIO_TF_Check_short_arr_val

  LOGICAL FUNCTION PIO_TF_Check_2d_short_arr_arr(arr, exp_arr)
    INTEGER(FC_SHORT), DIMENSION(:,:), INTENT(IN) :: arr
    INTEGER(FC_SHORT), DIMENSION(:,:), INTENT(IN) :: exp_arr

    INTEGER(FC_SHORT), DIMENSION(:), ALLOCATABLE :: arr_val
    INTEGER(FC_SHORT), DIMENSION(:), ALLOCATABLE :: exp_arr_val
    INTEGER, PARAMETER :: NDIMS = 2

    ALLOCATE(arr_val(SIZE(arr)))
    ALLOCATE(exp_arr_val(SIZE(exp_arr)))
    arr_val = RESHAPE(arr,(/SIZE(arr)/))
    exp_arr_val = RESHAPE(exp_arr,(/SIZE(exp_arr)/))

    PIO_TF_Check_2d_short_arr_arr = PIO_TF_Check_short_arr_arr_(arr_val, exp_arr_val,&
                                    SHAPE(arr))
    DEALLOCATE(arr_val)
    DEALLOCATE(exp_arr_val)
  END FUNCTION PIO_TF_Check_2d_short_arr_arr

  LOGICAL FUNCTION PIO_TF_Check_3d_short_arr_arr(arr, exp_arr)
    INTEGER(FC_SHORT), DIMENSION(:,:,:), INTENT(IN) :: arr
    INTEGER(FC_SHORT), DIMENSION(:,:,:), INTENT(IN) :: exp_arr

    INTEGER(FC_SHORT), DIMENSION(:), ALLOCATABLE :: arr_val
    INTEGER(FC_SHORT), DIMENSION(:), ALLOCATABLE :: exp_arr_val
    INTEGER, PARAMETER :: NDIMS = 2

    ALLOCATE(arr_val(SIZE(arr)))
    ALLOCATE(exp_arr_val(SIZE(exp_arr)))
    arr_val = RESHAPE(arr,(/SIZE(arr)/))
    exp_arr_val = RESHAPE(exp_arr,(/SIZE(exp_arr)/))

    PIO_TF_Check_3d_short_arr_arr = PIO_TF_Check_short_arr_arr_(arr_val, exp_arr_val,&
                                    SHAPE(arr))
    DEALLOCATE(arr_val)
    DEALLOCATE(exp_arr_val)
  END FUNCTION PIO_TF_Check_3d_short_arr_arr

  LOGICAL FUNCTION PIO_TF_Check_real_arr_arr_tol_(arr, exp_arr, arr_shape, tol)
#ifndef NO_MPIMOD
    USE mpi
#else
    include 'mpif.h'
#endif
    REAL(KIND=fc_real), DIMENSION(:), INTENT(IN) :: arr
    REAL(KIND=fc_real), DIMENSION(:), INTENT(IN) :: exp_arr
    INTEGER, DIMENSION(:), INTENT(IN) :: arr_shape
    REAL, INTENT(IN) :: tol

    CHARACTER(LEN=PIO_TF_MAX_STR_LEN) :: idx_str
    INTEGER :: arr_sz, i, ierr
    ! Not equal at id = nequal_idx
    REAL(KIND=fc_real) :: nequal_idx
    ! Local and global equal bools
    LOGICAL :: lequal, gequal
    TYPE failed_info
      SEQUENCE
      REAL(KIND=fc_real) :: idx
      REAL(KIND=fc_real) :: val
      REAL(KIND=fc_real) :: exp_val
    END TYPE failed_info
    TYPE (failed_info) :: lfail_info
    TYPE (failed_info), DIMENSION(:), ALLOCATABLE :: gfail_info

    if (tol /= 0) continue ! to suppress warning
    arr_sz = SIZE(arr)
    lequal = .TRUE.;
    gequal = .TRUE.;
    nequal_idx = -1;
    IF( arr_sz /= SIZE(exp_arr)) THEN
      PRINT *, "PIO_TF: Unable to compare arrays of different sizes", arr_sz, " and", SIZE(exp_arr)
    END IF
    DO i=1, arr_sz
      IF (arr(i) /= exp_arr(i)) THEN
        lequal = .FALSE.
        nequal_idx = i
      END IF
    END DO
    CALL MPI_ALLREDUCE(lequal, gequal, 1, MPI_LOGICAL, MPI_LAND, pio_tf_comm_, ierr)
    IF (.NOT. gequal) THEN
      lfail_info % idx = nequal_idx
      IF (INT(nequal_idx) /= -1) THEN
        lfail_info % val     = arr(INT(nequal_idx))
        lfail_info % exp_val = exp_arr(INT(nequal_idx))
      END IF
      ALLOCATE(gfail_info(pio_tf_world_sz_))
      ! Gather the ranks where assertion failed
      CALL MPI_GATHER(lfail_info, 3, MPI_REAL, gfail_info, 3, MPI_REAL, 0, pio_tf_comm_, ierr)
      IF (pio_tf_world_rank_ == 0) THEN
        DO i=1,pio_tf_world_sz_
          IF(INT(gfail_info(i) % idx) /= -1) THEN
            CALL PIO_TF_Get_idx_from_1d_idx(INT(gfail_info(i)%idx), arr_shape, idx_str)
            PRINT *, "PIO_TF: Fatal Error: rank =", i, ", Val[", trim(idx_str),&
                 "]=", gfail_info(i) % val, ", Expected = ", gfail_info(i) % exp_val
          END IF
        END DO
      END IF
      DEALLOCATE(gfail_info)
   END IF

    PIO_TF_Check_real_arr_arr_tol_ = gequal
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_real_arr_arr_tol(arr, exp_arr, tol)
    REAL(KIND=fc_real), DIMENSION(:), INTENT(IN) :: arr
    REAL(KIND=fc_real), DIMENSION(:), INTENT(IN) :: exp_arr
    REAL, INTENT(IN) :: tol

    PIO_TF_Check_real_arr_arr_tol = PIO_TF_Check_real_arr_arr_tol_(arr, exp_arr,&
                                SHAPE(arr), tol)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_real_arr_arr(arr, exp_arr)
    REAL(KIND=fc_real), DIMENSION(:), INTENT(IN) :: arr
    REAL(KIND=fc_real), DIMENSION(:), INTENT(IN) :: exp_arr

    PIO_TF_Check_real_arr_arr = PIO_TF_Check_real_arr_arr_tol(arr, exp_arr, 0.0)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_real_arr_val(arr, val)
    REAL(KIND=fc_real), DIMENSION(:), INTENT(IN) :: arr
    REAL(KIND=fc_real), INTENT(IN) :: val
    REAL(KIND=fc_real), DIMENSION(:), ALLOCATABLE :: arr_val

    ALLOCATE(arr_val(SIZE(arr)))
    arr_val = val
    PIO_TF_Check_real_arr_val = PIO_TF_Check_real_arr_arr(arr, arr_val)
    DEALLOCATE(arr_val)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_2d_real_arr_arr(arr, exp_arr)
    REAL(KIND=fc_real), DIMENSION(:,:), INTENT(IN) :: arr
    REAL(KIND=fc_real), DIMENSION(:,:), INTENT(IN) :: exp_arr

    REAL(KIND=fc_real), DIMENSION(:), ALLOCATABLE :: arr_val
    REAL(KIND=fc_real), DIMENSION(:), ALLOCATABLE :: exp_arr_val
    INTEGER, PARAMETER :: NDIMS = 2

    ALLOCATE(arr_val(SIZE(arr)))
    ALLOCATE(exp_arr_val(SIZE(exp_arr)))
    arr_val = RESHAPE(arr,(/SIZE(arr)/))
    exp_arr_val = RESHAPE(exp_arr,(/SIZE(exp_arr)/))

    PIO_TF_Check_2d_real_arr_arr = PIO_TF_Check_real_arr_arr_tol_(arr_val,&
                                      exp_arr_val, SHAPE(arr), 0.0)
    DEALLOCATE(arr_val)
    DEALLOCATE(exp_arr_val)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_3d_real_arr_arr(arr, exp_arr)
    REAL(KIND=fc_real), DIMENSION(:,:,:), INTENT(IN) :: arr
    REAL(KIND=fc_real), DIMENSION(:,:,:), INTENT(IN) :: exp_arr

    REAL(KIND=fc_real), DIMENSION(:), ALLOCATABLE :: arr_val
    REAL(KIND=fc_real), DIMENSION(:), ALLOCATABLE :: exp_arr_val
    INTEGER, PARAMETER :: NDIMS = 2

    ALLOCATE(arr_val(SIZE(arr)))
    ALLOCATE(exp_arr_val(SIZE(exp_arr)))
    arr_val = RESHAPE(arr,(/SIZE(arr)/))
    exp_arr_val = RESHAPE(exp_arr,(/SIZE(exp_arr)/))

    PIO_TF_Check_3d_real_arr_arr = PIO_TF_Check_real_arr_arr_tol_(arr_val,&
                                      exp_arr_val, SHAPE(arr), 0.0)
    DEALLOCATE(arr_val)
    DEALLOCATE(exp_arr_val)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_double_arr_arr_tol_(arr, exp_arr, arr_shape, tol)
#ifndef NO_MPIMOD
    USE mpi
#else
    include 'mpif.h'
#endif
#ifndef MPI_DOUBLE
#define MPI_DOUBLE MPI_DOUBLE_PRECISION
#endif
    REAL(KIND=fc_double), DIMENSION(:), INTENT(IN) :: arr
    REAL(KIND=fc_double), DIMENSION(:), INTENT(IN) :: exp_arr
    INTEGER, DIMENSION(:), INTENT(IN) :: arr_shape
    REAL, INTENT(IN) :: tol

    CHARACTER(LEN=PIO_TF_MAX_STR_LEN) :: idx_str
    INTEGER :: arr_sz, i, ierr
    ! Not equal at id = nequal_idx
    REAL(KIND=fc_double) :: nequal_idx
    ! Local and global equal bools
    LOGICAL :: lequal, gequal
    TYPE failed_info
      SEQUENCE
      REAL(KIND=fc_double) :: idx
      REAL(KIND=fc_double) :: val
      REAL(KIND=fc_double) :: exp_val
    END TYPE failed_info
    TYPE (failed_info) :: lfail_info
    TYPE (failed_info), DIMENSION(:), ALLOCATABLE :: gfail_info

    if (tol /= 0) continue ! to suppress warning
    arr_sz = SIZE(arr)
    lequal = .TRUE.;
    gequal = .TRUE.;
    nequal_idx = -1;
    IF( arr_sz /= SIZE(exp_arr)) THEN
      PRINT *, "PIO_TF: Unable to compare arrays of different sizes", arr_sz, " and ", SIZE(exp_arr)
    END IF
    DO i=1, arr_sz
      IF (arr(i) /= exp_arr(i)) THEN
        lequal = .FALSE.
        nequal_idx = i
      END IF
    END DO
    CALL MPI_ALLREDUCE(lequal, gequal, 1, MPI_LOGICAL, MPI_LAND, pio_tf_comm_, ierr)
    IF (.NOT. gequal) THEN
      lfail_info % idx = nequal_idx
      IF (INT(nequal_idx) /= -1) THEN
        lfail_info % val     = arr(INT(nequal_idx))
        lfail_info % exp_val = exp_arr(INT(nequal_idx))
      END IF

      ALLOCATE(gfail_info(pio_tf_world_sz_))

      ! Gather the ranks where assertion failed
      CALL MPI_GATHER(lfail_info, 3, MPI_DOUBLE, gfail_info, 3, MPI_DOUBLE, 0, pio_tf_comm_, ierr)
      IF (pio_tf_world_rank_ == 0) THEN
        DO i=1,pio_tf_world_sz_
          IF(INT(gfail_info(i) % idx) /= -1) THEN
            CALL PIO_TF_Get_idx_from_1d_idx(INT(gfail_info(i)%idx), arr_shape, idx_str)
            PRINT *, "PIO_TF: Fatal Error: rank =", i, ", Val[",&
                  trim(idx_str), "]=", gfail_info(i) % val,&
                  ", Expected = ", gfail_info(i) % exp_val
          END IF
        END DO
      END IF
      DEALLOCATE(gfail_info)
   END IF

    PIO_TF_Check_double_arr_arr_tol_ = gequal
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_double_arr_arr_tol(arr, exp_arr, tol)
    REAL(KIND=fc_double), DIMENSION(:), INTENT(IN) :: arr
    REAL(KIND=fc_double), DIMENSION(:), INTENT(IN) :: exp_arr
    REAL, INTENT(IN) :: tol

    PIO_TF_Check_double_arr_arr_tol = PIO_TF_Check_double_arr_arr_tol_(arr, exp_arr,&
                                    SHAPE(arr), tol)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_double_arr_arr(arr, exp_arr)
    REAL(KIND=fc_double), DIMENSION(:), INTENT(IN) :: arr
    REAL(KIND=fc_double), DIMENSION(:), INTENT(IN) :: exp_arr

    PIO_TF_Check_double_arr_arr = PIO_TF_Check_double_arr_arr_tol(arr, exp_arr, 0.0)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_double_arr_val(arr, val)
    REAL(KIND=fc_double), DIMENSION(:), INTENT(IN) :: arr
    REAL(KIND=fc_double), INTENT(IN) :: val
    REAL(KIND=fc_double), DIMENSION(:), ALLOCATABLE :: arr_val

    ALLOCATE(arr_val(SIZE(arr)))
    arr_val = val
    PIO_TF_Check_double_arr_val = PIO_TF_Check_double_arr_arr(arr, arr_val)
    DEALLOCATE(arr_val)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_2d_double_arr_arr(arr, exp_arr)
    REAL(KIND=fc_double), DIMENSION(:,:), INTENT(IN) :: arr
    REAL(KIND=fc_double), DIMENSION(:,:), INTENT(IN) :: exp_arr

    REAL(KIND=fc_double), DIMENSION(:), ALLOCATABLE :: arr_val
    REAL(KIND=fc_double), DIMENSION(:), ALLOCATABLE :: exp_arr_val
    INTEGER, PARAMETER :: NDIMS = 2

    ALLOCATE(arr_val(SIZE(arr)))
    ALLOCATE(exp_arr_val(SIZE(exp_arr)))
    arr_val = RESHAPE(arr,(/SIZE(arr)/))
    exp_arr_val = RESHAPE(exp_arr,(/SIZE(exp_arr)/))

    PIO_TF_Check_2d_double_arr_arr = PIO_TF_Check_double_arr_arr_tol_(arr_val,&
                                      exp_arr_val, SHAPE(arr), 0.0)
    DEALLOCATE(arr_val)
    DEALLOCATE(exp_arr_val)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_3d_double_arr_arr(arr, exp_arr)
    REAL(KIND=fc_double), DIMENSION(:,:,:), INTENT(IN) :: arr
    REAL(KIND=fc_double), DIMENSION(:,:,:), INTENT(IN) :: exp_arr

    REAL(KIND=fc_double), DIMENSION(:), ALLOCATABLE :: arr_val
    REAL(KIND=fc_double), DIMENSION(:), ALLOCATABLE :: exp_arr_val
    INTEGER, PARAMETER :: NDIMS = 2

    ALLOCATE(arr_val(SIZE(arr)))
    ALLOCATE(exp_arr_val(SIZE(exp_arr)))
    arr_val = RESHAPE(arr,(/SIZE(arr)/))
    exp_arr_val = RESHAPE(exp_arr,(/SIZE(exp_arr)/))

    PIO_TF_Check_3d_double_arr_arr = PIO_TF_Check_double_arr_arr_tol_(arr_val,&
                                      exp_arr_val, SHAPE(arr), 0.0)
    DEALLOCATE(arr_val)
    DEALLOCATE(exp_arr_val)
  END FUNCTION

  LOGICAL FUNCTION PIO_TF_Check_char_str_str(str1, str2)
    CHARACTER(LEN=*), INTENT(IN)  :: str1
    CHARACTER(LEN=*), INTENT(IN)  :: str2

    IF (str1 == str2) THEN
      PIO_TF_Check_char_str_str = .TRUE.
    ELSE
      PIO_TF_Check_char_str_str = .FALSE.
    END IF
  END FUNCTION

  ! Parse and process input arguments like "--pio-tf-stride=2" passed
  ! to the unit tests - PRIVATE function
  ! FIXME: Do we need to move input argument processing to a new module?
  SUBROUTINE Parse_and_process_input(argv)
    CHARACTER(LEN=*), INTENT(IN)  :: argv
    INTEGER :: pos

    ! All input arguments are of the form <INPUT_ARG_NAME>=<INPUT_ARG>
    PRINT *, argv
    pos = INDEX(argv, "=")
    IF (pos == 0) THEN
      ! Ignore unrecognized args
      RETURN
    ELSE
      ! Check if it an input to PIO testing framework
      IF (argv(:pos) == "--pio-tf-num-io-tasks=") THEN
        READ(argv(pos+1:), *) pio_tf_num_io_tasks_
      ELSE IF (argv(:pos) == "--pio-tf-num-aggregators=") THEN
        READ(argv(pos+1:), *) pio_tf_num_aggregators_
      ELSE IF (argv(:pos) == "--pio-tf-stride=") THEN
        READ(argv(pos+1:), *) pio_tf_stride_
      ELSE IF (argv(:pos) == "--pio-tf-log-level=") THEN
        READ(argv(pos+1:), *) pio_tf_log_level_
      ELSE IF (argv(:pos) == "--pio-tf-input-file=") THEN
        PRINT *, "This option is not implemented yet"
      END IF
    END IF

  END SUBROUTINE Parse_and_process_input

  ! Read input arguments - command line, namelist files - common
  ! to all unit test cases and make sure all MPI processes have
  ! access to it - PRIVATE function
  SUBROUTINE Read_input()
#ifndef NO_MPIMOD
    use mpi
#else
    include 'mpif.h'
#endif
    INTEGER :: i, nargs, ierr
    CHARACTER(LEN=MAX_STDIN_ARG_LEN) :: argv
    ! Need to send pio_tf_stride_, pio_tf_num_io_tasks_, pio_tf_num_aggregators_
    INTEGER :: send_buf(NUM_IARGS)

    IF (pio_tf_world_rank_ == 0) THEN
      nargs = COMMAND_ARGUMENT_COUNT()
      DO i=1, nargs
        CALL GET_COMMAND_ARGUMENT(i, argv)
        CALL Parse_and_process_input(argv)
      END DO
      send_buf(IARG_STRIDE_SIDX) = pio_tf_stride_
      send_buf(IARG_NUM_IO_TASKS_SIDX) = pio_tf_num_io_tasks_
      send_buf(IARG_NUM_AGGREGATORS_SIDX) = pio_tf_num_aggregators_
      send_buf(IARG_LOG_LEVEL_SIDX) = pio_tf_log_level_
    END IF
    ! Make sure all processes get the input args
    CALL MPI_BCAST(send_buf, NUM_IARGS, MPI_INTEGER, 0, pio_tf_comm_, ierr)
    pio_tf_stride_ = send_buf(IARG_STRIDE_SIDX)
    pio_tf_num_io_tasks_ = send_buf(IARG_NUM_IO_TASKS_SIDX)
    pio_tf_num_aggregators_ = send_buf(IARG_NUM_AGGREGATORS_SIDX)
    pio_tf_log_level_ = send_buf(IARG_LOG_LEVEL_SIDX)

  END SUBROUTINE Read_input
END MODULE pio_tutil
