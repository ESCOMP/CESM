!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math + Computer Science Division / Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!BOP -------------------------------------------------------------------
!
! !MODULE: m_MatAttrVectMul - Sparse Matrix AttrVect Multipication.
!
! !DESCRIPTION:
!
! This module contains routines supporting the sparse matrix-vector
! multiplication
! $${\bf y} = {\bf M} {\bf x},$$
! where the vectors {\bf x} and {\bf y} are stored using the MCT
! {\tt AttrVect} datatype, and {\bf M} is stored using either the MCT
! {\tt SparseMatrix} or {\tt SparseMatrixPlus} type.  The {\tt SparseMatrix}
! type is used to represent {\bf M} if the multiplication process is
! purely data-local (e.g., in a global address space, or if the process
! has been rendered embarrasingly parallel by earlier or subsequent
! vector data redistributions).  If the multiplication process is to
! be explicitly distributed-memory parallel, then the {\tt SparseMatrixPlus}
! type is used to store the elements of {\bf M} and all information needed
! to coordinate data redistribution and reduction of partial sums.
!
! {\bf N.B.:} The matrix-vector multiplication routines in this module
! process only the {\bf real} attributes of the {\tt AttrVect} arguments
! corresponding to {\bf x} and {\bf y}.  They ignore the integer attributes.
!
! !INTERFACE:

 module m_MatAttrVectMul

      private   ! except

      public :: sMatAvMult        ! The master Sparse Matrix -
                                  ! Attribute Vector multipy API

    interface sMatAvMult   ; module procedure &
        sMatAvMult_DataLocal_, &
        sMatAvMult_sMPlus_
    end interface

! !SEE ALSO:
! The MCT module m_AttrVect for more information about the AttrVect type.
! The MCT module m_SparseMatrix for more information about the SparseMatrix
! type.
! The MCT module m_SparseMatrixPlus for more details about the master class
! for parallel sparse matrix-vector multiplication, the SparseMatrixPlus.

! !REVISION HISTORY:
! 12Jan01 - J.W. Larson <larson@mcs.anl.gov> - initial module.
! 26Sep02 - J.W. Larson <larson@mcs.anl.gov> - added high-level, distributed
!           matrix-vector multiply routine using the SparseMatrixPlus class.
!
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname='MCT::m_MatAttrVectMul'

 contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math + Computer Science Division / Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: sMatAvMult_DataLocal -- Purely local matrix-vector multiply
!
! !DESCRIPTION:
!
! The sparse matrix-vector multiplication routine {\tt sMatAvMult\_DataLocal\_()}
! operates on the assumption of total data locality, which is equivalent
! to the following two conditions:
! \begin{enumerate}
! \item The input {\tt AttrVect} {\tt xAV} contains all the values referenced
! by the local column indices stored in the input {\tt SparsMatrix} argument
! {\tt sMat}; and
! \item The output {\tt AttrVect} {\tt yAV} contains all the values referenced
! by the local row indices stored in the input {\tt SparsMatrix} argument
! {\tt sMat}.
! \end{enumerate}
! By default, the multiplication occurs for each of the common {\tt REAL} attributes
! shared by {\tt xAV} and {\tt yAV}.  This routine is capable of
! cross-indexing the attributes and performing the necessary multiplications.
!
! If the optional argument {\tt rList} is present, only the attributes listed will
! be multiplied.  If the attributes have different names in {\tt yAV}, the optional
! {\tt TrList} argument can be used to provide the translation.
!
! If the optional argument {\tt Vector} is present and true, the vector
! architecture-friendly portions of this routine will be invoked.  It
! will also cause the vector parts of {\\ sMat} to be initialized if they
! have not been already.
!
! !INTERFACE:

 subroutine sMatAvMult_DataLocal_(xAV, sMat, yAV, Vector, rList, TrList)
