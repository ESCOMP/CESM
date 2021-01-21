/*
** $Id: f_wrappers.c,v 1.56 2010-12-29 18:46:42 rosinski Exp $
**
** Author: Jim Rosinski
** 
** Fortran wrappers for timing library routines
*/

#include <string.h>
#include <stdlib.h>
#include "private.h" /* MAX_CHARS, bool */
#include "gptl.h"    /* function prototypes and HAVE_MPI logic*/

#if ( defined FORTRANCAPS )

#define gptlinitialize GPTLINITIALIZE
#define gptlfinalize GPTLFINALIZE
#define gptlpr_set_append GPTLPR_SET_APPEND
#define gptlpr_query_append GPTLPR_QUERY_APPEND
#define gptlpr_set_write GPTLPR_SET_WRITE
#define gptlpr_query_write GPTLPR_QUERY_WRITE
#define gptlpr GPTLPR
#define gptlpr_file GPTLPR_FILE
#define gptlpr_summary GPTLPR_SUMMARY
#define gptlpr_summary_FILE GPTLPR_SUMMARY_FILE
#define gptlbarrier GPTLBARRIER
#define gptlreset GPTLRESET
#define gptlstamp GPTLSTAMP
#define gptlstart GPTLSTART
#define gptlstart_handle GPTLSTART_HANDLE
#define gptlstop GPTLSTOP
#define gptlstop_handle GPTLSTOP_HANDLE
#define gptlsetoption GPTLSETOPTION
#define gptlenable GPTLENABLE
#define gptldisable GPTLDISABLE
#define gptlsetutr GPTLSETUTR
#define gptlquery GPTLQUERY
#define gptlquerycounters GPTLQUERYCOUNTERS
#define gptlget_wallclock GPTLGET_WALLCLOCK
#define gptlget_eventvalue GPTLGET_EVENTVALUE
#define gptlget_nregions GPTLGET_NREGIONS
#define gptlget_regionname GPTLGET_REGIONNAME
#define gptlget_memusage GPTLGET_MEMUSAGE
#define gptlprint_memusage GPTLPRINT_MEMUSAGE
#define gptl_papilibraryinit GPTL_PAPILIBRARYINIT
#define gptlevent_name_to_code GPTLEVENT_NAME_TO_CODE
#define gptlevent_code_to_name GPTLEVENT_CODE_TO_NAME

#elif ( defined INCLUDE_CMAKE_FCI )

