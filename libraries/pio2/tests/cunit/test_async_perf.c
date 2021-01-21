/*
 * This program tests performance of darray writes with async.
 *
 * @author Ed Hartnett
 * @date 5/4/17
 */
#include <config.h>
#include <pio.h>
#include <pio_tests.h>
#include <pio_internal.h>
#include <sys/time.h>

/* The number of tasks this test should run on. */
#define TARGET_NTASKS 4

/* The minimum number of tasks this test should run on. */
#define MIN_NTASKS 1

/* The name of this test. */
#define TEST_NAME "test_async_perf"

/* For 2-D use. */
#define NDIM2 2

/* For 3-D use. */
#define NDIM3 3

/* For 4-D use. */
#define NDIM4 4

/* For maplens of 2. */
#define MAPLEN2 2

/* Lengths of non-unlimited dimensions. */
#define LAT_LEN 2
#define LON_LEN 3

/* The length of our sample data along each dimension. */
#define X_DIM_LEN 128
#define Y_DIM_LEN 128
#define Z_DIM_LEN 32
/* #define X_DIM_LEN 1024 */
/* #define Y_DIM_LEN 1024 */
/* #define Z_DIM_LEN 256 */

/* The number of timesteps of data to write. */
#define NUM_TIMESTEPS 3

/* Name of record test var. */
#define REC_VAR_NAME "Duncan_McCloud_of_the_clan_McCloud"

/* How many different number of IO tasks to check? */
#define MAX_IO_TESTS 5

#define COMPONENT_COUNT 1

char dim_name[NDIM4][PIO_MAX_NAME + 1] = {"unlim", "x", "y", "z"};

/* Length of the dimension. */
#define LEN3 3

#define NUM_VAR_SETS 2

/* How long to sleep for "calculation time". */
#define SLEEP_SECONDS 1

#ifdef USE_MPE
/* This array holds even numbers for MPE. */
int test_event[2][TEST_NUM_EVENTS];
#endif /* USE_MPE */

/* Create the decomposition to divide the 4-dimensional sample data
 * between the 4 tasks. For the purposes of decomposition we are only
 * concerned with 3 dimensions - we ignore the unlimited dimension.
 *
 * @param ntasks the number of available tasks (tasks doing
 * computation).
 * @param my_rank rank of this task.
 * @param iosysid the IO system ID.
 * @param dim_len an array of length 3 with the dimension sizes.
 * @param ioid a pointer that gets the ID of this decomposition.
 * @returns 0 for success, error code otherwise.
 **/
int
create_decomposition_3d(int ntasks, int my_rank, int iosysid, int *ioid,
                        PIO_Offset *elements_per_pe)
{
    PIO_Offset my_elem_per_pe;     /* Array elements per processing unit. */
    PIO_Offset *compdof;  /* The decomposition mapping. */
    int dim_len_3d[NDIM3] = {X_DIM_LEN, Y_DIM_LEN, Z_DIM_LEN};
    int my_proc_rank = my_rank - 1;
    int ret;

#ifdef USE_MPE
    test_start_mpe_log(TEST_DECOMP);
#endif /* USE_MPE */

    /* How many data elements per task? */
    my_elem_per_pe = X_DIM_LEN * Y_DIM_LEN * Z_DIM_LEN / ntasks;
    if (elements_per_pe)
        *elements_per_pe = my_elem_per_pe;

    /* Allocate space for the decomposition array. */
    if (!(compdof = malloc(my_elem_per_pe * sizeof(PIO_Offset))))
        return PIO_ENOMEM;

    /* Describe the decomposition. */
    for (int i = 0; i < my_elem_per_pe; i++)
        compdof[i] = my_proc_rank * my_elem_per_pe + i;

    /* Create the PIO decomposition for this test. */
    if ((ret = PIOc_init_decomp(iosysid, PIO_INT, NDIM3, dim_len_3d, my_elem_per_pe,
                                compdof, ioid, 0, NULL, NULL)))
        ERR(ret);

    /* Free the mapping. */
    free(compdof);

#ifdef USE_MPE
    {
        char msg[MPE_MAX_MSG_LEN + 1];
        sprintf(msg, "elements_per_pe %lld", my_elem_per_pe);
        test_stop_mpe_log(TEST_DECOMP, msg);
    }
#endif /* USE_MPE */

    return 0;
}

