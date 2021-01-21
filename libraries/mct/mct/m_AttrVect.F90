!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_AttrVect - Multi-field Storage
!
! !DESCRIPTION:
!
! An {\em attribute vector} is a scheme for storing bundles of integer
! and real data vectors, indexed by the names of the fields stored in
! {\tt List} format (see the mpeu module {\tt m\_List} for more
! information about the {\tt List} datatype).  The ordering of the
! fieldnames in the integer and real attribute {\tt List} components
! ({\tt AttrVect\%iList} and {\tt AttrVect\%rList}, respectively)
! corresponds to the storage order of the attributes in their respective
! data buffers (the components {\tt AttrVect\%iAttr(:,:)} and
! {\tt AttrVect\%rAttr(:,:)}, respectively).   The organization of
! the fieldnames in {\tt List} format, along with the direct mapping
! between {\tt List} items and locations in the data buffer, allows
! the user to have {\em random access} to the field data.  This
! approach also allows the user to set the number and the names of fields
! stored in an {\tt AttrVect} at run-time.
!
! The {\tt AttrVect} stores field data in a {\em pointwise} fashion
! (that is, the data are grouped so that all the integer or real data
! associated with an individual point are adjacent to each other in memory.
! This amounts to the having the integer and real field data arrays in
! the {\tt AttrVect} (the components {\tt AttrVect\%iAttr(:,:)} and
! {\tt AttrVect\%rAttr(:,:)}, respectively) having the attribute index
! as the major (or fastest-varying) index.  A prime example of this is
! observational data input to a data assimilation system.  In the Model
! Coupling Toolkit, this datatype is the fundamental type for storing
! field data exchanged by component models, and forms a basis for other
! MCT datatypes that encapsulate time accumulation/averaging buffers (the
! {\tt Accumulator} datatype defined in the module {\tt m\_Accumulator}),
! coordinate grid information (the {\tt GeneralGrid} datatype defined in
! the module {\tt m\_GeneralGrid}), and sparse interpolation matrices
! (the {\tt SparseMatrix} datatype defined in the module
! {\tt m\_SparseMatrix}).
!
! The attribute vector is implemented in Fortran 90 using the
! {\tt AttrVect} derived type.  This module contains the definition
! of the {\tt AttrVect}, and the numerous methods that service it.  There
! are a number of initialization (creation) schemes, and a routine for
! zeroing out the elements of an {\tt AttrVect}.  There is a method
! to {\em clean} up allocated memory used by an {\tt AttrVect}
! (destruction).  There are numerous query methods that return:  the
! number of datapoints (or {\em length}; the numbers of integer and
! real attributes; the data buffer index of a given real or integer
! attribute; and return the lists of real and integer attributes.  There
! also exist methods for exporting a given attribute as a one-dimensional
! array and importing a given attribute from a one-dimensional array.
! There is a method for copying attributes from one {\tt AttrVect} to
! another.  There is also a method for cross-indexing the attributes in
! two {\tt AttrVect} variables.  In addition, there are methods that
! return those cross-indexed attributes along with some auxiliary data
! in a {\tt AVSharedIndicesOneType} or {\tt AVSharedIndices} structure.
! Finally, there are methods for sorting and permuting {\tt AttrVect}
! entries using a MergeSort scheme keyed by the attributes of the {\tt
! AttrVect}.
!
! !INTERFACE:

 module m_AttrVect
!
! !USES:
!
      use m_realkinds,only : SP,DP,FP          ! Real types definitions

      use m_List, only : List   ! Support for rList and iList components.

      implicit none

      private	! except

! !PUBLIC TYPES:

      public :: AttrVect        ! The class data structure
      public :: AVSharedIndicesOneType ! Data structure recording shared indices between
                                       ! two attribute vectors, for a single data type
                                       ! (e.g., shared real attributes)
      public :: AVSharedIndices ! Data structure recording shared indices between two
                                ! attribute vectors, for all data types

    type AttrVect
#ifdef SEQUENCE
      sequence
#endif
      type(List) :: iList
      type(List) :: rList
      integer,dimension(:,:),pointer :: iAttr
      real(FP) ,dimension(:,:),pointer :: rAttr
    end type AttrVect

    type AVSharedIndicesOneType
       integer :: num_indices           ! number of shared items
       logical :: contiguous            ! true if index segments are contiguous in memory
       character*7 :: data_flag         ! data type flag (e.g., 'REAL' or 'INTEGER')

       ! arrays of indices to storage locations of shared attributes between the two
       ! attribute vectors:
       integer, dimension(:), pointer :: aVindices1
       integer, dimension(:), pointer :: aVindices2
    end type AVSharedIndicesOneType

    type AVSharedIndices
       type(AVSharedIndicesOneType) :: shared_real     ! shared indices of type REAL
       type(AVSharedIndicesOneType) :: shared_integer  ! shared indices of type INTEGER
    end type AVSharedIndices


! !PUBLIC MEMBER FUNCTIONS:

      public :: init		! create a local vector
      public :: clean		! clean the local vector
      public :: zero		! zero the local vector
      public :: lsize		! size of the local vector
      public :: nIAttr		! number of integer attributes on local
      public :: nRAttr		! number of real attributes on local
      public :: indexIA		! index the integer attributes
      public :: indexRA		! index the real attributes
      public :: getIList        ! return list of integer attributes
      public :: getRList        ! return list of real attributes
      public :: getIListtoChar  ! return list of integer attributes as Char
      public :: getRListtoChar  ! return list of real attributes as Char
      public :: exportIList     ! export INTEGER attibute List
      public :: exportRList     ! export REAL attibute List
      public :: exportIListToChar ! export INTEGER attibute List as Char
      public :: exportRListToChar ! export REAL attibute List as Char
      public :: appendIAttr     ! append INTEGER attribute List
      public :: appendRAttr     ! append REAL attribute List
      public :: exportIAttr     ! export INTEGER attribute to vector
      public :: exportRAttr     ! export REAL attribute to vector
      public :: importIAttr     ! import INTEGER attribute from vector
      public :: importRAttr     ! import REAL attribute from vector
      public :: Copy		! copy attributes from one Av to another
      public :: RCopy		! copy real attributes from one Av to another
      public :: ICopy		! copy integer attributes from one Av to another
      public :: Sort            ! sort entries, and return permutation
      public :: Permute         ! permute entries
      public :: Unpermute       ! Unpermute entries
      public :: SortPermute     ! sort and permute entries
      public :: SharedAttrIndexList  ! Cross-indices of shared
                                     ! attributes of two AttrVects
      public :: SharedIndices        ! Given two AttrVects, create an AVSharedIndices structure
      public :: SharedIndicesOneType ! Given two AttrVects, create an
                                     ! AVSharedIndicesOneType structure for a single type
      public :: cleanSharedIndices   ! clean a AVSharedIndices structure
      public :: cleanSharedIndicesOneType  ! clean a AVSharedIndicesOneType structure


    interface init   ; module procedure	&
       init_,  &
       initv_, &
       initl_
    end interface
    interface clean  ; module procedure clean_  ; end interface
    interface zero  ; module procedure zero_  ; end interface
    interface lsize  ; module procedure lsize_  ; end interface
    interface nIAttr ; module procedure nIAttr_ ; end interface
    interface nRAttr ; module procedure nRAttr_ ; end interface
    interface indexIA; module procedure indexIA_; end interface
    interface indexRA; module procedure indexRA_; end interface
    interface getIList; module procedure getIList_; end interface
    interface getRList; module procedure getRList_; end interface
    interface getIListToChar; module procedure getIListToChar_; end interface
    interface getRListToChar; module procedure getRListToChar_; end interface
    interface exportIList; module procedure exportIList_; end interface
    interface exportRList; module procedure exportRList_; end interface
    interface exportIListToChar
       module procedure exportIListToChar_
    end interface
    interface exportRListToChar
       module procedure exportRListToChar_
    end interface
    interface appendIAttr  ; module procedure appendIAttr_  ; end interface
    interface appendRAttr  ; module procedure appendRAttr_  ; end interface
    interface exportIAttr; module procedure exportIAttr_; end interface
    interface exportRAttr; module procedure &
       exportRAttrSP_, &
       exportRAttrDP_
    end interface
    interface importIAttr; module procedure importIAttr_; end interface
    interface importRAttr; module procedure &
         importRAttrSP_, &
         importRAttrDP_
    end interface
    interface Copy    ; module procedure Copy_    ; end interface
    interface RCopy   ; module procedure  &
         RCopy_, &
         RCopyL_
    end interface
    interface ICopy   ; module procedure  &
          ICopy_, &
          ICopyL_
    end interface
    interface Sort    ; module procedure Sort_    ; end interface
    interface Permute ; module procedure Permute_ ; end interface
    interface Unpermute ; module procedure Unpermute_ ; end interface
    interface SortPermute ; module procedure SortPermute_ ; end interface
    interface SharedAttrIndexList ; module procedure &
        aVaVSharedAttrIndexList_
    end interface
    interface SharedIndices ; module procedure SharedIndices_ ; end interface
    interface SharedIndicesOneType ; module procedure SharedIndicesOneType_ ; end interface
    interface cleanSharedIndices ; module procedure cleanSharedIndices_ ; end interface
    interface cleanSharedIndicesOneType ; module procedure cleanSharedIndicesOneType_ ; end interface

! !REVISION HISTORY:
! 10Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 10Oct00 - J.W. Larson <larson@mcs.anl.gov> - made getIList
!           and getRList functions public and added appropriate
!           interface definitions
! 20Oct00 - J.W. Larson <larson@mcs.anl.gov> - added Sort,
!           Permute, and SortPermute functions.
! 09May01 - J.W. Larson <larson@mcs.anl.gov> - added initl_().
! 19Oct01 - J.W. Larson <larson@mcs.anl.gov> - added routines
!           exportIattr(), exportRAttr(), importIAttr(),
!           and importRAttr().  Also cleaned up module and
!           routine prologues.
! 13Dec01 - J.W. Larson <larson@mcs.anl.gov> - made importIAttr()
!           and importRAttr() public (bug fix).
! 14Dec01 - J.W. Larson <larson@mcs.anl.gov> - added exportIList()
!           and exportRList().
! 14Feb02 - J.W. Larson <larson@mcs.anl.gov> - added CHARCTER
!           functions exportIListToChar() and exportRListToChar()
! 26Feb02 - J.W. Larson <larson@mcs.anl.gov> - corrected of usage
!           of m_die routines throughout this module.
! 16Apr02 - J.W. Larson <larson@mcs.anl.gov> - added the method
!           LocalReduce(), and the public data members AttrVectSUM,
!           AttrVectMIN, and AttrVectMAX.
! 7May02 - J.W. Larson <larson@mcs.anl.gov> - Refactoring.  Moved
!          LocalReduce() and the public data members AttrVectSUM,
!           AttrVectMIN, and AttrVectMAX to a new module named
!           m_AttrVectReduce.
! 12Jun02 - R.L. Jacob <jacob@mcs.anl.gov> - add Copy function
! 13Jun02 - R.L. Jacob <jacob@mcs.anl.gov> - move aVavSharedAttrIndexList
!           to this module from old m_SharedAttrIndicies
! 28Apr11 - W.J. Sacks <sacks@ucar.edu> - added AVSharedIndices and
!           AVSharedIndicesOneType derived types, and associated
!           subroutines
! 10Apr12 - W.J. Sacks <sacks@ucar.edu> - modified AVSharedIndices code
!           to be Fortran-90 compliant
! 10Jan13 - T.Craig <tcraig@ucar.edu> - add getRListToChar and getIListToChar
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_AttrVect'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: init_ - Initialize an AttrVect Given Attribute Lists and Length
!
! !DESCRIPTION:
! This routine creates an {\tt AttrVect} (the output argument {\tt aV})
! using the optional input {\tt CHARACTER} arguments {\tt iList}, and
! {\tt rList} to define its integer and real attributes, respectively.
! The optional input {\tt INTEGER} argument {\tt lsize} defines the
! number of points for which we are storing attributes, or the
! {\em length} of {\tt aV}.  The expected form for the arguments
! {\tt iList} and {\tt rList} are colon-delimited strings where each
! substring defines an attribute.  Suppose we wish to store {\tt N}
! observations that have the real attributes {\tt 'latitude'},
! {\tt 'longitude'}, {\tt pressure}, {\tt 'u-wind'}, and
! {\tt 'v-wind'}.  Suppose we also wish to store the integer
! attributes {\tt 'hour'}, {\tt 'day'}, {\tt 'month'}, {\tt 'year'},
! and {\tt 'data source'}.  This can be accomplished by invoking
! {\tt init\_()} as follows:
! \begin{verbatim}
! call init_(aV, 'hour:day:month:year:data source', &
!            'latitude:longitude:pressure:u-wind:v-wind', N)
! \end{verbatim}
! The resulting {\tt AttrVect} {\tt aV} will have five integer
! attributes, five real attributes, and length {\tt N}.
!
! !INTERFACE:

 subroutine init_(aV, iList, rList, lsize)
!
! !USES:
!
      use m_List, only : List
      use m_List, only : init,nitem
      use m_List, only : List_nullify => nullify
      use m_mall
      use m_die

      implicit none

! !INPUT PARAMETERS:
!
      character(len=*), optional, intent(in)  :: iList
      character(len=*), optional, intent(in)  :: rList
      integer,          optional, intent(in)  :: lsize

! !OUTPUT PARAMETERS:
!
      type(AttrVect),             intent(out) :: aV

! !REVISION HISTORY:
! 09Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 09Oct01 - J.W. Larson <larson@mcs.anl.gov> - added feature to
!           nullify all pointers before usage.  This was done to
!           accomodate behavior of the f90 ASSOCIATED intrinsic
!           function on the AIX platform.
! 07Dec01 - E.T. Ong <eong@mcs.anl.gov> - added support for
!           intialization with blank character strings for iList
!           and rList
!EOP ___________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::init_'
  integer :: nIA,nRA,n,ier

       ! Initially, nullify all pointers in the AttrVect aV:

  nullify(aV%iAttr)
  nullify(aV%rAttr)
  call List_nullify(aV%iList)
  call List_nullify(aV%rList)

  if(present(rList)) then
     if(len_trim(rList) > 0) then
	call init(aV%rList,rList)	! init.List()
     endif
  endif

  if(present(iList)) then
     if(len_trim(iList) > 0) then
	call init(aV%iList,iList)	! init.List()
     endif
  endif

  nIA=nitem(aV%iList)		! nitem.List()
  nRA=nitem(aV%rList)		! nitem.List()

  n=0
  if(present(lsize)) n=lsize

  allocate( aV%iAttr(nIA,n),aV%rAttr(nRA,n),	stat=ier)
  if(ier /= 0) call die(myname_,'allocate()',ier)

#ifdef MALL_ON
	call mall_ci(size(transfer(aV%iAttr,(/1/)),myname_)
	call mall_ci(size(transfer(aV%rAttr,(/1/)),myname_)
#endif

 end subroutine init_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initv_ - Initialize One AttrVect from Another
!
! !DESCRIPTION:  This routine takes an input {\tt AttrVect} argument
! {\tt bV}, and uses its attribute list information to create an output
! {\tt AttrVect} variable {\tt aV}.  The length of {\tt aV} is defined
! by the input {\tt INTEGER} argument {\tt lsize}.
!
! !INTERFACE:

 subroutine initv_(aV, bV, lsize)
!
! !USES:
!
      use m_String, only : String,char
      use m_String, only : String_clean => clean
      use m_List,   only : get
      use m_List,   only : List_nullify => nullify
      use m_die
      use m_stdio

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),intent(in)  :: bV
      integer,       intent(in)  :: lsize

! !OUTPUT PARAMETERS:
!
      type(AttrVect),intent(out) :: aV

! !REVISION HISTORY:
! 22Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 17May01 - R. Jacob <jacob@mcs.anl.gov> - add a check to see if
!           input argument has been defined.  SGI will dump
!           core if its not.
! 10Oct01 - J. Larson <larson@mcs.anl.gov> - Nullify all pointers
!           in ouput AttrVect aV before initializing aV.
! 19Sep08 - J. Wolfe <jwolfe@ucar.edu> - plug memory leak from not deallocating
!           strings.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::initv_'
  type(String) :: iLStr,rLStr

	! Step One:  Nullify all pointers in aV.  We will set
        ! only the pointers we really need for aV based on those
        ! currently ASSOCIATED in bV.

  call List_nullify(aV%iList)
  call List_nullify(aV%rList)
  nullify(aV%iAttr)
  nullify(aV%rAttr)

	! Convert the two Lists to two Strings

  if(.not.associated(bv%iList%bf) .and. &
       .not.associated(bv%rList%bf)) then
     write(stderr,'(2a)')myname_, &
      'MCTERROR:  Trying to initialize a new AttrVect off an undefined AttrVect'
      call die(myname_,'undefined input argument',0)
  endif

  if(associated(bv%iList%bf)) then
     call get(iLStr,bv%iList)
  endif

  if(associated(bv%rList%bf)) then
     call get(rLStr,bv%rList)
  endif

       ! Initialize the AttrVect aV depending on which parts of
       ! the input bV are valid:

  if(associated(bv%iList%bf) .and. associated(bv%rList%bf)) then
     call init_(aV,iList=char(iLStr),rList=char(rLStr),lsize=lsize)
  endif
  if(.not.associated(bv%iList%bf) .and. associated(bv%rList%bf)) then
     call init_(aV,rList=char(rLStr),lsize=lsize)
  endif
  if(associated(bv%iList%bf) .and. .not.associated(bv%rList%bf)) then
     call init_(aV,iList=char(iLStr),lsize=lsize)
  endif

  if(associated(bv%iList%bf)) then
     call String_clean(iLStr)
  endif
  if(associated(bv%rList%bf)) then
     call String_clean(rLStr)
  endif

 end subroutine initv_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: initl_ - Initialize an AttrVect Using the List Type
!
! !DESCRIPTION:  This routine initializes an {\tt AttrVect} directly
! from input {\tt List} data type arguments {\tt iList} and {\tt rList}
! (see the module {\tt m\_List} in mpeu for further details), and an
! input length {\tt lsize}.  The resulting {\tt AttrVect} is returned in
! the argument {\tt aV}.
!
! {\bf N.B.}:  If the user supplies an empty list for the arguments
! {\tt iList} ({\tt rList}), then {\tt aV} will be created only with
! {\tt REAL} ({\tt INTEGER}) attributes.  If both arguments {\tt iList}
! and {\tt rList} are empty, the routine will terminate execution and
! report an error.
!
! {\bf N.B.}:  The outcome of this routine, {\tt aV} represents
! allocated memory.  When this {\tt AttrVect} is no longer needed,
! it must be deallocated by invoking the routine {\tt AttrVect\_clean()}.
! Failure to do so will spawn a memory leak.
!
! !INTERFACE:

 subroutine initl_(aV, iList, rList, lsize)

!
! !USES:
!
      use m_die
      use m_stdio

      use m_String, only : String
      use m_String, only : String_clean => clean
      use m_String, only : String_toChar => toChar

      use m_List, only : List
      use m_List, only : List_nitem => nitem
      use m_List, only : List_exportToChar => exportToChar

      implicit none

! !INPUT PARAMETERS:
!
      type(List),  intent(in)  :: iList
      type(List),  intent(in)  :: rList
      integer,     intent(in)  :: lsize

! !OUTPUT PARAMETERS:
!
      type(AttrVect), intent(out) :: aV

! !REVISION HISTORY:
! 09May98 - J.W. Larson <larson@mcs.anl.gov> - initial version.
! 08Aug01 - E.T. Ong <eong@mcs.anl.gov> - change list assignment(=)
!           to list copy to avoid compiler errors with pgf90.
! 10Oct01 - J. Larson <larson@mcs.anl.gov> - Nullify all pointers
!           in ouput AttrVect aV before initializing aV.  Also,
!           greater caution taken regarding validity of input
!           arguments iList and rList.
! 15May08 - J. Larson <larson@mcs.anl.gov> - Simplify to use
!           the init_ routine.  Better argument checking.
!EOP ___________________________________________________________________
!
  character(len=*),parameter :: myname_=myname//'::initl_'

  ! Basic argument sanity checks:

  if (List_nitem(iList) < 0) then
     write(stderr,'(2a,i8,a)') myname_, &
          ':: FATAL:  List argument iList has a negative number ( ',List_nitem(iList), &
          ' ) of attributes!'
     call die(myname_)
  endif

  if (List_nitem(rList) < 0) then
     write(stderr,'(2a,i8,a)') myname_, &
          ':: FATAL:  List argument rList has a negative number ( ',List_nitem(rList), &
          ' ) of attributes!'
     call die(myname_)
  endif

  if ((List_nitem(iList) > 0) .and. (List_nitem(rList) > 0)) then

     call init_(aV, List_exportToChar(iList), List_exportToChar(rList), lsize)

  else ! Then solely REAL or solely INTEGER attributes:

     if (List_nitem(iList) > 0) then ! solely INTEGER attributes

        call init_(aV, iList=List_exportToChar(iList), lsize=lsize)

     endif ! if (List_nitem(iList) > 0) then...

     if (List_nitem(rList) > 0) then ! solely REAL attributes

        call init_(aV, rList=List_exportToChar(rList), lsize=lsize)

     endif ! if (List_nitem(rList) > 0) then...

  endif ! if ((List_nitem(iList) > 0) .and. (List_nitem(rList) > 0)) then...

 end subroutine initl_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: clean_ - Deallocate Allocated Memory Structures of an AttrVect
!
! !DESCRIPTION:
! This routine deallocates the allocated memory structures of the
! input/output {\tt AttrVect} argument {\tt aV}.  This amounts to
! cleaning the {\tt List} structures {\tt aV\%iList} and {\tt av\%rList},
! and deallocating the arrays {\tt aV\%iAttr(:,:)} and
! {\tt aV\%rAttr(:,:)}.  The success (failure) of this operation is
! signified by a zero (non-zero) value of the optional {\tt INTEGER}
! output argument {\tt stat}.  If {\tt clean\_()} is invoked without
! supplying {\tt stat}, and any of the deallocation operations fail,
! the routine will terminate with an error message.
!
! !INTERFACE:

 subroutine clean_(aV, stat)
!
! !USES:
!
      use m_mall
      use m_stdio
      use m_die
      use m_List, only : List_clean => clean

      implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),    intent(inout) :: aV

! !OUTPUT PARAMETERS:
!
      integer, optional, intent(out)   :: stat

! !REVISION HISTORY:
! 09Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 10Oct01 - J. Larson <larson@mcs.anl.gov> - various fixes to
!           prevent deallocation of UNASSOCIATED pointers.
! 01Mar01 - E.T. Ong <eong@mcs.anl.gov> - removed dies to prevent
!           crashes when cleaning uninitialized attrvects. Added
!           optional stat argument.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::clean_'
  integer :: ier

	! Note that an undefined pointer may either crash the process
	! or return either .true. or .false. to the associated() test.
	! One should therefore avoid using the function on an
	! undefined pointer.

        ! Clean up INTEGER attribute list:

  if(present(stat)) stat=0

  if(associated(aV%iList%bf)) then

     if(present(stat)) then
	call List_clean(aV%iList,ier)
	if(ier/=0) stat=ier
     else
	call List_clean(aV%iList)
     endif

  endif

        ! Clean up REAL attribute list:

  if(associated(aV%rList%bf)) then

     if(present(stat)) then
	call List_clean(aV%rList,ier)
	if(ier/=0) stat=ier
     else
	call List_clean(aV%rList)
     endif

  endif

        ! Clean up INTEGER attributes:

  if(associated(aV%iAttr)) then

#ifdef MALL_ON
     call mall_co(size(transfer(aV%iAttr,(/1/)),myname_)
#endif

     deallocate(aV%iAttr,stat=ier)

     if(ier /= 0) then
	if(present(stat)) then
	   stat=ier
	else
	   call warn(myname_,'deallocate(aV%iAttr)',ier)
	endif
     endif

  endif ! if(associated(aV%iAttr))...

        ! Clean up REAL attributes:

  if(associated(aV%rAttr)) then

#ifdef MALL_ON
     call mall_co(size(transfer(aV%rAttr,(/1/)),myname_)
#endif

     deallocate(aV%rAttr,stat=ier)

     if(ier /= 0) then
	if(present(stat)) then
	   stat=ier
	else
	   call warn(myname_,'deallocate(aV%rAttr)',ier)
	endif
     endif

  endif ! if(associated(aV%rAttr))...


 end subroutine clean_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: lsize_ - Length of an AttrVect
!
! !DESCRIPTION:
! This function returns the number of elements, or {\em length} of the
! input {\tt AttrVect} argument {\tt aV}.  This function examines the
! length of the second dimension of the arrays {\tt aV\%iAttr(:,:)}
! and {\tt aV\%rAttr(:,:)}.  If neither {\tt aV\%iAttr(:,:)} nor
! {\tt aV\%rAttr(:,:)} are associated, then ${\tt lsize\_(aV)} = 0$.
! If {\tt aV\%iAttr(:,:)} is associated, but {\tt aV\%rAttr(:,:)} is
! not, then ${\tt lsize\_(aV)} = {\tt size(aV\%iAttr,2)}$. If
! {\tt aV\%iAttr(:,:)} is not associated, but {\tt aV\%rAttr(:,:)} is,
! then ${\tt lsize\_(aV)} = {\tt size(aV\%rAttr,2)}$. If both
! {\tt aV\%iAttr(:,:)} and {\tt aV\%rAttr(:,:)} are associated, the
! function {\tt lsize\_()} will do one of two things:  If
! ${\tt size(aV\%iAttr,2)} = {\tt size(aV\%rAttr,2)}$, this equal value
! will be returned.  If ${\tt size(aV\%iAttr,2)} \neq
! {\tt size(aV\%rAttr,2)}$, termination with an error message will occur.
!
! !INTERFACE:

 integer function lsize_(aV)

! !USES:

     use m_List,  only : List
     use m_List,  only : List_allocated => allocated

     use m_stdio, only : stderr
     use m_die

     implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect), intent(in) :: aV

! !REVISION HISTORY:
! 09Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 10Oct01 - J. Larson <larson@mcs.anl.gov> - made code more robust
!           to handle cases where the length of either aV%iAttr or
!           aV%rAttr is zero, but the other is positive.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::lsize_'
  integer :: iLength, rLength

	! One should try to avoid using this function on an undefined
	! or disassocated pointer.  However, it is understandable
	! that an undefined or disassocated pointer has a size 0, if
	! the associated() test sucesses.

  lsize_=0

  if(List_allocated(aV%iList) .and. associated(aV%iAttr)) then
     iLength = size(aV%iAttr,2)
  else
     iLength = 0
  endif

  if(List_allocated(aV%rList) .and. associated(aV%rAttr)) then
     rLength = size(aV%rAttr,2)
  else
     rLength = 0
  endif

  if(iLength /= rLength) then

     if((rLength > 0) .and. (iLength > 0)) then
	call die(myname_,'attribute array length mismatch', &
	     iLength-rLength)
     endif

     if((rLength > 0) .and. (iLength == 0)) then
	lsize_ = rLength
     endif

     if((iLength > 0) .and. (rLength == 0)) then
	lsize_ = iLength
     endif

  endif

  if(iLength == rLength) lsize_ = iLength

 end function lsize_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!        Math and Computer Science Division, Argonne National Laboratory
!BOP -------------------------------------------------------------------
!
! !IROUTINE: zero_ - Set AttrVect Field Data to Zero
!
! !DESCRIPTION:
! This routine sets all of the point values of the integer and real
! attributes of an the input/output {\tt AttrVect} argument {\tt aV}
! to zero.  The default action is to set the values of all the real and
! integer attributes to zero.  The user may prevent the zeroing of the
! real (integer) attributes invoking {\tt zero\_()} with the optional
! {\tt LOGICAL} argument {\tt zeroReals} ({\tt zeroInts}) set with value
! {\tt .FALSE.}
!
! !INTERFACE:

 subroutine zero_(aV, zeroReals, zeroInts)

! !USES:


     use m_die,only	: die
     use m_stdio,only	: stderr

     use m_List, only : List
     use m_List, only : List_allocated => allocated

     implicit none

! !INPUT PARAMETERS:

     logical, optional, intent(IN)    :: zeroReals
     logical, optional, intent(IN)    :: zeroInts

! !INPUT/OUTPUT PARAMETERS:
!
     type(AttrVect),    intent(INOUT) :: aV

! !REVISION HISTORY:
! 17May01 - R. Jacob <jacob@mcs.anl.gov> - initial prototype/code
! 15Oct01 - J. Larson <larson@mcs.anl.gov> - switched loop order
!           for cache optimization.
! 03Dec01 - E.T. Ong <eong@mcs.anl.gov> - eliminated looping method of
!           of zeroing. "Compiler assignment" of attrvect performs faster
!           on the IBM SP with mpxlf90 compiler.
! 05Jan10 - R. Jacob <jacob@mcs.anl.gov> - zeroing an uninitialized aV is no
!           longer a fatal error.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::zero_'

  logical myZeroReals, myZeroInts

  if(present(zeroReals)) then
     myZeroReals = zeroReals
  else
     myZeroReals = .TRUE.
  endif

  if(present(zeroInts)) then
     myZeroInts = zeroInts
  else
     myZeroInts = .TRUE.
  endif

!  if((.not. List_allocated(aV%iList)) .and. (.not. List_allocated(aV%rList))) then
!    write(stderr,'(2a)')myname_, &
!      'MCTERROR:  Trying to zero an uninitialized AttrVect'
!      call die(myname_)
!  endif

  if(myZeroInts) then ! zero out INTEGER attributes
     if(List_allocated(aV%iList)) then
        if(associated(aV%iAttr) .and. (nIAttr_(aV)>0)) then
!DIR$ COLLAPSE
           aV%iAttr=0
        endif
     endif
  endif

  if(myZeroReals) then ! zero out REAL attributes
     if(List_allocated(aV%rList)) then
        if(associated(aV%rAttr) .and. (nRAttr_(aV)>0)) then
!DIR$ COLLAPSE
           aV%rAttr=0._FP
        endif
     endif
  endif

 end subroutine zero_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: nIAttr_ - Return the Number of Integer Attributes
!
! !DESCRIPTION:
! This integer function returns the number of integer attributes
! present in the input {\tt AttrVect} argument {\tt aV}.
!
! !INTERFACE:

 integer function nIAttr_(aV)
!
! !USES:
!
      use m_List, only : nitem

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),intent(in) :: aV

! !REVISION HISTORY:
! 22Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 10Oct01 - J. Larson <larson@mcs.anl.gov> - made code more robust
!           by checking status of pointers in aV%iList
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::nIAttr_'

  if(associated(aV%iList%bf)) then
     nIAttr_ = nitem(aV%iList)
  else
     nIAttr_ = 0
  endif

 end function nIAttr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: nRAttr_ - Return the Number of Real Attributes
!
! !DESCRIPTION:
! This integer function returns the number of real attributes
! present in the input {\tt AttrVect} argument {\tt aV}.

! !INTERFACE:

 integer function nRAttr_(aV)
!
! !USES:
!
      use m_List, only : nitem

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),intent(in) :: aV

! !REVISION HISTORY:
! 22Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 10Oct01 - J. Larson <larson@mcs.anl.gov> - made code more robust
!           by checking status of pointers in aV%iList
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::nRAttr_'

  if(associated(aV%rList%bf)) then
     nRAttr_ = nitem(aV%rList)
  else
     nRAttr_ = 0
  endif

 end function nRAttr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: getIList_ - Retrieve the Name of a Numbered Integer Attribute
!
! !DESCRIPTION:
! This routine returns the name of the {\tt ith} integer attribute of
! the input {\tt AttrVect} argument {\tt aVect}.  The name is returned
! in the output {\tt String} argument {\tt item} (see the mpeu module
! {\tt m\_String} for more information regarding the {\tt String} type).
!
! !INTERFACE:

 subroutine getIList_(item, ith, aVect)
!
! !USES:
!
      use m_String, only : String
      use m_List,   only : get

      implicit none

! !INPUT PARAMETERS:
!
      integer,     intent(in)  :: ith
      type(AttrVect),intent(in) :: aVect

! !OUTPUT PARAMETERS:
!
      type(String),intent(out) :: item

! !REVISION HISTORY:
! 24Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::getIList_'

  call get(item, ith, aVect%iList)

 end subroutine getIList_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: getRList_ - Retrieve the Name of a Numbered Real Attribute
!
! !DESCRIPTION:
! This routine returns the name of the {\tt ith} real attribute of
! the input {\tt AttrVect} argument {\tt aVect}.  The name is returned
! in the output {\tt String} argument {\tt item} (see the mpeu module
! {\tt m\_String} for more information regarding the {\tt String} type).
!
! !INTERFACE:

 subroutine getRList_(item, ith, aVect)
!
! !USES:
!
      use m_String, only : String
      use m_List,   only : get

      implicit none

! !INPUT PARAMETERS:
!
      integer,        intent(in)  :: ith
      type(AttrVect), intent(in)  :: aVect

! !OUTPUT PARAMETERS:
!
      type(String),   intent(out) :: item

! !REVISION HISTORY:
! 24Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::getRList_'

  call get(item,ith,aVect%rList)

 end subroutine getRList_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: getIListToChar_ - Retrieve the Name of a Numbered Integer Attribute
!
! !DESCRIPTION:
! This routine returns the name of the {\tt ith} integer attribute of
! the input {\tt AttrVect} argument {\tt aVect}.  The name is returned
! in the function {\tt char} argument.
!
! !INTERFACE:

 function getIListToChar_(ith, aVect)
!
! !USES:
!
      use m_String, only : String
      use m_String, only : String_ToChar => ToChar
      use m_String, only : String_clean => clean
      use m_List,   only : get

      implicit none

! !INPUT PARAMETERS:
!
      integer,     intent(in)  :: ith
      type(AttrVect),intent(in) :: aVect

! !OUTPUT PARAMETERS:
!
      character(len=size(aVect%iList%bf,1)) :: getIListToChar_

! !REVISION HISTORY:
! 10Jan13 - T. Craig <tcraig@ucar.edu> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  type(String) :: item
  character(len=*),parameter :: myname_=myname//'::getIListToChar_'

  call get(item, ith, aVect%iList)
  getIListToChar_ = String_toChar(item)
  call String_clean(item)

 end function getIListToChar_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: getRListToChar_ - Retrieve the Name of a Numbered Integer Attribute
!
! !DESCRIPTION:
! This routine returns the name of the {\tt ith} integer attribute of
! the input {\tt AttrVect} argument {\tt aVect}.  The name is returned
! in the function {\tt char} argument.
!
! !INTERFACE:

 function getRListToChar_(ith, aVect)
!
! !USES:
!
      use m_String, only : String
      use m_String, only : String_ToChar => ToChar
      use m_String, only : String_clean => clean
      use m_List,   only : get

      implicit none

! !INPUT PARAMETERS:
!
      integer,     intent(in)  :: ith
      type(AttrVect),intent(in) :: aVect

! !OUTPUT PARAMETERS:
!
      character(len=size(aVect%rList%bf,1)) :: getRListToChar_

! !REVISION HISTORY:
! 10Jan13 - T. Craig <tcraig@ucar.edu> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  type(String) :: item
  character(len=*),parameter :: myname_=myname//'::getRListToChar_'

  call get(item, ith, aVect%rList)
  getRListToChar_ = String_toChar(item)
  call String_clean(item)

 end function getRListToChar_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: indexIA_ - Index an Integer Attribute
!
! !DESCRIPTION:
! This function returns an {\tt INTEGER}, corresponding to the location
! of an integer attribute within the input {\tt AttrVect} argument
! {\tt aV}.  For example, suppose {\tt aV} has the following attributes
! {\tt 'month'}, {\tt 'day'}, and {\tt 'year'}.  The array of integer
! values for the attribute {\tt 'day'}  is stored in
!% \begin{verbatim}
! {\tt aV\%iAttr(indexIA\_(aV,'day'),:)}.
!% \end{verbatim}
! If {\tt indexIA\_()} is unable to match {\tt item} to any of the integer
! attributes in {\tt aV}, the resulting value is zero which is equivalent
! to an error.  The optional input {\tt CHARACTER} arguments {\tt perrWith}
! and {\tt dieWith} control how such errors are handled.
! \begin{enumerate}
! \item if neither {\tt perrWith} nor {\tt dieWith} are present,
! {\tt indexIA\_()} terminates execution with an internally generated
! error message;
! \item if {\tt perrWith} is present, but {\tt dieWith} is not, an error
! message is written to {\tt stderr} incorporating user-supplied traceback
! information stored in the argument {\tt perrWith};
! \item if {\tt perrWith} is present, but {\tt dieWith} is not, and
! {\tt perrWith} is equal to ``quiet'', no error message is written.
! \item if {\tt dieWith} is present, execution terminates with an error
! message written to {\tt stderr} that incorporates user-supplied traceback
! information stored in the argument {\tt dieWith}; and
! \item if both {\tt perrWith} and {\tt dieWith} are present, execution
! terminates with an error message using {\tt dieWith}, and the argument
! {\tt perrWith} is ignored.
! \end{enumerate}
!
! !INTERFACE:

 integer function indexIA_(aV, item, perrWith, dieWith)
!
! !USES:
!
      use m_die,  only : die
      use m_stdio,only : stderr

      use m_String, only : String
      use m_String, only : String_init => init
      use m_String, only : String_clean => clean
      use m_String, only : String_ToChar => ToChar

      use m_List, only : index

      use m_TraceBack, only : GenTraceBackString

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),             intent(in) :: aV
      character(len=*),           intent(in) :: item
      character(len=*), optional, intent(in) :: perrWith
      character(len=*), optional, intent(in) :: dieWith

