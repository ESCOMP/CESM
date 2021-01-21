!>
!! @file
!! This module defines default numerical data types for all common data
!! types like integer, character, logical, real4 and real8.
!!
!<
#include "config.h"
 module pio_kinds

!  uses mpi if available
#ifndef NO_MPIMOD
   use mpi, only : MPI_OFFSET_KIND ! _EXTERNAL
#endif

   implicit none
   private
#ifdef NO_MPIMOD
#include <mpif.h>
#endif
! !DEFINED PARAMETERS:

   integer, parameter, public ::          &
      char_len  = 360                    ,& !< char len
      log_kind  = kind(.true.)           ,& !< logical kind
      int_kind  = kind(1)                ,& !< int kind
      i2        = selected_int_kind(4)   ,& !< i2 (short) kind
      i4        = selected_int_kind(6)   ,& !< i4 kind
      i8        = selected_int_kind(13)  ,& !< i8 kind
      r4        = selected_real_kind(6)  ,& !< r4 kind
      r8        = selected_real_kind(13)    !< r8 kind
!
!  MPI defines MPI_OFFSET_KIND as the byte size of the
!  type, which is not nessasarily the type kind
!
!> Byte size of the MPI_OFFSET type.
   integer, parameter, public :: PIO_OFFSET_KIND=MPI_OFFSET_KIND

 end module pio_kinds
