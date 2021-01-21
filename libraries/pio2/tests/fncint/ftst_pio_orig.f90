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
  parameter (FILE_NAME = 'ftst_pio_orig.nc')
  integer :: NDIM3 = 3, NRECS = 2, NLAT = 4, NLON = 4
  character*(*) LAT_NAME, LON_NAME, REC_NAME, VAR_NAME
  parameter (LAT_NAME = 'latitude', LON_NAME = 'longitude', &
       REC_NAME = 'time', VAR_NAME = 'some_data_var')
  integer :: my_rank, ntasks
  integer :: niotasks = 1, numAggregator = 0, stride = 1, base = 0
  integer :: ncid
  integer, dimension(:), allocatable :: compdof
  integer, dimension(:), allocatable :: data_buffer
  integer, dimension(2) :: dims
  integer, dimension(3) :: var_dim
  type(iosystem_desc_t) :: ioSystem
  type(file_desc_t) :: pioFileDesc
  type(io_desc_t) :: iodesc
  type(var_desc_t) :: var
  integer(kind=pio_offset_kind) :: recnum = 1
  integer :: maplen
  integer :: decompid, iosysid
  integer :: varid, i
  integer :: ierr

  ! Set up MPI.
  call MPI_Init(ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, my_rank, ierr)
  call MPI_Comm_size(MPI_COMM_WORLD, ntasks, ierr)

  ! These control logging in the PIO and netCDF libraries.
!  ierr = pio_set_log_level(3)
!  ierr = nf_set_log_level(2)

  ! Define an IOSystem.
  call PIO_init(my_rank, MPI_COMM_WORLD, niotasks, numAggregator, stride, &
       PIO_rearr_subset, ioSystem, base=base)

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

  call PIO_initdecomp(ioSystem, PIO_int, dims, compdof, iodesc)

  ! Create a file.
  ierr = PIO_createfile(ioSystem, pioFileDesc, PIO_IOTYPE_PNETCDF, FILE_NAME, PIO_clobber)
  if (ierr .ne. nf_noerr) call handle_err(ierr)

  ! Define dimensions.
  ierr = PIO_def_dim(pioFileDesc%fh, LAT_NAME, NLAT, var_dim(1))
  if (ierr .ne. nf_noerr) call handle_err(ierr)
  ierr = PIO_def_dim(pioFileDesc%fh, LON_NAME, NLON, var_dim(2))
  if (ierr .ne. nf_noerr) call handle_err(ierr)
  ierr = PIO_def_dim(pioFileDesc%fh, REC_NAME, NF_UNLIMITED, var_dim(3))
  if (ierr .ne. nf_noerr) call handle_err(ierr)

  ! Define a data variable.
  ierr = PIO_def_var(pioFileDesc, VAR_NAME, NF_INT, var_dim, var)
  if (ierr .ne. nf_noerr) call handle_err(ierr)
  ierr = PIO_enddef(pioFileDesc%fh)
  if (ierr .ne. nf_noerr) call handle_err(ierr)

  ! Write 1st record with distributed arrays.
  call PIO_setframe(pioFileDesc, var, recnum)
  call PIO_write_darray(pioFileDesc, var, iodesc, data_buffer, ierr)
  if (ierr .ne. nf_noerr) call handle_err(ierr)

  ! Close the file.
  call PIO_closefile(pioFileDesc)
  if (ierr .ne. nf_noerr) call handle_err(ierr)

  ! Free resources.
  deallocate(compdof)
  deallocate(data_buffer)
  call PIO_freedecomp(ioSystem, iodesc)
  call pio_finalize(ioSystem, ierr)

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
