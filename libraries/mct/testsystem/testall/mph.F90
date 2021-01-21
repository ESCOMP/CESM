!-----------------------------------------------------------------------
! CVS $Id: mph.F90,v 1.3 2006-10-03 22:43:29 jacob Exp $
! CVS $Name:  $
! =============================================================
! Multi Program-Components Handshaking (MPH) Utility

! This is a small utility of global handshaking among different component
! models. Each component will run on a set of nodes or processors.
! Different components could run either on different set of nodes, or
! on set of nodes that overlap.

! There are three seperate implementations:
! 1. Multiple Components, Multiple Executables, components non-overlap
! 2. Multiple Components, Single Executable, components non-overlap
! 3. Multiple Components, Single Executable, components overlap, flexible

! This is a combined module for all the above.
! The user only has to "use MPH_all" in their application codes.
! You may need to use MPH_help to understand the required information
! for setup, input file and inquiry functions.

! Written by Yun He and Chris Ding, NERSC/LBL, January 2001.


!==============================================================
! common data used by all three versions of MPH
!==============================================================

      module comm_data123

      use m_mpif
      implicit none

      integer istatus(MPI_STATUS_SIZE), ierr
      integer max_num_comps, maxProcs_comp
      parameter (max_num_comps=20)    ! maximum number of components
      parameter (maxProcs_comp=128)   ! maximum number of procs per comps

      type Acomponent
         character*16 name          ! component name
         integer num_process        ! number of processors
         integer process_list(maxProcs_comp)
                                    ! global processor_id, increasing order
      end type Acomponent

      type (Acomponent)  components(max_num_comps) ! allocate components
      integer MPI_Acomponent

      integer global_proc_id   ! proc id in the whole world
      integer global_totProcs  ! total # of procs for the whole world
      integer COMM_master    ! communicator for submaster of each component

      integer total_components
      character*16 component_names(max_num_comps)

! for timer
      integer N_CHANNELS
      parameter (N_CHANNELS=10)
      real (kind=8) :: init_time = -1.0
      real (kind=8) :: last_time, tot_time(0:N_CHANNELS)

      end module comm_data123

!===============================================================
! common data shared by MPH_Multi_Exec and MPH_Single_Exec
!===============================================================

      module comm_data12
      use comm_data123
      integer component_id
      integer local_world      ! communicator for this component
      integer local_proc_id    ! proc id in this component
      integer local_totProcs   ! total # of procs for this component
      end module comm_data12

!==================================================================
! common subroutines used by all three versions of MPH
!==================================================================

      module comm_sub123
      use comm_data123
      contains

!--------------- subroutine MPH_init () ------------

      subroutine MPH_init ()
      implicit none

      integer iblock(3), idisp(3), itype(3)

      call MPI_COMM_RANK (MPI_COMM_WORLD, global_proc_id, ierr)
      call MPI_COMM_SIZE (MPI_COMM_WORLD, global_totProcs, ierr)

! create a new MPI data type MPI_Acomponent

      iblock(1) = 16
      iblock(2) = 1
      iblock(3) = maxProcs_comp
      idisp(1) = 0
      idisp(2) = 16
      idisp(3) = 20
      itype(1) = MPI_CHARACTER
      itype(2) = MPI_INTEGER
      itype(3) = MPI_INTEGER
      call MPI_TYPE_STRUCT (3,iblock,idisp,itype,MPI_Acomponent,ierr)
      call MPI_TYPE_COMMIT (MPI_Acomponent, ierr)

      end subroutine MPH_init


!--------- subroutine MPH_global_id (name, local_id) ----------

      integer function MPH_global_id (name, local_id)
      implicit none

      character*(*) name
      integer local_id, temp

! then find out the component rank
      temp = MPH_find_name (name, component_names, total_components)

! process_list starts from 1, while proc rank starts from 0
      MPH_global_id = components(temp) % process_list(local_id+1)

      end function MPH_global_id


!------ integer function MPH_find_name(name, namelist, num) ------

      integer function MPH_find_name(name, namelist, num)
      implicit none

