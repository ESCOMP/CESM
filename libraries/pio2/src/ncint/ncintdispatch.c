/**
 * @file
 * @internal Dispatch layer for netcdf PIO integration.
 *
 * @author Ed Hartnett
 */

#include "config.h"
#include <stdlib.h>
#include "pio.h"
#include "pio_internal.h"
#include "ncintdispatch.h"

/* Prototypes from nc4internal.h. */
int nc4_file_list_add(int ncid, const char *path, int mode,
                      void **dispatchdata);
int nc4_file_list_del(int ncid);
int nc4_file_list_get(int ncid, char **path, int *mode,
                      void **dispatchdata);

/** Default iosysid. */
int diosysid;

/** Did we initialize user-defined format? */
int ncint_initialized = 0;

/** Version of dispatch table. */
#define DISPATCH_VERSION 2

/* This is the dispatch object that holds pointers to all the
 * functions that make up the NCINT dispatch interface. */
NC_Dispatch NCINT_dispatcher = {

    NC_FORMATX_UDF0,
    DISPATCH_VERSION,

    PIO_NCINT_create,
    PIO_NCINT_open,

    PIO_NCINT_redef,
    PIO_NCINT__enddef,
    PIO_NCINT_sync,
    PIO_NCINT_abort,
    PIO_NCINT_close,
    PIO_NCINT_set_fill,
    PIO_NCINT_inq_format,
    PIO_NCINT_inq_format_extended,

    PIO_NCINT_inq,
    PIO_NCINT_inq_type,

    PIO_NCINT_def_dim,
    PIO_NCINT_inq_dimid,
    PIO_NCINT_inq_dim,
    PIO_NCINT_inq_unlimdim,
    PIO_NCINT_rename_dim,

    PIO_NCINT_inq_att,
    PIO_NCINT_inq_attid,
    PIO_NCINT_inq_attname,
    PIO_NCINT_rename_att,
    PIO_NCINT_del_att,
    PIO_NCINT_get_att,
    PIO_NCINT_put_att,

    PIO_NCINT_def_var,
    PIO_NCINT_inq_varid,
    PIO_NCINT_rename_var,
    PIO_NCINT_get_vara,
    PIO_NCINT_put_vara,
    PIO_NCINT_get_vars,
    PIO_NCINT_put_vars,
    NC_NOTNC3_get_varm,
    NC_NOTNC3_put_varm,

    PIO_NCINT_inq_var_all,

    NC_NOTNC4_var_par_access,
    PIO_NCINT_def_var_fill,

    PIO_NCINT_show_metadata,
    PIO_NCINT_inq_unlimdims,

    NC_NOTNC4_inq_ncid,
    NC_NOTNC4_inq_grps,
    NC_NOTNC4_inq_grpname,
    NC_NOTNC4_inq_grpname_full,
    NC_NOTNC4_inq_grp_parent,
    NC_NOTNC4_inq_grp_full_ncid,
    NC_NOTNC4_inq_varids,
    NC_NOTNC4_inq_dimids,
    NC_NOTNC4_inq_typeids,
    PIO_NCINT_inq_type_equal,
    NC_NOTNC4_def_grp,
    NC_NOTNC4_rename_grp,
    NC_NOTNC4_inq_user_type,
    NC_NOTNC4_inq_typeid,

    NC_NOTNC4_def_compound,
    NC_NOTNC4_insert_compound,
    NC_NOTNC4_insert_array_compound,
    NC_NOTNC4_inq_compound_field,
    NC_NOTNC4_inq_compound_fieldindex,
    NC_NOTNC4_def_vlen,
    NC_NOTNC4_put_vlen_element,
    NC_NOTNC4_get_vlen_element,
    NC_NOTNC4_def_enum,
    NC_NOTNC4_insert_enum,
    NC_NOTNC4_inq_enum_member,
    NC_NOTNC4_inq_enum_ident,
    NC_NOTNC4_def_opaque,
    PIO_NCINT_def_var_deflate,
    NC_NOTNC4_def_var_fletcher32,
    PIO_NCINT_def_var_chunking,
    PIOc_def_var_endian,
    NC_NOTNC4_def_var_filter,
    NC_NOTNC4_set_var_chunk_cache,
    NC_NOTNC4_get_var_chunk_cache,
    NC_NOTNC4_filter_actions
};

