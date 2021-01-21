/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!       NASA/GSFC, Data Assimilation Office, Code 910.3, GEOS/DAS      !
!-----------------------------------------------------------------------
! CVS $Id$
! CVS $Name$
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE: get_zeits - a C interface to times for Fortran calls
!
! !DESCRIPTION:
!
! !INTERFACE: */
 /*
  System times() dependencies:
 */


#include <sys/types.h>
#ifndef NOTIMES
#include <sys/times.h>
#endif

#include <time.h> /* POSIX standard says CLOCKS_PER_SEC is here */
#include "config.h"
/*
 *  CLK_TCK is obsolete - replace with CLOCKS_PER_SEC
 */

#define ZCLK_TCK ((double)CLOCKS_PER_SEC)




 /*  Prototype: */

   void FC_FUNC(get_zeits,GET_ZEITS)(double *zts);
   void FC_FUNC(get_ztick,GET_ZTICK)(double *tic);

/*!REVISION HISTORY:
! 	12Mar98 - Jing Guo <guo@thunder> - initial prototype/prolog/code
! 	06Jul99 - J.W. Larson <jlarson@dao> - support for AIX platform
!EOP */

/*  Implementations: */

void FC_FUNC(get_zeits,GET_ZEITS)(zts)
  double *zts;
{

#ifndef NOTIMES
  struct tms tm;
  double secs;
  secs=1./ZCLK_TCK;

  zts[0]=times(&tm)*secs;
  zts[1]=tm.tms_utime*secs;
  zts[2]=tm.tms_stime*secs;
  zts[3]=tm.tms_cutime*secs;
  zts[4]=tm.tms_cstime*secs;
#else
  zts[0]=0.;
  zts[1]=0.;
  zts[2]=0.;
  zts[3]=0.;
  zts[4]=0.;
#endif

}

void FC_FUNC(get_ztick,GET_ZTICK)(tic)
  double *tic;
{
  tic[0]=1./ZCLK_TCK;
}

