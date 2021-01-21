/*
 * JCY
 * 07/2007
 * Derived Datatype functions for mpi-serial
 */

#include "type.h"
#include "mpiP.h"
#include <stdlib.h>
#include <stdio.h>
#include <limits.h>

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

/*
 * NOTES: All MPI_ prefixed (public) functions operate
 * using the integer handle for a datatype.  Most of these
 * functions are wrapper functions for a different function,
 * _not_ prefixed with MPI_.  These functions translate the
 * handle to a pointer and call the non-MPI_ func.
 *
 * Fortran bindings use FC_FUNC, as defined in mpiP.h.
 */


/*
 * Wrapper for mpi_handle_to_ptr in handles.c
 * specific for datatype handles, which may be
 * predefined negative handles
 */
Datatype* mpi_handle_to_datatype(int handle)
{
  if (handle < 0)
    return (Datatype*) &simpletypes[-1-handle];
  else
    return (Datatype*) mpi_handle_to_ptr(handle);
}

/*
 * Calculate the epsilon value of typemap
 * using the largest element in the typemap
 */

int calc_padding(Datatype datatype)
{
  long size_max = INT_MIN;
  long type_len;
  int i;
  //find the largest datatype size.  The epsilon padding is (probably) based on this.

  for (i = 0; i < datatype->count; i++)
  {
    type_len = Simpletype_length(datatype->pairs[i].type);
    size_max = type_len > size_max ? type_len : size_max;
  }

  return size_max;
}

/* Retrieve size of any simple type
 * C sizes use sizeof the literal type
 * they represent.  Fortran types are those
 * as defined in type.h
 */

int Simpletype_length(Simpletype t)
{
  switch(t)
  {
    case SIMPLE_CHAR:
      return sizeof(char); break;
    case SIMPLE_SHORT:
      return sizeof(short); break;
    case SIMPLE_INT:
      return sizeof(int); break;
    case SIMPLE_LONG:
      return sizeof(long); break;
    case SIMPLE_UCHAR:
      return sizeof(unsigned char); break;
    case SIMPLE_USHORT:
      return sizeof(unsigned short); break;
    case SIMPLE_UINT:
      return sizeof(unsigned int); break;
    case SIMPLE_ULONG:
      return sizeof(unsigned long); break;
    case SIMPLE_FLOAT:
      return sizeof(float); break;
    case SIMPLE_DOUBLE:
      return sizeof(double); break;
    case SIMPLE_LDOUBLE:
      return sizeof(long double); break;
    case SIMPLE_BYTE:
      return sizeof(char); break;
    case SIMPLE_FINTEGER:
      return FSIZE_INTEGER; break;
    case SIMPLE_FREAL:
      return FSIZE_REAL; break;
    case SIMPLE_FDPRECISION:
      return FSIZE_DPRECISION; break;
    case SIMPLE_FCOMPLEX:
      return FSIZE_COMPLEX; break;
    case SIMPLE_FDCOMPLEX:
      return FSIZE_DCOMPLEX; break;
    case SIMPLE_FLOGICAL:
      return FSIZE_LOGICAL; break;
    case SIMPLE_FCHARACTER:
      return FSIZE_CHARACTER; break;
    case SIMPLE_FINTEGER1:
      return 1; break;
    case SIMPLE_FINTEGER2:
      return 2; break;
    case SIMPLE_FINTEGER4:
      return 4; break;
    case SIMPLE_FINTEGER8:
      return 8; break;
    case SIMPLE_FREAL4:
      return 4; break;
    case SIMPLE_FREAL8:
      return 8; break;
    case SIMPLE_FREAL16:
      return 16; break;
    case SIMPLE_FCOMPLEX8:
      return 8; break;
    case SIMPLE_FCOMPLEX16:
      return 16; break;
    case SIMPLE_FCOMPLEX32:
      return 32; break;
    case SIMPLE_LONGLONG:
      return sizeof(long long); break;
    case SIMPLE_ULONGLONG:
      return sizeof(unsigned long long); break;
    case SIMPLE_OFFSET:
      return sizeof(MPI_Offset); break;

    default:
      printf("Invalid simple type\n");
      exit(1);
  }
}

/*
 * calculates the lower bound of a datatype using typemap
 * (This gives no regard to MPI_LB, but rather uses only displacements)
 */
