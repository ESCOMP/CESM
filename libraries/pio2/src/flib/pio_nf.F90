#include "config.h"
!>
!! @file
!! Code to implement the classic netCDF Fortran API in PIO.
!! @author Jim Edwards
!<

!> @defgroup PIO_inquire_dimension Learn About Dimension
!! Learn dimension name, ID, or length in Fortran.
!!
!! Use the generic functions to call the underlying Fortran functions.
!!
!! Generic Function  | Function(s)
!! ----------------  | -----------
!! pio_inq_dimlen()  | inq_dimlen_desc(), inq_dimlen_id(), inq_dimlen_desc_long(), inq_dimlen_id_long()
!! pio_inq_ndims()   | inq_ndims_id()
!! pio_inq_dimid()   | inq_dimid_desc(), inq_dimid_id()
!! pio_inq_dimname() | inq_dimname_desc(), inq_dimname_id()
!!
!! @defgroup PIO_inquire Learn About a File
!! Learn the number of variables, dimensions, global attributes, and
!! the unlimited dimension ID in Fortran.
!!
!! Use the generic functions to call the underlying Fortran functions.
!!
!! Generic Function  | Function(s)
!! ----------------  | -----------
!! pio_inquire()     | inquire_desc(), inquire_id()
!!
!! @defgroup PIO_enddef Define Mode
!! End or re-enter define mode in Fortran.
!!
!! Use the generic functions to call the underlying Fortran functions.
!!
!! Generic Function  | Function(s)
!! ----------------  | -----------
!! pio_enddef()      | enddef_desc(), enddef_id()
!! pio_redef()       | redef_desc(), redef_id()
!!
!! @defgroup PIO_set_log_level Debug Logging
!! Set debugging log level in Fortran.
!!
!! @defgroup PIO_strerror Error Messages
!! Get the error message from an error in Fortran.
!!
!! @defgroup PIO_def_dim Define a Dimension
!! Define a new dimension, with name and length in Fortran.
!!
!! Use the generic functions to call the underlying Fortran functions.
!!
!! Generic Function       | Function(s)
!! ----------------       | -----------
!! pio_def_dim() | def_dim_desc(), def_dim_id(), def_dim_int_desc(), def_dim_int_id()
!!
!! @defgroup PIO_inquire_variable Learn About a Variable
!! Learn variable name, ID, type, dimensions, compression, chunking in
!! Fortran.
!!
!! Use the generic functions to call the underlying Fortran functions.
!!
!! Generic Function       | Function(s)
!! ----------------       | -----------
!! pio_inquire_variable() | inquire_variable_desc(), inquire_variable_vid(), inquire_variable_id()
!! pio_inq_varid()        | inq_varid_desc(), inq_varid_vid(), inq_varid_id()
!! pio_inq_vartype()      | inq_varname_desc(), inq_varname_vid(), inq_varname_id()
!! pio_inq_varndims()     | inq_varndims_desc(), inq_varndims_vid(), inq_varndims_id()
!! pio_inq_vardimid()     | inq_vardimid_desc(), inq_vardimid_vid(), inq_vardimid_id()
!! pio_inq_varnatts()     | inq_varnatts_desc(), inq_varnatts_vid(), inq_varnatts_id()
!! pio_inq_var_deflate()  | inq_var_deflate_desc(), inq_var_deflate_vid(), inq_var_deflate_id()
!! pio_inq_var_chunking() | inq_var_chunking_desc(), inq_var_chunking_vid(), inq_var_chunking_id()
!!
!! @defgroup PIO_inq_att Learn About an Attribute
!! Learn attribute name, number, type, size in Fortran.
!!
!! Use the generic functions to call the underlying Fortran functions.
!!
!! Generic Function   | Function(s)
!! ----------------   | -----------
!! pio_inq_attname()  | inq_attname_desc(), inq_attname_vid(), inq_attname_id()
!! pio_inq_att()      | inq_att_desc(), inq_att_vid(), inq_att_id()
!! pio_inq_attlen()   | inq_attlen_desc(), inq_attlen_vid(), inq_attlen_id()
!!
!! @defgroup PIO_def_var Define a Variable
!! Define a new variable in Fortran.
!!
!! Use the generic functions to call the underlying Fortran functions.
!!
!! Generic Function       | Function(s)
!! ----------------       | -----------
!! pio_def_var()          | def_var_0d_desc(), def_var_md_desc(), def_var_0d_id(), def_var_md_id()
!! pio_def_var_deflate()  | def_var_deflate_desc(), def_var_deflate_id()
!! pio_def_var_chunking() | def_var_chunking_desc()
!<

module pio_nf
#ifdef TIMING
  use perf_mod           , only : t_startf, t_stopf      ! _EXTERNAL
#endif
  use pio_kinds           , only :  pio_offset_kind
  use pio_types           , only : file_desc_t, var_desc_t, PIO_MAX_VAR_DIMS
  use iso_c_binding
  use pio_support        , only : replace_c_null
  implicit none
  private

  public :: &
       pio_def_var                                          , &
       pio_def_var_deflate                                  , &
       pio_def_var_chunking                                 , &
       pio_def_dim                                          , &
       pio_inq_attname                                      , &
       pio_inq_att                                          , &
       pio_inq_attlen                                       , &
       pio_inq_varid                                        , &
       pio_inq_varname                                      , &
       pio_inq_vartype                                      , &
       pio_inq_varndims                                     , &
       pio_inq_vardimid                                     , &
       pio_inq_varnatts                                     , &
       pio_inq_var_deflate                                  , &
       pio_inq_var_chunking                                 , &
       pio_inquire_variable                                 , &
       pio_inquire_dimension                                , &
       pio_inq_dimname                                      , &
       pio_inq_dimlen                                       , &
       pio_inq_dimid                                        , &
       pio_inq_unlimdim                                     , &
       pio_inquire                                          , &
       pio_enddef                                           , &
       pio_set_chunk_cache                                  , &
       pio_get_chunk_cache                                  , &
       pio_set_var_chunk_cache                              , &
       pio_get_var_chunk_cache                              , &
       pio_redef                                            , &
       pio_set_log_level                                    , &
       pio_strerror                                         , &
       pio_set_fill
  !       pio_copy_att    to be done

  interface pio_def_var
     module procedure &
          def_var_0d_desc                                   , &
          def_var_md_desc                                   , &
          def_var_0d_id                                     , &
          def_var_md_id
  end interface pio_def_var
  interface pio_def_var_deflate
     module procedure &
          def_var_deflate_desc                              , &
          def_var_deflate_id
  end interface pio_def_var_deflate
  interface pio_def_var_chunking
     module procedure &
          def_var_chunking_desc
  end interface pio_def_var_chunking
  interface pio_inq_attname
     module procedure &
          inq_attname_desc                                  , &
          inq_attname_vid                                   ,    &
          inq_attname_id
  end interface pio_inq_attname
  interface pio_inq_att
     module procedure &
          inq_att_desc                                      , &
          inq_att_vid                                       ,    &
          inq_att_id
  end interface pio_inq_att
  interface pio_inq_attlen
     module procedure &
          inq_attlen_desc                                   , &
          inq_attlen_vid                                    ,    &
          inq_attlen_id
  end interface pio_inq_attlen
  interface pio_inq_varid
     module procedure &
          inq_varid_desc                                    , &
          inq_varid_vid                                     ,    &
          inq_varid_id
  end interface pio_inq_varid

  interface pio_inq_varname
     module procedure &
          inq_varname_desc                                  , &
          inq_varname_vid                                   ,    &
          inq_varname_id
  end interface pio_inq_varname

  interface pio_inq_vartype
     module procedure &
          inq_vartype_desc                                  , &
          inq_vartype_vid                                   ,    &
          inq_vartype_id
  end interface pio_inq_vartype
  interface pio_inq_varndims
     module procedure &
          inq_varndims_desc                                 , &
          inq_varndims_vid                                  ,    &
          inq_varndims_id
  end interface pio_inq_varndims
  interface pio_inq_vardimid
     module procedure &
          inq_vardimid_desc                                 , &
          inq_vardimid_vid                                  ,    &
          inq_vardimid_id
  end interface pio_inq_vardimid
  interface pio_inq_varnatts
     module procedure &
          inq_varnatts_desc                                 , &
          inq_varnatts_vid                                  ,    &
          inq_varnatts_id
  end interface pio_inq_varnatts
  interface pio_inq_var_deflate
     module procedure &
          inq_var_deflate_desc                                 , &
          inq_var_deflate_vid                                  , &
          inq_var_deflate_id
  end interface pio_inq_var_deflate
  interface pio_inq_var_chunking
     module procedure &
          inq_var_chunking_desc                                 , &
          inq_var_chunking_vid                                  , &
          inq_var_chunking_id
  end interface pio_inq_var_chunking
  interface pio_inquire_dimension
     module procedure &
          inquire_dimension_desc                            , &
          inquire_dimension_id
  end interface pio_inquire_dimension

  interface pio_inquire_variable
     module procedure &
          inquire_variable_desc                             , &
          inquire_variable_vid                              , &
          inquire_variable_id
  end interface pio_inquire_variable

  interface pio_def_dim
     module procedure &
          def_dim_desc                                      , &
          def_dim_id                                        , &
          def_dim_int_desc                                  , &
          def_dim_int_id
  end interface pio_def_dim
  interface pio_inq_dimlen
     module procedure &
          inq_dimlen_desc                                   , &
          inq_dimlen_id                                     , &
          inq_dimlen_desc_long                              , &
          inq_dimlen_id_long
  end interface pio_inq_dimlen
  interface pio_inq_ndims
     module procedure &
          inq_ndims_id
