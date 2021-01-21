/*
 *  (C) 2000 UNIVERSITY OF CHICAGO
 *      See COPYRIGHT in top-level directory.
 */



/*
 * Private data structures for the list
 *
 */


typedef struct _List
{
  pListitem head;
  pListitem tail;
  int count;
} List;


typedef struct _Listitem
{
  void *data;
  pListitem prev;
  pListitem next;

#ifdef CHECKS
  pList list;
#endif

} Listitem;

