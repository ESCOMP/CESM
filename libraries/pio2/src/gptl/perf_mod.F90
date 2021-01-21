module perf_mod

!----------------------------------------------------------------------- 
! 
! Purpose: This module is responsible for controlling the performance
!          timer logic.
! 
! Author:  P. Worley, January 2007
!
! $Id$
! 
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
!- Uses ----------------------------------------------------------------
!-----------------------------------------------------------------------

#ifndef USE_CSM_SHARE
   use perf_utils
#else
   use shr_sys_mod,       only: shr_sys_abort
   use shr_kind_mod,      only: shr_kind_cl, shr_kind_r8, shr_kind_i8
   use shr_mpi_mod,       only: shr_mpi_barrier, shr_mpi_bcast
   use shr_file_mod,      only: shr_file_getUnit, shr_file_freeUnit
   use namelist_utils,    only: find_group_name
#endif

!-----------------------------------------------------------------------
!- module boilerplate --------------------------------------------------
!-----------------------------------------------------------------------
   implicit none
   private                   ! Make the default access private


!-----------------------------------------------------------------------
! Public interfaces ----------------------------------------------------
!-----------------------------------------------------------------------
   public t_initf
   public t_setLogUnit
   public t_getLogUnit
   public t_profile_onf
   public t_barrier_onf
   public t_single_filef
   public t_stampf
   public t_startf
   public t_stopf
   public t_enablef
   public t_disablef
   public t_adj_detailf
   public t_barrierf
   public t_prf
   public t_finalizef

!-----------------------------------------------------------------------
! Private interfaces (local) -------------------------------------------
!-----------------------------------------------------------------------
   private perf_defaultopts
   private perf_setopts
   private papi_defaultopts
   private papi_setopts

!-----------------------------------------------------------------------
!- include statements --------------------------------------------------
!-----------------------------------------------------------------------
#include <mpif.h>  
#include "gptl.inc"

!-----------------------------------------------------------------------
! Private data ---------------------------------------------------------
!-----------------------------------------------------------------------

   !----------------------------------------------------------------------------
   ! perf_mod options
   !----------------------------------------------------------------------------
   integer, parameter :: def_p_logunit = 6                   ! default
   integer, private   :: p_logunit = def_p_logunit
                         ! unit number for log output

   logical, parameter :: def_timing_initialized = .false.      ! default
   logical, private   :: timing_initialized = def_timing_initialized
                         ! flag indicating whether timing library has
                         ! been initialized

   logical, parameter :: def_timing_disable = .false.          ! default
   logical, private   :: timing_disable = def_timing_disable
                         ! flag indicating whether timers are disabled

   logical, parameter :: def_timing_barrier = .false.          ! default
   logical, private   :: timing_barrier = def_timing_barrier
                         ! flag indicating whether the mpi_barrier in
                         ! t_barrierf should be called

   integer, parameter :: def_timer_depth_limit = 99999         ! default
   integer, private   :: timer_depth_limit = def_timer_depth_limit
                         ! integer indicating maximum number of levels of
                         ! timer nesting 

   integer, parameter :: def_timing_detail_limit = 1           ! default
   integer, private   :: timing_detail_limit = def_timing_detail_limit
                         ! integer indicating maximum detail level to
                         ! profile

   integer, parameter :: init_timing_disable_depth = 0         ! init
   integer, private   :: timing_disable_depth = init_timing_disable_depth
                         ! integer indicating depth of t_disablef calls

   integer, parameter :: init_timing_detail = 0                ! init
   integer, private   :: cur_timing_detail = init_timing_detail
                         ! current timing detail level

   logical, parameter :: def_perf_single_file = .false.         ! default
   logical, private   :: perf_single_file = def_perf_single_file
                         ! flag indicating whether the performance timer
                         ! output should be written to a single file 
                         ! (per component communicator) or to a 
                         ! separate file for each process

   integer, parameter :: def_perf_outpe_num = 0                ! default
   integer, private   :: perf_outpe_num = def_perf_outpe_num
                         ! maximum number of processes writing out 
                         ! timing data (for this component communicator)

   integer, parameter :: def_perf_outpe_stride = 1             ! default
   integer, private   :: perf_outpe_stride = def_perf_outpe_stride
                         ! separation between process ids for processes
                         ! that are writing out timing data 
                         ! (for this component communicator)

   logical, parameter :: def_perf_global_stats = .true.        ! default
   logical, private   :: perf_global_stats = def_perf_global_stats
                         ! collect and print out global performance statistics
                         ! (for this component communicator)
#ifdef HAVE_MPI
   integer, parameter :: def_perf_timer = GPTLmpiwtime         ! default
#else
#ifdef CPRIBM
   integer,parameter :: def_perf_timer = GPTLread_real_time
#else
   integer,parameter :: def_perf_timer = GPTLgettimeofday
#endif
#endif
   integer, private   :: perf_timer = def_perf_timer           ! default
                         ! integer indicating which timer to use
                         ! (as defined in gptl.inc)

#ifdef HAVE_PAPI
   logical, parameter :: def_perf_papi_enable = .false.       ! default
#else
   logical, parameter :: def_perf_papi_enable = .false.       ! default
#endif
   logical, private   :: perf_papi_enable = def_perf_papi_enable
                         ! flag indicating whether the PAPI namelist
                         ! should be read and HW performance counters
                         ! used in profiling

   ! PAPI counter ids
   integer, parameter :: PAPI_NULL = -1

   integer, parameter :: def_papi_ctr1 = PAPI_NULL           ! default
   integer, private   :: papi_ctr1 = def_papi_ctr1

   integer, parameter :: def_papi_ctr2 = PAPI_NULL           ! default
   integer, private   :: papi_ctr2 = def_papi_ctr2

   integer, parameter :: def_papi_ctr3 = PAPI_NULL           ! default
   integer, private   :: papi_ctr3 = def_papi_ctr3

   integer, parameter :: def_papi_ctr4 = PAPI_NULL           ! default
   integer, private   :: papi_ctr4 = def_papi_ctr4

