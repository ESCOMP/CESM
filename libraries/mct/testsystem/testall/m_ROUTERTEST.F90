!
! !INTERFACE:

 module m_ROUTERTEST
!
! !USES:
!
      implicit none

      private	! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: testall

    interface testall
       module procedure testRouter_
    end interface


! !REVISION HISTORY:
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='m_ROUTERTEST'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: aVtest_ - Test the functions in the AttrVect module
!
! !DESCRIPTION:
! This routine writes diagnostic information about the input
! {\tt AttrVect}. Each line of the output will be preceded by the
! character argument {\tt identifier}. The output device is specified
! by the integer argument {\tt device}.
!
! !INTERFACE:

 subroutine testRouter_(Rout, identifier, device)

!
! !USES:
!
      use m_Router         ! Use all GlobalSegMap routines
      use m_stdio
      use m_die
      use m_mpif90

      implicit none

! !INPUT PARAMETERS:

      type(Router),               intent(in)  :: Rout
      character(len=*),           intent(in)  :: identifier
      integer,                    intent(in)  :: device

! !REVISION HISTORY:
! 23Sep02 - E.T. Ong <eong@mcs.anl.gov> - initial prototype.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::testRouter_'
  integer :: proc, nseg

  write(device,*) identifier, ":: TYPE CHECK:"
  write(device,*) identifier, ":: COMP1ID = ", Rout%comp1id
  write(device,*) identifier, ":: COMP2ID = ", Rout%comp2id
  write(device,*) identifier, ":: NPROCS = ", Rout%nprocs
  write(device,*) identifier, ":: MAXSIZE = ", Rout%maxsize

  if(associated(Rout%pe_list)) then
     write(device,*) identifier, ":: PE_LIST = ", Rout%pe_list
  else
     call die(myname_,"PE_LIST IS NOT ASSOCIATED!")
  endif

  if(associated(Rout%num_segs)) then
     write(device,*) identifier, ":: NUM_SEGS = ", Rout%num_segs
  else
     call die(myname_,"NUM_SEGS IS NOT ASSOCIATED!")
  endif

  if(associated(Rout%locsize)) then
     write(device,*) identifier, ":: LOCSIZE = ", Rout%locsize
  else
     call die(myname_,"LOCSIZE IS NOT ASSOCIATED!")
  endif

  if(associated(Rout%seg_starts)) then
     write(device,*) identifier, ":: SIZE OF SEG_STARTS &
          &(FIRST, SECOND DIM) = ", &
          size(Rout%seg_starts,1), size(Rout%seg_lengths,2)
  else
     call die(myname_,"SEG_STARTS IS NOT ASSOCIATED!")
  endif

  if(associated(Rout%seg_lengths)) then
     write(device,*) identifier, ":: SIZE OF SEG_LENGTHS = &
          &(FIRST, SECOND DIM) = ", &
          size(Rout%seg_lengths,1), size(Rout%seg_lengths,2)
  else
     call die(myname_,"SEG_LENGTHS IS NOT ASSOCIATED!")
  endif

  write(device,*) identifier, ":: SEG_STARTS AND SEG_LENGTHS &
       &VALUES: (PE, START, LENGTH) = "

  do proc = 1, Rout%nprocs
     do nseg = 1, Rout%num_segs(proc)
        write(device,*) identifier, Rout%pe_list(proc), &
             Rout%seg_starts(proc,nseg), &
             Rout%seg_lengths(proc,nseg)
     enddo
  enddo

 end subroutine testRouter_

end module m_ROUTERTEST
