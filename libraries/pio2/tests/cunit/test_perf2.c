/*
 * Tests for PIO distributed arrays.
 *
 * @author Ed Hartnett
 * @date 2/21/17
 */
#include <config.h>
#include <pio.h>
#include <pio_internal.h>
#include <pio_tests.h>
#include <sys/time.h>

/* The number of tasks this test should run on. */
#define TARGET_NTASKS 16

/* The minimum number of tasks this test should run on. */
#define MIN_NTASKS TARGET_NTASKS

/* The name of this test. */
#define TEST_NAME "test_perf2"

/* Number of computational components to create. */
#define COMPONENT_COUNT 1

/* The number of dimensions in the example data. In this test, we
 * are using three-dimensional data. */
#define NDIM 4

/* But sometimes we need arrays of the non-record dimensions. */
#define NDIM3 3

/* The length of our sample data along each dimension. */
#define X_DIM_LEN 128
#define Y_DIM_LEN 128
#define Z_DIM_LEN 32
/* #define X_DIM_LEN 1024 */
/* #define Y_DIM_LEN 1024 */
/* #define Z_DIM_LEN 128 */

/* The number of timesteps of data to write. */
#define NUM_TIMESTEPS 10

/* The name of the variable in the netCDF output files. */
#define VAR_NAME "foo"

/* Test with and without specifying a fill value to
 * PIOc_write_darray(). */
#define NUM_TEST_CASES_FILLVALUE 2

/* How many different number of IO tasks to check? */
#define MAX_IO_TESTS 5

/* The dimension names. */
char dim_name[NDIM][PIO_MAX_NAME + 1] = {"timestep", "x", "y", "z"};

/* Length of the dimensions in the sample data. */
int dim_len[NDIM] = {NC_UNLIMITED, X_DIM_LEN, Y_DIM_LEN, Z_DIM_LEN};

#define DIM_NAME "dim"
#define NDIM1 1

/* Run test for each of the rearrangers. */
#define NUM_REARRANGERS_TO_TEST 2

#ifdef USE_MPE
/* This array holds even numbers for MPE. */
int test_event[2][TEST_NUM_EVENTS];
#endif /* USE_MPE */

/* Create the decomposition to divide the 4-dimensional sample data
 * between the 4 tasks. For the purposes of decomposition we are only
 * concerned with 3 dimensions - we ignore the unlimited dimension.
 *
 * @param ntasks the number of available tasks
 * @param my_rank rank of this task.
 * @param iosysid the IO system ID.
 * @param dim_len an array of length 3 with the dimension sizes.
 * @param ioid a pointer that gets the ID of this decomposition.
 * @returns 0 for success, error code otherwise.
 **/
int
create_decomposition_3d(int ntasks, int my_rank, int iosysid, int *ioid)
{
    PIO_Offset elements_per_pe;     /* Array elements per processing unit. */
    PIO_Offset *compdof;  /* The decomposition mapping. */
    int dim_len_3d[NDIM3] = {X_DIM_LEN, Y_DIM_LEN, Z_DIM_LEN};
    int ret;

    /* How many data elements per task? */
    elements_per_pe = X_DIM_LEN * Y_DIM_LEN * Z_DIM_LEN / ntasks;

    /* Allocate space for the decomposition array. */
    if (!(compdof = malloc(elements_per_pe * sizeof(PIO_Offset))))
        return PIO_ENOMEM;

    /* Describe the decomposition. */
    for (int i = 0; i < elements_per_pe; i++)
        compdof[i] = my_rank * elements_per_pe + i;

    /* Create the PIO decomposition for this test. */
    if ((ret = PIOc_init_decomp(iosysid, PIO_INT, NDIM3, dim_len_3d, elements_per_pe,
                                compdof, ioid, 0, NULL, NULL)))
        ERR(ret);

    /* Free the mapping. */
    free(compdof);

    return 0;
}

/**
 * Test the darray functionality. Create a netCDF file with 4
 * dimensions and 1 PIO_INT variable, and use darray to write some
 * data.
 *
 * @param iosysid the IO system ID.
 * @param ioid the ID of the decomposition.
 * @param num_flavors the number of IOTYPES available in this build.
 * @param flavor array of available iotypes.
 * @param my_rank rank of this task.
 * @param ntasks number of tasks in test_comm.
 * @param num_io_procs number of IO processors.
 * @param provide_fill 1 if fillvalue should be provided to PIOc_write_darray().
 * @param rearranger the rearranger in use.
 * @returns 0 for success, error code otherwise.
 */
