#ifndef _MPI_H_
#define _MPI_H_

#define MPI_MAX_LIBRARY_VERSION_STRING (80)

typedef int MPI_Comm;
typedef int MPI_Request;


#define MPI_COMM_WORLD (1)
#define MPI_COMM_NULL (0)      /* handle 0 maps to NULL */


typedef int MPI_Group;

/* MPI_GROUP_EMPTY and MPI_GROUP_NULL must not conflict with MPI_GROUP_ONE */
#define MPI_GROUP_EMPTY (-1)
#define MPI_GROUP_NULL  (0)


/*
 * Return codes
 *   On error, mpi-serial aborts so the values don't really matter
 *   as long as they are different than MPI_SUCCESS
 *
 */

#define MPI_SUCCESS        (0)
#define MPI_ERR_BUFFER     (-1)
#define MPI_ERR_COUNT      (-1)
#define MPI_ERR_TYPE       (-1)
#define MPI_ERR_TAG        (-1)
#define MPI_ERR_COMM       (-1)
#define MPI_ERR_RANK       (-1)
#define MPI_ERR_REQUEST    (-1)
#define MPI_ERR_ROOT       (-1)
#define MPI_ERR_GROUP      (-1)
#define MPI_ERR_OP         (-1)
#define MPI_ERR_TOPOLOGY   (-1)
#define MPI_ERR_DIMS       (-1)
#define MPI_ERR_ARG        (-1)
#define MPI_ERR_UNKNOWN    (-1)
#define MPI_ERR_TRUNCATE   (-1)
#define MPI_ERR_OTHER      (-1)
#define MPI_ERR_INTERN     (-1)
#define MPI_PENDING        (-1)
#define MPI_ERR_IN_STATUS  (-1)
#define MPI_ERR_LASTCODE   (-1)

/*
 * MPI_UNDEFINED
 *
 * Uses:
 *   value for "color" in e.g. comm_split
 *   value for rank in Group_translate_ranks
 *
 */


#define MPI_UNDEFINED (-1)


/*
 * Data types etc.
 */

typedef unsigned long int MPI_Aint;
#define MPI_BOTTOM (0)
#define MPI_IN_PLACE (void *)(-1)
typedef int MPI_Datatype;


/* The type's value is now a handle */

#define MPI_DATATYPE_NULL   (0)

//C types
#define MPI_CHAR            (-1)
#define MPI_SHORT           (-2)
#define MPI_INT             (-3)
#define MPI_LONG            (-4)
#define MPI_UNSIGNED_CHAR   (-5)
#define MPI_UNSIGNED_SHORT  (-6)
#define MPI_UNSIGNED        (-7)
#define MPI_UNSIGNED_LONG   (-8)
#define MPI_FLOAT           (-9)
#define MPI_DOUBLE          (-10)
#define MPI_LONG_DOUBLE     (-11)

//Cross-language
#define MPI_BYTE            (-12)
#define MPI_PACKED          (-13)
#define MPI_LB              (-14)
#define MPI_UB              (-15)

// Fortran types
#define MPI_INTEGER           (-16)     // RML: why not (MPI_INT)
#define MPI_REAL              (-17)     // RML: why not (MPI_FLOAT)
#define MPI_DOUBLE_PRECISION  (-18)     // RML: why not (MPI_DOUBLE)

#define MPI_COMPLEX           (-19)
#define MPI_DOUBLE_COMPLEX    (-20)
#define MPI_LOGICAL           (-21)
#define MPI_CHARACTER         (-22)
#define MPI_2REAL             (-23)
#define MPI_2DOUBLE_PRECISION (-24)
#define MPI_2INTEGER          (-25)

//Reduction function types

#define MPI_FLOAT_INT       (-26)
#define MPI_DOUBLE_INT      (-27)
#define MPI_LONG_INT        (-28)
#define MPI_2INT            (-29)
#define MPI_SHORT_INT       (-30)
#define MPI_LONG_DOUBLE_INT (-31)


/* Fortran size-specific types */

#define MPI_INTEGER1       (-32)
#define MPI_INTEGER2       (-33)
#define MPI_INTEGER4       (-34)
#define MPI_INTEGER8       (-35)
#define MPI_INTEGER16      (-36)

#define MPI_REAL4          (-37)
#define MPI_REAL8          (-38)
#define MPI_REAL16         (-39)

#define MPI_COMPLEX8       (-40)
#define MPI_COMPLEX16      (-41)
#define MPI_COMPLEX32      (-42)

/* Some more types */

#define MPI_LONG_LONG_INT       (-43)
#define MPI_LONG_LONG           MPI_LONG_LONG_INT
#define MPI_UNSIGNED_LONG_LONG  (-44)

#define MPI_OFFSET              (-45)


/*
 * Fortran int size
 *
 */

typedef int MPI_Fint;



