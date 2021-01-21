!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!-------------------------------------------------------------------------
!BOI
!
! !TITLE: Inpak 90 Documentation \\ Version 1.01
!
! !AUTHORS: Arlindo da Silva
!
! !AFFILIATION: Data Assimilation Office, NASA/GSFC, Greenbelt, MD 20771
!
! !DATE: June 20, 1996
!
! !INTRODUCTION: Package Overview
!
!      Inpak 90 is a Fortran (77/90) collection of
!      routines/functions for accessing {\em Resource Files}
!      in ASCII format. The package is optimized
!      for minimizing formatted I/O, performing all of its string
!      operations in memory using Fortran intrinsic functions.
!
! \subsection{Resource Files}
!
!      A {\em Resource File} is a text file consisting of variable
!     length lines (records), each possibly starting with a {\em label}
!     (or {\em key}), followed by some data. A simple resource file
!     looks like this:
!
! \begin{verbatim}
! # Lines starting with # are comments which are
! # ignored during processing.
! my_file_names:         jan87.dat jan88.dat jan89.dat
! radius_of_the_earth:   6.37E6  # these are comments too
! constants:             3.1415   25
! my_favourite_colors:   green blue 022 # text & number are OK
! \end{verbatim}
!
!    In this example, {\tt my\_file\_names:} and {\tt constants:}
!    are labels, while {\tt jan87.dat, jan88.dat} and {\tt jan89.dat} are
!    data associated with label {\tt my\_file\_names:}.
!    Resource files can also contain simple tables of the form,
!
! \begin{verbatim}
! my_table_name::
!  1000     3000     263.0
!   925     3000     263.0
!   850     3000     263.0
!   700     3000     269.0
!   500     3000     287.0
!   400     3000     295.8
!   300     3000     295.8
! ::
! \end{verbatim}
!
! Resource files are random access, the particular order of the
! records are not important (except between ::s in a table definition).
!
!    \subsection{A Quick Stroll}
!
!    The first step is to load the ASCII resource (rc) file into
!    memory\footnote{See next section for a complete description
!    of parameters for each routine/function}:
!
! \begin{verbatim}
!       call i90_LoadF ( 'my_file.rc', iret )
! \end{verbatim}
!
!    The next step is to select the label (record) of interest, say
!
! \begin{verbatim}
!       call i90_label ( 'constants:', iret )
! \end{verbatim}
!
!  The 2 constants above can be retrieved with the following code
!  fragment:
! \begin{verbatim}
!       real    r
!       integer i
!       call i90_label ( 'constants:', iret )
!       r = i90_gfloat(iret)    ! results in r = 3.1415
!       i = i90_gint(iret)      ! results in i = 25
! \end{verbatim}
!
!  The file names above can be retrieved with the following
!  code fragment:
! \begin{verbatim}
!       character*20 fn1, fn2, fn3
!       integer      iret
!       call i90_label ( 'my_file_names:', iret )
!       call i90_Gtoken ( fn1, iret )  ! ==> fn1 = 'jan87.dat'
!       call i90_Gtoken ( fn2, iret )  ! ==> fn1 = 'jan88.dat'
!       call i90_Gtoken ( fn3, iret )  ! ==> fn1 = 'jan89.dat'
! \end{verbatim}
!
! To access the table above, the user first must use {\tt i90\_label()} to
! locate the beginning of the table, e.g.,
!
! \begin{verbatim}
!       call i90_label ( 'my_table_name::', iret )
! \end{verbatim}
!
! Subsequently, {\tt i90\_gline()} can be used to gain access to each
! row of the table. Here is a code fragment to read the above
! table (7 rows, 3 columns):
!
! \begin{verbatim}
!       real          table(7,3)
!       character*20  word
!       integer       iret
!       call i90_label ( 'my_table_name::', iret )
!       do i = 1, 7
!          call i90_gline ( iret )
!          do j = 1, 3
!             table(i,j) = i90_gfloat ( iret )
!          end do
!       end do
! \end{verbatim}
!
! Get the idea?
!
! \newpage
! \subsection{Main Routine/Functions}
!
! \begin{verbatim}
!  ------------------------------------------------------------------
!         Routine/Function                  Description
!  ------------------------------------------------------------------
!  I90_LoadF ( filen, iret )     loads resource file into memory
!  I90_Label ( label, iret )     selects a label (key)
!  I90_GLine ( iret )            selects next line (for tables)
!  I90_Gtoken ( word, iret )     get next token
!  I90_Gfloat ( iret )           returns next float number (function)
!  I90_GInt ( iret )             returns next integer number (function)
!  i90_AtoF ( string, iret )     ASCII to float (function)
!  i90_AtoI ( string, iret )     ASCII to integer (function)
!  I90_Len ( string )            string length without trailing blanks
!  LabLin ( label )              similar to i90_label (no iret)
!  FltGet ( default )            returns next float number (function)
!  IntGet ( default )            returns next integer number (function)
!  ChrGet ( default )            returns next character (function)
!  TokGet ( string, default )    get next token
!  ------------------------------------------------------------------
! \end{verbatim}
!
! {\em Common Arguments:}
!
! \begin{verbatim}
! character*(*)      filen       file name
! integer            iret        error return code (0 is OK)
! character*(*)      label       label (key) to locate record
! character*(*)      word        blank delimited string
! character*(*)      string      a sequence of characters
! \end{verbatim}
!
! See the Prologues in the next section for additional details.
!
!
!    \subsection{Package History}
!       Back in the 70s Eli Isaacson wrote IOPACK in Fortran
!       66.  In June of 1987 I wrote Inpak77 using
!       Fortran 77 string functions; Inpak 77 is a vastly
!       simplified IOPACK, but has its own goodies not found in
!       IOPACK.  Inpak 90 removes some obsolete functionality in
!       Inpak77, and parses the whole resource file in memory for
!       performance.  Despite its name, Inpak 90 compiles fine
!       under any modern Fortran 77 compiler.
!
!   \subsection{Bugs}
!       Inpak 90 is not very gracious with error messages.
!       The interactive functionality of Inpak77 has not been implemented.
!       The comment character \# cannot be escaped.
!
!  \subsection{Availability}
!
!   This software is available at
! \begin{verbatim}
!         ftp://niteroi.gsfc.nasa.gov/pub/packages/i90/
! \end{verbatim}
!   There you will find the following files:
! \begin{verbatim}
! i90.f      Fortran 77/90 source code
! i90.h      Include file needed by i90.f
! ti90.f     Test code
! i90.ps     Postscript documentation
! \end{verbatim}
! An on-line version of this document is available at
! \begin{verbatim}
!        ftp://niteroi.gsfc.nasa.gov/www/packages/i90/i90.html
! \end{verbatim}
!
!EOI
!-------------------------------------------------------------------------
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!
! !REVISION HISTORY:
! 	03Jul96 - J. Guo	- evolved to Fortran 90 module.  The
!		modifications include 1) additional subroutines to
!		dynamically manage the memory, 2) privatized most
!		entries, 3) included "i90.h" into the module source
!		with better initializations, 4) removed blockdata, 5)
!		used a portable opntext() call to avoid I/O portability
!		problems.
!
!		See I90_page() I90_Release(), and I90_LoadF() for
!		details.
!
!	05Aug98	- Jing Guo	-
!		  Removed i90_page() and its references.
!		  Added internal subroutines push_() and pop_().
!		  Modified i90_release().
!		  Added i90_fullrelease().
!		  Removed %loaded.  Check i90_depth instead.
!       06Aug98 - Todling       - made I90_gstr public
!	20Dec98 - Jing Guo	- replaced the description of I90_Gstr
!	28Sep99 - Jing Guo	- Merged with the MPI version with
!				  some addtional changes based on
!				  merging decisions.
!	12Oct99 - Larson/Guo	- Overloaded fltget() to new routines
!                 getfltsp() and fltgetdp(), providing better support
!                 for 32 and 64 bit platforms, respectively.
!_______________________________________________________________________

     module m_inpak90
     use m_stdio, only : stderr,stdout
     use m_realkinds, only: FP, SP, DP,kind_r8
     implicit none
     private
     public :: I90_LoadF   ! loads a resource file into memory
     public :: I90_allLoadF! loads/populates a resource file to all PEs
     public :: I90_Release ! Releases one cached resource file
     public :: I90_fullRelease ! Releases the whole stack
     public :: I90_Label   ! selects a label (key)
     public :: I90_GLine   ! selects the next line (for tables)
     public :: I90_Gtoken  ! gets the next token
     public :: I90_Gstr    ! get a string upto to a "$" or EOL

     public :: I90_AtoF	! ASCII to float (function)
     public :: I90_AtoI	! ASCII to integer (function)

     public :: I90_Gfloat  ! returns next float number (function)
     public :: I90_GInt	! returns next integer number (function)

     public :: lablin,rdnext,fltget,intget,getwrd,str2rn,chrget,getstr
     public :: strget

     interface fltget; module procedure &
	  fltgetsp, &
	  fltgetdp
     end interface


