!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!     This program creates a remapping grid file for Gaussian lat/lon
!     grids (for spectral transform codes).
!
!-----------------------------------------------------------------------
!
!     CVS:$Id: convertgauss.F90,v 1.3 2002-11-14 17:11:07 eong Exp $
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

      subroutine convertgauss(GGrid, nx, ny)

!-----------------------------------------------------------------------
!
!     This file creates a remapping grid file for a Gaussian grid
!
!-----------------------------------------------------------------------

      use m_AttrVect,only    : AttrVect
!      use m_GeneralGrid,only : MCT_GGrid_init => init
      use m_GeneralGrid,only : MCT_GGrid_initUnstructured => initUnstructured
      use m_GeneralGrid,only : MCT_GGrid_indexIA => indexIA
      use m_GeneralGrid,only : MCT_GGrid_indexRA => indexRA
      use m_GeneralGrid,only : GeneralGrid
      use m_die
      use m_stdio

      implicit none

!-----------------------------------------------------------------------
!
!     variables that describe the grid
!
!     T42: nx=128 ny=64
!     T62: nx=192 ny=94
!
!-----------------------------------------------------------------------

      type(GeneralGrid),       intent(out) :: GGrid
      integer,                 intent(in) :: nx
      integer,                 intent(in) :: ny

      integer :: grid_size

      integer, parameter :: &
                   grid_rank = 2, &
                   grid_corners = 4

      integer, dimension(grid_rank) :: &
                   grid_dims

!-----------------------------------------------------------------------
!
!     grid coordinates and masks
!
!-----------------------------------------------------------------------

      integer, dimension(:), allocatable :: &
                   grid_imask

      real, dimension(:), allocatable :: &
	           grid_area      ,  & ! area weights
                   grid_center_lat,  & ! lat/lon coordinates for
                   grid_center_lon     ! each grid center in degrees

      real, dimension(:,:), allocatable :: &
                   grid_corner_lat,  & ! lat/lon coordinates for
                   grid_corner_lon     ! each grid corner in degrees


!-----------------------------------------------------------------------
!
!     defined constants
!
!-----------------------------------------------------------------------

      real, parameter ::            &
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

!-----------------------------------------------------------------------
!
!     other local variables
!
!-----------------------------------------------------------------------

      character(len=*),parameter :: myname_= 'convertgauss'

      integer :: i, j, k, p, q, r, ier, atm_add

      integer :: center_lat, center_lon, &
	         corner_lat, corner_lon, &
		 imask, area

      real :: dlon, minlon, maxlon, centerlon, &
	      minlat, maxlat, centerlat

      real, dimension(ny) :: gauss_root, gauss_wgt, gauss_lat

      real, dimension(:), pointer :: PointData
      integer :: offset

!-----------------------------------------------------------------------
!
!     compute longitudes of cell centers and corners.  set up alon
!     array for search routine.
!
!-----------------------------------------------------------------------

      grid_size = nx*ny

      allocate(grid_imask(grid_size), &
	       grid_area(grid_size),  &
	       grid_center_lat(grid_size), &
	       grid_center_lon(grid_size), &
               grid_corner_lat(grid_corners,grid_size), &
	       grid_corner_lon(grid_corners,grid_size), stat=ier)

      if(ier/=0) call die(myname_,"allocate(grid_imask... ", ier)

      grid_dims(1) = nx
      grid_dims(2) = ny

      dlon = 360./nx

      do i=1,nx

        centerlon = (i-1)*dlon
        minlon = centerlon - half*dlon
        maxlon = centerlon + half*dlon

        do j=1,ny
          atm_add = (j-1)*nx + i

          grid_center_lon(atm_add  ) = centerlon
          grid_corner_lon(1,atm_add) = minlon
          grid_corner_lon(2,atm_add) = maxlon
          grid_corner_lon(3,atm_add) = maxlon
          grid_corner_lon(4,atm_add) = minlon
        end do

      end do

!-----------------------------------------------------------------------
!
!     compute Gaussian latitudes and store in gauss_wgt.
!
!-----------------------------------------------------------------------

      call gquad(ny, gauss_root, gauss_wgt)
      do j=1,ny
        gauss_lat(j) = pih - gauss_root(ny+1-j)
      end do

