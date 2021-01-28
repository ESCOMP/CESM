/*
** $Id: gptl.c,v 1.157 2011-03-28 20:55:18 rosinski Exp $
**
** Author: Jim Rosinski
**
** Main file contains most user-accessible GPTL functions
*/

#include <stdlib.h>        /* malloc */
#include <sys/time.h>      /* gettimeofday */
#include <sys/times.h>     /* times */
#include <unistd.h>        /* gettimeofday, syscall */
#include <stdio.h>
#include <string.h>        /* memset, strcmp (via STRMATCH), strncmp (via STRNMATCH) */
#include <ctype.h>         /* isdigit */
#include <sys/types.h>     /* u_int8_t, u_int16_t */
#include <float.h>         /* FLT_MAX */
#include <assert.h>

#ifndef HAVE_C99_INLINE
#define inline
#endif

#ifdef HAVE_PAPI
#include <papi.h>          /* PAPI_get_real_usec */
#endif

#ifdef HAVE_LIBRT
#include <time.h>
#endif

#ifdef _AIX
#include <sys/systemcfg.h>
#endif

#include "private.h"
#include "gptl.h"

static Timer **timers = 0;           /* linked list of timers */
static Timer **last = 0;             /* last element in list */
static int *max_depth;               /* maximum indentation level encountered */
static int *max_name_len;            /* max length of timer name */
static volatile int nthreads = -1;   /* num threads. Init to bad value */
static volatile int maxthreads = -1; /* max threads (=nthreads for OMP). Init to bad value */
static int depthlimit = 99999;       /* max depth for timers (99999 is effectively infinite) */
static volatile bool disabled = false;           /* Timers disabled? */
static volatile bool initialized = false;        /* GPTLinitialize has been called */
static volatile bool pr_has_been_called = false; /* GPTLpr_file has been called */
static Entry eventlist[MAX_AUX];    /* list of PAPI-based events to be counted */
static int nevents = 0;             /* number of PAPI events (init to 0) */
static bool dousepapi = false;      /* saves a function call if stays false */
static bool verbose = false;        /* output verbosity */
static bool percent = false;        /* print wallclock also as percent of 1st timers[0] */
static bool dopr_preamble = true;   /* whether to print preamble info */
static bool dopr_threadsort = true; /* whether to print sorted thread stats */
static bool dopr_multparent = true; /* whether to print multiple parent info */
static bool dopr_collision = true;  /* whether to print hash collision info */
static bool dopr_quotes = false;    /* whether to surround timer names with double quotes */

static time_t ref_gettimeofday = -1; /* ref start point for gettimeofday */
static time_t ref_clock_gettime = -1;/* ref start point for clock_gettime */
#ifdef _AIX
static time_t ref_read_real_time = -1; /* ref start point for read_real_time */
#endif
static long long ref_papitime = -1;  /* ref start point for PAPI_get_real_usec */

#if ( defined THREADED_OMP )

#include <omp.h>
static volatile int *threadid_omp = 0;        /* array of thread ids */

#elif ( defined THREADED_PTHREADS )

#include <pthread.h>

#define MUTEX_API
#ifdef MUTEX_API
static volatile pthread_mutex_t t_mutex;
#else
static volatile pthread_mutex_t t_mutex = PTHREAD_MUTEX_INITIALIZER;
#endif
static volatile pthread_t *threadid = 0;  /* array of thread ids */
static int lock_mutex (void);      /* lock a mutex for entry into a critical region */
static int unlock_mutex (void);    /* unlock a mutex for exit from a critical region */

#else

/* Unthreaded case */
static int threadid = -1;

#endif

typedef struct {
  const Option option;  /* wall, cpu, etc. */
  const char *str;      /* descriptive string for printing */
  bool enabled;         /* flag */
} Settings;

/* For Summary stats */

typedef struct {
  double wallmax;
  double wallmin;
  double walltotal;
  int onflgs;
  int processes;
  int threads;
#ifdef HAVE_PAPI
  double papimax[MAX_AUX];
  double papimin[MAX_AUX];
  double papitotal[MAX_AUX];
#endif
  unsigned long count;
  int wallmax_p;               /* over processes */
  int wallmax_t;               /* over threads */
  int wallmin_p;
  int wallmin_t;
#ifdef HAVE_PAPI
  int papimax_p[MAX_AUX];      /* over processes */
  int papimax_t[MAX_AUX];      /* over threads */
  int papimin_p[MAX_AUX];
  int papimin_t[MAX_AUX];
#endif
} Summarystats;

/* Options, print strings, and default enable flags */

static Settings cpustats =      {GPTLcpu,      "Usr       sys       usr+sys   ", false};
static Settings wallstats =     {GPTLwall,     "   Wallclock          max          min", true };
static Settings overheadstats = {GPTLoverhead, "     UTR Overhead "            , true };
static Settings profileovhd   = {GPTLprofile_ovhd, "", false };

static Hashentry **hashtable;    /* table of entries */
static long ticks_per_sec;       /* clock ticks per second */
static char **timerlist;         /* list of all timers */

typedef struct {
  int val;                       /* depth in calling tree */
  int padding[31];               /* padding is to mitigate false cache sharing */
} Nofalse;
static Timer ***callstack;       /* call stack */
static Nofalse *stackidx;        /* index into callstack: */

static int prefix_len_nt;        /* length of timer name prefix set outside parallel region */
static char *prefix_nt;          /* timer name prefix set outside of parallel region */
static int *prefix_len;          /* length of timer name prefix for each thread */
static char **prefix;            /* timer name prefix for each thread */

static Method method = GPTLmost_frequent;  /* default parent/child printing mechanism */
static PRMode print_mode = GPTLprint_write;  /* default output mode */

/* Local function prototypes */

static void printstats (const Timer *, FILE *, const int, const int, const bool, double);
static void add (Timer *, const Timer *);

static void get_threadstats (const int, const char *, Summarystats *);
static void get_summarystats (Summarystats *, const Summarystats *);
#ifdef HAVE_MPI
static int collect_data( const int, MPI_Comm, int *, Summarystats ** );
#else
static int collect_data( const int, const int, int *, Summarystats ** );
#endif
static int merge_thread_data();

static void print_multparentinfo (FILE *, Timer *);
static inline int get_cpustamp (long *, long *);
static int newchild (Timer *, Timer *);
static int get_max_depth (const Timer *, const int);
static int num_descendants (Timer *);
static int is_descendant (const Timer *, const Timer *);
static int show_descendant (const int, const Timer *, const Timer *);
static char *methodstr (Method);
static char *modestr (PRMode);

/* Prototypes from previously separate file threadutil.c */

static int threadinit (void);                    /* initialize threading environment */
static void threadfinalize (void);               /* finalize threading environment */
static void print_threadmapping (FILE *);        /* print mapping of thread ids */
static inline int get_thread_num (void);         /* get 0-based thread number */
static int serial_region (void);                 /* check whether in a serial region */

/* These are the (possibly) supported underlying wallclock timers */

static inline double utr_nanotime (void);
static inline double utr_mpiwtime (void);
static inline double utr_clock_gettime (void);
static inline double utr_papitime (void);
static inline double utr_read_real_time (void);
static inline double utr_gettimeofday (void);

static int init_nanotime (void);
static int init_mpiwtime (void);
static int init_clock_gettime (void);
static int init_papitime (void);
static int init_read_real_time (void);
static int init_gettimeofday (void);

static double utr_getoverhead (void);
static inline Timer *getentry_instr (const Hashentry *, void *, unsigned int *);
static inline Timer *getentry (const Hashentry *, const char *, unsigned int *);
static inline Timer *getentryf (const Hashentry *, const char *, const int, unsigned int *);
static void printself_andchildren (const Timer *, FILE *, const int, const int, const double);
static inline int update_parent_info (Timer *, Timer **, int);
static inline int update_stats (Timer *, const double, const long, const long, const int);
static int update_ll_hash (Timer *, const int, const unsigned int);
static inline int update_ptr (Timer *, const int);
static int construct_tree (Timer *, Method);

static int cmp (const void *, const void *);
static int ncmp (const void *, const void *);
static int get_index ( const char *, const char *);

static int add_prefix( char *, const char *, const int, const int);

typedef struct {
  const Funcoption option;
  double (*func)(void);
  int (*funcinit)(void);
  const char *name;
} Funcentry;

static Funcentry funclist[] = {
  {GPTLgettimeofday,   utr_gettimeofday,   init_gettimeofday,  "gettimeofday"},
  {GPTLnanotime,       utr_nanotime,       init_nanotime,      "nanotime"},
  {GPTLmpiwtime,       utr_mpiwtime,       init_mpiwtime,      "MPI_Wtime"},
  {GPTLclockgettime,   utr_clock_gettime,  init_clock_gettime, "clock_gettime"},
  {GPTLpapitime,       utr_papitime,       init_papitime,      "PAPI_get_real_usec"},
  {GPTLread_real_time, utr_read_real_time, init_read_real_time,"read_real_time"}     /* AIX only */
};
static const int nfuncentries = sizeof (funclist) / sizeof (Funcentry);

static double (*ptr2wtimefunc)() = 0; /* init to invalid */
static int funcidx = 0;               /* default timer is gettimeofday */

#ifdef HAVE_NANOTIME
static float cpumhz = -1.;                        /* init to bad value */
static double cyc2sec = -1;                       /* init to bad value */
static unsigned inline long long nanotime (void); /* read counter (assembler) */
static float get_clockfreq (void);                /* cycles/sec */
#endif

#define DEFAULT_TABLE_SIZE 2048
static int tablesize = DEFAULT_TABLE_SIZE;  /* per-thread size of hash table (settable parameter) */
static char *outdir = 0;      /* dir to write output files to (currently unused) */

static double overhead_utr   = 0.0;                 /* timer cost estimate */
static double overhead_est   = 0.0;                 /* direct measurement of overhead for thread 0 */
static double overhead_bound = 0.0;                 /* direct measurement of overhead for thread 0 */

/* VERBOSE is a debugging ifdef local to the rest of this file */
#undef VERBOSE

/*
** GPTLsetoption: set option value to true or false.
**
** Input arguments:
**   option: option to be set
**   val:    value to which option should be set (nonzero=true, zero=false)
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLsetoption (const int option,  /* option */
		   const int val)     /* value */
{
  static const char *thisfunc = "GPTLsetoption";

  if (initialized)
    return GPTLerror ("%s: must be called BEFORE GPTLinitialize\n", thisfunc);

  if (option == GPTLabort_on_error) {
    GPTLset_abort_on_error ((bool) val);
    if (verbose)
      printf ("%s: boolean abort_on_error = %d\n", thisfunc, val);
    return 0;
  }

  switch (option) {
  case GPTLcpu:
#ifdef HAVE_TIMES
    cpustats.enabled = (bool) val;
    if (verbose)
      printf ("%s: cpustats = %d\n", thisfunc, val);
#else
    if (val)
      return GPTLerror ("%s: times() not available\n", thisfunc);
#endif
    return 0;
  case GPTLwall:
    wallstats.enabled = (bool) val;
    if (verbose)
      printf ("%s: boolean wallstats = %d\n", thisfunc, val);
    return 0;
  case GPTLoverhead:
    overheadstats.enabled = (bool) val;
    if (verbose)
      printf ("%s: boolean overheadstats = %d\n", thisfunc, val);
    return 0;
  case GPTLprofile_ovhd:
    profileovhd.enabled = (bool) val;
    if (verbose)
      printf ("%s: boolean profileovhd = %d\n", thisfunc, val);
    return 0;
  case GPTLdepthlimit:
    depthlimit = val;
    if (verbose)
      printf ("%s: depthlimit = %d\n", thisfunc, val);
    return 0;
  case GPTLverbose:
    verbose = (bool) val;
#ifdef HAVE_PAPI
    (void) GPTL_PAPIsetoption (GPTLverbose, val);
#endif
    if (verbose)
      printf ("%s: boolean verbose = %d\n", thisfunc, val);
    return 0;
  case GPTLpercent:
    percent = (bool) val;
    if (verbose)
      printf ("%s: boolean percent = %d\n", thisfunc, val);
    return 0;
  case GPTLdopr_preamble:
    dopr_preamble = (bool) val;
    if (verbose)
      printf ("%s: boolean dopr_preamble = %d\n", thisfunc, val);
    return 0;
  case GPTLdopr_threadsort:
    dopr_threadsort = (bool) val;
    if (verbose)
      printf ("%s: boolean dopr_threadsort = %d\n", thisfunc, val);
    return 0;
  case GPTLdopr_multparent:
    dopr_multparent = (bool) val;
    if (verbose)
      printf ("%s: boolean dopr_multparent = %d\n", thisfunc, val);
    return 0;
  case GPTLdopr_collision:
    dopr_collision = (bool) val;
    if (verbose)
      printf ("%s: boolean dopr_collision = %d\n", thisfunc, val);
    return 0;
  case GPTLdopr_quotes:
    dopr_quotes = (bool) val;
    if (verbose)
      printf ("%s: boolean dopr_quotes = %d\n", thisfunc, val);
    return 0;
  case GPTLprint_mode:
    print_mode = (PRMode) val; 
    if (verbose)
      printf ("%s: print_mode = %s\n", thisfunc, modestr (print_mode));
    return 0;
  case GPTLprint_method:
    method = (Method) val;
    if (verbose)
      printf ("%s: print_method = %s\n", thisfunc, methodstr (method));
    return 0;
  case GPTLtablesize:
    if (val < 1)
      return GPTLerror ("%s: tablesize must be positive. %d is invalid\n", thisfunc, val);
    tablesize = val;
    if (verbose)
      printf ("%s: tablesize = %d\n", thisfunc, tablesize);
    return 0;
  case GPTLsync_mpi:
#ifdef ENABLE_PMPI
    if (GPTLpmpi_setoption (option, val) != 0)
      fprintf (stderr, "%s: GPTLpmpi_setoption failure\n", thisfunc);
#endif
    if (verbose)
      printf ("%s: boolean sync_mpi = %d\n", thisfunc, val);
    return 0;

  case GPTLmaxthreads:
    if (val < 1)
      return GPTLerror ("%s: maxthreads must be positive. %d is invalid\n", thisfunc, val);

    maxthreads = val;
    return 0;

  /*
  ** Allow GPTLmultiplex to fall through because it will be handled by
  ** GPTL_PAPIsetoption()
  */

  case GPTLmultiplex:
  default:
    break;
  }

#ifdef HAVE_PAPI
  if (GPTL_PAPIsetoption (option, val) == 0) {
    if (val)
      dousepapi = true;
    return 0;
  }
#else
  /* Make GPTLnarrowprint a placebo if PAPI not enabled */

  if (option == GPTLnarrowprint)
    return 0;
#endif

  return GPTLerror ("%s: faiure to enable option %d\n", thisfunc, option);
}

/*
** GPTLsetutr: set underlying timing routine.
**
** Input arguments:
**   option: index which sets function
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLsetutr (const int option)
{
  int i;  /* index over number of underlying timer  */
  static const char *thisfunc = "GPTLsetutr";

  if (initialized)
    return GPTLerror ("%s: must be called BEFORE GPTLinitialize\n", thisfunc);

  for (i = 0; i < nfuncentries; i++) {
    if (option == (int) funclist[i].option) {
      if (verbose)
	printf ("%s: underlying wallclock timer = %s\n", thisfunc, funclist[i].name);
      funcidx = i;

      /*
      ** Return an error condition if the function is not available.
      ** OK for the user code to ignore: GPTLinitialize() will reset to gettimeofday
      */

      if ((*funclist[i].funcinit)() < 0)
	return GPTLerror ("%s: utr=%s not available\n", thisfunc, funclist[i].name);
      else
	return 0;
    }
  }
  return GPTLerror ("%s: unknown option %d\n", thisfunc, option);
}

/*
** GPTLinitialize (): Initialization routine must be called from single-threaded
**   region before any other timing routines may be called.  The need for this
**   routine could be eliminated if not targetting timing library for threaded
**   capability.
**
** return value: 0 (success) or GPTLerror (failure)
*/

int GPTLinitialize (void)
{
  int i;          /* loop index */
  int t;          /* thread index */
  double t1, t2;  /* returned from underlying timer */
  static const char *thisfunc = "GPTLinitialize";

  if (initialized)
    return GPTLerror ("%s: has already been called\n", thisfunc);

  if (threadinit () < 0)
    return GPTLerror ("%s: bad return from threadinit\n", thisfunc);

  if ((ticks_per_sec = sysconf (_SC_CLK_TCK)) == -1)
    return GPTLerror ("%s: failure from sysconf (_SC_CLK_TCK)\n", thisfunc);

  /* Allocate space for global arrays */

  callstack     = (Timer ***)    GPTLallocate (maxthreads * sizeof (Timer **));
  stackidx      = (Nofalse *)    GPTLallocate (maxthreads * sizeof (Nofalse));
  timers        = (Timer **)     GPTLallocate (maxthreads * sizeof (Timer *));
  last          = (Timer **)     GPTLallocate (maxthreads * sizeof (Timer *));
  max_depth     = (int *)        GPTLallocate (maxthreads * sizeof (int));
  max_name_len  = (int *)        GPTLallocate (maxthreads * sizeof (int));
  hashtable     = (Hashentry **) GPTLallocate (maxthreads * sizeof (Hashentry *));
  prefix_len    = (int *)        GPTLallocate (maxthreads * sizeof (int));
  prefix        = (char **)      GPTLallocate (maxthreads * sizeof (char *));

  /* Initialize array values */

  for (t = 0; t < maxthreads; t++) {
    max_depth[t]    = -1;
    max_name_len[t] = 0;
    callstack[t] = (Timer **) GPTLallocate (MAX_STACK * sizeof (Timer *));
    hashtable[t] = (Hashentry *) GPTLallocate (tablesize * sizeof (Hashentry));
    for (i = 0; i < tablesize; i++) {
      hashtable[t][i].nument = 0;
      hashtable[t][i].entries = 0;
    }

    /*
    ** Make a timer "GPTL_ROOT" to ensure no orphans, and to simplify printing.
    */

    timers[t] = (Timer *) GPTLallocate (sizeof (Timer));
    memset (timers[t], 0, sizeof (Timer));
    strcpy (timers[t]->name, "GPTL_ROOT");
    timers[t]->onflg = true;
    last[t] = timers[t];

    stackidx[t].val = 0;
    callstack[t][0] = timers[t];
    for (i = 1; i < MAX_STACK; i++)
      callstack[t][i] = 0;

    prefix_len[t] = 0;
    prefix[t] = (char *) GPTLallocate ((MAX_CHARS+1) * sizeof (char));
    prefix[t][0] = '\0';
  }

  prefix_len_nt = 0;
  prefix_nt = (char *) GPTLallocate ((MAX_CHARS+1) * sizeof (char));
  prefix_nt[0] = '\0';

#ifdef HAVE_PAPI
  if (GPTL_PAPIinitialize (maxthreads, verbose, &nevents, eventlist) < 0)
    return GPTLerror ("%s: Failure from GPTL_PAPIinitialize\n", thisfunc);
#endif

  /*
  ** Call init routine for underlying timing routine.
  */

  if ((*funclist[funcidx].funcinit)() < 0) {
    fprintf (stderr, "%s: Failure initializing %s. Reverting underlying timer to %s\n",
	     thisfunc, funclist[funcidx].name, funclist[0].name);
    funcidx = 0;
  }

  ptr2wtimefunc = funclist[funcidx].func;

  if (verbose) {
    t1 = (*ptr2wtimefunc) ();
    t2 = (*ptr2wtimefunc) ();
    if (t1 > t2)
      fprintf (stderr, "%s: negative delta-t=%g\n", thisfunc, t2-t1);

    printf ("Per call overhead est. t2-t1=%g should be near zero\n", t2-t1);
    printf ("Underlying wallclock timing routine is %s\n", funclist[funcidx].name);
  }

  /* set global timer overhead estimate */
  if (wallstats.enabled && profileovhd.enabled){
    overhead_utr = utr_getoverhead ();
  }

  initialized = true;
  return 0;
}

/*
** GPTLfinalize (): Finalization routine must be called from single-threaded
**   region. Free all malloc'd space
**
** return value: 0 (success) or GPTLerror (failure)
*/

int GPTLfinalize (void)
{
  int t;                /* thread index */
  int n;                /* array index */
  Timer *ptr, *ptrnext; /* ll indices */
  static const char *thisfunc = "GPTLfinalize";

  if ( ! initialized)
    return GPTLerror ("%s: initialization was not completed\n", thisfunc);

  for (t = 0; t < maxthreads; ++t) {
    for (n = 0; n < tablesize; ++n) {
      if (hashtable[t][n].nument > 0)
	free (hashtable[t][n].entries);
    }
    free (hashtable[t]);
    hashtable[t] = NULL;
    free (callstack[t]);
    free (prefix[t]);
    for (ptr = timers[t]; ptr; ptr = ptrnext) {
      ptrnext = ptr->next;
      if (ptr->nparent > 0) {
	free (ptr->parent);
	free (ptr->parent_count);
      }
      if (ptr->nchildren > 0)
	free (ptr->children);
      free (ptr);
    }
  }

  free (callstack);
  free (stackidx);
  free (timers);
  free (last);
  free (max_depth);
  free (max_name_len);
  free (hashtable);
  free (prefix_len);
  free (prefix);
  free (prefix_nt);

  threadfinalize ();

#ifdef HAVE_PAPI
  GPTL_PAPIfinalize (maxthreads);
#endif

  /* Reset initial values */

  timers = 0;
  last = 0;
  max_depth = 0;
  max_name_len = 0;
  nthreads = -1;
  maxthreads = -1;
  depthlimit = 99999;
  disabled = false;
  initialized = false;
  pr_has_been_called = false;
  dousepapi = false;
  verbose = false;
  percent = false;
  dopr_preamble = true;
  dopr_threadsort = true;
  dopr_multparent = true;
  dopr_collision = true;
  print_mode = GPTLprint_write;
  ref_gettimeofday = -1;
  ref_clock_gettime = -1;
#ifdef _AIX
  ref_read_real_time = -1;
#endif
  ref_papitime = -1;
  funcidx = 0;
#ifdef HAVE_NANOTIME
  cpumhz= 0;
  cyc2sec = -1;
#endif
  outdir = 0;
  tablesize = DEFAULT_TABLE_SIZE;
  prefix_len_nt = 0;

  return 0;
}

