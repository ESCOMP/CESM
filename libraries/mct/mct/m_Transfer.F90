!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_Transfer - Routines for the MxN transfer of Attribute Vectors
!
! !DESCRIPTION:
! This module provides routines for doing MxN transfer of data in an
! Attribute Vector between two components on separate sets of MPI processes.
! Uses the Router datatype.
!
! !SEE ALSO:
! m_Rearranger

! !INTERFACE:

 module m_Transfer

! !USES:
  use m_MCTWorld, only : MCTWorld
  use m_MCTWorld, only : ThisMCTWorld
  use m_AttrVect, only : AttrVect
  use m_AttrVect, only : nIAttr,nRAttr
  use m_AttrVect, only : Permute, Unpermute
  use m_AttrVect, only : AttrVect_init => init
  use m_AttrVect, only : AttrVect_copy => copy
  use m_AttrVect, only : AttrVect_clean => clean
  use m_AttrVect, only : lsize
  use m_Router,   only : Router

  use m_mpif90
  use m_die
  use m_stdio

  implicit none

  private ! except

! !PUBLIC MEMBER FUNCTIONS:

  public  :: isend
  public  :: send
  public  :: waitsend
  public  :: irecv
  public  :: recv
  public  :: waitrecv


  interface isend    ; module procedure isend_    ; end interface
  interface send     ; module procedure send_     ; end interface
  interface waitsend ; module procedure waitsend_ ; end interface
  interface irecv    ; module procedure irecv_    ; end interface
  interface recv     ; module procedure recv_     ; end interface
  interface waitrecv ; module procedure waitrecv_ ; end interface

! !DEFINED PARAMETERS:

  integer,parameter		       :: DefaultTag = 600

! !REVISION HISTORY:
! 08Nov02 - R. Jacob <jacob@mcs.anl.gov> - make new module by combining
!           MCT_Send, MCT_Recv and MCT_Recvsum
! 11Nov02 - R. Jacob <jacob@mcs.anl.gov> - Remove MCT_Recvsum and use
!           optional argument in recv_ to do the same thing.
! 23Jul03 - R. Jacob <jacob@mcs.anl.gov> - Move buffers for data and
!           MPI_Reqest and MPI_Status arrays to Router.  Use them.
! 24Jul03 - R. Jacob <jacob@mcs.anl.gov> - Split send_ into isend_ and
!           waitsend_.  Redefine send_.
! 22Jan08 - R. Jacob <jacob@mcs.anl.gov> - Handle unordered GSMaps
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_Transfer'

  contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: isend_ - Distributed non-blocking send of an Attribute Vector
!
! !DESCRIPTION:
! Send the the data in the {\tt AttrVect} {\tt aV} to the
! component specified in the {\tt Router} {\tt Rout}.  An error will
! result if the size of the attribute vector does not match the size
! parameter stored in the {\tt Router}.
!
! Requires a corresponding {\tt recv\_} or {\tt irecv\_} to be called on the other component.
!
! The optional argument {\tt Tag} can be used to set the tag value used in
! the data transfer.  DefaultTag will be used otherwise. {\tt Tag} must be
! the same in the matching {\tt recv\_} or {\tt irecv\_}.
!
! {\bf N.B.:} The {\tt AttrVect} argument in the corresponding
! {\tt recv\_} call is assumed to have exactly the same attributes
! in exactly the same order as {\tt aV}.
!
! !INTERFACE:

 subroutine isend_(aVin, Rout, Tag)

!
! !USES:
!
      implicit none

! !INPUT PARAMETERS:
!

      Type(AttrVect),target,intent(in)    :: aVin
      Type(Router),         intent(inout) :: Rout
      integer,optional,     intent(in) :: Tag

