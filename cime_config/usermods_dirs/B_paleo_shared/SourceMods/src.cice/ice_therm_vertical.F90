!  SVN:$Id: ice_therm_vertical.F90 915 2015-02-08 02:50:33Z tcraig $
!=========================================================================
!
! Update ice and snow internal temperatures and compute
! thermodynamic growth rates and atmospheric fluxes.
!
! NOTE: The thermodynamic calculation is split in two for load balancing.
!       First ice_therm_vertical computes vertical growth rates and coupler
!       fluxes.  Then ice_therm_itd does thermodynamic calculations not
!       needed for coupling.
!
! authors: William H. Lipscomb, LANL
!          C. M. Bitz, UW
!          Elizabeth C. Hunke, LANL
!
! 2003: Vectorized by Clifford Chen (Fujitsu) and William Lipscomb
! 2004: Block structure added by William Lipscomb
! 2006: Streamlined for efficiency by Elizabeth Hunke
!       Converted to free source form (F90)

      module ice_therm_vertical

      use ice_kinds_mod
      use ice_domain_size, only: ncat, nilyr, nslyr, max_ntrcr, max_blocks 
      use ice_calendar, only: istep1
      use ice_constants
      use ice_fileunits, only: nu_diag
      use ice_state, only: tr_iage, tr_pond_topo, nt_apnd, nt_hpnd, tr_pond, &
                           nt_Tsfc, nt_iage, nt_sice, nt_qice, nt_qsno, &
                           nt_apnd, nt_hpnd
      use ice_therm_shared, only: ktherm, ferrmax, heat_capacity, l_brine, &
                                  calc_Tsfc, calculate_tin_from_qin, Tmin
      use ice_therm_bl99, only: temperature_changes
      use ice_therm_0layer, only: zerolayer_temperature
      use ice_flux, only: Tf
      use ice_zbgc_shared, only: min_salin

      implicit none
      save

      private
      public :: init_thermo_vertical, frzmlt_bottom_lateral, thermo_vertical

      real (kind=dbl_kind), parameter, public :: &
         saltmax = 3.2_dbl_kind,   & ! max salinity at ice base for BL99 (ppt)
         ! phi_init and dSin0_frazil are used for mushy thermo, ktherm=2
         phi_init = 0.75_dbl_kind, & ! initial liquid fraction of frazil
         dSin0_frazil = c3 ! bulk salinity reduction of newly formed frazil

      real (kind=dbl_kind), public :: &
         ustar_min       ! minimum friction velocity for ice-ocean heat flux

      character (len=char_len), public :: &
         fbot_xfer_type  ! transfer coefficient type for ice-ocean heat flux

!=======================================================================

      contains

!=======================================================================
!
! Driver for updating ice and snow internal temperatures and
! computing thermodynamic growth rates and atmospheric fluxes.
!
! authors: William H. Lipscomb, LANL
!          C. M. Bitz, UW

      subroutine thermo_vertical (nx_block,    ny_block,  &
                                  dt,          icells,    &
                                  indxi,       indxj,     &
                                  aicen,       trcrn,     &
                                  vicen,       vsnon,     &
                                  flw,         potT,      &
                                  Qa,          rhoa,      &
                                  fsnow,       fpond,     &
                                  fbot,        Tbot,      &
                                  Tsnice, &
                                  sss,                    &
                                  lhcoef,      shcoef,    &
                                  fswsfc,      fswint,    &
                                  Sswabs,      Iswabs,    &
                                  fsurfn,      fcondtopn, &
                                  fcondbotn, &
                                  fsensn,      flatn,     &
                                  flwoutn,     evapn,     &
                                  evapin,      evapsn,    &
                                  freshn,      fsaltn,    &
                                  fhocnn,      meltt,     &
                                  melts,       meltb,     &
                                  congel,      snoice,    &
                                  mlt_onset,   frz_onset, &
                                  yday,        l_stop,    &
                                  istop,       jstop,     &
                                  dsnow)

      use ice_communicate, only: my_task
      use ice_therm_mushy, only: temperature_changes_salinity
#ifdef CESMCOUPLED
      use ice_prescribed_mod, only: prescribed_ice
#endif

      integer (kind=int_kind), intent(in) :: &
         nx_block, ny_block, & ! block dimensions
         icells                ! number of cells with ice present

      integer (kind=int_kind), dimension (nx_block*ny_block), &
         intent(in) :: &
         indxi, indxj     ! compressed indices for cells with ice

      real (kind=dbl_kind), intent(in) :: &
         dt      ! time step

      ! ice state variables
      real (kind=dbl_kind), dimension (nx_block,ny_block), &
         intent(inout) :: &
         aicen , & ! concentration of ice
         vicen , & ! volume per unit area of ice          (m)
         vsnon     ! volume per unit area of snow         (m)

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_ntrcr), &
         intent(inout) :: &
         trcrn

      ! input from atmosphere
      real (kind=dbl_kind), dimension (nx_block,ny_block), &
         intent(in) :: &
         flw     , & ! incoming longwave radiation (W/m^2)
         potT    , & ! air potential temperature  (K) 
         Qa      , & ! specific humidity (kg/kg) 
         rhoa    , & ! air density (kg/m^3) 
         fsnow   , & ! snowfall rate (kg m-2 s-1)
         shcoef  , & ! transfer coefficient for sensible heat
         lhcoef      ! transfer coefficient for latent heat

      real (kind=dbl_kind), dimension (nx_block,ny_block), &
         intent(inout) :: &
         fswsfc  , & ! SW absorbed at ice/snow surface (W m-2)
         fswint  , & ! SW absorbed in ice interior, below surface (W m-2)
         fpond       ! fresh water flux to ponds (kg/m^2/s)

      real (kind=dbl_kind), dimension (nx_block,ny_block,nslyr), &
         intent(inout) :: &
         Sswabs      ! SW radiation absorbed in snow layers (W m-2)

      real (kind=dbl_kind), dimension (nx_block,ny_block,nilyr), &
         intent(inout) :: &
         Iswabs      ! SW radiation absorbed in ice layers (W m-2)

      ! input from ocean
      real (kind=dbl_kind), dimension (nx_block,ny_block), intent(in) :: &
         fbot    , & ! ice-ocean heat flux at bottom surface (W/m^2)
         Tbot    , & ! ice bottom surface temperature (deg C)
         sss         ! ocean salinity

      ! coupler fluxes to atmosphere
      real (kind=dbl_kind), dimension (nx_block,ny_block), intent(out):: &
         flwoutn , & ! outgoing longwave radiation (W/m^2) 
         evapn   , & ! evaporative water flux (kg/m^2/s) 
         evapin   , & ! evaporative water flux (kg/m^2/s) 
         evapsn       ! evaporative water flux (kg/m^2/s) 

      ! Note: these are intent out if calc_Tsfc = T, otherwise intent in
      real (kind=dbl_kind), dimension (nx_block,ny_block), intent(inout):: &
         fsensn   , & ! sensible heat flux (W/m^2) 
         flatn    , & ! latent heat flux   (W/m^2) 
         fsurfn   , & ! net flux to top surface, excluding fcondtopn
         fcondtopn, & ! downward cond flux at top surface (W m-2)
         fcondbotn    ! downward cond flux at bottom surface (W m-2)

      ! coupler fluxes to ocean
      real (kind=dbl_kind), dimension (nx_block,ny_block), intent(out):: &
         freshn  , & ! fresh water flux to ocean (kg/m^2/s)
         fsaltn  , & ! salt flux to ocean (kg/m^2/s)
         fhocnn      ! net heat flux to ocean (W/m^2) 

      ! diagnostic fields
      real (kind=dbl_kind), dimension(nx_block,ny_block), &
         intent(inout):: &
         Tsnice    , & ! snow ice interface temperature (deg C)
         meltt    , & ! top ice melt             (m/step-->cm/day) 
         melts    , & ! snow melt                (m/step-->cm/day) 
         meltb    , & ! basal ice melt           (m/step-->cm/day) 
         congel   , & ! basal ice growth         (m/step-->cm/day) 
         snoice   , & ! snow-ice formation       (m/step-->cm/day) 
         dsnow    , & ! change in snow thickness (m/step-->cm/day) 
         mlt_onset, & ! day of year that sfc melting begins 
         frz_onset    ! day of year that freezing begins (congel or frazil) 

      real (kind=dbl_kind), intent(in) :: &
         yday      ! day of year

      logical (kind=log_kind), intent(out) :: &
         l_stop          ! if true, print diagnostics and abort on return

      integer (kind=int_kind), intent(out) :: &
         istop, jstop    ! indices of grid cell where code aborts

      ! local variables

      integer (kind=int_kind) :: &
         i, j        , & ! horizontal indices
         ij          , & ! horizontal index, combines i and j loops
         k               ! ice layer index

      real (kind=dbl_kind) :: &
         dhi         , & ! change in ice thickness
         dhs             ! change in snow thickness

! 2D state variables (thickness, temperature, enthalpy)

      real (kind=dbl_kind), dimension (icells) :: &
         hilyr       , & ! ice layer thickness
         hslyr       , & ! snow layer thickness
         Tsf         , & ! ice/snow top surface temp, same as Tsfcn (deg C)
         hin         , & ! ice thickness (m)
         hsn         , & ! snow thickness (m)
         hsn_new     , & ! thickness of new snow (m)
         worki       , & ! local work array
         works           ! local work array

      real (kind=dbl_kind), dimension (icells,nilyr) :: &
         zqin        , & ! ice layer enthalpy, zqin < 0 (J m-3)
         zTin        , & ! internal ice layer temperatures
         zSin            ! internal ice layer salinities

      real (kind=dbl_kind), dimension (icells,nslyr) :: &
         zqsn        , & ! snow layer enthalpy, zqsn < 0 (J m-3)
         zTsn            ! internal snow layer temperatures

! other 2D flux and energy variables

      real (kind=dbl_kind), dimension (icells) :: &
         einit       , & ! initial energy of melting (J m-2)
         efinal      , & ! final energy of melting (J m-2)
         einter          ! intermediate energy