/* Run a simple test using darrays with async. */
int
run_darray_async_test(int iosysid, int fmt, int my_rank, int ntasks, int niotasks,
                      MPI_Comm test_comm, MPI_Comm comp_comm, int *flavor, int piotype)
{
    int ioid3;
    int dim_len[NDIM4] = {NC_UNLIMITED, X_DIM_LEN, Y_DIM_LEN, Z_DIM_LEN};
    PIO_Offset elements_per_pe2;
    char decomp_filename[PIO_MAX_NAME + 1];
    int ret;

    sprintf(decomp_filename, "decomp_rdat_%s_.nc", TEST_NAME);

    /* Decompose the data over the tasks. */
    if ((ret = create_decomposition_3d(ntasks - niotasks, my_rank, iosysid, &ioid3,
                                       &elements_per_pe2)))
        return ret;

    {
        int ncid;
        PIO_Offset type_size;
        int dimid[NDIM4];
        int varid;
        char data_filename[PIO_MAX_NAME + 1];
        int *my_data_int;
        int d, t;

        if (!(my_data_int = malloc(elements_per_pe2 * sizeof(int))))
            PBAIL(PIO_ENOMEM);

        for (d = 0; d < elements_per_pe2; d++)
            my_data_int[d] = my_rank;

#ifdef USE_MPE
        test_start_mpe_log(TEST_CREATE);
#endif /* USE_MPE */

        /* Create sample output file. */
        /* sprintf(data_filename, "data_%s_iotype_%d_piotype_%d.nc", TEST_NAME, flavor[fmt], */
        /*         piotype); */
        sprintf(data_filename, "data_%s.nc", TEST_NAME);
        if ((ret = PIOc_createfile(iosysid, &ncid, &flavor[fmt], data_filename,
                                   NC_CLOBBER)))
            PBAIL(ret);

#ifdef USE_MPE
        {
            char msg[MPE_MAX_MSG_LEN + 1];
            sprintf(msg, "iotype %d", flavor[fmt]);
            test_stop_mpe_log(TEST_CREATE, msg);
        }
#endif /* USE_MPE */

        /* Find the size of the type. */
        if ((ret = PIOc_inq_type(ncid, piotype, NULL, &type_size)))
            PBAIL(ret);

        /* Define dimensions. */
        for (int d = 0; d < NDIM4; d++)
            if ((ret = PIOc_def_dim(ncid, dim_name[d], dim_len[d], &dimid[d])))
                PBAIL(ret);

        /* Define variables. */
        if ((ret = PIOc_def_var(ncid, REC_VAR_NAME, piotype, NDIM4, dimid, &varid)))
            PBAIL(ret);

        /* End define mode. */
        if ((ret = PIOc_enddef(ncid)))
            PBAIL(ret);

        for (t = 0; t < NUM_TIMESTEPS; t++)
        {
#ifdef USE_MPE
            test_start_mpe_log(TEST_DARRAY_WRITE);
#endif /* USE_MPE */

            /* Set the record number for the record vars. */
            if ((ret = PIOc_setframe(ncid, varid, t)))
                PBAIL(ret);

            /* Write some data to the record vars. */
            if ((ret = PIOc_write_darray(ncid, varid, ioid3, elements_per_pe2,
                                         my_data_int, NULL)))
                PBAIL(ret);

#ifdef USE_MPE
            {
                char msg[MPE_MAX_MSG_LEN + 1];
                sprintf(msg, "timestep %d", t);
                test_stop_mpe_log(TEST_DARRAY_WRITE, msg);
            }
#endif /* USE_MPE */

            /* Now do some calculations. */
#ifdef USE_MPE
            test_start_mpe_log(TEST_CALCULATE);
#endif /* USE_MPE */

            /* Sleep some seconds away. */
            sleep(SLEEP_SECONDS);

#ifdef USE_MPE
            {
                char msg[MPE_MAX_MSG_LEN + 1];
                sprintf(msg, "timestep %d", t);
                test_stop_mpe_log(TEST_CALCULATE, msg);
            }
#endif /* USE_MPE */
        }

        /* Close the file. */
        if ((ret = PIOc_closefile(ncid)))
            PBAIL(ret);

        free(my_data_int);
    }

    /* Free the decomposition. */
    if ((ret = PIOc_freedecomp(iosysid, ioid3)))
        PBAIL(ret);
exit:
    return ret;
}

