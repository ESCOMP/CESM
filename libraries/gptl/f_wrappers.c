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
#define gptlprint_mode_query GPTLPRINT_MODE_QUERY
#define gptlprint_mode_set GPTLPRINT_MODE_SET
#define gptlpr GPTLPR
#define gptlpr_file GPTLPR_FILE
#define gptlpr_summary GPTLPR_SUMMARY
#define gptlpr_summary_FILE GPTLPR_SUMMARY_FILE
#define gptlbarrier GPTLBARRIER
#define gptlprefix_set GPTLPREFIX_SET
#define gptlprefix_unset GPTLPREFIX_UNSET
#define gptlreset GPTLRESET
#define gptlstamp GPTLSTAMP
#define gptlstart GPTLSTART
#define gptlstart_handle GPTLSTART_HANDLE
#define gptlstop GPTLSTOP
#define gptlstop_handle GPTLSTOP_HANDLE
#define gptlstartstop_vals GPTLSTARTSTOP_VALS
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
#define gptlprint_mode_query        FCI_GLOBAL(gptlprint_mode_query,GPTLPRINT_MODE_QUERY)
#define gptlprint_mode_set          FCI_GLOBAL(gptlprint_mode_set,GPTLPRINT_MODE_SET)
#define gptlpr                      FCI_GLOBAL(gptlpr,GPTLPR)
#define gptlpr_file                 FCI_GLOBAL(gptlpr_file,GPTLPR_FILE)
#define gptlpr_summary              FCI_GLOBAL(gptlpr_summary,GPTLPR_SUMMARY)
#define gptlpr_summary_file         FCI_GLOBAL(gptlpr_summary_file,GPTLPR_SUMMARY_FILE)
#define gptlbarrier                 FCI_GLOBAL(gptlbarrier,GPTLBARRIER)
#define gptlprefix_set              FCI_GLOBAL(gptlprefix_set,GPTLPREFIX_SET)
#define gptlprefix_unset            FCI_GLOBAL(gptlprefix_unset,GPTLPREFIX_UNSET)
#define gptlreset                   FCI_GLOBAL(gptlreset,GPTLRESET)
#define gptlstamp                   FCI_GLOBAL(gptlstamp,GPTLSTAMP)
#define gptlstart                   FCI_GLOBAL(gptlstart,GPTLSTART)
#define gptlstart_handle            FCI_GLOBAL(gptlstart_handle,GPTLSTART_HANDLE)
#define gptlstop                    FCI_GLOBAL(gptlstop,GPTLSTOP)
#define gptlstop_handle             FCI_GLOBAL(gptlstop_handle,GPTLSTOP_HANDLE)
#define gptlstartstop_vals          FCI_GLOBAL(gptlstartstop_vals,GPTLSTARTSTOP_VALS)
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

#elif ( defined FORTRANUNDERSCORE )

