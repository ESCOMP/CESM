!
! !INTERFACE:

 module m_GSMapTest
!
! !USES:
!
      implicit none

      private	! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: testall
      public :: Identical

    interface testall
       module procedure testGSMap_
    end interface

    interface Identical
       module procedure Identical_
    end interface


! !REVISION HISTORY:
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='m_GSMapTest'

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

 subroutine testGSMap_(GSMap, identifier, mycomm, device)

!
! !USES:
!
      use m_GlobalSegMap         ! Use all GlobalSegMap routines
      use m_GlobalToLocal        ! Use all GlobalToLocal routines
      use m_stdio
      use m_die
      use m_mpif90

      implicit none

! !INPUT PARAMETERS:

      type(GlobalSegMap),         intent(in)  :: GSMap
      character(len=*),           intent(in)  :: identifier
      integer,                    intent(in)  :: device
      integer,                    intent(in)  :: mycomm

! !REVISION HISTORY:
! 23Sep02 - E.T. Ong <eong@mcs.anl.gov> - initial prototype.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::testGSMap_'
  integer :: myProc, mySize, ierr
  integer :: i, j, k, m, n, o
  integer :: first,last, owner, numlocs, nactive, npoints, proc
  integer, dimension(:), pointer :: points, owners, pelist, perm, &
       mystart, mylength
  integer, dimension(:), allocatable :: locs, slpArray
  logical :: found

  type(GlobalSegMap) :: PGSMap, P1GSMap

!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!
!:::::WRITE OUT INFO ABOUT THE GLOBALSEGMAP::::::::::::::::::::::::::::!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::!

  call MPI_COMM_RANK (mycomm, myProc, ierr)
  call MPI_COMM_SIZE(mycomm, mySize, ierr)

  write(device,*) identifier, ":: TYPE CHECK:"
  write(device,*) identifier, ":: COMP_ID = ", GSMap%comp_id
  write(device,*) identifier, ":: NGSEG = ", GSMap%ngseg
  write(device,*) identifier, ":: GSIZE = ", GSMap%gsize
  write(device,*) identifier, ":: START:: association status, &
       & size, values = ", associated(GSMap%start), size(GSMap%start)
  write(device,*) identifier, ":: START = ", GSMap%start
  write(device,*) identifier, ":: LENGTH:: association status, &
       &size, values = ", associated(GSMap%length), size(GSMap%length)
  write(device,*) identifier, ":: LENGTH = ", GSMap%length
  write(device,*) identifier, ":: PE_LOC:: association status, &
       &size, values = ", associated(GSMap%pe_loc), size(GSMap%pe_loc)
  write(device,*) identifier, ":: PE_LOC = ", GSMap%pe_loc

  write(device,*) identifier, ":: NGSEG_ = ", ngseg(GSMap)
  write(device,*) identifier, ":: NLSEG_ = ", nlseg(GSMap,myProc)
  write(device,*) identifier, ":: COMP_ID_ = ", comp_id(GSMap)
  write(device,*) identifier, ":: GSIZE_ = ", gsize(GSMap)
  write(device,*) identifier, ":: GLOBALSTORAGE = ", GlobalStorage(GSMap)
  write(device,*) identifier, ":: PROCESSSTORAGE = (PE, PE-STORAGE)"
  do i=1,mySize
     write(device,*) identifier, ":: PROCESSSTORAGE = ", &
          i-1, ProcessStorage(GSMap,i-1)
  enddo
  write(device,*) identifier, ":: LSIZE_ = ", lsize(GSMap,mycomm)
  write(device,*) identifier, ":: HALOED = ", haloed(GSMap)

  write(device,*) identifier, ":: SUBROUTINES CHECK:"
  write(device,*) identifier, ":: ORDERED POINTS = (PE, SIZE, FIRST, LAST)"

  do i=1,mySize

     first=1
     last=0

     proc = i-1

     call OrderedPoints(GSMap,proc,points)

     npoints=size(points)
     if(npoints>0) then
        first = points(1)
        last = points(npoints)
        write(device,*) identifier, ":: ORDERED POINTS = ", proc, npoints, &
             first, last
     else
        write(device,*) identifier, ":: ORDERED POINTS :: EXTREME WARNING:: &
             &Process ", proc, " contains ", npoints, "points"
        write(device,*) identifier, ":: AS A RESULT, &
             &NOT TESTING RANK AND PELOCS::"
	EXIT