! !REVISION HISTORY:
! 07Feb01 - R. Jacob <jacob@mcs.anl.gov> - initial prototype
! 08Feb01 - R. Jacob <jacob@mcs.anl.gov> - First working code
! 18May01 - R. Jacob <jacob@mcs.anl.gov> - use MP_Type to determine type in mpi_send
! 07Jun01 - R. Jacob <jacob@mcs.anl.gov> - remove logic to check "direction" of Router.
!           remove references to ThisMCTWorld%mylrank
! 03Aug01 - E. Ong <eong@mcs.anl.gov> - Explicitly specify the starting address in mpi_send.
! 15Feb02 - R. Jacob <jacob@mcs.anl.gov> - Use MCT_comm
! 26Mar02 - E. Ong <eong@mcs.anl.gov> - Apply faster copy order
! 26Sep02 - R. Jacob <jacob@mcs.anl.gov> - Check Av against Router lAvsize
! 05Nov02 - R. Jacob <jacob@mcs.anl.gov> - Remove iList, rList arguments.
! 08Nov02 - R. Jacob <jacob@mcs.anl.gov> - MCT_Send is now send_ in m_Transfer
! 11Nov02 - R. Jacob <jacob@mcs.anl.gov> - Use DefaultTag and add optional Tag argument
! 25Jul03 - R. Jacob <jacob@mcs.anl.gov> - Split into isend_ and waitsend_
! 22Jan08 - R. Jacob <jacob@mcs.anl.gov> - Handle unordered GSMaps by permuting before send.
!           remove special case for sending one segment directly from Av which probably
!           wasn't safe.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::isend_'
  integer ::	numi,numr,i,j,k,ier
  integer ::    mycomp,othercomp
  integer ::    AttrIndex,VectIndex,seg_start,seg_end
  integer ::    proc,nseg,mytag
  integer ::    mp_Type_rp1
  logical ::    unordered
  type(AttrVect),pointer :: Av
  type(AttrVect),target  :: Avtmp

!--------------------------------------------------------

! Return if no one to send to
  if(Rout%nprocs .eq. 0 ) RETURN

! set up Av to send from
  unordered = associated(Rout%permarr)
  if (unordered) then
     call AttrVect_init(Avtmp,Avin,lsize(Avin))
     call AttrVect_copy(Avin,aVtmp)
     call Permute(aVtmp,Rout%permarr)
     Av => Avtmp
  else
     Av => Avin
  endif

!check Av size against Router
!
  if(lsize(aV) /= Rout%lAvsize) then
    write(stderr,'(2a)') myname_, &
    ' MCTERROR:  AV size not appropriate for this Router...exiting'
    call die(myname_)
  endif

! get ids of components involved in this communication
  mycomp=Rout%comp1id
  othercomp=Rout%comp2id


! find total number of real and integer vectors
! for now, assume we are sending all of them
  Rout%numiatt = nIAttr(aV)
  Rout%numratt = nRAttr(aV)
  numi = Rout%numiatt
  numr = Rout%numratt

!!!!!!!!!!!!!! IF SENDING INTEGER DATA
  if(numi .ge. 1) then

! allocate buffers to hold all outgoing data
  do proc=1,Rout%nprocs
     allocate(Rout%ip1(proc)%pi(Rout%locsize(proc)*numi),stat=ier)
     if(ier/=0) call die(myname_,'allocate(Rout%ip1%pi)',ier)
  enddo

  endif

!!!!!!!!!!!!!! IF SENDING REAL DATA
  if(numr .ge. 1) then

