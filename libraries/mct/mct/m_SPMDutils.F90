!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_SPMDutils -- Communication operators to address performance
!                         issues for specific communication patterns
!
! !DESCRIPTION:
! This module provides the swapm equivalent to MPI_Alltoallv that
! has proven to be more robust with respect to performance than the
! MPI collective or the native MCT communication algorithms when the
! communication pattern is sparse and when load imbalance or send/receive
! asymmetry leads some processes to be flooded by unexpected messages.
!
! Based on algorithms implemented in CAM, but this version modelled after
! pio_spmd_utils.F90 in PIO1
!
! !SEE ALSO:
!  m_Rearranger
!
!
! !INTERFACE:

! Disable the use of the MPI ready send protocol by default, to
! address recurrent issues with poor performance or incorrect
! functionality in MPI libraries. When support is known to be robust,
! or for experimentation, can be re-enabled by defining the CPP token
! _USE_MPI_RSEND during the build process.
!
#ifndef _USE_MPI_RSEND
#define MPI_RSEND MPI_SEND
#define mpi_rsend mpi_send
#define MPI_IRSEND MPI_ISEND
#define mpi_irsend mpi_isend
#endif

 module m_SPMDutils

      implicit none

      private	! except

! !PUBLIC MEMBER FUNCTIONS:

      public :: m_swapm_int  ! swapm alternative to MPI_AlltoallV for integer data
      public :: m_swapm_FP   ! swapm alternative to MPI_AlltoallV for FP data

! !DEFINED PARAMETERS:

  character(len=*), parameter :: myname='MCT::m_SPMDutils'

! !REVISION HISTORY:
! 28Sep16 - P. Worley <worleyph@gmail.com> - initial prototype
!EOP ___________________________________________________________________

 contains

!========================================================================
!

   integer function pair(np,p,k)

      integer np,p,k,q
      q = ieor(p,k)
      if(q.gt.np-1) then
         pair = -1
      else
         pair = q
      endif
      return

   end function pair

!
!========================================================================
!

  integer function ceil2(n)
     integer n,p
     p=1
     do while(p.lt.n)
        p=p*2
     enddo
     ceil2=p
     return
  end function ceil2

!
!========================================================================
!
   subroutine m_swapm_int ( nprocs, mytask,      &
      sndbuf, sbuf_siz, sndlths, sdispls, stypes,  &
      rcvbuf, rbuf_siz, rcvlths, rdispls, rtypes,  &
      comm, comm_hs, comm_isend, comm_maxreq       )

!-----------------------------------------------------------------------
!
!> Purpose:
!!   Reduced version of original swapm (for swap of multiple messages
!!   using MPI point-to-point routines), more efficiently implementing a
!!   subset of the swap protocols.
!!
!! Method:
!! comm_protocol:
!!  comm_isend == .true.: use nonblocking send, else use blocking send
!!  comm_hs == .true.: use handshaking protocol
!! comm_maxreq:
!!  =-1,0: do not limit number of outstanding send/receive requests
!!     >0: do not allow more than min(comm_maxreq, steps) outstanding
!!         nonblocking send requests or nonblocking receive requests
!!
!! Author of original version:  P. Worley
!! Ported from PIO1: P. Worley, September 2016
!<
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
   use m_mpif90
   use m_realkinds, only : FP
   use m_die,       only : MP_perr_die

   implicit none
