/**
  * @file
  * PIO functions to get data with distributed arrays.
  *
  * @author Ed Hartnett
  * @date  2019
  *
  * @see https://github.com/NCAR/ParallelIO
  */
#include <config.h>
#include <pio.h>
#include <pio_internal.h>

/**
 * @addtogroup PIO_read_darray_c
 * Read distributed arrays from a variable in C.
 * @{
 */

/**
 * Get a muti-dimensional subset of a text variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param buf pointer that will get the data.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int PIOc_get_vard_text(int ncid, int varid, int decompid,
                       const PIO_Offset recnum, char *buf)
{
    return PIOc_get_vard_tc(ncid, varid, decompid, recnum, NC_CHAR, buf);
}

/**
 * Get a muti-dimensional subset of an unsigned char variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param buf pointer that will get the data.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int PIOc_get_vard_uchar(int ncid, int varid, int decompid,
                        const PIO_Offset recnum, unsigned char *buf)
{
    return PIOc_get_vard_tc(ncid, varid, decompid, recnum, NC_UBYTE, buf);
}

/**
 * Get a muti-dimensional subset of a signed char variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param buf pointer that will get the data.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int PIOc_get_vard_schar(int ncid, int varid, int decompid,
                        const PIO_Offset recnum, signed char *buf)
{
    return PIOc_get_vard_tc(ncid, varid, decompid, recnum, NC_BYTE, buf);
}

/**
 * Get a muti-dimensional subset of an unsigned 16-bit integer
 * variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param buf pointer that will get the data.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int PIOc_get_vard_ushort(int ncid, int varid, int decompid,
                         const PIO_Offset recnum, unsigned short *buf)
{
    return PIOc_get_vard_tc(ncid, varid, decompid, recnum, NC_USHORT,
                            buf);
}

/**
 * Get a muti-dimensional subset of a 16-bit integer variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param buf pointer that will get the data.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int PIOc_get_vard_short(int ncid, int varid, int decompid,
                        const PIO_Offset recnum, short *buf)
{
    return PIOc_get_vard_tc(ncid, varid, decompid, recnum, NC_SHORT, buf);
}

/**
 * Get a muti-dimensional subset of an unsigned integer variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param buf pointer that will get the data.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int PIOc_get_vard_uint(int ncid, int varid, int decompid,
                       const PIO_Offset recnum, unsigned int *buf)
{
    return PIOc_get_vard_tc(ncid, varid, decompid, recnum, NC_UINT, buf);
}

/**
 * Get a muti-dimensional subset of an integer variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param buf pointer that will get the data.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int PIOc_get_vard_int(int ncid, int varid, int decompid,
                      const PIO_Offset recnum, int *buf)
{
    return PIOc_get_vard_tc(ncid, varid, decompid, recnum, NC_INT, buf);
}

/**
 * Get a muti-dimensional subset of a floating point variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param buf pointer that will get the data.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int PIOc_get_vard_float(int ncid, int varid, int decompid,
                        const PIO_Offset recnum, float *buf)
{
    return PIOc_get_vard_tc(ncid, varid, decompid, recnum, NC_FLOAT, buf);
}

/**
 * Get a muti-dimensional subset of a 64-bit floating point variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param buf pointer that will get the data.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int PIOc_get_vard_double(int ncid, int varid, int decompid,
                         const PIO_Offset recnum, double *buf)
{
    return PIOc_get_vard_tc(ncid, varid, decompid, recnum, NC_DOUBLE,
                            buf);
}

/**
 * Get a muti-dimensional subset of an unsigned 64-bit integer
 * variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param buf pointer that will get the data.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int PIOc_get_vard_ulonglong(int ncid, int varid, int decompid,
                            const PIO_Offset recnum, unsigned long long *buf)
{
    return PIOc_get_vard_tc(ncid, varid, decompid, recnum, NC_UINT64,
                            buf);
}

/**
 * Get a muti-dimensional subset of a 64-bit integer variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param buf pointer that will get the data.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int PIOc_get_vard_longlong(int ncid, int varid, int decompid,
                           const PIO_Offset recnum, long long *buf)
{
    return PIOc_get_vard_tc(ncid, varid, decompid, recnum, NC_INT64, buf);
}

/**
 * Get a muti-dimensional subset of a variable the same type
 * as the variable in the file.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param buf pointer that will get the data.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int PIOc_get_vard(int ncid, int varid, int decompid, const PIO_Offset recnum,
                  void *buf)
{
    return PIOc_get_vard_tc(ncid, varid, decompid, recnum, NC_NAT, buf);
}


/**
 * @}
 */
