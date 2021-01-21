/**
 * @file 
 * A simple C example for the ParallelIO Library.
 *
 * This example creates a netCDF output file with one 3D variable. One
 * of the dimensions will be unlimited.  The example first writes the
 * sample file using the ParallelIO library, then reads it with the
 * plain old netCDF library to check that it is correct.
 *
 * This example can be run in parallel for 1, 2, 4, 8, or 16
 * processors.
 *
 * This example uses the MPE performace profiling library, if it is
 * present on the build machine. After the program is run, MPE will
 * produce a file called example2.clog2. In order to see the nice
 * graphs, execute the commands: 
 *
 * <pre>
 * clog2ToSlog2 example2.clog2
 * jumpshot example2.slog2 
 * </pre>
 */

#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <mpi.h>
#include <pio.h>
#include <math.h>
#ifdef TIMING
#include <gptl.h>
#endif
#ifdef HAVE_MPE
#include <mpe.h>
#endif

/** The number of possible output netCDF output flavors available to
 * the ParallelIO library. */
#define NUM_NETCDF_FLAVORS 4

/** The number of dimensions in the example data. In this example, we
 * are using three-dimensional data. */
#define NDIM 3

/** Length along x dimension. */
#define X_DIM_LEN 20

/** Length along y dimension. */
#define Y_DIM_LEN 30

/** The number of timesteps of data to write. */
#define NUM_TIMESTEPS 6

/** The name of the variable in the netCDF output file. */
#define VAR_NAME "foo"

/** Return code when netCDF output file does not match
 * expectations. */
#define ERR_BAD 1001

/** The meaning of life, the universe, and everything. */
#define START_DATA_VAL 42

/** Handle MPI errors. This should only be used with MPI library
 * function calls. */
#define MPIERR(e) do {                                                  \
	MPI_Error_string(e, err_buffer, &resultlen);			\
	fprintf(stderr, "MPI error, line %d, file %s: %s\n", __LINE__, __FILE__, err_buffer); \
	MPI_Finalize();							\
	return 2;							\
    } while (0) 

/** Handle non-MPI errors by finalizing the MPI library and exiting
 * with an exit code. */
#define ERR(e) do {				\
        fprintf(stderr, "Error %d in %s, line %d\n", e, __FILE__, __LINE__); \
	MPI_Finalize();				\
	return e;				\
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
PIO_Offset chunksize[NDIM] = {2, X_DIM_LEN/2, Y_DIM_LEN/2};

/** Number of MPE events. The start and stop of each event will be
 * tracked, and graphed. This value is used outside of HAVE_MPE ifdefs.*/
#define NUM_EVENTS 10

#ifdef HAVE_MPE
/** Start and end for each MPE event. */
/**@{*/
#define START 0
#define END 1
/**@}*/

/** These are for the event numbers array used to log various events
 * in the program with the MPE library, which produces output for the
 * Jumpshot program. */
/**@{*/
#define INIT 0
#define CREATE_PNETCDF 1
#define CREATE_CLASSIC 2
#define CREATE_SERIAL4 3
#define CREATE_PARALLEL4 4
#define CALCULATE 5
#define WRITE 6
#define CLOSE 7
#define FREE 8
#define READ 9
/**@}*/
#endif /* HAVE_MPE */

/** File error. */
#define ERR_FILE 1
/** File error. */
#define ERR_DUMB 2
/** Argument error. */
#define ERR_ARG 3
/** MPI error. */
#define ERR_MPI 4
/** MPI Type error. */
#define ERR_MPITYPE 5
/** Logging error. */
#define ERR_LOGGING 6
/** Update error. */
#define ERR_UPDATE 7
/** Calculation error. */
#define ERR_CALC 8
/** Count error. */
#define ERR_COUNT 9
/** Write error. */
#define ERR_WRITE 10
/** Swap error. */
#define ERR_SWAP 11
/** Init error. */
#define ERR_INIT 12

/** This will set up the MPE logging event numbers. 
 *
 * @param my_rank the rank of the processor running the code.
 * @param event_num array of MPE event numbers. 
 *
 * @return 0 for success, non-zero for failure.
 */
