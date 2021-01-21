#ifdef BGP
#define BGx
#endif
#ifdef BGL
#define BGx
#endif
module namelist_mod

    use kinds_mod

! Modules from PIO package that are used by this application

    use pio_support, only : piodie, CheckMPIReturn ! _EXTERNAL
    use pio, only : pio_offset_kind
    implicit none    
    private

    public :: broadcast_namelist
    public :: readtestpio_namelist

    integer(kind=i4), public, parameter :: buffer_size_str_len = 20
    integer(kind=i4), public, parameter :: true_false_str_len = 6
    integer(kind=i4), public, parameter :: romio_str_len = 10
    
    logical, public, save :: async
    integer(i4), public, save :: nx_global,ny_global,nz_global
    integer(i4), public, save :: rearr_type
    integer(i4), public, save :: num_iotasks
    integer(i4), public, save :: stride
    integer(i4), public, save :: base
    integer(i4), public, save :: DebugLevel
    integer(i4), public, save :: maxiter
    integer(i4), public, save :: num_aggregator
    integer(i4), public, save :: iotype
    integer(i4), public, save :: num_iodofs
    integer(i4), public, save :: nvars
    integer(i4), public, save :: npr_yz(4)   ! To simulate cam fv decompositions

    integer(kind=i4), public, save :: set_mpi_values = 0 !! Set to one for true
    character(len=buffer_size_str_len), public, save :: mpi_cb_buffer_size = ''
    integer(kind=i4), public, save :: set_romio_values = 0 !! Set to one for true
    character(len=romio_str_len), public, save :: romio_cb_write = ''
    character(len=romio_str_len), public, save :: romio_cb_read = ''
    character(len=romio_str_len), public, save :: romio_direct_io = ''
    integer(kind=i4), public, save :: set_ibm_io_values = 0 !! Set to one for true
    character(len=buffer_size_str_len), public, save :: ibm_io_buffer_size = ''
    character(len=true_false_str_len), public, save :: ibm_io_largeblock_io = ''
    character(len=true_false_str_len), public, save :: ibm_io_sparse_access = ''

    integer(kind=i4), public, save :: set_lustre_values = 0 !! Set to one for true
    integer(kind=i4), public, save :: lfs_ost_count = 1
    
    character(len=80), save, public :: compdof_input
    character(len=80), save, public :: iodof_input 
    character(len=80), save, public :: compdof_output
    character(len=256), save, public :: part_input
    character(len=256), save, public :: casename
    character(len=80), save, public :: dir
    character(len=4) , save, public :: ioFMTd
    character(len=8) , save, public :: rearr

    integer(i4), save :: nprocsIO
    integer(i4), save :: PrintRec
    character(len=4), save  :: ioFMT
    character(len=80), save :: fname1, fname2
    character(len=*), parameter :: myname='namelist_mod'
    integer(PIO_OFFSET_KIND) :: max_buffer_size
    integer(i4) :: block_size

! Variables whose values are derived form items in namelist io_nml:

    namelist /io_nml/  	&
        async,          &
	stride,  	&
        base,           &
        num_aggregator, &
	nx_global,	&
	ny_global,	&
	nz_global,	&
        nvars,          &
	dir, 		&
        max_buffer_size, &
        block_size,     &
	casename, 	&
	maxiter,	&
        ioFMT, 		&
	rearr, 		&
        nprocsIO,       &
        num_iodofs,     &
        compdof_input,  &
        compdof_output, &
        iodof_input,    &
	part_input, 	&
	DebugLevel,     &
        npr_yz,         &
        set_mpi_values,       &
        mpi_cb_buffer_size,   &
        set_romio_values,     &
        romio_cb_write,       &
        romio_cb_read,        &
        romio_direct_io,      &
        set_ibm_io_values,    &
        ibm_io_buffer_size,   &
        ibm_io_largeblock_io, &
        ibm_io_sparse_access, &
	set_lustre_values,    &
	lfs_ost_count

contains


