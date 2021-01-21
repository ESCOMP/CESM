!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!     This file converts a POP grid.dat file to a remapping grid file
!     in netCDF format.
!
!-----------------------------------------------------------------------
!
!     CVS:$Id: convertPOPT.F90,v 1.9 2004-06-02 23:25:50 eong Exp $
!     CVS $Name:  $
!
!     Copyright (c) 1997, 1998 the Regents of the University of
!       California.
!
!     Unless otherwise indicated, this software has been authored
!     by an employee or employees of the University of California,
!     operator of the Los Alamos National Laboratory under Contract
!     No. W-7405-ENG-36 with the U.S. Department of Energy.  The U.S.
!     Government has rights to use, reproduce, and distribute this
!     software.  The public may copy and use this software without
!     charge, provided that this Notice and any statement of authorship
!     are reproduced on all copies.  Neither the Government nor the
!     University makes any warranty, express or implied, or assumes
!     any liability or responsibility for the use of this software.
!
!***********************************************************************

      subroutine convertPOPT(GGrid, grid_file_in, grid_topo_in, nx, ny)

!-----------------------------------------------------------------------
!
!     This file converts a POP grid.dat file to a remapping grid file.
!
!-----------------------------------------------------------------------

      use m_AttrVect,only    : AttrVect
      use m_GeneralGrid,only : MCT_GGrid_init => init
      use m_GeneralGrid,only : MCT_GGrid_indexIA => indexIA
      use m_GeneralGrid,only : MCT_GGrid_indexRA => indexRA
      use m_GeneralGrid,only : GeneralGrid
      use m_stdio
      use m_ioutil
      use m_die


      implicit none

!-----------------------------------------------------------------------
!
!     variables that describe the grid
!       4/3       nx = 192, ny = 128
!       2/3 (mod) nx = 384, ny = 288
!       x3p Greenland DP nx = 100, ny = 116
!       x2p Greenland DP nx = 160, ny = 192
!       x1p Greenland DP nx = 320, ny = 384
!
!-----------------------------------------------------------------------

      type(GeneralGrid),       intent(out) :: GGrid
      character (len=*),       intent(in)  :: grid_file_in
      character (len=*),       intent(in)  :: grid_topo_in
      integer,                 intent(in)  :: nx
      integer,                 intent(in)  :: ny

      integer :: grid_size

      integer, parameter :: &
                   grid_rank = 2, &
                   grid_corners = 4

      integer, dimension(2) :: &
                   grid_dims   ! size of each dimension

!-----------------------------------------------------------------------
!
!     grid coordinates and masks
!
!-----------------------------------------------------------------------

!:: NOTE: The following kind specifiers are needed to read the proper
!:: values for the POP grid files. The subsequent type conversions
!:: on these variables may pose a risk.

      integer(kind(1)), dimension(:), allocatable :: &
                   grid_imask

      real, dimension(:), allocatable :: &
                   grid_area      ,  &! area as computed in POP
                   grid_center_lat,  &! lat/lon coordinates for
                   grid_center_lon   ! each grid center in radians

      real(selected_real_kind(13)), dimension(:,:), allocatable :: &
                   grid_corner_lat,  &! lat/lon coordinates for
                   grid_corner_lon   ! each grid corner in radians

      real(selected_real_kind(13)), dimension(:,:), allocatable :: &
                   HTN, HTE          ! T-cell grid lengths

!-----------------------------------------------------------------------
!
!     defined constants
!
!-----------------------------------------------------------------------

      real(selected_real_kind(13)), parameter ::  &
	    zero   = 0.0,           &
	    one    = 1.0,           &
	    two    = 2.0,           &
	    three  = 3.0,           &
	    four   = 4.0,           &
	    five   = 5.0,           &
	    half   = 0.5,           &
	    quart  = 0.25,          &
	    bignum = 1.e+20,        &
	    tiny   = 1.e-14,        &
	    pi     = 3.14159265359, &
	    pi2    = two*pi,        &
	    pih    = half*pi

      real(selected_real_kind(13)), parameter ::  &
	           radius    = 6.37122e8 ,        &  ! radius of Earth (cm)
		   area_norm = one/(radius*radius)

