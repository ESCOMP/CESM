!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
! CVS $Id: srcmodel.F90,v 1.8 2005-11-18 23:15:38 rloy Exp $
! CVS $Name:  $
!BOP -------------------------------------------------------------------
!
! !MODULE: srcmodel -- generic model for unit tester
!
! !DESCRIPTION:
! init run and finalize methods for source model
!
module srcmodel

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
use m_AttrVect,only    : AttrVect_zero => zero
use m_AttrVect,only    : AttrVect_indxR => indexRA
use m_AttrVect,only    : AttrVect_importRAttr => importRAttr
use m_AttrVectComms,only : AttrVect_scatter => scatter

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

public srcinit
public srcrun
public srcfin

! private module variables
character(len=*), parameter :: modelname='srcmodel.F90'
integer  :: rank
real, dimension(:), pointer :: avdata

!EOP -------------------------------------------------------------------

contains

!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: srcinit  - Source model initialization

subroutine srcinit(GSMap,IMPORT,EXPORT,comm,compid)

! !INPUT PARAMETERS:
  type(GlobalSegMap),intent(inout) :: GSMap    !  decomposition
  type(AttrVect),intent(inout)     :: IMPORT,EXPORT  !  state data
  integer,intent(in)               :: comm     !  MPI communicator
  integer,intent(in)               :: compid   !  component ID
!
!EOP ___________________________________________________________________

!     local variables

!     parameters for this model
  integer :: nxa   ! number of points in x-direction
  integer :: nya   ! number of points in y-direction

  integer :: i,j,k,mdev,fx,fy
  integer :: nprocs, root, ier,fileno

! GlobalSegMap variables
  integer,dimension(:),pointer :: lindex

! AttrVect variables
  integer :: avsize
  type(AttrVect)   :: GlobalD  ! Av to hold global data

  real,dimension(:),pointer :: rootdata

  character*2 :: ldecomp


  call MPI_COMM_RANK(comm,rank, ier)
  call MPI_COMM_SIZE(comm,nprocs,ier)

  if(rank==0) then
    write(6,*) modelname, ' init start'
    write(6,*) modelname,' MyID ', compid
    write(6,*) modelname,' Num procs ', nprocs
  endif

!  Get configuration
   call i90_LoadF('src.rc',ier)

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

! Initialize the IMPORT  Av by scattering from a root Av
! with real data.

! Read in data from root and scatter to nodes
  if(rank==0) then
    call AttrVect_init(GlobalD,rList="field1:field2",lsize=nxa*nya)
    mdev=luavail()
    open(mdev, file="TS1.dat",status="old")
    read(mdev,*) fx,fy
    do i=1,nxa*nya
      read(mdev,*) GlobalD%rAttr(1,i)
    enddo
    write(6,*) modelname,'Global init ',GlobalD%rAttr(1,1),GlobalD%rAttr(1,8000)
  endif

! this scatter will create IMPORT if it hasn't already been initialized
  call AttrVect_scatter(GlobalD,IMPORT,GSMap,0,comm,ier)

! initialize EXPORT Av with two real attributes.
  call AttrVect_init(EXPORT,rList="field3:field4",lsize=avsize)

  call AttrVect_zero(EXPORT)

  if(rank==0) then
    write(6,*) modelname, rank,' IMPORT field1', IMPORT%rAttr(1,1)
    write(6,*) modelname, rank,' IMPORt field2', IMPORT%rAttr(2,1)
    write(6,*) modelname, rank,' EXPORT field3', EXPORT%rAttr(1,1)
    write(6,*) modelname, rank,' EXPORT field4', EXPORT%rAttr(2,1)
  endif

! allocate buffer for use in run method
  allocate(avdata(avsize),stat=ier)

  if(rank==0) write(6,*) modelname, ' init done'
end subroutine srcinit
!!! END OF INIT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   RUN PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: srcrun  - Source model run method

subroutine srcrun(IMPORT,EXPORT)

! !INPUT PARAMETERS:
  type(AttrVect),intent(inout) :: IMPORT,EXPORT   ! Input and Output states

!EOP -------------------------------------------------------------------
! local variables
  integer :: avsize,ier,i

! Nothing to do with IMPORT


! Fill EXPORT with data
  if(rank==0) write(6,*) modelname, ' run start'

! Use Av copy to copy input data from field1 in Imp to field3 in EXPORT
  call AttrVect_copy(IMPORT,EXPORT,rList='field1',TrList='field3')

! Use import to load data in second field
  avdata=30.0
  call AttrVect_importRAttr(EXPORT,"field4",avdata)

  if(rank==0) write(6,*) modelname, ' In field1', IMPORT%rAttr(1,1)
  if(rank==0) write(6,*) modelname, ' In field2', IMPORT%rAttr(2,1)
  if(rank==0) write(6,*) modelname, ' Out field3', EXPORT%rAttr(1,1)
  if(rank==0) write(6,*) modelname, ' Out field4', EXPORT%rAttr(2,1)

  if(rank==0) write(6,*) modelname, ' run done'

end subroutine srcrun
!!! END OF RUN  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!   FINALIZE PHASE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!BOP -------------------------------------------------------------------
!
! !IROUTINE: srcfin  - Source model finalize method

subroutine srcfin(IMPORT,EXPORT,GSMap)

! !INPUT PARAMETERS:
  type(AttrVect),intent(inout) :: IMPORT,EXPORT   ! imp,exp states
  type(GlobalSegMap),intent(inout) :: GSMap
!EOP -------------------------------------------------------------------
 ! clean up
  call AttrVect_clean(IMPORT)
  call AttrVect_clean(EXPORT)
  call GlobalSegMap_clean(GSMap)
  deallocate(avdata)
  if(rank==0) write(6,*) modelname,' fin done'
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
endsubroutine srcfin

end module srcmodel