#define MPI_ANY_TAG (-1)

#define MPI_ANY_SOURCE (-1)
#define MPI_PROC_NULL (-2)
#define MPI_ROOT (-3)

#define MPI_REQUEST_NULL (0)

#define MPI_MAX_ERROR_STRING (128)
#define MPI_MAX_PROCESSOR_NAME (128)


/*
 * MPI_Status
 *
 * definition must be compatible with the mpif.h values for
 * MPI_STATUS_SIZE, MPI_SOURCE, MPI_TAG, and MPI_ERROR.
 *
 * Note: The type used for MPI_Status_int must be chosen to match
 * Fortran INTEGER.
 *
 */

typedef int MPI_Status_int;

typedef struct                  /* Fortran: INTEGER status(MPI_STATUS_SIZE) */
{
  MPI_Status_int MPI_SOURCE;    /* Fortran: status(MPI_SOURCE) */
  MPI_Status_int MPI_TAG;       /* Fortran: status(MPI_TAG) */
  MPI_Status_int MPI_ERROR;     /* Fortran: status(MPI_ERROR) */
  int            get_count;     /* Number specified for send */

} MPI_Status;


#define MPI_STATUS_IGNORE    ((MPI_Status *)0)
#define MPI_STATUSES_IGNORE  ((MPI_Status *)0)


/*
 * MPI Errhandling stubs (Not functional currently)
 */
typedef int MPI_Errhandler;

#define MPI_ERRORS_ARE_FATAL ((MPI_Errhandler)0)
#define MPI_ERRORS_RETURN    ((MPI_Errhandler)-1)


/*
 * Collective operations
 */


typedef int MPI_Op;

typedef void MPI_User_function( void *invec, void *inoutvec, int *len,
                                MPI_Datatype *datatype);

#define MPI_OP_NULL (0)

#define MPI_MAX     (0)
#define MPI_MIN     (0)
#define MPI_SUM     (0)
#define MPI_PROD    (0)
#define MPI_LAND    (0)
#define MPI_BAND    (0)
#define MPI_LOR     (0)
#define MPI_BOR     (0)
#define MPI_LXOR    (0)
#define MPI_BXOR    (0)
#define MPI_MAXLOC  (0)
#define MPI_MINLOC  (0)



#define MPI_STATUS_SIZE       (sizeof(MPI_Status) / sizeof(int))


/* NOTE: the C type MPI_Offset is NOT the same as MPI datatype MPI_OFFSET */
typedef long long int MPI_Offset;


/* info
 */

typedef int MPI_Info;         /* handle */

#define MPI_INFO_NULL (0)



/**********************************************************
 *
 * Note: if you need to regenerate the prototypes below,
 * you can use 'protify.awk' and paste the output here.
 *
 */


extern int MPI_Intercomm_create(MPI_Comm local_comm, int local_leader,
                          MPI_Comm peer_comm, int remote_leader,
                          int tag, MPI_Comm *newintercomm);
extern int MPI_Intercomm_merge(MPI_Comm intercomm, int high,
			       MPI_Comm *newintercomm);
extern int MPI_Cart_create(MPI_Comm comm_old, int ndims, int *dims,
                        int *periods, int reorder, MPI_Comm *comm_cart);
extern int MPI_Cart_get(MPI_Comm comm, int maxdims, int *dims,
                        int *periods, int *coords);
extern int MPI_Cart_coords(MPI_Comm comm, int rank, int maxdims,
                        int *coords);
extern int MPI_Dims_create(int nnodes, int ndims, int *dims);

extern int MPI_Barrier(MPI_Comm comm );
extern int MPI_Bcast(void* buffer, int count, MPI_Datatype datatype,
                     int root, MPI_Comm comm );
extern int MPI_Gather(void* sendbuf, int sendcount, MPI_Datatype sendtype,
                      void* recvbuf, int recvcount, MPI_Datatype recvtype,
                      int root, MPI_Comm comm);
extern int MPI_Gatherv(void* sendbuf, int sendcount, MPI_Datatype sendtype,
                       void* recvbuf, int *recvcounts, int *displs,
                       MPI_Datatype recvtype, int root, MPI_Comm comm);
extern int MPI_Allgather(void* sendbuf, int sendcount, MPI_Datatype sendtype,
                         void* recvbuf, int recvcount, MPI_Datatype recvtype,
                         MPI_Comm comm);
extern int MPI_Allgatherv(void* sendbuf, int sendcount, MPI_Datatype sendtype,
                          void* recvbuf, int *recvcounts, int *displs,
                          MPI_Datatype recvtype, MPI_Comm comm);
extern int MPI_Scatter( void* sendbuf, int sendcount, MPI_Datatype sendtype,
                        void* recvbuf, int recvcount, MPI_Datatype recvtype,
                        int root, MPI_Comm comm);
