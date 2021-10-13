.. _configurations:

================================
CESM2 Configurations (|version|)
================================

The CESM2 system can be configured a number of different ways from both
a science and technical perspective. CESM2 supports numerous
`resolutions
<http://www.cesm.ucar.edu/models/cesm2/cesm/grids.html>`_, and
`component sets
<http://www.cesm.ucar.edu/models/cesm2/cesm/compsets.html>`_.  In
addition, each model component has input options to configure specific
`model settings
<http://www.cesm.ucar.edu/models/cesm2/settings/current>`_
and `parameterizations
<http://www.cesm.ucar.edu/models/cesm2/settings/current>`_.


CESM2 Components
----------------

CESM2 consists of seven geophysical model components: 

- `atmosphere (atm) <http://www.cesm.ucar.edu/models/cesm2/atmosphere>`_
- `sea-ice (ice) <http://www.cesm.ucar.edu/models/cesm2/sea-ice>`_
- `land (lnd) <http://www.cesm.ucar.edu/models/cesm2/land>`_
- `river (rof) <http://www.cesm.ucar.edu/models/cesm2/river>`_
- `ocean (ocn), <http://www.cesm.ucar.edu/models/cesm2/ocean>`_
- `land-ice (glc) <http://www.cesm.ucar.edu/models/cesm2/land-ice>`_
- `ocean-wave (wav) <http://www.cesm.ucar.edu/models/cesm2/wave>`_

and an external system processing component

- external system processing (esp) 
  
In addition CESM2 is accompanied by a `driver/coupler (cpl7)
<http://esmci.github.io/cime/versions/master/html/driver_cpl/index.html>`_ that coordinates
the time evolution of geophysical components and periodically permits
the components to exchange data.  Each component is represented in one
of several modes: "active," "data," "dead," or "stub" that permits the
whole system to activate and deactive component feedbacks by allowing
for a variety of "plug and play" combinations.

During the course of a CESM2 run, the model components integrate forward
in time, periodically exchanging information with the coupler.
The coupler meanwhile receives fields from the component models,
computes, maps, and merges this information, then sends the fields back
to the component models. The coupler brokers this sequence of
communication interchanges and manages the overall time progression of
the coupled system. A CESM2 component set is comprised of eight
components: one component from each model (atm, lnd, rof, ocn, ice, glc,
wav, and esp) plus the coupler. Model components are written primarily in
Fortran.

The active (dynamical) components are generally fully prognostic, and
they are state-of-the-art climate prediction and analysis tools. Because
the active models are relatively expensive to run, data models that
cycle input data are included for testing, spin-up, and model
parameterization development. The dead components generate
scientifically invalid data and exist only to support technical system
testing. The dead components must all be run together and should never
be combined with any active or data versions of models. Stub components
exist only to satisfy interface requirements when the component is not
needed for the model configuration (e.g., the active land component
forced with atmospheric data does not need ice, ocn, or glc components,
so ice, ocn, and glc stubs are used).

The CESM2 components can be summarized as follows:

