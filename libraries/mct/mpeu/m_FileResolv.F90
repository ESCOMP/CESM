!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!-----------------------------------------------------------------------
!BOP
!
! !MODULE:  m_FileResolv --- Resolve file name templates
!
! !INTERFACE:
!

   MODULE  m_FileResolv

! !USES:

   use  m_StrTemplate  ! grads style templates
   use  m_die
   Implicit NONE

!
! !PUBLIC MEMBER FUNCTIONS:
!
   PRIVATE
   PUBLIC  FileResolv
   PUBLIC  remote_cp
   PUBLIC  gunzip
!
! !DESCRIPTION: This module provides routines for resolving GrADS like
!               file name templates.
!
! !REVISION HISTORY:
!
!  10Jan2000 da Silva  Initial code.
!
!EOP
!-------------------------------------------------------------------------

  character(len=255) :: remote_cp = 'rcp'
  character(len=255) ::    gunzip = 'gunzip'

CONTAINS

!-------------------------------------------------------------------------
!         NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-------------------------------------------------------------------------
!BOP
!
! !IROUTINE: FileResolv -- Resolve file name templates (single file)
!
! !INTERFACE:
!
    subroutine FileResolv ( expid, nymd, nhms, templ, fname, &
                            stat, cache )

! !USES:

    IMPLICIT NONE

!
! !INPUT PARAMETERS:
!
    character(len=*), intent(in) :: expid          ! Experiment id
    integer,          intent(in) :: nymd           ! Year-month-day
    integer,          intent(in) :: nhms           ! Hour-min-sec
    character(len=*), intent(in) :: templ       ! file name template

!
! !OUTPUT PARAMETERS:
!
    character(len=*),  intent(out) :: fname        ! resolved file name

    integer, OPTIONAL, intent(out) :: stat         ! Status
                                                   !  0 - file exists
                                                   !  1 - file does not exist

    logical, OPTIONAL, intent(in) :: cache         ! skips rcp/gunzip if
                                                   ! file exists locally

! !DESCRIPTION: Resolve file name templates, rcp'ing files from remote and
!               performing gunzip'ing as necessary.
!
! !TO DO:
!         1. Expand environment variables in templates
!
! !REVISION HISTORY:
!
! 10Jan2000  da Silva  Initial code,
! 23Jul2002  J. Larson <larson@mcs.anl.gov> - fixed bug detected by the
!            Fujitsu frt compiler (on the VPP).
!
!EOP
!--------------------------------------------------------------------------

   character(len=*), parameter	:: myname = 'MCT(MPEU)::FileResolv'

#if SYSUNICOS || CPRCRAY
   integer, external  :: ishell
#elif (!defined __GFORTRAN__)
   integer, external  :: system
#endif
   character(len=255) :: path, host, dirn, basen, head, tail, cmd, filen

   integer i, rc
   logical :: fexists, caching


!  Default is cache = .true.
!  -------------------------
   if ( present(cache) ) then
        caching = cache
   else
        caching = .TRUE.
   end if

!  Start by expanding template
!  ---------------------------
   call strTemplate ( path, templ, 'GRADS', trim(expid), nymd, nhms, rc )
   if ( rc .ne. 0 ) then
        if ( present(stat) ) then
             stat = 1
             return
        else
             call die ( myname, 'cannot expand template '//trim(templ) )
        end if
   end if


!  Parse file name
!  ---------------
   i = index ( trim(path), ':' )
   if ( i .gt. 0 ) then
        host  = path(1:i-1)
        fname = path(i+1:)
   else
        host = ''
        fname = path
   end if
   i = index ( trim(fname), '/', back=.true. )
   if ( i .gt. 1 ) then
        dirn  = fname(1:i-1)
        basen = fname(i+1:)
   else if ( i .gt. 0 ) then
        dirn  = fname(1:i)
        basen = fname(i+1:)
   else
        dirn  = ''
        basen = fname
   end if
   i = index ( basen, '.', back=.true. )
   if ( i .gt. 0 ) then
      head = basen(1:i-1)
      tail = basen(i+1:)
   else
      head = basen
      tail = ''
   end if

!   print *, 'Template = |'//trim(templ)//'|'
!   print *, '   path  = |'//trim(path)//'|'
!   print *, '   host  = |'//trim(host)//'|'
!   print *, '   dirn  = |'//trim(dirn)//'|'
!   print *, '   basen = |'//trim(basen)//'|'
!   print *, '   head  = |'//trim(head)//'|'
!   print *, '   tail  = |'//trim(tail)//'|'
!   print *, '   fname = |'//trim(fname)//'|'


!  If file is remote, bring it here
!  --------------------------------
   if ( len_trim(host) .gt. 0 ) then
      if ( trim(tail) .eq. 'gz' ) then
           inquire ( file=trim(head),  exist=fexists )
           filen = head
      else
           inquire ( file=trim(basen), exist=fexists )
           filen = basen
      end if
      if ( .not. ( fexists .and. caching ) ) then
         cmd = trim(remote_cp) // ' ' // &
               trim(host) // ':' // trim(fname) // ' . '
#if SYSUNICOS || CPRCRAY
         rc = ishell ( cmd )
#else
         rc = system ( cmd )
#endif

         if ( rc .eq. 0 ) then
            fname = basen
         else
            if ( present(stat) ) then ! return an error code
               stat = 2
               return
	    else ! shut down
               fname = basen
               call die ( myname, 'cannot execute: '//trim(cmd) )
            end if
         end if
       else
         fname = filen
         call warn(myname,'using cached version of '//trim(filen) )
       end if


!  If not, make sure file exists locally
!  -------------------------------------
   else

      inquire ( file=trim(fname), exist=fexists )
      if ( .not. fexists ) then
           if ( present(stat) ) then
              stat = 3
           else
              call die(myname,'cannot find '//trim(fname) )
           end if
      end if

   end if


!  If file is gzip'ed, leave original alone and create uncompressed
!  version in the local directory
!  ----------------------------------------------------------------
   if ( trim(tail) .eq. 'gz' ) then
      inquire ( file=trim(head), exist=fexists ) ! do we have a local copy?
      if ( .not. ( fexists .and. caching ) ) then
        if ( len_trim(host) .gt. 0 ) then             ! remove file.gz
             cmd = trim(gunzip) // ' -f ' // trim(fname)
        else                                          ! keep   file.gz
             cmd = trim(gunzip) // ' -c ' // trim(fname) // ' > ' // trim(head)
        end if
#if SYSUNICOS || CPRCRAY
        rc = ishell ( cmd )
#else
        rc = system ( cmd )
#endif
        if ( rc .eq. 0 ) then
           fname = head
        else
           if ( present(stat) ) then
              stat = 4
              return
           else
              call die ( myname, 'cannot execute: '//trim(cmd) )
           end if
        end if
       else
         fname = head
         call warn(myname,'using cached version of '//trim(head) )
       end if
    end if


!   Once more, make sure file exists
!   --------------------------------
    inquire ( file=trim(fname), exist=fexists )
    if ( .not. fexists ) then
       if ( present(stat) ) then
          stat = 3
       else
          call die(myname,'cannot find '//trim(fname) )
       end if
    end if


!   All done
!   --------
    if ( present(stat) ) stat = 0

  end subroutine FileResolv

  end MODULE m_FileResolv