long calc_lb(Datatype type)
{
  int i;
  int min_disp = INT_MAX;
  typepair * tp;

  for(i =0; i < type->count; i++)
  {
    tp =  type->pairs+i;
    min_disp = tp->disp < min_disp
                ? tp->disp
                : min_disp;
  }
  return min_disp;
}

/*
 * Calculate upper bound using typemap
 * (Gives no regard to MPI_UB, just calculates
 * highest displacement+size of its respective data type)
 */
long calc_ub(Datatype type)
{
  int i;
  long max_disp = INT_MIN;
  typepair * tp;

  for(i = 0; i < type->count; i++)
  {
    tp = type->pairs+i;
    max_disp = tp->disp + Simpletype_length(tp->type) > max_disp
                ? tp->disp + Simpletype_length(tp->type)
                : max_disp;
  }

  return max_disp;
}


/*******************************************************/
/* MPI_Type_struct is the most general type constructor that
 * does the common work other constructors.
 * All other type constructors call this function.
 */

FC_FUNC( mpi_type_struct, MPI_TYPE_STRUCT )
         (int * count,       int * blocklens, long * displacements,
          int *oldtypes_ptr, int *newtype,    int *ierror)
{
  *ierror=MPI_Type_struct(*count, blocklens, displacements,
                                    oldtypes_ptr, newtype);
}

/* Public function, wrapper for Type_struct that translates handle to
 * pointer (see NOTES at top of file)
 */
int MPI_Type_struct(int count, int * blocklens, MPI_Aint * displacements,
                    MPI_Datatype *oldtypes,     MPI_Datatype *newtype)
{
  int i;
  Datatype oldtypes_ptr[count];
  Datatype * newtype_ptr;

  for (i = 0; i < count; i++)
  {
    oldtypes_ptr[i] = *(Datatype*) mpi_handle_to_datatype(oldtypes[i]);
  }

  mpi_alloc_handle(newtype, (void**) &newtype_ptr);

  return Type_struct(count, blocklens, displacements,
                          oldtypes_ptr, newtype_ptr);
}

int Type_struct(int count, int * blocklens, MPI_Aint * displacements,
                Datatype *oldtypes_ptr,     Datatype *newtype)
{
  int i, j, k;
  Datatype temp, temp2;
  int newcount;
  char override_lower = 0, //whether to override
       override_upper = 0;
  MPI_Aint  new_lb = LONG_MAX,
            new_ub = LONG_MIN,
       clb, cub;            //calculated lb and ub
  int simpletype_count = 0; //total additional blocks for malloc
  MPI_Aint tmp_offset;      //for contiguous blocks of type
  MPI_Aint extent;

  // find the total number of elements in the typemap we need to add.
  for (i = 0; i < count; i++)
  {
    //check for MPI_UB or MPI_LB.  These types are special
    // cases and will be skipped over

    temp2 = oldtypes_ptr[i];
    if (temp2->pairs[0].type == SIMPLE_LOWER)
    {
      //found MPI_LB.  This is a candidate for the actual lb
      if (new_lb > displacements[i])
        new_lb = displacements[i];
      override_lower = 1;
    }
    else if (temp2->pairs[0].type == SIMPLE_UPPER)
    {
      //same as above, but ub
      if (new_ub < displacements[i])
	new_ub = displacements[i];
      override_upper = 1;
    }
    else
    {
      //this is not MPI_LB or MPI_UB
      //However it may still have overriding bounds
      //Test for these and add its size to the typemap.

      if (temp2->o_lb)
        // this type's lb has been overridden.
        // ONLY an overriding lb can be the actual lb now.
        override_lower = 1;
      if (temp2->o_ub)
        //same as above, but ub
        override_upper = 1;

      simpletype_count += blocklens[i] * oldtypes_ptr[i]->count;
    }
  }
  temp = malloc(sizeof(Typestruct) +
               ((simpletype_count-1) * sizeof(typepair)));

  temp->count = simpletype_count;

  i = 0;         //old type's index
  newcount = 0;  //new type's index

  while (i < count)
  {
    tmp_offset = 0;

    temp2 = oldtypes_ptr[i];

    //test for previous MPI_LB or MPI_UB in one of the comprising types.
    //If found, skip over.
    if (!((temp2->pairs[0].type == SIMPLE_LOWER) ||
          (temp2->pairs[0].type == SIMPLE_UPPER)))
    {
      for (j = 0; j < blocklens[i]; j++)
      {
        //Copy the old type's typemap and merge into the new type
        //by a "flattening" process
        Type_extent((Datatype) oldtypes_ptr[i], &extent);

        tmp_offset = j * extent;

        if (temp2->o_lb && temp2->lb+displacements[i]+tmp_offset < new_lb)
          new_lb = temp2->lb+displacements[i]+tmp_offset;
        if (temp2->o_ub && temp2->ub+displacements[i]+tmp_offset > new_ub)
        {
          new_ub = temp2->ub+displacements[i]+tmp_offset;
        }

        for (k = 0;  k < oldtypes_ptr[i]->count; k++)
        {
          Copy_type( (typepair*) oldtypes_ptr[i]->pairs+k,
                     (typepair*) (temp->pairs+newcount));


          ((typepair*) temp->pairs+(newcount))->disp +=
                       displacements[i] + tmp_offset;
          newcount++;
        }
      }
    }
    i++;
  }
  //type is NOT committed
  temp->committed = 0;

  //assign upper and lower bounds here
  if (override_lower)
  {
    //use lowest previous overridden lower bound
    temp->o_lb = 1;
    temp->lb = new_lb;
  }
  else
  {
    //use calculation
    temp->lb = calc_lb(temp);
  }

  if (override_upper)
  {
    temp->o_ub = 1;
    temp->ub = new_ub;
  }
  else
  {
    temp->ub = calc_ub(temp);
  }

  *newtype = temp;
  temp = MPI_DATATYPE_NULL;

  return MPI_SUCCESS;
}

