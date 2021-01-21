#include "type.h"

  /* Here are the statically initialized structs for the predefined datatypes.
   */

  //C type structs
  Typestruct TSchar   = {.count=1,     .lb=0,   .ub=sizeof(char),
                         .committed=1, .o_lb=0, .o_ub=0, .pairs[0] =
			 {.disp = 0,   .type = (Simpletype) SIMPLE_CHAR }};
  Typestruct TSshort  = {.count=1,     .lb=0,   .ub=sizeof(short),
                         .committed=1, .o_lb=0, .o_ub=0, .pairs[0] =
			 {.disp = 0,   .type = (Simpletype) SIMPLE_SHORT }};
  Typestruct TSint    = {.count = 1,   .lb = 0,   .ub=sizeof(int),
                         .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			 {.disp = 0,   .type = (Simpletype) SIMPLE_INT }};
  Typestruct TSlong   = {.count = 1,   .lb = 0,   .ub = sizeof(long),
                         .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0] =
			 {.disp = 0,   .type = (Simpletype) SIMPLE_LONG }};
  Typestruct TSuchar  = {.count = 1,   .lb = 0, .ub=sizeof(unsigned char),
                         .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0] =
			 {.disp = 0,   .type = (Simpletype) SIMPLE_UCHAR }};
  Typestruct TSushort = {.count = 1,   .lb = 0, .ub=sizeof(unsigned short),
                         .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0] =
			 {.disp = 0,   .type = (Simpletype) SIMPLE_USHORT }};
  Typestruct TSuint   = {.count = 1,   .lb = 0,   .ub = sizeof(unsigned int),
                         .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0] =
			 {.disp = 0,   .type = (Simpletype) SIMPLE_UINT }};
  Typestruct TSulong  = {.count = 1,   .lb = 0, .ub = sizeof(unsigned long),
                         .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0] =
			 {.disp = 0,   .type = (Simpletype) SIMPLE_ULONG }};
  Typestruct TSfloat  = {.count = 1,   .lb = 0, .ub = sizeof(float),
                         .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0] =
			 {.disp = 0,   .type = (Simpletype) SIMPLE_FLOAT }};
  Typestruct TSdouble = {.count = 1,   .lb = 0, .ub = sizeof(double),
                         .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0] =
			 {.disp = 0,   .type = (Simpletype) SIMPLE_DOUBLE }};
  Typestruct TSldouble = {.count = 1,  .lb = 0, .ub = sizeof(long double),
                         .committed=1,.o_lb = 0, .o_ub = 0, .pairs[0] =
			  {.disp = 0, .type = (Simpletype) SIMPLE_LDOUBLE }};

  //Cross-language types
  Typestruct TSbyte = { .count = 1, .lb = 0, .ub = sizeof(char), .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_BYTE } };
  Typestruct TSpacked = { .count = 1, .lb = 0, .ub = sizeof(char), .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_BYTE } };
  Typestruct TSlower = { .count = 1, .lb = 0, .ub = 0, .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_LOWER } };
  Typestruct TSupper = { .count = 1, .lb = 0, .ub = 0, .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_UPPER } };

  //Fortran type structs
  Typestruct TSinteger = { .count = 1, .lb = 0, .ub = FSIZE_INTEGER, .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_FINTEGER } };
  Typestruct TSreal = { .count = 1, .lb = 0, .ub = FSIZE_REAL, .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_FREAL } };
  Typestruct TSdprecision = { .count = 1, .lb = 0, .ub = FSIZE_DPRECISION, .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_FDPRECISION } };
  Typestruct TScomplex = { .count = 1, .lb = 0, .ub = FSIZE_COMPLEX, .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_FCOMPLEX } };
  Typestruct TSdcomplex = { .count = 1, .lb = 0, .ub = FSIZE_DCOMPLEX, .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_FDCOMPLEX } };
  Typestruct TSlogical = { .count = 1, .lb = 0, .ub = FSIZE_LOGICAL, .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_FLOGICAL } };
  Typestruct TScharacter = { .count = 1, .lb = 0, .ub = FSIZE_CHARACTER, .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_FCHARACTER } };

  /*Reduction function types (C)
   */
  Typestruct TSfloat_int   = { .count = 2, .lb = 0, .ub = sizeof(struct {float a; int b;}), .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_FLOAT },
                         .pairs[1] = { .disp=sizeof(float), .type = (Simpletype) SIMPLE_INT}};
  Typestruct TSdouble_int  = { .count = 2, .lb = 0, .ub =  sizeof(struct {double a; int b;}), .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_DOUBLE },
                         .pairs[1] = { .disp=sizeof(double), .type = (Simpletype) SIMPLE_INT}};
  Typestruct TSlong_int    = { .count = 2, .lb = 0, .ub = sizeof(struct {long a; int b;}), .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_LONG },
                         .pairs[1] = { .disp=sizeof(long), .type = (Simpletype) SIMPLE_INT}};
  Typestruct TS2int       = { .count = 2, .lb = 0, .ub = 2*sizeof(int), .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_INT },
                         .pairs[1] = { .disp=sizeof(int), .type = (Simpletype) SIMPLE_INT}};
  Typestruct TSshort_int   = { .count = 2, .lb = 0, .ub = sizeof(struct {short a; int b;}), .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_SHORT },
                         .pairs[1] = { .disp=sizeof(int), .type = (Simpletype) SIMPLE_INT}};
  Typestruct TSldouble_int = { .count = 2, .lb = 0, .ub = sizeof(struct {long double a; int b;}), .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_LDOUBLE },
                         .pairs[1] = { .disp=sizeof(long double), .type = (Simpletype) SIMPLE_INT}};

  /* Reduction function types (Fortran)
   */
  Typestruct TS2real       = { .count = 2, .lb = 0, .ub = 2*FSIZE_REAL, .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_FREAL },
                         .pairs[1] = { .disp=FSIZE_REAL, .type = (Simpletype) SIMPLE_FREAL}};
  Typestruct TS2dprecision = { .count = 2, .lb = 0, .ub = 2*FSIZE_DPRECISION, .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_FDPRECISION },
                         .pairs[1] = { .disp=FSIZE_DPRECISION, .type = (Simpletype) SIMPLE_FDPRECISION}};
  Typestruct TS2integer    = { .count = 2, .lb = 0, .ub = 2*FSIZE_INTEGER, .committed = 1,
   .o_lb = 0, .o_ub = 0, .pairs[0] = { .disp = 0, .type = (Simpletype) SIMPLE_FINTEGER },
                         .pairs[1] = { .disp=FSIZE_INTEGER, .type = (Simpletype) SIMPLE_FINTEGER}};


  /* Fortran sized types
   */

  Typestruct TSinteger1  = {.count = 1,   .lb = 0,   .ub=1,
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_FINTEGER1 }};

  Typestruct TSinteger2  = {.count = 1,   .lb = 0,   .ub=2,
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_FINTEGER2 }};

  Typestruct TSinteger4  = {.count = 1,   .lb = 0,   .ub=4,
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_FINTEGER4 }};

  Typestruct TSinteger8  = {.count = 1,   .lb = 0,   .ub=8,
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_FINTEGER8 }};

  Typestruct TSinteger16 = {.count = 1,   .lb = 0,   .ub=16,
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_FINTEGER16 }};


  Typestruct TSreal4     = {.count = 1,   .lb = 0,   .ub=4,
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_FREAL4 }};

  Typestruct TSreal8     = {.count = 1,   .lb = 0,   .ub=8,
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_FREAL8 }};

  Typestruct TSreal16    = {.count = 1,   .lb = 0,   .ub=16,
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_FREAL16 }};

  Typestruct TScomplex8  = {.count = 1,   .lb = 0,   .ub=8,
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_FCOMPLEX8 }};

  Typestruct TScomplex16 = {.count = 1,   .lb = 0,   .ub=16,
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_FCOMPLEX16 }};

  Typestruct TScomplex32 = {.count = 1,   .lb = 0,   .ub=32,
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_FCOMPLEX32 }};

  /* Additions
   */