! find name in component_names
      character*(*) name
      integer i, num
      character*16 namelist(num)

      do i = 1, num
         if (name == namelist(i)) then
!            print *, i, name, namelist(i)
            goto 100
         endif
      enddo

! name is not found
      MPH_find_name = -1
      print *, "ERROR: ", name, " not found in components.in"
      stop

100   MPH_find_name = i
      return
      end function MPH_find_name


!---------- subroutine MPH_redirect_output (name) ---------

      subroutine MPH_redirect_output (name)
      character*(*) name
      integer lenname, lenval, rcode
      character*16 output_name_env
      character*64 output_name, temp_value

      output_name = ' '
      output_name_env = trim (name) // "_out_env"

#if (defined AIX)
      call getenv (trim(output_name_env), temp_value)
      output_name = trim (temp_value)
      if (len_trim(output_name) == 0) then
         write(*,*)'output file names not preset by env varibales'
         write(*,*)'so output not redirected'
      else
         open (unit=6, file=output_name, position='append')
         call flush_(6)
      endif
#endif

#if (defined SUPERUX)
      call getenv (trim(output_name_env), temp_value)
      output_name = trim (temp_value)
      if (len_trim(output_name) == 0) then
         write(*,*)'output file names not preset by env varibales'
         write(*,*)'so output not redirected'
      else
         open (unit=6, file=output_name, position='append')
         call flush(6)
      endif
#endif

#if (defined IRIX64 || defined CRAY || defined sn6711)
      lenname = len_trim (output_name_env)
      call pxfgetenv (output_name_env,lenname,output_name,lenval,rcode)
      if (len_trim(output_name) == 0) then
         write(*,*)'output file names not preset by env varibales'
         write(*,*)'so output not redirected'
      else
         open (unit=6, file=output_name, position='append')
         call flush(6)
      endif
#endif

#if (!defined AIX && !defined IRIX64 && !defined CRAY && !defined sn6711 && !defined SUPERUX)
      write(*,*) 'No implementation for this architecture'
      write(*,*) 'output redirect is not performed by getenv'
#endif

      end subroutine MPH_redirect_output


!----------- subroutine MPH_help (arg) --------------

      subroutine MPH_help (arg)
      implicit none

      character*(*) arg
      write(*,*)'Message from MPH_help:'

      if (arg .eq. 'off') then
         write(*,*)'off'

      else if (arg .eq. 'Multi_Exec') then
         write(*,*)'Multiple executables'
         write(*,*)'Required setup function for pop is: '
         write(*,*)'   call MPH_setup_ME ("ocean", POP_World)'
         write(*,*)'Required input file is "components.in"'

         write(*,*)'Subroutine call to join two communicators is:'
         write(*,*)'   MPH_comm_join_ME_SE(name1,name2,comm_joined)'

         write(*,*)'Available inquiry functions are:'
         write(*,*)'   character*16 MPH_component_name(id)'
         write(*,*)'   integer MPH_get_component_id(name)'
         write(*,*)'   integer MPH_total_components()'
         write(*,*)'   integer MPH_global_proc_id()'
         write(*,*)'   character*16 MPH_myName_ME_SE()'
         write(*,*)'   integer MPH_component_id_ME_SE()'
         write(*,*)'   integer MPH_local_proc_id_ME_SE()'
         write(*,*)'   integer MPH_local_world_ME_SE()'

      else if (arg .eq. 'Single_Exec') then
         write(*,*)'Single executable, processors non-overlap'
         write(*,*)'Required setup function is: '
         write(*,*)'   call MPH_setup_SE (atmosphere=ccm3_8,&
     & ocean=pop2_2, coupler=cpl5_1)'
         write(*,*)'Required input file is "processors_map.in"'

         write(*,*)'Subroutine call to join two communicators is:'
         write(*,*)'   MPH_comm_join_ME_SE(name1,name2,comm_joined)'

         write(*,*)'Available inquiry functions are:'
         write(*,*)'   character*16 MPH_component_name(id)'
         write(*,*)'   integer MPH_get_component_id(name)'
         write(*,*)'   integer MPH_total_components()'
         write(*,*)'   integer MPH_global_proc_id()'
         write(*,*)'   character*16 MPH_myName_ME_SE()'
         write(*,*)'   integer MPH_component_id_ME_SE()'
         write(*,*)'   integer MPH_local_proc_id_ME_SE()'
         write(*,*)'   integer MPH_local_world_ME_SE()'
         write(*,*)'   integer MPH_low_proc_limit(id)'
         write(*,*)'   integer MPH_up_proc_limit(id)'

      else if (arg .eq. 'Single_Exec_Overlap') then
         write(*,*)'Single executable, processors overlap'
         write(*,*)'Required setup function is: '
         write(*,*)'   call MPH_setup_SE_overlap ("atmosphere",&
     & "ocean", "coupler")'
         write(*,*)'Required input file is "processors_map.in"'

         write(*,*)'Subroutine call to join two communicators is:'
         write(*,*)'   MPH_comm_join_SE_overlap (name1, name2,&
     & comm_joined)'

         write(*,*)'Available inquiry functions are:'
         write(*,*)'   character*16 MPH_component_name(id)'
         write(*,*)'   integer MPH_get_component_id(name)'
         write(*,*)'   integer MPH_total_components()'
         write(*,*)'   integer MPH_global_proc_id()'
         write(*,*)'   integer MPH_local_proc_id_SE_overlap(id)'
         write(*,*)'   integer MPH_local_world_SE_overlap(id)'
         write(*,*)'   integer MPH_low_proc_limit(id)'
         write(*,*)'   integer MPH_up_proc_limit(id)'

      else
         write(*,*)'wrong argument for MPH_help'
      endif

      end subroutine MPH_help


