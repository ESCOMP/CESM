/* getcount.c
 *
 * 07/2007 JCY
 * Functions for count information regarding MPI_Status
 */

#include "type.h"
#include "mpiP.h"


FC_FUNC( mpi_get_count , MPI_GET_COUNT )
	 (int *status, int *datatype, int *count, int *ierr)
{
  *ierr = MPI_Get_count((MPI_Status *)status, *datatype, count);
}


int MPI_Get_count(MPI_Status *status, MPI_Datatype datatype, int *count)
{
  *count = status->get_count;
}


/********/


FC_FUNC( mpi_get_elements , MPI_GET_ELEMENTS )
	 (MPI_Status *status, int *datatype, int *count, int *ierr)
{
  *ierr = MPI_Get_elements(status, *datatype, count);
}


int MPI_Get_elements(MPI_Status *status, MPI_Datatype datatype, int *count)
{
  Datatype dt_ptr = *(Datatype*)mpi_handle_to_datatype(datatype);
  *count = status->get_count * dt_ptr->count;
}