int
test_darray(int iosysid, int ioid, int num_flavors, int *flavor,
            int my_rank, int ntasks, int num_io_procs, int provide_fill,
            int rearranger)
{
    int dimids[NDIM];      /* The dimension IDs. */
    int ncid;      /* The ncid of the netCDF file. */
    int varid;     /* The ID of the netCDF varable. */
    PIO_Offset arraylen = (X_DIM_LEN * Y_DIM_LEN * Z_DIM_LEN / ntasks);
    int int_fillvalue = NC_FILL_INT;
    void *fillvalue = NULL;
    int *test_data;
    int ret;       /* Return code. */

    if (!(test_data = malloc(sizeof(int) * arraylen)))
        ERR(PIO_ENOMEM);

    /* Are we providing a fill value? */
    if (provide_fill)
        fillvalue = &int_fillvalue;

    /* Use PIO to create the example file in each of the four
     * available ways. */
    for (int fmt = 0; fmt < num_flavors; fmt++)
    {
        char filename[PIO_MAX_NAME + 1]; /* Name for the output files. */
        struct timeval starttime, endtime;
        long long startt, endt;
        long long delta;
        float num_megabytes = 0;
        float delta_in_sec;
        float mb_per_sec;

#ifdef USE_MPE
        test_start_mpe_log(TEST_CREATE);
#endif /* USE_MPE */

        /* Create the filename. Use the same filename for all, so we
         * don't waste disk space. */
        /* sprintf(filename, "data_%s_iotype_%d_rearr_%d.nc", TEST_NAME, flavor[fmt], */
        /*         rearranger); */
        sprintf(filename, "data_%s.nc", TEST_NAME);

        /* Create the netCDF output file. */
        if ((ret = PIOc_createfile(iosysid, &ncid, &flavor[fmt], filename, PIO_CLOBBER)))
            ERR(ret);

        /* Turn on fill mode. */
        if ((ret = PIOc_set_fill(ncid, NC_FILL, NULL)))
            ERR(ret);

        /* Define netCDF dimensions and variable. */
        for (int d = 0; d < NDIM; d++)
            if ((ret = PIOc_def_dim(ncid, dim_name[d], (PIO_Offset)dim_len[d], &dimids[d])))
                ERR(ret);

        /* Define a variable. */
        if ((ret = PIOc_def_var(ncid, VAR_NAME, PIO_INT, NDIM, dimids, &varid)))
            ERR(ret);

        /* End define mode. */
        if ((ret = PIOc_enddef(ncid)))
            ERR(ret);

#ifdef USE_MPE
        {
            char msg[MPE_MAX_MSG_LEN + 1];
            sprintf(msg, "iotype %d rearr %d", flavor[fmt], rearranger);
            test_stop_mpe_log(TEST_CREATE, msg);
        }
#endif /* USE_MPE */

        /* Start the clock. */
        gettimeofday(&starttime, NULL);

        for (int t = 0; t < NUM_TIMESTEPS; t++)
        {
            /* Initialize some data. */
            for (int f = 0; f < arraylen; f++)
                test_data[f] = (my_rank * 10 + f) + t * 1000;

#ifdef USE_MPE
            test_start_mpe_log(TEST_DARRAY_WRITE);
#endif /* USE_MPE */

            /* Set the value of the record dimension. */
            if ((ret = PIOc_setframe(ncid, varid, t)))
                ERR(ret);

            /* Write the data. */
            if ((ret = PIOc_write_darray(ncid, varid, ioid, arraylen, test_data, fillvalue)))
                ERR(ret);

#ifdef USE_MPE
            {
                char msg[MPE_MAX_MSG_LEN + 1];
                sprintf(msg, "write_darray timestep %d", t);
                test_stop_mpe_log(TEST_DARRAY_WRITE, msg);
            }
#endif /* USE_MPE */

            num_megabytes += (X_DIM_LEN * Y_DIM_LEN * Z_DIM_LEN * sizeof(int))/(1024*1024);
        }

#ifdef USE_MPE
        test_start_mpe_log(TEST_CLOSE);
#endif /* USE_MPE */

        /* Close the netCDF file. */
        if ((ret = PIOc_closefile(ncid)))
            ERR(ret);

#ifdef USE_MPE
        {
            char msg[MPE_MAX_MSG_LEN + 1];
            sprintf(msg, "closed ncid %d", ncid);
            test_stop_mpe_log(TEST_CLOSE, msg);
        }
#endif /* USE_MPE */

        /* Stop the clock. */
        gettimeofday(&endtime, NULL);

        /* Compute the time delta */
        startt = (1000000 * starttime.tv_sec) + starttime.tv_usec;
        endt = (1000000 * endtime.tv_sec) + endtime.tv_usec;
        delta = (endt - startt)/NUM_TIMESTEPS;
        delta_in_sec = (float)delta / 1000000;
        mb_per_sec = num_megabytes / delta_in_sec;
        if (!my_rank)
            printf("%d\t%d\t%d\t%d\t%d\t%8.3f\t%8.1f\t%8.3f\n", ntasks, num_io_procs,
                   rearranger, provide_fill, fmt, delta_in_sec, num_megabytes, mb_per_sec);
    }

    free(test_data);

    return PIO_NOERR;
}

