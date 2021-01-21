!
! !INTERFACE:

 module m_GMAPTEST
!
! !USES:
!
      implicit none

      private	! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: testall

    interface testall
       module procedure testGMap_
    end interface


! !REVISION HISTORY:
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='m_GMAPTEST'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: testGMap_ - Test the functions in the AttrVect module
!
! !DESCRIPTION:
! This routine writes diagnostic information about the input
! {\tt AttrVect}. Each line of the output will be preceded by the
! character argument {\tt identifier}. The output device is specified
! by the integer argument {\tt device}.
!
! !INTERFACE:

 subroutine testGMap_(GMap, identifier, mycomm, device)

!
! !USES:
!
      use m_GlobalMap         ! Use all of MCTWorld
      use m_GlobalToLocal,only : GlobalToLocalIndex
      use m_stdio
      use m_die
      use m_mpif90

      implicit none

! !INPUT PARAMETERS:

      type(GlobalMap),            intent(in)  :: GMap
      character(len=*),           intent(in)  :: identifier
      integer, optional,          intent(in)  :: mycomm
      integer,                    intent(in)  :: device

! !REVISION HISTORY:
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::testGMap_'
  integer :: i,j,k,lower,upper
  integer :: mySize,myProc,proc,ierr

  write(device,*) identifier, ":: TESTING GLOBALMAP ::"

  write(device,*) identifier, ":: TYPE CHECK:"
  write(device,*) identifier, ":: comp_id = ", GMap%comp_id
  write(device,*) identifier, ":: gsize = ", GMap%gsize
  write(device,*) identifier, ":: lsize = ", GMap%lsize

  mySize = size(GMap%counts)

  if(mySize<=0) call die(myname_,"size(GMap%counts)<=0")

  if(size(GMap%counts) /= size(GMap%displs)) then
     call die(myname_,"size(GMap%counts) /= size(GMap%displs)")
  endif

  write(device,*) identifier, ":: counts = &
       &(associated, size, counts) ", associated(GMap%counts), &
       size(GMap%counts), GMap%counts
  write(device,*) identifier, ":: displs = &
       &(associated, size, displs) ", associated(GMap%displs), &
       size(GMap%displs), GMap%displs

  write(device,*) identifier, ":: counts = ", &
       GMap%counts

  write(device,*) identifier, ":: FUNCTION CHECK:"
  write(device,*) identifier, ":: lsize = ", lsize(GMap)
  write(device,*) identifier, ":: gsize = ", gsize(GMap)
  write(device,*) identifier, ":: comp_id = ",comp_id(GMap)

  write(device,*) identifier, ":: Testing rank"
  do i=0,mySize-1
     do j=1,GMap%counts(i)
        call rank(GMap,GMap%displs(i)+j,proc)
        if(i/=proc) then
           write(device,*) identifier, ":: subroutine rank failed! ", &
                i,j,mySize,GMap%counts(i), GMap%displs(i),proc
           call die(myname_,"subroutine rank failed!")
        endif
     enddo
  enddo

  write(device,*) identifier, ":: Testing bounds"
  do i=0,mySize-1
     call bounds(GMap,i,lower,upper)
     if(lower/=GMap%displs(i)+1) then
        write(device,*) identifier, ":: subroutine bounds failed! ", &
             i, lower, GMap%displs(i)
        call die(myname_,"subroutine bounds failed!")
     endif
     if(upper/=GMap%displs(i)+GMap%counts(i)) then
        write(device,*) identifier, ":: subroutine bounds failed! ", &
             i,upper,GMap%displs(i)+GMap%counts(i)-1
        call die(myname_,"subroutine bounds failed!")
     endif
  enddo

  if(present(mycomm)) then
     j=-12345
     k=-12345

     do i=1,GMap%gsize
        if(GlobalToLocalIndex(GMap,i,mycomm)/=-1) then
           j=GlobalToLocalIndex(GMap,i,mycomm)
           EXIT
        endif
     enddo

     do i=1,GMap%gsize
        if(GlobalToLocalIndex(GMap,i,mycomm)/=-1) then
           k=GlobalToLocalIndex(GMap,i,mycomm)
        endif
     enddo

     if( (j==-12345).and.(k==-12345) ) then
        write(device,*) identifier, ":: GlobalMapToIndex :: &
             &THIS PROCESS OWNS ZERO POINTS"
     else
        write(device,*) identifier, ":: GlobalMapToIndex :: &
             &first, last indices = ", j, k
     endif

  else

     write(device,*) identifier, ":: NOT TESTING GLOBALMAPTOLOCALINDEX. &
          &PLEASE CONSULT SOURCE CODE TO ENABLE TESTING"

  endif

end subroutine testGMap_

end module m_GMAPTEST
