/**
 * @file
 * Tests for handling of fillval.
 *
 * This test was added to track down memory leaks in
 * pio_decomp_fillval. Since that code is large, complex, and in
 * fortran, I have reproduced the error-inducing calls in a simple C
 * test.
 *
 */
#include <pio.h>
#ifdef TIMING
#include <gptl.h>
#endif

/** The number of possible output netCDF output flavors available to
 * the ParallelIO library. */
#define NUM_NETCDF_FLAVORS 4

/** The number of dimensions in the example data. In this example, we
 * are using three-dimensional data. */
#define NDIM 3

/** The length of our sample data along each dimension. There will be
 * a total of 16 integers in each timestep of our data, and
 * responsibilty for writing and reading them will be spread between
 * all the processors used to run this example. */
/**@{*/
#define X_DIM_LEN 400
#define Y_DIM_LEN 400
/**@}*/

/** The number of timesteps of data to write. */
#define NUM_TIMESTEPS 6

/** The name of the variable in the netCDF output file. */
#define VAR_NAME "foo"

/** The meaning of life, the universe, and everything. */
#define START_DATA_VAL 42

/** Handle MPI errors. This should only be used with MPI library
 * function calls. */
#define MPIERR(e) do {                                                  \
	MPI_Error_string(e, err_buffer, &resultlen);                    \
	fprintf(stderr, "MPI error, line %d, file %s: %s\n", __LINE__, __FILE__, err_buffer); \
	MPI_Finalize();                                                 \
	return 2;                                                       \
    } while (0)

/** Handle non-MPI errors by finalizing the MPI library and exiting
 * with an exit code. */
#define ERR(e) do {                             \
	fprintf(stderr, "Error %d in %s, line %d\n", e, __FILE__, __LINE__); \
	MPI_Finalize();                         \
	return e;                               \
    } while (0)

/** Global err buffer for MPI. When there is an MPI error, this buffer
 * is used to store the error message that is associated with the MPI
 * error. */
char err_buffer[MPI_MAX_ERROR_STRING];

/** This is the length of the most recent MPI error message, stored
 * int the global error string. */
int resultlen;

/** The dimension names. */
char dim_name[NDIM][PIO_MAX_NAME + 1] = {"timestep", "x", "y"};

/** Length of the dimensions in the sample data. */
int dim_len[NDIM] = {NC_UNLIMITED, X_DIM_LEN, Y_DIM_LEN};

/** Length of chunksizes to use in netCDF-4 files. */
size_t chunksize[NDIM] = {2, X_DIM_LEN/2, Y_DIM_LEN/2};

/** Error code for when things go wrong. */
#define ERR_AWFUL 1111

/** Run Tests for NetCDF-4 Functions.
 *
 * @param argc argument count
 * @param argv array of arguments
 */