!----------- function MPH_timer (flag, channel)  ------------

! Usage:

! channel 0 is the default channel, using init_time.

!  ---------------------------------------------------------
!  timer calls to walk-clock dclock(), and do the following:
!  ---------------------------------------------------------
!  flag=0  : Sets initial time; init all channels.
!
!  flag =1 : Calculates the most recent time interval; accure it to the
!            specified channel;
!            Returns it to calling process.
!            Channel 0 is the default channel, which is automatically accrued.

!  flag =2 : Calculates the most recent time interval; accure it to the
!            specified channel;
!            Returns the curent total time in the specified channel;
!            Channel 0 is the default channel, which is automatically accrued.
!  ---------------------------------------------------------

      real (kind=8) function MPH_timer (flag, channel)
      integer flag, channel
      real (kind=8) :: new_time, delta_time, MPI_Wtime

      new_time = MPI_Wtime()

      if (flag == 0) then
         init_time = new_time
         last_time = new_time
         tot_time = 0.0
         MPH_timer = new_time - init_time
      else if (init_time == -1.0) then
!        Error Condition
         MPH_timer = init_time
      endif

! Timer is initialized and flag != 0

      delta_time = new_time - last_time
      last_time = new_time

! For channel=0 or other undefined channels which is treated as 0
      if ( channel < 0  .or. channel > N_CHANNELS) then
         write(*,*) 'Timer channel is not properly specified!'
      endif

! channel != 0

      if (flag == 1) then
         tot_time(channel) = tot_time(channel) + delta_time
         MPH_timer = delta_time
      else if (flag == 2) then
         tot_time(channel) = tot_time(channel) + delta_time
         MPH_timer = tot_time(channel)
      else
!        Error Condition
         MPH_timer = -1.0
      endif

      end function MPH_timer


!-------- common inquiry functions for MPH1, MPH2 and MPH3 -------

      character*16 function MPH_component_name(id)
         integer id
         MPH_component_name = component_names (id)
      end function  MPH_component_name

      integer function MPH_get_component_id(name)
         character*(*) name
         MPH_get_component_id = MPH_find_name (name, component_names,&
                                               total_components)
      end function MPH_get_component_id

      integer function MPH_total_components()
         MPH_total_components = total_components
      end function MPH_total_components

      integer function MPH_global_proc_id()
         MPH_global_proc_id = global_proc_id
      end function MPH_global_proc_id

      end module comm_sub123