! echmod: reduce size to icells?
      real (kind=dbl_kind), dimension (nx_block,ny_block) :: &
         iage    ! ice age (s)

      real (kind=dbl_kind), dimension (nx_block,ny_block) :: &
         fadvocn ! advective heat flux to ocean

      !-----------------------------------------------------------------
      ! Initialize
      !-----------------------------------------------------------------

      l_stop = .false.
      istop = 0
      jstop = 0

      do j=1, ny_block
      do i=1, nx_block
         flwoutn(i,j) = c0
         evapn  (i,j) = c0
         evapin  (i,j) = c0
         evapsn  (i,j) = c0

         freshn (i,j) = c0
         fsaltn (i,j) = c0
         fhocnn (i,j) = c0
         fadvocn(i,j) = c0

         meltt  (i,j) = c0
         meltb  (i,j) = c0
         melts  (i,j) = c0
         congel (i,j) = c0
         snoice (i,j) = c0
         dsnow  (i,j) = c0
         if (tr_iage) iage(i,j) = trcrn(i,j,nt_iage)
      enddo
      enddo

      if (calc_Tsfc) then
         do j=1, ny_block
         do i=1, nx_block
            fsensn   (i,j) = c0
            flatn    (i,j) = c0
            fsurfn   (i,j) = c0
            fcondtopn(i,j) = c0
            fcondbotn(i,j) = c0
         enddo
         enddo
      endif

      !-----------------------------------------------------------------
      ! Compute variables needed for vertical thermo calculation
      !-----------------------------------------------------------------

      call init_vertical_profile (nx_block,     ny_block,     &
                                  my_task,      istep1,       &
                                  icells,                     &
                                  indxi,        indxj,        &
                                  aicen(:,:),                 &
                                  vicen(:,:),   vsnon(:,:),   &
                                  trcrn(:,:,:),               &
                                  hin,          hilyr,        &
                                  hsn,          hslyr,        &
                                  zqin,         zTin,         &
                                  zqsn,         zTsn,         &
                                  zSin,                       &
                                  Tsf,          einit,        &
                                  Tbot,         l_stop,       &
                                  istop,        jstop)
      if (l_stop) return

      do ij = 1, icells
         ! Save initial ice and snow thickness (for fresh and fsalt)
         worki(ij) = hin(ij)
         works(ij) = hsn(ij)
      enddo

      !-----------------------------------------------------------------
      ! Compute new surface temperature and internal ice and snow
      !  temperatures.
      !-----------------------------------------------------------------

      if (heat_capacity) then   ! usual case

         if (ktherm == 2) then

            call temperature_changes_salinity(nx_block,      ny_block, &
                                              my_task,       istep1,   &
                                              dt,            icells,   & 
                                              indxi,         indxj,    &
                                              rhoa,          flw,      &
                                              potT,          Qa,       &
                                              shcoef,        lhcoef,   &
                                              fswsfc,        fswint,   &
                                              Sswabs,        Iswabs,   &
                                              hilyr,         hslyr,    &
                                              zqin,          zTin,     &
                                              zqsn,          zTsn,     &
                                              zSin,                    &
                                              trcrn,                   &
                                              Tsf,           Tbot,     &
                                              sss,                     &
                                              fsensn,        flatn,    &
                                              flwoutn,       fsurfn,   &
                                              fcondtopn,     fcondbotn, &
                                              fadvocn,       snoice,   &
                                              einit,         l_stop,   &
                                              istop,         jstop)

         else ! ktherm

            call temperature_changes(nx_block,      ny_block, &
                                     my_task,       istep1,   &
                                     dt,            icells,   & 
                                     indxi,         indxj,    &
                                     rhoa,          flw,      &
                                     potT,          Qa,       &
                                     shcoef,        lhcoef,   &
                                     fswsfc,        fswint,   &
                                     Sswabs,        Iswabs,   &
                                     hilyr,         hslyr,    &
                                     zqin,          zTin,     &
                                     zqsn,          zTsn,     &
                                     zSin,                    &
                                     Tsf,           Tbot,     &
                                     fsensn,        flatn,    &
                                     flwoutn,       fsurfn,   &
                                     fcondtopn,     fcondbotn, &
                                     einit,         l_stop,   &
                                     istop,         jstop)

         endif ! ktherm
            
      else

         if (calc_Tsfc) then       

            call zerolayer_temperature(nx_block,      ny_block, &
                                       my_task,       istep1,   &
                                       dt,            icells,   & 
                                       indxi,         indxj,    &
                                       rhoa,          flw,      &
                                       potT,          Qa,       &
                                       shcoef,        lhcoef,   &
                                       fswsfc,                  &
                                       hilyr,         hslyr,    &
                                       Tsf,           Tbot,     &
                                       fsensn,        flatn,    &
                                       flwoutn,       fsurfn,   &
                                       fcondtopn,     fcondbotn, &
                                       l_stop,                  &
                                       istop,         jstop)

         else

            !------------------------------------------------------------
            ! Set fcondbot = fcondtop for zero layer thermodynamics
            ! fcondtop is set in call to set_sfcflux in step_therm1
            !------------------------------------------------------------

            do ij = 1, icells
               i = indxi(ij)
               j = indxj(ij)
               fcondbotn(i,j)  = fcondtopn(i,j)   ! zero layer         
            enddo
      
         endif      ! calc_Tsfc

      endif         ! heat_capacity

            ! intermediate energy for error check
            do ij = 1, icells
               einter(ij) = c0
               do k = 1, nslyr
                  einter(ij) = einter(ij) + hslyr(ij) * zqsn(ij,k)
               enddo ! k
               do k = 1, nilyr
                  einter(ij) = einter(ij) + hilyr(ij) * zqin(ij,k)
               enddo ! k
            enddo ! ij

      if (l_stop) return
 
      ! Add snow-ice interface temperature diagnostic

      do ij = 1, icells
         i = indxi(ij)
         j = indxj(ij)

         Tsnice(i,j) = (hslyr(ij)*zTsn(ij,nslyr) + hilyr(ij)*zTin(ij,1)) &
                    / (hslyr(ij)+hilyr(ij))
      enddo

      !-----------------------------------------------------------------
      ! Compute growth and/or melting at the top and bottom surfaces.
      ! Add new snowfall.
      ! Repartition ice into equal-thickness layers, conserving energy.
      !----------------------------------------------------------------- 

         call thickness_changes(nx_block,     ny_block, &
                                dt,                     &
                                yday,         icells,   &
                                indxi,        indxj,    &
                                efinal,                 &
                                hin,          hilyr,    &
                                hsn,          hslyr,    &
                                zqin,         zqsn,     &
                                fbot,         Tbot,     &
                                flatn,        fsurfn,   &
                                fcondtopn,    fcondbotn, &
                                fsnow,        hsn_new,  &
                                fhocnn,       evapn,    &
                                evapin,       evapsn,   &
                                meltt,        melts,    &
                                meltb,        iage,     &
                                congel,       snoice,   &
                                mlt_onset,    frz_onset,&
                                zSin,         sss,      &
                                dsnow)

      !-----------------------------------------------------------------
      ! Check for energy conservation by comparing the change in energy
      ! to the net energy input
      !-----------------------------------------------------------------

        call conservation_check_vthermo(nx_block, ny_block, &
                                        my_task,  istep1,   &
                                        dt,       icells,   &
                                        indxi,    indxj,    &
                                        fsurfn,   flatn,    &
                                        fhocnn,   fswint,   &
                                        fsnow,    einit,    &
                                        einter,   efinal,   &
                                        fcondtopn,fcondbotn, &
                                        fadvocn,            &
                                        fbot,     l_stop,   &
                                        istop,    jstop)

      if (l_stop) return

      !-----------------------------------------------------------------
      ! If prescribed ice, set hi back to old values
      !-----------------------------------------------------------------

#ifdef CESMCOUPLED
      if (prescribed_ice) then
         do ij = 1, icells
            i = indxi(ij)
            j = indxj(ij)
            hin(ij) = worki(ij)
            fhocnn(i,j) = c0             ! for diagnostics
         enddo                  ! ij
      endif
#endif

      !-----------------------------------------------------------------
      ! Compute fluxes of water and salt from ice to ocean.
      ! evapn < 0 => sublimation, evapn > 0 => condensation
      ! aerosol flux is accounted for in ice_aerosol.F90
      !-----------------------------------------------------------------

      do ij = 1, icells
         i = indxi(ij)
         j = indxj(ij)
            
         dhi = hin(ij) - worki(ij)
         dhs = hsn(ij) - works(ij) - hsn_new(ij)
               
         freshn(i,j) = freshn(i,j) + &
                       evapn(i,j) - &
                       (rhoi*dhi + rhos*dhs) / dt
         fsaltn(i,j) = fsaltn(i,j) - &
                       rhoi*dhi*ice_ref_salinity*p001/dt

         fhocnn(i,j) = fhocnn(i,j) + fadvocn(i,j) ! for ktherm=2 

         if (hin(ij) == c0) then
            if (tr_pond_topo) &
            fpond(i,j) = fpond(i,j) - aicen(i,j) &
                       * trcrn(i,j,nt_apnd) * trcrn(i,j,nt_hpnd)
         endif

      enddo                     ! ij

      !-----------------------------------------------------------------
      !  Given the vertical thermo state variables, compute the new ice 
      !   state variables.
      !-----------------------------------------------------------------

         call update_state_vthermo(nx_block,     ny_block,   &
                                   icells,                   &
                                   indxi,        indxj,      &
                                   Tbot,         Tsf,        &     
                                   hin,          hsn,        &
                                   zqin,         zSin,       &
                                   zqsn,                     &
                                   aicen(:,:),               &
                                   vicen(:,:),   vsnon(:,:), &
                                   trcrn(:,:,:))

      !-----------------------------------------------------------------
      ! Reload passive tracer array
      !-----------------------------------------------------------------

      do j = 1, ny_block
      do i = 1, nx_block
         if (tr_iage) trcrn(i,j,nt_iage) = iage(i,j)
      enddo
      enddo

    end subroutine thermo_vertical

!=======================================================================
!
! Initialize the vertical profile of ice salinity and melting temperature.
!
! authors: C. M. Bitz, UW
!          William H. Lipscomb, LANL

      subroutine init_thermo_vertical

      use ice_blocks, only: nx_block, ny_block
      use ice_flux, only: salinz, Tmltz, sss

      integer (kind=int_kind) :: &
           i, j, iblk           ! horizontal indices

      real (kind=dbl_kind), parameter :: &
         nsal    = 0.407_dbl_kind, &
         msal    = 0.573_dbl_kind

      integer (kind=int_kind) :: k        ! ice layer index
      real (kind=dbl_kind)    :: zn       ! normalized ice thickness

      !-----------------------------------------------------------------
      ! Determine l_brine based on saltmax.
      ! Thermodynamic solver will not converge if l_brine is true and
      !  saltmax is close to zero.
      ! Set l_brine to false for zero layer thermodynamics
      !-----------------------------------------------------------------

      heat_capacity = .true.      
      if (ktherm == 0) heat_capacity = .false. ! 0-layer thermodynamics

      l_brine = .false.
      if (saltmax > min_salin .and. heat_capacity) l_brine = .true.

      !-----------------------------------------------------------------
      ! Prescibe vertical profile of salinity and melting temperature.
      ! Note this profile is only used for BL99 thermodynamics.
      !-----------------------------------------------------------------

      !$OMP PARALLEL DO PRIVATE(iblk,i,j,k,zn)
      do iblk = 1,max_blocks
      do j = 1, ny_block
      do i = 1, nx_block
      if (l_brine) then
         do k = 1, nilyr
            zn = (real(k,kind=dbl_kind)-p5) /  &
                  real(nilyr,kind=dbl_kind)
            salinz(i,j,k,iblk)=(saltmax/c2)*(c1-cos(pi*zn**(nsal/(msal+zn))))
            salinz(i,j,k,iblk) = max(salinz(i,j,k,iblk), min_salin)
            Tmltz (i,j,k,iblk) = -salinz(i,j,k,iblk)*depressT
         enddo ! k
         salinz(i,j,nilyr+1,iblk) = saltmax
         Tmltz(i,j,nilyr+1,iblk) = -salinz(i,j,nilyr+1,iblk)*depressT

      else ! .not. l_brine
         do k = 1, nilyr+1
            salinz(i,j,k,iblk) = c0
            Tmltz(i,j,k,iblk) = c0
         enddo
      endif ! l_brine

      enddo !i
      enddo !j
      enddo !iblk
      !$OMP END PARALLEL DO

      end subroutine init_thermo_vertical