/*
** GPTLprefix_set: define prefix for subsequent timer names
**
** Input arguments:
**   prefixname: prefix string
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLprefix_set (const char *prefixname)      /* prefix string */
{
  int t;                      /* thread index (of this thread) */
  int len_prefix;             /* number of characters in prefix */
  char *ptr_prefix;           /* pointer to prefix string */
  static const char *thisfunc = "GPTLprefix_set";

  if (disabled)
    return 0;

  if ( ! initialized){
    return 0;
  }

#if ( defined THREADED_PTHREADS )
  /*
  ** prefix logic not enabled when using PTHREADS
  */
  return 0;
#endif

  len_prefix = MIN (strlen (prefixname), MAX_CHARS);

  /*
  ** Note: if in a parallel region with only one active thread, e.g.
  ** thread 0, this will NOT be identified as a serial regions.
  ** If want GPTLprefix_set to apply to all threads, will need to 
  ** "fire up" the idle threads in some sort of parallel loop. 
  ** It is not safe to just test omp_in_parallel and
  ** omp_get_thread_num == 1 unless add a thread barrier, and this 
  ** barrier would apply to all calls, so would be a performance bottleneck.
  */

  if (serial_region()){

    prefix_len_nt = len_prefix;
    ptr_prefix = prefix_nt;
    
  } else {

    if ((t = get_thread_num ()) < 0)
      return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

    prefix_len[t] = len_prefix;
    ptr_prefix = prefix[t];

  }

  strncpy (ptr_prefix, prefixname, len_prefix);

  return (0);
}

/*
** GPTLprefix_setf: define prefix for subsequent timer names when 
**                  the string may not be null terminated
**
** Input arguments:
**   prefixname: prefix string
**   prefixlen:  number of characters in timer name
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLprefix_setf (const char *prefixname, const int prefixlen)  /* prefix string and length*/
{
  int t;                      /* thread index (of this thread) */
  int c;                      /* character index */
  int len_prefix;             /* number of characters in prefix */
  char *ptr_prefix;           /* pointer to prefix string */
  static const char *thisfunc = "GPTLprefix_setf";

  if (disabled)
    return 0;

  if ( ! initialized){
    return 0;
  }

#if ( defined THREADED_PTHREADS )
  /*
  ** prefix logic not enabled when using PTHREADS
  */
  return 0;
#endif

  len_prefix = MIN (prefixlen, MAX_CHARS);

  /*
  ** Note: if in a parallel region with only one active thread, e.g.
  ** thread 0, this will NOT be identified as a serial regions.
  ** If want GPTLprefix_setf to apply to all threads, will need to 
  ** "fire up" the idle threads in some sort of parallel loop. 
  ** It is not safe to just test omp_in_parallel and
  ** omp_get_thread_num == 1 unless add a thread barrier, and this 
  ** barrier would apply to all calls, so would be a performance bottleneck.
  */

  if (serial_region()){

    prefix_len_nt = len_prefix;
    ptr_prefix = prefix_nt;
    
  } else {

    if ((t = get_thread_num ()) < 0)
      return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

    prefix_len[t] = len_prefix;
    ptr_prefix = prefix[t];

  }

  for (c = 0; c < len_prefix; c++) {
    ptr_prefix[c] = prefixname[c];
  }
  ptr_prefix[len_prefix] = '\0';

  return (0);
}

/*
** GPTLprefix_unset: undefine prefix for subsequent timer names
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLprefix_unset ()
{
  int t;                      /* thread index (of this thread) */
  int c;                      /* character index */
  char *ptr_prefix;           /* pointer to prefix string */
  static const char *thisfunc = "GPTLprefix_setf";

  if (disabled)
    return 0;

  if ( ! initialized){
    return 0;
  }

#if ( defined THREADED_PTHREADS )
  /*
  ** prefix logic not enabled when using PTHREADS
  */
  return 0;
#endif

  /*
  ** Note: if in a parallel region with only one active thread, e.g.
  ** thread 0, this will NOT be identified as a serial regions.
  ** If want GPTLprefix_unset to apply to all threads, will need to 
  ** "fire up" the idle threads in some sort of parallel loop. 
  ** It is not safe to just test omp_in_parallel and
  ** omp_get_thread_num == 1 unless add a thread barrier, and this 
  ** barrier would apply to all calls, so would be a performance bottleneck.
  */

  if (serial_region()){

    prefix_len_nt = 0;
    ptr_prefix = prefix_nt;
    
  } else {

    if ((t = get_thread_num ()) < 0)
      return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

    prefix_len[t] = 0;
    ptr_prefix = prefix[t];

  }

  ptr_prefix[0] = '\0';

  return (0);
}

/*
** GPTLstart_instr: start a timer (auto-instrumented)
**
** Input arguments:
**   self: function address
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLstart_instr (void *self)
{
  Timer *ptr;              /* linked list pointer */
  int t;                   /* thread index (of this thread) */
  unsigned int indx;       /* hash table index */
  static const char *thisfunc = "GPTLstart_instr";

  if (disabled)
    return 0;

  if ( ! initialized)
    return GPTLerror ("%s self=%p: GPTLinitialize has not been called\n", thisfunc, self);

  if ((t = get_thread_num ()) < 0)
    return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

  /*
  ** If current depth exceeds a user-specified limit for print, just
  ** increment and return
  */

  if (stackidx[t].val >= depthlimit) {
    ++stackidx[t].val;
    return 0;
  }

  ptr = getentry_instr (hashtable[t], self, &indx);

  /*
  ** Recursion => increment depth in recursion and return.  We need to return
  ** because we don't want to restart the timer.  We want the reported time for
  ** the timer to reflect the outermost layer of recursion.
  */

  if (ptr && ptr->onflg) {
    ++ptr->recurselvl;
    return 0;
  }

  /*
  ** Increment stackidx[t] unconditionally. This is necessary to ensure the correct
  ** behavior when GPTLstop_instr decrements stackidx[t] unconditionally.
  */

  if (++stackidx[t].val > MAX_STACK-1)
    return GPTLerror ("%s: stack too big\n", thisfunc);

  if ( ! ptr) {     /* Add a new entry and initialize */
    ptr = (Timer *) GPTLallocate (sizeof (Timer));
    memset (ptr, 0, sizeof (Timer));

    /*
    ** Need to save the address string for later conversion back to a real
    ** name by an offline tool.
    */

    snprintf (ptr->name, MAX_CHARS+1, "%lx", (unsigned long) self);
    ptr->address = self;

    if (update_ll_hash (ptr, t, indx) != 0)
      return GPTLerror ("%s: update_ll_hash error\n", thisfunc);
  }

  if (update_parent_info (ptr, callstack[t], stackidx[t].val) != 0)
    return GPTLerror ("%s: update_parent_info error\n", thisfunc);

  if (update_ptr (ptr, t) != 0)
    return GPTLerror ("%s: update_ptr error\n", thisfunc);

  return (0);
}

/*
** GPTLstart: start a timer
**
** Input arguments:
**   timername: timer name
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLstart (const char *timername)                  /* timer name */
{
  Timer *ptr;                 /* linked list pointer */
  int t;                      /* thread index (of this thread) */
  int numchars;               /* number of characters to copy */
  int namelen;                /* number of characters in timer name */
  unsigned int indx;          /* hash table index */
  double tpa = 0.0;           /* time stamp */
  double tpb = 0.0;           /* time stamp */
  char new_name[MAX_CHARS+1]; /* timer name with prefix, if there is one */
  const char *name;           /* pointer to timer name */
  static const char *thisfunc = "GPTLstart";

  if (disabled)
    return 0;

  if ( ! initialized)
    return 0;

  if ((t = get_thread_num ()) < 0)
    return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

  /*
  ** If current depth exceeds a user-specified limit for print, just
  ** increment and return
  */

  if (stackidx[t].val >= depthlimit) {
    ++stackidx[t].val;
    return 0;
  }

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* first caliper timestamp */
      tpa = (*ptr2wtimefunc) ();
    }
  }

  /*
  ** If prefix string is defined, prepend it to timername
  ** and assign the name pointer to the new string. 
  ** Otherwise assign the name pointer to the original string.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    namelen = strlen(timername);
    numchars = add_prefix(new_name, timername, namelen, t);
    name = new_name;
  } else {
    name = timername;
    numchars = MIN (strlen (name), MAX_CHARS);
  }

  /*
  ** ptr will point to the requested timer in the current list,
  ** or NULL if this is a new entry
  */

  ptr = getentry (hashtable[t], name, &indx);

  /*
  ** Recursion => increment depth in recursion and return.  We need to return
  ** because we don't want to restart the timer.  We want the reported time for
  ** the timer to reflect the outermost layer of recursion.
  */

  if (ptr && ptr->onflg) {
    ++ptr->recurselvl;

    if (wallstats.enabled && profileovhd.enabled){
      if (t == 0){
        /* second caliper timestamp */
        tpb = (*ptr2wtimefunc) ();
        /* subtract out additional overhead from caliper timing calls */
        overhead_est += ((tpb - tpa) - overhead_utr);
        /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
        overhead_bound += ((tpb - tpa) + 2*overhead_utr);
      }
    }
    return 0;
  }

  /*
  ** Increment stackidx[t] unconditionally. This is necessary to ensure the correct
  ** behavior when GPTLstop decrements stackidx[t] unconditionally.
  */

  if (++stackidx[t].val > MAX_STACK-1)
    return GPTLerror ("%s: stack too big\n", thisfunc);

  if ( ! ptr) { /* Add a new entry and initialize */
    ptr = (Timer *) GPTLallocate (sizeof (Timer));
    memset (ptr, 0, sizeof (Timer));

    //pw    numchars = MIN (strlen (name), MAX_CHARS);
    strncpy (ptr->name, name, numchars);
    ptr->name[numchars] = '\0';

    if (update_ll_hash (ptr, t, indx) != 0)
      return GPTLerror ("%s: update_ll_hash error\n", thisfunc);
  }

  if (update_parent_info (ptr, callstack[t], stackidx[t].val) != 0)
    return GPTLerror ("%s: update_parent_info error\n", thisfunc);

  if (update_ptr (ptr, t) != 0)
    return GPTLerror ("%s: update_ptr error\n", thisfunc);

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* second caliper timestamp */
      tpb = (*ptr2wtimefunc) ();
      /* subtract out additional overhead from caliper timing calls */
      overhead_est += ((tpb - tpa) - overhead_utr);
      /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
      overhead_bound += ((tpb - tpa) + 2*overhead_utr);
    }
  }

  return (0);
}

/*
** GPTLstart_handle: start a timer based on a handle
**
** Input arguments:
**   name: timer name (required when on input, handle=0)
**   handle: pointer to timer matching "name"
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLstart_handle (const char *name,  /* timer name */
		      void **handle)     /* handle (output if input value is 0) */
{
  Timer *ptr;                            /* linked list pointer */
  int t;                                 /* thread index (of this thread) */
  int numchars;                          /* number of characters to copy */
  unsigned int indx = (unsigned int) -1; /* hash table index: init to bad value */
  double tpa = 0.0;                      /* time stamp */
  double tpb = 0.0;                      /* time stamp */
  static const char *thisfunc = "GPTLstart_handle";

  if (disabled)
    return 0;

  if ( ! initialized)
    return 0;

  if ((t = get_thread_num ()) < 0)
    return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

  /*
  ** If current depth exceeds a user-specified limit for print, just
  ** increment and return
  */

  if (stackidx[t].val >= depthlimit) {
    ++stackidx[t].val;
    return 0;
  }

  /*
  ** If prefix string is defined, then call GPTLstart and
  ** return a handle of 0. Otherwise a change in the prefix
  ** might be ignored if the handle has already been set.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    *handle = 0;
    return GPTLstart (name);
  }

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* first caliper timestamp */
      tpa = (*ptr2wtimefunc) ();
    }
  }

  /*
  ** If on input, handle references a non-zero value, assume it's a previously returned Timer*
  ** passed in by the user. If zero, generate the hash entry and return it to the user.
  */

  if (*handle) {
    ptr = (Timer *) *handle;
  } else {
    ptr = getentry (hashtable[t], name, &indx);
  }

  /*
  ** Recursion => increment depth in recursion and return.  We need to return
  ** because we don't want to restart the timer.  We want the reported time for
  ** the timer to reflect the outermost layer of recursion.
  */

  if (ptr && ptr->onflg) {
    ++ptr->recurselvl;

    if (wallstats.enabled && profileovhd.enabled){
      if (t == 0){
        /* second caliper timestamp */
        tpb = (*ptr2wtimefunc) ();
        /* subtract out additional overhead from caliper timing calls */
        overhead_est += ((tpb - tpa) - overhead_utr);
        /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
        overhead_bound += ((tpb - tpa) + 2*overhead_utr);
      }
    }

    return 0;
  }

  /*
  ** Increment stackidx[t] unconditionally. This is necessary to ensure the correct
  ** behavior when GPTLstop decrements stackidx[t] unconditionally.
  */

  if (++stackidx[t].val > MAX_STACK-1)
    return GPTLerror ("%s: stack too big\n", thisfunc);

  if ( ! ptr) { /* Add a new entry and initialize */
    ptr = (Timer *) GPTLallocate (sizeof (Timer));
    memset (ptr, 0, sizeof (Timer));

    numchars = MIN (strlen (name), MAX_CHARS);
    strncpy (ptr->name, name, numchars);
    ptr->name[numchars] = '\0';

    if (update_ll_hash (ptr, t, indx) != 0)
      return GPTLerror ("%s: update_ll_hash error\n", thisfunc);
  }

  if (update_parent_info (ptr, callstack[t], stackidx[t].val) != 0)
    return GPTLerror ("%s: update_parent_info error\n", thisfunc);

  if (update_ptr (ptr, t) != 0)
    return GPTLerror ("%s: update_ptr error\n", thisfunc);

  /*
  ** If on input, *handle was 0, return the pointer to the timer for future input
  */

  if ( ! *handle)
    *handle = (void *) ptr;

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* second caliper timestamp */
      tpb = (*ptr2wtimefunc) ();
      /* subtract out additional overhead from caliper timing calls */
      overhead_est += ((tpb - tpa) - overhead_utr);
      /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
      overhead_bound += ((tpb - tpa) + 2*overhead_utr);
    }
  }

  return (0);
}

/*
** GPTLstartf: start a timer when the timer name may not be null terminated
**
** Input arguments:
**   timername: timer name
**   namelen:   number of characters in timer name
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLstartf (const char *timername, const int namelen)    /* timer name and length */
{
  Timer *ptr;                 /* linked list pointer */
  int t;                      /* thread index (of this thread) */
  int c;                      /* character index */
  int numchars;               /* number of characters to copy */
  unsigned int indx;          /* hash table index */
  double tpa = 0.0;           /* time stamp */
  double tpb = 0.0;           /* time stamp */
  char new_name[MAX_CHARS+1]; /* timer name with prefix, if there is one */
  const char *name;           /* pointer to timer name */
  static const char *thisfunc = "GPTLstartf";

  if (disabled)
    return 0;

  if ( ! initialized)
    return 0;

  if ((t = get_thread_num ()) < 0)
    return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

  /*
  ** If current depth exceeds a user-specified limit for print, just
  ** increment and return
  */

  if (stackidx[t].val >= depthlimit) {
    ++stackidx[t].val;
    return 0;
  }

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* first caliper timestamp */
      tpa = (*ptr2wtimefunc) ();
    }
  }

  /*
  ** If prefix string is defined, prepend it to timername
  ** and assign the name pointer to the new string. 
  ** Otherwise assign the name pointer to the original string.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    numchars = add_prefix(new_name, timername, namelen, t);
    name = new_name;
  } else {
    numchars = MIN (namelen, MAX_CHARS);
    name = timername;
  }

  /*
  ** ptr will point to the requested timer in the current list,
  ** or NULL if this is a new entry
  */

  ptr = getentryf (hashtable[t], name, numchars, &indx);

  /*
  ** Recursion => increment depth in recursion and return.  We need to return
  ** because we don't want to restart the timer.  We want the reported time for
  ** the timer to reflect the outermost layer of recursion.
  */

  if (ptr && ptr->onflg) {
    ++ptr->recurselvl;

    if (wallstats.enabled && profileovhd.enabled){
      if (t == 0){
        /* second caliper timestamp */
        tpb = (*ptr2wtimefunc) ();
        /* subtract out additional overhead from caliper timing calls */
        overhead_est += ((tpb - tpa) - overhead_utr);
        /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
        overhead_bound += ((tpb - tpa) + 2*overhead_utr);
      }
    }

    return 0;
  }

  /*
  ** Increment stackidx[t] unconditionally. This is necessary to ensure the correct
  ** behavior when GPTLstop decrements stackidx[t] unconditionally.
  */

  if (++stackidx[t].val > MAX_STACK-1)
    return GPTLerror ("%s: stack too big\n", thisfunc);

  if ( ! ptr) { /* Add a new entry and initialize */
    ptr = (Timer *) GPTLallocate (sizeof (Timer));
    memset (ptr, 0, sizeof (Timer));

    //pw    numchars = MIN (namelen, MAX_CHARS);
    //pw    strncpy (ptr->name, name, numchars);
    for (c = 0; c < numchars; c++) {
      ptr->name[c] = name[c];
    }
    ptr->name[numchars] = '\0';

    if (update_ll_hash (ptr, t, indx) != 0)
      return GPTLerror ("%s: update_ll_hash error\n", thisfunc);
  }

  if (update_parent_info (ptr, callstack[t], stackidx[t].val) != 0)
    return GPTLerror ("%s: update_parent_info error\n", thisfunc);

  if (update_ptr (ptr, t) != 0)
    return GPTLerror ("%s: update_ptr error\n", thisfunc);

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* second caliper timestamp */
      tpb = (*ptr2wtimefunc) ();
      /* subtract out additional overhead from caliper timing calls */
      overhead_est += ((tpb - tpa) - overhead_utr);
      /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
      overhead_bound += ((tpb - tpa) + 2*overhead_utr);
    }
  }

  return (0);
}

/*
** GPTLstartf_handle: start a timer based on a handle
**  when the timer name may not be null terminated
**
** Input arguments:
**   name:    timer name (required when on input, handle=0)
**   namelen: number of characters in timer name
**   handle:  pointer to timer matching "name"
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLstartf_handle (const char *name,  /* timer name */
                       const int namelen, /* timer name length */
		       void **handle)     /* handle (output if input value is 0) */
{
  Timer *ptr;                            /* linked list pointer */
  int t;                                 /* thread index (of this thread) */
  int c;                      /* character index */
  int numchars;                          /* number of characters to copy */
  unsigned int indx = (unsigned int) -1; /* hash table index: init to bad value */
  double tpa = 0.0;                      /* time stamp */
  double tpb = 0.0;                      /* time stamp */
  static const char *thisfunc = "GPTLstartf_handle";

  if (disabled)
    return 0;

  if ( ! initialized)
    return 0;

  if ((t = get_thread_num ()) < 0)
    return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

  /*
  ** If current depth exceeds a user-specified limit for print, just
  ** increment and return
  */

  if (stackidx[t].val >= depthlimit) {
    ++stackidx[t].val;
    return 0;
  }

  /*
  ** If prefix string is defined, then call GPTLstartf and
  ** return a handle of 0. Otherwise a change in the prefix
  ** might be ignored if the handle has already been set.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    *handle = 0;
    return GPTLstartf (name, namelen);
  }

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* first caliper timestamp */
      tpa = (*ptr2wtimefunc) ();
    }
  }

  /*
  ** If on input, handle references a non-zero value, assume it's a previously returned Timer*
  ** passed in by the user. If zero, generate the hash entry and return it to the user.
  */

  if (*handle) {
    ptr = (Timer *) *handle;
  } else {
    numchars = MIN (namelen, MAX_CHARS);
    ptr = getentryf (hashtable[t], name, numchars, &indx);
  }

  /*
  ** Recursion => increment depth in recursion and return.  We need to return
  ** because we don't want to restart the timer.  We want the reported time for
  ** the timer to reflect the outermost layer of recursion.
  */

  if (ptr && ptr->onflg) {
    ++ptr->recurselvl;

    if (wallstats.enabled && profileovhd.enabled){
      if (t == 0){
        /* second caliper timestamp */
        tpb = (*ptr2wtimefunc) ();
        /* subtract out additional overhead from caliper timing calls */
        overhead_est += ((tpb - tpa) - overhead_utr);
        /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
        overhead_bound += ((tpb - tpa) + 2*overhead_utr);
      }
    }

    return 0;
  }

  /*
  ** Increment stackidx[t] unconditionally. This is necessary to ensure the correct
  ** behavior when GPTLstop decrements stackidx[t] unconditionally.
  */

  if (++stackidx[t].val > MAX_STACK-1)
    return GPTLerror ("%s: stack too big\n", thisfunc);

  if ( ! ptr) { /* Add a new entry and initialize */
    ptr = (Timer *) GPTLallocate (sizeof (Timer));
    memset (ptr, 0, sizeof (Timer));

    numchars = MIN (namelen, MAX_CHARS);
    //pw    strncpy (ptr->name, name, numchars);
    for (c = 0; c < numchars; c++) {
      ptr->name[c] = name[c];
    }
    ptr->name[numchars] = '\0';

    if (update_ll_hash (ptr, t, indx) != 0)
      return GPTLerror ("%s: update_ll_hash error\n", thisfunc);
  }

  if (update_parent_info (ptr, callstack[t], stackidx[t].val) != 0)
    return GPTLerror ("%s: update_parent_info error\n", thisfunc);

  if (update_ptr (ptr, t) != 0)
    return GPTLerror ("%s: update_ptr error\n", thisfunc);

  /*
  ** If on input, *handle was 0, return the pointer to the timer for future input
  */

  if ( ! *handle)
    *handle = (void *) ptr;

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* second caliper timestamp */
      tpb = (*ptr2wtimefunc) ();
      /* subtract out additional overhead from caliper timing calls */
      overhead_est += ((tpb - tpa) - overhead_utr);
      /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
      overhead_bound += ((tpb - tpa) + 2*overhead_utr);
    }
  }

  return (0);
}

/*
** add_prefix: add prefix string to timer name
**
** Input arguments:
**   new_name:  new name 
**   timername: timer name
**   namelen:   length of timer name
**   t:         thread id
**
** Return value: length of new name
*/

static int add_prefix (char *new_name, const char *timername, const int namelen, const int t)
{
  int numchars;               /* number of characters to copy */
  int c;                      /* character index */

  /* add prefix from serial region */
  numchars = MIN (prefix_len_nt, MAX_CHARS);
  for (c = 0; c < numchars; c++) {
    new_name[c] = prefix_nt[c];
  }
    
  /* add thread-specific prefix */
  numchars = MIN (prefix_len[t], MAX_CHARS-prefix_len_nt);
  for (c = 0; c < numchars; c++) {
    new_name[c+prefix_len_nt] = prefix[t][c];
  }

  /* add timer name */
  numchars = MIN (namelen, MAX_CHARS-prefix_len_nt-prefix_len[t]);
  for (c = 0; c < numchars; c++) {
    new_name[c+prefix_len_nt+prefix_len[t]] = timername[c];
  }

  /* add string terminator */
  numchars = MIN (namelen+prefix_len_nt+prefix_len[t], MAX_CHARS);
  new_name[numchars] = '\0';

  return numchars;
}

