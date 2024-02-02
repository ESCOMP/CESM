==================================
 The Community Earth System Model
==================================

See the CESM web site for documentation and information:

http://www.cesm.ucar.edu

The CESM Quickstart Guide is available at:

http://escomp.github.io/cesm

This repository provides tools for managing the external components that
make up a CESM tag - alpha, beta and release. CESM tag creation should
be coordinated through CSEG at NCAR.

This repository is also connected to slack at http://cesm2.slack.com

.. sectnum::

.. contents::

Software requirements
=====================

Software requirements for installing, building and running CESM
---------------------------------------------------------------

Installing, building and running CESM requires:

* a Unix-like operating system (Linux, AIX, OS X, etc.)

* git client version 1.8 or newer

* python3 version 3.6 or newer

* perl version 5

* build tools gmake and cmake

* Fortran and C compilers

  * See `Details on Fortran compiler versions`_ below for more information

* LAPACK and BLAS libraries

* a NetCDF library version 4.3 or newer built with the same compiler you
  will use for CESM

  * a PnetCDF library is optional

* a functioning MPI environment (unless you plan to run on a single core
  with the CIME mpi-serial library)

Details on Fortran compiler versions
------------------------------------
The Fortran compiler must support Fortran 2003 features. However, even
among mainstream Fortran compilers that claim to support Fortran 2003,
we have found numerous bugs. Thus, many compiler versions do *not* build
or run CESM properly (see
https://wiki.ucar.edu/display/ccsm/Fortran+Compiler+Bug+List for more
details on older Fortran compiler versions).

CESM2 is tested on several different systems with newer Fortran compilers:
Please see `CESM Compiler/Machine Tests <https://docs.google.com/spreadsheets/d/15QUqsXD1Z0K_rYNTlykBvjTRt8s0XcQw0cfAj9DZbj0/edit#gid=0>`_
for a spreadsheet of the current results.

More details on porting CESM
----------------------------

For more details on porting CESM to a new machine, see
http://esmci.github.io/cime/users_guide/porting-cime.html

Obtaining the full model code and associated scripting infrastructure
=====================================================================

CESM is now released via github. You will need some familiarity with git in order
to modify the code and commit these changes. However, to simply checkout and run the
code, no git knowledge is required other than what is documented in the following steps.

To obtain the CESM code you need to do the following:

#. Clone the repository. ::

      git clone https://github.com/escomp/cesm.git my_cesm_sandbox

   This will create a directory ``my_cesm_sandbox/`` in your current working directory.

#. Go into the newly created CESM repository and determine what version of CESM you want.
   To see what cesm tags are available, simply issue the **git tag** command. ::

      cd my_cesm_sandbox
      git tag

#. Do a git checkout of the tag you want. If you want to checkout release-cesm2.1.5a, you would issue the following. ::

      git checkout release-cesm2.1.5

   (It is normal and expected to get a message about being in 'detached
   HEAD' state.)

#. Run the script **bin/git-fleximod install**. ::

      ./bin/git-fleximod checkout

   The **git-fleximod** script is a package manager that will
   populate the cesm directory with the relevant versions of each of the
   components along with the CIME infrastructure code.

At this point you have a working version of CESM.

To see full details of how to set up a case, compile and run, see the CIME documentation at http://esmci.github.io/cime/ .

More details on git-fleximod
----------------------------------

The file **.gitmodules** in your top-level CESM directory tells
**git-fleximod** which tag/branch of each component should be
brought in to generate your sandbox. 

NOTE: git-fleximod will always attempt
to make the working copy exactly match the submodule description. For
example, if you manually modify an submodule without updating .gitmodules
(e.g. switch to a different tag), then rerunning git-fleximod update
will automatically restore the submodules described in .gitmodules See
below documentation `Customizing your CESM sandbox`_ for more details.

**You need to rerun git-fleximod update whenever .gitmodules has
changed** (unless you have already manually updated the relevant
external(s) to have the correct branch/tag checked out). Common times
when this is needed are:

* After checking out a new CESM branch/tag

* After merging some other CESM branch/tag into your currently
  checked-out branch

To see more details of **git-fleximod**, issue ::

  ./bin/git-fleximod -h

or visit the github page https://github.com/jedwards4b/git-fleximod

Customizing your CESM sandbox
=============================

There are several use cases to consider when you want to customize or modify your CESM sandbox.

Switching to a different CESM tag
---------------------------------

If you have already checked out a tag and **HAVE NOT MADE ANY
MODIFICATIONS** it is simple to change your sandbox. Say that you
checked out release-cesm2.1.2 but really wanted to have release-cesm2.1.5;
you would simply do the following::

  git checkout release-cesm2.1.5
  ./bin/git-fleximod update

You should **not** use this method if you have made any source code
changes, or if you have any ongoing CESM cases that were created from
this sandbox. In these cases, it is often easiest to do a second **git
clone**.

Pointing to a different version of a component
----------------------------------------------

Each entry in **.gitmodules** has the following form (we use CAM as an
example below)::

[submodule "cam"]
	path = components/cam
	url = https://www.github.com/jedwards4b/CAM
	fxurl = https://www.github.com/ESCOMP/CAM
        fxtag = cam6_3_143_rme01
        fxrequired = T:T
        
Each entry specifies a tag. To point to a new tag:

#. Modify the relevant entry/entries in **.gitmodules** (e.g., changing
   ``cam5_4_143_rme01`` to ``cam5_4_144_rme01`` above)

#. Checkout the new component(s)::

     ./bin/git-fleximod update

Keep in mind that changing individual components from a tag may result
in an invalid model (won't compile, won't run, not scientifically
meaningful) and is unsupported.

Committing your change to .gitmodules
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After making this change, it's a good idea to commit the change in your
local CESM git repository. First create a CESM branch in your local
repository, then commit it. (In git branches are stored
locally unless you explicitly push them up to github. Feel free to
create whatever local branches you'd like.) 

Modifying a component
---------------------

If you'd like to modify a component via a branch and point to that
branch in your CESM sandbox, use the following procedure (again, using
CAM as an example):

#. Create a CAM fork and a branch within that fork. 
   Let's assume you have created this branch and called it
   **my_branch**.

#. Update **.gitmodules** to point to your fork.

     [cam]
     url = https://github.com/mygithubusername/cam
     path = components/cam
     fxrequired = T:T
     fxtag = cam6_3_143_mytagname
     fxrequired = T:T

#. Checkout your branch::

     ./bin/git-fleximod update cam

It's a good idea to commit your **.gitmodules** file changes. See the above
documentation, `Committing your change to .gitmodules`_.

Developer setup
===============

Developers who have not already done so should follow the recommended
`one-time <https://github.com/esmci/cime/wiki/CIME-Git-Workflow#configure-git-one-time>`_
setup directions for git. Developers may also want to set up
`ssh <https://help.github.com/articles/connecting-to-github-with-ssh/>`_
keys and switch to using the ``git@github.com:ESCOMP/cesm.git`` form of the github URLs.