subroutine ReadTestPIO_Namelist(device, nprocs, filename, caller, ierror)

    use pio ! _EXTERNAL

    implicit none

    integer(i4),      intent(IN)  :: device
    integer(i4),      intent(IN)  :: nprocs
    character(len=*), intent(IN)  :: filename
    character(len=*), intent(IN)  :: caller
    integer(i4),      intent(OUT) :: ierror

    character(len=16) :: string
    character(len=*), parameter :: myname_=myname//'ReadPIO_Namelist'

    !-------------------------------------------------
    ! set default values for namelist io_nml variables 
    !-------------------------------------------------

    async = .false.
    DebugLevel=2
    stride = 0
    base = 0
    nx_global = 3600
    ny_global = 2400
    nz_global = 1
    num_iotasks = -1
    num_aggregator = 4
    nprocsIO = 0
    num_iodofs = 1
    compdof_input = 'namelist'
    part_input = 'null'
    iodof_input = 'internal'
    compdof_output = 'none'
    nvars = 10

    max_buffer_size = -1  !! use default value
    block_size = -1       !! use default value



    npr_yz = (/nprocs,1,1,nprocs/)
    set_mpi_values = 0  !! Set to one for true
    mpi_cb_buffer_size = ''

    set_romio_values = 0  !! Set to one for true
    romio_cb_write = ''   !! Default is "automatic"
    romio_cb_read = ''    !! Default is "automatic"
    romio_direct_io = ''  !! Default is "automatic"

    set_ibm_io_values = 0 !! Set to one for true
    ibm_io_buffer_size = ''
    ibm_io_largeblock_io = ''  !! Default is "false"
    ibm_io_sparse_access = ''  !! Default is false

    set_lustre_values = 0
    lfs_ost_count = 1

    ioFMT = 'bin'
    dir   = './'
    casename  = ''
    rearr = 'box'
    maxiter = 10

    open (device, file=filename,status='old',iostat=ierror)

    if(ierror /= 0) then 
       write(*,*) caller,'->',myname_,':: Error opening file ',filename, &
            ' on device ',device,' with iostat=',ierror
       ierror = -1
    else
       ierror =  1
    endif
    
    do while (ierror > 0)
       read(device, nml=io_nml, iostat=ierror)
    enddo

    if (ierror == 0) close(device)

    if(nvars > 99999) then
       write(*,*) 'nvars exceeds limit of 99999, resetting'
       nvars = 99999
    else if(nvars < 1) then
       write(*,*) 'nvars < 1, resetting'
       nvars = 1
    end if


    string = 'namelist_input'
    write(*,*) ' '
    write(*,*) trim(string),' async      = ',async
    write(*,*) trim(string),' casename   = ',trim(casename)
    write(*,*) trim(string),' nx_global  = ',nx_global
    write(*,*) trim(string),' ny_global  = ',ny_global
    write(*,*) trim(string),' nz_global  = ',nz_global
    write(*,*) trim(string),' nvars      = ',nvars
    write(*,*) trim(string),' ioFMT      = ',ioFMT
    write(*,*) trim(string),' rearr      = ',rearr
    write(*,*) trim(string),' nprocsIO   = ',nprocsIO
    write(*,*) trim(string),' base       = ',base
    write(*,*) trim(string),' stride     = ',stride
    write(*,*) trim(string),' num_aggregator = ',num_aggregator
    write(*,*) trim(string),' num_iodofs = ',num_iodofs
    write(*,*) trim(string),' maxiter    = ',maxiter
    write(*,*) trim(string),' dir        = ',trim(dir)
    write(*,*) trim(string),' npr_yz     = ',npr_yz
    write(*,*) trim(string),' DebugLevel = ',DebugLevel
    write(*,*) trim(string),' DebugLevel = ',DebugLevel
    write(*,*) trim(string),' compdof_input  = ',trim(compdof_input)
    write(*,*) trim(string),' compdof_output = ',trim(compdof_output)
    write(*,*) trim(string),' iodof_input = ',trim(iodof_input)
    write(*,*) trim(string),' part_input =', trim(part_input)
    if (set_mpi_values /= 0) then
       if (mpi_cb_buffer_size /= '') then
          write(*,*) trim(string),' mpi_cb_buffer_size = ', &
               trim(mpi_cb_buffer_size)
       end if
    end if

    if (set_romio_values /= 0) then
       if (romio_cb_write /= '') then
          write(*,*) trim(string),' romio_cb_write = ', romio_cb_write
       end if

       if (romio_cb_read /= '') then
          write(*,*) trim(string),' romio_cb_read = ', romio_cb_read
       end if

       if (romio_direct_io /= '') then
          write(*,*) trim(string),' romio_direct_io = ', romio_direct_io
       end if
    end if

    if (set_ibm_io_values /= 0) then
       if (ibm_io_buffer_size /= '') then
          write(*,*) trim(string),'ibm_io_buffer_size = ', &
               trim(ibm_io_buffer_size)
       end if

       if (ibm_io_largeblock_io /= '') then
          write(*,*) trim(string),'ibm_io_largeblock_io = ', &
               trim(ibm_io_largeblock_io)
       end if

       if (ibm_io_sparse_access /= '') then
          write(*,*) trim(string),'ibm_io_sparse_access = ', &
               trim(ibm_io_sparse_access)
       end if
    end if

    if (set_lustre_values /= 0) then
       write(*,*) trim(string),'lfs_ost_count = ', lfs_ost_count
    endif

    write(*,*) ' '

    string = 'derived_input'
    select case(trim(rearr))
    case('none')
       rearr_type=PIO_rearr_none
       write(*,*) trim(string),' rearr_type = ','PIO_rearr_none'
    case('box')
       rearr_type=PIO_rearr_box
       write(*,*) trim(string),' rearr_type = ','PIO_rearr_box'
    case('sub')
       rearr_type=PIO_rearr_subset
       write(*,*) trim(string),' rearr_type = ','PIO_rearr_subset'
    case default
       write(*,'(6a)') caller,'->',myname,':: Value of Rearranger type rearr = ',rearr, &
            'not supported.'
       call piodie(__FILE__,__LINE__)
    end select
    write(*,*) trim(string),' rearr_type = ',rearr_type

    iofmtd = iofmt
    select case(ioFMT)
      case('bin') ! binary format
         iotype = iotype_pbinary
         write(*,*) trim(string),' iotype     = ','iotype_pbinary'
      case('pnc') !Parallel netCDF
         iotype = iotype_pnetcdf
         ioFmtd = 'nc'
         write(*,*) trim(string),' iotype     = ','iotype_pnetcdf'
      case('snc') ! serial netCDF
         iotype = iotype_netcdf
         ioFmtd = 'nc'
         write(*,*) trim(string),' iotype     = ','iotype_netcdf'
      case('nc4p') ! netCDF4 parallel
         iotype = PIO_iotype_netcdf4p
         ioFmtd = 'nc'
         write(*,*) trim(string),' iotype     = ','PIO_iotype_netcdf4p'
      case('nc4c') ! netCDF4 compressed
         iotype = PIO_iotype_netcdf4c
         ioFmtd = 'nc'
         write(*,*) trim(string),' iotype     = ','PIO_iotype_netcdf4c'
      case default
         write(*,'(4a,i8)') caller,'->',myname,':: Unrecognized value of ioFMT =',ioFMT
         call piodie(__FILE__,__LINE__)
    end select
    write(*,*) trim(string),' iofmtd     = ',trim(iofmtd)

    num_iotasks = -1
    if (nprocsIO > 0) then
       num_iotasks=nprocsIO
       if (stride <= 0 .or. stride>nprocs) then
          stride = (nprocs-base)/num_iotasks
       endif
    elseif (nprocsIO <= 0) then
