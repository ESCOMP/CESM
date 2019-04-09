==================================
 Community Regional Earth System Model - RCESM
==================================

A Private repo for code and issues related to building a regional coupled version of CESM as part of a joint NCAR/TAMU project.

See the CESM web site for documentation and information on the base model:

http://www.cesm.ucar.edu

This repository provides tools for managing the external components required to run and build the RCESM. The basic components used in this model are included in the repo (unlike CESM), but the scripting infrastructure is maintained in an external repository and managed with the "manage_externals" tool. 

.. sectnum::

.. contents::

Obtaining the full RCESM model code and associated scripting infrastructure
=====================================================================

The RCESM code is available from this repository in github. You will need some familiarity with git in order to modify the code and commit any changes. However, to simply checkout and run the code, no git knowledge is required other than what is documented in the following steps.

To obtain the rcesm0.2 (release version 0.2) code you need to do the following:

#. Clone the repository. ::

      git clone https://github.com/ihesp/cesm my_rcesm_sandbox

   This will create a directory ``my_rcesm_sandbox/`` in your current working directory.

#. Go into the newly created directory and determine what version of the RCESM you want.
   To see what ihesp/cesm tags are available, simply issue the **git tag** command. ::

      cd my_rcesm_sandbox
      git tag

#. Do a git checkout of the tag you want. If you want to checkout ihesp_release_rcesm0.2, you would issue the following. ::

      git checkout ihesp_release_rcesm0.2

   (It is normal and expected to get a message about being in 'detached
   HEAD' state. For now you can ignore this, but it becomes important if
   you want to make changes to your Externals.cfg file and commit those
   changes to a branch.)

#. Run the script **manage_externals/checkout_externals**. ::

      ./manage_externals/checkout_externals

   The **checkout_externals** script is a package manager that will
   populate the rcesm directory with the relevant version of the CIME 
   infrastructure code.

At this point you have a working version of RCESM.

For general information on using the CIME framework in the context of CESM, see the CIME documentation at http://esmci.github.io/cime/ .

More details on checkout_externals
----------------------------------

The file **Externals.cfg** in your top-level RCESM directory tells
**checkout_externals** which tag/branch of CIME should be
brought in to generate your sandbox. (This file serves the same purpose
as SVN_EXTERNAL_DIRECTORIES when CESM was in a subversion repository.)

NOTE: Just like svn externals, checkout_externals will always attempt
to make the working copy exactly match the externals description. 

**You need to rerun checkout_externals whenever Externals.cfg has
changed** (unless you have already manually updated the relevant
external(s) to have the correct branch/tag checked out). Common times
when this is needed are:

* After checking out a new RCESM branch/tag

* After merging some other RCESM branch/tag into your currently
  checked-out branch

**checkout_externals** must be run from the root of the source
tree. For example, if you cloned RCESM with::

  git clone https://github.com/ihesp/cesm.git my_rcesm_sandbox

then you must run **checkout_externals** from
``/path/to/my_rcesm_sandbox``.

To see more details of **checkout_externals**, issue ::

  ./manage_externals/checkout_externals --help


Setting up a RCESM case
=====================================================================

When building and running the RCESM it is good to have your working directories set up as follows:

* The RCESM source code in it's own sandbox

* The RCESM case directory in a seperate (parallel) directory

* The RCESM build and run directory in an area with a lot of space for model output

On Cheyenne, your working paths might look like:

* Source code : ``/glade/p/work/user/RCESM/my_rcesm_sandbox``

* Case directory : ``/glade/p/work/user/RCESM/my_case_dirs/case1``

* Build and Run directories : ``/glade/scratch/user/case1``

A RCESM case directory contains all of the configuration xml files, case control scripts, and namelists to start a RCESM run. It also contains the README document which contains information about the case as it was created, and the CaseStatus document that keeps track of changes as you go. To create a case, run the "create_newcase" script from the CIME/scripts directory. As an example: ::

   my_rcesm_sandbox/cime/scripts/create_newcase --case my_case_dirs/new_case_1 --compset PBSGULF2010 -res tx9k_g3x -mach Cheyenne --run-unsupported 

Where the arguments mean:

