module check_mod
  
  use kinds_mod
  use pio_types, only : PIO_NOERR  ! _EXTERNAL
  use alloc_mod  ! _EXTERNAL
  use pio_support, only : CheckMPIReturn  ! _EXTERNAL
#ifndef NO_MPIMOD
  use mpi !_EXTERNAL
#endif
  implicit none
  private 
#ifdef NO_MPIMOD
  include 'mpif.h'    ! _EXTERNAL
#endif
  public :: checkpattern 

  interface checkpattern
      module procedure check_1D_r8, &
		       check_1D_r4, &
		       check_1D_i4
      module procedure check_3D_r8, &
		       check_3D_r4, &
		       check_3D_i4
  end interface

contains 

subroutine check_1D_r8(my_comm, fname,wr_array,rd_array,len,iostat)
    integer, intent(in) :: my_comm
    character(len=*) :: fname
    real(r8) :: wr_array(:)
    real(r8) :: rd_array(:)
    integer(i4), intent(in) :: len
    integer(i4),optional :: iostat

    real(r8),pointer :: diff(:)
    real(r8) :: lsum,gsum, maxbad
    integer(i4) :: ierr,cbad,rank, maxbadloc(1)

    if(present(iostat)) iostat = PIO_noerr
   
    call alloc_check(diff,len,' check_1D_r8:diff ')

    if(len>0) then
       diff = abs(wr_array - rd_array)
       cbad = COUNT(diff > 1.0d-299)
       maxbad = maxval(diff)
       maxbadloc = maxloc(diff)
       lsum = SUM(diff)
    else
       lsum = 0
    end if
    call MPI_Allreduce(lsum,gsum,1,MPI_REAL8,MPI_SUM,MY_COMM,ierr)
    call CheckMPIReturn('Call to MPI_Allreduce()',ierr,__FILE__,__LINE__)

    if(lsum > 1.0d-80) then ! There is a discrepency between read + write data
       call MPI_COMM_rank(MY_COMM,rank,ierr)
       call CheckMPIReturn('Call to MPI_COMM_RANK()',ierr,__FILE__,__LINE__)
       print *,'IAM: ', rank, 'File: ',TRIM(fname),&
            ' Error detected for correctness test(1D,R8): ',lsum,' # bad: ',cbad, &
            ' gsum:', gsum, 'max ',maxbad,' loc ',maxbadloc, &
            wr_array(maxbadloc), rd_array(maxbadloc)
       if(present(iostat)) iostat = -20
    endif
    call dealloc_check(diff)	
end subroutine check_1D_r8

subroutine check_3D_r8(my_comm, fname,wr_array,rd_array)
    integer, intent(in) :: my_comm

    character(len=*) :: fname
    real(r8) :: wr_array(:,:,:)
    real(r8) :: rd_array(:,:,:)

    real(r8), pointer :: diff(:,:,:)
    real(r8) :: lsum,gsum
    integer(i4) :: ierr,cbad,rank
    integer(i4) :: len1,len2,len3
   
    len1 = SIZE(wr_array,dim=1)
    len2 = SIZE(wr_array,dim=2)
    len3 = SIZE(wr_array,dim=3)
   
    allocate(diff(len1,len2,len3))
  
    diff = wr_array - rd_array
    cbad = COUNT(diff .ne. 0.0)
    lsum = SUM(diff)
   
    call MPI_Allreduce(lsum,gsum,1,MPI_REAL8,MPI_SUM,MY_COMM,ierr)
    call CheckMPIReturn('Call to MPI_Allreduce()',ierr,__FILE__,__LINE__)

    if(abs(gsum) > 1.0d-80) then
       call MPI_COMM_rank(MY_COMM,rank,ierr)
       call CheckMPIReturn('Call to MPI_COMM_RANK()',ierr,__FILE__,__LINE__)
       if(lsum .ne. 0.0) print *,'IAM: ', rank, 'File: ',TRIM(fname),&
            ' Error detected for correctness test(3D,R8): ',lsum,' # bad: ',cbad
    endif
    deallocate(diff)	

end subroutine check_3D_r8

subroutine check_3D_r4(my_comm, fname,wr_array,rd_array)
    integer, intent(in) :: my_comm

    character(len=*) :: fname
    real(r4) :: wr_array(:,:,:)
    real(r4) :: rd_array(:,:,:)

    real(r4), pointer :: diff(:,:,:)
    real(r4) :: lsum,gsum
    integer(i4) :: ierr,cbad,rank
    integer(i4) :: len1,len2,len3
   
    len1 = SIZE(wr_array,dim=1)
    len2 = SIZE(wr_array,dim=2)
    len3 = SIZE(wr_array,dim=3)
   
    allocate(diff(len1,len2,len3))
  
    diff = wr_array - rd_array
    cbad = COUNT(diff .ne. 0.0)
    lsum = SUM(diff)
   
    call MPI_Allreduce(lsum,gsum,1,MPI_REAL,MPI_SUM,MY_COMM,ierr)
    call CheckMPIReturn('Call to MPI_Allreduce()',ierr,__FILE__,__LINE__)

    if(abs(gsum) .gt. tiny(gsum)) then
       call MPI_COMM_rank(MY_COMM,rank,ierr)
       call CheckMPIReturn('Call to MPI_COMM_RANK()',ierr,__FILE__,__LINE__)
       if(lsum .ne. 0) print *,'IAM: ', rank, 'File: ',TRIM(fname),&
            ' Error detected for correctness test(3D,R4): ',lsum,' # bad: ',cbad
    endif
    deallocate(diff)	