!=======================================================================
!
! Compute heat flux to bottom surface.
! Compute fraction of ice that melts laterally.
!
! authors C. M. Bitz, UW
!         William H. Lipscomb, LANL
!         Elizabeth C. Hunke, LANL

      subroutine frzmlt_bottom_lateral (nx_block, ny_block, &
                                        ilo, ihi, jlo, jhi, &
                                        ntrcr,    dt,       &
                                        aice,     frzmlt,   &
                                        vicen,    vsnon,    &
                                        trcrn,              &
                                        sst,      Tf,       &
                                        strocnxT, strocnyT, &
                                        Tbot,     fbot,     &
                                        rside,    Cdn_ocn)

      integer (kind=int_kind), intent(in) :: &
         nx_block, ny_block, & ! block dimensions
         ilo,ihi,jlo,jhi   , & ! beginning and end of physical domain
         ntrcr                 ! number of tracers

      real (kind=dbl_kind), intent(in) :: &
         dt                  ! time step

      real (kind=dbl_kind), dimension(nx_block,ny_block), intent(in) :: &
         aice    , & ! ice concentration
         frzmlt  , & ! freezing/melting potential (W/m^2)
         sst     , & ! sea surface temperature (C)
         Tf      , & ! freezing temperature (C)
         Cdn_ocn , & ! ocean-ice neutral drag coefficient
         strocnxT, & ! ice-ocean stress, x-direction
         strocnyT    ! ice-ocean stress, y-direction

      real (kind=dbl_kind), dimension(nx_block,ny_block,ncat), &
         intent(in) :: &
         vicen   , & ! ice volume (m)
         vsnon       ! snow volume (m)

      real (kind=dbl_kind), dimension(nx_block,ny_block,ntrcr,ncat), &
         intent(in) :: &
         trcrn       ! tracer array

      real (kind=dbl_kind), dimension(nx_block,ny_block), &
         intent(out) :: &
         Tbot    , & ! ice bottom surface temperature (deg C)
         fbot    , & ! heat flux to ice bottom  (W/m^2)
         rside       ! fraction of ice that melts laterally

      ! local variables

      integer (kind=int_kind) :: &
         i, j           , & ! horizontal indices
         n              , & ! thickness category index
         k              , & ! layer index
         ij             , & ! horizontal index, combines i and j loops
         imelt              ! number of cells with ice melting

      integer (kind=int_kind), dimension (nx_block*ny_block) :: &
         indxi, indxj     ! compressed indices for cells with ice melting

      real (kind=dbl_kind), dimension (:), allocatable :: &
         etot    , & ! total energy in column
         fside       ! lateral heat flux (W/m^2)

      real (kind=dbl_kind) :: &
         deltaT    , & ! SST - Tbot >= 0
         ustar     , & ! skin friction velocity for fbot (m/s)
         wlat      , & ! lateral melt rate (m/s)
         xtmp          ! temporary variable

      ! Parameters for bottom melting

      real (kind=dbl_kind) :: &
         cpchr         ! -cp_ocn*rhow*exchange coefficient

      ! Parameters for lateral melting

      real (kind=dbl_kind), parameter :: &
         floediam = 300.0_dbl_kind, & ! effective floe diameter (m)
         floeshape = 0.66_dbl_kind , & ! constant from Steele (unitless)
         m1 = 1.6e-6_dbl_kind     , & ! constant from Maykut & Perovich
                                      ! (m/s/deg^(-m2))
         m2 = 1.36_dbl_kind           ! constant from Maykut & Perovich
                                      ! (unitless)

      do j = 1, ny_block
      do i = 1, nx_block
         rside(i,j) = c0
         Tbot (i,j) = Tf(i,j)
         fbot (i,j) = c0
      enddo
      enddo

      !-----------------------------------------------------------------
      ! Identify grid cells where ice can melt.
      !-----------------------------------------------------------------

      imelt = 0
      do j = jlo, jhi
      do i = ilo, ihi
         if (aice(i,j) > puny .and. frzmlt(i,j) < c0) then ! ice can melt
            imelt = imelt + 1
            indxi(imelt) = i
            indxj(imelt) = j
         endif
      enddo                     ! i
      enddo                     ! j

      allocate(etot (imelt))
      allocate(fside(imelt))

      do ij = 1, imelt  ! cells where ice can melt
         i = indxi(ij)
         j = indxj(ij)

         fside(ij) = c0

      !-----------------------------------------------------------------
      ! Use boundary layer theory for fbot.
      ! See Maykut and McPhee (1995): JGR, 100, 24,691-24,703.
      !-----------------------------------------------------------------

         deltaT = max((sst(i,j)-Tbot(i,j)),c0)

         ! strocnx has units N/m^2 so strocnx/rho has units m^2/s^2
         ustar = sqrt (sqrt(strocnxT(i,j)**2+strocnyT(i,j)**2)/rhow)
         ustar = max (ustar,ustar_min)

         if (trim(fbot_xfer_type) == 'Cdn_ocn') then
            ! Note: Cdn_ocn has already been used for calculating ustar 
            ! (formdrag only) --- David Schroeder (CPOM)
            cpchr = -cp_ocn*rhow*Cdn_ocn(i,j)
         else ! fbot_xfer_type == 'constant'
            ! 0.006 = unitless param for basal heat flx ala McPhee and Maykut
            cpchr = -cp_ocn*rhow*0.006_dbl_kind
         endif

         fbot(i,j) = cpchr * deltaT * ustar ! < 0

         fbot(i,j) = max (fbot(i,j), frzmlt(i,j)) ! frzmlt < fbot < 0

!!! uncomment to use all frzmlt for standalone runs
   !     fbot(i,j) = min (c0, frzmlt(i,j))

      !-----------------------------------------------------------------
      ! Compute rside.  See these references:
      !    Maykut and Perovich (1987): JGR, 92, 7032-7044
      !    Steele (1992): JGR, 97, 17,729-17,738
      !-----------------------------------------------------------------

         wlat = m1 * deltaT**m2 ! Maykut & Perovich
         rside(i,j) = wlat*dt*pi/(floeshape*floediam) ! Steele
         rside(i,j) = max(c0,min(rside(i,j),c1))

      enddo                     ! ij

      !-----------------------------------------------------------------
      ! Compute heat flux associated with this value of rside.
      !-----------------------------------------------------------------

      do n = 1, ncat

         do ij = 1, imelt
            etot(ij) = c0
         enddo

         ! melting energy/unit area in each column, etot < 0

         do k = 1, nslyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
            do ij = 1, imelt
               i = indxi(ij)
               j = indxj(ij)
               etot(ij) = etot(ij) + trcrn(i,j,nt_qsno+k-1,n) &
                                   * vsnon(i,j,n)/real(nslyr,kind=dbl_kind)
            enddo               ! ij
         enddo

         do k = 1, nilyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
            do ij = 1, imelt
               i = indxi(ij)
               j = indxj(ij)
               etot(ij) = etot(ij) + trcrn(i,j,nt_qice+k-1,n) &
                                   * vicen(i,j,n)/real(nilyr,kind=dbl_kind)
            enddo               ! ij
         enddo                  ! nilyr

!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, imelt
            i = indxi(ij)
            j = indxj(ij)
            ! lateral heat flux
            fside(ij) = fside(ij) + rside(i,j)*etot(ij)/dt ! fside < 0
         enddo                  ! ij

      enddo                     ! n

      !-----------------------------------------------------------------
      ! Limit bottom and lateral heat fluxes if necessary.
      !-----------------------------------------------------------------

!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
      do ij = 1, imelt
         i = indxi(ij)
         j = indxj(ij)

         xtmp = frzmlt(i,j)/(fbot(i,j) + fside(ij) + puny) 
         xtmp = min(xtmp, c1)
         fbot (i,j) = fbot (i,j) * xtmp
         rside(i,j) = rside(i,j) * xtmp
      enddo                     ! ij

      deallocate(etot)
      deallocate(fside)

      end subroutine frzmlt_bottom_lateral

!=======================================================================
!
! Given the state variables (vicen, vsnon, trcrn)
! compute variables needed for the vertical thermodynamics
! (hin, hsn, zqin, zqsn, zTin, zTsn, Tsf).
!
! authors William H. Lipscomb, LANL
!         C. M. Bitz, UW

      subroutine init_vertical_profile(nx_block, ny_block, &
                                       my_task,  istep1,   &
                                       icells,             &
                                       indxi,    indxj,    &
                                       aicen,    vicen,    &
                                       vsnon,    trcrn,    &
                                       hin,      hilyr,    &
                                       hsn,      hslyr,    &
                                       zqin,     zTin,     &
                                       zqsn,     zTsn,     &
                                       zSin,               &
                                       Tsf,      einit,    &
                                       Tbot,     l_stop,   &
                                       istop,    jstop)

      use ice_therm_mushy, only: temperature_mush, &
                                 liquidus_temperature_mush, &
                                 enthalpy_of_melting

      integer (kind=int_kind), intent(in) :: &
         nx_block, ny_block, & ! block dimensions
         my_task           , & ! task number (diagnostic only)
         istep1            , & ! time step index (diagnostic only)
         icells                ! number of cells with aicen > puny

      integer (kind=int_kind), dimension(nx_block*ny_block), &
         intent(in) :: &
         indxi, indxj    ! compressed indices for cells with aicen > puny

      real (kind=dbl_kind), dimension (nx_block,ny_block), intent(in) :: &
         aicen , & ! concentration of ice
         vicen , & ! volume per unit area of ice          (m)
         vsnon     ! volume per unit area of snow         (m)
 
      real (kind=dbl_kind), dimension (nx_block,ny_block,max_ntrcr), &
         intent(in) :: &
         trcrn     ! tracer array

      real (kind=dbl_kind), dimension(icells), intent(out):: &
         hilyr       , & ! ice layer thickness
         hslyr       , & ! snow layer thickness
         Tsf         , & ! ice/snow surface temperature, Tsfcn
         einit           ! initial energy of melting (J m-2)
 
      real (kind=dbl_kind), dimension(nx_block,ny_block), intent(in):: &
         Tbot            ! bottom ice temp  (C)

      real (kind=dbl_kind), dimension(icells), intent(out):: &
         hin         , & ! ice thickness (m)
         hsn             ! snow thickness (m)

      real (kind=dbl_kind), dimension (icells,nilyr), &
         intent(out) :: &
         zqin        , & ! ice layer enthalpy (J m-3)
         zTin        , & ! internal ice layer temperatures
         zSin            ! internal ice layer salinities

      real (kind=dbl_kind), dimension (icells,nslyr), &
         intent(out) :: &
         zqsn        , & ! snow enthalpy
         zTsn            ! snow temperature

      logical (kind=log_kind), intent(inout) :: &
         l_stop          ! if true, print diagnostics and abort model

      integer (kind=int_kind), intent(inout) :: &
         istop, jstop    ! i and j indices of cell where model fails

      ! local variables
      real (kind=dbl_kind), dimension(icells,nilyr) :: &
         Tmlts           ! melting temperature

      integer (kind=int_kind) :: &
         i, j        , & ! horizontal indices
         ij          , & ! horizontal index, combines i and j loops
         k               ! ice layer index

      real (kind=dbl_kind) :: &
         rnslyr,       & ! real(nslyr)
         Tmax            ! maximum allowed snow/ice temperature (deg C)

      logical (kind=log_kind) :: &   ! for vector-friendly error checks
         tsno_high   , & ! flag for zTsn > Tmax
         tice_high   , & ! flag for zTin > Tmlt
         tsno_low    , & ! flag for zTsn < Tmin
         tice_low        ! flag for zTin < Tmin

      !-----------------------------------------------------------------
      ! Initialize
      !-----------------------------------------------------------------

      rnslyr = real(nslyr,kind=dbl_kind)

      do ij = 1, icells
         einit(ij) = c0
      enddo

      tsno_high = .false.
      tice_high = .false.
      tsno_low  = .false.
      tice_low  = .false.

      !-----------------------------------------------------------------
      ! Load arrays for vertical thermo calculation.
      !-----------------------------------------------------------------

