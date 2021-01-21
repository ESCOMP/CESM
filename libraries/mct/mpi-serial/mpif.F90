#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

Module mpi
implicit none
! MPI_ADDRESS_KIND: need an 8-byte integer.
        INTEGER, PARAMETER, PUBLIC :: MPI_ADDRESS_KIND=selected_int_kind(13)


        include "mpif.h"
end Module mpi
