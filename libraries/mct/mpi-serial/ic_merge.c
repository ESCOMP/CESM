
#include "mpiP.h"

/*
 * MPI_Intercomm_merge - Creates an intracommunicator from an intercommunicator
 * This is just a stub for now to support mpi function calls even in Serial
 * applications. In the case of a serial program, this function is a no-op and
 * only ever returns MPI_SUCCESS
 */

int MPI_Intercomm_merge( MPI_Comm intercomm, int high, MPI_Comm *newintracomm )
{
  newintracomm = (MPI_Comm *)intercomm;
  return(MPI_SUCCESS);
}
