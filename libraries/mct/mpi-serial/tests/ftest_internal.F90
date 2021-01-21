      program test
      use mpi
      implicit none

        call test_contiguous()
        call test_vector()
        call test_simple_hvector()
        call test_simple_indexed()
        call test_simple_bindexed()
        call test_simple_hindexed()
        call test_packed()
        call test_multiple()
        stop
      end

!!!!!!!!!!!!!!!!!!!
! Contiguous type.  Simplest example.  Strings 5
!  integers together and tests their equality after
!  a send operation
!!!!!!!!!!!!!!!!!!!

      subroutine test_contiguous()
      use mpi
      integer ierr
      integer datatype
      integer a(5)
      integer b(5)
      integer i
      data a/1,2,3,4,5/
      data b/5 * 0/

      print *, "Test Contiguous of 5 x MPI_INTEGER"
      call mpi_type_contiguous(5, mpi_integer, datatype,ierr)

      call mpi_type_commit(datatype, ierr)

      call print_typemap(datatype,ierr)
      call copy_data2(a,1,datatype, b,1,datatype, ierr)

      do i=1,5
        if (a(i) .ne. b(i)) then
          print *,">>>FAILED: mpi_type_contiguous"
          stop
        end if
      end do
      print *, ">>>PASSED: mpi_type_contiguous"
      end

!!!!!!!!!!!!!!!!!!!!!!!!
! Vector type.  collect a series of indices with
! set stride from an array.
!!!!!!!!!!!!!!!!!!!!!!!!

      subroutine test_vector()
      use mpi
      integer ierr
      integer datatype
      integer a(10) != (1,2,3,4,5,6,7,8,9,0)
      integer b(10)
      integer check_index(6)
      data a/1,2,3,4,5,6,7,8,9,10/
      data b/10 * 0/
      data check_index/1,2,4,5,7,8/
      integer i

      print *, "Test vector of MPI_INTEGER"

      call mpi_type_vector(3, 2, 3, mpi_integer, datatype, ierr)
      call mpi_type_commit(datatype, ierr)
      call print_typemap(datatype,ierr)
      call copy_data2(a,1,datatype,b,1,datatype,ierr)

      do i=1,6
        if (a(check_index(i)) .ne. b(check_index(i))) then
          print *,">>>FAILED: mpi_type_vector"
          stop
        end if
      end do
      print *, ">>>PASSED: mpi_type_vector"
      end

!!!!!!!!!!!!!!!!!!!!!
! Byte-addressed vector.
! values calculated with mpi_type_extent(),
! so basically we are doing the work here in the
! test program instead of in the library
!!!!!!!!!!!!!!!!!!!!!

      subroutine test_simple_hvector()
      use mpi
        integer vector_type
        integer (kind=mpi_address_kind) extent
        integer i
        integer a(10)
        integer b(10)
        integer index_test(6)
        integer ierr

        data a/1,2,3,4,5,6,7,8,9,10/, b/0,0,0,0,0,0,0,0,0,0/
        data index_test/1,2,5,6,9,10/

        print *, "Vector type of 3 groups of 2 MPI_INTEGER"
        print *, "Stride of 4 (in bytes)"

        call mpi_type_extent(mpi_integer, extent, ierr)
        call mpi_type_hvector(3, 2, 4 * extent, mpi_integer, &
             vector_type, ierr)
        call mpi_type_commit(vector_type, ierr)
        call print_typemap(vector_type,ierr)
        call copy_data2(a,1,vector_type, b,1,vector_type,ierr)

        do i=1,7
          if (a(index_test(i)) .ne. (b(index_test(i)))) then
            print *, ">>>FAILED: test_simple_hvector"
            stop
          end if
        end do
      print *, ">>>PASSED: test_simple_hvector"
      end subroutine

!!!!!!!!!!!!!!!!!!!!
! indexed type.  test certain indices of an array
!!!!!!!!!!!!!!!!!!!!

      subroutine test_simple_indexed()
      use mpi
        integer i
        complex a(15)
        complex b(15)
        integer index_test(6)
        integer blens(3)
        integer disps(3)
        integer indexed_type
        integer ierr

        data a/1,2,3,4,5,6,7,8,9,10,11,12,13,14,15/
        data b/0,0,0,0,0,0,0,0,0,0,0,0,0,0,0/
        data index_test/1,6,7,11,12,13/
        data blens/2,1,3/
        data disps/5,0,10/
        print *, "Indexed type"

        call mpi_type_indexed(3, blens, disps, mpi_complex, &
                         indexed_type, ierr)
        call mpi_type_commit(indexed_type, ierr)
        call print_typemap(indexed_type, ierr)
        call copy_data2(a,1,indexed_type, b,1,indexed_type,ierr)

        do i=1,6
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, ">>>FAILED: test_simple_indexed"
            stop
          end if
        end do
        print *, ">>>PASSED: test_simple_indexed"
      end subroutine