#define gptlinitialize              FCI_GLOBAL(gptlinitialize,GPTLINITIALIZE)
#define gptlfinalize                FCI_GLOBAL(gptlfinalize,GPTLFINALIZE)
#define gptlpr                      FCI_GLOBAL(gptlpr,GPTLPR)
#define gptlpr_file                 FCI_GLOBAL(gptlpr_file,GPTLPR_FILE)
#define gptlpr_summary              FCI_GLOBAL(gptlpr_summary,GPTLPR_SUMMARY)
#define gptlreset                   FCI_GLOBAL(gptlreset,GPTLRESET)
#define gptlstamp                   FCI_GLOBAL(gptlstamp,GPTLSTAMP)
#define gptlstart                   FCI_GLOBAL(gptlstart,GPTLSTART)
#define gptlstop                    FCI_GLOBAL(gptlstop,GPTLSTOP)
#define gptlsetoption               FCI_GLOBAL(gptlsetoption,GPTLSETOPTION)
#define gptlenable                  FCI_GLOBAL(gptlenable,GPTLENABLE)
#define gptldisable                 FCI_GLOBAL(gptldisable,GPTLDISABLE)
#define gptlsetutr                  FCI_GLOBAL(gptlsetutr,GPTLSETUTR)
#define gptlquery                   FCI_GLOBAL(gptlquery,GPTLQUERY)
#define gptlquerycounters           FCI_GLOBAL(gptlquerycounters,GPTLQUERYCOUNTERS)
#define gptlget_wallclock           FCI_GLOBAL(gptlget_wallclock,GPTLGET_WALLCLOCK)
#define gptlget_eventvalue          FCI_GLOBAL(gptlget_eventvalue,GPTLGET_EVENTVALUE)
#define gptlget_nregions            FCI_GLOBAL(gptlget_nregions,GPTLGET_NREGIONS)
#define gptlget_regionname          FCI_GLOBAL(gptlget_regionname,GPTLGET_REGIONNAME)
#define gptlget_memusage            FCI_GLOBAL(gptlget_memusage,GPTLGET_MEMUSAGE)
#define gptlprint_memusage          FCI_GLOBAL(gptlprint_memusage,GPTLPRINT_MEMUSAGE)
#define gptl_papilibraryinit        FCI_GLOBAL(gptl_papilibraryinit,GPTL_PAPILIBRARYINIT)
#define gptlevent_name_to_code      FCI_GLOBAL(gptlevent_name_to_code,GPTLEVENT_NAME_TO_CODE)
#define gptlevent_code_to_name      FCI_GLOBAL(gptlevent_code_to_name,GPTLEVENT_CODE_TO_NAME)
#define gptlpr_query_write          FCI_GLOBAL(gptlpr_query_write,GPTLPR_QUERY_WRITE)
#define gptlpr_summary_file         FCI_GLOBAL(gptlpr_summary_file,GPTLPR_SUMMARY_FILE)
#define gptlpr_set_write            FCI_GLOBAL(gptlpr_set_write,GPTLPR_SET_WRITE)
#define gptlpr_set_append           FCI_GLOBAL(gptlpr_set_append,GPTLPR_SET_APPEND)
#define gptlstop_handle             FCI_GLOBAL(gptlstop_handle,GPTLSTOP_HANDLE)
#define gptlstart_handle            FCI_GLOBAL(gptlstart_handle,GPTLSTART_HANDLE)
#elif ( defined FORTRANUNDERSCORE )

#define gptlinitialize gptlinitialize_
#define gptlfinalize gptlfinalize_
#define gptlpr_set_append gptlpr_set_append_
#define gptlpr_query_append gptlpr_query_append_
#define gptlpr_set_write gptlpr_set_write_
#define gptlpr_query_write gptlpr_query_write_
#define gptlpr gptlpr_
#define gptlpr_file gptlpr_file_
#define gptlpr_summary gptlpr_summary_
#define gptlpr_summary_file gptlpr_summary_file_
#define gptlbarrier gptlbarrier_
#define gptlreset gptlreset_
#define gptlstamp gptlstamp_
#define gptlstart gptlstart_
#define gptlstart_handle gptlstart_handle_
#define gptlstop gptlstop_
#define gptlstop_handle gptlstop_handle_
#define gptlsetoption gptlsetoption_
#define gptlenable gptlenable_
#define gptldisable gptldisable_
#define gptlsetutr gptlsetutr_
#define gptlquery gptlquery_
#define gptlquerycounters gptlquerycounters_
#define gptlget_wallclock gptlget_wallclock_
#define gptlget_eventvalue gptlget_eventvalue_
#define gptlget_nregions gptlget_nregions_
#define gptlget_regionname gptlget_regionname_
#define gptlget_memusage gptlget_memusage_
#define gptlprint_memusage gptlprint_memusage_
#define gptl_papilibraryinit gptl_papilibraryinit_
#define gptlevent_name_to_code gptlevent_name_to_code_
#define gptlevent_code_to_name gptlevent_code_to_name_

#elif ( defined FORTRANDOUBLEUNDERSCORE )

