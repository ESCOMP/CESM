/*
 * Tests for PIO distributed arrays. This code duplicates the code in
 * the fortran test pio_decomp_frame_tests.F90.
 *
 * @author Ed Hartnett
 * @date 5/7/18
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
#define TEST_NAME "test_decomp_frame"

/* Number of processors that will do IO. */
#define NUM_IO_PROCS 4

/* Number of computational components to create. */
#define COMPONENT_COUNT 1

#define VAR_NAME "PIO_TF_test_var"
#define DIM_NAME "PIO_TF_test_dim"
#define FILL_VALUE_NAME "_FillValue"

/* Test with and without specifying a fill value to
 * PIOc_write_darray(). */
#define NUM_TEST_CASES_FILLVALUE 2

#define NDIM1 1
#define MAPLEN 7

/* Length of the dimensions in the sample data. */
int dim_len[NDIM1] = {28};

/* Run test for each of the rearrangers. */
#define NUM_REARRANGERS_TO_TEST 2

/* Run tests for darray functions. */
int main(int argc, char **argv)
{
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

    if ((ret = PIOc_set_iosystem_error_handling(PIO_DEFAULT, PIO_RETURN_ERROR, NULL)))
        return ret;

    /* Only do something on max_ntasks tasks. */
    if (my_rank < TARGET_NTASKS)
    {
        int iosysid;  /* The ID for the parallel I/O system. */
        int ioproc_stride = 1;    /* Stride in the mpi rank between io tasks. */
        int ioproc_start = 0;     /* Zero based rank of first processor to be used for I/O. */
        int wioid, rioid;
        int maplen = MAPLEN;
        MPI_Offset wcompmap[MAPLEN];
        MPI_Offset rcompmap[MAPLEN];
        int rearranger[NUM_REARRANGERS_TO_TEST] = {PIO_REARR_BOX, PIO_REARR_SUBSET};

        /* Data we will write for each type. */
        signed char byte_data[MAPLEN];
        char char_data[MAPLEN];
        short short_data[MAPLEN];
        int int_data[MAPLEN];
        float float_data[MAPLEN];
        double double_data[MAPLEN];
#ifdef _NETCDF4
        unsigned char ubyte_data[MAPLEN];
        unsigned short ushort_data[MAPLEN];
        unsigned int uint_data[MAPLEN];
        long long int64_data[MAPLEN];
        unsigned long long uint64_data[MAPLEN];
#endif /* _NETCDF4 */

        /* Expected results for each type. */
        signed char byte_expected[MAPLEN];
        char char_expected[MAPLEN];
        short short_expected[MAPLEN];
        int int_expected[MAPLEN];
        float float_expected[MAPLEN];
        double double_expected[MAPLEN];
#ifdef _NETCDF4
        unsigned char ubyte_expected[MAPLEN];
        unsigned short ushort_expected[MAPLEN];
        unsigned int uint_expected[MAPLEN];
        long long int64_expected[MAPLEN];
        unsigned long long uint64_expected[MAPLEN];
#endif /* _NETCDF4 */

        /* Custom fill value for each type. */
        signed char byte_fill = -2;
        char char_fill = 2;
        short short_fill = -2;
        int int_fill = -2;
        float float_fill = -2;
        double double_fill = -2;
#ifdef _NETCDF4
        unsigned char ubyte_fill = 2;
        unsigned short ushort_fill = 2;
        unsigned int uint_fill = 2;
        long long int64_fill = 2;
        unsigned long long uint64_fill = 2;
#endif /* _NETCDF4 */

        /* Default fill value for each type. */
        signed char byte_default_fill = NC_FILL_BYTE;
        char char_default_fill = NC_FILL_CHAR;
        short short_default_fill = NC_FILL_SHORT;
        int int_default_fill = NC_FILL_INT;
        float float_default_fill = NC_FILL_FLOAT;
        double double_default_fill = NC_FILL_DOUBLE;
#ifdef _NETCDF4
        unsigned char ubyte_default_fill = NC_FILL_UBYTE;
        unsigned short ushort_default_fill = NC_FILL_USHORT;
        unsigned int uint_default_fill = NC_FILL_UINT;
        long long int64_default_fill = NC_FILL_INT64;
        unsigned long long uint64_default_fill = NC_FILL_UINT64;
#endif /* _NETCDF4 */

        int ret;      /* Return code. */

        /* Set up the compmaps. Don't forget these are 1-based
         * numbers, like in Fortran! */
        for (int i = 0; i < MAPLEN; i++)
        {
            wcompmap[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : 0; /* Even values missing. */
            rcompmap[i] = my_rank * MAPLEN + i + 1;
        }

        /* Figure out iotypes. */
        if ((ret = get_iotypes(&num_flavors, flavor)))
            ERR(ret);

        /* Test for each rearranger. */
        for (int r = 0; r < NUM_REARRANGERS_TO_TEST; r++)
        {
            /* Initialize the PIO IO system. This specifies how
             * many and which processors are involved in I/O. */
            if ((ret = PIOc_Init_Intracomm(test_comm, NUM_IO_PROCS, ioproc_stride, ioproc_start,
                                           rearranger[r], &iosysid)))
                return ret;

            /* Test with and without custom fill values. */
            for (int fv = 0; fv < NUM_TEST_CASES_FILLVALUE; fv++)
            {
#ifndef _NETCDF4
#define NUM_TYPES 6
                int test_type[NUM_TYPES] = {PIO_BYTE, PIO_CHAR, PIO_SHORT, PIO_INT, PIO_FLOAT, PIO_DOUBLE};
#else
#define NUM_TYPES 11
                int test_type[NUM_TYPES] = {PIO_BYTE, PIO_CHAR, PIO_SHORT, PIO_INT, PIO_FLOAT, PIO_DOUBLE,
                                            PIO_UBYTE, PIO_USHORT, PIO_UINT, PIO_INT64, PIO_UINT64};
                
#endif /* _NETCDF4 */

                /* Determine what data to write. Put value of 42 into
                 * array elements that will not get written. Due to
                 * the decomposition, these will be replaced by fill
                 * values. */
                for (int i = 0; i < MAPLEN; i++)
                {
                    byte_data[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : TEST_VAL_42;
                    char_data[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : TEST_VAL_42;
                    short_data[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : TEST_VAL_42;
                    int_data[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : TEST_VAL_42;
                    float_data[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : TEST_VAL_42;
                    double_data[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : TEST_VAL_42;
#ifdef _NETCDF4
                    ubyte_data[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : TEST_VAL_42;
                    ushort_data[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : TEST_VAL_42;
                    uint_data[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : TEST_VAL_42;
                    int64_data[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : TEST_VAL_42;
                    uint64_data[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : TEST_VAL_42;
#endif /* _NETCDF4 */
                }

                /* Determine what data to expect from the test. For
                 * even values of i, the fill value will be used, and
                 * it may be custom or default fill value. */
                for (int i = 0; i < MAPLEN; i++)
                {
                    byte_expected[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : (fv ? byte_default_fill : byte_fill);
                    char_expected[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : (fv ? char_default_fill : char_fill);
                    short_expected[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : (fv ? short_default_fill : short_fill);
                    int_expected[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : (fv ? int_default_fill : int_fill);
                    float_expected[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : (fv ? float_default_fill : float_fill);
                    double_expected[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : (fv ? double_default_fill : double_fill);
#ifdef _NETCDF4
                    ubyte_expected[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : (fv ? ubyte_default_fill : ubyte_fill);
                    ushort_expected[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : (fv ? ushort_default_fill : ushort_fill);
                    uint_expected[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : (fv ? uint_default_fill : uint_fill);
                    int64_expected[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : (fv ? int64_default_fill : int64_fill);
                    uint64_expected[i] = (i % 2) ? my_rank * MAPLEN + i + 1 : (fv ? uint64_default_fill : uint64_fill);
#endif /* _NETCDF4 */
                }

                /* Test for each available type. */
                for (int t = 0; t < NUM_TYPES; t++)
                {
                    void *expected;
                    void *fill;
                    void *data;
                    int ncid, dimid, varid;
                    char filename[NC_MAX_NAME + 1];

                    switch (test_type[t])
                    {
                    case PIO_BYTE:
                        expected = byte_expected;
                        fill = fv ? &byte_default_fill : &byte_fill;
                        data = byte_data;
                        break;
                    case PIO_CHAR:
                        expected = char_expected;
                        fill = fv ? &char_default_fill : &char_fill;
                        data = char_data;
                        break;
                    case PIO_SHORT:
                        expected = short_expected;
                        fill = fv ? &short_default_fill : &short_fill;
                        data = short_data;
                        break;
                    case PIO_INT:
                        expected = int_expected;
                        fill = fv ? &int_default_fill : &int_fill;
                        data = int_data;
                        break;
                    case PIO_FLOAT:
                        expected = float_expected;
                        fill = fv ? &float_default_fill : &float_fill;
                        data = float_data;
                        break;
                    case PIO_DOUBLE:
                        expected = double_expected;
                        fill = fv ? &double_default_fill : &double_fill;
                        data = double_data;
                        break;
#ifdef _NETCDF4
                    case PIO_UBYTE:
                        expected = ubyte_expected;
                        fill = fv ? &ubyte_default_fill : &ubyte_fill;
                        data = ubyte_data;
                        break;
                    case PIO_USHORT:
                        expected = ushort_expected;
                        fill = fv ? &ushort_default_fill : &ushort_fill;
                        data = ushort_data;
                        break;
                    case PIO_UINT:
                        expected = uint_expected;
                        fill = fv ? &uint_default_fill : &uint_fill;
                        data = uint_data;
                        break;
                    case PIO_INT64:
                        expected = int64_expected;
                        fill = fv ? &int64_default_fill : &int64_fill;
                        data = int64_data;
                        break;
                    case PIO_UINT64:
                        expected = uint64_expected;
                        fill = fv ? &uint64_default_fill : &uint64_fill;
                        data = uint64_data;
                        break;
#endif /* _NETCDF4 */
                    default:
                        return ERR_AWFUL;
                    }

                    /* Initialize decompositions. */
                    if ((ret = PIOc_InitDecomp(iosysid, test_type[t], NDIM1, dim_len, maplen, wcompmap,
                                               &wioid, &rearranger[r], NULL, NULL)))
                        return ret;
                    if ((ret = PIOc_InitDecomp(iosysid, test_type[t], NDIM1, dim_len, maplen, rcompmap,
                                               &rioid, &rearranger[r], NULL, NULL)))
                        return ret;

                    /* Create the test file in each of the available iotypes. */
                    for (int fmt = 0; fmt < num_flavors; fmt++)
                    {
                        PIO_Offset type_size;
                        void *data_in;

                        /* Byte type doesn't work with pnetcdf. */
                        if (flavor[fmt] == PIO_IOTYPE_PNETCDF && (test_type[t] == PIO_BYTE || test_type[t] == PIO_CHAR))
                            continue;

                        /* NetCDF-4 types only work with netCDF-4 formats. */
                        if (test_type[t] > PIO_DOUBLE && flavor[fmt] != PIO_IOTYPE_NETCDF4C &&
                            flavor[fmt] != PIO_IOTYPE_NETCDF4P)
                            continue;

                        /* Put together filename. */
                        sprintf(filename, "%s_iotype_%d_rearr_%d_type_%d.nc", TEST_NAME, flavor[fmt],
                                rearranger[r], test_type[t]);

                        /* Create file. */
                        if ((ret = PIOc_createfile(iosysid, &ncid, &flavor[fmt], filename, NC_CLOBBER)))
                            return ret;

                        /* Define metadata. */
                        if ((ret = PIOc_def_dim(ncid, DIM_NAME, dim_len[0], &dimid)))
                            return ret;
                        if ((ret = PIOc_def_var(ncid, VAR_NAME, test_type[t], NDIM1, &dimid, &varid)))
                            return ret;
                        if ((ret = PIOc_put_att(ncid, varid, FILL_VALUE_NAME, test_type[t],
                                                1, fill)))
                            return ret;
                        if ((ret = PIOc_enddef(ncid)))
                            return ret;

                        /* Write some data. */
                        if ((ret = PIOc_write_darray(ncid, varid, wioid, MAPLEN, data, fill)))
                            return ret;
                        if ((ret = PIOc_sync(ncid)))
                            return ret;

                        /* What is size of type? */
                        if ((ret = PIOc_inq_type(ncid, test_type[t], NULL, &type_size)))
                            return ret;

                        /* Allocate space to read data into. */
                        if (!(data_in = malloc(type_size * MAPLEN)))
                            return PIO_ENOMEM;

                        /* Read the data. */
                        if ((ret = PIOc_read_darray(ncid, varid, rioid, MAPLEN, data_in)))
                            return ret;

                        /* Check results. */
                        if (memcmp(data_in, expected, type_size * MAPLEN))
                            return ERR_AWFUL;

                        /* Release storage. */
                        free(data_in);

                        /* Close file. */
                        if ((ret = PIOc_closefile(ncid)))
                            return ret;
                    } /* next iotype */

                    /* Free decompositions. */
                    if ((ret = PIOc_freedecomp(iosysid, wioid)))
                        return ret;
                    if ((ret = PIOc_freedecomp(iosysid, rioid)))
                        return ret;

                } /* next type */
            } /* next fill value test case */
        } /* next rearranger */

        /* Finalize PIO system. */
        if ((ret = PIOc_free_iosystem(iosysid)))
            return ret;

    } /* endif my_rank < TARGET_NTASKS */

    /* Finalize the MPI library. */
    if ((ret = pio_test_finalize(&test_comm)))
        return ret;

    printf("%d %s SUCCESS!!\n", my_rank, TEST_NAME);
    return 0;
}
