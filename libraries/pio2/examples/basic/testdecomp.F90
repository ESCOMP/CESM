   program testdecomp

! xlf90 -g -I/usr/local/include -c kinds_mod.F90
! xlf90 -g -DSTANDALONE_TEST -I/usr/local/include -c gdecomp_mod.F90
! xlf90 -g -DSTANDALONE_TEST -I/usr/local/include -L/usr/local/lib -lnetcdf gdecomp_mod.F90 testdecomp.F90

   use gdecomp_mod

   implicit none
   
   integer, pointer  :: compDOF(:), ioDOF(:)
   integer :: startcomp(3),cntcomp(3)
   integer :: startio(3),cntio(3),gdims(3)
   integer :: my_task,num_tasks
   logical :: test
   character(len=*),parameter :: fin = 'testdecomp_in'
   character(len=*),parameter :: progname = 'testdecomp'
   type(gdecomp_type) :: gdecomp

   test = .true.

   my_task = 0
   num_tasks = 192
   gdims(1) = 3600
   gdims(2) = 2400
   gdims(3) = 40 

!   call gdecomp_read_nml(gdecomp,fin,'comp',my_task)
!   print  *,'after gdecomp_read_nml'
!   call gdecomp_DOF(gdecomp,my_task,compDOF,startcomp,cntcomp,test=test,write_decomp=.false.)

   call gdecomp_read_nml(gdecomp,fin,'io',my_task)
   call gdecomp_DOF(gdecomp,my_task,ioDOF,startio,cntio,test=test,write_decomp=.true.)

   call gdecomp_read_nml(gdecomp,fin,'comp',my_task,num_tasks,gdims)
   call gdecomp_DOF(gdecomp,my_task,compDOF,startcomp,cntcomp,test=test)

   call gdecomp_set(gdecomp,name='xx1',my_task=my_task, &
     nxg=360,nyg=240,nzg=10,gdz=5,npes=32,nblksppe=4, &
     grdorder='zxy',grddecomp='xy',blkorder='xyz',blkdecomp1='xyz')
   call gdecomp_DOF(gdecomp,my_task,compDOF,startcomp,cntcomp,test=test,write_decomp=.true.)

   write(6,*) ' testdecomp completed successfully '

   end program testdecomp