/*
** update_ll_hash: Update linked list and hash table.
**                 Called by GPTLstart(f), GPTLstart_instr, 
**                 and GPTLstart(f)_handle.
**
** Input arguments:
**   ptr:  pointer to timer
**   t:    thread index
**   indx: hash index
**
** Return value: 0 (success) or GPTLerror (failure)
*/

static int update_ll_hash (Timer *ptr, const int t, const unsigned int indx)
{
  int nchars;      /* number of chars */
  int nument;      /* number of entries */
  Timer **eptr;    /* for realloc */

  nchars = strlen (ptr->name);
  if (nchars > max_name_len[t])
    max_name_len[t] = nchars;

  last[t]->next = ptr;
  last[t] = ptr;
  ++hashtable[t][indx].nument;
  nument = hashtable[t][indx].nument;

  eptr = (Timer **) realloc (hashtable[t][indx].entries, nument * sizeof (Timer *));
  if ( ! eptr)
    return GPTLerror ("update_ll_hash: realloc error\n");

  hashtable[t][indx].entries           = eptr;
  hashtable[t][indx].entries[nument-1] = ptr;

  return 0;
}

/*
** update_ptr: Update timer contents.
**  Called by GPTLstart(f), GPTLstart_instr, and GPTLstart(f)_handle.
**
** Input arguments:
**   ptr:  pointer to timer
**   t:    thread index
**
** Return value: 0 (success) or GPTLerror (failure)
*/

static inline int update_ptr (Timer *ptr, const int t)
{
  double tp2;    /* time stamp */

  ptr->onflg = true;

  if (cpustats.enabled && get_cpustamp (&ptr->cpu.last_utime, &ptr->cpu.last_stime) < 0)
    return GPTLerror ("update_ptr: get_cpustamp error");

  if (wallstats.enabled) {
    tp2 = (*ptr2wtimefunc) ();
    ptr->wall.last = tp2;
  }

#ifdef HAVE_PAPI
  if (dousepapi && GPTL_PAPIstart (t, &ptr->aux) < 0)
    return GPTLerror ("update_ptr: error from GPTL_PAPIstart\n");
#endif
  return 0;
}

/*
** update_parent_info: update info about parent, and in the parent about this child
**
** Arguments:
**   ptr:  pointer to timer
**   callstackt: callstack for this thread
**   stackidxt:  stack index for this thread
**
** Return value: 0 (success) or GPTLerror (failure)
*/

static inline int update_parent_info (Timer *ptr,
				      Timer **callstackt,
				      int stackidxt)
{
  int n;             /* loop index through known parents */
  Timer *pptr;       /* pointer to parent in callstack */
  Timer **pptrtmp;   /* for realloc parent pointer array */
  int nparent;       /* number of parents */
  int *parent_count; /* number of times parent invoked this child */
  static const char *thisfunc = "update_parent_info";

  if ( ! ptr )
    return -1;

  if (stackidxt < 0)
    return GPTLerror ("%s: called with negative stackidx\n", thisfunc);

  callstackt[stackidxt] = ptr;

  /*
  ** If the region has no parent, bump its orphan count
  ** (should never happen since "GPTL_ROOT" added).
  */

  if (stackidxt == 0) {
    ++ptr->norphan;
    return 0;
  }

  pptr = callstackt[stackidxt-1];

  /* If this parent occurred before, bump its count */

  for (n = 0; n < ptr->nparent; ++n) {
    if (ptr->parent[n] == pptr) {
      ++ptr->parent_count[n];
      break;
    }
  }

  /* If this is a new parent, update info */

  if (n == ptr->nparent) {
    ++ptr->nparent;
    nparent = ptr->nparent;
    pptrtmp = (Timer **) realloc (ptr->parent, nparent * sizeof (Timer *));
    if ( ! pptrtmp)
      return GPTLerror ("%s: realloc error pptrtmp nparent=%d\n", thisfunc, nparent);

    ptr->parent = pptrtmp;
    ptr->parent[nparent-1] = pptr;
    parent_count = (int *) realloc (ptr->parent_count, nparent * sizeof (int));
    if ( ! parent_count)
      return GPTLerror ("%s: realloc error parent_count nparent=%d\n", thisfunc, nparent);

    ptr->parent_count = parent_count;
    ptr->parent_count[nparent-1] = 1;
  }

  return 0;
}

/*
** GPTLstop_instr: stop a timer (auto-instrumented)
**
** Input arguments:
**   self: function address
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLstop_instr (void *self)
{
  double tp1 = 0.0;          /* time stamp */
  Timer *ptr;                /* linked list pointer */
  int t;                     /* thread number for this process */
  unsigned int indx;         /* index into hash table */
  long usr = 0;              /* user time (returned from get_cpustamp) */
  long sys = 0;              /* system time (returned from get_cpustamp) */
  static const char *thisfunc = "GPTLstop_instr";

  if (disabled)
    return 0;

  if ( ! initialized)
    return GPTLerror ("%s: GPTLinitialize has not been called\n", thisfunc);

  /* Get the timestamp */

  if (wallstats.enabled) {
    tp1 = (*ptr2wtimefunc) ();
  }

  if (cpustats.enabled && get_cpustamp (&usr, &sys) < 0)
    return GPTLerror ("%s: bad return from get_cpustamp\n", thisfunc);

  if ((t = get_thread_num ()) < 0)
    return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

  /*
  ** If current depth exceeds a user-specified limit for print, just
  ** decrement and return
  */

  if (stackidx[t].val > depthlimit) {
    --stackidx[t].val;
    return 0;
  }

  ptr = getentry_instr (hashtable[t], self, &indx);

  if ( ! ptr)
    return GPTLerror ("%s: timer for %p had not been started.\n", thisfunc, self);

  if ( ! ptr->onflg )
    return GPTLerror ("%s: timer %s was already off.\n", thisfunc, ptr->name);

  ++ptr->count;

  /*
  ** Recursion => decrement depth in recursion and return.  We need to return
  ** because we don't want to stop the timer.  We want the reported time for
  ** the timer to reflect the outermost layer of recursion.
  */

  if (ptr->recurselvl > 0) {
    ++ptr->nrecurse;
    --ptr->recurselvl;
    return 0;
  }

  if (update_stats (ptr, tp1, usr, sys, t) != 0)
    return GPTLerror ("%s: error from update_stats\n", thisfunc);

  return 0;
}

/*
** GPTLstop: stop a timer
**
** Input arguments:
**   timername: timer name
**
** Return value: 0 (success) or -1 (failure)
*/

int GPTLstop (const char *timername)         /* timer name */
{
  double tp1 = 0.0;           /* time stamp */
  Timer *ptr;                 /* linked list pointer */
  int t;                      /* thread number for this process */
  int numchars;               /* number of characters to copy */
  int namelen;                /* number of characters in timer name */
  int len_prefix;             /* number of characters in prefix */
  unsigned int indx;          /* index into hash table */
  long usr = 0;               /* user time (returned from get_cpustamp) */
  long sys = 0;               /* system time (returned from get_cpustamp) */
  double tpa = 0.0;           /* time stamp */
  double tpb = 0.0;           /* time stamp */
  char *ptr_prefix;           /* pointer to prefix string */
  char new_name[MAX_CHARS+1]; /* timer name with prefix, if there is one */
  const char *name;           /* pointer to timer name */
  static const char *thisfunc = "GPTLstop";

  if (disabled)
    return 0;

  if ( ! initialized)
    return 0;

  /* Get the timestamp */

  if (wallstats.enabled) {
    tp1 = (*ptr2wtimefunc) ();
  }

  if (cpustats.enabled && get_cpustamp (&usr, &sys) < 0)
    return GPTLerror ("%s: get_cpustamp error", thisfunc);

  if ((t = get_thread_num ()) < 0)
    return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

  /*
  ** If current depth exceeds a user-specified limit for print, just
  ** decrement and return
  */

  if (stackidx[t].val > depthlimit) {
    --stackidx[t].val;
    return 0;
  }

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* dummy clock call, to capture earlier tp1 call */
      tpa = (*ptr2wtimefunc) ();
    }
  }

  /*
  ** If prefix string is defined, prepend it to timername
  ** and assign the name pointer to the new string. 
  ** Otherwise assign the name pointer to the original string.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    namelen = strlen(timername);
    numchars = add_prefix(new_name, timername, namelen, t);
    name = new_name;
  } else {
    name = timername;
  }

  if ( ! (ptr = getentry (hashtable[t], name, &indx)))
    return GPTLerror ("%s thread %d: timer for %s had not been started.\n", thisfunc, t, name);

  if ( ! ptr->onflg )
    return GPTLerror ("%s: timer %s was already off.\n", thisfunc, ptr->name);

  ++ptr->count;

  /*
  ** Recursion => decrement depth in recursion and return.  We need to return
  ** because we don't want to stop the timer.  We want the reported time for
  ** the timer to reflect the outermost layer of recursion.
  */

  if (ptr->recurselvl > 0) {
    ++ptr->nrecurse;
    --ptr->recurselvl;

    if (wallstats.enabled && profileovhd.enabled){
      if (t == 0){
        /* second caliper timestamp */
        tpb = (*ptr2wtimefunc) ();
        /* subtract out additional overhead from caliper timing calls */
        overhead_est += ((tpb - tp1) - overhead_utr);
        /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
        overhead_bound += ((tpb - tp1) + 2*overhead_utr);
      }
    }

    return 0;
  }

  if (update_stats (ptr, tp1, usr, sys, t) != 0)
    return GPTLerror ("%s: error from update_stats\n", thisfunc);

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* second caliper timestamp */
      tpb = (*ptr2wtimefunc) ();
      /* subtract out additional overhead from caliper timing calls */
      overhead_est += ((tpb - tp1) - overhead_utr);
      /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
      overhead_bound += ((tpb - tp1) + 2*overhead_utr);
    }
  }

  return 0;
}

/*
** GPTLstop_handle: stop a timer based on a handle
**
** Input arguments:
**   name: timer name (used only for diagnostics)
**   handle: pointer to timer
**
** Return value: 0 (success) or -1 (failure)
*/

int GPTLstop_handle (const char *name,     /* timer name */
		     void **handle)        /* handle (output if input value is 0) */
{
  double tp1 = 0.0;          /* time stamp */
  Timer *ptr;                /* linked list pointer */
  int t;                     /* thread number for this process */
  unsigned int indx;         /* index into hash table */
  long usr = 0;              /* user time (returned from get_cpustamp) */
  long sys = 0;              /* system time (returned from get_cpustamp) */
  double tpa = 0.0;          /* time stamp */
  double tpb = 0.0;          /* time stamp */
  static const char *thisfunc = "GPTLstop_handle";

  if (disabled)
    return 0;

  if ( ! initialized)
    return 0;

  if ((t = get_thread_num ()) < 0)
    return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

  /*
  ** If prefix string is defined, then call GPTLstop and
  ** return a handle of 0. Otherwise a change in the prefix
  ** might be ignored if the handle has already been set.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    *handle = 0;
    return GPTLstop (name);
  }

  /* Get the timestamp */

  if (wallstats.enabled) {
    tp1 = (*ptr2wtimefunc) ();
  }

  if (cpustats.enabled && get_cpustamp (&usr, &sys) < 0)
    return GPTLerror (0);

  /*
  ** If current depth exceeds a user-specified limit for print, just
  ** decrement and return
  */

  if (stackidx[t].val > depthlimit) {
    --stackidx[t].val;
    return 0;
  }

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* dummy clock call, to capture earlier tp1 call */
      tpa = (*ptr2wtimefunc) ();
    }
  }

  /*
  ** If on input, handle references a non-zero value, assume it's a previously returned Timer*
  ** passed in by the user. If zero, generate the hash entry and return it to the user.
  */

  if (*handle) {
    ptr = (Timer *) *handle;
  } else {
    if ( ! (ptr = getentry (hashtable[t], name, &indx)))
    return GPTLerror ("%s thread %d: timer for %s had not been started.\n", thisfunc, t, name);
  }

  if ( ! ptr->onflg )
    return GPTLerror ("%s: timer %s was already off.\n", thisfunc, ptr->name);

  ++ptr->count;

  /*
  ** Recursion => decrement depth in recursion and return.  We need to return
  ** because we don't want to stop the timer.  We want the reported time for
  ** the timer to reflect the outermost layer of recursion.
  */

  if (ptr->recurselvl > 0) {
    ++ptr->nrecurse;
    --ptr->recurselvl;

    if (wallstats.enabled && profileovhd.enabled){
      if (t == 0){
        /* second caliper timestamp */
        tpb = (*ptr2wtimefunc) ();
        /* subtract out additional overhead from caliper timing calls */
        overhead_est += ((tpb - tp1) - overhead_utr);
        /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
        overhead_bound += ((tpb - tp1) + 2*overhead_utr);
      }
    }

    return 0;
  }

  if (update_stats (ptr, tp1, usr, sys, t) != 0)
    return GPTLerror ("%s: error from update_stats\n", thisfunc);

  /*
  ** If on input, *handle was 0, return the pointer to the timer for future input
  */

  if ( ! *handle)
    *handle = (void *) ptr;

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* second caliper timestamp */
      tpb = (*ptr2wtimefunc) ();
      /* subtract out additional overhead from caliper timing calls */
      overhead_est += ((tpb - tp1) - overhead_utr);
      /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
      overhead_bound += ((tpb - tp1) + 2*overhead_utr);
    }
  }

  return 0;
}

/*
** GPTLstopf: stop a timer when the timer name may not be null terminated
**
** Input arguments:
**   timername: timer name
**   namelen:   number of characters in timer name
**
** Return value: 0 (success) or -1 (failure)
*/

int GPTLstopf (const char *timername, const int namelen) /* timer name and length */
{
  double tp1 = 0.0;           /* time stamp */
  Timer *ptr;                 /* linked list pointer */
  int t;                      /* thread number for this process */
  int c;                      /* character index */
  int numchars;               /* number of characters to copy */
  unsigned int indx;          /* index into hash table */
  long usr = 0;               /* user time (returned from get_cpustamp) */
  long sys = 0;               /* system time (returned from get_cpustamp) */
  char strname[MAX_CHARS+1];  /* null terminated version of name */
  double tpa = 0.0;           /* time stamp */
  double tpb = 0.0;           /* time stamp */
  char new_name[MAX_CHARS+1]; /* timer name with prefix, if there is one */
  const char *name;           /* pointer to timer name */
  static const char *thisfunc = "GPTLstopf";

  if (disabled)
    return 0;

  if ( ! initialized)
    return 0;

  /* Get the timestamp */

  if (wallstats.enabled) {
    tp1 = (*ptr2wtimefunc) ();
  }

  if (cpustats.enabled && get_cpustamp (&usr, &sys) < 0)
    return GPTLerror ("%s: get_cpustamp error", thisfunc);

  if ((t = get_thread_num ()) < 0)
    return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

  /*
  ** If current depth exceeds a user-specified limit for print, just
  ** decrement and return
  */

  if (stackidx[t].val > depthlimit) {
    --stackidx[t].val;
    return 0;
  }

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* dummy clock call, to capture earlier tp1 call */
      tpa = (*ptr2wtimefunc) ();
    }
  }

  /*
  ** If prefix string is defined, prepend it to timername
  ** and assign the name pointer to the new string. 
  ** Otherwise assign the name pointer to the original string.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    numchars = add_prefix(new_name, timername, namelen, t);
    name = new_name;
  } else {
    numchars = MIN (namelen, MAX_CHARS);
    name = timername;
  }

  if ( ! (ptr = getentryf (hashtable[t], name, numchars, &indx))){
    //pw    numchars = MIN (namelen, MAX_CHARS);
    //pw    strncpy (strname, name, numchars);
    for (c = 0; c < numchars; c++) {
      strname[c] = name[c];
    }
    strname[numchars] = '\0';
    return GPTLerror ("%s thread %d: timer for %s had not been started.\n", thisfunc, t, strname);
  }

  if ( ! ptr->onflg )
    return GPTLerror ("%s: timer %s was already off.\n", thisfunc, ptr->name);

  ++ptr->count;

  /*
  ** Recursion => decrement depth in recursion and return.  We need to return
  ** because we don't want to stop the timer.  We want the reported time for
  ** the timer to reflect the outermost layer of recursion.
  */

  if (ptr->recurselvl > 0) {
    ++ptr->nrecurse;
    --ptr->recurselvl;

    if (wallstats.enabled && profileovhd.enabled){
      if (t == 0){
        /* second caliper timestamp */
        tpb = (*ptr2wtimefunc) ();
        /* subtract out additional overhead from caliper timing calls */
        overhead_est += ((tpb - tp1) - overhead_utr);
        /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
        overhead_bound += ((tpb - tp1) + 2*overhead_utr);
      }
    }

    return 0;
  }

  if (update_stats (ptr, tp1, usr, sys, t) != 0)
    return GPTLerror ("%s: error from update_stats\n", thisfunc);

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* second caliper timestamp */
      tpb = (*ptr2wtimefunc) ();
      /* subtract out additional overhead from caliper timing calls */
      overhead_est += ((tpb - tp1) - overhead_utr);
      /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
      overhead_bound += ((tpb - tp1) + 2*overhead_utr);
    }
  }

  return 0;
}

/*
** GPTLstopf_handle: stop a timer based on a handle
**  when the timer name may not be null terminated
**
** Input arguments:
**   name: timer name (used only for diagnostics)
**   namelen: number of characters in timer name
**   handle: pointer to timer
**
** Return value: 0 (success) or -1 (failure)
*/

int GPTLstopf_handle (const char *name,     /* timer name */
                      const int namelen,    /* timer name length */
                      void **handle)        /* handle (output if input value is 0) */
{
  double tp1 = 0.0;          /* time stamp */
  Timer *ptr;                /* linked list pointer */
  int t;                     /* thread number for this process */
  int c;                      /* character index */
  unsigned int indx;         /* index into hash table */
  long usr = 0;              /* user time (returned from get_cpustamp) */
  long sys = 0;              /* system time (returned from get_cpustamp) */
  int numchars;              /* number of characters to copy */
  char strname[MAX_CHARS+1]; /* null terminated version of name */
  double tpa = 0.0;          /* time stamp */
  double tpb = 0.0;          /* time stamp */
  static const char *thisfunc = "GPTLstopf_handle";

  if (disabled)
    return 0;

  if ( ! initialized)
    return 0;

  if ((t = get_thread_num ()) < 0)
    return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

  /*
  ** If prefix string is defined, then call GPTLstopf and
  ** return a handle of 0. Otherwise a change in the prefix
  ** might be ignored if the handle has already been set.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    *handle = 0;
    return GPTLstopf (name, namelen);
  }

  /* Get the timestamp */

  if (wallstats.enabled) {
    tp1 = (*ptr2wtimefunc) ();
  }

  if (cpustats.enabled && get_cpustamp (&usr, &sys) < 0)
    return GPTLerror (0);

  /*
  ** If current depth exceeds a user-specified limit for print, just
  ** decrement and return
  */

  if (stackidx[t].val > depthlimit) {
    --stackidx[t].val;
    return 0;
  }

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* dummy clock call, to capture earlier tp1 call */
      tpa = (*ptr2wtimefunc) ();
    }
  }

  /*
  ** If on input, handle references a non-zero value, assume it's a previously returned Timer*
  ** passed in by the user. If zero, generate the hash entry and return it to the user.
  */

  if (*handle) {
    ptr = (Timer *) *handle;
  } else {
    if ( ! (ptr = getentryf (hashtable[t], name, namelen, &indx))){
      numchars = MIN (namelen, MAX_CHARS);
      //pw      strncpy (strname, name, numchars);
      for (c = 0; c < numchars; c++) {
        strname[c] = name[c];
      }
      strname[numchars] = '\0';
      return GPTLerror ("%s thread %d: timer for %s had not been started.\n", thisfunc, t, strname);
    }
  }

  if ( ! ptr->onflg )
    return GPTLerror ("%s: timer %s was already off.\n", thisfunc, ptr->name);

  ++ptr->count;

  /*
  ** Recursion => decrement depth in recursion and return.  We need to return
  ** because we don't want to stop the timer.  We want the reported time for
  ** the timer to reflect the outermost layer of recursion.
  */

  if (ptr->recurselvl > 0) {
    ++ptr->nrecurse;
    --ptr->recurselvl;

    if (wallstats.enabled && profileovhd.enabled){
      if (t == 0){
        /* second caliper timestamp */
        tpb = (*ptr2wtimefunc) ();
        /* subtract out additional overhead from caliper timing calls */
        overhead_est += ((tpb - tp1) - overhead_utr);
        /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
        overhead_bound += ((tpb - tp1) + 2*overhead_utr);
      }
    }

    return 0;
  }

  if (update_stats (ptr, tp1, usr, sys, t) != 0)
    return GPTLerror ("%s: error from update_stats\n", thisfunc);

  /*
  ** If on input, *handle was 0, return the pointer to the timer for future input
  */

  if ( ! *handle)
    *handle = (void *) ptr;

  if (wallstats.enabled && profileovhd.enabled){
    if (t == 0){
      /* second caliper timestamp */
      tpb = (*ptr2wtimefunc) ();
      /* subtract out additional overhead from caliper timing calls */
      overhead_est += ((tpb - tp1) - overhead_utr);
      /* add in additional overhead due to caliper timing calls (probaby 2X what necessary) */
      overhead_bound += ((tpb - tp1) + 2*overhead_utr);
    }
  }

  return 0;
}

/*
** update_stats: update stats inside ptr. Called by GPTLstop(f), GPTLstop_instr,
**               GPTLstop(f)_handle
**
** Input arguments:
**   ptr: pointer to timer
**   tp1: input time stapm
**   usr: user time
**   sys: system time
**   t: thread index
**
** Return value: 0 (success) or GPTLerror (failure)
*/

