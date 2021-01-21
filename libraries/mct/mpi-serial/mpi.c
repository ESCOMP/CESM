

#include "mpiP.h"
#include "mpi.h"
#include "type.h"

/****************************************************************************/

static int initialized=0;


/* Store fortran pointer values here */

static int *f_MPI_STATUS_IGNORE;
static int *f_MPI_STATUSES_IGNORE;
static int *f_MPI_IN_PLACE;

static char *mpi_version_string="mpi-serial 2.0";


/****************************************************************************/


/*
 * INIT/FINALIZE
 *
 */



FC_FUNC( mpi_init_fort , MPI_INIT_FORT)
                          (int *f_MPI_COMM_WORLD,
                           int *f_MPI_ANY_SOURCE, int *f_MPI_ANY_TAG,
			   int *f_MPI_PROC_NULL, int *f_MPI_ROOT,
                           int *f_MPI_COMM_NULL, int *f_MPI_REQUEST_NULL,
			   int *f_MPI_GROUP_NULL, int *f_MPI_GROUP_EMPTY,
			   int *f_MPI_UNDEFINED,
                           int *f_MPI_MAX_ERROR_STRING,
                           int *f_MPI_MAX_PROCESSOR_NAME,
                           int *f_MPI_STATUS_SIZE,
                           int *f_MPI_SOURCE, int *f_MPI_TAG, int *f_MPI_ERROR,
			   int *f_status,
			   int *fsource, int *ftag, int *ferror,
                           int *f_MPI_INTEGER, void *fint1, void *fint2,
                           int *f_MPI_LOGICAL, void *flog1, void *flog2,
                           int *f_MPI_REAL, void *freal1, void *freal2,
                           int *f_MPI_DOUBLE_PRECISION,
			   void *fdub1, void *fdub2,
			   int *f_MPI_COMPLEX, void *fcomp1, void *fcomp2,
                           int *ierror)
{
  int err;
  int size;
  int offset;

  *ierror=MPI_Init(NULL,NULL);

  err=0;

  /*
   * These 3 macros compare things from mpif.h (as passed in by the f_
   * arguments) to the values in C (from #including mpi.h).
   *
   * Unfortunately, this kind of thing is done most easily in a nasty
   * looking macto.
   *
   */


  /*
   * verify_eq
   *   compare value of constants in C and fortran
   *   i.e. compare *f_<name> to <name>
   */

#define verify_eq(name)  \
  if (*f_##name != name) \
    { fprintf(stderr,"mpi-serial: mpi_init_fort: %s not consistent " \
                     "between mpif.h (%d) and mpi.h (%d)\n",\
                     #name,*f_##name,name); \
      err=1; }

#define verify_eq_warn(name)  \
  if (*f_##name != name) \
    { fprintf(stderr,"mpi-serial: mpi_init_fort: warning: %s not consistent " \
                     "between mpif.h (%d) and mpi.h (%d)\n",\
                     #name,*f_##name,name); \
    }


  /*
   * verify_size
   *   verify that the type name in fortran has the correct
   *   value (i.e. the size of that data type).
   *   Determine size by subtracting the pointer values of two
   *   consecutive array locations.
   */

#define verify_size(name,p1,p2) \
  if ( (size=((char *)(p2) - (char *)(p1))) != Simpletype_length( \
              (*(Datatype*)mpi_handle_to_datatype(*f_##name))->pairs[0].type) ) \
    { fprintf(stderr,"mpi-serial: mpi_init_fort: mpif.h %s (%d) " \
                     "does not match actual fortran size (%d)\n", \
                     #name,*f_##name,size); \
      err=1; }

  /*
   * verify_field
   *   check the struct member offsets for MPI_Status vs. the
   *   fortan integer array offsets.  E.g. the location of
   *   status->MPI_SOURCE should be the same as STATUS(MPI_SOURCE)
   */

#define verify_field(name) \
  { offset= (char *)&((MPI_Status *)f_status)->name - (char *)f_status; \
    if ( offset != (*f_##name-1)*sizeof(int) ) \
    { fprintf(stderr,"mpi-serial: mpi_init_fort: mpif.h %s (%d) (%d bytes) " \
                     "is inconsistent w/offset in MPI_Status (%d bytes)\n", \
                    #name,*f_##name,(*f_##name-1)*sizeof(int),offset); \
      err=1; }}



  verify_eq(MPI_COMM_WORLD);
  verify_eq(MPI_ANY_SOURCE);
  verify_eq(MPI_ANY_TAG);
  verify_eq(MPI_PROC_NULL);
  verify_eq(MPI_ROOT);
  verify_eq(MPI_COMM_NULL);
  verify_eq(MPI_REQUEST_NULL);
  verify_eq(MPI_GROUP_NULL);
  verify_eq(MPI_GROUP_EMPTY);
  verify_eq(MPI_UNDEFINED);
  verify_eq(MPI_MAX_ERROR_STRING);
  verify_eq(MPI_MAX_PROCESSOR_NAME);

  verify_eq(MPI_STATUS_SIZE);
  verify_field(MPI_SOURCE);
  verify_field(MPI_TAG);
  verify_field(MPI_ERROR);

  verify_eq(MPI_INTEGER);
  verify_size(MPI_INTEGER,fint1,fint2);

  verify_size(MPI_LOGICAL,flog1,flog2);

  verify_eq_warn(MPI_REAL);
  verify_size(MPI_REAL,freal1,freal2);

  verify_eq(MPI_DOUBLE_PRECISION);
  verify_size(MPI_DOUBLE_PRECISION,fdub1,fdub2);

  verify_size(MPI_COMPLEX,fcomp1,fcomp2);

  if (err)
    abort();
}

int MPI_Init(int *argc, char **argv[])
{
  MPI_Comm my_comm_world;

  if (sizeof(MPI_Aint) < sizeof(void *))
    {
      fprintf(stderr, "mpi-serial: MPI_Init: "
                      "MPI_Aint is not large enough for void *\n");
      abort();
    }

  my_comm_world=mpi_comm_new();

  if (my_comm_world != MPI_COMM_WORLD)
    {
      fprintf(stderr,"MPI_Init: conflicting MPI_COMM_WORLD\n");
      abort();
    }

  // call this to have the fortran routine call back and save
  // values for f_MPI_STATUS_IGNORE and f_MPI_STATUSES_IGNORE
  FC_FUNC(mpi_get_fort_pointers,MPI_GET_FORT_POINTERS)();  // the () are important

  initialized=1;
  return(MPI_SUCCESS);
}


/*********/


FC_FUNC( mpi_finalize, MPI_FINALIZE )(int *ierror)
{
  *ierror=MPI_Finalize();
}


/*
 * MPI_Finalize()
 *
 * this library doesn't support re-initializing MPI, so
 * the finalize will just leave everythign as it is...
 *
 */


int MPI_Finalize(void)
{
  initialized=0;

  mpi_destroy_handles();

  return(MPI_SUCCESS);
}


/*********/


FC_FUNC( mpi_abort , MPI_ABORT )(int *comm, int *errorcode, int *ierror)
{
  *ierror=MPI_Abort( *comm, *errorcode);
}



int MPI_Abort(MPI_Comm comm, int errorcode)
{
  fprintf(stderr,"MPI_Abort: error code = %d\n",errorcode);
  exit(errorcode);
}


/*********/



FC_FUNC( mpi_error_string , MPI_ERROR_STRING)
                             (int *errorcode, char *string,
			      int *resultlen, int *ierror)
{
  *ierror=MPI_Error_string(*errorcode, string, resultlen);
}


int MPI_Error_string(int errorcode, char *string, int *resultlen)
{
  sprintf(string,"MPI Error: code %d\n",errorcode);
  *resultlen=strlen(string);

  return(MPI_SUCCESS);
}


/*********/


FC_FUNC( mpi_get_processor_name , MPI_GET_PROCESSOR_NAME )
                          (char *name, int *resultlen, int *ierror)
{
  *ierror=MPI_Get_processor_name(name,resultlen);
}


int MPI_Get_processor_name(char *name, int *resultlen)
{
  int ret;

  ret=gethostname(name,MPI_MAX_PROCESSOR_NAME);

  if (ret!=0)
    strncpy(name,"unknown host name",MPI_MAX_PROCESSOR_NAME);


  name[MPI_MAX_PROCESSOR_NAME-1]='\0';  /* make sure NULL terminated */
  *resultlen=strlen(name);

  return(MPI_SUCCESS);
}


/*********/


FC_FUNC( mpi_initialized , MPI_INITIALIZED )(int *flag, int *ierror)
{
  *ierror=MPI_Initialized(flag);
}


int MPI_Initialized(int *flag)
{
  *flag= initialized;

  return(MPI_SUCCESS);
}


/**********/


void FC_FUNC( mpi_get_library_version, MPI_GET_LIBRARY_VERSION) (char *version, int *resultlen, int *ierror)
{
  MPI_Get_library_version(version,resultlen);

  // Sanity check before the memset()
  if ( (*resultlen) > (MPI_MAX_LIBRARY_VERSION_STRING-1) )
    abort();

  memset(version+(*resultlen),' ',MPI_MAX_LIBRARY_VERSION_STRING-(*resultlen));

  *ierror=MPI_SUCCESS;
}



int MPI_Get_library_version(char *version, int *resultlen)
{

  strncpy(version,mpi_version_string,MPI_MAX_LIBRARY_VERSION_STRING);
  // Make sure it is null terminated
  version[MPI_MAX_LIBRARY_VERSION_STRING-1]='\0';
  *resultlen=strlen(version);

  return(MPI_SUCCESS);
}

/**********/
void FC_FUNC( mpi_get_version, MPI_GET_VERSION )(int *mpi_vers, int *mpi_subvers, int *ierror)
{
  MPI_Get_Version(mpi_vers, mpi_subvers);

  *ierror=MPI_SUCCESS;
}

int MPI_Get_Version(int *mpi_vers, int *mpi_subvers)
{
  *mpi_vers = 1;
  *mpi_subvers = 0;

  return (MPI_SUCCESS);
}

/**********/


void FC_FUNC( mpi_save_fort_pointers, MPI_SAVE_FORT_POINTERS ) (int *status, int *statuses, int *in_place)
{
  f_MPI_STATUS_IGNORE=status;
  f_MPI_STATUSES_IGNORE=statuses;
  f_MPI_IN_PLACE=in_place;
}



MPI_Status *mpi_c_status(int *status)
{
  if (status==f_MPI_STATUS_IGNORE)
    return(MPI_STATUS_IGNORE);

  return((MPI_Status *)status);
}


MPI_Status *mpi_c_statuses(int *statuses)
{
  if (statuses==f_MPI_STATUSES_IGNORE)
    return(MPI_STATUSES_IGNORE);

  return((MPI_Status *)statuses);
}


void *mpi_c_in_place(void *buffer)
{
  if (buffer==(void *)f_MPI_IN_PLACE)
    return(MPI_IN_PLACE);

  return(buffer);
}