#ifdef BGx 
       ! A negative value for num_iotasks has a special meaning on Blue Gene
       num_iotasks = nprocsIO
#else
       if (stride <= 0 .or. stride>nprocs) then
          num_iotasks = nprocs
          stride = 1
          base=0
       else
          num_iotasks = max(1,(nprocs-base)/stride)
       endif
#endif
    endif

    !------------------------------------------------
    ! reset stride if there are not enough processors 
    !------------------------------------------------
    if (base + num_iotasks * (stride-1) > nprocs-1) then
       stride = FLOOR(real((nprocs - 1 - base),kind=r8)/real(num_iotasks,kind=r8))
    endif

    !-------------------------------------------------------
    ! If rearrangement is 'none' reset to the proper values
    !-------------------------------------------------------
    if(trim(rearr) == 'none') then  
        stride = 1
        num_iotasks = nprocs	
    endif

    write(*,*) trim(string),' n_iotasks  = ',num_iotasks,'  (updated)'
    write(*,*) trim(string),' base       = ',base,'  (updated)'
    write(*,*) trim(string),' stride     = ',stride,'  (updated)'
    write(*,*) ' '

    !--- error check

    string = 'namelist_ERROR:'
    print *,'ReadTestPIO_Namelist: at the end'

end subroutine ReadTestPIO_Namelist


subroutine Broadcast_Namelist(caller, myID, root, comm, ierror)

  use pio ! _EXTERNAL
#ifndef NO_MPIMOD
  use mpi ! _EXTERNAL
#endif
  implicit none
#ifdef NO_MPIMOD
  include 'mpif.h' ! _EXTERNAL