! allocate buffers to hold all outgoing data
  do proc=1,Rout%nprocs
     allocate(Rout%rp1(proc)%pr(Rout%locsize(proc)*numr),stat=ier)
     if(ier/=0) call die(myname_,'allocate(Rout%rp1%pr)',ier)
  enddo

  mp_Type_rp1=MP_Type(Rout%rp1(1)%pr(1))

  endif


  ! Load data going to each processor
  do proc = 1,Rout%nprocs

     j=1
     k=1

     ! load the correct pieces of the integer and real vectors
     ! if Rout%num_segs(proc)=1, then this will do one loop
     do nseg = 1,Rout%num_segs(proc)
	 seg_start = Rout%seg_starts(proc,nseg)
	 seg_end = seg_start + Rout%seg_lengths(proc,nseg)-1
	 do VectIndex = seg_start,seg_end
	    do AttrIndex = 1,numi
	        Rout%ip1(proc)%pi(j) = aV%iAttr(AttrIndex,VectIndex)
		j=j+1
	    enddo
	    do AttrIndex = 1,numr
	        Rout%rp1(proc)%pr(k) = aV%rAttr(AttrIndex,VectIndex)
	        k=k+1
	    enddo
	 enddo
     enddo



     ! Send the integer data
     if(numi .ge. 1) then

        ! set tag
        mytag = DefaultTag
        if(present(Tag)) mytag=Tag


	call MPI_ISEND(Rout%ip1(proc)%pi(1), &
	     Rout%locsize(proc)*numi,MP_INTEGER,Rout%pe_list(proc), &
	     mytag,ThisMCTWorld%MCT_comm,Rout%ireqs(proc),ier)

	if(ier /= 0) call MP_perr_die(myname_,'MPI_ISEND(ints)',ier)

     endif

     ! Send the real data
     if(numr .ge. 1) then

       ! set tag
       mytag = DefaultTag + 1
       if(present(Tag)) mytag=Tag +1


       call MPI_ISEND(Rout%rp1(proc)%pr(1), &
	    Rout%locsize(proc)*numr,mp_Type_rp1,Rout%pe_list(proc), &
	    mytag,ThisMCTWorld%MCT_comm,Rout%rreqs(proc),ier)


       if(ier /= 0) call MP_perr_die(myname_,'MPI_ISEND(reals)',ier)

    endif

  enddo

  if (unordered) then
     call AttrVect_clean(aVtmp)
     nullify(aV)
  else
     nullify(aV)
  endif

end subroutine isend_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: waitsend_ - Wait for a distributed non-blocking send to complete
!
! !DESCRIPTION:
! Wait for the data being sent with the {\tt Router} {\tt Rout} to complete.
!
! !INTERFACE:

 subroutine waitsend_(Rout)

!
! !USES:
!
      implicit none

! !INPUT PARAMETERS:
!
      Type(Router),         intent(inout) :: Rout

! !REVISION HISTORY:
! 24Jul03 - R. Jacob <jacob@mcs.anl.gov> - First working version is
!           the wait part of original send_
!EOP ___________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::waitsend_'
  integer ::   proc,ier

! Return if nothing to wait for
  if(Rout%nprocs .eq. 0 ) RETURN

  ! wait for all sends to complete
  if(Rout%numiatt .ge. 1) then

     call MPI_WAITALL(Rout%nprocs,Rout%ireqs,Rout%istatus,ier)
     if(ier /= 0) call MP_perr_die(myname_,'MPI_WAITALL(ints)',ier)

     do proc=1,Rout%nprocs
	deallocate(Rout%ip1(proc)%pi,stat=ier)
	if(ier/=0) call die(myname_,'deallocate(ip1%pi)',ier)
     enddo

  endif

  if(Rout%numratt .ge. 1) then

     call MPI_WAITALL(Rout%nprocs,Rout%rreqs,Rout%rstatus,ier)
     if(ier /= 0) call MP_perr_die(myname_,'MPI_WAITALL(reals)',ier)

     do proc=1,Rout%nprocs
	deallocate(Rout%rp1(proc)%pr,stat=ier)
	if(ier/=0) call die(myname_,'deallocate(rp1%pi)',ier)
     enddo

  endif


end subroutine waitsend_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: send_ - Distributed blocking send of an Attribute Vector
!
! !DESCRIPTION:
! Send the the data in the {\tt AttrVect} {\tt aV} to the
! component specified in the {\tt Router} {\tt Rout}.  An error will
! result if the size of the attribute vector does not match the size
! parameter stored in the {\tt Router}.
!
! Requires a corresponding {\tt recv\_} or {\tt irecv\_} to be called on the other
! component.
!
! The optional argument {\tt Tag} can be used to set the tag value used in
! the data transfer.  DefaultTag will be used otherwise. {\tt Tag} must be
! the same in the matching {\tt recv\_} or {\tt irecv\_}.
!
! {\bf N.B.:} The {\tt AttrVect} argument in the corresponding
! {\tt recv} call is assumed to have exactly the same attributes
! in exactly the same order as {\tt aV}.
!
! !INTERFACE:

 subroutine send_(aV, Rout, Tag)

