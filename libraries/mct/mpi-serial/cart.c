#include "mpiP.h"

/*
 * MPI_Cart_create
 *
 * create a new communicator,
 */


FC_FUNC( mpi_cart_create , MPI_CART_CREATE )
	 ( int *comm_old, int *ndims, int *dims, int *periods,
           int *reorder, int *comm_cart, int *ierr)
{
  *ierr = MPI_Cart_create( *comm_old, *ndims, dims, periods, *reorder,
  	                   comm_cart);
}


int MPI_Cart_create( MPI_Comm comm_old, int ndims, int *dims, int *periods,
                     int reorder, MPI_Comm *comm_cart)
{
  int i;
  for (i = 0; i < ndims; i++)
    if (dims[i] > 1)
    {
      printf("MPI_Cart_create: Greater dimension than no. of procs\n");
      abort();
    }

  MPI_Comm_dup(comm_old, comm_cart);

  return MPI_SUCCESS;
}


/*
 * MPI_Cart_get
 *
 * Returns information about the cartesian organization
 * of the communicator.
 *
 * Assuming the user gives right maxdims, the only possible
 * dimensions are (1,1,..,1) for however many dimensions
 */


FC_FUNC( mpi_cart_get , MPI_CART_GET )
         (int * comm, int * maxdims, int * dims,
          int * periods, int * coords, int * ierr)
{
  *ierr = MPI_Cart_get(*comm, *maxdims, dims, periods, coords);
}


int MPI_Cart_get(MPI_Comm comm, int maxdims, int *dims,
                 int *periods, int *coords)
{
  int i;
  for (i=0;i<maxdims;i++)
  {
    dims[i]=1;
    coords[i]=0;
  }
}



/*
 * MPI_Cart_coords
 *
 * Returns the coordinates of a particular rank
 * If rank != 0, erroneous.  Coordinates must be (0,0)
 */


FC_FUNC( mpi_cart_coords , MPI_CART_COORDS)
         (int *comm, int *rank, int *maxdims, int *coords, int *ierr)
{
  *ierr = MPI_Cart_coords(*comm, *rank, *maxdims, coords);
}


int MPI_Cart_coords(MPI_Comm comm, int rank, int maxdims, int *coords)
{
  int i;

  if (rank != 0)
  {
    printf("MPI_Cart_coords: Rank != 0\n");
    abort();
  }

  for (i=0;i<maxdims;i++)
    coords[i]=0;

  return MPI_SUCCESS;
}


/*
 * MPI_Dims_create
 *
 * A convenience function to distribute nodes among a grid.  Since we have one
 * node only, every dimension must be "1" or it is erroneous
 */

FC_FUNC( mpi_dims_create , MPI_DIMS_CREATE )
         (int *nnodes, int *ndims, int * dims, int *ierr)
{
  *ierr = MPI_Dims_create(*nnodes, *ndims, dims);
}


int MPI_Dims_create(int nnodes, int ndims, int *dims)
{
  int i;

  if (nnodes > 1)
  {
    printf("MPI_Dims_create: More nodes than procs specified.\n");
    abort();
  }

  for (i=0; i<ndims; i++)
    dims[i] = 1;

  return MPI_SUCCESS;
}
