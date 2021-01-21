/*
 * Tests for PIO distributed arrays.
 *
 * @author Ed Hartnett
 * @date 6/4/19
 */
#include <config.h>
#include <pio.h>
#include <pio_internal.h>
#include <pio_tests.h>

/* The number of tasks this test should run on. */
#define TARGET_NTASKS 4

/* The minimum number of tasks this test should run on. */
#define MIN_NTASKS 4

/* The name of this test. */
#define TEST_NAME "test_darray_vard"

/* Number of processors that will do IO. */
#define NUM_IO_PROCS 1

/* Number of computational components to create. */
#define COMPONENT_COUNT 1

/* The number of dimensions in the example data. In this test, we
 * are using three-dimensional data. */
#define NDIM 3

/* But sometimes we need arrays of the non-record dimensions. */
#define NDIM2 2

/* The length of our sample data along each dimension. */
#define X_DIM_LEN 4
#define Y_DIM_LEN 4

/* The names of variables in the netCDF output files. */
#define VAR_NAME "Billy-Bob"

/* Test with and without specifying a fill value to
 * PIOc_write_darray(). */
#define NUM_TEST_CASES_FILLVALUE 2

/* The dimension names. */
char dim_name[NDIM][PIO_MAX_NAME + 1] = {"timestep", "x", "y"};

/* Length of the dimensions in the sample data. */
int dim_len[NDIM] = {NC_UNLIMITED, X_DIM_LEN, Y_DIM_LEN};

#define NUM_TYPES_TO_TEST 6

/**
 * Test the darray functionality. Create a netCDF file with 3
 * dimensions and 1 PIO_INT variable, and use darray to write some
 * data.
 *
 * @param iosysid the IO system ID.
 * @param ioid the ID of the decomposition.
 * @param fmt the index of the IOTYPE to test.
 * @param num_flavors the number of IOTYPES available in this build.
 * @param flavor array of available iotypes.
 * @param my_rank rank of this task.
 * @param pio_type the type of the data.
 * @returns 0 for success, error code otherwise.
 */
