!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: dstmodel.F90,v 1.8 2006-10-17 21:47:56 jacob Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !MODULE: dstmodel -- generic model for sequential climate model
!
! !DESCRIPTION:
! init run and finalize methods for destination model
!
! !INTERFACE:
!
module dstmodel

!
! !USES:
!
! Get the things needed from MCT by "Use,only" with renaming:
!
!---Domain Decomposition Descriptor DataType and associated methods
use m_GlobalSegMap,only: GlobalSegMap
use m_GlobalSegMap,only: GlobalSegMap_init => init
use m_GlobalSegMap,only: GlobalSegMap_lsize => lsize
use m_GlobalSegMap,only: GlobalSegMap_clean => clean
!---Field Storage DataType and associated methods
use m_AttrVect,only    : AttrVect
use m_AttrVect,only    : AttrVect_init => init
use m_AttrVect,only    : AttrVect_lsize => lsize
use m_AttrVect,only    : AttrVect_clean => clean
use m_AttrVect,only    : AttrVect_copy => copy
use m_AttrVect,only    : AttrVect_indxR => indexRA
use m_AttrVect,only    : AttrVect_importRAttr => importRAttr
use m_AttrVectcomms,only  : AttrVect_gather => gather

! Get things from MPEU
use m_inpak90   ! Resource files
use m_stdio     ! I/O utils
use m_ioutil


! Get utilities for this program.
use mutils

implicit none

private
! except

! !PUBLIC MEMBER FUNCTIONS:
!
public dstinit
public dstrun
public dstfin

! module variables
character(len=*), parameter :: modelname='dstmodel.F90'
integer  :: rank, lcomm

!EOP -------------------------------------------------------------------

contains
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: dstinit  - Destination model initialization

subroutine dstinit(GSMap,IMPORT,EXPORT,comm,compid)

! !INPUT PARAMETERS:
  type(GlobalSegMap),intent(inout) :: GSMap    ! decomposition
  type(AttrVect),intent(inout)     :: IMPORT,EXPORT  ! state data
  integer,intent(in)               :: comm     ! MPI communicator
  integer,intent(in)               :: compid   ! component ID
!
!EOP ___________________________________________________________________

!     local variables

!     parameters for this model
  integer :: nxa   ! number of points in x-direction
  integer :: nya   ! number of points in y-direction

  integer :: i,j,k,idx

  integer :: nprocs, root, ier

! GlobalSegMap variables
  integer,dimension(:),pointer :: lindex

! AttrVect variables
  integer :: avsize

  character*2, ldecomp


  call MPI_COMM_RANK(comm,rank, ier)
  call MPI_COMM_SIZE(comm,nprocs,ier)

! save local communicator
  lcomm=comm

  if(rank==0) then
    write(6,*) modelname, ' init start'
    write(6,*) modelname,' MyID ', compid
    write(6,*) modelname,' Num procs ', nprocs
  endif

!  Get configuration
  call i90_LoadF('dst.rc',ier)

  call i90_label('nx:',ier)
  nxa=i90_gint(ier)
  call i90_label('ny:',ier)
  nya=i90_gint(ier)
  if(rank==0) write(6,*) modelname, ' x,y ', nxa,nya

  call i90_label('decomp:',ier)
  call i90_Gtoken(ldecomp, ier)
  if(rank==0) write(6,*) modelname, ' decomp ', ldecomp


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Initialize a Global Segment Map


  call get_index(ldecomp,nprocs,rank,nxa,nya,lindex)

  call GlobalSegMap_init(GSMap,lindex,comm,compid,gsize=nxa*nya)


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


  if(rank==0) write(6,*) modelname, ' GSMap ',GSMap%ngseg,GSMap%gsize


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Initialize import and export Attribute vectors

! size is the number of grid points on this processor
  avsize = GlobalSegMap_lsize(GSMap,comm)
  if(rank==0) write(6,*) modelname, ' localsize ', avsize

! initialize Avs with two real attributes.
  call AttrVect_init(IMPORT,rList="field3:field4",lsize=avsize)
  call AttrVect_init(EXPORT,rList="field5:field6",lsize=avsize)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  if(rank==0) write(6,*) modelname, ' init done'
end subroutine dstinit
!!! END OF INIT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   RUN PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: dstrun  - Destination model run method

subroutine dstrun(IMPORT,EXPORT)

! !INPUT PARAMETERS:
  type(AttrVect),intent(inout) :: IMPORT,EXPORT   ! Input and Output states

!EOP -------------------------------------------------------------------

! local variables
  integer :: avsize,ier,i,index

  if(rank==0) write(6,*) modelname, ' run start'

! Copy input data to output data using translation between different names
  call AttrVect_copy(IMPORT,EXPORT,rList="field3:field4", &
                                     TrList="field5:field6")

  if(rank==0) write(6,*) modelname, ' run done'

end subroutine dstrun
!!! END OF RUN  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   FINALIZE PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: dstfin  - Destination model finalize method

subroutine dstfin(IMPORT,EXPORT,GSMap)

! !INPUT PARAMETERS:
  type(AttrVect),intent(inout) :: IMPORT,EXPORT   ! MCT defined type
  type(GlobalSegMap),intent(inout) :: GSMap

!EOP -------------------------------------------------------------------
  type(AttrVect) :: GlobalD
  integer :: lsize,ier,mdev,i

  if(rank==0) write(6,*) modelname,' fin start'
! gather data to node 0 and write it out
  call AttrVect_gather(EXPORT,GlobalD,GSMap,0,lcomm,ier)

! write out gathered data
  if(rank==0) then
    mdev=luavail()
    lsize=AttrVect_lsize(GlobalD)
    open(mdev, file="TS1out.dat")
    do i=1,lsize
     write(mdev,*) GlobalD%rAttr(1,i)
    enddo
    close(mdev)
  endif

 ! clean up
  call AttrVect_clean(IMPORT)
  call AttrVect_clean(EXPORT)
  if(rank==0)call AttrVect_clean(GlobalD)
  call GlobalSegMap_clean(GSMap)
  if(rank==0) write(6,*) modelname,' fin done'
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
endsubroutine dstfin

end module dstmodel