!-----------------------------------------------------------------------
!
!	This part was originally in "i90.h", but included for module.
!

		! revised parameter table to fit Fortran 90 standard

  integer,   parameter :: LSZ      = 256

!ams
! On Linux with the Fujitsu compiler, I needed to reduce NBUF_MAX
!ams
! integer,   parameter :: NBUF_MAX = 400*(LSZ) ! max size of buffer
! integer,   parameter :: NBUF_MAX = 200*(LSZ) ! max size of buffer
! Further reduction of NBUF_MAX was necessary for the Fujitsu VPP:
  integer,   parameter :: NBUF_MAX = 128*(LSZ)-1 ! Maximum buffer size
                                                 ! that works with the
                                                 ! Fujitsu-VPP platform.


  character, parameter :: BLK = achar(32)   ! blank (space)
  character, parameter :: TAB = achar(09)   ! TAB
  character, parameter :: EOL = achar(10)   ! end of line mark (newline)
  character, parameter :: EOB = achar(00)   ! end of buffer mark (null)
  character, parameter :: NULL= achar(00)   ! what it says

  type inpak90
		! May be easily paged for extentable file size (J.G.)

    integer :: nbuf                           ! actual size of buffer
    character(len=NBUF_MAX),pointer :: buffer ! hold the whole file?
    character(len=LSZ),     pointer :: this_line ! the current line

    integer :: next_line  ! index for next line on buffer

    type(inpak90),pointer :: last
  end type inpak90

  integer,parameter :: MALLSIZE_=10	! just an estimation

  character(len=*),parameter :: myname='MCT(MPEU)::m_inpak90'
!-----------------------------------------------------------------------

    integer,parameter :: i90_MXDEP = 5
    integer,save      :: i90_depth = 0
    type(inpak90),save,pointer :: i90_now

!-----------------------------------------------------------------------
      contains
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: I90_allLoadF - populate a rooted database to all PEs
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine I90_allLoadF(fname,root,comm,istat)
      use m_mpif90, only : MP_perr
      use m_mpif90, only : MP_comm_rank
      use m_mpif90, only : MP_CHARACTER
      use m_mpif90, only : MP_INTEGER
      use m_die, only : perr
      implicit none
      character(len=*),intent(in) :: fname
      integer,intent(in) :: root
      integer,intent(in) :: comm
      integer,intent(out) :: istat