int test_darray(int iosysid, int ioid, int fmt, int num_flavors,
                int *flavor, int my_rank, int pio_type)
{
    char filename[PIO_MAX_NAME + 1]; /* Name for the output files. */
    int dimids[NDIM];      /* The dimension IDs. */
    int ncid;      /* The ncid of the netCDF file. */
    int ncid2;     /* The ncid of the re-opened netCDF file. */
    int varid;     /* The ID of the netCDF varable. */
    int ret;       /* Return code. */
    int type_to_use;
    PIO_Offset arraylen = 4;
    char test_data_char[arraylen];
    char test_data_char_in[arraylen];
    signed char test_data_byte[arraylen];
    signed char test_data_byte_in[arraylen];
    short test_data_short[arraylen];
    short test_data_short_in[arraylen];
    int test_data_int[arraylen];
    int test_data_int_in[arraylen];
    float test_data_float[arraylen];
    float test_data_float_in[arraylen];
    double test_data_double[arraylen];
    double test_data_double_in[arraylen];
    unsigned char test_data_ubyte[arraylen];
    unsigned char test_data_ubyte_in[arraylen];
    unsigned short test_data_ushort[arraylen];
    unsigned short test_data_ushort_in[arraylen];
    unsigned int test_data_uint[arraylen];
    unsigned int test_data_uint_in[arraylen];
    long long int test_data_int64[arraylen];
    long long int test_data_int64_in[arraylen];
    unsigned long long int test_data_uint64[arraylen];
    unsigned long long int test_data_uint64_in[arraylen];
    int f, d;

    /* Initialize some data. */
    for (f = 0; f < arraylen; f++)
    {
        test_data_char[f] = my_rank;
        test_data_byte[f] = my_rank - f;
        test_data_short[f] = my_rank + f;
        test_data_int[f] = my_rank * 10 + f;
        test_data_float[f] = my_rank * 10 + f + 0.5;
        test_data_double[f] = my_rank * 100000 + f + 0.5;
        test_data_ubyte[f] = my_rank + f + 2;
        test_data_ushort[f] = my_rank + f + 20;
        test_data_uint[f] = my_rank + f + 200;
        test_data_int64[f] = my_rank - f - 20000;
        test_data_uint64[f] = my_rank + f + 20000;
    }

    /* Use PIO to create the example file in each of the four
     * available ways. */
    {
        /* Pnetcdf cannot handle 1-byte types. */
        if (fmt == 0 && (pio_type == PIO_BYTE || pio_type == PIO_CHAR))
            return PIO_NOERR;

        {
            /* Create the filename. */
            sprintf(filename, "%s_iotype_%d_pio_type_%d.nc",
                    TEST_NAME, flavor[fmt], pio_type);

            /* Create the netCDF output file. */
            if ((ret = PIOc_createfile(iosysid, &ncid, &flavor[fmt], filename,
                                       PIO_CLOBBER)))
                ERR(ret);

            /* Define netCDF dimensions and variable. */
            for (d = 0; d < NDIM; d++)
                if ((ret = PIOc_def_dim(ncid, dim_name[d],
                                        (PIO_Offset)dim_len[d], &dimids[d])))
                    ERR(ret);

            /* Define a variable. */
            type_to_use = (pio_type == NC_NAT) ? PIO_INT : pio_type;
            if ((ret = PIOc_def_var(ncid, VAR_NAME, type_to_use, NDIM, dimids,
                                    &varid)))
                ERR(ret);

            /* End define mode. */
            if ((ret = PIOc_enddef(ncid)))
                ERR(ret);


            switch (pio_type)
            {
            case PIO_CHAR:
                /* These should not work. */
                if (PIOc_put_vard_text(ncid + TEST_VAL_42, varid, ioid, 0,
                                       test_data_char) != PIO_EBADID)
                    ERR(ERR_WRONG);
                if (PIOc_put_vard_text(ncid, varid + TEST_VAL_42, ioid, 0,
                                       test_data_char) != PIO_ENOTVAR)
                    ERR(ERR_WRONG);
                if (PIOc_put_vard_text(ncid, varid, ioid + TEST_VAL_42, 0,
                                       test_data_char) != PIO_EBADID)
                    ERR(ERR_WRONG);

                /* This will work. */
                if ((ret = PIOc_put_vard_text(ncid, varid, ioid, 0,
                                              test_data_char)))
                    ERR(ret);
                break;
            case PIO_BYTE:
                if ((ret = PIOc_put_vard_schar(ncid, varid, ioid, 0,
                                               test_data_byte)))
                    ERR(ret);
                break;
            case PIO_SHORT:
                if ((ret = PIOc_put_vard_short(ncid, varid, ioid, 0,
                                               test_data_short)))
                    ERR(ret);
                break;
            case PIO_INT:
                if ((ret = PIOc_put_vard_int(ncid, varid, ioid, 0,
                                             test_data_int)))
                    ERR(ret);
                break;
            case PIO_FLOAT:
                if ((ret = PIOc_put_vard_float(ncid, varid, ioid, 0,
                                               test_data_float)))
                    ERR(ret);
                break;
            case PIO_DOUBLE:
                if ((ret = PIOc_put_vard_double(ncid, varid, ioid, 0,
                                                test_data_double)))
                    ERR(ret);
                break;
            case PIO_UBYTE:
                if ((ret = PIOc_put_vard_uchar(ncid, varid, ioid, 0,
                                               test_data_ubyte)))
                    ERR(ret);
                break;
            case PIO_USHORT:
                if ((ret = PIOc_put_vard_ushort(ncid, varid, ioid, 0,
                                                test_data_ushort)))
                    ERR(ret);
                break;
            case PIO_UINT:
                if ((ret = PIOc_put_vard_uint(ncid, varid, ioid, 0,
                                              test_data_uint)))
                    ERR(ret);
                break;
            case PIO_INT64:
                if ((ret = PIOc_put_vard_longlong(ncid, varid, ioid, 0,
                                                  test_data_int64)))
                    ERR(ret);
                break;
            case PIO_UINT64:
                if ((ret = PIOc_put_vard_ulonglong(ncid, varid, ioid, 0,
                                                   test_data_uint64)))
                    ERR(ret);
                break;
            case NC_NAT:
                /* Using NAT to test void * version, using int data. */
                if ((ret = PIOc_put_vard(ncid, varid, ioid, 0, test_data_int)))
                    ERR(ret);
                break;
            default:
                ERR(ERR_WRONG);
            }

            /* Close the netCDF file. */
            if ((ret = PIOc_closefile(ncid)))
                ERR(ret);

            /* Reopen the file. */
            if ((ret = PIOc_openfile(iosysid, &ncid2, &flavor[fmt], filename,
                                     PIO_NOWRITE)))
                ERR(ret);

            PIO_Offset dimlen;

            /* check the unlimited dim size - it should be 1 */
            if ((ret = PIOc_inq_dimlen(ncid2, dimids[0], &dimlen)))
                ERR(ret);
            if (dimlen != 1)
                ERR(ERR_WRONG);

            /* Read the data. */
            switch (pio_type)
            {
            case PIO_CHAR:
                /* These should not work. */
                if ((ret = PIOc_get_vard_text(ncid2 + TEST_VAL_42, varid, ioid, 0,
                                              test_data_char_in)) != PIO_EBADID)
                    ERR(ret);
                if ((ret = PIOc_get_vard_text(ncid2, varid, ioid + TEST_VAL_42, 0,
                                              test_data_char_in)) != PIO_EBADID)
                    ERR(ret);

                /* This will work. */
                if ((ret = PIOc_get_vard_text(ncid2, varid, ioid, 0,
                                              test_data_char_in)))
                    ERR(ret);
                break;
            case PIO_BYTE:
                if ((ret = PIOc_get_vard_schar(ncid2, varid, ioid, 0,
                                               test_data_byte_in)))
                    ERR(ret);
                break;
            case PIO_SHORT:
                if ((ret = PIOc_get_vard_short(ncid2, varid, ioid, 0,
                                               test_data_short_in)))
                    ERR(ret);
                break;
            case PIO_INT:
                if ((ret = PIOc_get_vard_int(ncid2, varid, ioid, 0,
                                             test_data_int_in)))
                    ERR(ret);
                break;
            case PIO_FLOAT:
                if ((ret = PIOc_get_vard_float(ncid2, varid, ioid, 0,
                                               test_data_float_in)))
                    ERR(ret);
                break;
            case PIO_DOUBLE:
                if ((ret = PIOc_get_vard_double(ncid2, varid, ioid, 0,
                                                test_data_double_in)))
                    ERR(ret);
                break;
            case PIO_UBYTE:
                if ((ret = PIOc_get_vard_uchar(ncid2, varid, ioid, 0,
                                               test_data_ubyte_in)))
                    ERR(ret);
                break;
            case PIO_USHORT:
                if ((ret = PIOc_get_vard_ushort(ncid2, varid, ioid, 0,
                                                test_data_ushort_in)))
                    ERR(ret);
                break;
            case PIO_UINT:
                if ((ret = PIOc_get_vard_uint(ncid2, varid, ioid, 0,
                                              test_data_uint_in)))
                    ERR(ret);
                break;
            case PIO_INT64:
                if ((ret = PIOc_get_vard_longlong(ncid2, varid, ioid, 0,
                                                  test_data_int64_in)))
                    ERR(ret);
                break;
            case PIO_UINT64:
                if ((ret = PIOc_get_vard_ulonglong(ncid2, varid, ioid, 0,
                                                   test_data_uint64_in)))
                    ERR(ret);
                break;
            case NC_NAT:
                /* Using NAT to test void * version, using int data. */
                if ((ret = PIOc_get_vard(ncid2, varid, ioid, 0,
                                         test_data_int_in)))
                    ERR(ret);
                break;
            default:
                ERR(ERR_WRONG);
            }

            /* Check the results. */
            for (f = 0; f < arraylen; f++)
            {
                switch (pio_type)
                {
                case PIO_CHAR:
                    if (test_data_char_in[f] != test_data_char[f])
                        return ERR_WRONG;
                    break;
                case PIO_BYTE:
                    if (test_data_byte_in[f] != test_data_byte[f])
                        return ERR_WRONG;
                    break;
                case PIO_SHORT:
                    if (test_data_short_in[f] != test_data_short[f])
                        return ERR_WRONG;
                    break;
                case PIO_INT:
                    if (test_data_int_in[f] != test_data_int[f])
                        return ERR_WRONG;
                    break;
                case PIO_FLOAT:
                    if (test_data_float_in[f] != test_data_float[f])
                        return ERR_WRONG;
                    break;
                case PIO_DOUBLE:
                    if (test_data_double_in[f] != test_data_double[f])
                        return ERR_WRONG;
                    break;
                case PIO_UBYTE:
                    if (test_data_ubyte_in[f] != test_data_ubyte[f])
                        return ERR_WRONG;
                    break;
                case PIO_USHORT:
                    if (test_data_ushort_in[f] != test_data_ushort[f])
                        return ERR_WRONG;
                    break;
                case PIO_UINT:
                    if (test_data_uint_in[f] != test_data_uint[f])
                        return ERR_WRONG;
                    break;
                case PIO_INT64:
                    if (test_data_int64_in[f] != test_data_int64[f])
                        return ERR_WRONG;
                    break;
                case PIO_UINT64:
                    if (test_data_uint64_in[f] != test_data_uint64[f])
                        return ERR_WRONG;
                    break;
                case NC_NAT:
                    /* Using NAT to test void * version, using int data. */
                    if (test_data_int_in[f] != test_data_int[f])
                        return ERR_WRONG;
                    break;
                default:
                    ERR(ERR_WRONG);
                }
            }

            /* Try to write, but it won't work, because we opened file
             * read-only. */
            if (PIOc_write_darray(ncid2, varid, ioid, arraylen, test_data_char,
                                  NULL) != PIO_EPERM)
                ERR(ERR_WRONG);

            /* Close the netCDF file. */
            if ((ret = PIOc_closefile(ncid2)))
                ERR(ret);
        } /* next fillvalue test case */
    } /* next iotype */

    return PIO_NOERR;
}

