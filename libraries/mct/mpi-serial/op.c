#include "mpi.h"
#include "mpiP.h"
/* Because operations based on one processor are essentially no operation,
 * all MPI_Ops are handled as null ops.  Therefore, returning 0 (OP_NULL)
 * suffices here.
 */

FC_FUNC(mpi_op_create, MPI_OP_CREATE)(MPI_User_function *func, int * commute, int * op, int * ierr)
{
  *ierr = MPI_Op_create(func, *commute, op);
}

int MPI_Op_create(MPI_User_function *function, int commute, MPI_Op *op)
{
  *op = 0;
  return MPI_SUCCESS;
}

FC_FUNC(mpi_op_free, MPI_OP_FREE)(int * op, int * ierr)
{
  *ierr = MPI_Op_free(op);
}

int MPI_Op_free(MPI_Op * op)
{
  return MPI_SUCCESS;
}