! !REVISION HISTORY:
! 	28Jul98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::I90_allLoadF'
  integer :: myID,ier

  istat=0

  call MP_comm_rank(comm,myID,ier)
  if(ier/=0) then
    call MP_perr(myname_,'MP_comm_rank()',ier)
    istat=ier
    return
  endif

  if(myID == root) then
    call i90_LoadF(fname,ier)
    if(ier /= 0) then
      call perr(myname_,'i90_LoadF("//trim(fname)//")',ier)
      istat=ier
      return
    endif
  else
    call push_(ier)
    if(ier /= 0) then
      call perr(myname_,'push_()',ier)
      istat=ier
      return
    endif
  endif

	! Initialize the buffer on all PEs

  call MPI_Bcast(i90_now%buffer,NBUF_MAX,MP_CHARACTER,root,comm,ier)
  if(ier /= 0) then
    call MP_perr(myname_,'MPI_Bcast(%buffer)',ier)
    istat=ier
    return
  endif

  call MPI_Bcast(i90_now%nbuf,1,MP_INTEGER,root,comm,ier)
  if(ier /= 0) then
    call MP_perr(myname_,'MPI_Bcast(%nbuf)',ier)
    istat=ier
    return
  endif

  i90_now%this_line=' '
  i90_now%next_line=0

end subroutine I90_allLoadF

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: push_ - push on a new layer of the internal file _i90_now_
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine push_(ier)
      use m_die, only : perr
      use m_mall,only : mall_mci,mall_ci,mall_ison
      implicit none
      integer,intent(out) :: ier

! !REVISION HISTORY:
! 	05Aug98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::push_'
  type(inpak90),pointer :: new

  if(i90_depth <= 0) nullify(i90_now)	! just an initialization

	! Too many levels

  if(i90_depth >= i90_MXDEP) then
	call perr(myname_,'(overflow)',i90_depth)
	ier=1
	return
  endif

  allocate(new,stat=ier)
	if(ier /= 0) then
	  call perr(myname_,'allocate(new)',ier)
	  return
	endif

	if(mall_ison()) call mall_ci(MALLSIZE_,myname)

  allocate(new%buffer,new%this_line,stat=ier)
	if(ier /= 0) then
	  call perr(myname_,'allocate(new%..)',ier)
	  return
	endif

	if(mall_ison()) then
	  call mall_mci(new%buffer,myname)
	  call mall_mci(new%this_line,myname)
	endif

  new%last => i90_now
  i90_now  => new
  nullify(new)

  i90_depth = i90_depth+1
end subroutine push_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: pop_ - pop off a layer of the internal file _i90_now_
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine pop_(ier)
      use m_die, only : perr
      use m_mall,only : mall_mco,mall_co,mall_ison
      implicit none
      integer,intent(out) :: ier

! !REVISION HISTORY:
! 	05Aug98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::pop_'
  type(inpak90),pointer :: old

  if(i90_depth <= 0) then
	call perr(myname_,'(underflow)',i90_depth)
	ier=1
	return
  endif

  old => i90_now%last

	if(mall_ison()) then
	  call mall_mco(i90_now%this_line,myname)
	  call mall_mco(i90_now%buffer,myname)
	endif

  deallocate(i90_now%buffer,i90_now%this_line,stat=ier)
	if(ier /= 0) then
	  call perr(myname_,'deallocate(new%..)',ier)
	  return
	endif

	if(mall_ison())  call mall_co(MALLSIZE_,myname)

  deallocate(i90_now,stat=ier)
	if(ier /= 0) then
	  call perr(myname_,'deallocate(new)',ier)
	  return
	endif

  i90_now => old
  nullify(old)

  i90_depth = i90_depth - 1
end subroutine pop_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
!
! !ROUTINE: I90_Release - deallocate memory used to load a resource file
!
! !INTERFACE:
!
      subroutine I90_Release(stat)
	use m_die,only : perr,die
	implicit none
	integer,optional, intent(out) :: stat
!
! !DESCRIPTION:
!
!	I90_Release() is used to pair I90_LoadF() to release the memory
!	used by I90_LoadF() for resourse data input.
!
! !SEE ALSO:
!
! !REVISION HISTORY:
! 	03Jul96 - J. Guo	- added to Arlindos inpak90 for its
!				  Fortran 90 revision.
!_______________________________________________________________________
  character(len=*),parameter :: myname_=myname//'::i90_Release'
  integer :: ier

  if(present(stat)) stat=0

  call pop_(ier)
  if(ier/=0) then
    call perr(myname_,'pop_()',ier)
    if(.not.present(stat)) call die(myname_)
    stat=ier
    return
  endif

 end subroutine I90_Release

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: i90_fullRelease - releases the whole stack led by _i90_now_
!
! !DESCRIPTION:
!
! !INTERFACE:

    subroutine i90_fullRelease(ier)
      use m_die,only : perr
      implicit none
      integer,intent(out) :: ier

! !REVISION HISTORY:
! 	05Aug98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::i90_fullRelease'

  do while(i90_depth > 0)
    call pop_(ier)
    if(ier /= 0) then
      call perr(myname_,'pop_()',ier)
      return
    endif
  end do
  ier=0

end subroutine i90_fullRelease
!=======================================================================
      subroutine I90_LoadF ( filen, iret )
	use m_ioutil, only : luavail,opntext,clstext
	use m_die, only : perr
      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE:  I90_LoadF() --- Loads resource file into memory.
!
! !DESCRIPTION:
!
!  Reads resource file, strips out comments, translate TABs into
!  blanks, and loads the modified file contents into memory.
!  Must be called only once for each resource file.
!
! !CALLING SEQUENCE:
!
!     call i90_LoadF ( filen, iret )
!
! !INPUT PARAMETERS:
!
      character*(*) filen            ! file name

! !OUTPUT PARAMETERS:

      integer       iret             ! Return code:
                                     !   0    no error
                                     ! -98    coult not get unit number
                                     !        (strange!)
                                     ! -98    talk to a wizzard
                                     ! -99    out of memory: increase
                                     !        NBUF_MAX in 'i90.h'
                                     ! other  iostat from open statement.
