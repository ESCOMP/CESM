/*
 * @file
 * @brief A simple C example for the ParallelIO Library.
 *
 * This example creates a netCDF output file with three dimensions
 * (one unlimited) and one variable. It first writes, then reads the
 * sample file using distributed arrays.
 *
 * This example can be run in parallel for 16 processors.
 */

#include "config.h"
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <mpi.h>
#include <pio.h>
#include <pio_internal.h>
#ifdef TIMING
#include <gptl.h>
#endif

/* The name of this program. */
#define TEST_NAME "darray_no_async"

/* The number of possible output netCDF output flavors available to
 * the ParallelIO library. */
#define NUM_NETCDF_FLAVORS 4

/* The number of dimensions in the example data. */
#define NDIM3 3

/* The number of timesteps of data. */
#define NUM_TIMESTEPS 2

/* The length of our sample data in X dimension.*/
#define DIM_LEN_X 8

/* The length of our sample data in Y dimension.*/
#define DIM_LEN_Y 8

/* The name of the variable in the netCDF output file. */
#define VAR_NAME "foo"

/* Return code when netCDF output file does not match
 * expectations. */
#define ERR_BAD 1001

/* The meaning of life, the universe, and everything. */
#define START_DATA_VAL 42

/* Number of tasks this example runs on. */
#define TARGET_NTASKS 16

/* Logging level. */
#define LOG_LEVEL -1

/* Lengths of dimensions. */
int dim_len[NDIM3] = {NC_UNLIMITED, DIM_LEN_X, DIM_LEN_Y};

/* Names of dimensions. */
char dim_name[NDIM3][PIO_MAX_NAME + 1] = {"unlimted", "x", "y"};

/* These are used when writing the decomposition file. */
#define DECOMP_FILENAME "darray_no_async_decomp.nc"
#define DECOMP_TITLE "Example Decomposition from darray_no_async.c"
#define DECOMP_HISTORY "This file is created by the program darray_no_async in the PIO C library"

/* Global err buffer for MPI. When there is an MPI error, this buffer
 * is used to store the error message that is associated with the MPI
 * error. */
char err_buffer[MPI_MAX_ERROR_STRING];

/* This is the length of the most recent MPI error message, stored
 * int the global error string. */
int resultlen;

/* @brief Check the output file.
 *
 *  Use netCDF to check that the output is as expected.
 *
 * @param ntasks The number of processors running the example.
 * @param filename The name of the example file to check.
 *
 * @return 0 if example file is correct, non-zero otherwise. */
int check_file(int iosysid, int ntasks, char *filename, int iotype,
               int elements_per_pe, int my_rank, int ioid)
{

    int ncid;         /* File ID from netCDF. */
    int ndims;        /* Number of dimensions. */
    int nvars;        /* Number of variables. */
    int ngatts;       /* Number of global attributes. */
    int unlimdimid;   /* ID of unlimited dimension. */
    int natts;        /* Number of variable attributes. */
    nc_type xtype;    /* NetCDF data type of this variable. */
    int ret;          /* Return code for function calls. */
    int dimids[NDIM3]; /* Dimension ids for this variable. */
    char var_name[PIO_MAX_NAME];   /* Name of the variable. */
    /* size_t start[NDIM3];           /\* Zero-based index to start read. *\/ */
    /* size_t count[NDIM3];           /\* Number of elements to read. *\/ */
    /* int buffer[DIM_LEN_X];          /\* Buffer to read in data. *\/ */
    /* int expected[DIM_LEN_X];        /\* Data values we expect to find. *\/ */

    /* Open the file. */
    if ((ret = PIOc_openfile_retry(iosysid, &ncid, &iotype, filename, 0, 0, 0)))
        return ret;
    /* printf("opened file %s ncid = %d\n", filename, ncid); */

    /* Check the metadata. */
    if ((ret = PIOc_inq(ncid, &ndims, &nvars, &ngatts, &unlimdimid)))
        return ret;

    /* Check the dimensions. */
    if (ndims != NDIM3 || nvars != 1 || ngatts != 0 || unlimdimid != 0)
        return ERR_BAD;
    for (int d = 0; d < NDIM3; d++)
    {
        char my_dim_name[PIO_MAX_NAME];
        PIO_Offset dimlen;

        if ((ret = PIOc_inq_dim(ncid, d, my_dim_name, &dimlen)))
            return ret;
        if (dimlen != (d ? dim_len[d] : NUM_TIMESTEPS) || strcmp(my_dim_name, dim_name[d]))
            return ERR_BAD;
    }

    /* Check the variable. */
    if ((ret = PIOc_inq_var(ncid, 0, var_name, &xtype, &ndims, dimids, &natts)))
        return ret;
    if (xtype != NC_INT || ndims != NDIM3 || dimids[0] != 0 || dimids[1] != 1 ||
        dimids[2] != 2 || natts != 0)
        return ERR_BAD;

    /* Allocate storage for sample data. */
    int buffer[elements_per_pe];
    int buffer_in[elements_per_pe];

    /* Check each timestep. */
    for (int t = 0; t < NUM_TIMESTEPS; t++)
    {
        int varid = 0; /* There's only one var in sample file. */

        /* This is the data we expect for this timestep. */
        for (int i = 0; i < elements_per_pe; i++)
            buffer[i] = 100 * t + START_DATA_VAL + my_rank;

        /* Read one record. */
        if ((ret = PIOc_setframe(ncid, varid, t)))
            ERR(ret);
        if ((ret = PIOc_read_darray(ncid, varid, ioid, elements_per_pe, buffer_in)))
            return ret;

        /* Check the results. */
        for (int i = 0; i < elements_per_pe; i++)
            if (buffer_in[i] != buffer[i])
                return ERR_BAD;
    }

    /* Close the file. */
    if ((ret = PIOc_closefile(ncid)))
        return ret;

    /* Everything looks good! */
    return 0;
}