/**
 * Pointer to the dispatch table used for netCDF/PIO
 * integration. Files opened or created with mode flag NC_UDF0 will be
 * opened using the functions in this dispatch table. */
const NC_Dispatch* NCINT_dispatch_table = NULL;

/**
 * @internal Initialize NCINT dispatch layer.
 *
 * @return ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_initialize(void)
{
    int ret;

    if (!ncint_initialized)
    {
        NCINT_dispatch_table = &NCINT_dispatcher;

        PLOG((1, "Adding user-defined format for netCDF PIO integration"));

        /* Add our user defined format. */
        if ((ret = nc_def_user_format(NC_UDF0, &NCINT_dispatcher, NULL)))
            return ret;
        ncint_initialized++;
    }

    return NC_NOERR;
}

/**
 * @internal Finalize NCINT dispatch layer.
 *
 * @return ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_finalize(void)
{
    return NC_NOERR;
}

/**
 * Create a file using PIO via netCDF's nc_create().
 *
 * @param path The file name of the new file.
 * @param cmode The creation mode flag.
 * @param initialsz Ignored by this function.
 * @param basepe Ignored by this function.
 * @param chunksizehintp Ignored by this function.
 * @param parameters pointer to struct holding extra data (e.g. for
 * parallel I/O) layer. Ignored if NULL.
 * @param dispatch Pointer to the dispatch table for this file.
 * @param ncid The ncid assigned to this file by netCDF (aka
 * ext_ncid).
 *
 * @return ::NC_NOERR No error, or error code.
 * @author Ed Hartnett
 */
int
PIO_NCINT_create(const char *path, int cmode, size_t initialsz, int basepe,
                 size_t *chunksizehintp, void *parameters,
                 const NC_Dispatch *dispatch, int ncid)
{
    int iotype;
    iosystem_desc_t *ios;  /* Pointer to io system information. */
    int ret;

    PLOG((1, "PIO_NCINT_create path = %s mode = %x", path, cmode));

    /* Get the IO system info from the id. */
    if (!(ios = pio_get_iosystem_from_id(diosysid)))
        return pio_err(NULL, NULL, PIO_EBADID, __FILE__, __LINE__);

    /* Turn of NC_UDF0 in the mode flag. */
    cmode = cmode & ~NC_UDF0;

    /* Find the IOTYPE from the mode flag. */
    if ((ret = find_iotype_from_omode(cmode, &iotype)))
        return pio_err(ios, NULL, ret, __FILE__, __LINE__);

    /* Add necessary structs to hold netcdf-4 file data. */
    if ((ret = nc4_file_list_add(ncid, path, cmode, NULL)))
        return ret;

    /* Create the file with PIO. The final parameter tests
     * createfile_int to accept the externally assigned ncid. */
    if ((ret = PIOc_createfile_int(diosysid, &ncid, &iotype, path, cmode, 1)))
        return ret;

    return PIO_NOERR;
}

/**
 * @internal Open a netCDF file with PIO.
 *
 * @param path The file name of the file.
 * @param mode The open mode flag.
 * @param basepe Ignored by this function.
 * @param chunksizehintp Ignored by this function.
 * @param parameters pointer to struct holding extra data (e.g. for
 * parallel I/O) layer. Ignored if NULL. Ignored by this function.
 * @param dispatch Pointer to the dispatch table for this file.
 * @param ncid
 *
 * @return ::NC_NOERR No error.
 * @return ::NC_EINVAL Invalid input.
 * @return ::NC_EHDFERR Error from HDF4 layer.
 * @return ::NC_ENOMEM Out of memory.
 * @author Ed Hartnett
 */