! ===============================================================
! common subroutines used by MPH_Multi_Exec and MPH_Single_Exec
! ===============================================================

      module comm_sub12
      use comm_data123
      use comm_data12
      use comm_sub123

      contains

!--------------- subroutine MPH_global_ME_SE () ------------

! global hand-shaking among root processors of each component.

      subroutine MPH_global_ME_SE ()
      implicit none
      integer sendtag, recvtag, i, color, key

! create a MPI communicator COMM_master for all submasters
! arrange the rank of the submasters in COMM_master by their component_id
! i.e., their rank of the component model in "components.in"
      if (local_proc_id == 0) then
         color = 1
      else
         color = 2
      endif
      key = component_id
      call MPI_COMM_SPLIT (MPI_COMM_WORLD,color,key,COMM_master,ierr)

! gather Acomponents to 0th proc in COMM_master
      if (local_proc_id == 0) then
         call MPI_GATHER (components(component_id), 1, MPI_Acomponent,&
                          components, 1, MPI_Acomponent,&
                          0, COMM_master, ierr)

! 0th proc in COMM_master broadcast Acomponents to all submasters
         call MPI_BCAST (components, total_components,&
                         MPI_Acomponent, 0, COMM_master, ierr)
      endif

! submaster broadcast AComponents to all process in the components
      call MPI_BCAST (components, total_components,&
                      MPI_Acomponent, 0, local_world, ierr)

! everybody lists the complete info
!     write(*,*)'I am proc ', local_proc_id, ' in ',
!    &           component_names(component_id), ' , which is proc ',
!    &           global_proc_id, ' in global_world'
!     write(*,*)'infos I have for all proc of all components are:'
!     do i = 1, total_components
!        write(*,*)'   ', components(i)%name
!        write(*,*)'   ', components(i)%num_process
!        write(*,*)'   ', components(i)%process_list(1:8)  ! partial list
!     enddo

      end subroutine MPH_global_ME_SE


!------- subroutine MPH_comm_join_ME_SE (name1, name2, comm_joined) ---

      subroutine MPH_comm_join_ME_SE (name1, name2, comm_joined)
      implicit none

      character*(*) name1, name2
      integer temp1, temp2
      integer comm_joined, color, key

      temp1 = MPH_find_name(name1,component_names,total_components)
      temp2 = MPH_find_name(name2,component_names,total_components)

! the order of two components does matter: first one has lower ranks in
! the new joined communicator, and second one has higher ranks.

      if (component_id==temp1 .or. component_id==temp2) then
         color = 1
         if (component_id == temp1) then
            key = local_proc_id
         else
            key = global_totProcs + local_proc_id
         endif
      else
         color = 2
         key = 0
      endif

      call MPI_COMM_SPLIT (MPI_COMM_WORLD,color,key,comm_joined,ierr)

      end subroutine MPH_comm_join_ME_SE


!-------- common inquiry functions for MPH1 and MPH2 ---------

      character*16 function MPH_myName_ME_SE()
         MPH_myName_ME_SE = component_names (component_id)
      end function MPH_myName_ME_SE

      integer function MPH_component_id_ME_SE()
         MPH_component_id_ME_SE = component_id
      end function MPH_component_id_ME_SE

      integer function MPH_local_proc_id_ME_SE()
         MPH_local_proc_id_ME_SE = local_proc_id
      end function MPH_local_proc_id_ME_SE

      integer function MPH_local_world_ME_SE()
         MPH_local_world_ME_SE = local_world
      end function MPH_local_world_ME_SE

      end module comm_sub12


! ==============================================================
!  module MPH_Multi_Exec
! ==============================================================

! Multi-Process Handshaking utility
! to facilitate a plug & play style programming on
! using multiple component executables.

      module MPH_Multi_Exec
      use comm_data123
      use comm_data12
      use comm_sub123
      use comm_sub12
      character*16 myName

      contains