!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
      do ij = 1, icells
         i = indxi(ij)
         j = indxj(ij)

      !-----------------------------------------------------------------
      ! Surface temperature, ice and snow thickness
      ! Initialize internal energy
      !-----------------------------------------------------------------

         Tsf(ij)    = trcrn(i,j,nt_Tsfc)
         hin(ij)    = vicen(i,j) / aicen(i,j)
         hsn(ij)    = vsnon(i,j) / aicen(i,j)
         hilyr(ij)    = hin(ij) / real(nilyr,kind=dbl_kind)
         hslyr(ij)    = hsn(ij) / rnslyr

      enddo                     ! ij

      !-----------------------------------------------------------------
      ! Snow enthalpy and maximum allowed snow temperature
      ! If heat_capacity = F, zqsn and zTsn are used only for checking
      ! conservation.
      !-----------------------------------------------------------------

      do k = 1, nslyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells
            i = indxi(ij)
            j = indxj(ij)

      !-----------------------------------------------------------------
      ! Tmax based on the idea that dT ~ dq / (rhos*cp_ice)
      !                             dq ~ q dv / v
      !                             dv ~ puny = eps11
      ! where 'd' denotes an error due to roundoff.
      !-----------------------------------------------------------------

            if (hslyr(ij) > hs_min/rnslyr .and. heat_capacity) then
               ! zqsn < 0              
               zqsn(ij,k) = trcrn(i,j,nt_qsno+k-1)
               Tmax = -zqsn(ij,k)*puny*rnslyr / &
                       (rhos*cp_ice*vsnon(i,j))
            else
               zqsn  (ij,k) = -rhos * Lfresh
               Tmax = puny
            endif

      !-----------------------------------------------------------------
      ! Compute snow temperatures from enthalpies.
      ! Note: zqsn <= -rhos*Lfresh, so zTsn <= 0.
      !-----------------------------------------------------------------
            zTsn(ij,k) = (Lfresh + zqsn(ij,k)/rhos)/cp_ice

      !-----------------------------------------------------------------
      ! Check for zTsn > Tmax (allowing for roundoff error) and zTsn < Tmin.
      !-----------------------------------------------------------------
            if (zTsn(ij,k) > Tmax) then
               tsno_high = .true.
            elseif (zTsn(ij,k) < Tmin) then
               tsno_low  = .true.
            endif

         enddo                  ! ij
      enddo                     ! nslyr

      !-----------------------------------------------------------------
      ! If zTsn is out of bounds, print diagnostics and exit.
      !-----------------------------------------------------------------

      if (tsno_high .and. heat_capacity) then
         do k = 1, nslyr
            do ij = 1, icells
               i = indxi(ij)
               j = indxj(ij)

               if (hslyr(ij) > hs_min/rnslyr) then
                  Tmax = -zqsn(ij,k)*puny*rnslyr / &
                           (rhos*cp_ice*vsnon(i,j))
               else
                  Tmax = puny
               endif

               if (zTsn(ij,k) > Tmax) then
                  write(nu_diag,*) ' '
                  write(nu_diag,*) 'Starting thermo, zTsn > Tmax'
                  write(nu_diag,*) 'zTsn=',zTsn(ij,k)
                  write(nu_diag,*) 'Tmax=',Tmax
                  write(nu_diag,*) 'istep1, my_task, i, j:', &
                                    istep1, my_task, i, j
                  write(nu_diag,*) 'zqsn',zqsn(ij,k),-Lfresh*rhos,zqsn(ij,k)+Lfresh*rhos
                  l_stop = .true.
                  istop = i
                  jstop = j
                  return
               endif

            enddo               ! ij
         enddo                  ! nslyr
      endif                     ! tsno_high

      if (tsno_low .and. heat_capacity) then
         do k = 1, nslyr
            do ij = 1, icells
               i = indxi(ij)
               j = indxj(ij)

               if (zTsn(ij,k) < Tmin) then ! allowing for roundoff error
                  write(nu_diag,*) ' '
                  write(nu_diag,*) 'Starting thermo, zTsn < Tmin'
                  write(nu_diag,*) 'zTsn=', zTsn(ij,k)
                  write(nu_diag,*) 'Tmin=', Tmin
                  write(nu_diag,*) 'istep1, my_task, i, j:', &
                                    istep1, my_task, i, j
                  write(nu_diag,*) 'zqsn', zqsn(ij,k)
                  write(nu_diag,*) hin(ij)
                  write(nu_diag,*) hsn(ij)
                  write(nu_diag,*) 0, Tsf(ij)
                  l_stop = .true.
                  istop = i
                  jstop = j
                  return
               endif

            enddo               ! ij
         enddo                  ! nslyr
      endif                     ! tsno_low

      do k = 1, nslyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells

            if (zTsn(ij,k) > c0) then   ! correct roundoff error
               zTsn(ij,k) = c0
               zqsn(ij,k) = -rhos*Lfresh
            endif

      !-----------------------------------------------------------------
      ! initial energy per unit area of ice/snow, relative to 0 C
      !-----------------------------------------------------------------
            einit(ij) = einit(ij) + hslyr(ij)*zqsn(ij,k)

         enddo                  ! ij
      enddo                     ! nslyr

      do k = 1, nilyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells
            i = indxi(ij)
            j = indxj(ij)

      !---------------------------------------------------------------------
      !  Use initial salinity profile for thin ice
      !---------------------------------------------------------------------

            zSin(ij,k) = trcrn(i,j,nt_sice+k-1)
            if (ktherm == 1 .and. zSin(ij,k) < min_salin-puny) then
                  write(nu_diag,*) ' '
                  write(nu_diag,*) 'Starting zSin < min_salin, layer', k
                  write(nu_diag,*) 'zSin =', zSin(ij,k)
                  write(nu_diag,*) 'min_salin =', min_salin
                  write(nu_diag,*) 'istep1, my_task, i, j:', &
                                    istep1, my_task, i, j
                  l_stop = .true.
                  istop = i
                  jstop = j
                  return
            endif

            if (ktherm == 2) then
               Tmlts(ij,k) = liquidus_temperature_mush(zSin(ij,k))
            else
               Tmlts(ij,k) = -zSin(ij,k) * depressT
            endif

      !-----------------------------------------------------------------
      ! Compute ice enthalpy
      ! If heat_capacity = F, zqin and zTin are used only for checking
      ! conservation.
      !-----------------------------------------------------------------
            ! zqin < 0
            zqin(ij,k) = trcrn(i,j,nt_qice+k-1)

      !-----------------------------------------------------------------
      ! Compute ice temperatures from enthalpies using quadratic formula
      !-----------------------------------------------------------------

            if (ktherm == 2) then
               zTin(ij,k) = temperature_mush(zqin(ij,k),zSin(ij,k))
            else
               zTin(ij,k) = calculate_Tin_from_qin(zqin(ij,k),Tmlts(ij,k))
            endif

            if (l_brine) then
               Tmax = Tmlts(ij,k)
            else                ! fresh ice
               Tmax = -zqin(ij,k)*puny/(rhos*cp_ice*vicen(i,j))
            endif

      !-----------------------------------------------------------------
      ! Check for zTin > Tmax and zTin < Tmin
      !-----------------------------------------------------------------
            if (zTin(ij,k) > Tmax) then
               tice_high = .true.
            elseif (zTin(ij,k) < Tmin) then
               tice_low  = .true.
            endif

         enddo                  ! ij

      !-----------------------------------------------------------------
      ! If zTin is out of bounds, print diagnostics and exit.
      !-----------------------------------------------------------------

         if (tice_high .and. heat_capacity) then
            do ij = 1, icells
               i = indxi(ij)
               j = indxj(ij)

               if (l_brine) then
                  Tmax = Tmlts(ij,k)
               else             ! fresh ice
                  Tmax = -zqin(ij,k)*puny/(rhos*cp_ice*vicen(i,j))
               endif

               if (zTin(ij,k) > Tmax) then
                     write(nu_diag,*) ' '
                     write(nu_diag,*) 'Starting thermo, T > Tmax, layer', k
                     write(nu_diag,*) 'istep1, my_task, i, j, k:', &
                                       istep1, my_task, i, j, k
                     write(nu_diag,*) 'zTin =',zTin(ij,k),', Tmax=',Tmax
                     write(nu_diag,*) 'zSin =',zSin(ij,k)
                     write(nu_diag,*) 'hin =',hin(ij)
                     write(nu_diag,*) 'zqin =',zqin(ij,k)
                     write(nu_diag,*) 'qmlt=',enthalpy_of_melting(zSin(ij,k))
                     write(nu_diag,*) 'Tmlt=',Tmlts(ij,k)

                  if (ktherm == 2) then
                     zqin(ij,k) = enthalpy_of_melting(zSin(ij,k)) - c1
                     zTin(ij,k) = temperature_mush(zqin(ij,k),zSin(ij,k))
                     write(nu_diag,*) 'Corrected quantities'
                     write(nu_diag,*) 'zqin=',zqin(ij,k)
                     write(nu_diag,*) 'zTin=',zTin(ij,k)
                  else
                     l_stop = .true.
                     istop = i
                     jstop = j
                     return
                  endif
               endif
            enddo               ! ij
         endif                  ! tice_high

         if (tice_low .and. heat_capacity) then
            do ij = 1, icells
               i = indxi(ij)
               j = indxj(ij)

               if (zTin(ij,k) < Tmin) then
                  write(nu_diag,*) ' '
                  write(nu_diag,*) 'Starting thermo T < Tmin, layer', k
                  write(nu_diag,*) 'zTin =', zTin(ij,k)
                  write(nu_diag,*) 'Tmin =', Tmin
                  write(nu_diag,*) 'istep1, my_task, i, j:', &
                                    istep1, my_task, i, j
                  l_stop = .true.
                  istop = i
                  jstop = j
                  return
               endif
            enddo               ! ij
         endif                  ! tice_low

      !-----------------------------------------------------------------
      ! correct roundoff error
      !-----------------------------------------------------------------

         if (ktherm /= 2) then
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
            do ij = 1, icells
               if (zTin(ij,k) > c0) then
                   zTin(ij,k) = c0
                   zqin(ij,k) = -rhoi*Lfresh
               endif
            enddo                  ! ij
         endif

! echmod: is this necessary?
!         if (ktherm == 1) then
!!DIR$ CONCURRENT !Cray
!!cdir nodep      !NEC
!!ocl novrec      !Fujitsu
!            do ij = 1, icells
!               if (zTin(ij,k)>= -zSin(ij,k)*depressT) then
!                   zTin(ij,k) = -zSin(ij,k)*depressT - puny
!                   zqin(ij,k) = -rhoi*cp_ocn*zSin(ij,k)*depressT
!               endif
!            enddo                  ! ij
!         endif

      !-----------------------------------------------------------------
      ! initial energy per unit area of ice/snow, relative to 0 C
      !-----------------------------------------------------------------

!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells
            einit(ij) = einit(ij) + hilyr(ij)*zqin(ij,k) 
         enddo                  ! ij

      enddo                     ! nilyr

      end subroutine init_vertical_profile

