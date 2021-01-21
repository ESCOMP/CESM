/**
 * @file
 * PIO list functions.
 */
#include <config.h>
#include <pio.h>
#include <pio_internal.h>
#include <string.h>
#include <stdio.h>
#include <uthash.h>

static io_desc_t *pio_iodesc_list = NULL;
static io_desc_t *current_iodesc = NULL;
static iosystem_desc_t *pio_iosystem_list = NULL;
static file_desc_t *pio_file_list = NULL;
static file_desc_t *current_file = NULL;

/**
 * Add a new entry to the global list of open files.
 *
 * @param file pointer to the file_desc_t struct for the new file.
 * @author Jim Edwards
 */
void
pio_add_to_file_list(file_desc_t *file)
{
    assert(file);

    /* Keep a global pointer to the current file. */
    current_file = file;

    /* Add file to list. */
    HASH_ADD_INT(pio_file_list, pio_ncid, file);
}

/**
 * Given ncid, find the file_desc_t data for an open file. The ncid
 * used is the interally generated pio_ncid.
 *
 * @param ncid the PIO assigned ncid of the open file.
 * @param cfile1 pointer to a pointer to a file_desc_t. The pointer
 * will get a copy of the pointer to the file info.
 *
 * @returns 0 for success, error code otherwise.
 * @author Ed Hartnett
 */
int
pio_get_file(int ncid, file_desc_t **cfile1)
{
    file_desc_t *cfile = NULL;

    PLOG((2, "pio_get_file ncid = %d", ncid));

    /* Caller must provide this. */
    if (!cfile1)
        return PIO_EINVAL;

    /* Find the file pointer. */
    if (current_file && current_file->pio_ncid == ncid)
        cfile = current_file;
    else
        HASH_FIND_INT(pio_file_list, &ncid, cfile);

    /* If not found, return error. */
    if (!cfile)
        return PIO_EBADID;

    current_file = cfile;

    /* We depend on every file having a pointer to the iosystem. */
    if (!cfile->iosystem)
        return PIO_EINVAL;

    /* Let's just ensure we have a valid IO type. */
    pioassert(iotype_is_valid(cfile->iotype), "invalid IO type", __FILE__, __LINE__);

    /* Copy pointer to file info. */
    *cfile1 = cfile;

    return PIO_NOERR;
}

/**
 * Delete a file from the list of open files.
 *
 * @param ncid ID of file to delete from list
 * @returns 0 for success, error code otherwise
 * @author Jim Edwards, Ed Hartnett
 */
int
pio_delete_file_from_list(int ncid)
{
    file_desc_t *cfile = NULL;
    int ret;

    /* Find the file pointer. */
    if (current_file && current_file->pio_ncid == ncid)
        cfile = current_file;
    else
        HASH_FIND_INT(pio_file_list, &ncid, cfile);

    if (cfile)
    {
        HASH_DEL(pio_file_list, cfile);

        if (current_file == cfile)
            current_file = pio_file_list;

        /* Free the varlist entries for this file. */
        while (cfile->varlist)
            if ((ret = delete_var_desc(cfile->varlist->varid, &cfile->varlist)))
                return pio_err(NULL, cfile, ret, __FILE__, __LINE__);

        /* Free the memory used for this file. */
        free(cfile);

        return PIO_NOERR;
    }

    /* No file was found. */
    return PIO_EBADID;
}

/**
 * Delete iosystem info from list.
 *
 * @param piosysid the iosysid to delete
 * @returns 0 on success, error code otherwise
 * @author Jim Edwards
 */
int
pio_delete_iosystem_from_list(int piosysid)
{
    iosystem_desc_t *ciosystem, *piosystem = NULL;

    PLOG((1, "pio_delete_iosystem_from_list piosysid = %d", piosysid));

    for (ciosystem = pio_iosystem_list; ciosystem; ciosystem = ciosystem->next)
    {
        PLOG((3, "ciosystem->iosysid = %d", ciosystem->iosysid));
        if (ciosystem->iosysid == piosysid)
        {
            if (piosystem == NULL)
                pio_iosystem_list = ciosystem->next;
            else
                piosystem->next = ciosystem->next;
            free(ciosystem);
            return PIO_NOERR;
        }
        piosystem = ciosystem;
    }
    return PIO_EBADID;
}

/**
 * Add iosystem info to list.
 *
 * @param ios pointer to the iosystem_desc_t info to add.
 * @returns 0 on success, error code otherwise
 * @author Jim Edwards
 */
int
pio_add_to_iosystem_list(iosystem_desc_t *ios)
{
    iosystem_desc_t *cios;
    int i = 1;

    assert(ios);

    ios->next = NULL;
    cios = pio_iosystem_list;
    if (!cios)
        pio_iosystem_list = ios;
    else
    {
        i++;
        while (cios->next)
        {
            cios = cios->next;
            i++;
        }
        cios->next = ios;
    }

    ios->iosysid = i << 16;

    return ios->iosysid;
}

/**
 * Get iosystem info from list.
 *
 * @param iosysid id of the iosystem
 * @returns pointer to iosystem_desc_t, or NULL if not found.
 * @author Jim Edwards
 */
iosystem_desc_t *
pio_get_iosystem_from_id(int iosysid)
{
    iosystem_desc_t *ciosystem;

    PLOG((2, "pio_get_iosystem_from_id iosysid = %d", iosysid));

    for (ciosystem = pio_iosystem_list; ciosystem; ciosystem = ciosystem->next)
        if (ciosystem->iosysid == iosysid)
            return ciosystem;

    return NULL;
}