!------------- subroutine MPH_setup_ME (name, comm_world) ---------

      subroutine MPH_setup_ME (name, comm_world)
      implicit none

      character*(*) name
      integer comm_world

      myName = name
      call MPH_init ()
      call MPH_local_ME ()
      call MPH_global_ME_SE ()
      call MPI_COMM_DUP (local_world, comm_world, ierr)

      end subroutine MPH_setup_ME


!--------------- subroutine MPH_local_ME () ------------

! local hand-shaking

      subroutine MPH_local_ME ()
      implicit none
      integer key

      total_components = MPH_read_list_ME("components.in",&
                "COMPONENT_LIST", component_names, max_num_comps)

      component_id = MPH_find_name (myName, component_names,&
                                    total_components)
      key = 0
      call MPI_COMM_SPLIT (MPI_COMM_WORLD, component_id, key,&
                           local_world,ierr)

! setup local_world, local_proc_id, local_totProcs
      call MPI_COMM_RANK (local_world, local_proc_id, ierr)
      call MPI_COMM_SIZE (local_world, local_totProcs, ierr)

      components(component_id)%name = myName
      components(component_id)%num_process = local_totProcs

! gather processor ids to 0th proc in this component.
      call MPI_GATHER (global_proc_id, 1, MPI_INTEGER,&
                       components(component_id)%process_list,&
                       1, MPI_INTEGER, 0, local_world, ierr)

      end subroutine MPH_local_ME


!--- function MPH_read_list_ME(filename, filetag, namelist, num) ---

      integer function MPH_read_list_ME(filename,filetag,namelist,num)
      implicit none
      integer i, num
      character*(*) filename, filetag
      character*16 namelist(num), firstline, temp

      open(10, file=filename, status='unknown')
      read(10, '(a16)', end=200) firstline
      if (firstline .ne. filetag) then
         print *, 'ERROR: filetag inconsistent', filename
         print *, 'ERROR: ', filetag, '!=', firstline
         stop
      endif

      read(10, '(a16)', end=200) temp
      if (temp .ne. 'BEGIN') then
         print *, 'ERROR: no BEGIN in ', filename
         stop
      endif

      do i = 1, num
         read(10, '(a16)', end=100) temp
         if (temp .ne. 'END') then
             namelist(i) = temp
         else
             goto 200
         endif
      enddo

100   print *, 'ERROR: no END in ', filename
      stop

200   MPH_read_list_ME = i - 1
      close(10)

      return
      end function MPH_read_list_ME

      end module MPH_Multi_Exec


! ==============================================================
! module MPH_Single_Exec
! ==============================================================

! Multi-Process Handshaking utility
! to facilitate a plug & play style programming using single executable.
! each processor only execute one component model once.

      module MPH_Single_Exec
      use comm_data123
      use comm_data12
      use comm_sub123
      use comm_sub12
      integer low_proc_limit(max_num_comps)
      integer up_proc_limit(max_num_comps)

      contains


!---- subroutine MPH_setup_SE (atmosphere, ocean, coupler, land) ------

      subroutine MPH_setup_SE (atmosphere, ocean, coupler, land,&
                 ice, biosphere, io)
      implicit none

      optional atmosphere, ocean, coupler, land, ice, biosphere, io
      external atmosphere, ocean, coupler, land, ice, biosphere, io
      integer id

      call MPH_init ()

      total_components = MPH_read_list_SE ("processors_map.in",&
                    "PROCESSORS_MAP", component_names,&
                    low_proc_limit, up_proc_limit, max_num_comps)

      if (present(atmosphere)) then
         id=MPH_find_name("atmosphere",component_names,total_components)
         if (low_proc_limit(id) .le. global_proc_id .and.&
             global_proc_id .le. up_proc_limit(id)) then
            call MPH_local_SE (id)
            call MPH_global_ME_SE ()
            call atmosphere (local_world)
         endif
      endif

      if (present(ocean)) then
         id=MPH_find_name("ocean",component_names,total_components)
         if (low_proc_limit(id) .le. global_proc_id .and.&
             global_proc_id .le. up_proc_limit(id)) then
            call MPH_local_SE (id)
            call MPH_global_ME_SE ()
            call ocean (local_world)
         endif
      endif

      if (present(coupler)) then
         id=MPH_find_name("coupler",component_names,total_components)
         if (low_proc_limit(id) .le. global_proc_id .and.&
             global_proc_id .le. up_proc_limit(id)) then
            call MPH_local_SE (id)
            call MPH_global_ME_SE ()
            call coupler (local_world)
         endif
      endif

