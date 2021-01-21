#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

      program test
      use mpi
      implicit none
        integer ierr
        integer ec
        character*(MPI_MAX_LIBRARY_VERSION_STRING) version
        integer vlen

        ec = 0
#ifdef TEST_INTERNAL
        print *, "Using internal tests"
#endif

        call mpi_init(ierr)

        call MPI_GET_LIBRARY_VERSION(version,vlen,ierr)
        print *,"MPI Version '",version,"' len=",vlen

        call test_contiguous(ec)
        call test_vector(ec)
        call test_simple_hvector(ec)
        call test_simple_indexed(ec)
        call test_simple_bindexed(ec)
        call test_simple_hindexed(ec)
        call test_complex_indexed(ec)
        call test_packed(ec)
        call test_multiple(ec)
        call test_multiple_indexed(ec)
        call test_collectives(ec)
        call test_mpi_version(ec)

        call mpi_finalize(ierr)
        if (ec .eq. 0) then
          print *, "PASSED ALL TESTS"
        else
          print *, "Errors:",ec
        end if
        stop
      end

!!!!!!!!!!!!!!!!!!!
! Contiguous type.  Simplest example.  Strings 5
!  integers together and tests their equality after
!  a send operation
!!!!!!!!!!!!!!!!!!!

      subroutine test_contiguous(ec)
      use mpi
      integer ec
      integer ierr
      integer datatype
      integer a(5)
      integer b(5)
      integer i
      data a/1,2,3,4,5/
      data b/5 * 0/
      integer req

      print *, "Test Contiguous of 5 x MPI_INTEGER"
      call mpi_type_contiguous(5, mpi_integer, datatype,ierr)
      call mpi_type_commit(datatype, ierr)

#ifdef TEST_INTERNAL
      call copy_data2(a,1,datatype,b,1,datatype,ierr)
#else
      call mpi_isend(a, 1, datatype, 0, 0, mpi_comm_world, req, ierr)
      call mpi_irecv(b, 1, datatype, mpi_any_source, mpi_any_tag, &
                     mpi_comm_world, req, ierr)
#endif

      do i=1,5
        if (a(i) .ne. b(i)) then
          print *,">>>FAILED: mpi_type_contiguous"
          ec = ec+1
          return
        end if
      end do

      end

!!!!!!!!!!!!!!!!!!!!!!!!
! Vector type.  collect a series of indices with
! set stride from an array.
!!!!!!!!!!!!!!!!!!!!!!!!

      subroutine test_vector(ec)
      use mpi
      integer ec
      integer ierr
      integer datatype
      integer a(10) != (1,2,3,4,5,6,7,8,9,0)
      integer b(10)
      integer check_index(6)
      data a/1,2,3,4,5,6,7,8,9,10/
      data b/10 * 0/
      data check_index/1,2,4,5,7,8/
      integer i
      integer req

      print *, "Test vector of MPI_INTEGER"

      call mpi_type_vector(3, 2, 3, mpi_integer, datatype, ierr)
      call mpi_type_commit(datatype, ierr)
#ifdef TEST_INTERNAL
      call copy_data2(a,1,datatype,b,1,datatype,ierr)
#else
      call mpi_isend(a, 1, datatype, 0, 0, mpi_comm_world, req, ierr)
      call mpi_irecv(b, 1, datatype, mpi_any_source, mpi_any_tag, &
                     mpi_comm_world, req, ierr)
#endif
      do i=1,6
        if (a(check_index(i)) .ne. b(check_index(i))) then
          print *,">>>FAILED: mpi_type_vector"
          ec = ec+1
          return
        end if
      end do
      end

!!!!!!!!!!!!!!!!!!!!!
! Byte-addressed vector.
! values calculated with mpi_type_extent(),
! so basically we are doing the work here in the
! test program instead of in the library
!!!!!!!!!!!!!!!!!!!!!

      subroutine test_simple_hvector(ec)
      use mpi
      integer ec
        integer vector_type
        integer (kind=mpi_address_kind) extent
        integer i
        integer a(10)
        integer b(10)
        integer index_test(6)
        integer ierr
        integer req

        data a/1,2,3,4,5,6,7,8,9,10/, b/0,0,0,0,0,0,0,0,0,0/
        data index_test/1,2,5,6,9,10/

        print *, "Vector type with stride 4 in bytes"

        call mpi_type_extent(mpi_integer, extent, ierr)
        call mpi_type_hvector(3, 2, 4 * extent, mpi_integer, &
             vector_type, ierr)
        call mpi_type_commit(vector_type, ierr)