/**
 * Test the decomp read/write functionality.
 *
 * @param iosysid the IO system ID.
 * @param ioid the ID of the decomposition.
 * @param num_flavors the number of IOTYPES available in this build.
 * @param flavor array of available iotypes.
 * @param my_rank rank of this task.
 * @param ntasks number of tasks in test_comm.
 * @param rearranger the rearranger to use (PIO_REARR_BOX or
 * PIO_REARR_SUBSET).
 * @param test_comm the MPI communicator for this test.
 * @returns 0 for success, error code otherwise.
 */
int
test_decomp_read_write(int iosysid, int ioid, int num_flavors, int *flavor,
                       int my_rank, int ntasks, int rearranger,
                       MPI_Comm test_comm)
{

    for (int fmt = 0; fmt < num_flavors; fmt++)
    {
	int ioid2;             /* ID for decomposition we will create from file. */
	char filename[PIO_MAX_NAME + 1]; /* Name for the output files. */
	char title_in[PIO_MAX_NAME + 1];   /* Optional title. */
	char history_in[PIO_MAX_NAME + 1]; /* Optional history. */
	int fortran_order_in; /* Indicates fortran vs. c order. */
	int ret;              /* Return code. */

        /* Create the filename. */
        snprintf(filename, PIO_MAX_NAME, "decomp_%s_iotype_%d.nc", TEST_NAME,
		 flavor[fmt]);

        if ((ret = PIOc_write_nc_decomp(iosysid, filename, 0, ioid, NULL, NULL, 0)))
            return ret;

        /* Read the data. */
        if ((ret = PIOc_read_nc_decomp(iosysid, filename, &ioid2, test_comm, PIO_INT,
                                       title_in, history_in, &fortran_order_in)))
            return ret;

        /* Check the results. */
        {
            iosystem_desc_t *ios;
            io_desc_t *iodesc;
            int expected_maplen = (X_DIM_LEN * Y_DIM_LEN * Z_DIM_LEN / ntasks);

            /* Get the IO system info. */
            if (!(ios = pio_get_iosystem_from_id(iosysid)))
                return pio_err(NULL, NULL, PIO_EBADID, __FILE__, __LINE__);

            /* Get the IO desc, which describes the decomposition. */
            if (!(iodesc = pio_get_iodesc_from_id(ioid2)))
                return pio_err(ios, NULL, PIO_EBADID, __FILE__, __LINE__);
            if (iodesc->ioid != ioid2 || iodesc->maplen != expected_maplen || iodesc->ndims != NDIM3 ||
                iodesc->ndof != expected_maplen)
                return ERR_WRONG;
            if (iodesc->rearranger != rearranger || iodesc->maxregions != 1 ||
                iodesc->needsfill || iodesc->mpitype != MPI_INT)
                return ERR_WRONG;
            for (int e = 0; e < iodesc->maplen; e++)
                if (iodesc->map[e] != my_rank * iodesc->maplen + e + 1)
                    return ERR_WRONG;
            if (iodesc->dimlen[0] != X_DIM_LEN || iodesc->dimlen[1] != Y_DIM_LEN ||
                iodesc->dimlen[2] != Z_DIM_LEN)
                return ERR_WRONG;
            if (rearranger == PIO_REARR_SUBSET)
            {
                if (iodesc->nrecvs != 1  || iodesc->num_aiotasks != ntasks)
                    return ERR_WRONG;
            }
            else
            {
                /* I haven't figured out yet what these should be for
                 * the box rearranger. */
                /* printf("iodesc->nrecv = %d iodesc->num_aiotasks = %d\n", iodesc->nrecvs, */
                /*        iodesc->num_aiotasks); */
            }
        }

        /* Free the PIO decomposition. */
        if ((ret = PIOc_freedecomp(iosysid, ioid2)))
            ERR(ret);
    }
    return PIO_NOERR;
}

/**
 * Run all the tests.
 *
 * @param iosysid the IO system ID.
 * @param num_flavors number of available iotypes in the build.
 * @param flavor pointer to array of the available iotypes.
 * @param my_rank rank of this task.
 * @param ntasks number of tasks in test_comm.
 * @param num_io_procs number of IO procs used.
 * @param rearranger the rearranger to use (PIO_REARR_BOX or
 * PIO_REARR_SUBSET).
 * @param test_comm the communicator the test is running on.
 * @returns 0 for success, error code otherwise.
 */