extern int MPI_Scatterv(void* sendbuf, int *sendcounts, int *displs,
                        MPI_Datatype sendtype, void* recvbuf, int recvcount,
                        MPI_Datatype recvtype, int root, MPI_Comm comm);
extern int MPI_Reduce(void* sendbuf, void* recvbuf, int count,
                      MPI_Datatype datatype, MPI_Op op, int root, MPI_Comm comm);
extern int MPI_Reduce_scatter(void* sendbuf, void* recvbuf, int *recvcounts,
                         MPI_Datatype datatype, MPI_Op op, MPI_Comm comm);
extern int MPI_Allreduce(void* sendbuf, void* recvbuf, int count,
                         MPI_Datatype datatype, MPI_Op op, MPI_Comm comm);
extern int MPI_Scan( void* sendbuf, void* recvbuf, int count,
                    MPI_Datatype datatype, MPI_Op op, MPI_Comm comm);
extern int MPI_Alltoall(void *sendbuf, int sendcount, MPI_Datatype sendtype,
                        void *recvbuf, int recvcount, MPI_Datatype recvtype,
                        MPI_Comm comm);
extern int MPI_Alltoallv(void *sendbuf, int *sendcounts,
                         int *sdispls, MPI_Datatype sendtype,
                         void *recvbuf, int *recvcounts,
                         int *rdispls, MPI_Datatype recvtype,
                         MPI_Comm comm) ;
extern int MPI_Alltoallw(void *sendbuf, int *sendcounts,
                         int *sdispls, MPI_Datatype *sendtypes,
                         void *recvbuf, int *recvcounts,
                         int *rdispls, MPI_Datatype *recvtypes,
                         MPI_Comm comm) ;


extern int MPI_Op_create(MPI_User_function *function, int commute,
                         MPI_Op *op);
extern MPI_Op MPI_Op_f2c(MPI_Fint op);
extern MPI_Fint MPI_Op_c2f(MPI_Op op);
extern MPI_Comm mpi_comm_new(void);
extern int MPI_Op_free(MPI_Op *op);
extern int MPI_Comm_free(MPI_Comm *comm);
extern int MPI_Comm_size(MPI_Comm comm, int *size);
extern int MPI_Comm_rank(MPI_Comm comm, int *rank);
extern int MPI_Comm_dup(MPI_Comm comm, MPI_Comm *newcomm);
extern int MPI_Comm_create(MPI_Comm comm, MPI_Group group, MPI_Comm *newcomm);
extern int MPI_Comm_split(MPI_Comm comm, int color, int key, MPI_Comm *newcomm);
extern int MPI_Comm_group(MPI_Comm comm, MPI_Group *group);
extern MPI_Comm MPI_Comm_f2c(MPI_Fint comm);
extern MPI_Fint MPI_Comm_c2f(MPI_Comm comm);
extern int MPI_Group_incl(MPI_Group group, int n, int *ranks, MPI_Group *newgroup);
extern int MPI_Group_range_incl(MPI_Group group, int n, int ranges[][3],
                         MPI_Group *newgroup);
extern int MPI_Group_union(MPI_Group group1, MPI_Group group2, MPI_Group *newgroup);
extern int MPI_Group_intersection(MPI_Group group1, MPI_Group group2,
                                  MPI_Group *newgroup);
extern int MPI_Group_difference(MPI_Group group1, MPI_Group group2,
                         MPI_Group *newgroup);
extern int MPI_Group_free(MPI_Group *group);
extern int MPI_Group_translate_ranks(MPI_Group group1, int n, int *ranks1,
                                     MPI_Group group2, int *ranks2);
extern MPI_Group MPI_Group_f2c(MPI_Fint group);
extern MPI_Fint MPI_Group_c2f(MPI_Group group);

extern int MPI_Init(int *argc, char **argv[]) ;
extern int MPI_Finalize(void);
extern int MPI_Abort(MPI_Comm comm, int errorcode);
extern int MPI_Error_string(int errorcode, char *string, int *resultlen);
extern int MPI_Get_processor_name(char *name, int *resultlen);

extern int MPI_Info_create(MPI_Info *info);
extern int MPI_Info_set(MPI_Info info, char *key, char *value);

extern int MPI_Initialized(int *flag);
extern int MPI_Pack( void *inbuf, int incount, MPI_Datatype datatype,
                     void *outbuf, int outsize, int *position, MPI_Comm comm);
extern int MPI_Unpack( void *inbuf, int insize, int *position,
                       void *outbuf, int outcount, MPI_Datatype datatype,
                       MPI_Comm comm );
extern int MPI_Irecv(void *buf, int count, MPI_Datatype datatype,
                     int source, int tag, MPI_Comm comm, MPI_Request *request);
extern int MPI_Recv(void *buf, int count, MPI_Datatype datatype, int source,
                    int tag, MPI_Comm comm, MPI_Status *status);

