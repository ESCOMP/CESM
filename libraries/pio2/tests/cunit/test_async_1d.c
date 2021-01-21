/*
 * Tests for PIOc_Intercomm. This tests basic asynch I/O capability.
 *
 * This very simple test runs on 4 ranks.
 *
 * @author Ed Hartnett
 */
#include <config.h>
#include <pio.h>
#include <pio_tests.h>

/* The number of tasks this test should run on. */
#define TARGET_NTASKS 4

/* The number of IO tasks. */
#define NUM_IO_TASKS 1

/* The number of computational tasks. */
#define NUM_COMP_TASKS 3

/* The name of this test. */
#define TEST_NAME "test_async_1d"

/* The name of the output of the test. */
#define FILE_NAME "test_async_1d.nc"

/* Number of different combonations of IO and computation processor
 * numbers we will try in this test. */
#define NUM_COMBOS 3

/* Number of computational components to create. */
#define COMPONENT_COUNT 1

#define NDIM1 1
#define NDIM2 2
#define DIM_NAME_0 "unlim"
#define DIM_NAME_1 "dim_1"
#define DIM_LEN_1 3
#define VAR_NAME "async_var"
#define MAPLEN 1

/* Run async tests. */
int main(int argc, char **argv)
{
#ifdef USE_NETCDF4
    int my_rank; /* Zero-based rank of processor. */
    int ntasks; /* Number of processors involved in current execution. */
    int iosysid; /* The ID for the parallel I/O system. */
    int num_procs_per_comp[COMPONENT_COUNT] = {3};
    /* int num_flavors; /\* Number of PIO netCDF flavors in this build. *\/ */
    /* int flavor[NUM_FLAVORS]; /\* iotypes for the supported netCDF IO flavors. *\/ */
    int ret; /* Return code. */

    /* Initialize MPI. */
    if ((ret = MPI_Init(&argc, &argv)))
        MPIERR(ret);

    /* Learn my rank and the total number of processors. */
    if ((ret = MPI_Comm_rank(MPI_COMM_WORLD, &my_rank)))
        MPIERR(ret);
    if ((ret = MPI_Comm_size(MPI_COMM_WORLD, &ntasks)))
        MPIERR(ret);

    /* Make sure we have 4 tasks. */
    if (ntasks != TARGET_NTASKS) ERR(ERR_WRONG);

    /* PIOc_set_log_level(4); */

    /* Change error handling so we can test inval parameters. */
    if ((ret = PIOc_set_iosystem_error_handling(PIO_DEFAULT, PIO_RETURN_ERROR, NULL)))
        return ret;

    /* Set up IO system. Task 0 will do IO, tasks 1-3 will be a single
     * computational unit. Task 0 will stay in this function until the
     * computational component calls PIOc_finalize(). */
    if ((ret = PIOc_init_async(MPI_COMM_WORLD, NUM_IO_TASKS, NULL, COMPONENT_COUNT,
                               num_procs_per_comp, NULL, NULL, NULL,
                               PIO_REARR_BOX, &iosysid)))
        ERR(ret);

    /* Only computational processors run this code. */
    if (my_rank)
    {
        int ncid;
        int iotype = PIO_IOTYPE_NETCDF4C;
        int dimid[NDIM2];
        int gdimlen[NDIM1] = {DIM_LEN_1};
        PIO_Offset compmap[MAPLEN];
        int varid;
        int data;
        int data_in;
        int ioid;

        /* Create a file. */
        if ((ret = PIOc_createfile(iosysid, &ncid, &iotype, FILE_NAME, 0)))
            ERR(ret);
        if ((ret = PIOc_def_dim(ncid, DIM_NAME_0, PIO_UNLIMITED, &dimid[0])))
            ERR(ret);
        if ((ret = PIOc_def_dim(ncid, DIM_NAME_1, DIM_LEN_1, &dimid[1])))
            ERR(ret);
        if ((ret = PIOc_def_var(ncid, VAR_NAME, PIO_INT, NDIM2, dimid, &varid)))
            ERR(ret);
        if ((ret = PIOc_def_var_fill(ncid, varid, PIO_NOFILL, NULL)))
            ERR(ret);
        if ((ret = PIOc_enddef(ncid)))
            ERR(ret);

        /* Set up a decomposition. Each of the 3 computational procs
         * will write one value, to get the 3-values of each
         * record. */
        compmap[0] = my_rank - 1;
        if ((ret = PIOc_init_decomp(iosysid, PIO_INT, NDIM1, gdimlen, MAPLEN,
                                    compmap, &ioid, PIO_REARR_BOX, NULL, NULL)))
            ERR(ret);

        /* Write a record of data. */
        data = my_rank;
        if ((ret = PIOc_setframe(ncid, 0, 0)))
            ERR(ret);
        if ((ret = PIOc_write_darray(ncid, 0, ioid, MAPLEN, &data, NULL)))
            ERR(ret);

        /* Close the file. */
        if ((ret = PIOc_closefile(ncid)))
            ERR(ret);

        /* Reopen the file and check. */
        if ((ret = PIOc_openfile(iosysid, &ncid, &iotype, FILE_NAME, 0)))
            ERR(ret);

        /* Read the data. */
        if ((ret = PIOc_setframe(ncid, 0, 0)))
            ERR(ret);
        if ((ret = PIOc_read_darray(ncid, 0, ioid, MAPLEN, &data_in)))
            ERR(ret);
        if (data_in != data) ERR(ERR_WRONG);

        /* Close the file. */
        if ((ret = PIOc_closefile(ncid)))
            ERR(ret);

        /* Free the decomposition. */
        if ((ret = PIOc_freedecomp(iosysid, ioid)))
            ERR(ret);

        /* Shut down the IO system. */
        if ((ret = PIOc_finalize(iosysid)))
            ERR(ret);
    }

    printf("%d %s SUCCESS!!\n", my_rank, TEST_NAME);
#endif /* USE_NETCDF4 */

    return 0;
}