!-----------------------------------------------------------------------
!
!     other local variables
!
!-----------------------------------------------------------------------

      character(len=*),parameter :: myname_= 'convertPOPT'

      integer :: i, j, k, n, p, q, r, ier

      integer :: iunit, ocn_add, im1, jm1, np1, np2

      integer :: center_lat, center_lon, &
	         corner_lat, corner_lon, &
		 imask, area

      real :: tmplon, dlat, dxt, dyt

      real :: x1, x2, x3, x4, &
              y1, y2, y3, y4, &
              z1, z2, z3, z4, &
              tx, ty, tz, da

      grid_size = nx*ny

      allocate(grid_imask(grid_size), &
	       grid_area(grid_size), &
	       grid_center_lat(grid_size), &
	       grid_center_lon(grid_size), &
               grid_corner_lat(grid_corners,grid_size), &
	       grid_corner_lon(grid_corners,grid_size), &
	       HTN(nx,ny), &
	       HTE(nx,ny), &
	       stat=ier)

      if(ier/=0) call die(myname_,"allocate(grid_imask... ", ier)

!-----------------------------------------------------------------------
!
!     read in grid info
!     lat/lon info is on velocity points which correspond
!     to the NE corner (in logical space) of the grid cell.
!
!-----------------------------------------------------------------------

      iunit = luavail()

      open(unit=iunit, file=trim(grid_topo_in), status='old', &
           form='unformatted', access='direct', recl=grid_size*4)

      read (unit=iunit,rec=1) grid_imask

      call luflush(iunit)

      iunit = luavail()
#if SYSSUPERUX || SYSOSF1
      open(unit=iunit, file=trim(grid_file_in), status='old', &
           form='unformatted', access='direct', recl=grid_size*2)
#else
      open(unit=iunit, file=trim(grid_file_in), status='old', &
           form='unformatted', access='direct', recl=grid_size*8)
#endif

      read (unit=iunit, rec=1) grid_corner_lat(3,:)
      read (unit=iunit, rec=2) grid_corner_lon(3,:)
      read (unit=iunit, rec=3) HTN
      read (unit=iunit, rec=4) HTE
      call luflush(iunit)

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!::::::::::::TEST DIAGNOSTICS::::::::::::::::::::::::::::::::::
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

      k=0
      do j=1,grid_size
         if(grid_imask(j)==0) k=k+1
      enddo

      write(stdout,*) "CONVERTPOPT: NUM_ZEROES(GRID_IMASK), SUM(GRID_IMASK)",&
           k, sum(grid_imask)

     write(stdout,*) "CONVERTPOPT: GRID_CORNER_LAT VALUES = ", &
          grid_corner_lat(3,1:10)

     write(stdout,*) "CONVERTPOPT: GRID_CORNER_LON VALUES = ", &
          grid_corner_lon(3,1:10)

     write(stdout,*) "CONVERTPOPT: HTN VALUES = ", &
          HTN(1,1:10)

     write(stdout,*) "CONVERTPOPT: HTE VALUES = ", &
          HTE(1,1:10)

!:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

      grid_dims(1) = nx
      grid_dims(2) = ny

!-----------------------------------------------------------------------
!
!     convert KMT field to integer grid mask
!
!-----------------------------------------------------------------------

      grid_imask = min(grid_imask, 1)

