!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: mutils.F90,v 1.8 2005-11-18 23:15:38 rloy Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !MODULE: mutils -- utilities for the sequential climate example
!
! !DESCRIPTION:
!
! !INTERFACE:
!
module mutils

! module of utilties for the sequential climate example
!

  implicit none

  private
! except

! !PUBLIC TYPES:

  public get_index

  contains
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: get_index - get local index array and size
! for 3 standard decompositions of a grid.
!
! !DESCRIPTION:
! The routine get_index will return a local index array and size that can
! be passed to a GSMap_init routine for three possible decompositions:
! R - by row or latitude
! C - by column or longitude
! RC - row and column or checkerboard
! choice is determined by the value of ldecomp.
!
! !INTERFACE:

subroutine get_index(ldecomp,nprocs,myproc,gnx,gny,gridbuf)
! !INPUT PARAMETERS:
!
  character(len=*),intent(inout) :: ldecomp   !  decomp choice
  integer,intent(in)             :: nprocs    ! total number of MPI processes
  integer,intent(in)             :: myproc    ! my rank in local communicator
  integer,intent(in)             :: gnx       ! total points in X direction
  integer,intent(in)             :: gny       ! total points in Y direction

! !OUTPUT PARAMETERS:
!
  integer,dimension(:),pointer :: gridbuf  ! local index array
!
!EOP ___________________________________________________________________

  integer :: npesx,npesy,ng,ny,n,i,j,nx,ig,jg,nseg,factor


! default decomp is R
   if((trim(ldecomp) .ne. 'R') .and. (ldecomp .ne. 'C') .and. (ldecomp .ne. 'RC')) then
      ldecomp = 'R'
   endif

! A 'by-row' or 'by-latitude' decomposition
  if(trim(ldecomp) .eq. 'R') then
   npesx=1
   npesy=nprocs
   nx=gnx
   ny=gny/npesy
   allocate(gridbuf(nx*ny))
   n=0
   do j=1,ny
     do i=1,nx
      n=n+1
      ig=i
      jg = j + myProc*ny
      ng =(jg-1)*gnx + ig
      gridbuf(n)=ng
     enddo
   enddo

! A 'by-column' or 'by-longitude' decomposition
  else if (ldecomp .eq. 'C') then
   npesx=nprocs
   npesy=1
   nx=gnx/npesx
   ny=gny
   allocate(gridbuf(nx*ny))
   n=0
   do j=1,ny
    do i=1,nx
      n=n+1
      ig=i + myProc*nx
      jg= j
      ng=(jg-1)*gnx + ig
      gridbuf(n)=ng
    enddo
   enddo

! A 'row-columen' or 'checkerboard' decomposition
  else if (ldecomp .eq. 'RC') then
  ! find the closest square
   factor=1
   do i=2,INT(sqrt(FLOAT(nprocs)))
     if ( (nprocs/i) * i .eq. nprocs) then
       factor = i
     endif
   enddo
   npesx=factor
   npesy=nprocs/factor
   nx=gnx/npesx
   ny=gny/npesy
!   write(6,*) 'RC',factor,npesy,nx,ny
   allocate(gridbuf(nx*ny))
   n=0
   do j=1,ny
     do i=1,nx
       n=n+1
       ig=mod(myProc,npesx)*nx+i
       jg=(myProc/npesx)*ny+j
       ng=(jg-1)*gnx + ig
       gridbuf(n)=ng
     enddo
   enddo


  endif

end subroutine get_index




end module mutils
