/**
 * @file
 * Include file for tests for the Parallel IO library.
 * @author Ed Hartnett
 * @date 9/13/2016
 */

#ifndef _PIO_TESTS_H
#define _PIO_TESTS_H
#include <pio_error.h>
#include <unistd.h> /* Include this for the sleep function. */
#include <assert.h>

/* Timing header may need to be included. */
#ifdef TIMING
#include <gptl.h>
#endif

#ifdef USE_MPE
#include <mpe.h>
#endif /* USE_MPE */

#ifdef USE_MPE
/* These are for the event numbers array used to log various events in
 * the program with the MPE library, which produces output for the
 * Jumpshot program. */
#define TEST_NUM_EVENTS 6
#define TEST_INIT 0
#define TEST_DECOMP 1
#define TEST_CREATE 2
#define TEST_DARRAY_WRITE 3
#define TEST_CLOSE 4
#define TEST_CALCULATE 5

int init_mpe_test_logging(int my_rank, int test_event[][TEST_NUM_EVENTS]);
void test_start_mpe_log(int state);
void test_stop_mpe_log(int state, const char *msg);
#endif /* USE_MPE */

/** The number of possible output netCDF output flavors available to
 * the ParallelIO library. */
#define NUM_FLAVORS 4
#define NUM_IOTYPES 4

/** Number of netCDF types. */
#define NUM_NETCDF_TYPES 12

/* Number of NetCDF classic types. */
#define NUM_CLASSIC_TYPES 6

/* Number of NetCDF-4 types. */
#define NUM_NETCDF4_TYPES 12

/* Number of PIO rearrangers. */
#define NUM_REARRANGERS 2

/* Number of sample files constructed for these tests. */
#define NUM_SAMPLES 3

/** Error code for when things go wrong. */
#define ERR_CHECK 1109
#define ERR_INIT 1110
#define ERR_AWFUL 1111
#define ERR_WRONG 1112
#define ERR_GPTL 1113
#define ERR_MPI 1114
#define ERR_MEM 1115

/** The meaning of life, the universe, and everything. */
#define TEST_VAL_42 42

/* Dimension lengths used in some C tests. */
#define DIM_LEN2 2
#define DIM_LEN3 3

/* Number of dims in test file. */
#define NDIM2 2
#define NDIM3 3
#ifdef _NETCDF4
#define NUM_PIO_TYPES_TO_TEST 11
#else
#define NUM_PIO_TYPES_TO_TEST 6
#endif /* _NETCDF4 */

/* Function prototypes. */
int pio_test_init2(int argc, char **argv, int *my_rank, int *ntasks, int min_ntasks,
                   int max_ntasks, int log_level, MPI_Comm *test_comm);
int create_nc_sample(int sample, int iosysid, int format, char *filename, int my_rank, int *ncid);
int check_nc_sample(int sample, int iosysid, int format, char *filename, int my_rank, int *ncid);
int create_nc_sample_0(int iosysid, int format, char *filename, int my_rank, int *ncid);
int check_nc_sample_0(int iosysid, int format, char *filename, int my_rank, int *ncid);
int create_nc_sample_1(int iosysid, int format, char *filename, int my_rank, int *ncid);
int check_nc_sample_1(int iosysid, int format, char *filename, int my_rank, int *ncid);
int create_nc_sample_2(int iosysid, int format, char *filename, int my_rank, int *ncid);
int check_nc_sample_2(int iosysid, int format, char *filename, int my_rank, int *ncid);
int create_nc_sample_3(int iosysid, int iotype, int my_rank, int my_comp_idx,
                       char *filename, char *test_name, int verbose, int use_darray,
                       int ioid);
int check_nc_sample_3(int iosysid, int iotype, int my_rank, int my_comp_idx,
                      const char *filename, int verbose, int use_darray, int ioid);
int create_nc_sample_4(int iosysid, int iotype, int my_rank, int my_comp_idx,
                       char *filename, char *test_name, int verbose, int num_types);
int check_nc_sample_4(int iosysid, int iotype, int my_rank, int my_comp_idx,
                      const char *filename, int verbose, int num_types);
int get_iotypes(int *num_flavors, int *flavors);
int get_iotype_name(int iotype, char *name);
int pio_test_finalize(MPI_Comm *test_comm);
int pio_test_finalize2(MPI_Comm *test_comm, const char *test_name);
int test_async2(int my_rank, int num_flavors, int *flavor, MPI_Comm test_comm,
                int component_count, int num_io_procs, int target_ntasks, char *test_name);
int test_no_async2(int my_rank, int num_flavors, int *flavor, MPI_Comm test_comm, int target_ntasks,
                   int x_dim_len, int y_dim_len);
int test_all(int iosysid, int num_flavors, int *flavor, int my_rank, MPI_Comm test_comm,
             int async);
int run_test_main(int argc, char **argv, int min_ntasks, int max_ntasks,
                  int log_level, char *test_name, int *dim_len, int component_count,
                  int num_io_procs);

/* Create a 2D decomposition used in some tests. */
int create_decomposition_2d(int ntasks, int my_rank, int iosysid, int *dim_len_2d, int *ioid,
                            int pio_type);
#endif /* _PIO_TESTS_H */