!-----------------------------------------------------------------------
!
!     compute latitudes at cell centers and corners.  set up alat
!     array for search routine.
!
!-----------------------------------------------------------------------

      do j=1,ny
        centerlat = gauss_lat(j)

        if (j .eq. 1) then
          minlat = -pih
        else
          minlat = ATAN((COS(gauss_lat(j-1)) - &
                         COS(gauss_lat(j  )))/ &
                        (SIN(gauss_lat(j  )) - &
                         SIN(gauss_lat(j-1))))
        endif

        if (j .eq. ny) then
          maxlat = pih
        else
          maxlat = ATAN((COS(gauss_lat(j  )) - &
                         COS(gauss_lat(j+1)))/ &
                        (SIN(gauss_lat(j+1)) - &
                         SIN(gauss_lat(j  ))))
        endif

        do i=1,nx
          atm_add = (j-1)*nx + i
          grid_center_lat(atm_add  ) = centerlat*360./pi2
          grid_corner_lat(1,atm_add) = minlat*360./pi2
          grid_corner_lat(2,atm_add) = minlat*360./pi2
          grid_corner_lat(3,atm_add) = maxlat*360./pi2
          grid_corner_lat(4,atm_add) = maxlat*360./pi2
	  grid_area(atm_add) = gauss_wgt(j)*pi2/nx
        end do

      end do

!-----------------------------------------------------------------------
!
!     define mask
!
!-----------------------------------------------------------------------

      grid_imask = 1

!-----------------------------------------------------------------------
!
!     intialize GeneralGrid
!
!-----------------------------------------------------------------------

!      call MCT_GGrid_init(GGrid=GGrid, &
!                          CoordChars="grid_center_lat:&
!			             &grid_center_lon", &
!			  WeightChars="grid_area", &
!		          OtherChars="grid_corner_lat_1:&
!			             &grid_corner_lat_2:&
!				     &grid_corner_lat_3:&
!				     &grid_corner_lat_4:&
!				     &grid_corner_lon_1:&
!				     &grid_corner_lon_2:&
!				     &grid_corner_lon_3:&
!				     &grid_corner_lon_4", &
!	                  IndexChars="grid_imask", &
!                          lsize=grid_size)

! Create and fill PointData(:) array for unstructured-style GeneralGrid_init

      allocate(PointData(2*grid_size), stat=ier)
      if(ier /= 0) then
	 write(stderr,'(2a,i8)') myname_, &
	      ':: allocate(PointData(...) failed with ier=',ier
	 call die(myname_)
      endif

      do i=1,grid_size
	 offset = 2 * (i-1)
	 PointData(offset+1) = grid_center_lat(i)
	 PointData(offset+2) = grid_center_lon(i)
      end do

      call MCT_GGrid_initUnstructured(GGrid=GGrid, &
                                     CoordChars="grid_center_lat:&
			             &grid_center_lon", &
                                     CoordSortOrder="grid_center_lat:&
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
				     nDims=2, nPoints=grid_size, &
				     PointData=PointData)

      deallocate(PointData, stat=ier)
      if(ier /= 0) then
	 write(stderr,'(2a,i8)') myname_, &
	      ':: deallocate(PointData...) failed with ier=',ier
	 call die(myname_)
      endif

!      center_lat = MCT_GGrid_indexRA(GGrid,'grid_center_lat')
!      center_lon = MCT_GGrid_indexRA(GGrid,'grid_center_lon')
      corner_lat = MCT_GGrid_indexRA(GGrid,'grid_corner_lat_1')
      corner_lon = MCT_GGrid_indexRA(GGrid,'grid_corner_lon_1')
      area       = MCT_GGrid_indexRA(GGrid,'grid_area')
      imask      = MCT_GGrid_indexIA(GGrid,'grid_imask')

!      GGrid%data%rattr(center_lat,1:grid_size) = &
!	   grid_center_lat(1:grid_size)
!      GGrid%data%rattr(center_lon,1:grid_size) = &
!	   grid_center_lon(1:grid_size)
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
		 stat=ier)

      if(ier/=0) call die(myname_,"deallocate(grid_imask... ", ier)


!-----------------------------------------------------------------------

    end subroutine convertgauss

!***********************************************************************

      subroutine gquad(l,root,w)

!-----------------------------------------------------------------------
!
!     This subroutine finds the l roots (in theta) and gaussian weights
!     associated with the legendre polynomial of degree l > 1.
!
!-----------------------------------------------------------------------

      use m_die

      implicit none