int
init_logging(int my_rank, int event_num[][NUM_EVENTS])
{
#ifdef HAVE_MPE
/* Get a bunch of event numbers. */
    event_num[START][INIT] = MPE_Log_get_event_number();
    event_num[END][INIT] = MPE_Log_get_event_number();
    event_num[START][CREATE_PNETCDF] = MPE_Log_get_event_number();
    event_num[END][CREATE_PNETCDF] = MPE_Log_get_event_number();
    event_num[START][CREATE_CLASSIC] = MPE_Log_get_event_number();
    event_num[END][CREATE_CLASSIC] = MPE_Log_get_event_number();
    event_num[START][CREATE_SERIAL4] = MPE_Log_get_event_number();
    event_num[END][CREATE_SERIAL4] = MPE_Log_get_event_number();
    event_num[START][CREATE_PARALLEL4] = MPE_Log_get_event_number();
    event_num[END][CREATE_PARALLEL4] = MPE_Log_get_event_number();
    event_num[START][CALCULATE] = MPE_Log_get_event_number();
    event_num[END][CALCULATE] = MPE_Log_get_event_number();
    event_num[START][WRITE] = MPE_Log_get_event_number();
    event_num[END][WRITE] = MPE_Log_get_event_number();
    event_num[START][CLOSE] = MPE_Log_get_event_number();
    event_num[END][CLOSE] = MPE_Log_get_event_number();
    event_num[START][FREE] = MPE_Log_get_event_number();
    event_num[END][FREE] = MPE_Log_get_event_number();
    event_num[START][READ] = MPE_Log_get_event_number();
    event_num[END][READ] = MPE_Log_get_event_number();

/* You should track at least initialization and partitioning, data
 * ingest, update computation, all communications, any memory
 * copies (if you do that), any output rendering, and any global
 * communications. */
    if (!my_rank)
    {
	MPE_Describe_state(event_num[START][INIT], event_num[END][INIT],
			   "init", "yellow");
	MPE_Describe_state(event_num[START][CREATE_PNETCDF], event_num[END][CREATE_PNETCDF],
			   "create pnetcdf", "red");
	MPE_Describe_state(event_num[START][CREATE_CLASSIC], event_num[END][CREATE_CLASSIC],
			   "create classic", "red");
	MPE_Describe_state(event_num[START][CREATE_SERIAL4], event_num[END][CREATE_SERIAL4],
			   "create netcdf-4 serial", "red");
	MPE_Describe_state(event_num[START][CREATE_PARALLEL4], event_num[END][CREATE_PARALLEL4],
			   "create netcdf-4 parallel", "red");
	MPE_Describe_state(event_num[START][CALCULATE], event_num[END][CALCULATE],
			   "calculate", "orange");
	MPE_Describe_state(event_num[START][WRITE], event_num[END][WRITE],
			   "write", "green");
	MPE_Describe_state(event_num[START][CLOSE], event_num[END][CLOSE],
			   "close", "purple");
	MPE_Describe_state(event_num[START][FREE], event_num[END][FREE],
			   "free", "blue");
	MPE_Describe_state(event_num[START][READ], event_num[END][READ],
			   "read", "pink");
    }
#endif /* HAVE_MPE */
    return 0;
}

/** Check the output file.
 *
 *  Use netCDF to check that the output is as expected. 
 *
 * @param ntasks The number of processors running the example. 
 * @param filename The name of the example file to check. 
 *
 * @return 0 if example file is correct, non-zero otherwise. */
int check_file(int ntasks, char *filename) {
    
    int ncid;         /**< File ID from netCDF. */
    int ndims;        /**< Number of dimensions. */
    int nvars;        /**< Number of variables. */
    int ngatts;       /**< Number of global attributes. */
    int unlimdimid;   /**< ID of unlimited dimension. */
    size_t dimlen;    /**< Length of the dimension. */
    int natts;        /**< Number of variable attributes. */
    nc_type xtype;    /**< NetCDF data type of this variable. */
    int ret;          /**< Return code for function calls. */
    int dimids[NDIM]; /**< Dimension ids for this variable. */
    char my_dim_name[PIO_MAX_NAME + 1]; /**< Name of the dimension. */
    char var_name[PIO_MAX_NAME + 1];    /**< Name of the variable. */
    size_t start[NDIM];                /**< Zero-based index to start read. */
    size_t count[NDIM];                /**< Number of elements to read. */
    int buffer[X_DIM_LEN];             /**< Buffer to read in data. */
    int expected[X_DIM_LEN];           /**< Data values we expect to find. */
    
/* Open the file. */
    if ((ret = nc_open(filename, 0, &ncid)))
	return ret;

/* Check the metadata. */
    if ((ret = nc_inq(ncid, &ndims, &nvars, &ngatts, &unlimdimid)))
	return ret;
    if (ndims != NDIM || nvars != 1 || ngatts != 0 || unlimdimid != -1)
	return ERR_BAD;
    for (int d = 0; d < ndims; d++)
    {
	if ((ret = nc_inq_dim(ncid, d, my_dim_name, &dimlen)))
	    return ret;
	if (dimlen != X_DIM_LEN || strcmp(my_dim_name, dim_name[d]))
	    return ERR_BAD;
    }
    if ((ret = nc_inq_var(ncid, 0, var_name, &xtype, &ndims, dimids, &natts)))
	return ret;
    if (xtype != NC_FLOAT || ndims != NDIM || dimids[0] != 0 || natts != 0)
	return ERR_BAD;

/* Use the number of processors to figure out what the data in the
 * file should look like. */
    int div = X_DIM_LEN * Y_DIM_LEN / ntasks;
    for (int d = 0; d < X_DIM_LEN; d++)
	expected[d] = START_DATA_VAL + d/div;
    
/* Check the data. */
    start[0] = 0;
    count[0] = X_DIM_LEN;
    if ((ret = nc_get_vara(ncid, 0, start, count, buffer)))
	return ret;
    for (int d = 0; d < X_DIM_LEN; d++)
	if (buffer[d] != expected[d])
	    return ERR_BAD;

/* Close the file. */
    if ((ret = nc_close(ncid)))
	return ret;

/* Everything looks good! */
    return 0;
}

