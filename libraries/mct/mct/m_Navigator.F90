!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_Navigator - An Object for Indexing Segments of a Vector
!
! !DESCRIPTION:
! A {\em Navigator} is a table used to {\em index} or {\em Navigate}
!  segments of a vector, or segments of a dimension of a
! higher-dimensional array.  In MCT, this concept is embodied in
! the {\tt Navigator} datatype, which contains
! the following components:
! \begin{itemize}
! \item The {\em number} of segments;
! \item The {\em displacement} of the starting index of each segment
! from the vector's first element (i.e. the starting index minus 1);
! \item The {\em length} of each segment; and
! \item The {\em total length} of the vector or array dimension for which
! segments are defined.  This last item is optional, but if defined
! provides the ability for the {\tt Navigator} to check for erroneous
! segment entries (i.e., segments that are out-of-bounds).
! \end{itemize}
!
! This module defines the {\tt Navigator} datatype, creation and
! destruction methods, a variety of query methods, and a method for
! resizing the {\tt Navigator}.
!
! !INTERFACE:

 module m_Navigator

! !USES:
! No external modules are used in the declaration section of this module.

      implicit none

      private	! except

! !PUBLIC TYPES:

      public :: Navigator		! The class data structure

    Type Navigator
      integer :: NumSegments	! Number of defined Segments
      integer :: VectorLength	! Length of the Vector being indexed
      integer,pointer,dimension(:) :: displs ! Segment start displacements
      integer,pointer,dimension(:) :: counts ! Segment lengths
    End Type Navigator

! !PUBLIC MEMBER FUNCTIONS:

      public :: Navigator_init,init ! initialize an object
      public :: clean               ! clean an object
      public :: NumSegments         ! number of vector segments
      public :: VectorLength        ! indexed vector's total length
      public :: msize               ! the maximum size
      public :: resize              ! adjust the true size
      public :: get                 ! get an entry
      public :: ptr_displs          ! referencing %displs(:)
      public :: ptr_counts          ! referencing %counts(:)

    interface Navigator_init; module procedure	&
       init_
    end interface
    interface init  ; module procedure init_  ; end interface
    interface clean ; module procedure clean_ ; end interface
    interface NumSegments ; module procedure  &
       NumSegments_
    end interface
    interface VectorLength ; module procedure  &
       VectorLength_
    end interface
    interface msize ; module procedure msize_ ; end interface
    interface resize; module procedure resize_; end interface
    interface get   ; module procedure get_   ; end interface
    interface ptr_displs; module procedure &
       ptr_displs_
    end interface
    interface ptr_counts; module procedure &
       ptr_counts_
    end interface

! !REVISION HISTORY:
! 22May00 - Jing Guo <guo@dao.gsfc.nasa.gov> - initial prototype/prolog/code
! 26Aug02 - J. Larson <larson@mcs.anl.gov> - expanded datatype to inlcude
!           VectorLength component.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_Navigator'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: init_ - Create a Navigator
!
! !DESCRIPTION:
! This routine creates a {\tt Navigator} {\tt Nav} capable of storing
! information about {\tt NumSegments} segments.  The user can supply the
! length of the vector (or array subspace) being indexed by supplying the
! optional input {\tt INTEGER} argument {\tt VectorLength} (if it is not
! supplied, this component of {\tt Nav} will be set to zero, signifying
! to other {\tt Navigator} routines that vector length information is
! unavailable).  The success (failure) of this operation is signified by
! the zero (non-zero) value of the optional output {\tt INTEGER} argument
! {\tt stat}.
!
! !INTERFACE:

    subroutine init_(Nav, NumSegments, VectorLength, stat)

! !USES:

      use m_mall,only : mall_ison,mall_mci
      use m_die ,only : die,perr
      use m_stdio, only : stderr

      implicit none

! !INPUT PARAMETERS:

      integer,                   intent(in)  :: NumSegments
      integer,         optional, intent(in)  :: VectorLength

