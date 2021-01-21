!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: coupler.F90,v 1.8 2004-04-23 20:57:10 jacob Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !ROUTINE: coupler -- coupler for unit tester
!
! !DESCRIPTION:
! A coupler subroutine to test functionality of MCT.
!
! !INTERFACE:
!
      subroutine coupler (comm,ncomps,compid)
!
! !USES:
!
! Get the things needed from MCT by "Use,only" with renaming:
!
! ---------- first group is identical to what model.F90 uses ----
!
!---Component Model Registry
      use m_MCTWorld,only: MCTWorld_init => init
      use m_MCTWorld,only: MCTWorld_clean => clean
!---Domain Decomposition Descriptor DataType and associated methods
      use m_GlobalSegMap,only: GlobalSegMap
      use m_GlobalSegMap,only: GlobalSegMap_init => init
      use m_GlobalSegMap,only: GlobalSegMap_lsize => lsize
      use m_GlobalSegMap,only: GlobalSegMap_clean => clean
      use m_GlobalSegMap,only: GlobalSegMap_Ordpnts => OrderedPoints
!---Field Storage DataType and associated methods
      use m_AttrVect,only    : AttrVect
      use m_AttrVect,only    : AttrVect_init => init
      use m_AttrVect,only    : AttrVect_clean => clean
      use m_AttrVect,only    : AttrVect_importRAttr => importRAttr
!---Intercomponent communications scheduler
      use m_Router,only: Router
      use m_Router,only: Router_init => init
      use m_Router,only: Router_clean => clean
!---Intercomponent transfer
      use m_Transfer,only : MCT_Send => send
      use m_Transfer,only : MCT_Recv => recv

! ---------- because coupler will do the interpolation  ---------
!                it needs more methods
!
!---Sparse Matrix DataType and associated methods
      use m_SparseMatrix, only : SparseMatrix
      use m_SparseMatrix, only : SparseMatrix_init => init
      use m_SparseMatrix, only : SparseMatrix_importGRowInd => &
                                                      importGlobalRowIndices
      use m_SparseMatrix, only : SparseMatrix_importGColInd => &
                                                      importGlobalColumnIndices
      use m_SparseMatrix, only : SparseMatrix_importMatrixElts => &
                                                           importMatrixElements
      use m_SparseMatrixPlus, only : SparseMatrixPlus
      use m_SparseMatrixPlus, only : SparseMatrixPlus_init => init
      use m_SparseMatrixPlus, only : SparseMatrixPlus_clean => clean
      use m_SparseMatrixPlus, only : Xonly ! Decompose matrix by row
!---Matrix-Vector multiply methods
      use m_MatAttrVectMul, only: MCT_MatVecMul => sMatAvMult

!---MPEU I/O utilities
      use m_stdio
      use m_ioutil

      implicit none

      include "mpif.h"

! !INPUT PARAMETERS:

      integer,intent(in) :: comm
      integer,intent(in) :: ncomps
      integer,intent(in) :: compid
!
!EOP ___________________________________________________________________

!     Local variables

      character(len=*), parameter :: cplname='coupler.F90'

      integer :: nxa   !  number of points in x-direction, atmos
      integer :: nya   !  number of points in y-direction, atmos
      integer :: nxo  !  number of points in x-direction, ocean
      integer :: nyo   !  number of points in y-direction, ocean

      character(len=100),parameter :: &
        RemapMatrixFile='../../data/t42_to_popx1_c_mat.asc'

! Loop indicies
      integer :: i,j,k,n

      logical :: match

! MPI variables
      integer :: rank, nprocs, root, ierr
! MCTWorld variables
      integer :: AtmID
! Grid variables
      integer :: localsize
! GlobalSegMap variables
      type(GlobalSegMap)   :: AtmGSMap, OcnGSMap
      integer,dimension(1) :: start,length
      integer, dimension(:), pointer :: points
      integer :: latsize, lonsize
      integer :: rowindex, colindex, boxvertex
! AttVect variables
      type(AttrVect) :: AtmAV, OcnAV
      integer :: aavsize,oavsize
! Router variables
      type(Router) :: Rout
! SparseMatrix variables
      integer :: mdev
      integer :: num_elements, nRows, nColumns
      integer, dimension(2) :: src_dims, dst_dims
      integer, dimension(:), pointer :: rows, columns
      real, dimension(:), pointer :: weights
! A2O SparseMatrix elements on root
      type(SparseMatrix) :: sMat
! A2O distributed SparseMatrixPlus variables
      type(SparseMatrixPlus) :: A2OMatPlus