end subroutine check_3D_r4

subroutine check_3D_i4(my_comm, fname,wr_array,rd_array)
    integer, intent(in) :: my_comm

    character(len=*) :: fname
    integer(i4) :: wr_array(:,:,:)
    integer(i4) :: rd_array(:,:,:)

    integer(i4), pointer :: diff(:,:,:)
    integer(i4) :: lsum,gsum
    integer(i4) :: ierr,cbad,rank
    integer(i4) :: len1,len2,len3
   
    len1 = SIZE(wr_array,dim=1)
    len2 = SIZE(wr_array,dim=2)
    len3 = SIZE(wr_array,dim=3)
   
    allocate(diff(len1,len2,len3))
  
    diff = wr_array - rd_array
    cbad = COUNT(diff .ne. 0.0)
    lsum = SUM(diff)
   
    call MPI_Allreduce(lsum,gsum,1,MPI_INTEGER,MPI_SUM,MY_COMM,ierr)
    call CheckMPIReturn('Call to MPI_Allreduce()',ierr,__FILE__,__LINE__)
    if(gsum .ne. 0.0) then
       call MPI_COMM_rank(MY_COMM,rank,ierr)
       call CheckMPIReturn('Call to MPI_COMM_RANK()',ierr,__FILE__,__LINE__)
       if(lsum .ne. 0) print *,'IAM: ', rank, 'File: ',TRIM(fname),&
            ' Error detected for correctness test(3D,I4): ',lsum,' # bad: ',cbad
    endif
    deallocate(diff)	

end subroutine check_3D_i4

subroutine check_1D_r4(my_comm,fname,wr_array,rd_array,len,iostat)
    integer, intent(in) :: my_comm
 
    character(len=*) :: fname
    real(r4) :: wr_array(:)
    real(r4) :: rd_array(:)
    integer(i4),optional :: iostat

    real(r4),pointer :: diff(:)
    real(r4) :: lsum,gsum
    integer(i4) :: ierr,len,cbad,rank

    

! Set default (no error) value for iostat if present)
    if(present(iostat)) iostat = PIO_noerr
   
    call alloc_check(diff,len,' check_1D_r4:diff ')

    if(len>0) then
       diff = wr_array - rd_array
       cbad = COUNT(diff .ne. 0.0)
       lsum = SUM(diff)
    else
       lsum = 0
    end if
    
    call MPI_Allreduce(lsum,gsum,1,MPI_REAL,MPI_SUM,MY_COMM,ierr)
    call CheckMPIReturn('Call to MPI_Allreduce()',ierr,__FILE__,__LINE__)
    if(abs(gsum) > tiny(gsum)) then
       call MPI_COMM_rank(MY_COMM,rank,ierr)
       call CheckMPIReturn('Call to MPI_COMM_RANK()',ierr,__FILE__,__LINE__)
       if(lsum .ne. 0.0) print *,'IAM: ', rank, 'File: ',TRIM(fname),&
            ' Error detected for correctness test(1D,R4): ',lsum,' # bad: ',cbad
       if(present(iostat)) iostat = -20
    endif
    deallocate(diff)	

end subroutine check_1D_r4

subroutine check_1D_i4(my_comm, fname,wr_array,rd_array,len,iostat)
    integer, intent(in) :: my_comm
    character(len=*) :: fname
    integer(i4) :: wr_array(:)
    integer(i4) :: rd_array(:)
    integer(i4), intent(in) :: len
    integer(i4),optional :: iostat

    integer(i4),pointer :: diff(:)
    integer(i4) :: lsum,gsum
    integer(i4) :: ierr,cbad,rank, lloc(1)

    

! Set default (no error) value for iostat if present)
    if(present(iostat)) iostat = PIO_noerr
   
    call alloc_check(diff,len,' check_1D_r4:diff ')
    if(len>0) then
       diff = wr_array - rd_array
       cbad = COUNT(diff .ne. 0.0)
       lsum = SUM(diff)
       lloc = maxloc(wr_array-rd_array)
    else
       lsum = 0
    end if
    call MPI_Allreduce(lsum,gsum,1,MPI_INTEGER,MPI_SUM,MY_COMM,ierr)
    call CheckMPIReturn('Call to MPI_Allreduce()',ierr,__FILE__,__LINE__)
    if(gsum .ne. 0.0) then
       call MPI_COMM_rank(MY_COMM,rank,ierr)
       call CheckMPIReturn('Call to MPI_COMM_RANK()',ierr,__FILE__,__LINE__)
       if(lsum .ne. 0) print *,'IAM: ', rank, 'File: ',TRIM(fname),&
            ' Error detected for correctness test(1D,I4): ',lsum,' # bad: ',cbad, &
            lloc, wr_array(lloc(1)), rd_array(lloc(1))
       if(present(iostat)) iostat = -20
    endif
    deallocate(diff)	

end subroutine check_1D_i4

end module check_mod