static inline int update_stats (Timer *ptr,
				const double tp1,
				const long usr,
				const long sys,
				const int t)
{
  double delta;       /* difference */
  static const char *thisfunc = "update_stats";

  ptr->onflg = false;
  --stackidx[t].val;
  if (stackidx[t].val < -1) {
    stackidx[t].val = -1;
    return GPTLerror ("%s: tree depth has become negative.\n", thisfunc);
  }

#ifdef HAVE_PAPI
  if (dousepapi && GPTL_PAPIstop (t, &ptr->aux) < 0)
    return GPTLerror ("%s: error from GPTL_PAPIstop\n", thisfunc);
#endif

  if (wallstats.enabled) {
    delta = tp1 - ptr->wall.last;

    if (delta < 0.) {
      fprintf (stderr, "%s: negative delta=%g\n", thisfunc, delta);
      delta = 0.0;
    }

    ptr->wall.accum += delta;
    ptr->wall.latest = delta;

    if (ptr->count == 1) {
      ptr->wall.max = delta;

      ptr->wall.prev_min = FLT_MAX;
      ptr->wall.min = delta;
      ptr->wall.latest_is_min = 1;
    } else {
      if (delta > ptr->wall.max)
	ptr->wall.max = delta;
      if (delta < ptr->wall.min){
        ptr->wall.prev_min = ptr->wall.min;
	ptr->wall.min = delta;
        ptr->wall.latest_is_min = 1;
      } else {
        ptr->wall.latest_is_min = 0;
      }
    }
  }

  if (cpustats.enabled) {
    ptr->cpu.accum_utime += usr - ptr->cpu.last_utime;
    ptr->cpu.accum_stime += sys - ptr->cpu.last_stime;
    ptr->cpu.last_utime   = usr;
    ptr->cpu.last_stime   = sys;
  }
  return 0;
}

/*
** GPTLenable: enable timers
**
** Return value: 0 (success)
*/

int GPTLenable (void)
{
  disabled = false;
  return (0);
}

/*
** GPTLdisable: disable timers
**
** Return value: 0 (success)
*/

int GPTLdisable (void)
{
  disabled = true;
  return (0);
}

/*
** GPTLstamp: Compute timestamp of usr, sys, and wallclock time (seconds)
**
** Output arguments:
**   wall: wallclock
**   usr:  user time
**   sys:  system time
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLstamp (double *wall, double *usr, double *sys)
{
  struct tms buf;            /* argument to times */

  if ( ! initialized)
    return GPTLerror ("GPTLstamp: GPTLinitialize has not been called\n");

#ifdef HAVE_TIMES
  *usr = 0;
  *sys = 0;

  if (times (&buf) == -1)
    return GPTLerror ("GPTLstamp: times() failed. Results bogus\n");

  *usr = buf.tms_utime / (double) ticks_per_sec;
  *sys = buf.tms_stime / (double) ticks_per_sec;
#endif
  *wall = (*ptr2wtimefunc) ();
  return 0;
}

/*
** GPTLreset: reset all timers to 0
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLreset (void)
{
  int t;             /* index over threads */
  Timer *ptr;        /* linked list index */
  static const char *thisfunc = "GPTLreset";

  if ( ! initialized)
    return GPTLerror ("%s: GPTLinitialize has not been called\n", thisfunc);

  for (t = 0; t < nthreads; t++) {
    for (ptr = timers[t]; ptr; ptr = ptr->next) {
      ptr->onflg = false;
      ptr->count = 0;
      memset (&ptr->wall, 0, sizeof (ptr->wall));
      memset (&ptr->cpu, 0, sizeof (ptr->cpu));
#ifdef HAVE_PAPI
      memset (&ptr->aux, 0, sizeof (ptr->aux));
#endif
    }
  }

  if (verbose)
    printf ("%s: accumulators for all timers set to zero\n", thisfunc);

  return 0;
}

/*
** GPTLprint_mode_set: set output mode to use for
** GPTLpr_file and GPTLpr_summary_file
*/

int GPTLprint_mode_set (int pr_mode)
{
  print_mode = (PRMode) pr_mode;
  return 0;
}

/*
** GPTLprint_mode_query: query output mode used
** for GPTLpr_file and GPTLpr_summary_file
*/

int GPTLprint_mode_query (void)
{
  return (int) print_mode;
}

/*
** GPTLpr: Print values of all timers
**
** Input arguments:
**   id: integer to append to string "timing."
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLpr (const int id)   /* output file will be named "timing.<id>" */
{
  char outfile[14];         /* name of output file: timing.xxxxxx */
  static const char *thisfunc = "GPTLpr";

  if (id < 0 || id > 999999)
    return GPTLerror ("%s: bad id=%d for output file. Must be >= 0 and < 1000000\n", thisfunc, id);

  sprintf (outfile, "timing.%d", id);

  if (GPTLpr_file (outfile) != 0)
    return GPTLerror ("%s: Error in GPTLpr_file\n", thisfunc);

  return 0;
}

/*
** GPTLpr_file: Print values of all timers
**
** Input arguments:
**   outfile: Name of output file to write
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLpr_file (const char *outfile) /* output file to write */
{
  FILE *fp;                 /* file handle to write to */
  Timer *ptr;               /* walk through master thread linked list */
  Timer *tptr;              /* walk through slave threads linked lists */
  Timer sumstats;           /* sum of same timer stats over threads */
  int i, ii, n, t;          /* indices */
  int totent;               /* per-thread collision count (diagnostic) */
  int nument;               /* per-index collision count (diagnostic) */
  int totlen;               /* length for malloc */
  unsigned long totcount;   /* total timer invocations */
  char *outpath;            /* path to output file: outdir/timing.xxxxxx */
  float *sum;               /* sum of overhead values (per thread) */
  float osum;               /* sum of overhead over threads */
  double utr_overhead;      /* overhead of calling underlying timing routine */
  double tot_overhead;      /* utr_overhead + papi overhead */
  double papi_overhead = 0; /* overhead of reading papi counters */
  bool found;               /* jump out of loop when name found */
  bool foundany;            /* whether summation print necessary */
  bool first;               /* flag 1st time entry found */
  /*
  ** Diagnostics for collisions and GPTL memory usage
  */
  int num_zero;             /* number of buckets with 0 collisions */
  int num_one;              /* number of buckets with 1 collision */
  int num_two;              /* number of buckets with 2 collisions */
  int num_more;             /* number of buckets with more than 2 collisions */
  int most;                 /* biggest collision count */
  int numtimers = 0;        /* number of timers */
  float hashmem;            /* hash table memory usage */
  float regionmem;          /* timer memory usage */
  float papimem;            /* PAPI stats memory usage */
  float pchmem;             /* parent/child array memory usage */
  float gptlmem;            /* total per-thread GPTL memory usage estimate */
  float totmem;             /* sum of gptlmem across threads */

  static const char *thisfunc = "GPTLpr_file";

  if ( ! initialized)
    return GPTLerror ("%s: GPTLinitialize() has not been called\n", thisfunc);

  /* 2 is for "/" plus null */
  if (outdir)
    totlen = strlen (outdir) + strlen (outfile) + 2;
  else
    totlen = strlen (outfile) + 2;

  outpath = (char *) GPTLallocate (totlen);

  if (outdir) {
     strcpy (outpath, outdir);
     strcat (outpath, "/");
     strcat (outpath, outfile);
  } else {
     strcpy (outpath, outfile);
  }

  if (print_mode == GPTLprint_append){
    if ( ! (fp = fopen (outpath, "a")))
      fp = stderr;
  }
  else{
    if ( ! (fp = fopen (outpath, "w")))
      fp = stderr;
  }

  free (outpath);

  fprintf (fp, "$Id: gptl.c,v 1.157 2011-03-28 20:55:18 rosinski Exp $\n");

  /*
  ** A set of nasty ifdefs to tell important aspects of how GPTL was built
  */

#ifdef HAVE_NANOTIME
  if (funclist[funcidx].option == GPTLnanotime) {
    fprintf (fp, "Clock rate = %f MHz\n", cpumhz);
#ifdef BIT64
    fprintf (fp, "  BIT64 was true\n");
#else
    fprintf (fp, "  BIT64 was false\n");
#endif
  }
#endif

#if ( defined THREADED_OMP )
  fprintf (fp, "GPTL was built with THREADED_OMP\n");
#elif ( defined THREADED_PTHREADS )
  fprintf (fp, "GPTL was built with THREADED_PTHREADS\n");
#else
  fprintf (fp, "GPTL was built without threading\n");
#endif

#ifdef HAVE_MPI
  fprintf (fp, "HAVE_MPI was true\n");

#ifdef HAVE_COMM_F2C
  fprintf (fp, "  HAVE_COMM_F2C was true\n");
#else
  fprintf (fp, "  HAVE_COMM_F2C was false\n");
#endif

#ifdef ENABLE_PMPI
  fprintf (fp, "  ENABLE_PMPI was true\n");
#else
  fprintf (fp, "  ENABLE_PMPI was false\n");
#endif

#else
  fprintf (fp, "HAVE_MPI was false\n");
#endif

#ifdef HAVE_PAPI
  fprintf (fp, "HAVE_PAPI was true\n");
  if (dousepapi) {
    if (GPTL_PAPIis_multiplexed ())
      fprintf (fp, "  PAPI event multiplexing was ON\n");
    else
      fprintf (fp, "  PAPI event multiplexing was OFF\n");
    GPTL_PAPIprintenabled (fp);
  }
#else
  fprintf (fp, "HAVE_PAPI was false\n");
#endif

  /*
  ** Estimate underlying timing routine overhead
  */

  utr_overhead = utr_getoverhead ();
  fprintf (fp, "Underlying timing routine was %s.\n", funclist[funcidx].name);
  if (wallstats.enabled && profileovhd.enabled){
    fprintf (fp, "Per-call utr overhead est (at init): %g sec.\n", overhead_utr);
    fprintf (fp, "Per-call utr overhead est (at end): %g sec.\n", utr_overhead);
  } else {
    fprintf (fp, "Per-call utr overhead est: %g sec.\n", utr_overhead);
  }
#ifdef HAVE_PAPI
  if (dousepapi) {
    double t1, t2;
    t1 = (*ptr2wtimefunc) ();
    read_counters100 ();
    t2 = (*ptr2wtimefunc) ();
    papi_overhead = 0.01 * (t2 - t1);
    fprintf (fp, "Per-call PAPI overhead est: %g sec.\n", papi_overhead);
  }
#endif
  tot_overhead = utr_overhead + papi_overhead;
  if (dopr_preamble) {
    fprintf (fp, "If overhead stats are printed, roughly half the estimated number is\n"
	     "embedded in the wallclock stats for each timer.\n"
	     "Print method was %s.\n", methodstr (method));
#ifdef ENABLE_PMPI
    fprintf (fp, "If a AVG_MPI_BYTES field is present, it is an estimate of the per-call "
	     "average number of bytes handled by that process.\n"
	     "If timers beginning with sync_ are present, it means MPI synchronization "
	     "was turned on.\n");
#endif
    fprintf (fp, "If a \'%%_of\' field is present, it is w.r.t. the first timer for thread 0.\n"
	     "If a \'e6_per_sec\' field is present, it is in millions of PAPI counts per sec.\n\n"
	     "A '*' in column 1 below means the timer had multiple parents, though the\n"
	     "values printed are for all calls.\n"
	     "Further down the listing may be more detailed information about multiple\n"
	     "parents. Look for 'Multiple parent info'\n\n");
  }

  sum = (float *) GPTLallocate (nthreads * sizeof (float));

  for (t = 0; t < nthreads; ++t) {

    /*
    ** Construct tree for printing timers in parent/child form. get_max_depth() must be called
    ** AFTER construct_tree() because it relies on the per-parent children arrays being complete.
    */

    if (construct_tree (timers[t], method) != 0)
      printf ("GPTLpr_file: failure from construct_tree: output will be incomplete\n");
    max_depth[t] = get_max_depth (timers[t], 0);

    if (t > 0)
      fprintf (fp, "\n");
    fprintf (fp, "Stats for thread %d:\n", t);

    for (n = 0; n < max_depth[t]+1; ++n)    /* +1 to always indent timer name */
      fprintf (fp, "  ");
    if (dopr_quotes){
      for (n = 0; n < max_name_len[t]+2; ++n) /* longest timer name + quotes */
        fprintf (fp, " ");
    } else {
      for (n = 0; n < max_name_len[t]; ++n)   /* longest timer name */
        fprintf (fp, " ");
    }

    fprintf (fp, " On  Called Recurse");

    /* Print strings for enabled timer types */

    if (cpustats.enabled)
      fprintf (fp, "%s", cpustats.str);
    if (wallstats.enabled) {
      fprintf (fp, "%s", wallstats.str);
      if (percent && timers[0]->next)
	fprintf (fp, "%%_of_%5.5s ", timers[0]->next->name);
      if (overheadstats.enabled)
	fprintf (fp, "%s", overheadstats.str);
    }

#ifdef ENABLE_PMPI
    fprintf (fp, "AVG_MPI_BYTES ");
#endif

#ifdef HAVE_PAPI
    GPTL_PAPIprstr (fp);
#endif

    fprintf (fp, "\n");        /* Done with titles, now print stats */

    /*
    ** Print call tree and stats via recursive routine. "-1" is flag to
    ** avoid printing dummy outermost timer, and initialize the depth.
    */

    printself_andchildren (timers[t], fp, t, -1, tot_overhead);

    /*
    ** Sum of overhead across timers is meaningful.
    ** Factor of 2 is because there are 2 utr calls per start/stop pair.
    */

    sum[t]     = 0;
    totcount   = 0;
    for (ptr = timers[t]->next; ptr; ptr = ptr->next) {
      sum[t]     += ptr->count * 2 * tot_overhead;
      totcount   += ptr->count;
    }
    fprintf (fp, "\n");
    if (wallstats.enabled && overheadstats.enabled){
      fprintf (fp, "Overhead sum = %9.3g wallclock seconds\n", sum[t]);
    }
    if (t == 0){
      if (wallstats.enabled && profileovhd.enabled){
        fprintf (fp, "Overhead estimate = %9.3g wallclock seconds\n", overhead_est);
        fprintf (fp, "Overhead bound = %9.3g wallclock seconds\n", overhead_bound);
      }
    }
    if (totcount < PRTHRESH)
      fprintf (fp, "Total calls  = %lu\n", totcount);
    else
      fprintf (fp, "Total calls  = %9.3e\n", (float) totcount);
  }

  /* Print per-name stats for all threads */

  if (dopr_threadsort && nthreads > 1) {
    fprintf (fp, "\nSame stats sorted by timer for threaded regions (for timers active on thread 0):\n");
    fprintf (fp, "Thd ");

    for (n = 0; n < max_name_len[0]; ++n) /* longest timer name */
      fprintf (fp, " ");

    fprintf (fp, " On  Called Recurse");

    if (cpustats.enabled)
      fprintf (fp, "%s", cpustats.str);
    if (wallstats.enabled) {
      fprintf (fp, "%s", wallstats.str);
      if (percent && timers[0]->next)
	fprintf (fp, "%%_of_%5.5s ", timers[0]->next->name);
      if (overheadstats.enabled)
	fprintf (fp, "%s", overheadstats.str);
    }

#ifdef HAVE_PAPI
    GPTL_PAPIprstr (fp);
#endif

    fprintf (fp, "\n");

    /* Start at next to skip dummy */

    for (ptr = timers[0]->next; ptr; ptr = ptr->next) {

      /*
      ** To print sum stats, first create a new timer then copy thread 0
      ** stats into it. then sum using "add", and finally print.
      */

      foundany = false;
      first = true;
      sumstats = *ptr;
      for (t = 1; t < nthreads; ++t) {
	found = false;
	for (tptr = timers[t]->next; tptr && ! found; tptr = tptr->next) {
	  if (STRMATCH (ptr->name, tptr->name)) {

	    /* Only print thread 0 when this timer found for other threads */

	    if (first) {
	      first = false;
	      fprintf (fp, "%3.3d ", 0);
	      printstats (ptr, fp, 0, 0, false, tot_overhead);
	    }

	    found = true;
	    foundany = true;
	    fprintf (fp, "%3.3d ", t);
	    printstats (tptr, fp, 0, 0, false, tot_overhead);
	    add (&sumstats, tptr);
	  }
	}
      }

      if (foundany) {
	fprintf (fp, "SUM ");
	printstats (&sumstats, fp, 0, 0, false, tot_overhead);
	fprintf (fp, "\n");
      }
    }

    /* Repeat overhead print in loop over threads */

    if (wallstats.enabled && overheadstats.enabled) {
      osum = 0.;
      for (t = 0; t < nthreads; ++t) {
	fprintf (fp, "OVERHEAD.%3.3d (wallclock seconds) = %9.3g\n", t, sum[t]);
	osum += sum[t];
      }
      fprintf (fp, "OVERHEAD.SUM (wallclock seconds) = %9.3g\n", osum);
    }
  }

  /* Print info about timers with multiple parents */

  if (dopr_multparent) {
    for (t = 0; t < nthreads; ++t) {
      bool some_multparents = false;   /* thread has entries with multiple parents? */
      for (ptr = timers[t]->next; ptr; ptr = ptr->next) {
	if (ptr->nparent > 1) {
	  some_multparents = true;
	  break;
	}
      }

      if (some_multparents) {
	fprintf (fp, "\nMultiple parent info for thread %d:\n", t);
	if (dopr_preamble && t == 0) {
	  fprintf (fp, "Columns are count and name for the listed child\n"
		   "Rows are each parent, with their common child being the last entry, "
		   "which is indented.\n"
		   "Count next to each parent is the number of times it called the child.\n"
		   "Count next to child is total number of times it was called by the "
		   "listed parents.\n\n");
	}

	for (ptr = timers[t]->next; ptr; ptr = ptr->next)
	  if (ptr->nparent > 1)
	    print_multparentinfo (fp, ptr);
      }
    }
  }

  /* Print hash table stats */

  if (dopr_collision) {
    for (t = 0; t < nthreads; t++) {
      first = true;
      totent   = 0;
      num_zero = 0;
      num_one  = 0;
      num_two  = 0;
      num_more = 0;
      most     = 0;
      numtimers= 0;

      for (i = 0; i < tablesize; i++) {
	nument = hashtable[t][i].nument;
	if (nument > 1) {
	  totent += nument-1;
	  if (first) {
	    first = false;
	    fprintf (fp, "\nthread %d had some hash collisions:\n", t);
	  }
	  fprintf (fp, "hashtable[%d][%d] had %d entries:", t, i, nument);
	  for (ii = 0; ii < nument; ii++)
	    fprintf (fp, " %s", hashtable[t][i].entries[ii]->name);
	  fprintf (fp, "\n");
	}
	switch (nument) {
	case 0:
	  ++num_zero;
	  break;
	case 1:
	  ++num_one;
	  break;
	case 2:
	  ++num_two;
	  break;
	default:
	  ++num_more;
	  break;
	}
	most = MAX (most, nument);
	numtimers += nument;
      }

      if (totent > 0) {
	fprintf (fp, "Total collisions thread %d = %d\n", t, totent);
	fprintf (fp, "Entry information:\n");
	fprintf (fp, "num_zero = %d num_one = %d num_two = %d num_more = %d\n",
		 num_zero, num_one, num_two, num_more);
	fprintf (fp, "Most = %d\n", most);
      }
    }
  }

  /* Stats on GPTL memory usage */

  totmem = 0.;
  for (t = 0; t < nthreads; t++) {
    hashmem = (float) sizeof (Hashentry) * tablesize;
    regionmem = (float) numtimers * sizeof (Timer);
#ifdef HAVE_PAPI
    papimem = (float) numtimers * sizeof (Papistats);
#else
    papimem = 0.;
#endif
    pchmem = 0.;
    for (ptr = timers[t]->next; ptr; ptr = ptr->next)
      pchmem += (float) (sizeof (Timer *)) * (ptr->nchildren + ptr->nparent);

    gptlmem = hashmem + regionmem + pchmem;
    totmem += gptlmem;
    fprintf (fp, "\n");
    fprintf (fp, "Thread %d total memory usage = %g KB\n", t, gptlmem*.001);
    fprintf (fp, "  Hashmem                   = %g KB\n"
	         "  Regionmem                 = %g KB (papimem portion = %g KB)\n"
	         "  Parent/child arrays       = %g KB\n",
	     hashmem*.001, regionmem*.001, papimem*.001, pchmem*.001);
  }
  fprintf (fp, "\n");
  fprintf (fp, "Total memory usage all threads = %g KB\n", totmem*0.001);

  print_threadmapping (fp);
  free (sum);

  if (fclose (fp) != 0)
    fprintf (stderr, "Attempt to close %s failed\n", outfile);

  pr_has_been_called = true;
  return 0;
}

/*
** construct_tree: Build the parent->children tree starting with knowledge of
**                 parent list for each child.
**
** Input arguments:
**   timerst: Linked list of timers
**   method:  method to be used to define the links
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int construct_tree (Timer *timerst, Method method)
{
  Timer *ptr;       /* loop through linked list */
  Timer *pptr = 0;  /* parent (init to NULL to avoid compiler warning) */
  int nparent;      /* number of parents */
  int maxcount;     /* max calls by a single parent */
  int n;            /* loop over nparent */

  /*
  ** Walk the linked list to build the parent-child tree, using whichever
  ** mechanism is in place. newchild() will prevent loops.
  */

  for (ptr = timerst; ptr; ptr = ptr->next) {
    switch (method) {
    case GPTLfirst_parent:
      if (ptr->nparent > 0) {
	pptr = ptr->parent[0];
	if (newchild (pptr, ptr) != 0);
      }
      break;
    case GPTLlast_parent:
      if (ptr->nparent > 0) {
	nparent = ptr->nparent;
	pptr = ptr->parent[nparent-1];
	if (newchild (pptr, ptr) != 0);
      }
      break;
    case GPTLmost_frequent:
      maxcount = 0;
      for (n = 0; n < ptr->nparent; ++n) {
	if (ptr->parent_count[n] > maxcount) {
	  pptr = ptr->parent[n];
	  maxcount = ptr->parent_count[n];
	}
      }
      if (maxcount > 0) {   /* not an orphan */
	if (newchild (pptr, ptr) != 0);
      }
      break;
    case GPTLfull_tree:
      /*
      ** Careful: this one can create *lots* of output!
      */
      for (n = 0; n < ptr->nparent; ++n) {
	pptr = ptr->parent[n];
	if (newchild (pptr, ptr) != 0);
      }
      break;
    default:
      return GPTLerror ("construct_tree: method %d is not known\n", method);
    }
  }
  return 0;
}

/* 
** modestr: Return a pointer to a string that represents the mode
**
** Input arguments:
**   mode: print mode type (write or append)
*/
static char *modestr (PRMode prmode)
{
  if (prmode == GPTLprint_write)
    return "write";
  else if (prmode == GPTLprint_append)
    return "append";
  else
    return "Unknown";
}

/*
** methodstr: Return a pointer to a string which represents the method
**
** Input arguments:
**   method: method type
*/

