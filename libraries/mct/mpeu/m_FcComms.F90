!BOP -------------------------------------------------------------------
!
! !MODULE: m_FcComms - MPI collective communication operators
!                      with explict flow control
!
! !DESCRIPTION:
!
! This module includes implementations of MPI collective operators that
! have proven problematic on certain systems when run at scale. By
! introducing additonal flow control, these problems (exhausting internal
! system resources) can be avoided. These routines were ported from
! the Community Atmosphere Model's spmd_utils.F90.
!
! !INTERFACE:
!
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

 module m_FcComms

      implicit none

      private	! except

      public :: fc_gather_int  ! flow control version of mpi_gather for integer vectors
      public :: fc_gather_fp   ! flow control version of mpi_gather for FP vectors
      public :: fc_gatherv_int ! flow control version of mpi_gatherv for integer vectors
      public :: fc_gatherv_fp  ! flow control version of mpi_gatherv for integer vectors
      public :: get_fcblocksize ! get current value of max_gather_block_size
      public :: set_fcblocksize ! set current value of max_gather_block_size


! !REVISION HISTORY:
! 30Jan09 - P.H. Worley <worleyph@ornl.gov> - imported routines
!           from CAM's spmd_utils to create this module.

  integer, public :: max_gather_block_size = 64
  character(len=*),parameter :: myname='MCT(MPEU)::m_FcComms'

 contains

!BOP -------------------------------------------------------------------
!
! !IROUTINE: fc_gather_int - Gather an array of type integer
!
! !DESCRIPTION:
! This routine gathers a {\em distributed} array of type {\em integer}
! to the {\tt root} process. Explicit handshaking messages are used
! to control the number of processes communicating with the root
! at any one time.
!
! If flow_cntl optional parameter
!    < 0 : use MPI_Gather
!    >= 0: use point-to-point with handshaking messages and
!          preposting receive requests up to
!          min(max(1,flow_cntl),max_gather_block_size)
!          ahead if optional flow_cntl parameter is present.
!          Otherwise, max_gather_block_size is used in its place.
!    Default value is max_gather_block_size.
! !INTERFACE:
!
   subroutine fc_gather_int (sendbuf, sendcnt, sendtype, &
                             recvbuf, recvcnt, recvtype, &
                             root, comm, flow_cntl )
!
! !USES:
!
      use m_die
      use m_mpif90
!
! !INPUT PARAMETERS:
!
      integer, intent(in) :: sendbuf(*)
      integer, intent(in) :: sendcnt
      integer, intent(in) :: sendtype
      integer, intent(in) :: recvcnt
      integer, intent(in) :: recvtype
      integer, intent(in) :: root
      integer, intent(in) :: comm
      integer, optional, intent(in) :: flow_cntl

! !OUTPUT PARAMETERS:
!
      integer, intent(out) :: recvbuf(*)

! !REVISION HISTORY:
! 30Jan09 - P.H. Worley - imported from spmd_utils.F90
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::fc_gather_int'

 integer :: signal
 logical fc_gather         ! use explicit flow control?
 integer gather_block_size ! number of preposted receive requests

 integer :: mytid, mysize, mtag, p, i, count, displs
 integer :: preposts, head, tail
 integer :: rcvid(max_gather_block_size)
 integer :: status(MP_STATUS_SIZE)
 integer :: ier ! MPI error code

 signal = 1
 if ( present(flow_cntl) ) then
    if (flow_cntl >= 0) then
       gather_block_size = min(max(1,flow_cntl),max_gather_block_size)
       fc_gather = .true.
    else
       fc_gather = .false.
    endif
 else
    gather_block_size = max(1,max_gather_block_size)
    fc_gather = .true.
 endif

 if (fc_gather) then

    call mpi_comm_rank (comm, mytid, ier)
    call mpi_comm_size (comm, mysize, ier)
    mtag = 0
    if (root .eq. mytid) then