!-----------------------------------------------------------------------
!
!     compute remaining corners
!
!-----------------------------------------------------------------------

      do j=1,ny
        do i=1,nx
          ocn_add = (j-1)*nx + i
          if (i .ne. 1) then
            im1 = ocn_add - 1
          else
            im1 = ocn_add + nx - 1
          endif

          grid_corner_lat(4,ocn_add) = grid_corner_lat(3,im1)
          grid_corner_lon(4,ocn_add) = grid_corner_lon(3,im1)
        end do
      end do

      do j=2,ny
        do i=1,nx
          ocn_add = (j-1)*nx + i
          jm1 = (j-2)*nx + i

          grid_corner_lat(2,ocn_add) = grid_corner_lat(3,jm1)
          grid_corner_lat(1,ocn_add) = grid_corner_lat(4,jm1)

          grid_corner_lon(2,ocn_add) = grid_corner_lon(3,jm1)
          grid_corner_lon(1,ocn_add) = grid_corner_lon(4,jm1)
        end do
      end do

!-----------------------------------------------------------------------
!
!     mock up the lower row boundaries
!
!-----------------------------------------------------------------------

      do i=1,nx
        dlat = grid_corner_lat(1,i+2*nx) - grid_corner_lat(1,i+nx)
        grid_corner_lat(1,i) = grid_corner_lat(1,i+nx) - dlat
        grid_corner_lat(1,i) = max(grid_corner_lat(1,i), -pih + tiny)

        dlat = grid_corner_lat(2,i+2*nx) - grid_corner_lat(2,i+nx)
        grid_corner_lat(2,i) = grid_corner_lat(2,i+nx) - dlat
        grid_corner_lat(2,i) = max(grid_corner_lat(2,i), -pih + tiny)

        grid_corner_lon(1,i) = grid_corner_lon(4,i)
        grid_corner_lon(2,i) = grid_corner_lon(3,i)
      end do

!-----------------------------------------------------------------------
!
!     correct for 0,2pi longitude crossings
!
!-----------------------------------------------------------------------

      do ocn_add=1,grid_size
        if (grid_corner_lon(1,ocn_add) > pi2) &
            grid_corner_lon(1,ocn_add) = &
            grid_corner_lon(1,ocn_add) - pi2
        if (grid_corner_lon(1,ocn_add) < 0.0) &
            grid_corner_lon(1,ocn_add) = &
            grid_corner_lon(1,ocn_add) + pi2
        do n=2,grid_corners
          tmplon = grid_corner_lon(n  ,ocn_add) -  &
                   grid_corner_lon(n-1,ocn_add)
          if (tmplon < -three*pih) grid_corner_lon(n,ocn_add) = &
                                   grid_corner_lon(n,ocn_add) + pi2
          if (tmplon >  three*pih) grid_corner_lon(n,ocn_add) = &
                                   grid_corner_lon(n,ocn_add) - pi2
        end do
      end do

!-----------------------------------------------------------------------
!
!     compute ocean cell centers by averaging corner values
!
!-----------------------------------------------------------------------

      do ocn_add=1,grid_size
         z1 = cos(grid_corner_lat(1,ocn_add))
         x1 = cos(grid_corner_lon(1,ocn_add))*z1
         y1 = sin(grid_corner_lon(1,ocn_add))*z1
         z1 = sin(grid_corner_lat(1,ocn_add))

         z2 = cos(grid_corner_lat(2,ocn_add))
         x2 = cos(grid_corner_lon(2,ocn_add))*z2
         y2 = sin(grid_corner_lon(2,ocn_add))*z2
         z2 = sin(grid_corner_lat(2,ocn_add))

         z3 = cos(grid_corner_lat(3,ocn_add))
         x3 = cos(grid_corner_lon(3,ocn_add))*z3
         y3 = sin(grid_corner_lon(3,ocn_add))*z3
         z3 = sin(grid_corner_lat(3,ocn_add))

         z4 = cos(grid_corner_lat(4,ocn_add))
         x4 = cos(grid_corner_lon(4,ocn_add))*z4
         y4 = sin(grid_corner_lon(4,ocn_add))*z4
         z4 = sin(grid_corner_lat(4,ocn_add))

         tx = (x1+x2+x3+x4)/4.0
         ty = (y1+y2+y3+y4)/4.0
         tz = (z1+z2+z3+z4)/4.0
         da = sqrt(tx**2+ty**2+tz**2)

         tz = tz/da
                                ! grid_center_lon in radians
         grid_center_lon(ocn_add) = 0.0
         if (tx .ne. 0.0 .or. ty .ne. 0.0) &
              grid_center_lon(ocn_add) = atan2(ty,tx)
                                ! grid_center_lat in radians
         grid_center_lat(ocn_add) = asin(tz)

      end do

      ! j=1: linear approximation
      n = 0
      do i=1,nx
         n   = n + 1
         np1 = n + nx
         np2 = n + 2*nx
         grid_center_lon(n) = grid_center_lon(np1)
         grid_center_lat(n) = 2.0*grid_center_lat(np1) - &
              grid_center_lat(np2)
      end do

      do ocn_add=1,grid_size
        if (grid_center_lon(ocn_add) > pi2) &
            grid_center_lon(ocn_add) = grid_center_lon(ocn_add) - pi2
        if (grid_center_lon(ocn_add) < 0.0) &
            grid_center_lon(ocn_add) = grid_center_lon(ocn_add) + pi2
      enddo