! !REVISION HISTORY:
! 27Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!  2Aug02 - J. Larson - Solidified error handling using perrWith/dieWith
!  1Jan05 - R. Jacob - add quiet option for error handling
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::indexIA_'

  type(String) :: myTrace

  if(present(dieWith)) then
     call GenTraceBackString(myTrace, dieWith, myname_)
  else
     if(present(perrWith)) then
	call GenTraceBackString(myTrace, perrWith, myname_)
     else
	call GenTraceBackString(myTrace, myname_)
     endif
  endif

  indexIA_=index(aV%iList,item)

  if(indexIA_==0) then ! The attribute was not found!
       ! As per the prologue, decide how to handle this error
     if(present(perrWith) .and. (.not. present(dieWith))) then
       if (trim(perrWith).eq.'quiet') then
        ! do nothing
       else
        write(stderr,'(5a)') myname_, &
             ':: ERROR--attribute not found: "',trim(item),'" ', &
             'Traceback:  ',String_ToChar(myTrace)
       endif
     else ! Shutdown
	write(stderr,'(5a)') myname_, &
	     ':: FATAL--attribute not found: "',trim(item),'" ', &
	     'Traceback:  ',String_ToChar(myTrace)
	call die(myname_)
     endif
  endif

  call String_clean(myTrace)

 end function indexIA_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math and Computer Science Division, Argonne National Laboratory  !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: indexRA_ - Index a Real Attribute
