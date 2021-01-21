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

static int nearest_powerof2 (const int);
static int convert_to_mb = 1;   /* true */

int GPTLprint_memusage (const char *str)
{
  int size, size2;                        /* process size (returned from OS) */
  int rss, rss2;                          /* resident set size (returned from OS) */
  int share, share2;                      /* shared data segment size (returned from OS) */
  int text, text2;                        /* text segment size (returned from OS) */
  int datastack, datastack2;              /* data/stack size (returned from OS) */
  static int bytesperblock = -1;          /* convert to bytes (init to invalid) */
  static const int nbytes = 1024*1024*10; /* allocate 10 MB */
  static double blockstomb;               /* convert blocks to MB */
  void *space;                            /* allocated space */
  
  if (GPTLget_memusage (&size, &rss, &share, &text, &datastack) < 0)
    return -1;

#if (defined HAVE_SLASHPROC || defined __APPLE__)
  /*
  ** Determine size in bytes of memory usage info presented by the OS. Method: allocate a 
  ** known amount of memory and see how much bigger the process becomes.
  */

  if (convert_to_mb && bytesperblock == -1 && (space = malloc (nbytes))) {
    memset (space, 0, nbytes);  /* ensure the space is really allocated */
    if (GPTLget_memusage (&size2, &rss2, &share2, &text2, &datastack2) == 0) {
      if (size2 > size) {
	/*
	** Estimate bytes per block, then refine to nearest power of 2.
	** The assumption is that the OS presents memory usage info in
	** units that are a power of 2. 
	*/
	bytesperblock = (int) ((nbytes / (double) (size2 - size)) + 0.5);
	bytesperblock = nearest_powerof2 (bytesperblock);
	blockstomb = bytesperblock / (1024.*1024.);
	printf ("GPTLprint_memusage: Using bytesperblock=%d\n", bytesperblock);
      }
    }
    free (space);
  }
  
  if (bytesperblock > 0)
    printf ("%s size=%.1f MB rss=%.1f MB share=%.1f MB text=%.1f MB datastack=%.1f MB\n", 
	    str, size*blockstomb, rss*blockstomb, share*blockstomb, 
	    text*blockstomb, datastack*blockstomb);
  else
    printf ("%s size=%d rss=%d share=%d text=%d datastack=%d\n", 
	    str, size, rss, share, text, datastack);

#else

  /*
  ** Use max rss as returned by getrusage. If someone knows how to 
  ** get the process size under AIX please tell me.
  */

  bytesperblock = 1024;
  blockstomb = bytesperblock / (1024.*1024.);
  if (convert_to_mb)
    printf ("%s max rss=%.1f MB\n", str, rss*blockstomb);
  else
    printf ("%s max rss=%d\n", str, rss);
#endif

  return 0;
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