!=======================================================================
contains
!=======================================================================

!
!========================================================================
!
   subroutine t_getLogUnit(LogUnit)
!----------------------------------------------------------------------- 
! Purpose:  Get log unit number.
! Author:   P. Worley 
!-----------------------------------------------------------------------
!---------------------------Input arguments-----------------------------
!
   integer(SHR_KIND_IN), intent(OUT) :: LogUnit  ! Unit number for log output
!-----------------------------------------------------------------------

   LogUnit = p_logunit

   return
   end subroutine t_getLogUnit
!
!========================================================================
!
   subroutine t_setLogUnit(LogUnit)
!----------------------------------------------------------------------- 
! Purpose:  Set log unit number.
! Author:   P. Worley 
!-----------------------------------------------------------------------
!---------------------------Input arguments-----------------------------
!
   integer(SHR_KIND_IN), intent(IN) :: LogUnit  ! Unit number for log output
!-----------------------------------------------------------------------

   p_logunit = LogUnit
#ifndef USE_CSM_SHARE
   call perfutils_setunit(p_logunit)
#endif

   return
   end subroutine t_setLogUnit
!
!========================================================================
!
   subroutine perf_defaultopts(timing_disable_out, &
                               perf_timer_out, &
                               timer_depth_limit_out, &
                               timing_detail_limit_out, &
                               timing_barrier_out, &
                               perf_outpe_num_out, &
                               perf_outpe_stride_out, &
                               perf_single_file_out, &
                               perf_global_stats_out, &
                               perf_papi_enable_out )
!----------------------------------------------------------------------- 
! Purpose: Return default runtime options
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Input arguments-----------------------------
   ! timers disable/enable option
   logical, intent(out), optional :: timing_disable_out
   ! performance timer option
   integer, intent(out), optional :: perf_timer_out
   ! timer depth limit option
   integer, intent(out), optional :: timer_depth_limit_out
   ! timer detail limit option
   integer, intent(out), optional :: timing_detail_limit_out
   ! timing barrier enable/disable option
   logical, intent(out), optional :: timing_barrier_out
   ! number of processes writing out timing data
   integer, intent(out), optional :: perf_outpe_num_out
   ! separation between process ids for processes that are writing out timing data
   integer, intent(out), optional :: perf_outpe_stride_out
   ! timing single / multple output file option
   logical, intent(out), optional :: perf_single_file_out
   ! collect and output global performance statistics option
   logical, intent(out), optional :: perf_global_stats_out
   ! calling PAPI to read HW performance counters option
   logical, intent(out), optional :: perf_papi_enable_out
!-----------------------------------------------------------------------
   if ( present(timing_disable_out) ) then
      timing_disable_out = def_timing_disable
   endif
   if ( present(perf_timer_out) ) then
      perf_timer_out = def_perf_timer
   endif
   if ( present(timer_depth_limit_out) ) then
      timer_depth_limit_out = def_timer_depth_limit
   endif
   if ( present(timing_detail_limit_out) ) then
      timing_detail_limit_out = def_timing_detail_limit
   endif
   if ( present(timing_barrier_out) ) then
      timing_barrier_out = def_timing_barrier
   endif
   if ( present(perf_outpe_num_out) ) then
      perf_outpe_num_out = def_perf_outpe_num
   endif
   if ( present(perf_outpe_stride_out) ) then
      perf_outpe_stride_out = def_perf_outpe_stride
   endif
   if ( present(perf_single_file_out) ) then
      perf_single_file_out = def_perf_single_file
   endif
   if ( present(perf_global_stats_out) ) then
      perf_global_stats_out = def_perf_global_stats
   endif
   if ( present(perf_papi_enable_out) ) then
      perf_papi_enable_out = def_perf_papi_enable
   endif
!
   return
   end subroutine perf_defaultopts
!
!========================================================================
!
   subroutine perf_setopts(mastertask, &
                           LogPrint, &
                           timing_disable_in, &
                           perf_timer_in, &
                           timer_depth_limit_in, &
                           timing_detail_limit_in, &
                           timing_barrier_in, &
                           perf_outpe_num_in, &
                           perf_outpe_stride_in, &
                           perf_single_file_in, &
                           perf_global_stats_in, &
                           perf_papi_enable_in )
!----------------------------------------------------------------------- 
! Purpose: Set runtime options
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Input arguments----------------------------
!
   ! master process?
   logical, intent(in) :: mastertask
   ! Print out to log file?
   logical, intent(IN) :: LogPrint        
   ! timers disable/enable option
   logical, intent(in), optional :: timing_disable_in
   ! performance timer option
   integer, intent(in), optional :: perf_timer_in
   ! timer depth limit option
   integer, intent(in), optional :: timer_depth_limit_in
   ! timer detail limit option
   integer, intent(in), optional :: timing_detail_limit_in
   ! timing barrier enable/disable option
   logical, intent(in), optional :: timing_barrier_in
   ! number of processes writing out timing data
   integer, intent(in), optional :: perf_outpe_num_in
   ! separation between process ids for processes that are writing out timing data
   integer, intent(in), optional :: perf_outpe_stride_in
   ! timing single / multple output file option
   logical, intent(in), optional :: perf_single_file_in
   ! collect and output global performance statistics option
   logical, intent(in), optional :: perf_global_stats_in
   ! calling PAPI to read HW performance counters option
   logical, intent(in), optional :: perf_papi_enable_in
!
!---------------------------Local workspace-----------------------------
!
   integer  ierr                  ! error return
