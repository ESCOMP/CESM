module perf_utils

!----------------------------------------------------------------------- 
! 
! Purpose: This module supplies the csm_share and CAM utilities
!          needed by perf_mod.F90 (when the csm_share and CAM utilities
!          are not available).
! 
! Author:  P. Worley, October 2007
!
! $Id$
! 
!-----------------------------------------------------------------------
#ifndef NO_MPIMOD
  use mpi
#endif
!-----------------------------------------------------------------------
!- module boilerplate --------------------------------------------------
!-----------------------------------------------------------------------
   implicit none
   private                   ! Make the default access private
   save

!-----------------------------------------------------------------------
! Public interfaces ----------------------------------------------------
!-----------------------------------------------------------------------
   public perfutils_setunit
   public shr_sys_abort
   public shr_mpi_barrier
   public shr_file_getUnit
   public shr_file_freeUnit
   public find_group_name
   public to_lower
   public shr_mpi_bcast

   interface shr_mpi_bcast ; module procedure &
     shr_mpi_bcastl0, &
     shr_mpi_bcasti0
   end interface

!-----------------------------------------------------------------------
! Private interfaces ---------------------------------------------------
!-----------------------------------------------------------------------
   private shr_sys_flush
   private shr_mpi_chkerr
   private shr_mpi_abort

!-----------------------------------------------------------------------
!- include statements --------------------------------------------------
!-----------------------------------------------------------------------
#ifdef NO_MPIMOD
#include <mpif.h>  
#endif
#include "gptl.inc"

!-----------------------------------------------------------------------
! Public data ---------------------------------------------------------
!-----------------------------------------------------------------------

   !----------------------------------------------------------------------------
   ! precision/kind constants (from csm_share/shr/shr_kind_mod.F90)
   !----------------------------------------------------------------------------
   integer,parameter,public :: SHR_KIND_R8 = selected_real_kind(12) ! 8 byte real
   integer,parameter,public :: SHR_KIND_I8 = selected_int_kind (13) ! 8 byte integer
   integer,parameter,public :: SHR_KIND_IN = kind(1)                ! native integer
   integer,parameter,public :: SHR_KIND_CL = 256                    ! long char
   integer,parameter,public :: SHR_KIND_CX = 512                    ! extra-long char

!-----------------------------------------------------------------------
! Private data ---------------------------------------------------------
!-----------------------------------------------------------------------

   integer, parameter :: def_pu_logunit = 6                   ! default
   integer, private   :: pu_logunit = def_pu_logunit
                         ! unit number for log output

!=======================================================================
contains
!=======================================================================

!
!========================================================================
!
   subroutine perfutils_setunit(LogUnit)
!----------------------------------------------------------------------- 
! Purpose:  Set log unit number.
! Author:   P. Worley 
!-----------------------------------------------------------------------
!---------------------------Input arguments-----------------------------
!
   integer(SHR_KIND_IN), intent(IN) :: LogUnit  ! Unit number for log output
!-----------------------------------------------------------------------
   pu_logunit = LogUnit
!
   return
!
   end subroutine perfutils_setunit

!============== Routines from csm_share/shr/shr_sys_mod.F90 ============
!=======================================================================

SUBROUTINE shr_sys_abort(string)

   IMPLICIT none

   character(*)        ,optional :: string  ! error message string

   !----- local -----
   integer(SHR_KIND_IN) :: ierr
   logical              :: flag

   !----- formats -----
   character(*),parameter :: subName =   '(shr_sys_abort) '
   character(*),parameter :: F00     = "('(shr_sys_abort) ',4a)"

!-------------------------------------------------------------------------------
! PURPOSE: consistent stopping mechanism
! (dumbed down from original shr_sys_mod.F90 version for use in perf_mod)
!-------------------------------------------------------------------------------

   call shr_sys_flush(pu_logunit)

   if ( present(string) ) then
      if (len_trim(string) > 0) then
         write(pu_logunit,*) trim(subName),' ERROR: ',trim(string)
      else
         write(pu_logunit,*) trim(subName),' ERROR '
      endif
   else
      write(pu_logunit,*) trim(subName),' ERROR '
   endif

   write(pu_logunit,F00) 'WARNING: calling mpi_abort() and stopping'
   call shr_sys_flush(pu_logunit)
   call mpi_abort(MPI_COMM_WORLD,0,ierr)
   call shr_sys_flush(pu_logunit)