.. csv-table:: "CESM2 model components"
   :header: "Component Generic Type", "Component Generic Name", "Component Name", "Component Type", "Description"
   :widths: 12, 10, 10, 10, 60

   "atmosphere","atm","cam", "active","The `Community Atmosphere Model (CAM) <http://www.cesm.ucar.edu/models/cesm2/atmosphere/>`_ is a global atmospheric general circulation model developed from the NCAR CCM3."                                                                                                                                      
   "atmosphere","atm","datm", "data", "The `data atmosphere <http://esmci.github.io/cime/versions/master/html/data_models/data-atm.html>`_ component is a pure data component that reads in atmospheric forcing data"
   "atmosphere","atm", "xatm", "dead", "Used only for testing the driver/coupler"
   "atmosphere","atm", "satm", "stub", "Used only to satisy the interface requirements"
   "land", "lnd", "clm", "active", "The `Community Land Model (CLM) <http://www.cesm.ucar.edu/models/cesm2/land/>`_ is the result of a collaborative project between scientists in the Terrestrial Sciences Section of the Climate and Global Dynamics Division (CGD) at NCAR and the CESM Land Model Working Group. Other principal working groups that also contribute to the CLM are Biogeochemistry, Paleoclimate, and Climate Change and Assessment."
   "land", "lnd", "dlnd", "data", "The `data land component <http://esmci.github.io/cime/versions/master/html/data_models/data-lnd.html>`_ is a purely data-land component (reading in coupler history data for atm/land fluxes and land albedos produced by a previous run, or snow surface mass balance fields) or both."
   "land", "lnd", "xlnd", "dead", "Used only for testing the driver/coupler"
   "land", "lnd", "slnd", "stub", "Used only to satisy the interface requirements"
   "river", "rof", "rtm", "active", "The `river transport model (RTM) <http://www.cesm.ucar.edu/models/cesm2/river/>`_ was previously part of CLM and was developed to route total runoff from the land surface model to either the active ocean or marginal seas which enables the hydrologic cycle to be closed (Branstetter 2001, Branstetter and Famiglietti 1999). This is needed to model ocean convection and circulation, which is affected by freshwater input."
   "river", "rof", "mosart", "active", "`MOdel for Scale Adaptive River Transport (MOSART) <http://www.cesm.ucar.edu/models/cesm2/river/>`_ , a new large-scale river routing model. MOSART improves the magnitude and timing of river flow simulations."
   "river", "rof", "drof", "data", "The `data runoff model <http://esmci.github.io/cime/versions/master/html/data_models/data-river.html>`_ was previously part of the data land model and functions as a purely data-runoff model (reading in runoff data)."
   "river", "rof", "xrof", "dead", "Used only for testing the driver/coupler"
   "river", "rof", "srof", "stub", "Used only to satisy the interface requirements"
   "ocean", "ocn", "pop", "active", "The ocean model is an extension of the `Parallel Ocean Program (POP) <http://www.cesm.ucar.edu/models/cesm2/ocean/>`_ Version 2 from Los Alamos National Laboratory (LANL)."
   "ocean", "ocn", "mom6", "active", "Based on the `Modular Ocean Model version 6 <http://www.cesm.ucar.edu/models/cesm2/ocean/>`_; an early functional release is available starting in CESM2.2.   Note that MOM6 is not obtained by default; for instructions on obtaining it, see https://github.com/ESCOMP/MOM_interface/wiki/Detailed-Instructions."
   "ocean", "ocn", "docn", "data", "The `data ocean <http://esmci.github.io/cime/versions/master/html/data_models/data-ocean.html>`_ component has two distinct modes of operation. It can run as a pure data model, reading ocean SSTs (normally climatological) from input datasets, interpolating in space and time, and then passing these to the coupler. Alternatively, docn can compute updated SSTs based on a slab ocean model where bottom ocean heat flux convergence and boundary layer depths are read in and used with the atmosphere/ocean and ice/ocean fluxes obtained from the coupler."
   "ocean", "ocn", "xocn", "dead"
   "ocean", "ocn", "socn", "stub"
   "sea-ice", "ice", "cice", "active", "The `sea-ice component (CICE) <http://www.cesm.ucar.edu/models/cesm2/sea-ice/>`_ is an extension of the Los Alamos National Laboratory (LANL) sea-ice model and was developed though collaboration within the CESM Polar Climate Working Group (PCWG). In CESM, CICE can run as a fully prognostic component or in prescribed mode where ice coverage (normally climatological) is read in."
   "sea-ice", "ice", "dice", "data", "The `data ice <http://esmci.github.io/cime/versions/master/html/data_models/data-seaice.html>`_ component is a partially prognostic model. The model reads in ice coverage and receives atmospheric forcing from the coupler, and then it calculates the ice/atmosphere and ice/ocean fluxes. The data ice component acts very similarly to CICE running in prescribed mode."
   "sea-ice", "ice", "xice", "dead", "Used only for testing the driver/coupler"
   "sea-ice", "ice", "sice", "stub"
   "land-ice", "glc", "cism", "active", The `CISM component <http://www.cesm.ucar.edu/models/cesm2/land-ice/>`_ is an extension of the Glimmer ice sheet model.                                                                                                                                                                                        
   "land-ice", "glc", "sglc", "stub", "Used only to satisy the interface requirements"
   "ocean-wave", "wav", "wav", "ww3","The `ww3 <http://www.cesm.ucar.edu/models/cesm2/wave/>`_ component adds prognostic ocean waves to the system" 
   "ocean-wave", "wav", "xwav", "dead", "Used only for testing the driver/coupler"
   "ocean-wave", "wav", "swav", "stub", "Used only to satisy the interface requirements"
   "coupler", "cpl", "cpl", "active", "The `CESM coupler <http://esmci.github.io/cime/versions/master/html/driver_cpl/index.html>`_ was built primarily through a collaboration of the NCAR CESM Software Engineering Group and the Argonne National Laboratory (ANL). The MCT coupling library provides much of the infrastructure."


