.. _quickstart:

============================================
Quick Start: CESM Model Workflow (|version|)
============================================

The following quick start guide is for versions of CESM2 that have
already been ported to the local target machine. CESM2 is built on the
CIME (Common Infrastructure for Modeling Earth) framework.
Please refer to the `CIME Porting Documentation <http://esmci.github.io/cime/versions/master/html/users_guide/porting-cime.html>`_ if CIME has not
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

See the `supported component sets <http://www.cesm.ucar.edu/models/cesm2/config/compsets.html>`_,
`supported model resolutions <http://www.cesm.ucar.edu/models/cesm2/config/grids.html>`_ and `supported
machines <http://www.cesm.ucar.edu/models/cesm2/config/machines.html>`_ for a complete list of CESM2
supported component sets, grids and computational platforms.

.. note:: 

   Variables presented as ``$VAR`` in this guide typically refer to variables in XML files
   in a CESM case. From within a case directory, you can determine the value of such a
   variable with ``./xmlquery VAR``. In some instances, ``$VAR`` refers to a shell
   variable or some other variable; we try to make these exceptions clear.

Create a case
==============

The `create_newcase`_ command creates a case directory containing the scripts and XML
files to configure a case (see below) for the requested resolution, component set, and
machine. **create_newcase** has three required arguments: ``--case``, ``--compset`` and
``--res`` (invoke **create_newcase --help** for help).

On machines where a project or account code is needed (including NCAR's machines), you
must either specify the ``--project`` argument to **create_newcase** or set the
``$PROJECT`` variable in your shell environment.

If running on a supported machine, that machine will
normally be recognized automatically and therefore it is *not* required
to specify the ``--machine`` argument to **create_newcase**. 

Invoke **create_newcase** as follows:

.. code-block:: console

    ./create_newcase --case CASENAME --compset COMPSET --res GRID

where:

- ``CASENAME`` defines the name of your case (stored in the ``$CASE`` XML variable). This
  is a very important piece of metadata that will be used in filenames, internal metadata
  and directory paths. **create_newcase** will create the *case directory* with the same
  name as the ``CASENAME``. If ``CASENAME`` is simply a name (not a path), the case
  directory is created in the directory where you executed create_newcase. If ``CASENAME``
  is a relative or absolute path, the case directory is created there, and the name of the
  case will be the last component of the path. The full path to the case directory will be
  stored in the ``$CASEROOT`` XML variable. See `CESM2 Experiment Casenames
  <http://www.cesm.ucar.edu/models/cesm2/naming_conventions.html#casenames>`_ for
  details regarding CESM experiment case naming conventions.

- ``COMPSET`` is the `component set <http://www.cesm.ucar.edu/models/cesm2/config/compsets.html>`_.

- ``GRID`` is the model `resolution <http://www.cesm.ucar.edu/models/cesm2/config/grids.html>`_.

Here is an example on NCAR machine cheyenne with the ``$USER`` shell environment variable
set to your cheyenne login name:

.. code-block:: console

    ./create_newcase --case /glade/scratch/$USER/cases/b.e20.B1850.f19_g17.test --compset B1850 --res f19_g17 


Setting up the case run script
==============================

Issuing the `case.setup`_ command creates scripts needed to run the model
along with namelist ``user_nl_xxx`` files, where xxx denotes the set of components
for the given case configuration. Before invoking **case.setup**, modify
the ``env_mach_pes.xml`` file in the case directory using the `xmlchange`_ command
as needed for the experiment.

cd to the case directory. Following the example from above:

.. code-block:: console

    cd /glade/scratch/$USER/cases/b.e20.B1850.f19_g17.test

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

Modify runtime settings in ``env_run.xml`` (optional). Two settings you may want to change
now are:

1. Run length: By default, the model is set to run for 5 days based on the ``$STOP_N`` and
   ``$STOP_OPTION`` variables:

   .. code-block:: console

      ./xmlquery STOP_OPTION,STOP_N

   These default settings can be useful in `troubleshooting
   <http://esmci.github.io/cime/versions/master/html/users_guide/troubleshooting.html>`_ runtime problems
   before submitting for a longer time, but will not allow the model to run long enough to
   produce monthly history climatology files. In order to produce history files, increase
   the run length to a month or longer:

   .. code-block:: console

      ./xmlchange STOP_OPTION=nmonths,STOP_N=1

2. You can set the ``$DOUT_S`` variable to FALSE to turn off short term archiving:

   .. code-block:: console

      ./xmlchange DOUT_S=FALSE

Submit the job to the batch queue using the **case.submit** command.

.. code-block:: console

    ./case.submit

When the job is complete, most output will *NOT* be written under the case directory, but
instead under some other directories (on NCAR's cheyenne machine, these other directories
will be in ``/glade/scratch/$USER``). Review the following directories and files, whose
locations can be found with **xmlquery** (note: **xmlquery** can be run with a list of
comma separated names and no spaces):

.. code-block:: console

   ./xmlquery RUNDIR,CASE,CASEROOT,DOUT_S,DOUT_S_ROOT

- ``$RUNDIR``

  This directory is set in the ``env_run.xml`` file. This is the
  location where CESM2 was run. There should be log files there for every
  component (i.e. of the form cpl.log.yymmdd-hhmmss) if ``$DOUT_S == FALSE``. 
  Each component writes its own log file. Also see whether any restart or history files were
  written. To check that a run completed successfully, check the last
  several lines of the cpl.log file for the string "SUCCESSFUL
  TERMINATION OF CPL7-cesm".

- ``$DOUT_S_ROOT/$CASE``

  ``$DOUT_S_ROOT`` refers to the short term archive path location on local disk.
  This path is used by the case.st_archive script when ``$DOUT_S = TRUE``.
  See `CESM Model Output File Locations <http://www.cesm.ucar.edu/models/cesm2/naming_conventions.html#modelOutputLocations>`_
  for details regarding the component model output filenames and locations. 

  ``$DOUT_S_ROOT/$CASE`` is the short term archive directory for this case. If ``$DOUT_S`` is
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

  There should be two timing files there that summarize the model performance.


.. _CIME: http://esmci.github.io/cime
.. _query_config: http://esmci.github.io/cime/versions/master/html/users_guide/introduction-and-overview.html#discovering-available-cases-with-query-config
.. _create_newcase: http://esmci.github.io/cime/versions/master/html/users_guide/create-a-case.html
.. _xmlchange: http://esmci.github.io/cime/versions/master/html/Tools_user/xmlchange.html
.. _case.setup: http://esmci.github.io/cime/versions/master/html/users_guide/setting-up-a-case.html
