/**
 * @file
 * PIO functions to write data with distributed arrays.
 *
 * @author Ed Hartnett
 * @date 2019
 * @see https://github.com/NCAR/ParallelIO
 */
#include <config.h>
#include <pio.h>
#include <pio_internal.h>

/**
 * @addtogroup PIO_write_darray_c
 * Write distributed arrays to a Variable in C.
 * @{
 */

/**
 * Put distributed array subset of a text variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param op pointer to the data to be written.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_put_vard_text(int ncid, int varid, int decompid, const size_t recnum,
                 const char *op)
{
    return PIOc_put_vard_tc(ncid, varid, decompid, recnum, NC_CHAR, op);
}

/**
 * Put distributed array subset of an unsigned char variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param op pointer to the data to be written.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_put_vard_uchar(int ncid, int varid, int decompid, const size_t recnum,
                  const unsigned char *op)
{
    return PIOc_put_vard_tc(ncid, varid, decompid, recnum, NC_UBYTE, op);
}

/**
 * Put distributed array subset of a signed char variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param op pointer to the data to be written.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_put_vard_schar(int ncid, int varid, int decompid, const size_t recnum,
                  const signed char *op)
{
    return PIOc_put_vard_tc(ncid, varid, decompid, recnum, NC_BYTE, op);
}

/**
 * Put distributed array subset of an unsigned 16-bit integer
 * variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param op pointer to the data to be written.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_put_vard_ushort(int ncid, int varid, int decompid, const size_t recnum,
                   const unsigned short *op)
{
    return PIOc_put_vard_tc(ncid, varid, decompid, recnum, NC_USHORT, op);
}

/**
 * Put distributed array subset of a 16-bit integer variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param op pointer to the data to be written.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_put_vard_short(int ncid, int varid, int decompid, const size_t recnum,
                  const short *op)
{
    return PIOc_put_vard_tc(ncid, varid, decompid, recnum, NC_SHORT, op);
}

/**
 * Put distributed array subset of an unsigned integer
 * variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param op pointer to the data to be written.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_put_vard_uint(int ncid, int varid, int decompid, const size_t recnum,
                 const unsigned int *op)
{
    return PIOc_put_vard_tc(ncid, varid, decompid, recnum, NC_UINT, op);
}

/**
 * Put distributed array subset of an integer variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param op pointer to the data to be written.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_put_vard_int(int ncid, int varid, int decompid, const size_t recnum,
                const int *op)
{
    return PIOc_put_vard_tc(ncid, varid, decompid, recnum, NC_INT, op);
}

/* /\** */
/*  * Put distributed array subset of a 64-bit integer variable. */
/*  * */
/*  * This routine is called collectively by all tasks in the */
/*  * communicator ios.union_comm. */
/*  * */
/*  * @param ncid identifies the netCDF file */
/*  * @param varid the variable ID number */
/*  * @param decompid the decomposition ID. */
/*  * @param recnum the record number. */
/*  * @param op pointer to the data to be written. */
/*  * @return PIO_NOERR on success, error code otherwise. */
/*  * @author Ed Hartnett */
/*  *\/ */
/* int */
/* nc_put_vard_long(int ncid, int varid, int decompid, const size_t recnum, */
/*                    const long *op) */
/* { */
/*     return PIOc_put_vard_tc(ncid, varid, decompid, recnum, PIO_LONG_INTERNAL, op); */
/* } */

/**
 * Put distributed array subset of a floating point variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param op pointer to the data to be written.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_put_vard_float(int ncid, int varid, int decompid, const size_t recnum,
                  const float *op)
{
    return PIOc_put_vard_tc(ncid, varid, decompid, recnum, NC_FLOAT, op);
}

/**
 * Put distributed array subset of a 64-bit unsigned integer
 * variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param op pointer to the data to be written.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_put_vard_longlong(int ncid, int varid, int decompid, const size_t recnum,
                     const long long *op)
{
    return PIOc_put_vard_tc(ncid, varid, decompid, recnum, NC_INT64, op);
}

/**
 * Put distributed array subset of a 64-bit floating point
 * variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param op pointer to the data to be written.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_put_vard_double(int ncid, int varid, int decompid, const size_t recnum,
                   const double *op)
{
    return PIOc_put_vard_tc(ncid, varid, decompid, recnum, NC_DOUBLE, op);
}

/**
 * Put distributed array subset of an unsigned 64-bit integer
 * variable.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param op pointer to the data to be written.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_put_vard_ulonglong(int ncid, int varid, int decompid, const size_t recnum,
                      const unsigned long long *op)
{
    return PIOc_put_vard_tc(ncid, varid, decompid, recnum, NC_UINT64, op);
}

/**
 * Write distributed array subset of a variable of any type.
 *
 * This routine is called collectively by all tasks in the
 * communicator ios.union_comm.
 *
 * @param ncid identifies the netCDF file
 * @param varid the variable ID number
 * @param decompid the decomposition ID.
 * @param recnum the record number.
 * @param op pointer to the data to be written.
 * @return PIO_NOERR on success, error code otherwise.
 * @author Ed Hartnett
 */
int
nc_put_vard(int ncid, int varid, int decompid, const size_t recnum,
            const void *op)
{
    return PIOc_put_vard_tc(ncid, varid, decompid, recnum, NC_NAT, op);
}

/**
 * @}
 */