/*******************************************************/
/*  MPI_Type_contiguous.  Create count copies of a type.
 *  this creates arrays of the singleton arguments and use them to call
 *  MPI_Type_struct()
 */

FC_FUNC( mpi_type_contiguous, MPI_TYPE_CONTIGUOUS )
         (int *count, int *oldtype, int * newtype, int * ierr)
{
  *ierr = MPI_Type_contiguous(*count, *oldtype, newtype);
}

int MPI_Type_contiguous(int count, MPI_Datatype old, MPI_Datatype * new)
{
  int ret;
  Datatype old_ptr = *(Datatype*) mpi_handle_to_datatype(old);
  Datatype * new_ptr;

  mpi_alloc_handle(new, (void**) &new_ptr);

  return Type_contiguous(count, old_ptr, new_ptr);
}

int Type_contiguous(int count, Datatype oldtype, Datatype *newtype)
{
  int i;
  int blocklengths[count];
  Datatype oldtypes[count];
  MPI_Aint offsets[count];
  MPI_Aint extent;

  //each copy is strided by the extent of the datatype.
  // Calculate that here.
  Type_extent(oldtype, &extent);
  for (i = 0; i < count; i++)
  {
    blocklengths[i] = 1;
    offsets[i] = extent * i;
    oldtypes[i] = oldtype;
  }
  return Type_struct(count, blocklengths, offsets, oldtypes, newtype);
}

/*************************/
/* Type_vector
 */

FC_FUNC( mpi_type_vector, MPI_TYPE_VECTOR )
         (int * count, int * blocklen, int * stride,
          int * oldtype, int * newtype, int * ierr)
{
  *ierr = MPI_Type_vector(*count, *blocklen, *stride, *oldtype, newtype);
}

int MPI_Type_vector(int count, int blocklen, int stride,
                    MPI_Datatype oldtype, MPI_Datatype * newtype)
{
  Datatype old_ptr = *(Datatype*) mpi_handle_to_datatype(oldtype);
  Datatype * new_ptr;

  mpi_alloc_handle(newtype, (void**) &new_ptr);

  return Type_vector(count, blocklen, stride, old_ptr, new_ptr);
}


int Type_vector(int count, int blocklen, int stride,
                Datatype oldtype, Datatype *newtype)
{
  MPI_Aint extent;
  MPI_Aint bstride;

  Type_extent(oldtype, &extent);
  bstride = stride * extent;

  return Type_hvector(count, blocklen, bstride, oldtype, newtype);
}

/*******************************************************/