!
! !USES:
!
      implicit none

! !INPUT PARAMETERS:
!

      Type(AttrVect),       intent(in)    :: aV
      Type(Router),         intent(inout) :: Rout
      integer,optional,     intent(in)    :: Tag

! !REVISION HISTORY:
! 24Jul03 - R. Jacob <jacob@mcs.anl.gov> - New version uses isend and waitsend
!EOP ___________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::send_'

  call isend_(aV,Rout,Tag)

  call waitsend_(Rout)

end subroutine send_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: irecv_ - Distributed receive of an Attribute Vector
!
! !DESCRIPTION:
! Recieve into the {\tt AttrVect} {\tt aV} the data coming from the
! component specified in the {\tt Router} {\tt Rout}.  An error will
! result if the size of the attribute vector does not match the size
! parameter stored in the {\tt Router}.
!
! Requires a corresponding {\tt send\_} or {\tt isend\_} to be called
! on the other component.
!
! The optional argument {\tt Tag} can be used to set the tag value used in
! the data transfer.  DefaultTag will be used otherwise. {\tt Tag} must be
! the same in the matching {\tt send\_} or {\tt isend\_}.
!
! If data for a grid point is coming from more than one process, {\tt recv\_}
! will overwrite the duplicate values leaving the last received value
! in the output aV.  If the optional argument {\tt Sum} is invoked, the output
! will contain the sum of any duplicate values received for the same grid point.
!
! Will return as soon as MPI\_IRECV's are posted.  Call {\tt waitrecv\_} to
! complete the receive operation.
!
! {\bf N.B.:} The {\tt AttrVect} argument in the corresponding
! {\tt send\_} call is assumed to have exactly the same attributes
! in exactly the same order as {\tt aV}.
!
! !INTERFACE:

 subroutine irecv_(aV, Rout, Tag, Sum)
!
! !USES:
!
      implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      Type(AttrVect),       intent(inout) :: aV

! !INPUT PARAMETERS:
!
      Type(Router),         intent(inout) :: Rout
      integer,optional,     intent(in)    :: Tag
      logical,optional,     intent(in)    :: Sum

! !REVISION HISTORY:
! 07Feb01 - R. Jacob <jacob@mcs.anl.gov> - initial prototype
! 07Jun01 - R. Jacob <jacob@mcs.anl.gov> - remove logic to
!           check "direction" of Router.  remove references
!           to ThisMCTWorld%mylrank
! 03Aug01 - E.T. Ong <eong@mcs.anl.gov> - explicity specify starting
!           address in MPI_RECV
! 27Nov01 - E.T. Ong <eong@mcs.anl.gov> - deallocated to prevent
!           memory leaks
! 15Feb02 - R. Jacob <jacob@mcs.anl.gov> - Use MCT_comm
! 26Mar02 - E. Ong <eong@mcs.anl.gov> - Apply faster copy order.
! 26Sep02 - R. Jacob <jacob@mcs.anl.gov> - Check Av against Router lAvsize
! 08Nov02 - R. Jacob <jacob@mcs.anl.gov> - MCT_Recv is now recv_ in m_Transfer
! 11Nov02 - R. Jacob <jacob@mcs.anl.gov> - Add optional Sum argument to
!           tell recv_ to sum data for the same point received from multiple
!           processors.  Replaces recvsum_ which had replaced MCT_Recvsum.
!           Use DefaultTag and add optional Tag argument
! 25Jul03 - R. Jacob <jacob@mcs.anl.gov> - break into irecv_ and waitrecv_
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::irecv_'
  integer ::	numi,numr,i,j,k,ier
  integer ::    mycomp,othercomp
  integer ::    seg_start,seg_end
  integer ::    proc,numprocs,nseg,mytag
  integer ::    mp_Type_rp1
  logical ::    DoSum