!
! !BUGS:
!
!  It does not perform dynamic allocation, mostly to keep vanilla f77
!  compatibility. Overall amount of static memory is small (~100K
!  for default NBUF_MAX = 400*256).
!
! !SEE ALSO:
!
!  i90_label()   selects a label (key)
!
! !FILES USED:
!
!  File name supplied on input. The file is opened, read and then closed.
!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!
!EOP
!-------------------------------------------------------------------------
      integer         lu, ios, loop, ls, ptr
      character*256   line
      character(len=*), parameter :: myname_ = myname//'::i90_loadf'

		! Check to make sure there is not too many levels
		! of the stacked resource files

  if(i90_depth >= i90_MXDEP) then
	call perr(myname_,'(overflow)',i90_depth)
	iret=1
	return
  endif

!     Open file
!     ---------
!      lu = i90_lua()

      lu = luavail()	! a more portable version
      if ( lu .lt. 0 ) then
         iret = -97
         return
      end if

	! A open through an interface to avoid portability problems.
	! (J.G.)

      call opntext(lu,filen,'old',ios)
      if ( ios .ne. 0 ) then
	 write(stderr,'(2a,i5)') myname_,': opntext() error, ios =',ios
         iret = ios
         return
      end if

	! Create a dynamic page to store the file.  It might be expanded
	! to allocate memory on requests (a link list) (J.G.)

	! Changed from page_() to push_(), to allow multiple (stacked)
	! inpak90 buffers.  J.G.

      call push_(ios)	! to create buffer space
      if ( ios .ne. 0 ) then
	 write(stderr,'(2a,i5)') myname_,': push_() error, ios =',ios
         iret = ios
         return
      end if

!     Read to end of file
!     -------------------
      i90_now%buffer(1:1) = EOL
      ptr = 2                         ! next buffer position
      do loop = 1, NBUF_MAX

!        Read next line
!        --------------
         read(lu,'(a)', end=11) line  ! read next line
         call i90_trim ( line )      ! remove trailing blanks
         call i90_pad ( line )        ! Pad with # from end of line

!        A non-empty line
!        ----------------
         ls = index(line,'#' ) - 1    ! line length
         if ( ls .gt. 0 ) then
              if ( (ptr+ls) .gt. NBUF_MAX ) then
                 iret = -99
                 return
              end if
              i90_now%buffer(ptr:ptr+ls) = line(1:ls) // EOL
              ptr = ptr + ls + 1
         end if

      end do

      iret = -98 ! good chance i90_now%buffer is not big enough
      return

 11   continue

!     All done
!     --------
!      close(lu)
	call clstext(lu,ios)
	if(ios /= 0) then
	  iret=-99
	  return
	endif
      i90_now%buffer(ptr:ptr) = EOB
      i90_now%nbuf = ptr
      i90_now%this_line=' '
      i90_now%next_line=0
      iret = 0

      return
      end subroutine I90_LoadF


!...................................................................

      subroutine i90_label ( label, iret )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE:  I90_Label() --- Selects a label (record).
!
! !DESCRIPTION:
!
!  Once the buffer has been loaded with {\tt i90\_loadf()}, this routine
!  selects a given ``line'' (record/table) associated with ``label''.
!  Think of ``label'' as a resource name or data base ``key''.
!
! !CALLING SEQUENCE:
!
!     call i90_Label ( label, iret )
!
! !INPUT PARAMETERS:
!
      character(len=*),intent(in) :: label            ! input label

! !OUTPUT PARAMETERS:

      integer       iret             ! Return code:
                                     !   0    no error
                                     !  -1    buffer not loaded
                                     !  -2    could not find label
!
! !SEE ALSO:
!
!  i90_loadf()    load file into buffer
!  i90_gtoken()   get next token
!  i90_gline()    get next line (for tables)
!  atof()         convert word (string) to float
!  atoi()         convert word (string) to integer
!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!  19Jan01   Jay Larson <larson@mcs.anl.gov> - introduced CHARACTER
!            variable EOL_label, which is used to circumvent pgf90
!            problems with passing concatenated characters as an argument
!            to a function.
!
!EOP
!-------------------------------------------------------------------------

      integer i, j

      character(len=(len(label)+len(EOL))) :: EOL_label

!	Make sure that a buffer is defined (JG)
!	----------------------------------
	if(i90_depth <= 0) then
	  iret = -1
	  return
	endif

!     Determine whether label exists
!     ------------------------------
      EOL_label = EOL // label
      i = index ( i90_now%buffer(1:i90_now%nbuf), EOL_label ) + 1
      if ( i .le. 1 ) then
           i90_now%this_line = BLK // EOL
           iret = -2
           return
      end if

!     Extract the line associated with this label
!     -------------------------------------------
      i = i + len ( label )
      j = i + index(i90_now%buffer(i:i90_now%nbuf),EOL) - 2
      i90_now%this_line = i90_now%buffer(i:j) // BLK // EOL

      i90_now%next_line = j + 2

      iret = 0

      return
      end subroutine i90_label

!...................................................................

      subroutine i90_gline ( iret )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE:  I90_GLine() --- Selects next line.
!
! !DESCRIPTION:
!
!     Selects next line, irrespective of of label. If the next line starts
! with :: (end of table mark), then it lets the user know. This sequential
! access of the buffer is useful to assess tables, a concept introduced
! in Inpak 77 by Jing Guo. A table is a construct like this:
!
! \begin{verbatim}
! my_table_name::
!  1000     3000     263.0
!   925     3000     263.0
!   850     3000     263.0
!   700     3000     269.0
!   500     3000     287.0
!   400     3000     295.8
!   300     3000     295.8
! ::
! \end{verbatim}
!
! To access this table, the user first must use {\tt i90\_label()} to
! locate the beginning of the table, e.g.,
!
! \begin{verbatim}
!       call i90_label ( 'my_table_name::', iret )
! \end{verbatim}
!
! Subsequently, {\tt i90\_gline()} can be used to gain acess to each
! row of the table. Here is a code fragment to read the above
! table (7 rows, 3 columns):
!
! \begin{verbatim}
!       real          table(7,3)
!       character*20  word
!       integer       iret
!       call i90_label ( 'my_table_name::', iret )
!       do i = 1, 7
!          call i90_gline ( iret )
!          do j = 1, 3
!             table(i,j) = fltget ( 0. )
!          end do
!       end do
! \end{verbatim}
!
!  For simplicity we have assumed that the dimensions of table were
!  known. It is relatively simple to infer the table dimensions
!  by manipulating ``iret''.
!
! !CALLING SEQUENCE:
!
!     call i90_gline ( iret )
!
! !INPUT PARAMETERS:
!
!     None.
!
! !OUTPUT PARAMETERS:
!
      integer       iret             ! Return code:
                                     !   0    no error
                                     !  -1    end of buffer reached
                                     !  +1    end of table  reached