int
main(int argc, char **argv)
{
    int verbose = 1;

    /** Zero-based rank of processor. */
    int my_rank;

    /** Number of processors involved in current execution. */
    int ntasks;

    /** Different output flavors. The example file is written (and
     * then read) four times. The first two flavors,
     * parallel-netcdf, and netCDF serial, both produce a netCDF
     * classic format file (but with different libraries). The
     * last two produce netCDF4/HDF5 format files, written with
     * and without using netCDF-4 parallel I/O. */
    int format[NUM_NETCDF_FLAVORS] = {PIO_IOTYPE_PNETCDF,
				      PIO_IOTYPE_NETCDF,
				      PIO_IOTYPE_NETCDF4C,
				      PIO_IOTYPE_NETCDF4P};

    /** Names for the output files. Two of them (pnetcdf and
     * classic) will be in classic netCDF format, the others
     * (serial4 and parallel4) will be in netCDF-4/HDF5
     * format. All four can be read by the netCDF library, and all
     * will contain the same contents. */
    char filename[NUM_NETCDF_FLAVORS][PIO_MAX_NAME + 1] = {"test_nc4_pnetcdf.nc",
                                                           "test_nc4_classic.nc",
                                                           "test_nc4_serial4.nc",
                                                           "test_nc4_parallel4.nc"};

    /** Number of processors that will do IO. In this example we
     * will do IO from all processors. */
    int niotasks;

    /** Stride in the mpi rank between io tasks. Always 1 in this
     * example. */
    int ioproc_stride = 1;

    /** Zero based rank of first processor to be used for I/O. */
    int ioproc_start = 0;

    /** Specifies the flavor of netCDF output format. */
    int iotype;

    /** The dimension IDs. */
    int dimids[NDIM];

    /** Array index per processing unit. This is the number of
     * elements of the data array that will be handled by each
     * processor. In this example there are 16 data elements. If the
     * example is run on 4 processors, then arrIdxPerPe will be 4. */
    PIO_Offset elements_per_pe;

    /** The ID for the parallel I/O system. It is set by
     * PIOc_Init_Intracomm(). It references an internal structure
     * containing the general IO subsystem data and MPI
     * structure. It is passed to PIOc_finalize() to free
     * associated resources, after all I/O, but before
     * MPI_Finalize is called. */
    int iosysid;

    /** The ncid of the netCDF file created in this example. */
    int ncid = 0;

    /** The ID of the netCDF varable in the example file. */
    int varid;

    /** The I/O description ID as passed back by PIOc_InitDecomp()
     * and freed in PIOc_freedecomp(). */
    int ioid;

    /** A buffer for sample data.  The size of this array will
     * vary depending on how many processors are involved in the
     * execution of the example code. It's length will be the same
     * as elements_per_pe.*/
    float *buffer;

    /** A buffer for reading data back from the file. The size of
     * this array will vary depending on how many processors are
     * involved in the execution of the example code. It's length
     * will be the same as elements_per_pe.*/
    int *read_buffer;

    /** A 1-D array which holds the decomposition mapping for this
     * example. The size of this array will vary depending on how
     * many processors are involved in the execution of the
     * example code. It's length will be the same as
     * elements_per_pe. */
    PIO_Offset *compdof;

    /** Return code. */
    int ret;

#ifdef TIMING
    /* Initialize the GPTL timing library. */
    if ((ret = GPTLinitialize ()))
	return ret;
#endif

    /* Initialize MPI. */
    if ((ret = MPI_Init(&argc, &argv)))
	MPIERR(ret);
    if ((ret = MPI_Errhandler_set(MPI_COMM_WORLD, MPI_ERRORS_RETURN)))
	MPIERR(ret);

    /* Learn my rank and the total number of processors. */
    if ((ret = MPI_Comm_rank(MPI_COMM_WORLD, &my_rank)))
	MPIERR(ret);
    if ((ret = MPI_Comm_size(MPI_COMM_WORLD, &ntasks)))
	MPIERR(ret);

    /* Check that a valid number of processors was specified. */
    if (!(ntasks == 1 || ntasks == 2 || ntasks == 4 ||
	  ntasks == 8 || ntasks == 16))
	fprintf(stderr, "Number of processors must be 1, 2, 4, 8, or 16!\n");
    if (verbose)
	printf("%d: ParallelIO Library example1 running on %d processors.\n",
	       my_rank, ntasks);

    /* keep things simple - 1 iotask per MPI process */
    niotasks = ntasks;

    /* Initialize the PIO IO system. This specifies how
     * many and which processors are involved in I/O. */
    if ((ret = PIOc_Init_Intracomm(MPI_COMM_WORLD, niotasks, ioproc_stride,
				   ioproc_start, PIO_REARR_SUBSET, &iosysid)))
	ERR(ret);

    /* Describe the decomposition. This is a 1-based array, so add 1! */
    elements_per_pe = X_DIM_LEN * Y_DIM_LEN / ntasks;
    if (!(compdof = malloc(elements_per_pe * sizeof(PIO_Offset))))
	return PIO_ENOMEM;
    for (int i = 0; i < elements_per_pe; i++) {
	compdof[i] = my_rank * elements_per_pe + i + 1;
    }

    /* Create the PIO decomposition for this test. */
    if (verbose)
	printf("rank: %d Creating decomposition...\n", my_rank);
    if ((ret = PIOc_InitDecomp(iosysid, PIO_FLOAT, 2, &dim_len[1], (PIO_Offset)elements_per_pe,
			       compdof, &ioid, NULL, NULL, NULL)))
	ERR(ret);
    free(compdof);

#ifdef HAVE_MPE
    /* Log with MPE that we are done with INIT. */
    if ((ret = MPE_Log_event(event_num[END][INIT], 0, "end init")))
	MPIERR(ret);
#endif /* HAVE_MPE */

    /* Use PIO to create the example file in each of the four
     * available ways. */
    for (int fmt = 0; fmt < NUM_NETCDF_FLAVORS; fmt++)
    {
#ifdef HAVE_MPE
	/* Log with MPE that we are starting CREATE. */
	if ((ret = MPE_Log_event(event_num[START][CREATE_PNETCDF+fmt], 0, "start create")))
	    MPIERR(ret);
#endif /* HAVE_MPE */

	/* Create the netCDF output file. */
	if (verbose)
	    printf("rank: %d Creating sample file %s with format %d...\n",
		   my_rank, filename[fmt], format[fmt]);
	if ((ret = PIOc_createfile(iosysid, &ncid, &(format[fmt]), filename[fmt],
				   PIO_CLOBBER)))
	    ERR(ret);

	/* Define netCDF dimensions and variable. */
	if (verbose)
	    printf("rank: %d Defining netCDF metadata...\n", my_rank);
	for (int d = 0; d < NDIM; d++) {
	    if (verbose)
		printf("rank: %d Defining netCDF dimension %s, length %d\n", my_rank,
		       dim_name[d], dim_len[d]);
	    if ((ret = PIOc_def_dim(ncid, dim_name[d], (PIO_Offset)dim_len[d], &dimids[d])))
		ERR(ret);
	}
	if ((ret = PIOc_def_var(ncid, VAR_NAME, PIO_FLOAT, NDIM, dimids, &varid)))
	    ERR(ret);

	/* For netCDF-4 files, set the chunksize to improve performance. */
	if (format[fmt] == PIO_IOTYPE_NETCDF4C || format[fmt] == PIO_IOTYPE_NETCDF4P)
	{
	    if ((ret = PIOc_def_var_chunking(ncid, 0, NC_CHUNKED, chunksize)))
		ERR(ret);

	    /** Check that the inq_var_chunking function works. */
	    int storage;
	    size_t my_chunksize[NDIM];
	    if ((ret = PIOc_inq_var_chunking(ncid, 0, &storage, my_chunksize)))
		ERR(ret);

	    /** For serial netCDF-4, only processor rank 0 gets the answers. */
	    if (format[fmt] == PIO_IOTYPE_NETCDF4C && !my_rank ||
		format[fmt] == PIO_IOTYPE_NETCDF4P)
	    {
		if (storage != NC_CHUNKED)
		    ERR(ERR_AWFUL);
		for (int d = 0; d < NDIM; d++)
		    if (my_chunksize[d] != chunksize[d])
			ERR(ERR_AWFUL);
	    }

	    /* Check that the inv_var_deflate functions works. */
	    int shuffle;
	    int deflate;
	    int deflate_level;
	    if ((ret = PIOc_inq_var_deflate(ncid, 0, &shuffle, &deflate, &deflate_level)))
		ERR(ret);

	    /** For serial netCDF-4, only processor rank 0 gets the
	     * answers. Also deflate is turned on by default */
	    if (format[fmt] == PIO_IOTYPE_NETCDF4C && !my_rank)
		if (shuffle || !deflate || deflate_level != 1)
		    ERR(ERR_AWFUL);

	    /* For parallel netCDF, no compression available. :-( */
	    if (format[fmt] == PIO_IOTYPE_NETCDF4P)
		if (shuffle || deflate)
		    ERR(ERR_AWFUL);

	} else {
	    /* Trying to set chunking for non-netCDF-4 files results
	     * in the PIO_ENOTNC4 error. */
	    if ((ret = PIOc_def_var_chunking(ncid, 0, NC_CHUNKED, chunksize)) != PIO_ENOTNC4)
		ERR(ERR_AWFUL);
	}

	if ((ret = PIOc_enddef(ncid)))
	    ERR(ret);

	/* Close the netCDF file. */
	if (verbose)
	    printf("rank: %d Closing the sample data file...\n", my_rank);
	if ((ret = PIOc_closefile(ncid)))
	    ERR(ret);
    }

    /* Free the PIO decomposition. */
    if (verbose)
	printf("rank: %d Freeing PIO decomposition...\n", my_rank);
    if ((ret = PIOc_freedecomp(iosysid, ioid)))
	ERR(ret);

    /* Finalize the IO system. */
    if (verbose)
	printf("rank: %d Freeing PIO resources...\n", my_rank);
    if ((ret = PIOc_finalize(iosysid)))
	ERR(ret);

    /* Finalize the MPI library. */
    MPI_Finalize();

#ifdef TIMING
    /* Finalize the GPTL timing library. */
    if ((ret = GPTLfinalize ()))
	return ret;
#endif

    return 0;
}
