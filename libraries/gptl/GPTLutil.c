/*
** $Id: util.c,v 1.13 2010-01-01 01:34:07 rosinski Exp $
*/

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#include "private.h"

static bool abort_on_error = false; /* flag says to abort on any error */
static int max_error = 500;         /* max number of error print msgs */

/*
** GPTLerror: error return routine to print a message and return a failure
** value.
**
** Input arguments:
**   fmt: format string
**   variable list of additional arguments for vfprintf
**
** Return value: -1 (failure)
*/

int GPTLerror (const char *fmt, ...)
{
  va_list args;

  va_start (args, fmt);
  static int num_error = 0;

  if (fmt != NULL && num_error < max_error) {
#ifndef NO_VPRINTF
    (void) vfprintf (stderr, fmt, args);
#else
    (void) fprintf (stderr, "GPTLerror: no vfprintf: fmt is %s\n", fmt);
#endif
    if (num_error == max_error)
      (void) fprintf (stderr, "Truncating further error print now after %d msgs",
		      num_error);
    ++num_error;
  }

  va_end (args);

  if (abort_on_error)
    exit (-1);

  return (-1);
}

/*
** GPTLset_abort_on_error: User-visible routine to set abort_on_error flag
**
** Input arguments:
**   val: true (abort on error) or false (don't)
*/

void GPTLset_abort_on_error (bool val)
{
  abort_on_error = val;
}

/*
** GPTLallocate: wrapper utility for malloc
**
** Input arguments:
**   nbytes: size to allocate
**
** Return value: pointer to the new space (or NULL)
*/

void *GPTLallocate (const int nbytes)
{
  void *ptr;

  if ( nbytes <= 0 || ! (ptr = malloc (nbytes)))
    (void) GPTLerror ("GPTLallocate: malloc failed for %d bytes\n", nbytes);

  return ptr;
}