!--------------------------------------------------------

! Return if no one to receive from
  if(Rout%nprocs .eq. 0 ) RETURN

!check Av size against Router
!
  if(lsize(aV) /= Rout%lAvsize) then
    write(stderr,'(2a)') myname_, &
    ' MCTERROR:  AV size not appropriate for this Router...exiting'
    call die(myname_)
  endif

  DoSum = .false.
  if(present(Sum)) DoSum=Sum


  mycomp=Rout%comp1id
  othercomp=Rout%comp2id

!  find total number of real and integer vectors
! for now, assume we are receiving all of them
  Rout%numiatt = nIAttr(aV)
  Rout%numratt = nRAttr(aV)
  numi = Rout%numiatt
  numr = Rout%numratt

!!!!!!!!!!!!!! IF RECEVING INTEGER DATA
  if(numi .ge. 1) then

! allocate buffers to hold all incoming data
  do proc=1,Rout%nprocs
     allocate(Rout%ip1(proc)%pi(Rout%locsize(proc)*numi),stat=ier)
     if(ier/=0) call die(myname_,'allocate(Rout%ip1%pi)',ier)
  enddo

  endif

!!!!!!!!!!!!!! IF RECEIVING REAL DATA
  if(numr .ge. 1) then

! allocate buffers to hold all incoming data
  do proc=1,Rout%nprocs
     allocate(Rout%rp1(proc)%pr(Rout%locsize(proc)*numr),stat=ier)
     if(ier/=0) call die(myname_,'allocate(Rout%rp1%pr)',ier)
  enddo

  mp_Type_rp1=MP_Type(Rout%rp1(1)%pr(1))

  endif

  ! Post all MPI_IRECV
  do proc=1,Rout%nprocs

     ! receive the integer data
     if(numi .ge. 1) then

        ! set tag
        mytag = DefaultTag
        if(present(Tag)) mytag=Tag

	if( Rout%num_segs(proc) > 1 .or. DoSum ) then

	   call MPI_IRECV(Rout%ip1(proc)%pi(1), &
		Rout%locsize(proc)*numi,MP_INTEGER,Rout%pe_list(proc), &
		mytag,ThisMCTWorld%MCT_comm,Rout%ireqs(proc),ier)

	else

	   call MPI_IRECV(aV%iAttr(1,Rout%seg_starts(proc,1)), &
		Rout%locsize(proc)*numi,MP_INTEGER,Rout%pe_list(proc), &
		mytag,ThisMCTWorld%MCT_comm,Rout%ireqs(proc),ier)

	endif

	if(ier /= 0) call MP_perr_die(myname_,'MPI_IRECV(ints)',ier)

     endif

     ! receive the real data
     if(numr .ge. 1) then

	! corresponding tag logic must be in send_
        mytag = DefaultTag + 1
        if(present(Tag)) mytag=Tag +1

	if( Rout%num_segs(proc) > 1 .or. DoSum ) then

	   call MPI_IRECV(Rout%rp1(proc)%pr(1), &
		Rout%locsize(proc)*numr,mp_Type_rp1,Rout%pe_list(proc), &
		mytag,ThisMCTWorld%MCT_comm,Rout%rreqs(proc),ier)

	else

	   call MPI_IRECV(aV%rAttr(1,Rout%seg_starts(proc,1)), &
		Rout%locsize(proc)*numr,mp_Type_rp1,Rout%pe_list(proc), &
		mytag,ThisMCTWorld%MCT_comm,Rout%rreqs(proc),ier)

	endif

	if(ier /= 0) call MP_perr_die(myname_,'MPI_IRECV(reals)',ier)

     endif

  enddo

end subroutine irecv_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: waitrecv_ - Wait for a distributed non-blocking recv to complete
!
! !DESCRIPTION:
! Wait for the data being received with the {\tt Router} {\tt Rout} to complete.
! When done, copy the data into the {\tt AttrVect} {\tt aV}.
!
! !INTERFACE:

 subroutine waitrecv_(aV, Rout, Sum)