#ifdef TEST_INTERNAL
        call copy_data2(a,1,vector_type, b,1,vector_type, ierr)
#else
        call mpi_isend(a, 1, vector_type, 0, 0, mpi_comm_world,req,ierr)
        call mpi_irecv(b, 1, vector_type, mpi_any_source, mpi_any_tag, &
                       mpi_comm_world, req, ierr)
#endif
        do i=1,6
          if (a(index_test(i)) .ne. (b(index_test(i)))) then
            print *, ">>>FAILED: test_simple_hvector"
            ec = ec+1
            return
          end if
        end do
      end subroutine

!!!!!!!!!!!!!!!!!!!!
! indexed type.  test certain indices of an array
!!!!!!!!!!!!!!!!!!!!

      subroutine test_simple_indexed(ec)
      use mpi
      integer ec
        integer i
        double complex a(15)
        double complex b(15)
        integer index_test(6)
        integer blens(3)
        integer disps(3)
        integer indexed_type
        integer ierr
        integer req

        data a/1,2,3,4,5,6,7,8,9,10,11,12,13,14,15/
        data b/0,0,0,0,0,0,0,0,0,0,0,0,0,0,0/
        data index_test/1,6,7,11,12,13/
        data blens/2,1,3/
        data disps/5,0,10/
        print *, "Indexed type"

        call mpi_type_indexed(3, blens, disps, mpi_double_complex, &
                         indexed_type, ierr)
        call mpi_type_commit(indexed_type, ierr)
#ifdef TEST_INTERNAL
        call copy_data2(a,1,indexed_type,b,1,indexed_type,ierr)
#else
        call mpi_isend(a, 1, indexed_type,0, 0, mpi_comm_world,req,ierr)
        call mpi_irecv(b, 1, indexed_type, mpi_any_source, mpi_any_tag,&
                       mpi_comm_world, req, ierr)
#endif

        do i=1,6
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, ">>>FAILED: test_simple_indexed"
            ec = ec+1
            return
          end if
        end do
      end subroutine

!!!!!!!!!!!!!!!!
! Block indexed.  All blocks have same length
!!!!!!!!!!!!!!!!

      subroutine test_simple_bindexed(ec)
      use mpi
      integer ec
        integer i
        integer disps(3)
        integer a(10), b(10)
        integer index_test(6)
        integer indexed_type
        integer ierr
        integer req

        data disps/0,4,7/
        data a/1,2,3,4,5,6,7,8,9,10/
        data b/0,0,0,0,0,0,0,0,0,0/
        data index_test/1,2,5,6,8,9/
        print *, "Block indexed type"

        call mpi_type_create_indexed_block(3,2,disps,mpi_integer, &
                                           indexed_type, ierr)
        call mpi_type_commit(indexed_type, ierr)
#ifdef TEST_INTERNAL
        call copy_data2(a,1,indexed_type, b,1,indexed_type, ierr)
#else
        call mpi_isend(a, 1, indexed_type,0, 0, mpi_comm_world,req,ierr)
        call mpi_irecv(b, 1, indexed_type,mpi_any_source,mpi_any_tag, &
                       mpi_comm_world, req, ierr)
#endif
        do i=1,6
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, ">>>FAILED:test_simple_bindexed"
            ec = ec+1
            return
          end if
        end do
      end subroutine

