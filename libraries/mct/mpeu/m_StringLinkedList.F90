!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !MODULE: m_StringLinkedList - A linked-list of String
!
! !DESCRIPTION:
!
! !INTERFACE:

    module m_StringLinkedList
      use m_String,only : String
      implicit none
      private	! except

      public :: StringLinkedList	! The class data structure

		! o An object of a StringLinkedList should be defined
		!   as a pointer of a StringLinkedList.  It is often
		!   represented by a pointer to the head-node of the
		!   linked-list.
		!
		! o A node in a StringLinkedList is specificed by a
		!   reference pointer.  A reference pointer is a
		!   logical reference of a node in the list.  However,
		!   it does not physically point to that node.  In
		!   fact, a reference pointer normally references to
		!   the node physically pointed by the pointer in the
		!   node physically pointed by the reference pointer,
		!
		!	[this] -> [..|next] -> [..|next]
		!
		!   where the last node is the logically referenced
		!   node.

      public :: StringLinkedList_init	! constructor
      public :: StringLinkedList_clean  ! destructor

		! A _clean() action will reset a StringLinkedList to its
		! pre-_init() status.

      public :: StringLinkedList_insert ! grower, insert a node
      public :: StringLinkedList_delete ! ungrower, delete a node

		! Both procedures processing the node through a given
		! reference pointer.  The reference pointer will not
		! be modified directly through either _insert() or
		! _delete().  It is the pointer in the node physically
		! pointed by a reference pointer got modified.  Also,
		! the node logically referenced by the reference
		! pointer is either the new node for an _insert(), and
		! the removed node for a _delete().

      public :: StringLinkedList_eol	! inquirer, is an end-node?

		! An end-of-list situation occurs when the reference
		! pointer is logically referencing to the end-node or
		! beyond.  Note that an end-node links to itself.

      public :: StringLinkedList_next	! iterator, go to the next node.

      public :: StringLinkedList_count	! counter

		! Count the number of nodes from this reference pointer,
		! starting from and including the logical node but
		! excluding the end-node.

      public :: StringLinkedList_get	! fetcher

		! Get the value logically referenced by a reference
		! pointer.  Return EOL if the referenced node is an
		! EOL().  The reference pointer will be iterated to
		! the next node if the referenced node is not an EOL.

    type StringLinkedList
      type(String) :: str
      type(StringLinkedList),pointer :: next
    end type StringLinkedList

    interface StringLinkedList_init  ; module procedure	&
	init_
    end interface

    interface StringLinkedList_clean ; module procedure	&
	clean_
    end interface

    interface StringLinkedList_insert; module procedure	&
	insertc_,	&	! insert a CHARACTER(len=*) argument
	inserts_		! insert a String argument
    end interface

    interface StringLinkedList_delete; module procedure	&
	delete_
    end interface

    interface StringLinkedList_eol   ; module procedure	&
	eol_
    end interface

    interface StringLinkedList_next  ; module procedure	&
	next_
    end interface

    interface StringLinkedList_count ; module procedure	&
	count_
    end interface

    interface StringLinkedList_get   ; module procedure	&
	getc_,		&	! get as a CHARACTER(len=*)
	gets_			! get as a String
    end interface

! !REVISION HISTORY:
! 	16Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT(MPEU)::m_StringLinkedList'

!   Examples:
!
!   1) Creating a first-in-first-out linked-list,
!
!	type(StringLinkedList),pointer :: head,this
!	character(len=80) :: aline
!
!	call StringLinkedList_init(head)
!	this => head
!	do
!	  read(*,'(a)',iostat=ier) aline
!	  if(ier/=0) exit
!	  call StringLinkedList_insert(trim(aline),this)
!	  call StringLinkedList_next(this)
!	end do
!
!   2) Creating a last-in-first-out linked-list,  Note that the only
!     difference from Example (1) is without a call to
!     StringLinkedList_next().
!
!	type(StringLinkedList),pointer :: head,this
!	character(len=80) :: aline
!
!	call StringLinkedList_init(head)
!	this => head
!	do
!	  read(*,'(a)',iostat=ier) aline
!	  if(ier/=0) exit
!	  call StringLinkedList_insert(trim(aline),this)
!	end do
!

contains
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: init_ - initialize a StringLinkedList from a pointer
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine init_(head)
      use m_die, only : die
      use m_mall,only : mall_ison,mall_ci
      implicit none
      type(StringLinkedList),pointer :: head	! (out) a list

! !REVISION HISTORY:
! 	22Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::init_'
  type(StringLinkedList),pointer :: tail
  integer :: ier

	! Two special nodes are needed for a linked-list, according to
	! Robert Sedgewick (Algorithms, QA76.6.S435, page 21).
	!
	! It seems only _head_ will be needed for external references.
	! Node _tail_ will be used to denote an end-node.

  allocate(head,tail,stat=ier)
	if(ier/=0) call die(myname_,'allocate()',ier)

	if(mall_ison()) call mall_ci(2,myname)	! for two nodes

  head%next => tail
  tail%next => tail

  nullify(tail)

end subroutine init_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: insertc_ - insert before the logically referenced node
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine insertc_(cstr,this)
      use m_String,only : String_init
      use m_mall,  only : mall_ison,mall_ci
      use m_die,   only : die
      implicit none
      character(len=*),intent(in) :: cstr ! a new entry
      type(StringLinkedList),pointer :: this ! (in) a node

! !REVISION HISTORY:
! 	16Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::insertc_'
  type(StringLinkedList),pointer :: tmpl
  integer :: ier

	! Create a memory cell for the new entry of StringLinkedList

  allocate(tmpl,stat=ier)
	if(ier/=0) call die(myname_,'allocate()',ier)

	if(mall_ison()) call mall_ci(1,myname)	! for one nodes

	! Store the data

  call String_init(tmpl%str,cstr)

	! Rebuild the links, if the List was not empty

  tmpl%next => this%next
  this%next => tmpl

	! Clean the working pointer

  nullify(tmpl)