#ifndef CPRNAG
   call abort()
#endif
   stop

END SUBROUTINE shr_sys_abort

!===============================================================================
!===============================================================================

SUBROUTINE shr_sys_flush(unit)

   IMPLICIT none

   !----- arguments -----
   integer(SHR_KIND_IN) :: unit  ! flush output buffer for this unit

   !----- formats -----
   character(*),parameter :: subName =   '(shr_sys_flush) '
   character(*),parameter :: F00     = "('(shr_sys_flush) ',4a)"

!-------------------------------------------------------------------------------
! PURPOSE: an architecture independant system call
!-------------------------------------------------------------------------------

   flush(unit)


END SUBROUTINE shr_sys_flush

!===============================================================================

!================== Routines from csm_share/shr/shr_mpi_mod.F90 ===============
!===============================================================================

SUBROUTINE shr_mpi_chkerr(rcode,string)

   IMPLICIT none

   !----- arguments ---
   integer(SHR_KIND_IN), intent(in) :: rcode  ! input MPI error code
   character(*),         intent(in) :: string ! message

   !----- local ---
   character(*),parameter           :: subName = '(shr_mpi_chkerr) '
   character(MPI_MAX_ERROR_STRING)  :: lstring
   integer(SHR_KIND_IN)             :: len
   integer(SHR_KIND_IN)             :: ierr

!-------------------------------------------------------------------------------
! PURPOSE: layer on MPI error checking
!-------------------------------------------------------------------------------

   if (rcode /= MPI_SUCCESS) then
     call MPI_ERROR_STRING(rcode,lstring,len,ierr)
     write(pu_logunit,*) trim(subName),":",lstring(1:len)
     call shr_mpi_abort(string,rcode)
   endif

END SUBROUTINE shr_mpi_chkerr

!===============================================================================
!===============================================================================

SUBROUTINE shr_mpi_abort(string,rcode)

   IMPLICIT none

   !----- arguments ---
   character(*),optional,intent(in)   :: string   ! message
   integer,optional,intent(in)        :: rcode    ! optional code

   !----- local ---
   character(*),parameter             :: subName = '(shr_mpi_abort) '
   integer(SHR_KIND_IN)               :: ierr

!-------------------------------------------------------------------------------
! PURPOSE: MPI abort
!-------------------------------------------------------------------------------

   if ( present(string) .and. present(rcode) ) then
      write(pu_logunit,*) trim(subName),":",trim(string),rcode
   endif
   call MPI_ABORT(MPI_COMM_WORLD,rcode,ierr)

END SUBROUTINE shr_mpi_abort

!===============================================================================
!===============================================================================

SUBROUTINE shr_mpi_barrier(comm,string)

   IMPLICIT none

   !----- arguments ---
   integer,intent(in)                 :: comm
   character(*),optional,intent(in)   :: string   ! message

   !----- local ---
   character(*),parameter             :: subName = '(shr_mpi_barrier) '
   integer(SHR_KIND_IN)               :: ierr