!=======================================================================
!
! Compute growth and/or melting at the top and bottom surfaces.
! Convert snow to ice if necessary.
!
! authors William H. Lipscomb, LANL
!         C. M. Bitz, UW

      subroutine thickness_changes (nx_block,  ny_block, &
                                    dt,                  &
                                    yday,      icells,   &
                                    indxi,     indxj,    &
                                    efinal,              & 
                                    hin,       hilyr,    &
                                    hsn,       hslyr,    &
                                    zqin,      zqsn,     &
                                    fbot,      Tbot,     &
                                    flatn,     fsurfn,   &
                                    fcondtopn, fcondbotn, &
                                    fsnow,     hsn_new,  &
                                    fhocnn,    evapn,    &
                                    evapin,    evapsn,   &
                                    meltt,     melts,    &
                                    meltb,     iage,     &
                                    congel,    snoice,   &  
                                    mlt_onset, frz_onset,&
                                    zSin,      sss,      &
                                    dsnow)

      use ice_therm_mushy, only: enthalpy_mush, enthalpy_of_melting, &
                           phi_i_mushy, temperature_mush, &
                           liquidus_temperature_mush, liquid_fraction

      integer (kind=int_kind), intent(in) :: &
         nx_block, ny_block, & ! block dimensions
         icells          ! number of cells with aicen > puny

      integer (kind=int_kind), dimension(nx_block*ny_block), &
         intent(in) :: &
         indxi, indxj    ! compressed indices for cells with aicen > puny

      real (kind=dbl_kind), intent(in) :: &
         dt          , & ! time step
         yday            ! day of the year

      real (kind=dbl_kind), dimension (nx_block,ny_block), intent(in) :: &
         fbot        , & ! ice-ocean heat flux at bottom surface (W/m^2)
         Tbot        , & ! ice bottom surface temperature (deg C)
         fsnow       , & ! snowfall rate (kg m-2 s-1)
         flatn       , & ! surface downward latent heat (W m-2)
         fsurfn      , & ! net flux to top surface, excluding fcondtopn
         fcondtopn   , & ! downward cond flux at top surface (W m-2)
         fcondbotn       ! downward cond flux at bottom surface (W m-2)

      real (kind=dbl_kind), dimension (icells,nilyr), &
         intent(inout) :: &
         zqin            ! ice layer enthalpy (J m-3)

      real (kind=dbl_kind), dimension (icells,nslyr), &
         intent(inout) :: &
         zqsn            ! snow layer enthalpy (J m-3)

      real (kind=dbl_kind), dimension (icells), &
         intent(inout) :: &
         hilyr       , & ! ice layer thickness (m)
         hslyr           ! snow layer thickness (m)

      real (kind=dbl_kind), dimension (nx_block,ny_block), &
         intent(inout) :: &
         meltt       , & ! top ice melt             (m/step-->cm/day)
         melts       , & ! snow melt                (m/step-->cm/day)
         meltb       , & ! basal ice melt           (m/step-->cm/day)
         congel      , & ! basal ice growth         (m/step-->cm/day)
         snoice      , & ! snow-ice formation       (m/step-->cm/day)
         dsnow       , & ! snow  formation          (m/step-->cm/day)
         iage        , & ! ice age (s)
         mlt_onset   , & ! day of year that sfc melting begins
         frz_onset       ! day of year that freezing begins (congel or frazil)

      real (kind=dbl_kind), dimension (icells), &
         intent(inout) :: &
         hin         , & ! total ice thickness (m)
         hsn             ! total snow thickness (m)

      real (kind=dbl_kind), dimension (icells), intent(out):: &
         efinal          ! final energy of melting (J m-2)

      real (kind=dbl_kind), dimension (nx_block,ny_block), intent(out):: &
         fhocnn      , & ! fbot, corrected for any surplus energy (W m-2)
         evapn       , & ! ice/snow mass sublimated/condensed (kg m-2 s-1)
         evapin       , & ! ice mass sublimated/condensed (kg m-2 s-1)
         evapsn           ! snow mass sublimated/condensed (kg m-2 s-1)

      real (kind=dbl_kind), dimension (icells), intent(out):: &
         hsn_new         ! thickness of new snow (m)

      ! changes to zSin in this subroutine are not reloaded into the
      ! trcrn array for ktherm /= 2, so we could remove ktherm=2 conditionals
      real (kind=dbl_kind), dimension (icells,nilyr), &
         intent(inout) :: &
         zSin            ! ice layer salinity (ppt)

      real (kind=dbl_kind), dimension (nx_block,ny_block), &
         intent(in) :: &
         sss             ! ocean salinity (PSU) 

      ! local variables

      real (kind=dbl_kind), parameter :: &
         qbotmax = -p5*rhoi*Lfresh  ! max enthalpy of ice growing at bottom

      integer (kind=int_kind) :: &
         i, j        , & ! horizontal indices
         ij          , & ! horizontal index, combines i and j loops
         k               ! vertical index

      real (kind=dbl_kind), dimension (icells) :: &
         esub        , & ! energy for sublimation, > 0    (J m-2)
         econ        , & ! energy for condensation, < 0   (J m-2)
         etop_mlt    , & ! energy for top melting, > 0    (J m-2)
         ebot_mlt    , & ! energy for bottom melting, > 0 (J m-2)
         ebot_gro    , & ! energy for bottom growth, < 0  (J m-2)
         emlt_atm    , & ! total energy of brine, from atmosphere (J m-2)
         emlt_ocn        ! total energy of brine, to ocean        (J m-2)

      real (kind=dbl_kind) :: &
         dhi         , & ! change in ice thickness
         dhs         , & ! change in snow thickness
         Ti          , & ! ice temperature
         Ts          , & ! snow temperature
         qbot        , & ! enthalpy of ice growing at bottom surface (J m-3)
         qsub        , & ! energy/unit volume to sublimate ice/snow (J m-3)
         hqtot       , & ! sum of h*q for two layers
         wk1         , & ! temporary variable
         zqsnew      , & ! enthalpy of new snow (J m-3)
         hstot       , & ! snow thickness including new snow (m)
         Tmlts           ! melting temperature

      real (kind=dbl_kind), dimension (icells,nilyr+1) :: &
         zi1         , & ! depth of ice layer boundaries (m)
         zi2             ! adjusted depths, with equal hilyr (m)

      real (kind=dbl_kind), dimension (icells,nslyr+1) :: &
         zs1         , & ! depth of snow layer boundaries (m)
         zs2             ! adjusted depths, with equal hslyr (m)

      real (kind=dbl_kind), dimension (icells,nilyr) :: &
         dzi             ! ice layer thickness after growth/melting

      real (kind=dbl_kind), dimension (icells,nslyr) :: &
         dzs             ! snow layer thickness after growth/melting

      real (kind=dbl_kind), dimension (icells,nilyr) :: &
         qm          , & ! energy of melting (J m-3) = zqin in BL99 formulation
         qmlt            ! enthalpy of melted ice (J m-3) = zero in BL99 formulation

      real (kind=dbl_kind) :: &
         qbotm       , &
         qbotp       , &
         qbot0

      !-----------------------------------------------------------------
      ! Initialize
      !-----------------------------------------------------------------

      hsn_new (:) = c0

      do k = 1, nilyr
         do ij = 1, icells
            dzi(ij,k) = hilyr(ij)
         enddo
      enddo

      do k = 1, nslyr
         do ij = 1, icells
            dzs(ij,k) = hslyr(ij)
         enddo
      enddo

      do k = 1, nilyr
         do ij = 1, icells
            if (ktherm == 2) then
               qmlt(ij,k) = enthalpy_of_melting(zSin(ij,k))
            else
               qmlt(ij,k) = c0
            endif
            qm(ij,k) = zqin(ij,k) - qmlt(ij,k)
            emlt_atm(ij) = c0
            emlt_ocn(ij) = c0
         enddo
      enddo

      !-----------------------------------------------------------------
      ! For l_brine = false (fresh ice), check for temperatures > 0.
      !  Melt ice or snow as needed to bring temperatures back to 0.
      ! For l_brine = true, this should not be necessary.
      !-----------------------------------------------------------------

      if (.not. l_brine) then 

         do k = 1, nslyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
            do ij = 1, icells
               Ts = (Lfresh + zqsn(ij,k)/rhos) / cp_ice
               if (Ts > c0) then
                  dhs = cp_ice*Ts*dzs(ij,k) / Lfresh
                  dzs(ij,k) = dzs(ij,k) - dhs
                  zqsn(ij,k) = -rhos*Lfresh
               endif
            enddo
         enddo

         do k = 1, nilyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
            do ij = 1, icells
               Ti = (Lfresh + zqin(ij,k)/rhoi) / cp_ice
               if (Ti > c0) then
                  dhi = cp_ice*Ti*dzi(ij,k) / Lfresh
                  dzi(ij,k) = dzi(ij,k) - dhi
                  zqin(ij,k) = -rhoi*Lfresh
               endif
            enddo               ! ij
         enddo                  ! k

      endif                     ! .not. l_brine

      !-----------------------------------------------------------------
      ! Compute energy available for sublimation/condensation, top melt,
      ! and bottom growth/melt.
      !-----------------------------------------------------------------

      do ij = 1, icells
         i = indxi(ij)
         j = indxj(ij)

         wk1 = -flatn(i,j) * dt
         esub(ij) = max(wk1, c0)     ! energy for sublimation, > 0
         econ(ij) = min(wk1, c0)     ! energy for condensation, < 0

         wk1 = (fsurfn(i,j) - fcondtopn(i,j)) * dt
         etop_mlt(ij) = max(wk1, c0)           ! etop_mlt > 0
         
         wk1 = (fcondbotn(i,j) - fbot(i,j)) * dt
         ebot_mlt(ij) = max(wk1, c0)           ! ebot_mlt > 0
         ebot_gro(ij) = min(wk1, c0)           ! ebot_gro < 0

         !--------------------------------------------------------------
         ! Condensation (evapn > 0)
         ! Note: evapn here has unit of kg/m^2.  Divide by dt later.
         ! This is the only case in which energy from the atmosphere
         ! is used for changes in the brine energy (emlt_atm).
         !--------------------------------------------------------------

         evapn   (i,j) = c0          ! initialize

         if (hsn(ij) > puny) then    ! add snow with enthalpy zqsn(ij,1)
            dhs = econ(ij) / (zqsn(ij,1) - rhos*Lvap) ! econ < 0, dhs > 0
            dzs(ij,1) = dzs(ij,1) + dhs
            evapn(i,j) = evapn(i,j) + dhs*rhos
            evapsn(i,j) = evapsn(i,j) + dhs*rhos
         else                        ! add ice with enthalpy zqin(ij,1)
            dhi = econ(ij) / (qm(ij,1) - rhoi*Lvap) ! econ < 0, dhi > 0
            dzi(ij,1) = dzi(ij,1) + dhi
            evapn(i,j) = evapn(i,j) + dhi*rhoi
            evapin(i,j) = evapin(i,j) + dhi*rhoi
            ! enthalpy of melt water
            emlt_atm(ij) = emlt_atm(ij) - qmlt(ij,1) * dhi 
         endif

         !--------------------------------------------------------------
         ! Grow ice (bottom)
         !--------------------------------------------------------------

         if (ktherm == 2) then

            qbotm = enthalpy_mush(Tbot(i,j), sss(i,j))
            qbotp = -Lfresh * rhoi * (c1 - phi_i_mushy)
            qbot0 = qbotm - qbotp

            dhi  = ebot_gro(ij) / qbotp     ! dhi > 0

            hqtot = dzi(ij,nilyr)*zqin(ij,nilyr) + dhi*qbotm
            hstot = dzi(ij,nilyr)*zSin(ij,nilyr) + dhi*sss(i,j)
            emlt_ocn(ij) = emlt_ocn(ij) - qbot0 * dhi

         else

            Tmlts = -zSin(ij,nilyr) * depressT 

            ! enthalpy of new ice growing at bottom surface
            if (heat_capacity) then
               if (l_brine) then
                  qbot = -rhoi * (cp_ice * (Tmlts-Tbot(i,j)) &
                                + Lfresh * (c1-Tmlts/Tbot(i,j)) &
                                - cp_ocn * Tmlts)
                  qbot = min (qbot, qbotmax)      ! in case Tbot is close to Tmlt
               else
                  qbot = -rhoi * (-cp_ice * Tbot(i,j) + Lfresh)
               endif
            else   ! zero layer
               qbot = -rhoi * Lfresh
            endif

            dhi  = ebot_gro(ij) / qbot     ! dhi > 0

            hqtot = dzi(ij,nilyr)*zqin(ij,nilyr) + dhi*qbot
            hstot = c0

         endif ! ktherm

         dzi(ij,nilyr) = dzi(ij,nilyr) + dhi
         if (dzi(ij,nilyr) > puny) then
            zqin(ij,nilyr) = hqtot / dzi(ij,nilyr)
            if (ktherm == 2) then
               zSin(ij,nilyr) = hstot / dzi(ij,nilyr)
               qmlt(ij,nilyr) = enthalpy_of_melting(zSin(ij,nilyr))
            else
               qmlt(ij,nilyr) = c0
            endif
            qm(ij,nilyr) = zqin(ij,nilyr) - qmlt(ij,nilyr)
         endif

         ! update ice age due to freezing (new ice age = dt)
