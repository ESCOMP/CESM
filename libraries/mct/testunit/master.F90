program main

implicit none

#include "mpif.h"

integer ierr,myProc
character(len=12) date1

integer ui

call MPI_INIT(ierr)
call MPI_COMM_RANK(MPI_COMM_WORLD,myProc,ierr)

call DATE_AND_TIME(date=date1)
ui = 7

if(myProc .eq. 0) call openIO(date1,ui,'AttrVect')
call testAttrVect(myProc,ui)
ui = ui+1

call MPI_FINALIZE(ierr)


end program

subroutine outputTestStatus(ui, routine, testid, status)

integer ui, testid

character(*) routine, status

character(len=96) output

integer ok

if (status == "PASS") then
ok=1
else if (status == "FAIL") then
ok = 1
else
write(0,*) "WHAT HAPPENED? ", routine, testid
endif

write(ui,'(a,a,i1,a,a)')routine," <test ",testid,"> ... ",status

end subroutine


subroutine outputRoutineStatus(ui, routine, status)

integer ui

character(*) routine, status

character(len=96) output

integer ok

if (status == "PASS") then
ok=1
else if (status == "FAIL") then
ok = 1
else
write(0,*) "WHAT HAPPENED? ", routine
endif

write(ui,'(a,a,a)')routine," SUMMARY ... ",status

end subroutine


!####################################
!
! open io unit for log file
!
!####################################

subroutine openIO(stamp,ui,routine)

  character(*) stamp, routine
  integer ui

  character(len=54) filename
  integer ierr

  ierr = 0

  filename = trim(routine)//'.log.' // stamp(1:8)
  OPEN (UNIT=ui, FILE=filename,STATUS='NEW',IOSTAT=ierr)

  if (ierr /= 0) then
     write(6,*) "Open failed on unit: ", ui
     write(6,*) "File name was: [", filename, "]"
     write(6,*) "Error code was: ", ierr

     stop 1
  end if

end subroutine

