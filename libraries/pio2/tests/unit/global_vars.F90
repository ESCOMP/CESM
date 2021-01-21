!>
!! @file
!! @brief Module containing variables used across all unit test files
!<
#include "config.h"

module global_vars

  use pio
  use mpi

  Implicit None
  public

  integer, parameter :: str_len = pio_max_name, ntest=4
   integer, parameter ::NETCDF =1, &
                        NETCDF4P=2, &
                        NETCDF4C=3, &
                        PNETCDF=4

  ! MPI Variables
  integer :: my_rank, ntasks
  logical :: master_task

  ! PIO Variables
  integer                     :: stride, niotasks
  type(iosystem_desc_t), save :: pio_iosystem
  type(file_desc_t), save     :: pio_file

  ! Arguments for the different tests
  character(len=str_len), dimension(ntest) :: fnames = (/&
                                                         "piotest_netcdf.nc   ", &
                                                         "piotest_netcdf4p.nc ", &
                                                         "piotest_netcdf4c.nc ", &
                                                         "piotest_pnetcdf.nc  "/)
  integer, dimension(ntest) :: iotypes =  (/ PIO_iotype_netcdf,         &
                                           PIO_iotype_netcdf4p,         &
                                           PIO_iotype_netcdf4c,         &
                                           PIO_iotype_pnetcdf/)
  logical, dimension(ntest) :: ltest

  Contains

    Function is_netcdf(iotype)

      integer, intent(in) :: iotype
      logical             :: is_netcdf

      is_netcdf =  &
           (iotype.eq.PIO_iotype_netcdf) .or. &
           (iotype.eq.PIO_iotype_netcdf4p) .or. &
           (iotype.eq.PIO_iotype_netcdf4c) .or. &
           (iotype.eq.PIO_iotype_pnetcdf)

    End Function is_netcdf

end module global_vars