!        call die(myname_,"OrderedPoints may have failed ")
     endif


     !:::CHECK THE CORRECTNESS OF ROUTINE RANK1_:::! !::NOT YET PUBLIC IN MODULE::!
     if(haloed(GSMap)) then
        do k=first,last
           call rank(GSMap,k,numlocs,owners)
           found = .false.
           do n=1,numlocs
              if(owners(n) /= proc) then
                 found = .true.
              endif
           enddo
           if(.not.found) then
              call die(myname_,"SUBROUTINE RANKM_ failed!")
           endif
        enddo
        deallocate(owners,stat=ierr)
        if(ierr/=0) call die(myname_,"deallocate(owners)",ierr)
     else
        allocate(locs(npoints),stat=ierr)
        if(ierr/=0) call die(myname_,"allocate(locs)")
	call peLocs(GSMap,npoints,points,locs)
        do n=1,npoints
           if(locs(n) /= proc) then
              call die(myname_,"SUBROUTINE PELOCS FAILED!",locs(n))
           endif
        enddo
        deallocate(locs,stat=ierr)
        if(ierr/=0) call die(myname_,"deallocate(locs)")
        do k=first,last
           call rank(GSMap,k,owner)
           if(owner /= proc) then
              write(device,*) identifier, ":: RANK1_ FAILED:: ", owner, proc, first, last, k
              call die(myname_,"SUBROUTINE RANK1_ failed!")
           endif
        enddo
     endif
     !:::::::::::::::::::::::::::::::::::::::::::::!

     deallocate(points,stat=ierr)
     if(ierr/=0) call die(myname_,"deallocate(points)",ierr)
  enddo

  call active_pes(GSMap, nactive, pelist)
  write(device,*) identifier, ":: ACTIVE PES (NUM_ACTIVE, PE_LIST) = ", &
       nactive, pelist
  deallocate(pelist,stat=ierr)
  if(ierr/=0) call die(myname_,"deallocate(pelist)",ierr)


  write(device,*) identifier, ":: TESTING INITP and INITP1"
  call init(PGSMAP, GSMap%comp_id, GSMap%ngseg, GSMap%gsize, GSMap%start, &
       GSMap%length, GSMap%pe_loc)

  k = size(GSMap%start)+size(GSMap%length)+size(GSMap%pe_loc)
  allocate(slparray(k),stat=ierr)
  if(ierr/=0) call die(myname_,"allocate(slparray)",ierr)

  slpArray(1:GSMap%ngseg) = GSMap%start(1:GSMap%ngseg)
  slpArray(GSMap%ngseg+1:2*GSMap%ngseg) = GSMap%length(1:GSMap%ngseg)
  slpArray(2*GSMap%ngseg+1:3*GSMap%ngseg) = GSMap%pe_loc(1:GSMap%ngseg)

  call init(P1GSMap, GSMap%comp_id, GSMap%ngseg, GSMap%gsize, slpArray)

  deallocate(slpArray,stat=ierr)
  if(ierr/=0) call die(myname_,"deallocate(slparray)",ierr)

  write(device,*) identifier, ":: COMPARE ALL GLOBALSEGMAPS: &
       & YOU SHOULD SEE 3 IDENTICAL COLUMNS OF NUMBERS:"
  write(device,*) identifier, ":: COMP_ID = ", &
       GSMap%comp_id, PGSMap%comp_id, P1GSMap%comp_id
  write(device,*) identifier, ":: NGSEG = ", &
       GSMap%ngseg, GSMap%ngseg, GSMap%ngseg
  write(device,*) identifier, ":: GSIZE = ", &
       GSMap%gsize, GSMap%gsize, GSMap%gsize
  write(device,*) identifier, ":: START:: association status = ", &
       associated(GSMap%start), associated(PGSMap%start), &
       associated(P1GSMap%start)
  write(device,*) identifier, ":: START:: size = ", &
       size(GSMap%start), size(PGSMap%start), size(P1GSMap%start)

  write(device,*) identifier, ":: LENGTH:: association status = ", &
       associated(GSMap%length), associated(PGSMap%length), &
       associated(P1GSMap%length)
  write(device,*) identifier, ":: LENGTH:: size = ", &
       size(GSMap%length), size(PGSMap%length), size(P1GSMap%length)


  write(device,*) identifier, ":: PE_LOC:: association status = ", &
       associated(GSMap%pe_loc), associated(PGSMap%pe_loc), &
       associated(P1GSMap%pe_loc)
  write(device,*) identifier, ":: PE_LOC:: size = ", &
       size(GSMap%pe_loc), size(PGSMap%pe_loc), size(P1GSMap%pe_loc)

  do i=1,GSMap%ngseg
     if( (GSMap%start(i) /= PGSMap%start(i)) .or. &
          (GSMap%start(i) /= P1GSMap%start(i)) ) then
        call die(myname_,"INITP or INITP1 failed -starts-!")
     endif
     if( (GSMap%length(i) /= PGSMap%length(i)) .or. &
          (GSMap%length(i) /= P1GSMap%length(i)) ) then
        call die(myname_,"INITP or INITP1 failed -lengths-!")
     endif
     if( (GSMap%pe_loc(i) /= PGSMap%pe_loc(i)) .or. &
          (GSMap%pe_loc(i) /= P1GSMap%pe_loc(i)) ) then
        call die(myname_,"INITP or INITP1 failed -pe_locs-!")
     endif
  enddo

  write(device,*) identifier, ":: TESTING SORT AND PERMUTE"

  call Sort(PGSMap,PGSMap%pe_loc,PGSMap%start,perm)
  call Permute(PGSMap, perm)

  deallocate(perm,stat=ierr)
  if(ierr/=0) call die(myname_,"deallocate(perm)")

  call SortPermute(P1GSMap,PGSMap%pe_loc,PGSMap%start)

  do i=1,GSMap%ngseg
     if( (P1GSMap%start(i) /= PGSMap%start(i)) ) then
        call die(myname_,"Sort or Permute failed -starts-!")
     endif
     if( (P1GSMap%length(i) /= PGSMap%length(i)) ) then
        call die(myname_,"Sort or Permute failed -lengths-!")
     endif
     if( (P1GSMap%pe_loc(i) /= PGSMap%pe_loc(i)) ) then
        call die(myname_,"Sort or Permute failed -pe_locs-!")
     endif
  enddo

  write(device,*) identifier, ":: TESTING GLOBALTOLOCAL FUNCTIONS ::"

  write(device,*) identifier, ":: TESTING GLOBALSEGMAPTOINDICES ::"

  call GlobalToLocalIndices(GSMap,mycomm,mystart,mylength)

  if(.NOT. (associated(mystart).and.associated(mylength)) ) then
     call die(myname_, "::GLOBALSEGMAPTOINDICES::&
          &mystart and/or mylength is not associated")
  endif

  if(size(mystart)<0) then
     call die(myname_, "::GLOBALSEGMAPTOINDICES::size(start) < 0")
  endif

  if(size(mystart) /= size(mylength)) then
     call die(myname_, "::GLOBALSEGMAPTOINDICES::size(start)/=size(length)")
  endif

  if(size(mystart) /= nlseg(GSMap,myProc)) then
      call die(myname_, "::GLOBALSEGMAPTOINDICES::size(start)/=nlseg")
  endif

  if(size(mystart)>0) then
     write(device,*) identifier, ":: GLOBALSEGMAPTOINDICES :: &
          &start = (size, values) ", &
          size(mystart), mystart
  else
     write(device,*) identifier, ":: GLOBALSEGMAPTOINDICES :: &
          &start has zero size"
  endif

  if(size(mylength)>0) then
     write(device,*) identifier, ":: GLOBALSEGMAPTOINDICES :: &
          &length = (size, values) ", &
          size(mylength), mylength
  else
     write(device,*) identifier, ":: GLOBALSEGMAPTOINDICES :: &
          &length has zero size"
  endif

  if(size(mystart)>0) then
     write(device,*) identifier, ":: GLOBALSEGMAPTOINDICES :: &
          &first, last indices = ", &
          mystart(1), mystart(size(mystart))+mylength(size(mylength))-1
  else
     write(device,*) identifier, ":: GLOBALSEGMAPTOINDICES :: NOT TESTING&
          & THIS ROUTINE BECAUSE START AND LENGTH HAVE ZERO SIZE"
  endif

  deallocate(mystart,mylength,stat=ierr)
  if(ierr/=0) call die(myname_,"deallocate(mystart,mylength)")

  write(device,*) identifier, ":: TESTING GLOBALSEGMAPTOINDEX"

  j=-12345
  k=-12345

  do i=1,GlobalStorage(GSMap)
     if(GlobalToLocalIndex(GSMap,i,mycomm)/=-1) then
        j=GlobalToLocalIndex(GSMap,i,mycomm)
        EXIT
     endif
  enddo

  do i=1,GlobalStorage(GSMap)
     if(GlobalToLocalIndex(GSMap,i,mycomm)/=-1) then
        k=GlobalToLocalIndex(GSMap,i,mycomm)
     endif
  enddo

  if( (j==-12345).and.(k==-12345) ) then
     write(device,*) identifier, ":: GlobalSegMapToIndex :: &
          &THIS PROCESS OWNS ZERO POINTS"
  else
     write(device,*) identifier, ":: GlobalSegMapToIndex :: &
          &first, last indices = ", j, k
  endif

 end subroutine testGSMap_

 logical function Identical_(GSMap1,GSMap2)

   use m_GlobalSegMap         ! Use all GlobalSegMap routines

   implicit none

   type(GlobalSegMap),         intent(in)  :: GSMap1, GSMap2

   integer :: i
   Identical_=.true.

   if(GSMap1%comp_id /= GSMap2%comp_id) Identical_=.false.
   if(GSMap1%ngseg /= GSMap2%ngseg) Identical_=.false.
   if(GSMap1%gsize /= GSMap2%gsize) Identical_=.false.

   do i=1,GSMap1%ngseg
      if(GSMap1%start(i) /= GSMap2%start(i)) Identical_=.false.
      if(GSMap1%length(i) /= GSMap2%length(i)) Identical_ =.false.
      if(GSMap1%pe_loc(i) /= GSMap2%pe_loc(i)) Identical_ =.false.
   enddo

 end function Identical_

end module m_GSMapTest
