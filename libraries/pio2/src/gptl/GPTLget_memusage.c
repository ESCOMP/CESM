/*
** $Id: get_memusage.c,v 1.10 2010-11-09 19:08:53 rosinski Exp $
**
** Author: Jim Rosinski
**   Credit to Chuck Bardeen for MACOS section (__APPLE__ ifdef)
**
** get_memusage: 
**
**   Designed to be called from Fortran, returns information about memory
**   usage in each of 5 input int* args.  On Linux read from the /proc
**   filesystem because getrusage() returns placebos (zeros).  Return -1 for
**   values which are unavailable or ambiguous on a particular architecture.
**
**   Return value: 0  = success
**                 -1 = failure
*/

#include <sys/resource.h>
#include "gptl.h"    /* additional cpp defs and function prototypes */

/* _AIX is automatically defined when using the AIX C compilers */
#ifdef _AIX
#include <sys/times.h>
#endif

#ifdef IRIX64
#include <sys/time.h>
#endif

#ifdef HAVE_SLASHPROC

#include <sys/time.h>
#include <sys/types.h>
#include <stdio.h>
#include <unistd.h>

#elif (defined __APPLE__)

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#endif

#ifdef BGP

#include <spi/kernel_interface.h>
#include <common/bgp_personality.h>
#include <common/bgp_personality_inlines.h>
#include <malloc.h>
#define   Personality                    _BGP_Personality_t

#endif


int GPTLget_memusage (int *size, int *rss, int *share, int *text, int *datastack)
{
#ifdef BGP

  long long alloc;
  struct mallinfo m;
  Personality pers;

  long long total;
  int node_config;
 
 /* memory available */
  Kernel_GetPersonality(&pers, sizeof(pers));
  total = BGP_Personality_DDRSizeMB(&pers);

  node_config  = BGP_Personality_processConfig(&pers);
  if (node_config == _BGP_PERS_PROCESSCONFIG_VNM) total /= 4;
  else if (node_config == _BGP_PERS_PROCESSCONFIG_2x2) total /= 2;
  total *= 1024*1024;

  *size = total;

  /* total memory used  - heap only (not static memory)*/

  m = mallinfo();
  alloc = m.hblkhd + m.uordblks;

  *rss = alloc;
  *share     = -1;
  *text     = -1;
  *datastack = -1;


#elif (defined HAVE_SLASHPROC)
  FILE *fd;                       /* file descriptor for fopen */
  int pid;                        /* process id */
  static char *head = "/proc/";   /* part of path */
  static char *tail = "/statm";   /* part of path */
  char file[19];                  /* full path to file in /proc */
  int dum;                        /* placeholder for unused return arguments */
  int ret;                        /* function return value */

  /*
  ** The file we want to open is /proc/<pid>/statm
  */

  pid = (int) getpid ();
  if (pid > 999999) {
    fprintf (stderr, "get_memusage: pid %d is too large\n", pid);
    return -1;
  }

  sprintf (file, "%s%d%s", head, pid, tail);
  if ((fd = fopen (file, "r")) < 0) {
    fprintf (stderr, "get_memusage: bad attempt to open %s\n", file);
    return -1;
  }

  /*
  ** Read the desired data from the /proc filesystem directly into the output
  ** arguments, close the file and return.
  */

  ret = fscanf (fd, "%d %d %d %d %d %d %d", 
		size, rss, share, text, datastack, &dum, &dum);
  ret = fclose (fd);
  return 0;

#elif (defined __APPLE__)

  FILE *fd;
  char cmd[60];  
  int pid = (int) getpid ();
  
  sprintf (cmd, "ps -o vsz -o rss -o tsiz -p %d | grep -v RSS", pid);
  fd = popen (cmd, "r");

  if (fd) {
    fscanf (fd, "%d %d %d", size, rss, text);
    *share     = -1;
    *datastack = -1;
    (void) pclose (fd);
  }

  return 0;

#else

  struct rusage usage;         /* structure filled in by getrusage */

  if (getrusage (RUSAGE_SELF, &usage) < 0)
    return -1;
  
  *size      = -1;
  *rss       = usage.ru_maxrss;
  *share     = -1;
  *text      = -1;
  *datastack = -1;
#ifdef IRIX64
  *datastack = usage.ru_idrss + usage.ru_isrss;
#endif
  return 0;

#endif
}