int
PIO_NCINT_open(const char *path, int mode, int basepe, size_t *chunksizehintp,
               void *parameters, const NC_Dispatch *dispatch, int ncid)
{
    int iotype;
    iosystem_desc_t *ios;  /* Pointer to io system information. */
    int ret;

    PLOG((1, "PIO_NCINT_open path = %s mode = %x", path, mode));

    /* Get the IO system info from the id. */
    if (!(ios = pio_get_iosystem_from_id(diosysid)))
        return pio_err(NULL, NULL, PIO_EBADID, __FILE__, __LINE__);

    /* Turn of NC_UDF0 in the mode flag. */
    mode = mode & ~NC_UDF0;

    /* Find the IOTYPE from the mode flag. */
    if ((ret = find_iotype_from_omode(mode, &iotype)))
        return pio_err(ios, NULL, ret, __FILE__, __LINE__);

    /* Add necessary structs to hold netcdf-4 file data. */
    if ((ret = nc4_file_list_add(ncid, path, mode, NULL)))
        return ret;

    /* Open the file with PIO. Tell openfile_retry to accept the
     * externally assigned ncid. */
    if ((ret = PIOc_openfile_retry(diosysid, &ncid, &iotype, path, mode, 0, 1)))
        return ret;

    return NC_NOERR;
}

/**
 * @internal This just calls nc_enddef, ignoring the extra parameters.
 *
 * @param ncid File and group ID.
 * @param h_minfree Ignored.
 * @param v_align Ignored.
 * @param v_minfree Ignored.
 * @param r_align Ignored.
 *
 * @return ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT__enddef(int ncid, size_t h_minfree, size_t v_align,
                  size_t v_minfree, size_t r_align)
{
    return PIOc_enddef(ncid);
}

/**
 * @internal Put the file back in redef mode. This is done
 * automatically for netcdf-4 files, if the user forgets.
 *
 * @param ncid File and group ID.
 *
 * @return ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_redef(int ncid)
{
    return PIOc_redef(ncid);
}

/**
 * @internal Flushes all buffers associated with the file, after
 * writing all changed metadata. This may only be called in data mode.
 *
 * @param ncid File and group ID.
 *
 * @return ::NC_NOERR No error.
 * @return ::NC_EBADID Bad ncid.
 * @return ::NC_EINDEFINE Classic model file is in define mode.
 * @author Ed Hartnett
 */
int
PIO_NCINT_sync(int ncid)
{
    return PIOc_sync(ncid);
}

int
PIO_NCINT_abort(int ncid)
{
    return PIO_NCINT_close(ncid, NULL);
}

/**
 * Close a file opened with PIO.
 *
 * @param ncid the ncid for the PIO file.
 * @param v ignored, use NULL.
 *
 * @return PIO_NOERR for success, error code otherwise.
 * @author Ed Hartnett
 */
int
PIO_NCINT_close(int ncid, void *v)
{
    int retval;

    /* Tell PIO to close the file. */
    if ((retval = PIOc_closefile(ncid)))
        return retval;

    /* Delete the group name. */
    if ((retval = nc4_file_list_del(ncid)))
        return retval;

    return retval;
}

/**
 * @internal Set fill mode.
 *
 * @param ncid File ID.
 * @param fillmode File mode.
 * @param old_modep Pointer that gets old mode. Ignored if NULL.
 *
 * @return ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_set_fill(int ncid, int fillmode, int *old_modep)
{
    return PIOc_set_fill(ncid, fillmode, old_modep);
}

/**
 * @internal Get the format (i.e. NC_FORMAT_UDF0) of a file opened
 * with PIO.
 *
 * @param ncid File ID (ignored).
 * @param formatp Pointer that gets the constant indicating format.

 * @return ::NC_NOERR No error.
 * @return ::NC_EBADID Bad ncid.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_format(int ncid, int *formatp)
{
    /* HDF4 is the format. */
    if (formatp)
        *formatp = NC_FORMATX_UDF0;

    return NC_NOERR;
}

