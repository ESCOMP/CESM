/**
 * @file
 * This header file contains the prototypes for the PIO netCDF
 * integration layer.
 *
 * Ed Hartnett
 */
#ifndef _NCINTDISPATCH_H
#define _NCINTDISPATCH_H

#include "config.h"
#include <netcdf_dispatch.h>

#if defined(__cplusplus)
extern "C" {
#endif

    extern int
    PIO_NCINT_initialize(void);

    extern int
    PIO_NCINT_open(const char *path, int mode, int basepe, size_t *chunksizehintp,
                  void *parameters, const NC_Dispatch *, int);

    extern int
    PIO_NCINT_create(const char* path, int cmode, size_t initialsz, int basepe,
                    size_t *chunksizehintp, void *parameters,
                    const NC_Dispatch *dispatch, int);

    extern int
    PIO_NCINT_def_var(int ncid, const char *name, nc_type xtype, int ndims,
                     const int *dimidsp, int *varidp);

    extern int
    PIO_NCINT_def_dim(int ncid, const char *name, size_t len, int *idp);

    extern int
    PIO_NCINT_sync(int ncid);

    extern int
    PIO_NCINT_redef(int ncid);

    extern int
    PIO_NCINT__enddef(int ncid, size_t h_minfree, size_t v_align,
                      size_t v_minfree, size_t r_align);

    extern int
    PIO_NCINT_set_fill(int ncid, int fillmode, int *old_modep);

    extern int
    PIO_NCINT_abort(int ncid);

    extern int
    PIO_NCINT_close(int ncid, void *ignore);

    extern int
    PIO_NCINT_inq_format(int ncid, int *formatp);

    extern int
    PIO_NCINT_inq_format_extended(int ncid, int *formatp, int *modep);

    extern int
    PIO_NCINT_inq(int ncid, int *ndimsp, int *nvarsp, int *nattsp, int *unlimdimidp);

    extern int
    PIO_NCINT_inq_type(int ncid, nc_type typeid1, char *name, size_t *size);

    extern int
    PIO_NCINT_inq_dimid(int ncid, const char *name, int *idp);

    extern int
    PIO_NCINT_inq_dim(int ncid, int dimid, char *name, size_t *lenp);

    extern int
    PIO_NCINT_inq_unlimdim(int ncid, int *unlimdimidp);

    extern int
    PIO_NCINT_rename_dim(int ncid, int dimid, const char *name);

    extern int
    PIO_NCINT_inq_att(int ncid, int varid, const char *name, nc_type *xtypep,
                      size_t *lenp);

    extern int
    PIO_NCINT_inq_attid(int ncid, int varid, const char *name, int *attnump);

    extern int
    PIO_NCINT_inq_attname(int ncid, int varid, int attnum, char *name);

    extern int
    PIO_NCINT_rename_att(int ncid, int varid, const char *name, const char *newname);

    extern int
    PIO_NCINT_del_att(int ncid, int varid, const char *name);

    extern int
    PIO_NCINT_get_att(int ncid, int varid, const char *name, void *value,
                      nc_type memtype);

    extern int
    PIO_NCINT_put_att(int ncid, int varid, const char *name, nc_type file_type,
                      size_t len, const void *data, nc_type mem_type);

    extern int
    PIO_NCINT_inq_varid(int ncid, const char *name, int *varidp);

    extern int
    PIO_NCINT_rename_var(int ncid, int varid, const char *name);

    extern int
    PIO_NCINT_get_vara(int ncid, int varid, const size_t *start, const size_t *count,
                       void *value, nc_type t);

    extern int
    PIO_NCINT_put_vara(int ncid, int varid, const size_t *startp,
                       const size_t *countp, const void *op, int memtype);

    extern int
    PIO_NCINT_get_vars(int ncid, int varid, const size_t *startp, const size_t *countp,
                       const ptrdiff_t *stridep, void *data, nc_type mem_nc_type);

    extern int
    PIO_NCINT_put_vars(int ncid, int varid, const size_t *startp, const size_t *countp,
                       const ptrdiff_t *stridep, const void *data, nc_type mem_nc_type);


    extern int
    PIO_NCINT_inq_var_all(int ncid, int varid, char *name, nc_type *xtypep,
                          int *ndimsp, int *dimidsp, int *nattsp,
                          int *shufflep, int *deflatep, int *deflate_levelp,
                          int *fletcher32p, int *contiguousp, size_t *chunksizesp,
                          int *no_fill, void *fill_valuep, int *endiannessp,
                          unsigned int *idp, size_t *nparamsp, unsigned int *params);

    extern int
    PIO_NCINT_def_var_fill(int ncid, int varid, int no_fill, const void *fill_value);

    extern int
    PIO_NCINT_inq_unlimdims(int ncid, int *nunlimdimsp, int *unlimdimidsp);

    extern int
    PIO_NCINT_show_metadata(int i);

    extern int
    PIO_NCINT_inq_type_equal(int ncid1, nc_type typeid1, int ncid2,
                             nc_type typeid2, int *equalp);

    extern int
    PIO_NCINT_def_var_deflate(int ncid, int varid, int shuffle, int deflate,
			      int deflate_level);

    extern int
    PIO_NCINT_def_var_chunking(int ncid, int varid, int storage, const size_t *chunksizesp);


#if defined(__cplusplus)
}
#endif

#endif /*_NCINTDISPATCH_H */