FC_FUNC( mpi_type_hvector, MPI_TYPE_HVECTOR )
         (int * count,   long * blocklen, long * stride,
          int * oldtype, int * newtype,   int * ierr)
{
  *ierr = MPI_Type_hvector(*count, *blocklen, *stride, *oldtype, newtype);
}

int MPI_Type_hvector(int count, int blocklen, MPI_Aint stride,
                     MPI_Datatype oldtype, MPI_Datatype * newtype)
{
  Datatype old_ptr = *(Datatype*) mpi_handle_to_datatype(oldtype);
  Datatype * new_ptr;

  mpi_alloc_handle(newtype, (void**) &new_ptr);
  return Type_hvector(count, blocklen, stride, old_ptr, new_ptr);
}

FC_FUNC( mpi_type_create_hvector, MPI_TYPE_CREATE_HVECTOR )
         (int * count,   long * blocklen, long * stride,
          int * oldtype, int * newtype,   int * ierr)
{
  *ierr = MPI_Type_create_hvector(*count, *blocklen, *stride, *oldtype, newtype);
}

int MPI_Type_create_hvector(int count, int blocklen, MPI_Aint stride,
                     MPI_Datatype oldtype, MPI_Datatype * newtype)
{
  Datatype old_ptr = *(Datatype*) mpi_handle_to_datatype(oldtype);
  Datatype * new_ptr;

  mpi_alloc_handle(newtype, (void**) &new_ptr);
  return Type_hvector(count, blocklen, stride, old_ptr, new_ptr);
}


int Type_hvector(int count, int blocklen, MPI_Aint stride,
                      Datatype oldtype, Datatype *newtype)
{
  int i;
  int blocklengths[count];
  Datatype oldtypes[count];
  MPI_Aint offsets[count];
  MPI_Aint extent;

  Type_extent(oldtype, &extent);
  for (i = 0; i < count; i++)
  {
    blocklengths[i] = blocklen;
    offsets[i] = stride * i;
    oldtypes[i] = oldtype;
  }

  return Type_struct(count, blocklengths, offsets, oldtypes, newtype);
}

/*******************************************************/

FC_FUNC( mpi_type_indexed, MPI_TYPE_INDEXED )
         (int * count,   int * blocklens, int * displacements,
          int * oldtype, int * newtype,   int * ierr)
{
  *ierr = MPI_Type_indexed(*count, blocklens, displacements, *oldtype, newtype);
}


int MPI_Type_indexed(int count, int *blocklens, int *displacements,
                     MPI_Datatype oldtype, MPI_Datatype * newtype)
{
  Datatype old_ptr = *(Datatype*) mpi_handle_to_datatype(oldtype);
  Datatype * new_ptr;

  mpi_alloc_handle(newtype, (void**) &new_ptr);
  return Type_indexed(count, blocklens, displacements, old_ptr, new_ptr);
}

int Type_indexed(int count, int *blocklens, int *displacements,
                 Datatype oldtype, Datatype *newtype)
{
  int i;
  MPI_Aint extent;
  MPI_Aint bdisps[count];

  for (i = 0; i < count; i++)
  {
    Type_extent(oldtype, &extent);
    bdisps[i] = displacements[i] * extent;
  }

  return Type_hindexed(count, blocklens, bdisps, oldtype, newtype);
}

/*******************************************************/

FC_FUNC( mpi_type_create_indexed_block, MPI_TYPE_CREATE_INDEXED_BLOCK )
         (int * count,   int * blocklen, int * displacements,
          int * oldtype, int * newtype,  int * ierr)
{
  *ierr = MPI_Type_create_indexed_block(*count, *blocklen, displacements,
					*oldtype, newtype);
}

int MPI_Type_create_indexed_block(int count, int blocklen, int *displacements,
				  MPI_Datatype oldtype, MPI_Datatype * newtype)
{
  int ret;
  Datatype old_ptr = *(Datatype*) mpi_handle_to_datatype(oldtype);
  Datatype * new_ptr;

  mpi_alloc_handle(newtype, (void**) &new_ptr);
  return Type_create_indexed_block(count, blocklen, displacements, old_ptr, new_ptr);
}

int Type_create_indexed_block(int count, int blocklen, int *displacements,
			      Datatype oldtype, Datatype *newtype)
{
  int i;
  int blocklens[count];

  for (i = 0; i < count; i++)
    blocklens[i] = blocklen;

  return Type_indexed(count, blocklens, displacements, oldtype, newtype);
}