/* Write, then read, a simple example with darrays.

   The sample file created by this program is a small netCDF file. It
   has the following contents (as shown by ncdump):

   <pre>
netcdf darray_no_async_iotype_1 {
dimensions:
	unlimted = UNLIMITED ; // (2 currently)
	x = 8 ;
	y = 8 ;
variables:
	int foo(unlimted, x, y) ;
data:

 foo =
  42, 42, 42, 42, 43, 43, 43, 43,
  44, 44, 44, 44, 45, 45, 45, 45,
  46, 46, 46, 46, 47, 47, 47, 47,
  48, 48, 48, 48, 49, 49, 49, 49,
  50, 50, 50, 50, 51, 51, 51, 51,
  52, 52, 52, 52, 53, 53, 53, 53,
  54, 54, 54, 54, 55, 55, 55, 55,
  56, 56, 56, 56, 57, 57, 57, 57,
  142, 142, 142, 142, 143, 143, 143, 143,
  144, 144, 144, 144, 145, 145, 145, 145,
  146, 146, 146, 146, 147, 147, 147, 147,
  148, 148, 148, 148, 149, 149, 149, 149,
  150, 150, 150, 150, 151, 151, 151, 151,
  152, 152, 152, 152, 153, 153, 153, 153,
  154, 154, 154, 154, 155, 155, 155, 155,
  156, 156, 156, 156, 157, 157, 157, 157 ;
}
   </pre>

*/
int main(int argc, char* argv[])
{
    int my_rank;  /* Zero-based rank of processor. */
    int ntasks;   /* Number of processors involved in current execution. */
    int ioproc_stride = 1;	    /* Stride in the mpi rank between io tasks. */
    int ioproc_start = 0; 	    /* Rank of first task to be used for I/O. */
    PIO_Offset elements_per_pe; /* Array elements per processing unit. */
    int iosysid;  /* The ID for the parallel I/O system. */
    int ncid;     /* The ncid of the netCDF file. */
    int dimid[NDIM3];    /* The dimension ID. */
    int varid;    /* The ID of the netCDF varable. */
    int ioid;     /* The I/O description ID. */
    char filename[PIO_MAX_NAME + 1]; /* Test filename. */
    int num_flavors = 0;            /* Number of iotypes available in this build. */
    int format[NUM_NETCDF_FLAVORS]; /* Different output flavors. */
    int ret;                        /* Return value. */

#ifdef TIMING
    /* Initialize the GPTL timing library. */
    if ((ret = GPTLinitialize ()))
        return ret;
#endif

    /* Initialize MPI. */
    if ((ret = MPI_Init(&argc, &argv)))
        MPIERR(ret);
    if ((ret = MPI_Comm_set_errhandler(MPI_COMM_WORLD, MPI_ERRORS_RETURN)))
        MPIERR(ret);

    /* Learn my rank and the total number of processors. */
    if ((ret = MPI_Comm_rank(MPI_COMM_WORLD, &my_rank)))
        MPIERR(ret);
    if ((ret = MPI_Comm_size(MPI_COMM_WORLD, &ntasks)))
        MPIERR(ret);

#ifdef USE_MPE
    /* If MPE logging is being used, then initialize it. */
    if ((ret = MPE_Init_log()))
        return ret;
#endif /* USE_MPE */

    /* Check that a valid number of processors was specified. */
    if (ntasks != TARGET_NTASKS)
        fprintf(stderr, "Number of processors must be 16!\n");
    /* printf("%d: ParallelIO Library darray_no_async example running on %d processors.\n", */
    /*        my_rank, ntasks); */

    /* Turn on logging. */
    if ((ret = PIOc_set_log_level(LOG_LEVEL)))
        return ret;

    /* /\* Change error handling so we can test inval parameters. *\/ */
    /* if ((ret = PIOc_set_iosystem_error_handling(PIO_DEFAULT, PIO_RETURN_ERROR, NULL))) */
    /*     return ret; */

    /* Initialize the PIO IO system. This specifies how many and
     * which processors are involved in I/O. */
    if ((ret = PIOc_Init_Intracomm(MPI_COMM_WORLD, 4, ioproc_stride,
                                   ioproc_start, PIO_REARR_BOX, &iosysid)))
        ERR(ret);

    /* Describe the decomposition. */
    elements_per_pe = DIM_LEN_X * DIM_LEN_Y / TARGET_NTASKS;

    /* Allocate and initialize array of decomposition mapping. */
    PIO_Offset compdof[elements_per_pe];
    for (int i = 0; i < elements_per_pe; i++)
        compdof[i] = my_rank * elements_per_pe + i;

    /* Create the PIO decomposition for this example. Since this
     * is a variable with an unlimited dimension, we want to
     * create a 2-D composition which represents one record. */
    /* printf("rank: %d Creating decomposition, elements_per_pe %lld...\n", my_rank, */
    /*        elements_per_pe); */
    if ((ret = PIOc_init_decomp(iosysid, PIO_INT, NDIM3 - 1, &dim_len[1], elements_per_pe,
                                compdof, &ioid, PIO_REARR_SUBSET, NULL, NULL)))
        ERR(ret);

    /* Write the decomposition file. */
    if ((ret = PIOc_write_nc_decomp(iosysid, DECOMP_FILENAME, NC_CLOBBER,
                                    ioid, DECOMP_TITLE, DECOMP_HISTORY, 0)))
        ERR(ret);

    /* The number of favors may change with the build parameters. */
#ifdef _PNETCDF
    format[num_flavors++] = PIO_IOTYPE_PNETCDF;
#endif
    format[num_flavors++] = PIO_IOTYPE_NETCDF;
#ifdef _NETCDF4
    format[num_flavors++] = PIO_IOTYPE_NETCDF4C;
    format[num_flavors++] = PIO_IOTYPE_NETCDF4P;
#endif

    /* Use PIO to create the example file in each of the four
     * available ways. */
    for (int fmt = 0; fmt < num_flavors; fmt++)
    {
        /* Create a filename. */
        sprintf(filename, "darray_no_async_iotype_%d.nc", format[fmt]);

        /* Create the netCDF output file. */
        /* printf("rank: %d Creating sample file %s with format %d...\n", */
        /*        my_rank, filename, format[fmt]); */
        if ((ret = PIOc_createfile(iosysid, &ncid, &(format[fmt]), filename, PIO_CLOBBER)))
            ERR(ret);

        /* Define netCDF dimension and variable. */
        /* printf("rank: %d Defining netCDF metadata...\n", my_rank); */
        for (int d = 0; d < NDIM3; d++)
            if ((ret = PIOc_def_dim(ncid, dim_name[d], dim_len[d], &dimid[d])))
                ERR(ret);
        if ((ret = PIOc_def_var(ncid, VAR_NAME, PIO_INT, NDIM3, dimid, &varid)))
            ERR(ret);
        if ((ret = PIOc_enddef(ncid)))
            ERR(ret);

        /* Allocate storage for sample data. */
        int buffer[elements_per_pe];

        /* Write each timestep. */
        for (int t = 0; t < NUM_TIMESTEPS; t++)
        {
            /* Create some data for this timestep. */
            for (int i = 0; i < elements_per_pe; i++)
                buffer[i] = 100 * t + START_DATA_VAL + my_rank;

            /* Write data to the file. */
            /* printf("rank: %d Writing sample data...\n", my_rank); */
            if ((ret = PIOc_setframe(ncid, varid, t)))
                ERR(ret);
            if ((ret = PIOc_write_darray(ncid, varid, ioid, elements_per_pe, buffer, NULL)))
                ERR(ret);
        }

        /* THis will cause all data to be written to disk. */
        if ((ret = PIOc_sync(ncid)))
            ERR(ret);

        /* Close the netCDF file. */
        /* printf("rank: %d Closing the sample data file...\n", my_rank); */
        if ((ret = PIOc_closefile(ncid)))
            ERR(ret);

        /* Check the output file. */
        /* if ((ret = check_file(iosysid, ntasks, filename, format[fmt], elements_per_pe, */
        /*                       my_rank, ioid))) */
        /*     ERR(ret); */
    }

    /* Free the PIO decomposition. */
    /* printf("rank: %d Freeing PIO decomposition...\n", my_rank); */
    if ((ret = PIOc_freedecomp(iosysid, ioid)))
        ERR(ret);

    /* Finalize the IO system. */
    /* printf("rank: %d Freeing PIO resources...\n", my_rank); */
    if ((ret = PIOc_free_iosystem(iosysid)))
        ERR(ret);

    /* Finalize the MPI library. */
    MPI_Finalize();

#ifdef TIMING
    /* Finalize the GPTL timing library. */
    if ((ret = GPTLfinalize ()))
        return ret;
#endif

    if (!my_rank)
        printf("rank: %d SUCCESS!\n", my_rank);
    return 0;
}