#define gptlinitialize gptlinitialize_
#define gptlfinalize gptlfinalize_
#define gptlprint_mode_query gptlprint_mode_query_
#define gptlprint_mode_set gptlprint_mode_set_
#define gptlpr gptlpr_
#define gptlpr_file gptlpr_file_
#define gptlpr_summary gptlpr_summary_
#define gptlpr_summary_file gptlpr_summary_file_
#define gptlbarrier gptlbarrier_
#define gptlprefix_set gptlprefix_set_
#define gptlprefix_unset gptlprefix_unset_
#define gptlreset gptlreset_
#define gptlstamp gptlstamp_
#define gptlstart gptlstart_
#define gptlstart_handle gptlstart_handle_
#define gptlstop gptlstop_
#define gptlstop_handle gptlstop_handle_
#define gptlstartstop_vals gptlstartstop_vals_
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
#define gptlprint_mode_query gptlprint_mode_query__
#define gptlprint_mode_set gptlprint_mode_set__
#define gptlpr gptlpr__
#define gptlpr_file gptlpr_file__
#define gptlpr_summary gptlpr_summary__
#define gptlpr_summary_file gptlpr_summary_file__
#define gptlbarrier gptlbarrier__
#define gptlprefix_set gptlprefix_set__
#define gptlprefix_unset gptlprefix_unset__
#define gptlreset gptlreset__
#define gptlstamp gptlstamp__
#define gptlstart gptlstart__
#define gptlstart_handle gptlstart_handle__
#define gptlstop gptlstop__
#define gptlstop_handle gptlstop_handle__
#define gptlstartstop_vals gptlstartstop_vals__
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
int gptlprint_mode_query (void);
int gptlprint_mode_set (int *pr_mode);
int gptlpr (int *procid);
int gptlpr_file (char *file, int nc1);
int gptlpr_summary (int *fcomm);
int gptlpr_summary_file (int *fcomm, char *name, int nc1);
int gptlbarrier (int *fcomm, char *name, int nc1);
int gptlprefix_set (char *name, int nc1);
int gptlprefix_unset (void);
int gptlreset (void);
int gptlstamp (double *wall, double *usr, double *sys);
int gptlstart (char *name, int nc1);
int gptlstart_handle (char *name, void **, int nc1);
int gptlstop (char *name, int nc1);
int gptlstop_handle (char *name, void **, int nc1);
int gptlstartstop_vals (char *name, double *val, int *cnt, int nc1);
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

int gptlprint_mode_query (void)
{
  return GPTLprint_mode_query ();
}

int gptlprint_mode_set (int *pr_mode)
{
  return GPTLprint_mode_set (*pr_mode);
}

int gptlpr (int *procid)
{
  return GPTLpr (*procid);
}

int gptlpr_file (char *file, int nc1)
{
  char *locfile;
  int c;
  int ret;

  if ( ! (locfile = (char *) malloc (nc1+1)))
    return GPTLerror ("gptlpr_file: malloc error\n");

  //pw  snprintf (locfile, nc1+1, "%s", file);
  for (c = 0; c < nc1; c++) {
    locfile[c] = file[c];
  }
  locfile[c] = '\0';

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
  int c;
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

  //pw  snprintf (locfile, nc1+1, "%s", file);
  for (c = 0; c < nc1; c++) {
    locfile[c] = file[c];
  }
  locfile[c] = '\0';

  ret = GPTLpr_summary_file (ccomm, locfile);
  free (locfile);
  return ret;
}

int gptlbarrier (int *fcomm, char *name, int nc1)
{
  char cname[MAX_CHARS+1];
  int c;
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
  //pw  strncpy (cname, name, numchars);
  for (c = 0; c < numchars; c++) {
    cname[c] = name[c];
  }
  cname[numchars] = '\0';
  return GPTLbarrier (ccomm, cname);
}

int gptlprefix_set (char *name, int nc1)
{
  /*  char cname[MAX_CHARS+1]; */
  /*  int numchars; */

  /*  numchars = MIN (nc1, MAX_CHARS);*/
  /*  strncpy (cname, name, numchars);*/
  /*  cname[numchars] = '\0';*/
  /*  return GPTLprefix_set (cname);*/
  return GPTLprefix_setf (name, nc1);
}

int gptlprefix_unset (void)
{
  return GPTLprefix_unset ();
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
  /*  char cname[MAX_CHARS+1]; */
  /*  int numchars; */

  /*  numchars = MIN (nc1, MAX_CHARS);*/
  /*  strncpy (cname, name, numchars);*/
  /*  cname[numchars] = '\0';*/
  /*  return GPTLstart (cname);*/
  return GPTLstartf (name, nc1);
}

int gptlstart_handle (char *name, void **handle, int nc1)
{
  /*  char cname[MAX_CHARS+1];*/
  /*  int numchars;*/

  /*  if (*handle) {*/
  /*    cname[0] = '\0';*/
  /*  } else {*/
  /*    numchars = MIN (nc1, MAX_CHARS);*/
  /*    strncpy (cname, name, numchars);*/
  /*    cname[numchars] = '\0';*/
  /*  }*/
  /*  return GPTLstart_handle (cname, handle);*/
  return GPTLstartf_handle (name, nc1, handle);
}

