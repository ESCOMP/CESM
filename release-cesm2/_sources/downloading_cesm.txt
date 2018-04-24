.. _downloading:

===================
 Downloading CESM2
===================

Downloading the code and scripts
--------------------------------

Starting with CESM2, releases are available through a public github
repository, `http://github.com/ESCOMP/cesm <http://github.com/ESCOMP/cesm>`_. 

Be aware that for release CESM2.0.0, the CAM and POP models are still
distributed via a NCAR hosted Subversion server and require a separate
authentication step for `CESM registered users
<http://www.cesm.ucar.edu/models/register/register.html>`_.

Access to the code requires both git and Subversion client software
in place that is compatible with github and our Subversion server software, such
as a recent version of the command line clients, git and svn. Currently, our
Subversion server software is at version 1.8.17. We recommend using svn and git clients at
version 1.8 or later, though older versions may suffice. For more information or to
download open source tools, visit `Subversion <http://subversion.tigris.org/>`_
and `git downloads <https://git-scm.com/downloads>`_.

With valid git and svn clients installed on the machine where CESM will be
built and run, the user may download the latest version of the release
code:

.. code-block:: console

    > git clone https://escomp.github.com/cesm/branches my_cesm_sandbox
    > cd my_cesm_sandbox

By default, this command places you at the head of the master branch of
CESM repository which may include in-test development code. We recommend
that users should check out a currently supported CESM release tag.
To list the currently supported CESM2 release tags type:

.. code-block:: console

    > git tag

To checkout a specific CESM release tag type:

.. code-block:: console 

    > git checkout release-cesm2.0.0

Alternatively, you can clone a release directly 

.. code-block:: console

    > git clone -b release-cesm2.0.0  https://escomp.github.com/cesm/branches my_cesm_sandbox

then run the **checkout_externals** script from /path/to/my_cesm_sandbox.

.. code-block:: console

    > ./manage_externals/checkout_externals

The **checkout_externals** script will read the configuration file called ``externals.cfg`` and
will download all the external component models and CIME into /path/to/my_cesm_sandbox. 

Details regarding the CESM checkout process are available in the README
at the bottom of the `http://github.com/ESCOMP/cesm <http://github.com/ESCOMP/cesm>`_ page.
To see more details regarding the checkout_externals script from the command line, type:

.. code-block:: console

    > ./manage_externals/checkout_externals --help


.. warning:: When contacting the Subversion server for the first time, you may need to accept an authentication certification.

Be aware that the request is set to the current machine login id and you
must enter the CESM registered default username of 'guestuser' by
pressing the 'Enter' key when prompted for a Username.

You may be prompted up to 3 times for the username and password when
checking out the code for the first time from the Subversion server.
This is because the code is distributed across a number of different
Subversion repositories and each repository requires authentication.

Once correctly entered, the username and password will be cached in a
protected subdirectory of the user's home directory so that repeated
entry of this information will not be required for a given machine.

.. warning:: If a problem was encountered during checkout_externals, which may happen with an older version of the svn client software, it may appear to have downloaded successfully, but in fact only a partial checkout has occurred. 

To ensure a successful download, make sure the last line of the ``manage_externals.log`` file contains:

.. code-block:: console

	INFO : 2018-04-03 15:36:19 : checkout_externals completed without exceptions.

In addition, you can run **checkout_externals** script with the following options
to ensure that the checkout process is complete:

.. code-block:: console

    > ./manage_externals/checkout_externals -S -v
 

You should now have a complete copy of the CESM2 source code in your /path/to/my_cesm_sandbox. 


Downloading input data
----------------------

Input datasets are needed to run the model. CESM input data will be made
available through a separate Subversion input data repository. The
username and password for the input data repository will be the same as
for the code repository for CESM registered users.

.. warning:: The input data repository contains datasets for many configurations and resolutions and is well over 10 TByte in total size. DO NOT try to download the entire dataset.

Datasets can be downloaded on a case by case basis as needed and CESM
provides tools to check and download input data automatically.

A local input data directory should exist on the local disk, and it also 
needs to be set in the CESM scripts via the variable ``$DIN_LOC_ROOT.``
For supported machines, this variable is preset. For generic machines,
this variable is set as an argument to **create_newcase**. It is recommended that all users
of a given filesystem share the same ``$DIN_LOC_ROOT`` directory.

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