! _____________________________________________________________________

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   INITIALIZATION PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


      ! LOCAL RANK AND SIZE
      call MPI_COMM_RANK(comm,rank,ierr)
      call MPI_COMM_SIZE(comm,nprocs,ierr)
      root = 0

      if(rank==0) write(6,*) cplname,' MyID ', compid
      if(rank==0) write(6,*) cplname,' Num procs ', nprocs

      ! Initialize MCTworld
      call MCTWorld_init(ncomps,MPI_COMM_WORLD,comm,compid)

      ! Set the atm component id.  Must be known to this
      !  component.  (MCT doesn't handle that).
      AtmID=1

      ! Set grid dimensions for atmosphere and ocean grids.
      ! MCT could be used for this (by defining a GeneralGrid in
      ! each and sending them to the coupler) but for this simple
      ! example, we'll assume they're known to the coupler
      nxa = 128
      nya = 64

      nxo = 320
      nyo = 384

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Read matrix weights for interpolation from a file.
      if (rank == root) then
         mdev = luavail()
         open(mdev, file=trim(RemapMatrixFile), status="old")
         read(mdev,*) num_elements
         read(mdev,*) src_dims(1), src_dims(2)
         read(mdev,*) dst_dims(1), dst_dims(2)

         allocate(rows(num_elements), columns(num_elements), &
              weights(num_elements), stat=ierr)

         do n=1, num_elements
            read(mdev,*) rows(n), columns(n), weights(n)
         end do

         close(mdev)

         ! Initialize a Sparsematrix
         nRows = dst_dims(1) * dst_dims(2)
         nColumns = src_dims(1) * src_dims(2)
         call SparseMatrix_init(sMat,nRows,nColumns,num_elements)
         call SparseMatrix_importGRowInd(sMat, rows, size(rows))
         call SparseMatrix_importGColInd(sMat, columns, size(columns))
         call SparseMatrix_importMatrixElts(sMat, weights, size(weights))

         deallocate(rows, columns, weights, stat=ierr)

      endif
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Initialize a Global Segment Map for the Ocean

      ! Set up a 1-d decomposition.
      ! There is just 1 segment per processor
      localsize = nxo*nyo / nprocs

      ! we'll use the distributed init of GSMap so
      ! initialize start and length arrays for this processor
      start(1) = (rank*localsize) + 1
      length(1) = localsize

      ! initialize the GSMap
      call GlobalSegMap_init(OcnGSMap,start,length,root,comm,compid)
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Initialize a Global Segment Map for the Atmosphere

      ! Set up a 1-d decomposition.
      ! There is just 1 segment per processor
      localsize = nxa*nya / nprocs

      ! we'll use the distributed init of GSMap so
      ! initialize start and length arrays for this processor
      start(1) = (rank*localsize) + 1
      length(1) = localsize

      ! initialize the GSMap
      call GlobalSegMap_init(AtmGSMap,start,length,root,comm,compid)
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      ! Use a GSMap function:
      ! return the points local to this processor
      ! in their assumed order.
      call GlobalSegMap_Ordpnts(AtmGSMap,rank,points)


      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Build a SparseMatrixPlus for doing the interpolation
      ! Specify matrix decomposition to be by row.
      ! following the atmosphere's decomposition.
      call SparseMatrixPlus_init(A2OMatPlus, sMat, AtmGSMap, OcnGSMap, &
           Xonly, root, comm, compid)

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Initialize and Attribute vector the atmosphere grid
      aavsize = GlobalSegMap_lsize(AtmGSMap,comm)
      if(rank==0) write(6,*) cplname, ' localsize: Atm ', aavsize
      call AttrVect_init(AtmAV,rList="field1:field2",lsize=aavsize)


      ! Initialize and Attribute vector the ocean grid
      oavsize = GlobalSegMap_lsize(OcnGSMap,comm)
      if(rank==0) write(6,*) cplname, ' localsize: Ocn ', oavsize
      call AttrVect_init(OcnAV,rList="field1:field2",lsize=oavsize)
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! Initialize a Router
      call Router_init(AtmID,AtmGSMap,comm,Rout)

!!! END OF INIT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   RUN PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      do j=1,10   ! "timestep" loop


        ! coupler calculations here

        match=.TRUE.

        ! Receive the data
        call MCT_Recv(AtmAV,Rout)

        ! The 2nd attribute has the values of each gridpoint in
        ! the index numbering scheme.  Check the received values
        ! against the points on the this processor.  They should
        ! match exactly.
        do i=1,aavsize
           if( int(AtmAV%rAttr(2,i)) .ne. points(i)) then
             write(6,*) cplname,rank, " Data doesn't match ",i
             match=.FALSE.
           endif
        enddo
        if(match .and. j==10) &
         write(6,*) cplname," Last step, All points match on ",rank

        if(rank==0) write(6,*) cplname, " Received data step ",j

        ! Interpolate by doing a parallel sparsematrix-attrvect multiply
        ! Note:  it doesn't make much sense to interpolate "field2" which
        ! is the grid point indicies but MatVecMul will interpolate all
        ! real attributes.
        call MCT_MatVecMul(AtmAV, A2OMatPlus, OcnAV)
        if(rank==0) write(6,*) cplname," Data transformed step ",j


        ! pass interpolated data on to ocean model and/or
        !  do more calculations

      enddo


!!! END OF RUN  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   FINALIZE PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      ! deallocate memory
      call Router_clean(Rout)
      call AttrVect_clean(AtmAV)
      call AttrVect_clean(OcnAV)
      call GlobalSegMap_clean(AtmGSMap)
      call GlobalSegMap_clean(OcnGSMap)
      call MCTWorld_clean()
      if(rank==0) write(6,*) cplname, " done"

    end subroutine coupler