!---------------------------Input arguments--------------------------
!
   integer, intent(in)   :: nprocs             ! size of communicator
   integer, intent(in)   :: mytask             ! MPI task id with communicator
   integer, intent(in)   :: sbuf_siz           ! size of send buffer
   integer, intent(in)   :: rbuf_siz           ! size of receive buffer

   integer, intent(in)   :: sndlths(0:nprocs-1)! length of outgoing message
   integer, intent(in)   :: sdispls(0:nprocs-1)! offset from beginning of send
                                               !  buffer where outgoing messages
                                               !  should be sent from
   integer, intent(in)   :: stypes(0:nprocs-1) ! MPI data types
   integer, intent(in)   :: rcvlths(0:nprocs-1)! length of incoming messages
   integer, intent(in)   :: rdispls(0:nprocs-1)! offset from beginning of receive
                                               !  buffer where incoming messages
                                               !  should be placed
   integer, intent(in)   :: rtypes(0:nprocs-1) ! MPI data types
   integer, intent(in)   :: sndbuf(sbuf_siz)   ! outgoing message buffer

   integer, intent(in)   :: comm               ! MPI communicator
   logical, intent(in)   :: comm_hs            ! handshaking protocol?
   logical, intent(in)   :: comm_isend         ! nonblocking send protocol?
   integer, intent(in)   :: comm_maxreq        ! maximum number of outstanding
                                               !  nonblocking requests

!---------------------------Output arguments--------------------------
!
   integer, intent(out)  :: rcvbuf(rbuf_siz)   ! incoming message buffer

!
!---------------------------Local workspace-------------------------------------------
!
   character(len=*), parameter :: subName=myname//'::m_swapm_int'

   integer :: steps                            ! number of swaps to initiate
   integer :: swapids(nprocs)                  ! MPI process id of swap partners
   integer :: p                                ! process index
   integer :: istep                            ! loop index
   integer :: tag                              ! MPI message tag
   integer :: offset_t                         ! MPI message tag offset, for addressing
                                               !  message conflict bug (if necessary)
   integer :: offset_s                         ! index of message beginning in
                                               !  send buffer
   integer :: offset_r                         ! index of message beginning in
                                               !  receive buffer
   integer :: sndids(nprocs)                   ! send request ids
   integer :: rcvids(nprocs)                   ! receive request ids
   integer :: hs_rcvids(nprocs)                ! handshake receive request ids

   integer :: maxreq, maxreqh                  ! maximum number of outstanding
                                               !  nonblocking requests (and half)
   integer :: hs                               ! handshake variable
   integer :: rstep                            ! "receive" step index

   logical :: handshake, sendd                 ! protocol option flags

   integer :: ier                              ! return error status
   integer :: status(MP_STATUS_SIZE)           ! MPI status
!
!-------------------------------------------------------------------------------------
!
#ifdef _NO_M_SWAPM_TAG_OFFSET
   offset_t = 0
#else
   offset_t = nprocs
#endif
!
   ! if necessary, send to self
   if (sndlths(mytask) > 0) then
      tag = mytask + offset_t

      offset_r = rdispls(mytask)+1
      call mpi_irecv( rcvbuf(offset_r), rcvlths(mytask), rtypes(mytask), &
                      mytask, tag, comm, rcvids(1), ier )
      if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)

      offset_s = sdispls(mytask)+1
      call mpi_send( sndbuf(offset_s), sndlths(mytask), stypes(mytask), &
                     mytask, tag, comm, ier )
      if(ier /= 0) call MP_perr_die(subName,'MPI_SEND',ier)

      call mpi_wait( rcvids(1), status, ier )
      if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
   endif

   ! calculate swap partners and communication ordering
   steps = 0
   do istep=1,ceil2(nprocs)-1
      p = pair(nprocs,istep,mytask)
      if (p >= 0) then
         if (sndlths(p) > 0 .or. rcvlths(p) > 0) then
            steps = steps + 1
            swapids(steps) = p
         end if
      end if
   end do

   if (steps .eq. 0) return

   ! identify communication protocol
   if (comm_isend) then
      sendd = .false.
   else
      sendd = .true.
   endif
   handshake = comm_hs

   ! identify maximum number of outstanding nonblocking requests to permit
   if (steps .eq. 1) then
      maxreq  = 1
      maxreqh = 1
   else
      if (comm_maxreq >= -1) then
         maxreq = comm_maxreq
      else
         maxreq = steps
      endif

      if ((maxreq .le. steps) .and. (maxreq > 0)) then
         if (maxreq > 1) then
            maxreqh = maxreq/2
         else
            maxreq  = 2
            maxreqh = 1
         endif
      else
         maxreq  = steps
         maxreqh = steps
      endif
   endif