/**
 * Run all the tests.
 *
 * @param iosysid the IO system ID.
 * @param fmt index into array of IOTYPEs.
 * @param num_flavors number of available iotypes in the build.
 * @param flavor pointer to array of the available iotypes.
 * @param my_rank rank of this task.
 * @param test_comm the communicator the test is running on.
 * @returns 0 for success, error code otherwise.
 */
int test_all_darray(int iosysid, int fmt, int num_flavors, int *flavor,
                    int my_rank, MPI_Comm test_comm)
{
    int ioid;
    char filename[PIO_MAX_NAME + 1];
    int pio_type[NUM_NETCDF4_TYPES] = {PIO_BYTE, PIO_CHAR, PIO_SHORT, PIO_INT,
                                       PIO_FLOAT, PIO_DOUBLE, PIO_UBYTE, PIO_USHORT,
                                       PIO_UINT, PIO_INT64, PIO_UINT64, NC_NAT};
    int dim_len_2d[NDIM2] = {X_DIM_LEN, Y_DIM_LEN};
    int num_types;
    int t;
    int ret; /* Return code. */

    /* Based on the IOTYPE, decide how many types to check. */
    if (flavor[fmt] == PIO_IOTYPE_NETCDF4C || flavor[fmt] == PIO_IOTYPE_NETCDF4P)
        num_types = NUM_NETCDF4_TYPES;
    else
        num_types = NUM_CLASSIC_TYPES;

    /* Check each type. */
    for (t = 0; t < num_types; t++)
    {
        int type_to_use;

        /* Using NAT to test generic versions of vard functions, so
         * substiture PIO_INT. */
        type_to_use = (pio_type[t] == NC_NAT) ? PIO_INT : pio_type[t];

        /* This will be our file name for writing out decompositions. */
        sprintf(filename, "%s_decomp_rank_%d_flavor_%d_type_%d.nc",
                TEST_NAME, my_rank, *flavor, pio_type[t]);

        /* Decompose the data over the tasks. */
        if ((ret = create_decomposition_2d(TARGET_NTASKS, my_rank, iosysid,
                                           dim_len_2d, &ioid, type_to_use)))
            return ret;

        /* Run a simple darray test. */
        if ((ret = test_darray(iosysid, ioid, fmt, num_flavors, flavor,
                               my_rank, pio_type[t])))
            return ret;

        /* Free the PIO decomposition. */
        if ((ret = PIOc_freedecomp(iosysid, ioid)))
            ERR(ret);
    }

    return PIO_NOERR;
}

