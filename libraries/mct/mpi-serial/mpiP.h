#ifndef _MPIP_H
#define _MPIP_H

/*
 * Private .h file for MPI
 */


#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "listops.h"
#include "mpi.h"

/* Autoconf Fortran name mangling
 *
 * config.h defines F77_FUNC and F77_FUNC_
 * Since we are generally using FC_FUNC, and
 * all of our functions will ONLY use F77_FUNC_
 * (with the underscore, define FC_FUNC as the
 * aforementioned.
 *
 * If config.h is not present, default to the old
 * approach.
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
/* config.h should define FC_FUNC */
#else

/*
 * Fortran name mangling
 *
 * the configure.ac specifies these
 *
 * cpp does not have the ability to change the case
 * of the argument, so the invocation of the macro
 * has to be give both e.g. FC_FUNC(hello,HELLO)
 * and maps to "hello_", "hello", and "HELLO" repectively.
 *
 * IMPORTANT NOTE:
 * In the case of FORTRAN_GNUF2C (e.g. g95), the rule is this:
 *    name does not contain an underscore -> append *one* underscore
 *    name contains an underscore -> append *two* underscore
 * Since all the mpi-serial names exported to fortran start with "mpi_",
 * we only support the latter.
 *
 * Note: FORTRANUNDERSCORE is needed by ccsm
 *
 */


#if   defined(FORTRAN_UNDERSCORE_) || defined(FORTRANUNDERSCORE)
#define FC_FUNC(lower,upper) lower##_
#elif defined(FORTRAN_GNUF2C)
#define FC_FUNC(lower,upper) lower##__
#elif defined(FORTRAN_SAME)
#define FC_FUNC(lower,upper) lower
#elif defined(FORTRAN_CAPS_)
#define FC_FUNC(lower,upper) upper
#else
#error "Unrecognized Fortran-mangle type"
/* set to something reasonable to avoid cascade of cc errors */
#define FC_FUNC(lower,upper) lower##_
#endif
#endif /* HAVE_CONFIG_H */

/*
 * MPI_GROUP_ONE must not conflict with MPI_GROUP_NULL or
 * MPI_GROUP_EMPTY
 */

#define MPI_GROUP_ONE  (1)


/****************************************************************************/


typedef struct
{
  pList sendlist;
  pList recvlist;

  int num;

} Comm;



typedef struct
{
  pListitem listitem;        /* to allow Req to be removed from list */

  int *buf;
  int source;
  int tag;
  int complete;

} Req;


/****************************************************************************/

/* copy functions */
extern int copy_data2(void * source, int src_count, MPI_Datatype src_type,
                      void * dest, int dest_count, MPI_Datatype dest_type);

extern void *mpi_malloc(int size);
extern void mpi_free(void *ptr);

extern MPI_Comm mpi_comm_new(void);

extern void mpi_destroy_handles(void);
extern void mpi_alloc_handle(int *handle, void **data);
extern void *mpi_handle_to_ptr(int handle);
extern void mpi_free_handle(int handle);

extern void FC_FUNC(mpi_get_fort_pointers,MPI_GET_FORT_POINTERS)(void);

extern MPI_Status *mpi_c_status(int *status);
extern MPI_Status *mpi_c_statuses(int *statuses);
extern void *mpi_c_in_place(void *buffer);


#endif /* _MPIP_H */