/*******************************************************/

FC_FUNC( mpi_type_hindexed, MPI_TYPE_HINDEXED )
         (int * count,   int * blocklens, MPI_Aint * displacements,
          int * oldtype, int * newtype,   int * ierr)
{
  *ierr = MPI_Type_hindexed(*count, blocklens, displacements,
                            *oldtype, newtype);
}

int MPI_Type_hindexed(int count, int *blocklens, MPI_Aint * disps,
                      MPI_Datatype oldtype, MPI_Datatype * newtype)
{
  Datatype old_ptr = *(Datatype*) mpi_handle_to_datatype(oldtype);
  Datatype * new_ptr;

  mpi_alloc_handle(newtype, (void**) &new_ptr);
  return Type_hindexed(count, blocklens, disps, old_ptr, new_ptr);
}

int Type_hindexed(int count, int *blocklens, MPI_Aint *displacements,
                  Datatype oldtype, Datatype *newtype)
{
  int i;
  Datatype oldtypes[count];

  for (i = 0; i < count; i++)
  {
    oldtypes[i] = oldtype;
  }

  return Type_struct(count, blocklens, displacements, oldtypes, newtype);
}


/*******************************************************/

int Type_dup(Datatype oldtype, Datatype *newtype)
{
  int i;
  //create a deep copy of given Datatype
  newtype = malloc(sizeof(oldtype));
  (*newtype)->committed = oldtype->committed;
  (*newtype)->lb = oldtype->lb;
  (*newtype)->ub = oldtype->ub;
  (*newtype)->o_lb = oldtype->o_lb;
  (*newtype)->o_ub = oldtype->o_ub;

  for (i = 0; i < oldtype->count; i++)
  {
    Copy_type((typepair*) oldtype->pairs + i,
              (typepair*) (*newtype)->pairs + i );
  }
}

/* copy_type: Creates a deep copy of source typepair into dest
 */
int Copy_type(typepair *source, typepair *dest)
{
  dest->type = source->type;
  dest->disp = source->disp;
}

/* MPI_Type_size:  Returns the sum of the lengths of each simple
 * type that makes up the data type argument
 */
FC_FUNC( mpi_type_size, MPI_TYPE_SIZE )(int * type, int * size, int * ierr)
{
  *ierr=MPI_Type_size(*type, size);
}

int MPI_Type_size(MPI_Datatype type, int * size)
{
  Datatype type_ptr = *(Datatype*) mpi_handle_to_datatype(type);
  return Type_size(type_ptr, size);
}

int Type_size(Datatype type, int * size)
{
  int i;
  *size = 0;
  for (i=0; i < type->count; i++)
    *size += Simpletype_length(type->pairs[i].type);


  return MPI_SUCCESS;
}
/* MPI_Type_lb: Returns the lower bound (which may be overridden
 * or calculated)
 */
FC_FUNC( mpi_type_lb, MPI_TYPE_LB )(int * type, long * lb, int * ierr)
{
  *ierr = MPI_Type_lb(*type, lb);
}

int MPI_Type_lb(MPI_Datatype type, MPI_Aint * lb)
{
  Datatype type_ptr = *(Datatype*) mpi_handle_to_datatype(type);

  return Type_lb(type_ptr, lb);
}

int Type_lb(Datatype type, MPI_Aint * lb)
{
  *lb = type->lb;
}

/* MPI_Type_ub: Return upper bound (which may be overridden
 * or calculated
 */
FC_FUNC( mpi_type_ub, MPI_TYPE_UB )(int * type, long * ub, int * ierr)
{
  *ierr = MPI_Type_ub(*type, ub);
}

int MPI_Type_ub(MPI_Datatype type, MPI_Aint * ub)
{
  Datatype type_ptr = *(Datatype*) mpi_handle_to_datatype(type);

  return Type_ub(type_ptr, ub);
}

int Type_ub(Datatype type, MPI_Aint * ub)
{
  *ub = type->ub;
}

/* MPI_Get_address
 * MPI_Address
 * Return address of an object
 */
FC_FUNC( mpi_get_address, MPI_ADDRESS )(void * loc, long * address, int * ierr)
{
  *ierr = FGet_address(loc, address);
}

FC_FUNC( mpi_address, MPI_ADDRESS )(void * loc, long * address, int * ierr)
{
  *address = (long) loc;
  *ierr = FGet_address(loc, address);
}

