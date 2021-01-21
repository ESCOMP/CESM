/**
 * @file
 * @internal Additional nc_* functions to support netCDF integration.
 *
 * @author Ed Hartnett
 */

#include "config.h"
#include <stdlib.h>
#include <pio_internal.h>
#include "ncintdispatch.h"

/** This is te default io system id. */
extern int diosysid;

/**
 * Same as PIOc_Init_Intracomm().
 *
 * @author Ed Hartnett
 */
int
nc_def_iosystem(MPI_Comm comp_comm, int num_iotasks, int stride, int base,
                int rearr, int *iosysidp)
{
    int ret;

    /* Make sure PIO was initialized. */
    if ((ret = PIO_NCINT_initialize()))
        return ret;

    /* Call the PIOc_ function to initialize the intracomm. */
    if ((ret = PIOc_Init_Intracomm(comp_comm, num_iotasks, stride, base, rearr,
                                   iosysidp)))
        return ret;

    /* Remember the io system id. */
    diosysid = *iosysidp;

    return PIO_NOERR;
}

/**
 * Same as PIOc_init_async().
 *
 * @param world the communicator containing all the available tasks.
 * @param num_io_procs the number of processes for the IO component.
 * @param io_proc_list an array of lenth num_io_procs with the
 * processor number for each IO processor. If NULL then the IO
 * processes are assigned starting at processes 0.
 * @param component_count number of computational components
 * @param num_procs_per_comp an array of int, of length
 * component_count, with the number of processors in each computation
 * component.
 * @param proc_list an array of arrays containing the processor
 * numbers for each computation component. If NULL then the
 * computation components are assigned processors sequentially
 * starting with processor num_io_procs.
 * @param io_comm pointer to an MPI_Comm. If not NULL, it will
 * get an MPI duplicate of the IO communicator. (It is a full
 * duplicate and later must be freed with MPI_Free() by the caller.)
 * @param comp_comm pointer to an array of pointers to MPI_Comm;
 * the array is of length component_count. If not NULL, it will get an
 * MPI duplicate of each computation communicator. (These are full
 * duplicates and each must later be freed with MPI_Free() by the
 * caller.)
 * @param rearranger the default rearranger to use for decompositions
 * in this IO system. Only PIO_REARR_BOX is supported for
 * async. Support for PIO_REARR_SUBSET will be provided in a future
 * version.
 * @param iosysidp pointer to array of length component_count that
 * gets the iosysid for each component.
 *
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_def_async(MPI_Comm world, int num_io_procs, int *io_proc_list,
             int component_count, int *num_procs_per_comp, int **proc_list,
             MPI_Comm *io_comm, MPI_Comm *comp_comm, int rearranger,
             int *iosysidp)
{
    int ret;

    /* Make sure PIO was initialized. */
    if ((ret = PIO_NCINT_initialize()))
        return ret;

    /* Change error handling so we can test inval parameters. */
    if ((ret = PIOc_set_iosystem_error_handling(PIO_DEFAULT, PIO_RETURN_ERROR, NULL)))
        return ret;

    /* Call the PIOc_ function to initialize the intracomm. */
    if ((ret = PIOc_init_async(world, num_io_procs, io_proc_list,
                               component_count, num_procs_per_comp, proc_list,
                               io_comm, comp_comm, rearranger, iosysidp)))
        return ret;

    /* Remember the io system id. */
    diosysid = *iosysidp;

    return PIO_NOERR;
}

/**
 * Set the default iosystemID.
 *
 * @param iosysid The IO system ID to set.
 *
 * @return PIO_NOERR for success.
 * @author Ed Hartnett
 */
int
nc_set_iosystem(int iosysid)
{
    /* Remember the io system id. */
    diosysid = iosysid;

    return PIO_NOERR;
}

/**
 * Get the default iosystemID.
 *
 * @param iosysid Pointer that gets The IO system ID.
 *
 * @return PIO_NOERR for success.
 * @author Ed Hartnett
 */
int
nc_get_iosystem(int *iosysid)
{
    pioassert(iosysid, "pointer to iosysid must be provided", __FILE__,
              __LINE__);

    /* Remember the io system id. */
    *iosysid = diosysid;

    return PIO_NOERR;
}

/**
 * Same as PIOc_free_iosystem().
 *
 * @author Ed Hartnett
 */
int
nc_free_iosystem(int iosysid)
{
    return PIOc_free_iosystem(iosysid);
}

/**
 * Same as PIOc_init_decomp().
 *
 * @author Ed Hartnett
 */
int
nc_def_decomp(int iosysid, int pio_type, int ndims, const int *gdimlen,
               int maplen, const size_t *compmap, int *ioidp,
              int rearranger, const size_t *iostart,
              const size_t *iocount)
{
    return PIOc_init_decomp(iosysid, pio_type, ndims, gdimlen, maplen,
                            (const PIO_Offset *)compmap, ioidp, rearranger,
                            (const PIO_Offset *)iostart,
                            (const PIO_Offset *)iocount);
}

/**
 * Same as PIOc_freedecomp().
 *
 * @author Ed Hartnett
 */
int
nc_free_decomp(int ioid)
{
    PLOG((1, "nc_free_decomp ioid %d", ioid));
    return PIOc_freedecomp(diosysid, ioid);
}