!         if (tr_iage) &
!            iage(i,j) = (iage(i,j)*hin(ij) + dt*dhi) / (hin(ij) + dhi)

         ! history diagnostics
         congel(i,j) = congel(i,j) + dhi
         if (dhi > puny .and. frz_onset(i,j) < puny) &
                 frz_onset(i,j) = yday

      enddo                     ! ij

      do k = 1, nslyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells
            i = indxi(ij)
            j = indxj(ij)

         !--------------------------------------------------------------
         ! Remove internal snow melt 
         !--------------------------------------------------------------

            if (ktherm == 2 .and. zqsn(ij,k) > -rhos * Lfresh) then

               dhs = max(-dzs(ij,k), &
                         -((zqsn(ij,k) + rhos*Lfresh) / (rhos*Lfresh)) * dzs(ij,k))
               dzs(ij,k) = dzs(ij,k) + dhs
               zqsn(ij,k) = -rhos * Lfresh
               melts(i,j) = melts(i,j) - dhs
               ! delta E = zqsn(ij,k) + rhos * Lfresh

            endif

         !--------------------------------------------------------------
         ! Sublimation of snow (evapn < 0)
         !--------------------------------------------------------------

            qsub = zqsn(ij,k) - rhos*Lvap ! qsub < 0
            dhs  = max (-dzs(ij,k), esub(ij)/qsub)  ! esub > 0, dhs < 0
            dzs(ij,k) = dzs(ij,k) + dhs
            esub(ij) = esub(ij) - dhs*qsub
            esub(ij) = max(esub(ij), c0)   ! in case of roundoff error
            evapn(i,j) = evapn(i,j) + dhs*rhos
            evapsn(i,j) = evapsn(i,j) + dhs*rhos

         !--------------------------------------------------------------
         ! Melt snow (top)
         !--------------------------------------------------------------

            dhs = max(-dzs(ij,k), etop_mlt(ij)/zqsn(ij,k))
            dzs(ij,k) = dzs(ij,k) + dhs         ! zqsn < 0, dhs < 0
            etop_mlt(ij) = etop_mlt(ij) - dhs*zqsn(ij,k)
            etop_mlt(ij) = max(etop_mlt(ij), c0) ! in case of roundoff error

            ! history diagnostics
            if (dhs < -puny .and. mlt_onset(i,j) < puny) &
               mlt_onset(i,j) = yday
            melts(i,j) = melts(i,j) - dhs

         enddo                  ! ij
      enddo                     ! nslyr

      do k = 1, nilyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells
            i = indxi(ij)
            j = indxj(ij)

         !--------------------------------------------------------------
         ! Sublimation of ice (evapn < 0)
         !--------------------------------------------------------------

            qsub = qm(ij,k) - rhoi*Lvap              ! qsub < 0
            dhi  = max (-dzi(ij,k), esub(ij)/qsub) ! esub < 0, dhi < 0
            dzi(ij,k) = dzi(ij,k) + dhi
            esub(ij) = esub(ij) - dhi*qsub
            esub(ij) = max(esub(ij), c0)
            evapn(i,j) = evapn(i,j) + dhi*rhoi
            evapin(i,j) = evapin(i,j) + dhi*rhoi
            emlt_ocn(ij) = emlt_ocn(ij) - qmlt(ij,k) * dhi 

         !--------------------------------------------------------------
         ! Melt ice (top)
         !--------------------------------------------------------------
   
            if (qm(ij,k) < c0) then
               dhi = max(-dzi(ij,k), etop_mlt(ij)/qm(ij,k))
            else
               qm(ij,k) = c0
               dhi = -dzi(ij,k)
            endif
            emlt_ocn(ij) = emlt_ocn(ij) - max(zqin(ij,k),qmlt(ij,k)) * dhi

            dzi(ij,k) = dzi(ij,k) + dhi         ! zqin < 0, dhi < 0
            etop_mlt(ij) = max(etop_mlt(ij) - dhi*qm(ij,k), c0)

            ! history diagnostics
            if (dhi < -puny .and. mlt_onset(i,j) < puny) &
                 mlt_onset(i,j) = yday
              meltt(i,j) = meltt(i,j) - dhi
          
         enddo                  ! ij
      enddo                     ! nilyr

      do k = nilyr, 1, -1
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells
            i = indxi(ij)
            j = indxj(ij)

         !--------------------------------------------------------------
         ! Melt ice (bottom)
         !--------------------------------------------------------------

            if (qm(ij,k) < c0) then
               dhi = max(-dzi(ij,k), ebot_mlt(ij)/qm(ij,k))
            else
               qm(ij,k) = c0
               dhi = -dzi(ij,k)
            endif
            emlt_ocn(ij) = emlt_ocn(ij) - max(zqin(ij,k),qmlt(ij,k)) * dhi

            dzi(ij,k) = dzi(ij,k) + dhi         ! zqin < 0, dhi < 0
            ebot_mlt(ij) = max(ebot_mlt(ij) - dhi*qm(ij,k), c0)

            ! history diagnostics 
            meltb(i,j) = meltb(i,j) -dhi

         enddo                  ! ij
      enddo                     ! nilyr

      do k = nslyr, 1, -1
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells

            i = indxi(ij)
            j = indxj(ij)

         !--------------------------------------------------------------
         ! Melt snow (only if all the ice has melted)
         !--------------------------------------------------------------

            dhs = max(-dzs(ij,k), ebot_mlt(ij)/zqsn(ij,k))
            dzs(ij,k) = dzs(ij,k) + dhs         ! zqsn < 0, dhs < 0
            ebot_mlt(ij) = ebot_mlt(ij) - dhs*zqsn(ij,k)
            ebot_mlt(ij) = max(ebot_mlt(ij), c0)

            !-----------------------------------------------------------
            ! Added here to ensure that the snow-thickness diagostics
            ! are closed. This is needed for isotope update.
            !   hs = hs_old + evap - melts - dhs_snoice + dhs_snow
            ! Jiang Zhu (jzhu47@wisc.edu), Nov. 20, 2014
            !-----------------------------------------------------------
            melts(i,j) = melts(i,j) - dhs

         enddo                  ! ij
      enddo                     ! nslyr


      !-----------------------------------------------------------------
      ! Compute heat flux used by the ice (<=0).
      ! fhocn is the available ocean heat that is left after use by ice
      !-----------------------------------------------------------------

      do ij = 1, icells
         i = indxi(ij)
         j = indxj(ij)
         fhocnn(i,j) = fbot(i,j) &
                     + (esub(ij) + etop_mlt(ij) + ebot_mlt(ij))/dt
      enddo

!---!-----------------------------------------------------------------
!---! Add new snowfall at top surface.
!---!-----------------------------------------------------------------

!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
      do ij = 1, icells
         i = indxi(ij)
         j = indxj(ij)

      !----------------------------------------------------------------
      ! NOTE: If heat flux diagnostics are to work, new snow should
      !       have T = 0 (i.e. q = -rhos*Lfresh) and should not be
      !       converted to rain.
      !----------------------------------------------------------------

         if (fsnow(i,j) > c0) then

            hsn_new(ij) = fsnow(i,j)/rhos * dt
            zqsnew = -rhos*Lfresh
            hstot = dzs(ij,1) + hsn_new(ij)

            if (hstot > c0) then
               zqsn(ij,1) =  (dzs(ij,1) * zqsn(ij,1) &
                          + hsn_new(ij) * zqsnew) / hstot
               ! avoid roundoff errors
               zqsn(ij,1) = min(zqsn(ij,1), -rhos*Lfresh)

               dzs(ij,1) = hstot
            endif
         endif

    !-----------------------------------------------------------------
    ! Find the new ice and snow thicknesses.
    !-----------------------------------------------------------------

         hin(ij) = c0
         hsn(ij) = c0
      enddo

      do k = 1, nilyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells
            hin(ij) = hin(ij) + dzi(ij,k)
         enddo                  ! ij
      enddo                     ! k

      do k = 1, nslyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells
            i = indxi(ij)
            j = indxj(ij)
            hsn(ij) = hsn(ij) + dzs(ij,k)
            dsnow(i,j) = dsnow(i,j) + dzs(ij,k) - hslyr(ij)  
         enddo                  ! ij
      enddo                     ! k

    !-------------------------------------------------------------------
    ! Convert snow to ice if snow lies below freeboard.
    !-------------------------------------------------------------------

      if (ktherm /= 2) &
      call freeboard (nx_block, ny_block, &
                      icells,             &
                      indxi,    indxj,    &
                      dt,                 &
                      snoice,             &
                      iage,               &
                      hin,      hsn,      &
                      zqin,     zqsn,     &
                      dzi,      dzs,      &
                      dsnow)