!!!!!!!!!!!!!!!!
! test_simple_hindexed
!  test equality of a byte-addressed
!  type of integer array
!  (disps calculated through mpi_type_extent()
!!!!!!!!!!!!!!!
      subroutine test_simple_hindexed(ec)
      use mpi
      integer ec
        integer i
        integer a(10), b(10)
        integer index_test(6)
        integer blens(3)
        integer(kind=mpi_address_kind) disps(3)
        integer indexed_type
        integer(kind=mpi_address_kind) extent
        integer ierr
        integer req
        integer (kind=mpi_address_kind) addr, baddr

        data a/1,2,3,4,5,6,7,8,9,10/
        data b/0,0,0,0,0,0,0,0,0,0/
        data index_test/1,3,4,6,7,8/
        data blens/2,1,3/

        call mpi_address(a(1), baddr,ierr)
        call mpi_address(a(3), addr ,ierr)
        disps(1) = addr - baddr
        call mpi_address(a(6), addr, ierr)
        disps(3) = addr - baddr
!        call mpi_type_extent(mpi_integer, extent, ierr)
!        disps(1) = 2*extent
        disps(2) = 0
!        disps(3) = 5*extent


        print *, "Byte addressed indexed type"
        call mpi_type_hindexed(3,blens,disps, MPI_INTEGER, &
             indexed_type,ierr)
        call mpi_type_commit(indexed_type, ierr)
#ifdef TEST_INTERNAL
        call copy_data2(a,1,indexed_type, b,1,indexed_type, ierr)
#else
        call mpi_isend(a, 1, indexed_type,0, 0, mpi_comm_world,req,ierr)
        call mpi_irecv(b, 1, indexed_type,mpi_any_source,mpi_any_tag, &
                      mpi_comm_world,req,ierr)
#endif
        do i=1,6
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, ">>>FAILED: test_simple_hindexed"
            ec = ec+1
            return
          end if
        end do
      end subroutine

      subroutine test_complex_indexed(ec)
      use mpi
      integer ec
        integer i
        double precision a(72), b(72)
        integer disps(3), blens(3)
        integer cdisps(2), cblens(2)
        integer index_test(8), cindex_test(3)
        integer ierr
        integer req
        integer indexed_type, complex_indexed

        data blens/3,1,4/
        data disps/0,5,8/
        data cindex_test/1,4,5/
        data index_test/1,2,3, 6, 9,10,11,12/

        data a/1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15, &
              16,17,18,19,20,21,22,23,24,25,26,27,28,29,30, &
              31,32,33,34,35,36,37,38,39,40,41,42,43,44,45, &
              46,47,48,49,50,51,52,53,54,55,56,57,58,59,60, &
              61,62,63,64,65,66,67,68,69,70,71,72/
        data b/0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, &
               0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, &
               0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, &
               0,0,0,0,0,0,0,0,0,0,0,0/

        call mpi_type_indexed(3,blens,disps, MPI_DOUBLE_PRECISION, &
             indexed_type, ierr)
        call mpi_type_commit(indexed_type, ierr)

        data cblens/1, 2/
        data cdisps/1, 4/
        call mpi_type_indexed(2,cblens,cdisps,indexed_type, &
             complex_indexed, ierr)
        call mpi_type_commit(complex_indexed, ierr)
#ifdef TEST_INTERNAL
        call copy_data2(a,1,complex_indexed,b,1,complex_indexed,ierr)
#else
        call mpi_isend(a,1,complex_indexed,0,0,mpi_comm_world,req,ierr)
        call mpi_irecv(b,1,complex_indexed,mpi_any_source,mpi_any_tag,&
                       mpi_comm_world, req, ierr)
#endif
        do i=1,3
          do j=1,8
            if (a(index_test(j)+12*cindex_test(i)) .ne. &
                b(index_test(j)+12*cindex_test(i))) then
              print *, ">>>FAILED: test_complex_indexed"
              print *, "index ",index_test(j)+12*cindex_test(i)
              print *, "Found:",b(index_test(j)+12*cindex_test(i))
              print *, "Should be:",a(index_test(j)+12*cindex_test(i))
              ec = ec+1
            end if
          end do
        end do

        call mpi_type_free(complex_indexed, ierr)
        call mpi_type_free(indexed_type, ierr)
      end subroutine
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! test_packed()
! Creates a few variable pairs, assigns the first
!  of each pair, then packs their values and unpacks
!  them to the other set.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      subroutine test_packed(ec)
      use mpi
        integer ec
        integer size
        integer x, y
        real f, g
        complex c, d
        character*5 a, b
        character buf(100), rbuf(100)
        integer blens(3)
        integer(kind=mpi_address_kind) disps(3)
        integer pos
        integer req

        x = 10
        f = 14.333
        c = (100, 20)
        a = "xyzab"

        pos = 0
        data blens/1,2,1/, disps/0,4,8/

        print *, "Packed type "

        call mpi_pack(x, 1, mpi_integer, buf, 100, pos, 0, ierr)
        call mpi_pack(f, 1, mpi_real, buf, 100, pos, 0, ierr)
        call mpi_pack(c, 1, mpi_complex, buf, 100, pos, 0, ierr)
        call mpi_pack(a, 5, mpi_character, buf, 100, pos, 0, ierr)
#ifdef TEST_INTERNAL
        call copy_data2(buf, pos, mpi_packed, rbuf, pos, &
                        mpi_packed, ierr)
#else
        call mpi_isend(buf, pos, mpi_packed,0,0,mpi_comm_world,req,ierr)
        call mpi_irecv(rbuf, pos, mpi_packed,mpi_any_source,mpi_any_tag&
                       ,mpi_comm_world, req, ierr)
#endif
        pos = 0;

        call mpi_unpack(rbuf, 100, pos, y, 1, mpi_integer, 0, ierr)
        call mpi_unpack(rbuf, 100, pos, g, 1, mpi_real, 0, ierr)
        call mpi_unpack(rbuf, 100, pos, d, 1, mpi_complex, 0, ierr)
        call mpi_unpack(rbuf, 100, pos, b, 5, mpi_character, &
                        0, ierr)

        if (x .ne. y .OR. f .ne. g &
            .OR. c .ne. d .OR. a .ne. b) &
            then
          print *, ">>>FAILED: mpi_pack"
          ec = ec+1
          return
        end if

      end subroutine

      subroutine test_multiple(ec)
      use mpi
      integer ec
        integer i
        complex a(10)
        complex b(10)
        integer contig_type
        integer ierr
        integer req

        data a/1,2,3,4,5,6,7,8,9,10/
        data b/0,0,0,0,0,0,0,0,0,0/
        print *, "Contig type send, multiple receive"

        call mpi_type_contiguous(10, mpi_complex, contig_type, ierr)
        call mpi_type_commit(contig_type, ierr)
#ifdef TEST_INTERNAL
        call copy_data2(a,1,contig_type, b,10, mpi_complex, ierr)
#else
        call mpi_isend(a, 1, contig_type,0,0,mpi_comm_world,req,ierr)
        call mpi_irecv(b, 10, mpi_complex,mpi_any_source,mpi_any_tag, &
                       mpi_comm_world,req,ierr)
#endif

        do i=1,10
          if (a(i) .ne. b(i)) then
            print *, ">>>FAILED: test_multiple"
            ec = ec+1
            return
          end if
        end do
      end subroutine

!!!!!!!!!!!!!!!!!!!!!!!!!
! Test an indexed send with a multiple receive
!!!!!!!!!!!!!!!!!!!!!!!!!
      subroutine test_multiple_indexed(ec)
      use mpi
        integer ec
        integer i,j
        complex a(75)
        complex b(75)
        integer index_test(6)
        integer blens(3)
        integer disps(3)
        integer indexed_type,contig_indexed
        integer ierr
        integer req

        data a/ 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,&
               16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,&
               31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,&
               46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,&
               61,62,63,64,65,66,67,68,69,70,71,72,73,74,75/
        data b/75*0/
        data index_test/1,6,7,11,12,13/
        data blens/1,2,3/
        data disps/0,5,10/
        print *, "Indexed type send, multiple indexed receive"

        call mpi_type_indexed(3, blens, disps, mpi_complex, &
                         indexed_type, ierr)
        call mpi_type_commit(indexed_type, ierr)

        call mpi_type_contiguous(5, indexed_type, contig_indexed,ierr)
        call mpi_type_commit(contig_indexed, ierr)
#ifdef TEST_INTERNAL
        call copy_data2(a,1,contig_indexed,b,5,indexed_type,ierr)
#else
        call mpi_isend(a, 1, contig_indexed,0,0,mpi_comm_world,req,ierr)
        call mpi_irecv(b, 5, indexed_type,mpi_any_source,mpi_any_tag, &
                       mpi_comm_world,req,ierr)
#endif
        do i=0,4
          do j=1,6
            if (a(index_test(j)+(13*i)) .ne. b(index_test(j)+(13*i))) then
              print *, ">>>FAILED: test_multiple_indexed"
              print *, " Found:",a(index_test(j)+13*i)
              print *, " Expected:",b(index_test(j)+13*i)
              ec = ec+1
!              return
            end if
          end do
        end do
      end subroutine

      subroutine test_collectives(ec)
      use mpi
      integer ec
        integer i
        integer a(10)
        integer b(10)
        integer disps(3)
        integer blens(3)
        integer itype
        integer ierr
        integer scount
        integer rcount
        integer disp
        integer index_test(7)

        data scount/1/rcount/1/disp/0/
        data disps/0,5,8/
        data blens/4,2,1/
        data a/1,2,3,4,5,6,7,8,9,10/
        data b/10*0/
        data index_test/1,2,3,4,6,7,9/

        call mpi_type_indexed(3, blens, disps, MPI_LOGICAL,&
               itype, ierr)
        call mpi_type_commit(itype, ierr)

        call mpi_bcast(a, scount, itype, 0, &
                     mpi_comm_world, ierr)
        call mpi_gather(a,scount, itype, b, rcount, &
                     itype, 0, mpi_comm_world, ierr)
        print *, "Testing mpi_gather"
        do i=1,7
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, "mpi_gather failed"
            ec=ec+1
          end if
        end do
        do i=1,10
          b(i) = 0
        end do
        print *, "Testing mpi_gatherv"
        call mpi_gatherv(a, scount, itype, b, rcount, &
                     disp, itype, 0, mpi_comm_world, ierr)
        do i=1,7
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, "mpi_gatherv failed"
            ec=ec+1
          end if
        end do
        do i=1,10
          b(i) = 0
        end do
        print *, "Testing mpi_allgather"
        call mpi_allgather(a, scount, itype, b, rcount, &
                    itype, mpi_comm_world, ierr)
        do i=1,7
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, "mpi_allgather failed"
            ec=ec+1
          end if
        end do
        print *, "Testing mpi_allgatherv"
        call mpi_allgatherv(a, scount, itype, b, rcount, &
                    disp, itype, mpi_comm_world, ierr)
        do i=1,7
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, "mpi_allgatherv failed"
            ec=ec+1
          end if
        end do
        do i=1,10
          b(i) = 0
        end do
        print *, "Testing mpi_scatter"
        call mpi_scatter(a, scount, itype, b, rcount, &
                      itype, 0, mpi_comm_world, ierr)
         do i=1,7
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, "mpi_scatter failed"
            ec=ec+1
          end if
        end do
        do i=1,10
          b(i) = 0
        end do
        print *, "Testing mpi_scatterv"
        call mpi_scatterv(a, scount, disp, itype, b, &
                      rcount, itype, 0, mpi_comm_world, ierr)
         do i=1,7
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, "mpi_scatterv failed"
            ec=ec+1
          end if
        end do
        do i=1,10
          b(i) = 0
        end do
        print *, "Testing mpi_reduce"
        call mpi_reduce(a, b, scount, itype, mpi_max, &
                      0, mpi_comm_world, ierr)
         do i=1,7
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, "mpi_reduce failed"
            ec=ec+1
          end if
        end do
        do i=1,10
          b(i) = 0
        end do
        print *, "Testing mpi_allreduce"
        call mpi_allreduce(a, b, scount, itype, mpi_max, &
                      mpi_comm_world, ierr)
         do i=1,7
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, "mpi_allreduce failed"
            ec=ec+1
          end if
        end do
        do i=1,10
          b(i) = 0
        end do
        print *, "Testing mpi_alltoall"
        call mpi_alltoall(a, scount, itype, b, rcount, &
                      itype, mpi_comm_world, ierr)
         do i=1,7
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, "mpi_alltoall failed"
            ec=ec+1
          end if
        end do
        do i=1,10
          b(i) = 0
        end do
        print *, "Testing mpi_alltoallv"
        call mpi_alltoallv(a, scount, disp, itype, b, &
                      rcount, disp, itype, mpi_comm_world, ierr)
         do i=1,7
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, "mpi_alltoallv failed"
            ec=ec+1
          end if
        end do
        do i=1,10
          b(i) = 0
        end do
        print *, "Testing mpi_reduce_scatter"
        call mpi_reduce_scatter(a, b, rcount, itype, &
                      mpi_max, mpi_comm_world, ierr)
         do i=1,7
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, "mpi_reduce_scatter failed"
            ec=ec+1
          end if
        end do
        do i=1,10
          b(i) = 0
        end do
        print *, "Testing mpi_scan"
        call mpi_scan(a, b, scount, itype, mpi_max, &
                      mpi_comm_world, ierr)

         do i=1,7
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, "mpi_scan failed"
            ec=ec+1
          end if
        end do
      end subroutine

!!!!!!!!!!!!!!!!!!!!!!!!
! Test MPI_VERSION
!!!!!!!!!!!!!!!!!!!!!!!!

      subroutine test_mpi_version(ec)
      use mpi
      integer ec
      integer ierr
      integer mpiv
      integer mpisv

      print *, "Testing MPI_Get_Version"

      call mpi_get_version(mpiv, mpisv, ierr)
      if (ierr /= MPI_SUCCESS) then
        print *, "MPI_get_VERSION ierr not zero (",ierr,")"
        ec = ec + 1
      else
        if (mpiv /= MPI_VERSION) then
          print *, "MPI_VERSION mismatch, should be ",MPI_VERSION,", found ",mpiv
          ec = ec + 1
        end if
        if (mpisv /= MPI_SUBVERSION) then
          print *, "MPI_SUBVERSION mismatch, should be ",MPI_SUBVERSION,", found ",mpisv
          ec = ec + 1
        end if
      end if
      end subroutine test_mpi_version
