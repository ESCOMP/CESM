!===============================================================================
! Dust for Modal Aerosol Model
!===============================================================================
module dust_model 
  use shr_kind_mod,     only: r8 => shr_kind_r8, cl => shr_kind_cl
  use spmd_utils,       only: masterproc
  use cam_abortutils,   only: endrun
  use modal_aero_data,  only: ntot_amode, ndst=>nDust

  implicit none
  private

  public :: dust_names
  public :: dust_nbin
  public :: dust_nnum
  public :: dust_indices
  public :: dust_emis
  public :: dust_readnl
  public :: dust_init
  public :: dust_active

  integer, protected :: dust_nbin != 2
  integer, protected :: dust_nnum != 2
  character(len=6), protected, allocatable :: dust_names(:)

  real(r8), allocatable :: dust_dmt_grd(:)
  real(r8), allocatable :: dust_emis_sclfctr(:)

  integer , protected, allocatable :: dust_indices(:)
  real(r8), allocatable :: dust_dmt_vwr(:)
  real(r8), allocatable :: dust_stk_crc(:)

  real(r8)          :: dust_emis_fact = -1.e36_r8        ! tuning parameter for dust emissions
  character(len=cl) :: soil_erod_file = 'soil_erod_file' ! full pathname for soil erodibility dataset

  logical :: dust_active = .false.

 contains

  !=============================================================================
  ! reads dust namelist options
  !=============================================================================
  subroutine dust_readnl(nlfile)

    use namelist_utils,  only: find_group_name
    use units,           only: getunit, freeunit
    use mpishorthand

    character(len=*), intent(in) :: nlfile  ! filepath for file containing namelist input

    ! Local variables
    integer :: unitn, ierr
    character(len=*), parameter :: subname = 'dust_readnl'

    namelist /dust_nl/ dust_emis_fact, soil_erod_file

    !-----------------------------------------------------------------------------

    ! Read namelist
    if (masterproc) then
       unitn = getunit()
       open( unitn, file=trim(nlfile), status='old' )
       call find_group_name(unitn, 'dust_nl', status=ierr)
       if (ierr == 0) then
          read(unitn, dust_nl, iostat=ierr)
          if (ierr /= 0) then
             call endrun(subname // ':: ERROR reading namelist')
          end if
       end if
       close(unitn)
       call freeunit(unitn)
    end if

#ifdef SPMD
    ! Broadcast namelist variables
    call mpibcast(dust_emis_fact, 1,                   mpir8,   0, mpicom)
    call mpibcast(soil_erod_file, len(soil_erod_file), mpichar, 0, mpicom)
#endif

  end subroutine dust_readnl

  !=============================================================================
  !=============================================================================
  subroutine dust_init()
    use soil_erod_mod, only: soil_erod_init
    use constituents,  only: cnst_get_ind
    use rad_constituents, only: rad_cnst_get_info
    use dust_common,   only: dust_set_params

    integer :: l, m, mm, ndx, nspec
    character(len=32) :: spec_name
    integer, parameter :: mymodes(7) = (/ 2, 1, 3, 4, 5, 6, 7 /) ! tricky order ...

    dust_nbin = ndst
    dust_nnum = ndst

    allocate( dust_names(2*ndst) )
    allocate( dust_indices(2*ndst) )
    allocate( dust_dmt_grd(ndst+1) )
    allocate( dust_emis_sclfctr(ndst) )
    allocate( dust_dmt_vwr(ndst) )
    allocate( dust_stk_crc(ndst) )

    if ( ntot_amode == 3 ) then
       dust_dmt_grd(:) = (/ 0.1e-6_r8, 1.0e-6_r8, 10.0e-6_r8/)
       dust_emis_sclfctr(:) = (/ 0.011_r8,0.989_r8 /)
    elseif ( ntot_amode == 4 ) then
       dust_dmt_grd(:) = (/ 0.01e-6_r8, 0.1e-6_r8, 1.0e-6_r8, 10.0e-6_r8 /) ! Aitken dust
       dust_emis_sclfctr(:) = (/ 1.65E-05_r8, 0.011_r8, 0.989_r8 /) ! Aitken dust
    else if( ntot_amode == 7 ) then
       dust_dmt_grd(:) = (/ 0.1e-6_r8, 2.0e-6_r8, 10.0e-6_r8/)
       dust_emis_sclfctr(:) = (/ 0.13_r8, 0.87_r8 /)
    endif

    ndx = 0
    do mm = 1, ntot_amode
       m = mymodes(mm)
       call rad_cnst_get_info(0, m, nspec=nspec)
       do l = 1, nspec
          call rad_cnst_get_info(0, m, l, spec_name=spec_name )
          if (spec_name(:3) == 'dst') then
             ndx=ndx+1
             dust_names(ndx) = spec_name
             dust_names(ndst+ndx) = 'num_'//spec_name(5:)
             call cnst_get_ind(dust_names(     ndx), dust_indices(     ndx))
             call cnst_get_ind(dust_names(ndst+ndx), dust_indices(ndst+ndx))
          endif
       enddo
    enddo

    dust_active = any(dust_indices(:) > 0)
    if (.not.dust_active) return
   
    call  soil_erod_init( dust_emis_fact, soil_erod_file )

    call dust_set_params( dust_nbin, dust_dmt_grd, dust_dmt_vwr, dust_stk_crc )

  end subroutine dust_init

  !===============================================================================
  !===============================================================================
  subroutine dust_emis( ncol, lchnk, dust_flux_in, cflx, soil_erod )
    use soil_erod_mod, only : soil_erod_fact
    use soil_erod_mod, only : soil_erodibility
    use mo_constants,  only : dust_density
    use physconst,     only : pi

  ! args
    integer,  intent(in)    :: ncol, lchnk
    real(r8), intent(in)    :: dust_flux_in(:,:)
    real(r8), intent(inout) :: cflx(:,:)
    real(r8), intent(out)   :: soil_erod(:)

  ! local vars
    integer :: i, m, idst, inum
    real(r8) :: x_mton
   ! modify nmm from  0.1_r8 to 0.0_r8
    real(r8),parameter :: soil_erod_threshold = 0.0_r8

    ! set dust emissions

    col_loop: do i =1,ncol

       soil_erod(i) = soil_erodibility( i, lchnk )

       if( soil_erod(i) .lt. soil_erod_threshold ) soil_erod(i) = 0._r8

       ! rebin and adjust dust emissons..
       do m = 1,dust_nbin

          idst = dust_indices(m)

          cflx(i,idst) = sum( -dust_flux_in(i,:) ) &
               * dust_emis_sclfctr(m)*soil_erod(i)/soil_erod_fact*1.15_r8

          x_mton = 6._r8 / (pi * dust_density * (dust_dmt_vwr(m)**3._r8))                

          inum = dust_indices(m+dust_nbin)

          cflx(i,inum) = cflx(i,idst)*x_mton

       enddo

    end do col_loop

  end subroutine dust_emis

end module dust_model