!
! !USES:
!
      use m_realkinds, only : FP
      use m_stdio,     only : stderr
      use m_die,       only : MP_perr_die, die, warn

      use m_List, only : List_identical => identical
      use m_List, only : List_nitem => nitem
      use m_List, only : GetIndices => get_indices

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_zero => zero
      use m_AttrVect, only : AttrVect_indexRA => indexRA
      use m_AttrVect, only : SharedAttrIndexList

      use m_SparseMatrix, only : SparseMatrix
      use m_SparseMatrix, only : SparseMatrix_lsize => lsize
      use m_SparseMatrix, only : SparseMatrix_indexIA => indexIA
      use m_SparseMatrix, only : SparseMatrix_indexRA => indexRA
      use m_SparseMatrix, only : SparseMatrix_vecinit => vecinit

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),     intent(in)    :: xAV
      logical,optional,   intent(in)    :: Vector
      character(len=*),optional, intent(in)    :: rList
      character(len=*),optional, intent(in)    :: TrList


! !INPUT/OUTPUT PARAMETERS:

      type(SparseMatrix), intent(inout)    :: sMat
      type(AttrVect),     intent(inout) :: yAV

! !REVISION HISTORY:
! 15Jan01 - J.W. Larson <larson@mcs.anl.gov> - API specification.
! 10Feb01 - J.W. Larson <larson@mcs.anl.gov> - Prototype code.
! 24Apr01 - J.W. Larson <larson@mcs.anl.gov> - Modified to accomodate
!           changes to the SparseMatrix datatype.
! 25Apr01 - J.W. Larson <larson@mcs.anl.gov> - Reversed loop order
!           for cache-friendliness
! 17May01 - R. Jacob <jacob@mcs.anl.gov> - Zero the output
!           attribute vector
! 10Oct01 - J. Larson <larson@mcs.anl.gov> - Added optional LOGICAL
!           input argument InterpInts to make application of the
!           multiply to INTEGER attributes optional
! 15Oct01 - J. Larson <larson@mcs.anl.gov> - Added feature to
!           detect when attribute lists are identical, and cross-
!           indexing of attributes is not needed.
! 29Nov01 - E.T. Ong <eong@mcs.anl.gov> - Removed MP_PERR_DIE if
!           there are zero elements in sMat. This allows for
!           decompositions where a process may own zero points.
! 29Oct03 - R. Jacob <jacob@mcs.anl.gov> - add Vector argument to
!           optionally use the vector-friendly version provided by
!           Fujitsu
! 21Nov06 - R. Jacob <jacob@mcs.anl.gov> - Allow attributes to be
!           to be multiplied to be specified with rList and TrList.
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::sMatAvMult_DataLocal_'

! Matrix element count:
  integer :: num_elements

! Matrix row, column, and weight indices:
  integer :: icol, irow, iwgt

! Overlapping attribute index number
  integer :: num_indices

! Overlapping attribute index storage arrays:
  integer, dimension(:), pointer :: xAVindices, yAVindices

! Temporary variables for multiply do-loop
  integer :: row, col
  real(FP) :: wgt

! Error flag and loop indices
  integer :: ierr, i, m, n, l,ier
  integer :: inxmin,outxmin
  integer :: ysize, numav,j

! Character variable used as a data type flag:
  character*7 :: data_flag

! logical flag
  logical :: usevector,TrListIsPresent,rListIsPresent
  logical :: contiguous,ycontiguous


  usevector = .false.
  if(present(Vector)) then
    if(Vector) usevector = .true.
  endif

  rListIsPresent = .false.
  if(present(rList)) then
    rListIsPresent = .true.
  endif

!  TrList is present if it is provided and its length>0
  TrListIsPresent = .false.
  if(present(TrList)) then
     if(.not.present(rList)) then
       call die(myname_,'MCTERROR: TrList provided without rList',2)
     endif
     if(len_trim(TrList) > 0) then
       TrListIsPresent = .true.
     endif
  endif


       ! Retrieve the number of elements in sMat:

  num_elements = SparseMatrix_lsize(sMat)

       ! Indexing the sparse matrix sMat:

  irow = SparseMatrix_indexIA(sMat,'lrow')    ! local row index
  icol = SparseMatrix_indexIA(sMat,'lcol')    ! local column index
  iwgt = SparseMatrix_indexRA(sMat,'weight')  ! weight index


       ! Multiplication sMat by REAL attributes in xAV:

  if(List_identical(xAV%rList, yAV%rList).and.   &
    .not.rListIsPresent) then                  ! no cross-indexing

       ! zero the output AttributeVector
     call AttrVect_zero(yAV, zeroInts=.FALSE.)

     num_indices = List_nitem(xAV%rList)

     if(usevector) then

       if(.not.sMat%vecinit) then
            call SparseMatrix_vecinit(sMat)
       endif