/**
 * @internal Return the extended format (i.e. the dispatch model),
 * plus the mode associated with an open file.
 *
 * @param ncid File ID.
 * @param formatp a pointer that gets the extended format. PIO files
 * will always get NC_FORMATX_UDF0.
 * @param modep a pointer that gets the open/create mode associated with
 * this file. Ignored if NULL.

 * @return ::NC_NOERR No error.
 * @return ::NC_EBADID Bad ncid.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_format_extended(int ncid, int *formatp, int *modep)
{
    int my_mode;
    int retval;

    PLOG((2, "%s: ncid 0x%x", __func__, ncid));

    if ((retval = nc4_file_list_get(ncid, NULL, &my_mode, NULL)))
        return NC_EBADID;

    if (modep)
        *modep = my_mode|NC_UDF0;

    if (formatp)
        *formatp = NC_FORMATX_UDF0;

    return NC_NOERR;
}

/**
 * @internal Learn number of dimensions, variables, global attributes,
 * and the ID of the first unlimited dimension (if any).
 *
 * @note It's possible for any of these pointers to be NULL, in which
 * case don't try to figure out that value.
 *
 * @param ncid File and group ID.
 * @param ndimsp Pointer that gets number of dimensions.
 * @param nvarsp Pointer that gets number of variables.
 * @param nattsp Pointer that gets number of global attributes.
 * @param unlimdimidp Pointer that gets first unlimited dimension ID,
 * or -1 if there are no unlimied dimensions.
 *
 * @return ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq(int ncid, int *ndimsp, int *nvarsp, int *nattsp, int *unlimdimidp)
{
    return PIOc_inq(ncid, ndimsp, nvarsp, nattsp, unlimdimidp);
}

/**
 * @internal Get the name and size of a type. For strings, 1 is
 * returned. For VLEN the base type len is returned.
 *
 * @param ncid File and group ID.
 * @param typeid1 Type ID.
 * @param name Gets the name of the type.
 * @param size Gets the size of one element of the type in bytes.
 *
 * @return ::NC_NOERR No error.
 * @return ::NC_EBADID Bad ncid.
 * @return ::NC_EBADTYPE Type not found.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_type(int ncid, nc_type typeid1, char *name, size_t *size)
{
    return PIOc_inq_type(ncid, typeid1, name, (PIO_Offset *)size);
}

int
PIO_NCINT_def_dim(int ncid, const char *name, size_t len, int *idp)
{
    return PIOc_def_dim(ncid, name, len, idp);
}

/**
 * @internal Given dim name, find its id.
 *
 * @param ncid File and group ID.
 * @param name Name of the dimension to find.
 * @param idp Pointer that gets dimension ID.
 *
 * @return ::NC_NOERR No error.
 * @return ::NC_EBADID Bad ncid.
 * @return ::NC_EBADDIM Dimension not found.
 * @return ::NC_EINVAL Invalid input. Name must be provided.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_dimid(int ncid, const char *name, int *idp)
{
    return PIOc_inq_dimid(ncid, name, idp);
}

/**
 * @internal Find out name and len of a dim. For an unlimited
 * dimension, the length is the largest length so far written. If the
 * name of lenp pointers are NULL, they will be ignored.
 *
 * @param ncid File and group ID.
 * @param dimid Dimension ID.
 * @param name Pointer that gets name of the dimension.
 * @param lenp Pointer that gets length of dimension.
 *
 * @return ::NC_NOERR No error.
 * @return ::NC_EBADID Bad ncid.
 * @return ::NC_EDIMSIZE Dimension length too large.
 * @return ::NC_EBADDIM Dimension not found.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_dim(int ncid, int dimid, char *name, size_t *lenp)
{
    return PIOc_inq_dim(ncid, dimid, name, (PIO_Offset *)lenp);
}

/**
 * @internal Netcdf-4 files might have more than one unlimited
 * dimension, but return the first one anyway.
 *
 * @note that this code is inconsistent with nc_inq
 *
 * @param ncid File and group ID.
 * @param unlimdimidp Pointer that gets ID of first unlimited
 * dimension, or -1.
 *
 * @return ::NC_NOERR No error.
 * @return ::NC_EBADID Bad ncid.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_unlimdim(int ncid, int *unlimdimidp)
{
    return PIOc_inq_unlimdim(ncid, unlimdimidp);
}

/**
 * @internal Rename a dimension, for those who like to prevaricate.
 *
 * @note If we're not in define mode, new name must be of equal or
 * less size, if strict nc3 rules are in effect for this file. But we
 * don't check this because reproducing the exact classic behavior
 * would be too difficult. See github issue #1340.
 *
 * @param ncid File and group ID.
 * @param dimid Dimension ID.
 * @param name New dimension name.
 *
 * @return 0 on success, error code otherwise.
 * @author Ed Hartnett
 */