! !SEE ALSO:
!
!  i90_label()    selects a line (record/table)
!
! !REVISION HISTORY:
!
!  10feb95   Guo        Wrote rdnext(), Inpak 77 extension.
!  19Jun96   da Silva   Original code with functionality of rdnext()
!
!EOP
!-------------------------------------------------------------------------

      integer i, j

!	Make sure that a buffer is defined (JG)
!	----------------------------------
	if(i90_depth <= 0) then
	  iret = -1
	  return
	endif

      if ( i90_now%next_line .ge. i90_now%nbuf ) then
         iret = -1
         return
      end if

      i = i90_now%next_line
      j = i + index(i90_now%buffer(i:i90_now%nbuf),EOL) - 2
      i90_now%this_line = i90_now%buffer(i:j) // BLK // EOL

      if ( i90_now%this_line(1:2) .eq. '::' ) then
           iret = 1                        ! end of table
           i90_now%next_line = i90_now%nbuf + 1
           return
      end if

      i90_now%next_line = j + 2
      iret = 0

      return
      end subroutine i90_gline

!...................................................................

      subroutine i90_GToken ( token, iret )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE:  I90_GToken()  --- Gets next token.
!
! !DESCRIPTION:
!
!  Get next token from current line. The current line is defined by a
!  call to {\tt i90\_label()}. Tokens are sequences of characters (including
!  blanks) which may be enclosed by single or double quotes.
!  If no quotes are present, the token from the current position to the next
!  blank of TAB is returned.
!
!  {\em Examples of valid token:}
!
!  \begin{verbatim}
!               single_token "second token on line"
!               "this is a token"
!               'Another example of a token'
!               'this is how you get a " inside a token'
!               "this is how you get a ' inside a token"
!               This is valid too   # the line ends before the #
!  \end{verbatim}
!  The last line has 4 valid tokens: {\tt This, is, valid} and {\tt too}.
!
!  {\em Invalid string constructs:}
!
!  \begin{verbatim}
!               cannot handle mixed quotes (i.e. single/double)
!               'escaping like this \' is not implemented'
!               'this # will not work because of the #'
!  \end{verbatim}
!  The \# character is reserved for comments and cannot be included
!  inside quotation marks.
!
! !CALLING SEQUENCE:
!
!     call i90_GToken ( token, iret )
!
! !INPUT PARAMETERS:
!
!     None.
!
! !OUTPUT PARAMETERS:
!
      character*(*) token            ! Next token from current line
      integer       iret             ! Return code:
                                     !   0    no error
                                     !  -1    either nothing left
                                     !        on line or mismatched
                                     !        quotation marks.

! !BUGS:
!
!     Standard Unix escaping is not implemented at the moment.
!
!
! !SEE ALSO:
!
!  i90_label()    selects a line (record/table)
!  i90_gline()    get next line (for tables)
!  atof()         convert word (string) to float
!  atoi()         convert word (string) to integer
!
!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!
!EOP
!-------------------------------------------------------------------------

      character*1   ch
      integer       ib, ie

!	Make sure that a buffer is defined (JG)
!	----------------------------------
	if(i90_depth <= 0) then
	  iret = -1
	  return
	endif

      call i90_trim ( i90_now%this_line )

      ch = i90_now%this_line(1:1)
      if ( ch .eq. '"' .or. ch .eq. "'" ) then
           ib = 2
           ie = index ( i90_now%this_line(ib:), ch )
      else
           ib = 1
           ie = min(index(i90_now%this_line,BLK),	&
		    index(i90_now%this_line,EOL)) - 1

      end if

      if ( ie .lt. ib ) then
           token = BLK
           iret = -1
           return
      else
		! Get the token, and shift the rest of %this_line to
		! the left

           token = i90_now%this_line(ib:ie)
           i90_now%this_line = i90_now%this_line(ie+2:)
           iret = 0
      end if

      return
      end subroutine i90_gtoken
!...................................................................
      subroutine i90_gstr ( string, iret )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!
! !ROUTINE:  I90\_GStr()
!
! !DESCRIPTION:
!
!  Get next string from current line. The current line is defined by a
!  call to {\tt i90\_label()}. Strings are sequence of characters (including
!  blanks) enclosed by single or double quotes. If no quotes
!  are present, the string from the current position to the end of
!  the line is returned.
!
!  NOTE: This routine is defined differently from \verb"i90_GTolen()",
!	 where a {\sl token} is white-space delimited, but this routine
!	 will try to fetch a string either terminated by a "$" or by the
!	 end of the line.
!
!  {\em Examples of valid strings:}
!
!  \begin{verbatim}
!               "this is a string"
!               'Another example of string'
!               'this is how you get a " inside a string'
!               "this is how you get a ' inside a string"
!               This is valid too   # the line ends before the #
!
!  \end{verbatim}
!
!  {\em Invalid string constructs:}
!
!  \begin{verbatim}
!               cannot handle mixed quotes
!               'escaping like this \' is not implemented'
!  \end{verbatim}
!
!  {\em Obsolete feature (for Inpak 77 compatibility):}
!
!  \begin{verbatim}
!               the string ends after a $ this is another string
!  \end{verbatim}
!
! !CALLING SEQUENCE:
!
!  \begin{verbatim}
!     call i90_Gstr ( string, iret )
!  \end{verbatim}
!
! !INPUT PARAMETERS:
!
      character*(*) string           ! A NULL (char(0)) delimited string.

