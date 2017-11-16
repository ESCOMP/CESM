========================================================
 The Community Earth System Model version 2.0 (CESM2.0)
========================================================

See the CESM web site for documentation and information:
http://www2.cesm.ucar.edu

Obtaining the full model code and associated scripting infrastructure
=====================================================================

CESM2.0 is now released via github. You will need some familiarity with git in order
to modify the code and commit these changes. However, to simply checkout and run the
code, no git knowledge is required other than what is documented in the following steps.

To obtain the CESM2.0 code you need to do the following:

#. Clone the repository. ::

      > git clone https://github.com/escomp/cesm.git my_cesm_sandbox

   This will create a directory ``my_cesm_sandbox/`` in your current working directory.

#. Go into the newly created CESM repository and determine what version of CESM you want.
   To see what cesm tags are available, simply issue the **git tag** command. ::

      > cd my_cesm_sandbox
      > git tag

#. Do a git checkout of the tag you want. If you want to checkout cesm2.0.beta07, you would issue the following. ::

      > git checkout cesm2.0.beta07

#. Run the script **manage_externals/checkout_externals.py**. ::

      > ./manage_externals/checkout_externals.py

   The **checkout_externals.py** script is a package manager that will populate the cesm directory with the
   relevant versions of each of the components along with the CIME infrastructure code. To see more details of
   **checkout_externals.py**, issue ::

     > ./manage_externals/checkout_externals.py --help

At this point you have a working version of CESM.

To see full details of how to set up a case, compile and run, see the CIME documentation at http://esmci.github.io/cime/ .

Customizing your CESM sandbox
=============================

There are several use cases to consider when you want to customize or modify your CESM sandbox.

Switching to a different CESM tag
---------------------------------

If you have already checked out a tag and **HAVE NOT MADE ANY
MODIFICATIONS** it is simple to change your sandbox. Say that you
checked out cesm2.0.beta07 but really wanted to have cesm2.0.beta08;
you would simply do the following::

  > git checkout cesm2.0.beta08
  > ./manage_externals/checkout_externals.py

You should **not** use this method if you have made any source code
changes, or if you have any ongoing CESM cases that were created from
this sandbox. In these cases, it is often easiest to do a second **git
clone**.

Pointing to a different version of a component
----------------------------------------------

The file **CESM.cfg** in your top-level CESM directory tells
**checkout_externals.py** which tag/branch of each component should be
brought in to generate your sandbox. (This file serves the same purpose
as SVN_EXTERNAL_DIRECTORIES when CESM was in a subversion repository.)
Each entry in **CESM.cfg** has the following form (we use CAM as an
example below)::
 
  [cam]
  tag = trunk_tags/cam5_4_143/components/cam
  protocol = svn
  repo_url = https://svn-ccsm-models.cgd.ucar.edu/cam1
  local_path = components/cam
  required = True

Each entry specifies either a tag or a branch. To point to a new tag:

#. Modify the relevant entry/entries in **CESM.cfg** (e.g., changing
   ``cam5_4_143`` to ``cam5_4_144`` above)

#. Checkout the new component(s)::

     > ./manage_externals/checkout_externals.py

Committing your change to CESM.cfg
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After making this change, it's a good idea to commit the change in your
local CESM git repository. First create a CESM branch in your local
repository, then commit it. (Unlike with subversion, branches are stored
locally unless you explicitly push them up to github. Feel free to
create whatever local branches you'd like.) For example::

  > git checkout -b my_cesm_branch
  > git add CESM.cfg
  > git commit -m "Update CAM to cam5_4_144"

Modifying a component
---------------------

If you'd like to modify a component via a branch and point to that
branch in your CESM sandbox, use the following procedure (again, using
CAM as an example):

#. Create a CAM branch. Since CAM originates from a subversion
   repository, you will first need to create a branch in that
   repository. Let's assume you have created this branch and called it
   **my_branch**.

#. Update **CESM.cfg** to point to your branch. You can replace the
   **tag** entry with a **branch** entry, as follows::

     [cam]
     branch = branches/my_branch/components/cam
     protocol = svn
     repo_url = https://svn-ccsm-models.cgd.ucar.edu/cam1
     local_path = components/cam
     required = True

#. Checkout your branch::

     > ./manage_externals/checkout_externals.py

It's a good idea to commit your **CESM.cfg** file changes. See the above
documentation, `Committing your change to CESM.cfg`_.