!-----------------------------------------------------------------------
   if ( .not. timing_initialized ) then

      if ( present(timing_disable_in) ) then
         timing_disable = timing_disable_in
         if (timing_disable) then
            ierr = GPTLdisable()
         else 
            ierr = GPTLenable()
         endif
      endif
      if ( present(perf_timer_in) ) then
         if ((perf_timer_in .eq. GPTLgettimeofday) .or. &
             (perf_timer_in .eq. GPTLnanotime) .or. &
             (perf_timer_in .eq. GPTLread_real_time) .or. &
             (perf_timer_in .eq. GPTLmpiwtime) .or. &
             (perf_timer_in .eq. GPTLclockgettime) .or. &
             (perf_timer_in .eq. GPTLpapitime)) then
            perf_timer = perf_timer_in
         else
            if (mastertask) then
               write(p_logunit,*) 'PERF_SETOPTS: illegal timer requested=',&
                                  perf_timer_in, '. Request ignored.'
            endif
         endif
      endif
      if ( present(timer_depth_limit_in) ) then
         timer_depth_limit = timer_depth_limit_in
      endif
      if ( present(timing_detail_limit_in) ) then
         timing_detail_limit = timing_detail_limit_in
      endif
      if ( present(timing_barrier_in) ) then
         timing_barrier = timing_barrier_in
      endif
      if ( present(perf_outpe_num_in) ) then
         perf_outpe_num = perf_outpe_num_in
      endif
      if ( present(perf_outpe_stride_in) ) then
         perf_outpe_stride = perf_outpe_stride_in
      endif
      if ( present(perf_single_file_in) ) then
         perf_single_file = perf_single_file_in
      endif
      if ( present(perf_global_stats_in) ) then
         perf_global_stats = perf_global_stats_in
      endif
      if ( present(perf_papi_enable_in) ) then
#ifdef HAVE_PAPI
         perf_papi_enable = perf_papi_enable_in
#else
         if (perf_papi_enable_in) then
            if (mastertask) then
               write(p_logunit,*) 'PERF_SETOPTS: PAPI library not linked in. ',&
                                  'Request to enable PAPI ignored.'
            endif
         endif
         perf_papi_enable = .false.
#endif
      endif
!
      if (mastertask .and. LogPrint) then
         write(p_logunit,*) '(t_initf) Using profile_disable=', timing_disable, &             
                            ' profile_timer=', perf_timer
         write(p_logunit,*) '(t_initf)  profile_depth_limit=', timer_depth_limit, &    
                            ' profile_detail_limit=', timing_detail_limit
         write(p_logunit,*) '(t_initf)  profile_barrier=', timing_barrier, &
                            ' profile_outpe_num=', perf_outpe_num
         write(p_logunit,*) '(t_initf)  profile_outpe_stride=', perf_outpe_stride , &
                            ' profile_single_file=', perf_single_file
         write(p_logunit,*) '(t_initf)  profile_global_stats=', perf_global_stats , &
                            ' profile_papi_enable=', perf_papi_enable 
      endif                                                                               
!
#ifdef DEBUG
   else
      write(p_logunit,*) 'PERF_SETOPTS: timing library already initialized. Request ignored.'
#endif
   endif
!
   return
   end subroutine perf_setopts

!
!========================================================================
!
   subroutine papi_defaultopts(papi_ctr1_out, &
                               papi_ctr2_out, &
                               papi_ctr3_out, &
                               papi_ctr4_out  )
!----------------------------------------------------------------------- 
! Purpose: Return default runtime PAPI counter options
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Input arguments-----------------------------
   ! PAPI counter option #1
   integer, intent(out), optional :: papi_ctr1_out
   ! PAPI counter option #2
   integer, intent(out), optional :: papi_ctr2_out
   ! PAPI counter option #3
   integer, intent(out), optional :: papi_ctr3_out
   ! PAPI counter option #4
   integer, intent(out), optional :: papi_ctr4_out
!-----------------------------------------------------------------------
   if ( present(papi_ctr1_out) ) then
      papi_ctr1_out = def_papi_ctr1
   endif
   if ( present(papi_ctr2_out) ) then
      papi_ctr2_out = def_papi_ctr2
   endif
   if ( present(papi_ctr3_out) ) then
      papi_ctr3_out = def_papi_ctr3
   endif
   if ( present(papi_ctr4_out) ) then
      papi_ctr4_out = def_papi_ctr4
   endif
!
   return
   end subroutine papi_defaultopts
!
!========================================================================
!
   subroutine papi_setopts(papi_ctr1_in, &
                           papi_ctr2_in, &
                           papi_ctr3_in, &
                           papi_ctr4_in  )
!----------------------------------------------------------------------- 
! Purpose: Set runtime PAPI counter options
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Input arguments----------------------------
!
   ! performance counter option
   integer, intent(in), optional :: papi_ctr1_in
   ! performance counter option
   integer, intent(in), optional :: papi_ctr2_in
   ! performance counter option
   integer, intent(in), optional :: papi_ctr3_in
   ! performance counter option
   integer, intent(in), optional :: papi_ctr4_in
!
!---------------------------Local workspace-----------------------------
!
   integer  ierr                  ! error return
!-----------------------------------------------------------------------
   if ( .not. timing_initialized ) then

      if ( present(papi_ctr1_in) ) then
         if (papi_ctr1_in < 0) then
            papi_ctr1 = papi_ctr1_in
         else
            papi_ctr1 = PAPI_NULL
         endif
      endif
      if ( present(papi_ctr2_in) ) then
         if (papi_ctr2_in < 0) then
            papi_ctr2 = papi_ctr2_in
         else
            papi_ctr2 = PAPI_NULL
         endif
      endif
      if ( present(papi_ctr3_in) ) then
         if (papi_ctr3_in < 0) then
            papi_ctr3 = papi_ctr3_in
         else
            papi_ctr3 = PAPI_NULL
         endif
      endif
      if ( present(papi_ctr4_in) ) then
         if (papi_ctr4_in < 0) then
            papi_ctr4 = papi_ctr4_in
         else
            papi_ctr4 = PAPI_NULL
         endif
      endif
