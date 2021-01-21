!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_GlobalMap - One-Dimensional Domain Decomposition Descriptor
!
! !DESCRIPTION:
! The {\tt GlobalMap} is a datatype used to store descriptors of a
! one-dimensional domain decomposition for a vector on an MPI communicator.
! It is defined with three assumptions:
! \begin{enumerate}
! \item Each process ID owns only one segment;
! \item No two segments in the decomposition overlap; and
! \item The segments are laid out in identical order to the MPI rank of
! each process participating in the decomposition.
! \end{enumerate}
! per process ID).  It is the simpler of the two domain decomposition
! descriptors offerd by MCT (the other being the {\tt GlobalSegMap}).
! It consists of the following components:
! \begin{itemize}
! \item The MCT component identification number (see the module
! {\tt m\_MCTWorld} for more information about MCT's component model
! registry);
! \item The {\em global} number of elements in the distributed vector;
! \item The number of elements {\em stored locally};
! \item The number of elements {\em stored on each process} on the
! communicator over which the vector is distributed; and
! \item The index of the elemnent {\em immediately before} the starting
! element of each local segment (this choice allows for direct use of
! this information with MPI's scatter and gather operations).  We refer
! to this quantity as the {\em displacement} of the segment, a term used
! both here and in the definition of the MCT {\tt Navigator} datatype.
! \end{itemize}
!
! Both the segment displacement and length data are stored in arrays
! whose indices run from zero to $N-1$, where $N$ is the number of MPI
! processes on the communicator on which the {\tt GlobalMap} is defined.
! This is done so this information corresponds directly to the MPI process
! ID's on whihc the segments reside.
!
! This module contains the definition of the {\tt GlobalMap} datatype,
! all-processor and an on-root creation methods (both of which can be
! used to create a {\tt GlobalMap} on the local communicator), a creation
! method to create/propagate a {\tt GlobalMap} native to a remote
! communicator, a destruction method, and a variety of query methods.
!
! !INTERFACE:

 module m_GlobalMap

! !USES
! No external modules are used in the declaration section of this module.

      implicit none

      private	! except

! !PUBLIC TYPES:

      public :: GlobalMap		! The class data structure

    Type GlobalMap
      integer :: comp_id                        ! Component ID number
      integer :: gsize				! the Global size
      integer :: lsize				! my local size
      integer,dimension(:),pointer :: counts	! all local sizes
      integer,dimension(:),pointer :: displs	! PE ordered locations
    End Type GlobalMap

! !PUBLIC MEMBER FUNCTIONS:

      public :: gsize
      public :: lsize
      public :: init
      public :: init_remote
      public :: clean
      public :: rank
      public :: bounds
      public :: comp_id

    interface gsize; module procedure gsize_; end interface
    interface lsize; module procedure lsize_; end interface
    interface init ; module procedure	&
       initd_,	&	! initialize from all PEs
       initr_		! initialize from the root
    end interface
    interface init_remote; module procedure init_remote_; end interface
    interface clean; module procedure clean_; end interface
    interface rank ; module procedure rank_ ; end interface
    interface bounds; module procedure bounds_; end interface
    interface comp_id ; module procedure comp_id_ ; end interface

! !SEE ALSO:
! The MCT module m_MCTWorld for more information regarding component
! ID numbers.
!
! !REVISION HISTORY:
! 21Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!  9Nov00 - J.W. Larson <larson@mcs.anl.gov> - added init_remote
!           interface.
! 26Jan01 - J.W. Larson <larson@mcs.anl.gov> - added storage for
!           component ID number GlobalMap%comp_id, and associated
!           method comp_id_()
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_GlobalMap'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initd_ - Collective Creation on the Local Communicator
!
! !DESCRIPTION:
! This routine creates the {\tt GlobalMap} {\tt GMap} from distributed
! data spread across the MPI communicatior associated with the input
! {\tt INTEGER} handle {\tt comm}.  The {\tt INTEGER} input argument
! {\tt comp\_id} is used to define the MCT component ID for {\tt GMap}.
! The input {\tt INTEGER} argument {\tt ln} is the number of elements
! in the local vector segment.
!
! !INTERFACE:

 subroutine initd_(GMap, comp_id, ln, comm)

! !USES:

      use m_mpif90
      use m_die

      implicit none

! !INPUT PARAMETERS:

      integer,         intent(in)  :: comp_id ! Component ID
      integer,         intent(in)  :: ln      ! the local size
      integer,         intent(in)  :: comm    ! f90 MPI communicator
                                              ! handle

! !OUTPUT PARAMETERS:

      type(GlobalMap), intent(out) :: GMap

! !SEE ALSO:
! The MCT module m_MCTWorld for more information regarding component
! ID numbers.
!
! !REVISION HISTORY:
! 21Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initd_'
  integer :: nPEs,myID,ier,l,i

  call MP_comm_size(comm,nPEs,ier)
  if(ier /= 0) call MP_perr_die(myname_,'MP_comm_size()',ier)

  call MP_comm_rank(comm,myID,ier)
  if(ier /= 0) call MP_perr_die(myname_,'MP_comm_rank()',ier)

  allocate(GMap%counts(0:nPEs-1),GMap%displs(0:nPEs-1),stat=ier)
  if(ier /= 0) call die(myname_,'allocate()',ier)

#ifdef MALL_ON
	call mall_ci(size(transfer(GMap%counts,(/1/))),myname_)
	call mall_ci(size(transfer(GMap%displs,(/1/))),myname_)
#endif

  call MPI_allgather(ln,1,MP_INTEGER,GMap%counts,1,MP_INTEGER,comm,ier)
  if(ier/=0) call MP_perr_die(myname_,'MPI_allgather()',ier)

  l=0
  do i=0,nPEs-1
    GMap%displs(i)=l
    l=l+GMap%counts(i)
  end do

  GMap%lsize=GMap%counts(myID)	! the local size
  GMap%gsize=l	! the global size
  GMap%comp_id = comp_id ! the component ID number

 end subroutine initd_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initr_ Create a GlobalMap from the Root Process
!
! !DESCRIPTION:
! This routine creates the {\tt GlobalMap} {\tt GMap}, and propagates
! it to all processes on the communicator associated with the MPI
! {\tt INTEGER} handle {\tt comm}.  The input {\tt INTEGER} arguments
! {\tt comp\_id} (the MCT component ID number) and {\tt lns(:)} need
! only be valid on the process whose rank is equal to {\tt root} on
! {\tt comm}.  The array {\tt lns(:)} should have length equal to the
! number of processes on {\tt comm}, and contains the length of each
! local segment.
!
! !INTERFACE:

 subroutine initr_(GMap, comp_id, lns, root, comm)

! !USES:

      use m_mpif90
      use m_die
      use m_stdio

      implicit none

! !INPUT PARAMETERS:

      integer,               intent(in)  :: comp_id ! component ID number
      integer, dimension(:), intent(in)  :: lns     ! segment lengths
      integer,               intent(in)  :: root    ! root process ID
      integer,               intent(in)  :: comm    ! communicator ID

! !OUTPUT PARAMETERS:

      type(GlobalMap),       intent(out) :: GMap

! !SEE ALSO:
! The MCT module m_MCTWorld for more information regarding component
! ID numbers.
!
! !REVISION HISTORY:
! 29May98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initr_'
  integer :: nPEs,myID,ier,l,i

  call MP_comm_size(comm,nPEs,ier)
  if(ier /= 0) call MP_perr_die(myname_,'MP_comm_size()',ier)

  call MP_comm_rank(comm,myID,ier)
  if(ier /= 0) call MP_perr_die(myname_,'MP_comm_rank()',ier)

  allocate(GMap%counts(0:nPEs-1),GMap%displs(0:nPEs-1),stat=ier)
  if(ier /= 0) call die(myname_,'allocate()',ier)

#ifdef MALL_ON
	call mall_ci(size(transfer(GMap%counts,(/1/))),myname_)
	call mall_ci(size(transfer(GMap%displs,(/1/))),myname_)
#endif

  if(myID == root) then
    if(size(lns(:)) /= nPEs) then
      write(stderr,'(2a,2(a,i4))') myname_,	&
	': _root_ argument error',		&
	', size(lns) =',size(lns),		&
	', nPEs =',nPEs
      call die(myname_)
    endif

    GMap%counts(:)=lns(:)
  endif

  call MPI_bcast(GMap%counts, nPEs, MP_INTEGER, root, comm, ier)
  if(ier/=0) call MP_perr_die(myname_,'MPI_bcast()',ier)

  ! on each process, use GMap%counts(:) to compute GMap%displs(:)

  l=0
  do i=0,nPEs-1
    GMap%displs(i)=l
    l=l+GMap%counts(i)
  end do

  GMap%lsize=GMap%counts(myID)	! the local size
  GMap%gsize=l	! the global size

  ! finally, set and broadcast the component ID number GMap%comp_id

  if(myID == root) GMap%comp_id = comp_id

  call MPI_bcast(GMap%comp_id,1,MP_INTEGER,root,comm,ier)
  if(ier/=0) call MP_perr_die(myname_,'MPI_bcast()',ier)

 end subroutine initr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: init_remote_ Initialize Remote GlobalMap from the Root
!
! !DESCRIPTION:
! This routine creates and propagates across the local communicator a
! {\tt GlobalMap} associated with a remote component.  The controlling
! process in this operation has MPI process ID defined by the input
! {\tt INTEGER} argument {\tt my\_root}, and its MPI communinicator
! is defined by the input {\tt INTEGER} argument {\tt my\_comm}.  The
! input {\tt INTEGER} argument {\tt remote\_npes} is the number of MPI
! processes on the remote component's communicator (which need be valid
! only on the process {\tt my\_root}).  The input the {\tt INTEGER}
! array {\tt remote\_lns(:)}, and the {\tt INTEGER} argument
! {\tt remote\_comp\_id} need only be valid on the process
! whose rank on the communicator {\tt my\_comm} is {\tt my\_root}.  The
! argument {\tt remote\_lns(:)} defines the vector segment length on each
! process of the remote component's communicator, and the argument
! {\tt remote\_comp\_id} defines the remote component's ID number in
! the MCT component registry {\tt MCTWorld}.
!
! !INTERFACE:

 subroutine init_remote_(GMap, remote_lns, remote_npes, my_root, &
                         my_comm, remote_comp_id)