! add more component models as follows:
      if (present(land)) then
         id=MPH_find_name("land",component_names,total_components)
         if (low_proc_limit(id) .le. global_proc_id .and.&
             global_proc_id .le. up_proc_limit(id)) then
            call MPH_local_SE (id)
            call MPH_global_ME_SE ()
            call land (local_world)
         endif
      endif

      if (present(ice)) then
         id=MPH_find_name("ice",component_names,total_components)
         if (low_proc_limit(id) .le. global_proc_id .and.&
             global_proc_id .le. up_proc_limit(id)) then
            call MPH_local_SE (id)
            call MPH_global_ME_SE ()
            call ice (local_world)
         endif
      endif

      if (present(biosphere)) then
         id=MPH_find_name("biosphere",component_names,total_components)
         if (low_proc_limit(id) .le. global_proc_id .and.&
             global_proc_id .le. up_proc_limit(id)) then
            call MPH_local_SE (id)
            call MPH_global_ME_SE ()
            call biosphere (local_world)
         endif
      endif

      if (present(io)) then
         id=MPH_find_name("io",component_names,total_components)
         if (low_proc_limit(id) .le. global_proc_id .and.&
             global_proc_id .le. up_proc_limit(id)) then
            call MPH_local_SE (id)
            call MPH_global_ME_SE ()
            call io (local_world)
         endif
      endif

      end subroutine MPH_setup_SE


!--------------- subroutine MPH_local_SE (id) ------------

! local hand-shaking

      subroutine MPH_local_SE (id)
      implicit none
      integer id, key

      component_id = id
      key = 0
      call MPI_COMM_SPLIT (MPI_COMM_WORLD, component_id,&
                           key, local_World, ierr)

! setup local_world, local_proc_id, local_totProcs
      call MPI_COMM_RANK (local_world, local_proc_id, ierr)
      call MPI_COMM_SIZE (local_world, local_totProcs, ierr)

      components(component_id)%name = component_names(component_id)
      components(component_id)%num_process = local_totProcs

! gather processor ids to 0th proc in this component.
      call MPI_GATHER (global_proc_id, 1, MPI_INTEGER,&
                       components(component_id)%process_list, 1,&
                       MPI_INTEGER, 0, local_world, ierr)

      end subroutine MPH_local_SE


!---- function MPH_read_list_SE (filename, filetag, namelist,
!---- low, up, num) --------

      integer function MPH_read_list_SE (filename, filetag,&
                            namelist, low, up, num)
      implicit none
      integer i, num
      character*(*) filename, filetag
      character*16 namelist(num), firstline, temp
      integer itemp1, itemp2
      integer low(num), up(num)

      open(10, file=filename, status='unknown')
      read(10, *, end=100) firstline
      if (firstline .ne. filetag) then
         print *, 'ERROR: filetag inconsistent', filename
         print *, 'ERROR: ', filetag, '!=', firstline
         stop
      endif

      read(10, *, end=200) temp
      if (temp .ne. "BEGIN") then
         print *, 'ERROR: no BEGIN in ', filename
         stop
      endif

      do i = 1, num
         read(10, *, err=300, end=400) temp, itemp1, itemp2
         if (temp .eq. "END") goto 500
         namelist(i) = temp
         low(i) = itemp1
         up(i) = itemp2
      enddo

100   print *, 'ERROR: no filetag in ', filename
      stop

200   print *, 'ERROR: no BEGIN in ', filename
      stop

300   if (temp .eq. "END") then
         goto 500
      else
         print *, 'ERROR: either: no END in ', filename
         print *, '       or: does not provide correct format as'
         print *, '           in input example: ocean 11 18'
         stop
      endif

400   print *, 'ERROR: no END in ', filename
      stop

500   MPH_read_list_SE = i - 1
      close(10)

      return
      end function MPH_read_list_SE


