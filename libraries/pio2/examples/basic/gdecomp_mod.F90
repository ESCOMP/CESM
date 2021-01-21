module gdecomp_mod

   use kinds_mod
#if !defined(STANDALONE_TEST)
   use pio_support, only : piodie  ! _EXTERNAL
   use pio, only : pio_offset_kind   ! _EXTERNAL
#endif

   implicit none
   private

   public :: gdecomp_type

   public :: gdecomp_read_nml
   public :: gdecomp_set
   public :: gdecomp_print
   public :: gdecomp_DOF
   public :: camlike_decomp_generator
   public :: mpas_decomp_generator

   type :: gdecomp_type
      private
      integer(i4) :: nxg,nyg,nzg      ! global grid size
      integer(i4) :: gdx,gdy,gdz      ! block size
      integer(i4) :: bdx,bdy,bdz      ! block ordering
      integer(i4) :: npes,nblksppe    ! total pes, avg blocks/pe
      character(len=16) :: grdorder   ! grid order
      character(len=16) :: grddecomp  ! grid decomp strategy
      character(len=16) :: blkorder   ! block order
      character(len=16) :: blkdecomp1 ! block decomp strategy
      character(len=16) :: blkdecomp2 ! block decomp strategy
      character(len=128):: nml_file   ! namelist filename if used
      character(len=16) :: nml_var    ! namelist variable if used
   end type
      
   character(len=*),parameter :: modname = 'gdecomp_mod'
   integer(i4),parameter :: master_task = 0

!==================================================================
contains

!==================================================================
!==================================================================
!==================================================================
   subroutine gdecomp_set(gdecomp,nxg,nyg,nzg,gdx,gdy,gdz,bdx,bdy,bdz, &
     npes,nblksppe,grdorder,grddecomp,blkorder,blkdecomp1,blkdecomp2, &
     name,my_task)

   implicit none

   type(gdecomp_type), intent(inout) :: gdecomp

