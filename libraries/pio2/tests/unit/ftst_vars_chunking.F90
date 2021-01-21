  ! This is a test of the PIO Fortran library.

  ! This tests var functions.

  ! Ed Hartnett, 8/28/20
#include "config.h"

program ftst_vars_chunking
  use mpi
  use pio
  use pio_nf
  
  integer, parameter :: NUM_IOTYPES = 2
  integer, parameter :: NDIM2 = 2
  
  type(iosystem_desc_t) :: pio_iosystem
  type(file_desc_t)     :: pio_file
  type(var_desc_t)      :: pio_var  
  integer :: my_rank, ntasks
  integer :: niotasks = 1, stride = 1
  character(len=64) :: filename = 'ftst_vars_chunking.nc'
  character(len=64) :: dim_name_1 = 'influence_on_Roman_history'
  character(len=64) :: dim_name_2 = 'age_at_death'
  character(len=64) :: var_name = 'Caesar'
  integer :: dimid1, dimid2, dim_len1 = 40, dim_len2 = 80
  integer :: chunksize1 = 10, chunksize2 = 20
  integer :: storage_in
  integer (kind=PIO_OFFSET_KIND) :: chunksizes_in(NDIM2)
  integer :: iotype(NUM_IOTYPES) = (/ PIO_iotype_netcdf4c, PIO_iotype_netcdf4p /)
  integer :: iotype_idx, ierr
  
  ! Set up MPI
  call MPI_Init(ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, my_rank, ierr)
  call MPI_Comm_size(MPI_COMM_WORLD, ntasks , ierr)

  ! This whole test only works for netCDF/HDF5 files, because it is
  ! about chunking.
#ifdef _NETCDF4
  if (my_rank .eq. 0) print *,'Testing variables...'

  ! Initialize PIO.
  call PIO_init(my_rank, MPI_COMM_WORLD, niotasks, 0, stride, &
       PIO_rearr_subset, pio_iosystem, base=1)

  ! Set error handling for test.
  call PIO_seterrorhandling(pio_iosystem, PIO_RETURN_ERROR)  
  call PIO_seterrorhandling(PIO_DEFAULT, PIO_RETURN_ERROR)

  ! Uncomment (and build with --enable-logging) to turn on logging.
  !ret_val = PIO_set_log_level(3)

  ! Try this test for NETCDF4C and NETCDF4P.
  do iotype_idx = 1, NUM_IOTYPES
     
     ! Create a file.
     ierr = PIO_createfile(pio_iosystem, pio_file, iotype(iotype_idx), filename)
     if (ierr .ne. PIO_NOERR) stop 3
     
     ! Define dims.
     ret_val = PIO_def_dim(pio_file, dim_name_1, dim_len1, dimid1)
     if (ierr .ne. PIO_NOERR) stop 5
     ret_val = PIO_def_dim(pio_file, dim_name_2, dim_len2, dimid2)
     if (ierr .ne. PIO_NOERR) stop 6
     
     ! Define a var.
     ret_val = PIO_def_var(pio_file, var_name, PIO_int, (/dimid1, dimid2/), pio_var)
     if (ierr .ne. PIO_NOERR) stop 7
     
     ! Define chunking for var.
     ret_val = PIO_def_var_chunking(pio_file, pio_var, 0, (/chunksize1, chunksize2/))
     if (ierr .ne. PIO_NOERR) stop 9
     
     ! Close the file.
     call PIO_closefile(pio_file)
     
     ! Open the file.
     ret_val = PIO_openfile(pio_iosystem, pio_file, iotype(iotype_idx), filename, PIO_nowrite)  
     if (ierr .ne. PIO_NOERR) stop 23
     
     ! Find var chunksizes using varid.
     ret_val = PIO_inq_var_chunking(pio_file, 1, storage_in, chunksizes_in)
     if (ierr .ne. PIO_NOERR) stop 25
     if (chunksizes_in(1) .ne. chunksize1) stop 26
     if (chunksizes_in(2) .ne. chunksize2) stop 26

     ! Close the file.
     call PIO_closefile(pio_file)

  end do ! next IOTYPE
  
  ! Finalize PIO.
  call PIO_finalize(pio_iosystem, ierr)
  
  if (my_rank .eq. 0) print *,'SUCCESS!'
#endif 
  call MPI_Finalize(ierr)        
end program ftst_vars_chunking