int FGet_address(void * loc, long * address, int * ierr)
{
  *address = (long) loc;
  return MPI_SUCCESS;
}

int MPI_Address(void * loc, MPI_Aint * address)
{
  return MPI_Get_address(loc, address);
}

int MPI_Get_address(void * loc, MPI_Aint * address)
{
  *address = (MPI_Aint) loc;
  return MPI_SUCCESS;
}

/* MPI_Type_extent: return ub-lb, plus padding
 */
FC_FUNC( mpi_type_extent, MPI_TYPE_EXTENT)(int * type, long * extent, int * ierr)
{
  *ierr = MPI_Type_extent(*type, extent);
}

int MPI_Type_extent(MPI_Datatype type, MPI_Aint * extent)
{
  Datatype type_ptr = *(Datatype*) mpi_handle_to_datatype(type);

  return Type_extent(type_ptr, extent);
}

int Type_extent(Datatype datatype, MPI_Aint * extent)
{

  if (!(datatype->o_lb || datatype->o_ub))
  {
    int epsilon = calc_padding(datatype);
    //current epsilon value is based off of largest datatype size
    int mod = (datatype->ub - datatype->lb) % epsilon;
    if (mod == 0)
      epsilon = 0;
    else
      epsilon = epsilon - mod;
    *extent = (datatype->ub - datatype->lb) + epsilon;
  }
  else
  {
    *extent = datatype->ub - datatype->lb;
  }

  return MPI_SUCCESS;
}

/* True_extent returns an extent based only on
 * calculated upper and lower bound, regardless of any
 * override using MPI_LB or MPI_UB
 */
int Type_get_true_extent(Datatype type, MPI_Aint * extent)
{
  long epsilon = calc_padding(type);
  long ub = calc_ub(type);
  long lb = calc_lb(type);
  //current epsilon value is based off of largest datatype size
  long mod = (ub - lb) % epsilon;
  if (mod == 0)
    epsilon = 0;
  else
    epsilon = epsilon - mod;
  *extent = (ub - lb) + epsilon;

  return MPI_SUCCESS;
}

/***********************/

FC_FUNC( mpi_type_commit, MPI_TYPE_COMMIT )(int * datatype, int * ierr)
{
  *ierr = MPI_Type_commit(datatype);
}

int MPI_Type_commit(MPI_Datatype * datatype)
{
  Datatype type_ptr = *(Datatype*) mpi_handle_to_datatype(*datatype);
  (type_ptr)->committed = 1;

  return MPI_SUCCESS;
}

/**********************/
FC_FUNC( mpi_type_free, MPI_TYPE_FREE )(int * datatype, int * ierr)
{
  *ierr = MPI_Type_free(datatype);
}

int MPI_Type_free(MPI_Datatype * datatype)
{
  Datatype type_ptr = *(Datatype*) mpi_handle_to_datatype(*datatype);
  free(type_ptr);
  type_ptr = MPI_DATATYPE_NULL;

  mpi_free_handle(*datatype);

  return MPI_SUCCESS;
}

/* Print_typemap is used in test programs only when
 * --enable-test-internal is enabled in configure.
 */

#ifdef TEST_INTERNAL
FC_FUNC( print_typemap, PRINT_TYPEMAP )(int * type, int * ierr)
{
  *ierr = print_typemap(*type);
}

int print_typemap(MPI_Datatype type)
{
  Datatype type_ptr = *(Datatype*) mpi_handle_to_datatype(type);

  return Pprint_typemap(type_ptr);
}

int Pprint_typemap(Datatype type)
{
  int i;
  MPI_Aint extent;
  Type_extent(type, &extent);

  printf("Type with %d type pairs.\n>> lb is %d\n>> ub is %d\n>>"
          "Extent is %d\n>>Epsilon based on %d\nTypemap: \n{",
          type->count, type->lb, type->ub, extent, calc_padding(type));

  for (i = 0; i < type->count; i++)
  {
    printf("(t%d:%d, o%d)", type->pairs[i].type,
           Simpletype_length(type->pairs[i].type),
           type->pairs[i].disp);

    if (i != type->count-1)
      printf(", ");
  }
  printf("}\n");

  return MPI_SUCCESS;
}
#endif //TEST_INTERNAL