/* Run Tests for pio_spmd.c functions. */
int main(int argc, char **argv)
{
    int my_rank; /* Zero-based rank of processor. */
    int ntasks;  /* Number of processors involved in current execution. */
    int num_flavors; /* Number of PIO netCDF flavors in this build. */
    int flavor[NUM_FLAVORS]; /* iotypes for the supported netCDF IO flavors. */
    MPI_Comm test_comm; /* A communicator for this test. */
    int iosysid;
    int num_computation_procs;
    MPI_Comm io_comm;              /* Will get a duplicate of IO communicator. */
    MPI_Comm comp_comm[COMPONENT_COUNT]; /* Will get duplicates of computation communicators. */
    int num_io_procs[MAX_IO_TESTS] = {1, 4, 16, 64, 128}; /* Number of processors that will do IO. */
    int num_io_tests; /* How many different num IO procs to try? */
    int mpierr;
    int fmt, niotest;
    int ret;     /* Return code. */

    /* Initialize test. */
    if ((ret = pio_test_init2(argc, argv, &my_rank, &ntasks, 1, 0, -1, &test_comm)))
        ERR(ERR_INIT);

#ifdef USE_MPE
    /* If --enable-mpe was specified at configure, start MPE
     * logging. */
    if (init_mpe_test_logging(my_rank, test_event))
        return ERR_AWFUL;
#endif /* USE_MPE */

    if ((ret = PIOc_set_iosystem_error_handling(PIO_DEFAULT, PIO_RETURN_ERROR, NULL)))
        return ret;

    /* Figure out iotypes. */
    if ((ret = get_iotypes(&num_flavors, flavor)))
        ERR(ret);

    /* How many processors for IO? */
    num_io_tests = 1;
    if (ntasks >= 32)
        num_io_tests = 2;
    if (ntasks >= 64)
        num_io_tests = 3;
    if (ntasks >= 128)
        num_io_tests = 4;
    if (ntasks >= 512)
        num_io_tests = 5;

    if (!my_rank)
        printf("ntasks\tnio\trearr\tfill\tformat\ttime(s)\tdata size (MB)\t"
               "performance(MB/s)\n");

    for (niotest = 0; niotest < num_io_tests; niotest++)
    {
        num_computation_procs = ntasks - num_io_procs[niotest];

        for (fmt = 0; fmt < num_flavors; fmt++)
        {
            struct timeval starttime, endtime;
            long long startt, endt;
            long long delta;
            float num_megabytes;
            float delta_in_sec;
            float mb_per_sec;

#ifdef USE_MPE
            test_start_mpe_log(TEST_INIT);
#endif /* USE_MPE */

            /* Start the clock. */
            if (!my_rank)
            {
                gettimeofday(&starttime, NULL);
                startt = (1000000 * starttime.tv_sec) + starttime.tv_usec;
            }

            if ((ret = PIOc_init_async(test_comm, num_io_procs[niotest], NULL, COMPONENT_COUNT,
                                       &num_computation_procs, NULL, &io_comm, comp_comm,
                                       PIO_REARR_BOX, &iosysid)))
                ERR(ERR_INIT);

#ifdef USE_MPE
            {
                char msg[MPE_MAX_MSG_LEN + 1];
                sprintf(msg, "num IO procs %d", num_io_procs[niotest]);
                test_stop_mpe_log(TEST_INIT, msg);
            }
#endif /* USE_MPE */

            /* This code runs only on computation components. */
            if (my_rank >= num_io_procs[niotest])
            {
                /* Run the simple darray async test. */
                if ((ret = run_darray_async_test(iosysid, fmt, my_rank, ntasks, num_io_procs[niotest],
                                                 test_comm, comp_comm[0], flavor, PIO_INT)))
                    return ret;

                /* Finalize PIO system. */
                if ((ret = PIOc_free_iosystem(iosysid)))
                    return ret;

                /* Free the computation conomponent communicator. */
                if ((mpierr = MPI_Comm_free(comp_comm)))
                    MPIERR(mpierr);
            }
            else
            {
                /* Free the IO communicator. */
                if ((mpierr = MPI_Comm_free(&io_comm)))
                    MPIERR(mpierr);
            }

            if (!my_rank)
            {
                /* Stop the clock. */
                gettimeofday(&endtime, NULL);

                /* Compute the time delta */
                endt = (1000000 * endtime.tv_sec) + endtime.tv_usec;
                delta = (endt - startt)/NUM_TIMESTEPS;
                delta_in_sec = (float)delta / 1000000;
                num_megabytes = (X_DIM_LEN * Y_DIM_LEN * Z_DIM_LEN * (long long int)  NUM_TIMESTEPS *
                                 sizeof(int))/(1024*1024);
                mb_per_sec = num_megabytes / delta_in_sec;
                printf("%d\t%d\t%d\t%d\t%d\t%8.3f\t%8.1f\t%8.3f\n", ntasks, num_io_procs[niotest],
                       1, 0, fmt, delta_in_sec, num_megabytes, mb_per_sec);
            }

        } /* next fmt */
    } /* next niotest */

    /* printf("%d %s SUCCESS!!\n", my_rank, TEST_NAME); */
    /* Finalize the MPI library. */
    if ((ret = pio_test_finalize(&test_comm)))
        return ret;

    return 0;
}