!-------------------------------------------------------------------------------
! PURPOSE: MPI barrier
!-------------------------------------------------------------------------------

   call MPI_BARRIER(comm,ierr)
   if (present(string)) then
     call shr_mpi_chkerr(ierr,subName//trim(string))
   else
     call shr_mpi_chkerr(ierr,subName)
   endif

END SUBROUTINE shr_mpi_barrier

!===============================================================================
!===============================================================================

SUBROUTINE shr_mpi_bcasti0(vec,comm,string)

   IMPLICIT none

   !----- arguments ---
   integer(SHR_KIND_IN), intent(inout):: vec      ! vector of 1
   integer(SHR_KIND_IN), intent(in)   :: comm     ! mpi communicator
   character(*),optional,intent(in)   :: string   ! message

   !----- local ---
   character(*),parameter             :: subName = '(shr_mpi_bcasti0) '
   integer(SHR_KIND_IN)               :: ierr
   integer(SHR_KIND_IN)               :: lsize

!-------------------------------------------------------------------------------
! PURPOSE: Broadcast an integer
!-------------------------------------------------------------------------------

   lsize = 1

   call MPI_BCAST(vec,lsize,MPI_INTEGER,0,comm,ierr)
   if (present(string)) then
     call shr_mpi_chkerr(ierr,subName//trim(string))
   else
     call shr_mpi_chkerr(ierr,subName)
   endif

END SUBROUTINE shr_mpi_bcasti0

!===============================================================================
!===============================================================================

SUBROUTINE shr_mpi_bcastl0(vec,comm,string)

   IMPLICIT none

   !----- arguments ---
   logical, intent(inout):: vec      ! vector of 1
   integer(SHR_KIND_IN), intent(in)   :: comm     ! mpi communicator
   character(*),optional,intent(in)   :: string   ! message

   !----- local ---
   character(*),parameter             :: subName = '(shr_mpi_bcastl0) '
   integer(SHR_KIND_IN)               :: ierr
   integer(SHR_KIND_IN)               :: lsize

!-------------------------------------------------------------------------------
! PURPOSE: Broadcast a logical
!-------------------------------------------------------------------------------

   lsize = 1

   call MPI_BCAST(vec,lsize,MPI_LOGICAL,0,comm,ierr)
   if (present(string)) then
     call shr_mpi_chkerr(ierr,subName//trim(string))
   else
     call shr_mpi_chkerr(ierr,subName)
   endif

END SUBROUTINE shr_mpi_bcastl0

!===============================================================================

!================== Routines from csm_share/shr/shr_file_mod.F90 ===============
!===============================================================================
!BOP ===========================================================================
!
! !IROUTINE: shr_file_getUnit -- Get a free FORTRAN unit number
!
! !DESCRIPTION: Get the next free FORTRAN unit number.
!
! !REVISION HISTORY:
!     2005-Dec-14 - E. Kluzek - creation
!     2007-Oct-21 - P. Worley - dumbed down for use in perf_mod
!
! !INTERFACE: ------------------------------------------------------------------  

INTEGER FUNCTION shr_file_getUnit ()

   implicit none

!EOP

   !----- local parameters -----
   integer(SHR_KIND_IN),parameter :: shr_file_minUnit = 10      ! Min unit number to give
   integer(SHR_KIND_IN),parameter :: shr_file_maxUnit = 99      ! Max unit number to give

   !----- local variables -----
   integer(SHR_KIND_IN)   :: n      ! loop index
   logical                :: opened ! If unit opened or not

   !----- formats -----
   character(*),parameter :: subName = '(shr_file_getUnit) '
   character(*),parameter :: F00   = "('(shr_file_getUnit) ',A,I4,A)"

!-------------------------------------------------------------------------------
! Notes:
!-------------------------------------------------------------------------------

   ! --- Choose first available unit other than 0, 5, or 6  ------
   do n=shr_file_minUnit, shr_file_maxUnit
      inquire( n, opened=opened )
      if (n == 5 .or. n == 6 .or. opened) then
         cycle
      end if
      shr_file_getUnit = n
      return
   end do

   call shr_sys_abort( subName//': Error: no available units found' )

END FUNCTION shr_file_getUnit
!===============================================================================

!===============================================================================
!BOP ===========================================================================
!
! !IROUTINE: shr_file_freeUnit -- Free up a FORTRAN unit number
!
! !DESCRIPTION: Free up the given unit number
!
! !REVISION HISTORY:
!     2005-Dec-14 - E. Kluzek - creation
!     2007-Oct-21 - P. Worley - dumbed down for use in perf_mod
!
! !INTERFACE: ------------------------------------------------------------------  

SUBROUTINE shr_file_freeUnit ( unit)

   implicit none

! !INPUT/OUTPUT PARAMETERS:

   integer(SHR_KIND_IN),intent(in) :: unit  ! unit number to be freed

!EOP

   !----- local parameters -----
   integer(SHR_KIND_IN),parameter :: shr_file_minUnit = 10      ! Min unit number to give
   integer(SHR_KIND_IN),parameter :: shr_file_maxUnit = 99      ! Max unit number to give

   !----- formats -----
   character(*), parameter :: subName = '(shr_file_freeUnit) '
   character(*), parameter :: F00 =   "('(shr_file_freeUnit) ',A,I4,A)"

!-------------------------------------------------------------------------------
! Notes:
!-------------------------------------------------------------------------------

   if (unit < 0 .or. unit > shr_file_maxUnit) then
!pw   if (s_loglev > 0) write(pu_logunit,F00) 'invalid unit number request:', unit
   else if (unit == 0 .or. unit == 5 .or. unit == 6) then
      call shr_sys_abort( subName//': Error: units 0, 5, and 6 must not be freed' )
   end if

   return

END SUBROUTINE shr_file_freeUnit
!===============================================================================

!============= Routines from atm/cam/src/utils/namelist_utils.F90 ==============
!===============================================================================

subroutine find_group_name(unit, group, status)

!---------------------------------------------------------------------------------------
! Purpose: 
! Search a file that contains namelist input for the specified namelist group name.
! Leave the file positioned so that the current record is the first record of the
! input for the specified group.
! 
! Method: 
! Read the file line by line.  Each line is searched for an '&' which may only
! be preceded by blanks, immediately followed by the group name which is case
! insensitive.  If found then backspace the file so the current record is the
! one containing the group name and return success.  Otherwise return -1.
!
! Author:  B. Eaton, August 2007
!---------------------------------------------------------------------------------------

   integer,          intent(in)  :: unit     ! fortran unit attached to file
   character(len=*), intent(in)  :: group    ! namelist group name
   integer,          intent(out) :: status   ! 0 for success, -1 if group name not found

   ! Local variables

   integer           :: len_grp
   integer           :: ios    ! io status
   character(len=80) :: inrec  ! first 80 characters of input record
   character(len=80) :: inrec2 ! left adjusted input record
   character(len=len(group)) :: lc_group

   !---------------------------------------------------------------------------

   len_grp = len_trim(group)
   lc_group = to_lower(group)

   ios = 0
   do while (ios <= 0)

      read(unit, '(a)', iostat=ios, end=102) inrec

      if (ios <= 0) then  ! ios < 0  indicates an end of record condition

         ! look for group name in this record

         ! remove leading blanks
         inrec2 = to_lower(adjustl(inrec))

         ! check for leading '&'
         if (inrec2(1:1) == '&') then

            ! check for case insensitive group name
            if (trim(lc_group) == inrec2(2:len_grp+1)) then

               ! found group name.  backspace to leave file position at this record
               backspace(unit)
               status = 0
               return

            end if
         end if
      end if

   end do

   102 continue  ! end of file processing
   status = -1

end subroutine find_group_name
!===============================================================================

!================ Routines from atm/cam/src/utils/string_utils.F90 =============
!===============================================================================

function to_lower(str)

!----------------------------------------------------------------------- 
! Purpose: 
! Convert character string to lower case.
! 
! Method: 
! Use achar and iachar intrinsics to ensure use of ascii collating sequence.
!
! Author:  B. Eaton, July 2001
!     
! $Id$
!----------------------------------------------------------------------- 
   implicit none

   character(len=*), intent(in) :: str      ! String to convert to lower case
   character(len=len(str))      :: to_lower

! Local variables

   integer :: i                ! Index
   integer :: aseq             ! ascii collating sequence
   integer :: upper_to_lower   ! integer to convert case
   character(len=1) :: ctmp    ! Character temporary
!-----------------------------------------------------------------------
   upper_to_lower = iachar("a") - iachar("A")

   do i = 1, len(str)
      ctmp = str(i:i)
      aseq = iachar(ctmp)
      if ( aseq >= iachar("A") .and. aseq <= iachar("Z") ) &
           ctmp = achar(aseq + upper_to_lower)	
      to_lower(i:i) = ctmp
   end do

end function to_lower
!===============================================================================

end module perf_utils