int
PIO_NCINT_rename_dim(int ncid, int dimid, const char *name)
{
    return PIOc_rename_dim(ncid, dimid, name);
}

/**
 * @internal Learn about an att. All the nc4 nc_inq_ functions just
 * call nc4_get_att to get the metadata on an attribute.
 *
 * @param ncid File and group ID.
 * @param varid Variable ID.
 * @param name Name of attribute.
 * @param xtypep Pointer that gets type of attribute.
 * @param lenp Pointer that gets length of attribute data array.
 *
 * @return ::NC_NOERR No error.
 * @return ::NC_EBADID Bad ncid.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_att(int ncid, int varid, const char *name, nc_type *xtypep,
                  size_t *lenp)
{
    return PIOc_inq_att(ncid, varid, name, xtypep, (PIO_Offset *)lenp);
}

/**
 * @internal Learn an attnum, given a name.
 *
 * @param ncid File and group ID.
 * @param varid Variable ID.
 * @param name Name of attribute.
 * @param attnump Pointer that gets the attribute index number.
 *
 * @return ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_attid(int ncid, int varid, const char *name, int *attnump)
{
    return PIOc_inq_attid(ncid, varid, name, attnump);
}

/**
 * @internal Given an attnum, find the att's name.
 *
 * @param ncid File and group ID.
 * @param varid Variable ID.
 * @param attnum The index number of the attribute.
 * @param name Pointer that gets name of attrribute.
 *
 * @return ::NC_NOERR No error.
 * @return ::NC_EBADID Bad ncid.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_attname(int ncid, int varid, int attnum, char *name)
{
    return PIOc_inq_attname(ncid, varid, attnum, name);
}

/**
 * @internal I think all atts should be named the exact same thing, to
 * avoid confusion!
 *
 * @param ncid File and group ID.
 * @param varid Variable ID.
 * @param name Name of attribute.
 * @param newname New name for attribute.
 *
 * @return ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_rename_att(int ncid, int varid, const char *name, const char *newname)
{
    return PIOc_rename_att(ncid, varid, name, newname);
}

/**
 * @internal Delete an att. Rub it out. Push the button on
 * it. Liquidate it. Bump it off. Take it for a one-way
 * ride. Terminate it.
 *
 * @param ncid File and group ID.
 * @param varid Variable ID.
 * @param name Name of attribute to delete.
 *
 * @return ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_del_att(int ncid, int varid, const char *name)
{
    return PIOc_del_att(ncid, varid, name);
}

/**
 * @internal Get an attribute.
 *
 * @param ncid File and group ID.
 * @param varid Variable ID.
 * @param name Name of attribute.
 * @param value Pointer that gets attribute data.
 * @param memtype The type the data should be converted to as it is
 * read.
 *
 * @return ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_get_att(int ncid, int varid, const char *name, void *value,
                  nc_type memtype)
{
    return PIOc_get_att_tc(ncid, varid, name, memtype, value);
}

/**
 * @internal Write an attribute.
 *
 * @return ::NC_EPERM Not allowed.
 * @author Ed Hartnett
 */