! !USES:

      use m_mpif90
      use m_die
      use m_stdio

      implicit none

! !INPUT PARAMETERS:

      integer, dimension(:), intent(in)  :: remote_lns
      integer,               intent(in)  :: remote_npes
      integer,               intent(in)  :: my_root
      integer,               intent(in)  :: my_comm
      integer,               intent(in)  :: remote_comp_id

! !OUTPUT PARAMETERS:

      type(GlobalMap),       intent(out) :: GMap

! !SEE ALSO:
! The MCT module m_MCTWorld for more information regarding component
! ID numbers.
!
! !REVISION HISTORY:
!  8Nov00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
! 26Jan01 - J.W. Larson <larson@mcs.anl.gov> - slight change--remote
!           communicator is replaced by remote component ID number
!           in argument remote_comp_id.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::init_remote_'
  integer :: nPEs,myID,ier,l,i


        ! Which processor am I on communicator my_comm?  Store
        ! the answer in myID:

  call MP_comm_rank(my_comm, myID, ier)
  if(ier /= 0) call MP_perr_die(myname_,'MP_comm_rank()',ier)

        ! allocate counts and displacements component arrays
        ! for the sake of compactness, store the value of remote_npes
        ! in the more tersely named variable nPEs.

  if(myID == my_root) nPEs = remote_npes

  call MPI_bcast(nPEs, 1, MP_INTEGER, my_root, my_comm, ier)
  if(ier/=0) call MP_perr_die(myname_,'MPI_bcast(nPEs...)',ier)

  allocate(GMap%counts(0:nPEs-1),GMap%displs(0:nPEs-1),stat=ier)
  if(ier /= 0) call die(myname_,'allocate()',ier)