#define gptlinitialize gptlinitialize__
#define gptlfinalize gptlfinalize__
#define gptlpr_set_append gptlpr_set_append__
#define gptlpr_query_append gptlpr_query_append__
#define gptlpr_set_write gptlpr_set_write__
#define gptlpr_query_write gptlpr_query_write__
#define gptlpr gptlpr__
#define gptlpr_file gptlpr_file__
#define gptlpr_summary gptlpr_summary__
#define gptlpr_summary_file gptlpr_summary_file__
#define gptlbarrier gptlbarrier__
#define gptlreset gptlreset__
#define gptlstamp gptlstamp__
#define gptlstart gptlstart__
#define gptlstart_handle gptlstart_handle__
#define gptlstop gptlstop__
#define gptlstop_handle gptlstop_handle__
#define gptlsetoption gptlsetoption__
#define gptlenable gptlenable__
#define gptldisable gptldisable__
#define gptlsetutr gptlsetutr__
#define gptlquery gptlquery__
#define gptlquerycounters gptlquerycounters__
#define gptlget_wallclock gptlget_wallclock__
#define gptlget_eventvalue gptlget_eventvalue__
#define gptlget_nregions gptlget_nregions__
#define gptlget_regionname gptlget_regionname__
#define gptlget_memusage gptlget_memusage__
#define gptlprint_memusage gptlprint_memusage__
#define gptl_papilibraryinit gptl_papilibraryinit__
#define gptlevent_name_to_code gptlevent_name_to_code__
#define gptlevent_code_to_name gptlevent_code_to_name__

#endif

/*
** Local function prototypes
*/

int gptlinitialize (void);
int gptlfinalize (void);
int gptlpr_set_append (void);
int gptlpr_query_append (void);
int gptlpr_set_write (void);
int gptlpr_query_write (void);
int gptlpr (int *procid);
int gptlpr_file (char *file, int nc1);
int gptlpr_summary (int *fcomm);
int gptlpr_summary_file (int *fcomm, char *name, int nc1);
int gptlbarrier (int *fcomm, char *name, int nc1);
int gptlreset (void);
int gptlstamp (double *wall, double *usr, double *sys);
int gptlstart (char *name, int nc1);
int gptlstart_handle (char *name, void **, int nc1);
int gptlstop (char *name, int nc1);
int gptlstop_handle (char *name, void **, int nc1);
int gptlsetoption (int *option, int *val);
int gptlenable (void);
int gptldisable (void);
int gptlsetutr (int *option);
int gptlquery (const char *name, int *t, int *count, int *onflg, double *wallclock, 
		      double *usr, double *sys, long long *papicounters_out, int *maxcounters, 
		      int nc);
int gptlquerycounters (const char *name, int *t, long long *papicounters_out, int nc);
int gptlget_wallclock (const char *name, int *t, double *value, int nc);
int gptlget_eventvalue (const char *timername, const char *eventname, int *t, double *value, 
			int nc1, int nc2);
int gptlget_nregions (int *t, int *nregions);
int gptlget_regionname (int *t, int *region, char *name, int nc);
int gptlget_memusage (int *size, int *rss, int *share, int *text, int *datastack);
int gptlprint_memusage (const char *str, int nc);
#ifdef HAVE_PAPI
int gptl_papilibraryinit (void);
int gptlevent_name_to_code (const char *str, int *code, int nc);
int gptlevent_code_to_name (int *code, char *str, int nc);
#endif

/*
** Fortran wrapper functions start here
*/

int gptlinitialize (void)
{
  return GPTLinitialize ();
}

int gptlfinalize (void)
{
  return GPTLfinalize ();
}

int gptlpr_set_append (void)
{
  return GPTLpr_set_append ();
}

int gptlpr_query_append (void)
{
  return GPTLpr_set_append ();
}

int gptlpr_set_write (void)
{
  return GPTLpr_set_append ();
}

int gptlpr_query_write (void)
{
  return GPTLpr_set_append ();
}

int gptlpr (int *procid)
{
  return GPTLpr (*procid);
}

int gptlpr_file (char *file, int nc1)
{
  char *locfile;
  int ret;

  if ( ! (locfile = (char *) malloc (nc1+1)))
    return GPTLerror ("gptlpr_file: malloc error\n");

  snprintf (locfile, nc1+1, "%s", file);

  ret = GPTLpr_file (locfile);
  free (locfile);
  return ret;
}

