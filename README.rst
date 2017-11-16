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

1. Clone the repository. ::

      > git clone https://github.com/escomp/cesm.git

   This will create a directory cesm/ in your current working directory.

2. Go into the newly created cesm repository and determine what version of cesm you want.
   To see what cesm tags are available, simply issue the **git tag** command. ::

      > cd cesm
      > git tag

3. Do a git checkout of the tag you want. If you want to checkout cesm2_0_beta07, you would issue the following. ::

      > git checkout cesm2.0.beta07

4. Run the script **manage_externals/checkout_externals.py**. ::

      > ./manage_externals/checkout_externals.py

   The **checkout_externals.py** script is a package manager that will populate the cesm directory with the
   relevant versions of each of the components along with the CIME infrastructure code. To see more details of
   **checkout_externals.py** simply issue ::

     > ./manage_externals/checkout_externals.py --help

At this point you have a working version of CESM.

To see full details of how to set up a case, compile and run see the CIME documentation at http://esmci.github.io/cime/ .