#ifdef MALL_ON
	call mall_ci(size(transfer(GMap%counts,(/1/))),myname_)
	call mall_ci(size(transfer(GMap%displs,(/1/))),myname_)
#endif

        ! On the Root processor, check the size of remote_lns(:)
        ! to see it is equal to nPEs, the number of remote processes,
        ! then store it as GMap%counts and broadcast it.

  if(myID == my_root) then
    if(size(remote_lns(:)) /= nPEs) then
      write(stderr,'(2a,2(a,i4))') myname_,	 &
	': _root_ argument error',		 &
	', size(remote_lns) =',size(remote_lns), &
	', nPEs =',nPEs
      call die(myname_)
    endif

    GMap%counts(:)=remote_lns(:)
  endif

  call MPI_bcast(GMap%counts, nPEs, MP_INTEGER, my_root, my_comm, ier)
  if(ier/=0) call MP_perr_die(myname_,'MPI_bcast()',ier)

        ! Now, on each processor of my_comm, compute from
        ! GMap%counts(:) the entries of GMap%displs(:)

  l=0
  do i=0,nPEs-1
    GMap%displs(i)=l
    l=l+GMap%counts(i)
  end do

  GMap%lsize = -1                ! In this case, the local size is invalid!!!
  GMap%gsize = l      	         ! the global size

        ! Finally, set GMap's component ID (recall only the value on
        ! process my_root is valid).

  if(myID == my_root)  GMap%comp_id = remote_comp_id
  call MPI_bcast(GMap%comp_id, 1, MP_INTEGER, my_root, my_comm,ier)
  if(ier/=0) call MP_perr_die(myname_,'MPI_bcast(GMap%comp_id...)',ier)

 end subroutine init_remote_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: clean_ - Destroy a GlobalMap