!
! !USES:
!
      implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      Type(AttrVect),       intent(inout) :: aV
      Type(Router),         intent(inout) :: Rout

! !INPUT PARAMETERS:
!
      logical,optional,     intent(in)    :: Sum


! !REVISION HISTORY:
! 25Jul03 - R. Jacob <jacob@mcs.anl.gov> - First working version is the wait
!           and copy parts from old recv_.
! 25Jan08 - R. Jacob <jacob@mcs.anl.gov> - Handle unordered GSMaps by
!           applying permutation to received array.
!EOP ___________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::waitrecv_'
  integer ::   proc,ier,j,k,nseg
  integer ::   AttrIndex,VectIndex,seg_start,seg_end
  logical ::   DoSum
  logical ::   unordered

! Return if nothing to wait for
  if(Rout%nprocs .eq. 0 ) RETURN

!check Av size against Router
!
  if(lsize(aV) /= Rout%lAvsize) then
    write(stderr,'(2a)') myname_, &
    ' MCTERROR:  AV size not appropriate for this Router...exiting'
    call die(myname_)
  endif

  unordered = associated(Rout%permarr)

  DoSum = .false.
  if(present(Sum)) DoSum=Sum

  ! wait for all recieves to complete
  if(Rout%numiatt .ge. 1)  then

    call MPI_WAITALL(Rout%nprocs,Rout%ireqs,Rout%istatus,ier)
    if(ier /= 0) call MP_perr_die(myname_,'MPI_WAITALL(ints)',ier)

  endif

  if(Rout%numratt .ge. 1) then

    call MPI_WAITALL(Rout%nprocs,Rout%rreqs,Rout%rstatus,ier)
    if(ier /= 0) call MP_perr_die(myname_,'MPI_WAITALL(reals)',ier)

  endif

  ! Load data which came from each processor
  do proc=1,Rout%nprocs

     if( (Rout%num_segs(proc) > 1) .or. DoSum ) then

        j=1
	k=1

	if(DoSum) then
	! sum the correct pieces of the integer and real vectors
	  do nseg = 1,Rout%num_segs(proc)
	   seg_start = Rout%seg_starts(proc,nseg)
	   seg_end = seg_start + Rout%seg_lengths(proc,nseg)-1
	   do VectIndex = seg_start,seg_end
	      do AttrIndex = 1,Rout%numiatt
		 aV%iAttr(AttrIndex,VectIndex)= &
		 aV%iAttr(AttrIndex,VectIndex)+Rout%ip1(proc)%pi(j)
		 j=j+1
	      enddo
	      do AttrIndex = 1,Rout%numratt
		 aV%rAttr(AttrIndex,VectIndex)= &
		 aV%rAttr(AttrIndex,VectIndex)+Rout%rp1(proc)%pr(k)
		 k=k+1
	      enddo
	   enddo
	  enddo
	else
	! load the correct pieces of the integer and real vectors
	  do nseg = 1,Rout%num_segs(proc)
	   seg_start = Rout%seg_starts(proc,nseg)
	   seg_end = seg_start + Rout%seg_lengths(proc,nseg)-1
	   do VectIndex = seg_start,seg_end
	      do AttrIndex = 1,Rout%numiatt
		 aV%iAttr(AttrIndex,VectIndex)=Rout%ip1(proc)%pi(j)
		 j=j+1
	      enddo
	      do AttrIndex = 1,Rout%numratt
		 aV%rAttr(AttrIndex,VectIndex)=Rout%rp1(proc)%pr(k)
		 k=k+1
	      enddo
	   enddo
	  enddo
        endif

     endif

  enddo