/**
 * Count the number of open iosystems.
 *
 * @param niosysid pointer that will get the number of open iosystems.
 * @returns 0 for success.
 * @author Jim Edwards
 */
int
pio_num_iosystem(int *niosysid)
{
    int count = 0;

    /* Count the elements in the list. */
    for (iosystem_desc_t *c = pio_iosystem_list; c; c = c->next)
    {
        PLOG((3, "pio_num_iosystem c->iosysid %d", c->iosysid));
        count++;
    }

    /* Return count to caller via pointer. */
    if (niosysid)
        *niosysid = count;

    return PIO_NOERR;
}

/**
 * Add an iodesc.
 *
 * @param iodesc io_desc_t pointer to data to add to list.
 * @returns 0 for success, error code otherwise.
 * @author Jim Edwards, Ed Hartnett
 */
int
pio_add_to_iodesc_list(io_desc_t *iodesc)
{
    HASH_ADD_INT(pio_iodesc_list, ioid, iodesc);
    current_iodesc = iodesc;
    return PIO_NOERR;
}

/**
 * Get an iodesc.
 *
 * @param ioid ID of iodesc to get.
 * @returns pointer to the iodesc struc.
 * @author Jim Edwards
 */
io_desc_t *
pio_get_iodesc_from_id(int ioid)
{
    io_desc_t *ciodesc=NULL;
    if (current_iodesc && current_iodesc->ioid == ioid)
        ciodesc = current_iodesc;
    else
    {
        HASH_FIND_INT(pio_iodesc_list, &ioid, ciodesc);
        current_iodesc = ciodesc;
    }
    return ciodesc;
}

/**
 * Delete an iodesc.
 *
 * @param ioid ID of iodesc to delete.
 * @returns 0 on success, error code otherwise.
 * @author Jim Edwards
 */
int
pio_delete_iodesc_from_list(int ioid)
{
    io_desc_t *ciodesc;

    ciodesc = pio_get_iodesc_from_id(ioid);
    if (ciodesc)
    {
        HASH_DEL(pio_iodesc_list, ciodesc);
        if (current_iodesc == ciodesc)
            current_iodesc = pio_iodesc_list;
        free(ciodesc);
        return PIO_NOERR;
    }
    return PIO_EBADID;
}

/**
 * Add var_desc_t info to the list.
 *
 * @param varid the varid of the variable.
 * @param rec_var non-zero if this is a record var.
 * @param pio_type the PIO type.
 * @param pio_type_size size of the PIO type in bytes
 * @param mpi_type the MPI type.
 * @param mpi_type_size size of the MPI type in bytes.
 * @param ndims the number of dims for this var.
 * @param varlist pointer to list to add to.
 * @returns 0 for success, error code otherwise.
 * @author Ed Hartnett
 */
int
add_to_varlist(int varid, int rec_var, int pio_type, int pio_type_size,
               MPI_Datatype mpi_type, int mpi_type_size, int ndims,
               var_desc_t **varlist)
{
    var_desc_t *var_desc;

    /* Check inputs. */
    pioassert(varid >= 0 && varlist, "invalid input", __FILE__, __LINE__);

    PLOG((4, "add_to_varlist varid %d rec_var %d pio_type %d pio_type_size %d "
          "mpi_type %d mpi_type_size %d ndims %d", varid, rec_var, pio_type,
          pio_type_size, mpi_type, mpi_type_size, ndims));

    /* Allocate storage. */
    if (!(var_desc = calloc(1, sizeof(var_desc_t))))
        return PIO_ENOMEM;

    /* Set values. */
    var_desc->varid = varid;
    var_desc->rec_var = rec_var;
    var_desc->pio_type = pio_type;
    var_desc->pio_type_size = pio_type_size;
    var_desc->mpi_type = mpi_type;
    var_desc->mpi_type_size = mpi_type_size;
    var_desc->ndims = ndims;
    var_desc->record = -1;

    HASH_ADD_INT(*varlist, varid, var_desc);

    return PIO_NOERR;
}

/**
 * Get a var_desc_t info for a variable.
 *
 * @param varid ID of variable to get var_desc_t of.
 * @param varlist pointer to list of var_desc_t.
 * @param var_desc pointer that gets pointer to var_desc_t struct.
 * @returns 0 for success, error code otherwise.
 * @author Ed Hartnett
 */
int
get_var_desc(int varid, var_desc_t **varlist, var_desc_t **var_desc)
{
    var_desc_t *my_var=NULL;

    /* Check inputs. */
    pioassert(varlist, "invalid input", __FILE__, __LINE__);

    /* Empty varlist. */
    if (!*varlist)
        return PIO_ENOTVAR;

    HASH_FIND_INT( *varlist, &varid, my_var);

    /* Did we find it? */
    if (!my_var)
        return PIO_ENOTVAR;
    else
        *var_desc = my_var;

    return PIO_NOERR;
}

/**
 * Delete var_desc_t info for a variable.
 *
 * @param varid ID of variable to delete.
 * @param varlist pointer to list of var_desc_t.
 * @returns 0 on success, error code otherwise.
 * @author Ed Hartnett
 */
int
delete_var_desc(int varid, var_desc_t **varlist)
{
    var_desc_t *v;
    int ret;

    /* Check inputs. */
    pioassert(varid >= 0 && varlist, "invalid input", __FILE__, __LINE__);

    /* Null list means no variables to delete. */
    if (!*varlist)
        return PIO_ENOTVAR;

    if ((ret = get_var_desc( varid, varlist, &v)))
        return ret;

    HASH_DEL(*varlist, v);

    /* Free memory. */
    if (v->fillvalue)
        free(v->fillvalue);
    free(v);

    return PIO_NOERR;
}