static char *methodstr (Method method)
{
  if (method == GPTLfirst_parent)
    return "first_parent";
  else if (method == GPTLlast_parent)
    return "last_parent";
  else if (method == GPTLmost_frequent)
    return "most_frequent";
  else if (method == GPTLfull_tree)
    return "full_tree";
  else
    return "Unknown";
}

/*
** newchild: Add an entry to the children list of parent. Use function
**   is_descendant() to prevent infinite loops.
**
** Input arguments:
**   parent: parent node
**   child:  child to be added
**
** Return value: 0 (success) or GPTLerror (failure)
*/

static int newchild (Timer *parent, Timer *child)
{
  int nchildren;     /* number of children (temporary) */
  Timer **chptr;     /* array of pointers to children */
  int n;             /* loop over nchildren */

  static const char *thisfunc = "newchild";

  if (parent == child)
    return GPTLerror ("%s: child %s can't be a parent of itself\n", thisfunc, child->name);

  /*
  ** To allow construct_tree to be called multiple times, check that proposed child
  ** is not a known child
  */

  for (n = 0; n < parent->nchildren; ++n) {
     if (parent->children[n] == child){
        n = parent->nchildren + 1;
     }
  }
  if (n > parent->nchildren){
    return 0;
  }

  /*
  ** To guarantee no loops, ensure that proposed parent isn't already a descendant of
  ** proposed child
  */

  if (is_descendant (child, parent)) {
    show_descendant (0, child, parent);
    return GPTLerror ("%s: loop detected: NOT adding %s to descendant list of %s. "
		      "Proposed parent is in child's descendant path.\n",
		      thisfunc, child->name, parent->name);
  }

  /* Safe to add the child to the parent's list of children */

  ++parent->nchildren;
  nchildren = parent->nchildren;
  chptr = (Timer **) realloc (parent->children, nchildren * sizeof (Timer *));
  if ( ! chptr)
    return GPTLerror ("%s: realloc error\n", thisfunc);
  parent->children = chptr;
  parent->children[nchildren-1] = child;

  return 0;
}

/*
** get_max_depth: Determine the maximum call tree depth by traversing the
**   tree recursively
**
** Input arguments:
**   ptr:        Starting timer
**   startdepth: current depth when function invoked
**
** Return value: maximum depth
*/

static int get_max_depth (const Timer *ptr, const int startdepth)
{
  int maxdepth = startdepth;
  int depth;
  int n;

  for (n = 0; n < ptr->nchildren; ++n)
    if ((depth = get_max_depth (ptr->children[n], startdepth+1)) > maxdepth)
      maxdepth = depth;

  return maxdepth;
}

/*
** num_descendants: Determine the number of descendants of a timer by traversing
**   the tree recursively. This function is not currently used. It could be
**   useful in a pruning algorithm
**
** Input arguments:
**   ptr: Starting timer
**
** Return value: number of descendants
*/

static int num_descendants (Timer *ptr)
{
  int n;

  ptr->num_desc = ptr->nchildren;
  for (n = 0; n < ptr->nchildren; ++n) {
    ptr->num_desc += num_descendants (ptr->children[n]);
  }
  return ptr->num_desc;
}

/*
** is_descendant: Determine whether node2 is in the descendant list for
**   node1
**
** Input arguments:
**   node1: starting node for recursive search
**   node2: node to be searched for
**
** Return value: true or false
*/

static int is_descendant (const Timer *node1, const Timer *node2)
{
  int n;

  /* Breadth before depth for efficiency */

  for (n = 0; n < node1->nchildren; ++n)
    if (node1->children[n] == node2)
      return 1;

  for (n = 0; n < node1->nchildren; ++n)
    if (is_descendant (node1->children[n], node2))
      return 1;

  return 0;
}

/*
** show_descendant: list descendants, breadth first, stopping early
**  if a particular node is discovered (e.g. the parent)
**
** Input arguments:
**   level: current level in recursion, should be 0 when first called
**   node1: starting node for recursive listing
**   node2: node defining the early stopping criterion
**
** Return value: true (listed all descendants) or false (stopped early)
*/

static int show_descendant (const int level, const Timer *node1, const Timer *node2)
{
  int n;

  /* Breadth before depth for efficiency */

  for (n = 0; n < node1->nchildren; ++n){
    printf ("node1: %-32s level: %d child: %d label: %-32s\n", node1->name, level, n, node1->children[n]->name);
    if (node1->children[n] == node2)
      return 1;
  }

  for (n = 0; n < node1->nchildren; ++n)
    if (show_descendant (level+1, node1->children[n], node2))
      return 1;

  return 0;
}

/*
** printstats: print a single timer
**
** Input arguments:
**   timer:        timer for which to print stats
**   fp:           file descriptor to write to
**   t:            thread number
**   depth:        depth to indent timer
**   doindent:     whether indenting will be done
**   tot_overhead: underlying timing routine overhead
*/

static void printstats (const Timer *timer,
			FILE *fp,
			const int t,
			const int depth,
			const bool doindent,
			const double tot_overhead)
{
  int i;               /* index */
  int indent;          /* index for indenting */
  int extraspace;      /* for padding to length of longest name */
  float fusr;          /* user time as float */
  float fsys;          /* system time as float */
  float usrsys;        /* usr + sys */
  float elapse;        /* elapsed time */
  float wallmax;       /* max wall time */
  float wallmin;       /* min wall time */
  float ratio;         /* percentage calc */

  /* Flag regions having multiple parents with a "*" in column 1 */

  if (doindent) {
    if (timer->nparent > 1)
      fprintf (fp, "* ");
    else
      fprintf (fp, "  ");

    /* Indent to depth of this timer */

    for (indent = 0; indent < depth; ++indent)
      fprintf (fp, "  ");
  }

  if (dopr_quotes){
    fprintf (fp, "\"%s\"", timer->name);
  } else {
    fprintf (fp, "%s", timer->name);
  }

  /* Pad to length of longest name */

  extraspace = max_name_len[t] - strlen (timer->name); 
  for (i = 0; i < extraspace; ++i)
    fprintf (fp, " ");

  /* Pad to max indent level */

  if (doindent)
    for (indent = depth; indent < max_depth[t]; ++indent)
      fprintf (fp, "  ");

  if (timer->onflg)
    fprintf (fp, "  y");
  else
    fprintf (fp, "  -");

  if (timer->count < PRTHRESH) {
    if (timer->nrecurse > 0)
      fprintf (fp, "%8lu %6lu ", timer->count, timer->nrecurse);
    else
      fprintf (fp, "%8lu    -   ", timer->count);
  } else {
    if (timer->nrecurse > 0)
      fprintf (fp, "%8.1e %6.0e ", (float) timer->count, (float) timer->nrecurse);
    else
      fprintf (fp, "%8.1e    -   ", (float) timer->count);
  }

  if (cpustats.enabled) {
    fusr = timer->cpu.accum_utime / (float) ticks_per_sec;
    fsys = timer->cpu.accum_stime / (float) ticks_per_sec;
    usrsys = fusr + fsys;
    fprintf (fp, "%9.3f %9.3f %9.3f ", fusr, fsys, usrsys);
  }

  if (wallstats.enabled) {
    elapse = timer->wall.accum;
    wallmax = timer->wall.max;
    wallmin = timer->wall.min;
    fprintf (fp, "%12.6f %12.6f %12.6f ", elapse, wallmax, wallmin);

    if (percent && timers[0]->next) {
      ratio = 0.;
      if (timers[0]->next->wall.accum > 0.)
	ratio = (timer->wall.accum * 100.) / timers[0]->next->wall.accum;
      fprintf (fp, " %9.2f ", ratio);
    }

    /*
    ** Factor of 2 is because there are 2 utr calls per start/stop pair.
    */

    if (overheadstats.enabled) {
      fprintf (fp, "%16.6f ", timer->count * 2 * tot_overhead);
    }
  }

#ifdef ENABLE_PMPI
  if (timer->nbytes == 0.)
    fprintf (fp, "      -       ");
  else
    fprintf (fp, "%13.3e ", timer->nbytes / timer->count);
#endif

#ifdef HAVE_PAPI
  GPTL_PAPIpr (fp, &timer->aux, t, timer->count, timer->wall.accum);
#endif

  fprintf (fp, "\n");
}

/*
** print_multparentinfo:
**
** Input arguments:
** Input/output arguments:
*/
void print_multparentinfo (FILE *fp,
			   Timer *ptr)
{
  int n;

  if (ptr->norphan > 0) {
    if (ptr->norphan < PRTHRESH)
      fprintf (fp, "%8u %-32s\n", ptr->norphan, "ORPHAN");
    else
      fprintf (fp, "%8.1e %-32s\n", (float) ptr->norphan, "ORPHAN");
  }

  for (n = 0; n < ptr->nparent; ++n) {
    if (ptr->parent_count[n] < PRTHRESH)
      fprintf (fp, "%8d %-32s\n", ptr->parent_count[n], ptr->parent[n]->name);
    else
      fprintf (fp, "%8.1e %-32s\n", (float) ptr->parent_count[n], ptr->parent[n]->name);
  }

  if (ptr->count < PRTHRESH)
    fprintf (fp, "%8lu   %-32s\n\n", ptr->count, ptr->name);
  else
    fprintf (fp, "%8.1e   %-32s\n\n", (float) ptr->count, ptr->name);
}

/*
** add: add the contents of tin to tout
**
** Input arguments:
**   tin:  input timer
** Input/output arguments:
**   tout: output timer summed into
*/

static void add (Timer *tout,
		 const Timer *tin)
{
  tout->count += tin->count;

  if (wallstats.enabled) {
    tout->wall.accum += tin->wall.accum;

    tout->wall.max = MAX (tout->wall.max, tin->wall.max);
    tout->wall.min = MIN (tout->wall.min, tin->wall.min);
  }

  if (cpustats.enabled) {
    tout->cpu.accum_utime += tin->cpu.accum_utime;
    tout->cpu.accum_stime += tin->cpu.accum_stime;
  }
#ifdef HAVE_PAPI
  GPTL_PAPIadd (&tout->aux, &tin->aux);
#endif
}

/*
** GPTLpr_summary: Gather and print summary stats across
**                 threads and MPI tasks
**
** Input arguments:
**   comm: commuicator (e.g. MPI_COMM_WORLD). If zero, use MPI_COMM_WORLD
*/

#ifdef HAVE_MPI
int GPTLpr_summary (MPI_Comm comm)
#else
int GPTLpr_summary (int comm)
#endif
{
  const char *outfile = "timing.summary";
  int ret;

  ret = GPTLpr_summary_file(comm, outfile);
  return 0;
}

#ifdef HAVE_MPI
int GPTLpr_summary_file (MPI_Comm comm,
                         const char *outfile)
#else
int GPTLpr_summary_file (int comm,
                         const char *outfile)
#endif
{
  int iam = 0;                     /* MPI rank: default master */
  int n;                           /* index */
  int extraspace;                  /* for padding to length of longest name */
  int totlen;                      /* length for malloc */
  char *outpath;                   /* path to output file: outdir/outfile */
  FILE *fp = 0;                    /* output file */

  int count;                       /* number of timers */
  Summarystats *storage;           /* storage for data from all timers */

  int x;                           /* pointer increment */
  int k;                           /* counter */
  char *tempname;                  /* event name workspace */
  int max_name_length;
  int len;
  float temp;
  int ret;                                  /* return code */

  static const char *thisfunc = "GPTLpr_summary_file";

#ifdef HAVE_MPI
  int nproc;                                /* number of procs in MPI communicator */

  char name[MAX_CHARS+1];                   /* timer name requested by master */

  if (((int) comm) == 0)
    comm = MPI_COMM_WORLD;

  if ((ret = MPI_Comm_rank (comm, &iam)) != MPI_SUCCESS)
    return GPTLerror ("%s: Bad return from MPI_Comm_rank=%d\n", thisfunc, ret);

  if ((ret = MPI_Comm_size (comm, &nproc)) != MPI_SUCCESS)
    return GPTLerror ("%s rank %d: Bad return from MPI_Comm_size=%d\n", thisfunc, iam, ret);

#endif

  if ( ! initialized)
    return GPTLerror ("%s: GPTLinitialize() has not been called\n", thisfunc);

  /*
  ** Each process gathers stats for its threads.
  ** Binary tree used combine results.
  ** Master prints results.
  */

  if (iam == 0) {

    /* 2 is for "/" plus null */
    if (outdir)
      totlen = strlen (outdir) + strlen (outfile) + 2;
    else
      totlen = strlen (outfile) + 2;

    outpath = (char *) GPTLallocate (totlen);

    if (outdir) {
      strcpy (outpath, outdir);
      strcat (outpath, "/");
      strcat (outpath, outfile);
    } else {
      strcpy (outpath, outfile);
    }

    if (print_mode == GPTLprint_append){
      if ( ! (fp = fopen (outpath, "a")))
        fp = stderr;
    }
    else{
      if ( ! (fp = fopen (outpath, "w")))
        fp = stderr;
    }

    free (outpath);

    fprintf (fp, "$Id: gptl.c,v 1.157 2011-03-28 20:55:18 rosinski Exp $\n");
    fprintf (fp, "'count' is cumulative. All other stats are max/min\n");
    fprintf (fp, "'on' indicates whether the timer was active during output, and so stats are lower or upper bounds.\n");
#ifndef HAVE_MPI
    fprintf (fp, "NOTE: GPTL was built WITHOUT MPI: Only task 0 stats will be printed.\n");
    fprintf (fp, "This is even for MPI codes.\n");
#endif
    fprintf (fp, "\n");

    count = merge_thread_data(); /*merges events from all threads*/

    if( !( tempname = (char*)malloc((MAX_CHARS + 1) * sizeof(char) ) ) )
      return GPTLerror ("%s: memory allocation failed\n", thisfunc);

    /* allocate storage for data for all timers */
    if( !( storage = malloc( sizeof(Summarystats) * count ) ) && count )
      return GPTLerror ("%s: memory allocation failed\n", thisfunc);

    if ( (ret = collect_data( iam, comm, &count, &storage) ) != 0 )
      return GPTLerror ("%s: master collect_data failed\n", thisfunc);

    x = 0; /*finds max timer name length*/
    max_name_length = 0;
    for( k = 0; k < count; k++ ) {
        len = strlen( timerlist[0] + x );
        if( len > max_name_length )
            max_name_length = len;
        x += MAX_CHARS + 1;
    }

    /* Print heading */

    fprintf (fp, "name");
    if (dopr_quotes){
      extraspace = (max_name_length+2) - strlen ("name");
    } else {
      extraspace = max_name_length - strlen ("name");
    }
    for (n = 0; n < extraspace; ++n)
      fprintf (fp, " ");
    fprintf (fp, " on  processes  threads        count");
    fprintf (fp, "      walltotal   wallmax (proc   thrd  )   wallmin (proc   thrd  )");

    for (n = 0; n < nevents; ++n) {
      fprintf (fp, "    %8.8stotal", eventlist[n].str8);
      fprintf (fp, " %8.8smax (proc   thrd  )", eventlist[n].str8);
      fprintf (fp, " %8.8smin (proc   thrd  )", eventlist[n].str8);
    }

    fprintf (fp, "\n");

    x = 0;
    for( k = 0; k < count; k++ ) {

      /* Print the results for this timer */
      memset( tempname, 0, (MAX_CHARS + 1) * sizeof(char) );
      memcpy( tempname, timerlist[0] + x, (MAX_CHARS + 1) * sizeof(char) );

      x += (MAX_CHARS + 1);
      if (dopr_quotes){
        fprintf (fp, "\"%s\"", tempname);
      } else {
        fprintf (fp, "%s", tempname);
      }
      extraspace = max_name_length - strlen (tempname);
      for (n = 0; n < extraspace; ++n)
        fprintf (fp, " ");
      if (storage[k].onflgs > 0)
        fprintf (fp, "  y ");
      else
        fprintf (fp, "  - ");
      temp = storage[k].count;
      fprintf(fp, "  %8d %8d %12.6e ",
              storage[k].processes, storage[k].threads, temp);
      fprintf (fp, "  %12.6e %9.3f (%6d %6d) %9.3f (%6d %6d)",
	       storage[k].walltotal,
	       storage[k].wallmax, storage[k].wallmax_p, storage[k].wallmax_t,
	       storage[k].wallmin, storage[k].wallmin_p, storage[k].wallmin_t);
#ifdef HAVE_PAPI
      for (n = 0; n < nevents; ++n) {
          fprintf (fp, "     %12.6e", storage[k].papitotal[n]);

          fprintf (fp, "  %9.3e  (%6d %6d)",
               storage[k].papimax[n], storage[k].papimax_p[n],
               storage[k].papimax_t[n]);

          fprintf (fp, "  %9.3e  (%6d %6d)",
               storage[k].papimin[n], storage[k].papimin_p[n],
               storage[k].papimin_t[n]);
      }
#endif
    fprintf (fp, "\n");
    }

    fprintf (fp, "\n");
    free(tempname);

  }
  else {   /* iam != 0 (slave) */
#ifdef HAVE_MPI
    /* count number of timers from linked list */
    count = merge_thread_data();

    /*allocate storage for data for all timers */
    if( !( storage = malloc( sizeof(Summarystats) * count ) ) && count )
      return GPTLerror ("%s: memory allocation failed\n", thisfunc);

    if ( (ret = collect_data( iam, comm, &count, &storage ) ) != 0 )
      return GPTLerror ("%s: slave collect_data failed\n", thisfunc);
#endif
  }

  free(timerlist[0]);
  free(timerlist);
  free(storage);
  if (iam == 0 && fclose (fp) != 0)
    fprintf (stderr, "%s: Attempt to close %s failed\n", thisfunc, outfile);
  return 0;
}

/*
** merge_thread_data: returns number of events in merged list
*/

static int merge_thread_data()
{
  int n, k, x;                     /*counters*/
  int t;                           /*current thread*/
  int num_newtimers;
  int compare;
  int *count;
  int max_count;                   /* largest number of timers among non-thread-0 threads */
  char **newtimers;
  int length = MAX_CHARS + 1;
  char ***sort;
  int count_r;                     /* count to be returned, allows *count to be free()ed */
  Timer *ptr;

  static const char *thisfunc = "merge_thread_data";

  if( nthreads == 1 ) { /* merging is not needed since only 1 thread */

    /* count timers for thread 0 */
    count_r = 0;
    for (ptr = timers[0]->next; ptr; ptr = ptr->next) count_r++;

    timerlist    = (char **) GPTLallocate( sizeof (char *));
    if( !( timerlist[0] = (char *)malloc( count_r * length * sizeof (char)) ) && count_r)
      return GPTLerror ("%s: memory allocation failed\n", thisfunc);

    x = 0;
    for (ptr = timers[0]->next; ptr; ptr = ptr->next) {
      strcpy((timerlist[0] + x), ptr->name);
      x += length;
    }

    return count_r;

  }

  timerlist = (char **)  GPTLallocate( nthreads * sizeof (char *));
  count     = (int *)    GPTLallocate( nthreads * sizeof (int));
  sort      = (char ***) GPTLallocate( nthreads * sizeof (void *));

  max_count = 0;
  for (t = 0; t < nthreads; t++) {

    /* count timers for thread */
    count[t] = 0;
    for (ptr = timers[t]->next; ptr; ptr = ptr->next) count[t]++;

    if( count[t] > max_count || max_count == 0 ) max_count = count[t];

    if( !( sort[t] = (char **)malloc( count[t] * sizeof (char *)) ) && count[t])
      return GPTLerror ("%s: memory allocation failed\n", thisfunc);

    /* allocate memory to hold list of timer names */
    if( !( timerlist[t] = (char *)malloc( length * count[t] * sizeof (char)) ) && count[t])
      return GPTLerror ("%s: memory allocation failed\n", thisfunc);
    memset( timerlist[t], 0, length  * count[t] * sizeof (char) );

    x = 0;
    for (ptr = timers[t]->next; ptr; ptr = ptr->next) {
      strcpy((timerlist[t] + x), ptr->name);
      x += length;
    }

    x = 0;
    for (k = 0; k < count[t]; k++) {
      sort[t][k] = timerlist[t] + x;
      x += length;
    }

    qsort( sort[t], count[t], sizeof (char *), cmp );

  }

  if( !( newtimers = (char **)malloc( max_count * sizeof (char *)) ) && max_count)
    return GPTLerror ("%s: memory allocation failed\n", thisfunc);

  for (t = 1; t < nthreads; t++) {
    memset( newtimers, 0, max_count * sizeof (char *) );
    k = 0;
    n = 0;
    num_newtimers = 0;
    while( k < count[0] && n < count[t] ) {
      /* linear comparison of timers */
      compare = strcmp( sort[0][k], sort[t][n]  );

      if( compare == 0 ) {
        /* both have, nothing needs to be done */
        k++;
        n++;
        continue;
      }

      if( compare < 0 ) {
        /* event that only master has, nothing needs to be done */
        k++;
        continue;
      }

      if( compare > 0 ) {
        /* event that only slave thread has, need to add */
        newtimers[num_newtimers] = sort[t][n];
        n++;
        num_newtimers++;
      }
    }

    while( n < count[t] ) {
      /* adds any remaining timers, since we know that all the rest
         are new since have checked all master thread timers */
      newtimers[num_newtimers] = sort[t][n];
      num_newtimers++;
      n++;
    }

    if( num_newtimers ) {
      /* sorts by memory address to restore original order */
      qsort( newtimers, num_newtimers, sizeof(char*), ncmp );

      /* reallocate memory to hold additional timers */
      if( !( sort[0] = realloc( sort[0], (count[0] + num_newtimers) * sizeof (char *)) ) )
        return GPTLerror ("%s: memory reallocation failed\n", thisfunc);
      if( !(timerlist[0] = realloc(timerlist[0], length * (count[0] + num_newtimers) * sizeof (char)) ) )
        return GPTLerror ("%s: memory reallocation failed\n", thisfunc);

      k = count[0];
      for (n = 0; n < num_newtimers; n++) {
        /* add new found timers */
        memcpy( timerlist[0] + (count[0] + n) *  length, newtimers[n], length * sizeof (char) );
      }

      count[0] += num_newtimers;

      /* reassign pointers in sort since realloc will have broken them if it moved the memory. */
      x = 0;
      for (k = 0; k < count[0]; k++) {
        sort[0][k] = timerlist[0] + x;
        x += length;
      }

      qsort( sort[0], count[0], sizeof (char *), cmp );
    }
  }

  free(newtimers);
  free(sort[0]);
  /* don't free timerlist[0], since needed for subsequent steps in gathering global statistics */
  for (t = 1; t < nthreads; t++) {
    free(sort[t]);
    free(timerlist[t]);
  }

  free(sort);
  count_r = count[0];
  free(count);

  return count_r;
}