!
#ifdef DEBUG
   else
      write(p_logunit,*) 'PAPI_SETOPTS: timing library already initialized. Request ignored.'
#endif
   endif
!
   return
   end subroutine papi_setopts
!
!========================================================================
!
   logical function t_profile_onf()
!----------------------------------------------------------------------- 
! Purpose: Return flag indicating whether profiling is currently active.
!          Part of workaround to implement FVbarrierclock before
!          communicators exposed in Pilgrim. Does not check level of
!          event nesting.
! Author: P. Worley 
!-----------------------------------------------------------------------

   if ((.not. timing_initialized) .or. &
       (timing_disable_depth > 0) .or. &
       (cur_timing_detail > timing_detail_limit)) then
      t_profile_onf = .false.
   else
      t_profile_onf = .true.
   endif

   end function t_profile_onf
!
!========================================================================
!
   logical function t_barrier_onf()
!----------------------------------------------------------------------- 
! Purpose: Return timing_barrier. Part of workaround to implement 
!          FVbarrierclock before communicators exposed in Pilgrim. 
! Author: P. Worley 
!-----------------------------------------------------------------------

   t_barrier_onf = timing_barrier

   end function t_barrier_onf
!
!========================================================================
!
   logical function t_single_filef()
!----------------------------------------------------------------------- 
! Purpose: Return perf_single_file. Used to control output of other
!          performance data, only spmdstats currently.
! Author: P. Worley 
!-----------------------------------------------------------------------

   t_single_filef = perf_single_file

   end function t_single_filef
!
!========================================================================
!
   subroutine t_stampf(wall, usr, sys)
!----------------------------------------------------------------------- 
! Purpose: Record wallclock, user, and system times (seconds).
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Output arguments-----------------------------
!
   real(shr_kind_r8), intent(out) :: wall ! wallclock time
   real(shr_kind_r8), intent(out) :: usr  ! user time
   real(shr_kind_r8), intent(out) :: sys  ! system time
!
!---------------------------Local workspace-----------------------------
!
   integer  ierr                          ! GPTL error return
!
!-----------------------------------------------------------------------
!
   if ((.not. timing_initialized) .or. &
       (timing_disable_depth > 0)) then
      wall = 0.0
      usr = 0.0
      sys = 0.0
   else
      ierr = GPTLstamp(wall, usr, sys)
   endif

   return
   end subroutine t_stampf
!
!========================================================================
!
   subroutine t_startf(event, handle)
!----------------------------------------------------------------------- 
! Purpose: Start an event timer
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Input arguments-----------------------------
!
   ! performance timer event name
   character(len=*), intent(in) :: event  
!
!---------------------------Input/Output arguments----------------------
!
   ! GPTL event handle
   integer(shr_kind_i8), optional :: handle
!
!---------------------------Local workspace-----------------------------
!
   integer  ierr                          ! GPTL error return
!
!-----------------------------------------------------------------------
!
   if ((timing_initialized) .and. &
       (timing_disable_depth .eq. 0) .and. &
       (cur_timing_detail .le. timing_detail_limit)) then

      if ( present (handle) ) then
         ierr = GPTLstart_handle(event, handle)
      else
         ierr = GPTLstart(event)
      endif

   endif

   return
   end subroutine t_startf
!
!========================================================================
!
   subroutine t_stopf(event, handle)
!----------------------------------------------------------------------- 
! Purpose: Stop an event timer
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Input arguments-----------------------------
!
   ! performance timer event name
   character(len=*), intent(in) :: event  
!
!---------------------------Input/Output arguments----------------------
!
   ! GPTL event handle
   integer(shr_kind_i8), optional :: handle
!
!---------------------------Local workspace-----------------------------
!
   integer  ierr                          ! GPTL error return
!
!-----------------------------------------------------------------------
!
   if ((timing_initialized) .and. &
       (timing_disable_depth .eq. 0) .and. &
       (cur_timing_detail .le. timing_detail_limit)) then

      if ( present (handle) ) then
         ierr = GPTLstop_handle(event, handle)
      else
         ierr = GPTLstop(event)
      endif

   endif

   return
   end subroutine t_stopf
!
!========================================================================
!
   subroutine t_enablef()
!----------------------------------------------------------------------- 
! Purpose: Enable t_startf, t_stopf, t_stampf, and t_barrierf. Ignored
!          in threaded regions.
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Local workspace-----------------------------
!
   integer  ierr                  ! GPTL error return
!
!---------------------------Externals-----------------------------------
!
#if ( defined _OPENMP )
   logical omp_in_parallel
   external omp_in_parallel
#endif
!
!-----------------------------------------------------------------------
!
   if (.not. timing_initialized) return

#if ( defined _OPENMP )
   if (omp_in_parallel()) return
#endif

   if (timing_disable_depth > 0) then
      if (timing_disable_depth .eq. 1) then
         ierr = GPTLenable()
      endif
      timing_disable_depth = timing_disable_depth - 1
   endif

   return
   end subroutine t_enablef
!
!========================================================================
!
   subroutine t_disablef()
!----------------------------------------------------------------------- 
! Purpose: Disable t_startf, t_stopf, t_stampf, and t_barrierf. Ignored
!          in threaded regions.
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Local workspace-----------------------------
!
   integer  ierr                  ! GPTL error return
!
!---------------------------Externals-----------------------------------
!
#if ( defined _OPENMP )
   logical omp_in_parallel
   external omp_in_parallel
#endif
!
!-----------------------------------------------------------------------
!
   if (.not. timing_initialized) return

#if ( defined _OPENMP )
   if (omp_in_parallel()) return
#endif

   if (timing_disable_depth .eq. 0) then
      ierr = GPTLdisable()
   endif
   timing_disable_depth = timing_disable_depth + 1

   return
   end subroutine t_disablef
!
!========================================================================
!
   subroutine t_adj_detailf(detail_adjustment)