- ``--case my_case_dirs/new_case_1`` This is the name of and path to the new case. This directory is created by the create_newcase script and should not exist before calling create_newcase.
- ``--compset PKWUS2003`` compsets in CESM/RCESM describe which components are active and their basic configurations for the run. In the RCESM, some pertinant compsets are:

 ================  ========================
  COMPSET Name         Components Used
 ================  ========================
  PKWUS2003         WRF atmosphere, CLM 4.0 land, data ice and data ocean
  PRSGULF2010       Data atmosphere, stub land, stub ice and ROMS ocean
  PRDXGULF2010      Data atmosphere, stub land, stub ice and ROMS ocean extended via XROMS
  PBSGULF2010       WRF atmosphere, CLM 4.0 land, stub ice and ROMS ocean extended via XROMS
 ================  ========================

- Note that the compsets describe the active components used in an experiment, and also the start date and forcing data, but not the domain or grid size. Thus, the PKWUS2003 compset can be used for the Gulf of Mexico case, if the start date is changed before runtime with the command ::

    ./xmlchange RUN_STARTDATE=2010-01-01

- ``-res tx9k_g3x`` describes the grids and domains used in this experiment. In the RCESM, the currently available resoultions are:

 =================  ========================
   Resolution          Description
 =================  ========================
  wus12_wus12         A 12km Western US domain. Ocean, land, and atmosphere all on the same grid. Has not been tested with ROMS.
  3x3_gulfmexico      A 3km Gulf of Mexico domain for ROMS only (not extended). Data atmosphere on the same grid.
  tx9k_g3x            A 9km atmosphere grid and 3km ocean grid (extended for XROMS) in the Gulf of Mexico (as used for the coupled simulation test case).
 =================  ========================

- ``-mach Cheyenne`` : The machine where the build and run is happening. This allows CIME to load the correct environment and libraries, set up applicable node and task configurations, and configure submission scripts for the correct queues. On many NCAR-supported machines (such as Cheyenne) this flag is optional, as CIME can determine what machine it is on through the shell. For more information on porting to a new machine, see "Porting CIME and the RCESM to a new machine"_ below.
- ``--run-unsupported`` : Currently required flag due to the experimental nature of RCESM in general. Only lets the user know the current configuration is not scientifically supported by the CESM scientific working groups.


Building a RCESM case
=====================================================================

Once the case has been created, only a few commands are required to build the model ::

      cd my_case_dirs/new_case_1
      ./case.setup
      ./case.build

The ``case.setup`` script builds the ``user_nl_`` user namelists and sets up the PE layout for the run. The ``./case.build`` script actually builds the model into the build directory (such as ``/glade/scratch/user/new_case_1/bld``) and builds the component namelists and copies all of the needed model run data (including boundary forcing files for WRF and ROMS) into the run directory (such as ``/glade/scratch/user/new_case_1/run`` in the example).

**Note that when working on Cheyenne it is very frowned upon to build the model interactively at a login node as is done in this example. It is better to use the wrapper script** ::
       qcmd -- ./case.build
**Which will send the build command to an interactive batch node and return when the build is complete. On Cheyenne, please use the above form.**


Running a RCESM case and Looking at Output
=====================================================================

After the model builds successfully, you can submit a run to the compute queue with the command ::

      ./case.submit

from the case directory. This will rebuild all of the model namelists and recheck to make sure that all of the correct input data has been linked and moved to the correct places within the run directory. It will then put together a submit script for the machine batch system and submit it. You can check on the status of your run either through the job status commands on your system (``qstat`` on Cheyenne) or by investigating the log output in the run directory.

The results of a simulation are located as follows

- *Log files*: If the simulation encounters an error, all log and output files will remain in the run directory. If the model successfully completes the simulation, log files will be zipped and copied to the ``logs/`` subdirectory of the case directory. 

- *WRF per process output*: If the WRF component is running as the atmosphere, it produces two output files for each process, an rsl.out.XXXX file and an rsl.error.XXXX file (where XXXX is the process rank, ie. 0036). The standard output and standard error streams can be found in these files, which will remain in the run directory regardless of the success or failure of the model run.

- *History files*: In the model's default configuration and after a successful run, all history files are moved to an archive directory on the user's larger scratch space. On Cheyenne, this is located at ::

    \glade\scratch\{$user}\case_name\{$component_name}\hist