!
! !DESCRIPTION:
! This routine deallocates all allocated memory associated with the
! input/output {\tt GlobalMap} argument {\tt GMap}, and sets to zero
! all of its statically defined components.  The success (failure) of
! this operation is signified by the zero (non-zero) value of the
! optional output {\tt INTEGER} argument {\tt stat}.
!
! !INTERFACE:

 subroutine clean_(GMap, stat)

! !USES:

      use m_die

      implicit none

! !INPUT/OUTPUT PARAMETERS:

      type(GlobalMap),           intent(inout) :: GMap

! !OUTPUT PARAMETERS:

      integer,         optional, intent(out)   :: stat

! !REVISION HISTORY:
! 21Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 26Jan01 - J. Larson <larson@mcs.anl.gov> incorporated comp_id.
!  1Mar02 - E.T. Ong <eong@mcs.anl.gov> removed the die to prevent
!           crashes and added stat argument.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::clean_'
  integer :: ier

  deallocate(GMap%counts,GMap%displs,stat=ier)

  if(present(stat)) then
     stat=ier
  else
     if(ier /= 0) call warn(myname_,'deallocate(GMap%...)',ier)
  endif

  if(ier == 0) then

#ifdef MALL_ON
	call mall_co(size(transfer(GMap%counts,(/1/))),myname_)
	call mall_co(size(transfer(GMap%displs,(/1/))),myname_)
#endif

  endif

  GMap%lsize = 0
  GMap%gsize = 0
  GMap%comp_id = 0

 end subroutine clean_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: lsize_ - Return Local Segment Length
!
! !DESCRIPTION:
! This {\tt INTEGER} function returns the length of the local vector
! segment as defined by the input {\tt GlobalMap} argument {\tt GMap}.