! prepost gather_block_size irecvs, and start receiving data
       preposts = min(mysize-1, gather_block_size)
       head = 0
       count = 0
       do p=0, mysize-1
          if (p .ne. root) then
             if (recvcnt > 0) then
                count = count + 1
                if (count > preposts) then
                   tail = mod(head,preposts) + 1
                   call mpi_wait (rcvid(tail), status, ier)
                end if
                head = mod(head,preposts) + 1
                displs = p*recvcnt
                call mpi_irecv ( recvbuf(displs+1), recvcnt, &
                                 recvtype, p, mtag, comm, rcvid(head), &
                                 ier )
                call mpi_send ( signal, 1, recvtype, p, mtag, comm, ier )
             end if
          end if
       end do

! copy local data
       displs = mytid*recvcnt
       do i=1,sendcnt
          recvbuf(displs+i) = sendbuf(i)
       enddo

! wait for final data
       do i=1,min(count,preposts)
          call mpi_wait (rcvid(i), status, ier)
       enddo

    else

       if (sendcnt > 0) then
          call mpi_recv ( signal, 1, sendtype, root, mtag, comm, &
                          status, ier )
          call mpi_rsend ( sendbuf, sendcnt, sendtype, root, mtag, &
                           comm, ier )
       end if

    endif
    if (ier /= 0) then
       call MP_perr_die(myname_,':: (point-to-point implementation)',ier)
    end if

 else

    call mpi_gather (sendbuf, sendcnt, sendtype, &
                     recvbuf, recvcnt, recvtype, &
                     root, comm, ier)
    if (ier /= 0) then
       call MP_perr_die(myname_,':: MPI_GATHER',ier)
    end if

 endif

 return
 end subroutine fc_gather_int

!BOP -------------------------------------------------------------------
!
! !IROUTINE: fc_gather_fp - Gather an array of type FP
!
! !DESCRIPTION:
! This routine gathers a {\em distributed} array of type {\em FP} to
! the {\tt root} process. Explicit handshaking messages are used
! to control the number of processes communicating with the root
! at any one time.
!
! If flow_cntl optional parameter
!    < 0 : use MPI_Gather
!    >= 0: use point-to-point with handshaking messages and
!          preposting receive requests up to
!          min(max(1,flow_cntl),max_gather_block_size)
!          ahead if optional flow_cntl parameter is present.
!          Otherwise, max_gather_block_size is used in its place.
!    Default value is max_gather_block_size.
! !INTERFACE:
!
   subroutine fc_gather_fp (sendbuf, sendcnt, sendtype, &
                            recvbuf, recvcnt, recvtype, &
                             root, comm, flow_cntl )
!
! !USES:
!
      use m_realkinds, only : FP
      use m_die
      use m_mpif90
!
! !INPUT PARAMETERS:
!
      real (FP), intent(in)  :: sendbuf(*)
      integer, intent(in) :: sendcnt
      integer, intent(in) :: sendtype
      integer, intent(in) :: recvcnt
      integer, intent(in) :: recvtype
      integer, intent(in) :: root
      integer, intent(in) :: comm
      integer, optional, intent(in) :: flow_cntl

! !OUTPUT PARAMETERS:
!
      real (FP), intent(out) :: recvbuf(*)

! !REVISION HISTORY:
! 30Jan09 - P.H. Worley - imported from spmd_utils.F90
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::fc_gather_fp'

 real (FP) :: signal
 logical fc_gather         ! use explicit flow control?
 integer gather_block_size ! number of preposted receive requests

 integer :: mytid, mysize, mtag, p, i, count, displs
 integer :: preposts, head, tail
 integer :: rcvid(max_gather_block_size)
 integer :: status(MP_STATUS_SIZE)
 integer :: ier ! MPI error code

 signal = 1.0
 if ( present(flow_cntl) ) then
    if (flow_cntl >= 0) then
       gather_block_size = min(max(1,flow_cntl),max_gather_block_size)
       fc_gather = .true.
    else
       fc_gather = .false.
    endif
 else
    gather_block_size = max(1,max_gather_block_size)
    fc_gather = .true.
 endif

 if (fc_gather) then

    call mpi_comm_rank (comm, mytid, ier)
    call mpi_comm_size (comm, mysize, ier)
    mtag = 0
    if (root .eq. mytid) then

