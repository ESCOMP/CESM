/*
** $Id: print_memusage.c,v 1.13 2010-11-09 19:08:54 rosinski Exp $
**
** Author: Jim Rosinski
**
** print_memusage:
**
**   Prints info about memory usage of this process by calling get_memusage.
**
**   Return value: 0  = success
**                 -1 = failure
*/

#include "gptl.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#ifdef __bgq__
#include <spi/include/kernel/memory.h>
#endif

static int nearest_powerof2 (const int);
static int convert_to_mb = 1;   /* true */

int GPTLprint_memusage (const char *str)
{
#ifdef __bgq__
  uint64_t shared, persist, heapavail, stackavail, stack, heap, guard, mmap;

  Kernel_GetMemorySize(KERNEL_MEMSIZE_HEAP, &heap);
  Kernel_GetMemorySize(KERNEL_MEMSIZE_SHARED, &shared);
  Kernel_GetMemorySize(KERNEL_MEMSIZE_STACK, &stack);
  Kernel_GetMemorySize(KERNEL_MEMSIZE_PERSIST, &persist);
  Kernel_GetMemorySize(KERNEL_MEMSIZE_HEAPAVAIL, &heapavail);
  Kernel_GetMemorySize(KERNEL_MEMSIZE_STACKAVAIL, &stackavail);
  Kernel_GetMemorySize(KERNEL_MEMSIZE_GUARD, &guard);
  Kernel_GetMemorySize(KERNEL_MEMSIZE_MMAP, &mmap);

  printf("%s Memory(MB): heap-alloc: %.2f, heap-avail: %.2f,"
         "stack-alloc: %.2f, stack-avail: %.2f,"
         "shared: %.2f, persist: %.2f, guard: %.2f, mmap: %.2f\n", str,
         (double)heap/(1024*1024),   (double)heapavail/(1024*1024),
         (double)stack/(1024*1024),  (double)stackavail/(1024*1024),
         (double)shared/(1024*1024), (double)persist/(1024*1024),
         (double)guard/(1024*1024),  (double)mmap/(1024*1024));
  return 0;

#else
  int size, size2;                        /* process size (returned from OS) */
  int rss, rss2;                          /* resident set size (returned from OS) */
  int share, share2;                      /* shared data segment size (returned from OS) */
  int text, text2;                        /* text segment size (returned from OS) */
  int datastack, datastack2;              /* data/stack size (returned from OS) */
  static int kbytesperblock = -1;         /* convert to Kbytes (init to invalid) */
  static const int nbytes =1024*1024*1024;/* allocate 1 GB */
  void *space;                            /* allocated space */

  setbuf(stdout, NULL); // don't buffer stdout, flush
  if (GPTLget_memusage (&size, &rss, &share, &text, &datastack) < 0) {
    printf ("GPTLprint_memusage: GPTLget_memusage failed.\n");
    return -1;
  }

#if (defined HAVE_SLASHPROC || defined __APPLE__)
  if (kbytesperblock == -1) {
    kbytesperblock = sysconf(_SC_PAGESIZE) / 1024;
    printf ("GPTLprint_memusage: Using Kbytesperpage=%d\n", kbytesperblock);
  }

  /*
  ** Determine size in bytes of memory usage info presented by the OS. Method: allocate a
  ** known amount of memory and see how much bigger the process becomes.
  */

  if (convert_to_mb && kbytesperblock == -1 && (space = malloc (nbytes))) {
    memset (space, 0, nbytes);  /* ensure the space is really allocated */
    if (GPTLget_memusage (&size2, &rss2, &share2, &text2, &datastack2) == 0) {
      if (size2 > size) {
	/*
	** Estimate bytes per block, then refine to nearest power of 2.
	** The assumption is that the OS presents memory usage info in
	** units that are a power of 2.
	*/
        kbytesperblock = (int) ((nbytes / (double) (size2 - size)) + 0.5);
        kbytesperblock = nearest_powerof2 (kbytesperblock);
        printf ("GPTLprint_memusage: Using Kbytesperblock=%d\n", kbytesperblock);
      } else {
        printf ("GPTLprint_memusage: highwater did not increase.\n");
      }
    } else {
      printf ("GPTLprint_memusage: call GPTLget_memusage failed.\n");
    }
    free (space);
  }

  if (kbytesperblock > 0) {
    printf ("%s sysmem size=%.1f MB rss=%.1f MB share=%.1f MB text=%.1f MB datastack=%.1f MB\n",
            str, size/1024., rss/1024., share/1024., text/1024., datastack/1024.);
  } else {
    printf ("%s sysmem size=%d rss=%d share=%d text=%d datastack=%d\n",
            str, size, rss, share, text, datastack);
  }

#else

  /*
  ** Use max rss as returned by getrusage. If someone knows how to
  ** get the process size under AIX please tell me.
  */

  if (convert_to_mb)
    printf ("%s max rss=%.1f MB\n", str, rss*1024.);
  else
    printf ("%s max rss=%d\n", str, rss);
#endif

  return 0;
#endif
}

/*
** nearest_powerof2:
**   Determine nearest integer which is a power of 2.
**   Note: algorithm can't use anything that requires -lm because this is a library,
**   and we don't want to burden the user with having to add extra libraries to the
**   link line.
**
** Input arguments:
**   val: input integer
**
** Return value: nearest integer to val which is a power of 2
*/

static int nearest_powerof2 (const int val)
{
  int lower;  /* power of 2 which is just less than val */
  int higher; /* power of 2 which is just more than val */
  int delta1; /* difference between val and lower */
  int delta2; /* difference between val and higher */

  if (val < 2)
    return 0;

  for (higher = 1; higher < val; higher *= 2)
    lower = higher;

  delta1 = val - lower;
  delta2 = higher - val;

  if (delta1 < delta2)
    return lower;
  else
    return higher;
}
