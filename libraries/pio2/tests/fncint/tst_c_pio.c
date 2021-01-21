/* This program does a very simple I/O system and decomposition, and
 * writes a simple file.

   Ed Hartnett, 7/27/19
*/

#include "config.h"
#include <pio.h>
#include <mpi.h>
#include <pio_tests.h>
#include <pio_internal.h>

#define FILE_NAME "tst_c_pio.nc"
#define VAR_NAME "data_var"
#define DIM_NAME_UNLIMITED "dim_unlimited"
#define DIM_NAME_X "dim_x"
#define DIM_NAME_Y "dim_y"
#define DIM_LEN_X 4
#define DIM_LEN_Y 4
#define NDIM2 2
#define NDIM3 3
#define LLEN 4
#define MPI_ERR 999
#define NTASKS4 4

int
main(int argc, char **argv)
{
    int my_rank;
    int ntasks;

    /* Initialize MPI. */
    if (MPI_Init(&argc, &argv))
        return MPI_ERR;

    /* Learn my rank and the total number of processors. */
    if (MPI_Comm_rank(MPI_COMM_WORLD, &my_rank))
        return MPI_ERR;
    if (MPI_Comm_size(MPI_COMM_WORLD, &ntasks))
        return MPI_ERR;
    /* Must run on 4 tasks only. */
    if (ntasks != NTASKS4)
        return MPI_ERR;

    if (!my_rank)
    {
        printf("\n*** Testing simple use of PIO.\n");
        printf("*** testing creating of simple file...");
    }
    {
        int iosysid;
        int ncid;
        int dimid[NDIM3];
        int varid;
        int ioid;
        int dimlen[NDIM3] = {NC_UNLIMITED, DIM_LEN_X, DIM_LEN_Y};
        char dimname[NDIM3][NC_MAX_NAME + 1] = {DIM_NAME_UNLIMITED, DIM_NAME_X, DIM_NAME_Y};
        int iotype = PIO_IOTYPE_NETCDF;
        int my_data[LLEN];
        PIO_Offset compmap[LLEN];
        int i;
        int ret;

        /* PIOc_set_log_level(3); */

        /* Initialize local data. */
        for (i = 0; i < LLEN; i++)
            my_data[i] = my_rank * 10 + i;

        /* Initialize the IOSystem. */
        if ((ret = PIOc_Init_Intracomm(MPI_COMM_WORLD, 1, 1, 0, 0, &iosysid)))
            return ret;

        /* Create a file. */
        if ((ret = PIOc_createfile(iosysid, &ncid, &iotype, FILE_NAME, 0)))
            return ret;

        /* Define metadata. */
        for (i = 0; i < NDIM3; i++)
            if ((ret = PIOc_def_dim(ncid, dimname[i], dimlen[i], &dimid[i])))
                return ret;
        if ((ret = PIOc_def_var(ncid, VAR_NAME, PIO_INT, NDIM3, dimid, &varid)))
            return ret;
        if ((ret = PIOc_enddef(ncid)))
            return ret;

        /* Create the decomposition. */
        for (i = 0; i < LLEN; i++)
            compmap[i] = i + my_rank * LLEN;
        if ((ret = PIOc_init_decomp(iosysid, PIO_INT, NDIM2, &dimlen[1], LLEN, compmap,
                                    &ioid, PIO_REARR_BOX, NULL, NULL)))
            return ret;

        /* Write data. */
        if ((ret = PIOc_setframe(ncid, varid, 0)))
            return ret;
        if ((ret = PIOc_write_darray(ncid, varid, ioid, LLEN, my_data, NULL)))
            return ret;

        /* Close the file. */
        if ((ret = PIOc_closefile(ncid)))
            return ret;

        /* Free the decomposition. */
        if ((ret = PIOc_freedecomp(iosysid, ioid)))
            return ret;

        /* Free the IOSystem. */
        if ((ret = PIOc_free_iosystem(iosysid)))
            return ret;
    }

    if (!my_rank)
        printf("\nSUCCESS!\n");
    /* Finalize MPI. */
    MPI_Finalize();
    return 0;
}