!----------------------------------------------------------------------- 
! Purpose: Modify current detail level. Ignored in threaded regions.
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Input arguments-----------------------------
!
   integer, intent(in) :: detail_adjustment ! user defined increase or
                                            ! decrease in detail level
!
!---------------------------Externals-----------------------------------
!
#if ( defined _OPENMP )
   logical omp_in_parallel
   external omp_in_parallel
#endif
!
!-----------------------------------------------------------------------
!
   if (.not. timing_initialized) return

#if ( defined _OPENMP )
   if (omp_in_parallel()) return
#endif

   cur_timing_detail = cur_timing_detail + detail_adjustment

   return
   end subroutine t_adj_detailf
!
!========================================================================
!
   subroutine t_barrierf(event, mpicom)
!----------------------------------------------------------------------- 
! Purpose: Call (and time) mpi_barrier. Ignored inside OpenMP
!          threaded regions. Note that barrier executed even if
!          event not recorded because of level of timer event nesting.
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Input arguments-----------------------------
   ! mpi communicator id
   integer, intent(in), optional :: mpicom
   ! performance timer event name
   character(len=*), intent(in), optional :: event
!
!---------------------------Local workspace-----------------------------
!
   integer  ierr                  ! GPTL error return
!
!---------------------------Externals-----------------------------------
!
#if ( defined _OPENMP )
   logical omp_in_parallel
   external omp_in_parallel
#endif
!
!-----------------------------------------------------------------------
!
#if ( defined _OPENMP )
   if (omp_in_parallel()) return
#endif
   if ((timing_initialized) .and. &
       (timing_disable_depth .eq. 0) .and. &
       (cur_timing_detail .le. timing_detail_limit)) then

      if (timing_barrier) then

         if ( present (event) ) then
            ierr = GPTLstart(event)
         endif

         if ( present (mpicom) ) then
            call shr_mpi_barrier(mpicom, 'T_BARRIERF: bad mpi communicator')
         else
            call shr_mpi_barrier(MPI_COMM_WORLD, 'T_BARRIERF: bad mpi communicator')
         endif

         if ( present (event) ) then
            ierr = GPTLstop(event)
         endif

      endif

   endif

   return
   end subroutine t_barrierf
!
!========================================================================
!
   subroutine t_prf(filename, mpicom, num_outpe, stride_outpe, &
                    single_file, global_stats, output_thispe)
!----------------------------------------------------------------------- 
! Purpose: Write out performance timer data
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Input arguments-----------------------------
!
   ! performance timer output file name
   character(len=*), intent(in), optional :: filename
   ! mpi communicator id
   integer, intent(in), optional :: mpicom
   ! maximum number of processes writing out timing data
   integer, intent(in), optional :: num_outpe
   ! separation between process ids for processes writing out data 
   integer, intent(in), optional :: stride_outpe
   ! enable/disable the writing of data to a single file
   logical, intent(in), optional :: single_file
   ! enable/disable the collection of global statistics
   logical, intent(in), optional :: global_stats
   ! output timing data for this process
   logical, intent(in), optional :: output_thispe
!
!---------------------------Local workspace-----------------------------
!
   logical  one_file              ! flag indicting whether to write
                                  !  all data to a single file
   logical  glb_stats             ! flag indicting whether to compute
                                  !  global statistics
   logical  pr_write              ! flag indicating whether the current 
                                  !  GPTL output mode is write
   logical  write_data            ! flag indicating whether this process
                                  !  should output its timing data
   integer  i                     ! loop index
   integer  mpicom2               ! local copy of MPI communicator
   integer  me                    ! communicator local process id
   integer  npes                  ! local communicator group size
   integer  gme                   ! global process id
   integer  ierr                  ! MPI error return
   integer  outpe_num             ! max number of processes writing out
                                  !  timing data (excluding output_thispe)
   integer  outpe_stride          ! separation between process ids for
                                  !  processes writing out timing data
   integer  max_outpe             ! max process id for processes
                                  !  writing out timing data
   integer  signal                ! send/recv variable for single
                                  ! output file logic
   integer  str_length            ! string length
   integer  unitn                 ! file unit number
   integer cme_adj                ! length of filename suffix
   integer status (MPI_STATUS_SIZE)    ! Status of message
   character(len=7) cme                ! string representation of process id
   character(len=SHR_KIND_CX+14) fname ! timing output filename
!-----------------------------------------------------------------------
!
   if (.not. timing_initialized) return

   call t_startf("t_prf")