/*
** collect data: compute global stats using tree reduction algorithm
** returns pointer to new summarystats list
**
** Input arguments:
**   iam:   process id
**   comm:  MPI communicator
** Input/Output arguments:
**   summarystats: max/min/etc stats over all processes and threads
**   count: number of events
**   timerlist:  list of all timer names (global variable)
**
** Return value: 0 (success) or GPTLerror (failure)
*/

#ifdef HAVE_MPI
static int collect_data(const int iam,
                        MPI_Comm comm,
                        int *count,
                        Summarystats **summarystats_cumul )
#else
static int collect_data(const int iam,
                        int comm,
                        int *count,
                        Summarystats **summarystats_cumul )
#endif
{
  int step;                        /* spacing beween active processes */
  int mstep;                       /* spacing between active masters */
  int procid;                      /* process to communicate with */
  int ret;
  int nproc;
  int signal = 1;
  int x, k, n;                     /* counters */
  char *tempname;
  int s = (MAX_CHARS + 1 );        /* spacing between timer names */
  int length = MAX_CHARS + 1;
  int compare;
  int num_newtimers;
  int count_slave;
  char *timers_slave;              /* slave timerlist */
  char **newtimers;
  char **sort_slave;               /* slave sorted list */
  char **sort_master;              /* master sorted list */
  int m_index, s_index;
  Summarystats *summarystats;      /* stats collected on master */

  static const char *thisfunc = "collect_data";

#ifdef HAVE_MPI
  Summarystats *summarystats_slave; /* stats sent to master */
  const int taga =  99;
  const int tagb = 100;
  const int tagc = 101;
  MPI_Status status;
  MPI_Request rcvreq1;
  MPI_Request rcvreq2;
  MPI_Request rcvreq3;

  if ((ret = MPI_Comm_size (comm, &nproc)) != MPI_SUCCESS)
    return GPTLerror ("%s rank %d: Bad return from MPI_Comm_size=%d\n", thisfunc, iam, ret);

#endif

  summarystats = *summarystats_cumul;

  if (!( tempname = (char*)malloc((MAX_CHARS +1) * sizeof(char) ) ))
    return GPTLerror ("%s: memory allocation failed\n", thisfunc);

  x = 0;
  for (k = 0; k < *count; k++) {
    memcpy( tempname, timerlist[0] + x, (MAX_CHARS + 1) * sizeof (char) );
    /* calculate individual stats */
    get_threadstats( iam, tempname, &summarystats[k]);
    x += (MAX_CHARS + 1);
  }

#ifdef HAVE_MPI
  step = 1;
  mstep = 2;
  while( step < nproc ) {

    if ((iam % mstep) == 0) {
       /* find new masters at the current level, which are at every n*step starting with 0 */

      procid = iam + step;
      if (procid < nproc) {
        /* prevent lone master wanting data from nonexistent process problem */

        /* prepare for receive */
        if ((ret = MPI_Irecv (&count_slave, 1, MPI_INTEGER, procid, taga, comm, &rcvreq2)) != MPI_SUCCESS)
          return GPTLerror ("%s rank %d: Bad return from MPI_Irecv=%d\n", thisfunc, iam, ret);

        /* handshake with slave */
        if ((ret = MPI_Send (&signal, 1, MPI_INTEGER, procid, taga, comm)) != MPI_SUCCESS)
          return GPTLerror ("%s rank %d: Bad return from MPI_Send=%d\n", thisfunc, iam, ret);

        /* wait for message from slave */
        if ((ret = MPI_Wait (&rcvreq2, MPI_STATUS_IGNORE)) != MPI_SUCCESS)
          return GPTLerror ("%s rank %d: Bad return from MPI_Wait=%d\n", thisfunc, iam, ret);

        if (count_slave != 0) { /* if slave had no events, then nothing needs to be done*/

          if (!(sort_master = (char **) malloc( (*count) * sizeof (char *) ) ) && (*count))
            return GPTLerror ("%s: memory allocation failed\n", thisfunc);
          if (!(newtimers = (char **) malloc( count_slave * sizeof (char *) ) ))
            return GPTLerror ("%s: memory allocation failed\n", thisfunc);
          if (!(sort_slave = (char **) malloc( count_slave * sizeof (char *) ) ))
            return GPTLerror ("%s: memory allocation failed\n", thisfunc);
          if (!(summarystats_slave = (Summarystats *) malloc( count_slave * sizeof (Summarystats) ) ))
            return GPTLerror ("%s: memory allocation failed\n", thisfunc);
          if (!(timers_slave = (char *) malloc( count_slave * (MAX_CHARS + 1) * sizeof (char) ) ))
            return GPTLerror ("%s: memory allocation failed\n", thisfunc);

          if ((ret = MPI_Irecv (timers_slave, count_slave * (MAX_CHARS + 1), MPI_CHAR, procid, tagb, comm, &rcvreq3)) != MPI_SUCCESS)
            return GPTLerror ("%s rank %d: Bad return from MPI_Irecv=%d\n", thisfunc, iam, ret);
          if ((ret = MPI_Irecv (summarystats_slave, count_slave * sizeof(Summarystats), MPI_BYTE, procid, tagc, comm, &rcvreq1)) != MPI_SUCCESS)
            return GPTLerror ("%s rank %d: Bad return from MPI_Irecv=%d\n", thisfunc, iam, ret);
          if ((ret = MPI_Send (&signal, 1, MPI_INT, procid, tagb, comm)) != MPI_SUCCESS)
            return GPTLerror ("%s rank %d: Bad return from MPI_Send=%d\n", thisfunc, iam, ret);
          if ((ret = MPI_Wait (&rcvreq1, MPI_STATUS_IGNORE)) != MPI_SUCCESS)
            return GPTLerror ("%s rank %d: Bad return from MPI_Wait=%d\n", thisfunc, iam, ret);
          if ((ret = MPI_Wait (&rcvreq3, MPI_STATUS_IGNORE)) != MPI_SUCCESS)
            return GPTLerror ("%s rank %d: Bad return from MPI_Wait=%d\n", thisfunc, iam, ret);

          x = 0;
          for (k = 0; k < count_slave; k++) {
            sort_slave[k] = timers_slave + x;
            x += MAX_CHARS + 1;
          }
          x = 0;
          for (k = 0; k < *count; k++) {
            sort_master[k] = timerlist[0] + x;
            x += MAX_CHARS + 1;
          }

          qsort(sort_master, *count, sizeof(char*), cmp);
          qsort(sort_slave, count_slave, sizeof(char*), cmp);

          num_newtimers = 0;
          n = 0;
          k = 0;
          while (k < *count && n < count_slave)
          {
            compare = strcmp(sort_master[k], sort_slave[n]);

            if (compare == 0) {
              /* matching timers found */

              /* find element number of the name in original timerlist so that it can be matched with its summarystats */
              m_index = get_index( timerlist[0], sort_master[k] );

              s_index = get_index( timers_slave, sort_slave[n] );
              get_summarystats (&summarystats[m_index], &summarystats_slave[s_index]);
              k++;
              n++;
              continue;
            }

            if (compare > 0) {
              /* s1 >s2 . slave has event; master does not */
              newtimers[num_newtimers] = sort_slave[n];
              num_newtimers++;
              n++;
              continue;
            }

            if (compare < 0) /* only master has event; nothing needs to be done */
              k++;
          }

          while (n < count_slave) {
            /* add all remaining timers which only the slave has */
            newtimers[num_newtimers] = sort_slave[n];
            num_newtimers++;
            n++;
          }

          /* sort by memory address to get original order */
          qsort (newtimers, num_newtimers, sizeof(char*), ncmp);

          /* reallocate to hold new timer names and summary stats from slave */
          if (!(timerlist[0] = realloc( timerlist[0], length * (*count + num_newtimers) * sizeof (char) ) ))
            return GPTLerror ("%s: memory reallocation failed\n", thisfunc);
          if (!(summarystats = realloc( summarystats, (*count + count_slave ) * sizeof (Summarystats) ) ))
            return GPTLerror ("%s: memory reallocation failed\n", thisfunc);

          k = *count;
          x = *count * (MAX_CHARS + 1);
          for (n = 0; n < num_newtimers; n++) {
            /* copy new timers names and new timer data */
            memcpy(timerlist[0] + x, newtimers[n], length * sizeof (char));
            s_index = get_index( timers_slave, newtimers[n] );
            memcpy(&summarystats[k], &summarystats_slave[s_index], sizeof (Summarystats));
            k++;
            x += MAX_CHARS + 1;
          }
          *count += num_newtimers;

          free(timers_slave);
          free(summarystats_slave);
          free(newtimers);
          free(sort_slave);
          free(sort_master);
        }

      }

    }
    else if ( (iam % step) == 0 ) {
      /* non masters send data */

      procid = iam - step;

      /* wait for ready signal from master */
      if ((ret = MPI_Recv (&signal, 1, MPI_INTEGER, procid, taga, comm, MPI_STATUS_IGNORE)) != MPI_SUCCESS)
        return GPTLerror ("%s rank %d: Bad return from MPI_Recv=%d\n", thisfunc, iam, ret);

      if ((ret = MPI_Send (count, 1, MPI_INTEGER, procid, taga, comm)) != MPI_SUCCESS)
        return GPTLerror ("%s rank %d: Bad return from MPI_Send=%d\n", thisfunc, iam, ret);

      if ( count != 0) {
        if ((ret = MPI_Recv (&signal, 1, MPI_INTEGER, procid, tagb, comm, MPI_STATUS_IGNORE)) != MPI_SUCCESS)
          return GPTLerror ("%s rank %d: Bad return from MPI_Recv=%d\n", thisfunc, iam, ret);
        if ((ret = MPI_Send (timerlist[0], (*count) * (MAX_CHARS + 1), MPI_CHAR, procid, tagb, comm)) != MPI_SUCCESS)
          return GPTLerror ("%s rank %d: Bad return from MPI_Send=%d\n", thisfunc, iam, ret);
        if ((ret = MPI_Send (summarystats, (*count) * sizeof(Summarystats), MPI_BYTE, procid, tagc, comm)) != MPI_SUCCESS)
          return GPTLerror ("%s rank %d: Bad return from MPI_Send=%d\n", thisfunc, iam, ret);
      }
      free(tempname);
      *summarystats_cumul = summarystats;
      return 0;

    }

    step = mstep;
    mstep = 2 * mstep;

  }

#endif

  free(tempname);
  *summarystats_cumul = summarystats;
  return 0;
}

/*
** get_index: calculates the index number of an element in a list
** based on the start memory address and memory address of the element
** where each element is MAX_CHARS+1 long
**
** Input arguments:
**   list: start address of list
**   element: start address of element
**
** Return value: index of element in list
*/

int get_index( const char * list,
               const char * element )
{
  return (( element - list ) / ( MAX_CHARS  + 1 ));
}


/*
** cmp: returns value from strcmp. for use with qsort
*/

static int cmp(const void *pa, const void *pb)
{
  const char** x = (const char**)pa;
  const char** y = (const char**)pb;
  return strcmp(*x, *y);
}


/*
** ncmp: compares values of memory adresses pointed to by a pointer. for use with qsort
*/

static int ncmp( const void *pa, const void *pb )
{
  static const char *thisfunc = "GPTLsetoption";
  const char** x = (const char**)pa;
  const char** y = (const char**)pb;

  if( *x > *y )
    return 1;
  if( *x < *y )
    return -1;
  if( *x == *y )
    GPTLerror("%s: shared memory address between timers\n", thisfunc);
}

/*
** get_threadstats: gather stats for timer "name" over all threads
**
** Input arguments:
**   iam:   MPI process id
**   name:  timer name
** Output arguments:
**   summarystats: max/min stats over all threads
*/

void get_threadstats (const int iam,
                      const char *name,
		      Summarystats *summarystats)
{
#ifdef HAVE_PAPI
  int n;                /* event index */
#endif
  int t;                /* thread index */
  unsigned int indx;    /* returned from getentry() */
  Timer *ptr;           /* timer */

  /*
  ** This memset fortuitiously initializes the process values (_p) to master (0)
  */

  memset (summarystats, 0, sizeof (Summarystats));

  summarystats->wallmax_p = iam;
  summarystats->wallmin_p = iam;

  for (t = 0; t < nthreads; ++t) {
    if ((ptr = getentry (hashtable[t], name, &indx))) {

      if (ptr->onflg)
        summarystats->onflgs++;

      if (ptr->count > 0) {
        summarystats->threads++;
        summarystats->walltotal += ptr->wall.accum;
      }
      summarystats->count += ptr->count;

      if (ptr->wall.accum > summarystats->wallmax) {
	summarystats->wallmax   = ptr->wall.accum;
	summarystats->wallmax_t = t;
      }

      if (ptr->wall.accum < summarystats->wallmin || summarystats->wallmin == 0.) {
	summarystats->wallmin   = ptr->wall.accum;
	summarystats->wallmin_t = t;
      }
#ifdef HAVE_PAPI
      for (n = 0; n < nevents; ++n) {
	double value;
	if (GPTL_PAPIget_eventvalue (eventlist[n].namestr, &ptr->aux, &value) != 0) {
	  fprintf (stderr, "Bad return from GPTL_PAPIget_eventvalue\n");
	  return;
	}
        summarystats->papimax_p[n] = iam;
        summarystats->papimin_p[n] = iam;

	if (value > summarystats->papimax[n]) {
	  summarystats->papimax[n]   = value;
	  summarystats->papimax_t[n] = t;
	}

	if (value < summarystats->papimin[n] || summarystats->papimin[n] == 0.) {
	  summarystats->papimin[n]   = value;
	  summarystats->papimin_t[n] = t;
	}
	summarystats->papitotal[n] += value;
      }
#endif
    }
  }
  if ( summarystats->count ) summarystats->processes = 1;
}

/*
** get_summarystats: write max/min stats into mpistats based on comparison
**                   with  summarystats_slave
**
** Input arguments:
**   summarystats_slave: stats from a slave process
** Input/Output arguments:
**   summarystats:       stats (starts out as master stats)
*/

void get_summarystats (Summarystats *summarystats,
		       const Summarystats *summarystats_slave)
{
  if (summarystats_slave->count == 0) return;

  if (summarystats_slave->wallmax > summarystats->wallmax) {
    summarystats->wallmax   = summarystats_slave->wallmax;
    summarystats->wallmax_p = summarystats_slave->wallmax_p;
    summarystats->wallmax_t = summarystats_slave->wallmax_t;
  }

  if ((summarystats_slave->wallmin < summarystats->wallmin) ||
      (summarystats->count == 0)){
    summarystats->wallmin   = summarystats_slave->wallmin;
    summarystats->wallmin_p = summarystats_slave->wallmin_p;
    summarystats->wallmin_t = summarystats_slave->wallmin_t;
  }

#ifdef HAVE_PAPI
  {
    int n;
    for (n = 0; n < nevents; ++n) {
      if (summarystats_slave->papimax[n] > summarystats->papimax[n]) {
	summarystats->papimax[n]   = summarystats_slave->papimax[n];
	summarystats->papimax_p[n] = summarystats_slave->papimax_p[n];
	summarystats->papimax_t[n] = summarystats_slave->papimax_t[n];
      }

      if ((summarystats_slave->papimin[n] < summarystats->papimin[n]) ||
          (summarystats->count == 0)){
	summarystats->papimin[n]   = summarystats_slave->papimin[n];
	summarystats->papimin_p[n] = summarystats_slave->papimin_p[n];
	summarystats->papimin_t[n] = summarystats_slave->papimin_t[n];
      }
      summarystats->papitotal[n] += summarystats_slave->papitotal[n];
    }
  }
#endif

  summarystats->onflgs    += summarystats_slave->onflgs;
  summarystats->count     += summarystats_slave->count;
  summarystats->walltotal += summarystats_slave->walltotal;
  summarystats->processes += summarystats_slave->processes;
  summarystats->threads   += summarystats_slave->threads;
}

/*
** GPTLbarrier: When MPI enabled, set and time an MPI barrier
**
** Input arguments:
**   comm: commuicator (e.g. MPI_COMM_WORLD). If zero, use MPI_COMM_WORLD
**   name: region name
**
** Return value: 0 (success)
*/

#ifdef HAVE_MPI
int GPTLbarrier (MPI_Comm comm, const char *name)
#else
int GPTLbarrier (int comm, const char *name)
#endif
{
  int ret;
  static const char *thisfunc = "GPTLbarrier";

  ret = GPTLstart (name);
#ifdef HAVE_MPI
  if ((ret = MPI_Barrier (comm)) != MPI_SUCCESS)
    return GPTLerror ("%s: Bad return from MPI_Barrier=%d", thisfunc, ret);
#endif
  ret = GPTLstop (name);
  return 0;
}

/*
** get_cpustamp: Invoke the proper system timer and return stats.
**
** Output arguments:
**   usr: user time
**   sys: system time
**
** Return value: 0 (success)
*/

static inline int get_cpustamp (long *usr, long *sys)
{
#ifdef HAVE_TIMES
  struct tms buf;

  (void) times (&buf);
  *usr = buf.tms_utime;
  *sys = buf.tms_stime;
  return 0;
#else
  return GPTLerror ("get_cpustamp: times() not available\n");
#endif
}

/*
** GPTLquery: return current status info about a timer. If certain stats are not
** enabled, they should just have zeros in them. If PAPI is not enabled, input
** counter info is ignored.
**
** Input args:
**   timername:   timer name
**   maxcounters: max number of PAPI counters to get info for
**   t:           thread number (if < 0, the request is for the current thread)
**
** Output args:
**   count:            number of times this timer was called
**   onflg:            whether timer is currently on
**   wallclock:        accumulated wallclock time
**   usr:              accumulated user CPU time
**   sys:              accumulated system CPU time
**   papicounters_out: accumulated PAPI counters
*/

int GPTLquery (const char *timername,
	       int t,
	       int *count,
	       int *onflg,
	       double *wallclock,
	       double *dusr,
	       double *dsys,
	       long long *papicounters_out,
	       const int maxcounters)
{
  Timer *ptr;                 /* linked list pointer */
  int numchars;               /* number of characters to copy */
  int namelen;                /* number of characters in timer name */
  unsigned int indx;          /* linked list index returned from getentry (unused) */
  char new_name[MAX_CHARS+1]; /* timer name with prefix, if there is one */
  const char *name;           /* pointer to timer name */
  static const char *thisfunc = "GPTLquery";

  if ( ! initialized)
    return GPTLerror ("%s: GPTLinitialize has not been called\n", thisfunc);

  /*
  ** If t is < 0, assume the request is for the current thread
  */

  if (t < 0) {
    if ((t = get_thread_num ()) < 0)
      return GPTLerror ("%s: get_thread_num failure\n", thisfunc);
  } else {
    if (t >= maxthreads)
      return GPTLerror ("%s: requested thread %d is too big\n", thisfunc, t);
  }

  /*
  ** If prefix string is defined, prepend it to timername
  ** and assign the name pointer to the new string. 
  ** Otherwise assign the name pointer to the original string.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    namelen = strlen(timername);
    numchars = add_prefix(new_name, timername, namelen, t);
    name = new_name;
  } else {
    name = timername;
  }

  ptr = getentry (hashtable[t], name, &indx);
  if ( !ptr)
    return GPTLerror ("%s: requested timer %s does not have a name hash\n", thisfunc, name);

  *onflg     = ptr->onflg;
  *count     = ptr->count;
  *wallclock = ptr->wall.accum;
  *dusr      = ptr->cpu.accum_utime / (double) ticks_per_sec;
  *dsys      = ptr->cpu.accum_stime / (double) ticks_per_sec;
#ifdef HAVE_PAPI
  GPTL_PAPIquery (&ptr->aux, papicounters_out, maxcounters);
#endif
  return 0;
}

/*
** GPTLquerycounters: return current PAPI counters for a timer.
** THIS ROUTINE ID DEPRECATED. USE GPTLget_eventvalue() instead
**
** Input args:
**   timername: timer name
**   t:         thread number (if < 0, the request is for the current thread)
**
** Output args:
**   papicounters_out: accumulated PAPI counters
*/

int GPTLquerycounters (const char *timername,
		       int t,
		       long long *papicounters_out)
{
  Timer *ptr;                 /* linked list pointer */
  unsigned int indx;          /* hash index returned from getentry */
  int numchars;               /* number of characters to copy */
  int namelen;                /* number of characters in timer name */
  char new_name[MAX_CHARS+1]; /* timer name with prefix, if there is one */
  const char *name;           /* pointer to timer name */
  static const char *thisfunc = "GPTLquery_counters";

  if ( ! initialized)
    return GPTLerror ("%s: GPTLinitialize has not been called\n", thisfunc);

  /*
  ** If t is < 0, assume the request is for the current thread
  */

  if (t < 0) {
    if ((t = get_thread_num ()) < 0)
      return GPTLerror ("%s: get_thread_num failure\n", thisfunc);
  } else {
    if (t >= maxthreads)
      return GPTLerror ("%s: requested thread %d is too big\n", thisfunc, t);
  }

  /*
  ** If prefix string is defined, prepend it to timername
  ** and assign the name pointer to the new string. 
  ** Otherwise assign the name pointer to the original string.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    namelen = strlen(timername);
    numchars = add_prefix(new_name, timername, namelen, t);
    name = new_name;
  } else {
    name = timername;
  }

  ptr = getentry (hashtable[t], name, &indx);
  if ( !ptr)
    return GPTLerror ("%s: requested timer %s does not have a name hash\n", thisfunc, name);

#ifdef HAVE_PAPI
  /* The 999 is a hack to say "give me all the counters" */
  GPTL_PAPIquery (&ptr->aux, papicounters_out, 999);
#endif
  return 0;
}

/*
** GPTLget_wallclock: return wallclock accumulation for a timer.
**
** Input args:
**   timername: timer name
**   t:         thread number (if < 0, the request is for the current thread)
**
** Output args:
**   value: current wallclock accumulation for the timer
*/

int GPTLget_wallclock (const char *timername,
		      int t,
		      double *value)
{
  void *self;                 /* timer address when hash entry generated with *_instr */
  Timer *ptr;                 /* linked list pointer */
  unsigned int indx;          /* hash index returned from getentry (unused) */
  int numchars;               /* number of characters to copy */
  int namelen;                /* number of characters in timer name */
  char new_name[MAX_CHARS+1]; /* timer name with prefix, if there is one */
  const char *name;           /* pointer to timer name */
  static const char *thisfunc = "GPTLget_wallclock";

  if ( ! initialized)
    return GPTLerror ("%s: GPTLinitialize has not been called\n", thisfunc);

  if ( ! wallstats.enabled)
    return GPTLerror ("%s: wallstats not enabled\n", thisfunc);

  /*
  ** If t is < 0, assume the request is for the current thread
  */

  if (t < 0) {
    if ((t = get_thread_num ()) < 0)
      return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);
  } else {
    if (t >= maxthreads)
      return GPTLerror ("%s: requested thread %d is too big\n", thisfunc, t);
  }

  /*
  ** If prefix string is defined, prepend it to timername
  ** and assign the name pointer to the new string. 
  ** Otherwise assign the name pointer to the original string.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    namelen = strlen(timername);
    numchars = add_prefix(new_name, timername, namelen, t);
    name = new_name;
  } else {
    name = timername;
  }

  /*
  ** Don't know whether hashtable entry for timername was generated with
  ** *_instr() or not, so try both possibilities
  */

  ptr = getentry (hashtable[t], name, &indx);
  if ( !ptr) {
    if (sscanf (timername, "%lx", (unsigned long *) &self) < 1)
      return GPTLerror ("%s: requested timer %s does not exist\n", thisfunc, timername);
    ptr = getentry_instr (hashtable[t], self, &indx);
    if ( !ptr)
      return GPTLerror ("%s: requested timer %s does not exist\n", thisfunc, timername);
  }

  *value = ptr->wall.accum;
  return 0;
}

