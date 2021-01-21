# ParallelIO

A high-level Parallel I/O Library for structured grid applications

## Website

For complete documentation, see our website at
[http://ncar.github.io/ParallelIO/](http://ncar.github.io/ParallelIO/).

## Mailing List

The (low-traffic) PIO mailing list is at
https://groups.google.com/forum/#!forum/parallelio, send email to the
list at parallelio@googlegroups.com.

## Nightly Tests

The results of our nightly tests on multiple platforms can be found on our
cdash site at [http://my.cdash.org/index.php?project=PIO](http://my.cdash.org/index.php?project=PIO).

## Dependencies

PIO can use NetCDF (version 4.6.1+) and/or PnetCDF (version 1.9.0+)
for I/O. NetCDF may be built with or without netCDF-4 features. NetCDF
is required for PIO, PnetCDF is optional.

Ideally, the NetCDF version should be built with MPI, which requires that it
be linked with an MPI-enabled version of HDF5.  Optionally, NetCDF can be 
built with DAP support, which introduces a dependency on CURL.  Additionally,
HDF5, itself, introduces dependencies on LIBZ and (optionally) SZIP.

## Building PIO

To build PIO, unpack the distribution tarball and do:

```
CC=mpicc FC=mpif90 ./configure --enable-fortran && make check install
```

For a full description of the available options and flags, try:
```
./configure --help
```

Note that environment variables CC and FC may need to be set to the
MPI versions of the C and Fortran compiler. Also CPPFLAGS and LDFLAGS
may need to be set to indicate the locations of one or more of the
dependent libraries. (If using MPI compilers, the entire set of
dependent libraries should be built with the same compilers.) For
example:

```
export CC=mpicc
export FC=mpifort
export CPPFLAGS='-I/usr/local/netcdf-fortran-4.4.5_c_4.6.3_mpich-3.2/include -I/usr/local/netcdf-c-4.6.3_hdf5-1.10.5/include -I/usr/local/pnetcdf-1.11.0_shared/include'
export LDFLAGS='-L/usr/local/netcdf-c-4.6.3_hdf5-1.10.5/lib -L/usr/local/pnetcdf-1.11.0_shared/lib'
./configure --prefix=/usr/local/pio-2.4.2 --enable-fortran
make check
make install
```

## Building with CMake

The typical configuration with CMake can be done as follows:

```
CC=mpicc FC=mpif90 cmake [-DOPTION1=value1 -DOPTION2=value2 ...] /path/to/pio/source
```

Full instructions for the cmake build can be found in the installation
documentation.