int
PIO_NCINT_put_att(int ncid, int varid, const char *name, nc_type file_type,
                  size_t len, const void *data, nc_type mem_type)
{
    return PIOc_put_att_tc(ncid, varid, name, file_type, (PIO_Offset)len,
                           mem_type,  data);
}

int
PIO_NCINT_def_var(int ncid, const char *name, nc_type xtype, int ndims,
                  const int *dimidsp, int *varidp)
{
    return PIOc_def_var(ncid, name, xtype, ndims, dimidsp, varidp);
}

/**
 * @internal Find the ID of a variable, from the name. This function
 * is called by nc_inq_varid().
 *
 * @param ncid File ID.
 * @param name Name of the variable.
 * @param varidp Gets variable ID.

 * @returns ::NC_NOERR No error.
 * @returns ::NC_EBADID Bad ncid.
 * @returns ::NC_ENOTVAR Bad variable ID.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_varid(int ncid, const char *name, int *varidp)
{
    return PIOc_inq_varid(ncid, name, varidp);
}

/**
 * @internal Rename a var to "bubba," for example. This is called by
 * nc_rename_var() for netCDF-4 files. This results in complexities
 * when coordinate variables are involved.

 * Whenever a var has the same name as a dim, and also uses that dim
 * as its first dimension, then that var is aid to be a coordinate
 * variable for that dimensions. Coordinate variables are represented
 * in the HDF5 by making them dimscales. Dimensions without coordinate
 * vars are represented by datasets which are dimscales, but have a
 * special attribute marking them as dimscales without associated
 * coordinate variables.
 *
 * When a var is renamed, we must detect whether it has become a
 * coordinate var (by being renamed to the same name as a dim that is
 * also its first dimension), or whether it is no longer a coordinate
 * var. These cause flags to be set in NC_VAR_INFO_T which are used at
 * enddef time to make changes in the HDF5 file.
 *
 * @param ncid File ID.
 * @param varid Variable ID
 * @param name New name of the variable.
 *
 * @returns ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_rename_var(int ncid, int varid, const char *name)
{
    return PIOc_rename_var(ncid, varid, name);
}

/**
 * @internal Read an array of data to a variable.
 *
 * @param ncid File ID.
 * @param varid Variable ID.
 * @param startp Array of start indices.
 * @param countp Array of counts.
 * @param op pointer that gets the data.
 * @param memtype The type of these data in memory.
 *
 * @returns ::NC_NOERR for success
 * @author Ed Hartnett
 */
int
PIO_NCINT_get_vara(int ncid, int varid, const size_t *start,
                   const size_t *count, void *value, nc_type t)
{
    return PIOc_get_vars_tc(ncid, varid, (PIO_Offset *)start,
                            (PIO_Offset *)count, NULL, t, value);
}

/**
 * @internal Write an array of data to a variable. This is called by
 * nc_put_vara() and other nc_put_vara_* functions, for netCDF-4
 * files.
 *
 * @param ncid File ID.
 * @param varid Variable ID.
 * @param startp Array of start indices.
 * @param countp Array of counts.
 * @param op pointer that gets the data.
 * @param memtype The type of these data in memory.
 *
 * @returns ::NC_NOERR for success
 * @author Ed Hartnett
 */
int
PIO_NCINT_put_vara(int ncid, int varid, const size_t *startp,
                   const size_t *countp, const void *op, int memtype)
{
    return PIOc_put_vars_tc(ncid, varid, (PIO_Offset *)startp,
                            (PIO_Offset *)countp, NULL, memtype, op);
}