!          inq_ndims_desc                                    , &
  end interface pio_inq_ndims
  interface pio_inq_dimid
     module procedure &
          inq_dimid_desc                                    , &
          inq_dimid_id
  end interface pio_inq_dimid
  interface pio_inq_dimname
     module procedure &
          inq_dimname_desc                                  , &
          inq_dimname_id
  end interface pio_inq_dimname

  interface PIO_set_fill
     module procedure &
          set_fill_id ,&
          set_fill_desc
  end interface PIO_set_fill


  interface pio_inq_nvars
     module procedure &
          inq_nvars_id
!          inq_nvars_desc
  end interface pio_inq_nvars
  interface pio_inq_natts
     module procedure &
          inq_natts_id
!          inq_natts_desc
  end interface pio_inq_natts
  interface pio_inq_unlimdim
     module procedure &
          inq_unlimdim_desc                                 , &
          inq_unlimdim_id
  end interface pio_inq_unlimdim

  interface pio_enddef
     module procedure &
          enddef_desc                                       , &
          enddef_id
  end interface pio_enddef

  interface pio_redef
     module procedure &
          redef_desc                                        , &
          redef_id
  end interface pio_redef

  interface pio_set_log_level
     module procedure &
          set_log_level
  end interface pio_set_log_level

  interface pio_strerror
     module procedure &
          strerror
  end interface pio_strerror

  interface pio_inquire
     module procedure &
          inquire_desc                                      , &
          inquire_id
  end interface pio_inquire

  interface pio_set_chunk_cache
     module procedure &
          set_chunk_cache
  end interface pio_set_chunk_cache

  interface pio_get_chunk_cache
     module procedure &
          get_chunk_cache
  end interface pio_get_chunk_cache

  interface pio_set_var_chunk_cache
     module procedure &
          set_var_chunk_cache_desc                          , &
          set_var_chunk_cache_id
  end interface pio_set_var_chunk_cache

  interface pio_get_var_chunk_cache
     module procedure &
          get_var_chunk_cache_desc                          , &
          get_var_chunk_cache_id
  end interface pio_get_var_chunk_cache

