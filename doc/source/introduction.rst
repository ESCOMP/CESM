.. _introduction:

========================
Introduction (|version|)
========================

How To Use This Document
------------------------

This guide instructs both novice and experienced users on downloading,
building and running `CESM2
<http://www.cesm.ucar.edu/models/cesm2>`_.

CESM2 is built on the `CIME framework <http://github.com/ESMCI/cime>`_.

The majority of the CESM2 User's Guide is contained in the `CIME`_ documentation.

If you are a new user, we recommend reading the first few sections of
the `CIME`_ documentation which is written so that, as much as
possible, individual sections stand on their own and the `CIME`_
documentation guide can be scanned and sections read in a relatively
ad hoc order.

.. code-block:: console 

    Throughout the guide, this presentation style indicates shell
    commands and options, fragments of code, namelist variables, etc.

.. note:: 

   Variables presented as ``$VAR`` in this guide typically refer to variables in XML files
   in a CESM case. From within a case directory, you can determine the value of such a
   variable with ``./xmlquery VAR``. In some instances, ``$VAR`` refers to a shell
   variable or some other variable; we try to make these exceptions clear.
    
Please feel free to provide feedback to the `CESM forum <https://bb.cgd.ucar.edu/>`_ about how to improve the
documentation. 

CESM Model Version Naming Conventions
-------------------------------------

CESM model release versions include three numbers separated by a period (.)
- CESM X.Y.Z

-  X - corresponds to the major release number indicating significant
   science changes.

-  Y - corresponds to the addition of new infrastructure and new science
   capabilities for targeted components.

-  Z - corresponds to release bug fixes and machine updates.

When refering to CESM2, it is understood that the all versions of the
CESM2.Y.Z series of models are included. 

CESM Overview
=============

The Community Earth System Model (CESM) is a coupled climate model for
simulating Earth's climate system. Composed of separate models
simultaneously simulating the Earth's atmosphere, ocean, land, river
run-off, land-ice, and sea-ice, plus one central coupler/moderator
component, CESM allows researchers to conduct fundamental research
into the Earth's past, present, and future climate states.

CESM can be run on a number of different `hardware platforms
<http://www.cesm.ucar.edu/models/cesm2/cesm/machines.html>`__, and
has a relatively flexible design with respect to `processor layout
<http://esmci.github.io/cime/versions/master/html/users_guide/pes-threads.html>`__
of components.

The CESM project is a cooperative effort among U.S. climate
researchers.  Primarily supported by the `National Science
Foundation(NSF) <https://www.nsf.gov/>`_ and centered at the `National
Center for Atmospheric Research (NCAR) <https://ncar.ucar.edu/>`_ in
Boulder, Colorado, the CESM project enjoys close collaborations with
the `U.S. Department of Energy (DOE) <https://energy.gov/>`_ and the
`National Aeronautics and Space Administration (NASA)
<http://www.nasa.gov>`_.  Scientific development of the CESM is guided
by the CESM working groups, which meet twice a year. The main CESM
workshop is held each year in June to showcase results from the
various working groups and coordinate future CESM developments among
the working groups. The `CESM website <http://www.cesm.ucar.edu/>`__
provides more information on the CESM project, such as the management
structure, the scientific working groups, downloadable source code,
and online archives of data from previous CESM experiments.

CESM2 Software/Operating System Prerequisites
---------------------------------------------

The following are the external system and software requirements for
installing and running CESM2.

-  UNIX style operating system such as CNL, AIX or Linux

-  python >= 2.7

-  perl 5 

-  subversion client (version 1.8 or greater but less than v1.11) for downloading CAM, POP, and WW3

-  git client (1.8 or greater)

-  Fortran compiler with support for Fortran 2003

-  C compiler

-  MPI (although CESM does not absolutely require it for running on one processor)

-  `NetCDF 4.3 or newer <http://www.unidata.ucar.edu/software/netcdf/>`_.

-  `ESMF 5.2.0 or newer (optional) <http://www.earthsystemmodeling.org/>`_.

-  `pnetcdf 1.7.0 is required and 1.8.1 is optional but recommended <http://trac.mcs.anl.gov/projects/parallel-netcdf/>`_

-  `Trilinos <https://trilinos.github.io/>`_ may be required for certain configurations 

-  `LAPACK <http://www.netlib.org/lapack/>`_ and `BLAS <http://www.netlib.org/blas/>`_

-  `CMake 2.8.6 or newer <http://www.cmake.org/>`_ 

.. warning:: NetCDF must be built with the same Fortran compiler as CESM. In the netCDF build the FC environment variable specifies which Fortran compiler to use. CESM is written mostly in Fortran, netCDF is written in C. Because there is no standard way to call a C program from a Fortran program, the Fortran to C layer between CESM and netCDF will vary depending on which Fortran compiler you use for CESM. When a function in the netCDF library is called from a Fortran application, the netCDF Fortran API calls the netCDF C library. If you do not use the same compiler to build netCDF and CESM you will in most cases get errors from netCDF saying certain netCDF functions cannot be found.

Parallel-netCDF, also referred to as pnetcdf, is optional. If a user
chooses to use pnetcdf, version 1.7.0 or later should be used with CESM.
It is a library that is file-format compatible with netCDF, and provides
higher performance by using MPI-IO. Pnetcdf is enabled by setting the
``$PNETCDF_PATH`` Makefile variable in the ``Macros.make`` file.

.. _CIME: http://esmci.github.io/cime