CESM2 Component Sets
--------------------

The CESM2 components can be combined in numerous ways to carry out
various scientific or software experiments. A particular mix of
components, *along with* component-specific configuration and/or
namelist settings is called a `component set or compset
<http://www.cesm.ucar.edu/models/cesm2/cesm/compsets.html>`_. CESM has a
shorthand naming convention (known as an alias) for component sets that
are supported out-of-the-box. The compset alias usually has a
well-defined first letter followed by some characters that are
indicative of the configuration setup.

The first letter in a compset alias generally indicates which of the
components are fully active (prognostic), which are data components, and
which are completely absent (or stub). For the most part, this first
letter refers only to the atmosphere (atm), land (lnd), sea ice (ice)
and ocean (ocn) components. The type of component used for river (rof),
land ice (glc) and ocean wave (wav) is either specified in some other
way in the alias or is not specified explicitly. For example, an
evolving land ice (glc) model is denoted by a capital G near the end of
the compset alias (e.g., B1850G is similar to B1850 but with an evolving
Greenland ice sheet). In some cases, the distinction between prognostic
and data components is not clear-cut -- for example, when using a data
ocean model in slab ocean model (SOM) mode, or when using a prognostic
sea ice model (CICE) in prescribed mode.

The following table summarizes these first-letter designations in
compset aliases:

.. table::

    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | Designation | Active Components  | Data Components | Notes                                                                    |
    +=============+====================+=================+==========================================================================+
    | A           | --                 | various         | All data components; used for software testing                           |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | B           | atm, lnd, ice, ocn | --              | Fully active components                                                  |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | C           | ocn                | atm, ice, rof   | \                                                                        |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | D           | ice                | atm, ocn, rof   | Slab ocean model (SOM)                                                   |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | E           | atm, lnd, ice      | ocn             | Slab ocean model (SOM)                                                   |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | F           | atm, lnd           | ice, ocn        | Sea ice in prescribed mode; some F compsets use fewer surface components |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | G           | ice, ocn           | atm, rof        | \                                                                        |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | I           | lnd                | atm             | \                                                                        |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | J           | lnd, ice, ocn      | atm             | Can be used to spin up the surface components                            |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | P           | atm                | --              | CAM PORT compsets                                                        |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | Q           | atm                | ocn             | Aquaplanet compsets                                                      |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | S           | --                 | --              | No components present; used for software testing                         |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | T           | glc                | lnd             | \                                                                        |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+
    | X           | --                 | --              | Coupler-test components; used for software testing                       |
    +-------------+--------------------+-----------------+--------------------------------------------------------------------------+

See `supported component sets
<http://www.cesm.ucar.edu/models/cesm2/cesm/compsets.html>`_ for a
complete list of supported compset options. Running **query_config**
with the ``--compsets`` option will also provide a listing of the
supported out-of-the-box component sets for the local version of CESM2.