!DIR$ IVDEP
       do m=1,num_indices
          do l=1,sMat%tbl_end
!CDIR NOLOOPCHG
!DIR$ IVDEP
             do i=sMat%row_s(l),sMat%row_e(l)
               col = sMat%tcol(i,l)
               wgt = sMat%twgt(i,l)
               if (col < 0) cycle
               yAV%rAttr(m,i) = yAV%rAttr(m,i) + wgt * xAV%rAttr(m,col)
             enddo
          enddo
       enddo

     else

       do n=1,num_elements

    	  row = sMat%data%iAttr(irow,n)
    	  col = sMat%data%iAttr(icol,n)
	  wgt = sMat%data%rAttr(iwgt,n)

         ! loop over attributes being regridded.

!DIR$ IVDEP
	  do m=1,num_indices

	     yAV%rAttr(m,row) = yAV%rAttr(m,row) + wgt * xAV%rAttr(m,col)

  	  end do ! m=1,num_indices

       end do ! n=1,num_elements

     endif

! lists are not identical or only want to do part.
  else

   if(rListIsPresent) then
     call GetIndices(xAVindices,xAV%rList,trim(rList))

     if(TrListIsPresent) then
       call GetIndices(yAVindices,yAV%rList,trim(TrList))

       if(size(xAVindices) /= size(yAVindices)) then
         call die(myname_,"Arguments rList and TrList do not&
             &contain the same number of items")
       endif

     else
       call GetIndices(yAVindices,yAV%rList,trim(rList))
     endif

     num_indices=size(yAVindices)

     ! nothing to do if num_indices <=0
     if (num_indices <= 0) then
       deallocate(xaVindices, yAVindices, stat=ier)
       if(ier/=0) call die(myname_,"deallocate(xAVindices...)",ier)
       return
     endif

   else

     data_flag = 'REAL'
     call SharedAttrIndexList(xAV, yAV, data_flag, num_indices, &
	                      xAVindices, yAVindices)

     ! nothing to do if num_indices <=0
     if (num_indices <= 0) then
       deallocate(xaVindices, yAVindices, stat=ier)
       call warn(myname_,"No matching indicies found, returning.")
       if(ier/=0) call die(myname_,"deallocate(xaVinindices...)",ier)
       return
     endif
   endif

! Check if the indices are contiguous in memory for faster copy
   contiguous=.true.
   ycontiguous=.true.
   do i=2,num_indices
      if(xaVindices(i) /= xAVindices(i-1)+1) then
         contiguous = .false.
         exit
      endif
   enddo
   if(contiguous) then
      do i=2,num_indices
          if(yAVindices(i) /= yAVindices(i-1)+1) then
	    contiguous=.false.
            ycontiguous=.false.
            exit
          endif
      enddo
   endif

       ! zero the right parts of the output AttributeVector
   ysize = AttrVect_lsize(yAV)
   numav=size(yAVindices)

   if(ycontiguous) then
     outxmin=yaVindices(1)-1
!dir$ collapse
     do j=1,ysize
       do i=1,numav
         yAV%rAttr(outxmin+i,j)=0._FP
       enddo
     enddo
   else
     do j=1,ysize
       do i=1,numav
         yAV%rAttr(yaVindices(i),j)=0._FP
       enddo
     enddo
   endif

       ! loop over matrix elements

   if(contiguous) then
     outxmin=yaVindices(1)-1
     inxmin=xaVindices(1)-1
     do n=1,num_elements

	row = sMat%data%iAttr(irow,n)
	col = sMat%data%iAttr(icol,n)
	wgt = sMat%data%rAttr(iwgt,n)

       ! loop over attributes being regridded.
!DIR$ IVDEP
  	do m=1,num_indices
	    yAV%rAttr(outxmin+m,row) = &
	       yAV%rAttr(outxmin+m,row) + &
	       wgt * xAV%rAttr(inxmin+m,col)
        end do ! m=1,num_indices
     end do ! n=1,num_elements
   else
     do n=1,num_elements

	row = sMat%data%iAttr(irow,n)
	col = sMat%data%iAttr(icol,n)
	wgt = sMat%data%rAttr(iwgt,n)

       ! loop over attributes being regridded.
!DIR$ IVDEP
  	do m=1,num_indices
	    yAV%rAttr(yAVindices(m),row) = &
	       yAV%rAttr(yAVindices(m),row) + &
	       wgt * xAV%rAttr(xAVindices(m),col)
        end do ! m=1,num_indices
     end do ! n=1,num_elements
   endif


   deallocate(xAVindices, yAVindices, stat=ierr)
   if(ierr /= 0) call die(myname_,'first deallocate(xAVindices...',ierr)

  endif ! if(List_identical(xAV%rAttr, yAV%rAttr))...
        ! And we are finished!

 end subroutine sMatAvMult_DataLocal_

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!     Math + Computer Science Division / Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: sMatAvMult_SMPlus_ - Parallel Multiply Using SparseMatrixPlus
!
! !DESCRIPTION:
! This routine performs distributed parallel sparse matrix-vector
! multiplication ${\bf y} = {\bf M} {\bf x}$, where {\bf y} and
! {\bf x} are represented by the {\tt AttrVect} arguments {\tt yAV} and
! {\tt xAV}, respectively.  The matrix {\bf M} is stored in the input
! {\tt SparseMatrixPlus} argument {\tt sMatPlus}, which also contains
! all the information needed to coordinate the communications required to
! gather intermediate vectors used in the multiplication process, and to
! reduce partial sums as needed.
! By default, the multiplication occurs for each of the common {\tt REAL} attributes
! shared by {\tt xAV} and {\tt yAV}.  This routine is capable of
! cross-indexing the attributes and performing the necessary multiplications.
!
! If the optional argument {\tt rList} is present, only the attributes listed will
! be multiplied.  If the attributes have different names in {\tt yAV}, the optional
! {\tt TrList} argument can be used to provide the translation.
!
! If the optional argument {\tt Vector} is present and true, the vector
! architecture-friendly portions of this routine will be invoked.  It
! will also cause the vector parts of {\tt sMatPlus} to be initialized if they
! have not been already.
!
! !INTERFACE:

 subroutine sMatAvMult_SMPlus_(xAV, sMatPlus, yAV, Vector, rList, TrList)
!
! !USES:
!
      use m_stdio
      use m_die
      use m_mpif90

      use m_String, only : String
      use m_String, only : String_ToChar => ToChar

      use m_AttrVect, only : AttrVect
      use m_AttrVect, only : AttrVect_init => init
      use m_AttrVect, only : AttrVect_lsize => lsize
      use m_AttrVect, only : AttrVect_clean => clean
      use m_AttrVect, only : AttrVect_Rcopy => Rcopy
      use m_AttrVect, only : AttrVect_zero  => zero

      use m_Rearranger, only : Rearranger
      use m_Rearranger, only : Rearrange

      use m_SparseMatrixPlus, only : SparseMatrixPlus
      use m_SparseMatrixPlus, only : Xonly
      use m_SparseMatrixPlus, only : Yonly
      use m_SparseMatrixPlus, only : XandY

      implicit none

! !INPUT PARAMETERS:

      type(AttrVect),         intent(in)    :: xAV
      logical, optional,      intent(in)    :: Vector
      character(len=*),optional, intent(in)    :: rList
      character(len=*),optional, intent(in)    :: TrList

! !INPUT/OUTPUT PARAMETERS:

      type(AttrVect),         intent(inout) :: yAV
      type(SparseMatrixPlus), intent(inout) :: sMatPlus

! !SEE ALSO:
! The MCT module m_AttrVect for more information about the AttrVect type.
! The MCT module m_SparseMatrixPlus for more information about the
! SparseMatrixPlus type.

! !REVISION HISTORY:
! 26Sep02 - J.W. Larson <larson@mcs.anl.gov> - API specification and
!           implementation.
! 29Oct03 - R. Jacob <jacob@mcs.anl.gov> - add vector argument to all
!           calls to Rearrange and DataLocal_.  Add optional input
!           argument to change value (assumed false)
! 22Nov06 - R. Jacob <jacob@mcs.anl.gov> - add rList,TrList arguments
! 10Jan08 - T. Craig <tcraig@ucar.edu> - zero out intermediate aVs before
!           they are used
!EOP ___________________________________________________________________

  character(len=*),parameter :: myname_=myname//'::sMatAvMult_SMPlus_'
  type(AttrVect) :: xPrimeAV, yPrimeAV
  type(AttrVect) :: yAVre
  integer :: ierr
  logical ::  usevector
  character(len=5) :: strat

  ! check arguments
  if(present(TrList)) then
     if(.not.present(rList)) then
       call die(myname_,'MCTERROR: TrList provided without rList',2)
     endif
  endif

  usevector = .FALSE.
  if(present(Vector)) then
   if(Vector)usevector = .TRUE.
  endif
       ! Examine the parallelization strategy, and act accordingly

  strat = String_ToChar(sMatPlus%Strategy)
  select case( strat )
  case('Xonly')
       ! Create intermediate AttrVect for x'
     call AttrVect_init(xPrimeAV, xAV, sMatPlus%XPrimeLength)
     call AttrVect_zero(xPrimeAV)
       ! Rearrange data from x to get x'
     call Rearrange(xAV, xPrimeAV, sMatPlus%XToXPrime, &
                    tag=sMatPlus%Tag, vector=usevector,&
                    alltoall=.true., handshake=.true.  )

       ! Perform perfectly data-local multiply y = Mx'
     if (present(TrList).and.present(rList)) then
       call sMatAvMult_DataLocal_(xPrimeAV, sMatPlus%Matrix, yaV, &
              Vector=usevector,rList=rList,TrList=TrList)
     else if(.not.present(TrList) .and. present(rList)) then
       call sMatAvMult_DataLocal_(xPrimeAV, sMatPlus%Matrix, yaV, &
               Vector=usevector,rList=rList)
     else
       call sMatAvMult_DataLocal_(xPrimeAV, sMatPlus%Matrix, yaV, &
               Vector=usevector)
     endif

       ! Clean up space occupied by x'
     call AttrVect_clean(xPrimeAV, ierr)
  case('Yonly')
       ! Create intermediate AttrVect for y'
     if (present(TrList).and.present(rList)) then
        call AttrVect_init(yPrimeAV, rList=TrList, lsize=sMatPlus%YPrimeLength)
     else if(.not.present(TrList) .and. present(rList)) then
        call AttrVect_init(yPrimeAV, rList=rList, lsize=sMatPlus%YPrimeLength)
     else
        call AttrVect_init(yPrimeAV, yAV, sMatPlus%YPrimeLength)
     endif
     call AttrVect_zero(yPrimeAV)

     if (present(TrList).or.present(rList)) then
        call AttrVect_init(yAVre, yPrimeAV , lsize=AttrVect_lsize(yAV))
        call AttrVect_zero(yAVre)
     endif

       ! Perform perfectly data-local multiply y' = Mx
     if (present(TrList).and.present(rList)) then
        call sMatAvMult_DataLocal_(xAV, sMatPlus%Matrix, yPrimeAV, &
	       Vector=usevector,rList=rList,TrList=TrList)
     else if(.not.present(TrList) .and. present(rList)) then
        call sMatAvMult_DataLocal_(xAV, sMatPlus%Matrix, yPrimeAV, &
	       Vector=usevector,rList=rList)
     else
        call sMatAvMult_DataLocal_(xAV, sMatPlus%Matrix, yPrimeAV, &
	       Vector=usevector)
     endif

       ! Rearrange/reduce partial sums in y' to get y
     if (present(TrList).or.present(rList)) then
       call Rearrange(yPrimeAV, yAVre, sMatPlus%YPrimeToY,            &
                      tag=sMatPlus%Tag, sum=.TRUE., Vector=usevector, &
                      alltoall=.true., handshake=.true.               )
       call AttrVect_Rcopy(yAVre,yAV,vector=usevector)
       call AttrVect_clean(yAVre, ierr)
     else
       call Rearrange(yPrimeAV, yAV, sMatPlus%YPrimeToY,              &
                      tag=sMatPlus%Tag, sum=.TRUE., Vector=usevector, &
                      alltoall=.true., handshake=.true.               )
     endif
       ! Clean up space occupied by y'
     call AttrVect_clean(yPrimeAV, ierr)

  case('XandY')
       ! Create intermediate AttrVect for x'
     call AttrVect_init(xPrimeAV, xAV, sMatPlus%XPrimeLength)
     call AttrVect_zero(xPrimeAV)

       ! Create intermediate AttrVect for y'
     if (present(TrList).and.present(rList)) then
        call AttrVect_init(yPrimeAV, rList=TrList, lsize=sMatPlus%YPrimeLength)
     else if(.not.present(TrList) .and. present(rList)) then
        call AttrVect_init(yPrimeAV, rList=rList, lsize=sMatPlus%YPrimeLength)
     else
        call AttrVect_init(yPrimeAV, yAV, sMatPlus%YPrimeLength)
     endif
     call AttrVect_zero(yPrimeAV)

     if (present(TrList).or.present(rList)) then
        call AttrVect_init(yAVre, yPrimeAV , lsize=AttrVect_lsize(yAV))
        call AttrVect_zero(yAVre)
     endif

       ! Rearrange data from x to get x'
     call Rearrange(xAV, xPrimeAV, sMatPlus%XToXPrime,  &
                    tag=sMatPlus%Tag, Vector=usevector, &
                    alltoall=.true., handshake=.true.   )

       ! Perform perfectly data-local multiply y' = Mx'
     if (present(TrList).and.present(rList)) then
         call sMatAvMult_DataLocal_(xPrimeAV, sMatPlus%Matrix, yPrimeAV, &
                             Vector=usevector,rList=rList,TrList=TrList)
     else if(.not.present(TrList) .and. present(rList)) then
         call sMatAvMult_DataLocal_(xPrimeAV, sMatPlus%Matrix, yPrimeAV, &
                             Vector=usevector,rList=rList)
     else
         call sMatAvMult_DataLocal_(xPrimeAV, sMatPlus%Matrix, yPrimeAV, &
                             Vector=usevector)
     endif

       ! Rearrange/reduce partial sums in y' to get y
     if (present(TrList).or.present(rList)) then
       call Rearrange(yPrimeAV, yAVre, sMatPlus%YPrimeToY,            &
                      tag=sMatPlus%Tag, sum=.TRUE., Vector=usevector, &
                      alltoall=.true., handshake=.true.               )
       call AttrVect_Rcopy(yAVre,yAV,vector=usevector)
       call AttrVect_clean(yAVre, ierr)
     else
       call Rearrange(yPrimeAV, yAV, sMatPlus%YPrimeToY,              &
                      tag=sMatPlus%Tag, sum=.TRUE., Vector=usevector, &
                      alltoall=.true., handshake=.true.               )
     endif

       ! Clean up space occupied by x'
     call AttrVect_clean(xPrimeAV, ierr)
       ! Clean up space occupied by y'
     call AttrVect_clean(yPrimeAV, ierr)
  case default
     write(stderr,'(4a)') myname_, &
	  ':: FATAL ERROR--parallelization strategy name ',&
	  String_ToChar(sMatPlus%Strategy),' not supported.'
     call die(myname_)
  end select

 end subroutine sMatAvMult_SMPlus_

 end module m_MatAttrVectMul




