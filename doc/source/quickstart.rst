.. _quickstart:

====================================
 Quick Start (CESM Model Workflow)
====================================

The following quick start guide is for versions of CESM that have
already been ported to the local target machine. CESM2 is built on the
CIME (Common Infrastructure for Modeling Earth) framework.

Please refer to the CIME `porting`_ documentation if CIME has not
yet been ported to the target machine. 

If you are new to CESM2, please consider reading the
`CIME Case Control System Part 1: Basic Usage guide <https://esmci.github.io/cime/index.html>`_ first.

These definitions are required to understand this section:

-  ``$COMPSET`` refers to the component set.

-  ``$GRID`` refers to the model resolution.

-  ``$MACHINE`` refers to the target machine.

-  ``$CIMEROOT`` refers to the CIME root directory.

-  ``$CASE`` refers to the case name.

-  ``$CASEROOT`` refers to the full pathname of the root directory where the
   case (``$CASE``) will be created.

-  ``$EXEROOT`` refers to the build directory. (``$EXEROOT`` IS NORMALLY
   NOT THE SAME AS ``$CASEROOT``).

-  ``$RUNDIR`` refers to the directory where CESM actually runs. This is
   normally set to ``$EXEROOT``/../run. (Note: changing ``$EXEROOT`` does not
   change ``$RUNDIR`` as these are independent variables. However by default
   they are both located under ``$CIME_OUTPUT_ROOT``)

This is the procedure for quickly setting up and running a CESM case.

Download CESM  (see `Downloading CESM <downloading_cesm.html>`_).

Select a component set, and a resolution for your case.  Details of available
component sets and resolutions are available from the `query_config`_ tool located
in the ``$CIMEROOT/scripts`` directory

::

    > cd $CIMEROOT/scripts
    > ./query_config --help

See the `supported component sets <http://www.cesm.ucar.edu/models/cesm2.0/cesm/compsets.html>`_,
`supported model resolutions <http://www.cesm.ucar.edu/models/cesm2.0/cesm/grids.html>`_ and `supported
machines <http://www.cesm.ucar.edu/models/cesm2.0/cesm/machines.html>`_ for a complete list of CESM
supported component sets, grids and computational platforms.

Create a case
==============

The `create_newcase`_ command creates a case directory containing the
scripts and XML files to configure a case (see below) for the requested
resolution, component set, and machine. **create_newcase** has several
required arguments (invoke **create_newcase --help** for help).

If running on a supported machine, (``$MACHINE``), that machine will
normally be recognized automatically and therefore it is not required
to specify the ``--machine`` argument to **create_newcase**, then
invoke **create_newcase** as follows:

::

    > create_newcase --case $CASEROOT --compset $COMPSET --res $GRID 

If running on a new target machine, see
`the CIME porting guide <http://esmci.github.io/cime/users_guide/porting-cime.html>`_.

Setting up the case run script
==============================

Issuing the `case.setup`_ command creates a ``$CASEROOT/case.run`` script
along with namelist ``user_nl_xxx`` files, where xxx denotes the set of components
for the given case configuration. Before invoking **case.setup**, modify
the ``env_mach_pes.xml`` file in $CASEROOT using the `xmlchange`_ command
as needed for the experiment.

cd to the ``$CASEROOT`` directory.

::

    > cd $CASEROOT

Modify settings in ``env_mach_pes.xml`` (optional). (Note: To edit any of
the env xml files, use the `xmlchange`_ command.
invoke **xmlchange --help** for help.)

Invoke the **case.setup** command.

::

    > ./case.setup  


Build the executable using the case.build command
=================================================

Modify build settings in ``env_build.xml`` (optional).

Run the build script.

::

    > ./case.build 

Users of the NCAR cheyenne system should consider using 
the `qcmd <https://dailyb.cisl.ucar.edu/bulletins/cisl-adds-qcmd-script-launching-resource-intensive-compilation-jobs>`_
to compile CESM on a compute node as follows:

::

    > qcmd ./case.build


Run the case
============

Modify runtime settings in ``env_run.xml`` (optional). In particular, set
the ``$DOUT_S`` variable to FALSE to turn off short term archiving.

Submit the job to the batch queue using the **case.submit** command.

::

    > ./case.submit

When the job is complete, review the following directories and files

``$RUNDIR``, this directory is set in the ``env_build.xml`` file. This is the
location where CESM was run. There should be log files there for every
component (i.e. of the form cpl.log.yymmdd-hhmmss). Each component writes
its own log file. Also see whether any restart or history files were
written. To check that a run completed successfully, check the last
several lines of the cpl.log file for the string " SUCCESSFUL
TERMINATION OF CPL7-cesm ".

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

- ``$DOUT_S_ROOT/$CASE``

  This is the short term archive directory. If ``$DOUT_S`` is
  FALSE, then no archive directory should exist. If ``$DOUT_S`` is TRUE, then
  log, history, and restart files should have been copied into a directory
  tree here.

.. _CIME: http://esmci.github.io/cime
.. _porting: http://esmci.github.io/cime/users_guide/porting-cime
.. _query_config: http://esmci.github.io/cime/users_guide/introduction-and-overview.html#discovering-available-cases-with-query-config
.. _create_newcase: http://esmci.github.io/cime/users_guide/create-a-case.html
.. _xmlchange: http://esmci.github.io/cime/Tools_user/xmlchange.html
.. _case.setup: http://esmci.github.io/cime/users_guide/setting-up-a-case.html
