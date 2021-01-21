#ifndef TYPE_H
#define TYPE_H

/* type.h */
/* defines interface and types used for mpi-serial user-defined datatypes */

#include "mpiP.h"

//for Fortran type sizes
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

//predefined type value used in typemap
typedef int Simpletype;

typedef struct
{
  long disp;
  Simpletype type;
} typepair;

typedef struct
{
  int count;
  long ub;
  long lb;
  int committed; //type has been committed
  int o_lb; //overridden lower/upper bound
  int o_ub; // "
  /* pairs[] is size 2 because of predefined types
   * such as MPI_2INT that have 2 typemap entries
   * upon initialization.
   */
  typepair pairs[2];
} Typestruct;

typedef Typestruct* Datatype;

//Simpletype constants
#define SIMPLE_CHAR         0
#define SIMPLE_SHORT        1
#define SIMPLE_INT          2
#define SIMPLE_LONG         3
#define SIMPLE_UCHAR        4
#define SIMPLE_USHORT       5
#define SIMPLE_UINT         6
#define SIMPLE_ULONG        7
#define SIMPLE_FLOAT        8
#define SIMPLE_DOUBLE       9
#define SIMPLE_LDOUBLE     10
#define SIMPLE_BYTE        11
#define SIMPLE_LOWER       12
#define SIMPLE_UPPER       13
#define SIMPLE_FINTEGER    14
#define SIMPLE_FREAL       15
#define SIMPLE_FDPRECISION 16
#define SIMPLE_FCOMPLEX    17
#define SIMPLE_FDCOMPLEX   18
#define SIMPLE_FLOGICAL    19
#define SIMPLE_FCHARACTER  20

#define SIMPLE_FINTEGER1   21
#define SIMPLE_FINTEGER2   22
#define SIMPLE_FINTEGER4   23
#define SIMPLE_FINTEGER8   24
#define SIMPLE_FINTEGER16  25

#define SIMPLE_FREAL4      26
#define SIMPLE_FREAL8      27
#define SIMPLE_FREAL16     28

#define SIMPLE_FCOMPLEX8   29
#define SIMPLE_FCOMPLEX16  30
#define SIMPLE_FCOMPLEX32  31

#define SIMPLE_LONGLONG    32
#define SIMPLE_ULONGLONG   33

#define SIMPLE_OFFSET      34

//internal type functions
int Simpletype_length(Simpletype s);

//testing only
int print_typemap(MPI_Datatype in);


/*
 * Fortran type sizes
 *
 * If config.h is used and the user has specified
 * sizes using --enable-fort-real and --enable-fort-double
 * args, they will be used here.  Otherwise just take a shot
 * in the dark?
 *
 */

#ifdef CONFIG_FORT_REAL
#define FSIZE_REAL CONFIG_FORT_REAL
#else
#define FSIZE_REAL 4 //guess something reasonable
#endif

#ifdef CONFIG_FORT_DOUBLE
#define FSIZE_DPRECISION CONFIG_FORT_DOUBLE
#else
#define FSIZE_DPRECISION 8
#endif

#define FSIZE_INTEGER 4
#define FSIZE_COMPLEX 2*FSIZE_REAL
#define FSIZE_DCOMPLEX 2*FSIZE_DPRECISION
#define FSIZE_LOGICAL 4
#define FSIZE_CHARACTER 1

const extern Datatype simpletypes[];
Datatype* mpi_handle_to_datatype(int handle);

extern int Unpack(void * inbuf, int insize, int * position, void *outbuf,
                  int outcount, Datatype type, Comm* comm);
extern int Pack(void *inbuf, int incount, Datatype type,
              void *outbuf, int outsize, int *position, Comm * comm);
#endif /* TYPE_H */
