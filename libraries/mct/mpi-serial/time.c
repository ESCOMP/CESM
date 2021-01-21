
#include <sys/time.h>
#include <time.h>


#include "mpiP.h"


double MPI_Wtime(void);



double FC_FUNC( mpi_wtime, MPI_WTIME )(void)
{
  return(MPI_Wtime());
}



double MPI_Wtime(void)
{
  struct timeval tv;

  if (gettimeofday(&tv,0))
    {
      fprintf(stderr,"MPI_Wtime: error calling gettimeofday()\n");
      abort();
    }


  return((double)(tv.tv_sec) + (double)(tv.tv_usec)/1e6) ;
}