! !OUTPUT PARAMETERS:
!
      integer       iret             ! Return code:
                                     !   0    no error
                                     !  -1    either nothing left
                                     !        on line or mismatched
                                     !        quotation marks.

! !BUGS:
!
!     Standard Unix escaping is not implemented at the moment.
!     No way to tell sintax error from end of line (same iret).
!
!
! !SEE ALSO:
!
!  i90_label()    selects a line (record/table)
!  i90_gtoken()   get next token
!  i90_gline()    get next line (for tables)
!  atof()         convert word (string) to float
!  atoi()         convert word (string) to integer
!
!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!  01Oct96   Jing Guo	Removed the null terminitor
!
!-------------------------------------------------------------------------

      character*1   ch
      integer       ib, ie

!	Make sure that a buffer is defined (JG)
!	----------------------------------
	if(i90_depth <= 0) then
	  iret = -1
	  return
	endif

      call i90_trim ( i90_now%this_line )

      ch = i90_now%this_line(1:1)
      if ( ch .eq. '"' .or. ch .eq. "'" ) then
           ib = 2
           ie = index ( i90_now%this_line(ib:), ch )
      else
           ib = 1
           ie = index(i90_now%this_line,'$')-1  ! undocumented feature!
           if ( ie .lt. 1 ) ie = index(i90_now%this_line,EOL)-2
      end if

      if ( ie .lt. ib ) then
!         string = NULL
           iret = -1
           return
      else
           string = i90_now%this_line(ib:ie) ! // NULL
           i90_now%this_line = i90_now%this_line(ie+2:)
           iret = 0
      end if

      return
      end subroutine i90_gstr

!...................................................................

      real(FP) function i90_GFloat( iret )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE: i90_GFloat() --- Returns next float number.
!
! !DESCRIPTION:
!
!  Returns next float (real number) from the current line.
!  If an error occurs a zero value is returned.
!
! !CALLING SEQUENCE:
!
!      real  rnumber
!      rnumber = i90_gfloat ( default )
!
! !OUTPUT PARAMETERS:
!
      integer,intent(out) :: iret    ! Return code:
                                     !   0    no error
                                     !  -1    either nothing left
                                     !        on line or mismatched
                                     !        quotation marks.
                                     !  -2    parsing error

!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!
!EOP
!-------------------------------------------------------------------------

      character*256 token
      integer       ios
      real(FP)      x

!	Make sure that a buffer is defined (JG)
!	----------------------------------
	if(i90_depth <= 0) then
	  iret = -1
	  return
	endif

      call i90_gtoken ( token, iret )
      if ( iret .eq. 0 ) then
           read(token,*,iostat=ios) x	! Does it require an extension?
           if ( ios .ne. 0 ) iret = -2
      end if
      if ( iret .ne. 0 ) x = 0.
      i90_GFloat = x

      return
      end function i90_GFloat

!...................................................................

      integer function I90_GInt ( iret )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE: I90_GInt() --- Returns next integer number.
!
! !DESCRIPTION:
!
!  Returns next integer number from the current line.
!  If an error occurs a zero value is returned.
!
! !CALLING SEQUENCE:
!
!      integer number
!      number = i90_gint ( default )
!
! !OUTPUT PARAMETERS:
!
      integer       iret             ! Return code:
                                     !   0    no error
                                     !  -1    either nothing left
                                     !        on line or mismatched
                                     !        quotation marks.
                                     !  -2    parsing error

!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!  24may00   da Silva   delcared x as real*8 in case this module is compiled
!                       with real*4
!
!EOP
!-------------------------------------------------------------------------

      character*256 token
      real(kind_r8) x
      integer       ios

!	Make sure that a buffer is defined (JG)
!	----------------------------------
	if(i90_depth <= 0) then
	  iret = -1
	  return
	endif

      call i90_gtoken ( token, iret )
      if ( iret .eq. 0 ) then
           read(token,*,iostat=ios) x
           if ( ios .ne. 0 ) iret = -2
      end if
      if ( iret .ne. 0 ) x = 0
      i90_gint = nint(x)

      return
      end function i90_gint

!...................................................................

      real(FP) function i90_AtoF( string, iret )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE:  i90_AtoF() --- Translates ASCII (string) to float.
!
! !DESCRIPTION:
!
!     Converts string to real number. Same as obsolete {\tt str2rn()}.
!
! !CALLING SEQUENCE:
!
!     real  rnumber
!     rnumber = i90_atof ( string, iret )
!
! !INPUT PARAMETERS:
!
      character(len=*),intent(in) :: string           ! a string

! !OUTPUT PARAMETERS:
!
      integer,intent(out) :: iret    ! Return code:
                                     !   0    no error
                                     !  -1    could not convert, probably
                                     !        string is not a number

!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!
!EOP
!-------------------------------------------------------------------------

      read(string,*,end=11,err=11) i90_AtoF
      iret = 0
      return
 11   iret = -1
      return
      end function i90_AtoF

!...................................................................

      integer function i90_atoi ( string, iret )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE:  I90_AtoI() --- Translates ASCII (strings) to integer.
!
! !DESCRIPTION:
!
!     Converts string to integer number.
!
! !CALLING SEQUENCE:
!
!     integer number
!     number = i90_atoi ( string, iret )
!
! !INPUT PARAMETERS:
!
      character*(*) string           ! a string

! !OUTPUT PARAMETERS:
!
      integer       iret             ! Return code:
                                     !   0    no error
                                     !  -1    could not convert, probably
                                     !        string is not a number

!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!
!EOP
!-------------------------------------------------------------------------

      read(string,*,end=11,err=11) i90_atoi
      iret = 0
      return
 11   iret = -1
      return
      end function i90_atoi

!...................................................................

      integer function i90_Len ( string )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE:  I90_Len() --- Returns length of string.