!---!-------------------------------------------------------------------
!---! Repartition the ice and snow into equal-thickness layers,
!---! conserving energy.
!---!-------------------------------------------------------------------

      !-----------------------------------------------------------------
      ! Compute desired layer thicknesses.
      !-----------------------------------------------------------------

      do ij = 1, icells
 
         if (hin(ij) > c0) then
            hilyr(ij) = hin(ij) / real(nilyr,kind=dbl_kind)
         else
            hin(ij) = c0
            hilyr(ij) = c0
         endif
         if (hsn(ij) > c0) then
            hslyr(ij) = hsn(ij) / real(nslyr,kind=dbl_kind)
         else
            hsn(ij) = c0
            hslyr(ij) = c0
         endif

      !-----------------------------------------------------------------
      ! Compute depths zi1 of old layers (unequal thickness).
      ! Compute depths zi2 of new layers (equal thickness).
      !-----------------------------------------------------------------

         zi1(ij,1) = c0
         zi1(ij,1+nilyr) = hin(ij)
 
         zi2(ij,1) = c0
         zi2(ij,1+nilyr) = hin(ij)

      enddo   ! ij

      if (heat_capacity) then

         do k = 1, nilyr-1
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
            do ij = 1, icells
               zi1(ij,k+1) = zi1(ij,k) + dzi(ij,k)
               zi2(ij,k+1) = zi2(ij,k) + hilyr(ij)
            end do
         enddo

        !-----------------------------------------------------------------
        ! Conserving energy, compute the enthalpy of the new equal layers.
        !-----------------------------------------------------------------

        call adjust_enthalpy (nx_block, ny_block, &
                              nilyr,    icells,   &
                              indxi,    indxj,    &
                              zi1,      zi2,      &
                              hilyr,    hin,      &
                              zqin)

        if (ktherm == 2) &
             call adjust_enthalpy (nx_block, ny_block, &
                                   nilyr,    icells,   &
                                   indxi,    indxj,    &
                                   zi1,      zi2,      &
                                   hilyr,    hin,      &
                                   zSin)

      else ! zero layer (nilyr=1)

         do ij = 1, icells
            zqin(ij,1) = -rhoi * Lfresh
            zqsn(ij,1) = -rhos * Lfresh
         end do
       
      endif

      if (nslyr > 1) then

      !-----------------------------------------------------------------
      ! Compute depths zs1 of old layers (unequal thickness).
      ! Compute depths zs2 of new layers (equal thickness).
      !-----------------------------------------------------------------

         do ij = 1, icells
            zs1(ij,1) = c0
            zs1(ij,1+nslyr) = hsn(ij)

            zs2(ij,1) = c0
            zs2(ij,1+nslyr) = hsn(ij)
         enddo

         do k = 1, nslyr-1
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
            do ij = 1, icells
               zs1(ij,k+1) = zs1(ij,k) + dzs(ij,k)
               zs2(ij,k+1) = zs2(ij,k) + hslyr(ij)
            end do
         enddo

      !-----------------------------------------------------------------
      ! Conserving energy, compute the enthalpy of the new equal layers.
      !-----------------------------------------------------------------

         call adjust_enthalpy (nx_block, ny_block, &
                               nslyr,    icells,   &
                               indxi,    indxj,    &
                               zs1,      zs2,      &
                               hslyr,    hsn,      &
                               zqsn)

      endif   ! nslyr > 1

      !-----------------------------------------------------------------
      ! Remove very thin snow layers (ktherm = 2)
      !-----------------------------------------------------------------

      if (ktherm == 2) then
         do k = 1, nslyr
            do ij = 1, icells
               i = indxi(ij)
               j = indxj(ij)
               if (hsn(ij) <= puny) then
                  fhocnn(i,j) = fhocnn(i,j) &
                    + zqsn(ij,k)*hsn(ij)/(real(nslyr,kind=dbl_kind)*dt)
                  zqsn(ij,k) = -rhos*Lfresh
                  hslyr(ij) = c0
               endif
            enddo
         enddo
      endif

      !-----------------------------------------------------------------
      ! Compute final ice-snow energy, including the energy of
      !  sublimated/condensed ice.
      !-----------------------------------------------------------------

      do ij = 1, icells
         i = indxi(ij)
         j = indxj(ij)
         efinal(ij) = -evapn(i,j)*Lvap
         evapn(i,j) =  evapn(i,j)/dt
      enddo

      do k = 1, nslyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells
            efinal(ij) = efinal(ij) + hslyr(ij)*zqsn(ij,k)
         enddo                  ! ij
      enddo

      do k = 1, nilyr
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells
            efinal(ij) = efinal(ij) + hilyr(ij)*zqin(ij,k)
         enddo                  ! ij
      enddo                     ! k

      if (ktherm < 2) then
         do ij = 1, icells 
           emlt_atm(ij) = c0
           emlt_ocn(ij) = c0
         enddo
      endif

      ! melt water is no longer zero enthalpy with ktherm=2
      do ij = 1, icells
         i = indxi(ij)
         j = indxj(ij)
         fhocnn(i,j) = fhocnn(i,j) + emlt_ocn(ij)/dt
         efinal(ij)  = efinal(ij)  + emlt_atm(ij) ! for conservation check
      enddo                  ! ij

      end subroutine thickness_changes

!=======================================================================
!
! If there is enough snow to lower the ice/snow interface below
! sea level, convert enough snow to ice to bring the interface back
! to sea level.
!
! authors William H. Lipscomb, LANL
!         Elizabeth C. Hunke, LANL

      subroutine freeboard (nx_block, ny_block, &
                            icells,             &
                            indxi,    indxj,    &
                            dt,                 &
                            snoice,             &
                            iage,               &
                            hin,      hsn,      &
                            zqin,     zqsn,     &
                            dzi,      dzs,      &
                            dsnow)

      integer (kind=int_kind), intent(in) :: &
         nx_block, ny_block, & ! block dimensions
         icells              ! number of cells with aicen > puny

      integer (kind=int_kind), dimension(nx_block*ny_block), &
         intent(in) :: &
         indxi, indxj    ! compressed indices for cells with aicen > puny

      real (kind=dbl_kind), intent(in) :: &
         dt      ! time step

      real (kind=dbl_kind), dimension (nx_block,ny_block), &
         intent(inout) :: &
         snoice  , & ! snow-ice formation       (m/step-->cm/day)
         dsnow   , & ! change in snow thickness after snow-ice formation (m)
         iage        ! snow thickness (m)

      real (kind=dbl_kind), dimension (icells), &
         intent(inout) :: &
         hin     , & ! ice thickness (m)
         hsn         ! snow thickness (m)

      real (kind=dbl_kind), dimension (icells,nilyr), &
         intent(inout) :: &
         zqin        ! ice layer enthalpy (J m-3)

      real (kind=dbl_kind), dimension (icells,nilyr), &
         intent(inout) :: &
         dzi         ! ice layer thicknesses (m)

      real (kind=dbl_kind), dimension (icells,nslyr), &
         intent(in) :: &
         zqsn        ! snow layer enthalpy (J m-3)

      real (kind=dbl_kind), dimension (icells,nslyr), &
         intent(inout) :: &
         dzs         ! snow layer thicknesses (m)

      ! local variables

      integer (kind=int_kind) :: &
         i, j        , & ! horizontal indices
         ij          , & ! horizontal index, combines i and j loops
         k               ! vertical index

      real (kind=dbl_kind), dimension (icells) :: &
         dhin        , & ! change in ice thickness (m)
         dhsn        , & ! change in snow thickness (m)
         hqs             ! sum of h*q for snow (J m-2)

      real (kind=dbl_kind) :: &
         wk1         , & ! temporary variable
         dhs             ! snow to remove from layer (m)

      !-----------------------------------------------------------------
      ! Determine whether snow lies below freeboard.
      !-----------------------------------------------------------------

      do ij = 1, icells

         i = indxi(ij)
         j = indxj(ij)

         dhin(ij) = c0
         dhsn(ij) = c0
         hqs (ij) = c0
 
         wk1 = hsn(ij) - hin(ij)*(rhow-rhoi)/rhos

         if (wk1 > puny .and. hsn(ij) > puny) then  ! snow below freeboard
            dhsn(ij) = min(wk1*rhoi/rhow, hsn(ij)) ! snow to remove
            dhin(ij) = dhsn(ij) * rhos/rhoi        ! ice to add
         endif
      enddo

      !-----------------------------------------------------------------
      ! Adjust snow layer thickness.
      ! Compute energy to transfer from snow to ice.
      !-----------------------------------------------------------------

      do k = nslyr, 1, -1
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
         do ij = 1, icells
         i = indxi(ij)
         j = indxj(ij)
            if (dhin(ij) > puny) then
               dhs = min(dhsn(ij), dzs(ij,k)) ! snow to remove from layer
               hsn(ij) = hsn(ij) - dhs
               dsnow(i,j) = dsnow(i,j) -dhs   !new snow addition term 
               dzs(ij,k) = dzs(ij,k) - dhs
               dhsn(ij) = dhsn(ij) - dhs
               dhsn(ij) = max(dhsn(ij),c0)
               hqs(ij) = hqs(ij) + dhs * zqsn(ij,k)
            endif               ! dhin > puny
         enddo
      enddo

      !-----------------------------------------------------------------
      ! Transfer volume and energy from snow to top ice layer.
      !-----------------------------------------------------------------

!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
      do ij = 1, icells
         i = indxi(ij)
         j = indxj(ij)

         if (dhin(ij) > puny) then
            ! update ice age due to freezing (new ice age = dt)
!            if (tr_iage) &
!               iage(i,j) = (iage(i,j)*hin(ij)+dt*dhin(ij))/(hin(ij)+dhin(ij))

            wk1 = dzi(ij,1) + dhin(ij)
            hin(ij) = hin(ij) + dhin(ij)
            zqin(ij,1) = (dzi(ij,1)*zqin(ij,1) + hqs(ij)) / wk1
            dzi(ij,1) = wk1

            ! history diagnostic
            snoice(i,j) = snoice(i,j) + dhin(ij)
         endif               ! dhin > puny
      enddo                  ! ij

      end subroutine freeboard

!=======================================================================
!
! Conserving energy, compute the new enthalpy of equal-thickness ice
! or snow layers.
!
! authors William H. Lipscomb, LANL
!         C. M. Bitz, UW

      subroutine adjust_enthalpy (nx_block, ny_block, &
                                  nlyr,     icells,   &
                                  indxi,    indxj,    &
                                  z1,       z2,       &
                                  hlyr,     hn,       &
                                  qn)

      integer (kind=int_kind), intent(in) :: &
         nx_block, ny_block, & ! block dimensions
         nlyr              , & ! number of layers (nilyr or nslyr)
         icells                ! number of cells with aicen > puny

      integer (kind=int_kind), dimension (nx_block*ny_block), &
         intent(in) :: &
         indxi, indxj    ! compressed indices for cells with aicen > puny

      real (kind=dbl_kind), dimension (icells,nlyr+1), &
         intent(in) :: &
         z1          , & ! interface depth for old, unequal layers (m)
         z2              ! interface depth for new, equal layers (m)

      real (kind=dbl_kind), dimension (icells), intent(in) :: &
         hlyr            ! new layer thickness (m)

      real (kind=dbl_kind), dimension (icells), intent(in) :: &
         hn              ! total thickness (m)

      real (kind=dbl_kind), dimension (icells,nlyr), &
         intent(inout) :: &
         qn              ! layer quantity (enthalpy, salinity...)

      ! local variables

      integer (kind=int_kind) :: &
         i, j        , & ! horizontal indices
         ij          , & ! horizontal index, combines i and j loops
         k, k1, k2       ! vertical indices

      real (kind=dbl_kind) :: &
         hovlp           ! overlap between old and new layers (m)

      real (kind=dbl_kind), dimension (icells) :: &
         rhlyr           ! 1./hlyr

      real (kind=dbl_kind), dimension (icells,nlyr) :: &
         hq              ! h * q for a layer

      !-----------------------------------------------------------------
      ! Compute reciprocal layer thickness.
      !-----------------------------------------------------------------

      do ij = 1, icells
         rhlyr(ij) = c0
         if (hn(ij) > puny) rhlyr(ij) = c1 / hlyr(ij)
      enddo                     ! ij

      !-----------------------------------------------------------------
      ! Compute h*q for new layers (k2) given overlap with old layers (k1)
      !-----------------------------------------------------------------

      do k2 = 1, nlyr
         do ij = 1, icells
            hq(ij,k2) = c0
         enddo
      enddo                     ! k