!  NOTE: not all of these are optional, but optional allows
!        them to be called in arbitrary order 

   integer(i4),optional :: nxg,nyg,nzg      ! global grid size
   integer(i4),optional :: gdx,gdy,gdz      ! block size
   integer(i4),optional :: bdx,bdy,bdz      ! block ordering
   integer(i4),optional :: npes,nblksppe    ! total pes, avg blocks/pe
   character(len=*),optional :: grdorder    ! grid order
   character(len=*),optional :: grddecomp   ! grid decomp strategy
   character(len=*),optional :: blkorder    ! block order
   character(len=*),optional :: blkdecomp1  ! block decomp strategy
   character(len=*),optional :: blkdecomp2  ! block decomp strategy
   character(len=*),optional :: name        ! optional input name
   integer(i4),optional :: my_task          ! task number

   character(len=*),parameter :: subname = 'gdecomp_set'

   gdecomp%nml_file='set_manually'
   if (present(name)) then
      gdecomp%nml_var=trim(name)
   else
      gdecomp%nml_var='none'
   endif

   if (present(nxg)) then
      gdecomp%nxg = nxg
   else
      call piodie(__FILE__,__LINE__,trim(subname)//' nxg must be set')
   endif

   if (present(nyg)) then
      gdecomp%nyg = nyg
   else
      call piodie(__FILE__,__LINE__,trim(subname)//' nyg must be set')
   endif

   if (present(nzg)) then
      gdecomp%nzg = nzg
   else
      call piodie(__FILE__,__LINE__,trim(subname)//' nzg must be set')
   endif

   if (present(npes)) then
      gdecomp%npes = npes
   else
      call piodie(__FILE__,__LINE__,trim(subname)//' npes must be set')
   endif

   if (present(nblksppe)) then
      gdecomp%nblksppe = nblksppe
   else
      gdecomp%nblksppe = 1
   endif

   if (present(grdorder)) then
      gdecomp%grdorder = grdorder
   else
      gdecomp%grdorder = 'xyz'
   endif

   if (present(grddecomp)) then
      gdecomp%grddecomp = grddecomp
   else
      gdecomp%grddecomp = 'xyz'
   endif

   if (present(gdx)) then
      gdecomp%gdx = gdx
   else
      gdecomp%gdx = 0
   endif

   if (present(gdy)) then
      gdecomp%gdy = gdy
   else
      gdecomp%gdy = 0
   endif

   if (present(gdz)) then
      gdecomp%gdz = gdz
   else
      gdecomp%gdz = 0
   endif

   if (present(blkorder)) then
      gdecomp%blkorder = blkorder
   else
      gdecomp%blkorder = 'xyz'
   endif

   if (present(blkdecomp1)) then
      gdecomp%blkdecomp1 = blkdecomp1
   else
      gdecomp%blkdecomp1 = 'xyz'
   endif

   if (present(blkdecomp2)) then
      gdecomp%blkdecomp2 = blkdecomp2
   else
      gdecomp%blkdecomp2 = ''
   endif

   if (present(bdx)) then
      gdecomp%bdx = bdx
   else
      gdecomp%bdx = 0
   endif

   if (present(bdy)) then
      gdecomp%bdy = bdy
   else
      gdecomp%bdy = 0
   endif

   if (present(bdz)) then
      gdecomp%bdz = bdz
   else
      gdecomp%bdz = 0
   endif

   if (present(my_task)) then
      if (my_task == master_task) call gdecomp_print(gdecomp)
   endif

   end subroutine gdecomp_set
   
!==================================================================
   subroutine gdecomp_read_nml(gdecomp,nml_file,nml_var,my_task,ntasks,gdims)

   implicit none

   type(gdecomp_type), intent(inout) :: gdecomp
   character(len=*),intent(in) :: nml_file        ! input namelist file
   character(len=*),intent(in) :: nml_var         ! input namelist variable
   integer(i4), optional, intent(in)  :: my_task  ! task number
   integer(i4), optional, intent(in)  :: ntasks   ! total number of tasks
   integer(i4), optional, intent(in)  :: gdims(3) ! global grid size

   ! --- namelist ---
   integer(i4) :: nxg,nyg,nzg
   integer(i4) :: gdx,gdy,gdz
   integer(i4) :: bdx,bdy,bdz
   integer(i4) :: npes,nblksppe
   character(len=16) :: grdorder
   character(len=16) :: grddecomp
   character(len=16) :: blkorder
   character(len=16) :: blkdecomp1
   character(len=16) :: blkdecomp2
   namelist / compdof_nml / &
      nxg,nyg,nzg,npes,nblksppe, &
      grdorder,grddecomp,gdx,gdy,gdz, &
      blkorder,blkdecomp1,blkdecomp2,bdx,bdy,bdz
   namelist / iodof_nml / &
      nxg,nyg,nzg,npes,nblksppe, &
      grdorder,grddecomp,gdx,gdy,gdz, &
      blkorder,blkdecomp1,blkdecomp2,bdx,bdy,bdz
   character(len=*),parameter :: subname = 'gdecomp_read_nml'

   nxg=1;nyg=1;nzg=1
   gdx=0;gdy=0;gdz=0
   bdx=0;bdy=0;bdz=0
   npes=1
   nblksppe=1
   grdorder='xyz'
   grddecomp='xy'
   blkorder='xyz'
   blkdecomp1='xy'
   blkdecomp2=''

   if (trim(nml_var) == 'comp') then
      open(10,file=nml_file,status='old')
      read(10,nml=compdof_nml)
      close(10)
   elseif (trim(nml_var) == 'io') then
      open(10,file=nml_file,status='old')
      read(10,nml=iodof_nml)
      close(10)
   endif

   if (present(ntasks)) then
      npes=ntasks
   endif
   if (present(gdims)) then
      nxg = gdims(1)
      nyg = gdims(2)
      nzg = gdims(3)
   endif

   gdecomp%nml_file = trim(nml_file)
   gdecomp%nml_var  = trim(nml_var)
   gdecomp%nxg = nxg
   gdecomp%nyg = nyg
   gdecomp%nzg = nzg
   gdecomp%npes = npes
   gdecomp%nblksppe = nblksppe

   gdecomp%grdorder   = grdorder
   gdecomp%grddecomp  = grddecomp
   gdecomp%gdx = gdx
   gdecomp%gdy = gdy
   gdecomp%gdz = gdz

   gdecomp%blkorder   = blkorder
   gdecomp%blkdecomp1 = blkdecomp1
   gdecomp%blkdecomp2 = blkdecomp2
   gdecomp%bdx = bdx
   gdecomp%bdy = bdy
   gdecomp%bdz = bdz

   if (present(my_task)) then
      if (my_task == master_task) call gdecomp_print(gdecomp)
   endif

   end subroutine gdecomp_read_nml
   
!==================================================================

   subroutine gdecomp_print(gdecomp)

   implicit none

   type(gdecomp_type),intent(in) :: gdecomp
   character(len=*),parameter :: subname = 'gdecomp_print'

   write(6,*) ' '
   write(6,*) trim(subname),'   nml_file = ',trim(gdecomp%nml_file)
   write(6,*) trim(subname),'    nml_var = ',trim(gdecomp%nml_var)
   write(6,*) trim(subname),'        nxg = ',gdecomp%nxg
   write(6,*) trim(subname),'        nyg = ',gdecomp%nyg
   write(6,*) trim(subname),'        nzg = ',gdecomp%nzg
   write(6,*) trim(subname),'       npes = ',gdecomp%npes
   write(6,*) trim(subname),'   nblksppe = ',gdecomp%nblksppe
   write(6,*) trim(subname),'   grdorder = ',gdecomp%grdorder
   write(6,*) trim(subname),'  grddecomp = ',gdecomp%grddecomp
   write(6,*) trim(subname),'        gdx = ',gdecomp%gdx
   write(6,*) trim(subname),'        gdy = ',gdecomp%gdy
   write(6,*) trim(subname),'        gdz = ',gdecomp%gdz
   write(6,*) trim(subname),' blkdecomp1 = ',gdecomp%blkdecomp1
   write(6,*) trim(subname),' blkdecomp2 = ',gdecomp%blkdecomp2
   write(6,*) trim(subname),'        bdx = ',gdecomp%bdx
   write(6,*) trim(subname),'        bdy = ',gdecomp%bdy
   write(6,*) trim(subname),'        bdz = ',gdecomp%bdz
   write(6,*) trim(subname),'   blkorder = ',gdecomp%blkorder
   write(6,*) ' '

   end subroutine gdecomp_print

!==================================================================
   subroutine gdecomp_DOF(gdecomp,my_task,DOF,start,count,write_decomp,test)

   use netcdf   ! _EXTERNAL

   implicit none

   type(gdecomp_type), intent(in)  :: gdecomp
   integer(i4),        intent(in)  :: my_task  ! task number
   integer(kind=pio_offset_kind),pointer             :: DOF(:)   ! allocated in this routine
   integer(i4),        intent(out) :: start(3) ! netcdf start index
   integer(i4),        intent(out) :: count(3) ! netcdf count index
   logical, optional,  intent(in)  :: write_decomp  ! write gdecomp.nc output file
   logical, optional,  intent(in)  :: test     ! single pe test mode

   integer(i4),parameter :: ndims=3
   integer(i4) :: gsiz(ndims)   ! global size
   integer(i4) :: bsiz(ndims)   ! block size
   integer(i4) :: nblk(ndims)   ! number of blocks
   integer(i4) :: dblk(ndims)   ! block decomp
   integer(i4) :: nbor(ndims)   ! block ordering
   integer(i4) :: nn(ndims)     ! index ordering
   integer(i4),pointer :: blkid(:,:,:)
   integer(i4),pointer :: tskid(:,:,:)
   integer(i4),pointer :: bxyzbord(:)
   integer(i4),pointer :: bxyzpord(:)
   integer(i4),pointer :: bordpord(:)
   integer(i4),pointer :: testdof(:,:)
   integer(i4),pointer :: bordstart(:,:)
   integer(i4),pointer :: bordend(:,:)
   integer(i4),pointer :: pstart(:,:)
   integer(i4),pointer :: pend(:,:)
   integer(i4),pointer :: cnta(:)
   integer(i4),pointer :: cntb(:)
   integer(i4) :: cntmax,cnt1,cnt2
   integer(i4) :: tsk
   integer(i4) :: minv,maxv
   integer(i4) :: ierr,rcode
   integer(i4) :: npesx,nblks,nbors
   integer(i4) :: gnpes
   integer(i4) :: n1,n2,n3,n2b,nbord,nb1,nb2,nb3,nb,nbtmp,n
   integer(kind=pio_offset_kind) :: ii, nbxyz
   integer(i4) :: contval
   logical :: testonly,startok,wdecomp
   logical,save :: first_call = .true.

   integer(i4) :: ncid,dimid(ndims),varid(2)
   character(len=16) :: dname,vname
   character(len=*),parameter :: ncname = 'gdecomp.nc'

   character(len=*),parameter :: subname = 'gdecomp_DOF'

   ! --- start instructions ---

!DBG   print *,'IAM: ',my_task,'gdecomp_DOF: point #1'
   testonly = .false.
   if (present(test)) then
      testonly = test
   endif
   wdecomp = .false.
   if (present(write_decomp)) then
      wdecomp = write_decomp
   endif
   start = 1
   count = 0

!DBG   print *,'IAM: ',my_task,'gdecomp_DOF: point #2'
   if (.not.testonly) then
      if (my_task < 0) return
      if (my_task < 0 .or. my_task > gdecomp%npes-1) then
         write(6,*) trim(subname),' ERROR: my_task out of range ',my_task,0,gdecomp%npes-1
      endif
   endif

   gsiz(1) = gdecomp%nxg
   gsiz(2) = gdecomp%nyg
   gsiz(3) = gdecomp%nzg
   bsiz(1) = gdecomp%gdx
   bsiz(2) = gdecomp%gdy
   bsiz(3) = gdecomp%gdz
   nbor(1) = gdecomp%bdx
   nbor(2) = gdecomp%bdy
   nbor(3) = gdecomp%bdz
   gnpes   = gdecomp%npes
!DBG   print *,'IAM: ',my_task,'gdecomp_DOF: point #3 gsiz:',gsiz
!DBG   print *,'IAM: ',my_task,'gdecomp_DOF: point #3 bsiz:',bsiz

   if(wdecomp) then 
     allocate(blkid(gsiz(1),gsiz(2),gsiz(3)))
     allocate(tskid(gsiz(1),gsiz(2),gsiz(3)))
     blkid = -1
     tskid = -1
   endif
!DBG   print *,'IAM: ',my_task,'gdecomp_DOF: point #4'



   ! --- calc blocks ---

   npesx = gnpes * gdecomp%nblksppe

   selectcase (trim(gdecomp%grddecomp))
      case default
         call calcdecomp(gdecomp%grddecomp,npesx,gsiz,bsiz,ierr)
!DBG	 print *,'gdecomp_DOF: grdecomp is:',gdecomp%grddecomp
   end select
!DBG   print *,'IAM: ',my_task,'gdecomp_DOF: point #5 bsiz:',bsiz
!DBG   stop "after call to gdecomp_print"

   ! --- sort and arrange blocks ---

   call pad_div(nblk(1),gsiz(1),bsiz(1))
   call pad_div(nblk(2),gsiz(2),bsiz(2))
   call pad_div(nblk(3),gsiz(3),bsiz(3))
   nblks = nblk(1)*nblk(2)*nblk(3)
   contval = 0

   selectcase (trim(gdecomp%blkdecomp1))
!!      case ('sfcxy')
      case ('cont1d')
         contval = maxval(nbor)
         if (contval <= 0) then
            write(6,*) trim(subname),' ERROR: contval must be > 0 ',nbor
            call piodie(__FILE__,__LINE__)
         endif
         if (my_task == master_task) &
            write(6,*) trim(subname),' blkdecomp1 = ',trim(gdecomp%blkdecomp1),' contval = ',contval
      case ('cont1dm')
         call pad_div(contval,nblks,gnpes)
         if (contval <= 0) then
            write(6,*) trim(subname),' ERROR: contval must be > 0 ',nbor
            call piodie(__FILE__,__LINE__)
         endif
         if (my_task == master_task) &
            write(6,*) trim(subname),' blkdecomp1 = ',trim(gdecomp%blkdecomp1),' contval = ',contval
      case default
         call calcdecomp(gdecomp%blkdecomp1,gnpes,nblk,nbor,ierr)
   end select

   nbors = nbor(1)*nbor(2)*nbor(3)
   dblk = 0
   if (nbors > 0) then
      call pad_div(dblk(1),nblk(1),nbor(1))
      call pad_div(dblk(2),nblk(2),nbor(2))
      call pad_div(dblk(3),nblk(3),nbor(3))
   endif

   call calcorder(gdecomp%blkorder,nb1,nb2,nb3,ierr)
   allocate(bxyzbord(nblks),bxyzpord(nblks),bordpord(nblks))
   allocate(bordstart(3,nblks),bordend(3,nblks))
   bxyzbord = -1
   bxyzpord = -1
   bordpord = -1
   bordstart = -1
   bordend = -1
   do n3 = 1,nblk(3)
   do n2 = 1,nblk(2)
   do n1 = 1,nblk(1)
      nn(1)=n1; nn(2)=n2; nn(3)=n3
      nbxyz = (nn(  3)-1)*nblk(  1)*nblk(  2) + (nn(  2)-1)*nblk(  1) + nn(  1)
      nbord = (nn(nb3)-1)*nblk(nb1)*nblk(nb2) + (nn(nb2)-1)*nblk(nb1) + nn(nb1)
      if (nbxyz < 1 .or. nbxyz > nblks .or. nbord < 1 .or. nbord > nblks) then
         write(6,*) trim(subname),' ERROR: bxyzbord ',nbxyz,nbord
         call piodie(__FILE__,__LINE__)
      endif
      bxyzbord(nbxyz) = nbord
      bordstart(1,nbord) = (n1-1)*bsiz(1) + 1
      bordstart(2,nbord) = (n2-1)*bsiz(2) + 1
      bordstart(3,nbord) = (n3-1)*bsiz(3) + 1
      bordend  (1,nbord) = min((n1)*bsiz(1),gsiz(1))
      bordend  (2,nbord) = min((n2)*bsiz(2),gsiz(2))
      bordend  (3,nbord) = min((n3)*bsiz(3),gsiz(3))
      if (contval > 0) then
         tsk = mod(((nbord-1)/contval),gnpes)
         if (tsk < 0 .or. tsk >= gnpes) then
            write(6,*) trim(subname),' ERROR: tsk1 ',tsk,nbord,contval,gnpes
            call piodie(__FILE__,__LINE__)
         endif
         bxyzpord(nbxyz) = tsk
      else
         tsk = ((n3-1)/nbor(3))*dblk(2)*dblk(1) + ((n2-1)/nbor(2))*dblk(1) + (n1-1)/nbor(1)
         if (nbors <= 0 .or. tsk < 0 .or. tsk >= gnpes) then
            write(6,*) trim(subname),' ERROR: tsk2 ',tsk,gnpes,n1,n2,n3,nbor,dblk
            call piodie(__FILE__,__LINE__)
         endif
         bxyzpord(nbxyz) = tsk
      endif
   enddo
   enddo
   enddo

   ! --- "refine" blkdecomp1 decomp ---

   selectcase (trim(gdecomp%blkdecomp2))
      case ('')
         ! ok, but does nothing
      case ('ysym2')
         if (mod(nblk(2),2) /= 0) then
            write(6,*) trim(subname),' ERROR: ysym2 option must have factor of 2 in y nblocks '
            call piodie(__FILE__,__LINE__)
         endif
      case ('ysym4')
         if (mod(nblk(2),4) /= 0) then
            write(6,*) trim(subname),' ERROR: ysym4 option must have factor of 4 in y nblocks '
            call piodie(__FILE__,__LINE__)
         endif
      case default
         write(6,*) trim(subname),' ERROR: blkdecomp2 not supported ',trim(gdecomp%blkdecomp2)
         call piodie(__FILE__,__LINE__)
   end select

   if (trim(gdecomp%blkdecomp2) == 'ysym4') then
      do n3 = 1,nblk(3)
      do n2 = nblk(2)/4+1,nblk(2)/2
      do n1 = 1,nblk(1)
         n2b = nblk(2)/2-n2+1
         nbxyz = (n3-1)*nblk(1)*nblk(2) + (n2 -1)*nblk(1) + n1
         nbtmp = (n3-1)*nblk(1)*nblk(2) + (n2b-1)*nblk(1) + n1
         bxyzpord(nbxyz) = bxyzpord(nbtmp)
      enddo
      enddo
      enddo
   endif

   if (trim(gdecomp%blkdecomp2) == 'ysym2' .or. trim(gdecomp%blkdecomp2) == 'ysym4') then
      do n3 = 1,nblk(3)
      do n2 = nblk(2)/2+1,nblk(2)
      do n1 = 1,nblk(1)
         n2b = nblk(2)-n2+1
         nbxyz = (n3-1)*nblk(1)*nblk(2) + (n2 -1)*nblk(1) + n1
         nbtmp = (n3-1)*nblk(1)*nblk(2) + (n2b-1)*nblk(1) + n1
         bxyzpord(nbxyz) = bxyzpord(nbtmp)
      enddo
      enddo
      enddo
   endif

   ! derive one more block mapping
   do nb = 1,nblks
      bordpord(bxyzbord(nb)) = bxyzpord(nb)
   enddo

!   if (testonly) then
!      write(6,*) ' '
!      do nb = 1,nblks
!         write(6,*) trim(subname),' nb,bxyzbord,bxyzpord,bordpord ',nb,bxyzbord(nb),bxyzpord(nb),bordpord(nb)
!      enddo
!      write(6,*) ' '
!      do nb = 1,nblks
!         write(6,*) trim(subname),' nb,bordstart,bordend ',n,bordstart(:,nb),bordend(:,nb)
!      enddo
!      write(6,*) ' '
!   endif

   ! --- map blocks onto gridcells ---

   allocate(cnta(0:gnpes-1),cntb(0:gnpes-1))
   cnta = 0
   cntb = 0
   do n3 = 1,gsiz(3)
   do n2 = 1,gsiz(2)
   do n1 = 1,gsiz(1)
!     ii = (n3-1)*gsiz(2)*gsiz(1) + (n2-1)*gsiz(1) + n1
      nbxyz = ((n3-1)/bsiz(3))*nblk(2)*nblk(1) + ((n2-1)/bsiz(2))*nblk(1) + &
              ((n1-1)/bsiz(1)) + 1
      if(wdecomp) then 
          blkid(n1,n2,n3) = bxyzbord(nbxyz)
          tskid(n1,n2,n3) = bxyzpord(nbxyz)
      endif
! checked above
!      if (tskid(n1,n2,n3) < 0 .or. tskid(n1,n2,n3) >= gnpes) then
!         write(6,*) trim(subname),' ERROR: tskid ',n1,n2,n3,tskid(n1,n2,n3)
!         call piodie(__FILE__,__LINE__)
!      endif
!      cnta(tskid(n1,n2,n3)) = cnta(tskid(n1,n2,n3)) + 1
       cnta(bxyzpord(nbxyz)) = cnta(bxyzpord(nbxyz)) + 1
   enddo
   enddo
   enddo
   cntmax = maxval(cnta)

   ! --- map gridcells to dof ---
   
   if (testonly) then
      allocate(testdof(cntmax,0:gnpes-1))
      testdof = 0
   else
      allocate(testdof(1,1))
      testdof = 0
   endif

   allocate(dof(cnta(my_task)))
   dof = 0
   cntb = 0
   allocate(pstart(3,0:gnpes-1),pend(3,0:gnpes-1))
   pstart = maxval(gsiz)
   pend = 0

   call calcorder(gdecomp%grdorder,nb1,nb2,nb3,ierr)
   do nb = 1,nblks
      tsk = bordpord(nb)
      pstart(1,tsk) = min(pstart(1,tsk),bordstart(1,nb))
      pstart(2,tsk) = min(pstart(2,tsk),bordstart(2,nb))
      pstart(3,tsk) = min(pstart(3,tsk),bordstart(3,nb))
      pend(1,tsk) = max(pend(1,tsk),bordend(1,nb))
      pend(2,tsk) = max(pend(2,tsk),bordend(2,nb))
      pend(3,tsk) = max(pend(3,tsk),bordend(3,nb))
      if (testonly .or. (.not.testonly .and. my_task == tsk)) then
      do n3 = bordstart(nb3,nb),bordend(nb3,nb)
      do n2 = bordstart(nb2,nb),bordend(nb2,nb)
      do n1 = bordstart(nb1,nb),bordend(nb1,nb)
         nn(nb1)=n1
         nn(nb2)=n2
         nn(nb3)=n3
         ii = (nn(3)-1)*gsiz(2)*gsiz(1) + (nn(2)-1)*gsiz(1) + nn(1)
!!         tsk = tskid(nn(1),nn(2),nn(3))
         cntb(tsk) = cntb(tsk) + 1
         if (cntb(tsk) > cntmax) then
            write(6,*) trim(subname),' ERROR: cntb > cntmax ',tsk,cntb(tsk),cntmax
            call piodie(__FILE__,__LINE__)
         endif
         if (testonly) then
            testdof(cntb(tsk),tsk) = ii
         endif
        if (my_task == tsk) dof(cntb(tsk)) = ii
      enddo
      enddo
      enddo
      endif
   enddo
!DBG   print *,__FILE__,__LINE__,cnta
!DBG   print *,__FILE__,__LINE__,cntb

   if (cntb(my_task) /= cnta(my_task)) then
      write(6,*) trim(subname),' ERROR: cntb ne cnta ',tsk,cnta(tsk),cntb(tsk)
      call piodie(__FILE__,__LINE__)
   endif

   startok = .true.
   do n1 = 0,gnpes-1
      cnt1 = cnta(n1)
      cnt2 = (max(pend(1,n1)-pstart(1,n1)+1,0))* &
             (max(pend(2,n1)-pstart(2,n1)+1,0))* &
             (max(pend(3,n1)-pstart(3,n1)+1,0))
      if (cnt1 /= cnt2) then
         startok = .false.
      endif
   enddo

   if (startok) then
      n1 = my_task
      cnt2 = (max(pend(1,n1)-pstart(1,n1)+1,0))* &
             (max(pend(2,n1)-pstart(2,n1)+1,0))* &
             (max(pend(3,n1)-pstart(3,n1)+1,0))
      if (cnt2 == 0) then
         start = 1
         count = 0
      else
         start(1:3) = pstart(1:3,my_task)
         count(1:3) = pend(1:3,my_task) - pstart(1:3,my_task) + 1
      endif
      if (my_task == master_task) &
         write(6,*) trim(subname),' start and count were computed ',my_task,start,count
   else
      start = 1
      count = 0
      if (my_task == master_task) &
         write(6,*) trim(subname),' start and count could NOT be computed '
   endif

!------- MASTER TASK WRITE ------------------------------------- 

   if (my_task == master_task) then

   ! --- write testdof ---

   if (testonly) then
   write(6,*) ' '
   do n1 = 0,gnpes-1
      if (cnta(n1) > 0) then
         minv = testdof(1,n1)
         maxv = testdof(1,n1)
      else
         minv = 0
         maxv = 0
      endif
      do n2 = 1,cnta(n1)
         minv = min(minv,testdof(n2,n1))
         maxv = max(maxv,testdof(n2,n1))
      enddo
      write(6,*) trim(subname),' TESTDOF ntask=',n1,' size=',cnta(n1),&
           ' min=',minv,' max=',maxv,' values=',testdof(1:min(10,cnta(n1)),n1)
   enddo
   endif ! testonly
   deallocate(testdof)
   ! --- write summary ---

   write(6,*) ' '
   write(6,*) trim(subname),' MY_TASK       = ',my_task
   write(6,*) trim(subname),' GRID SIZE     = ',gsiz
   write(6,*) trim(subname),' BLOCK SIZE    = ',bsiz
   write(6,*) trim(subname),' NUM of BLOCKS = ',nblks
   if (nbors > 0) then
   write(6,*) trim(subname),' BLOCK GROUP   = ',nbor
   endif
   if (startok) then
   write(6,*) trim(subname),' START         = ',start
   write(6,*) trim(subname),' COUNT         = ',count
   endif
   write(6,*) ' '

   ! --- write out arrays ---

   if (wdecomp) then
   write(6,*) ' '
   write(6,*) trim(subname),' writing decomp info to file ',trim(ncname)
   write(6,*) ' '
   if (first_call) then
      rcode = nf90_create(ncname,nf90_clobber,ncid)
   else
      rcode = nf90_open(ncname,nf90_write,ncid)      
   endif
   rcode = nf90_redef(ncid)
   dname = trim(gdecomp%nml_var)//'_nx'
   rcode = nf90_def_dim(ncid,dname,gsiz(1),dimid(1))
   dname = trim(gdecomp%nml_var)//'_ny'
   rcode = nf90_def_dim(ncid,dname,gsiz(2),dimid(2))
   dname = trim(gdecomp%nml_var)//'_nz'
   rcode = nf90_def_dim(ncid,dname,gsiz(3),dimid(3))
   vname = trim(gdecomp%nml_var)//'_blkid'
   rcode = nf90_def_var(ncid,vname,NF90_INT,dimid,varid(1))
   vname = trim(gdecomp%nml_var)//'_tskid'
   rcode = nf90_def_var(ncid,vname,NF90_INT,dimid,varid(2))
   rcode = nf90_enddef(ncid)
   rcode = nf90_put_var(ncid,varid(1),blkid)
   rcode = nf90_put_var(ncid,varid(2),tskid)
   rcode = nf90_close(ncid)
   endif

   endif   ! testonly

!------- END MASTER TASK WRITE --------------------------------- 

   if(wdecomp) then 
     deallocate(blkid,tskid)
   endif
   deallocate(cnta,cntb,bxyzbord,bxyzpord,bordpord)
   deallocate(bordstart,bordend,pstart,pend)
   first_call = .false.

   end subroutine gdecomp_DOF

!==================================================================
   subroutine calcorder(type,nb1,nb2,nb3,ierr)

   implicit none

   character(len=*),intent(in) :: type
   integer(i4), intent(out)   :: nb1,nb2,nb3
   integer(i4), intent(out)   :: ierr

   character(len=*),parameter :: subname = 'calcorder'

   selectcase (trim(type))
      case ('xyz')
        nb1=1; nb2=2; nb3=3
      case ('xzy')
        nb1=1; nb2=3; nb3=2
      case ('yxz')
        nb1=2; nb2=1; nb3=3
      case ('yzx')
        nb1=2; nb2=3; nb3=1
      case ('zxy')
        nb1=3; nb2=1; nb3=2
      case ('zyx')
        nb1=3; nb2=2; nb3=1
      case default
         write(6,*) trim(subname),' ERROR: ',trim(type),' not supported'
         call piodie(__FILE__,__LINE__)
   end select

   end subroutine calcorder

!==================================================================

   subroutine calcdecomp(type,npes,gsiz,bsiz,ierr)

   implicit none

   character(len=*),intent(in) :: type
   integer(i4), intent(in)    :: npes
   integer(i4), intent(in)    :: gsiz(:)
   integer(i4), intent(inout) :: bsiz(:)
   integer(i4), intent(out)   :: ierr

   character(len=16) :: option
   character(len=*),parameter :: subname = 'calcdecomp'

   option = ''

!DBG   print *,'calcdecomp: type: ',trim(type),' npes: ',npes
   selectcase (trim(type))

      case ('x')
          bsiz(1) = 0
          if (bsiz(2) == 0) bsiz(2) = gsiz(2)
          if (bsiz(3) == 0) bsiz(3) = gsiz(3)
          call calcbsiz(npes,gsiz,bsiz,option,ierr)

      case ('y')
          bsiz(2) = 0
          if (bsiz(1) == 0) bsiz(1) = gsiz(1)
          if (bsiz(3) == 0) bsiz(3) = gsiz(3)
          call calcbsiz(npes,gsiz,bsiz,option,ierr)

      case ('z')
          bsiz(3) = 0
          if (bsiz(1) == 0) bsiz(1) = gsiz(1)
          if (bsiz(2) == 0) bsiz(2) = gsiz(2)
          call calcbsiz(npes,gsiz,bsiz,option,ierr)

      case ('xy')
          bsiz(1) = 0
          bsiz(2) = 0
          if (bsiz(3) == 0) bsiz(3) = gsiz(3)
          call calcbsiz(npes,gsiz,bsiz,option,ierr)

      case ('xye')
          bsiz(1) = 0
          bsiz(2) = 0
          if (bsiz(3) == 0) bsiz(3) = gsiz(3)
          option = 'ediv'
          call calcbsiz(npes,gsiz,bsiz,option,ierr)

      case ('yz')
          bsiz(2) = 0
          bsiz(3) = 0
          if (bsiz(1) == 0) bsiz(1) = gsiz(1)
          call calcbsiz(npes,gsiz,bsiz,option,ierr)

      case ('yze')
          bsiz(2) = 0
          bsiz(3) = 0
          if (bsiz(1) == 0) bsiz(1) = gsiz(1)
          option = 'ediv'
          call calcbsiz(npes,gsiz,bsiz,option,ierr)

      case ('xz')
          bsiz(1) = 0
          bsiz(3) = 0
          if (bsiz(2) == 0) bsiz(2) = gsiz(2)
          call calcbsiz(npes,gsiz,bsiz,option,ierr)

      case ('xze')
          bsiz(1) = 0
          bsiz(3) = 0
          if (bsiz(2) == 0) bsiz(2) = gsiz(2)
          option = 'ediv'
          call calcbsiz(npes,gsiz,bsiz,option,ierr)

      case ('xyz')
          bsiz(1) = 0
          bsiz(2) = 0
          bsiz(3) = 0
          call calcbsiz(npes,gsiz,bsiz,option,ierr)

      case ('xyze')
          bsiz(1) = 0
          bsiz(2) = 0
          bsiz(3) = 0
          option = 'ediv'
          call calcbsiz(npes,gsiz,bsiz,option,ierr)

      case ('setblk')
          if (bsiz(1) == 0 .or. bsiz(2) == 0 .or. bsiz(3) == 0) then
             write(6,*) trim(subname),' ERROR: must specify bx, by, and bz with type setblk'
             call piodie(__FILE__,__LINE__)
          endif

      case default
         write(6,*) trim(subname),' ERROR: type ',trim(type),' not supported'
         call piodie(__FILE__,__LINE__)

   end select

   end subroutine calcdecomp
!==================================================================

   subroutine calcbsiz(npes,gsiz,bsiz,option,ierr)

   implicit none

   integer(i4), intent(in)    :: npes
   integer(i4), intent(in)    :: gsiz(:)
   integer(i4), intent(inout) :: bsiz(:)
   character(len=*),intent(in) ,optional :: option
   integer(i4),         intent(out),optional :: ierr

   integer(i4) :: gs,bs
   integer(i4),allocatable :: nsiz(:),isiz(:)
   integer(i4) :: npes2
   integer(i4) :: bs1,bs2,bs3
   real(r8)    :: rbs1,rbs2,rbs3
   integer(i4) :: n,m,nx,ny,nz,n1,n2,n3
   real(r8)    :: ratio,ratio2
   integer(i4) :: nbsiz
   real(r8),parameter :: dbsizm = 0.7      ! 0.0 turns this off
   real(r8),parameter :: dbsizp = 1.3   ! big number turns this off (npes)
   logical :: found
   logical :: ediv
   character(len=*),parameter :: subname = 'calcbsiz'

   ediv = .false.

   if (present(option)) then
      if (trim(option) == 'ediv') then
         ediv = .true.
      elseif (trim(option) == '') then
         ! no op
      else
         write(6,*) trim(subname),' ERROR: option not valid ',trim(option)
         call piodie(__FILE__,__LINE__)
      endif
   endif

   found = .false.
   gs = size(gsiz)
   bs = size(bsiz)
   if (gs /= 3) then
      write(6,*) trim(subname),' ERROR: gs size must be 3 ',gs
      call piodie(__FILE__,__LINE__)
   endif
   if (gs /= bs) then
      write(6,*) trim(subname),' ERROR: bs ne gs ',bs,gs
      call piodie(__FILE__,__LINE__)
   endif
   allocate(nsiz(gs),isiz(gs))

   npes2 = npes
   do n = 1,3
      if (bsiz(n) /= 0) then
         call pad_div(m,gsiz(n),bsiz(n))
         if (mod(npes2,m) == 0) then
            nsiz(n) = m
            npes2 = npes2/m
            bs = bs - 1
         else
            write(6,*) trim(subname),' ERROR: bsiz not allowed ',n,gsiz(n),bsiz(n),m,npes,npes2 
            call piodie(__FILE__,__LINE__)
         endif
      endif
   enddo

   bs = 0
   isiz = 0
   do n = 1,3
      if (bsiz(n) == 0) then
         bs = bs + 1
         isiz(bs) = n
      endif
   enddo
   n1 = isiz(1)
   n2 = isiz(2)
   n3 = isiz(3)

   if (bs == 1) then
      nsiz(n1) = npes2
      if (check_ediv(ediv,gsiz(n1),nsiz(n1))) then
         call pad_div(bsiz(n1),gsiz(n1),nsiz(n1))
         found = .true.
      endif
   endif

   if (bs == 2) then
      ratio = 10.*gsiz(1)*gsiz(2)
      nbsiz = 10.*gsiz(1)*gsiz(2)
      do nx = 1,npes2
         if (mod(npes2,nx) == 0) then
            ny = npes2/nx
            if (check_ediv(ediv,gsiz(n1),nx) .and. check_ediv(ediv,gsiz(n2),ny)) then
               call pad_div(bs1,gsiz(n1),nx)
               call pad_div(bs2,gsiz(n2),ny)
               rbs1 = bs1
               rbs2 = bs2
!               if (max(rbs1/rbs2,rbs2/rbs1) < ratio) then
               if ((bs1*bs2 < (dbsizm)*nbsiz) .or. &
                   (bs1*bs2 < (dbsizp)*nbsiz .and. max(rbs1/rbs2,rbs2/rbs1) < ratio)) then
                  ratio = max(rbs1/rbs2,rbs2/rbs1)
                  nbsiz = bs1*bs2
                  bsiz(n1) = bs1
                  bsiz(n2) = bs2
                  nsiz(n1) = nx
                  nsiz(n2) = ny
                  found = .true.
               endif
            endif
         endif
      enddo
   endif

   if (bs == 3) then
      ratio = 10.*gsiz(1)*gsiz(2)*gsiz(3)
      nbsiz = 10.*gsiz(1)*gsiz(2)*gsiz(3)
      do nx = 1,npes2
         if (mod(npes2,nx) == 0) then
            do ny = 1,npes2/nx
               if (mod(npes2/nx,ny) == 0) then
                  nz = npes2/(nx*ny)
                  if (check_ediv(ediv,gsiz(n1),nx) .and. check_ediv(ediv,gsiz(n2),ny) .and. check_ediv(ediv,gsiz(n3),nz)) then
                     call pad_div(bs1,gsiz(n1),nx)
                     call pad_div(bs2,gsiz(n2),ny)
                     call pad_div(bs3,gsiz(n3),nz)
                     rbs1 = bs1
                     rbs2 = bs2
                     rbs3 = bs3
                     ratio2 = max(rbs1/rbs2,rbs2/rbs1)
                     ratio2 = max(ratio2,rbs1/rbs3)
                     ratio2 = max(ratio2,rbs3/rbs1)
                     ratio2 = max(ratio2,rbs2/rbs3)
                     ratio2 = max(ratio2,rbs3/rbs2)
!                     if (ratio2 < ratio) then
                     if ((bs1*bs2*bs3 < (dbsizm)*nbsiz) .or. &
                         (bs1*bs2*bs3 < (dbsizp)*nbsiz .and. ratio2 < ratio)) then
                        ratio = ratio2
                        nbsiz = bs1*bs2*bs3
                        bsiz(n1) = bs1
                        bsiz(n2) = bs2
                        bsiz(n3) = bs3
                        nsiz(n1) = nx
                        nsiz(n2) = ny
                        nsiz(n3) = nz
                        found = .true.
                     endif
                  endif
               endif
            enddo
         endif
      enddo
   endif

   if (found) then
!      write(6,*) trim(subname),' found; gsiz=',gsiz,'npes=',npes,'nsiz=',nsiz,'bsiz=',bsiz
   else
      write(6,*) trim(subname),' ERROR: no decomp found gsiz=',gsiz,' npes=',npes
      call piodie(__FILE__,__LINE__)
   endif

   deallocate(nsiz,isiz)

   end subroutine calcbsiz

!==================================================================

   subroutine pad_div(mout,num,den)

   implicit none
   integer(i4), intent(out) :: mout
   integer(i4), intent(in)  :: num
   integer(i4), intent(in)  :: den
   character(len=*),parameter :: subname = 'pad_div'

   if (den == 0) then
      write(6,*) trim(subname),' ERROR: den = 0'
      call piodie(__FILE__,__LINE__)
   endif
   mout = num/den
   if (mod(num,den) > 0) then
      mout = mout + 1
   endif

   end subroutine pad_div

!==================================================================

   logical function check_ediv(ediv,num,den)

   implicit none

   logical, intent(in)  :: ediv
   integer(i4), intent(in)  :: num
   integer(i4), intent(in)  :: den
   character(len=*),parameter :: subname = 'check_ediv'

   if (ediv .and. (den == 0 .or. mod(num,den) > 0)) then
      check_ediv = .false.
   else
      check_ediv = .true.
   endif

   end function check_ediv

!==================================================================
#if defined(STANDALONE_TEST)
   subroutine piodie(file,line,msg)
   implicit none
   character(len=*), intent(in) :: file
   integer,intent(in) :: line
   character(len=*),optional,intent(in) :: msg
   character(len=*),parameter :: subname = 'abort'

   if (present(msg)) then
      write(6,*) 'piodie in file=',trim(file),' line=',line, &
                ' msg=',trim(msg)
   else
      write(6,*) 'piodie in file=',trim(file),' line=',line
   endif
   stop
   end subroutine piodie
#endif
!==================================================================
!==================================================================

  subroutine mpas_decomp_generator(dim1,dim2,dim3,my_task,fname,dof)
    integer :: dim1, dim2, dim3
    integer, intent(in)          :: my_task         ! my MPI rank
    character(len=*),intent(in)  :: fname           ! name of MPAS partition file 
    integer(kind=pio_offset_kind), pointer             :: dof(:)

!  Local variables

    integer :: idx
    integer :: gnz             ! number of vertical levels
    integer :: nCellsGlobal    ! total number of cells in the horizontal
    integer :: nCellsSolve

    integer, pointer :: globalIDList(:)
    integer :: i1,i2

!    print *,'IAM: ',my_task,' Inside mpas_decomp_generator'
    ! ----------------------------
    ! MPAS convension
    ! ----------------------------
    !   1st dimension:	vertical
    !   2nd dimension:  horizontal

    gnz = dim1     
    nCellsGlobal = dim2*dim3
    call get_global_id_list(my_task,fname,nCellsSolve,nCellsGlobal,globalIDList)

    allocate(dof(gnz*nCellsSolve))
    idx = 1
    do i2=1,nCellsSolve
    do i1=1,gnz
       dof(idx) = i1 + (globalIDList(i2)-1)*gnz
       idx = idx + 1
    enddo
    enddo

  end subroutine mpas_decomp_generator

  subroutine get_global_id_list(mype, fname, nCellsSolve, nCellsGlobal, globalIDList)

   implicit none

   include 'mpif.h' ! _EXTERNAL

   integer, intent(in) :: mype, nCellsGlobal
   character(len=*), intent(in) :: fname
   integer, intent(out) :: nCellsSolve
   integer, dimension(:), pointer :: globalIDList

   integer :: i, nlist, ierr
   integer, dimension(nCellsGlobal) :: owner_list

   !
   ! Each line in the part.128 file corresponds to a global column, and the value in the line
   !   identifies the partition that owns the corresponding column
   !
   if (mype == 0) then
      open(21,file=TRIM(fname),form='formatted',status='old')
      do i=1,nCellsGlobal
         read(21,*) owner_list(i)
      end do
      close(21)
   end if
   call MPI_Bcast(owner_list, nCellsGlobal, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)

   nlist = 0
   do i=1,nCellsGlobal
      if (owner_list(i) == mype) nlist = nlist + 1
   end do
   allocate(globalIDList(nlist))

   nCellsSolve = nlist

   nlist = 1
   do i=1,nCellsGlobal
      if (owner_list(i) == mype) then
         globalIDList(nlist) = i
         nlist = nlist + 1
     end if
   end do

   end subroutine get_global_id_list




  subroutine camlike_decomp_generator(gnx, gny, gnz, myid, ntasks, npr_yz, dof)
    integer, intent(in) :: gnx, gny, gnz, myid, ntasks, npr_yz(4)
    integer(kind=pio_offset_kind), pointer :: dof(:), tdof(:), tchk(:) 
    real, pointer :: rdof(:)
    integer(kind=pio_offset_kind) :: dofsize,tdofsize

    integer :: twodsize, i, j, spnt



    if(gny > 1 .and. npr_yz(1)*npr_yz(2)/=ntasks) then
       call piodie(__FILE__,__LINE__,&
            'npr_yz(1)*npr_yz(2) must equal ntasks')
    end if





    twodsize=gnx*gny
    dofsize = twodsize/npr_yz(1)
    !  print *,myid, dofsize



    spnt=dofsize*myid+1

    if( mod(twodsize,npr_yz(1))>=(npr_yz(1)-myid)) then
       dofsize=dofsize+1
       spnt=spnt+mod(twodsize,npr_yz(1))-(npr_yz(1)-myid)
    end if

    !  call mpi_allreduce(dofsize, tdofsize, 1, mpi_integer, mpi_sum, mpi_comm_world, ierr)
    !  print *, myid, dofsize, spnt, tdofsize, twodsize, mod(twodsize,npr_yz(1)), npr_yz(1)-myid







    allocate(dof(dofsize*gnz))

    allocate(rdof(twodsize), tdof(twodsize))

    call random_number(rdof)

    tdof = int(twodsize*rdof)+1

    deallocate(rdof)
    allocate(tchk(twodsize))
    tchk=0

    do i=1,twodsize
       if((tchk(tdof(i)))==0) then
          tchk(tdof(i))=1
       else
          do j=tdof(i),twodsize
             if(tchk(j)==0) then
                tdof(i)=j
                tchk(j)=1
                exit
             end if
          end do
          if(tdof(i)/=j) then
             do j=1,tdof(i)-1
                if(tchk(j)==0) then
                   tdof(i)=j
                   tchk(j)=1
                   exit
                end if
             end do
          end if
       end if
    end do
    deallocate(tchk)
    !  print *, tdof, sum(tchk)


    do j=1,gnz
       do i=1,dofsize
          dof(i+(j-1)*dofsize) = tdof(spnt+i-1)+(j-1)*twodsize
       end do
    end do

    CALL qsRecursive(1_PIO_OFFSET_KIND, dofsize, dof) !kicks off the recursive 

    deallocate(tdof)


  end subroutine camlike_decomp_generator





  RECURSIVE SUBROUTINE qsRecursive (lo, hi, list)
    !This is the actualy recursive portion of the quicksort
    INTEGER(KIND=PIO_OFFSET_KIND) :: pivotPoint
    INTEGER(KIND=PIO_OFFSET_KIND), INTENT(IN) :: lo
    INTEGER(KIND=PIO_OFFSET_KIND), INTENT(IN) :: hi
    integer(kind=pio_offset_kind), INTENT(INOUT), DIMENSION(*) :: list
    pivotPoint = qsPartition(lo, hi, list); !basically all we do is find the pivot point, adjust elements, then call it again
    IF (lo < pivotPoint) CALL qsRecursive(lo, pivotPoint -1, list)
    IF (pivotPoint < hi) CALL qsRecursive(pivotPoint + 1, hi, list)

  END SUBROUTINE qsRecursive



  integer(kind=pio_offset_kind) FUNCTION qsPartition (loin, hiin, list)
    !The partition portios of the Quick Sort is the must involved part
    integer(kind=pio_offset_kind), INTENT(INOUT), DIMENSION(*) :: list
    INTEGER(KIND=PIO_OFFSET_KIND), INTENT(IN) :: loin
    INTEGER(KIND=PIO_OFFSET_KIND):: lo !variable so we can manipulate the hi and lo values without changing things elsewhere in the program by reference
    INTEGER(KIND=PIO_OFFSET_KIND), INTENT(IN) :: hiin
    INTEGER(KIND=PIO_OFFSET_KIND):: hi !variable so we can manipulate the hi and lo values without changing things elsewhere in the program by reference
    integer(kind=pio_offset_kind)::pivot !the temp location for the pivitoal element to which everything will be compaired
    hi = hiin
    lo = loin
    pivot = list(lo)
    DO
       IF (lo >= hi) EXIT !exit the loop when done
       DO !move in from the right
          IF ((pivot > list(hi)) .OR. (lo >= hi)) EXIT
          hi = hi - 1
       END DO
       IF (hi /= lo) then !move the entry indexed by hi to left side of partition
          list(lo) = list(hi) 
          lo = lo + 1
       END IF
       DO !move in from the left
          IF ((list(lo) > pivot) .OR. (lo >= hi)) EXIT
          lo = lo + 1
       END DO
       IF (hi /= lo) then !move the entry indexed by hi to left side of partition
          list(hi) = list(lo) 
          hi = hi - 1
       END IF
    END DO
    list(hi) = pivot !put the pivot element back when we're done
    qsPartition = hi !return the correct position of the pivot element
  END FUNCTION qsPartition



!==================================================================

end module gdecomp_mod