/*
** GPTLstartstop_vals: create/add walltime and call count to an event timer
**
** Input arguments:
**   timername: timer name
**   add_time:  value to add to the walltime accumulator
**   add_count: value to add to the call counter
**
** Return value: 0 (success) or -1 (failure)
*/

int GPTLstartstop_vals (const char *timername, /* timer name */
                        double add_time,       /* walltime increment */
                        int add_count)         /* call count increment */
{
  Timer *ptr;                 /* linked list pointer */
  int t;                      /* thread number for this process */
  int numchars;               /* number of characters to copy */
  int namelen;                /* number of characters in timer name */
  unsigned int indx;          /* index into hash table */
  char new_name[MAX_CHARS+1]; /* timer name with prefix, if there is one */
  const char *name;           /* pointer to timer name */
  static const char *thisfunc = "GPTLstartstop_vals";

  if (disabled)
    return 0;

  if ( ! initialized)
    return 0;

  if ( ! wallstats.enabled)
    return GPTLerror ("%s: wallstats must be enabled to call this function\n", thisfunc);

  if (add_time < 0.)
    return GPTLerror ("%s: Input add_time must not be negative\n", thisfunc);

  /* getentry requires the thread number */
  if ((t = get_thread_num ()) < 0)
    return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

  /*
  ** If prefix string is defined, prepend it to timername
  ** and assign the name pointer to the new string. 
  ** Otherwise assign the name pointer to the original string.
  */
  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    namelen = strlen(timername);
    numchars = add_prefix(new_name, timername, namelen, t);
    name = new_name;
  } else {
    name = timername;
  }

  /* Find out if the timer already exists */
  ptr = getentry (hashtable[t], name, &indx);

  if (ptr) {
    /*
    ** The timer already exists. If add_count is > 0, then increment the 
    ** count and update the time stamp. Then let control jump to the point where
    ** wallclock settings are adjusted.
    */
    if (add_count > 0){
      ptr->count += add_count;
      ptr->wall.last = (*ptr2wtimefunc) ();
    }
  } else {
    /* Need to call start/stop to set up linked list and hash table. */
    if (GPTLstart (timername) != 0)
      return GPTLerror ("%s: Error from GPTLstart\n", thisfunc);

    if (GPTLstop (timername) != 0)
      return GPTLerror ("%s: Error from GPTLstop\n", thisfunc);

    /* start/stop pair just called should guarantee ptr will be found */
    if ( ! (ptr = getentry (hashtable[t], name, &indx)))
      return GPTLerror ("%s: Unexpected error from getentry\n", thisfunc);

    /*
    ** If add_count >= 0, then set count to desired value.
    ** Otherwise, assume add_count == 0 and set count to 0. 
    */
    if (add_count >= 0){
      ptr->count = add_count;
    } else {
      ptr->count = 0;
    }

    /* Since this is the first call, set max and min to user input. */
    ptr->wall.max = add_time;

    ptr->wall.prev_min = FLT_MAX;
    ptr->wall.min = add_time;
    ptr->wall.latest_is_min = 1;

    /* 
    ** Minor mod: Subtract the overhead of the above start/stop call, before
    ** adding user input
    */
    ptr->wall.accum -= ptr->wall.latest;

    /* Then set latest to zero, so that update below is correct */
    ptr->wall.latest = 0.0;

  }

  /* Update accum with user input */
  ptr->wall.accum += add_time;

  /* 
  ** Update latest with user input:
  **  If add_count > 0 and old count > 0 (new count > add_count), 
  **   assume new event time is the average (add_time/add_count).
  **  If add_count > 0 and old count = 0 (new count == add_count), 
  **   assume new event time is the augmented average 
  **   ((latest value + add_time)/add_count).
  **  If add_count == 0, new event time is latest value + add_time.
  */
  if (add_count > 0){
    if (ptr->count > add_count)
      ptr->wall.latest = add_time/add_count;
    else
      ptr->wall.latest = (ptr->wall.latest+add_time)/add_count;
  } else {
    ptr->wall.latest += add_time;
  }

  /* Update max with user input */
  if (ptr->wall.latest > ptr->wall.max)
    ptr->wall.max = ptr->wall.latest;

  /* Update min with user input */
  if ((ptr->count <= 1) || (add_count == ptr->count)) {
    /* 
    ** still recording walltime for first occurrence, 
    ** so assign latest estimate to min and prev_min
    */
    ptr->wall.min = ptr->wall.latest;
    ptr->wall.latest_is_min = 1;
  } else {
    if (add_count > 0){
      /* check whether latest is the new min */
      if (ptr->wall.latest < ptr->wall.min){
        ptr->wall.prev_min = ptr->wall.min; 
        ptr->wall.min = ptr->wall.latest;
        ptr->wall.latest_is_min = 1;
      } else {
        ptr->wall.latest_is_min = 0;
      }
    } else {
      /* 
      ** still recording walltime for latest occurrence, 
      ** so check whether updated latest is the new min.
      */
      if (ptr->wall.latest_is_min == 1){
        if (ptr->wall.prev_min > ptr->wall.latest){
          ptr->wall.min = ptr->wall.latest;
        } else {
          ptr->wall.min = ptr->wall.prev_min;
          ptr->wall.latest_is_min = 0;
        }
      }
    }
  }

  return 0;
}

/*
** GPTLstartstop_valsf: create/add walltime and call count to an event timer.
**                      Version for when timer name may not be null terminated.
**
** Input arguments:
**   timername: timer name
**   namelen:   number of characters in timer name
**   add_time:  value to add to the walltime accumulator
**   add_count: value to add to the call counter
**
** Return value: 0 (success) or -1 (failure)
*/

int GPTLstartstop_valsf (const char *timername,  /* timer name */
                         const int namelen,      /* timer name length */
                         double add_time,        /* walltime increment */
                         int add_count)          /* call count increment */
{
  Timer *ptr;                 /* linked list pointer */
  int t;                      /* thread number for this process */
  int numchars;               /* number of characters to copy */
  unsigned int indx;          /* index into hash table */
  char new_name[MAX_CHARS+1]; /* timer name with prefix, if there is one */
  const char *name;           /* pointer to timer name */
  static const char *thisfunc = "GPTLstartstop_valsf";

  if (disabled)
    return 0;

  if ( ! initialized)
    return 0;

  if ( ! wallstats.enabled)
    return GPTLerror ("%s: wallstats must be enabled to call this function\n", thisfunc);

  if (add_time < 0.)
    return GPTLerror ("%s: Input add_time must not be negative\n", thisfunc);

  /* getentry requires the thread number */
  if ((t = get_thread_num ()) < 0)
    return GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);

  /*
  ** If prefix string is defined, prepend it to timername
  ** and assign the name pointer to the new string. 
  ** Otherwise assign the name pointer to the original string.
  */
  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    numchars = add_prefix(new_name, timername, namelen, t);
    name = new_name;
  } else {
    numchars = MIN (namelen, MAX_CHARS);
    name = timername;
  }

  /* Find out if the timer already exists */
  ptr = getentryf (hashtable[t], name, numchars, &indx);

  if (ptr) {
    /*
    ** The timer already exists. If add_count is > 0, then increment the 
    ** count and update the time stamp. Then let control jump to the point where
    ** wallclock settings are adjusted.
    */
    if (add_count > 0){
      ptr->count += add_count;
      ptr->wall.last = (*ptr2wtimefunc) ();
    }
  } else {
    /* Need to call start/stop to set up linked list and hash table. */
    if (GPTLstartf (timername, namelen) != 0)
      return GPTLerror ("%s: Error from GPTLstart\n", thisfunc);

    if (GPTLstopf (timername, namelen) != 0)
      return GPTLerror ("%s: Error from GPTLstop\n", thisfunc);

    /* start/stop pair just called should guarantee ptr will be found */
    if ( ! (ptr = getentryf (hashtable[t], name, numchars, &indx)))
      return GPTLerror ("%s: Unexpected error from getentry\n", thisfunc);

    /*
    ** If add_count >= 0, then set count to desired value.
    ** Otherwise, assume add_count == 0 and set count to 0. 
    */
    if (add_count >= 0){
      ptr->count = add_count;
    } else {
      ptr->count = 0;
    }

    /* Since this is the first call, set max and min to user input. */
    ptr->wall.max = add_time;

    ptr->wall.prev_min = FLT_MAX;
    ptr->wall.min = add_time;
    ptr->wall.latest_is_min = 1;

    /* 
    ** Minor mod: Subtract the overhead of the above start/stop call, before
    ** adding user input
    */
    ptr->wall.accum -= ptr->wall.latest;

    /* Then set latest to zero, so that update below is correct */
    ptr->wall.latest = 0.0;

  }

  /* Update accum with user input */
  ptr->wall.accum += add_time;

  /* 
  ** Update latest with user input:
  **  If add_count > 0 and old count > 0 (new count > add_count), 
  **   assume new event time is the average (add_time/add_count).
  **  If add_count > 0 and old count = 0 (new count == add_count), 
  **   assume new event time is the augmented average 
  **   ((latest value + add_time)/add_count).
  **  If add_count == 0, new event time is latest value + add_time.
  */
  if (add_count > 0){
    if (ptr->count > add_count)
      ptr->wall.latest = add_time/add_count;
    else
      ptr->wall.latest = (ptr->wall.latest+add_time)/add_count;
  } else {
    ptr->wall.latest += add_time;
  }

  /* Update max with user input */
  if (ptr->wall.latest > ptr->wall.max)
    ptr->wall.max = ptr->wall.latest;

  /* Update min with user input */
  if ((ptr->count <= 1) || (add_count == ptr->count)) {
    /* 
    ** still recording walltime for first occurrence, 
    ** so assign latest estimate to min and prev_min
    */
    ptr->wall.min = ptr->wall.latest;
    ptr->wall.latest_is_min = 1;
  } else {
    if (add_count > 0){
      /* check whether latest is the new min */
      if (ptr->wall.latest < ptr->wall.min){
        ptr->wall.prev_min = ptr->wall.min; 
        ptr->wall.min = ptr->wall.latest;
        ptr->wall.latest_is_min = 1;
      } else {
        ptr->wall.latest_is_min = 0;
      }
    } else {
      /* 
      ** still recording walltime for latest occurrence, 
      ** so check whether updated latest is the new min.
      */
      if (ptr->wall.latest_is_min == 1){
        if (ptr->wall.prev_min > ptr->wall.latest){
          ptr->wall.min = ptr->wall.latest;
        } else {
          ptr->wall.min = ptr->wall.prev_min;
          ptr->wall.latest_is_min = 0;
        }
      }
    }
  }

  return 0;
}

/*
** GPTLget_eventvalue: return PAPI-based event value for a timer. All values will be
**   returned as doubles, even if the event is not derived.
**
** Input args:
**   timername: timer name
**   eventname: event name (must be currently enabled)
**   t:         thread number (if < 0, the request is for the current thread)
**
** Output args:
**   value: current value of the event for this timer
*/

int GPTLget_eventvalue (const char *timername,
			const char *eventname,
			int t,
			double *value)
{
  void *self;                 /* timer address when hash entry generated with *_instr */
  Timer *ptr;                 /* linked list pointer */
  int numchars;               /* number of characters to copy */
  int namelen;                /* number of characters in timer name */
  unsigned int indx;          /* hash index returned from getentry (unused) */
  char new_name[MAX_CHARS+1]; /* timer name with prefix, if there is one */
  const char *name;           /* pointer to timer name */
  static const char *thisfunc = "GPTLget_eventvalue";

  if ( ! initialized)
    return GPTLerror ("%s: GPTLinitialize has not been called\n", thisfunc);

  /*
  ** If t is < 0, assume the request is for the current thread
  */

  if (t < 0) {
    if ((t = get_thread_num ()) < 0)
      return GPTLerror ("%s: get_thread_num failure\n", thisfunc);
  } else {
    if (t >= maxthreads)
      return GPTLerror ("%s: requested thread %d is too big\n", thisfunc, t);
  }

  /*
  ** If prefix string is defined, prepend it to timername
  ** and assign the name pointer to the new string. 
  ** Otherwise assign the name pointer to the original string.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    namelen = strlen(timername);
    numchars = add_prefix(new_name, timername, namelen, t);
    name = new_name;
  } else {
    name = timername;
  }

  /*
  ** Don't know whether hashtable entry for timername was generated with
  ** *_instr() or not, so try both possibilities
  */

  ptr = getentry (hashtable[t], name, &indx);
  if ( !ptr) {
    if (sscanf (timername, "%lx", (unsigned long *) &self) < 1)
      return GPTLerror ("%s: requested timer %s does not exist\n", thisfunc, timername);
    ptr = getentry_instr (hashtable[t], self, &indx);
    if ( !ptr)
      return GPTLerror ("%s: requested timer %s does not exist\n", thisfunc, timername);
  }

#ifdef HAVE_PAPI
  return GPTL_PAPIget_eventvalue (eventname, &ptr->aux, value);
#else
  return GPTLerror ("%s: PAPI not enabled\n", thisfunc);
#endif
}

/*
** GPTLget_nregions: return number of regions (i.e. timer names) for this thread
**
** Input args:
**   t:    thread number (if < 0, the request is for the current thread)
**
** Output args:
**   nregions: number of regions
*/

int GPTLget_nregions (int t,
		      int *nregions)
{
  Timer *ptr;     /* walk through linked list */
  static const char *thisfunc = "GPTLget_nregions";

  if ( ! initialized)
    return GPTLerror ("%s: GPTLinitialize has not been called\n", thisfunc);

  /*
  ** If t is < 0, assume the request is for the current thread
  */

  if (t < 0) {
    if ((t = get_thread_num ()) < 0)
      return GPTLerror ("%s: get_thread_num failure\n", thisfunc);
  } else {
    if (t >= maxthreads)
      return GPTLerror ("%s: requested thread %d is too big\n", thisfunc, t);
  }

  *nregions = 0;
  for (ptr = timers[t]->next; ptr; ptr = ptr->next)
    ++*nregions;

  return 0;
}

/*
** GPTLget_regionname: return region name for this thread
**
** Input args:
**   t:      thread number (if < 0, the request is for the current thread)
**   region: region number
**   nc:     max number of chars to put in name
**
** Output args:
**   name    region name
*/

int GPTLget_regionname (int t,      /* thread number */
			int region, /* region number (0-based) */
			char *name, /* output region name */
			int nc)     /* number of chars in name (free form Fortran) */
{
  int ncpy;    /* number of characters to copy */
  int i;       /* index */
  Timer *ptr;  /* walk through linked list */
  static const char *thisfunc = "GPTLget_regionname";

  if ( ! initialized)
    return GPTLerror ("%s: GPTLinitialize has not been called\n", thisfunc);

  /*
  ** If t is < 0, assume the request is for the current thread
  */

  if (t < 0) {
    if ((t = get_thread_num ()) < 0)
      return GPTLerror ("%s: get_thread_num failure\n", thisfunc);
  } else {
    if (t >= maxthreads)
      return GPTLerror ("%s: requested thread %d is too big\n", thisfunc, t);
  }

  ptr = timers[t]->next;
  for (i = 0; i < region; i++) {
    if ( ! ptr)
      return GPTLerror ("%s: timer number %d does not exist in thread %d\n", thisfunc, region, t);
    ptr = ptr->next;
  }

  if (ptr) {
    ncpy = MIN (nc, strlen (ptr->name));
    strncpy (name, ptr->name, ncpy);

    /*
    ** Adding the \0 is only important when called from C
    */

    if (ncpy < nc)
      name[ncpy] = '\0';
  } else {
    return GPTLerror ("%s: timer number %d does not exist in thread %d\n", thisfunc, region, t);
  }
  return 0;
}

/*
** GPTLis_initialized: Return whether GPTL has been initialized
*/

int GPTLis_initialized (void)
{
  return (int) initialized;
}

/*
** getentry_instr: find hash table entry and return a pointer to it
**
** Input args:
**   hashtable: the hashtable (array)
**   self:      input address (from -finstrument-functions)
** Output args:
**   indx:      hashtable index
**
** Return value: pointer to the entry, or NULL if not found
*/

static inline Timer *getentry_instr (const Hashentry *hashtable, /* hash table */
				     void *self,                 /* address */
				     unsigned int *indx)         /* hash index */
{
  int i;
  Timer *ptr = 0;  /* return value when entry not found */

  /*
  ** Hash index is timer address modulo the table size
  ** On most machines, right-shifting the address helps because linkers often
  ** align functions on even boundaries
  */

  *indx = (((unsigned long) self) >> 4) % tablesize;
  for (i = 0; i < hashtable[*indx].nument; ++i) {
    if (hashtable[*indx].entries[i]->address == self) {
      ptr = hashtable[*indx].entries[i];
      break;
    }
  }
  return ptr;
}

/*
** getentry: find the entry in the hash table and return a pointer to it.
**
** Input args:
**   hashtable: the hashtable (array)
**   name:      string to be hashed on (specifically, summed)
** Output args:
**   indx:      hashtable index
**
** Return value: pointer to the entry, or NULL if not found
*/

static inline Timer *getentry (const Hashentry *hashtable, /* hash table */
			       const char *name,           /* name to hash */
			       unsigned int *indx)         /* hash index */
{
  int i;                      /* multiplier for hashing; loop index */
  const unsigned char *c;     /* pointer to elements of "name" */
  Timer *ptr = 0;             /* return value when entry not found */

  /*
  ** Hash value is sum of: chars times their 1-based position index, modulo tablesize
  */

  *indx = 0;
  c = (unsigned char *) name;
  for (i = 1; *c && i < MAX_CHARS+1; ++c, ++i) {
    *indx += (*c) * i;
  }

  *indx %= tablesize;

  /*
  ** If nument exceeds 1 there was a hash collision and we must search
  ** linearly through an array for a match
  */

  for (i = 0; i < hashtable[*indx].nument; i++) {
    if (STRMATCH (name, hashtable[*indx].entries[i]->name)) {
      ptr = hashtable[*indx].entries[i];
      break;
    }
  }
  return ptr;
}

/*
** getentryf: find the entry in the hash table and return a pointer to it.
** (variant of getentry where string length is included because string
**  may not be null terminated)
**
** Input args:
**   hashtable: the hashtable (array)
**   name:      string to be hashed on (specifically, summed)
**   namelen:   number of characters in string
** Output args:
**   indx:      hashtable index
**
** Return value: pointer to the entry, or NULL if not found
*/

static inline Timer *getentryf (const Hashentry *hashtable, /* hash table */
			        const char *name,           /* name to hash */
			        const int  namelen,         /* length of name */
			        unsigned int *indx)         /* hash index */
{
  int i;                      /* multiplier for hashing; loop index */
  int numchars;               /* maximum number of characters to examine */
  const unsigned char *c;     /* pointer to elements of "name" */
  Timer *ptr = 0;             /* return value when entry not found */

  numchars = MIN (namelen, MAX_CHARS);

  /*
  ** Hash value is sum of: chars times their 1-based position index, modulo tablesize
  */

  *indx = 0;
  c = (unsigned char *) name;
  for (i = 1; i < numchars+1; ++c, ++i) {
    *indx += (*c) * i;
  }

  *indx %= tablesize;

  /*
  ** If nument exceeds 1 there was a hash collision and we must search
  ** linearly through an array for a match
  */

  for (i = 0; i < hashtable[*indx].nument; i++) {
    if (STRNMATCH (name, hashtable[*indx].entries[i]->name,numchars)) {
      ptr = hashtable[*indx].entries[i];
      break;
    }
  }
  return ptr;
}

/*
** Add entry points for auto-instrumented codes
** Auto instrumentation flags for various compilers:
**
** gcc, pathcc, icc: -finstrument-functions
** pgcc:             -Minstrument:functions
** xlc:              -qdebug=function_trace
*/

#ifdef __cplusplus
extern "C" {
#endif

#ifdef AUTO_INST
#ifdef _AIX
void __func_trace_enter (const char *function_name,
			 const char *file_name,
			 int line_number,
			 void **const user_data)
{
  (void) GPTLstart (function_name);
}

void __func_trace_exit (const char *function_name,
			const char *file_name,
			int line_number,
			void **const user_data)
{
  (void) GPTLstop (function_name);
}

#else

void __cyg_profile_func_enter (void *this_fn,
                               void *call_site)
{
  (void) GPTLstart_instr (this_fn);
}

void __cyg_profile_func_exit (void *this_fn,
                              void *call_site)
{
  (void) GPTLstop_instr (this_fn);
}
#endif
#endif

#ifdef __cplusplus
};
#endif

#ifdef HAVE_NANOTIME
#ifdef BIT64
/* 64-bit code copied from PAPI library */
static inline unsigned long long nanotime (void)
{
  unsigned long long val;
  do {
    unsigned int a,d;
    asm volatile("rdtsc" : "=a" (a), "=d" (d));
    (val) = ((unsigned long)a) | (((unsigned long)d)<<32);
  } while(0);

  return (val);
}
#else
static inline unsigned long long nanotime (void)
{
  unsigned long long val;
  __asm__ __volatile__("rdtsc" : "=A" (val) : );
  return (val);
}
#endif

#define LEN 4096

static float get_clockfreq ()
{
  FILE *fd = 0;
  char buf[LEN];
  int is;

  if ( ! (fd = fopen ("/proc/cpuinfo", "r"))) {
    fprintf (stderr, "get_clockfreq: can't open /proc/cpuinfo\n");
    return -1.;
  }

  while (fgets (buf, LEN, fd)) {
    if (strncmp (buf, "cpu MHz", 7) == 0) {
      for (is = 7; buf[is] != '\0' && !isdigit (buf[is]); is++);
      if (isdigit (buf[is]))
	return (float) atof (&buf[is]);
    }
  }

  return -1.;
}
#endif