! prepost gather_block_size irecvs, and start receiving data
       preposts = min(mysize-1, gather_block_size)
       head = 0
       count = 0
       do p=0, mysize-1
          if (p .ne. root) then
             if (recvcnt > 0) then
                count = count + 1
                if (count > preposts) then
                   tail = mod(head,preposts) + 1
                   call mpi_wait (rcvid(tail), status, ier)
                end if
                head = mod(head,preposts) + 1
                displs = p*recvcnt
                call mpi_irecv ( recvbuf(displs+1), recvcnt, &
                                 recvtype, p, mtag, comm, rcvid(head), &
                                 ier )
                call mpi_send ( signal, 1, recvtype, p, mtag, comm, ier )
             end if
          end if
       end do

! copy local data
       displs = mytid*recvcnt
       do i=1,sendcnt
          recvbuf(displs+i) = sendbuf(i)
       enddo

! wait for final data
       do i=1,min(count,preposts)
          call mpi_wait (rcvid(i), status, ier)
       enddo

    else

       if (sendcnt > 0) then
          call mpi_recv ( signal, 1, sendtype, root, mtag, comm, &
                          status, ier )
          call mpi_rsend ( sendbuf, sendcnt, sendtype, root, mtag, &
                           comm, ier )
       end if

    endif
    if (ier /= 0) then
       call MP_perr_die(myname_,':: (point-to-point implementation)',ier)
    end if

 else

    call mpi_gather (sendbuf, sendcnt, sendtype, &
                     recvbuf, recvcnt, recvtype, &
                      root, comm, ier)
    if (ier /= 0) then
       call MP_perr_die(myname_,':: MPI_GATHER',ier)
    end if

 endif

 return
 end subroutine fc_gather_fp

!BOP -------------------------------------------------------------------
!
! !IROUTINE: fc_gatherv_int - Gather an array of type integer
!
! !DESCRIPTION:
! This routine gathers a {\em distributed} array of type {\em integer}
! to the {\tt root} process. Explicit handshaking messages are used
! to control the number of processes communicating with the root
! at any one time.
!
! If flow_cntl optional parameter
!    < 0 : use MPI_Gatherv
!    >= 0: use point-to-point with handshaking messages and
!          preposting receive requests up to
!          min(max(1,flow_cntl),max_gather_block_size)
!          ahead if optional flow_cntl parameter is present.
!          Otherwise, max_gather_block_size is used in its place.
!    Default value is max_gather_block_size.
! !INTERFACE:
!
   subroutine fc_gatherv_int (sendbuf, sendcnt, sendtype, &
                              recvbuf, recvcnts, displs, recvtype, &
                              root, comm, flow_cntl )
!
! !USES:
!
      use m_die
      use m_mpif90
!
! !INPUT PARAMETERS:
!
      integer, intent(in) :: sendbuf(*)
      integer, intent(in) :: sendcnt
      integer, intent(in) :: sendtype
      integer, intent(in) :: recvcnts(*)
      integer, intent(in) :: displs(*)
      integer, intent(in) :: recvtype
      integer, intent(in) :: root
      integer, intent(in) :: comm
      integer, optional, intent(in) :: flow_cntl

! !OUTPUT PARAMETERS:
!
      integer, intent(out) :: recvbuf(*)

! !REVISION HISTORY:
! 30Jan09 - P.H. Worley - imported from spmd_utils.F90
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::fc_gatherv_int'

 integer :: signal
 logical fc_gather         ! use explicit flow control?
 integer gather_block_size ! number of preposted receive requests

 integer :: mytid, mysize, mtag, p, q, i, count
 integer :: preposts, head, tail
 integer :: rcvid(max_gather_block_size)
 integer :: status(MP_STATUS_SIZE)
 integer :: ier ! MPI error code

 signal = 1
 if ( present(flow_cntl) ) then
    if (flow_cntl >= 0) then
       gather_block_size = min(max(1,flow_cntl),max_gather_block_size)
       fc_gather = .true.
    else
       fc_gather = .false.
    endif
 else
    gather_block_size = max(1,max_gather_block_size)
    fc_gather = .true.
 endif

 if (fc_gather) then

    call mpi_comm_rank (comm, mytid, ier)
    call mpi_comm_size (comm, mysize, ier)
    mtag = 0
    if (root .eq. mytid) then

