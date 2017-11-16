========================================================
 The Community Earth System Model version 2.0 (CESM2.0)
========================================================

See the CESM web site for documentation and information:
http://www2.cesm.ucar.edu

Obtaining and running the model
===============================
CESM2.0 is now released via github. You will need some familiarity with git in order
to modify the code and commit these changes. However, to simply checkout and run the
code, no git knowledge is required other than what is documented in the following steps.

To obtain the CESM2.0 code you need to do the following:

1. clone the repository

   ::

      > git clone https://github.com/escomp/cesm.git

   This will create a directory cesm/ in your current working directory.

2. cd into the newly created cesm repository and run the script **manage_externals/checkout_externals.py**

   ::

      > cd cesm
      > ./manage_externals/checkout_externals.py

   The **checkout_externals.py** script is a package manager that will populate the cesm directory with the
   relevant versions of each of the components along with the CIME infrastructure code. A quick overview of
   **checkout_externals.py** is provided below.
