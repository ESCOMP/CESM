/**
 * @file 
 * @brief A simple C example for the ParallelIO Library.
 *
 * This example creates a netCDF output file with one dimension and
 * one variable. It first writes, then reads the sample file using the
 * ParallelIO library. 
 *
 * This example can be run in parallel for 1, 2, 4, 8, or 16
 * processors.
 */

#include "config.h"
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <mpi.h>
#include <pio.h>
#ifdef TIMING
#include <gptl.h>
#endif
#ifdef USE_MPE
#include <mpe.h>
#endif /* USE_MPE */

/** The name of this program. */
#define TEST_NAME "example1"

/** The number of possible output netCDF output flavors available to
 * the ParallelIO library. */
#define NUM_NETCDF_FLAVORS 4	

/** The number of dimensions in the example data. In this simple
    example, we are using one-dimensional data. */
#define NDIM 1

/** The length of our sample data. There will be a total of 16
 * integers in our data, and responsibilty for writing and reading
 * them will be spread between all the processors used to run this
 * example. */
#define DIM_LEN 16

/** The name of the dimension in the netCDF output file. */
#define DIM_NAME "x"

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
	printf("MPI error, line %d, file %s: %s\n", __LINE__, __FILE__, err_buffer); \
	MPI_Finalize();							\
	return 2;							\
    } while (0) 

/** Handle non-MPI errors by finalizing the MPI library and exiting
 * with an exit code. */
#define ERR(e) do {				\
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

/** @brief Check the output file.
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
    char dim_name[NC_MAX_NAME];   /**< Name of the dimension. */
    char var_name[NC_MAX_NAME];   /**< Name of the variable. */
    size_t start[NDIM];           /**< Zero-based index to start read. */
    size_t count[NDIM];           /**< Number of elements to read. */
    int buffer[DIM_LEN];          /**< Buffer to read in data. */
    int expected[DIM_LEN];        /**< Data values we expect to find. */
    
    /* Open the file. */
    if ((ret = nc_open(filename, 0, &ncid)))
	return ret;

    /* Check the metadata. */
    if ((ret = nc_inq(ncid, &ndims, &nvars, &ngatts, &unlimdimid)))
	return ret;
    if (ndims != NDIM || nvars != 1 || ngatts != 0 || unlimdimid != -1)
	return ERR_BAD;
    if ((ret = nc_inq_dim(ncid, 0, dim_name, &dimlen)))
	return ret;
    if (dimlen != DIM_LEN || strcmp(dim_name, DIM_NAME))
	return ERR_BAD;
    if ((ret = nc_inq_var(ncid, 0, var_name, &xtype, &ndims, dimids, &natts)))
	return ret;
    if (xtype != NC_INT || ndims != NDIM || dimids[0] != 0 || natts != 0)
	return ERR_BAD;

    /* Use the number of processors to figure out what the data in the
     * file should look like. */
    int div = DIM_LEN/ntasks;
    for (int d = 0; d < DIM_LEN; d++)
	expected[d] = START_DATA_VAL + d/div;
    
    /* Check the data. */
    start[0] = 0;
    count[0] = DIM_LEN;
    if ((ret = nc_get_vara(ncid, 0, start, count, buffer)))
	return ret;
    for (int d = 0; d < DIM_LEN; d++)
	if (buffer[d] != expected[d])
	    return ERR_BAD;

    /* Close the file. */
    if ((ret = nc_close(ncid)))
	return ret;

    /* Everything looks good! */
    return 0;
}

/** @brief Main execution of code.

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
	int format[NUM_NETCDF_FLAVORS];

	/** Number of processors that will do IO. In this example we
	 * will do IO from all processors. */
	int niotasks;

	/** Stride in the mpi rank between io tasks. Always 1 in this
	 * example. */
	int ioproc_stride = 1;

	/** Zero based rank of first processor to be used for I/O. */
	int ioproc_start = 0;

	/** The dimension ID. */
	int dimid;

	/** Array index per processing unit. This is the number of
	 * elements of the data array that will be handled by each
	 * processor. In this example there are 16 data elements. If the
	 * example is run on 4 processors, then arrIdxPerPe will be 4. */
	PIO_Offset elements_per_pe;

	/* Length of the dimensions in the data. This simple example
	 * uses one-dimensional data. The lenght along that dimension
	 * is DIM_LEN (16). */
	int dim_len[1] = {DIM_LEN};

	/** The ID for the parallel I/O system. It is set by
	 * PIOc_Init_Intracomm(). It references an internal structure
	 * containing the general IO subsystem data and MPI
	 * structure. It is passed to PIOc_finalize() to free
	 * associated resources, after all I/O, but before
	 * MPI_Finalize is called. */
	int iosysid;

	/** The ncid of the netCDF file created in this example. */
	int ncid;

	/** The ID of the netCDF varable in the example file. */
	int varid;

	/** The I/O description ID as passed back by PIOc_InitDecomp()
	 * and freed in PIOc_freedecomp(). */
	int ioid;

	/** A buffer for sample data.  The size of this array will
	 * vary depending on how many processors are involved in the
	 * execution of the example code. It's length will be the same
	 * as elements_per_pe.*/
	int *buffer;

	/** A 1-D array which holds the decomposition mapping for this
	 * example. The size of this array will vary depending on how
	 * many processors are involved in the execution of the
	 * example code. It's length will be the same as
	 * elements_per_pe. */
	PIO_Offset *compdof;

        /** Test filename. */
        char filename[NC_MAX_NAME + 1];

        /** The number of netCDF flavors available in this build. */
        int num_flavors = 0;
            
	/** Used for command line processing. */
	int c;

	/** Return value. */
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
	if ((ret = MPI_Comm_set_errhandler(MPI_COMM_WORLD, MPI_ERRORS_RETURN)))
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