!
! !DESCRIPTION:
! This function returns an {\tt INTEGER}, corresponding to the location
! of a real attribute within the input {\tt AttrVect} argument
! {\tt aV}.  For example, suppose {\tt aV} has the following attributes
! {\tt 'latitude'}, {\tt 'longitude'}, and {\tt 'pressure'}.  The array
! of real values for the attribute {\tt 'longitude'}  is stored in
!% \begin{verbatim}
! {\tt aV\%iAttr(indexRA\_(aV,'longitude'),:)}.
!% \end{verbatim}
! If {\tt indexRA\_()} is unable to match {\tt item} to any of the real
! attributes in {\tt aV}, the resulting value is zero which is equivalent
! to an error.  The optional input {\tt CHARACTER} arguments {\tt perrWith}
! and {\tt dieWith} control how such errors are handled.
! \begin{enumerate}
! \item if neither {\tt perrWith} nor {\tt dieWith} are present,
! {\tt indexRA\_()} terminates execution with an internally generated
! error message;
! \item if {\tt perrWith} is present, but {\tt dieWith} is not, an error
! message is written to {\tt stderr} incorporating user-supplied traceback
! information stored in the argument {\tt perrWith};
! \item if {\tt perrWith} is present, but {\tt dieWith} is not, and
! {\tt perrWith} is equal to ``quiet'', no error message is written.
! \item if {\tt dieWith} is present, execution terminates with an error
! message written to {\tt stderr} that incorporates user-supplied traceback
! information stored in the argument {\tt dieWith}; and
! \item if both {\tt perrWith} and {\tt dieWith} are present, execution
! terminates with an error message using {\tt dieWith}, and the argument
! {\tt perrWith} is ignored.
! \end{enumerate}
!
! !INTERFACE:

 integer function indexRA_(aV, item, perrWith, dieWith)
!
! !USES:
!
      use m_die,  only : die
      use m_stdio,only : stderr

      use m_List, only : index

      use m_String, only : String
      use m_String, only : String_init => init
      use m_String, only : String_clean => clean
      use m_String, only : String_ToChar => ToChar

      use m_TraceBack, only : GenTraceBackString

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),             intent(in) :: aV
      character(len=*),           intent(in) :: item
      character(len=*), optional, intent(in) :: perrWith
      character(len=*), optional, intent(in) :: dieWith

! !REVISION HISTORY:
! 27Apr98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!  2Aug02 - J. Larson - Solidified error handling using perrWith/dieWith
! 18Jan05 - R. Jacob - add quiet option for error handling
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::indexRA_'

  type(String) :: myTrace

  if(present(dieWith)) then ! Append onto TraceBack
     call GenTraceBackString(myTrace, dieWith, myname_)
  else
     if(present(perrWith)) then ! Append onto TraceBack
	call GenTraceBackString(myTrace, perrWith, myname_)
     else ! Start a TraceBackString
	call GenTraceBackString(myTrace, myname_)
     endif
  endif

  indexRA_=index(aV%rList,item)

  if(indexRA_==0) then ! The attribute was not found!
       ! As per the prologue, decide how to handle this error
     if(present(perrWith) .and. (.not. present(dieWith))) then
       if (trim(perrWith).eq.'quiet') then
        ! do nothing
       else
	write(stderr,'(5a)') myname_, &
	     ':: ERROR--attribute not found: "',trim(item),'" ', &
	     'Traceback:  ',String_ToChar(myTrace)
       endif
     else ! Shutdown if dieWith or no arguments present
	write(stderr,'(5a)') myname_, &
	     ':: FATAL--attribute not found: "',trim(item),'" ', &
	     'Traceback:  ',String_ToChar(myTrace)
	call die(myname_)
     endif
  endif

  call String_clean(myTrace)

 end function indexRA_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       DOE/ANL Mathematics and Computer Science Division              !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: appendIAttr_ - Append one or more attributes onto the INTEGER part of an AttrVect.
!
! !DESCRIPTION:  This routine takes an input {\tt AttrVect} argument
! {\tt aV}, and an input character string {\tt rList} and Appends {\tt rList}
! to the INTEGER part of {\tt aV}. The success (failure) of this operation is
! signified by a zero (nonzero) value for the optional {\tt INTEGER}
! output argument {\tt status}.
!
! !INTERFACE:

 subroutine appendIAttr_(aV, iList, status)
!
! !USES:
!
      use m_List,   only : List_init => init
      use m_List,   only : List_append => append
      use m_List,   only : List_clean => clean
      use m_List,   only : List_nullify => nullify
      use m_List,   only : List_allocated => allocated
      use m_List,   only : List_copy => copy
      use m_List,   only : List
      use m_die
      use m_stdio

      implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),intent(inout)  :: aV

! !INPUT PARAMETERS:
!
      character(len=*), intent(in)  :: iList

! !OUTPUT PARAMETERS:
!
      integer,optional,intent(out)  :: status

! !REVISION HISTORY:
! 08Jul03 - R. Jacob <jacob@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::appendIAttr_'

  type(List) :: avRList,avIList        ! placeholders for the aV attributes
  type(List) :: addIlist               ! for the input string
  type(AttrVect) :: tempaV             ! placeholder for aV data.
  integer :: locsize                   ! size of aV
  integer :: rlstatus,cstatus           ! status flags
  integer :: ilstatus

  if(present(status)) status = 0

  call List_nullify(avIList)
  call List_nullify(avRList)

! save the local size and current int and real attributes
  locsize = lsize_(aV)
  call exportRList_(aV,avRList,rlstatus)
  call exportIList_(aV,avIList,ilstatus)

! create and fill a temporary AttrVect to hold any data currently in the aV
  call initv_(tempaV,aV,lsize=locsize)
  call Copy_(aV,tempaV)

! create a List with the new attributes
  call List_init(addIlist,iList)

! append addIlist to current avIList if it has attributes.
  if(List_allocated(avIList)) then
    call List_append(avIList,addIlist)
! copy addIlist to avIList
  else
    call List_copy(avIList,addIlist)
  endif

! now delete the input aV and recreate it
  call clean_(aV,cstatus)
  call initl_(aV,avIList,avRList,locsize)

! copy back the data
  call Copy_(tempaV,aV)

! clean up.
  call List_clean(avRList,cstatus)

  call clean_(tempaV,cstatus)
  call List_clean(addIlist,cstatus)
  call List_clean(avIList,cstatus)

  if(present(status)) status = cstatus

 end subroutine appendIAttr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       DOE/ANL Mathematics and Computer Science Division              !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: appendRAttr_ - Append one or more attributes onto the REAL part of an AttrVect.
!
! !DESCRIPTION:  This routine takes an input {\tt AttrVect} argument
! {\tt aV}, and an input character string {\tt rList} and Appends {\tt rList}
! to the REAL part of {\tt aV}. The success (failure) of this operation is
! signified by a zero (nonzero) value for the optional {\tt INTEGER}
! output argument {\tt status}.
!
! !INTERFACE:

 subroutine appendRAttr_(aV, rList, status)
!
! !USES:
!
      use m_List,   only : List_init => init
      use m_List,   only : List_append => append
      use m_List,   only : List_clean => clean
      use m_List,   only : List_nullify => nullify
      use m_List,   only : List_allocated => allocated
      use m_List,   only : List_copy => copy
      use m_List,   only : List
      use m_die
      use m_stdio

      implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),intent(inout)  :: aV

! !INPUT PARAMETERS:
!
      character(len=*), intent(in)  :: rList

! !OUTPUT PARAMETERS:
!
      integer,optional,intent(out)  :: status

! !REVISION HISTORY:
! 04Jun03 - R. Jacob <jacob@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::appendRAttr_'

  type(List) :: avRList,avIList        ! placeholders for the aV attributes
  type(List) :: addRlist               ! for the input string
  type(AttrVect) :: tempaV             ! placeholder for aV data.
  integer :: locsize                   ! size of aV
  integer :: rlstatus,cstatus           ! status flags
  integer :: ilstatus

  if(present(status)) status = 0

  call List_nullify(avIList)
  call List_nullify(avRList)

! save the local size and current int and real attributes
  locsize = lsize_(aV)
  call exportRList_(aV,avRList,rlstatus)
  call exportIList_(aV,avIList,ilstatus)

! create and fill a temporary AttrVect to hold any data currently in the aV
  call initv_(tempaV,aV,lsize=locsize)
  call Copy_(aV,tempaV)

! create a List with the new attributes
  call List_init(addRlist,rList)

! append addRlist to current avRList if it has attributes.
  if(List_allocated(avRList)) then
    call List_append(avRList,addRlist)
! copy addRlist to avRList
  else
    call List_copy(avRList,addRlist)
  endif

! now delete the input aV and recreate it
  call clean_(aV,cstatus)
  call initl_(aV,avIList,avRList,locsize)

! copy back the data
  call Copy_(tempaV,aV)

! clean up.
  call List_clean(avIList,cstatus)

  call clean_(tempaV,cstatus)
  call List_clean(addRlist,cstatus)
  call List_clean(avRList,cstatus)

  if(present(status)) status = cstatus

 end subroutine appendRAttr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: exportIList_ - Return INTEGER Attribute List
