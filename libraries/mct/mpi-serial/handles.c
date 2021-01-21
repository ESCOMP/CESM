
/*
 * 5/20/2005 RML
 *
 */


#include "mpiP.h"
#include "type.h"
/*
 * handles.c
 *
 * handle management
 * based on code from mpich-1.x/ptrcvt.c
 * --> simplified and store item directly in the struct
 * rather than as pointer to separately allocated object.
 *
 * CAVEAT:
 * as in mpich-1, storage will grow as needed and will
 * remain at the high water mark since it is likely that
 * the user code will repeat the use.
 *
 */


typedef struct _Handleitem
{
  int handle;
  struct _Handleitem *next;

  union
  {
    void *anything;           /* At least size of void *  */
    Comm comm;
    Req req;
    Datatype* type;

  } data;


} Handleitem;


/*
 * These must be consistent with each other
 *
 */

#define BLOCK_ITEMS          (256)
#define HANDLE_TO_BLOCK(x)   ( (x) >> 8)
#define HANDLE_TO_INDEX(x)   ( (x) & 0xff )
#define HANDLE(block,index)  ( (block << 8) | (index) )


/*
 * The first block of handle items will be statically allocated.
 * Subsequent ones will be added if necessary.
 * blocks[0..nblocks-1] are allocated at any given time.
 *
 * Increase MAX_BLOCKS if you *really* need more active request
 * (Although probably something is wrong if you need more than 256k !!!)
 *
 */


#define MAX_BLOCKS (1024)

static Handleitem block0[BLOCK_ITEMS];     /* array of handleitems */
static Handleitem *(blocks[MAX_BLOCKS]);   /* array of pointers to blocks */
static int nblocks;


static int need_to_init=1;
static Handleitem *nextfree;


/************************************************************************/

void *mpi_malloc(int size)
{
  void *ret;

  ret=malloc(size);

  if (!ret)
    {
      fprintf(stderr,"mpi_malloc: failed to allocate %d bytes\n",size);
      abort();
    }

  return(ret);
}


void mpi_free(void *ptr)
{
  free(ptr);
}


/************************************************************************/


/*
 * initialize a block s.t. handles are set and
 * 0 -> 1 -> 2 ... -> (BLOCK_ITEMS-1) -> NULL
 *
 */

static Handleitem *init_block(int block, Handleitem *b)
{
  int i;

  for (i=0; i<BLOCK_ITEMS-1; i++)
    {
      b[i].handle= HANDLE(block,i);
      b[i].next = &b[i+1];
    }

  b[BLOCK_ITEMS-1].handle= HANDLE(block,BLOCK_ITEMS-1);
  b[BLOCK_ITEMS-1].next=0;

  return( &(b[0]) );
}




static void init_handles(void)
{
  int i;
  Handleitem *new;

  /*
   * item 0 will not be used  (handle 0 maps to NULL)
   *
   */

  new=init_block(0,block0);

  nextfree=new->next;             /* Skip over using item 0 */
  new->next=NULL;

  /*
   * initialize the array of blocks
   *
   */

  blocks[0]=block0;
  nblocks=1;

  for (i=1; i<MAX_BLOCKS; i++)
    blocks[i]=NULL;


  need_to_init=0;
}



void mpi_destroy_handles(void)
{
  int i;

  if (need_to_init)
    return;

  for (i=1; i<nblocks; i++)          /* blocks[0] is statically allocated */
    mpi_free(blocks[i]);

  need_to_init=1;
}


/************************************************************************/


void mpi_alloc_handle(int *handle, void **data)
{
  Handleitem *new;
  int i;

  if (need_to_init)
    init_handles();

  if (nextfree)
    {
      new= nextfree;
      nextfree= nextfree->next;
      new->next=NULL;

      *handle= new->handle;
      *data= &(new->data);

      return;
    }

  /* there is nothing free, so allocate a new block and add it
   * to blocks[]
   */

  if (nblocks==MAX_BLOCKS)
    {
      fprintf(stderr,"mpi_allocate_handle: max %d active handles exceeded\n",
	      MAX_BLOCKS*BLOCK_ITEMS);
      abort();
    }

  blocks[nblocks]= (Handleitem *)mpi_malloc(sizeof(Handleitem)* BLOCK_ITEMS);
  new=init_block(nblocks,blocks[nblocks]);

  nextfree= new->next;
  new->next=NULL;

  *handle= new->handle;
  *data= &(new->data);

  nblocks++;  /* DON'T FORGET THIS!!!! */

#ifdef HANDLE_INFO
  fflush(stdout);
  fprintf(stderr,"mpi_alloc_handle: allocation %d blocks (%d handles)\n",
	  nblocks,nblocks*BLOCK_ITEMS);
#endif

}




static void verify_handle(int handle, int block, int index)
{
  if (block>=nblocks || block<0 ||
      index>=BLOCK_ITEMS || index<0)
    {
      fprintf(stderr,"mpi_verify_handle: bad handle\n");
      abort();
    }

  if (blocks[block][index].handle != handle)
    {
      fprintf(stderr,"mpi_verify_handle: handle mismatch\n");
      abort();
    }
}

void *mpi_handle_to_ptr(int handle)
{
  int block;
  int index;

  if (need_to_init)
    init_handles();

  if (!handle)     /* Handle 0 -> NULL */
    return(NULL);

  block=HANDLE_TO_BLOCK(handle);
  index=HANDLE_TO_INDEX(handle);

#ifdef CHECKS
  verify_handle(handle,block,index);
#endif

  return( &(blocks[block][index].data) );
}



void mpi_free_handle(int handle)
{
  int block;
  int index;
  Handleitem *item;

  if (!handle)                         /* ignore null handle */
    return;

  if (need_to_init)
    {
      fprintf(stderr,"mpi_free_handle: handles not initialized\n");
      abort();
    }

  block=HANDLE_TO_BLOCK(handle);
  index=HANDLE_TO_INDEX(handle);

#ifdef CHECKS
  verify_handle(handle,block,index);
#endif

  item=&(blocks[block][index]);

#ifdef CHECKS
  if (item->next)
    {
      fprintf(stderr,"mpi_free_handle: handle still in use\n");
      abort();
    }
#endif


  /* just return it to the free list.
   * space is not reclaimed.
   */

  item->next=nextfree;
  nextfree=item;
}
