#include "mpiP.h"


/*
 * COMPLETION
 */



FC_FUNC( mpi_test , MPI_TEST)(int *request, int *flag, int *status,
                                int *ierror)
{
  *ierror=MPI_Test( (void *)request ,flag,mpi_c_status(status));
}



int MPI_Test(MPI_Request *request, int *flag, MPI_Status *status)
{
  Req *req;

  if (*request==MPI_REQUEST_NULL)
    {
      if (status!=MPI_STATUS_IGNORE)
	{
	  status->MPI_TAG= MPI_ANY_TAG;
	  status->MPI_SOURCE= MPI_ANY_SOURCE;
	}
      *flag=1;
      return(MPI_SUCCESS);
    }


  req=mpi_handle_to_ptr(*request);

  *flag=req->complete;

  if (*flag)
    {
      if (status!=MPI_STATUS_IGNORE)
	{
	  status->MPI_SOURCE= req->source;
	  status->MPI_TAG= req->tag;
	}

      mpi_free_handle(*request);
      *request=MPI_REQUEST_NULL;
    }

  return(MPI_SUCCESS);
}



FC_FUNC( mpi_wait , MPI_WAIT )(int *request, int *status, int *ierror)
{
  *ierror=MPI_Wait( (void *)request, mpi_c_status(status) );
}



int MPI_Wait(MPI_Request *request, MPI_Status *status)
{
  int flag;

  MPI_Test(request,&flag,status);

  if (!flag)
    {
      fprintf(stderr,"MPI_Wait: request not complete, deadlock\n");
      abort();
    }

  return(MPI_SUCCESS);
}


/*********/


FC_FUNC( mpi_waitany , MPI_WAITANY )(int *count, int *requests,
                                       int *index, int *status, int *ierror)
{

  *ierror=MPI_Waitany(*count, (void *)requests,index,mpi_c_status(status));
}



int MPI_Waitany(int count, MPI_Request *array_of_requests,
                int *index, MPI_Status *status)
{
  int flag;

  MPI_Testany(count, array_of_requests, index, &flag, status);

  if (!flag)
  {
    /* none are completed */

    fprintf(stderr,"MPI_Waitany: no requests complete, deadlock\n");
    abort();

  }

  return(MPI_SUCCESS);
}

/* MPI_Testany:  looks for any message matching an element
 * in request array and returns its status.
 * flag=0 means no match was found.
 */

FC_FUNC(mpi_testany, MPI_TESTANY)
         (int * count, int * array_of_requests,
          int * index, int * flag, int *status, int * ierr)
{
  *ierr = MPI_Testany(*count, array_of_requests, index,
                      flag, mpi_c_status(status));
}

int MPI_Testany(int count,  MPI_Request *array_of_requests,
                int *index, int *flag, MPI_Status *status)
{
  int i;

  for (i=0; i<count; i++)
    {
      MPI_Test(&array_of_requests[i],flag,status);

      if (*flag)
        return(MPI_SUCCESS);
    }

  /* none are completed */

  *flag=0;
  return(MPI_SUCCESS);
}

/************
 * testall: tests that all requests have completed,
 * if so return request array, otherwise set flag=0
 */
FC_FUNC(mpi_testall, MPI_TESTALL)
         (int * count, int * array_of_requests, int *flag,
          int * array_of_statuses, int * ierr)
{
  *ierr = MPI_Testall(*count, array_of_requests, flag,
                      mpi_c_statuses(array_of_statuses));
}

int MPI_Testall(int count, MPI_Request *array_of_requests,
                int *flag, MPI_Status *array_of_statuses)
{
  int i;
  int iflag;

  *flag = 1;

  for (i=0; i<count && flag; i++)
  {
      MPI_Test(&array_of_requests[i],&iflag,&array_of_statuses[i]);

      if (!iflag)
        *flag=0;
  }

  return(MPI_SUCCESS);
}

/*********/
/* Waitall:  Does a testall, but if no request has
 * completed, abort with an error
 */

FC_FUNC( mpi_waitall , MPI_WAITALL )(int *count, int *array_of_requests,
                                       int *array_of_statuses, int *ierror)
{
  *ierror=MPI_Waitall(*count, (void *)array_of_requests,
                      mpi_c_statuses(array_of_statuses));

}



int MPI_Waitall(int count, MPI_Request *array_of_requests,
                MPI_Status *array_of_statuses)
{
  int i;
  int flag;

  for (i=0; i<count; i++)
    {
      MPI_Test(&array_of_requests[i],&flag,&array_of_statuses[i]);

      if (!flag)
        {
          fprintf(stderr,"MPI_Waitall: request not complete, deadlock\n");
          abort();
        }
    }

  return(MPI_SUCCESS);
}

/* Testsome:  tests each of an array of requests, and returns each one's
 * status in an array (if it is available
 */

FC_FUNC(mpi_testsome, MPI_TESTSOME)
         (int * incount, int * array_of_requests, int * outcount,
          int * array_of_indices, int * array_of_statuses, int * ierr)
{
  *ierr = MPI_Testsome(*incount, array_of_requests, outcount,
		       array_of_indices, mpi_c_statuses(array_of_statuses));
}

int MPI_Testsome(int incount, MPI_Request *array_of_requests, int *outcount,
                 int *array_of_indices, MPI_Status *array_of_statuses)
{
  int i;
  int flag;

  *outcount =0;
    for (i=0; i<incount; i++)
    {
      flag=0;
      MPI_Test(&array_of_requests[i],&flag,&array_of_statuses[i]);

      if (flag)
        *outcount++;
    }

  return(MPI_SUCCESS);

}

/* Waitsome: checks for availability of at least one status from array of
 * requests.  If no statuses are available, abort with error
 */

FC_FUNC(mpi_waitsome, MPI_WAITSOME)
         (int * incount, int * array_of_requests, int * outcount,
          int * array_of_indices, int *array_of_statuses, int * ierr)
{
  *ierr = MPI_Waitsome(*incount, array_of_requests, outcount,
		       array_of_indices, mpi_c_statuses(array_of_statuses));
}

int MPI_Waitsome(int incount, MPI_Request *array_of_requests, int *outcount,
                 int *array_of_indices, MPI_Status *array_of_statuses)
{
  MPI_Testsome(incount, array_of_requests, outcount,
               array_of_indices, array_of_statuses);

  if (!outcount)
  {
    fprintf(stderr,"Waitsome: No requests complete, deadlock\n");
    abort();
  }

  return MPI_SUCCESS;
}

/***********************/
/* Request_free:  Frees the handle and request
 */

FC_FUNC(mpi_request_free, MPI_REQUEST_FREE)
         (int * request, int * ierr)
{
  *ierr = MPI_Request_free(request);
}

int MPI_Request_free(MPI_Request * req)
{
  mpi_free_handle(*req);
  *req = MPI_REQUEST_NULL;
  return (MPI_SUCCESS);
}



/*********/


MPI_Request MPI_Request_f2c(MPI_Fint request)
{
  return(request);
}


/*********/



MPI_Fint MPI_Request_c2f(MPI_Request request)
{
  return(request);
}
