#include "config.h"
!>
!! @file
!! Derived datatypes and constants for PIO Fortran API.
!! @author Jim Edwards
!<
!>
!! @private
!! @defgroup iodesc_generate Creating Decompositions
!! Create a decomposition of data from a variable to multiple
!! computation tasks.
!!
!! @public
!! @defgroup PIO_iotype PIO_iotype
!! An integer parameter which controls the iotype.
!!   - PIO_iotype_pnetcdf : parallel read/write of pNetCDF files (netcdf3)
!!   - PIO_iotype_netcdf : serial read/write of NetCDF files using 'base_node' (netcdf3)
!!   - PIO_iotype_netcdf4c : parallel read/serial write of NetCDF4 (HDF5) files with data compression
!!   - PIO_iotype_netcdf4p : parallel read/write of NETCDF4 (HDF5) files
!!
!! @defgroup PIO_rearr_method Rearranger Methods
!! Rearranger methods.
!!  - PIO_rearr_none : Do not use any form of rearrangement
!!  - PIO_rearr_box : Use a PIO internal box rearrangement
!!  - PIO_rearr_subset : Use a PIO internal subsetting rearrangement
!!
!! @defgroup PIO_error_method Error Handling Methods
!! The error handling setting controls what happens if errors are
!! encountered by PIO. The three types of error handling methods are:
!!  - PIO_INTERNAL_ERROR  : abort on error from any task
!!  - PIO_BCAST_ERROR     : broadcast an error from io_rank 0 to all tasks in comm
!!  - PIO_RETURN_ERROR    : do nothing - allow the user to handle it
!>
!! @defgroup error_return Error Return Codes
!! The error return code (see @ref PIO_seterrorhandling).
!!
!! @defgroup PIO_kinds PIO Fortran Type Kinds
!! PIO supports different kinds of Fortran types.
!!  - PIO_doauble : 8-byte reals or double precision
!!  - PIO_real : 4-byte reals
!!  - PIO_int :  4-byte integers
!!  - PIO_short : 2-byte integers
!!  - PIO_char : character

module pio_types
  use pio_kinds
  use iso_c_binding
  implicit none
  private
  type, public :: DecompMap_t !< data structure to describe decomposition.
#ifdef SEQUENCE
     sequence
#endif
     integer(i4) :: start  !< start
     integer(i4) :: length !< length
  end type DecompMap_t

  !>
  !! @struct iosystem_desc_t
  !! A defined PIO system descriptor created by @ref PIO_init (see
  !! pio_types).
  type, public :: IOSystem_desc_t
     integer(kind=c_int) :: iosysid = -1 !< iosysid
  end type IOSystem_desc_t

  !>
  !! @public
  !! @struct file_desc_t
  !! File descriptor returned by \ref PIO_openfile or \ref
  !! PIO_createfile (see pio_types).
  type, public :: File_desc_t
     integer(kind=c_int) :: fh !< file handle
     type(iosystem_desc_t), pointer :: iosystem => null() !< iosystem
  end type File_desc_t

  !>
  !! @public
  !! @struct io_desc_t
  !! An decomposition handle that is generated in @ref PIO_initdecomp.
  !! (see pio_types)
  type, public :: io_desc_t
#ifdef SEQUENCE
     sequence
#endif
     integer(i4)         :: ioid !< decomposition id
  end type io_desc_t

  !>
  !! @public
  !! @struct var_desc_t
  !! A variable descriptor returned from @ref PIO_def_var (see
  !! pio_types).
  type, public :: Var_desc_t
#ifdef SEQUENCE
     sequence
#endif
     integer(i4) :: varID !< variable id
     integer(i4) :: ncid  !< file id
  end type Var_desc_t

  integer(i4), public, parameter ::  &
       PIO_iotype_pnetcdf = 1, &   !< parallel read/write of pNetCDF files
       PIO_iotype_netcdf  = 2, &   !< serial read/write of NetCDF file using 'base_node'
       PIO_iotype_netcdf4c = 3, &  !< netcdf4 (hdf5 format) file opened for compression (serial write access only)
       PIO_iotype_netcdf4p = 4     !< netcdf4 (hdf5 format) file opened in parallel


  ! These are for backward compatability and should not be used or expanded upon
  integer(i4), public, parameter ::                       &
       iotype_pnetcdf = PIO_iotype_pnetcdf,                & !< pnetcdf iotype
       iotype_netcdf  = PIO_iotype_netcdf                    !< netcdf iotype


  integer(i4), public, parameter :: PIO_rearr_box =  1    !< box rearranger
  integer(i4), public, parameter :: PIO_rearr_subset =  2 !< subset rearranger

  integer(i4), public, parameter :: PIO_INTERNAL_ERROR = -51 !< abort on error from any task
  integer(i4), public, parameter :: PIO_BCAST_ERROR = -52    !< broadcast an error
  integer(i4), public, parameter :: PIO_RETURN_ERROR = -53   !< do nothing

  integer(i4), public, parameter :: PIO_DEFAULT = -1 !< default error handler

  !>
  !! @struct use_PIO_kinds
  !! The type of variable(s) associated with this iodesc.
  !! @copydoc PIO_kinds

#ifdef _PNETCDF
#include <pnetcdf.inc>
  integer, public, parameter :: PIO_64BIT_DATA = nf_64bit_data            !< CDF5 format
#else
#include <netcdf.inc>
  integer, public, parameter :: PIO_64BIT_DATA = 0            !< CDF5 format