/**
 * @internal Read a strided array of data from a variable. This is
 * called by nc_get_vars() for netCDF-4 files, as well as all the
 * other nc_get_vars_* functions.
 *
 * @param ncid File ID.
 * @param varid Variable ID.
 * @param startp Array of start indices. Must be provided for
 * non-scalar vars.
 * @param countp Array of counts. Will default to counts of extent of
 * dimension if NULL.
 * @param stridep Array of strides. Will default to strides of 1 if
 * NULL.
 * @param data The data to be written.
 * @param mem_nc_type The type of the data in memory. (Convert to this
 * type from file type.)
 *
 * @returns ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_get_vars(int ncid, int varid, const size_t *startp, const size_t *countp,
                   const ptrdiff_t *stridep, void *data, nc_type mem_nc_type)
{
    return PIOc_get_vars_tc(ncid, varid, (PIO_Offset *)startp,
                            (PIO_Offset *)countp, (PIO_Offset *)stridep,
                            mem_nc_type, data);
}

/**
 * @internal Write a strided array of data to a variable. This is
 * called by nc_put_vars() and other nc_put_vars_* functions, for
 * netCDF-4 files. Also the nc_put_vara() calls end up calling this
 * with a NULL stride parameter.
 *
 * @param ncid File ID.
 * @param varid Variable ID.
 * @param startp Array of start indices. Must always be provided by
 * caller for non-scalar vars.
 * @param countp Array of counts. Will default to counts of full
 * dimension size if NULL.
 * @param stridep Array of strides. Will default to strides of 1 if
 * NULL.
 * @param data The data to be written.
 * @param mem_nc_type The type of the data in memory.
 *
 * @returns ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_put_vars(int ncid, int varid, const size_t *startp, const size_t *countp,
                   const ptrdiff_t *stridep, const void *data, nc_type mem_nc_type)
{
    return PIOc_put_vars_tc(ncid, varid, (PIO_Offset *)startp,
                            (PIO_Offset *)countp, (PIO_Offset *)stridep,
                            mem_nc_type, data);
}
/**
 * @internal Get all the information about a variable. Pass NULL for
 * whatever you don't care about.
 *
 * @param ncid File ID.
 * @param varid Variable ID.
 * @param name Gets name.
 * @param xtypep Gets type.
 * @param ndimsp Gets number of dims.
 * @param dimidsp Gets array of dim IDs.
 * @param nattsp Gets number of attributes.
 * @param shufflep Gets shuffle setting.
 * @param deflatep Gets deflate setting.
 * @param deflate_levelp Gets deflate level.
 * @param fletcher32p Gets fletcher32 setting.
 * @param contiguousp Gets contiguous setting.
 * @param chunksizesp Gets chunksizes.
 * @param no_fill Gets fill mode.
 * @param fill_valuep Gets fill value.
 * @param endiannessp Gets one of ::NC_ENDIAN_BIG ::NC_ENDIAN_LITTLE
 * ::NC_ENDIAN_NATIVE
 * @param idp Pointer to memory to store filter id.
 * @param nparamsp Pointer to memory to store filter parameter count.
 * @param params Pointer to vector of unsigned integers into which
 * to store filter parameters.
 *
 * @returns ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_var_all(int ncid, int varid, char *name, nc_type *xtypep,
                      int *ndimsp, int *dimidsp, int *nattsp,
                      int *shufflep, int *deflatep, int *deflate_levelp,
                      int *fletcher32p, int *contiguousp, size_t *chunksizesp,
                      int *no_fill, void *fill_valuep, int *endiannessp,
                      unsigned int *idp, size_t *nparamsp, unsigned int *params)
{
    int ret;

    ret = PIOc_inq_var(ncid, varid, name, xtypep, ndimsp, dimidsp, nattsp);

    if (!ret)
	ret = PIOc_inq_var_chunking(ncid, varid, contiguousp, (MPI_Offset *)chunksizesp);

    if (!ret)
	ret = PIOc_inq_var_deflate(ncid, varid, shufflep, deflatep, deflate_levelp);

    if (!ret)
	ret = PIOc_inq_var_endian(ncid, varid, endiannessp);
    
    return ret;
}

/**
 * @internal This functions sets fill value and no_fill mode for a
 * netCDF-4 variable. It is called by nc_def_var_fill().
 *
 * @note All pointer parameters may be NULL, in which case they are ignored.
 * @param ncid File ID.
 * @param varid Variable ID.
 * @param no_fill No_fill setting.
 * @param fill_value Pointer to fill value.
 *
 * @returns ::NC_NOERR for success
 * @author Ed Hartnett
 */