!---- the following two functions are common for MPH2 and MPH3 -------

      integer function MPH_low_proc_limit(id)
         integer id
         MPH_low_proc_limit = low_proc_limit(id)
      end function MPH_low_proc_limit

      integer function MPH_up_proc_limit(id)
         integer id
         MPH_up_proc_limit = up_proc_limit(id)
      end function MPH_up_proc_limit

      end module MPH_Single_Exec


! ==============================================================
! module MPH_Single_Exec_Overlap
! ==============================================================

! Multi-Process Handshaking utility
! to facilitate a plug & play style programming using single executable.
! each processor could execute more than one component model (processor
! overlap) in any flexible way (any order).


      module MPH_Single_Exec_Overlap
      use comm_data123
      use comm_sub123

      integer local_world(max_num_comps)  ! communicator for this component
      integer local_proc_id(max_num_comps)  ! proc id in this component
      integer local_totProcs(max_num_comps) ! total procs for this component
      integer low_proc_limit(max_num_comps)
      integer up_proc_limit(max_num_comps)

      contains

!---- subroutine MPH_setup_SE_overlap (model1, model2, ...) ------

      subroutine MPH_setup_SE_overlap (model1, model2, model3, model4,&
                 model5, model6, model7, model8, model9, model10)
      implicit none

      character*(*) model1, model2, model3, model4, model5
      character*(*) model6, model7, model8, model9, model10
      optional model1, model2, model3, model4, model5
      optional model6, model7, model8, model9, model10

      integer id, i

      call MPH_init ()
      call MPH_local_SE_overlap ()
      call MPH_global_SE_overlap ()

      end subroutine MPH_setup_SE_overlap


!--------------- subroutine MPH_local_SE_overlap () ------------

      subroutine MPH_local_SE_overlap ()
      implicit none
      integer id,  color, key

      total_components=MPH_read_list_SE_overlap("processors_map.in",&
                    "PROCESSORS_MAP", component_names,&
                    low_proc_limit, up_proc_limit, max_num_comps,&
                    local_totProcs)

! setup local_world, local_proc_id, local_totProcs
      do id = 1, total_components
         if (low_proc_limit(id) .le. global_proc_id .and.&
             global_proc_id .le. up_proc_limit(id)) then
            color = 1
         else
            color = 2
         endif
         key = 0
         call MPI_COMM_SPLIT (MPI_COMM_WORLD, color, key,&
                              local_World(id), ierr)
         call MPI_COMM_RANK(local_world(id),local_proc_id(id),ierr)
      enddo

      end subroutine MPH_local_SE_overlap


!--------------- subroutine MPH_global_SE_overlap () ------------

      subroutine MPH_global_SE_overlap()
      implicit none
      integer id, i

! record Acomponent for each component
      do id = 1, total_components
         components(id)%name = component_names(id)
         components(id)%num_process = local_totProcs(id)
         do i = low_proc_limit(id), up_proc_limit(id)
            components(id)%process_list(i-low_proc_limit(id)+1)=i
         enddo
      enddo

! everybody lists the complete info
      do id = 1, total_components
         if (low_proc_limit(id) .le. global_proc_id .and.&
             global_proc_id .le. up_proc_limit(id)) then
            write(*,*)'I am proc ', local_proc_id(id), ' in ',&
                 component_names(id), ' , which is proc ',&
                 global_proc_id, ' in global_world'
            write(*,*)'infos I have for all proc of all components are:'
            do i = 1, total_components
               write(*,*)'   ', components(i)%name
               write(*,*)'   ', components(i)%num_process
               write(*,*)'   ', components(i)%process_list(1:9)
            enddo
         endif
      enddo

      end subroutine MPH_global_SE_overlap


!----------- subroutine PE_in_component (name, comm) ------------

      logical function PE_in_component (name, comm)
      implicit none
      character*(*) name
      integer id, comm

      id = MPH_find_name(name, component_names, total_components)
      if (low_proc_limit(id) .le. global_proc_id .and.&
          global_proc_id .le. up_proc_limit(id)) then
         comm = local_world(id)
         PE_in_component = .true.
      else
         PE_in_component = .false.
      endif

      end function PE_in_component