#endif
  integer, public, parameter :: PIO_num_OST =  16 !< num ost
  integer, public, parameter :: PIO_global = nf_global       !< global atts
  integer, public, parameter :: PIO_unlimited = nf_unlimited !< unlimited dimension
  integer, public, parameter :: PIO_double = nf_double       !< double type
  integer, public, parameter :: PIO_real   = nf_real         !< real type
  integer, public, parameter :: PIO_int    = nf_int          !< int type
  integer, public, parameter :: PIO_short  = nf_short        !< short int type
  integer, public, parameter :: PIO_char   = nf_char         !< char type
  integer, public, parameter :: PIO_noerr  = nf_noerr        !< no error
  integer, public, parameter :: PIO_WRITE  = nf_write        !< read-write
  integer, public, parameter :: PIO_nowrite  = nf_nowrite    !< read-only
  integer, public, parameter :: PIO_CLOBBER = nf_clobber     !< clobber existing file
  integer, public, parameter :: PIO_NOCLOBBER = nf_NOclobber !< do not clobber existing file
  integer, public, parameter :: PIO_FILL = nf_fill           !< use fill values
  integer, public, parameter :: PIO_NOFILL = nf_nofill       !< do not use fill values
  integer, public, parameter :: PIO_MAX_NAME = nf_max_name   !< max name len
  integer, public, parameter :: PIO_MAX_VAR_DIMS = min(6,nf_max_var_dims) !< max dims for a var
  integer, public, parameter :: PIO_64BIT_OFFSET = nf_64bit_offset        !< 64bit offset format
  integer, public, parameter :: PIO_FILL_INT = nf_fill_int;               !< int fill value
  real, public, parameter :: PIO_FILL_FLOAT = nf_fill_float;              !< float fill value

  double precision, public, parameter :: PIO_FILL_DOUBLE = nf_fill_double; !< double fill value

  enum, bind(c)
     enumerator :: PIO_rearr_comm_p2p = 0 !< do point-to-point communications using mpi send and recv calls.
     enumerator :: PIO_rearr_comm_coll    !< use the MPI_ALLTOALLW function of the mpi library
  end enum

  !>
  !! @defgroup PIO_rearr_comm_t Rearranger Communication
  !! @public
  !! There are two choices for rearranger communication.
  !!  - PIO_rearr_comm_p2p : Point to point
  !!  - PIO_rearr_comm_coll : Collective
  !>
  !>
  !! @defgroup PIO_rearr_comm_dir PIO_rearr_comm_dir
  !! @public
  !! There are four choices for rearranger communication direction.
  !!  - PIO_rearr_comm_fc_2d_enable : COMM procs to IO procs and vice versa
  !!  - PIO_rearr_comm_fc_1d_comp2io: COMM procs to IO procs only
  !!  - PIO_rearr_comm_fc_1d_io2comp: IO procs to COMM procs only
  !!  - PIO_rearr_comm_fc_2d_disable: Disable flow control
  !!
  !! @defgroup PIO_rearr_comm_fc_options Rearranger Flow Control Options
  !! Type that defines the PIO rearranger options.
  !!  - enable_hs : Enable handshake (true/false)
  !!  - enable_isend : Enable Isends (true/false)
  !!  - max_pend_req : Maximum pending requests (To indicated unlimited
  !!                    number of requests use PIO_REARR_COMM_UNLIMITED_PEND_REQ)
  !!
  !! @defgroup PIO_rearr_options Rearranger Options
  !! Type that defines the PIO rearranger options.
  !!
  !!  - comm_type : @copydoc PIO_rearr_comm_t
  !!  - fcd : @copydoc PIO_rearr_comm_dir
  !!  - comm_fc_opts_comp2io : @copydoc PIO_rearr_comm_fc_options
  !!  - comm_fc_opts_io2comp : @copydoc PIO_rearr_comm_fc_options
  enum, bind(c)
     enumerator :: PIO_rearr_comm_fc_2d_enable = 0 !< COMM procs to IO procs and vice versa.
     enumerator :: PIO_rearr_comm_fc_1d_comp2io !< COMM procs to IO procs only.
     enumerator :: PIO_rearr_comm_fc_1d_io2comp !< IO procs to COMM procs only.
     enumerator :: PIO_rearr_comm_fc_2d_disable !< Disable flow control.
  end enum

  type, bind(c), public :: PIO_rearr_comm_fc_opt_t
     logical(c_bool) :: enable_hs            !< Enable handshake.
     logical(c_bool) :: enable_isend         !< Enable isends.
     integer(c_int) :: max_pend_req          !< Maximum pending requests (PIO_REARR_COMM_UNLIMITED_PEND_REQ for unlimited).
  end type PIO_rearr_comm_fc_opt_t

  integer, public, parameter :: PIO_REARR_COMM_UNLIMITED_PEND_REQ = -1 !< unlimited requests
  type, bind(c), public :: PIO_rearr_opt_t
     integer(c_int)                         :: comm_type !< Rearranger communication.
     integer(c_int)                         :: fcd       !< Communication direction.
     type(PIO_rearr_comm_fc_opt_t)   :: comm_fc_opts_comp2io !< The comp2io options.
     type(PIO_rearr_comm_fc_opt_t)   :: comm_fc_opts_io2comp !< The io2comp options.
  end type PIO_rearr_opt_t

  public :: PIO_rearr_comm_p2p, PIO_rearr_comm_coll,&
       PIO_rearr_comm_fc_2d_enable, PIO_rearr_comm_fc_1d_comp2io,&
       PIO_rearr_comm_fc_1d_io2comp, PIO_rearr_comm_fc_2d_disable

end module pio_types
