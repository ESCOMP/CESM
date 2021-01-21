
#include "mpiP.h"



/***/


FC_FUNC( mpi_info_create , MPI_INFO_CREATE ) (int *info, int *ierror)
{
  *ierror=MPI_Info_create(info);
}



int MPI_Info_create(MPI_Info *info)
{
  /* For now, we aren't storing anything, so don't bother with a real handle */
  *info=0;
  return(MPI_SUCCESS);
}


/***/


FC_FUNC( mpi_info_set , MPI_INFO_SET ) (int *info, char *key, char *value, int *ierror)
{
  *ierror=MPI_Info_set(*info, key, value);
}


int MPI_Info_set(MPI_Info info, char *key, char *value)
{
  /* for now, don't bother storing anything */
  return(MPI_SUCCESS);
}

/***/

FC_FUNC( mpi_info_free , MPI_INFO_FREE ) (int *info, int *ierror)
{
  *ierror=MPI_Info_free(info);
}



int MPI_Info_free(MPI_Info *info)
{
  /* For now, we aren't storing anything, so don't bother with a real handle */
  *info=0;
  return(MPI_SUCCESS);
}