#endif
  character(len=*), intent(IN) :: caller
  integer(i4),      intent(IN)  :: myID
  integer(i4),      intent(IN)  :: root
  integer(i4),      intent(IN)  :: comm

  integer(i4),      intent(OUT) :: ierror

  character(len=*), parameter :: myname_=myname//'Broadcast_Namelist'
  integer(i4) :: itmp

  !------------------------------------------
  ! broadcast namelist info to all processors 
  !------------------------------------------

  if(async) then
     itmp=1
  else
     itmp=0
  end if

  call MPI_Bcast(itmp, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(async)',ierror,__FILE__,__LINE__)

  if(itmp==1) then
     async=.true.
  else
     async=.false.
  end if


  call MPI_Bcast(num_iotasks, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(num_iotasks)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(num_iodofs, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(num_iodofs)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(num_aggregator, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(num_aggregator)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(stride, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(stride)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(base, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(base)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(nx_global, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(nx_global)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(ny_global, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(ny_global)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(nz_global, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(nz_global)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(nvars, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(nvars)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(set_mpi_values, 1, MPI_INTEGER, root, comm,ierror)
  call CheckMPIReturn('Call to MPI_Bcast(set_mpi_values)', ierror, &
                        __FILE__, __LINE__)

  call MPI_Bcast(mpi_cb_buffer_size, buffer_size_str_len, MPI_CHARACTER, &
                   root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(mpi_cb_buffer_size)', ierror, &
                        __FILE__, __LINE__)

  call MPI_Bcast(set_romio_values, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(set_romio_values)', ierror, &
                        __FILE__, __LINE__)

  call MPI_Bcast(romio_cb_write, romio_str_len, MPI_CHARACTER, root, &
                   comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(romio_cb_write)', ierror, &
                        __FILE__, __LINE__)

  call MPI_Bcast(romio_cb_read, romio_str_len, MPI_CHARACTER, root, &
                   comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(romio_cb_read)', ierror, &
                        __FILE__, __LINE__)

  call MPI_Bcast(romio_direct_io, romio_str_len, MPI_CHARACTER, root, &
                   comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(romio_direct_io)', ierror, &
                        __FILE__, __LINE__)

  call MPI_Bcast(set_ibm_io_values, 1, MPI_INTEGER, root, comm, &
                   ierror)
  call CheckMPIReturn('Call to MPI_Bcast(set_ibm_io_values)', ierror, &
                        __FILE__, __LINE__)

  call MPI_Bcast(ibm_io_buffer_size, buffer_size_str_len, MPI_CHARACTER, &
                   root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(ibm_io_buffer_size)', ierror, &
         __FILE__, __LINE__)

  call MPI_Bcast(ibm_io_largeblock_io, true_false_str_len, MPI_CHARACTER, &
                   root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(ibm_io_largeblock_io)', ierror, &
                        __FILE__, __LINE__)

  call MPI_Bcast(ibm_io_sparse_access, true_false_str_len, MPI_CHARACTER, &
                   root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(ibm_io_sparse_access)', ierror, &
                        __FILE__, __LINE__)

  call MPI_Bcast(set_lustre_values,1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcase(set_lustre_values)', ierror, __FILE__, __LINE__)

  call MPI_Bcast(lfs_ost_count,1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcase(lfs_ost_count)', ierror, __FILE__, __LINE__)

  call MPI_Bcast(iotype, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(iotype)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(ioFMTd, 4, MPI_CHARACTER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(ioFMTd)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(rearr, 8, MPI_CHARACTER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(rearr)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(rearr_type, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(rearr_type)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(dir, 80, MPI_CHARACTER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(dir)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(compdof_input, 80, MPI_CHARACTER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(compdof_input)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(compdof_output, 80, MPI_CHARACTER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(compdof_output)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(iodof_input, 80, MPI_CHARACTER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(iodof_input)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(part_input, 256, MPI_CHARACTER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(part_input)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(casename, 256, MPI_CHARACTER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(casename)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(DebugLevel, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(DebugLevel)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(maxiter, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(maxiter)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(nprocsIO, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(nprocsIO)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(npr_yz, 4, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(npr_yz)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(max_buffer_size, 1, MPI_INTEGER8, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(npr_yz)',ierror,__FILE__,__LINE__)

  call MPI_Bcast(block_size, 1, MPI_INTEGER, root, comm, ierror)
  call CheckMPIReturn('Call to MPI_Bcast(npr_yz)',ierror,__FILE__,__LINE__)

  if(max_buffer_size>0) then
     if(myid==0) print *,'Setting buffer_size_limit to : ',max_buffer_size
     call pio_set_buffer_size_limit(max_buffer_size)
  end if
  if(block_size>0) then
     if(myid==0) print *,'Setting blocksize to : ',block_size
     call pio_set_blocksize(block_size)
  end if





end subroutine Broadcast_Namelist

end module namelist_mod
