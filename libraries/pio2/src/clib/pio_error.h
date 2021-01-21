/**
 * @file
 * Macros to handle errors in tests or libray code.
 * @author Ed Hartnett
 * @date 2019
 *
 * @see https://github.com/NCAR/ParallelIO
 */

#ifndef __PIO_ERROR__
#define __PIO_ERROR__

#include <config.h>
#include <pio.h>

/**
 * Handle non-MPI errors by printing error message and goto exit. This
 * is used in test code.
 */
#define PBAIL(e) do {                                                    \
        fprintf(stderr, "%d Error %d in %s, line %d\n", my_rank, e, __FILE__, __LINE__); \
        goto exit;                                                      \
    } while (0)

/**
 * Handle non-MPI errors by calling pio_err(), setting return code,
 * and goto exit. This is used in library code.
 */
#define EXIT(ios, e) do {                                               \
        ret = pio_err(NULL, NULL, e, __FILE__, __LINE__);        \
        goto exit;                                                      \
    } while (0)

/**
 * Same as the EXIT macro, but uses NULL for iosystem.
 */
#define EXIT1(e) EXIT(NULL, e)

/**
 * Handle non-MPI errors by finalizing the MPI library and exiting
 * with an exit code.
 */
#define ERR(e) do {                                                     \
        fprintf(stderr, "%d Error %d in %s, line %d\n", my_rank, e, __FILE__, __LINE__); \
        MPI_Finalize();                                                 \
        return e;                                                       \
    } while (0)

/**
 * Handle MPI errors. This should only be used with MPI library
 * function calls. Print error message, finalize MPI and return error
 * code.
 */
#define MPIERR(e) do {                                                  \
        MPI_Error_string(e, err_buffer, &resultlen);                    \
        fprintf(stderr, "MPI error, line %d, file %s: %s\n", __LINE__, __FILE__, err_buffer); \
        MPI_Finalize();                                                 \
        return PIO_EIO;                                                 \
    } while (0)

/**
 * Handle MPI errors. This should only be used with MPI library
 * function calls. Print error message, finalize MPI and goto exit.
 */
#define MPIBAIL(e) do {                                                 \
        MPI_Error_string(e, err_buffer, &resultlen);                    \
        fprintf(stderr, "MPI error, line %d, file %s: %s\n", __LINE__, __FILE__, err_buffer); \
        ret = NC_EIO;                                                   \
        goto exit;                                                      \
    } while (0)

/**
 * Global err buffer for MPI. When there is an MPI error, this buffer
 * is used to store the error message that is associated with the MPI
 * error.
 */
extern char err_buffer[MPI_MAX_ERROR_STRING];

/**
 * This is the length of the most recent MPI error message, stored
 * int the global error string.
 */
extern int resultlen;

#endif /* __PIO_ERROR__ */
