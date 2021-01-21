#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#ifdef TEST_INTERNAL
#include <mpiP.h>
#include <type.h>
#else
MPI_Request req;
#endif


int errcount = 0;
//simplest example:  contiguous
// type of 5 MPI_INT

void test_simple_contig()
{
  int i;
  int a [5] = {1, 2, 3, 4, 5};
  int b [5];
  MPI_Datatype contig_type;

  //Contiguous type of simple types
  printf("\nContiguous type of 5 x MPI_INT\n");
  MPI_Type_contiguous(5, MPI_INT, &contig_type);
  MPI_Type_commit(&contig_type);

#ifdef TEST_INTERNAL
  print_typemap(contig_type);
  copy_data(&a, &b, contig_type);
#else
  MPI_Isend(&a, 1, contig_type, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&b, 1, contig_type, MPI_ANY_SOURCE, MPI_ANY_TAG, MPI_COMM_WORLD,&req);
#endif

  printf("a = [");
  for (i = 0; i < 5; i++)
    printf("%d ", a[i]);
  printf("]\n");

  printf("b = [");
  for (i = 0; i < 5; i++)
    printf("%d ", b[i]);
  printf("]\n");

  for (i = 0; i < 5; i++)
    if (a[i]!=b[i])
    {
      printf(">>>FAILED: test_simple_contig\n");
      errcount++;
      return;
    }
}

// vector type of MPI_INTs