!------ subroutine MPH_comm_join_SE_overlap (name1, name2, comm_joined) ---

      subroutine MPH_comm_join_SE_overlap (name1, name2, comm_joined)
      implicit none
      integer id1, id2

      character*(*) name1, name2
      integer comm_joined, color, key
      logical con1, con2

      id1 = MPH_find_name(name1,component_names,total_components)
      id2 = MPH_find_name(name2,component_names,total_components)

! the order of two components does matter: first one has lower ranks in
! the new joined communicator, and second one has higher ranks.

      con1 = (low_proc_limit(id1) .le. global_proc_id) .and.&
             (global_proc_id .le. up_proc_limit(id1))
      con2 = (low_proc_limit(id2) .le. global_proc_id).and.&
             (global_proc_id .le. up_proc_limit(id2))

      if (con1 .or. con2) then
         color = 1
         if (con1) then
            key = local_proc_id(id1)
         else
            key = global_totProcs + local_proc_id(id2)
         endif
      else
         color = 2
         key = 0
      endif

      call MPI_COMM_SPLIT (MPI_COMM_WORLD,color,key,comm_joined,ierr)

      end subroutine MPH_comm_join_SE_overlap


!---- function MPH_read_list_SE_overlap (filename, filetag, namelist,
!---- low, up, num, local_num) ------

      integer function MPH_read_list_SE_overlap (filename, filetag,&
                            namelist, low, up, num, local_num)
      implicit none
      integer i, num
      character*(*) filename, filetag
      character*16 namelist(num), firstline, temp
      integer itemp1, itemp2
      integer low(num), up(num), local_num(num)

      open(10, file=filename, status='unknown')
      read(10, *, end=100) firstline
      if (firstline .ne. filetag) then
         print *, 'ERROR: filetag inconsistent', filename
         print *, 'ERROR: ', filetag, '!=', firstline
         stop
      endif

      read(10, *, end=200) temp
      if (temp .ne. "BEGIN") then
         print *, 'ERROR: no BEGIN in ', filename
         stop
      endif

      do i = 1, num
         read(10, *, err=300, end=400) temp, itemp1, itemp2
         if (temp .eq. "END") goto 500
         namelist(i) = temp
         low(i) = itemp1
         up(i) = itemp2
         local_num(i) = itemp2 - itemp1 + 1
      enddo

100   print *, 'ERROR: no filetag in ', filename
      stop

200   print *, 'ERROR: no BEGIN in ', filename
      stop

300   if (temp .eq. "END") then
         goto 500
      else
         print *, 'ERROR: either: no END in ', filename
         print *, '       or: does not provide correct format as'
         print *, '           in input example: ocean 11 18'
         stop
      endif

400   print *, 'ERROR: no END in ', filename
      stop

500   MPH_read_list_SE_overlap = i - 1
      close(10)

      return
      end function MPH_read_list_SE_overlap


!--------- some special inquiry functions for MPH3 -----------

      integer function MPH_local_proc_id_SE_overlap(id)
         integer id
         MPH_local_proc_id_SE_overlap = local_proc_id(id)
      end function MPH_local_proc_id_SE_overlap

      integer function MPH_local_world_SE_overlap(id)
         integer id
         MPH_local_world_SE_overlap = local_world(id)
      end function MPH_local_world_SE_overlap

! -- the following two functions are common for MPH2 and MPH3

      integer function MPH_low_proc_limit(id)
         integer id
         MPH_low_proc_limit = low_proc_limit(id)
      end function MPH_low_proc_limit

      integer function MPH_up_proc_limit(id)
         integer id
         MPH_up_proc_limit = up_proc_limit(id)
      end function MPH_up_proc_limit

      end module MPH_Single_Exec_Overlap


! ==============================================================
!  module MPH_all
! ==============================================================

      module MPH_all

      use MPH_Multi_Exec
      use MPH_Single_Exec
      use MPH_Single_Exec_Overlap

      end module MPH_all