int gptlpr_summary (int *fcomm)
{
#ifdef HAVE_MPI
  MPI_Comm ccomm;
#ifdef HAVE_COMM_F2C
  ccomm = MPI_Comm_f2c (*fcomm);
#else
  /* Punt and try just casting the Fortran communicator */
  ccomm = (MPI_Comm) *fcomm;
#endif
#else
  int ccomm = 0;
#endif 

  return GPTLpr_summary (ccomm);
}

int gptlpr_summary_file (int *fcomm, char *file, int nc1)
{
  char *locfile;
  int ret;

#ifdef HAVE_MPI
  MPI_Comm ccomm;
#ifdef HAVE_COMM_F2C
  ccomm = MPI_Comm_f2c (*fcomm);
#else
  /* Punt and try just casting the Fortran communicator */
  ccomm = (MPI_Comm) *fcomm;
#endif
#else
  int ccomm = 0;
#endif 

  if ( ! (locfile = (char *) malloc (nc1+1)))
    return GPTLerror ("gptlpr_summary_file: malloc error\n");

  snprintf (locfile, nc1+1, "%s", file);

  ret = GPTLpr_summary_file (ccomm, locfile);
  free (locfile);
  return ret;
}

int gptlbarrier (int *fcomm, char *name, int nc1)
{
  char cname[MAX_CHARS+1];
  int numchars;
#ifdef HAVE_MPI
  MPI_Comm ccomm;
#ifdef HAVE_COMM_F2C
  ccomm = MPI_Comm_f2c (*fcomm);
#else
  /* Punt and try just casting the Fortran communicator */
  ccomm = (MPI_Comm) *fcomm;
#endif
#else
  int ccomm = 0;
#endif 

  numchars = MIN (nc1, MAX_CHARS);
  strncpy (cname, name, numchars);
  cname[numchars] = '\0';
  return GPTLbarrier (ccomm, cname);
}

int gptlreset (void)
{
  return GPTLreset();
}

int gptlstamp (double *wall, double *usr, double *sys)
{
  return GPTLstamp (wall, usr, sys);
}

int gptlstart (char *name, int nc1)
{
  char cname[MAX_CHARS+1];
  int numchars;

  numchars = MIN (nc1, MAX_CHARS);
  strncpy (cname, name, numchars);
  cname[numchars] = '\0';
  return GPTLstart (cname);
}

int gptlstart_handle (char *name, void **handle, int nc1)
{
  char cname[MAX_CHARS+1];
  int numchars;

  if (*handle) {
    cname[0] = '\0';
  } else {
    numchars = MIN (nc1, MAX_CHARS);
    strncpy (cname, name, numchars);
    cname[numchars] = '\0';
  }
  return GPTLstart_handle (cname, handle);
}

int gptlstop (char *name, int nc1)
{
  char cname[MAX_CHARS+1];
  int numchars;

  numchars = MIN (nc1, MAX_CHARS);
  strncpy (cname, name, numchars);
  cname[numchars] = '\0';
  return GPTLstop (cname);
}

int gptlstop_handle (char *name, void **handle, int nc1)
{
  char cname[MAX_CHARS+1];
  int numchars;

  if (*handle) {
    cname[0] = '\0';
  } else {
    numchars = MIN (nc1, MAX_CHARS);
    strncpy (cname, name, numchars);
    cname[numchars] = '\0';
  }
  return GPTLstop_handle (cname, handle);
}

int gptlsetoption (int *option, int *val)
{
  return GPTLsetoption (*option, *val);
}

int gptlenable (void)
{
  return GPTLenable ();
}

int gptldisable (void)
{
  return GPTLdisable ();
}

int gptlsetutr (int *option)
{
  return GPTLsetutr (*option);
}