/* Run tests for darray functions. */
int main(int argc, char **argv)
{
#define NUM_REARRANGERS_TO_TEST 2
    int rearranger[NUM_REARRANGERS_TO_TEST] = {PIO_REARR_BOX, PIO_REARR_SUBSET};
    int my_rank;
    int ntasks;
    int num_flavors; /* Number of PIO netCDF flavors in this build. */
    int flavor[NUM_FLAVORS]; /* iotypes for the supported netCDF IO flavors. */
    MPI_Comm test_comm; /* A communicator for this test. */
    int ret;         /* Return code. */

    /* Initialize test. */
    if ((ret = pio_test_init2(argc, argv, &my_rank, &ntasks, MIN_NTASKS,
                              MIN_NTASKS, -1, &test_comm)))
        ERR(ERR_INIT);

    if ((ret = PIOc_set_iosystem_error_handling(PIO_DEFAULT,
                                                PIO_RETURN_ERROR, NULL)))
        return ret;

    /* Only do something on max_ntasks tasks. */
    if (my_rank < TARGET_NTASKS)
    {
        int iosysid;  /* The ID for the parallel I/O system. */
        int ioproc_stride = 1;    /* Stride in rank between io tasks. */
        int ioproc_start = 0;     /* Zero based rank of first I/O task. */
        int r;
        int fmt;
        int ret;      /* Return code. */

        /* Figure out iotypes. */
        if ((ret = get_iotypes(&num_flavors, flavor)))
            ERR(ret);

        for (fmt = 0; fmt < num_flavors; fmt++)
        {
            for (r = 0; r < NUM_REARRANGERS_TO_TEST; r++)
            {
                /* Initialize the PIO IO system. This specifies how
                 * many and which processors are involved in I/O. */
                if ((ret = PIOc_Init_Intracomm(test_comm, TARGET_NTASKS,
                                               ioproc_stride, ioproc_start,
                                               rearranger[r], &iosysid)))
                    return ret;

                /* Run tests. */
                if ((ret = test_all_darray(iosysid, fmt, num_flavors, flavor,
                                           my_rank, test_comm)))
                    return ret;

                /* Finalize PIO system. */
                if ((ret = PIOc_free_iosystem(iosysid)))
                    return ret;
            } /* next rearranger */
        }
    } /* endif my_rank < TARGET_NTASKS */

    /* Finalize the MPI library. */
    if ((ret = pio_test_finalize(&test_comm)))
        return ret;

    printf("%d %s SUCCESS!!\n", my_rank, TEST_NAME);
    return 0;
}