end subroutine insertc_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: inserts_ - insert before the logically referenced node
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine inserts_(str,this)
      use m_String,only : String,String_init
      use m_mall,  only : mall_ison,mall_ci
      use m_die,   only : die
      implicit none
      type(String),intent(in)  :: str	! a new entry
      type(StringLinkedList),pointer :: this ! (in) a node

! !REVISION HISTORY:
! 	16Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::inserts_'
  type(StringLinkedList),pointer :: tmpl
  integer :: ier

	! Create a memory cell for the new entry of StringLinkedList

  allocate(tmpl,stat=ier)
	if(ier/=0) call die(myname_,'allocate()',ier)

	if(mall_ison()) call mall_ci(1,myname)	! for one nodes

	! Store the data

  call String_init(tmpl%str,str)

	! Rebuild the links, if the List was not empty

  tmpl%next => this%next
  this%next => tmpl

	! Clean the working pointer, if it mean anyting

  nullify(tmpl)

end subroutine inserts_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: delete_ - delete the logically referenced node
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine delete_(this)
      use m_String,only : String_clean
      use m_mall,  only : mall_ison,mall_co
      use m_die,   only : die
      implicit none
      type(StringLinkedList),pointer :: this ! (in) a node

! !REVISION HISTORY:
! 	17Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::delete_'
  type(StringLinkedList),pointer :: tmpl
  integer :: ier

  tmpl => this%next%next		! hold the next target
  call String_clean(this%next%str)	! remove the next storage

	if(mall_ison()) call mall_co(1,myname)	! removing one node

  deallocate(this%next,stat=ier)	! Clean memory gabage
	if(ier/=0) call die(myname_,'deallocate()',ier)

	! Skip the current target.  Rebuild the link to the target
	! of the current target.

  this%next => tmpl

	! Clean the working pointer, if it mean anything

  nullify(tmpl)
end subroutine delete_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: eol_ - if the logically referenced node is an end-node
!
! !DESCRIPTION:
!
! !INTERFACE:

    function eol_(this)
      implicit none
      type(StringLinkedList),pointer :: this ! (in) a node
      logical :: eol_		! returned value

! !REVISION HISTORY:
! 	23Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::eol_'

  eol_=associated(this%next,this%next%next)
end function eol_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: next_ - point a reference pointer to the next node
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine next_(this)
      implicit none
      type(StringLinkedList),pointer :: this ! (inout) a node

! !REVISION HISTORY:
! 	23Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::next_'

  this => this%next

end subroutine next_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: count_ - count the number of nodes
!
! !DESCRIPTION:
!
! !INTERFACE:

    function count_(this)
      implicit none
      type(StringLinkedList),pointer :: this ! (in) a node
      integer :: count_		! returned value

! !REVISION HISTORY:
! 	24Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::count_'
  type(StringLinkedList),pointer :: tmpl

  tmpl => this

  count_=0
  do while(.not.eol_(tmpl))
    count_=count_+1
    call next_(tmpl)
  end do

  nullify(tmpl)
end function count_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: getc_ - get the logically referenced value as CHARACTERs
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine getc_(this,cstr,eol)
      use m_String,only : String
      use m_String,only : String_init
      use m_String,only : String_clean
      use m_String,only : char
      implicit none
      type(StringLinkedList),pointer :: this ! (inout) a node
      character(len=*),intent(out) :: cstr ! the referenced value
      logical         ,intent(out) :: eol  ! if the node is an end-node

! !REVISION HISTORY:
! 	17Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::getc_'
  type(String) :: str

  call gets_(this,str,eol)

  if(.not.eol) then
    cstr=char(str)
    call String_clean(str)
  endif

end subroutine getc_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: gets_ - get the logically referenced value as a String
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine gets_(this,str,eol)
      use m_String,only : String
      use m_String,only : String_init
      implicit none
      type(StringLinkedList),pointer :: this ! (inout) a node
      type(String),intent(out) :: str  ! the referenced value
      logical     ,intent(out) :: eol  ! if the node is an end-node

! !REVISION HISTORY:
! 	17Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::gets_'

  eol=eol_(this)
  if(.not.eol) then
    call String_init(str,this%next%str)
    call next_(this)
  endif

end subroutine gets_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: clean_ - clean the whole object from this point
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine clean_(head,stat)
      use m_die,only : die,perr
      use m_mall,only : mall_ison,mall_co
      implicit none
      type(StringLinkedList),pointer :: head ! (inout) a head-node
      integer,optional,intent(out) :: stat ! return status

! !REVISION HISTORY:
! 	17Feb00	- Jing Guo <guo@dao.gsfc.nasa.gov>
!		- initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::clean_'
  integer :: ier
  logical :: err

  if(present(stat)) stat=0

	! Verify if the pointer is valid

  err=.not.associated(head)
  if(.not.err) err=.not.associated(head%next)

	if(err) then
	  call perr(myname_,'Attempting to clean an uninitialized list')
	  if(.not.present(stat)) call die(myname_)
	  stat=-1
	  return
	endif

	! Clean the rest before delete the current one.

  do
    if(eol_(head)) exit
    call delete_(head)
  end do

	if(mall_ison()) call mall_co(2,myname)	! remove two nodes

  deallocate(head%next,stat=ier)
  if(ier==0) deallocate(head,stat=ier)
	if(ier/=0) then
	  call perr(myname_,'deallocate()',ier)
	  if(.not.present(stat)) call die(myname_)
	  stat=-1
	  return
	endif

end subroutine clean_

end module m_StringLinkedList