#ifdef USE_MPE
        /* If MPE logging is being used, then initialize it. */
        if ((ret = MPE_Init_log()))
            return ret;
#endif /* USE_MPE */

        /* keep things simple - 1 iotask per MPI process */
	niotasks = ntasks;

        /* Turn on logging if available. */
        /* PIOc_set_log_level(4); */

        /* Change error handling to return errors. */
        if ((ret = PIOc_set_iosystem_error_handling(PIO_DEFAULT, PIO_RETURN_ERROR, NULL)))
            return ret;
        
	/* Initialize the PIO IO system. This specifies how
	 * many and which processors are involved in I/O. */
	if ((ret = PIOc_Init_Intracomm(MPI_COMM_WORLD, niotasks, ioproc_stride,
				       ioproc_start, PIO_REARR_SUBSET, &iosysid)))
	    ERR(ret);

	/* Describe the decomposition. This is a 1-based array, so add 1! */
	elements_per_pe = DIM_LEN / ntasks;
	if (!(compdof = malloc(elements_per_pe * sizeof(PIO_Offset))))
	    return PIO_ENOMEM;
	for (int i = 0; i < elements_per_pe; i++)
	    compdof[i] = my_rank * elements_per_pe + i + 1;
	
	/* Create the PIO decomposition for this example. */
	if (verbose)
	    printf("rank: %d Creating decomposition...\n", my_rank);
	if ((ret = PIOc_InitDecomp(iosysid, PIO_INT, NDIM, dim_len, (PIO_Offset)elements_per_pe,
				   compdof, &ioid, NULL, NULL, NULL)))
	    ERR(ret);
	free(compdof);

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
            sprintf(filename, "example1_%d.nc", fmt);
            
	    /* Create the netCDF output file. */
	    if (verbose)
		printf("rank: %d Creating sample file %s with format %d...\n",
		       my_rank, filename, format[fmt]);
	    if ((ret = PIOc_createfile(iosysid, &ncid, &(format[fmt]), filename,
				       PIO_CLOBBER)))
		ERR(ret);
	
	    /* Define netCDF dimension and variable. */
	    if (verbose)
		printf("rank: %d Defining netCDF metadata...\n", my_rank);
	    if ((ret = PIOc_def_dim(ncid, DIM_NAME, (PIO_Offset)dim_len[0], &dimid)))
		ERR(ret);
	    if ((ret = PIOc_def_var(ncid, VAR_NAME, PIO_INT, NDIM, &dimid, &varid)))
		ERR(ret);
	    if ((ret = PIOc_enddef(ncid)))
		ERR(ret);
	
	    /* Prepare sample data. */
	    if (!(buffer = malloc(elements_per_pe * sizeof(int))))
	        return PIO_ENOMEM;
	    for (int i = 0; i < elements_per_pe; i++)
	        buffer[i] = START_DATA_VAL + my_rank;

	    /* Write data to the file. */
	    if (verbose)
	        printf("rank: %d Writing sample data...\n", my_rank);
	    if ((ret = PIOc_write_darray(ncid, varid, ioid, (PIO_Offset)elements_per_pe,
	    			     buffer, NULL)))
	        ERR(ret);
	    if ((ret = PIOc_sync(ncid)))
	        ERR(ret);

	    /* Free buffer space used in this example. */
	    free(buffer);
	
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

	/* Check the output file. */
	if (!my_rank)
	    for (int fmt = 0; fmt < num_flavors; fmt++)
            {
                sprintf(filename, "example1_%d.nc", fmt);
		if ((ret = check_file(ntasks, filename)))
		    ERR(ret);
            }

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
