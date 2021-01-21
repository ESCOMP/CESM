//probe.c
#include "mpiP.h"

static int mpi_match_send(void *r, void *tag)
{
  return( *((int *)tag) == MPI_ANY_TAG ||
	  *((int *)tag) == ((Req *)r)->tag );
}

FC_FUNC(mpi_iprobe, MPI_IPROBE)(int * source, int * tag, int * comm,
                                  int * flag, int *status, int * ierr)
{
  *ierr = MPI_Iprobe(*source, *tag, *comm, flag, mpi_c_status(status));
}

/* Iprobe
 * Search for existing message, return status about it
 */

int MPI_Iprobe(int source, int tag, MPI_Comm comm, int *flag,
               MPI_Status *status)

{
  pListitem match;
  Comm *mycomm;
  Req *sreq;

  mycomm=mpi_handle_to_ptr(comm);         /* mycomm=(Comm *)comm; */

#ifdef INFO
  fflush(stdout);
  fprintf(stderr,"MPI_IProbev: Comm=%d  tag=%d  count=%d type=%d\n",
         mycomm->num,tag,count,datatype);
#endif


  if (source!=0 && source!=MPI_ANY_SOURCE)
    {
      fprintf(stderr,"MPI_Irecv: bad source %d\n",source);
      abort();
    }

  match=AP_list_search_func(mycomm->sendlist,mpi_match_send,&tag);

  *flag= (match==NULL ? 0:1 );

  if (*flag)
    {
      sreq=(Req *)AP_listitem_data(match);

      if (status!=MPI_STATUS_IGNORE)
	{
	  status->MPI_SOURCE=0  ;
	  status->MPI_TAG= sreq->tag;
	}
    }

  return(MPI_SUCCESS);
}


//probe:  wait for message, and return status
// (either message will immediately be available, or deadlock.

FC_FUNC(mpi_probe,MPI_PROBE)(int *source, int *tag, int *comm, int *status,
			     int *ierr)
{
  *ierr=MPI_Probe(*source,*tag,*comm,mpi_c_status(status));
}



int MPI_Probe(int source, int tag, MPI_Comm comm, MPI_Status *status)
{

  int flag;

  MPI_Iprobe(source,tag,comm,&flag,status);

  if (!flag)
    {
      fprintf(stderr,"MPI_Probe: no existing match, deadlock\n");
      abort();
    }

  return(MPI_SUCCESS);
}