!
! !DESCRIPTION:
!
!  Returns the length of a string excluding trailing blanks.
!  It follows that
!  \begin{verbatim}
!              i90_len(string) .le. len(string),
!  \end{verbatim}
!  where {\tt len} is the intrinsic string length function.
!  Example:
!  \begin{verbatim}
!         ls = len('abc  ')       ! results in ls = 5
!         ls = i90_len ('abc  ')  ! results in ls = 3
!  \end{verbatim}
!
! !CALLING SEQUENCE:
!
!       integer ls
!       ls = i90_len ( string )
!
! !INPUT PARAMETERS:
!
         character*(*)   string     ! a string
!
! !OUTPUT PARAMETERS:
!
!        The length of the string, excluding trailing blanks.
!
! !REVISION HISTORY:
!
!  01Apr94   Guo        Original code (a.k.a. luavail())
!  19Jun96   da Silva   Minor modification + prologue.
!
!EOP
!-------------------------------------------------------------------------

      integer ls, i, l
      ls = len(string)
      do i = ls, 1, -1
         l = i
         if ( string(i:i) .ne. BLK ) go to 11
      end do
      l = l - 1
 11   continue
      i90_len = l
      return
      end function i90_len

!...................................................................

      integer function I90_Lua()

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE:  I90_Lua() --- Returns available logical unit number.
!
! !DESCRIPTION:
!
!  Look for an available (not opened) Fortran logical unit for i/o.
!
! !CALLING SEQUENCE:
!
!       integer lu
!       lu = i90_lua()
!
! !INPUT PARAMETERS:
!
!       None.
!
! !OUTPUT PARAMETERS:
!
!       The desired unit number if positive, -1 if unsucessful.
!
! !REVISION HISTORY:
!
!  01Apr94   Guo        Original code (a.k.a. luavail())
!  19Jun96   da Silva   Minor modification + prologue.
!
!EOP
!-------------------------------------------------------------------------


      integer lu,ios
      logical opnd
      lu=7
      inquire(unit=lu,opened=opnd,iostat=ios)
      do while(ios.eq.0.and.opnd)
         lu=lu+1
         inquire(unit=lu,opened=opnd,iostat=ios)
      end do
      if(ios.ne.0) lu=-1
      i90_lua=lu
      return
      end function i90_lua

!...................................................................

      subroutine i90_pad ( string )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE:  I90_Pad() --- Pad strings.