!-----------------------------------------------------------------------
!
!     compute cell areas in same way as POP
!
!-----------------------------------------------------------------------

      n = 0
      do j=1,ny
        if (j > 1) then
          jm1 = j-1
        else
          jm1 = 1
        endif
        do i=1,nx
          if (i > 1) then
            im1 = i-1
          else
            im1 = nx
          endif

          n = n+1

          dxt = half*(HTN(i,j) + HTN(i,jm1))
          dyt = half*(HTE(i,j) + HTE(im1,j))
          if (dxt == zero) dxt=one
          if (dyt == zero) dyt=one

          grid_area(n) = dxt*dyt*area_norm
        end do
      end do

!-----------------------------------------------------------------------
!
!     intialize GeneralGrid
!
!-----------------------------------------------------------------------

      call MCT_GGrid_init(GGrid=GGrid, &
                          CoordChars="grid_center_lat:&
			             &grid_center_lon", &
			  WeightChars="grid_area", &
		          OtherChars="grid_corner_lat_1:&
			             &grid_corner_lat_2:&
				     &grid_corner_lat_3:&
				     &grid_corner_lat_4:&
				     &grid_corner_lon_1:&
				     &grid_corner_lon_2:&
				     &grid_corner_lon_3:&
				     &grid_corner_lon_4", &
	                  IndexChars="grid_imask", &
                          lsize=grid_size)

      center_lat = MCT_GGrid_indexRA(GGrid,'grid_center_lat')
      center_lon = MCT_GGrid_indexRA(GGrid,'grid_center_lon')
      corner_lat = MCT_GGrid_indexRA(GGrid,'grid_corner_lat_1')
      corner_lon = MCT_GGrid_indexRA(GGrid,'grid_corner_lon_1')
      area       = MCT_GGrid_indexRA(GGrid,'grid_area')
      imask      = MCT_GGrid_indexIA(GGrid,'grid_imask')

      GGrid%data%rattr(center_lat,1:grid_size) = &
	   grid_center_lat(1:grid_size)
      GGrid%data%rattr(center_lon,1:grid_size) = &
	   grid_center_lon(1:grid_size)
      GGrid%data%rattr(area,1:grid_size) = &
	   grid_area(1:grid_size)
      GGrid%data%iattr(imask,1:grid_size) = &
	   grid_imask(1:grid_size)

      do p = 1,grid_corners
	 GGrid%data%rattr(corner_lat+p-1,1:grid_size) = &
	      grid_corner_lat(p,1:grid_size)
	 GGrid%data%rattr(corner_lon+p-1,1:grid_size) = &
	   grid_corner_lon(p,1:grid_size)
      enddo

      deallocate(grid_imask, grid_area,            &
	         grid_center_lat, grid_center_lon, &
		 grid_corner_lat, grid_corner_lon, &
		 HTN, HTE, stat=ier)

      if(ier/=0) call die(myname_,"deallocate(grid_imask... ", ier)


!***********************************************************************

    end subroutine convertPOPT

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!