!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
      do ij = 1, icells
         k1 = 1
         k2 = 1
         do while (k1 <= nlyr .and. k2 <= nlyr)
            hovlp = min (z1(ij,k1+1), z2(ij,k2+1)) &
                  - max (z1(ij,k1),   z2(ij,k2))
            hovlp = max (hovlp, c0)
            hq(ij,k2) = hq(ij,k2) + hovlp*qn(ij,k1)
            if (z1(ij,k1+1) > z2(ij,k2+1)) then
               k2 = k2 + 1
            else
               k1 = k1 + 1
            endif
         enddo                  ! while
      enddo                     ! ij

      !-----------------------------------------------------------------
      ! Compute new enthalpies.
      !-----------------------------------------------------------------

      do k = 1, nlyr
         do ij = 1, icells
            qn(ij,k) = hq(ij,k) * rhlyr(ij)
         enddo                  ! ij
      enddo                     ! k

      end subroutine adjust_enthalpy

!=======================================================================
!
! Check for energy conservation by comparing the change in energy
! to the net energy input.
!
! authors William H. Lipscomb, LANL
!         C. M. Bitz, UW
!         Adrian K. Turner, LANL

      subroutine conservation_check_vthermo(nx_block, ny_block, &
                                            my_task,  istep1,   &
                                            dt,       icells,   &
                                            indxi,    indxj,    &
                                            fsurfn,   flatn,    &
                                            fhocnn,   fswint,   &
                                            fsnow,              &
                                            einit,    einter,   &
                                            efinal,             &
                                            fcondtopn,fcondbotn, &
                                            fadvocn,            &
                                            fbot,     l_stop,   &
                                            istop,    jstop)

      integer (kind=int_kind), intent(in) :: &
         nx_block, ny_block, & ! block dimensions
         my_task         , & ! task number (diagnostic only)
         istep1          , & ! time step index (diagnostic only)
         icells              ! number of cells with aicen > puny

      integer (kind=int_kind), dimension(nx_block*ny_block), &
         intent(in) :: &
         indxi, indxj    ! compressed indices for cells with aicen > puny

      real (kind=dbl_kind), intent(in) :: &
         dt              ! time step

      real (kind=dbl_kind), dimension (nx_block,ny_block), intent(in) :: &
         fsurfn      , & ! net flux to top surface, excluding fcondtopn
         flatn       , & ! surface downward latent heat (W m-2)
         fhocnn      , & ! fbot, corrected for any surplus energy
         fswint      , & ! SW absorbed in ice interior, below surface (W m-2)
         fsnow       , & ! snowfall rate (kg m-2 s-1)
         fcondtopn   , &
         fcondbotn   , &
         fadvocn     , &
         fbot           

      real (kind=dbl_kind), dimension (icells), intent(in) :: &
         einit       , & ! initial energy of melting (J m-2)
         einter      , & ! intermediate energy of melting (J m-2)
         efinal          ! final energy of melting (J m-2)

      logical (kind=log_kind), intent(inout) :: &
         l_stop          ! if true, print diagnostics and abort model

      integer (kind=int_kind), intent(inout) :: &
         istop, jstop    ! i and j indices of cell where model fails

      ! local variables

      integer (kind=int_kind) :: &
         i, j        , & ! horizontal indices
         ij              ! horizontal index, combines i and j loops

      real (kind=dbl_kind) :: &
         einp        , & ! energy input during timestep (J m-2)
         ferr            ! energy conservation error (W m-2)

      !----------------------------------------------------------------
      ! If energy is not conserved, print diagnostics and exit.
      !----------------------------------------------------------------
!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
    do ij = 1, icells
       i = indxi(ij)
       j = indxj(ij)

      !-----------------------------------------------------------------
      ! Note that fsurf - flat = fsw + flw + fsens; i.e., the latent
      ! heat is not included in the energy input, since (efinal - einit)
      ! is the energy change in the system ice + vapor, and the latent
      ! heat lost by the ice is equal to that gained by the vapor.
      !-----------------------------------------------------------------
       
         einp = (fsurfn(i,j) - flatn(i,j) + fswint(i,j) - fhocnn(i,j) &
               - fsnow(i,j)*Lfresh - fadvocn(i,j)) * dt
         ferr = abs(efinal(ij)-einit(ij)-einp) / dt

         if (ferr > 1.1_dbl_kind*ferrmax) then
            l_stop = .true.
            istop = i
            jstop = j

         write(nu_diag,*) 'Thermo energy conservation error'
         write(nu_diag,*) 'istep1, my_task, i, j:', &
                           istep1, my_task, i, j
         write(nu_diag,*) 'Flux error (W/m^2) =', ferr
         write(nu_diag,*) 'Energy error (J) =', ferr*dt
         write(nu_diag,*) 'Initial energy =', einit(ij)
         write(nu_diag,*) 'Final energy   =', efinal(ij)
         write(nu_diag,*) 'efinal - einit  =', &
                           efinal(ij)-einit(ij)
         write(nu_diag,*) 'fsurfn,flatn,fswint,fhocn, fsnow*Lfresh:'
         write(nu_diag,*) fsurfn(i,j),flatn(i,j),fswint(i,j),fhocnn(i,j), fsnow(i,j)*Lfresh
         write(nu_diag,*) 'Input energy =', einp
         write(nu_diag,*) 'fbot(i,j),fcondbotn(i,j):'
         write(nu_diag,*) fbot(i,j),fcondbotn(i,j)

!         if (ktherm == 2) then
            write(nu_diag,*) 'Intermediate energy =', einter(ij)
            write(nu_diag,*) 'efinal - einter =', &
                              efinal(ij)-einter(ij)
            write(nu_diag,*) 'einter - einit  =', &
                              einter(ij)-einit(ij)
            write(nu_diag,*) 'Conduction Error =', (einter(ij)-einit(ij)) &
                  - (fcondtopn(i,j)*dt - fcondbotn(i,j)*dt + fswint(i,j)*dt)
            write(nu_diag,*) 'Melt/Growth Error =', (einter(ij)-einit(ij)) &
                  + ferr*dt - (fcondtopn(i,j)*dt - fcondbotn(i,j)*dt + fswint(i,j)*dt)
            write(nu_diag,*) 'Advection Error =', fadvocn(i,j)*dt
!         endif

!         write(nu_diag,*) fsurfn(i,j),flatn(i,j),fswint(i,j),fhocnn(i,j)

         write(nu_diag,*) 'dt*(fsurfn, flatn, fswint, fhocn, fsnow*Lfresh, fadvocn):'
         write(nu_diag,*) fsurfn(i,j)*dt, flatn(i,j)*dt, &
                          fswint(i,j)*dt, fhocnn(i,j)*dt, &
                          fsnow(i,j)*Lfresh*dt, fadvocn(i,j)*dt
         return
         endif
      enddo

      end subroutine conservation_check_vthermo

!=======================================================================
!
! Given the vertical thermo state variables (hin, hsn, zqin,
!  zqsn, Tsf), compute the new ice state variables (vicen, vsnon, trcrn).
! Zero out state variables if ice has melted entirely.
!
! authors William H. Lipscomb, LANL
!         C. M. Bitz, UW

      subroutine update_state_vthermo(nx_block, ny_block, &
                                      icells,             &
                                      indxi,    indxj,    &
                                      Tf,       Tsf,      &
                                      hin,      hsn,      &
                                      zqin,     zSin,     &
                                      zqsn,               &
                                      aicen,    vicen,    &
                                      vsnon,    trcrn)

      integer (kind=int_kind), intent(in) :: &
         nx_block, ny_block, & ! block dimensions
         icells              ! number of cells with aicen > puny

      integer (kind=int_kind), dimension(nx_block*ny_block), &
         intent(in) :: &
         indxi, indxj    ! compressed indices for cells with aicen > puny

      real (kind=dbl_kind), dimension(nx_block,ny_block), intent(in) :: &
         Tf              ! freezing temperature (C)

      real (kind=dbl_kind), dimension(icells), intent(in) :: &
         Tsf             ! ice/snow surface temperature, Tsfcn

      real (kind=dbl_kind), dimension(icells), intent(in) :: &
         hin         , & ! ice thickness (m)
         hsn             ! snow thickness (m)

      real (kind=dbl_kind), dimension (icells,nilyr), &
         intent(in) :: &
         zqin        , & ! ice layer enthalpy (J m-3)
         zSin            ! ice salinity    (ppt)

      real (kind=dbl_kind), dimension (icells,nslyr), &
         intent(in) :: &
         zqsn            ! snow layer enthalpy (J m-3)

      real (kind=dbl_kind), dimension (nx_block,ny_block), &
         intent(inout) :: &
         aicen       , & ! concentration of ice
         vicen       , & ! volume per unit area of ice          (m)
         vsnon           ! volume per unit area of snow         (m)

      real (kind=dbl_kind), dimension (nx_block,ny_block,max_ntrcr), &
         intent(inout) :: &
         trcrn

      ! local variables

      integer (kind=int_kind) :: &
         i, j        , & ! horizontal indices
         ij          , & ! horizontal index, combines i and j loops
         k               ! ice layer index

!DIR$ CONCURRENT !Cray
!cdir nodep      !NEC
!ocl novrec      !Fujitsu
      do ij = 1, icells
         i = indxi(ij)
         j = indxj(ij)

         if (hin(ij) > c0) then
            ! aicen is already up to date
            vicen(i,j) = aicen(i,j) * hin(ij)
            vsnon(i,j) = aicen(i,j) * hsn(ij)
            trcrn(i,j,nt_Tsfc) = Tsf(ij)
         else  ! (hin(ij) == c0)
            aicen(i,j) = c0
            vicen(i,j) = c0
            vsnon(i,j) = c0
            trcrn(i,j,nt_Tsfc) = Tf(i,j)
         endif
      enddo                     ! ij

      do k = 1, nilyr
         do ij = 1, icells
            i = indxi(ij)
            j = indxj(ij)

            if (hin(ij) > c0) then
               trcrn(i,j,nt_qice+k-1) = zqin(ij,k)
              ! trcrn(i,j,nt_sice+k-1) = zSin(ij,k)
            else
               trcrn(i,j,nt_qice+k-1) = c0
              ! trcrn(i,j,nt_sice+k-1) = c0
            endif

         enddo                  ! ij
      enddo                     ! nilyr

      if (ktherm == 2) then
      do k = 1, nilyr
         do ij = 1, icells
            i = indxi(ij)
            j = indxj(ij)

            if (hin(ij) > c0) then
               trcrn(i,j,nt_sice+k-1) = zSin(ij,k)
            else
               trcrn(i,j,nt_sice+k-1) = c0
            endif

         enddo                  ! ij
      enddo                     ! nilyr
      endif

      do k = 1, nslyr
         do ij = 1, icells
            i = indxi(ij)
            j = indxj(ij)

            if (hin(ij) > c0) then
               trcrn(i,j,nt_qsno+k-1) = zqsn(ij,k)
            else
               trcrn(i,j,nt_qsno+k-1) = c0
            endif

         enddo                  ! ij
      enddo                     ! nslyr

    end subroutine update_state_vthermo

!=======================================================================

      end module ice_therm_vertical

!=======================================================================
