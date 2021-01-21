/**
 * @file
 * Definition for Macros to handle errors in tests or libray code.
 * @author Ed Hartnett
 * @date 2020
 *
 * @see https://github.com/NCAR/ParallelIO
 */

#include <pio_error.h>

/**
 * Global err buffer for MPI. When there is an MPI error, this buffer
 * is used to store the error message that is associated with the MPI
 * error.
 */
char err_buffer[MPI_MAX_ERROR_STRING];

/**
 * This is the length of the most recent MPI error message, stored
 * int the global error string.
 */
int resultlen;