! prepost gather_block_size irecvs, and start receiving data
       preposts = min(mysize-1, gather_block_size)
       head = 0
       count = 0
       do p=0, mysize-1
          if (p .ne. root) then
             q = p+1
             if (recvcnts(q) > 0) then
                count = count + 1
                if (count > preposts) then
                   tail = mod(head,preposts) + 1
                   call mpi_wait (rcvid(tail), status, ier)
                end if
                head = mod(head,preposts) + 1
                call mpi_irecv ( recvbuf(displs(q)+1), recvcnts(q), &
                                 recvtype, p, mtag, comm, rcvid(head), &
                                 ier )
                call mpi_send ( signal, 1, recvtype, p, mtag, comm, ier )
             end if
          end if
       end do

! copy local data
       q = mytid+1
       do i=1,sendcnt
          recvbuf(displs(q)+i) = sendbuf(i)
       enddo

! wait for final data
       do i=1,min(count,preposts)
          call mpi_wait (rcvid(i), status, ier)
       enddo

    else

       if (sendcnt > 0) then
          call mpi_recv ( signal, 1, sendtype, root, mtag, comm, &
                          status, ier )
          call mpi_rsend ( sendbuf, sendcnt, sendtype, root, mtag, &
                           comm, ier )
       end if

    endif
    if (ier /= 0) then
       call MP_perr_die(myname_,':: (point-to-point implementation)',ier)
    end if

 else

    call mpi_gatherv (sendbuf, sendcnt, sendtype, &
                      recvbuf, recvcnts, displs, recvtype, &
                      root, comm, ier)
    if (ier /= 0) then
       call MP_perr_die(myname_,':: MPI_GATHERV',ier)
    end if

 endif

 return
 end subroutine fc_gatherv_int

!BOP -------------------------------------------------------------------
!
! !IROUTINE: fc_gatherv_fp - Gather an array of type FP
!
! !DESCRIPTION:
! This routine gathers a {\em distributed} array of type {\em FP} to
! the {\tt root} process. Explicit handshaking messages are used
! to control the number of processes communicating with the root
! at any one time.
!
! If flow_cntl optional parameter
!    < 0 : use MPI_Gatherv
!    >= 0: use point-to-point with handshaking messages and
!          preposting receive requests up to
!          min(max(1,flow_cntl),max_gather_block_size)
!          ahead if optional flow_cntl parameter is present.
!          Otherwise, max_gather_block_size is used in its place.
!    Default value is max_gather_block_size.
! !INTERFACE:
!
   subroutine fc_gatherv_fp (sendbuf, sendcnt, sendtype, &
                             recvbuf, recvcnts, displs, recvtype, &
                             root, comm, flow_cntl )
!
! !USES:
!
      use m_realkinds, only : FP
      use m_die
      use m_mpif90
!
! !INPUT PARAMETERS:
!
      real (FP), intent(in)  :: sendbuf(*)
      integer, intent(in) :: sendcnt
      integer, intent(in) :: sendtype
      integer, intent(in) :: recvcnts(*)
      integer, intent(in) :: displs(*)
      integer, intent(in) :: recvtype
      integer, intent(in) :: root
      integer, intent(in) :: comm
      integer, optional, intent(in) :: flow_cntl

! !OUTPUT PARAMETERS:
!
      real (FP), intent(out) :: recvbuf(*)

