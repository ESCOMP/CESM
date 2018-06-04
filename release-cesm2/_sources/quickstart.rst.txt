.. _quickstart:

====================================
 Quick Start (CESM2 Model Workflow)
====================================

The following quick start guide is for versions of CESM2 that have
already been ported to the local target machine. CESM2 is built on the
CIME (Common Infrastructure for Modeling Earth) framework.
Please refer to the `CIME Porting Documentation <http://esmci.github.io/cime/users_guide/porting-cime.html>`_ if CIME has not
yet been ported to the target machine. 

If you are new to CESM2, please consider reading the
`CIME Case Control System Part 1: Basic Usage guide <https://esmci.github.io/cime/index.html>`_ first.

This is the procedure for quickly setting up and running a CESM2 case.

Download CESM2 (see `Downloading CESM2 <downloading_cesm.html>`_).

Select a component set, and a resolution for your case.  Details of available
component sets and resolutions are available from the `query_config`_ tool located
in the ``my_cesm_sandbox/cime/scripts`` directory

.. code-block:: console

    cd my_cesm_sandbox/cime/scripts
    ./query_config --help

See the `supported component sets <http://www.cesm.ucar.edu/models/cesm2.0/config/compsets.html>`_,
`supported model resolutions <http://www.cesm.ucar.edu/models/cesm2.0/config/grids.html>`_ and `supported
machines <http://www.cesm.ucar.edu/models/cesm2.0/config/machines.html>`_ for a complete list of CESM2
supported component sets, grids and computational platforms.

Create a case
==============

The `create_newcase`_ command creates a case directory containing the
scripts and XML files to configure a case (see below) for the requested
resolution, component set, and machine. **create_newcase** has several
required arguments (invoke **create_newcase --help** for help).

The ``$PROJECT`` variable must be specified in either your 
shell environment or as the ``--project`` argument to **create_newcase**.

If running on a supported machine, that machine will
normally be recognized automatically and therefore it is not required
to specify the ``--machine`` argument to **create_newcase**. 

Invoke **create_newcase** as follows:

.. code-block:: console

    ./create_newcase --case $CASEROOT --compset $COMPSET --res $GRID

where:

-  ``$COMPSET`` refers to the `component set <http://www.cesm.ucar.edu/models/cesm2.0/config/compsets.html>`_.

-  ``$GRID`` refers to the model `resolution <http://www.cesm.ucar.edu/models/cesm2.0/config/grids.html>`_.

-  ``$CASEROOT`` refers to the full path of the root directory where the
   case (``$CASE``) will be created. 

-  ``$CASE`` refers to the case name, which is the basename of $CASEROOT.
   See `CESM2 Experiment Casenames  <http://www.cesm.ucar.edu/models/cesm2.0/naming_conventions.html#casenames>`_
   for details regarding CESM experiment case naming conventions. 

An example on NCAR machine cheyenne with ``$USER`` set to your cheyenne login name
and``$CASEROOT = /glade/scratch/$USER/cases/b.e20.B1850.f19_g17.test`` is:

.. code-block:: console

    ./create_newcase --case /glade/scratch/$USER/cases/b.e20.B1850.f19_g17.test --compset B1850 --res f19_g17 


Setting up the case run script
==============================

Issuing the `case.setup`_ command creates scripts needed to run the model
along with namelist ``user_nl_xxx`` files, where xxx denotes the set of components
for the given case configuration. Before invoking **case.setup**, modify
the ``env_mach_pes.xml`` file in CASEROOT using the `xmlchange`_ command
as needed for the experiment.

cd to the ``$CASEROOT`` directory.

.. code-block:: console

    cd $CASEROOT

Modify settings in ``env_mach_pes.xml`` (optional). (Note: To edit any of
the env xml files, use the `xmlchange`_ command.
invoke **xmlchange --help** for help.)

Invoke the **case.setup** command.

.. code-block:: console

    ./case.setup  


Build the executable using the case.build command
=================================================

Modify build settings in ``env_build.xml`` (optional).

Run the build script.

.. code-block:: console

    ./case.build 

Users of the NCAR cheyenne system should consider using 
`qcmd <https://www2.cisl.ucar.edu/resources/computational-systems/cheyenne/running-jobs/submitting-jobs-pbs>`_
to compile CESM2 on a compute node as follows:

.. code-block:: console

    qcmd -- ./case.build

The CESM executable will appear in the directory given by the XML variable ``$EXEROOT``,
which can be queried using:

.. code-block:: console
   
   ./xmlquery EXEROOT


Run the case
============

Modify runtime settings in ``env_run.xml`` (optional). In particular, you can set
the ``$DOUT_S`` variable to FALSE to turn off short term archiving.

Submit the job to the batch queue using the **case.submit** command.

.. code-block:: console

    ./case.submit

When the job is complete, review the following directories and files
(Note: **xmlquery** can be run with a list of comma separated names
and no spaces):

.. code-block:: console

   ./xmlquery RUNDIR,CASE,CASEROOT,DOUT_S,DOUT_S_ROOT

- ``$RUNDIR``

  This directory is set in the ``env_run.xml`` file. This is the
  location where CESM2 was run. There should be log files there for every
  component (i.e. of the form cpl.log.yymmdd-hhmmss) if ``$DOUT_S == FALSE``. 
  Each component writes its own log file. Also see whether any restart or history files were
  written. To check that a run completed successfully, check the last
  several lines of the cpl.log file for the string " SUCCESSFUL
  TERMINATION OF CPL7-cesm ". 

- ``$DOUT_S_ROOT/$CASE``

  ``$DOUT_S_ROOT`` refers to the short term archive path location on local disk.
  This path is used by the case.st_archive script when ``$DOUT_S = TRUE``.
  See `CESM Model Output File Locations <http://www.cesm.ucar.edu/models/cesm2.0/naming_conventions.html#modelOutputLocations>`_
  for details regarding the component model output filenames and locations. 

  ``$DOUT_S_ROOT/$CASE`` is the short term archive directory for this ``$CASE``. If ``$DOUT_S`` is
  FALSE, then no archive directory should exist. If ``$DOUT_S`` is TRUE, then
  log, history, and restart files should have been copied into a directory
  tree here.

- ``$DOUT_S_ROOT/$CASE/logs``

  The log files should have been copied into this directory if the run completed successfully
  and the short-term archiver is turned on with ``$DOUT_S = TRUE``. Otherwise, the log files
  are in the ``$RUNDIR``.

- ``$CASEROOT``

  There could be standard out and/or standard error files output from the batch system.

- ``$CASEROOT/CaseDocs``

  The case namelist files are copied into this directory from the ``$RUNDIR``.

- ``$CASEROOT/timing``

  There should be a couple of timing files there that summarize the model performance.

By default, the model is set to run for 5 days based on the $STOP_N and $STOP_OPTION variables:

.. code-block:: console

   ./xmlquery STOP_N,STOP_OPTION

These default settings will not allow the model to run long enough to produce 
monthly history climatology files but can be useful in 
`troubleshooting  <http://esmci.github.io/cime/users_guide/troubleshooting.html>`_
runtime problems before submitting for a longer time.


.. _CIME: http://esmci.github.io/cime
.. _porting: http://esmci.github.io/cime/users_guide/porting-cime
.. _query_config: http://esmci.github.io/cime/users_guide/introduction-and-overview.html#discovering-available-cases-with-query-config
.. _create_newcase: http://esmci.github.io/cime/users_guide/create-a-case.html
.. _xmlchange: http://esmci.github.io/cime/Tools_user/xmlchange.html
.. _case.setup: http://esmci.github.io/cime/users_guide/setting-up-a-case.html
