/*
** Fortran wrappers for timing library routines that are not in GPTL.
* Ed Hartnett 4/9/19
*/

#include <string.h>
#include <stdlib.h>
#include "private.h" /* MAX_CHARS, bool */
#include "gptl.h"    /* function prototypes and HAVE_MPI logic*/
#ifdef HAVE_PAPI
#include <papi.h>
#endif /* HAVE_PAPI */

#define gptlevent_name_to_code gptlevent_name_to_code_
#define gptlevent_code_to_name gptlevent_code_to_name_
#define gptlpr_set_append gptlpr_set_append_
#define gptlpr_query_append gptlpr_query_append_
#define gptlpr_set_write gptlpr_set_write_
#define gptlpr_query_write gptlpr_query_write_

/*
** Local function prototypes
*/

int gptlpr_set_append (void);
int gptlpr_query_append (void);
int gptlpr_set_write (void);
int gptlpr_query_write (void);
static int pr_append;

#ifdef HAVE_PAPI
/* int gptl_papilibraryinit (void); */
int gptlevent_name_to_code (const char *str, int *code, int nc);
int gptlevent_code_to_name (int *code, char *str, int nc);

/** GPTL_PAPIlibraryinit: Call PAPI_library_init if necessary
 **
 ** Return value: 0 (success) or GPTLerror (failure)
 */

int GPTL_PAPIlibraryinit ()
{
    int ret;

    if ((ret = PAPI_is_initialized ()) == PAPI_NOT_INITED) {
        if ((ret = PAPI_library_init (PAPI_VER_CURRENT)) != PAPI_VER_CURRENT) {
            fprintf (stderr, "GPTL_PAPIlibraryinit: ret=%d PAPI_VER_CURRENT=%d\n",
                     ret, (int) PAPI_VER_CURRENT);
            return GPTLerror ("GPTL_PAPIlibraryinit: PAPI_library_init failure:%s\n",
                              PAPI_strerror (ret));
        }
    }
    return 0;
}

#endif

/*
** GPTLpr_set_append: set GPTLpr_file and GPTLpr_summary_file
** to use append mode
*/

int GPTLpr_set_append (void)
{
    pr_append = true;
    return 0;
}

/*
** GPTLpr_query_append: query whether GPTLpr_file and GPTLpr_summary_file
** use append mode
*/

int GPTLpr_query_append (void)
{
    if (pr_append)
        return 1;
    else
        return 0;
}

/*
** GPTLpr_set_write: set GPTLpr_file and GPTLpr_summary_file
** to use write mode
*/

int GPTLpr_set_write (void)
{
    pr_append = false;
    return 0;
}

/*
** GPTLpr_query_write: query whether GPTLpr_file and GPTLpr_summary_file
** use write mode
*/

int GPTLpr_query_write (void)
{
    if (pr_append)
        return 0;
    else
        return 1;
}


/*
** Fortran wrapper functions start here
*/

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

#ifdef HAVE_PAPI

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

    if (nc < PAPI_MAX_STR_LEN)
        return GPTLerror ("gptl_event_code_to_name: output name must hold at least %d characters\n",
                          PAPI_MAX_STR_LEN);

    if (GPTLevent_code_to_name (*code, str) == 0) {
        int i;
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
    return 0;
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