Typestruct TSlonglong  = {.count = 1,   .lb = 0,   .ub=sizeof(long long),
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_LONGLONG }};

Typestruct TSulonglong = {.count = 1,   .lb = 0,   .ub=sizeof(unsigned long long),
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_ULONGLONG }};

Typestruct TSoffset = {.count = 1,   .lb = 0,   .ub=sizeof(MPI_Offset),
                            .committed=1, .o_lb = 0, .o_ub = 0, .pairs[0]=
			    {.disp = 0,   .type = (Simpletype) SIMPLE_OFFSET }};



 /* RML NOTE: the order and numbering of the elements of simpletypes[] MUST match
  * the values for the MPI type constants e.g. MPI_INT
  * This should be coded in a better way to avoid human error.
  */

  const Datatype simpletypes[64] =
                      {&TSchar    , &TSshort     , &TSint        , &TSlong,
		       &TSuchar   , &TSushort    , &TSuint       , &TSulong,      //4
		       &TSfloat   , &TSdouble    , &TSldouble    , &TSbyte,       //8
		       &TSpacked  , &TSlower     , &TSupper      , &TSinteger,    //12
		       &TSreal    , &TSdprecision, &TScomplex    , &TSdcomplex,   //16
		       &TSlogical , &TScharacter , &TS2real      , &TS2dprecision,//20
		       &TS2integer, &TSfloat_int , &TSdouble_int , &TSlong_int,   //24
		       &TS2int    , &TSshort_int , &TSldouble_int, &TSinteger1,   //28
                       &TSinteger2, &TSinteger4  , &TSinteger8   , &TSinteger16,  //32
                       &TSreal4	  , &TSreal8	 , &TSreal16     , &TScomplex8,   //36
                       &TScomplex16, &TScomplex32, &TSlonglong   , &TSulonglong,  //40
                       &TSoffset
                       };


  /* optional datatypes (Fortran)  MPI_INTEGER1 MPI_INTEGER2 MPI_INTEGER4 MPI_REAL2 MPI_REAL4 MPI_REAL8

  /* optional datatypes (C)  MPI_LONG_LONG_INT */