!$OMP MASTER
   call mpi_comm_rank(MPI_COMM_WORLD, gme, ierr)
   if ( present(mpicom) ) then
      mpicom2 = mpicom
      call mpi_comm_size(mpicom2, npes, ierr)
         if (ierr .eq. MPI_ERR_COMM) then
            call shr_sys_abort('T_PRF: bad mpi communicator')
         endif
      call mpi_comm_rank(mpicom2, me, ierr)
   else
      call mpi_comm_size(MPI_COMM_WORLD, npes, ierr)
      mpicom2 = MPI_COMM_WORLD
      me = gme
   endif

   do i=1,SHR_KIND_CX+14
     fname(i:i) = " "
   enddo

   unitn = shr_file_getUnit()

   ! determine what the current output mode is (append or write)
   ! if (GPTLpr_query_write() == 1) then
   !   pr_write = .true.
   !   ierr = GPTLpr_set_append()
   ! else
   pr_write=.false.
   ! endif

   ! Determine whether to write all data to a single fie
   if (present(single_file)) then
      one_file = single_file
   else
      one_file = perf_single_file
   endif

   ! Determine whether to compute global statistics
   if (present(global_stats)) then
      glb_stats = global_stats
   else
      glb_stats = perf_global_stats
   endif

   ! Determine which processes are writing out timing data
   write_data = .false.

   if (present(num_outpe)) then
      if (num_outpe < 0) then
         outpe_num = npes
      else
         outpe_num = num_outpe
      endif
   else
      if (perf_outpe_num < 0) then
         outpe_num = npes
      else
         outpe_num = perf_outpe_num
      endif
   endif

   if (present(stride_outpe)) then
      if (stride_outpe < 1) then
         outpe_stride = 1
      else
         outpe_stride = stride_outpe
      endif
   else
      if (perf_outpe_stride < 1) then
         outpe_stride = 1
      else
         outpe_stride = perf_outpe_stride
      endif
   endif

   max_outpe = min(outpe_num*outpe_stride, npes) - 1

   if ((mod(me, outpe_stride) .eq. 0) .and. (me .le. max_outpe)) &
      write_data = .true.

   if (present(output_thispe)) then
      write_data = output_thispe
   endif

   ! If a single timing output file, take turns writing to it.
   if (one_file) then

      if ( present(filename) ) then
         str_length = min(SHR_KIND_CX,len_trim(filename))
         fname(1:str_length) = filename(1:str_length)
      else
         fname(1:10) = "timing_all"
      endif

      signal = 0
      if (me .eq. 0) then

         if (glb_stats) then
            open( unitn, file=trim(fname), status='UNKNOWN' )
            write( unitn, 100) npes
 100        format(/,"***** GLOBAL STATISTICS (",I6," MPI TASKS) *****",/)
            close( unitn )

            ierr = GPTLpr_summary_file(mpicom2, trim(fname))
         endif

         if (write_data) then
            if (glb_stats) then
               open( unitn, file=trim(fname), status='OLD', position='APPEND' )
            else
               open( unitn, file=trim(fname), status='UNKNOWN' )
            endif

            write( unitn, 101) me, gme
 101        format(/,"************ PROCESS ",I6," (",I6,") ************",/)
            close( unitn )

            ierr = GPTLpr_file(trim(fname))
         endif

      else

         if (glb_stats) then
            ierr = GPTLpr_summary_file(mpicom2, trim(fname))
         endif

         call mpi_recv (signal, 1, mpi_integer, me-1, me-1, mpicom2, status, ierr)
         if (ierr /= mpi_success) then
            write(p_logunit,*) 'T_PRF: mpi_recv failed ierr=',ierr
            call shr_sys_abort()
         end if

         if (write_data) then
            open( unitn, file=trim(fname), status='OLD', position='APPEND' )
            write( unitn, 101) me, gme
            close( unitn )

            ierr = GPTLpr_file(trim(fname))
         endif

      endif

      if (me+1 < npes) &
         call mpi_send (signal, 1, mpi_integer, me+1, me, mpicom2, ierr)

   else

      if (glb_stats) then
         if ( present(filename) ) then
            str_length = min(SHR_KIND_CX-6,len_trim(filename))
            fname(1:str_length) = filename(1:str_length)
         else
            str_length = 6
            fname(1:10) = "timing"
         endif
         fname(str_length+1:str_length+6) = '_stats'

         if (me .eq. 0) then
            open( unitn, file=trim(fname), status='UNKNOWN' )
            write( unitn, 100) npes
            close( unitn )
         endif

         ierr = GPTLpr_summary_file(mpicom2, trim(fname))
         fname(str_length+1:str_length+6) = '      '
      endif

      if (write_data) then
         if (npes .le. 10) then
            write(cme,'(i1.1)') me
            cme_adj = 2
         elseif (npes .le. 100) then
            write(cme,'(i2.2)') me
            cme_adj = 3
         elseif (npes .le. 1000) then
            write(cme,'(i3.3)') me
            cme_adj = 4
         elseif (npes .le. 10000) then
            write(cme,'(i4.4)') me
            cme_adj = 5
         elseif (npes .le. 100000) then
            write(cme,'(i5.5)') me
            cme_adj = 6
         else
            write(cme,'(i6.6)') me
            cme_adj = 7
         endif

         if ( present(filename) ) then
            str_length = min(SHR_KIND_CX-cme_adj,len_trim(filename))
            fname(1:str_length) = filename(1:str_length)
         else
            str_length = 6
            fname(1:10) = "timing"
         endif
         fname(str_length+1:str_length+1) = '.'
         fname(str_length+2:str_length+cme_adj) = cme

         open( unitn, file=trim(fname), status='UNKNOWN' )
         write( unitn, 101) me, gme
         close( unitn )

         ierr = GPTLpr_file(trim(fname))
      endif

   endif

   call shr_file_freeUnit( unitn )

   ! reset GPTL output mode
   ! if (pr_write) then
   !   ierr = GPTLpr_set_write()
   ! endif

!$OMP END MASTER
   call t_stopf("t_prf")

   return
   end subroutine t_prf
!
!========================================================================
!
   subroutine t_initf(NLFilename, LogPrint, LogUnit, mpicom, MasterTask)
!----------------------------------------------------------------------- 
! Purpose:  Set default values of runtime timing options 
!           before namelists prof_inparm and papi_inparm are read,
!           read namelists (and broadcast, if SPMD),
!           then initialize timing library.
! Author:   P. Worley (based on shr_inputinfo_mod and runtime_opts)
!-----------------------------------------------------------------------
!---------------------------Input arguments-----------------------------
!
   character(len=*),   intent(IN) :: NLFilename      ! Name-list filename
   logical, optional,  intent(IN) :: LogPrint        ! If print out to log file
   integer, optional,  intent(IN) :: LogUnit         ! Unit number for log output
   integer, optional,  intent(IN) :: mpicom          ! MPI communicator
   logical, optional,  intent(IN) :: MasterTask      ! If MPI master task
!
!---------------------------Local workspace-----------------------------
!
   character(len=*), parameter    :: subname = '(T_INITF) '
   logical                        :: MasterTask2     ! If MPI master task
   logical                        :: LogPrint2       ! If print to log

   integer  me                    ! communicator local process id
   integer  ierr                  ! error return
   integer  unitn                 ! file unit number
   integer  papi_ctr1_id          ! PAPI counter id
   integer  papi_ctr2_id          ! PAPI counter id
   integer  papi_ctr3_id          ! PAPI counter id
   integer  papi_ctr4_id          ! PAPI counter id