contains

  !>
  !! @public
  !! @ingroup PIO_inquire_dimension
  !! Returns the netcdf dimension id for the name.
  !!
  !! @note We do not want internal error checking for this function.
  !!
  !! @param File @copydoc file_desc_t
  !! @param name The name of the netcdf dimension.
  !! @param dimid The netcdf dimension id.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inq_dimid_desc(File                      ,name,dimid) result(ierr)
    type (File_desc_t)                                      , intent(in) :: File
    character(len=*)                                        , intent(in)   :: name
    integer                                                 , intent(out)           :: dimid        !dimension ID
    ierr = inq_dimid_id(file%fh                             ,name,dimid)
  end function inq_dimid_desc

  !>
  !! @public
  !! @ingroup PIO_set_fill
  !! Set the netcdf fill mode
  !!
  !! @param ncid A netcdf file ID returned by \ref
  !! PIO_openfile or \ref PIO_createfile.
  !! @param fillmode Desired fill mode for the dataset, either PIO_NOFILL or PIO_FILL.
  !! @param old_mode Returned current fill mode of the dataset before this call, either PIO_NOFILL or PIO_FILL.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function set_fill_id(ncid                         ,fillmode, old_mode) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 , intent(in) :: fillmode
    integer                                                 , intent(out) :: old_mode
    interface
       integer(C_INT) function PIOc_set_fill(ncid           ,fillmode, old_mode) &
            bind(C                                          ,name="PIOc_set_fill")
         use iso_c_binding
         integer(c_int), value     :: ncid
         integer(c_int), value     :: fillmode
         integer(c_int)            :: old_mode
       end function PIOc_set_fill
    end interface

    ierr = PIOc_set_fill(ncid, fillmode, old_mode)

  end function set_fill_id

  !>
  !! @public
  !! @ingroup PIO_set_fill
  !! Set the netcdf fill mode
  !!
  !! @param File @copydoc file_desc_t
  !! @param fillmode Desired fill mode for the dataset, either PIO_NOFILL or PIO_FILL.
  !! @param old_mode Returned current fill mode of the dataset before this call, either PIO_NOFILL or PIO_FILL.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function set_fill_desc(File, fillmode, old_mode) result(ierr)
    type(File_desc_t)                                       ,intent(in) :: File
    integer                                                 ,intent(in) :: fillmode
    integer                                                 ,intent(out):: old_mode
    ierr = set_fill_id(file%fh                              ,fillmode, old_mode)
  end function set_fill_desc


  !>
  !! @public
  !! @ingroup PIO_inquire_dimension
  !! Returns the netcdf dimension id for the name.
  !! @author Jim Edwards
  !<
  integer function inq_dimid_id(ncid                        ,name,dimid) result(ierr)
    integer                                                 , intent(in) :: ncid
    character(len=*)                                        , intent(in)   :: name
    integer                                                 , intent(out)           :: dimid        !dimension ID
    interface
       integer(C_INT) function PIOc_inq_dimid(ncid          ,name,dimid) &
            bind(C                                          ,name="PIOc_inq_dimid")
         use iso_c_binding
         integer(c_int)                                     , value :: ncid
         character(c_char) :: name
         integer(c_int) :: dimid
       end function PIOc_inq_dimid
    end interface
    ierr = PIOc_inq_dimid(ncid                              ,trim(name)//C_NULL_CHAR,dimid)
    dimid=dimid+1
  end function inq_dimid_id

  !>
  !! @public
  !! @ingroup PIO_inquire_dimension
  !! Get information about a particular dimension in netcdf file.
  !!
  !! @param file A netcdf file descriptor returned by \ref
  !! PIO_openfile or \ref PIO_createfile.
  !! @param dimid The netcdf dimension ID.
  !! @param name The name of the dimension.
  !! @param len The length of the dimesions name.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inquire_dimension_desc(file              , dimid, name, len) result(ierr)
    type(file_desc_T)                                       ,             intent(in)  :: file
    integer                                                 ,                       intent( in) :: dimid
    character (len = *)                                     , optional, intent(out) :: name
    integer                                                 ,             optional, intent(out) :: len
    ierr = Inquire_dimension_id(file%fh                     , dimid, name, len)
  end function inquire_dimension_desc

  !>
  !! @public
  !! @ingroup PIO_inquire_dimension
  !! Get information about a particular dimension in netcdf file.
  !!
  !! @param ncid A netcdf file ID returned by \ref
  !! PIO_openfile or \ref PIO_createfile.
  !! @param dimid The netcdf dimension ID.
  !! @param name The name of the dimension.
  !! @param len The length of the dimesions name.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inquire_dimension_id(ncid                , dimid, name, len) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 ,                       intent( in) :: dimid
    character (len = *)                                     , optional, intent(out) :: name
    integer                                                 ,             optional, intent(out) :: len
    integer(PIO_OFFSET_KIND) :: llen
    if(present(name)) ierr = inq_dimname_id(ncid            , dimid, name)
    if(present(len)) then
       ierr = inq_dimlen_id_long(ncid                       , dimid, llen)
       len = int(llen)
    endif

  end function inquire_dimension_id

  !>
  !! @public
  !! @ingroup PIO_inquire_dimension
  !! Get information about the length of a particular dimension in
  !! netcdf file.
  !!
  !! @param File @copydoc file_desc_t
  !! @param dimid The netcdf dimension ID.
  !! @param len The length of the dimesion.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inq_dimlen_desc(File                     , dimid, len) result(ierr)
    type(file_desc_t)                                       , intent(in) :: File
    integer                                                 , intent(in) :: dimid
    integer                                                 , intent(out) :: len
    ierr = inq_dimlen_id(file%fh                            ,dimid,len)
  end function inq_dimlen_desc

  !>
  !! @public
  !! @ingroup PIO_inquire_dimension
  !! Get information about the length of a particular dimension in
  !! netcdf file.
  !! @author Jim Edwards
  !<
  integer function inq_dimlen_desc_long(File                , dimid, len) result(ierr)
    type(file_desc_t)                                       , intent(in) :: File
    integer                                                 , intent(in) :: dimid
    integer(PIO_OFFSET_KIND)                                , intent(out) :: len
    ierr = inq_dimlen_id_long(file%fh                       ,dimid,len)
  end function inq_dimlen_desc_long

  !>
  !! @public
  !! @ingroup PIO_inquire_dimension
  !! Get information about the length of a particular dimension in
  !! netcdf file.
  !! @author Jim Edwards
  !<
  integer function inq_dimlen_id(ncid                       , dimid, len) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 , intent(in) :: dimid
    integer                                                 , intent(out) :: len
    integer(PIO_OFFSET_KIND) :: llen
    ierr = inq_dimlen_id_long(ncid                          ,dimid,llen)
    len = int(llen)
  end function inq_dimlen_id

  !>
  !! @public
  !! @ingroup PIO_inquire_dimension
  !! Get information about the length of a particular dimension in
  !! netcdf file.
  !! @author Jim Edwards
  !<
  integer function inq_dimlen_id_long(ncid                  , dimid, len) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 , intent(in) :: dimid
    integer(PIO_OFFSET_KIND)                                , intent(out) :: len
    interface
       integer(C_INT) function PIOc_inq_dimlen(ncid         ,dimid,len) &
            bind(C                                          ,name="PIOc_inq_dimlen")
         use iso_c_binding
         integer(C_INT)                                     , value :: ncid
         integer(c_int)                                     , value :: dimid
         integer(c_size_t) :: len
       end function PIOc_inq_dimlen
    end interface

    ierr = PIOc_inq_dimlen(ncid                             ,dimid-1,len)
  end function inq_dimlen_id_long

  !>
  !! @public
  !! @ingroup PIO_inquire_dimension
  !! Get information about the name of of a dimension.
  !!
  !! @param File @copydoc file_desc_t
  !! @param dimid The netcdf dimension ID.
  !! @param name The name of the dimesion.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inq_dimname_desc(File                    , dimid, name) result(ierr)
    type(file_desc_t)                                       , intent(in) :: File
    integer                                                 , intent(in) :: dimid
    character(len=*)                                        , intent(out) :: name
    ierr = inq_dimname_id(file%fh                           ,dimid,name)
  end function inq_dimname_desc

  !>
  !! @public
  !! @ingroup PIO_inquire_dimension
  !! Get information about the name of of a dimension.
  !! @author Jim Edwards
  !<
  integer function inq_dimname_id(ncid                      , dimid, name) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 , intent(in) :: dimid
    character(len=*)                                        , intent(out) :: name
    interface
       integer(C_INT) function PIOc_inq_dimname(ncid        ,dimid,name) &
            bind(C                                          ,name="PIOc_inq_dimname")
         use iso_c_binding
         integer(C_INT)                                     , value :: ncid
         integer(c_int)                                     , value :: dimid
         character(c_char) :: name(*)
       end function PIOc_inq_dimname
    end interface

    name = C_NULL_CHAR
    ierr = PIOc_inq_dimname(ncid                            ,dimid-1,name)
    call replace_c_null(name)

  end function inq_dimname_id

  !! @public
  !! @ingroup PIO_inquire
  !! Get information about the number of dimensions of a file or
  !! group.
  !!
  !! @param File @copydoc file_desc_t
  !! @param ndims The number of dimensions in the file.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  ! integer function inq_ndims_desc(File, ndims) result(ierr)
  !   type (File_desc_t), intent(inout) :: File
  !   integer, intent(out) :: ndims
  !   ierr = inq_ndims_id(file%fh, ndims)
  ! end function inq_ndims_desc

  !>
  !! @public
  !! @ingroup PIO_inquire
  !! Get information about the number of dimensions of a file or
  !! group.
  !! @author Jim Edwards
  !<
  integer function inq_ndims_id(ncid                        , ndims) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 , intent(out) :: ndims
    interface
       integer(C_INT) function PIOc_inq_ndims(ncid          ,ndims) &
            bind(C                                          ,name="PIOc_inq_ndims")
         use iso_c_binding
         integer(c_INT)                                     , value :: ncid
         integer(C_INT) :: ndims
       end function PIOc_inq_ndims
    end interface
    ierr = PIOc_inq_ndims(ncid                              ,ndims)
  end function inq_ndims_id

  !! @public
  !! @ingroup PIO_inquire
  !! Get information about the number of variables in a file or group.
  !!
  !! @param File @copydoc file_desc_t
  !! @param nvars The number of variables in the file.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  ! integer function inq_nvars_desc(File, nvars) result(ierr)
  !   type (File_desc_t), intent(inout) :: File
  !   integer, intent(out) :: nvars
  !   ierr = inq_nvars_id(file%fh, nvars)
  ! end function inq_nvars_desc

  !>
  !! @public
  !! @ingroup PIO_inquire
  !! Get information about the number of variables in a file or group.
  !! @author Jim Edwards
  !<
  integer function inq_nvars_id(ncid                        , nvars) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 , intent(out) :: nvars
    interface
       integer(C_INT) function PIOc_inq_nvars(ncid          ,nvars) &
            bind(C                                          ,name="PIOc_inq_nvars")
         use iso_c_binding
         integer(c_INT)                                     , value :: ncid
         integer(C_INT) :: nvars
       end function PIOc_inq_nvars
    end interface
    ierr = PIOc_inq_nvars(ncid                              ,nvars)
  end function inq_nvars_id

  !! @public
  !! @ingroup PIO_inquire
  !! Get information about the number of global attributes in a file
  !! or group.
  !!
  !! @param File @copydoc file_desc_t
  !! @param natts The number of attributes in the file.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  ! integer function inq_natts_desc(File, natts) result(ierr)
  !   type (File_desc_t), intent(inout) :: File
  !   integer, intent(out) :: natts
  !   ierr = inq_natts_id(file%fh, natts)
  ! end function inq_natts_desc

  !>
  !! @public
  !! @ingroup PIO_inquire
  !! Get information about the number of global attributes in a file
  !! or group.
  !! @author Jim Edwards
  !<
  integer function inq_natts_id(ncid                        , natts) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 , intent(out) :: natts
    interface
       integer(C_INT) function PIOc_inq_natts(ncid          ,natts) &
            bind(C                                          ,name="PIOc_inq_natts")
         use iso_c_binding
         integer(c_INT)                                     , value :: ncid
         integer(C_INT) :: natts
       end function PIOc_inq_natts
    end interface
    ierr = PIOc_inq_natts(ncid                              ,natts)
  end function inq_natts_id

  !>
  !! @public
  !! @ingroup PIO_inquire
  !! Get information about the unlimited dimension in a file.
  !!
  !! @param File @copydoc file_desc_t
  !! @param unlimdim Pointer to the unlimted dimension. If no
  !! unlimited dimension, this will be -1.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inq_unlimdim_desc(File                   , unlimdim) result(ierr)
    type (File_desc_t)                                      , intent(inout) :: File
    integer                                                 , intent(out) :: unlimdim
    ierr = inq_unlimdim_id(file%fh                          , unlimdim)
  end function inq_unlimdim_desc

  !>
  !! @public
  !! @ingroup PIO_inquire
  !! Get information about the unlimited dimension in a file.
  !! @author Jim Edwards
  !<
  integer function inq_unlimdim_id(ncid                     ,unlimdim) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 , intent(out) :: unlimdim
    interface
       integer(C_INT) function PIOc_inq_unlimdim(ncid       ,unlimdim) &
            bind(C                                          ,name="PIOc_inq_unlimdim")
         use iso_c_binding
         integer(c_INT)                                     , value :: ncid
         integer(C_INT) :: unlimdim
       end function PIOc_inq_unlimdim
    end interface
    ierr = PIOc_inq_unlimdim(ncid                           ,unlimdim)
    if(unlimdim>=0) unlimdim=unlimdim+1
  end function inq_unlimdim_id

  !>
  !! @public
  !! @ingroup PIO_inquire
  !! Gets metadata information for netcdf file.
  !!
  !! @param File @copydoc file_desc_t
  !! @param nDimensions Number of dimensions defined for the netcdf
  !! file
  !! @param nVariables Number of variables defined for the netcdf file
  !! @param nAttributes Number of attributes defined for the netcdf
  !! file
  !! @param unlimitedDimID the Unlimited dimension ID
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inquire_desc(File                        ,nDimensions,nVariables,nAttributes,unlimitedDimID) result(ierr)
    type (File_desc_t)                                      , intent(in) :: File

    integer                                                 , optional, intent(out) :: &
         nDimensions                                        ,  &! number of dimensions
         nVariables                                         ,   &! number of variables
         nAttributes                                        ,  & ! number of global attributes
         unlimitedDimID ! ID of unlimited dimension

    ierr = inquire_id(file%fh                               ,ndimensions,nvariables,nattributes,unlimitedDimID)
  end function inquire_desc

  !>
  !! @public
  !! @ingroup PIO_inquire
  !! Gets metadata information for netcdf file.
  !! @author Jim Edwards
  !<
  integer function inquire_id(ncid                          ,nDimensions,nVariables,nAttributes,unlimitedDimID) result(ierr)
    integer                                                 ,intent(in) :: ncid
    integer                                                 , optional, intent(out) :: &
         nDimensions                                        ,  &! number of dimensions
         nVariables                                         ,   &! number of variables
         nAttributes                                        ,  & ! number of global attributes
         unlimitedDimID ! ID of unlimited dimension

    if(present(nDimensions)) ierr = inq_ndims_id(ncid       ,ndimensions)
    if(present(nvariables)) ierr = inq_nvars_id(ncid        ,nvariables)
    if(present(nattributes)) ierr = inq_natts_id(ncid       ,nattributes)
    if(present(unlimitedDimID)) ierr = inq_unlimdim_id(ncid ,unlimitedDimID)
  end function inquire_id

  !>
  !! @public
  !! @ingroup PIO_enddef
  !! Exits netcdf define mode.
  !!
  !! @param File @copydoc file_desc_t
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function enddef_desc(File) result(ierr)
    type (File_desc_t)                                      , intent(inout) :: File
    ierr = enddef_id(file%fh)
  end function enddef_desc

  !>
  !! @public
  !! @ingroup PIO_enddef
  !! Wrapper for the C function \ref PIOc_enddef .
  !! @author Jim Edwards
  !<
  integer function enddef_id(ncid) result(ierr)
    integer                                                 ,intent(in) :: ncid
    interface
       integer(C_INT) function PIOc_enddef(ncid) &
            bind(C                                          ,name="PIOc_enddef")
         use iso_c_binding
         integer(C_INT)                                     , value :: ncid
       end function PIOc_enddef
    end interface
    ierr = PIOc_enddef(ncid)
  end function enddef_id

  !>
  !! @public
  !! @ingroup PIO_enddef
  !! Exits netcdf define mode.
  !!
  !! @param File @copydoc file_desc_t
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function redef_desc(File) result(ierr)
    type (File_desc_t)                                      , intent(inout) :: File
    ierr = redef_id(file%fh)
  end function redef_desc

  !>
  !! @public
  !! @ingroup PIO_set_log_level
  !! Sets the logging level. Only takes effect if PIO was built with
  !! PIO_ENABLE_LOGGING=On
  !!
  !! @param log_level the logging level.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function set_log_level(log_level) result(ierr)
    integer, intent(in) :: log_level
    interface
       integer(C_INT) function PIOc_set_log_level(log_level) &
            bind(C, name="PIOc_set_log_level")
         use iso_c_binding
         integer(C_INT), value :: log_level
       end function PIOc_set_log_level
    end interface
    ierr = PIOc_set_log_level(log_level)
  end function set_log_level

  !>
  !! @public
  !! @ingroup PIO_strerror
  !! Returns a descriptive string for an error code.
  !!
  !! @param errcode the error code.
  !! @param errmsg the error message.
  !! @retval 0 for success, error code otherwise.
  !! @author Jim Edwards
  !<
  integer function strerror(errcode, errmsg) result(ierr)
    integer, intent(in) :: errcode
    character(len=*), intent(out) :: errmsg
    interface
       integer(C_INT) function PIOc_strerror(errcode, errmsg) &
            bind(C, name="PIOc_strerror")
         use iso_c_binding
         integer(C_INT), value :: errcode
         character(C_CHAR) :: errmsg(*)
       end function PIOc_strerror
    end interface
    errmsg = C_NULL_CHAR
    ierr = PIOc_strerror(errcode, errmsg)
    call replace_c_null(errmsg)

  end function strerror

  !>
  !! @public
  !! @ingroup PIO_enddef
  !! Wrapper for the C function \ref PIOc_redef .
  !! @author Jim Edwards
  !<
  integer function redef_id(ncid) result(ierr)
    integer, intent(in) :: ncid
    interface
       integer(C_INT) function PIOc_redef(ncid) &
            bind(C, name="PIOc_redef")
         use iso_c_binding
         integer(C_INT), value :: ncid
       end function PIOc_redef
    end interface
    ierr = PIOc_redef(ncid)
  end function redef_id

  !>
  !! @ingroup PIO_def_dim
  !! Defines the netcdf dimension.
  !!
  !! @param File @copydoc file_desc_t
  !! @param name The name of the dimension to define
  !! @param len  The size of the dimension
  !! @param dimid The dimension identifier
  !! @author Jim Edwards
  !<
  integer function def_dim_int_desc(File                    ,name,len,dimid) result(ierr)

    type (File_desc_t)                                      , intent(in)  :: File
    character(len=*)                                        , intent(in)    :: name
    integer                                                 , intent(in)         :: len
    integer                                                 , intent(out)        :: dimid

    ierr = def_dim_id(file%fh                               ,name,int(len,pio_offset_kind),dimid)
  end function def_dim_int_desc

  !>
  !! @ingroup PIO_def_dim
  !! Defines the netcdf dimension.
  !! @author Jim Edwards
  !<
  integer function def_dim_int_id(ncid                      ,name,len,dimid) result(ierr)
    integer                                                 , intent(in) :: ncid
    character(len=*)                                        , intent(in)    :: name
    integer                                                 , intent(in)         :: len
    integer                                                 , intent(out)        :: dimid

    ierr = def_dim_id(ncid                                  ,name,int(len,pio_offset_kind),dimid)
  end function def_dim_int_id

  !>
  !! @ingroup PIO_def_dim
  !! Defines the netcdf dimension.
  !! @author Jim Edwards
  !<
  integer function def_dim_desc(File                        ,name,len,dimid) result(ierr)

    type (File_desc_t)                                      , intent(in)  :: File
    character(len=*)                                        , intent(in)    :: name
    integer(PIO_OFFSET_KIND)                                , intent(in)         :: len
    integer                                                 , intent(out)        :: dimid

    ierr = def_dim_id(file%fh                               ,name,len,dimid)
  end function def_dim_desc

  !>
  !! @ingroup PIO_def_dim
  !! Defines the netcdf dimension.
  !! @author Jim Edwards
  !<
  integer function def_dim_id(ncid                          ,name,len,dimid) result(ierr)
    integer                                                 , intent(in)         :: ncid
    character(len=*)                                        , intent(in)    :: name
    integer(PIO_OFFSET_KIND)                                , intent(in)         :: len
    integer                                                 , intent(out)        :: dimid

    interface
       integer(C_INT) function PIOc_def_dim(ncid            ,name,len,dimid) &
            bind(C                                          ,name="PIOc_def_dim")
         use iso_c_binding
         integer(C_INT)                                     , value :: ncid
         character(C_CHAR) :: name
         integer(C_SIZE_T)                                    , value :: len
         integer(C_INT) :: dimid
       end function PIOc_def_dim
    end interface
    ierr = PIOc_def_dim(ncid                                ,trim(name)//C_NULL_CHAR,len,dimid)
    dimid=dimid+1
  end function def_dim_id

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Inquires if a NetCDF variable is present and returns its
  !! attributes.
  !!
  !! @param file A netcdf file descriptor returned by \ref
  !! PIO_openfile or \ref PIO_createfile.
  !! @param vardesc @copydoc var_desc_t
  !! @param name The name of the variable
  !! @param xtype The type of the variable
  !! @param ndims The number of dimensions for the variable.
  !! @param dimids The dimension identifier returned by \ref
  !! PIO_def_dim
  !! @param natts Number of attributes associated with the variable
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inquire_variable_desc(file               , vardesc, name, xtype, ndims, dimids, natts) result(ierr)
    type(file_desc_t)                                       ,               intent(in) :: file
    type(var_desc_t)                                        ,                intent( in) :: vardesc
    character (len = *)                                     ,   optional, intent(out) :: name
    integer                                                 ,               optional, intent(out) :: xtype, ndims
    integer                                                 , dimension(:), optional, intent(out) :: dimids
    integer                                                 ,               optional, intent(out) :: natts

    ierr = pio_inquire_variable(file%fh                     ,vardesc%varid,name,xtype,ndims,dimids,natts)
  end function inquire_variable_desc

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Inquires if a NetCDF variable is present and returns its
  !! attributes.
  !! @author Jim Edwards
  !<
  integer function inquire_variable_vid(file                , varid, name, xtype, ndims, dimids, natts) result(ierr)
    type(file_desc_t)                                       ,               intent(in) :: file
    integer                                                 ,                intent( in) :: varid
    character (len = *)                                     ,   optional, intent(out) :: name
    integer                                                 ,               optional, intent(out) :: xtype, ndims
    integer                                                 , dimension(:), optional, intent(out) :: dimids
    integer                                                 ,               optional, intent(out) :: natts

    ierr = pio_inquire_variable(file%fh                     ,varid,name,xtype,ndims,dimids,natts)
  end function inquire_variable_vid

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Inquires if a NetCDF variable is present and returns its
  !! attributes.
  !! @author Jim Edwards
  !<
  integer function inquire_variable_id(ncid                 , varid, name, xtype, ndims, dimids, natts) result(ierr)
    integer                                                 ,                intent( in) :: ncid
    integer                                                 ,                intent( in) :: varid
    character (len = *)                                     ,   optional, intent(out) :: name
    integer                                                 ,               optional, intent(out) :: xtype, ndims
    integer                                                 , dimension(:), optional, intent(out) :: dimids
    integer                                                 ,               optional, intent(out) :: natts

    if(present(name)) ierr = pio_inq_varname(ncid           , varid, name)
    if(present(ndims)) ierr = pio_inq_varndims(ncid         , varid, ndims)
    if(present(dimids)) ierr = pio_inq_vardimid(ncid        , varid, dimids)
    if(present(natts)) ierr = pio_inq_varnatts(ncid         , varid, natts)
    if(present(xtype)) ierr = pio_inq_vartype(ncid          , varid, xtype)
  end function inquire_variable_id

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Returns the dimids of the variable as an interger array.
  !!
  !! @param File @copydoc file_desc_t
  !! @param vardesc @copydoc var_desc_t
  !! @param dimids The dimension identifier returned by \ref
  !! PIO_def_dim
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inq_vardimid_desc(File                   ,vardesc,dimids) result(ierr)

    type (File_desc_t)                                      , intent(in)   :: File
    type (Var_desc_t)                                       , intent(in) :: vardesc
    integer                                                 , intent(out)    :: dimids(:)


    ierr = pio_inq_vardimid(File%fh                         , vardesc%varid, dimids)
  end function inq_vardimid_desc

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Returns the dimids of the variable as an interger array.
  !! @author Jim Edwards
  !<
  integer function inq_vardimid_vid(File                    ,varid,dimids) result(ierr)

    type (File_desc_t)                                      , intent(in)   :: File
    integer                                                 , intent(in) :: varid
    integer                                                 , intent(out)    :: dimids(:)


    ierr = pio_inq_vardimid(File%fh                         , varid, dimids)
  end function inq_vardimid_vid

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Returns the dimids of the variable as an interger array.
  !! @author Jim Edwards
  !<
  integer function inq_vardimid_id(ncid                     ,varid,dimids) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 , intent(in) :: varid
    integer                                                 , intent(out) :: dimids(:)
    integer                                                 , allocatable :: cdimids(:)
    interface
       integer(C_INT) function PIOc_inq_vardimid(ncid       ,varid,dimids) &
            bind(C                                          ,name="PIOc_inq_vardimid")
         use iso_c_binding
         integer(C_INT)                                     , value :: ncid
         integer(C_INT)                                     , value :: varid
         integer(C_INT) :: dimids(*)
       end function PIOc_inq_vardimid
    end interface
    integer :: i                                            , ndims

    ierr = inq_varndims_id(ncid                             ,varid,ndims)
    allocate(cdimids(ndims))

    ierr = PIOc_inq_vardimid(ncid                           ,varid-1,cdimids)
    do i=1                                                  ,ndims
       dimids(i) =  cdimids(ndims-i+1)+1
    end do
    deallocate(cdimids)

  end function inq_vardimid_id

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets the number of dimension associated with a netcdf variable.
  !!
  !! @param File @copydoc file_desc_t
  !! @param vardesc @copydoc var_desc_t
  !! @param ndims The number of dimensions for the variable
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inq_varndims_desc(File                   ,vardesc,ndims) result(ierr)

    type (File_desc_t)                                      , intent(in)   :: File
    type (Var_desc_t)                                       , intent(in) :: vardesc
    integer                                                 , intent(out)    :: ndims

    ierr = pio_inq_varndims(File%fh                         , vardesc%varid, ndims)
  end function inq_varndims_desc

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets the number of dimension associated with a netcdf variable.
  !! @author Jim Edwards
  !<
  integer function inq_varndims_vid(File                    ,varid,ndims) result(ierr)

    type (File_desc_t)                                      , intent(in)   :: File
    integer                                                 , intent(in) :: varid
    integer                                                 , intent(out)    :: ndims

    ierr = pio_inq_varndims(File%fh                         , varid, ndims)
  end function inq_varndims_vid

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets the number of dimension associated with a netcdf variable.
  !! @author Jim Edwards
  !<
  integer function inq_varndims_id(ncid                     ,varid,ndims) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 , intent(in) :: varid
    integer                                                 , intent(out)    :: ndims
    interface
       integer(C_INT) function PIOc_inq_varndims(ncid       ,varid,ndims) &
            bind(C                                          ,name="PIOc_inq_varndims")
         use iso_c_binding
         integer(C_INT)                                     , value :: ncid
         integer(C_INT)                                     , value :: varid
         integer(C_INT) :: ndims
       end function PIOc_inq_varndims
    end interface
    ierr = PIOc_inq_varndims(ncid                           ,varid-1,ndims)
  end function inq_varndims_id

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets metadata information for netcdf file.
  !!
  !! @param File @copydoc file_desc_t
  !! @param vardesc @copydoc var_desc_t
  !! @param type The type of variable
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inq_vartype_desc(File                    ,vardesc,type) result(ierr)

    type (File_desc_t)                                      , intent(in)   :: File
    type (Var_desc_t)                                       , intent(in) :: vardesc
    integer                                                 , intent(out)    :: type

    ierr = pio_inq_vartype(File%fh                          , vardesc%varid, type)
  end function inq_vartype_desc

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets metadata information for netcdf file.
  !! @author Jim Edwards
  !<
  integer function inq_vartype_vid(File                     ,varid,type) result(ierr)

    type (File_desc_t)                                      , intent(in)   :: File
    integer                                                 , intent(in) :: varid
    integer                                                 , intent(out)    :: type

    ierr = pio_inq_vartype(File%fh                          , varid, type)
  end function inq_vartype_vid

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets metadata information for netcdf file.
  !! @author Jim Edwards
  !<
  integer function inq_vartype_id(ncid                      ,varid,type) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 , intent(in) :: varid
    integer                                                 , intent(out)    :: type

    interface
       integer(C_INT) function PIOc_inq_vartype(ncid        ,varid,xtype) &
            bind(C                                          ,name="PIOc_inq_vartype")
         use iso_c_binding
         integer(C_INT)                                     , value :: ncid
         integer(C_INT)                                     , value :: varid
         integer(C_INT) :: xtype
       end function PIOc_inq_vartype
    end interface

    ierr = PIOc_inq_vartype(ncid                            ,varid-1,type)
  end function inq_vartype_id

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets metadata information for netcdf file.
  !!
  !! @param File @copydoc file_desc_t
  !! @param vardesc @copydoc var_desc_t
  !! @param natts The number of atts
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inq_varnatts_desc(File                   ,vardesc,natts) result(ierr)

    type (File_desc_t)                                      , intent(in)   :: File
    type (Var_desc_t)                                       , intent(in) :: vardesc
    integer                                                 , intent(out)    :: natts

    ierr = pio_inq_varnatts(File%fh                         , vardesc%varid,natts)
  end function inq_varnatts_desc

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets metadata information for netcdf file.
  !! @author Jim Edwards
  !<
  integer function inq_varnatts_vid(File                    ,varid,natts) result(ierr)

    type (File_desc_t)                                      , intent(in)   :: File
    integer                                                 , intent(in) :: varid
    integer                                                 , intent(out)    :: natts

    ierr = pio_inq_varnatts(File%fh                         , varid, natts)
  end function inq_varnatts_vid

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets metadata information for netcdf file.
  !! @author Jim Edwards
  !<
  integer function inq_varnatts_id(ncid                     ,varid,natts) result(ierr)
    integer                                                 , intent(in) :: ncid
    integer                                                 , intent(in) :: varid
    integer                                                 , intent(out)    :: natts

    interface
       integer(C_INT) function PIOc_inq_varnatts(ncid       ,varid,natts) &
            bind(C                                          ,name="PIOc_inq_varnatts")
         use iso_c_binding
         integer(C_INT)                                     , value :: ncid
         integer(C_INT)                                     , value :: varid
         integer(C_INT) :: natts
       end function PIOc_inq_varnatts
    end interface

    ierr = PIOc_inq_varnatts(ncid                           ,varid-1,natts)
  end function inq_varnatts_id

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets metadata information for netcdf file.
  !!
  !! @param File @copydoc file_desc_t
  !! @param vardesc @copydoc var_desc_t
  !! @param shuffle Value of shuffle
  !! @param deflate Status of deflate
  !! @param deflate_level Level of deflate
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inq_var_deflate_desc(File, vardesc, shuffle, deflate, &
       deflate_level) result(ierr)

    type (File_desc_t), intent(in) :: File
    type (Var_desc_t), intent(in) :: vardesc
    integer, intent(out) :: shuffle
    integer, intent(out) :: deflate
    integer, intent(out) :: deflate_level

    ierr = pio_inq_var_deflate(File%fh, vardesc%varid, shuffle, deflate, deflate_level)
  end function inq_var_deflate_desc

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets metadata information for netcdf file.
  !! @author Jim Edwards
  !<
  integer function inq_var_deflate_vid(File, varid, shuffle, deflate, deflate_level) result(ierr)

    type (File_desc_t), intent(in) :: File
    integer, intent(in) :: varid
    integer, intent(out) :: shuffle
    integer, intent(out) :: deflate
    integer, intent(out) :: deflate_level

    ierr = pio_inq_var_deflate(File%fh, varid, shuffle, deflate, deflate_level)
  end function inq_var_deflate_vid

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets metadata information for netcdf file.
  !! @author Jim Edwards
  !<
  integer function inq_var_deflate_id(ncid, varid, shuffle, deflate, &
       deflate_level) result(ierr)
    integer, intent(in) :: ncid
    integer, intent(in) :: varid
    integer, intent(out) :: shuffle
    integer, intent(out) :: deflate
    integer, intent(out) :: deflate_level

    interface
       integer(C_INT) function PIOc_inq_var_deflate(ncid, varid, shuffle, deflate, deflate_level) &
            bind(C, name="PIOc_inq_var_deflate")
         use iso_c_binding
         integer(C_INT), value :: ncid
         integer(C_INT), value :: varid
         integer(C_INT) :: shuffle
         integer(C_INT) :: deflate
         integer(C_INT) :: deflate_level
       end function PIOc_inq_var_deflate
    end interface

    ierr = PIOc_inq_var_deflate(ncid, varid-1, shuffle, deflate, deflate_level)
  end function inq_var_deflate_id

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets metadata information for netcdf file.
  !!
  !! @param File @copydoc file_desc_t
  !! @param vardesc @copydoc var_desc_t
  !! @param storage 0 for chunked, 1 for contiguous
  !! @param chunksizes Array of chunk sizes.
  !! @retval ierr @copydoc error_return
  !! @author Ed Hartnett
  !<
  integer function inq_var_chunking_desc(File, vardesc, storage, chunksizes) result(ierr)

    type (File_desc_t), intent(in) :: File
    type (Var_desc_t), intent(in) :: vardesc
    integer, intent(out) :: storage
    integer (kind=PIO_OFFSET_KIND), intent(out) :: chunksizes(*)

    ierr = pio_inq_var_chunking(File%fh, vardesc%varid, storage, chunksizes)
  end function inq_var_chunking_desc

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets metadata information for netcdf file.
  !! @author Ed Hartnett
  !<
  integer function inq_var_chunking_vid(File, varid, storage, chunksizes) result(ierr)

    type (File_desc_t), intent(in) :: File
    integer, intent(in) :: varid
    integer, intent(out) :: storage
    integer (kind=PIO_OFFSET_KIND), intent(out) :: chunksizes(*)

    ierr = pio_inq_var_chunking(File%fh, varid, storage, chunksizes)
  end function inq_var_chunking_vid

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Gets metadata information for netcdf file.
  !! @author Ed Hartnett
  !<
  integer function inq_var_chunking_id(ncid, varid, storage, chunksizes) result(ierr)
    integer, intent(in) :: ncid
    integer, intent(in) :: varid
    integer, intent(out) :: storage
    integer (kind=PIO_OFFSET_KIND), intent(out) :: chunksizes(*)
    integer(kind=PIO_OFFSET_KIND) :: cchunksizes(PIO_MAX_VAR_DIMS)
    integer :: ndims, i

    interface
       integer(C_INT) function PIOc_inq_var_chunking(ncid, varid, storage, cchunksizes) &
            bind(C, name="PIOc_inq_var_chunking")
         use iso_c_binding
         integer(C_INT), value :: ncid
         integer(C_INT), value :: varid
         integer(C_INT) :: storage
         integer(C_SIZE_T) :: cchunksizes(*)
       end function PIOc_inq_var_chunking
    end interface

    ierr = PIOc_inq_var_chunking(ncid, varid-1, storage, cchunksizes)
    ierr = pio_inq_varndims(ncid, varid, ndims)
    do i = 1, ndims
       chunksizes(i) = cchunksizes(ndims - i + 1)
    enddo

  end function inq_var_chunking_id

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Get the name associated with a variable.
  !!
  !! @param File @copydoc file_desc_t
  !! @param vardesc @copydoc var_desc_t
  !! @param name The name of the netcdf variable.
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inq_varname_desc(File                    ,vardesc,name) result(ierr)

    type (File_desc_t)                                      , intent(in)   :: File
    type (Var_desc_t)                                       , intent(in)    :: vardesc
    character(len=*)                                        , intent(out)    :: name

    ierr = pio_inq_varname(file%fh                          ,vardesc%varid,name)

  end function inq_varname_desc

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Get the name associated with a variable.
  !! @author Jim Edwards
  !<
  integer function inq_varname_vid(File                     ,varid,name) result(ierr)

    type (File_desc_t)                                      , intent(in)   :: File
    integer                                                 , intent(in)    :: varid
    character(len=*)                                        , intent(out)    :: name

    ierr = pio_inq_varname(file%fh                          ,varid,name)

  end function inq_varname_vid

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Get the name associated with a variable.
  !! @author Jim Edwards
  !<
  integer function inq_varname_id(ncid                      ,varid,name) result(ierr)
    integer                                                 ,intent(in) :: ncid
    integer                                                 , intent(in) :: varid
    character(len=*)                                        , intent(out)    :: name
    interface
       integer(C_INT) function PIOc_inq_varname(ncid        ,varid,name) &
            bind(C                                          ,name="PIOc_inq_varname")
         use iso_c_binding
         integer(C_INT)                                     , value :: ncid
         integer(C_INT)                                     , value :: varid
         character(C_CHAR) :: name(*)
       end function PIOc_inq_varname
    end interface
    name = C_NULL_CHAR
    ierr = PIOc_inq_varname(ncid                            ,varid-1,name)
    call replace_c_null(name)

  end function inq_varname_id

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Returns the ID of a netcdf variable given its name.
  !!
  !! @param File @copydoc file_desc_t
  !! @param name   Name of the returned attribute
  !! @param vardesc @copydoc var_desc_t
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inq_varid_desc(File,name,vardesc) result(ierr)

    type (File_desc_t), intent(in)   :: File
    character(len=*), intent(in)     :: name
    type (Var_desc_t), intent(inout) :: vardesc

    ierr = pio_inq_varid(File%fh, name, vardesc%varid)
  end function inq_varid_desc

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Returns the ID of a netcdf variable given its name.
  !! @author Jim Edwards
  !<
  integer function inq_varid_vid(File,name,varid) result(ierr)

    type (File_desc_t), intent(in)   :: File
    character(len=*), intent(in)     :: name
    integer, intent(out) :: varid

    ierr = pio_inq_varid(File%fh, name, varid)
  end function inq_varid_vid

  !>
  !! @public
  !! @ingroup PIO_inquire_variable
  !! Returns the ID of a netcdf variable given its name.
  !! @author Jim Edwards
  !<
  integer function inq_varid_id(ncid,name,varid) result(ierr)

    integer, intent(in)   :: ncid
    character(len=*), intent(in)   :: name
    integer, intent(out) :: varid
    interface
       integer(c_int) function PIOc_inq_varid(ncid,name,varid) &
            bind(C,name="PIOc_inq_varid")
         use iso_c_binding
         integer(C_INT), value :: ncid
         character(C_CHAR) :: name(*)
         integer(C_INT) :: varid
       end function PIOc_inq_varid
    end interface

    ierr = PIOc_inq_varid(ncid, trim(name)//C_NULL_CHAR, varid)

    ! the fortran value is one based while the c value is 0 based
    if (ierr == 0) then
       varid = varid+1
    endif
  end function inq_varid_id

  !>
  !! @public
  !! @ingroup PIO_inq_att
  !! Gets the attribute length.
  !!
  !! @param File @copydoc file_desc_t
  !! @param vardesc @copydoc var_desc_t
  !! @param name name of attribute
  !! @param len Length of attribute
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !>
  integer function inq_attlen_desc(File,vardesc,name,len) result(ierr)

    type (File_desc_t), intent(inout) :: File
    type (Var_desc_t), intent(in)            :: vardesc
    character(len=*), intent(in)      :: name
    integer(kind=PIO_OFFSET_KIND), intent(out)        :: len !Attribute length

    ierr = pio_inq_attlen(file%fh, vardesc%varid, name, len)

  end function inq_attlen_desc

  !>
  !! @ingroup PIO_inq_att
  !! Gets the attribute length.
  !! @author Jim Edwards
  !<
  integer function inq_attlen_vid(File,varid,name,len) result(ierr)

    type (File_desc_t), intent(inout) :: File
    integer, intent(in)            :: varid
    character(len=*), intent(in)      :: name
    integer(kind=PIO_OFFSET_KIND), intent(out)     :: len !Attribute length

    ierr = pio_inq_attlen(file%fh, varid, name, len)

  end function inq_attlen_vid

  !>
  !! @ingroup PIO_inq_att
  !! Gets the attribute length.
  !<
  integer function inq_attlen_id(ncid,varid,name,len) result(ierr)
    integer, intent(in) :: ncid
    integer, intent(in) :: varid
    character(len=*), intent(in)      :: name
    integer(kind=PIO_OFFSET_KIND), intent(out)     :: len !Attribute length
    interface
       integer(C_INT) function PIOc_inq_attlen(ncid,varid,name,len) &
            bind(C,name="PIOc_inq_attlen")
         use iso_c_binding
         integer(C_INT), value :: ncid
         integer(C_INT), value :: varid
         character(C_CHAR) :: name
         integer(C_SIZE_T) :: len
       end function PIOc_inq_attlen
    end interface

    ierr = PIOc_inq_attlen(ncid,varid-1,trim(name)//C_NULL_CHAR,len)
  end function inq_attlen_id

  !>
  !! @ingroup PIO_inq_att
  !! Gets information about attributes.
  !!
  !! @param File @copydoc file_desc_t
  !! @param vardesc @copydoc var_desc_t
  !! @param name Name of the attribute
  !! @param xtype The type of attribute
  !! @param len The length of the attribute
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function inq_att_desc(File,vardesc,name,xtype,len) result(ierr)

    type (File_desc_t), intent(inout) :: File
    type(var_desc_t), intent(in)           :: vardesc
    character(len=*), intent(in)      :: name
    integer, optional, intent(out)              :: xtype
    integer(pio_offset_kind), optional, intent(out)              :: len !Attribute length

    ierr = pio_inq_att(file%fh, vardesc%varid, name, xtype, len)

  end function inq_att_desc

  !>
  !! @ingroup PIO_inq_att
  !! Gets information about attributes.
  !! @author Jim Edwards
  !<
  integer function inq_att_vid(File,varid,name,xtype,len) result(ierr)

    type (File_desc_t), intent(in) :: File
    integer, intent(in)           :: varid
    character(len=*), intent(in)      :: name
    integer, optional, intent(out)              :: xtype
    integer(pio_offset_kind), optional, intent(out)              :: len !Attribute length

    ierr = pio_inq_att(file%fh, varid, name, xtype, len)

  end function inq_att_vid

  !>
  !! @ingroup PIO_inq_att
  !! Gets information about attributes.
  !! @author Jim Edwards
  !<
  integer function inq_att_id(ncid,varid,name,xtype,len) result(ierr)

    integer, intent(in) :: ncid
    integer, intent(in)           :: varid
    character(len=*), intent(in)      :: name
    integer, optional, intent(out)              :: xtype
    integer(kind=PIO_OFFSET_KIND), optional, intent(out)              :: len !Attribute length

    integer :: ixtype
    integer(PIO_OFFSET_KIND) :: xlen

    interface
       integer(C_INT) function PIOc_inq_att(ncid,varid,name,xtype,len) &
            bind(C,name="PIOc_inq_att")
         use iso_c_binding
         integer(C_INT),value :: ncid
         integer(C_INT),value :: varid
         character(C_CHAR) :: name(*)
         integer(C_INT) :: xtype
         integer(C_SIZE_T) :: len
       end function PIOc_inq_att
    end interface

    ierr = PIOc_inq_att(ncid,varid-1,trim(name)//C_NULL_CHAR,ixtype,xlen)
    if(present(len)) len=xlen
    if(present(xtype)) xtype = ixtype

  end function inq_att_id

  !>
  !! @ingroup PIO_inq_att
  !! Gets the name of an attribute.
  !! @author Jim Edwards
  !<
  integer function inq_attname_desc(File,vdesc,attnum,name) result(ierr)
    type (File_desc_t), intent(inout) :: File
    type (var_desc_t), intent(in)           :: vdesc
    integer, intent(in)              :: attnum !Attribute number
    character(len=*), intent(out)     :: name

    ierr = inq_attname_id(file%fh,vdesc%varid,attnum,name)

  end function inq_attname_desc

  !>
  !! @ingroup PIO_inq_att
  !! Gets the name of an attribute.
  !! @author Jim Edwards
  !<
  integer function inq_attname_vid(File,varid,attnum,name) result(ierr)
    type (File_desc_t), intent(inout) :: File
    integer, intent(in)           :: varid
    integer, intent(in)              :: attnum !Attribute number
    character(len=*), intent(out)     :: name

    ierr = inq_attname_id(file%fh,varid,attnum,name)

  end function inq_attname_vid

  !>
  !! @ingroup PIO_inq_att
  !! Gets the name of an attribute.
  !! @author Jim Edwards
  !<
  integer function inq_attname_id(ncid,varid,attnum,name) result(ierr)
    integer, intent(in) :: ncid
    integer, intent(in) :: varid
    integer, intent(in)              :: attnum !Attribute number
    character(len=*), intent(out)     :: name
    interface
       integer(C_INT) function PIOc_inq_attname(ncid,varid,attnum,name) &
            bind(C,name="PIOc_inq_attname")
         use iso_c_binding
         integer(C_INT), value :: ncid
         integer(C_INT), value :: varid
         integer(C_INT), value :: attnum
         character(C_CHAR) :: name(*)
       end function PIOc_inq_attname
    end interface
    name = C_NULL_CHAR

    ierr = PIOc_inq_attname(ncid,varid-1,attnum-1,name)
    call replace_c_null(name)

  end function inq_attname_id

  !>
  !! @ingroup PIO_def_var
  !! Defines a netcdf variable.
  !!
  !! @param File @copydoc file_desc_t
  !! @param name The name of the variable to define
  !! @param type The type of variable
  !! @param vardesc @copydoc var_desc_t
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function def_var_0d_desc(File,name,type,vardesc) result(ierr)

    type (File_desc_t), intent(in)  :: File
    character(len=*), intent(in)    :: name
    integer, intent(in)             :: type
    type (Var_desc_t), intent(inout) :: vardesc
    integer :: dimids(0)

    ierr = def_var_md_id(File%fh,name,type,dimids,vardesc%varid)

  end function def_var_0d_desc

  !>
  !! @ingroup PIO_def_var
  !! Defines a netcdf variable.
  !! @author Jim Edwards
  !<
  integer function def_var_0d_id(ncid,name,type,varid) result(ierr)

    integer,intent(in) :: ncid
    character(len=*), intent(in)    :: name
    integer, intent(in)             :: type
    integer, intent(out) :: varid
    integer :: dimids(0)

    ierr = def_var_md_id(ncid,name,type,dimids,varid)

  end function def_var_0d_id

  !>
  !! @ingroup PIO_def_var
  !! Defines the a netcdf variable.
  !!
  !! @param File @copydoc file_desc_t
  !! @param name The name of the variable to define
  !! @param type The type of variable
  !! @param dimids The dimension identifier returned by \ref PIO_def_dim
  !! @param vardesc @copydoc var_desc_t
  !! @retval ierr @copydoc error_return
  !! @author Jim Edwards
  !<
  integer function def_var_md_desc(File,name,type,dimids,vardesc) result(ierr)
    type (File_desc_t), intent(in)  :: File
    character(len=*), intent(in)    :: name
    integer, intent(in)             :: type
    integer, intent(in)             :: dimids(:)
    type (Var_desc_t), intent(inout) :: vardesc

    ierr = def_var_md_id(file%fh,name,type,dimids,vardesc%varid)
  end function def_var_md_desc

  !>
  !! @ingroup PIO_def_var
  !! Defines a netcdf variable.
  !! @author Jim Edwards
  !<
  integer function def_var_md_id(ncid,name,type,dimids,varid) result(ierr)
    integer,intent(in) :: ncid
    character(len=*), intent(in)    :: name
    integer, intent(in)             :: type
    integer, intent(in)   :: dimids(:)
    integer, intent(out) :: varid
    integer(C_INT) :: cdimids(PIO_MAX_VAR_DIMS)
    integer :: ndims, i
    interface
       integer (C_INT) function PIOc_def_var(ncid,name,xtype,ndims,dimidsp,varidp) &
            bind(c,name="PIOc_def_var")
         use iso_c_binding
         integer(c_int), value :: ncid
         character(c_char) :: name
         integer(c_int), value :: xtype
         integer(c_int), value :: ndims
         integer(c_int) :: dimidsp(*)
         integer(c_int) :: varidp
       end function PIOc_def_var
    end interface
    ndims = size(dimids)
    do i=1,ndims
       cdimids(i) = dimids(ndims-i+1)-1
    enddo

    ierr = PIOc_def_var(ncid, trim(name)//C_NULL_CHAR, type, ndims, cdimids,varid)
    varid = varid+1
  end function def_var_md_id

  !>
  !! @ingroup PIO_def_var_deflate
  !! Changes compression settings for a netCDF-4/HDF5 variable.
  !! @author Ed Hartnett
  !<
  integer function def_var_deflate_id(file, varid, shuffle, deflate, deflate_level) &
       result(ierr)
    type (File_desc_t), intent(in)  :: file
    integer, intent(in) :: varid
    integer, intent(in) :: shuffle
    integer, intent(in) :: deflate
    integer, intent(in) :: deflate_level

    interface
       integer (C_INT) function PIOc_def_var_deflate(ncid, varid, shuffle, deflate, &
            deflate_level) bind(c,name="PIOc_def_var_deflate")
         use iso_c_binding
         integer(c_int), value :: ncid
         integer(c_int), value :: varid
         integer(c_int), value :: shuffle
         integer(c_int), value :: deflate
         integer(c_int), value :: deflate_level
       end function PIOc_def_var_deflate
    end interface

    ierr = PIOc_def_var_deflate(file%fh, varid-1, shuffle, deflate, deflate_level)
  end function def_var_deflate_id

  !>
  !! @ingroup PIO_def_var_deflate
  !! Changes compression settings for a netCDF-4/HDF5 variable.
  !! @author Ed Hartnett
  !<
  integer function def_var_deflate_desc(file, vardesc, shuffle, deflate, deflate_level) &
       result(ierr)
    type (File_desc_t), intent(in)  :: file
    type (var_desc_t), intent(in) :: vardesc
    integer, intent(in) :: shuffle
    integer, intent(in) :: deflate
    integer, intent(in) :: deflate_level

    ierr = def_var_deflate_id(file, vardesc%varid, shuffle, deflate, deflate_level)
  end function def_var_deflate_desc

  !>
  !! @ingroup PIO_def_var_chunking
  !! Changes chunking settings for a netCDF-4/HDF5 variable.
  !! @author Ed Hartnett
  !<
  integer function def_var_chunking_desc(file, vardesc, storage, chunksizes) result(ierr)
    type (File_desc_t), intent(in)  :: file
    type (var_desc_t), intent(in) :: vardesc
    integer, intent(in) :: storage
    integer, intent(in) :: chunksizes(:)
    integer(kind=PIO_OFFSET_KIND) :: cchunksizes(PIO_MAX_VAR_DIMS)
    integer :: ndims, i

    interface
       integer (C_INT) function PIOc_def_var_chunking(ncid, varid, storage, chunksizes) &
            bind(c,name="PIOc_def_var_chunking")
         use iso_c_binding
         integer(c_int), value :: ncid
         integer(c_int), value :: varid
         integer(c_int), value :: storage
         integer(c_size_t) :: chunksizes(*)
       end function PIOc_def_var_chunking
    end interface
    ndims = size(chunksizes)
    do i=1,ndims
       cchunksizes(i) = chunksizes(ndims-i+1)
    enddo

    ierr = PIOc_def_var_chunking(file%fh, vardesc%varid-1, storage, cchunksizes)
  end function def_var_chunking_desc

  !>
  !! @ingroup PIO_set_chunk_cache
  !! Changes chunk cache settings for netCDF-4/HDF5 files created after this call.
  !! @author Ed Hartnett
  !<
  integer function set_chunk_cache(iosysid, iotype, chunk_cache_size, chunk_cache_nelems, &
       chunk_cache_preemption) result(ierr)
    integer, intent(in) :: iosysid
    integer, intent(in) :: iotype
    integer(kind=PIO_OFFSET_KIND), intent(in) :: chunk_cache_size
    integer(kind=PIO_OFFSET_KIND), intent(in) :: chunk_cache_nelems
    real, intent(in) :: chunk_cache_preemption

    interface
       integer (C_INT) function PIOc_set_chunk_cache(iosysid, iotype, chunk_cache_size, &
            chunk_cache_nelems, chunk_cache_preemption) &
            bind(c,name="PIOc_set_chunk_cache")
         use iso_c_binding
         integer(c_int), value :: iosysid
         integer(c_int), value :: iotype
         integer(c_size_t), value :: chunk_cache_size
         integer(c_size_t), value :: chunk_cache_nelems
         real(c_float), value :: chunk_cache_preemption
       end function PIOc_set_chunk_cache
    end interface

    ierr = PIOc_set_chunk_cache(iosysid, iotype, chunk_cache_size, chunk_cache_nelems, &
         chunk_cache_preemption)
  end function set_chunk_cache

  !>
  !! @ingroup PIO_get_chunk_cache
  !! Gets current settings for chunk cache (only relevant for netCDF4/HDF5 files).
  !! @author Ed Hartnett
  !<
  integer function get_chunk_cache(iosysid, iotype, chunk_cache_size, chunk_cache_nelems, &
       chunk_cache_preemption) result(ierr)
    integer, intent(in) :: iosysid
    integer, intent(in) :: iotype
    integer(kind=PIO_OFFSET_KIND), intent(out) :: chunk_cache_size
    integer(kind=PIO_OFFSET_KIND), intent(out) :: chunk_cache_nelems
    real, intent(out) :: chunk_cache_preemption

    interface
       integer (C_INT) function PIOc_get_chunk_cache(iosysid, iotype, chunk_cache_size, &
            chunk_cache_nelems, chunk_cache_preemption) &
            bind(c,name="PIOc_get_chunk_cache")
         use iso_c_binding
         integer(c_int), value :: iosysid
         integer(c_int), value :: iotype
         integer(c_size_t) :: chunk_cache_size
         integer(c_size_t) :: chunk_cache_nelems
         real(c_float) :: chunk_cache_preemption
       end function PIOc_get_chunk_cache
    end interface

    ierr = PIOc_get_chunk_cache(iosysid, iotype, chunk_cache_size, chunk_cache_nelems, &
         chunk_cache_preemption)
  end function get_chunk_cache

  !>
  !! @ingroup PIO_set_var_chunk_cache
  !! Changes chunk cache settings for a variable in a netCDF-4/HDF5 file.
  !! @author Ed Hartnett
  !<
  integer function set_var_chunk_cache_id(file, varid, chunk_cache_size, &
       chunk_cache_nelems, chunk_cache_preemption) result(ierr)
    type (File_desc_t), intent(in)  :: file
    integer, intent(in) :: varid
    integer(PIO_OFFSET_KIND), intent(in) :: chunk_cache_size
    integer(PIO_OFFSET_KIND), intent(in) :: chunk_cache_nelems
    real, intent(in) :: chunk_cache_preemption

    interface
       integer (C_INT) function PIOc_set_var_chunk_cache(ncid, varid, chunk_cache_size, &
            chunk_cache_nelems, chunk_cache_preemption) &
            bind(c,name="PIOc_set_var_chunk_cache")
         use iso_c_binding
         integer(c_int), value :: ncid
         integer(c_int), value :: varid
         integer(c_size_t), value :: chunk_cache_size
         integer(c_size_t), value :: chunk_cache_nelems
         real(c_float), value :: chunk_cache_preemption
       end function PIOc_set_var_chunk_cache
    end interface

    ierr = PIOc_set_var_chunk_cache(file%fh, varid-1, chunk_cache_size, &
         chunk_cache_nelems, chunk_cache_preemption)
  end function set_var_chunk_cache_id

  !>
  !! @ingroup PIO_set_var_chunk_cache
  !! Changes chunk cacne for a variable.
  !! @author Ed Hartnett
  !<
  integer function set_var_chunk_cache_desc(file, vardesc, chunk_cache_size, &
       chunk_cache_nelems, chunk_cache_preemption) result(ierr)
    type (File_desc_t), intent(in)  :: file
    type (var_desc_t), intent(in) :: vardesc
    integer(PIO_OFFSET_KIND), intent(in) :: chunk_cache_size
    integer(PIO_OFFSET_KIND), intent(in) :: chunk_cache_nelems
    real, intent(in) :: chunk_cache_preemption

    ierr = set_var_chunk_cache_id(file, vardesc%varid, chunk_cache_size, &
         chunk_cache_nelems, chunk_cache_preemption)
  end function set_var_chunk_cache_desc

  !>
  !! @ingroup PIO_get_var_chunk_cache
  !! Get the chunk cache settings for a variable.
  !! @author Ed Hartnett
  !<
  integer function get_var_chunk_cache_desc(file, vardesc, chunk_cache_size, &
       chunk_cache_nelems, chunk_cache_preemption) result(ierr)
    type (File_desc_t), intent(in)  :: file
    type (var_desc_t), intent(in) :: vardesc
    integer(PIO_OFFSET_KIND), intent(out) :: chunk_cache_size
    integer(PIO_OFFSET_KIND), intent(out) :: chunk_cache_nelems
    real, intent(out) :: chunk_cache_preemption

    ierr = get_var_chunk_cache_id(file, vardesc%varid, chunk_cache_size, &
         chunk_cache_nelems, chunk_cache_preemption)
  end function get_var_chunk_cache_desc

  !>
  !! @ingroup PIO_get_var_chunk_cache
  !! Get the chunk cache settings for a variable.
  !! @author Ed Hartnett
  !<
  integer function get_var_chunk_cache_id(file, varid, chunk_cache_size, &
       chunk_cache_nelems, chunk_cache_preemption) result(ierr)
    type (File_desc_t), intent(in)  :: file
    integer, intent(in) :: varid
    integer(PIO_OFFSET_KIND), intent(out) :: chunk_cache_size
    integer(PIO_OFFSET_KIND), intent(out) :: chunk_cache_nelems
    real, intent(out) :: chunk_cache_preemption

    interface
       integer (C_INT) function PIOc_get_var_chunk_cache(ncid, varid, &
            chunk_cache_size, chunk_cache_nelems, chunk_cache_preemption) &
            bind(c,name="PIOc_get_var_chunk_cache")
         use iso_c_binding
         integer(c_int), value :: ncid
         integer(c_int), value :: varid
         integer(c_size_t) :: chunk_cache_size
         integer(c_size_t) :: chunk_cache_nelems
         real(c_float) :: chunk_cache_preemption
       end function PIOc_get_var_chunk_cache
    end interface

    ierr = PIOc_get_var_chunk_cache(file%fh, varid-1, chunk_cache_size, &
         chunk_cache_nelems, chunk_cache_preemption)
  end function get_var_chunk_cache_id

end module pio_nf