/** Calculate sample data. This function is deliberately slow in order to take up some time calculating. 
 * @param my_rank the rank of the processor running the code.
 * @param timestep the timestep.
 * @param datap pointer where we should write datum.
 * 
 * @return zero for success, non-zero otherwise.
 */
int calculate_value(int my_rank, int timestep, float *datap)
{
    *datap = my_rank + timestep;
    for (int i = 0; i < 50; i++)
	*datap += atan(cos(my_rank * timestep));
    return 0;
}

/** Main execution of code.

    Executes the functions to:
    - create a new examplePioClass instance
    - initialize MPI and the ParallelIO libraries
    - create the decomposition for this example
    - create the netCDF output file
    - define the variable in the file
    - write data to the variable in the file using decomposition
    - read the data back from the file using decomposition
    - close the file
    - clean up resources

    The example can be run from the command line (on system that support it) like this:
    <pre>
    mpiexec -n 4 ./examplePio
    </pre>

    The sample file created by this program is a small netCDF file. It
    has the following contents (as shown by ncdump) for a 4-processor
    run:

    <pre>
    netcdf examplePio_c {
    dimensions:
    x = 16 ;
    variables:
    int foo(x) ;
    data:

    foo = 42, 42, 42, 42, 43, 43, 43, 43, 44, 44, 44, 44, 45, 45, 45, 45 ;
    }
    </pre>
    
    @param [in] argc argument count (should be zero)
    @param [in] argv argument array (should be NULL)
    @retval examplePioClass* Pointer to self.
*/
int main(int argc, char* argv[])
{
    /** Set to non-zero to get output to stdout. */
    int verbose = 0;

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
    char filename[NUM_NETCDF_FLAVORS][PIO_MAX_NAME + 1] = {"example2_pnetcdf.nc",
							  "example2_classic.nc",
							  "example2_serial4.nc",
							  "example2_parallel4.nc"};
	
    /** Number of processors that will do IO. In this example we
     * will do IO from all processors. */
    int niotasks;

    /** Stride in the mpi rank between io tasks. Always 1 in this
     * example. */
    int ioproc_stride = 1;

    /** Number of the aggregator? Always 0 in this example. */
    int numAggregator = 0;

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

#ifdef HAVE_MPE	
    /** MPE event numbers used to track start and stop of
     * different parts of the program for later display with
     * Jumpshot. */
    int event_num[2][NUM_EVENTS];
#endif /* HAVE_MPE */

    /** Needed for command line processing. */
    int c;

    int ret;

    /* Parse command line. */
    while ((c = getopt(argc, argv, "v")) != -1)
	switch (c)
	{
	case 'v':
	    verbose++;
	    break;
	default:
	    break;
	}

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

#ifdef HAVE_MPE
    /* Initialize MPE logging. */
    if ((ret = MPE_Init_log()))
	ERR(ret);
    if (init_logging(my_rank, event_num))
	ERR(ERR_LOGGING);

    /* Log with MPE that we are starting INIT. */
    if ((ret = MPE_Log_event(event_num[START][INIT], 0, "start init")))
	MPIERR(ret);
#endif /* HAVE_MPE */

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
	
    /* Create the PIO decomposition for this example. */
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
	    if ((ret = PIOc_def_var_chunking(ncid, 0, NC_CHUNKED, chunksize)))
		ERR(ret);
	
	if ((ret = PIOc_enddef(ncid)))
	    ERR(ret);

#ifdef HAVE_MPE
	/* Log with MPE that we are done with CREATE. */
	if ((ret = MPE_Log_event(event_num[END][CREATE_PNETCDF + fmt], 0, "end create")))
	    MPIERR(ret);
#endif /* HAVE_MPE */

	/* Allocate space for sample data. */
	if (!(buffer = malloc(elements_per_pe * sizeof(float))))
	    return PIO_ENOMEM;

	/* Write data for each timestep. */
	for (int ts = 0; ts < NUM_TIMESTEPS; ts++) {

#ifdef HAVE_MPE
	    /* Log with MPE that we are starting CALCULATE. */
	    if ((ret = MPE_Log_event(event_num[START][CALCULATE], 0, "start calculate")))
		MPIERR(ret);
#endif /* HAVE_MPE */

	    /* Calculate sample data. Add some math function calls to make this slower. */
	    for (int i = 0; i < elements_per_pe; i++)
		if ((ret = calculate_value(my_rank, ts, &buffer[i])))
		    ERR(ret);

#ifdef HAVE_MPE
	    /* Log with MPE that we are done with CALCULATE. */
	    if ((ret = MPE_Log_event(event_num[END][CALCULATE], 0, "end calculate")))
		MPIERR(ret);
	    /* Log with MPE that we are starting WRITE. */
	    if ((ret = MPE_Log_event(event_num[START][WRITE], 0, "start write")))
		MPIERR(ret);
#endif /* HAVE_MPE */
		
	    /* Write data to the file. */
	    if (verbose)
		printf("rank: %d Writing sample data...\n", my_rank);

	    if ((ret = PIOc_setframe(ncid, varid, ts)))
		ERR(ret);
	    if ((ret = PIOc_write_darray(ncid, varid, ioid, (PIO_Offset)elements_per_pe,
					 buffer, NULL)))
		ERR(ret);
	    if ((ret = PIOc_sync(ncid)))
		ERR(ret);
#ifdef HAVE_MPE
	    /* Log with MPE that we are done with WRITE. */
	    if ((ret = MPE_Log_event(event_num[END][WRITE], 0, "end write")))
		MPIERR(ret);
#endif /* HAVE_MPE */
	}

#ifdef HAVE_MPE
	/* Log with MPE that we are starting CLOSE. */
	if ((ret = MPE_Log_event(event_num[START][CLOSE], 0, "start close")))
	    MPIERR(ret);
#endif /* HAVE_MPE */
		
	/* Free buffer space used in this example. */
	free(buffer);
	
	/* Close the netCDF file. */
	if (verbose)
	    printf("rank: %d Closing the sample data file...\n", my_rank);
	if ((ret = PIOc_closefile(ncid)))
	    ERR(ret);

#ifdef HAVE_MPE
	/* Log with MPE that we are done with CLOSE. */
	if ((ret = MPE_Log_event(event_num[END][CLOSE], 0, "end close")))
	    MPIERR(ret);
#endif /* HAVE_MPE */

	/* After each file is closed, make all processors wait so that
	 * all start creating the next file at the same time. */
	if ((ret = MPI_Barrier(MPI_COMM_WORLD)))
	    MPIERR(ret);
    }
	
