/* Test netcdf integration layer of the PIO library.

   Test variable compression settings with the netCDF integration
   layer.

   Ed Hartnett, 9/3/20
*/

#include "config.h"
#include "pio_err_macros.h"
#include <pio.h>

#define FILE_NAME "tst_var_compress.nc"
#define VAR_NAME "data_var"
#define DIM_NAME_UNLIMITED "dim_unlimited"
#define DIM_NAME_X "dim_x"
#define DIM_NAME_Y "dim_y"
#define DIM_LEN_X 4
#define DIM_LEN_Y 4
#define NDIM2 2
#define NDIM3 3
#define TEST_VAL_42 42
#define DEFLATE_LEVEL 4

int
run_var_compress_test(int my_rank, int ntasks, int iosysid)
{
    int ncid, ioid;
    int dimid[NDIM3], varid;
    int dimlen[NDIM3] = {NC_UNLIMITED, DIM_LEN_X, DIM_LEN_Y};
    size_t chunksizes[NDIM3] = {1, 1, 1};
    size_t elements_per_pe;
    size_t *compdof; /* The decomposition mapping. */
    int *my_data;
    int i;

    /* Turn on logging for PIO library. */
    /* PIOc_set_log_level(3); */

    /* Create a file with a 3D record var. */
    if (nc_create(FILE_NAME, NC_PIO|NC_NETCDF4, &ncid)) PERR;
    if (nc_def_dim(ncid, DIM_NAME_UNLIMITED, dimlen[0], &dimid[0])) PERR;
    if (nc_def_dim(ncid, DIM_NAME_X, dimlen[1], &dimid[1])) PERR;
    if (nc_def_dim(ncid, DIM_NAME_Y, dimlen[2], &dimid[2])) PERR;
    if (nc_def_var(ncid, VAR_NAME, NC_INT, NDIM3, dimid, &varid)) PERR;
    if (nc_def_var_deflate(ncid, varid, 1, 1, DEFLATE_LEVEL)) PERR;
    if (nc_def_var_chunking(ncid, varid, NC_CHUNKED, chunksizes)) PERR;
    if (nc_def_var_endian(ncid, varid, NC_ENDIAN_BIG)) PERR;

    /* Calculate a decomposition for distributed arrays. */
    elements_per_pe = DIM_LEN_X * DIM_LEN_Y / ntasks;
    if (!(compdof = malloc(elements_per_pe * sizeof(size_t))))
	PERR;
    for (i = 0; i < elements_per_pe; i++)
	compdof[i] = my_rank * elements_per_pe + i;

    /* Create the PIO decomposition for this test. */
    if (nc_def_decomp(iosysid, PIO_INT, NDIM2, &dimlen[1], elements_per_pe,
		      compdof, &ioid, 1, NULL, NULL)) PERR;
    free(compdof);

    /* Create some data on this processor. */
    if (!(my_data = malloc(elements_per_pe * sizeof(int)))) PERR;
    for (i = 0; i < elements_per_pe; i++)
	my_data[i] = my_rank * 10 + i;

    /* Write some data with distributed arrays. */
    if (nc_put_vard_int(ncid, varid, ioid, 0, my_data)) PERR;
    if (nc_close(ncid)) PERR;

    {
	int shuffle_in, deflate_in, deflate_level_in, storage_in;
	int *data_in;
	size_t chunksizes_in[NDIM3];
	int endian_in;
	int d;
	
	/* Open the file. */
	if (nc_open(FILE_NAME, NC_PIO, &ncid)) PERR;
	
	/* Check the variable deflate. */
	if (nc_inq_var_deflate(ncid, 0, &shuffle_in, &deflate_in, &deflate_level_in)) PERR;
	printf("%d %d %d\n", shuffle_in, deflate_in, deflate_level_in);
	/* if (shuffle_in || !deflate_in || deflate_level_in != DEFLATE_LEVEL) PERR; */

	/* Check the chunking. */
	if (nc_inq_var_chunking(ncid, 0, &storage_in, chunksizes_in)) PERR;
	for (d = 0; d < NDIM3; d++)
	    if (chunksizes_in[d] != chunksizes[d]) PERR;
	if (storage_in != NC_CHUNKED) PERR;

	/* Check the endianness. */
	if (nc_inq_var_endian(ncid, 0, &endian_in)) PERR;
	if (endian_in != NC_ENDIAN_BIG) PERR;
	
	/* Read distributed arrays. */
	if (!(data_in = malloc(elements_per_pe * sizeof(int)))) PERR;
	if (nc_get_vard_int(ncid, varid, ioid, 0, data_in)) PERR;
	
	/* Check results. */
	for (i = 0; i < elements_per_pe; i++)
	    if (data_in[i] != my_data[i]) PERR;
	
	/* Close file. */
	if (nc_close(ncid)) PERR;

	/* Free resources. */
	free(data_in);
    }
    free(my_data);
    if (nc_free_decomp(ioid)) PERR;

    return 0;
}

int
main(int argc, char **argv)
{
    int iosysid;
    int my_rank;
    int ntasks;

    /* Initialize MPI. */
    if (MPI_Init(&argc, &argv)) PERR;

    /* Learn my rank and the total number of processors. */
    if (MPI_Comm_rank(MPI_COMM_WORLD, &my_rank)) PERR;
    if (MPI_Comm_size(MPI_COMM_WORLD, &ntasks)) PERR;

    if (!my_rank)
        printf("\n*** Testing netCDF integration layer with var compression.\n");

    /* Only run tests if netCDF-4 is present in the build. */
#ifdef _NETCDF4

    if (!my_rank)
        printf("*** testing var compression with netCDF integration layer...");

    /* Initialize the intracomm. */
    if (nc_def_iosystem(MPI_COMM_WORLD, 1, 1, 0, 0, &iosysid)) PERR;

    /* Run the tests. */
    if (run_var_compress_test(my_rank, ntasks, iosysid)) PERR;

    /* Free the iosystem. */
    if (nc_free_iosystem(iosysid)) PERR;
    
    PSUMMARIZE_ERR;
#endif /* _NETCDF4 */

    /* Finalize MPI. */
    MPI_Finalize();
    PFINAL_RESULTS;
}