extern int MPI_Test(MPI_Request *request, int *flag, MPI_Status *status);
extern int MPI_Wait(MPI_Request *request, MPI_Status *status);
extern int MPI_Testany(int count,  MPI_Request *array_of_requests,
                       int *index, int *flag, MPI_Status *status);
extern int MPI_Waitany(int count, MPI_Request *array_of_requests,
                       int *index, MPI_Status *status);
extern int MPI_Testall(int count, MPI_Request *array_of_requests,
                       int *flag, MPI_Status *array_of_statuses);
extern int MPI_Waitall(int count, MPI_Request *array_of_requests,
                       MPI_Status *array_of_statuses);
extern MPI_Request MPI_Request_f2c(MPI_Fint request);
extern MPI_Fint MPI_Request_c2f(MPI_Request request);
extern int MPI_Testsome(int incount, MPI_Request *array_of_requests,
                        int *outcount, int *array_of_indices,
                        MPI_Status *array_of_statuses);
extern int MPI_Waitsome(int incount, MPI_Request *array_of_requests,
                        int *outcount, int *array_of_indices,
                        MPI_Status *array_of_statuses);
extern int MPI_Request_free(MPI_Request * req);
extern int MPI_Isend(void *buf, int count, MPI_Datatype datatype,
                     int dest, int tag, MPI_Comm comm, MPI_Request *request) ;
extern int MPI_Send(void* buf, int count, MPI_Datatype datatype,
                    int dest, int tag, MPI_Comm comm);
extern int MPI_Ssend(void* buf, int count, MPI_Datatype datatype,
                     int dest, int tag, MPI_Comm comm);
extern int MPI_Rsend(void* buf, int count, MPI_Datatype datatype,
                     int dest, int tag, MPI_Comm comm);
extern int MPI_Irsend(void *buf, int count, MPI_Datatype datatype,
                     int dest, int tag, MPI_Comm comm, MPI_Request *request) ;
extern int MPI_Sendrecv(void* sendbuf, int sendcount, MPI_Datatype sendtype,
                        int dest, int sendtag,
                        void *recvbuf, int recvcount, MPI_Datatype recvtype,
                        int source, int recvtag,
                        MPI_Comm comm, MPI_Status *status);

extern int MPI_Probe(int source, int tag, MPI_Comm comm, MPI_Status *status);
extern int MPI_Iprobe(int source, int tag, MPI_Comm comm,
                      int *flag, MPI_Status *status);

extern int MPI_Pack_size(int incount, MPI_Datatype type, MPI_Comm comm, MPI_Aint * size);

/* Error handling stub, not currently functional */
extern int MPI_Errhandler_set(MPI_Comm comm, MPI_Errhandler handle);

/* new type functions */
extern int MPI_Get_count(MPI_Status *status, MPI_Datatype datatype, int *count);
extern int MPI_Get_elements(MPI_Status *status, MPI_Datatype datatype, int *count);
extern int MPI_Type_contiguous(int count, MPI_Datatype oldtype, MPI_Datatype *newtype);

extern int MPI_Type_vector(int count, int blocklen, int stride, MPI_Datatype oldtype,
                           MPI_Datatype *newtype);

extern int MPI_Type_hvector(int count, int blocklen, MPI_Aint stride,
                            MPI_Datatype oldtype, MPI_Datatype *newtype);

extern int MPI_Type_create_hvector(int count, int blocklen, MPI_Aint stride,
                            MPI_Datatype oldtype, MPI_Datatype *newtype);

extern int MPI_Type_indexed(int count, int *blocklens, int *displacements,
                            MPI_Datatype oldtype, MPI_Datatype *newtype);

extern int MPI_Type_create_indexed_block(int count, int blocklen, int *displacements,
                                  MPI_Datatype oldtype, MPI_Datatype *newtype);
extern int MPI_Type_hindexed(int count, int *blocklens, MPI_Aint *displacements,
                             MPI_Datatype oldtype, MPI_Datatype *newtype);
extern int MPI_Type_size(MPI_Datatype type, int * size);
extern int MPI_Type_struct(int count, int *blocklens, MPI_Aint *displacements,
                           MPI_Datatype *oldtypes, MPI_Datatype *newtype);
extern int MPI_Type_dup(MPI_Datatype oldtype, MPI_Datatype *newtype);

extern int MPI_Type_extent(MPI_Datatype datatype, MPI_Aint * extent);
extern int MPI_Type_commit(MPI_Datatype * datatype);
extern int MPI_Type_free(MPI_Datatype * datatype);
extern int MPI_Type_lb(MPI_Datatype datatype, MPI_Aint * lb);
extern int MPI_Type_ub(MPI_Datatype datatype, MPI_Aint * ub);

extern double MPI_Wtime(void);

#endif