! !REVISION HISTORY:
! 30Jan09 - P.H. Worley - imported from spmd_utils.F90
!EOP ___________________________________________________________________

 character(len=*),parameter :: myname_=myname//'::fc_gatherv_fp'

 real (FP) :: signal
 logical fc_gather         ! use explicit flow control?
 integer gather_block_size ! number of preposted receive requests

 integer :: mytid, mysize, mtag, p, q, i, count
 integer :: preposts, head, tail
 integer :: rcvid(max_gather_block_size)
 integer :: status(MP_STATUS_SIZE)
 integer :: ier ! MPI error code

 signal = 1.0
 if ( present(flow_cntl) ) then
    if (flow_cntl >= 0) then
       gather_block_size = min(max(1,flow_cntl),max_gather_block_size)
       fc_gather = .true.
    else
       fc_gather = .false.
    endif
 else
    gather_block_size = max(1,max_gather_block_size)
    fc_gather = .true.
 endif

 if (fc_gather) then

    call mpi_comm_rank (comm, mytid, ier)
    call mpi_comm_size (comm, mysize, ier)
    mtag = 0
    if (root .eq. mytid) then

! prepost gather_block_size irecvs, and start receiving data
       preposts = min(mysize-1, gather_block_size)
       head = 0
       count = 0
       do p=0, mysize-1
          if (p .ne. root) then
             q = p+1
             if (recvcnts(q) > 0) then
                count = count + 1
                if (count > preposts) then
                   tail = mod(head,preposts) + 1
                   call mpi_wait (rcvid(tail), status, ier)
                end if
                head = mod(head,preposts) + 1
                call mpi_irecv ( recvbuf(displs(q)+1), recvcnts(q), &
                                 recvtype, p, mtag, comm, rcvid(head), &
                                 ier )
                call mpi_send ( signal, 1, recvtype, p, mtag, comm, ier )
             end if
          end if
       end do

! copy local data
       q = mytid+1
       do i=1,sendcnt
          recvbuf(displs(q)+i) = sendbuf(i)
       enddo

! wait for final data
       do i=1,min(count,preposts)
          call mpi_wait (rcvid(i), status, ier)
       enddo

    else

       if (sendcnt > 0) then
          call mpi_recv ( signal, 1, sendtype, root, mtag, comm, &
                          status, ier )
          call mpi_rsend ( sendbuf, sendcnt, sendtype, root, mtag, &
                           comm, ier )
       end if

    endif
    if (ier /= 0) then
       call MP_perr_die(myname_,':: (point-to-point implementation)',ier)
    end if

 else

    call mpi_gatherv (sendbuf, sendcnt, sendtype, &
                      recvbuf, recvcnts, displs, recvtype, &
                      root, comm, ier)
    if (ier /= 0) then
       call MP_perr_die(myname_,':: MPI_GATHERV',ier)
    end if

 endif

 return
 end subroutine fc_gatherv_fp

!BOP -------------------------------------------------------------------
!
! !IROUTINE: get_fcblocksize - return max_gather_block_size
!
! !DESCRIPTION:
! This function returns the current value of max_gather_block_size
!
! !INTERFACE:

 function get_fcblocksize()

! !USES:
!
! No external modules are used by this function.

     implicit none

! !INPUT PARAMETERS:
!

! !OUTPUT PARAMETERS:
!
    integer           :: get_fcblocksize

! !REVISION HISTORY:
!       03Mar09 - R. Jacob (jacob@mcs.anl.gov) -- intial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::get_fcblocksize'

  get_fcblocksize = max_gather_block_size

 end function  get_fcblocksize

!BOP -------------------------------------------------------------------
!
! !IROUTINE: set_fcblocksize - set max_gather_block_size
!
! !DESCRIPTION:
! This function sets the current value of max_gather_block_size
!
! !INTERFACE:

 subroutine set_fcblocksize(gather_block_size)

! !USES:
!
! No external modules are used by this function.

     implicit none

! !INPUT PARAMETERS:
!
    integer           :: gather_block_size

! !OUTPUT PARAMETERS:
!

! !REVISION HISTORY:
!       03Mar09 - R. Jacob (jacob@mcs.anl.gov) -- intial version
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//':: set_fcblocksize'

  max_gather_block_size = gather_block_size

 end subroutine  set_fcblocksize

 end module m_FcComms