int gptlstop (char *name, int nc1)
{
  /*  char cname[MAX_CHARS+1];*/
  /*  int numchars;*/

  /*  numchars = MIN (nc1, MAX_CHARS);*/
  /*  strncpy (cname, name, numchars);*/
  /*  cname[numchars] = '\0';*/
  /*  return GPTLstop (cname);*/
  return GPTLstopf (name, nc1);
}

int gptlstop_handle (char *name, void **handle, int nc1)
{
  /*  char cname[MAX_CHARS+1];*/
  /*  int numchars;*/

  /*  if (*handle) {*/
  /*    cname[0] = '\0';*/
  /*  } else {*/
  /*    numchars = MIN (nc1, MAX_CHARS);*/
  /*    strncpy (cname, name, numchars);*/
  /*    cname[numchars] = '\0';*/
  /*  }*/
  /*  return GPTLstop_handle (cname, handle);*/
  return GPTLstopf_handle (name, nc1, handle);
}

int gptlstartstop_vals (char *name, double *val, int *cnt, int nc1)
{
  /*  char cname[MAX_CHARS+1];*/
  /*  int c;*/
  /*  int numchars;*/

  /*  numchars = MIN (nc1, MAX_CHARS);*/
  //pw  strncpy (cname, name, numchars);
  /*  for (c = 0; c < numchars; c++) {*/
  /*    cname[c] = name[c];*/
  /*  }*/
  /*  cname[numchars] = '\0';*/
  /*  return GPTLstartstop_vals (cname, *val, *cnt);*/
  return GPTLstartstop_valsf (name, nc1, *val, *cnt);
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
  int c;
  int numchars;

  numchars = MIN (nc, MAX_CHARS);
  //pw  strncpy (cname, name, numchars);
  for (c = 0; c < numchars; c++) {
    cname[c] = name[c];
  }
  cname[numchars] = '\0';
  return GPTLquery (cname, *t, count, onflg, wallclock, usr, sys, papicounters_out, *maxcounters);
}

int gptlquerycounters (const char *name, int *t, long long *papicounters_out, int nc)
{
  char cname[MAX_CHARS+1];
  int c;
  int numchars;

  numchars = MIN (nc, MAX_CHARS);
  //pw  strncpy (cname, name, numchars);
  for (c = 0; c < numchars; c++) {
    cname[c] = name[c];
  }
  cname[numchars] = '\0';
  return GPTLquerycounters (cname, *t, papicounters_out);
}

int gptlget_wallclock (const char *name, int *t, double *value, int nc)
{
  char cname[MAX_CHARS+1];
  int c;
  int numchars;

  numchars = MIN (nc, MAX_CHARS);
  //pw  strncpy (cname, name, numchars);
  for (c = 0; c < numchars; c++) {
    cname[c] = name[c];
  }
  cname[numchars] = '\0';

  return GPTLget_wallclock (cname, *t, value);
}

int gptlget_eventvalue (const char *timername, const char *eventname, int *t, double *value,
			int nc1, int nc2)
{
  char ctimername[MAX_CHARS+1];
  char ceventname[MAX_CHARS+1];
  int c;
  int numchars;

  numchars = MIN (nc1, MAX_CHARS);
  //pw  strncpy (ctimername, timername, numchars);
  for (c = 0; c < numchars; c++) {
    ctimername[c] = timername[c];
  }
  ctimername[numchars] = '\0';

  numchars = MIN (nc2, MAX_CHARS);
  //pw  strncpy (ceventname, eventname, numchars);
  for (c = 0; c < numchars; c++) {
    ceventname[c] = eventname[c];
  }
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
  int c;
  int numchars = MIN (nc, 128);

  //pw  strncpy (cname, str, numchars);
  for (c = 0; c < numchars; c++) {
    cname[c] = str[c];
  }
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
  int c;
  int numchars = MIN (nc, PAPI_MAX_STR_LEN);

  //pw  strncpy (cname, str, numchars);
  for (c = 0; c < numchars; c++) {
    cname[c] = str[c];
  }
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
