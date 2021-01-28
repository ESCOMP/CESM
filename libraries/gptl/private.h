/*
** $Id: private.h,v 1.74 2011-03-28 20:55:19 rosinski Exp $
**
** Author: Jim Rosinski
**
** Contains definitions private to GPTL and inaccessible to invoking user environment
*/

#include <stdio.h>
#include <sys/time.h>

#ifndef NO_COMM_F2C
#ifndef HAVE_COMM_F2C
#define HAVE_COMM_F2C
#endif
#endif

#ifndef MIN
#define MIN(X,Y) ((X) < (Y) ? (X) : (Y))
#endif

#ifndef MAX
#define MAX(X,Y) ((X) > (Y) ? (X) : (Y))
#endif

#define STRMATCH(X,Y) (strcmp((X),(Y)) == 0)

#define STRNMATCH(X,Y,N) (strncmp((X),(Y),(N)) == 0)

/* Output counts less than PRTHRESH will be printed as integers */
#define PRTHRESH 1000000L

/* Maximum allowed callstack depth */
#define MAX_STACK 128

/* longest timer name allowed (probably safe to just change) */
#define MAX_CHARS 127

/*
** max allowable number of PAPI counters, or derived events. For convenience,
** set to max (# derived events, # papi counters required) so "avail" lists
** all available options.
*/
#define MAX_AUX 9

#ifndef __cplusplus
typedef enum {false = 0, true = 1} bool;  /* mimic C++ */
#endif

typedef struct {
  long last_utime;          /* saved usr time from "start" */
  long last_stime;          /* saved sys time from "start" */
  long accum_utime;         /* accumulator for usr time */
  long accum_stime;         /* accumulator for sys time */
} Cpustats;

typedef struct {
  double last;              /* timestamp from last call */
  double latest;            /* most recent delta */
  double accum;             /* accumulated time */
  float max;                /* longest time for start/stop pair */
  float min;                /* shortest time for start/stop pair */
  float prev_min;           /* previous shortest time for start/stop pair */
  int latest_is_min;        /* whether min is current latest (1) or not (0) */
} Wallstats;

typedef struct {
  long long last[MAX_AUX];  /* array of saved counters from "start" */
  long long accum[MAX_AUX]; /* accumulator for counters */
} Papistats;

typedef struct {
  int counter;      /* PAPI or Derived counter */
  char *namestr;    /* PAPI or Derived counter as string */
  char *str8;       /* print string for output timers (8 chars) */
  char *str16;      /* print string for output timers (16 chars) */
  char *longstr;    /* long descriptive print string */
} Entry;

typedef struct {
  Entry event;
  int numidx;       /* derived event: PAPI counter array index for numerator */
  int denomidx;     /* derived event: PAPI counter array index for denominator */
} Pr_event;

typedef struct TIMER {
  char name[MAX_CHARS+1];   /* timer name (user input) */
  bool onflg;               /* timer currently on or off */
#ifdef ENABLE_PMPI
  double nbytes;            /* number of bytes for MPI call */
#endif
#ifdef HAVE_PAPI
  Papistats aux;            /* PAPI stats  */
#endif
  Wallstats wall;           /* wallclock stats */
  Cpustats cpu;             /* cpu stats */
  unsigned long count;      /* number of start/stop calls */
  unsigned long nrecurse;   /* number of recursive start/stop calls */
  void *address;            /* address of timer: used only by _instr routines */
  struct TIMER *next;       /* next timer in linked list */
  struct TIMER **parent;    /* array of parents */
  struct TIMER **children;  /* array of children */
  int *parent_count;        /* array of call counts, one for each parent */
  unsigned int recurselvl;  /* recursion level */
  unsigned int nchildren;   /* number of children */
  unsigned int nparent;     /* number of parents */
  unsigned int norphan;     /* number of times this timer was an orphan */
  int num_desc;             /* number of descendants */
} Timer;

typedef struct {
  Timer **entries;          /* array of timers hashed to the same value */
  unsigned int nument;      /* number of entries hashed to the same value */
} Hashentry;

/* Function prototypes */

extern int GPTLerror (const char *, ...);      /* print error msg and return */
extern void GPTLset_abort_on_error (bool val); /* set flag to abort on error */
extern void *GPTLallocate (const int);         /* malloc wrapper */

extern int GPTLstart_instr (void *);           /* auto-instrumented start */
extern int GPTLstop_instr (void *);            /* auto-instrumented stop */
extern int GPTLis_initialized (void);          /* needed by MPI_Init wrapper */

#ifdef __cplusplus
extern "C" {
#endif

#ifdef AUTO_INST
extern void __cyg_profile_func_enter (void *, void *);
extern void __cyg_profile_func_exit (void *, void *);
#endif

#ifdef __cplusplus
};
#endif

/*
** These are needed for communication between gptl.c and gptl_papi.c
*/

#ifdef HAVE_PAPI
extern int GPTL_PAPIsetoption (const int, const int);
extern int GPTL_PAPIinitialize (const int, const bool, int *, Entry *);
extern int GPTL_PAPIstart (const int, Papistats *);
extern int GPTL_PAPIstop (const int, Papistats *);
extern void GPTL_PAPIprstr (FILE *);
extern void GPTL_PAPIpr (FILE *, const Papistats *, const int, const int, const double);
extern void GPTL_PAPIadd (Papistats *, const Papistats *);
extern void GPTL_PAPIfinalize (int);
extern void GPTL_PAPIquery (const Papistats *, long long *, int);
extern int GPTL_PAPIget_eventvalue (const char *, const Papistats *, double *);
extern bool GPTL_PAPIis_multiplexed (void);
extern void GPTL_PAPIprintenabled (FILE *);
extern void read_counters100 (void);
extern int GPTLget_npapievents (void);
extern int GPTLcreate_and_start_events (const int);
#endif

#ifdef ENABLE_PMPI
extern Timer *GPTLgetentry (const char *);
extern int GPTLpmpi_setoption (const int, const int);
extern int GPTLpr_has_been_called (void);      /* needed by MPI_Finalize wrapper*/
#endif