!!!!!!!!!!!!!!!!
! Block indexed.  All blocks have same length
!!!!!!!!!!!!!!!!

      subroutine test_simple_bindexed()
      use mpi
        integer i
        integer disps(3)
        integer a(10), b(10)
        integer index_test(6)
        integer indexed_type
        integer ierr

        data disps/0,4,7/
        data a/1,2,3,4,5,6,7,8,9,10/
        data b/0,0,0,0,0,0,0,0,0,0/
        data index_test/1,2,5,6,8,9/
        print *, "Block indexed type"

        call mpi_type_indexed_block(3,2,disps,mpi_integer, &
                        indexed_type, ierr)

        call mpi_type_commit(indexed_type, ierr)
        call print_typemap(indexed_type, ierr)
        call copy_data2(a,1,indexed_type, b,1,indexed_type, ierr)

        do i=1,6
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, ">>>FAILED: test_simple_bindexed"
            stop
          end if
        end do
        print *, ">>>PASSED: test_simple_bindexed"
      end subroutine

!!!!!!!!!!!!!!!!
! test_simple_indexed
!  test equality of a byte-addressed
!  type of integer array
!  (disps calculated through mpi_type_extent()
!!!!!!!!!!!!!!!
      subroutine test_simple_hindexed()
      use mpi
        integer i
        integer a(10), b(10)
        integer index_test(6)
        integer blens(3)
        integer*8 disps(3)
        integer indexed_type
        integer*8 extent
        integer ierr

        data a/1,2,3,4,5,6,7,8,9,10/
        data b/0,0,0,0,0,0,0,0,0,0/
        data index_test/1,3,4,6,7,8/
        data blens/2,1,3/

        call mpi_type_extent(mpi_integer, extent, ierr)
        disps(1) = 2*extent
        disps(2) = 0
        disps(3) = 5*extent


        print *, "Byte addressed indexed type"
        call mpi_type_hindexed(3,blens,disps, MPI_INTEGER, &
             indexed_type,ierr)
        call mpi_type_commit(indexed_type, ierr)
        call print_typemap(indexed_type, ierr)
        call copy_data2(a,1,indexed_type, b,1,indexed_type, ierr)

        do i=1,6
          if (a(index_test(i)) .ne. b(index_test(i))) then
            print *, ">>>FAILED: test_simple_hindexed"
            stop
          end if
        end do
        print *, ">>>PASSED: test_simple_hindexed"
      end subroutine

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! test_packed()
! Creates a few variable pairs, assigns the first
!  of each pair, then packs their values and unpacks
!  them to the other set.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      subroutine test_packed()
      use mpi
        integer size
        integer x, y
        real f, g
        complex c, d
        character*5 a, b
        character buf(100), rbuf(100)
        integer blens(3)
        integer(kind=mpi_address_kind) disps(3)
        integer pos


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

        call copy_data2(buf, pos, mpi_packed, rbuf, pos, &
                        mpi_packed, ierr)

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
          stop
        end if

        print *, ">>>PASSED: mpi_pack"

      end subroutine

!!!!!!!!!!!!!!!!!!!!!!!!!
! Test an indexed send with a multiple receive
!!!!!!!!!!!!!!!!!!!!!!!!!

      subroutine test_multiple()
      use mpi
        integer i
        complex a(15)
        complex b(15)
        integer index_test(6)
        integer blens(3)
        integer disps(3)
        integer indexed_type
        integer ierr

        data a/1,2,3,4,5,6,7,8,9,10,11,12,13,14,15/
        data b/0,0,0,0,0,0,0,0,0,0,0,0,0,0,0/
        data index_test/1,6,7,11,12,13/
        data blens/1,2,3/
        data disps/0,5,10/
        print *, "Indexed type"

        call mpi_type_indexed(3, blens, disps, mpi_complex, &
                         indexed_type, ierr)
        call mpi_type_commit(indexed_type, ierr)
        call copy_data2(a,1,indexed_type, b,6, mpi_complex, ierr)

        do i=1,6
          if (a(index_test(i)) .ne. b(i)) then
            print *, ">>>FAILED: test_multiple"
            stop
          end if
        end do
        print *, ">>>PASSED: test_multiple"
      end subroutine