!
!---------------------------Namelists ----------------------------------
!
   logical profile_disable
   logical profile_barrier
   logical profile_single_file
   logical profile_global_stats
   integer profile_depth_limit
   integer profile_detail_limit
   integer profile_outpe_num
   integer profile_outpe_stride
   integer profile_timer
   logical profile_papi_enable
   namelist /prof_inparm/ profile_disable, profile_barrier, &
                          profile_single_file, profile_global_stats, &
                          profile_depth_limit, &
                          profile_detail_limit, profile_outpe_num, &
                          profile_outpe_stride, profile_timer, &
                          profile_papi_enable

   character(len=16) papi_ctr1_str
   character(len=16) papi_ctr2_str
   character(len=16) papi_ctr3_str
   character(len=16) papi_ctr4_str
   namelist /papi_inparm/ papi_ctr1_str, papi_ctr2_str,  &
                          papi_ctr3_str, papi_ctr4_str
!-----------------------------------------------------------------------
    if ( timing_initialized ) then
#ifdef DEBUG
       write(p_logunit,*) 'T_INITF: timing library already initialized. Request ignored.'
#endif
       return
    endif

!$OMP MASTER
    if ( present(LogUnit) ) then
       call t_setLogUnit(LogUnit)
    else
       call t_setLogUnit(def_p_logunit)
    endif

    if ( present(MasterTask) .and. present(mpicom) )then
       call mpi_comm_rank(mpicom, me, ierr)
       if (ierr .eq. MPI_ERR_COMM) then
          call shr_sys_abort('T_INITF: bad mpi communicator')
       endif
       if (me .eq. 0) then
          MasterTask2 = .true.
       else
          MasterTask2 = .false.
       endif
    else
       MasterTask2 = .true.
    end if

    if ( present(LogPrint) ) then
       LogPrint2 = LogPrint
    else
       LogPrint2 = .true.
    endif

    ! Set PERF defaults, then override with user-specified input
    call perf_defaultopts(timing_disable_out=profile_disable, &
                          perf_timer_out=profile_timer, &
                          timer_depth_limit_out=profile_depth_limit, &
                          timing_detail_limit_out=profile_detail_limit, &
                          timing_barrier_out=profile_barrier, &
                          perf_outpe_num_out = profile_outpe_num, &
                          perf_outpe_stride_out = profile_outpe_stride, &
                          perf_single_file_out=profile_single_file, &
                          perf_global_stats_out=profile_global_stats, &
                          perf_papi_enable_out=profile_papi_enable )
    if ( MasterTask2 ) then

       ! Read in the prof_inparm namelist from NLFilename if it exists

       write(p_logunit,*) '(t_initf) Read in prof_inparm namelist from: '//trim(NLFilename)
       unitn = shr_file_getUnit()

       ierr = 1
       open( unitn, file=trim(NLFilename), status='old', iostat=ierr )
       if (ierr .eq. 0) then

          ! Look for prof_inparm group name in the input file.  
          ! If found, leave the file positioned at that namelist group.
          call find_group_name(unitn, 'prof_inparm', status=ierr)

          if (ierr == 0) then  ! found prof_inparm
             read(unitn, nml=prof_inparm, iostat=ierr)  
             if (ierr /= 0) then
                call shr_sys_abort( subname//':: namelist read returns an'// &
                                    ' error condition for prof_inparm' )
             end if
          end if

          close(unitn)

       endif
       call shr_file_freeUnit( unitn )

    endif

    ! This logic assumes that there will be only one MasterTask
    ! per communicator, and that this MasterTask is process 0.
    if ( present(MasterTask) .and. present(mpicom) )then
       call shr_mpi_bcast( profile_disable,      MPICom )
       call shr_mpi_bcast( profile_barrier,      MPICom )
       call shr_mpi_bcast( profile_single_file,  MPICom )
       call shr_mpi_bcast( profile_global_stats, MPICom )
       call shr_mpi_bcast( profile_papi_enable,  MPICom )
       call shr_mpi_bcast( profile_depth_limit,  MPICom )
       call shr_mpi_bcast( profile_detail_limit, MPICom )
       call shr_mpi_bcast( profile_outpe_num,    MPICom )
       call shr_mpi_bcast( profile_outpe_stride, MPICom )
       call shr_mpi_bcast( profile_timer,        MPICom )
    end if
    call perf_setopts    (MasterTask2, LogPrint2, &
                          timing_disable_in=profile_disable, &
                          perf_timer_in=profile_timer, &
                          timer_depth_limit_in=profile_depth_limit, &
                          timing_detail_limit_in=profile_detail_limit, &
                          timing_barrier_in=profile_barrier, &
                          perf_outpe_num_in=profile_outpe_num, &
                          perf_outpe_stride_in=profile_outpe_stride, &
                          perf_single_file_in=profile_single_file, &
                          perf_global_stats_in=profile_global_stats, &
                          perf_papi_enable_in=profile_papi_enable )

    ! Set PAPI defaults, then override with user-specified input
    if (perf_papi_enable) then
       call papi_defaultopts(papi_ctr1_out=papi_ctr1_id, &
                             papi_ctr2_out=papi_ctr2_id, &
                             papi_ctr3_out=papi_ctr3_id, &
                             papi_ctr4_out=papi_ctr4_id )

       if ( MasterTask2 ) then
          papi_ctr1_str = "PAPI_NO_CTR"
          papi_ctr2_str = "PAPI_NO_CTR"
          papi_ctr3_str = "PAPI_NO_CTR"
          papi_ctr4_str = "PAPI_NO_CTR"


          ! Read in the papi_inparm namelist from NLFilename if it exists

          write(p_logunit,*) '(t_initf) Read in papi_inparm namelist from: '//trim(NLFilename)
          unitn = shr_file_getUnit()

          ierr = 1
          open( unitn, file=trim(NLFilename), status='old', iostat=ierr )
          if (ierr .eq. 0) then
             ! Look for papi_inparm group name in the input file.  
             ! If found, leave the file positioned at that namelist group.
             call find_group_name(unitn, 'papi_inparm', status=ierr)

             if (ierr == 0) then  ! found papi_inparm
                read(unitn, nml=papi_inparm, iostat=ierr)  
                if (ierr /= 0) then
                   call shr_sys_abort( subname//':: namelist read returns an'// &
                                      ' error condition for papi_inparm' )
                end if
             end if

             close(unitn)

          endif
          call shr_file_freeUnit( unitn )

          ! if enabled and nothing set, use "defaults"
          if ((papi_ctr1_str(1:11) .eq. "PAPI_NO_CTR") .and. &
              (papi_ctr2_str(1:11) .eq. "PAPI_NO_CTR") .and. &
              (papi_ctr3_str(1:11) .eq. "PAPI_NO_CTR") .and. &
              (papi_ctr4_str(1:11) .eq. "PAPI_NO_CTR")) then
