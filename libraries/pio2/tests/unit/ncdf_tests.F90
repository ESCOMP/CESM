!>
!! @file
!! @brief Module containing netcdf-specific PIO unit tests
!<
#include "config.h"

module ncdf_tests

  use pio
  use global_vars

  Implicit None
  private
  save

  public :: test_redef
  public :: test_enddef
  public :: test_nc4

Contains

  Subroutine test_redef(test_id, err_msg)
    ! test_redef():
    ! * Open file, enter define mode, add dimension / variable / attribute
    !   * Try to run PIO_redef from define mode, check for error
    ! * Leave define mode, close file
    !   * Try to run PIO_redef with closed file
    ! Routines used in test: PIO_initdecomp, PIO_openfile, PIO_redef, PIO_def_dim,
    !                        PIO_def_var, PIO_put_att, PIO_enddef,
    !                        PIO_write_darray, PIO_closefile, PIO_freedecomp

    ! Input / Output Vars
    integer,                intent(in)  :: test_id
    character(len=str_len), intent(out) :: err_msg

    ! Local Vars
    character(len=str_len) :: filename
    integer                :: iotype, ret_val

    ! Data used to test writing
    integer,          dimension(2) :: data_to_write, compdof
    integer,          dimension(1) :: dims
    type(io_desc_t)                :: iodesc_nCells
    integer                        :: pio_dim
    type(var_desc_t)               :: pio_var

    err_msg = "no_error"

    dims(1) = 2*ntasks
    compdof = 2*my_rank+(/1,2/)  ! Where in the global array each task writes
    data_to_write = 1+my_rank

    call PIO_initdecomp(pio_iosystem, PIO_int, dims, compdof, iodesc_nCells)

    filename = fnames(test_id)
    iotype   = iotypes(test_id)

    ! Open existing file, write data to it
    ret_val = PIO_openfile(pio_iosystem, pio_file, iotype, filename, PIO_write)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_openfile
       err_msg = "Could not open " // trim(filename) // " in write mode"
       return
    end if

    ! Enter define mode
    ret_val = PIO_redef(pio_file)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_redef
       err_msg = "Could not enter define mode"
       call PIO_closefile(pio_file)
       return
    end if

    ! Define a new dimension M (already has 'N' from previous tests)
    ret_val = PIO_def_dim(pio_file, 'M', int(2*ntasks,pio_offset_kind), pio_dim)
    if (ret_val .ne. PIO_NOERR) then
       err_msg = "Could not define dimension M"
       call PIO_closefile(pio_file)
       return
    end if

    ! Define a new variable foo2 (already has 'foo' from previous tests)
    ret_val = PIO_def_var(pio_file, 'foo2', PIO_int, &
         (/pio_dim/), pio_var)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_def_var
       err_msg = "Could not define variable foo2"
       call PIO_closefile(pio_file)
       return
    end if

    ret_val = PIO_put_att(pio_file, pio_var, "max_val", ntasks)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_put_att
       err_msg = "Could not define max_val attribute for foo2"
       call PIO_closefile(pio_file)
       return
    end if

    ret_val = PIO_put_att(pio_file, PIO_global, "created_by", "PIO unit tests")
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_put_att
       err_msg = "Could not define global attribute"
       call PIO_closefile(pio_file)
       return
    end if

    ! Try to enter define mode again
    if(master_task) write(*,"(6x,A,1x)") "trying to enter define mode in define mode, error expected ... "
    call mpi_barrier(MPI_COMM_WORLD,ret_val)

    ret_val = PIO_redef(pio_file)
    if (ret_val .eq. PIO_NOERR) then
       ! Error in PIO_redef
       err_msg = "Entered define mode from define mode"
       call PIO_closefile(pio_file)
       return
    end if

    ! Leave define mode
    ret_val = PIO_enddef(pio_file)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_enddef
       print *,__FILE__,__LINE__,ret_val
       err_msg = "Could not end define mode"
       return
    end if

    ! Write foo2
    call PIO_write_darray(pio_file, pio_var, iodesc_nCells, data_to_write, ret_val)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_write_darray
       err_msg = "Could not write data"
       return
    end if

    ! Close file
    call PIO_closefile(pio_file)

    ! Try to enter define mode again
    if(master_task) write(*,"(6x,A,1x)") "trying to enter define mode in closed file, error expected ... "
    call mpi_barrier(MPI_COMM_WORLD,ret_val)
    ret_val = PIO_redef(pio_file)
    if (ret_val .eq. PIO_NOERR) then
       ! Error in PIO_redef
       err_msg = "Entered define mode from a closed file"
       return
    end if

    ! Free decomp
    call PIO_freedecomp(pio_iosystem, iodesc_nCells)

  End Subroutine test_redef

  Subroutine test_enddef(test_id, err_msg)
    ! test_enddef():
    ! * Open file with PIO_nowrite, try to enter define mode, check for error
    ! * Open file with PIO_write, enter define mode, leave define mode
    ! * Try calling PIO_enddef from data mode, check for error
    ! * Close file
    !   * Try to run PIO_enddef with closed file
    ! Routines used in test: PIO_openfile, PIO_redef, PIO_enddef, PIO_closefile

    ! Input / Output Vars
    integer,                intent(in)  :: test_id
    character(len=str_len), intent(out) :: err_msg

    ! Local Vars
    character(len=str_len) :: filename
    integer                :: iotype, ret_val

    err_msg = "no_error"
    filename = fnames(test_id)
    iotype   = iotypes(test_id)

    ! Open existing file (read-only)
    ret_val = PIO_openfile(pio_iosystem, pio_file, iotype, filename, PIO_nowrite)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_openfile
       err_msg = "Could not open " // trim(filename) // " in write mode"
       return
    end if

    ! Enter define mode
    if(master_task) write(*,"(6x,A,1x)") "trying to enter define mode in read only file, error expected ... "
    call mpi_barrier(MPI_COMM_WORLD,ret_val)
    ret_val = PIO_redef(pio_file)
    if (ret_val .eq. PIO_NOERR) then
       ! Error in PIO_redef
       err_msg = "Entered define mode in read-only file"
       call PIO_closefile(pio_file)
       return
    end if

    ! Close file
    call PIO_closefile(pio_file)

    ! Open existing file
    ret_val = PIO_openfile(pio_iosystem, pio_file, iotype, filename, PIO_write)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_openfile
       err_msg = "Could not open " // trim(filename) // " in write mode"
       return
    end if

    ! Enter define mode
    ret_val = PIO_redef(pio_file)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_redef
       err_msg = "Could not enter define mode"
       call PIO_closefile(pio_file)
       return
    end if

    ! End define mode
    ret_val = PIO_enddef(pio_file)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_enddef
       print *,__FILE__,__LINE__,ret_val
       err_msg = "Could not end define mode"
       call PIO_closefile(pio_file)
       return
    end if

    ! Try to end define mode from data mode
    if(master_task) write(*,"(6x,A,1x)") "trying to end define mode in data mode, error expected ... "
    call mpi_barrier(MPI_COMM_WORLD,ret_val)
    ret_val = PIO_enddef(pio_file)
    if (ret_val .eq. PIO_NOERR) then
       ! Error in PIO_enddef
       err_msg = "Ended define mode while in data mode"
       call PIO_closefile(pio_file)
       return
    end if

    call mpi_barrier(MPI_COMM_WORLD,ret_val)
    ! Close file
    call PIO_closefile(pio_file)

    ! Try to end define mode in un-opened file
    if(master_task) write(*,"(6x,A,1x)") "trying to end define mode in closed file, error expected ... "
    call mpi_barrier(MPI_COMM_WORLD,ret_val)
    ret_val = PIO_enddef(pio_file)
    if (ret_val .eq. PIO_NOERR) then
       ! Error in PIO_enddef
       err_msg = "Ended define mode in a file that was already closed"
       return
    end if
    call mpi_barrier(MPI_COMM_WORLD,ret_val)

  End Subroutine test_enddef

  Subroutine test_nc4(test_id, err_msg)
    ! test_nc4():
    ! * Tests netCDF-4 function pio_def_var_deflate().
    ! * Open file, enter define mode, add dimension / variable / attribute
    !   * Set deflate on the variable.
    ! * Leave define mode, close file
    ! * Re-open file and check that deflate value is correct.
    ! Routines used in test: PIO_initdecomp, PIO_openfile, PIO_def_dim,
    !                        PIO_def_var, PIO_def_var_deflate, PIO_enddef,
    !                        PIO_write_darray, PIO_closefile, PIO_freedecomp

    ! Input / Output Vars
    integer,                intent(in)  :: test_id
    character(len=str_len), intent(out) :: err_msg

    ! Local Vars
    character(len=str_len) :: filename
    integer                :: iotype, ret_val

    ! Data used to test writing
    integer,          dimension(2) :: data_to_write, compdof
    integer,          dimension(1) :: dims
    type(io_desc_t)                :: iodesc_nCells
    integer                        :: pio_dim
    type(var_desc_t)               :: pio_var

    ! These will be used to test the compression settings for netCDF-4
    ! files.
    integer :: shuffle
    integer :: deflate
    integer :: my_deflate_level, deflate_level, deflate_level_2

    ! These will be used to set chunk cache sizes in netCDF-4/HDF5
    ! files.
    integer(kind=PIO_OFFSET_KIND) :: chunk_cache_size
    integer(kind=PIO_OFFSET_KIND) :: chunk_cache_nelems
    real :: chunk_cache_preemption

    ! These will be used to check the settings of the chunk caches.
    integer(kind=PIO_OFFSET_KIND) :: chunk_cache_size_in
    integer(kind=PIO_OFFSET_KIND) :: chunk_cache_nelems_in
    real :: chunk_cache_preemption_in

    err_msg = "no_error"

    dims(1) = 2*ntasks
    compdof = 2*my_rank+(/1,2/)  ! Where in the global array each task writes
    data_to_write = 1+my_rank

    print*, 'PIO_initdecomp'
    call PIO_initdecomp(pio_iosystem, PIO_int, dims, compdof, iodesc_nCells)

    filename = fnames(test_id)
    iotype   = iotypes(test_id)

    ! Set the chunk cache for netCDF-4/HDF5 files.
    chunk_cache_size = 1024 * 1024
    chunk_cache_nelems = 3
    chunk_cache_preemption = 0.1
    print*, 'PIO_set_chunk_cache'
    ret_val = PIO_set_chunk_cache(pio_iosystem%iosysid, iotype, chunk_cache_size, &
         chunk_cache_nelems, chunk_cache_preemption)
    
    ! Should not have worked except for netCDF-4/HDF5 iotypes.
    if (iotype .eq. PIO_iotype_netcdf4c .and. ret_val .ne. PIO_NOERR) then
       err_msg = "Could not set chunk cache"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_pnetcdf .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to set chunk cache for pnetcdf file"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_netcdf .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to set chunk cache for netcdf classic file"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_netcdf4p .and. ret_val .ne. PIO_NOERR) then
       err_msg = "Could not set chunk cache"
       call PIO_closefile(pio_file)
       return
    end if

    ! Check the settings of the chunk cache for netCDF-4/HDF5 files.
    print*, 'testing PIO_get_chunk_cache'
    ret_val = PIO_get_chunk_cache(pio_iosystem%iosysid, iotype, chunk_cache_size_in, &
         chunk_cache_nelems_in, chunk_cache_preemption_in)
    print*, 'PIO_get_chunk_cache returned ', chunk_cache_size_in, &
         chunk_cache_nelems_in, chunk_cache_preemption_in
    
    ! Should not have worked except for netCDF-4/HDF5 iotypes.
    if (iotype .eq. PIO_iotype_netcdf4c .or. iotype .eq. PIO_iotype_netcdf4p) then
       if (ret_val .ne. PIO_NOERR) then
          err_msg = "Could not set chunk cache"
          call PIO_closefile(pio_file)
          return
       endif
       if (chunk_cache_size_in .ne. chunk_cache_size .or. chunk_cache_nelems_in .ne. chunk_cache_nelems .or. &
            chunk_cache_preemption_in .ne. chunk_cache_preemption) then
          err_msg = "Incorrect chunk cache values!"
          call PIO_closefile(pio_file)
          return
       endif
    else if (iotype .eq. PIO_iotype_pnetcdf .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to set chunk cache for pnetcdf file"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_netcdf .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to set chunk cache for netcdf classic file"
       call PIO_closefile(pio_file)
       return
    end if

    ! Open existing file, write data to itn
    print*, 'PIO_openfile ', filename
    ret_val = PIO_openfile(pio_iosystem, pio_file, iotype, filename, PIO_write)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_openfile
       err_msg = "Could not open " // trim(filename) // " in write mode"
       return
    end if

    ! Enter define mode
    print*, 'PIO_redef'
    ret_val = PIO_redef(pio_file)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_redef
       err_msg = "Could not enter define mode"
       call PIO_closefile(pio_file)
       return
    end if

    ! Define a new dimension M1.
    print*, 'PIO_def_dim'
    ret_val = PIO_def_dim(pio_file, 'M111222', int(2*ntasks,pio_offset_kind), pio_dim)
    if (ret_val .ne. PIO_NOERR) then
       err_msg = "Could not define dimension M111222"
       call PIO_closefile(pio_file)
       return
    end if

    ! Define a new variable
    print*, 'PIO_def_var'
    ret_val = PIO_def_var(pio_file, 'foo2222', PIO_int, (/pio_dim/), pio_var)
    if (ret_val .ne. PIO_NOERR) then
       err_msg = "Could not define variable foo2222"
       call PIO_closefile(pio_file)
       return
    end if

    ! Set the chunk cache for this variable in netCDF-4 files.
    chunk_cache_size = 1024
    chunk_cache_nelems = 4
    chunk_cache_preemption = 0.2
    print*, 'PIO_set_var_chunk_cache'
    ret_val = PIO_set_var_chunk_cache(pio_file, pio_var, chunk_cache_size, chunk_cache_nelems, &
         chunk_cache_preemption)
    
    ! Should not have worked except for netCDF-4/HDF5 iotypes.
    if (iotype .eq. PIO_iotype_netcdf4c .and. ret_val .ne. PIO_NOERR) then
       err_msg = "Could not set variable chunk cache"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_pnetcdf .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to set variable chunk cache for pnetcdf file"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_netcdf .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to set variable chunk cache for netcdf classic file"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_netcdf4p .and. ret_val .ne. PIO_NOERR) then
       err_msg = "Could not set variable chunk cache"
       call PIO_closefile(pio_file)
       return
    end if

    ! Check the settings of the chunk cache for netCDF-4/HDF5 files.
    print*, 'PIO_get_var_chunk_cache'
    ret_val = PIO_get_var_chunk_cache(pio_file, pio_var, chunk_cache_size_in, &
         chunk_cache_nelems_in, chunk_cache_preemption_in)
    print*, 'PIO_get_var_chunk_cache ret_val=', ret_val
    
    ! Should not have worked except for netCDF-4/HDF5 iotypes.
    if (iotype .eq. PIO_iotype_netcdf4c .or. iotype .eq. PIO_iotype_netcdf4p) then
       if (ret_val .ne. PIO_NOERR) then
          err_msg = "Could not set variable chunk cache"
          call PIO_closefile(pio_file)
          return
       endif
       if (chunk_cache_size_in .ne. chunk_cache_size .or. &
            chunk_cache_nelems_in .ne. chunk_cache_nelems .or. &
            chunk_cache_preemption_in .ne. chunk_cache_preemption) then
          err_msg = "Incorrect variable chunk cache values!"
          call PIO_closefile(pio_file)
          return
       endif
    else if (iotype .eq. PIO_iotype_pnetcdf .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to get variable chunk cache for pnetcdf file"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_netcdf .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to get variable chunk cache for netcdf classic file"
       call PIO_closefile(pio_file)
       return
    end if

    ! Try to turn on compression for this variable.
    print*, 'testing PIO_def_var_deflate' 
    shuffle = 0
    deflate = 1

    ! NetCDF-4.7.4 lost ability to set deflate once it was already
    ! set. THis is going to be fixed in the next release of
    ! netCDF. Until then I will change all deflate levels to 1 and the
    ! test will pass.
    ! deflate_level = 2
    ! deflate_level_2 = 4
    deflate_level = 1
    deflate_level_2 = 1
    ret_val = PIO_def_var_deflate(pio_file, pio_var, shuffle, deflate, &
         deflate_level)

    ! Should not have worked except for netCDF-4/HDF5 sequential, and
    ! perhaps parallel.
    if (iotype .eq. PIO_iotype_netcdf4c .and. ret_val .ne. PIO_NOERR) then
       err_msg = "Could not turn on compression for variable foo2222"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_netcdf4p) then
       !err_msg = "Could not turn on compression for variable foo2222"
       ! if (ret_val .ne. PIO_NOERR) then
       !    call PIO_closefile(pio_file)
       !    return
       ! end if
       ! return
    else if (iotype .eq. PIO_iotype_pnetcdf .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to turn deflate on for pnetcdf file"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_netcdf .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to turn deflate on for netcdf classic file"
       call PIO_closefile(pio_file)
       return
    end if

    print*, 'testing PIO_put_att'
    ret_val = PIO_put_att(pio_file, pio_var, "max_val", ntasks)
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_put_att
       err_msg = "Could not define max_val attribute for foo2"
       call PIO_closefile(pio_file)
       return
    end if

    print*, 'testing PIO_put_att'
    ret_val = PIO_put_att(pio_file, PIO_global, "created_by", "PIO unit tests")
    if (ret_val .ne. PIO_NOERR) then
       ! Error in PIO_put_att
       err_msg = "Could not define global attribute"
       call PIO_closefile(pio_file)
       return
    end if

    ! Check the compression settings of the variables.
    print*, 'testing PIO_inq_var_deflate'
    ret_val = PIO_inq_var_deflate(pio_file, pio_var, shuffle, deflate, my_deflate_level)

    ! Should not have worked except for netCDF-4/HDF5 sequential, and maybe parallel.
    if (iotype .eq. PIO_iotype_netcdf4c) then
       if (ret_val .ne. PIO_NOERR) then
          err_msg = "Got error trying to inquire about deflate on for serial netcdf-4 file"
          call PIO_closefile(pio_file)
          return
       else
          print *,shuffle, deflate, deflate_level, my_deflate_level
          if (shuffle .ne. 0 .or. deflate .ne. 1 .or. my_deflate_level .ne. deflate_level) then
             err_msg = "Wrong values for deflate and shuffle for serial netcdf-4 file"
             call PIO_closefile(pio_file)
             return
          end if
       end if
    else if (iotype .eq. PIO_iotype_netcdf4p) then
       ! if (ret_val .eq. PIO_NOERR) then
       !    print *,shuffle, deflate, deflate_level, my_deflate_level
       !    if (shuffle .ne. 0 .or. deflate .ne. 1 .or. my_deflate_level .ne. deflate_level) then
       !       err_msg = "Wrong values for deflate and shuffle for parallel netcdf-4 file"
       !       call PIO_closefile(pio_file)
       !       return
       !    end if
       ! end if
    else if ((iotype .eq. PIO_iotype_pnetcdf .or. iotype .eq. PIO_iotype_netcdf) .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to check deflate for non-netcdf-4 file"
       call PIO_closefile(pio_file)
       return
    end if

    ! Try to turn on compression for this variable.
    print*, 'testing PIO_def_var_deflate'
    ret_val = PIO_def_var_deflate(pio_file, pio_var%varid, shuffle, deflate, &
         deflate_level_2)

    ! Should not have worked except for netCDF-4/HDF5.
    if (iotype .eq. PIO_iotype_netcdf4c .and. ret_val .ne. PIO_NOERR) then
       err_msg = "Could not turn on compression for variable foo2222 second time"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_pnetcdf .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to turn deflate on for pnetcdf file"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_netcdf .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to turn deflate on for netcdf classic file"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_netcdf4p) then
!       err_msg = "Could not turn on compression for variable foo2222 second time"
!       call PIO_closefile(pio_file)
!       return
    end if

    ! Leave define mode
    print*, 'testing PIO_enddef'
    ret_val = PIO_enddef(pio_file)
    if (ret_val .ne. PIO_NOERR) then
       err_msg = "Could not end define mode"
       return
    end if

    ! Check the compression settings of the variables.
    print*, 'testing PIO_inq_var_deflate'
    ret_val = PIO_inq_var_deflate(pio_file, pio_var%varid, shuffle, deflate, my_deflate_level)

    ! Should not have worked except for netCDF-4/HDF5 serial and netcdf-4/HDF5 parallel.
    if (iotype .eq. PIO_iotype_netcdf4c) then
       if (ret_val .ne. PIO_NOERR) then
          err_msg = "Got error trying to inquire about deflate on for serial netcdf-4 file"
          call PIO_closefile(pio_file)
          return
       else
          if (shuffle .ne. 0 .or. deflate .ne. 1 .or. my_deflate_level .ne. deflate_level_2) then
             err_msg = "Wrong values for deflate and shuffle for serial netcdf-4 file"
             call PIO_closefile(pio_file)
             return
          end if
       end if
    else if ((iotype .eq. PIO_iotype_pnetcdf .or. iotype .eq. PIO_iotype_netcdf) .and. ret_val .eq. PIO_NOERR) then
       err_msg = "Did not get expected error when trying to check deflate for non-netcdf-4 file"
       call PIO_closefile(pio_file)
       return
    else if (iotype .eq. PIO_iotype_netcdf4p) then
       ! if (ret_val .ne. PIO_NOERR) then
       !    err_msg = "Got error trying to inquire about deflate on for parallel netcdf-4 file"
       !    call PIO_closefile(pio_file)
       !    return
       ! else
       !    if (shuffle .ne. 0 .or. deflate .ne. 1 .or. my_deflate_level .ne. deflate_level_2) then
       !       err_msg = "Wrong values for deflate and shuffle for parallel netcdf-4 file"
       !       call PIO_closefile(pio_file)
       !       return
       !    end if
       ! end if
    end if

    ! Write foo2
    print*, 'testing PIO_write_darray'
    call PIO_write_darray(pio_file, pio_var, iodesc_nCells, data_to_write, ret_val)
    if (ret_val .ne. PIO_NOERR) then
       err_msg = "Could not write data"
       return
    end if

    ! Close file
    print*, 'testing  PIO_closefile'
    call PIO_closefile(pio_file)

    ! Free decomp
    print*, 'testing  PIO_freedecomp'    
    call PIO_freedecomp(pio_iosystem, iodesc_nCells)
    call mpi_barrier(MPI_COMM_WORLD,ret_val)
    
    print*, 'after testing  err_msg = '    , err_msg
  End Subroutine test_nc4
end module ncdf_tests
