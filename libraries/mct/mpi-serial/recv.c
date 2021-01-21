
#include "mpiP.h"



/*
 * RECEIVING
 *
 */



static int mpi_match_send(void *r, void *tag)
{
  return( *((int *)tag) == MPI_ANY_TAG ||
	  *((int *)tag) == ((Req *)r)->tag );
}



/*
 *
 */



FC_FUNC( mpi_irecv , MPI_IRECV )(void *buf, int *count, int *datatype,
				   int *source, int *tag, int *comm,
				   int *request, int *ierror)
{

  *ierror=MPI_Irecv(buf,*count,*datatype,*source,*tag,
		    *comm, (void *)request);

}



int MPI_Irecv(void *buf, int count, MPI_Datatype datatype,
	      int source, int tag, MPI_Comm comm, MPI_Request *request)

{
  pListitem match;
  Comm *mycomm;
  Req *rreq, *sreq;

  mycomm=mpi_handle_to_ptr(comm);         /* mycomm=(Comm *)comm; */

#ifdef INFO
  fflush(stdout);
  fprintf(stderr,"MPI_Irecv: Comm=%d  tag=%d  count=%d type=%d\n",
	 mycomm->num,tag,count,datatype);
#endif


  if (source!=0 && source!=MPI_ANY_SOURCE && source!=MPI_PROC_NULL)
    {
      fprintf(stderr,"MPI_Irecv: bad source %d\n",source);
      abort();
    }

  mpi_alloc_handle(request,(void **)&rreq);

  if (source==MPI_PROC_NULL)
    {
      rreq->complete=1;
      rreq->source=MPI_PROC_NULL;
      rreq->tag=MPI_ANY_TAG;

      return(MPI_SUCCESS);
    }


  if ( match=AP_list_search_func(mycomm->sendlist,mpi_match_send,&tag) )
    {
      sreq=(Req *)AP_listitem_data(match);
      AP_list_delete_item(mycomm->sendlist,match);

//      memcpy(buf,sreq->buf,count * datatype);
      copy_data2(sreq->buf, count, datatype, buf, count, datatype);
      rreq->complete=1;
      rreq->source=0;
      rreq->tag=sreq->tag;                   /* in case tag was MPI_ANY_TAG */

      sreq->complete=1;

#ifdef DEBUG
      printf("Completion(recv) value=%d tag=%d\n",
	     *((int *)buf),rreq->tag);
#endif

      return(MPI_SUCCESS);
    }

  rreq->buf=buf;
  rreq->tag=tag;
  rreq->complete=0;
  rreq->listitem=AP_list_append(mycomm->recvlist,rreq);

#ifdef INFO
  print_list(mycomm->recvlist,"recvlist for comm ",mycomm->num);
#endif

  return(MPI_SUCCESS);
}


/*********/


FC_FUNC( mpi_recv , MPI_RECV )(void *buf, int *count, int *datatype,
				 int *source, int *tag, int *comm,
				 int *status, int *ierror)
{
  *ierror=MPI_Recv(buf,*count,*datatype,*source,*tag,*comm,
		   mpi_c_status(status));
}



int MPI_Recv(void *buf, int count, MPI_Datatype datatype, int source,
             int tag, MPI_Comm comm, MPI_Status *status)
{
  MPI_Request request;

#ifdef INFO
  fflush(stdout);
  fprintf(stderr,"MPI_Recv: ");
#endif


  MPI_Irecv(buf,count,datatype,source,tag,comm,&request);
  MPI_Wait(&request,status);

  if (status!=MPI_STATUS_IGNORE)
    status->get_count = count;   // rml: shouldn't this depend on send?

  return(MPI_SUCCESS);
}



#ifdef INFO

int print_item(void *item, void *data)
{
  fprintf(stderr,"%d  ", ((Req *)item)->tag);
  return(0);
}


int print_list(pList list, char *msg, int num)
{
  fflush(stdout);
  fprintf(stderr,"%s %d: ",msg,num);

  AP_list_apply(list,print_item,NULL);

  fprintf(stderr,"\n");
  return(0);
}


#endif
