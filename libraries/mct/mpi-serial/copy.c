/*
 * copy.c
 *
 * memcpy "wrapper" to copy MPI Datatypes
 *
 */

#include "mpiP.h"
#include "type.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>

//For type matching
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

/*
 * rml: this prototype should be in mpiP.h, but mpiP.h does not currently
 * include type.h so it can't just be added right now.  Come back and
 * fix this issue later...
 */

extern int Pcopy_data2(void *source, int src_count, Datatype src_type,
		       void *dest, int dest_count, Datatype dest_type);


int copy_data2(void *source, int src_count, MPI_Datatype src_type,
               void *dest, int dest_count, MPI_Datatype dest_type)
{
  Datatype src_ptr = *(Datatype*) mpi_handle_to_datatype(src_type);
  Datatype dest_ptr = *(Datatype*) mpi_handle_to_datatype(dest_type);

  return Pcopy_data2(source, src_count, src_ptr, dest, dest_count, dest_ptr);
}




int Pcopy_data2(void *source, int src_count, Datatype src_type,
                void *dest, int dest_count, Datatype dest_type)
{
  int i;
  int soffset, doffset;
  MPI_Aint src_extent, dest_extent;

  //commit checking here, since if any datatype is used in this function
  // it is considered "communication".  Should it be somewhere else?

  if (!(src_type->committed && dest_type->committed))
  {
    fprintf(stderr, "Type not committed\n");
    exit(-1);
  }

  // A receive of less elements than sent
  // is valid, but the reverse is a violation

  if (src_type->count * src_count < dest_type->count * dest_count)
  {
    printf("copy_data: Trying to over-receive\n");
    exit(1);
  }

  Type_extent(src_type, &src_extent);
  Type_extent(dest_type, &dest_extent);

  for (i = 0; i < dest_count * dest_type->count; i++)
  {

#ifdef TYPE_CHECKING
    if ( src_type->pairs[i % src_type->count].type !=
         dest_type->pairs[i % dest_type->count].type)
    {
      printf("copy_data: Types don't match.\n");
      exit(1);
    }
#endif

    soffset = src_type->pairs[i % src_type->count].disp + ((i / src_type->count) * src_extent);
    doffset = dest_type->pairs[i % dest_type->count].disp + ((i / dest_type->count) * dest_extent);

    memcpy(dest+doffset, source+soffset, Simpletype_length(dest_type->pairs[i % dest_type->count].type));
  }
}




