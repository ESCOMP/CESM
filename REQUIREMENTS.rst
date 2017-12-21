============================
 CESM software requirements
============================

Software requirements for installing, building and running CESM
===============================================================

Installing, building and running CESM requires:

* a Unix-like operating system (Linux, AIX, OS X, etc.)

* git client version 1.8 or newer

* subversion client version ??? or newer

* python2 version 2.7 or newer

* perl version ??? or newer

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
====================================

The Fortran compiler must support Fortran 2003 features. However, even
among mainstream Fortran compilers that claim to support Fortran 2003,
we have found numerous bugs. Thus, many compiler versions do *not* build
or run CESM properly (see
https://wiki.ucar.edu/display/ccsm/Fortran+Compiler+Bug+List for more
details).

We regularly test CESM with the following Fortran compiler versions:

* Intel (ifort) versions ???

* Gnu (gfortran) versions ???

* PGI (pgfortran) versions ???
    
* NAG (nagfor) versions ???

* Others???

The following relatively recent compiler versions are known to have
problems building and running at least some CESM configurations. **Do
not try to use these compiler versions:**

* Intel (ifort) versions 16.x

* PGI (pgfortran) versions ???

* Others???

More details on porting CESM
============================

For more details on porting CESM to a new machine, see
http://esmci.github.io/cime/users_guide/porting-cime.html