! !INTERFACE:

 integer function lsize_(GMap)

! !USES:

      implicit none

! !INPUT PARAMETERS:

      type(GlobalMap), intent(in) :: GMap

! !REVISION HISTORY:
! 21Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::lsize_'

  lsize_=GMap%lsize

 end function lsize_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: gsize_ - Return Global Vector Length
!
! !DESCRIPTION:
! This {\tt INTEGER} function returns the global length of a vector
! that is decomposed according to the input {\tt GlobalMap} argument
! {\tt GMap}.
!
! !INTERFACE:

 integer function gsize_(GMap)

! !USES:

      implicit none

! !INPUT PARAMETERS:

      type(GlobalMap), intent(in) :: GMap


! !REVISION HISTORY:
! 21Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::gsize_'

  gsize_=GMap%gsize

 end function gsize_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: rank_ - Process ID Location of a Given Vector Element
!
! !DESCRIPTION:
! This routine uses the input {\tt GlobalMap} argument {\tt GMap} to
! determine the process ID (on the communicator on which {\tt GMap} was
! defined) of the vector element with global index {\tt i\_g}.  This
! process ID is returned in the output {\tt INTEGER} argument {\tt rank}.
!
! !INTERFACE:

 subroutine rank_(GMap, i_g, rank)

! !USES:

      implicit none

! !INPUT PARAMETERS:

      type(GlobalMap), intent(in)  :: GMap
      integer,         intent(in)  :: i_g

! !OUTPUT PARAMETERS:

      integer,         intent(out) :: rank

! !REVISION HISTORY:
!  5May98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::rank_'
  integer :: i,ilc,ile

  rank=-1	! if nowhere fits
  do i=0,size(GMap%displs)-1
    ilc=GMap%displs(i)
    ile=ilc+GMap%counts(i)

		! If i_g in (ilc,ile].  Note that i_g := [1:..]

    if(ilc < i_g .and. i_g <= ile) then
      rank=i
      return
    endif
  end do

 end subroutine rank_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: bounds_ - First/Last Global Indicies for a Process' Segment
!
! !DESCRIPTION:
! This routine takes as input a process ID (defined by the input
! {\tt INTEGER} argument {\tt pe\_no}), examines the input {\tt GlobalMap}
! argument {\tt GMap}, and returns the global indices for the first and
! last elements of the segment owned by this process in the output
! {\tt INTEGER} arguments {\tt lbnd} and {\tt ubnd}, respectively.
!
! !INTERFACE:

 subroutine bounds_(GMap, pe_no, lbnd, ubnd)

! !USES:

      implicit none

! !INPUT PARAMETERS:

      type(GlobalMap), intent(in)  :: GMap
      integer,         intent(in)  :: pe_no

! !OUTPUT PARAMETERS:

      integer,         intent(out) :: lbnd
      integer,         intent(out) :: ubnd

! !REVISION HISTORY:
! 30Jan01 - J. Larson <larson@mcs.anl.gov> - initial code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::bounds_'

  lbnd = GMap%displs(pe_no) + 1
  ubnd = lbnd + GMap%counts(pe_no) - 1

 end subroutine bounds_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: comp_id_ - Return the Component ID Number
!
! !DESCRIPTION:
! This {\tt INTEGER} query function returns the MCT component ID number
! stored in the input {\tt GlobalMap} argument {\tt GMap}.
!
! !INTERFACE:

 integer function comp_id_(GMap)

! !USES:

      implicit none

! !INPUT PARAMETERS:

      type(GlobalMap), intent(in) :: GMap

! !SEE ALSO:
! The MCT module m_MCTWorld for more information regarding component
! ID numbers.
!
! !REVISION HISTORY:
! 25Jan02 - J. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::comp_id_'

  comp_id_ = GMap%comp_id

 end function comp_id_

 end module m_GlobalMap