CESM2 Grids
-----------

The `supported grid resolutions
<http://www.cesm.ucar.edu/models/cesm2/cesm/grids.html>`_ are
specified in CESM2 by setting an overall model resolution.  Once the
overall model resolution is set, components will read in appropriate
grid files and the coupler will read in appropriate mapping weights
files. Coupler mapping weights are always generated externally in
CESM2. The components will send the grid data to the coupler at
initialization, and the coupler will check that the component grids
are consistent with each other and with the mapping weights files.

In CESM2, the ocean and ice must be on the same grid, but the
atmosphere, land, river runoff and land ice can each be on different grids.
Each component determines its own unique grid decomposition based upon
the total number of pes or processing elements assigned to that component.

CESM2 supports several types of grids out-of-the-box including single
point, finite volume, cubed sphere, displaced pole, and
tripole. These grids are used internally by the
models. Input datasets are usually on the same grid but in some cases,
they can be interpolated from regular lon/lat grids in the data models.
The finite volume is generally associated with
atmosphere and land models but the data ocean and data ice models are
also supported on that grid. The cubed sphere grid is used only by the
active atmosphere model, cam. The displaced pole and tripole grids
are used by the ocean and ice models. Not every grid can be run by every
component. The ocean and ice models run on either a Greenland dipole or
a tripole grid. The Greenland Pole grid is a
latitude/longitude grid, with the North Pole displaced over Greenland to
avoid singularity problems in the ocn and ice models. The low-resolution
Greenland pole mesh from CCSM3 is illustrated in `Yeager et al., "The
Low-Resolution CCSM3", AMS (2006), Figure 1b.,
Web. <http://journals.ametsoc.org/doi/pdf/10.1175/JCLI3744.1>`_
Similarly, the `Poseidon tripole
grid <http://www.cesm.ucar.edu/models/cesm1.0/cesm/cesm_doc_1_0_4/x42.html>`_ is a latitude/longitude
grid with three poles that are all centered over land.


CESM2 Machines
--------------

Scripts for `supported machines
<http://www.cesm.ucar.edu/models/cesm2/cesm/machines.html>`_ and
userdefined machines are provided with the CESM2 release. Supported
machines have machine specific files and settings added to the CESM2
scripts and are machines that should run CESM2 cases
out-of-the-box. Machines are supported in CESM2 on an individual basis
and are usually listed by their common site-specific name. To get a
machine ported and functionally supported in CESM2, local batch, run,
environment, and compiler information must be configured in the CESM2
scripts. The machine name "userdefined" machines refer to any machine
that the user defines and requires that a user edit the resulting xml
files to fill in information required for the target platform. This
functionality is handy in accelerating the porting process and quickly
getting a case running on a new platform. For more information on
porting, see the `CIME porting guide
<http://esmci.github.io/cime/versions/master/html/users_guide/porting-cime.html>`_.  The
list of available machines are documented in `CESM2 supported machines
<http://www.cesm.ucar.edu/models/cesm2/cesm/machines.html>`_.
Running **query_config** with the ``--machines`` option will also show
the list of all machines for the current local version of
CESM. Supported machines have undergone the full CESM2 porting
process. The machines available in each of these categories changes as
access to machines change over time.


CESM2 Validation
----------------

Although CESM2 can be run out-of-the-box for a variety of resolutions,
component combinations, and machines, MOST combinations of component
sets, resolutions, and machines have not undergone rigorous scientific
climate validation. Control runs accompany `scientifically supported
<http://www.cesm.ucar.edu/models/scientifically-supported.html>`_
component sets and resolutions and are documented on the release page.
These control runs should be scientifically reproducible on the
original platform or other platforms. Bit-for-bit reproducibility
cannot be guaranteed due to variations in compiler or system
versions. Users should carry out their own `port validations
<http://esmci.github.io/cime/versions/master/html/users_guide/porting-cime.html#validating-your-port>`_
on any platform prior to doing scientific runs or scientific analysis
and documentation.