/*
** The following are the set of underlying timing routines which may or may
** not be available. And their accompanying init routines.
** NANOTIME is currently only available on x86.
*/

static int init_nanotime ()
{
  static const char *thisfunc = "init_nanotime";
#ifdef HAVE_NANOTIME
  if ((cpumhz = get_clockfreq ()) < 0)
    return GPTLerror ("%s: Can't get clock freq\n", thisfunc);

  if (verbose)
    printf ("%s: Clock rate = %f MHz\n", thisfunc, cpumhz);

  cyc2sec = 1./(cpumhz * 1.e6);
  return 0;
#else
  return GPTLerror ("%s: not enabled\n", thisfunc);
#endif
}

static inline double utr_nanotime ()
{
#ifdef HAVE_NANOTIME
  double timestamp;
  timestamp = nanotime () * cyc2sec;
  return timestamp;
#else
  static const char *thisfunc = "utr_nanotime";
  (void) GPTLerror ("%s: not enabled\n", thisfunc);
  return -1.;
#endif
}

/*
** MPI_Wtime requires the MPI lib.
*/

static int init_mpiwtime ()
{
#ifdef HAVE_MPI
  return 0;
#else
  static const char *thisfunc = "init_mpiwtime";
  return GPTLerror ("%s: not enabled\n", thisfunc);
#endif
}

static inline double utr_mpiwtime ()
{
#ifdef HAVE_MPI
  return MPI_Wtime ();
#else
  static const char *thisfunc = "utr_mpiwtime";
  (void) GPTLerror ("%s: not enabled\n", thisfunc);
  return -1.;
#endif
}

/*
** PAPI_get_real_usec requires the PAPI lib.
*/

static int init_papitime ()
{
  static const char *thisfunc = "init_papitime";
#ifdef HAVE_PAPI
  ref_papitime = PAPI_get_real_usec ();
  if (verbose)
    printf ("%s: ref_papitime=%ld\n", thisfunc, (long) ref_papitime);
  return 0;
#else
  return GPTLerror ("%s: not enabled\n", thisfunc);
#endif
}

static inline double utr_papitime ()
{
#ifdef HAVE_PAPI
  return (PAPI_get_real_usec () - ref_papitime) * 1.e-6;
#else
  static const char *thisfunc = "utr_papitime";
  (void) GPTLerror ("%s: not enabled\n", thisfunc);
  return -1.;
#endif
}

/*
** Probably need to link with -lrt for this one to work
*/

static int init_clock_gettime ()
{
  static const char *thisfunc = "init_clock_gettime";
#ifdef HAVE_LIBRT
  struct timespec tp;
  (void) clock_gettime (CLOCK_REALTIME, &tp);
  ref_clock_gettime = tp.tv_sec;
  if (verbose)
    printf ("%s: ref_clock_gettime=%ld\n", thisfunc, (long) ref_clock_gettime);
  return 0;
#else
  return GPTLerror ("%s: not enabled\n", thisfunc);
#endif
}

static inline double utr_clock_gettime ()
{
#ifdef HAVE_LIBRT
  struct timespec tp;
  (void) clock_gettime (CLOCK_REALTIME, &tp);
  return (tp.tv_sec - ref_clock_gettime) + 1.e-9*tp.tv_nsec;
#else
  static const char *thisfunc = "utr_clock_gettime";
  (void) GPTLerror ("%s: not enabled\n", thisfunc);
  return -1.;
#endif
}

/*
** High-res timer on AIX: read_real_time
*/

static int init_read_real_time ()
{
  static const char *thisfunc = "init_read_real_time";
#ifdef _AIX
  timebasestruct_t ibmtime;
  (void) read_real_time (&ibmtime, TIMEBASE_SZ);
  (void) time_base_to_time (&ibmtime, TIMEBASE_SZ);
  ref_read_real_time = ibmtime.tb_high;
  if (verbose)
    printf ("%s: ref_read_real_time=%ld\n", thisfunc, (long) ref_read_real_time);
  return 0;
#else
  return GPTLerror ("%s: not enabled\n", thisfunc);
#endif
}

static inline double utr_read_real_time ()
{
#ifdef _AIX
  timebasestruct_t ibmtime;
  (void) read_real_time (&ibmtime, TIMEBASE_SZ);
  (void) time_base_to_time (&ibmtime, TIMEBASE_SZ);
  return (ibmtime.tb_high - ref_read_real_time) + 1.e-9*ibmtime.tb_low;
#else
  static const char *thisfunc = "utr_read_real_time";
  return GPTLerror ("%s: not enabled\n", thisfunc);
#endif
}

/*
** Default available most places: gettimeofday
*/

static int init_gettimeofday ()
{
  static const char *thisfunc = "init_gettimeofday";
#ifdef HAVE_GETTIMEOFDAY
  struct timeval tp;
  (void) gettimeofday (&tp, 0);
  ref_gettimeofday = tp.tv_sec;
  if (verbose)
    printf ("%s: ref_gettimeofday=%ld\n", thisfunc, (long) ref_gettimeofday);
  return 0;
#else
  return GPTLerror ("%s: not enabled\n", thisfunc);
#endif
}

static inline double utr_gettimeofday ()
{
#ifdef HAVE_GETTIMEOFDAY
  struct timeval tp;
  (void) gettimeofday (&tp, 0);
  return (tp.tv_sec - ref_gettimeofday) + 1.e-6*tp.tv_usec;
#else
  static const char *thisfunc = "utr_gettimeofday";
  return GPTLerror ("%s: not enabled\n", thisfunc);
#endif
}

/*
** Determine underlying timing routine overhead: call it 1000 times.
*/

static double utr_getoverhead ()
{
  double val2[1001];
  int i;

  val2[0] = (*ptr2wtimefunc)();
  for (i = 1; i < 1001; ++i) {
    val2[i] = (*ptr2wtimefunc)();
  }
  return 0.001 * (val2[1000] - val2[0]);
}

/*
** printself_andchildren: Recurse through call tree, printing stats for self, then children
*/

static void printself_andchildren (const Timer *ptr,
				   FILE *fp,
				   const int t,
				   const int depth,
				   const double tot_overhead)
{
  int n;

  if (depth > -1)     /* -1 flag is to avoid printing stats for dummy outer timer */
    printstats (ptr, fp, t, depth, true, tot_overhead);

  for (n = 0; n < ptr->nchildren; n++)
    printself_andchildren (ptr->children[n], fp, t, depth+1, tot_overhead);
}

#ifdef ENABLE_PMPI
/*
** GPTLgetentry: called ONLY from pmpi.c (i.e. not a public entry point). Returns a pointer to the
**               requested timer name by calling internal function getentry()
**
** Return value: 0 (NULL) or the return value of getentry()
*/

Timer *GPTLgetentry (const char *timername)
{
  int t;                      /* thread number */
  int numchars;               /* number of characters to copy */
  int namelen;                /* number of characters in timer name */
  unsigned int indx;          /* returned from getentry (unused) */
  char new_name[MAX_CHARS+1]; /* timer name with prefix, if there is one */
  char *name;                 /* pointer to timer name */
  static const char *thisfunc = "GPTLgetentry";

  if ( ! initialized) {
    (void) GPTLerror ("%s: initialization was not completed\n", thisfunc);
    return 0;
  }

  if ((t = get_thread_num ()) < 0) {
    (void) GPTLerror ("%s: bad return from get_thread_num\n", thisfunc);
    return 0;
  }

  /*
  ** If prefix string is defined, prepend it to timername
  ** and assign the name pointer to the new string. 
  ** Otherwise assign the name pointer to the original string.
  */

  if ((prefix_len[t] > 0) || (prefix_len_nt > 0)){
    namelen = strlen(timername);
    numchars = add_prefix(new_name, timername, namelen, t);
    name = new_name;
  } else {
    name = timername;
  }

  return (getentry (hashtable[t], name, &indx));
}

/*
** GPTLpr_file_has_been_called: Called ONLY from pmpi.c (i.e. not a public entry point). Return
**                              whether GPTLpr_file has been called. MPI_Finalize wrapper needs
**                              to know whether it needs to call GPTLpr.
*/

int GPTLpr_has_been_called (void)
{
  return (int) pr_has_been_called;
}

#endif

/*************************************************************************************/

/*
** Contents of inserted threadutil.c starts here.
** Moved to gptl.c to enable inlining
*/

/*
** $Id: gptl.c,v 1.157 2011-03-28 20:55:18 rosinski Exp $
**
** Author: Jim Rosinski
**
** Utility functions handle thread-based GPTL needs.
*/

/* Max allowable number of threads (used only when THREADED_PTHREADS is true) */
#define MAX_THREADS 128

/**********************************************************************************/
/*
** 3 sets of routines: OMP threading, PTHREADS, unthreaded
*/

#if ( defined THREADED_OMP )

/*
** threadinit: Allocate and initialize threadid_omp; set max number of threads
**
** Output results:
**   maxthreads: max number of threads
**
**   threadid_omp[] is allocated and initialized to -1
**
**
** Return value: 0 (success) or GPTLerror (failure)
*/

static int threadinit (void)
{
  int t;  /* loop index */
  static const char *thisfunc = "threadinit";

  if (omp_get_thread_num () != 0)
    return GPTLerror ("OMP %s: MUST only be called by the master thread\n", thisfunc);

  /*
  ** Allocate the threadid array which maps physical thread IDs to logical IDs
  ** For OpenMP this will be just threadid_omp[iam] = iam;
  */

  if (threadid_omp)
    return GPTLerror ("OMP %s: has already been called.\nMaybe mistakenly called by multiple threads?",
		      thisfunc);

  /*
  ** maxthreads may have been set by the user, in which case use that. But if as
  ** yet uninitialized, set to the current value of OMP_NUM_THREADS.
  */
  if (maxthreads == -1)
    maxthreads = MAX ((1), (omp_get_max_threads ()));

  if ( ! (threadid_omp = (int *) GPTLallocate (maxthreads * sizeof (int))))
    return GPTLerror ("OMP %s: malloc failure for %d elements of threadid_omp\n", thisfunc, maxthreads);

  /*
  ** Initialize threadid array to flag values for use by get_thread_num().
  ** get_thread_num() will fill in the values on first use.
  */

  for (t = 0; t < maxthreads; ++t)
    threadid_omp[t] = -1;

#ifdef VERBOSE
  printf ("OMP %s: Set maxthreads=%d\n", thisfunc, maxthreads);
#endif

  return 0;
}

/*
** Threadfinalize: clean up
**
** Output results:
**   threadid_omp array is freed and array pointer nullified
*/

static void threadfinalize ()
{
  free ((void *) threadid_omp);
  threadid_omp = 0;
}

/*
** get_thread_num: Determine thread number of the calling thread
**                 Start PAPI counters if enabled and first call for this thread.
**
** Output results:
**   nthreads:     Number of threads (=maxthreads)
**   threadid_omp: Our thread id added to list on 1st call
**
** Return value: thread number (success) or GPTLerror (failure)
*/

static inline int get_thread_num (void)
{
  int t;        /* thread number */
  static const char *thisfunc = "get_thread_num";

  if ((t = omp_get_thread_num ()) >= maxthreads)
    return GPTLerror ("OMP %s: returned id=%d exceeds maxthreads=%d\n", thisfunc, t, maxthreads);

  /*
  ** If our thread number has already been set in the list, we are done
  */

  if (t == threadid_omp[t])
    return t;

  /*
  ** Thread id not found. Modify threadid_omp with our ID, then start PAPI events if required.
  ** Due to the setting of threadid_omp, everything below here will only execute once per thread.
  */

  threadid_omp[t] = t;

#ifdef VERBOSE
  printf ("OMP %s: 1st call t=%d\n", thisfunc, t);
#endif

#ifdef HAVE_PAPI

  /*
  ** When HAVE_PAPI is true, if 1 or more PAPI events are enabled,
  ** create and start an event set for the new thread.
  */

  if (GPTLget_npapievents () > 0) {
#ifdef VERBOSE
    printf ("OMP %s: Starting EventSet t=%d\n", thisfunc, t);
#endif

    if (GPTLcreate_and_start_events (t) < 0)
      return GPTLerror ("OMP %s: error from GPTLcreate_and_start_events for thread %d\n", thisfunc, t);
  }
#endif

  /*
  ** nthreads = maxthreads based on setting in threadinit
  */

  nthreads = maxthreads;
#ifdef VERBOSE
  printf ("OMP %s: nthreads=%d\n", thisfunc, nthreads);
#endif

  return t;
}

static void print_threadmapping (FILE *fp)
{
  int n;

  fprintf (fp, "\n");
  fprintf (fp, "Thread mapping:\n");
  for (n = 0; n < nthreads; ++n)
    fprintf (fp, "threadid_omp[%d] = %d\n", n, threadid_omp[n]);
}

/*
** serial_region: determine whether in a serial or parallel region
**
** Return value: true (1) or false (0)
*/

static int serial_region ()
{

  /* 
  ** This test is more robust than 'omp_in_parallel', which is true
  ** in a parallel region when only one thread is active, which may
  ** not be thread 0. Other active thread teams also will not be
  ** recognized.
  */
  if ( (omp_get_num_threads()==1 ) && ( omp_get_level()==0 ) ){
    return 1;
  } else {
    return 0;
  }

}

/**********************************************************************************/
/*
** PTHREADS
*/

#elif ( defined THREADED_PTHREADS )

/*
** threadinit: Allocate threadid and initialize to -1; set max number of threads;
**             Initialize the mutex for later use; Initialize nthreads to 0
**
** Output results:
**   nthreads:   number of threads (init to zero here, increment later in get_thread_num)
**   maxthreads: max number of threads (MAX_THREADS)
**
**   threadid[] is allocated and initialized to -1
**   mutex is initialized for future use
**
** Return value: 0 (success) or GPTLerror (failure)
*/

static int threadinit (void)
{
  int t;        /* thread number */
  int ret;      /* return code */
  static const char *thisfunc = "threadinit";

  /*
  ** The following test is not rock-solid, but it's pretty close in terms of guaranteeing that
  ** threadinit gets called by only 1 thread. Problem is, mutex hasn't yet been initialized
  ** so we can't use it.
  */

  if (nthreads == -1)
    nthreads = 0;
  else
    return GPTLerror ("PTHREADS %s: has already been called.\n"
		      "Maybe mistakenly called by multiple threads?\n", thisfunc);

  /*
  ** Initialize the mutex required for critical regions.
  ** Previously, t_mutex = PTHREAD_MUTEX_INITIALIZER on the static declaration line was
  ** adequate to initialize the mutex. But this failed in programs that invoked
  ** GPTLfinalize() followed by GPTLinitialize().
  ** "man pthread_mutex_init" indicates that passing NULL as the second argument to
  ** pthread_mutex_init() should appropriately initialize the mutex, assuming it was
  ** properly destroyed by a previous call to pthread_mutex_destroy();
  */

#ifdef MUTEX_API
  if ((ret = pthread_mutex_init ((pthread_mutex_t *) &t_mutex, NULL)) != 0)
    return GPTLerror ("PTHREADS %s: mutex init failure: ret=%d\n", thisfunc, ret);
#endif

  /*
  ** Allocate the threadid array which maps physical thread IDs to logical IDs
  */

  if (threadid)
    return GPTLerror ("PTHREADS %s: threadid not null\n", thisfunc);
  else if ( ! (threadid = (pthread_t *) GPTLallocate (MAX_THREADS * sizeof (pthread_t))))
    return GPTLerror ("PTHREADS %s: malloc failure for %d elements of threadid\n", thisfunc, MAX_THREADS);

  maxthreads = MAX_THREADS;

  /*
  ** Initialize threadid array to flag values for use by get_thread_num().
  ** get_thread_num() will fill in the values on first use.
  */

  for (t = 0; t < maxthreads; ++t)
    threadid[t] = (pthread_t) -1;

#ifdef VERBOSE
  printf ("PTHREADS %s: Set maxthreads=%d nthreads=%d\n", thisfunc, maxthreads, nthreads);
#endif

  return 0;
}

/*
** threadfinalize: Clean up
**
** Output results:
**   threadid array is freed and array pointer nullified
**   mutex is destroyed
*/

static void threadfinalize ()
{
  int ret;

#ifdef MUTEX_API
  if ((ret = pthread_mutex_destroy ((pthread_mutex_t *) &t_mutex)) != 0)
    printf ("threadfinalize: failed attempt to destroy t_mutex: ret=%d\n", ret);
#endif
  free ((void *) threadid);
  threadid = 0;
}

/*
** get_thread_num: Determine zero-based thread number of the calling thread.
**                 Update nthreads and maxthreads if necessary.
**                 Start PAPI counters if enabled and first call for this thread.
**
** Output results:
**   nthreads: Updated number of threads
**   threadid: Our thread id added to list on 1st call
**
** Return value: thread number (success) or GPTLerror (failure)
*/

static inline int get_thread_num (void)
{
  int t;                   /* logical thread number, defined by array index of found threadid */
  pthread_t mythreadid;    /* thread id from pthreads library */
  int retval;              /* value to return to caller */
  bool foundit = false;    /* thread id found in list */
  static const char *thisfunc = "get_thread_num";

  mythreadid = pthread_self ();

  /*
  ** If our thread number has already been set in the list, we are done
  ** VECTOR code should run a bit faster on vector machines.
  */
#define VECTOR
#ifdef VECTOR
  for (t = 0; t < nthreads; ++t)
    if (pthread_equal (mythreadid, threadid[t])) {
      foundit = true;
      retval = t;
    }

  if (foundit)
    return retval;
#else
  for (t = 0; t < nthreads; ++t)
    if (pthread_equal (mythreadid, threadid[t]))
      return t;
#endif

  /*
  ** Thread id not found. Define a critical region, then start PAPI counters if
  ** necessary and modify threadid[] with our id.
  */

  if (lock_mutex () < 0)
    return GPTLerror ("PTHREADS %s: mutex lock failure\n", thisfunc);

  /*
  ** If our thread id is not in the known list, add to it after checking that
  ** we do not have too many threads.
  */

  if (nthreads >= MAX_THREADS) {
    if (unlock_mutex () < 0)
      fprintf (stderr, "PTHREADS %s: mutex unlock failure\n", thisfunc);

    return GPTLerror ("PTHREADS %s: nthreads=%d is too big. Recompile "
		      "with larger value of MAX_THREADS\n", thisfunc, nthreads);
  }

  threadid[nthreads] = mythreadid;

#ifdef VERBOSE
  printf ("PTHREADS %s: 1st call threadid=%lu maps to location %d\n",
	  thisfunc, (unsigned long) mythreadid, nthreads);
#endif

#ifdef HAVE_PAPI

  /*
  ** When HAVE_PAPI is true, if 1 or more PAPI events are enabled,
  ** create and start an event set for the new thread.
  */

  if (GPTLget_npapievents () > 0) {
#ifdef VERBOSE
    printf ("PTHREADS get_thread_num: Starting EventSet threadid=%lu location=%d\n",
	    (unsigned long) mythreadid, nthreads);
#endif
    if (GPTLcreate_and_start_events (nthreads) < 0) {
      if (unlock_mutex () < 0)
	fprintf (stderr, "PTHREADS %s: mutex unlock failure\n", thisfunc);

      return GPTLerror ("PTHREADS %s: error from GPTLcreate_and_start_events for thread %d\n",
			thisfunc, nthreads);
    }
  }
#endif

  /*
  ** IMPORTANT to set return value before unlocking the mutex!!!!
  ** "return nthreads-1" fails occasionally when another thread modifies
  ** nthreads after it gets the mutex!
  */

  retval = nthreads++;

#ifdef VERBOSE
  printf ("PTHREADS get_thread_num: nthreads bumped to %d\n", nthreads);
#endif

  if (unlock_mutex () < 0)
    return GPTLerror ("PTHREADS %s: mutex unlock failure\n", thisfunc);

  return retval;
}

/*
** lock_mutex: lock a mutex for private access
*/

static int lock_mutex ()
{
  static const char *thisfunc = "lock_mutex";

  if (pthread_mutex_lock ((pthread_mutex_t *) &t_mutex) != 0)
    return GPTLerror ("%s: failure from pthread_lock_mutex\n", thisfunc);

  return 0;
}

/*
** unlock_mutex: unlock a mutex from private access
*/

static int unlock_mutex ()
{
  static const char *thisfunc = "unlock_mutex";

  if (pthread_mutex_unlock ((pthread_mutex_t *) &t_mutex) != 0)
    return GPTLerror ("%s: failure from pthread_unlock_mutex\n", thisfunc);
  return 0;
}

static void print_threadmapping (FILE *fp)
{
  int t;

  fprintf (fp, "\n");
  fprintf (fp, "Thread mapping:\n");
  for (t = 0; t < nthreads; ++t)
    fprintf (fp, "threadid[%d] = %lu\n", t, (unsigned long) threadid[t]);
}

/*
** serial_region: determine whether in a serial or parallel region
** 
** Not currently implemented (or even defined) when using PTHREADS/
** It is an error if this is ever called.
**
** Return value: true (1) or false (0)
*/

static int serial_region ()
{
  static const char *thisfunc = "serial_region";

  return GPTLerror ("%s: not supported for THREADED_PTHREADS\n", thisfunc);

}

/**********************************************************************************/
/*
** Unthreaded case
*/

#else

static int threadinit (void)
{
  static const char *thisfunc = "threadinit";

  if (nthreads != -1)
    return GPTLerror ("Unthreaded %s: MUST only be called once", thisfunc);

  nthreads = 0;
  maxthreads = 1;
  return 0;
}

void threadfinalize ()
{
  threadid = -1;
}

static inline int get_thread_num ()
{
  static const char *thisfunc = "get_thread_num";
#ifdef HAVE_PAPI
  /*
  ** When HAVE_PAPI is true, if 1 or more PAPI events are enabled,
  ** create and start an event set for the new thread.
  */

  if (threadid == -1 && GPTLget_npapievents () > 0) {
    if (GPTLcreate_and_start_events (0) < 0)
      return GPTLerror ("Unthreaded %s: error from GPTLcreate_and_start_events for thread %0\n", thisfunc);

    threadid = 0;
  }
#endif

  nthreads = 1;
  return 0;
}

static void print_threadmapping (FILE *fp)
{
  fprintf (fp, "\n");
  fprintf (fp, "threadid[0] = 0\n");
}

/*
** serial_region: determine whether in a serial or parallel region
**
** Return value: true (1) or false (0)
*/

static int serial_region ()
{
  return 1;
}

#endif
