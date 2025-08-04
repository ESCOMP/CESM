# Earthworks

[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://github.com/EarthWorksOrg/EarthWorks/blob/main/LICENSE)

EarthWorks is a community earth system model that strives to provide high-resolution climate-scale simulations. This work leverages and extends the [Community Earth System Model](https://github.com/ESCOMP/CESM) where possible to allow coupled runs of Atmosphere, Land, and Ocean components on a single grid with horizontal spacing (cell size) less than 4km.

EarthWorks allows the usage of MPAS-Ocean and MPAS-SeaIce components as an extension on CESM. When used with the MPAS-A dynamical core in the Community Atmosphere Model (CAM), regridding operations are reduced. EarthWorks also leverages the GPU-ported physics within CAM, the MPAS-A v7.x OpenACC port, and an MPAS-Ocean OpenACC port to run on GPUs to further increase performance.

Help us out by contributing your ideas and changes! Read the [Contributors' Guide](https://github.com/EarthWorksOrg/EarthWorks/blob/main/CONTRIBUTING.md) for more info.

Visit our [Wiki](https://github.com/EarthWorksOrg/EarthWorks/wiki) for instructions to get started and other guides.

This work is made possible through collaboration of NSF NCAR, Colorado State University, and others.

-----------

To checkout externals:

    ./bin/git-fleximod update

The externals are stored in: .gitmodules

The .gitmodules file can be modified. Then, running `bin/git-fleximod update` fetches the updated externals.

Details about git-fleximod and the variables in the .gitmodules file can be found in: .lib/git-fleximod/README.md

OR online in the repository for git-fleximod: https://github.com/ESMCI/git-fleximod

------------