! !OUTPUT PARAMETERS:

      type(Navigator),           intent(out) :: Nav
      integer,         optional, intent(out) :: stat

! !REVISION HISTORY:
! 22May00 - Jing Guo <guo@dao.gsfc.nasa.gov> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::init_'
  integer :: ier

! If the argument VectorLength is present, use this value to set
! Nav%VectorLength.  Otherwise, set Nav%VectorLength to zero.

  if(present(VectorLength)) then
     if(VectorLength < 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: FATAL -- illegal value of VectorLength=',VectorLength
	call die(myname_)
     endif
     Nav%VectorLength = VectorLength
  else
     Nav%VectorLength = 0
  endif

! Allocate segment attribute table arrays:

  allocate(Nav%displs(NumSegments),Nav%counts(NumSegments),stat=ier)
  if(ier/=0) then
     call perr(myname_,'allocate()',ier)
     if(.not.present(stat)) call die(myname_)
     stat=ier
     return
  endif
  if(mall_ison()) then
     call mall_mci(Nav%displs,myname)
     call mall_mci(Nav%counts,myname)
  endif

  Nav%NumSegments=NumSegments

 end subroutine init_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: clean_ - Destroy a Navigator
!
! !DESCRIPTION:
! This routine deallocates allocated memory associated with the
! input/output {\tt Navigator} argument {\tt Nav}, and clears the
! vector length and number of segments components  The success (failure)
! of this operation is signified by the zero (non-zero) value of the
! optional output {\tt INTEGER} argument {\tt stat}.
!
! !INTERFACE:

 subroutine clean_(Nav, stat)

! !USES:

      use m_mall, only : mall_ison,mall_mco
      use m_die,  only : warn

      implicit none

! !INPUT/OUTPUT PARAMETERS:

      type(Navigator),intent(inout) :: Nav

! !OUTPUT PARAMETERS:

      integer,optional,intent(out) :: stat

! !REVISION HISTORY:
! 22May00 - Jing Guo <guo@dao.gsfc.nasa.gov> initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::clean_'
  integer :: ier

  if(mall_ison()) then
     if(associated(Nav%displs)) call mall_mco(Nav%displs,myname_)
     if(associated(Nav%counts)) call mall_mco(Nav%counts,myname_)
  endif

  deallocate(Nav%displs,Nav%counts,stat=ier)

  if(present(stat)) then
     stat=ier
  else
     if(ier /= 0) call warn(myname_,'deallocate(Nav%...)',ier)
  endif

  Nav%NumSegments = 0
  Nav%VectorLength = 0

 end subroutine clean_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: NumSegments_ - Return the Number of Segments
!
! !DESCRIPTION:
! This {\tt INTEGER} query function returns the number of segments
! in the input {\tt Navigator} argument {\tt Nav} for which segment
! start and length information are defined .
!
! !INTERFACE:

 integer function NumSegments_(Nav)

! !USES:

      implicit none

! !INPUT PARAMETERS:

      type(Navigator), intent(in) :: Nav

! !REVISION HISTORY:
! 22May00 - Jing Guo <guo@dao.gsfc.nasa.gov> initial prototype/prolog/code
!  1Mar02 - E.T. Ong <eong@mcs.anl.gov> - removed die to prevent crashes.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::NumSegments_'

  NumSegments_=Nav%NumSegments

 end function NumSegments_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: msize_ - Return the Maximum Capacity for Segment Storage
!
! !DESCRIPTION:
! This {\tt INTEGER} query function returns the maximum number of
! segments for which start and length information can be stored in the
! input {\tt Navigator} argument {\tt Nav}.
!
! !INTERFACE:

 integer function msize_(Nav)

! !USES:

      implicit none

! !INPUT PARAMETERS:

      type(Navigator),intent(in) :: Nav

! !REVISION HISTORY:
! 22May00 - Jing Guo <guo@dao.gsfc.nasa.gov> initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::msize_'

  msize_=size(Nav%displs)

 end function msize_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: VectorLength_ - Return the Navigated Vector's Length
!
! !DESCRIPTION:
! This {\tt INTEGER} query function returns the total length of the
! vector navigated by the input {\tt Navigator} argument {\tt Nav}.
! Note that the vector length is a quantity the user must have set
! when {\tt Nav} was initialized.  If it has not been set, the return
! value will be zero.
!
! !INTERFACE:

 integer function VectorLength_(Nav)

! !USES:

      implicit none

! !INPUT PARAMETERS:

      type(Navigator), intent(in) :: Nav

! !REVISION HISTORY:
! 26Aug02 - J. Larson <larson@mcs.anl.gov> - initial implementation
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::VectorLength_'

  VectorLength_=Nav%VectorLength

 end function VectorLength_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: resize_ - Reset the Number of Segments
!
! !DESCRIPTION:
! This routine resets the number of segments stored in the input/output
! {\tt Navigator} argument {\tt Nav}.  It behaves in one of two modes:
! If the optional {\tt INTEGER} input argument {\tt NumSegments} is
! provided, then this value is taken to be the new number of segments.
! If this routine is invoked without {\tt NumSegments} provided, then
! the new number of segments is set as per the result of the Fortran
! {\tt size()} function applied to the segment table arrays.
!
! !INTERFACE:

 subroutine resize_(Nav, NumSegments)

! !USES:

      use m_stdio, only : stderr
      use m_die,  only : die

      implicit none

! !INPUT PARAMETERS:

      integer,optional,intent(in) :: NumSegments

! !INPUT/OUTPUT PARAMETERS:

      type(Navigator),intent(inout) :: Nav

! !REVISION HISTORY:
! 22May00 - Jing Guo <guo@dao.gsfc.nasa.gov> initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::resize_'
  integer :: m

  m=msize_(Nav)

  if(present(NumSegments)) then
     if(NumSegments > m) then
	write(stderr,'(3a,2(i8,a))') myname_, &
	     ':: FATAL value of argument NumSegments exceeds maximum ', &
	     ' storage for this Navigator.  NumSegments = ',NumSegments, &
	     ' Maximum storage capacity = ',m,' segments.'
	call die(myname_)
     endif
     Nav%NumSegments=NumSegments
  else
     Nav%NumSegments=m
  endif

 end subroutine resize_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: get_ - Retrieve Characteristics of a Segment
!
! !DESCRIPTION:
! This multi-purpose query routine can be used to retrieve various
! characteristics of a given segment (identified by the input
! {\tt INTEGER} argument {\tt iSeg}) stored in the input {\tt Navigator}
! argument {\tt Nav}:
! \begin{enumerate}
! \item The {\em displacement} of the first element in this segment from
! the first element of the vector.  This quantity is returned in the
! optional output {\tt INTEGER} argument {\tt displ}
! \item The {\em number of elements} in this segment.  This quantity
! is returned in the optional output {\tt INTEGER} argument {\tt displ}
! \item The {\em index} of the first element in this segment  This
! quantity is returned in the optional output {\tt INTEGER} argument
! {\tt lc}.
! \item The {\em index} of the final element in this segment  This
! quantity is returned in the optional output {\tt INTEGER} argument
! {\tt le}.
! \end{enumerate}
! Any combination of the above characteristics may be obtained by
! invoking this routine with the corresponding optional arguments.
!
! !INTERFACE:

 subroutine get_(Nav, iSeg, displ, count, lc, le)

! !USES:

      use m_stdio, only : stderr
      use m_die,  only : die

      implicit none

! !INPUT PARAMETERS:

      type(Navigator),           intent(in)  :: Nav
      integer,                   intent(in)  :: iSeg

! !OUTPUT PARAMETERS:

      integer,         optional, intent(out) :: displ
      integer,         optional, intent(out) :: count
      integer,         optional, intent(out) :: lc
      integer,         optional, intent(out) :: le

! !REVISION HISTORY:
! 22May00 - Jing Guo <guo@dao.gsfc.nasa.gov>  initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::get_'


       ! Argument sanity check:

  if(iSeg > msize_(Nav)) then
     write(stderr,'(2a,2(a,i8))') myname_, &
	  ':: FATAL -- Segment index out of Navigator table bounds, ', &
	  'Size of Navigator table = ',msize_(Nav),' iSeg = ',iSeg
     call die(myname_)
  endif

  if(present(displ)) displ=Nav%displs(iSeg)
  if(present(count)) count=Nav%counts(iSeg)
  if(present(lc)) lc=Nav%displs(iSeg)+1
  if(present(le)) le=Nav%displs(iSeg)+Nav%counts(iSeg)

 end subroutine get_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ptr_displs_ - Returns Pointer to the displs(:) Component
!
! !DESCRIPTION:
! This pointer-valued query function returns a pointer to the
! {\em displacements} information (the displacement of the first element
! of each segment from the beginning of the vector) contained in the
! input {\tt Navigator} argument {\tt Nav}.  It has four basic modes
! of behavior, depending on which (if any) of the optional input
! {\tt INTEGER} arguments {\tt lbnd} and {\tt ubnd} are supplied.
! \begin{enumerate}
! \item  If neither {\tt lbnd} nor {\tt ubnd} is supplied, then
! {\tt ptr\_displs\_} returns a pointer to {\em all} the elements in
! the array {\tt Nav\%displs(:)}.
! \item  If both {\tt lbnd} and {\tt ubnd} are supplied, then
! {\tt ptr\_displs\_} returns a pointer to the segment of the
! array {\tt Nav\%displs(lbnd:ubnd)}.
! \item  If {\tt lbnd} is supplied but {\tt ubnd} is not, then
! {\tt ptr\_displs\_} returns a pointer to the segment of the
! array {\tt Nav\%displs(lbnd:msize)}, where {\tt msize} is the
! length of the array {\tt Nav\%displs(:)}.
! \item  If {\tt lbnd} is not supplied but {\tt ubnd} is, then
! {\tt ptr\_displs\_} returns a pointer to the segment of the
! array {\tt Nav\%displs(1:ubnd)}.
! \end{enumerate}
!
! !INTERFACE:

 function ptr_displs_(Nav, lbnd, ubnd)

! !USES:

      use m_stdio, only : stderr
      use m_die,  only : die

      implicit none

! !INPUT PARAMETERS:

      type(Navigator),           intent(in) :: Nav
      integer,         optional, intent(in) :: lbnd
      integer,         optional, intent(in) :: ubnd

! !OUTPUT PARAMETERS:

      integer,     dimension(:), pointer    :: ptr_displs_

! !REVISION HISTORY:
! 22May00 - Jing Guo <guo@dao.gsfc.nasa.gov> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ptr_displs_'
  integer :: lc,le

       ! Argument sanity checks

  if(present(lbnd)) then
     if(lbnd <= 0) then
	write(stderr,'(3a,i8)') myname_, &
	     ':: FATAL -- illegal lower bound, which must be >= 1.', &
	     'lbnd = ',lbnd
	call die(myname_)
     endif
  endif

  if(present(ubnd)) then
     if(ubnd > msize_(Nav)) then
	write(stderr,'(2a,2(a,i8))') myname_, &
	     ':: FATAL -- illegal upper bound, which must be <= msize(Nav).', &
	     'msize(Nav) = ',msize_(Nav),' ubnd = ',ubnd
	call die(myname_)
     endif
  endif

  if(present(lbnd) .and. present(ubnd)) then
     if(lbnd > ubnd) then
	write(stderr,'(2a,2(a,i8))') myname_, &
	     ':: FATAL --  upper bound, must be >= lower bound.', &
	     'Lower bound lbnd = ',lbnd,' Upper bound ubnd = ',ubnd
	call die(myname_)
     endif
  endif

       ! End argument sanity checks

  if(present(lbnd).or.present(ubnd)) then
    lc=lbound(Nav%displs,1)
    if(present(lbnd)) lc=lbnd
    le=ubound(Nav%displs,1)
    if(present(ubnd)) le=ubnd
    ptr_displs_ => Nav%displs(lc:le)
  else
    le=Nav%NumSegments
    ptr_displs_ => Nav%displs(1:le)
  endif

 end function ptr_displs_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ptr_counts_ - Returns Pointer to counts(:) Component
!
! !DESCRIPTION:
! This pointer-valued query function returns a pointer to the
! {\em counts} information (that is, the number of elements in each
! of each segment the vector being navigated) contained in the
! input {\tt Navigator} argument {\tt Nav}.  It has four basic modes
! of behavior, depending on which (if any) of the optional input
! {\tt INTEGER} arguments {\tt lbnd} and {\tt ubnd} are supplied.
! \begin{enumerate}
! \item  If neither {\tt lbnd} nor {\tt ubnd} is supplied, then
! {\tt ptr\_counts\_} returns a pointer to {\em all} the elements in
! the array {\tt Nav\%counts(:)}.
! \item  If both {\tt lbnd} and {\tt ubnd} are supplied, then
! {\tt ptr\_counts\_} returns a pointer to the segment of the
! array {\tt Nav\%counts(lbnd:ubnd)}.
! \item  If {\tt lbnd} is supplied but {\tt ubnd} is not, then
! {\tt ptr\_counts\_} returns a pointer to the segment of the
! array {\tt Nav\%counts(lbnd:msize)}, where {\tt msize} is the
! length of the array {\tt Nav\%counts(:)}.
! \item  If {\tt lbnd} is not supplied but {\tt ubnd} is, then
! {\tt ptr\_counts\_} returns a pointer to the segment of the
! array {\tt Nav\%counts(1:ubnd)}.
! \end{enumerate}
!
! !INTERFACE:

 function ptr_counts_(Nav, lbnd, ubnd)

! !USES:

      use m_stdio, only : stderr
      use m_die,  only : die

      implicit none

! !INPUT PARAMETERS:

      type(Navigator),           intent(in) :: Nav
      integer,         optional, intent(in) :: lbnd
      integer,         optional, intent(in) :: ubnd

! !OUTPUT PARAMETERS:

      integer, dimension(:),     pointer    :: ptr_counts_

! !REVISION HISTORY:
! 22May00 - Jing Guo <guo@dao.gsfc.nasa.gov>- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ptr_counts_'
  integer :: lc,le

       ! Argument sanity checks

  if(present(lbnd)) then
     if(lbnd <= 0) then
	write(stderr,'(3a,i8)') myname_, &
	     ':: FATAL -- illegal lower bound, which must be >= 1.', &
	     'lbnd = ',lbnd
	call die(myname_)
     endif
  endif

  if(present(ubnd)) then
     if(ubnd > msize_(Nav)) then
	write(stderr,'(2a,2(a,i8))') myname_, &
	     ':: FATAL -- illegal upper bound, which must be <= msize(Nav).', &
	     'msize(Nav) = ',msize_(Nav),' ubnd = ',ubnd
	call die(myname_)
     endif
  endif

  if(present(lbnd) .and. present(ubnd)) then
     if(lbnd > ubnd) then
	write(stderr,'(2a,2(a,i8))') myname_, &
	     ':: FATAL --  upper bound, must be >= lower bound.', &
	     'Lower bound lbnd = ',lbnd,' Upper bound ubnd = ',ubnd
	call die(myname_)
     endif
  endif

       ! End argument sanity checks

  if(present(lbnd).or.present(ubnd)) then
    lc=lbound(Nav%counts,1)
    if(present(lbnd)) lc=lbnd
    le=ubound(Nav%counts,1)
    if(present(ubnd)) le=ubnd
    ptr_counts_ => Nav%counts(lc:le)
  else
    le=Nav%NumSegments
    ptr_counts_ => Nav%counts(1:le)
  endif

 end function ptr_counts_

 end module m_Navigator