int
PIO_NCINT_def_var_fill(int ncid, int varid, int no_fill, const void *fill_value)
{
    return PIOc_def_var_fill(ncid, varid, no_fill, fill_value);
}

/**
 * @internal Returns an array of unlimited dimension ids.The user can
 * get the number of unlimited dimensions by first calling this with
 * NULL for the second pointer.
 *
 * @param ncid File and group ID.
 * @param nunlimdimsp Pointer that gets the number of unlimited
 * dimensions. Ignored if NULL.
 * @param unlimdimidsp Pointer that gets arrray of unlimited dimension
 * ID. Ignored if NULL.
 *
 * @return ::NC_NOERR No error.
 * @return ::NC_EBADID Bad ncid.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_unlimdims(int ncid, int *nunlimdimsp, int *unlimdimidsp)
{
    return PIOc_inq_unlimdims(ncid, nunlimdimsp, unlimdimidsp);
}

/**
 * @internal Does nothing.
 *
 * @param i Ignored
 *
 * @return ::NC_NOERR No error.
 * @author Ed Hartnett
 */
int
PIO_NCINT_show_metadata(int i)
{
    return NC_NOERR;
}

/**
 * @internal Determine if two types are equal.
 *
 * @param ncid1 First file/group ID.
 * @param typeid1 First type ID.
 * @param ncid2 Second file/group ID.
 * @param typeid2 Second type ID.
 * @param equalp Pointer that will get 1 if the two types are equal.
 *
 * @return ::NC_NOERR No error.
 * @return ::NC_EBADID Bad ncid.
 * @return ::NC_EBADTYPE Type not found.
 * @return ::NC_EINVAL Invalid type.
 * @author Ed Hartnett
 */
int
PIO_NCINT_inq_type_equal(int ncid1, nc_type typeid1, int ncid2,
                         nc_type typeid2, int *equalp)
{
    if (equalp)
        *equalp = typeid1 == typeid2 ? 1 : 0;
    return NC_NOERR;
}

/**
 * @internal This functions sets deflate settings for a
 * netCDF-4 variable. It is called by nc_def_var_deflate().
 *
 * @param ncid the ncid of the open file.
 * @param varid the ID of the variable.
 * @param shuffle non-zero to turn on shuffle filter.
 * @param deflate non-zero to turn on zlib compression for this
 * variable.
 * @param deflate_level 1 to 9, with 1 being faster and 9 being more
 * compressed.
 *
 * @returns ::NC_NOERR for success
 * @author Ed Hartnett
 */
int
PIO_NCINT_def_var_deflate(int ncid, int varid, int shuffle, int deflate,
			  int deflate_level)
{
    return PIOc_def_var_deflate(ncid, varid, shuffle, deflate, deflate_level);
}

/**
 * @internal Set chunksizes for a variable.
 *
 * This function only applies to netCDF-4 files. When used with netCDF
 * classic files, the error PIO_ENOTNC4 will be returned.
 *
 * Chunksizes have important performance repercussions. NetCDF
 * attempts to choose sensible chunk sizes by default, but for best
 * performance check chunking against access patterns.
 *
 * See the <a
 * href="http://www.unidata.ucar.edu/software/netcdf/docs/group__variables.html">netCDF
 * variable documentation</a> for details about the operation of this
 * function.
 *
 * @param ncid the ncid of the open file.
 * @param varid the ID of the variable to set chunksizes for.
 * @param storage NC_CONTIGUOUS or NC_CHUNKED.
 * @param chunksizesp an array of chunksizes. Must have a chunksize for
 * every variable dimension.
 * @return PIO_NOERR for success, otherwise an error code.
 * @ingroup PIO_def_var_c
 * @author Ed Hartnett
 */
int
PIO_NCINT_def_var_chunking(int ncid, int varid, int storage, const size_t *chunksizesp)
{
    return PIOc_def_var_chunking(ncid, varid, storage, (const PIO_Offset *)chunksizesp);
}