#ifdef HAVE_MPE
    /* Log with MPE that we are starting FREE. */
    if ((ret = MPE_Log_event(event_num[START][FREE], 0, "start free")))
	MPIERR(ret);
#endif /* HAVE_MPE */
    
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

#ifdef HAVE_MPE
    /* Log with MPE that we are done with FREE. */
    if ((ret = MPE_Log_event(event_num[END][FREE], 0, "end free")))
	MPIERR(ret);
    /* Log with MPE that we are starting READ. */
    if ((ret = MPE_Log_event(event_num[START][READ], 0, "start read")))
	MPIERR(ret);
#endif /* HAVE_MPE */
    
    /* Check the output file. */
    /* if (!my_rank) */
    /*     for (int fmt = 0; fmt < NUM_NETCDF_FLAVORS; fmt++)  */
    /* 	if ((ret = check_file(ntasks, filename[fmt]))) */
    /* 	    ERR(ret); */

#ifdef HAVE_MPE
    /* Log with MPE that we are done with READ. */
    if ((ret = MPE_Log_event(event_num[END][READ], 0, "end read")))
	MPIERR(ret);
#endif /* HAVE_MPE */

    /* Finalize the MPI library. */
    MPI_Finalize();

#ifdef TIMING    
    /* Finalize the GPTL timing library. */
    if ((ret = GPTLfinalize ()))
	return ret;
#endif    

    if (verbose)
	printf("rank: %d SUCCESS!\n", my_rank);
    return 0;
}