!
! !DESCRIPTION:
!
!     Pads from the right with the comment character (\#). It also
!  replaces TABs with blanks for convenience. This is a low level
!  i90 routine.
!
! !CALLING SEQUENCE:
!
!      call i90_pad ( string )
!
! !INPUT PARAMETERS:
!
       character*256 string       ! input string

! !OUTPUT PARAMETERS:            ! modified string
!
!      character*256 string
!
! !BUGS:
!
!      It alters TABs even inside strings.
!
!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!
!EOP
!-------------------------------------------------------------------------

      integer i

!     Pad end of string with #
!     ------------------------
      do i = 256, 1, -1
         if ( string(i:i) .ne. ' ' .and.	&
	        string(i:i) .ne. '$' ) go to 11
         string(i:i) = '#'
      end do
 11   continue

!     Replace TABs with blanks
!     -------------------------
      do i = 1, 256
         if ( string(i:i) .eq. TAB ) string(i:i) = BLK
         if ( string(i:i) .eq. '#' ) go to 21
      end do
 21   continue

      return
      end subroutine i90_pad

!...................................................................

      subroutine I90_Trim ( string )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE:  I90_Trim() - Removes leading blanks from strings.
!
! !DESCRIPTION:
!
!    Removes blanks and TABS from begenning of string.
!    This is a low level i90 routine.
!
! !CALLING SEQUENCE:
!
!     call i90_Trim ( string )
!
! !INPUT PARAMETERS:
!
      character*256 string    ! the input string
!
! !OUTPUT PARAMETERS:
!
!     character*256 string    ! the modified string
!
!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!
!EOP
!-------------------------------------------------------------------------

      integer     ib, i

!     Get rid of leading blanks
!     -------------------------
      ib = 1
      do i = 1, 255
         if ( string(i:i) .ne. ' ' .and.	&
	        string(i:i) .ne. TAB ) go to 21
         ib = ib + 1
      end do
 21   continue

!     String without trailling blanks
!     -------------------------------
      string = string(ib:)

      return
      end subroutine i90_trim


!==========================================================================


!                        -----------------------------
!                        Inpak 77 Upward Compatibility
!                        -----------------------------


      subroutine lablin ( label )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE:  Lablin() --- Selects a Label (Inpak 77)
!
! !DESCRIPTION:
!
!    Selects a given ``line'' (record/table) associated with ``label''.
!    Similar to {\tt i90\_label()}, but prints a message to {\tt stdout}
!    if it cannot locate the label. Kept for Inpak 77 upward compatibility.
!
! !CALLING SEQUENCE:
!
!     call lablin ( label )
!
! !INPUT PARAMETERS:

      character(len=*),intent(in) :: label   ! string with label name
!
! !OUTPUT PARAMETERS:
!
!    None.
!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!
!EOP
!-------------------------------------------------------------------------

      integer       iret

      call i90_label ( label, iret )
      if ( iret .ne. 0 ) then
	write(stderr,'(2a)') 'i90/lablin: cannot find label ', label
      endif

      end subroutine lablin

!...................................................................

      real(SP) function fltgetsp ( default )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE: FltGetsp() --- Returns next float (Inpak 77, single precision)
!
! !DESCRIPTION:
!
!  Returns next float (real number, single precision) from the current
!  line, or a default value if it fails to obtain the desired number.
!  Kept for Inpak 77 upward compatibility.
!
! !CALLING SEQUENCE:
!
!      real  rnumber, default
!      rnumber = fltgetsp ( default )
!
! !INPUT PARAMETERS:
!
      real(SP), intent(IN) ::    default       ! default value.

!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!  12Oct99   Guo/Larson - Built from original FltGet() function.
!
!EOP
!-------------------------------------------------------------------------

      character*256 token
      real(FP)      x
      integer       iret

      call i90_gtoken ( token, iret )
      if ( iret .eq. 0 ) then
           read(token,*,iostat=iret) x
      end if
      if ( iret .ne. 0 ) x = default
      !print *, x
      fltgetsp = x

      return
      end function fltgetsp

!...................................................................

      real(DP) function fltgetdp ( default )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE: FltGetdp() --- Returns next float (Inpak 77)
!
! !DESCRIPTION:
!
!  Returns next float (real number) from the current line, or a
!  default value (double precision) if it fails to obtain the desired
!  number.  Kept for Inpak 77 upward compatibility.
!
! !CALLING SEQUENCE:
!
!      real(DP) :: default
!      real :: rnumber
!      rnumber = FltGetdp(default)
!
! !INPUT PARAMETERS:
!
      real(DP), intent(IN) ::    default       ! default value.

!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!  12Oct99   Guo/Larson - Built from original FltGet() function.
!
!EOP
!-------------------------------------------------------------------------

      character*256 token
      real(FP)          x
      integer       iret

      call i90_gtoken ( token, iret )
      if ( iret .eq. 0 ) then
           read(token,*,iostat=iret) x
      end if
      if ( iret .ne. 0 ) x = default
      !print *, x
      fltgetdp = x

      return
      end function fltgetdp

!...................................................................

      integer function intget ( default )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE: IntGet() --- Returns next integer (Inpak 77).
!
! !DESCRIPTION:
!
!  Returns next integer number from the current line, or a default
!  value if it fails to obtain the desired number.
!  Kept for Inpak 77 upward compatibility.
!
! !CALLING SEQUENCE:
!
!      integer number, default
!      number = intget ( default )
!
! !INPUT PARAMETERS:
!
       integer     default       ! default value.

!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!
!EOP
!-------------------------------------------------------------------------

      character*256 token
      real(FP)      x
      integer       iret

      call i90_gtoken ( token, iret )
      if ( iret .eq. 0 ) then
           read(token,*,iostat=iret) x
      end if
      if ( iret .ne. 0 ) x = default
      intget = nint(x)
      !print *, intget

      return
      end function intget

!...................................................................

      character(len=1) function chrget ( default )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE: ChrGet() --- Returns next character (Inpak 77).
!
! !DESCRIPTION:
!
!  Returns next non-blank character from the current line, or a default
!  character if it fails for whatever reason.
!  Kept for Inpak 77 upward compatibility.
!
! !CALLING SEQUENCE:
!
!     character*1 ch, default
!     ch = chrget ( default )
!
! !INPUT PARAMETERS:
!
      character*1    default       ! default value.

!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!
!EOP
!-------------------------------------------------------------------------

      character*256 token
      integer       iret

      call i90_gtoken ( token, iret )
      if ( iret .ne. 0 ) then
           chrget = default
      else
           chrget = token(1:1)
      end if
      !print *, chrget

      return
      end function chrget

!...................................................................

      subroutine TokGet ( token, default )

      implicit NONE


!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !ROUTINE: TokGet() --- Gets next token (Inpakk 77 like).
!
! !DESCRIPTION:
!
!  Returns next token from the current line, or a default
!  word if it fails for whatever reason.
!
! !CALLING SEQUENCE:
!
!      call TokGet ( token, default )
!
! !INPUT PARAMETERS:
!
       character*(*) default     ! default token

! !OUTPUT PARAMETERS:
!
       character*(*) token       ! desired token
!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!
!EOP
!-------------------------------------------------------------------------

      integer       iret

      call i90_GToken ( token, iret )
      if ( iret .ne. 0 ) then
           token = default
      end if
      !print *, token

      return
      end subroutine tokget

!====================================================================

!                          --------------------------
!                          Obsolete Inpak 77 Routines
!                              (Not Documented)
!                          --------------------------

!...................................................................

      subroutine iniin()
      print *, 		&
           'i90: iniin() is obsolete, use i90_loadf() instead!'
      return
      end subroutine iniin


!...................................................................

      subroutine iunits ( mifans, moftrm, moferr, miftrm )
      integer mifans, moftrm, moferr, miftrm
      print *, 		&
           'i90: iunits() is obsolete, use i90_loadf() instead!'
      return
      end subroutine iunits

!...................................................................

      subroutine getstr ( iret, string )
      implicit NONE
      character*(*) string
      integer       iret  !, ls
      call i90_gstr ( string, iret )
      return
      end subroutine getstr

!...................................................................

      subroutine getwrd ( iret, word )
      implicit NONE
      character*(*) word
      integer       iret
      call i90_gtoken ( word, iret )
      return
      end subroutine getwrd

!...................................................................

      subroutine rdnext ( iret )
      implicit NONE
      integer iret
      call i90_gline ( iret )
      return
      end subroutine rdnext

!...................................................................

      real(FP) function str2rn ( string, iret )
      implicit NONE
      character*(*) string
      integer iret
      read(string,*,end=11,err=11) str2rn
      iret = 0
      return
 11   iret = 1
      return
      end function str2rn

!...................................................................

      subroutine strget ( string, default )

      implicit NONE

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!
! !ROUTINE: StrGet()
!
! !DESCRIPTION:
!
!  Returns next string on the current line, or a default
!  string if it fails for whatever reason. Similar to {\tt i90\_gstr()}.
!  Kept for Inpak 77 upward compatibility.
!
!  NOTE: This is an obsolete routine. The notion of "string" used
!        here is not conventional. Please use routine {\tt TokGet()}
!        instead.
!
! !CALLING SEQUENCE:
!
!      call strget ( string, default )
!
! !INPUT PARAMETERS:
!
       character*(*) default      ! default string

! !OUTPUT PARAMETERS:

       character*(*) string       ! desired string

!
! !REVISION HISTORY:
!
!  19Jun96   da Silva   Original code.
!  01Oct96   Jing Guo   Removed the null terminitor
!
!-------------------------------------------------------------------------

      integer iret

      call i90_gstr ( string, iret )
      if ( iret .ne. 0 ) then
           string = default
      end if

      return
      end subroutine strget


end module m_inpak90