int gptlquery (const char *name, int *t, int *count, int *onflg, double *wallclock, 
	       double *usr, double *sys, long long *papicounters_out, int *maxcounters, 
	       int nc)
{
  char cname[MAX_CHARS+1];
  int numchars;

  numchars = MIN (nc, MAX_CHARS);
  strncpy (cname, name, numchars);
  cname[numchars] = '\0';
  return GPTLquery (cname, *t, count, onflg, wallclock, usr, sys, papicounters_out, *maxcounters);
}

int gptlquerycounters (const char *name, int *t, long long *papicounters_out, int nc)
{
  char cname[MAX_CHARS+1];
  int numchars;

  numchars = MIN (nc, MAX_CHARS);
  strncpy (cname, name, numchars);
  cname[numchars] = '\0';
  return GPTLquerycounters (cname, *t, papicounters_out);
}

int gptlget_wallclock (const char *name, int *t, double *value, int nc)
{
  char cname[MAX_CHARS+1];
  int numchars;

  numchars = MIN (nc, MAX_CHARS);
  strncpy (cname, name, numchars);
  cname[numchars] = '\0';

  return GPTLget_wallclock (cname, *t, value);
}

int gptlget_eventvalue (const char *timername, const char *eventname, int *t, double *value, 
			int nc1, int nc2)
{
  char ctimername[MAX_CHARS+1];
  char ceventname[MAX_CHARS+1];
  int numchars;

  numchars = MIN (nc1, MAX_CHARS);
  strncpy (ctimername, timername, numchars);
  ctimername[numchars] = '\0';

  numchars = MIN (nc2, MAX_CHARS);
  strncpy (ceventname, eventname, numchars);
  ceventname[numchars] = '\0';

  return GPTLget_eventvalue (ctimername, ceventname, *t, value);
}

int gptlget_nregions (int *t, int *nregions)
{
  return GPTLget_nregions (*t, nregions);
}

int gptlget_regionname (int *t, int *region, char *name, int nc)
{
  int n;
  int ret;

  ret = GPTLget_regionname (*t, *region, name, nc);
  /* Turn nulls into spaces for fortran */
  for (n = 0; n < nc; ++n)
    if (name[n] == '\0')
      name[n] = ' ';
  return ret;
}

int gptlget_memusage (int *size, int *rss, int *share, int *text, int *datastack)
{
  return GPTLget_memusage (size, rss, share, text, datastack);
}

int gptlprint_memusage (const char *str, int nc)
{
  char cname[128+1];
  int numchars = MIN (nc, 128);

  strncpy (cname, str, numchars);
  cname[numchars] = '\0';
  return GPTLprint_memusage (cname);
}

#ifdef HAVE_PAPI
#include <papi.h>

int gptl_papilibraryinit (void)
{
  return GPTL_PAPIlibraryinit ();
}

int gptlevent_name_to_code (const char *str, int *code, int nc)
{
  char cname[PAPI_MAX_STR_LEN+1];
  int numchars = MIN (nc, PAPI_MAX_STR_LEN);

  strncpy (cname, str, numchars);
  cname[numchars] = '\0';

  /* "code" is an int* and is an output variable */

  return GPTLevent_name_to_code (cname, code);
}

int gptlevent_code_to_name (int *code, char *str, int nc)
{
  int i;

  if (nc < PAPI_MAX_STR_LEN)
    return GPTLerror ("gptl_event_code_to_name: output name must hold at least %d characters\n",
		      PAPI_MAX_STR_LEN);

  if (GPTLevent_code_to_name (*code, str) == 0) {
    for (i = strlen(str); i < nc; ++i)
      str[i] = ' ';
  } else {
    return GPTLerror ("");
  }
  return 0;
}
#else

int gptl_papilibraryinit (void)
{
  return GPTL_PAPIlibraryinit ();
}

int gptlevent_name_to_code (const char *str, int *code, int nc)
{
  return GPTLevent_name_to_code (str, code);
}

int gptlevent_code_to_name (const int *code, char *str, int nc)
{
  return GPTLevent_code_to_name (*code, str);
}

#endif