!-----------------------------------------------------------------------
!
!     intent(in)
!
!-----------------------------------------------------------------------

      integer, intent(in) :: l

!-----------------------------------------------------------------------
!
!     intent(out)
!
!-----------------------------------------------------------------------

      real, dimension(l), intent(out) :: root, w

!-----------------------------------------------------------------------
!
!     defined constants
!
!-----------------------------------------------------------------------

      real, parameter ::            &
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

!-----------------------------------------------------------------------
!
!     local
!
!-----------------------------------------------------------------------

      integer :: l1, l2, l22, l3, k, i, j, loop_counter

      real :: del,co,p1,p2,p3,t1,t2,slope,s,c,pp1,pp2,p00

!-----MUST adjust tolerance for newton convergence-----!

      ! Modify tolerance level to the precision of the real numbers:
      ! Increase for lower precision, decrease for higher precision.

      real, parameter :: RTOL = 1.0e4*epsilon(0.)

!------------------------------------------------------!

!-----------------------------------------------------------------------
!
!     Define useful constants.
!
!-----------------------------------------------------------------------

      del= pi/float(4*l)
      l1 = l+1
      co = float(2*l+3)/float(l1**2)
      p2 = 1.0
      t2 = -del
      l2 = l/2
      k = 1
      p00 = one/sqrt(two)

!-----------------------------------------------------------------------
!
!     Start search for each root by looking for crossing point.
!
!-----------------------------------------------------------------------

      do i=1,l2
   10    t1 = t2
         t2 = t1+del
         p1 = p2
         s = sin(t2)
         c = cos(t2)
         pp1 = 1.0
         p3 = p00
         do j=1,l1
            pp2 = pp1
            pp1 = p3
            p3 = 2.0*sqrt((float(j**2)-0.250)/float(j**2))*c*pp1- &
                 sqrt(float((2*j+1)*(j-1)*(j-1))/ &
                 float((2*j-3)*j*j))*pp2
         end do
         p2 = pp1
         if ((k*p2).gt.0) goto 10

!-----------------------------------------------------------------------
!
!        Now converge using Newton-Raphson.
!
!-----------------------------------------------------------------------

         k = -k
	 loop_counter=0
   20    continue
	    loop_counter=loop_counter+1
            slope = (t2-t1)/(p2-p1)
            t1 = t2
            t2 = t2-slope*p2
            p1 = p2
            s = sin(t2)
            c = cos(t2)
            pp1 = 1.0
            p3 = p00
            do j=1,l1
               pp2 = pp1
               pp1 = p3
               p3 = 2.0*sqrt((float(j**2)-0.250)/float(j**2))*c*pp1- &
                    sqrt(float((2*j+1)*(j-1)*(j-1))/ &
                    float((2*j-3)*j*j))*pp2
            end do
            p2 = pp1

	    if(loop_counter > 1e4) then
	       call die("subroutine gquad",&
		    "ERROR:: Precision of reals is too low. &
		    & Increase the magnitude of RTOL.",0)
	    endif

         if (abs(p2).gt.RTOL) goto 20
         root(i) = t2
         w(i) = co*(sin(t2)/p3)**2
      end do

!-----------------------------------------------------------------------
!
!     If l is odd, take care of odd point.
!
!-----------------------------------------------------------------------

      l22 = 2*l2
      if (l22 .ne. l) then
         l2 = l2+1
         t2 = pi/2.0
         root(l2) = t2
         s = sin(t2)
         c = cos(t2)
         pp1 = 1.0
         p3 = p00
         do j=1,l1
            pp2 = pp1
            pp1 = p3
            p3 = 2.0*sqrt((float(j**2)-0.250)/float(j**2))*c*pp1- &
                 sqrt(float((2*j+1)*(j-1)*(j-1))/ &
                 float((2*j-3)*j*j))*pp2
         end do
         p2 = pp1
         w(l2) = co/p3**2
      endif

!-----------------------------------------------------------------------
!
!     Use symmetry to compute remaining roots and weights.
!
!-----------------------------------------------------------------------

      l3 = l2+1
      do i=l3,l
         root(i) = pi-root(l-i+1)
         w(i) = w(l-i+1)
      end do

!-----------------------------------------------------------------------

      end subroutine gquad

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