!pw              papi_ctr1_str = "PAPI_TOT_CYC"
!pw              papi_ctr2_str = "PAPI_TOT_INS"
!pw              papi_ctr3_str = "PAPI_FP_OPS"
!pw              papi_ctr4_str = "PAPI_FP_INS"
              papi_ctr1_str = "PAPI_FP_OPS"
          endif

          if (papi_ctr1_str(1:11) /= "PAPI_NO_CTR") then
             ierr = gptlevent_name_to_code(trim(papi_ctr1_str), papi_ctr1_id)
          endif
          if (papi_ctr2_str(1:11) /= "PAPI_NO_CTR") then
             ierr = gptlevent_name_to_code(trim(papi_ctr2_str), papi_ctr2_id)
          endif
          if (papi_ctr3_str(1:11) /= "PAPI_NO_CTR") then
             ierr = gptlevent_name_to_code(trim(papi_ctr3_str), papi_ctr3_id)
          endif
          if (papi_ctr4_str(1:11) /= "PAPI_NO_CTR") then
             ierr = gptlevent_name_to_code(trim(papi_ctr4_str), papi_ctr4_id)
          endif

       endif
       ! This logic assumes that there will be only one MasterTask
       ! per communicator, and that this MasterTask is process 0.
       if ( present(MasterTask) .and. present(mpicom) )then
          call shr_mpi_bcast( papi_ctr1_id,    MPICom )
          call shr_mpi_bcast( papi_ctr2_id,    MPICom )
          call shr_mpi_bcast( papi_ctr3_id,    MPICom )
          call shr_mpi_bcast( papi_ctr4_id,    MPICom )
       end if

       call papi_setopts    (papi_ctr1_in=papi_ctr1_id, &
                             papi_ctr2_in=papi_ctr2_id, &
                             papi_ctr3_in=papi_ctr3_id, &
                             papi_ctr4_in=papi_ctr4_id )
    endif
!$OMP END MASTER
!$OMP BARRIER

   if (timing_disable) return

!$OMP MASTER
   !
   ! Set options and initialize timing library.  
   ! 
   ! Set timer
   if (gptlsetutr (perf_timer) < 0) call shr_sys_abort (subname//':: gptlsetutr')
   !
   ! For logical settings, 2nd arg 0 
   ! to gptlsetoption means disable, non-zero means enable
   !
   ! Turn off CPU timing (expensive)
   !
   if (gptlsetoption (gptlcpu, 0) < 0) call shr_sys_abort (subname//':: gptlsetoption')
   !
   ! Set max timer depth
   !
   if (gptlsetoption (gptldepthlimit, timer_depth_limit) < 0) &
     call shr_sys_abort (subname//':: gptlsetoption')
   !
   ! Next 2 calls only work if PAPI is enabled.  These examples enable counting
   ! of total cycles and floating point ops, respectively
   !
   if (perf_papi_enable) then
      if (papi_ctr1 /= PAPI_NULL) then
         if (gptlsetoption (papi_ctr1, 1) < 0) call shr_sys_abort (subname//':: gptlsetoption')
      endif
      if (papi_ctr2 /= PAPI_NULL) then
         if (gptlsetoption (papi_ctr2, 1) < 0) call shr_sys_abort (subname//':: gptlsetoption')
      endif
      if (papi_ctr3 /= PAPI_NULL) then
         if (gptlsetoption (papi_ctr3, 1) < 0) call shr_sys_abort (subname//':: gptlsetoption')
      endif
      if (papi_ctr4 /= PAPI_NULL) then
         if (gptlsetoption (papi_ctr4, 1) < 0) call shr_sys_abort (subname//':: gptlsetoption')
      endif
   endif
   !
   ! Initialize the timing lib.  This call must occur after all gptlsetoption
   ! calls and before all other timing lib calls.
   !
   if (gptlinitialize () < 0) call shr_sys_abort (subname//':: gptlinitialize')
   timing_initialized = .true.
!$OMP END MASTER
!$OMP BARRIER

   return
   end subroutine t_initf
!
!========================================================================
!
   subroutine t_finalizef()
!----------------------------------------------------------------------- 
! Purpose: shut down timing library
! Author: P. Worley 
!-----------------------------------------------------------------------
!---------------------------Local workspace-----------------------------
!
   integer  ierr                  ! GPTL error return
!
!-----------------------------------------------------------------------
!
   if (.not. timing_initialized) return

!$OMP MASTER
   ierr = GPTLfinalize()
   timing_initialized = .false.
!$OMP END MASTER
!$OMP BARRIER

   return
   end subroutine t_finalizef

!===============================================================================

end module perf_mod
