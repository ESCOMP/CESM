#include "config.h"
!>
!! @file
!! These are the extra functions added to support netCDF
!! integration. In most cases these functions are wrappers for
!! existing PIO_ functions, but with names that start with nf_.
!!
!! @author Ed Hartnett
!<

!>
!! @defgroup ncint NetCDF Integration
!! Integrate netCDF and PIO code.
!!
module ncint_mod
  use iso_c_binding
  use pio_kinds
  use pio_types
  use pio_support, only : piodie, debug, debugio, debugasync, checkmpireturn
  use pio_nf, only : pio_set_log_level
  use piolib_mod, only : pio_init, pio_finalize, pio_initdecomp

#ifndef NO_MPIMOD
  use mpi    ! _EXTERNAL
#endif
  implicit none
  private
#ifdef NO_MPIMOD
  include 'mpif.h'    ! _EXTERNAL
#endif

  public :: nf_def_iosystem, nf_free_iosystem, nf_def_decomp, nf_free_decomp, &
       nf_put_vard_int

contains

  !>
  !! @public
  !! @ingroup ncint
  !! Initialize the pio subsystem. This is a collective call. Input
  !! parameters are read on comp_rank=0 values on other tasks are
  !! ignored. This variation of PIO_init locates the IO tasks on a
  !! subset of the compute tasks.
  !!
  !! @param comp_rank mpi rank of each participating task,
  !! @param comp_comm the mpi communicator which defines the
  !! collective.
  !! @param num_iotasks the number of iotasks to define.
  !! @param num_aggregator the mpi aggregator count
  !! @param stride the stride in the mpi rank between io tasks.
  !! @param rearr @copydoc PIO_rearr_method
  !! @param iosysid the ID of the IOSystem.
  !! @param base @em optional argument can be used to offset the first
  !! io task - default base is task 1.
  !! @param rearr_opts the rearranger options.
  !! @author Ed Hartnett
  !<
  function nf_def_iosystem(comp_rank, comp_comm, num_iotasks, &
       num_aggregator, stride,  rearr, iosysid, base, rearr_opts) result(ierr)
    use pio_types, only : pio_internal_error, pio_rearr_opt_t
    use iso_c_binding

    integer(i4), intent(in) :: comp_rank
    integer(i4), intent(in) :: comp_comm
    integer(i4), intent(in) :: num_iotasks
    integer(i4), intent(in) :: num_aggregator
    integer(i4), intent(in) :: stride
    integer(i4), intent(in) :: rearr
    integer(i4), intent(out) :: iosysid
    integer(i4), intent(in),optional :: base
    type (pio_rearr_opt_t), intent(in), optional :: rearr_opts
    type (iosystem_desc_t) :: iosystem
    integer :: ierr

    interface
       integer(C_INT) function nc_set_iosystem(iosystemid) &
            bind(C, name="nc_set_iosystem")
         use iso_c_binding
         integer(C_INT), intent(in), value :: iosystemid
       end function nc_set_iosystem
    end interface

    call PIO_init(comp_rank, comp_comm, num_iotasks, num_aggregator, &
         stride, rearr, iosystem, base, rearr_opts)

    iosysid = iosystem%iosysid
    ierr = nc_set_iosystem(iosysid)

  end function nf_def_iosystem

  !>
  !! @public
  !! @ingroup ncint
  !! Finalizes an IO System. This is a collective call.
  !!
  !! @param iosystem @copydoc io_desc_t
  !! @retval ierr @copydoc error_return
  !! @author Ed Hartnett
  !<
  function nf_free_iosystem() result(status)
    integer(i4) :: ierr
    integer(i4) :: iosysid;
    integer :: status

    interface
       integer(C_INT) function nc_get_iosystem(iosysid) &
            bind(C, name="nc_get_iosystem")
         use iso_c_binding
         integer(C_INT), intent(out) :: iosysid
       end function nc_get_iosystem
    end interface

    interface
       integer(C_INT) function PIOc_finalize(iosysid) &
            bind(C, name="PIOc_finalize")
         use iso_c_binding
         integer(C_INT), intent(in), value :: iosysid
       end function PIOc_finalize
    end interface

    ierr = nc_get_iosystem(iosysid)
    ierr = PIOc_finalize(iosysid)
    status = ierr
  end function nf_free_iosystem

  !>
  !! @public
  !! @ingroup ncint
  !! Free a decomposition.
  !!
  !! @param decompid the decompostion ID.
  !! @author Ed Hartnett
  !<
  function nf_free_decomp(decompid) result(status)
    integer, intent(in) :: decompid
    integer(C_INT) :: cdecompid
    integer(i4) :: ierr
    integer :: status

    interface
       integer(C_INT) function nc_free_decomp(decompid) &
            bind(C, name="nc_free_decomp")
         use iso_c_binding
         integer(C_INT), intent(in), value :: decompid
       end function nc_free_decomp
    end interface

    cdecompid = decompid
    ierr = nc_free_decomp(cdecompid)
    status = ierr
  end function nf_free_decomp

  !>
  !! @public
  !! @ingroup ncint
  !! Implements the block-cyclic decomposition for PIO_initdecomp.
  !! This provides the ability to describe a computational
  !! decomposition in PIO that has a block-cyclic form. That is
  !! something that can be described using start and count arrays.
  !! Optional parameters for this subroutine allows for the
  !! specification of io decomposition using iostart and iocount
  !! arrays. If iostart and iocount arrays are not specified by the
  !! user, and rearrangement is turned on then PIO will calculate a
  !! suitable IO decomposition
  !!
  !! @param iosystem @copydoc iosystem_desc_t
  !! @param basepiotype @copydoc use_PIO_kinds
  !! @param dims An array of the global length of each dimesion of the
  !! variable(s)
  !! @param compstart The start index into the block-cyclic
  !! computational decomposition
  !! @param compcount The count for the block-cyclic computational
  !! decomposition
  !! @param iodesc @copydoc iodesc_generate
  !! @author Ed Hartnett
  !<
  function nf_def_decomp(iosysid, basepiotype, dims, compdof, &
       decompid, rearr, iostart, iocount) result(status)
    integer(i4), intent(in) :: iosysid
    integer(i4), intent(in) :: basepiotype
    integer(i4), intent(in) :: dims(:)
    integer (PIO_OFFSET_KIND), intent(in) :: compdof(:)
    integer(i4), intent(out) :: decompid
    integer, optional, target :: rearr
    integer (PIO_OFFSET_KIND), optional :: iostart(:), iocount(:)
    type (io_desc_t) :: iodesc
    type (iosystem_desc_t) :: iosystem
    integer :: status

    iosystem%iosysid = iosysid
    call PIO_initdecomp(iosystem, basepiotype, dims, compdof, &
         iodesc, rearr, iostart, iocount)
    decompid = iodesc%ioid

    status = 0
  end function nf_def_decomp

  !>
  !! @public
  !! @ingroup ncint
  !! Put distributed array subset of an integer variable.
  !!
  !! This routine is called collectively by all tasks in the
  !! communicator ios.union_comm.
  !!
  !! @param ncid identifies the netCDF file
  !! @param varid the variable ID number
  !! @param decompid the decomposition ID.
  !! @param recnum the record number.
  !! @param op pointer to the data to be written.
  !! @return PIO_NOERR on success, error code otherwise.
  !! @author Ed Hartnett
  !<
  function nf_put_vard_int(ncid, varid, decompid, recnum, ivals) result(status)
    use iso_c_binding
    integer, intent(in):: ncid, varid, decompid, recnum
    integer, intent(in):: ivals(*)
    integer(c_int64_t):: lrecnum
    integer(c_int):: ierr
    integer:: status

    interface
       function nc_put_vard_int(ncid, varid, decompid, lrecnum, op) bind(c)
         use iso_c_binding
         integer(c_int), value, intent(in) :: ncid, varid, decompid
         integer(c_int64_t), value, intent(in) :: lrecnum
         integer(c_int), intent(in) :: op(*)
         integer(c_int) :: nc_put_vard_int
       end function nc_put_vard_int
    end interface

    lrecnum = recnum - 1 ! c functions are 0-based
    ierr = nc_put_vard_int(ncid, varid - 1, decompid, lrecnum, ivals)
    status = ierr
  end function nf_put_vard_int

  end module ncint_mod