int
test_all_darray(int iosysid, int num_flavors, int *flavor, int my_rank,
                int ntasks, int num_io_procs, int rearranger,
                MPI_Comm test_comm)
{
    int ioid;
    int my_test_size;
    int ret; /* Return code. */

    if ((ret = MPI_Comm_size(test_comm, &my_test_size)))
        MPIERR(ret);

#ifdef USE_MPE
    test_start_mpe_log(TEST_DECOMP);
#endif /* USE_MPE */

    /* Decompose the data over the tasks. */
    if ((ret = create_decomposition_3d(ntasks, my_rank, iosysid, &ioid)))
        return ret;

    /* /\* Test decomposition read/write. *\/ */
    /* if ((ret = test_decomp_read_write(iosysid, ioid, num_flavors, flavor, my_rank, */
    /*                                   ntasks, rearranger, test_comm))) */
    /*     return ret; */

#ifdef USE_MPE
    test_stop_mpe_log(TEST_DECOMP, TEST_NAME);
#endif /* USE_MPE */

    /* Test with/without providing a fill value to PIOc_write_darray(). */
    /* for (int provide_fill = 0; provide_fill < NUM_TEST_CASES_FILLVALUE; provide_fill++) */
    for (int provide_fill = 0; provide_fill < 1; provide_fill++)
    {
        /* Run a simple darray test. */
        if ((ret = test_darray(iosysid, ioid, num_flavors, flavor, my_rank,
                               ntasks, num_io_procs, provide_fill, rearranger)))
            return ret;
    }

#ifdef USE_MPE
    test_start_mpe_log(TEST_DECOMP);
#endif /* USE_MPE */

    /* Free the PIO decomposition. */
    if ((ret = PIOc_freedecomp(iosysid, ioid)))
        ERR(ret);

#ifdef USE_MPE
    test_stop_mpe_log(TEST_DECOMP, TEST_NAME);
#endif /* USE_MPE */

    return PIO_NOERR;
}

/* Run tests for darray functions. */
int
main(int argc, char **argv)
{
    int my_rank;
    int ntasks;
    MPI_Comm test_comm; /* A communicator for this test. */
    int rearranger[NUM_REARRANGERS_TO_TEST] = {PIO_REARR_BOX, PIO_REARR_SUBSET};
    int iosysid;  /* The ID for the parallel I/O system. */
    int ioproc_stride = 1;    /* Stride in the mpi rank between io tasks. */
    int ioproc_start = 0;     /* Zero based rank of first processor to be used for I/O. */
    int num_flavors; /* Number of PIO netCDF flavors in this build. */
    int flavor[NUM_FLAVORS]; /* iotypes for the supported netCDF IO flavors. */
    int num_io_procs[MAX_IO_TESTS] = {1, 4, 16, 64, 128}; /* Number of processors that will do IO. */
    int num_io_tests; /* How many different num IO procs to try? */
    int r, i;
    int ret;      /* Return code. */

    /* Initialize test. */
    if ((ret = pio_test_init2(argc, argv, &my_rank, &ntasks, 1,
                              0, -1, &test_comm)))
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

    if (!my_rank)
        printf("ntasks\tnio\trearr\tfill\tformat\ttime(s)\tdata size (MB)\t"
               "performance(MB/s)\n");

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

    for (i = 0; i < num_io_tests; i++)
    {
        /* for (r = 0; r < NUM_REARRANGERS_TO_TEST; r++) */
        for (r = 0; r < 1; r++)
        {
#ifdef USE_MPE
            test_start_mpe_log(TEST_INIT);
#endif /* USE_MPE */

            /* Initialize the PIO IO system. This specifies how
             * many and which processors are involved in I/O. */
            if ((ret = PIOc_Init_Intracomm(test_comm, num_io_procs[i], ioproc_stride,
                                           ioproc_start, rearranger[r], &iosysid)))
                return ret;

#ifdef USE_MPE
            test_stop_mpe_log(TEST_INIT, "test_perf2 init");
#endif /* USE_MPE */

            /* Run tests. */
            if ((ret = test_all_darray(iosysid, num_flavors, flavor, my_rank,
                                       ntasks, num_io_procs[i], rearranger[r], test_comm)))
                return ret;

            /* Finalize PIO system. */
            if ((ret = PIOc_free_iosystem(iosysid)))
                return ret;
        } /* next rearranger */
    } /* next num io procs */

    if (!my_rank)
        printf("finalizing io_test!\n");

    /* Finalize the MPI library. */
    if ((ret = pio_test_finalize(&test_comm)))
        return ret;

    /* printf("%d %s SUCCESS!!\n", my_rank, TEST_NAME); */
    return 0;
}