! Four protocol options:
!  (1) handshaking + blocking sends
   if ((handshake) .and. (sendd)) then

      ! Initialize hs variable
      hs = 1

      ! Post initial handshake receive requests
      do istep=1,maxreq
         p = swapids(istep)
         if (sndlths(p) > 0) then
            tag = mytask + offset_t
            call mpi_irecv( hs, 1, MP_INTEGER, p, tag, comm, &
                            hs_rcvids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
         endif
      enddo

      ! Post initial receive requests
      do istep=1,maxreq
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            tag = p + offset_t

            offset_r = rdispls(p)+1
            call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                            p, tag, comm, rcvids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)

            call mpi_send ( hs, 1, MP_INTEGER, p, tag, comm, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_SEND',ier)
         endif
      enddo
      rstep = maxreq

      ! Send (and start receiving) data
      do istep=1,steps
         p = swapids(istep)

         ! Submit new rsend request
         if (sndlths(p) > 0) then
            tag = mytask + offset_t

            offset_s = sdispls(p)+1
            call mpi_wait  ( hs_rcvids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)

            call mpi_rsend ( sndbuf(offset_s), sndlths(p), stypes(p), &
                             p, tag, comm, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_RSEND',ier)
         endif

         if (istep > maxreqh) then

            ! Wait for oldest irecv request to complete
            p = swapids(istep-maxreqh)
            if (rcvlths(p) > 0) then
               call mpi_wait( rcvids(istep-maxreqh), status, ier )
               if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
            endif

            if (rstep < steps) then
               rstep = rstep + 1
               p = swapids(rstep)

               ! Submit a new handshake irecv request
               if (sndlths(p) > 0) then
                  tag = mytask + offset_t
                  call mpi_irecv( hs, 1, MP_INTEGER, p, tag, comm, &
                                  hs_rcvids(rstep), ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
               endif

               ! Submit a new irecv request
               if (rcvlths(p) > 0) then
                  tag = p + offset_t

                  offset_r = rdispls(p)+1
                  call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                                  p, tag, comm, rcvids(rstep), ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)

                  call mpi_send ( hs, 1, MP_INTEGER, p, tag, comm, ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_SEND',ier)
               endif
            endif

         endif
!
      enddo

      ! wait for rest of receive requests to complete
      do istep=steps-maxreqh+1,steps
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            call mpi_wait( rcvids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
         endif
      enddo

!  (2) handshaking + nonblocking sends
   elseif ((handshake) .and. (.not. sendd)) then

      ! Initialize hs variable
      hs = 1

      ! Post initial handshake receive requests
      do istep=1,maxreq
         p = swapids(istep)
         if (sndlths(p) > 0) then
            tag = mytask + offset_t
            call mpi_irecv( hs, 1, MP_INTEGER, p, tag, comm, &
                            hs_rcvids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
         endif
      enddo

      ! Post initial receive requests
      do istep=1,maxreq
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            tag = p + offset_t

            offset_r = rdispls(p)+1
            call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                            p, tag, comm, rcvids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)

            call mpi_send ( hs, 1, MP_INTEGER, p, tag, comm, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_SEND',ier)
         endif
      enddo
      rstep = maxreq

      ! Send (and start receiving) data
      do istep=1,steps
         p = swapids(istep)

         ! Submit new irsend request
         if (sndlths(p) > 0) then
            tag = mytask + offset_t

            offset_s = sdispls(p)+1
            call mpi_wait  ( hs_rcvids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)

            call mpi_irsend( sndbuf(offset_s), sndlths(p), stypes(p), &
                             p, tag, comm, sndids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRSEND',ier)
         endif

         if (istep > maxreqh) then

            ! Wait for oldest irecv request to complete
            p = swapids(istep-maxreqh)
            if (rcvlths(p) > 0) then
               call mpi_wait( rcvids(istep-maxreqh), status, ier )
               if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
            endif

            if (rstep < steps) then
               rstep = rstep + 1
               p = swapids(rstep)

               ! Submit a new handshake irecv request
               if (sndlths(p) > 0) then
                  tag = mytask + offset_t
                  call mpi_irecv( hs, 1, MP_INTEGER, p, tag, comm, &
                                  hs_rcvids(rstep), ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
               endif

               ! Submit a new irecv request
               if (rcvlths(p) > 0) then
                  tag = p + offset_t

                  offset_r = rdispls(p)+1
                  call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                                  p, tag, comm, rcvids(rstep), ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)

                  call mpi_send ( hs, 1, MP_INTEGER, p, tag, comm, ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_SEND',ier)
               endif
            endif

            ! Wait for outstanding i(r)send request to complete
            p = swapids(istep-maxreqh)
            if (sndlths(p) > 0) then
               call mpi_wait( sndids(istep-maxreqh), status, ier )
               if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
            endif

         endif

      enddo

      ! wait for rest of send and receive requests to complete
      do istep=steps-maxreqh+1,steps
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            call mpi_wait( rcvids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
         endif
         if (sndlths(p) > 0) then
            call mpi_wait( sndids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
         endif
      enddo

!  (3) no handshaking + blocking sends
   elseif ((.not. handshake) .and. (sendd)) then

      ! Post receive requests
      do istep=1,maxreq
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            tag = p + offset_t

            offset_r = rdispls(p)+1
            call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                            p, tag, comm, rcvids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
         endif
      enddo
      rstep = maxreq

      ! Send (and start receiving) data
      do istep=1,steps
         p = swapids(istep)

         ! Submit new send request
         if (sndlths(p) > 0) then
            tag = mytask + offset_t

            offset_s = sdispls(p)+1
            call mpi_send( sndbuf(offset_s), sndlths(p), stypes(p), &
                           p, tag, comm, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_SEND',ier)
         endif

         if (istep > maxreqh) then

            ! Wait for oldest irecv request to complete
            p = swapids(istep-maxreqh)
            if (rcvlths(p) > 0) then
               call mpi_wait( rcvids(istep-maxreqh), status, ier )
               if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
            endif

            ! Submit a new irecv request
            if (rstep < steps) then
               rstep = rstep + 1
               p = swapids(rstep)
               if (rcvlths(p) > 0) then
                  tag = p + offset_t

                  offset_r = rdispls(p)+1
                  call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                                  p, tag, comm, rcvids(rstep), ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
               endif
            endif

         endif

      enddo

      ! wait for rest of send and receive requests to complete
      do istep=steps-maxreqh+1,steps
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            call mpi_wait( rcvids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
         endif
      enddo

!  (4) no handshaking + nonblocking sends
   elseif ((.not. handshake) .and. (.not. sendd)) then

      ! Post receive requests
      do istep=1,maxreq
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            tag = p + offset_t

            offset_r = rdispls(p)+1
            call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                            p, tag, comm, rcvids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
         endif
      enddo
      rstep = maxreq

      ! Send (and start receiving) data
      do istep=1,steps
         p = swapids(istep)

         ! Submit new isend request
         if (sndlths(p) > 0) then
            tag = mytask + offset_t

            offset_s = sdispls(p)+1
            call mpi_isend( sndbuf(offset_s), sndlths(p), stypes(p), &
                            p, tag, comm, sndids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_ISEND',ier)
         endif

         if (istep > maxreqh) then

            ! Wait for oldest irecv request to complete
            p = swapids(istep-maxreqh)
            if (rcvlths(p) > 0) then
               call mpi_wait( rcvids(istep-maxreqh), status, ier )
               if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
            endif

            ! Submit a new irecv request
            if (rstep < steps) then
               rstep = rstep + 1
               p = swapids(rstep)
               if (rcvlths(p) > 0) then
                  tag = p + offset_t

                  offset_r = rdispls(p)+1
                  call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                                  p, tag, comm, rcvids(rstep), ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
               endif
            endif

            ! Wait for outstanding i(r)send request to complete
            p = swapids(istep-maxreqh)
            if (sndlths(p) > 0) then
               call mpi_wait( sndids(istep-maxreqh), status, ier )
               if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
            endif

         endif

      enddo

      ! wait for rest of send and receive requests to complete
      do istep=steps-maxreqh+1,steps
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            call mpi_wait( rcvids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
         endif
         if (sndlths(p) > 0) then
            call mpi_wait( sndids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
         endif
      enddo

   endif

   return

   end subroutine m_swapm_int

!
!========================================================================
!
   subroutine m_swapm_FP ( nprocs, mytask,   &
      sndbuf, sbuf_siz, sndlths, sdispls, stypes,  &
      rcvbuf, rbuf_siz, rcvlths, rdispls, rtypes,  &
      comm, comm_hs, comm_isend, comm_maxreq       )

!-----------------------------------------------------------------------
!
!> Purpose:
!!   Reduced version of original swapm (for swap of multiple messages
!!   using MPI point-to-point routines), more efficiently implementing a
!!   subset of the swap protocols.
!!
!! Method:
!! comm_protocol:
!!  comm_isend == .true.: use nonblocking send, else use blocking send
!!  comm_hs == .true.: use handshaking protocol
!! comm_maxreq:
!!  =-1,0: do not limit number of outstanding send/receive requests
!!     >0: do not allow more than min(comm_maxreq, steps) outstanding
!!         nonblocking send requests or nonblocking receive requests
!!
!! Author of original version:  P. Worley
!! Ported from PIO1: P. Worley, September 2016
!<
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
   use m_mpif90
   use m_realkinds, only : FP
   use m_die,       only : MP_perr_die

   implicit none
!---------------------------Input arguments--------------------------
!
   integer, intent(in)   :: nprocs             ! size of communicator
   integer, intent(in)   :: mytask             ! MPI task id with communicator
   integer, intent(in)   :: sbuf_siz           ! size of send buffer
   integer, intent(in)   :: rbuf_siz           ! size of receive buffer

   integer, intent(in)   :: sndlths(0:nprocs-1)! length of outgoing message
   integer, intent(in)   :: sdispls(0:nprocs-1)! offset from beginning of send
                                               !  buffer where outgoing messages
                                               !  should be sent from
   integer, intent(in)   :: stypes(0:nprocs-1) ! MPI data types
   integer, intent(in)   :: rcvlths(0:nprocs-1)! length of incoming messages
   integer, intent(in)   :: rdispls(0:nprocs-1)! offset from beginning of receive
                                               !  buffer where incoming messages
                                               !  should be placed
   integer, intent(in)   :: rtypes(0:nprocs-1) ! MPI data types
   real(FP),intent(in)   :: sndbuf(sbuf_siz)   ! outgoing message buffer

   integer, intent(in)   :: comm               ! MPI communicator
   logical, intent(in)   :: comm_hs            ! handshaking protocol?
   logical, intent(in)   :: comm_isend         ! nonblocking send protocol?
   integer, intent(in)   :: comm_maxreq        ! maximum number of outstanding
                                               !  nonblocking requests

!---------------------------Output arguments--------------------------
!
   real(FP), intent(out)  :: rcvbuf(rbuf_siz)   ! incoming message buffer

!
!---------------------------Local workspace-------------------------------------------
!
   character(len=*), parameter :: subName=myname//'::m_swapm_FP'

   integer :: steps                            ! number of swaps to initiate
   integer :: swapids(nprocs)                  ! MPI process id of swap partners
   integer :: p                                ! process index
   integer :: istep                            ! loop index
   integer :: tag                              ! MPI message tag
   integer :: offset_t                         ! MPI message tag offset, for addressing
                                               !  message conflict bug (if necessary)
   integer :: offset_s                         ! index of message beginning in
                                               !  send buffer
   integer :: offset_r                         ! index of message beginning in
                                               !  receive buffer
   integer :: sndids(nprocs)                   ! send request ids
   integer :: rcvids(nprocs)                   ! receive request ids
   integer :: hs_rcvids(nprocs)                ! handshake receive request ids

   integer :: maxreq, maxreqh                  ! maximum number of outstanding
                                               !  nonblocking requests (and half)
   integer :: hs                               ! handshake variable
   integer :: rstep                            ! "receive" step index

   logical :: handshake, sendd                 ! protocol option flags

   integer :: ier                              ! return error status
   integer :: status(MP_STATUS_SIZE)           ! MPI status
!
!-------------------------------------------------------------------------------------
!
#ifdef _NO_M_SWAPM_TAG_OFFSET
   offset_t = 0
#else
   offset_t = nprocs
#endif
!
   ! if necessary, send to self
   if (sndlths(mytask) > 0) then
      tag = mytask + offset_t

      offset_r = rdispls(mytask)+1
      call mpi_irecv( rcvbuf(offset_r), rcvlths(mytask), rtypes(mytask), &
                      mytask, tag, comm, rcvids(1), ier )
      if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)

      offset_s = sdispls(mytask)+1
      call mpi_send( sndbuf(offset_s), sndlths(mytask), stypes(mytask), &
                     mytask, tag, comm, ier )
      if(ier /= 0) call MP_perr_die(subName,'MPI_SEND',ier)

      call mpi_wait( rcvids(1), status, ier )
      if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
   endif

   ! calculate swap partners and communication ordering
   steps = 0
   do istep=1,ceil2(nprocs)-1
      p = pair(nprocs,istep,mytask)
      if (p >= 0) then
         if (sndlths(p) > 0 .or. rcvlths(p) > 0) then
            steps = steps + 1
            swapids(steps) = p
         end if
      end if
   end do

   if (steps .eq. 0) return

   ! identify communication protocol
   if (comm_isend) then
      sendd = .false.
   else
      sendd = .true.
   endif
   handshake = comm_hs

   ! identify maximum number of outstanding nonblocking requests to permit
   if (steps .eq. 1) then
      maxreq  = 1
      maxreqh = 1
   else
      if (comm_maxreq >= -1) then
         maxreq = comm_maxreq
      else
         maxreq = steps
      endif

      if ((maxreq .le. steps) .and. (maxreq > 0)) then
         if (maxreq > 1) then
            maxreqh = maxreq/2
         else
            maxreq  = 2
            maxreqh = 1
         endif
      else
         maxreq  = steps
         maxreqh = steps
      endif
   endif

! Four protocol options:
!  (1) handshaking + blocking sends
   if ((handshake) .and. (sendd)) then

      ! Initialize hs variable
      hs = 1

      ! Post initial handshake receive requests
      do istep=1,maxreq
         p = swapids(istep)
         if (sndlths(p) > 0) then
            tag = mytask + offset_t
            call mpi_irecv( hs, 1, MP_INTEGER, p, tag, comm, &
                            hs_rcvids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
         endif
      enddo

      ! Post initial receive requests
      do istep=1,maxreq
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            tag = p + offset_t

            offset_r = rdispls(p)+1
            call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                            p, tag, comm, rcvids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)

            call mpi_send ( hs, 1, MP_INTEGER, p, tag, comm, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_SEND',ier)
         endif
      enddo
      rstep = maxreq

      ! Send (and start receiving) data
      do istep=1,steps
         p = swapids(istep)

         ! Submit new rsend request
         if (sndlths(p) > 0) then
            tag = mytask + offset_t

            offset_s = sdispls(p)+1
            call mpi_wait  ( hs_rcvids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)

            call mpi_rsend ( sndbuf(offset_s), sndlths(p), stypes(p), &
                             p, tag, comm, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_RSEND',ier)
         endif

         if (istep > maxreqh) then

            ! Wait for oldest irecv request to complete
            p = swapids(istep-maxreqh)
            if (rcvlths(p) > 0) then
               call mpi_wait( rcvids(istep-maxreqh), status, ier )
               if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
            endif

            if (rstep < steps) then
               rstep = rstep + 1
               p = swapids(rstep)

               ! Submit a new handshake irecv request
               if (sndlths(p) > 0) then
                  tag = mytask + offset_t
                  call mpi_irecv( hs, 1, MP_INTEGER, p, tag, comm, &
                                  hs_rcvids(rstep), ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
               endif

               ! Submit a new irecv request
               if (rcvlths(p) > 0) then
                  tag = p + offset_t

                  offset_r = rdispls(p)+1
                  call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                                  p, tag, comm, rcvids(rstep), ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)

                  call mpi_send ( hs, 1, MP_INTEGER, p, tag, comm, ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_SEND',ier)
               endif
            endif

         endif
!
      enddo

      ! wait for rest of receive requests to complete
      do istep=steps-maxreqh+1,steps
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            call mpi_wait( rcvids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
         endif
      enddo

!  (2) handshaking + nonblocking sends
   elseif ((handshake) .and. (.not. sendd)) then

      ! Initialize hs variable
      hs = 1

      ! Post initial handshake receive requests
      do istep=1,maxreq
         p = swapids(istep)
         if (sndlths(p) > 0) then
            tag = mytask + offset_t
            call mpi_irecv( hs, 1, MP_INTEGER, p, tag, comm, &
                            hs_rcvids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
         endif
      enddo

      ! Post initial receive requests
      do istep=1,maxreq
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            tag = p + offset_t

            offset_r = rdispls(p)+1
            call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                            p, tag, comm, rcvids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)

            call mpi_send ( hs, 1, MP_INTEGER, p, tag, comm, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_SEND',ier)
         endif
      enddo
      rstep = maxreq

      ! Send (and start receiving) data
      do istep=1,steps
         p = swapids(istep)

         ! Submit new irsend request
         if (sndlths(p) > 0) then
            tag = mytask + offset_t

            offset_s = sdispls(p)+1
            call mpi_wait  ( hs_rcvids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)

            call mpi_irsend( sndbuf(offset_s), sndlths(p), stypes(p), &
                             p, tag, comm, sndids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRSEND',ier)
         endif

         if (istep > maxreqh) then

            ! Wait for oldest irecv request to complete
            p = swapids(istep-maxreqh)
            if (rcvlths(p) > 0) then
               call mpi_wait( rcvids(istep-maxreqh), status, ier )
               if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
            endif

            if (rstep < steps) then
               rstep = rstep + 1
               p = swapids(rstep)

               ! Submit a new handshake irecv request
               if (sndlths(p) > 0) then
                  tag = mytask + offset_t
                  call mpi_irecv( hs, 1, MP_INTEGER, p, tag, comm, &
                                  hs_rcvids(rstep), ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
               endif

               ! Submit a new irecv request
               if (rcvlths(p) > 0) then
                  tag = p + offset_t

                  offset_r = rdispls(p)+1
                  call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                                  p, tag, comm, rcvids(rstep), ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)

                  call mpi_send ( hs, 1, MP_INTEGER, p, tag, comm, ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_SEND',ier)
               endif
            endif

            ! Wait for outstanding i(r)send request to complete
            p = swapids(istep-maxreqh)
            if (sndlths(p) > 0) then
               call mpi_wait( sndids(istep-maxreqh), status, ier )
               if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
            endif

         endif

      enddo

      ! wait for rest of send and receive requests to complete
      do istep=steps-maxreqh+1,steps
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            call mpi_wait( rcvids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
         endif
         if (sndlths(p) > 0) then
            call mpi_wait( sndids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
         endif
      enddo

!  (3) no handshaking + blocking sends
   elseif ((.not. handshake) .and. (sendd)) then

      ! Post receive requests
      do istep=1,maxreq
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            tag = p + offset_t

            offset_r = rdispls(p)+1
            call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                            p, tag, comm, rcvids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
         endif
      enddo
      rstep = maxreq

      ! Send (and start receiving) data
      do istep=1,steps
         p = swapids(istep)

         ! Submit new send request
         if (sndlths(p) > 0) then
            tag = mytask + offset_t

            offset_s = sdispls(p)+1
            call mpi_send( sndbuf(offset_s), sndlths(p), stypes(p), &
                           p, tag, comm, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_SEND',ier)
         endif

         if (istep > maxreqh) then

            ! Wait for oldest irecv request to complete
            p = swapids(istep-maxreqh)
            if (rcvlths(p) > 0) then
               call mpi_wait( rcvids(istep-maxreqh), status, ier )
               if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
            endif

            ! Submit a new irecv request
            if (rstep < steps) then
               rstep = rstep + 1
               p = swapids(rstep)
               if (rcvlths(p) > 0) then
                  tag = p + offset_t

                  offset_r = rdispls(p)+1
                  call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                                  p, tag, comm, rcvids(rstep), ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
               endif
            endif

         endif

      enddo

      ! wait for rest of send and receive requests to complete
      do istep=steps-maxreqh+1,steps
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            call mpi_wait( rcvids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
         endif
      enddo

!  (4) no handshaking + nonblocking sends
   elseif ((.not. handshake) .and. (.not. sendd)) then

      ! Post receive requests
      do istep=1,maxreq
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            tag = p + offset_t

            offset_r = rdispls(p)+1
            call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                            p, tag, comm, rcvids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
         endif
      enddo
      rstep = maxreq

      ! Send (and start receiving) data
      do istep=1,steps
         p = swapids(istep)

         ! Submit new isend request
         if (sndlths(p) > 0) then
            tag = mytask + offset_t

            offset_s = sdispls(p)+1
            call mpi_isend( sndbuf(offset_s), sndlths(p), stypes(p), &
                            p, tag, comm, sndids(istep), ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_ISEND',ier)
         endif

         if (istep > maxreqh) then

            ! Wait for oldest irecv request to complete
            p = swapids(istep-maxreqh)
            if (rcvlths(p) > 0) then
               call mpi_wait( rcvids(istep-maxreqh), status, ier )
               if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
            endif

            ! Submit a new irecv request
            if (rstep < steps) then
               rstep = rstep + 1
               p = swapids(rstep)
               if (rcvlths(p) > 0) then
                  tag = p + offset_t

                  offset_r = rdispls(p)+1
                  call mpi_irecv( rcvbuf(offset_r), rcvlths(p), rtypes(p), &
                                  p, tag, comm, rcvids(rstep), ier )
                  if(ier /= 0) call MP_perr_die(subName,'MPI_IRECV',ier)
               endif
            endif

            ! Wait for outstanding i(r)send request to complete
            p = swapids(istep-maxreqh)
            if (sndlths(p) > 0) then
               call mpi_wait( sndids(istep-maxreqh), status, ier )
               if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
            endif

         endif

      enddo

      ! wait for rest of send and receive requests to complete
      do istep=steps-maxreqh+1,steps
         p = swapids(istep)
         if (rcvlths(p) > 0) then
            call mpi_wait( rcvids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
         endif
         if (sndlths(p) > 0) then
            call mpi_wait( sndids(istep), status, ier )
            if(ier /= 0) call MP_perr_die(subName,'MPI_WAIT',ier)
         endif
      enddo

   endif

   return

   end subroutine m_swapm_FP

end module m_SPMDutils





