
#include "mpiP.h"



/*
 * Communicators
 *
 */



MPI_Comm mpi_comm_new(void)
{
  MPI_Comm chandle;
  Comm *cptr;
  static int num=0;

  mpi_alloc_handle(&chandle,(void **) &cptr);

  cptr->sendlist=AP_list_new();
  cptr->recvlist=AP_list_new();

  cptr->num=num++;

  return(chandle);
}


/*********/


FC_FUNC( mpi_comm_free , MPI_COMM_FREE )(int *comm, int *ierror)
{
  *ierror=MPI_Comm_free(comm);
}


/*
 * MPI_Comm_free()
 *
 * Note: will NOT free any pending MPI_Request handles
 * that are allocated...  correct user code should have
 * already done a Wait or Test to free them.
 *
 */


int MPI_Comm_free(MPI_Comm *comm)
{
  pList sendlist, recvlist;
  int size;
  Comm *mycomm;

  mycomm=mpi_handle_to_ptr(*comm);   /* (Comm *)(*comm) */

  sendlist=mycomm->sendlist;
  recvlist=mycomm->recvlist;

  size=AP_list_size(sendlist);
  if (size!=0)
    fprintf(stderr,"MPI_Comm_free: warning: %d pending send reqs\n",
	    size);
  AP_list_free(sendlist);


  size=AP_list_size(recvlist);
  if (size!=0)
    fprintf(stderr,"MPI_Comm_free: warning: %d pending receive reqs\n",
	    size);
  AP_list_free(recvlist);

  mpi_free_handle(*comm);            /* free(mycomm); */
  *comm=MPI_COMM_NULL;

  return(MPI_SUCCESS);
}


/*********/



FC_FUNC( mpi_comm_size , MPI_COMM_SIZE )(int *comm, int *size, int *ierror)
{
  *ierror=MPI_Comm_size(*comm, size);
}



int MPI_Comm_size(MPI_Comm comm, int *size)
{
  *size=1;

  return(MPI_SUCCESS);
}


/*********/


FC_FUNC( mpi_comm_rank , MPI_COMM_RANK )(int *comm, int *rank, int *ierror)
{
  *ierror=MPI_Comm_rank( *comm, rank);
}


int MPI_Comm_rank(MPI_Comm comm, int *rank)
{
  *rank=0;

  return(MPI_SUCCESS);
}



/*********/


FC_FUNC( mpi_comm_dup , MPI_COMM_DUP )(int *comm, int *newcomm, int *ierror)
{

  *ierror=MPI_Comm_dup( *comm, newcomm);

}


int MPI_Comm_dup(MPI_Comm comm, MPI_Comm *newcomm)
{
  *newcomm= mpi_comm_new();

#ifdef INFO
  fflush(stdout);
  fprintf(stderr,"MPI_Comm_dup: new comm handle=%d\n",*newcomm);
#endif

  return(MPI_SUCCESS);
}


/*********/


int FC_FUNC( mpi_comm_create, MPI_COMM_CREATE)
     (int *comm, int *group, int *newcomm, int *ierror)
{
  *ierror=MPI_Comm_create(*comm,*group,newcomm);
}



int MPI_Comm_create(MPI_Comm comm, MPI_Group group, MPI_Comm *newcomm)
{
  if (group==MPI_GROUP_NULL || group==MPI_GROUP_EMPTY)
    *newcomm= MPI_COMM_NULL;
  else
    *newcomm=mpi_comm_new();

  return(MPI_SUCCESS);
}



/*********/


FC_FUNC( mpi_comm_split, MPI_COMM_SPLIT )
     (int *comm, int *color, int *key, int *newcomm, int *ierror)
{
  *ierror=MPI_Comm_split(*comm,*color,*key,newcomm);

}



int MPI_Comm_split(MPI_Comm comm, int color, int key, MPI_Comm *newcomm)
{
  if (color==MPI_UNDEFINED)
    *newcomm=MPI_COMM_NULL;
  else
    *newcomm= mpi_comm_new();

  return(MPI_SUCCESS);
}


/*********/


FC_FUNC( mpi_comm_group, MPI_COMM_GROUP )
     (int *comm, int *group, int *ierror)
{
  *ierror= MPI_Comm_group(*comm, group);
}



int MPI_Comm_group(MPI_Comm comm, MPI_Group *group)
{
  if (comm==MPI_COMM_NULL)
    *group= MPI_GROUP_NULL;
  else
    *group= MPI_GROUP_ONE;

  return(MPI_SUCCESS);
}

/* Intercomm_create
 *
 */

FC_FUNC(mpi_intercomm_create, MPI_INTERCOMM_CREATE)(
                          int * local_comm, int * local_leader,
                          int * peer_comm,  int * remote_leader,
                          int * tag, int * newintercomm, int* ierr)
{
  *ierr = MPI_Intercomm_create(*local_comm, *local_leader, *peer_comm,
                               *remote_leader, *tag, newintercomm);
}

int MPI_Intercomm_create(MPI_Comm local_comm, int local_leader,
                          MPI_Comm peer_comm, int remote_leader,
                          int tag, MPI_Comm *newintercomm)
{
  if (local_comm==MPI_COMM_NULL && peer_comm==MPI_COMM_NULL)
    *newintercomm = MPI_COMM_NULL;
  else
    MPI_Comm_dup(MPI_COMM_WORLD, newintercomm);

  return MPI_SUCCESS;
}


/*********/


MPI_Comm MPI_Comm_f2c(MPI_Fint comm)
{
  /* Comm is an integer handle used both by C and Fortran */
  return(comm);
}


MPI_Fint MPI_Comm_c2f(MPI_Comm comm)
{
  return(comm);
}