!
! !DESCRIPTION:
! This routine extracts from the input {\tt AttrVect} argument {\tt aV}
! the integer attribute list, and returns it as the {\tt List} output
! argument {\tt outIList}.  The success (failure) of this operation is
! signified by a zero (nonzero) value for the optional {\tt INTEGER}
! output argument {\tt status}.
!
! {\bf N.B.:}  This routine returns an allocated {\tt List} data
! structure ({\tt outIList}).  The user is responsible for deallocating
! this structure by invoking {\tt List\_clean()} (see the module
! {\tt m\_List} for details) once it is no longer needed.  Failure to
! do so will result in a memory leak.
!
! !INTERFACE:

 subroutine exportIList_(aV, outIList, status)

!
! !USES:
!
      use m_die ,  only : die
      use m_stdio, only : stderr

      use m_List,  only : List
      use m_List,  only : List_allocated => allocated
      use m_List,  only : List_copy => copy
      use m_List,  only : List_nullify => nullify

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),             intent(in)  :: aV

! !OUTPUT PARAMETERS:

      type(List),                 intent(out) :: outIList
      integer,          optional, intent(out) :: status

! !REVISION HISTORY:
! 14Dec01 - J.W. Larson <larson@mcs.anl.gov> - initial prototype.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::exportIList_'

       ! Initialize status flag (if present) to success value of zero.

  if(present(status)) status = 0

  if(List_allocated(aV%iList)) then
     call List_copy(outIList, aV%iList)
  else
     call List_nullify(outIList)
     if(present(status)) then
	status = 1
     else
	call die(myname_)
     endif
  endif

 end subroutine exportIList_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: exportRList_ - Return REAL attribute List
!
! !DESCRIPTION:
! This routine extracts from the input {\tt AttrVect} argument {\tt aV}
! the real attribute list, and returns it as the {\tt List} output
! argument {\tt outRList}.  The success (failure) of this operation is
! signified by a zero (nonzero) value for the optional {\tt INTEGER}
! output argument {\tt status}.
!
! {\bf N.B.:}  This routine returns an allocated {\tt List} data
! structure ({\tt outRList}).  The user is responsible for deallocating
! this structure by invoking {\tt List\_clean()} (see the module
! {\tt m\_List} for details) once it is no longer needed.  Failure to
! do so will result in a memory leak.
!
! !INTERFACE:

 subroutine exportRList_(aV, outRList, status)

!
! !USES:
!
      use m_die ,  only : die
      use m_stdio, only : stderr

      use m_List,  only : List
      use m_List,  only : List_allocated => allocated
      use m_List,  only : List_copy => copy
      use m_List,  only : List_nullify => nullify

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),           intent(in)  :: aV

! !OUTPUT PARAMETERS:

      type(List),               intent(out) :: outRList
      integer,        optional, intent(out) :: status

! !REVISION HISTORY:
! 14Dec01 - J.W. Larson <larson@mcs.anl.gov> - initial prototype.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::exportRList_'

       ! Initialize status flag (if present) to success value of zero.

  if(present(status)) status = 0

  if(List_allocated(aV%rList)) then
     call List_copy(outRList, aV%rList)
  else
     call List_nullify(outRList)
     if(present(status)) then
	status = 1
     else
	call die(myname_)
     endif
  endif

 end subroutine exportRList_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: exportIListToChar_ - Return AttrVect\%iList as CHARACTER
!
! !DESCRIPTION:
! This routine extracts from the input {\tt AttrVect} argument {\tt aV}
! the integer attribute list (see the mpeu module {\tt m\_List} for more
! information regarding the {\tt List} type), and returns it as a
! {\tt CHARACTER} suitable for printing.  An example of its usage is
! \begin{verbatim}
!           write(stdout,'(1a)') exportIListToChar_(aV)
! \end{verbatim}
! which writes the contents of {\tt aV\%iList\%bf} to the Fortran device
! {\tt stdout}.
!
! !INTERFACE:

 function exportIListToChar_(aV)

!
! !USES:
!
      use m_die ,  only : die
      use m_stdio, only : stderr

      use m_List,  only : List
      use m_List,  only : List_allocated => allocated
      use m_List,  only : List_copy => copy
      use m_List,  only : List_exportToChar => exportToChar
      use m_List,  only : List_clean => clean

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),       intent(in) :: aV

! !OUTPUT PARAMETERS:

      character(len=size(aV%iList%bf,1)) :: exportIListToChar_

! !REVISION HISTORY:
! 13Feb02 - J.W. Larson <larson@mcs.anl.gov> - initial prototype.
! 05Jun03 - R. Jacob <jacob@mcs.anl.gov> - return a blank instead of dying
!           to avoid I/O errors when this function is used in a write statement.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::exportIListToChar_'

  ! The following extraneous list copy avoids a bug in the
  ! SGI MIPSpro Fortran 90 compiler version 7.30. and the
  ! Sun Fortran 90 Workshop compiler 5.0. If this line is removed,
  ! the following error will occur during compile time:

  ! Signal: Segmentation fault in IR->WHIRL Conversion phase.
  ! "m_AttrVect.F90": Error: Signal Segmentation fault in phase IR->WHIRL
  ! Conversion -- processing aborted
  ! f90 ERROR:  /opt/MIPSpro/73/usr/lib32/cmplrs/mfef90 died due to signal 4
  ! f90 ERROR:  core dumped
  ! *** Error code 32 (bu21)

  type(List) :: iListCopy

       ! Extract the INTEGER attribute list to a character:

  if(List_allocated(aV%iList)) then
     call List_copy(iListCopy,aV%iList)
     exportIListToChar_ = List_exportToChar(iListCopy)
     call List_clean(iListCopy)
  else
     exportIListToChar_ = ''
  endif

 end function exportIListToChar_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: exportRListToChar_ - Return AttrVect\%rList as CHARACTER
!
! !DESCRIPTION:
! This routine extracts from the input {\tt AttrVect} argument {\tt aV}
! the real attribute list (see the mpeu module {\tt m\_List} for more
! information regarding the {\tt List} type), and returns it as a
! {\tt CHARACTER} suitable for printing.  An example of its usage is
! \begin{verbatim}
!           write(stdout,'(1a)') exportRListToChar_(aV)
! \end{verbatim}
! which writes the contents of {\tt aV\%rList\%bf} to the Fortran device
! {\tt stdout}.
!
! !INTERFACE:

 function exportRListToChar_(aV)

!
! !USES:
!
      use m_die ,  only : die
      use m_stdio, only : stderr

      use m_List,  only : List
      use m_List,  only : List_allocated => allocated
      use m_List,  only : List_copy => copy
      use m_List,  only : List_exportToChar => exportToChar
      use m_List,  only : List_clean => clean

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),       intent(in) :: aV

! !OUTPUT PARAMETERS:

      character(len=size(aV%rList%bf,1)) :: exportRListToChar_

! !REVISION HISTORY:
! 13Feb02 - J.W. Larson <larson@mcs.anl.gov> - initial prototype.
! 05Jun03 - R. Jacob <jacob@mcs.anl.gov> - return a blank instead of dying
!           to avoid I/O errors when this function is used in a write statement.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::exportRListToChar_'

  ! The following extraneous list copy avoids a bug in the
  ! SGI MIPSpro Fortran 90 compiler version 7.30. and the
  ! Sun Fortran 90 Workshop compiler 5.0. If this line is removed,
  ! the following error will occur during compile time:

  ! Signal: Segmentation fault in IR->WHIRL Conversion phase.
  ! "m_AttrVect.F90": Error: Signal Segmentation fault in phase IR->WHIRL
  ! Conversion -- processing aborted
  ! f90 ERROR:  /opt/MIPSpro/73/usr/lib32/cmplrs/mfef90 died due to signal 4
  ! f90 ERROR:  core dumped
  ! *** Error code 32 (bu21)

  type(List) :: rListCopy

       ! Extract the REAL attribute list to a character:

  if(List_allocated(aV%rList)) then
     call List_copy(rListCopy,aV%rList)
     exportRListToChar_ = List_exportToChar(rListCopy)
     call List_clean(rListCopy)
  else
     exportRListToChar_ = ''
  endif

 end function exportRListToChar_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: exportIAttr_ - Return INTEGER Attribute as a Vector
!
! !DESCRIPTION:
! This routine extracts from the input {\tt AttrVect} argument {\tt aV}
! the integer attribute corresponding to the tag defined in the input
! {\tt CHARACTER} argument {\tt AttrTag}, and returns it in the
! {\tt INTEGER} output array {\tt outVect}, and its length in the output
! {\tt INTEGER} argument {\tt lsize}.  The optional input {\tt CHARACTER}
! arguments {\tt perrWith} and {\tt dieWith} control how errors are
! handled.
! \begin{enumerate}
! \item if neither {\tt perrWith} nor {\tt dieWith} are present,
! {\tt exportIAttr\_()} terminates execution with an internally generated
! error message;
! \item if {\tt perrWith} is present, but {\tt dieWith} is not, an error
! message is written to {\tt stderr} incorporating user-supplied traceback
! information stored in the argument {\tt perrWith};
! \item if {\tt dieWith} is present, execution terminates with an error
! message written to {\tt stderr} that incorporates user-supplied traceback
! information stored in the argument {\tt dieWith}; and
! \item if both {\tt perrWith} and {\tt dieWith} are present, execution
! terminates with an error message using {\tt dieWith}, and the argument
! {\tt perrWith} is ignored.
! \end{enumerate}
!
! {\bf N.B.:}  This routine will fail if the {\tt AttrTag} is not in
! the {\tt AttrVect} {\tt List} component {\tt aV\%iList}.
!
! {\bf N.B.:}  The flexibility of this routine regarding the pointer
! association status of the output argument {\tt outVect} means the
! user must invoke this routine with care.  If the user wishes this
! routine to fill a pre-allocated array, then obviously this array
! must be allocated prior to calling this routine.  If the user wishes
! that the routine {\em create} the output argument array {\tt outVect},
! then the user must ensure this pointer is not allocated (i.e. the user
! must nullify this pointer) before this routine is invoked.
!
! {\bf N.B.:}  If the user has relied on this routine to allocate memory
! associated with the pointer {\tt outVect}, then the user is responsible
! for deallocating this array once it is no longer needed.  Failure to
! do so will result in a memory leak.
!
! !INTERFACE:

 subroutine exportIAttr_(aV, AttrTag, outVect, lsize, perrWith, dieWith)

!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr

      use m_String, only : String
      use m_String, only : String_init => init
      use m_String, only : String_clean => clean
      use m_String, only : String_ToChar => ToChar

      use m_TraceBack, only : GenTraceBackString

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),             intent(in) :: aV
      character(len=*),           intent(in) :: AttrTag
      character(len=*), optional, intent(in) :: perrWith
      character(len=*), optional, intent(in) :: dieWith

! !OUTPUT PARAMETERS:

      integer,      dimension(:), pointer     :: outVect
      integer,          optional, intent(out) :: lsize