This behavior can be turned off (and history files remain in the run directory) by setting the xml variable ``DOUT_S`` to False in the case directory before submition. For more information on XML variables and how to query or change them, see `Useful XML variables in the RCESM case`_.

- Restart files: Currently, restarts have not been tested and are not supported in the RCESM. This is an important "to do" item on the list of `Bugs, Issues and Future work`_. Restart files are written and copied into the archive directory at ::

    \glade\scratch\{$user}\case_name\{$component_name}\rest

But there is no guarentee they will work currently.



Porting CIME and the RCESM to a new machine 
=====================================================================

Right now, in order to port the RCESM code to a new machine, there are likely three areas of changes that need to be made. The first is in the CIME code for general machine support. For instructions on how to port CIME to a new machine, see this documentation: http://esmci.github.io/cime/users_guide/porting-cime.html

Adding a machine to CIME can be done without making changes to settings for any other machines, and so settings for new machines can be included in the CIME repository. First you will need to `create a branch <https://help.github.com/articles/creating-and-deleting-branches-within-your-repository/>_` for your port changes. Then, test the changes, and create a `Github pull request <https://help.github.com/articles/creating-a-pull-request/>`_ so they are included in the central code repository.

After porting CIME to the new machine, you will need to make a few changes to WRF and ROMS. In WRF, you will need to create a new configure file in the main wrf directory: `RCESM_sandbox/components/wrf` . Look at the files `configure.wrf.cheyenne_intel` or `configure.wrf.yellowstone_intel` as an example. This is the main change needed, but you may need to adjust various makefiles to correct flags for your compilers as well. Similarly, the ROMS makefiles may need to be adjusted as well. If any changes are needed to WRF or ROMS, please add an issue to the `RCESM git repository <https://github.com/ihesp/cesm/issues>`_, as the final goal is to encapsulate all platform-dependant settings within the CIME software infrastructure. 


Useful XML variables in the RCESM case
=====================================================================

All of the required configuration options for an experiment with the RCESM are encapsulated in XML variables within various files in the case directory. While it is possible to edit these files directly, it is recommended that users use the "xmlquery" and "xmlchange" scripts to access and manipulate the xml variables. These scripts give more information about each variable, do error checking on changes, and keep track of changes in the CaseStatus file so it is easy to see exactly what has been changed from the default in any given experiment. To learn more about these scripts, go into a case directory and type ::

  ./xmlquery --help

or ::

  ./xmlchange --help

CESM xml variables will be documented in the upcoming CESM 2.0 release documents. For now, here is a short compilation of variables that may be useful in testing or running RCESM experiments.

 ===================  ========================
  XML Variable           Description
 ===================  ========================
  PROJECT                Account project number to charge compute time to
  JOB_QUEUE              Which queue to submit a job, if different than default
  JOB_WALLCLOCK_TIME     Wall time to request for a job
  STOP_OPTION            What units to use for the specified run length. Valid values: nsteps, ndays, nmonths, nyears
  STOP_N                 The number of STOP_OPTION units that the experiment will complete
  RUN_STARTDATE          The date on which the experimental run begins
  DEBUG                  Whether to compile the model with debug flags on
  DOUT_S                 Turns archiving of history and restart files on (TRUE) or off (FALSE)
  DIN_LOC_ROOT           Location of the input data directory structure
 ===================  ========================


Bugs, Issues and Future work
=====================================================================
(Last Updated April 4, 2018)

- Clean up any WRF or ROMS code that is specific to Cheyenne. Generalize it so the only code that needs to be ported is CIME.
- Test Restarts. Get these working if they do not already.
- ROMS%XROMS is the only component configuration actually available through that mechanism. Need to get the `%NULL` working again.
- Create PKGULF2010 compset so the RUN_STARTDATE does not need to be manually changed for this configuration.
- Make sure that WRF history output responds to CIME XML variables correctly. Investigate other WRF namelist options that need to be hooked up to CIME variables.
- Make sure all pertinant ROMS namelist and configuration files are properly hooked up to CIME variables.
- Remove the "csh script" step in WRF and ROMS builds. This is left over from old versions of CESM and should be replaced with python code.
- Set up nightly or some form of automated testing infrastructure.
- Investigate PE layouts for WRF-ROMS coupled runs. Can I find a layout that runs more efficiently?