!........................WAITANY METHOD................................
!
!....NOTE: Make status argument a 1-dimensional array
!  ! Load data which came from each processor
!  do numprocs = 1,Rout%nprocs
!     ! Load the integer data
!     if(Rout%numiatt .ge. 1) then
!	call MPI_WAITANY(Rout%nprocs,Rout%ireqs,proc,Rout%istatus,ier)
!	if(ier /= 0) call MP_perr_die(myname_,'MPI_WAITANY(ints)',ier)
!	j=1
!	! load the correct pieces of the integer vectors
!	do nseg = 1,Rout%num_segs(proc)
!	   seg_start = Rout%seg_starts(proc,nseg)
!	   seg_end = seg_start + Rout%seg_lengths(proc,nseg)-1
!	   do VectIndex = seg_start,seg_end
!	      do AttrIndex = 1,Rout%numiatt
!		 aV%iAttr(AttrIndex,VectIndex)=Rout%ip1(proc)%pi(j)
!		 j=j+1
!	      enddo
!	   enddo
!	enddo
!     endif
!     ! Load the real data
!     if(numr .ge. 1) then
!	call MPI_WAITANY(Rout%nprocs,Rout%rreqs,proc,Rout%rstatus,ier)
!	if(ier /= 0) call MP_perr_die(myname_,'MPI_WAITANY(reals)',ier)
!	k=1
!	! load the correct pieces of the real vectors
!	do nseg = 1,Rout%num_segs(proc)
!	   seg_start = Rout%seg_starts(proc,nseg)
!	   seg_end = seg_start + Rout%seg_lengths(proc,nseg)-1
!	   do VectIndex = seg_start,seg_end
!	      do AttrIndex = 1,numr
!		 aV%rAttr(AttrIndex,VectIndex)=Rout%rp1(proc)%pr(k)
!		 k=k+1
!	      enddo
!	   enddo
!	enddo
!     endif
!  enddo
!........................................................................

  ! Deallocate all structures
  if(Rout%numiatt .ge. 1) then

     ! Deallocate the receive buffers
     do proc=1,Rout%nprocs
	deallocate(Rout%ip1(proc)%pi,stat=ier)
	if(ier/=0) call die(myname_,'deallocate(Rout%ip1%pi)',ier)
     enddo

  endif

  if(Rout%numratt .ge. 1) then

     ! Deallocate the receive buffers
     do proc=1,Rout%nprocs
	deallocate(Rout%rp1(proc)%pr,stat=ier)
	if(ier/=0) call die(myname_,'deallocate(Rout%rp1%pr)',ier)
     enddo

  endif

  if (unordered) call Unpermute(aV,Rout%permarr)

end subroutine waitrecv_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: recv_ - Distributed receive of an Attribute Vector
!
! !DESCRIPTION:
! Recieve into the {\tt AttrVect} {\tt aV} the data coming from the
! component specified in the {\tt Router} {\tt Rout}.  An error will
! result if the size of the attribute vector does not match the size
! parameter stored in the {\tt Router}.
!
! Requires a corresponding {\tt send\_} or {\tt isend\_}to be called
! on the other component.
!
! The optional argument {\tt Tag} can be used to set the tag value used in
! the data transfer.  DefaultTag will be used otherwise. {\tt Tag} must be
! the same in the matching {\tt send\_}
!
! If data for a grid point is coming from more than one process, {\tt recv\_}
! will overwrite the duplicate values leaving the last received value
! in the output aV.  If the optional argument {\tt Sum} is invoked, the output
! will contain the sum of any duplicate values received for the same grid point.
!
! Will not return until all data has been received.
!
! {\bf N.B.:} The {\tt AttrVect} argument in the corresponding
! {\tt send\_} call is assumed to have exactly the same attributes
! in exactly the same order as {\tt aV}.
!
! !INTERFACE:

 subroutine recv_(aV, Rout, Tag, Sum)
!
! !USES:
!
      implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      Type(AttrVect),       intent(inout) :: aV

! !INPUT PARAMETERS:
!
      Type(Router),         intent(inout)    :: Rout
      integer,optional,     intent(in)    :: Tag
      logical,optional,     intent(in)    :: Sum

! !REVISION HISTORY:
! 25Jul03 - R. Jacob <jacob@mcs.anl.gov> - Rewrite using irecv and waitrecv
!EOP ___________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::recv_'

  call irecv_(aV,Rout,Tag,Sum)

  call waitrecv_(aV,Rout,Sum)

end subroutine recv_


end module m_Transfer