! !REVISION HISTORY:
! 19Oct01 - J.W. Larson <larson@mcs.anl.gov> - initial (slow)
!           prototype.
!  6May02 - J.W. Larson <larson@mcs.anl.gov> - added capability
!           to work with pre-allocated outVect.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::exportIAttr_'

  integer :: index, ierr, n, myLsize
  type(String) :: myTrace

  if(present(dieWith)) then ! Append onto TraceBack
     call GenTraceBackString(myTrace, dieWith, myname_)
  else
     if(present(perrWith)) then ! Append onto TraceBack
	call GenTraceBackString(myTrace, perrWith, myname_)
     else ! Start a TraceBackString
	call GenTraceBackString(myTrace, myname_)
     endif
  endif

       ! Index the attribute we wish to extract:

  index = indexIA_(aV, attrTag, dieWith=String_ToChar(myTrace))

       ! Determine the number of data points:

  myLsize = lsize_(aV)

       ! Allocate space for outVect (if it is not already dimensioned)

  if(associated(outVect)) then ! check the size of outVect
     if(size(outVect) < myLsize) then
	write(stderr,'(3a,i8,a,i8)') myname_, &
	    ':: ERROR length of output array outVect ', &
	    ' less than length of aV.  size(outVect)=',size(outVect), &
	    ', length of aV=',myLsize
	write(stderr,'(2a)') 'Traceback:  ',String_ToChar(myTrace)
	call die(myname_)
     endif
  else ! allocate space for outVect
     allocate(outVect(myLsize), stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: Error - allocate(outVect(...) failed. ierr = ',ierr
	write(stderr,'(2a)') 'Traceback:  ',String_ToChar(myTrace)
	call die(myname_)
     endif
  endif

       ! Copy the attribute data into outVect

!$OMP PARALLEL DO PRIVATE(n)
  do n=1,myLsize
     outVect(n) = aV%iAttr(index,n)
  end do

  ! return optional output argument lsize:
  if(present(lsize)) lsize = myLsize

  call String_clean(myTrace)

 end subroutine exportIAttr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: exportRAttrSP_ - Return REAL Attribute as a Pointer to Array
!
! !DESCRIPTION:
! This routine extracts from the input {\tt AttrVect} argument {\tt aV}
! the real attribute corresponding to the tag defined in the input
! {\tt CHARACTER} argument {\tt AttrTag}, and returns it in the
! {\tt REAL} output array {\tt outVect}, and its length in the output
! {\tt INTEGER} argument {\tt lsize}.  The optional input {\tt CHARACTER}
! arguments {\tt perrWith} and {\tt dieWith} control how errors are
! handled.
! \begin{enumerate}
! \item if neither {\tt perrWith} nor {\tt dieWith} are present,
! {\tt exportRAttr\_()} terminates execution with an internally generated
! error message;
! \item if {\tt perrWith} is present, but {\tt dieWith} is not, an error
! message is written to {\tt stderr} incorporating user-supplied traceback
! information stored in the argument {\tt perrWith};
! \item if {\tt dieWith} is present, execution terminates with an error
! message written to {\tt stderr} that incorporates user-supplied traceback
! information stored in the argument {\tt dieWith}; and
! \item if both {\tt perrWith} and {\tt dieWith} are present, execution
! terminates with an error message using {\tt dieWith}, and the argument
! {\tt perrWith} is ignored.
! \end{enumerate}
!
! {\bf N.B.:}  This routine will fail if the {\tt AttrTag} is not in
! the {\tt AttrVect} {\tt List} component {\tt aV\%iList}.
!
! {\bf N.B.:}  The flexibility of this routine regarding the pointer
! association status of the output argument {\tt outVect} means the
! user must invoke this routine with care.  If the user wishes this
! routine to fill a pre-allocated array, then obviously this array
! must be allocated prior to calling this routine.  If the user wishes
! that the routine {\em create} the output argument array {\tt outVect},
! then the user must ensure this pointer is not allocated (i.e. the user
! must nullify this pointer) before this routine is invoked.
!
! {\bf N.B.:}  If the user has relied on this routine to allocate memory
! associated with the pointer {\tt outVect}, then the user is responsible
! for deallocating this array once it is no longer needed.  Failure to
! do so will result in a memory leak.
!
! !INTERFACE:

 subroutine exportRAttrSP_(aV, AttrTag, outVect, lsize, perrWith, dieWith)

!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr


      use m_String, only : String
      use m_String, only : String_init => init
      use m_String, only : String_clean => clean
      use m_String, only : String_ToChar => ToChar

      use m_TraceBack, only : GenTraceBackString

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),             intent(in) :: aV
      character(len=*),           intent(in) :: AttrTag
      character(len=*), optional, intent(in) :: perrWith
      character(len=*), optional, intent(in) :: dieWith

! !OUTPUT PARAMETERS:

      real(SP),        dimension(:),  pointer     :: outVect
      integer,          optional,     intent(out) :: lsize

! !REVISION HISTORY:
! 19Oct01 - J.W. Larson <larson@mcs.anl.gov> - initial (slow)
!           prototype.
!  6May02 - J.W. Larson <larson@mcs.anl.gov> - added capability
!           to work with pre-allocated outVect.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::exportRAttrSP_'

  integer :: index, ierr, n, myLsize
  type(String) :: myTrace

  if(present(dieWith)) then ! Append onto TraceBack
     call GenTraceBackString(myTrace, dieWith, myname_)
  else
     if(present(perrWith)) then ! Append onto TraceBack
	call GenTraceBackString(myTrace, perrWith, myname_)
     else ! Start a TraceBackString
	call GenTraceBackString(myTrace, myname_)
     endif
  endif

       ! Index the attribute we wish to extract:

  index = indexRA_(aV, attrTag, dieWith=String_ToChar(myTrace))

       ! Determine the number of data points:

  myLsize = lsize_(aV)

       ! Allocate space for outVect (if it is not already dimensioned)

  if(associated(outVect)) then ! check the size of outVect
     if(size(outVect) < myLsize) then
	write(stderr,'(3a,i8,a,i8)') myname_, &
	    ':: ERROR length of output array outVect ', &
	    ' less than length of aV.  size(outVect)=',size(outVect), &
	    ', length of aV=',myLsize
	write(stderr,'(2a)') 'Traceback:  ',String_ToChar(myTrace)
	call die(myname_)
     endif
  else ! allocate space for outVect
     allocate(outVect(myLsize), stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: Error - allocate(outVect(...) failed. ierr = ',ierr
	write(stderr,'(2a)') 'Traceback:  ',String_ToChar(myTrace)
	call die(myname_)
     endif
  endif

       ! Copy the attribute data into outVect

!$OMP PARALLEL DO PRIVATE(n)
  do n=1,myLsize
     outVect(n) = aV%rAttr(index,n)
  end do

  call String_clean(myTrace)

  ! return optional argument lsize
  if(present(lsize)) lsize = myLsize

 end subroutine exportRAttrSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
! ----------------------------------------------------------------------
!
! !IROUTINE: exportRAttrDP_ - Return REAL Attribute as a Pointer to Array
!
! !DESCRIPTION:
! Double precision version of exportRAttrSP_
!
! !INTERFACE:

 subroutine exportRAttrDP_(aV, AttrTag, outVect, lsize, perrWith, dieWith)

!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr


      use m_String, only : String
      use m_String, only : String_init => init
      use m_String, only : String_clean => clean
      use m_String, only : String_ToChar => ToChar

      use m_TraceBack, only : GenTraceBackString

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),             intent(in) :: aV
      character(len=*),           intent(in) :: AttrTag
      character(len=*), optional, intent(in) :: perrWith
      character(len=*), optional, intent(in) :: dieWith

! !OUTPUT PARAMETERS:

      real(DP),    dimension(:),  pointer     :: outVect
      integer,          optional, intent(out) :: lsize

! !REVISION HISTORY:
! 19Oct01 - J.W. Larson <larson@mcs.anl.gov> - initial (slow)
!           prototype.
!  6May02 - J.W. Larson <larson@mcs.anl.gov> - added capability
!           to work with pre-allocated outVect.
!
! ______________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::exportRAttrDP_'

  integer :: index, ierr, n, myLsize
  type(String) :: myTrace

  if(present(dieWith)) then ! Append onto TraceBack
     call GenTraceBackString(myTrace, dieWith, myname_)
  else
     if(present(perrWith)) then ! Append onto TraceBack
	call GenTraceBackString(myTrace, perrWith, myname_)
     else ! Start a TraceBackString
	call GenTraceBackString(myTrace, myname_)
     endif
  endif

       ! Index the attribute we wish to extract:

  index = indexRA_(aV, attrTag, dieWith=String_ToChar(myTrace))

       ! Determine the number of data points:

  myLsize = lsize_(aV)

       ! Allocate space for outVect (if it is not already dimensioned)

  if(associated(outVect)) then ! check the size of outVect
     if(size(outVect) < myLsize) then
	write(stderr,'(3a,i8,a,i8)') myname_, &
	    ':: ERROR length of output array outVect ', &
	    ' less than length of aV.  size(outVect)=',size(outVect), &
	    ', length of aV=',myLsize
	write(stderr,'(2a)') 'Traceback:  ',String_ToChar(myTrace)
	call die(myname_)
     endif
  else ! allocate space for outVect
     allocate(outVect(myLsize), stat=ierr)
     if(ierr /= 0) then
	write(stderr,'(2a,i8)') myname_, &
	     ':: Error - allocate(outVect(...) failed. ierr = ',ierr
	write(stderr,'(2a)') 'Traceback:  ',String_ToChar(myTrace)
	call die(myname_)
     endif
  endif

       ! Copy the attribute data into outVect

!$OMP PARALLEL DO PRIVATE(n)
  do n=1,myLsize
     outVect(n) = aV%rAttr(index,n)
  end do

  call String_clean(myTrace)

  ! return optional argument lsize
  if(present(lsize)) lsize = myLsize

 end subroutine exportRAttrDP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: importIAttr_ - Import INTEGER Vector as an Attribute
!
! !DESCRIPTION:
! This routine imports into the input/output {\tt AttrVect} argument
! {\tt aV} the integer attribute corresponding to the tag defined in the
! input {\tt CHARACTER} argument {\tt AttrTag}.  The data to be imported
! is provided in the {\tt INTEGER} input array {\tt inVect}, and the
! number of entries to be imported in the optional input {\tt INTEGER}
! argument {\tt lsize}.
!
! {\bf N.B.:}  This routine will fail if the {\tt AttrTag} is not in
! the {\tt AttrVect} {\tt List} component {\tt aV\%iList}.
!
! !INTERFACE:

 subroutine importIAttr_(aV, AttrTag, inVect, lsize)
!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr

      implicit none

! !INPUT PARAMETERS:

      character(len=*),       intent(in)    :: AttrTag
      integer,  dimension(:), pointer       :: inVect
      integer,  optional,     intent(in)    :: lsize

! !INPUT/OUTPUT PARAMETERS:

      type(AttrVect),         intent(inout) :: aV

! !REVISION HISTORY:
! 19Oct01 - J.W. Larson <larson@mcs.anl.gov> - initial (slow)
!           prototype.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::importIAttr_'

  integer :: index, aVsize, ierr, n, mysize

       ! Index the attribute we wish to extract:

  index = indexIA_(aV, attrTag)

       ! Determine the number of data points:

  aVsize = lsize_(aV)

       ! Check input array size vs. lsize_(aV):

  if(present(lsize)) then
     if(aVsize < lsize) then
	write(stderr,'(3a,i8,a,i8)') myname_, &
	               ':: ERROR--attempt to import too many entries ', &
                       'into AttrVect aV.  AttrVect_lsize(aV)=',aVsize, &
                       ', number of entries to be imported=',lsize
	call die(myname_)
     endif
     mysize=lsize
  else
     if(aVsize < size(inVect)) then
	write(stderr,'(3a,i8,a,i8)') myname_, &
	               ':: ERROR--attempt to import too many entries ', &
                       'into AttrVect aV.  AttrVect_lsize(aV)=',aVsize, &
                       ' , number of entries to be imported=',size(inVect)
	call die(myname_)
     endif
     mysize = aVsize
  endif

       ! Copy the data from inVect to its attribute slot:

!$OMP PARALLEL DO PRIVATE(n)
  do n=1,mysize
     aV%iAttr(index,n) = inVect(n)
  end do

 end subroutine importIAttr_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: importRAttrSP_ - Import REAL Vector as an Attribute
!
! !DESCRIPTION:
! This routine imports into the input/output {\tt AttrVect} argument
! {\tt aV} the real attribute corresponding to the tag defined in the
! input {\tt CHARACTER} argument {\tt AttrTag}.  The data to be imported
! is provided in the {\tt REAL} input array {\tt inVect}, and its
! length in the optional input {\tt INTEGER} argument {\tt lsize}.
!
! {\bf N.B.:}  This routine will fail if the {\tt AttrTag} is not in
! the {\tt AttrVect} {\tt List} component {\tt aV\%rList}.
!
! !INTERFACE:

 subroutine importRAttrSP_(aV, AttrTag, inVect, lsize)
!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr

      implicit none

! !INPUT PARAMETERS:

      character(len=*),   intent(in)    :: AttrTag
      real(SP), dimension(:), pointer   :: inVect
      integer, optional,  intent(in)    :: lsize

! !INPUT/OUTPUT PARAMETERS:

      type(AttrVect),     intent(inout) :: aV



! !REVISION HISTORY:
! 19Oct01 - J.W. Larson <larson@mcs.anl.gov> - initial (slow)
!           prototype.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::importRAttrSP_'

  integer :: index, aVsize, ierr, n, mysize

       ! Index the attribute we wish to extract:

  index = indexRA_(aV, attrTag)

       ! Determine the number of data points:

  aVsize = lsize_(aV)

       ! Check input array size vs. lsize_(aV):

  if(present(lsize)) then
     if(aVsize < lsize) then
	write(stderr,'(3a,i8,a,i8)') myname_, &
	               ':: ERROR--attempt to import too many entries ', &
                       'into AttrVect aV.  AttrVect_lsize(aV)=',aVsize, &
                       ', number of entries to be imported=',lsize
	call die(myname_)
     endif
     mysize=lsize
  else
     if(aVsize < size(inVect)) then
	write(stderr,'(3a,i8,a,i8)') myname_, &
	               ':: ERROR--attempt to import too many entries ', &
                       'into AttrVect aV.  AttrVect_lsize(aV)=',aVsize, &
                       ' , number of entries to be imported=',size(inVect)
	call die(myname_)
     endif
     mysize=aVsize
  endif

       ! Copy the attribute data into outVect

!$OMP PARALLEL DO PRIVATE(n)
  do n=1,mysize
     aV%rAttr(index,n) = inVect(n)
  end do

 end subroutine importRAttrSP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
! ----------------------------------------------------------------------
!
! !IROUTINE: importRAttrDP_ - Import REAL Vector as an Attribute
!
! !DESCRIPTION:
! Double precision version of importRAttrSP_
!
! !INTERFACE:

 subroutine importRAttrDP_(aV, AttrTag, inVect, lsize)
!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr

      implicit none

! !INPUT PARAMETERS:

      character(len=*),   intent(in)    :: AttrTag
      real(DP), dimension(:), pointer   :: inVect
      integer, optional,  intent(in)    :: lsize

! !INPUT/OUTPUT PARAMETERS:

      type(AttrVect),     intent(inout) :: aV



! !REVISION HISTORY:
! 19Oct01 - J.W. Larson <larson@mcs.anl.gov> - initial (slow)
!           prototype.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::importRAttrDP_'

  integer :: index, aVsize, ierr, n, mysize

       ! Index the attribute we wish to extract:

  index = indexRA_(aV, attrTag)

       ! Determine the number of data points:

  aVsize = lsize_(aV)

       ! Check input array size vs. lsize_(aV):

  if(present(lsize)) then
     if(aVsize < lsize) then
	write(stderr,'(3a,i8,a,i8)') myname_, &
	               ':: ERROR--attempt to import too many entries ', &
                       'into AttrVect aV.  AttrVect_lsize(aV)=',aVsize, &
                       ', number of entries to be imported=',lsize
	call die(myname_)
     endif
     mysize=lsize
  else
     if(aVsize < size(inVect)) then
	write(stderr,'(3a,i8,a,i8)') myname_, &
	               ':: ERROR--attempt to import too many entries ', &
                       'into AttrVect aV.  AttrVect_lsize(aV)=',aVsize, &
                       ' , number of entries to be imported=',size(inVect)
	call die(myname_)
     endif
     mysize=aVsize
  endif

       ! Copy the attribute data into outVect

!$OMP PARALLEL DO PRIVATE(n)
  do n=1,mysize
     aV%rAttr(index,n) = inVect(n)
  end do

 end subroutine importRAttrDP_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: RCopy_ - Copy Real Attributes from One AttrVect to Another
!
! !DESCRIPTION:
! This routine copies from input argment {\tt aVin} into the output
! {\tt AttrVect} argument {\tt aVout} the shared real attributes.
!
! If the optional argument {\tt Vector} is present and true, the vector
! architecture-friendly portions of this routine will be invoked.
!
! If the optional argument {\tt sharedIndices} is present, it should be
! the result of the call {\tt SharedIndicesOneType\_(aVin, aVout, 'REAL',
! sharedIndices)}. Providing this argument speeds up this routine
! substantially. For example, you can compute a {\tt sharedIndices}
! structure once for a given pair of {\tt AttrVect}s, then use that same
! structure for all copies between those two {\tt AttrVect}s (although
! note that a different {\tt sharedIndices} variable would be needed if
! {\tt aVin} and {\tt aVout} were reversed).
!
! {\bf N.B.:}  This routine will fail if the {\tt aVout} is not initialized.
!
! !INTERFACE:

 subroutine RCopy_(aVin, aVout, vector, sharedIndices)

!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),             intent(in)    :: aVin
      logical, optional,          intent(in)    :: vector
      type(AVSharedIndicesOneType), optional, intent(in) :: sharedIndices

! !OUTPUT PARAMETERS:

      type(AttrVect),             intent(inout) :: aVout


! !REVISION HISTORY:
! 18Aug06 - R. Jacob <jacob@mcs.anl.gov> - initial version.
! 28Apr11 - W.J. Sacks <sacks@ucar.edu> - added sharedIndices argument
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::RCopy_'

  integer :: i,j,ier       ! dummy variables
  integer :: aVsize        ! The lsize of aVin and aVout
  integer :: inxmin, outxmin      ! Index variables
  logical :: usevector    ! true if vector flag is present and true.
  character*7 :: data_flag ! character variable used as data type flag
  type(AVSharedIndicesOneType) :: mySharedIndices  ! copied from sharedIndices, or
                                                   ! computed if sharedIndices is not
                                                   ! present
  logical :: clean_mySharedIndices ! true if we need to clean mySharedIndices before
                                   ! returning (will be true if we did allocation in this
                                   ! subroutine)


  ! Check the arguments
  aVsize = lsize_(aVin)
  if(lsize_(aVin) /= lsize_(aVout)) then
     write(stderr,'(2a)') myname_, &
      'MCTERROR: Input aV and output aV do not have the same size'
     call die(myname_,'MCTERROR: Input aV and output aV &
                       &do not have the same size',2)
  endif

  data_flag = 'REAL'

  if (present(sharedIndices)) then
     ! do some error checking on sharedIndices
     if (.not. (associated(sharedIndices%aVindices1) .and. associated(sharedIndices%aVindices2))) then
        call die(myname_,'MCTERROR: provided sharedIndices structure is uninitialized',3)
     endif
     if (trim(sharedIndices%data_flag) /= data_flag) then
        call die(myname_,'MCTERROR: provided sharedIndices structure has incorrect data_flag',4)
     endif

     ! copy into local variable
     mySharedIndices = sharedIndices
     clean_mySharedIndices = .false.
  else
     ! Check REAL attributes for matching indices
     call SharedIndicesOneType_(aVin, aVout, data_flag, mySharedIndices)
     clean_mySharedIndices = .true.
  endif

  if(mySharedIndices%num_indices <= 0) then
    if (clean_mySharedIndices) then
       call cleanSharedIndicesOneType_(mySharedIndices,stat=ier)
       if(ier /= 0) call die(myname_,'MCTERROR: in cleanSharedIndicesOneType_',ier)
    endif
    return
  endif

  ! check vector flag.
  usevector = .false.
  if (present(vector)) then
   if(vector) usevector = .true.
  endif

  ! Start copying

  if(mySharedIndices%contiguous) then

     outxmin=mySharedIndices%aVindices2(1)-1
     inxmin=mySharedIndices%aVindices1(1)-1
     if(usevector) then
!$OMP PARALLEL DO PRIVATE(i,j)
        do i=1,mySharedIndices%num_indices
!CDIR SELECT(VECTOR)
!DIR$ IVDEP
           do j=1,aVsize
              aVout%rAttr(outxmin+i,j) = aVin%rAttr(inxmin+i,j)
           enddo
        enddo
     else
!$OMP PARALLEL DO PRIVATE(j,i) COLLAPSE(2)
        do j=1,aVsize
           do i=1,mySharedIndices%num_indices
              aVout%rAttr(outxmin+i,j) = aVin%rAttr(inxmin+i,j)
           enddo
        enddo
     endif

  else

!$OMP PARALLEL DO PRIVATE(j,i) COLLAPSE(2)
     do j=1,aVsize
        do i=1,mySharedIndices%num_indices
           aVout%rAttr(mySharedIndices%aVindices2(i),j) = aVin%rAttr(mySharedIndices%aVindices1(i),j)
        enddo
     enddo

  endif


  if (clean_mySharedIndices) then
     call cleanSharedIndicesOneType_(mySharedIndices,stat=ier)
     if(ier /= 0) call die(myname_,'MCTERROR: in cleanSharedIndicesOneType_',ier)
  endif

 end subroutine RCopy_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: RCopyL_ - Copy Specific Real Attributes from One AttrVect to Another
!
! !DESCRIPTION:
! This routine copies from input argment {\tt aVin} into the output
! {\tt AttrVect} argument {\tt aVout} the real attributes specified in
! input {\tt CHARACTER} argument {\tt rList}. The attributes can
! be listed in any order.
!
! If any attributes in {\tt aVout} have different names but represent the
! the same quantity and should still be copied, you must provide a translation
! argument {\tt TrList}.  The translation arguments should
! be identical in length to the {\tt rList} but with the correct {\tt aVout}
! name subsititued at the appropriate place.
!
! If the optional argument {\tt Vector} is present and true, the vector
! architecture-friendly portions of this routine will be invoked.
!
! {\bf N.B.:}  This routine will fail if the {\tt aVout} is not initialized or
! if any of the specified attributes are not present in either {\tt aVout} or {\tt aVin}.
!
! !INTERFACE:

 subroutine RCopyL_(aVin, aVout, rList, TrList,  vector)

!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr

      use m_List,          only : GetIndices => get_indices

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),             intent(in)    :: aVin
      character(len=*),           intent(in)    :: rList
      character(len=*), optional, intent(in)    :: TrList
      logical, optional,          intent(in)    :: vector

! !OUTPUT PARAMETERS:

      type(AttrVect),             intent(inout) :: aVout


! !REVISION HISTORY:
! 16Aug06 - R. Jacob <jacob@mcs.anl.gov> - initial version from breakup
!           of Copy_.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::RCopyL_'

  integer :: i,j,ier       ! dummy variables
  integer :: num_indices   ! Overlapping attribute index number
  integer :: aVsize        ! The lsize of aVin and aVout
  integer :: inxmin, outxmin   ! Index variables
  logical :: TrListIsPresent   ! true if list argument is present
  logical :: contiguous    ! true if index segments are contiguous in memory
  logical :: usevector    ! true if vector flag is present and true.

  ! Overlapping attribute index storage arrays:
  integer, dimension(:), pointer :: aVinindices, aVoutindices


  ! Check the arguments
  aVsize = lsize_(aVin)
  if(lsize_(aVin) /= lsize_(aVout)) then
     write(stderr,'(2a)') myname_, &
      'MCTERROR: Input aV and output aV do not have the same size'
     call die(myname_,'MCTERROR: Input aV and output aV &
                       &do not have the same size',2)
  endif

  if(len_trim(rList) <= 0) return
  ! Copy the listed real attributes

  ! Index rList with the AttrVects
  call GetIndices(aVinindices,aVin%rList,trim(rList))

!  TrList is present if it is provided and its length>0
  TrListIsPresent = .false.
  if(present(TrList)) then
     if(len_trim(TrList) > 0) then
       TrListIsPresent = .true.
     endif
  endif

  if(TrListIsPresent) then
     call GetIndices(aVoutindices,aVout%rList,trim(TrList))

     if(size(aVinindices) /= size(aVoutindices)) then
       call die(myname_,"Arguments rList and TrList do not&
             &contain the same number of items")
     endif
  else
       call GetIndices(aVoutindices,aVout%rList,trim(rList))
  endif

  num_indices=size(aVoutindices)

  ! nothing to do if num_indices <=0
  if (num_indices <= 0) then
    deallocate(aVinindices, aVoutindices, stat=ier)
    if(ier/=0) call die(myname_,"deallocate(aVinindices...)",ier)
    return
  endif

  ! check vector flag.
  usevector = .false.
  if (present(vector)) then
   if(vector) usevector = .true.
  endif

! Check if the indices are contiguous in memory for faster copy
  contiguous=.true.
  do i=2,num_indices
     if(aVinindices(i) /= aVinindices(i-1)+1) then
        contiguous = .false.
        exit
     endif
  enddo
  if(contiguous) then
     do i=2,num_indices
        if(aVoutindices(i) /= aVoutindices(i-1)+1) then
           contiguous=.false.
           exit
        endif
     enddo
  endif

! Start copying (arranged loop order optimized for xlf90)
  if(contiguous) then

     outxmin=aVoutindices(1)-1
     inxmin=aVinindices(1)-1
     if(usevector) then
!$OMP PARALLEL DO PRIVATE(i,j)
        do i=1,num_indices
!DIR$ IVDEP
           do j=1,aVsize
              aVout%rAttr(outxmin+i,j) = aVin%rAttr(inxmin+i,j)
           enddo
        enddo
     else
!$OMP PARALLEL DO PRIVATE(j,i) COLLAPSE(2)
        do j=1,aVsize
           do i=1,num_indices
              aVout%rAttr(outxmin+i,j) = aVin%rAttr(inxmin+i,j)
           enddo
        enddo
     endif

  else

!$OMP PARALLEL DO PRIVATE(j,i) COLLAPSE(2)
    do j=1,aVsize
       do i=1,num_indices
          aVout%rAttr(aVoutindices(i),j) = aVin%rAttr(aVinindices(i),j)
       enddo
    enddo

  endif

  deallocate(aVinindices, aVoutindices, stat=ier)
  if(ier/=0) call die(myname_,"deallocate(aVinindices...)",ier)

 end subroutine RCopyL_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ICopy_ - Copy Integer Attributes from One AttrVect to Another
!
! !DESCRIPTION:
! This routine copies from input argment {\tt aVin} into the output
! {\tt AttrVect} argument {\tt aVout} the shared integer attributes.
!
! If the optional argument {\tt Vector} is present and true, the vector
! architecture-friendly portions of this routine will be invoked.
!
! If the optional argument {\tt sharedIndices} is present, it should be
! the result of the call {\tt SharedIndicesOneType\_(aVin, aVout, 'INTEGER',
! sharedIndices)}. Providing this argument speeds up this routine
! substantially. For example, you can compute a {\tt sharedIndices}
! structure once for a given pair of {\tt AttrVect}s, then use that same
! structure for all copies between those two {\tt AttrVect}s (although
! note that a different {\tt sharedIndices} variable would be needed if
! {\tt aVin} and {\tt aVout} were reversed).
!
! {\bf N.B.:}  This routine will fail if the {\tt aVout} is not initialized.
!
! !INTERFACE:

 subroutine ICopy_(aVin, aVout, vector, sharedIndices)

!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),             intent(in)    :: aVin
      logical, optional,          intent(in)    :: vector
      type(AVSharedIndicesOneType), optional, intent(in) :: sharedIndices

! !OUTPUT PARAMETERS:

      type(AttrVect),             intent(inout) :: aVout


! !REVISION HISTORY:
! 16Aug06 - R. Jacob <jacob@mcs.anl.gov> - initial version.
! 28Apr11 - W.J. Sacks <sacks@ucar.edu> - added sharedIndices argument
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ICopy_'

  integer :: i,j,ier       ! dummy variables
  integer :: aVsize        ! The lsize of aVin and aVout
  integer :: inxmin, outxmin      ! Index variables
  logical :: usevector    ! true if vector flag is present and true.
  character*7 :: data_flag ! character variable used as data type flag
  type(AVSharedIndicesOneType) :: mySharedIndices  ! copied from sharedIndices, or
                                                   ! computed if sharedIndices is not
                                                   ! present
  logical :: clean_mySharedIndices ! true if we need to clean mySharedIndices before
                                   ! returning (will be true if we did allocation in this
                                   ! subroutine)


  ! Check the arguments
  aVsize = lsize_(aVin)
  if(lsize_(aVin) /= lsize_(aVout)) then
     write(stderr,'(2a)') myname_, &
      'MCTERROR: Input aV and output aV do not have the same size'
     call die(myname_,'MCTERROR: Input aV and output aV &
                       &do not have the same size',2)
  endif

  data_flag = 'INTEGER'

  if (present(sharedIndices)) then
     ! do some error checking on sharedIndices
     if (.not. (associated(sharedIndices%aVindices1) .and. associated(sharedIndices%aVindices2))) then
        call die(myname_,'MCTERROR: provided sharedIndices structure is uninitialized',3)
     endif
     if (trim(sharedIndices%data_flag) /= data_flag) then
        call die(myname_,'MCTERROR: provided sharedIndices structure has incorrect data_flag',4)
     endif

     ! copy into local variable
     mySharedIndices = sharedIndices
     clean_mySharedIndices = .false.
  else
     ! Check INTEGER attributes for matching indices
     call SharedIndicesOneType_(aVin, aVout, data_flag, mySharedIndices)
     clean_mySharedIndices = .true.
  endif

  if(mySharedIndices%num_indices <= 0) then
    if (clean_mySharedIndices) then
       call cleanSharedIndicesOneType_(mySharedIndices,stat=ier)
       if(ier /= 0) call die(myname_,'MCTERROR: in cleanSharedIndicesOneType_',ier)
    endif
    return
  endif

  ! check vector flag.
  usevector = .false.
  if (present(vector)) then
   if(vector) usevector = .true.
  endif


  if(mySharedIndices%contiguous) then

     outxmin=mySharedIndices%aVindices2(1)-1
     inxmin=mySharedIndices%aVindices1(1)-1
     if(usevector) then
!$OMP PARALLEL DO PRIVATE(i,j)
        do i=1,mySharedIndices%num_indices
!CDIR SELECT(VECTOR)
!DIR$ IVDEP
           do j=1,aVsize
              aVout%iAttr(outxmin+i,j) = aVin%iAttr(inxmin+i,j)
           enddo
        enddo
     else
!$OMP PARALLEL DO PRIVATE(j,i) COLLAPSE(2)
        do j=1,aVsize
           do i=1,mySharedIndices%num_indices
              aVout%iAttr(outxmin+i,j) = aVin%iAttr(inxmin+i,j)
           enddo
        enddo
     endif

  else

!$OMP PARALLEL DO PRIVATE(j,i) COLLAPSE(2)
     do j=1,aVsize
        do i=1,mySharedIndices%num_indices
           aVout%iAttr(mySharedIndices%aVindices2(i),j) = aVin%iAttr(mySharedIndices%aVindices1(i),j)
        enddo
     enddo

  endif

  if (clean_mySharedIndices) then
     call cleanSharedIndicesOneType_(mySharedIndices,stat=ier)
     if(ier /= 0) call die(myname_,'MCTERROR: in cleanSharedIndicesOneType_',ier)
  endif

 end subroutine ICopy_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: ICopyL_ - Copy Specific Integer Attributes from One AttrVect to Another
!
! !DESCRIPTION:
! This routine copies from input argment {\tt aVin} into the output
! {\tt AttrVect} argument {\tt aVout} the integer attributes specified in
! input {\tt CHARACTER} argument {\tt iList}. The attributes can
! be listed in any order.
!
! If any attributes in {\tt aVout} have different names but represent the
! the same quantity and should still be copied, you must provide a translation
! argument {\tt TiList}.  The translation arguments should
! be identical in length to the {\tt iList} but with the correct {\tt aVout}
! name subsititued at the appropriate place.
!
! If the optional argument {\tt Vector} is present and true, the vector
! architecture-friendly portions of this routine will be invoked.
!
! {\bf N.B.:}  This routine will fail if the {\tt aVout} is not initialized or
! if any of the specified attributes are not present in either {\tt aVout} or {\tt aVin}.
!
! !INTERFACE:

 subroutine ICopyL_(aVin, aVout, iList, TiList, vector)

!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr

      use m_List,          only : GetIndices => get_indices

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),             intent(in)    :: aVin
      character(len=*)          , intent(in)    :: iList
      character(len=*), optional, intent(in)    :: TiList
      logical, optional,          intent(in)    :: vector

! !OUTPUT PARAMETERS:

      type(AttrVect),             intent(inout) :: aVout


! !REVISION HISTORY:
! 16Aug06 - R. Jacob <jacob@mcs.anl.gov> - initial version from breakup
!           of Copy_.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::ICopyL_'

  integer :: i,j,ier       ! dummy variables
  integer :: num_indices   ! Overlapping attribute index number
  integer :: aVsize        ! The lsize of aVin and aVout
  integer :: inxmin, outxmin      ! Index variables
  logical :: TiListIsPresent     ! true if list argument is present
  logical :: contiguous    ! true if index segments are contiguous in memory
  logical :: usevector    ! true if vector flag is present and true.

  ! Overlapping attribute index storage arrays:
  integer, dimension(:), pointer :: aVinindices, aVoutindices


  ! Check the arguments
  aVsize = lsize_(aVin)
  if(lsize_(aVin) /= lsize_(aVout)) then
     write(stderr,'(2a)') myname_, &
      'MCTERROR: Input aV and output aV do not have the same size'
     call die(myname_,'MCTERROR: Input aV and output aV &
                       &do not have the same size',2)
  endif

  if(len_trim(iList) <= 0) return
  ! Copy the listed real attributes


! Index rList with the AttrVects
  call GetIndices(aVinindices,aVin%iList,trim(iList))

! TiList is present if its provided and its length>0
  TiListIsPresent = .false.
  if(present(TiList)) then
    if(len_trim(TiList) > 0) then
      TiListIsPresent = .true.
    endif
  endif

  if(TiListIsPresent) then
     call GetIndices(aVoutindices,aVout%iList,trim(TiList))
     if(size(aVinindices) /= size(aVoutindices)) then
        call die(myname_,"Arguments iList and TiList do not&
               &contain the same number of items")
     endif
  else
     call GetIndices(aVoutindices,aVout%iList,trim(iList))
  endif

  num_indices=size(aVoutindices)

  ! nothing to do if num_indices <=0
  if (num_indices <= 0) then
    deallocate(aVinindices, aVoutindices, stat=ier)
    if(ier/=0) call die(myname_,"deallocate(aVinindices...)",ier)
    return
  endif

  ! check vector flag.
  usevector = .false.
  if (present(vector)) then
   if(vector) usevector = .true.
  endif

! Check if the indices are contiguous in memory for faster copy
  contiguous=.true.
  do i=2,num_indices
    if(aVinindices(i) /= aVinindices(i-1)+1) then
       contiguous = .false.
       exit
    endif
  enddo
  if(contiguous) then
    do i=2,num_indices
      if(aVoutindices(i) /= aVoutindices(i-1)+1) then
         contiguous=.false.
         exit
      endif
    enddo
  endif

! Start copying (arranged loop order optimized for xlf90)
  if(contiguous) then

    outxmin=aVoutindices(1)-1
    inxmin=aVinindices(1)-1
    if(usevector) then
!$OMP PARALLEL DO PRIVAtE(i,j)
      do i=1,num_indices
!CDIR SELECT(VECTOR)
!DIR$ IVDEP
         do j=1,aVsize
            aVout%iAttr(outxmin+i,j) = aVin%iAttr(inxmin+i,j)
         enddo
      enddo
    else
!$OMP PARALLEL DO PRIVATE(j,i) COLLAPSE(2)
      do j=1,aVsize
         do i=1,num_indices
            aVout%iAttr(outxmin+i,j) = aVin%iAttr(inxmin+i,j)
         enddo
      enddo
    endif

  else

!$OMP PARALLEL DO PRIVATE(j,i) COLLAPSE(2)
     do j=1,aVsize
       do i=1,num_indices
          aVout%iAttr(aVoutindices(i),j) = aVin%iAttr(aVinindices(i),j)
       enddo
     enddo

  endif

  deallocate(aVinindices, aVoutindices, stat=ier)
  if(ier/=0) call die(myname_,"deallocate(aVinindices...)",ier)

 end subroutine ICopyL_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: Copy_ - Copy Real and Integer Attributes from One AttrVect to Another
!
! !DESCRIPTION:
! This routine copies from input argment {\tt aVin} into the output
! {\tt AttrVect} argument {\tt aVout} the real and integer attributes specified in
! input {\tt CHARACTER} argument {\tt iList} and {\tt rList}. The attributes can
! be listed in any order.  If neither {\tt iList} nor {\tt rList} are provided,
! all attributes shared between {\tt aVin} and {\tt aVout} will be copied.
!
! If any attributes in {\tt aVout} have different names but represent the
! the same quantity and should still be copied, you must provide a translation
! argument {\tt TrList} and/or {\tt TiList}.  The translation arguments should
! be identical to the {\tt rList} or {\tt iList} but with the correct {\tt aVout}
! name subsititued at the appropriate place.
!
! This routines combines the functions of {\tt RCopy\_}, {\tt RCopyL\_},
! {\tt ICopy\_} and {\tt ICopyL\_}.  If you know you only want to copy real
! attributes, use the {\tt RCopy} functions.  If you know you only want to
! copy integer attributes, use the {\tt ICopy} functions.
!
! If the optional argument {\tt Vector} is present and true, the vector
! architecture-friendly portions of this routine will be invoked.
!
! If the optional argument {\tt sharedIndices} is present, it should be
! the result of the call {\tt SharedIndices\_(aVin, aVout,
! sharedIndices)}. Providing this argument speeds up this routine
! substantially. For example, you can compute a {\tt sharedIndices}
! structure once for a given pair of {\tt AttrVect}s, then use that same
! structure for all copies between those two {\tt AttrVect}s (although
! note that a different {\tt sharedIndices} variable would be needed if
! {\tt aVin} and {\tt aVout} were reversed). Note, however, that {\tt
! sharedIndices} is ignored if either {\tt rList} or {\tt iList} are
! given.
!
! {\bf N.B.:}  This routine will fail if the {\tt aVout} is not initialized or
! if any of the specified attributes are not present in either {\tt aVout} or {\tt aVin}.
!
! !INTERFACE:

 subroutine Copy_(aVin, aVout, rList, TrList, iList, TiList, vector, sharedIndices)

!
! !USES:
!
      use m_die ,          only : die, warn
      use m_stdio ,        only : stderr

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),             intent(in)    :: aVin
      character(len=*), optional, intent(in)    :: iList
      character(len=*), optional, intent(in)    :: rList
      character(len=*), optional, intent(in)    :: TiList
      character(len=*), optional, intent(in)    :: TrList
      logical, optional,          intent(in)    :: vector
      type(AVSharedIndices), optional, intent(in) :: sharedIndices

! !OUTPUT PARAMETERS:

      type(AttrVect),             intent(inout) :: aVout


! !REVISION HISTORY:
! 12Jun02 - R. Jacob <jacob@mcs.anl.gov> - initial version.
! 13Jun02 - R. Jacob <jacob@mcs.anl.gov> - copy shared attributes
!           if no attribute lists are specified.
! 30Sep02 - R. Jacob <jacob@mcs.anl.gov> - new argument order with all
!           optional arguments last
! 19Feb02 - E. Ong <eong@mcs.anl.gov> - new implementation using
!           new list function get_indices and faster memory copy
! 28Oct03 - R. Jacob <jacob@mcs.anl.gov> - add optional vector
!           argument to use vector-friendly code provided by Fujitsu
! 16Aug06 - R. Jacob <jacob@mcs.anl.gov> - split into 4 routines:
!           RCopy_,RCopyL_,ICopy_,ICopyL_
! 28Apr11 - W.J. Sacks <sacks@ucar.edu> - added sharedIndices argument
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::Copy_'

  integer :: i,j,ier       ! dummy variables
  integer :: num_indices   ! Overlapping attribute index number
  integer :: aVsize        ! The lsize of aVin and aVout
  integer :: num_inindices, num_outindices   ! Number of matching indices in aV
  integer :: inxmin, outxmin, inx, outx      ! Index variables
  logical :: TiListIsPresent, TrListIsPresent! true if list argument is present
  logical :: contiguous    ! true if index segments are contiguous in memory
  logical :: usevector    ! true if vector flag is present and true.

  ! Overlapping attribute index storage arrays:
  integer, dimension(:), pointer :: aVinindices, aVoutindices


  ! Check the arguments
  aVsize = lsize_(aVin)
  if(lsize_(aVin) /= lsize_(aVout)) then
     write(stderr,'(2a)') myname_, &
      'MCTERROR: Input aV and output aV do not have the same size'
     call die(myname_,'MCTERROR: Input aV and output aV &
                       &do not have the same size',2)
  endif

  ! check vector flag.
  usevector = .false.
  if (present(vector)) then
   if(vector) usevector = .true.
  endif

  ! Copy the listed real attributes
  if(present(rList)) then
     ! TrList is present if it is provided and its length>0
     TrListIsPresent = .false.
     if(present(TrList)) then
        if(len_trim(TrList) > 0) then
           TrListIsPresent = .true.
        endif
     endif

     if(present(sharedIndices)) then
        call warn(myname_,'Use of sharedIndices not implemented in RCopyL; &
                     &ignoring sharedIndices',1)
     endif

     if(TrListIsPresent) then
        call RCopyL_(aVin,aVout,rList,TrList,vector=usevector)
     else
        call RCopyL_(aVin,aVout,rList,vector=usevector)
     endif

  endif   ! if(present(rList)

  !  Copy the listed integer attributes
  if(present(iList)) then

     ! TiList is present if its provided and its length>0
     TiListIsPresent = .false.
     if(present(TiList)) then
        if(len_trim(TiList) > 0) then
           TiListIsPresent = .true.
        endif
     endif

     if(present(sharedIndices)) then
        call warn(myname_,'Use of sharedIndices not implemented in ICopyL; &
                     &ignoring sharedIndices',1)
     endif

     if(TiListIsPresent) then
        call ICopyL_(aVin,aVout,iList,TiList,vector=usevector)
     else
        call ICopyL_(aVin,aVout,iList,vector=usevector)
     endif

  endif   ! if(present(iList))

  ! If neither rList nor iList is present, copy shared attibutes
  ! from in to out.
  if( .not.present(rList) .and. .not.present(iList)) then

     if (present(sharedIndices)) then
        call RCopy_(aVin, Avout, vector=usevector, sharedIndices=sharedIndices%shared_real)
        call ICopy_(aVin, Avout, vector=usevector, sharedIndices=sharedIndices%shared_integer)
     else
        call RCopy_(aVin, Avout, vector=usevector)
        call ICopy_(aVin, Avout, vector=usevector)
     endif

  endif

 end subroutine Copy_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: Sort_ - Use Attributes as Keys to Generate an Index Permutation
!
! !DESCRIPTION:
! The subroutine {\tt Sort\_()} uses a list of keys defined by the {\tt List}
! {\tt key\_list}, searches for the appropriate integer or real attributes
! referenced by the items in {\tt key\_list} ( that is, it identifies the
! appropriate entries in {aV\%iList} and {\tt aV\%rList}), and then
! uses these keys to generate a permutation {\tt perm} that will put
! the entries of the attribute vector {\tt aV} in lexicographic order
! as defined by {\tt key\_list} (the ordering in {\tt key\_list} being from
! left to right.
!
! {\bf N.B.:}  This routine will fail if {\tt aV\%iList} and
! {\tt aV\%rList} share one or more common entries.
!
! {\bf N.B.:}  This routine will fail if one of the sorting keys presented is
! not present in {\tt aV\%iList} nor {\tt aV\%rList}.
!
! !INTERFACE:

 subroutine Sort_(aV, key_list, perm, descend, perrWith, dieWith)
!
! !USES:
!
      use m_String,        only : String
      use m_String,        only : String_tochar => tochar
      use m_String,        only : String_clean => clean
      use m_List ,         only : List_allocated => allocated
      use m_List ,         only : List_index => index
      use m_List ,         only : List_nitem => nitem
      use m_List ,         only : List_get   => get
      use m_die ,          only : die
      use m_stdio ,        only : stderr
      use m_SortingTools , only : IndexSet
      use m_SortingTools , only : IndexSort

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),                  intent(in) :: aV
      type(List),                      intent(in) :: key_list
      logical, dimension(:), optional, intent(in) :: descend
      character(len=*),      optional, intent(in) :: perrWith
      character(len=*),      optional, intent(in) :: dieWith

! !OUTPUT PARAMETERS:
!
      integer, dimension(:),           pointer    :: perm


! !REVISION HISTORY:
! 20Oct00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
! 25Apr01 - R.L. Jacob <jacob@mcs.anl.gov> - add -1 to make a
!           backwards loop go backwards
! 14Jun01 - J. Larson / E. Ong -- Fixed logic bug in REAL attribute
!           sort (discovered by E. Ong), and cleaned up error /
!           shutdown logic.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::Sort_'

! local variables

        ! storage for key extracted from key_list:

  type(String) :: key

        ! number of keys, loop index, error flag, and length:

  integer :: nkeys, n, ierr, length

        ! key indices for av%rAttr and av%iAttr, respectively:

  integer, dimension(:), allocatable :: rIndex, iIndex

        ! copy of descend argument

  logical, dimension(:), allocatable :: descend_copy

        ! count the sorting keys:

  nkeys = List_nitem(key_list)

        ! Check the descend argument. Note: the unnecessary copy
        ! circumvents an optimization bug in the compaq compiler

  if(present(descend)) then
     if(size(descend)/=nkeys) then
        call die(myname_,"Size of descend argument is not equal &
                  &to the number of keys")
     endif
     allocate(descend_copy(nkeys),stat=ierr)
     if(ierr/=0) call die(myname_,"allocate(descend_copy)",ierr)
     descend_copy=descend
  endif


        ! allocate and initialize rIndex and iIndex to
        ! zero (the null return values from the functions
        ! indexRA_() and indexIA_() ).

  allocate(rIndex(nkeys), iIndex(nkeys), stat=ierr)
  if(ierr/=0) call die(myname_,"allocate(rindex,iIndex)",ierr)

  rIndex = 0
  iIndex = 0

        ! Loop over the keys in the list, and identify the
        ! appropriate integer or real attribute, storing the
        ! attribute index in iIndex(:) or rIndex(:), respectively.

  do n = 1, nkeys

        ! grab the next key

     call List_get(key, n, key_list)

        ! determine wheter this key refers to an
        ! integer or real attribute:
! jwl commented out in favor of below code block unitl an error
! handling strategy is settled upon for indexIA_() and indexRA_().
!     rIndex(n) = indexRA_(aV, String_tochar(key), dieWith=myname_)
!     iIndex(n) = indexIA_(aV, String_tochar(key), dieWith=myname_)

     if(List_allocated(aV%rList)) then
	rIndex(n) = List_index(aV%rList, String_tochar(key))
     else
	rIndex(n) = 0
     endif
     if(List_allocated(aV%iList)) then
	iIndex(n) = List_index(aV%iList, String_tochar(key))
     else
	iIndex(n) = 0
     endif

        ! If both rIndex(n) and iIndex(n) are greater than
        ! zero, then we have an integer attribute sharing
        ! the same name as a real attribute, and there is
        ! no clear path as to which one is the sort key.
        ! This is a fatal error that triggers shutdown.

     if ((rIndex(n) > 0) .and. (iIndex(n) > 0)) then
	if(.not.present(dieWith)) then
	   if(present(perrWith)) write(stderr,'(4a)') myname, &
		":: ambiguous key, ", perrWith, &
		" both iIndex(n) and rIndex(n) positive."
	    call die(myname_,":: both iIndex(n) and rIndex(n) > 0.")
	else
	   if(present(perrWith)) then
	       write(stderr,'(4a)') myname_,":: ", perrWith, &
		       " both iIndex(n) and rIndex(n) positive."
           endif
	   call die(myname_,dieWith)
	endif
     endif

        ! If both rIndex(n) and iIndex(n) are nonpositive,
        ! then the requested sort key is not present in either
        ! aV%rList or aV%iList, and we cannot perform the sort.
        ! This is a fatal error that triggers shutdown.

     if ((rIndex(n) <= 0) .and. (iIndex(n) <= 0)) then
	if(.not.present(dieWith)) then
	   if(present(perrWith)) write(stderr,'(4a)') myname,":: ", &
		perrWith, &
		" both iIndex(n) and rIndex(n) nonpositive"
	   call die(myname_,":: both iIndex(n) and rIndex(n) <= 0.")
	else
	   if(present(perrWith)) then
	      write(stderr,'(4a)') myname_,":: ", perrWith,	&
		   " both iIndex(n) and rIndex(n) nonpositive"
           endif
	   call die(myname_,dieWith)
	endif
     endif

        ! If only one of rIndex(n) or iIndex(n) is positive,
        ! set the other value to zero.

     if (iIndex(n) > 0) rIndex(n) = 0
     if (rIndex(n) > 0) iIndex(n) = 0

        ! Clean up temporary string -key-

     call String_clean(key)

  enddo ! do n=1,nkeys

        ! Now we have the locations of the keys in the integer and
        ! real attribute storage areas aV%iAttr and aV%rAttr, respectively.
        ! our next step is to construct and initialize the permutation
        ! array perm.  First step--determine the length of aV using
        ! lsize_():

  length = lsize_(aV)

  allocate(perm(length), stat=ierr)
  if(ierr/=0) call die(myname_,"allocate(perm)",ierr)

        ! Initialize perm(i)=i, for i=1,length

  call IndexSet(perm)

        ! Now we can perform the stable successive keyed sorts to
        ! transform perm into the permutation that will place the
        ! entries of the attribute arrays in the lexicographic order
        ! defined by key_list.  This is achieved by successive calls to
        ! IndexSort(), but in reverse order to the order of the keys
        ! as they appear in key_list.

  do n=nkeys, 1, -1
     if(iIndex(n) > 0) then
	if(present(descend)) then
	   call IndexSort(length, perm, aV%iAttr(iIndex(n),:), &
		          descend_copy(n))
	else
   	   call IndexSort(length, perm, aV%iAttr(iIndex(n),:), &
               		  descend=.false.)
	endif ! if(present(descend)...
     else
	if(rIndex(n) > 0) then
	   if(present(descend)) then
	      call IndexSort(length, perm, aV%rAttr(rIndex(n),:), &
		             descend_copy(n))
	   else
	      call IndexSort(length, perm, aV%rAttr(rIndex(n),:), &
               		     descend=.false.)
	   endif ! if(present(descend)...
	endif ! if (rIndex(n) > 0)...
     endif ! if (iIndex(n) > 0)...
  enddo

        ! Now perm(1:length) is the transformation we seek--we are
        ! finished.

  deallocate(iIndex, rIndex, stat=ierr)  ! clean up allocated arrays.
  if(ierr/=0) call die(myname_,"deallocate(iIndex,rIndex)",ierr)

  if(present(descend)) deallocate(descend_copy,stat=ierr)
  if(ierr/=0) call die(myname_,"deallocate(descend_copy)",ierr)

 end subroutine Sort_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: Permute_ - Permute AttrVect Elements
!
! !DESCRIPTION:
! The subroutine {\tt Permute\_()} uses a a permutation {\tt perm} (which can
! be generated by the routine {\tt Sort\_()} in this module) to rearrange
! the entries in the attribute integer and real storage areas of the
! input attribute vector {\tt aV}--{\tt aV\%iAttr} and {\tt aV\%rAttr},
! respectively.
!
! !INTERFACE:

 subroutine Permute_(aV, perm, perrWith, dieWith)
!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr
      use m_SortingTools , only : Permute

      implicit none

! !INPUT PARAMETERS:
!
      integer, dimension(:),           intent(in)    :: perm
      character(len=*),      optional, intent(in)    :: perrWith
      character(len=*),      optional, intent(in)    :: dieWith

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),                  intent(inout) :: aV

! !REVISION HISTORY:
! 23Oct00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::Permute_'

! local variables

  integer :: i

        ! Check input arguments for compatibility--assure
        ! lsize_(aV) = size(perm); that is, make sure the
        ! index permutation is the same length as the vectors
        ! it will re-arrange.

  if (size(perm) /= lsize_(aV)) then
     if(.not.present(dieWith)) then
	if(present(perrWith)) write(stderr,'(4a,i8,a,i8)') myname, &
	  ":: size mismatch, ", perrWith, &
	  "size(perm)=",size(perm)," lsize_(aV)=",lsize_(aV)
     else
	write(stderr,'(4a,i8,a,i8)') myname, &
	 ":: size mismatch, ", dieWith,	&
	 "size(perm)=",size(perm)," lsize_(aV)=",lsize_(aV)
	call die(dieWith)
     endif
  endif

  if(size(perm) == lsize_(aV)) then

        ! Permute integer attributes:
     if(nIAttr_(aV) /= 0) then
	do i=1,nIAttr_(aV)
	   call Permute(aV%iAttr(i,:),perm,lsize_(aV))
	end do
     endif

        ! Permute real attributes:
     if(nRAttr_(aV) /= 0) then
	do i=1,nRAttr_(aV)
	   call Permute(aV%rAttr(i,:),perm,lsize_(aV))
	end do
     endif

  endif

 end subroutine Permute_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: Unpermute_ - Unpermute AttrVect Elements
!
! !DESCRIPTION:
! The subroutine {\tt Unpermute\_()} uses a a permutation {\tt perm} (which can
! be generated by the routine {\tt Sort\_()} in this module) to rearrange
! the entries in the attribute integer and real storage areas of the
! input attribute vector {\tt aV}--{\tt aV\%iAttr} and {\tt aV\%rAttr},
! respectively.  This is meant to be called on an {\tt aV} that has already
! been permuted but it could also be used to perform the inverse operation
! implied by {\tt perm} on an unpermuted {\tt aV}.
!
! !INTERFACE:

 subroutine Unpermute_(aV, perm, perrWith, dieWith)
!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr
      use m_SortingTools , only : Unpermute

      implicit none

! !INPUT PARAMETERS:
!
      integer, dimension(:),           intent(in)    :: perm
      character(len=*),      optional, intent(in)    :: perrWith
      character(len=*),      optional, intent(in)    :: dieWith

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),                  intent(inout) :: aV

! !REVISION HISTORY:
! 23Nov05 - R. Jacob <jacob@mcs.anl.gov> - based on Permute
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::Unpermute_'

! local variables

  integer :: i

        ! Check input arguments for compatibility--assure
        ! lsize_(aV) = size(perm); that is, make sure the
        ! index permutation is the same length as the vectors
        ! it will re-arrange.

  if (size(perm) /= lsize_(aV)) then
     if(.not.present(dieWith)) then
	if(present(perrWith)) write(stderr,'(4a,i8,a,i8)') myname, &
	  ":: size mismatch, ", perrWith, &
	  "size(perm)=",size(perm)," lsize_(aV)=",lsize_(aV)
     else
	write(stderr,'(4a,i8,a,i8)') myname, &
	 ":: size mismatch, ", dieWith,	&
	 "size(perm)=",size(perm)," lsize_(aV)=",lsize_(aV)
	call die(dieWith)
     endif
  endif

  if(size(perm) == lsize_(aV)) then

        ! Unpermute integer attributes:
     if(nIAttr_(aV) /= 0) then
	do i=1,nIAttr_(aV)
	   call Unpermute(aV%iAttr(i,:),perm,lsize_(aV))
	end do
     endif

        ! Permute real attributes:
     if(nRAttr_(aV) /= 0) then
	do i=1,nRAttr_(aV)
	   call Unpermute(aV%rAttr(i,:),perm,lsize_(aV))
	end do
     endif

  endif

 end subroutine Unpermute_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: SortPermute_ - In-place Lexicographic Sort of an AttrVect
!
! !DESCRIPTION:
!
! The subroutine {\tt SortPermute\_()} uses the routine {\tt Sort\_()}
! to create an index permutation {\tt perm} that will place the AttrVect
! entries in the lexicographic order defined by the keys in the List
! variable {\tt key\_list}.  This permutation is then used by the routine
! {\tt Permute\_()} to place the AttreVect entries in lexicographic order.
!
! !INTERFACE:

 subroutine SortPermute_(aV, key_list, descend, perrWith, dieWith)
!
! !USES:
!
      use m_die ,          only : die
      use m_stdio ,        only : stderr

      implicit none

! !INPUT PARAMETERS:
!
      type(List),                       intent(in)    :: key_list
      logical , dimension(:), optional, intent(in)    :: descend
      character(len=*),       optional, intent(in)    :: perrWith
      character(len=*),       optional, intent(in)    :: dieWith

! !INPUT/OUTPUT PARAMETERS:
!
      type(AttrVect),                   intent(inout) :: aV

! !REVISION HISTORY:
! 24Oct00 - J.W. Larson <larson@mcs.anl.gov> - initial prototype
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::Permute_'

! local variables

       ! Permutation array pointer perm(:)
  integer, dimension(:), pointer :: perm
       ! Error flag ierr
  integer :: ierr

       ! Step One: Generate the index permutation perm(:)

  if(present(descend)) then
     call Sort_(aV, key_list, perm, descend, perrWith, dieWith)
  else
     call Sort_(aV, key_list, perm, perrWith=perrWith, &
	        dieWith=dieWith)
  endif

       ! Step Two:  Apply the index permutation perm(:)

  call Permute_(aV, perm, perrWith, dieWith)

       ! Step Three:  deallocate temporary array used to
       ! store the index permutation (this was allocated
       ! in the routine Sort_()

  deallocate(perm, stat=ierr)

  end subroutine SortPermute_

! Sorting:
!
!	aV%iVect(:,:) =		&
!		aV%iVect((/(indx(i),i=1,lsize(aV))/),:)
!
!	aV%iVect((/(indx(i),i=1,lsize(aV))/),:) =	&
!		aV%iVect(:,:)
!
!	aV%iVect(:,ikx),aV%iVect(:,iks)
!
!

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: aVaVSharedAttrIndexList_ - AttrVect shared attributes.
!
! !DESCRIPTION:  {\tt aVaVSharedAttrIndexList\_()} takes a pair of
! user-supplied {\tt AttrVect} variables {\tt aV1} and {\tt aV2},
! and for choice of either {\tt REAL} or {\tt INTEGER} attributes (as
! specified literally in the input {\tt CHARACTER} argument {\tt attrib})
! returns the number of shared attributes {\tt NumShared}, and arrays of
! indices {\tt Indices1} and {\tt Indices2} to their storage locations
! in {\tt aV1} and {\tt aV2}, respectively.
!
! {\bf N.B.:}  This routine returns two allocated arrays---{\tt Indices1(:)}
! and {\tt Indices2(:)}---which must be deallocated once the user no longer
! needs them.  Failure to do this will create a memory leak.
!
! !INTERFACE:

 subroutine aVaVSharedAttrIndexList_(aV1, aV2, attrib, NumShared, &
                                     Indices1, Indices2)

!
! !USES:
!
      use m_stdio
      use m_die,      only : MP_perr_die, die, warn

      use m_List,     only : GetSharedListIndices

      implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),        intent(in)  :: aV1
      type(AttrVect),        intent(in)  :: aV2
      character(len=*),      intent(in)  :: attrib

! !OUTPUT PARAMETERS:
!
      integer,               intent(out) :: NumShared
      integer, dimension(:), pointer     :: Indices1
      integer, dimension(:), pointer     :: Indices2

! !REVISION HISTORY:
! 07Feb01 - J.W. Larson <larson@mcs.anl.gov> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::aVaVSharedAttrIndexList_'

  integer :: ierr

       ! Based on the value of the argument attrib, pass the
       ! appropriate pair of Lists for comparison...

  select case(trim(attrib))
  case('REAL','real')
     call GetSharedListIndices(aV1%rList, aV2%rList, NumShared, &
                                 Indices1, Indices2)
  case('INTEGER','integer')
     call GetSharedListIndices(aV1%iList, aV2%iList, NumShared, &
                                 Indices1, Indices2)
  case default
     write(stderr,'(4a)') myname_,":: value of argument attrib=",attrib, &
          " not recognized.  Allowed values: REAL, real, INTEGER, integer"
     ierr = 1
     call die(myname_, 'invalid value for attrib', ierr)
  end select

 end subroutine aVaVSharedAttrIndexList_


!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
! Climate and Global Dynamics Division, National Center for Atmospheric Research !
!BOP -----------------------------------------------------------------------------
!
! !IROUTINE: SharedIndices_ - AttrVect shared attributes and auxiliary information
!
! !DESCRIPTION:  {\tt SharedIndices\_()} takes a pair of user-supplied
! {\tt AttrVect} variables {\tt aV1} and {\tt aV2}, and returns a
! structure of type {\tt AVSharedIndices} ({\tt sharedIndices}).  This
! structure contains arrays of indices to the locations of the shared
! attributes, as well as auxiliary information.  The structure contains
! information on both the {\tt REAL} and {\tt INTEGER} attributes.  See
! documentation for the {\tt SharedIndicesOneType\_} subroutine for some
! additional details, as much of the work is done there.
!
! {\bf N.B.:} The returned structure, {\tt sharedIndices}, contains
! allocated arrays that must be deallocated once the user no longer
! needs them.  This should be done through a call to {\tt
! cleanSharedIndices\_}.
!
! !INTERFACE:

 subroutine SharedIndices_(aV1, aV2, sharedIndices)

    implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),        intent(in)  :: aV1
      type(AttrVect),        intent(in)  :: aV2

! !INPUT/OUTPUT PARAMETERS:
!
      type(AVSharedIndices), intent(inout) :: sharedIndices

! !REVISION HISTORY:
! 28Apr11 - W.J. Sacks <sacks@ucar.edu> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::SharedIndices_'

  call SharedIndicesOneType_(aV1, aV2, 'REAL', sharedIndices%shared_real)
  call SharedIndicesOneType_(aV1, aV2, 'INTEGER', sharedIndices%shared_integer)

 end subroutine SharedIndices_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
! Climate and Global Dynamics Division, National Center for Atmospheric Research !
!BOP -----------------------------------------------------------------------------
!
! !IROUTINE: SharedIndicesOneType_ - AttrVect shared attributes and auxiliary information, for one data type
!
! !DESCRIPTION:  {\tt SharedIndicesOneType\_()} takes a pair of
! user-supplied {\tt AttrVect} variables {\tt aV1} and {\tt aV2}, and
! for choice of either {\tt REAL} or {\tt INTEGER} attributes (as
! specified literally in the input {\tt CHARACTER} argument {\tt
! attrib}) returns a structure of type {\tt AVSharedIndicesOneType} ({\tt
! sharedIndices}).  This structure contains arrays of indices to the
! locations of the shared attributes of the given type, as well as
! auxiliary information.
!
! The {\tt aVindices1} and {\tt aVindices2} components of {\tt
! sharedIndices} will be indices into {\tt aV1} and {\tt aV2},
! respectively.
!
! {\bf N.B.:} The returned structure, {\tt sharedIndices}, contains
! allocated arrays that must be deallocated once the user no longer
! needs them.  This should be done through a call to {\tt
! cleanSharedIndicesOneType\_}.  Even if there are no attributes in
! common between {\tt aV1} and {\tt aV2}, {\tt sharedIndices} will still
! be initialized, and memory will still be allocated. Furthermore, if an
! already-initialized {\tt sharedIndices} variable is to be given new
! values, {\tt cleanSharedIndicesOneType\_} must be called before {\tt
! SharedIndicesOneType\_} is called a second time, in order to prevent a
! memory leak.
!
! !INTERFACE:

 subroutine SharedIndicesOneType_(aV1, aV2, attrib, sharedIndices)

    implicit none

! !INPUT PARAMETERS:
!
      type(AttrVect),        intent(in)  :: aV1
      type(AttrVect),        intent(in)  :: aV2
      character(len=*),      intent(in)  :: attrib

! !INPUT/OUTPUT PARAMETERS:
!
      type(AVSharedIndicesOneType), intent(inout) :: sharedIndices

! !REVISION HISTORY:
! 28Apr11 - W.J. Sacks <sacks@ucar.edu> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::SharedIndicesOneType_'
  integer :: i

  ! Check appropriate attributes (real or integer) for matching indices
  call aVaVSharedAttrIndexList_(aV1, aV2, attrib, sharedIndices%num_indices, &
                                   sharedIndices%aVindices1, sharedIndices%aVindices2)

  sharedIndices%data_flag = attrib

  ! Check indices for contiguous segments in memory
  sharedIndices%contiguous=.true.
  do i=2,sharedIndices%num_indices
     if(sharedIndices%aVindices1(i) /= sharedIndices%aVindices1(i-1)+1) then
        sharedIndices%contiguous = .false.
        exit
     endif
  enddo
  if(sharedIndices%contiguous) then
     do i=2,sharedIndices%num_indices
        if(sharedIndices%aVindices2(i) /= sharedIndices%aVindices2(i-1)+1) then
           sharedIndices%contiguous=.false.
           exit
        endif
     enddo
  endif

 end subroutine SharedIndicesOneType_


!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
! Climate and Global Dynamics Division, National Center for Atmospheric Research !
!BOP -----------------------------------------------------------------------------
!
! !IROUTINE: cleanSharedIndices_ - Deallocate allocated memory structures of an AVSharedIndices structure
!
! !DESCRIPTION: This routine deallocates the allocated memory structures
! of the input/output {\tt AVSharedIndicesOneType} argument {\tt
! sharedIndices}, if they are currently associated.  It also resets
! other components of this structure to a default state.  The success
! (failure) of this operation is signified by a zero (non-zero) value of
! the optional {\tt INTEGER} output argument {\tt stat}.  If {\tt
! clean\_()} is invoked without supplying {\tt stat}, and any of the
! deallocation operations fail, the routine will terminate with an error
! message.  If multiple errors occur, {\tt stat} will give the error
! condition for the last error.
!
! !INTERFACE:

 subroutine cleanSharedIndices_(sharedIndices, stat)

    implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      type(AVSharedIndices), intent(inout) :: sharedIndices

! !OUTPUT PARAMETERS:
!
      integer, optional, intent(out)       :: stat

! !REVISION HISTORY:
! 28Apr11 - W.J. Sacks <sacks@ucar.edu> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::cleanSharedIndices_'
  integer :: ier

  if(present(stat)) stat=0

  call cleanSharedIndicesOneType_(sharedIndices%shared_real, stat=ier)
  if(present(stat) .and. ier /= 0) then
     stat = ier
  end if

  call cleanSharedIndicesOneType_(sharedIndices%shared_integer, stat=ier)
  if(present(stat) .and. ier /= 0) then
     stat = ier
  end if

 end subroutine cleanSharedIndices_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
! Climate and Global Dynamics Division, National Center for Atmospheric Research !
!BOP -----------------------------------------------------------------------------
!
! !IROUTINE: cleanSharedIndicesOneType_ - Deallocate allocated memory structures of an AVSharedIndicesOneType structure
!
! !DESCRIPTION: This routine deallocates the allocated memory structures
! of the input/output {\tt AVSharedIndices} argument {\tt
! sharedIndices}, if they are currently associated.  It also resets
! other components of this structure to a default state.  The success
! (failure) of this operation is signified by a zero (non-zero) value of
! the optional {\tt INTEGER} output argument {\tt stat}.  If {\tt
! clean\_()} is invoked without supplying {\tt stat}, and any of the
! deallocation operations fail, the routine will terminate with an error
! message.  If multiple errors occur, {\tt stat} will give the error
! condition for the last error.
!
! !INTERFACE:

 subroutine cleanSharedIndicesOneType_(sharedIndices, stat)
!
! !USES:
!
      use m_die,      only : die

    implicit none

! !INPUT/OUTPUT PARAMETERS:
!
      type(AVSharedIndicesOneType), intent(inout) :: sharedIndices

! !OUTPUT PARAMETERS:
!
      integer, optional, intent(out)       :: stat

! !REVISION HISTORY:
! 28Apr11 - W.J. Sacks <sacks@ucar.edu> - initial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::cleanSharedIndicesOneType_'
  integer :: ier

  if(present(stat)) stat=0

  if(associated(sharedIndices%aVindices1)) then

     deallocate(sharedIndices%aVindices1,stat=ier)

     if (ier /= 0) then
        if(present(stat)) then
           stat=ier
        else
           call die(myname_,'deallocate(sharedIndices%aVindices1)',ier)
        endif
     endif

  endif

  if(associated(sharedIndices%aVindices2)) then

     deallocate(sharedIndices%aVindices2,stat=ier)

     if (ier /= 0) then
        if(present(stat)) then
           stat=ier
        else
           call die(myname_,'deallocate(sharedIndices%aVindices2)',ier)
        endif
     endif

  endif

  ! Reset other components to default values
  sharedIndices%num_indices = 0
  sharedIndices%contiguous = .false.
  sharedIndices%data_flag = ' '

  end subroutine cleanSharedIndicesOneType_

 end module m_AttrVect
!.




