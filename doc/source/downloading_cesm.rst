.. _downloading:

=============================
Downloading CESM2 (|version|)
=============================

Downloading the code and scripts
--------------------------------

Starting with CESM2, releases are available through a public GitHub
repository, `http://github.com/ESCOMP/CESM <http://github.com/ESCOMP/CESM>`_. 

Access to the code requires both git and Subversion client software in
place that is compatible with GitHub and our Subversion server
software.  You will need access to the command line clients, ``git``
(v1.8 or greater) and ``svn`` (v1.8 or greater but less than v1.11).  
Currently, our Subversion server
software is at version 1.8.17. For more information or to download
open source tools, visit `Subversion <http://subversion.apache.org/>`_
and `git downloads <https://git-scm.com/downloads>`_.

With valid git and svn clients installed on the machine where CESM2 will be
built and run, the user may download the latest version of the release
code:

.. code-block:: console

    git clone https://github.com/ESCOMP/CESM.git my_cesm_sandbox
    cd my_cesm_sandbox

To checkout a previous version of CESM2, first view the available versions:

.. code-block:: console

    git tag --list 'release-cesm2*'

To checkout a specific CESM2 release tag type, for example CESM2.0.1:

.. code-block:: console 

    git checkout release-cesm2.0.1

Finally, to checkout all the individual model components,
run the **checkout_externals** script from /path/to/my_cesm_sandbox.

.. code-block:: console

    ./manage_externals/checkout_externals

The **checkout_externals** script will read the configuration file called ``Externals.cfg`` and
will download all the external component models and CIME into /path/to/my_cesm_sandbox. 

Details regarding the CESM2 checkout process are available in the CESM GitHub repo
`README <http://github.com/ESCOMP/CESM/blob/master/README.rst>`_
To see more details regarding the checkout_externals script from the command line, type:

.. code-block:: console

    ./manage_externals/checkout_externals --help


.. warning:: When contacting the Subversion server for the first time, you may need to
             accept an authentication certification. If you experience problems such as
             ``checkout_externals`` hanging: Run ``svn ls
             https://svn-ccsm-models.cgd.ucar.edu/ww3/release_tags``, permanently
             accepting the certificate when prompted, then retry the CESM download
             (starting over at the top of these instructions).

.. warning:: If a problem was encountered during checkout_externals, which may happen with an older version of the svn client software, it may appear to have downloaded successfully, but in fact only a partial checkout has occurred. 

To confirm a successful download of all components, you can run ``checkout_externals``
with the status flag to show the status of the externals:

.. code-block:: console

    ./manage_externals/checkout_externals -S

This should show a clean status for all externals, with no characters in the first two
columns of output, as in this example:

.. code-block:: console

   Processing externals description file : Externals.cfg
   Processing externals description file : Externals_CLM.cfg
   Processing externals description file : ../Externals_cime.cfg
   Processing externals description file : Externals_POP.cfg
   Processing externals description file : Externals_CISM.cfg
   Processing externals description file : .gitmodules
   Processing submodules description file : .gitmodules
   Processing externals description file : Externals_CAM.cfg
   Checking status of externals: clm, fates, ptclm, mosart, cime, cmeps, ww3, cice, fms, pop, cvmix, marbl, cism, source_cism, rtm, cdeps, fox, mom, cam, silhs, clubb, pumas, atmos_phys, cosp2, chem_proc, atmos_cubed_sphere, carma, 
       ./cime
   e-o ./cime/src/drivers/nuopc/
       ./components/cam
       ./components/cam/chem_proc
       ./components/cam/src/atmos_phys
       ./components/cam/src/dynamics/fv3/atmos_cubed_sphere
       ./components/cam/src/physics/carma/base
       ./components/cam/src/physics/clubb
       ./components/cam/src/physics/cosp2/src
       ./components/cam/src/physics/pumas
       ./components/cam/src/physics/silhs
       ./components/cdeps
       ./components/cdeps/fox
       ./components/cice
       ./components/cism
       ./components/cism/source_cism
       ./components/clm
       ./components/clm/src/fates
       ./components/clm/tools/PTCLM
   e-o ./components/mom
       ./components/mosart
       ./components/pop
       ./components/pop/externals/CVMix
       ./components/pop/externals/MARBL
       ./components/rtm
       ./components/ww3
   e-o ./libraries/FMS


You should now have a default copy of the CESM2 source code in your /path/to/my_cesm_sandbox.

These components are optional and are not needed to run CESM2.

.. code-block:: console

   e-o ./cime/src/drivers/nuopc/
   e-o ./components/mom
   e-o ./libraries/FMS


If there were problems obtaining an external, you might instead see something like:

.. code-block:: console

   e-  ./components/cam

This might happen if there was an unexpected interruption while downloading.  
First try rerunning ``./manage_externals/checkout_externals``.
If there is still a problem, try running with logging turned on using:

.. code-block:: console

   ./manage_externals/checkout_externals --logging

Check the ``manage_externals.log`` file to see what errors are reported.

Downloading input data
----------------------

Input datasets are needed to run the model. CESM input data are
available through a separate Subversion input data repository.

.. warning:: The input data repository contains datasets for many configurations and resolutions and is well over 10 TByte in total size. DO NOT try to download the entire dataset.

Datasets can be downloaded on a case by case basis as needed and CESM
provides tools to check and download input data automatically.

A local input data directory should exist on the local disk, and it also 
needs to be set in the CESM scripts via the variable ``$DIN_LOC_ROOT.``
For supported machines, this variable is preset. For generic machines,
this variable is set via the ``--input-dir`` argument to **create_newcase**.
It is recommended that all users of a given filesystem share the same ``$DIN_LOC_ROOT`` directory.

The files in the subdirectories of ``$DIN_LOC_ROOT`` should be
write-protected. This prevents these files from being accidentally
modified or deleted. The directories in ``$DIN_LOC_ROOT`` should generally
be group writable, so the directory can be shared among multiple users.

As part of the process of generating the CESM executable, the utility,
**check_input_data** located in each case directory
is called, and it attempts to locate all required input data for the
case based upon file lists generated by components. If the required
data is not found on local disk in ``$DIN_LOC_ROOT``, then the data
will be downloaded automatically by the scripts or it can be
downloaded by the user by invoking **check_input_data** with the ``--download``
command argument. If you want to download the input data manually you
should do it before you build CESM.

It is possible for users to download the data using svn subcommands
directly, but use of the **check_input_data** script is highly recommended
to ensure that only the required datasets are downloaded. 

.. warning:: Again, users are **STRONGLY DISCOURAGED** from downloading the entire input dataset from the repository.