void test_simple_vector()
{
  int i;
  int a[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
  int b[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
  int index_test []= {0, 1, 3, 4, 6, 7};
  MPI_Datatype vector_type;

  //Vector type of simple types
  printf("\nVector type of 3 groups of 2 MPI_INT, stride of 3.\n");
  MPI_Type_vector(3, 2, 3, MPI_INT, &vector_type);
  MPI_Type_commit(&vector_type);

#ifdef TEST_INTERNAL
  print_typemap(vector_type);
  copy_data(&a, &b, vector_type);
#else
  MPI_Isend(&a, 1, vector_type, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&b, 1, vector_type, 0, 0, MPI_COMM_WORLD, &req);
#endif

  printf("a = [");
  for (i = 0; i < 10; i++)
    printf("%d ", a[i]);
  printf("]\n");

  printf("b = [");
  for (i = 0; i < 10; i++)
    printf("%d ", b[i]);
  printf("]\n");

  for (i = 0; i < 6; i++)
    if (a[index_test[i]]!=b[index_test[i]])
    {
      printf(">>>FAILED: test_simple_vector\n");
      errcount++;
      return;
    }
}
//vector type (byte addressed, using
// sizeof(int) to compute stride

void test_simple_hvector()
{
  MPI_Datatype vector_type;
  int i;
  int a[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
  int b[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  int index_test [6] = {0, 1, 4, 5, 8, 9};
  //Vector (byte-addressed) of simple types
  printf("\nVector type of 3 groups of 2 MPI_INT, stride of 16 bytes.\n");
  MPI_Type_hvector(3, 2, 4*sizeof(int), MPI_INT, &vector_type);
  MPI_Type_commit(&vector_type);

#ifdef TEST_INTERNAL
  print_typemap(vector_type);
  copy_data(&a, &b, vector_type);
#else
  MPI_Isend(&a, 1, vector_type, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&b, 1, vector_type, 0, 0, MPI_COMM_WORLD, &req);
#endif

  printf("a = [");
  for (i = 0; i < 10; i++)
    printf("%d ", a[i]);
  printf("]\n");

  printf("b = [");
  for (i = 0; i < 10; i++)
    printf("%d ", b[i]);
  printf("]\n");

  for (i = 0; i < 6; i++)
    if (a[index_test[i]]!=b[index_test[i]])
    {
      printf(">>>FAILED: test_simple_hvector\n");
      errcount++;
      return;
    }
}

//indexed type.

void test_simple_indexed()
{
  int i;
  int a[15] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15};
  int b[15] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  int index_test [6] = {0, 5, 6, 10, 11, 12};
  int blens[3] = {2, 1, 3};
  int disps[3] = {5, 0, 10};
  MPI_Datatype indexed_type;
  //Indexed of simple types

  printf("\nIndexed type of MPI_INT.\n");

  MPI_Type_indexed(3, blens, disps, MPI_INT, &indexed_type);
  MPI_Type_commit(&indexed_type);

#ifdef TEST_INTERNAL
  print_typemap(indexed_type);
  copy_data(&a, &b, indexed_type);
#else
  MPI_Isend(&a, 1, indexed_type, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&b, 1, indexed_type, 0, 0, MPI_COMM_WORLD, &req);
#endif

  printf("a = [");
  for (i = 0; i < 15; i++)
    printf("%d ", a[i]);
  printf("]\n");

  printf("b = [");
  for (i = 0; i < 15; i++)
    printf("%d ", b[i]);
  printf("]\n");

  for (i = 0; i < 6; i++)
    if (a[index_test[i]]!=b[index_test[i]])
    {
      printf(">>>FAILED: test_simple_indexed\n");
      errcount++;
      return;
    }
}

//block indexed.  Same as indexed except
//static block length

void test_simple_bindexed()
{
  int i;
  int disps[3] = {0, 4, 7};
  int a [10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
  int b [10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  int index_test[6] = {0, 1, 4, 5, 7, 8};
  MPI_Datatype indexed_type;

  //block indexed of simple types
  printf("\nBlock indexed type of MPI_INT.\n");
  MPI_Type_create_indexed_block(3, 2, disps, MPI_INT, &indexed_type);
  MPI_Type_commit(&indexed_type);
#ifdef TEST_INTERNAL
  copy_data(&a, &b, indexed_type);
  print_typemap(indexed_type);
#else
  MPI_Isend(&a, 1, indexed_type, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&b, 1, indexed_type, 0, 0, MPI_COMM_WORLD, &req);
#endif

  printf("a = [");
  for (i = 0; i < 10; i++)
    printf("%d ", a[i]);
  printf("]\n");

  printf("b = [");
  for (i = 0; i < 10; i++)
    printf("%d ", b[i]);
  printf("]\n");

  for (i = 0; i < 6; i++)
    if (a[index_test[i]]!=b[index_test[i]])
    {
      printf(">>>FAILED: test_simple_bindexed\n");
      errcount++;
      return;
    }
}

//hindexed:  same as indexed, but
//using byte displacements based off of sizeof(int)
//(no reason why this shouldn't work)

void test_simple_hindexed()
{
  int i;
  int a [10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
  int b [10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
  int index_test [6] = {0, 2, 3, 5, 6, 7};
  int blens[3] = {2, 1, 3};
  MPI_Aint disps[3] = {2*sizeof(int), 0, 5*sizeof(int)};
  MPI_Datatype indexed_type;

//Indexed (byte-addressed) of simple types
  printf("\nBlock indexed (byte addressed) type of MPI_INT.\n");
  MPI_Type_hindexed(3, blens, disps, MPI_INT, &indexed_type);
  MPI_Type_commit(&indexed_type);
#ifdef TEST_INTERNAL
  print_typemap(indexed_type);
  copy_data(&a, &b, indexed_type);
#else
  MPI_Isend(&a, 1, indexed_type, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&b, 1, indexed_type, 0, 0, MPI_COMM_WORLD, &req);
#endif

  printf("a = [");
  for (i = 0; i < 10; i++)
    printf("%d ", a[i]);
  printf("]\n");

  printf("b = [");
  for (i = 0; i < 10; i++)
    printf("%d ", b[i]);
  printf("]\n");

  for (i = 0; i < 6; i++)
    if (a[index_test[i]]!=b[index_test[i]])
    {
      printf(">>>FAILED: test_simple_hindexed\n");
      errcount++;
      return;
    }
}


/*
 * void struct_test()
{
  int blocklengths[6];
  int offsets[6];
  MPI_Aint boffsets[6];
  MPI_Datatype types[6];
  MPI_Datatype struct_type, newtype, newtype2, sstruct,
               indexed_type, vector_type;
  MPI_Aint extent2, extent3;
  //struct type of simple types
  printf("\nStruct of simple types\n");
  blocklengths[0] = 3;
  blocklengths[1] = 5;
  blocklengths[2] = 2;
  blocklengths[3] = 1;
  boffsets[0] = 0;
  boffsets[1] = 24;
  boffsets[2] = 32;
  boffsets[3] = 40;
  types[0] = MPI_DOUBLE;
  types[1] = MPI_CHAR;
  types[2] = MPI_INT;
  types[3] = MPI_LONG_DOUBLE;

  MPI_Type_struct(4, blocklengths, boffsets, types, &struct_type);
  print_typemap(struct_type);

  //struct type of simple types, with artificial LB and UB
  printf("\nStruct type of simple types, with LB and UB.\n");
  blocklengths[0] = 2;
  blocklengths[1] = 4;
  blocklengths[2] = 1;
  blocklengths[3] = 24;
  blocklengths[4] = 1;
  boffsets[0] = 0;
  boffsets[1] = 40;
  boffsets[2] = 80;
  boffsets[3] = 48;
  boffsets[4] = -8;
  types[0] = MPI_LONG;
  types[1] = MPI_INT;
  types[2] = MPI_UB;
  types[3] = MPI_CHAR;
  types[4] = MPI_LB;

  MPI_Type_struct(5, blocklengths, boffsets, types, &newtype2);
  print_typemap(newtype2);

  //struct type:  2 int, 1 float
  printf("\nSimple struct for use: 2 int, 1 float\n");
  blocklengths[0] = 2;
  blocklengths[1] = 1;
  boffsets[0] = 0;
  boffsets[1] = 8;
  types[0] = MPI_INT;
  types[1] = MPI_FLOAT;

  MPI_Type_struct(2, blocklengths, boffsets, types, &sstruct);
  print_typemap(sstruct);

  //contiguous type of complex (struct) type
  printf("\nContiguous type of complex (struct) type\n");
  MPI_Type_contiguous(3, newtype2, &newtype);
  print_typemap(newtype);

  //vector type of complex type
  printf("\nVector type of struct\n");
  MPI_Type_vector(3, 2, 2, struct_type, &vector_type);
  print_typemap(vector_type);

  //indexed of complex type
  printf("\nIndexed type of struct\n");
  blocklengths[0] = 1;
  blocklengths[1] = 2;
  offsets[0]      = 0;
  offsets[1]      = 7;
  MPI_Type_indexed(2, blocklengths, offsets, sstruct, &indexed_type);
  print_typemap(indexed_type);

  //struct of simple/complex
  printf("\nStruct of smaller structs and simple types\n");
  MPI_Type_extent(sstruct, &extent2);
  MPI_Type_extent(indexed_type, &extent3);
  blocklengths[0] = 2;
  blocklengths[1] = 1;
  blocklengths[2] = 4;
  blocklengths[3] = 5;
  boffsets[0]     = 0;
  boffsets[1]     = 2 * extent2;
  boffsets[2]     = boffsets[1] + extent3;
  boffsets[3]     = boffsets[2] + 4;
  types[0]        = sstruct;
  types[1]        = indexed_type;
  types[2]        = MPI_CHAR;
  types[3]        = newtype2;

  MPI_Type_struct(4, blocklengths, boffsets, types, &struct_type);
  print_typemap(struct_type);
}
*/

//simple struct, comprised of an int, 2 chars
// and a long int value.

void test_simple_struct()
{
  struct {int a; char b; char c; long d; } s1;
  struct {int a; char b; char c; long d; } s2;

  int blens[4] = {1, 2, 1};
  MPI_Aint disps[4] = {0, 4, 8};
  MPI_Datatype types[4] = {MPI_INT, MPI_CHAR, MPI_LONG};
  MPI_Datatype struct_type;

  printf("\nSimple struct type: 1 int, 2 char, 1 long\n");
  MPI_Type_struct(3, blens, disps, types, &struct_type);
  MPI_Type_commit(&struct_type);
  s1.a = 10;
  s1.b = 'x';
  s1.c = 'a';
  s1.d = 3000;

#ifdef TEST_INTERNAL
  print_typemap(struct_type);
  copy_data(&s1, &s2, struct_type);
#else
  MPI_Isend(&s1, 1, struct_type, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&s2, 1, struct_type, 0, 0, MPI_COMM_WORLD, &req);
#endif

  if (!(s1.a==s2.a && s1.b==s2.b && s1.c==s2.c && s1.d==s2.d))
  {
    printf(">>>FAILED: test_simple_struct\n");
    errcount++;
    return;
  }
}

// combine one struct into another struct for a complex
// type. This should test any funny padding issues

void test_complex_struct()
{
  MPI_Datatype sstruct;
  typedef struct {long a; long b; char c; int d; int e;} st;
  typedef struct {st a; int b; char c;} st2;
  st s1 = {.a = 100, .b = 200, .c = 'x', .d = 45, .e = 50};
  st s2;
  st2 s3 = {.a = { .a = 40, .b = 100, .c = 'x', .d = 50, .e = 20}, .b = 100, .c = 'g'} ;
  st2 s4;
  int blens[3] = {2, 2, 1};
  MPI_Aint disps[3] = {0, 2*sizeof(long) + sizeof(int), 2*sizeof(long)};
  MPI_Datatype types[3] = {MPI_LONG, MPI_INT, MPI_CHAR};
  MPI_Datatype newtype;


  printf("\nSimple struct to create complex struct\n");
  MPI_Type_struct(3, blens, disps, types, &newtype);
  MPI_Type_commit(&newtype);
#ifdef TEST_INTERNAL
  print_typemap(newtype);
  copy_data(&s1, &s2, newtype);
#else
  MPI_Isend(&s1, 1, newtype, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&s2, 1, newtype, 0, 0, MPI_COMM_WORLD, &req);
#endif

 if (!(s1.a==s2.a && s1.b==s2.b && s1.c==s2.c && s1.d==s2.d && s1.e==s2.e))
  {
    printf(">>>FAILED: test_complex_struct\n");
    errcount++;
    return;
  }
  MPI_Datatype newtype2;

  blens[0] = 1;
  blens[1] = 1;
  blens[2] = 1;
  disps[0] = 0;
  disps[1] = sizeof(st);
  disps[2] = sizeof(st) + sizeof(int);
  types[0] = newtype;
  types[1] = MPI_INT;
  types[2] = MPI_CHAR;

  printf("\nComplex struct type composed of other struct.\n");
  MPI_Type_struct(3, blens, disps, types, &newtype2);
  MPI_Type_commit(&newtype2);
#ifdef TEST_INTERNAL
  print_typemap(newtype2);
  copy_data(&s3, &s4, newtype2);
#else
  MPI_Isend(&s3, 1, newtype2, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&s4, 1, newtype2, 0, 0, MPI_COMM_WORLD, &req);
#endif

  if (!(s3.a.a==s4.a.a && s3.a.b==s4.a.b && s3.a.c==s4.a.c && s3.b==s4.b && s3.c==s4.c))
  {
    printf(">>>FAILED: test_complex_struct\n");
    errcount++;
    return;
  }
}

// Indexed struct.  This one is a bit complicated
// as to datatype layout, so it will also test the
// padding issue

void test_indexed_struct()
{
  int i;

  //simple struct vars
  int s_blens[4] = {1,1,1,2};
  MPI_Aint s_disps[4];
  MPI_Datatype s_types[4] = {MPI_CHAR, MPI_LONG,
                             MPI_CHAR, MPI_INT};
  MPI_Datatype s_struct;
  int i_blens[3] = {3, 1, 2};
  int i_disps[3] = {0, 5, 7};
  MPI_Datatype i_struct_indexed;
  int index_test [6] = {0,1,2,5,7,8};
  char* sadd;
  typedef struct
    {char a; long b; char c; int d; int e;}
    struct_t;

  struct_t send[10];
  struct_t recv[10];

  //initialize the structs
  for (i = 0; i < 10; i++)
  {
    send[i].a = i;
    send[i].b = 2*i;
    send[i].c = 'A' + i;
    send[i].d = i;
    send[i].e =-i;
    recv[i].a=0;
    recv[i].b=0;
    recv[i].c=' ';
    recv[i].d=0;
    recv[i].e=0;
  }

  //set the displacements by using address differences
  sadd = (char *)&send[0];
  s_disps[0] = (char*)&(send[0].a) - sadd;
  s_disps[1] = (char*)&(send[0].b) - sadd;
  s_disps[2] = (char*)&(send[0].c) - sadd;
  s_disps[3] = (char*)&(send[0].d) - sadd;
  //e is "contiguous" of d


  MPI_Type_struct(4, s_blens, s_disps, s_types, &s_struct);
  MPI_Type_commit(&s_struct);
#ifdef TEST_INTERNAL
  print_typemap(s_struct);
#endif

  //now, create an indexed type of this struct
  MPI_Type_indexed(3, i_blens, i_disps,
                   s_struct, &i_struct_indexed);
  MPI_Type_commit(&i_struct_indexed);

#ifdef TEST_INTERNAL
  print_typemap(i_struct_indexed);
  copy_data2(send, 1, i_struct_indexed, recv, 1, i_struct_indexed);
#else
  MPI_Isend(&send, 1, i_struct_indexed, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&recv, 1, i_struct_indexed, 0, 0, MPI_COMM_WORLD, &req);
#endif

  for (i = 0; i < 6; i++)
  {
    if (!(send[index_test[i]].a==recv[index_test[i]].a
      && send[index_test[i]].b==recv[index_test[i]].b
      && send[index_test[i]].c==recv[index_test[i]].c
      && send[index_test[i]].d==recv[index_test[i]].d
      && send[index_test[i]].e==recv[index_test[i]].e))
    {
      printf(">>>FAILED: test_indexed_struct\n");
      errcount++;
      return;
    }
  }

  //to make things really interesting, let's send as the
  //indexed type, and receive instead as _count_
  //consecutive struct types
#ifdef TEST_INTERNAL
  copy_data2(send, 1, i_struct_indexed, recv, 6, s_struct);
#else
  MPI_Gather(&send, 1, i_struct_indexed, &recv,
             6, s_struct, 0, MPI_COMM_WORLD);

//  MPI_Isend(&send, 1, i_struct_indexed, 0, 0, MPI_COMM_WORLD, &req);
//  MPI_Irecv(&recv, 6, s_struct, 0, 0, MPI_COMM_WORLD, &req);

#endif

  for (i = 0; i < 6; i++)
  {
    if (!(send[index_test[i]].a==recv[i].a
      && send[index_test[i]].b==recv[i].b
      && send[index_test[i]].c==recv[i].c
      && send[index_test[i]].d==recv[i].d
      && send[index_test[i]].e==recv[i].e))
    {
      printf(">>>FAILED: test_indexed_struct (multiple recv)\n");
      errcount++;
      return;
    }
  }

}


//test a differing issue with send/receive
//A contiguous type of 5 MPI_INTs is sent, and is
//received using a receive x5 of MPI_INT

void test_multiple()
{
  int i;
  int a[5] = {1, 2, 3, 4, 5};
  int b[5] = {0, 0, 0, 0, 0};



  MPI_Datatype contig5int;

  printf("\nSend contiguous of 5 MPI_INT, receive 5 x MPI_INT\n");
  MPI_Type_contiguous(5, MPI_INT, &contig5int);
  MPI_Type_commit(&contig5int);

#ifdef TEST_INTERNAL
  copy_data2(&a, 5, MPI_INT, &b, 1, contig5int);
#else
  MPI_Isend(&a, 5, MPI_INT, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&b, 1, contig5int, 0, 0, MPI_COMM_WORLD, &req);
#endif


  printf("a = [");
  for (i = 0; i < 5; i++)
    printf("%d ", a[i]);
  printf("]\n");

  printf("b = [");
  for (i = 0; i < 5; i++)
    printf("%d ", b[i]);
  printf("]\n");

  for (i = 0; i < 5; i++)
    if (a[i]!=b[i])
    {
      printf(">>>FAILED: test_multiple\n");
      errcount++;
      return;
    }
}

void test_multiple_struct()
{
  int i;
  typedef struct {int a; double b; char c;} struct_t;
  struct_t s1[5],s2[5];
  MPI_Aint disps[3];
  int blens[3] = {1,1,1};
  MPI_Datatype types[3] = {MPI_INT, MPI_DOUBLE, MPI_CHAR};
  MPI_Datatype struct_type, contig_struct;

  disps[0] = 0;
  disps[1] = (char*) &(s1[0].b) - (char*) &s1[0];
  disps[2] = (char*) &(s1[0].c) - (char*) &s1[0];

  for (i=0; i<5; i++)
  {
    s1[i].a=i; s1[i].b=i+15.0; s1[i].c='a'+i;
    s2[i].a=0; s2[i].b=0.0   ; s2[i].c=0    ;
  }

  MPI_Type_struct(3, blens, disps, types, &struct_type);
  MPI_Type_commit(&struct_type);
  MPI_Type_contiguous(5, struct_type, &contig_struct);
  MPI_Type_commit(&contig_struct);
  printf("\nSend contiguous of 5 struct, receive 5x struct\n");

#ifdef TEST_INTERNAL
  copy_data2(&s1, 1, contig_struct, &s2, 5, struct_type);
#else
  MPI_Isend(&s1, 1, contig_struct, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&s2, 5, struct_type, 0, 0, MPI_COMM_WORLD, &req);
#endif

  for (i = 0; i < 5; i++)
    if (!(s1[i].a == s2[i].a && s1[i].b == s2[i].b && s1[i].c == s2[i].c))
    {
      printf(">>>FAILED: test_multiple_struct\n");
      errcount++;
      return;
    }
}

// packed type.  Pack some arbitrary simple
// values into a buffer and copy.

void test_packed()
{
  int SIZE = 77;
  int i = 8;
  char c[] = "abcdefghijklmnopqrstuvwxyabcdefghijklmnopqrstuvwxyabcdefghijklmnopqrstuvwxyabcdefghijklmnopqrstuvwxyzabcdefg\0";
  int j;
  double k = 0.234234, l;
  char d[SIZE];
  char buffer[110];
  char recv[110];
  int position = 0;

  printf("\nSimple packed type (int, char, double)\n");
  c[SIZE-1] = '\0';
  MPI_Pack(&i, 1, MPI_INT, buffer, 110, &position, MPI_COMM_WORLD);
  MPI_Pack(c, SIZE, MPI_CHAR, buffer, 110, &position, MPI_COMM_WORLD);
  MPI_Pack(&k, 1, MPI_DOUBLE, buffer, 110, &position, MPI_COMM_WORLD);
#ifdef TEST_INTERNAL
  copy_data2(&buffer, position, MPI_PACKED, &recv, position, MPI_PACKED);
#else
  MPI_Isend(&buffer, position, MPI_PACKED, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&recv, position, MPI_PACKED, 0, 0, MPI_COMM_WORLD,&req);
#endif

  position = 0;

  MPI_Unpack(&recv, 110, &position, &j, 1, MPI_INT, MPI_COMM_WORLD);
  MPI_Unpack(&recv, 110, &position, d, SIZE, MPI_CHAR, MPI_COMM_WORLD);
  MPI_Unpack(&recv, 110, &position, &l, 1, MPI_DOUBLE, MPI_COMM_WORLD);

  if (!(i==j && k==l))
  {
    printf(">>>FAILED: test_packed\n");
    errcount++;
    return;
  }
}

// Complex pack.  Includes struct types that are packed

void test_packed_complex()
{
  struct {int a; char b; char c; long d; } s1;
  struct {int a; char b; char c; long d; } s2;

  MPI_Aint size;
  int pos = 0;
  int x = 10, y;
  float f = 0.345, g;
  char buf[100];
  char rbuf[100];
  int blens[3] = {1, 1, 1};
  MPI_Aint disps[3];
  MPI_Datatype types[3] = {MPI_INT, MPI_CHAR, MPI_LONG};
  MPI_Datatype struct_type;

  disps[0] = 0;
  disps[1] = (char*) &s1.b - (char*)&s1.a;
  disps[2] = (char*) &s1.d - (char*)&s1.a;

  printf("\nComplex packed type\n");

  MPI_Type_struct(3, blens, disps, types, &struct_type);
  s1.a = 10;
  s1.b = 'x';
  s1.c = 'a';
  s1.d = 3000;

  MPI_Pack_size(1, struct_type,MPI_COMM_WORLD, &size);
  MPI_Pack(&x, 1, MPI_INT, buf, 100, &pos, MPI_COMM_WORLD);
  MPI_Pack(&s1, 1, struct_type, buf, 100, &pos, MPI_COMM_WORLD);
  MPI_Pack(&f, 1, MPI_FLOAT, buf, 100, &pos, MPI_COMM_WORLD);

#ifdef TEST_INTERNAL
  copy_data2(&buf, pos, MPI_PACKED, &rbuf, pos, MPI_PACKED);
#else
  MPI_Isend(&buf, pos, MPI_PACKED, 0, 0, MPI_COMM_WORLD, &req);
  MPI_Irecv(&rbuf, pos, MPI_PACKED, 0, 0, MPI_COMM_WORLD,&req);
#endif

  pos = 0;
  MPI_Unpack(&rbuf, 100, &pos, &y, 1, MPI_INT, 0);
  MPI_Unpack(&rbuf, 100, &pos, &s2, 1, struct_type, 0);
  MPI_Unpack(&rbuf, 100, &pos, &g, 1, MPI_FLOAT, 0);

  if (!(s1.a==s2.a && s1.b==s2.b /*&& s1.c==s2.c*/ && s1.d==s2.d && x == y && f == g))
  {
    printf(">>>FAILED: test_packed_complex\n");
    errcount++;
    return;
  }

}

//Macro used in test_collectives
#define test_eq(s1, s2, op) { \
  printf("testing %s\n",op); \
  if (!(s1.a == s2.a && s1.b == s2.b &&  \
        s1.c == s2.c && s1.d == s2.d)) {\
    errcount++; \
    printf(">>>FAILED: test_collectives: %s\n", op); \
  } \
}

void test_collectives()
{
  typedef struct {int a; int b; double c; long d;} struct_t;
  MPI_Datatype struct_type;
  struct_t s1 = {.a=1, .b=2, .c=4.00, .d=100},
           s2 = {.a=0, .b=0, .c=0.00, .d=0  };
  MPI_Aint disps[3];

  int disp = 0;
  int sendcount = 1, recvcount = 1;


  int blens[3] = {2,1,1};
  MPI_Datatype types[3] = {MPI_INT, MPI_DOUBLE, MPI_LONG};

  disps[0] = 0;
  disps[1] = (char*)&s1.c - (char*) &s1.a;
  disps[2] = (char*)&s1.d - (char*) &s1.a;

  MPI_Type_struct(3, blens, disps, types, &struct_type);
  MPI_Type_commit(&struct_type);

  MPI_Bcast(&s1, sendcount, struct_type, 0, MPI_COMM_WORLD);
  MPI_Gather(&s1, sendcount, struct_type, &s2, recvcount,
		  struct_type, 0, MPI_COMM_WORLD);
  test_eq(s1,s2,"MPI_Gather");

  s2.a=0; s2.b=0; s2.c=0.00; s2.d=0;
  MPI_Gatherv(&s1, sendcount, struct_type, &s2, &recvcount, &disp,
		  struct_type, 0, MPI_COMM_WORLD);
  test_eq(s1,s2,"MPI_Gatherv");
  s2.a=0; s2.b=0; s2.c=0.00; s2.d=0;
  MPI_Allgather(&s1, sendcount, struct_type, &s2, recvcount,
		  struct_type, MPI_COMM_WORLD);
  test_eq(s1,s2,"MPI_Allgather");
  s2.a=0; s2.b=0; s2.c=0.00; s2.d=0;
  MPI_Allgatherv(&s1, sendcount, struct_type, &s2, &recvcount, &disp,
             struct_type, MPI_COMM_WORLD);
  test_eq(s1,s2,"MPI_Allgatherv");

  s2.a=0; s2.b=0; s2.c=0.00; s2.d=0;
  MPI_Scatter(&s1, sendcount, struct_type,
              &s2, recvcount, struct_type,
	       0, MPI_COMM_WORLD);
  test_eq(s1,s2,"MPI_Scatter");

  s2.a=0; s2.b=0; s2.c=0.00; s2.d=0;
  MPI_Scatterv(&s1, &sendcount, &disp, struct_type, &s2, recvcount,
             struct_type, 0, MPI_COMM_WORLD);
  test_eq(s1,s2,"MPI_Scatterv");

  s2.a=0; s2.b=0; s2.c=0.00; s2.d=0;
  MPI_Reduce(&s1, &s2, sendcount, struct_type, MPI_MAX, 0, MPI_COMM_WORLD);
  test_eq(s1, s2, "MPI_Reduce");

  s2.a=0; s2.b=0; s2.c=0.00; s2.d=0;
  MPI_Allreduce(&s1, &s2, sendcount, struct_type, MPI_MAX, MPI_COMM_WORLD);
  test_eq(s1, s2, "MPI_Allreduce");

  s2.a=0; s2.b=0; s2.c=0.00; s2.d=0;
  MPI_Alltoall(&s1, sendcount, struct_type,
               &s2, recvcount, struct_type, MPI_COMM_WORLD);
  test_eq(s1, s2, "MPI_Alltoall");

  s2.a=0; s2.b=0; s2.c=0.00; s2.d=0;
  MPI_Alltoallv(&s1, &sendcount, &disp, struct_type,
                &s2, &recvcount, &disp, struct_type, MPI_COMM_WORLD);
  test_eq(s1, s2, "MPI_Alltoallv");

  s2.a=0; s2.b=0; s2.c=0.00; s2.d=0;
  MPI_Reduce_scatter(&s1, &s2, &recvcount,struct_type, MPI_MAX, MPI_COMM_WORLD);
  test_eq(s1, s2, "MPI_Reduce_scatter");

  s2.a=0; s2.b=0; s2.c=0.00; s2.d=0;
  MPI_Scan(&s1, &s2, sendcount,struct_type, MPI_MAX, MPI_COMM_WORLD);
  test_eq(s1, s2, "MPI_Scan");
}
/*
void vector_test()
{
  int c[3][2] = { {1, 2}, {3, 4}, {5, 6} };
  int d[3][2] = { {0, 0}, {0, 0}, {0, 0} };
  int i;
  MPI_Datatype vector_type;
  //test vector.  First and third rows of array
  printf("\nVector type of first and third rows in INT array\n");
  MPI_Type_vector(2, 2, 4, MPI_INT, &vector_type);

  print_typemap(vector_type);

  copy_data(&c, &d, vector_type);

  for (i = 0; i < 3; i++)
    printf("%d %d\n", d[i][0], d[i][1]);
}

void indexed_test()
{
  //we want the 2nd, 3rd, 5th, and 8th elements (starting at 0)
  int i;
  int a[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
  int b[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  int blens[3] = {2, 1, 1};
  int disps[3] = {2, 5, 8};
  MPI_Datatype indexed_type;

  printf("\nIndexed:  2nd, 3rd, 5th, and 8th elements (0 base)\n");
  MPI_Type_indexed(3, blens, disps, MPI_INT, &indexed_type);

  print_typemap(indexed_type);

  copy_data(&a, &b, indexed_type);

  for (i = 0; i < 10; i++)
    printf("%d ", b[i]);
  printf("\n");
}

void structtests()
{
  int a[5] = {1, 2, 3, 4, 5};
  int b[5];

  MPI_Datatype type, vector_type;

  //test contiguous
  printf("\nContiguous type of 5 MPI_INT\n");
  MPI_Type_contiguous(5, MPI_INT, &type);
  printf("Done.\n");
  fflush(stdout);
  print_typemap(type);
  copy_data(&a, &b, type);
  printf("b = %d\n", a[4]);
}
*/

int main(int argc, char ** argv)
{
  char version[MPI_MAX_LIBRARY_VERSION_STRING];
  int vlen;

  MPI_Init(&argc, &argv);

  MPI_Get_library_version(version,&vlen);
  printf("MPI version=\"%s\" (len=%d)\n",version,vlen);

//  structtests();
//  indexed_test();
//  struct_test();

//  printf("\n\n---End of samples:  Testing now---\n\n");
#ifdef TEST_INTERNAL
  printf("Using internal tests\n");
#endif
  test_simple_contig();
  test_simple_vector();
  test_simple_hvector();
  test_simple_indexed();
  test_simple_bindexed();
  test_simple_hindexed();
  test_simple_struct();
  test_complex_struct();
  test_indexed_struct();
  test_multiple();
  test_multiple_struct();
  test_packed();
  test_packed_complex();
  test_collectives();

  MPI_Finalize();
  if (errcount)
    printf("Found %d errors\n", errcount);
  else
    printf(">>>PASSED ALL TESTS. No errors. <<<\n");

  return(errcount);
}

