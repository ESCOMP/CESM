!> This is a test program for the Fortran API use of the netCDF
!! integration layer.
!!
!! @author Ed Hartnett, 7/19/19

program ftst_pio
  use pio
  implicit none
  include 'mpif.h'
  include 'netcdf.inc'

  character*(*) FILE_NAME
  parameter (FILE_NAME = 'ftst_pio.nc')
  integer :: NDIM3 = 3, NRECS = 2, NLAT = 4, NLON = 4
  character*(*) LAT_NAME, LON_NAME, REC_NAME, VAR_NAME
  parameter (LAT_NAME = 'latitude', LON_NAME = 'longitude', &
       REC_NAME = 'time', VAR_NAME = 'some_data_var')
  integer :: my_rank, ntasks
  integer :: niotasks = 1, numAggregator = 0, stride = 1, base = 0
  integer :: ncid
  integer(kind = PIO_OFFSET_KIND), dimension(:), allocatable :: compdof
  integer, dimension(:), allocatable :: data_buffer
  integer, dimension(2) :: dims
  integer, dimension(3) :: var_dim
  integer :: maplen
  integer :: decompid, iosysid
  integer :: varid, i
  integer :: ierr

  ! Set up MPI.
  call MPI_Init(ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, my_rank, ierr)
  call MPI_Comm_size(MPI_COMM_WORLD, ntasks, ierr)

  ! These control logging in the PIO and netCDF libraries.
  !ierr = pio_set_log_level(3)
  !ierr = nf_set_log_level(2)

  ! Define an IOSystem.
  ierr = nf_def_iosystem(my_rank, MPI_COMM_WORLD, niotasks, numAggregator, &
       stride, PIO_rearr_box, iosysid, base)
  if (ierr .ne. nf_noerr) call handle_err(ierr)

  ! Define a 2D decomposition.
  dims(1) = 4
  dims(2) = 4
  maplen = 4
  print *, 'dims: ', dims
  print *, 'maplen: ', maplen
  print *, 'my_rank: ', my_rank
  allocate(compdof(maplen))
  allocate(data_buffer(maplen))
  ! Row decomposition. Recall that my_rank is 0-based, even
  ! in fortran. Also recall that compdof is 1-based for fortran.
  do i = 1, maplen
     compdof(i) = i + my_rank * maplen
     data_buffer(i) = my_rank * 10 + i
  end do
  print *, 'compdof', my_rank, compdof
  ierr = nf_def_decomp(iosysid, PIO_int, dims, compdof, decompid)
  if (ierr .ne. nf_noerr) call handle_err(ierr)

  ! Create a file.
  ierr = nf_create(FILE_NAME, 64, ncid)
  if (ierr .ne. nf_noerr) call handle_err(ierr)

  ! Define dimensions.
  ierr = nf_def_dim(ncid, LAT_NAME, NLAT, var_dim(1))
  if (ierr .ne. nf_noerr) call handle_err(ierr)
  ierr = nf_def_dim(ncid, LON_NAME, NLON, var_dim(2))
  if (ierr .ne. nf_noerr) call handle_err(ierr)
  ierr = nf_def_dim(ncid, REC_NAME, NF_UNLIMITED, var_dim(3))
  if (ierr .ne. nf_noerr) call handle_err(ierr)

  ! Define a data variable.
  ierr = nf_def_var(ncid, VAR_NAME, NF_INT, NDIM3, var_dim, varid)
  if (ierr .ne. nf_noerr) call handle_err(ierr)
  ierr = nf_enddef(ncid)
  if (ierr .ne. nf_noerr) call handle_err(ierr)

  ! Write 1st record with distributed arrays.
  ierr = nf_put_vard_int(ncid, varid, decompid, 1, data_buffer)
  if (ierr .ne. nf_noerr) call handle_err(ierr)

  ! Close the file.
  ierr = nf_close(ncid)
  if (ierr .ne. nf_noerr) call handle_err(ierr)

  ! Free resources.
  ierr = nf_free_decomp(decompid)
  if (ierr .ne. nf_noerr) call handle_err(ierr)
  ierr = nf_free_iosystem()
  if (ierr .ne. nf_noerr) call handle_err(ierr)
  deallocate(compdof)
  deallocate(data_buffer)

  ! We're done!
  call MPI_Finalize(ierr)
  if (my_rank .eq. 0) then
     print *, '*** SUCCESS running ftst_pio!'
  endif
end program ftst_pio

subroutine handle_err(errcode)
  implicit none
  include 'netcdf.inc'
  integer errcode

  print *, 'Error: ', nf_strerror(errcode)
  stop 2
end subroutine handle_err
