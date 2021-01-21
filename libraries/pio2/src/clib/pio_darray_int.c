/**
 * @file
 *
 * Private functions to help read and write distributed arrays in PIO.
 *
 * When arrays are distributed, each processor holds some of the
 * array. Only by combining the distributed arrays from all processor
 * can the full array be obtained.
 *
 * @author Jim Edwards
 */

#include <config.h>
#include <pio.h>
#include <pio_internal.h>

#if USE_VARD
#define USE_VARD_READ 1
#define USE_VARD_WRITE 1
#endif

/** 10MB default limit. */
extern PIO_Offset pio_buffer_size_limit;

/** Initial size of compute buffer. */
long pio_cnbuffer_limit = 33554432;

/** Global buffer pool pointer. */
extern void *CN_bpool;

/** Maximum buffer usage. */
extern PIO_Offset maxusage;

/**
 * Handler for freeing the memory buffer pool.
 *
 * @param p pointer to the memory buffer pool.
 * @author Jim Edwards
 */
void
bpool_free(void *p)
{
    free(p);
    if(p == CN_bpool){
        CN_bpool = NULL;
    }
}

#if USE_VARD
/**
 * Get the length of dimension 0.
 *
 * @param file pointer to the file descriptor.
 * @param iosdesc pointer to the iosystem descriptor.
 * @param varid variable ID.
 * @param fndims number of dimensions in the file.
 * @param gdim0 pointer that gets gdim0.
 * @returns 0 for success, error code otherwise.
 * @author Jim Edwards
 */
int
get_gdim0(file_desc_t *file,io_desc_t *iodesc, int varid, int fndims,
          MPI_Offset *gdim0)
{
    int ierr = PIO_NOERR;

    *gdim0 = 0;
    if (file->iotype == PIO_IOTYPE_PNETCDF && iodesc->ndims < fndims)
    {
        int numunlimdims;

        /* We need to confirm the file has an unlimited dimension and
           if it doesn't we need to find the extent of the first
           variable dimension. */
        PLOG((3,"look for numunlimdims"));
        if ((ierr = PIOc_inq_unlimdims(file->pio_ncid, &numunlimdims, NULL)))
            return check_netcdf(file, ierr, __FILE__, __LINE__);
        PLOG((3,"numunlimdims = %d", numunlimdims));
        if (numunlimdims <= 0)
        {
            int dimids[fndims];
            if ((ierr = PIOc_inq_vardimid(file->pio_ncid, varid, dimids)))
                return check_netcdf(file, ierr, __FILE__, __LINE__);
            if ((ierr = PIOc_inq_dimlen(file->pio_ncid, dimids[0], gdim0)))
                return check_netcdf(file, ierr, __FILE__, __LINE__);
        }
    }
    PLOG((3,"gdim0 = %d",*gdim0));
    return ierr;
}


/**
 * Get the MPI data type of vard.
 *
 * @param iosdesc pointer to the iosystem descriptor.
 * @param gdim0
 * @param unlimdimoffset
 * @param rrcnt
 * @param ndims the number of dimensions in the decomposition.
 * @param fndims the number of dimensions in the file.
 * @param varid variable ID.
 * @param fndims number of dimensions in the file.
 * @param frame the record number.
 * @param startlist
 * @param countlist
 * @param filetype a pointer that gets the MPI data type.
 * @returns 0 for success, error code otherwise.
 * @author Jim Edwards
 */
static
int get_vard_mpidatatype(io_desc_t *iodesc, MPI_Offset gdim0, PIO_Offset unlimdimoffset,
                         int rrcnt, int ndims, int fndims,
                         int frame, PIO_Offset **startlist, PIO_Offset **countlist,
                         MPI_Datatype *filetype)
{

    int sa_ndims;
    int gdims[fndims];
    int dim_offset;
    int mpierr;
    MPI_Aint displacements[rrcnt];
    int blocklengths[rrcnt];
    MPI_Datatype subarray[rrcnt];

    /* preserve the value of unlimdimoffset, as it may be changed */
    PIO_Offset _unlimdimoffset = unlimdimoffset;

    *filetype = MPI_DATATYPE_NULL;

    if(rrcnt == 0)
        return PIO_NOERR;

    for ( int rc=0; rc<rrcnt; rc++)
    {
        displacements[rc] = 0;
        blocklengths[rc] = 1;
        subarray[rc] = MPI_DATATYPE_NULL;
    }
    if(fndims > ndims)
    {
        if ( gdim0 > 0)
        {
            gdims[0] = gdim0;
            sa_ndims = fndims;
            dim_offset = 0;
            for (int i=1; i < fndims; i++)
                gdims[i] = iodesc->dimlen[i-1];
        }
        else
        {
            sa_ndims = ndims;
            dim_offset = 1;
            for (int i=0; i < ndims; i++)
                gdims[i] = iodesc->dimlen[i];
        }
    }
    else
    {
        sa_ndims = fndims;
        dim_offset = 0;
        for (int i=0; i < fndims; i++)
            gdims[i] = iodesc->dimlen[i];
    }

    int true_rrcnt=-1; /* true number of contiguous requests */
    MPI_Aint prev_end=-1; /* end offset of rc-1 request */
    for( int rc=0; rc<rrcnt; rc++)
    {
        int sacount[fndims];
        int sastart[fndims];
        for (int i=dim_offset; i< fndims; i++)
        {
            sacount[i-dim_offset] = (int) countlist[rc][i];
            sastart[i-dim_offset] = (int) startlist[rc][i];
        }
        if(gdim0 > 0)
        {
            unlimdimoffset = gdim0;
            sastart[0] = max(0, frame);
            displacements[rc]=0;
        }
        else
            displacements[rc] = unlimdimoffset * max(0, frame);

        /* Check whether this request is actually contiguous. If contiguous,
         * we do not need to create an MPI derived datatype.
         */
        int blocklen=1, isContig=1, warnContig=0;
        MPI_Aint disp=0, shape=iodesc->mpitype_size;
        for (int i=sa_ndims-1; i>=0; i--)
        {
            if (isContig) {
                /* blocklen is the amount of this request, rc */
                blocklen *= sacount[i];
                /* disp is the flattened starting array index */
                disp += sastart[i] * shape;
                /* shape is the dimension product from sa_ndims-1 to i */
                shape *= gdims[i];

                if (warnContig == 0) {
                    if (sacount[i] < gdims[i])
                        /* first i detected to access partial dimension. If this
                         * one is contiguous, the remaining sacount[i-1 ... 0]
                         * must all == 1 */
                        warnContig = 1; /* possible non-contiguos */
                }
                else if (sacount[i] != 1) {
                    isContig = 0;
                    break; /* loop i */
                }
            }
        }
        /* if this is a record variable, add the gap of record size */
        disp += _unlimdimoffset * max(0, frame);

#if PIO_ENABLE_LOGGING
        for (int i=0; i< sa_ndims; i++)
            PLOG((3, "vard: sastart[%d]=%d sacount[%d]=%d gdims[%d]=%d %ld %ld displacement = %ld un %d",
                  i,sastart[i], i,sacount[i], i, gdims[i], startlist[rc][i], countlist[rc][i], displacements[rc], unlimdimoffset));
#endif
        if (isContig) { /* this request rc is contiguous, no need to create a new MPI datatype */
            if (prev_end == disp) {
                /* this request rc can be coalesced into the previous
                 * displacements and blocklengths.
                 */
                blocklengths[true_rrcnt] += blocklen;
                prev_end += blocklen;
            }
            else {
                /* this request cannot be coalesced with the previous one */
                true_rrcnt++;
                subarray[true_rrcnt] = iodesc->mpitype;
                displacements[true_rrcnt] = disp;
                blocklengths[true_rrcnt] = blocklen;
                prev_end = disp + blocklen;
            }
        }
        else { /* request rc is not contiguous, must create a new MPI datatype */
            true_rrcnt++;
            if((mpierr = MPI_Type_create_subarray(sa_ndims, gdims,
                                                  sacount, sastart,MPI_ORDER_C
                                                  ,iodesc->mpitype, subarray + true_rrcnt)))
                return check_mpi(NULL, NULL, mpierr, __FILE__, __LINE__);

            if((mpierr = MPI_Type_commit(subarray + true_rrcnt)))
                return check_mpi(NULL, NULL, mpierr, __FILE__, __LINE__);
        }

#if PIO_ENABLE_LOGGING
        PLOG((3,"vard: blocklengths[%d]=%d displacement[%d]=%ld unlimdimoffset=%ld",rc,blocklengths[rc], rc, displacements[rc], unlimdimoffset));
#endif

    }
    true_rrcnt++;

    /* concatenate all MPI datatypes into filetype */
    if((mpierr = MPI_Type_create_struct(true_rrcnt, blocklengths, displacements, subarray, filetype)))
        return check_mpi(NULL, NULL, mpierr, __FILE__, __LINE__);

    if((mpierr = MPI_Type_commit(filetype)))
        return check_mpi(NULL, NULL, mpierr, __FILE__, __LINE__);

    for( int rc=0; rc<true_rrcnt; rc++)
        if (subarray[rc] != MPI_DATATYPE_NULL && subarray[rc] != iodesc->mpitype &&
            (mpierr = MPI_Type_free(subarray + rc)))
            return check_mpi(NULL, NULL, mpierr, __FILE__, __LINE__);

    return PIO_NOERR;
}

#endif

/**
 * Fill start/count arrays for write_darray_multi_par(). This is an
 * internal function.
 *
 * @param ndims the number of dims in the decomposition.
 * @param fndims the number of dims in the file.
 * @param vdesc pointer to the var_desc_t info.
 * @param region pointer to a region.
 * @param frame array of record values.
 * @param start an already-allocated array which gets the start
 * values.
 * @param count an already-allocated array which gets the count
 * values.
 * @return 0 for success, error code otherwise.
 * @ingroup PIO_write_darray_c
 * @author Ed Hartnett
 */
int
find_start_count(int ndims, int fndims, var_desc_t *vdesc,
                 io_region *region, const int *frame, size_t *start,
                 size_t *count)
{
    /* Init start/count arrays to zero. */
    for (int i = 0; i < fndims; i++)
    {
        start[i] = 0;
        count[i] = 0;
    }

    if (region)
    {
        if (vdesc->record >= 0)
        {
            /* This is a record based multidimensional
             * array. Figure out start/count for all but the
             * record dimension (dimid 0). */
            for (int i = fndims - ndims; i < fndims; i++)
            {
                start[i] = region->start[i - (fndims - ndims)];
                count[i] = region->count[i - (fndims - ndims)];
            }

            /* Now figure out start/count for record dimension. */
            if (fndims > 1 && ndims < fndims && count[1] > 0)
            {
                count[0] = 1;
                start[0] = frame[0];
            }
            else if (fndims == ndims)
            {
                /* In some cases the unlimited dim is not treated as
                   the pio record dim */
                start[0] += vdesc->record;
            }
        }
        else
        {
            /* This is a non record variable. */
            for (int i = 0; i < ndims; i++)
            {
                start[i] = region->start[i];
                count[i] = region->count[i];
            }
        }

#if PIO_ENABLE_LOGGING
        /* Log arrays for debug purposes. */
        for (int i = 0; i < ndims; i++)
            PLOG((3, "start[%d] = %d count[%d] = %d", i, start[i], i, count[i]));
#endif /* PIO_ENABLE_LOGGING */
    }

    return PIO_NOERR;
}

/**
 * Write a set of one or more aggregated arrays to output file. This
 * function is only used with parallel-netcdf and netcdf-4 parallel
 * iotypes. Serial io types use write_darray_multi_serial().
 *
 * @param file a pointer to the open file descriptor for the file
 * that will be written to
 * @param nvars the number of variables to be written with this
 * decomposition.
 * @param fndims number of dimensions of this var in the file.
 * @param varids an array of the variable ids to be written.
 * @param iodesc pointer to the io_desc_t info.
 * @param fill Non-zero if this write is fill data.
 * @param frame the record dimension for each of the nvars variables
 * in iobuf. NULL if this iodesc contains non-record vars.
 * @return 0 for success, error code otherwise.
 * @ingroup PIO_write_darray_c
 * @author Jim Edwards, Ed Hartnett
 */
int
write_darray_multi_par(file_desc_t *file, int nvars, int fndims, const int *varids,
                       io_desc_t *iodesc, int fill, const int *frame)
{
    iosystem_desc_t *ios;  /* Pointer to io system information. */
    var_desc_t *vdesc;    /* Pointer to var info struct. */
    int dsize;             /* Data size (for one region). */
    int ierr = PIO_NOERR;
#if USE_VARD_WRITE
    PIO_Offset gdim0;  /* global size of first dimension if no unlimited dimension and ndims<fndims */
    bool use_vard=true;
    gdim0 = 0;
#endif
    /* Check inputs. */
    pioassert(file && file->iosystem && varids && varids[0] >= 0 && varids[0] <= PIO_MAX_VARS &&
              iodesc, "invalid input", __FILE__, __LINE__);

    PLOG((1, "write_darray_multi_par nvars = %d iodesc->ndims = %d iodesc->mpitype = %d "
          "iodesc->maxregions = %d iodesc->llen = %d", nvars, iodesc->ndims,
          iodesc->mpitype, iodesc->maxregions, iodesc->llen));

#ifdef TIMING
    /* Start timer if desired. */
    if ((ierr = pio_start_timer("PIO:write_darray_multi_par")))
        return pio_err(NULL, NULL, ierr, __FILE__, __LINE__);
#endif /* TIMING */

    /* Get pointer to iosystem. */
    ios = file->iosystem;

    /* Point to var description scruct for first var. */
    if ((ierr = get_var_desc(varids[0], &file->varlist, &vdesc)))
        return pio_err(NULL, file, ierr, __FILE__, __LINE__);

    /* Set these differently for data and fill writing. */
    int num_regions = fill ? iodesc->maxfillregions: iodesc->maxregions;
    io_region *region = fill ? iodesc->fillregion : iodesc->firstregion;
    PIO_Offset llen = fill ? iodesc->holegridsize : iodesc->llen;
    void *iobuf = fill ? vdesc->fillbuf : file->iobuf;

#if USE_VARD_WRITE
    if (!ios->async || !ios->ioproc)
    {
        if ((ierr = get_gdim0(file, iodesc, varids[0], fndims, &gdim0)))
            return pio_err(NULL, file, ierr, __FILE__, __LINE__);

    }
#endif

    /* If this is an IO task write the data. */
    if (ios->ioproc)
    {
        void *bufptr;
        size_t start[fndims];
        size_t count[fndims];
        int ndims = iodesc->ndims;
#ifdef _PNETCDF
        int rrcnt = 0; /* Number of subarray requests (pnetcdf only). */
        PIO_Offset *startlist[num_regions]; /* Array of start arrays for ncmpi_iput_varn(). */
        PIO_Offset *countlist[num_regions]; /* Array of count  arrays for ncmpi_iput_varn(). */
#endif /* _PNETCDF */

        /* Process each region of data to be written. */
        for (int regioncnt = 0; regioncnt < num_regions; regioncnt++)
        {
            /* Fill the start/count arrays. */
            if ((ierr = find_start_count(iodesc->ndims, fndims, vdesc, region, frame,
                                         start, count)))
                return pio_err(ios, file, ierr, __FILE__, __LINE__);

            /* IO tasks will run the netCDF/pnetcdf functions to write the data. */
            switch (file->iotype)
            {
#ifdef _NETCDF4
            case PIO_IOTYPE_NETCDF4P:
                /* For each variable to be written. */
                for (int nv = 0; nv < nvars; nv++)
                {
                    /* Set the start of the record dimension. (Hasn't
                     * this already been set above ???) */
                    if (vdesc->record >= 0 && ndims < fndims)
                        start[0] = frame[nv];

                    /* If there is data for this region, get a pointer to it. */
                    if (region)
                        bufptr = (void *)((char *)iobuf + iodesc->mpitype_size * (nv * llen + region->loffset));

                    /* Ensure collective access. */
                    ierr = nc_var_par_access(file->fh, varids[nv], NC_COLLECTIVE);

                    /* Write the data for this variable. */
                    if (!ierr)
                        ierr = nc_put_vara(file->fh, varids[nv], (size_t *)start, (size_t *)count, bufptr);
                }
                break;
#endif
#ifdef _PNETCDF
            case PIO_IOTYPE_PNETCDF:
                /* Get the total number of data elements we are
                 * writing for this region. */
                dsize = 1;
                for (int i = 0; i < fndims; i++)
                    dsize *= count[i];
                PLOG((3, "dsize = %d", dsize));

                /* For pnetcdf's ncmpi_iput_varn() function, we need
                 * to provide arrays of arrays for start/count. */
                if (dsize > 0)
                {
                    /* Allocate storage for start/count arrays for
                     * this region. */
                    if (!(startlist[rrcnt] = calloc(fndims, sizeof(PIO_Offset))))
                        return pio_err(ios, file, PIO_ENOMEM, __FILE__, __LINE__);
                    if (!(countlist[rrcnt] = calloc(fndims, sizeof(PIO_Offset))))
                        return pio_err(ios, file, PIO_ENOMEM, __FILE__, __LINE__);

                    /* Copy the start/count arrays for this region. */
                    for (int i = 0; i < fndims; i++)
                    {
                        startlist[rrcnt][i] = start[i];
                        countlist[rrcnt][i] = count[i];
                        PLOG((3, "startlist[%d][%d] = %d countlist[%d][%d] = %d", rrcnt, i,
                              startlist[rrcnt][i], rrcnt, i, countlist[rrcnt][i]));
                    }
                    rrcnt++;
                }

                /* Do this when we reach the last region. */
                if (regioncnt == num_regions - 1)
                {
#ifdef USE_VARD_WRITE
                    MPI_Aint   var0_offset, var_offsets[nvars];
                    MPI_Offset vari_offset, vard_llen=0;
                    MPI_Datatype vartypes[nvars];
                    MPI_Datatype filetype = MPI_DATATYPE_NULL;
                    int blocklens[nvars];
                    int fvartype, var0_id;
                    int numReqs=0;
                    void *vard_bufptr;
                    int doFlush[nvars]; /* whether to flush or not */

                    /* construct doFlush[], so later when looping through nvars,
                     * it tells whether to flush or not.
                     */
                    for (int nv = 0; nv < nvars; nv++) {
                        /* Get the var info. */
                        if ((ierr = get_var_desc(varids[nv], &file->varlist, &vdesc)))
                            return pio_err(NULL, file, ierr, __FILE__, __LINE__);
                        if (nv == 0) { /* first variable */
                            fvartype = vdesc->pio_type; /* first var's var type */
                            continue;
                        }
                        if (fvartype != vdesc->pio_type) {
                            /* nv's external datatype is different from nv-1 */
                            doFlush[nv-1] = 1;
                            fvartype = vdesc->pio_type;
                        }
                        else /* same as nv-1, no flush */
                            doFlush[nv-1] = 0;
                    }
                    doFlush[nvars-1] = 1; /* flush when reach the last variable */
#endif
                    /* For each variable to be written. */
                    for (int nv = 0; nv < nvars; nv++)
                    {
#if USE_VARD_WRITE
                        /* PnetCDF 1.10.0 and later support type conversion in
                         * vard APIs. However, it requires all variables
                         * accessed by the filetype are of the same NC data
                         * type.
                         */

                        /* obtain file offset of variable nv */
                        if ((ierr = ncmpi_inq_varoffset(file->fh, varids[nv], &vari_offset)))
                            return pio_err(NULL, file, ierr, __FILE__, __LINE__);

                        if (numReqs == 0) { /* 1st variable of same datatype */
                            var0_offset = vari_offset;
                            var0_id = varids[nv];
                        }
                        /* calculate the offset relative to the first var */
                        var_offsets[numReqs] = vari_offset - var0_offset;
                        blocklens[nv] = 1; /* 1 for each vartypes[nv] */

                        /* If this is the first variable or the frame has changed between variables (this should be rare) */
                        if(nv==0 || (nv > 0 && frame != NULL && frame[nv] != frame[nv-1])){
                            int thisframe;
                            PIO_Offset unlimdimoffset;
                            if (gdim0 == 0) /* if there is an unlimited dimension get the offset between records of a variable */
                            {
                                if((ierr = ncmpi_inq_recsize(file->fh, &unlimdimoffset)))
                                    return pio_err(NULL, file, ierr, __FILE__, __LINE__);
                                PLOG((3, "num_regions = %d unlimdimoffset %ld", num_regions, unlimdimoffset));
                            }else
                                unlimdimoffset = gdim0;
                            if (frame)
                                thisframe = frame[nv];
                            else
                                thisframe = 0;

                            ierr = get_vard_mpidatatype(iodesc, gdim0, unlimdimoffset,
                                                        rrcnt, ndims, fndims,
                                                        thisframe, startlist, countlist,
                                                        &vartypes[numReqs]);
                        }
                        else /* reuse the previous variable's datatype */
                            vartypes[numReqs] = vartypes[numReqs-1];
#else
                        /* Get the var info. */
                        if ((ierr = get_var_desc(varids[nv], &file->varlist, &vdesc)))
                            return pio_err(NULL, file, ierr, __FILE__, __LINE__);

                        if (vdesc->record >= 0 && ndims < fndims)
                            for (int rc = 0; rc < rrcnt; rc++)
                                startlist[rc][0] = frame[nv];
#endif
                        /* Get a pointer to the data. */
                        bufptr = (void *)((char *)iobuf + nv * iodesc->mpitype_size * llen);

#if USE_VARD_WRITE
                        if (numReqs == 0) { /* first var of the same type */
                            vard_bufptr = bufptr; /* preserve variable ID */
                            vard_llen = llen;     /* reset I/O request size */
                        }
                        numReqs++;

                        if (doFlush[nv]) { /* flush the data now */
                            int mpierr;
                            /* concatenate vartypes[0...numReqs-1] */
                            if (numReqs > 1) {
                                /* check and remove NULL vartype */
                                int i, j=0;
                                for (i=0; i<numReqs; i++) {
                                    if (vartypes[i] != MPI_DATATYPE_NULL) {
                                        if (j < i) vartypes[j] = vartypes[i];
                                        j++;
                                    }
                                }
                                if (j > 0) { /* at least one vartypes[] is not NULL */
                                    /* concatenate non-NULL vartypes */
                                    if((mpierr = MPI_Type_create_struct(j, blocklens, var_offsets, vartypes, &filetype)))
                                        return check_mpi(NULL, NULL, mpierr, __FILE__, __LINE__);

                                    if((mpierr = MPI_Type_commit(&filetype)))
                                        return check_mpi(NULL, NULL, mpierr, __FILE__, __LINE__);

                                    /* free vartypes */
                                    for (i=j-1; i>0; i--) {
                                        if (vartypes[i] == vartypes[i-1]) continue;
                                        if((mpierr = MPI_Type_free(&vartypes[i])))
                                            return check_mpi(NULL, NULL, mpierr, __FILE__, __LINE__);
                                    }
                                    if((mpierr = MPI_Type_free(&vartypes[0])))
                                        return check_mpi(NULL, NULL, mpierr, __FILE__, __LINE__);
                                }
                                else /* all vartypes[] are NULL */
                                    filetype = MPI_DATATYPE_NULL;
                            }
                            else /* there is only one variable to flush */
                                filetype = vartypes[0];

                            PLOG((3, "vard: call ncmpi_put_vard llen = %d %d", llen, iodesc->mpitype_size ));
                            ierr = ncmpi_put_vard_all(file->fh, var0_id, filetype, vard_bufptr, vard_llen, iodesc->mpitype);
                            PLOG((3, "vard: return ncmpi_put_vard ierr = %d", ierr));
                            if(filetype != MPI_DATATYPE_NULL)
                            {
                                if((mpierr = MPI_Type_free(&filetype)))
                                    return check_mpi(NULL, NULL, mpierr, __FILE__, __LINE__);
                            }
                            vard_llen = 0; /* reset request size to 0 */
                            numReqs = 0;
                        }
                        else /* don't flush yet, accumulate the request size */
                            vard_llen += llen;
#else
                        if (vdesc->nreqs % PIO_REQUEST_ALLOC_CHUNK == 0)
                        {
                            if (!(vdesc->request = realloc(vdesc->request, sizeof(int) *
                                                           (vdesc->nreqs + PIO_REQUEST_ALLOC_CHUNK))))
                                return pio_err(ios, file, PIO_ENOMEM, __FILE__, __LINE__);

                            for (int i = vdesc->nreqs; i < vdesc->nreqs + PIO_REQUEST_ALLOC_CHUNK; i++)
                                vdesc->request[i] = NC_REQ_NULL;
                        }

                        /* Write, in non-blocking fashion, a list of subarrays. */
                        PLOG((3, "about to call ncmpi_iput_varn() varids[%d] = %d rrcnt = %d, llen = %d",
                              nv, varids[nv], rrcnt, llen));
                        ierr = ncmpi_iput_varn(file->fh, varids[nv], rrcnt, startlist, countlist,
                                               bufptr, llen, iodesc->mpitype, &vdesc->request[vdesc->nreqs]);

                        /* keeps wait calls in sync */
                        if (vdesc->request[vdesc->nreqs] == NC_REQ_NULL)
                            vdesc->request[vdesc->nreqs] = PIO_REQ_NULL;

                        vdesc->nreqs++;
#endif
                    }

                    /* Free resources. */
                    for (int i = 0; i < rrcnt; i++)
                    {
                        free(startlist[i]);
                        free(countlist[i]);
                    }
                }
                break;
#endif
            default:
                return pio_err(ios, file, PIO_EBADIOTYPE, __FILE__, __LINE__);
            }

            /* Go to next region. */
            if (region)
                region = region->next;
        } /* next regioncnt */
    } /* endif (ios->ioproc) */

    /* Check the return code from the netCDF/pnetcdf call. */
    ierr = check_netcdf(file, ierr, __FILE__,__LINE__);

#ifdef TIMING
    if ((ierr = pio_stop_timer("PIO:write_darray_multi_par")))
        return pio_err(ios, NULL, ierr, __FILE__, __LINE__);
#endif /* TIMING */

    return ierr;
}

/**
 * Fill the tmp_start and tmp_count arrays, which contain the start
 * and count arrays for all regions.
 *
 * This is an internal function which is only called on io tasks. It
 * is called by write_darray_multi_serial().
 *
 * @param region pointer to the first in a linked list of regions.
 * @param maxregions the number of regions in the list.
 * @param fndims the number of dimensions in the file.
 * @param iodesc_ndims the number of dimensions in the decomposition.
 * @param vdesc pointer to an array of var_desc_t for the vars being
 * written.
 * @param tmp_start pointer to an already allocaed array of length
 * fndims * maxregions. This array will get the start values for all
 * regions.
 * @param tmp_count pointer to an already allocaed array of length
 * fndims * maxregions. This array will get the count values for all
 * regions.
 * @returns 0 for success, error code otherwise.
 * @ingroup PIO_read_darray_c
 * @author Jim Edwards, Ed Hartnett
 **/
int
find_all_start_count(io_region *region, int maxregions, int fndims,
                     int iodesc_ndims, var_desc_t *vdesc, size_t *tmp_start,
                     size_t *tmp_count)
{
    /* Check inputs. */
    pioassert(maxregions >= 0 && fndims > 0 && iodesc_ndims >= 0 && vdesc &&
              tmp_start && tmp_count, "invalid input", __FILE__, __LINE__);

    /* Find the start/count arrays for each region in the list. */
    for (int r = 0; r < maxregions; r++)
    {
        /* Initialize the start/count arrays for this region to 0. */
        for (int d = 0; d < fndims; d++)
        {
            tmp_start[d + r * fndims] = 0;
            tmp_count[d + r * fndims] = 0;
        }

        if (region)
        {
            if (vdesc->record >= 0)
            {
                /* This is a record based multidimensional
                 * array. Copy start/count for non-record
                 * dimensions. */
                for (int i = fndims - iodesc_ndims; i < fndims; i++)
                {
                    tmp_start[i + r * fndims] = region->start[i - (fndims - iodesc_ndims)];
                    tmp_count[i + r * fndims] = region->count[i - (fndims - iodesc_ndims)];
                    PLOG((3, "tmp_start[%d] = %d tmp_count[%d] = %d", i + r * fndims,
                          tmp_start[i + r * fndims], i + r * fndims,
                          tmp_count[i + r * fndims]));
                }
            }
            else
            {
                /* This is not a record based multidimensional array. */
                for (int i = 0; i < iodesc_ndims; i++)
                {
                    tmp_start[i + r * fndims] = region->start[i];
                    tmp_count[i + r * fndims] = region->count[i];
                    PLOG((3, "tmp_start[%d] = %d tmp_count[%d] = %d", i + r * fndims,
                          tmp_start[i + r * fndims], i + r * fndims,
                          tmp_count[i + r * fndims]));
                }
            }

            /* Move to next region. */
            region = region->next;

        } /* endif region */
    } /* next r */

    return PIO_NOERR;
}

/**
 * Internal function called by IO tasks other than IO task 0 to send
 * their tmp_start/tmp_count arrays to IO task 0.
 *
 * This is an internal function which is only called on io tasks other
 * than IO task 0. It is called by write_darray_multi_serial().
 *
 * @return 0 for success, error code otherwise.
 * @ingroup PIO_write_darray_c
 * @author Jim Edwards, Ed Hartnett
 */
int
send_all_start_count(iosystem_desc_t *ios, io_desc_t *iodesc, PIO_Offset llen,
                     int maxregions, int nvars, int fndims, size_t *tmp_start,
                     size_t *tmp_count, void *iobuf)
{
    MPI_Status status;     /* Recv status for MPI. */
    int mpierr;  /* Return code from MPI function codes. */
    int ierr;    /* Return code. */

    /* Check inputs. */
    pioassert(ios && ios->ioproc && ios->io_rank > 0 && maxregions >= 0,
              "invalid inputs", __FILE__, __LINE__);

    /* Do a handshake. */
    if ((mpierr = MPI_Recv(&ierr, 1, MPI_INT, 0, 0, ios->io_comm, &status)))
        return check_mpi(ios, NULL, mpierr, __FILE__, __LINE__);

    /* Send local length of iobuffer for each field (all
     * fields are the same length). */
    if ((mpierr = MPI_Send((void *)&llen, 1, MPI_OFFSET, 0, ios->io_rank, ios->io_comm)))
        return check_mpi(ios, NULL, mpierr, __FILE__, __LINE__);
    PLOG((3, "sent llen = %d", llen));

    /* Send the number of data regions, the start/count for
     * all regions, and the data buffer with all the data. */
    if (llen > 0)
    {
        if ((mpierr = MPI_Send((void *)&maxregions, 1, MPI_INT, 0, ios->io_rank + ios->num_iotasks,
                               ios->io_comm)))
            return check_mpi(ios, NULL, mpierr, __FILE__, __LINE__);
        if ((mpierr = MPI_Send(tmp_start, maxregions * fndims, MPI_OFFSET, 0,
                               ios->io_rank + 2 * ios->num_iotasks, ios->io_comm)))
            return check_mpi(ios, NULL, mpierr, __FILE__, __LINE__);
        if ((mpierr = MPI_Send(tmp_count, maxregions * fndims, MPI_OFFSET, 0,
                               ios->io_rank + 3 * ios->num_iotasks, ios->io_comm)))
            return check_mpi(ios, NULL, mpierr, __FILE__, __LINE__);
        if ((mpierr = MPI_Send(iobuf, nvars * llen, iodesc->mpitype, 0,
                               ios->io_rank + 4 * ios->num_iotasks, ios->io_comm)))
            return check_mpi(ios, NULL, mpierr, __FILE__, __LINE__);
        PLOG((3, "sent data for maxregions = %d", maxregions));
    }

    return PIO_NOERR;
}

/**
 * This is an internal function that is run only on IO proc 0. It
 * receives data from all the other IO tasks, and write that data to
 * disk. This is called from write_darray_multi_serial().
 *
 * @param file a pointer to the open file descriptor for the file
 * that will be written to.
 * @param varids an array of the variable ids to be written
 * @param frame the record dimension for each of the nvars variables
 * in iobuf.  NULL if this iodesc contains non-record vars.
 * @param iodesc pointer to the decomposition info.
 * @param llen length of the iobuffer on this task for a single
 * field.
 * @param maxregions max number of blocks to be written from this
 * iotask.
 * @param nvars the number of variables to be written with this
 * decomposition.
 * @param fndims the number of dimensions in the file.
 * @param tmp_start pointer to an already allocaed array of length
 * fndims * maxregions. This array will get the start values for all
 * regions.
 * @param tmp_count pointer to an already allocaed array of length
 * fndims * maxregions. This array will get the count values for all
 * regions.
 * @param iobuf the buffer to be written from this mpi task. May be
 * null. for example we have 8 ionodes and a distributed array with
 * global size 4, then at least 4 nodes will have a null iobuf. In
 * practice the box rearranger trys to have at least blocksize bytes
 * on each io task and so if the total number of bytes to write is
 * less than blocksize*numiotasks then some iotasks will have a NULL
 * iobuf.
 * @return 0 for success, error code otherwise.
 * @ingroup PIO_write_darray_c
 * @author Jim Edwards, Ed Hartnett
 */
int
recv_and_write_data(file_desc_t *file, const int *varids, const int *frame,
                    io_desc_t *iodesc, PIO_Offset llen, int maxregions, int nvars,
                    int fndims, size_t *tmp_start, size_t *tmp_count, void *iobuf)
{
    iosystem_desc_t *ios;  /* Pointer to io system information. */
    size_t rlen;    /* Length of IO buffer on this task. */
    int rregions;   /* Number of regions in buffer for this task. */
    size_t start[fndims], count[fndims];
    size_t loffset;
    void *bufptr;
    var_desc_t *vdesc;    /* Contains info about the variable. */
    MPI_Status status;     /* Recv status for MPI. */
    int mpierr;  /* Return code from MPI function codes. */
    int ierr;    /* Return code. */

    /* Check inputs. */
    pioassert(file && varids && iodesc && tmp_start && tmp_count, "invalid input",
              __FILE__, __LINE__);

    PLOG((2, "recv_and_write_data llen = %d maxregions = %d nvars = %d fndims = %d",
          llen, maxregions, nvars, fndims));

    /* Get pointer to IO system. */
    ios = file->iosystem;

    /* For each of the other tasks that are using this task
     * for IO. */
    for (int rtask = 0; rtask < ios->num_iotasks; rtask++)
    {
        /* From the remote tasks, we send information about
         * the data regions. and also the data. */
        if (rtask)
        {
            /* handshake - tell the sending task I'm ready */
            if ((mpierr = MPI_Send(&ierr, 1, MPI_INT, rtask, 0, ios->io_comm)))
                return check_mpi(ios, NULL, mpierr, __FILE__, __LINE__);

            /* Get length of iobuffer for each field on this
             * task (all fields are the same length). */
            if ((mpierr = MPI_Recv(&rlen, 1, MPI_OFFSET, rtask, rtask, ios->io_comm,
                                   &status)))
                return check_mpi(ios, NULL, mpierr, __FILE__, __LINE__);
            PLOG((3, "received rlen = %d", rlen));

            /* Get the number of regions, the start/count
             * values for all regions, and the data buffer. */
            if (rlen > 0)
            {
                if ((mpierr = MPI_Recv(&rregions, 1, MPI_INT, rtask, rtask + ios->num_iotasks,
                                       ios->io_comm, &status)))
                    return check_mpi(ios, NULL, mpierr, __FILE__, __LINE__);
                if ((mpierr = MPI_Recv(tmp_start, rregions * fndims, MPI_OFFSET, rtask,
                                       rtask + 2 * ios->num_iotasks, ios->io_comm, &status)))
                    return check_mpi(ios, NULL, mpierr, __FILE__, __LINE__);
                if ((mpierr = MPI_Recv(tmp_count, rregions * fndims, MPI_OFFSET, rtask,
                                       rtask + 3 * ios->num_iotasks, ios->io_comm, &status)))
                    return check_mpi(ios, NULL, mpierr, __FILE__, __LINE__);
                if ((mpierr = MPI_Recv(iobuf, nvars * rlen, iodesc->mpitype, rtask,
                                       rtask + 4 * ios->num_iotasks, ios->io_comm, &status)))
                    return check_mpi(ios, NULL, mpierr, __FILE__, __LINE__);
                PLOG((3, "received data rregions = %d fndims = %d", rregions, fndims));
            }
        }
        else /* task 0 */
        {
            rlen = llen;
            rregions = maxregions;
        }
        PLOG((3, "rtask = %d rlen = %d rregions = %d", rtask, rlen, rregions));

        /* If there is data from this task, write it. */
        if (rlen > 0)
        {
            loffset = 0;
            for (int regioncnt = 0; regioncnt < rregions; regioncnt++)
            {
                PLOG((3, "writing data for region with regioncnt = %d", regioncnt));

                /* Get the start/count arrays for this region. */
                for (int i = 0; i < fndims; i++)
                {
                    start[i] = tmp_start[i + regioncnt * fndims];
                    count[i] = tmp_count[i + regioncnt * fndims];
                    PLOG((3, "start[%d] = %d count[%d] = %d", i, start[i], i, count[i]));
                }

                /* Process each variable in the buffer. */
                for (int nv = 0; nv < nvars; nv++)
                {
                    PLOG((3, "writing buffer var %d", nv));
                    if ((ierr = get_var_desc(varids[0], &file->varlist, &vdesc)))
                        return pio_err(NULL, file, ierr, __FILE__, __LINE__);

                    /* Get a pointer to the correct part of the buffer. */
                    bufptr = (void *)((char *)iobuf + iodesc->mpitype_size * (nv * rlen + loffset));

                    /* If this var has an unlimited dim, set
                     * the start on that dim to the frame
                     * value for this variable. */
                    if (vdesc->record >= 0)
                    {
                        if (fndims > 1 && iodesc->ndims < fndims && count[1] > 0)
                        {
                            count[0] = 1;
                            start[0] = frame[nv];
                        }
                        else if (fndims == iodesc->ndims)
                        {
                            start[0] += vdesc->record;
                        }
                    }

#ifdef LOGGING
                    for (int i = 1; i < fndims; i++)
                        PLOG((3, "start[%d] %d count[%d] %d", i, start[i], i, count[i]));
#endif /* LOGGING */

                    /* Call the netCDF functions to write the data. */
                    if ((ierr = nc_put_vara(file->fh, varids[nv], start, count, bufptr)))
                        return check_netcdf2(ios, NULL, ierr, __FILE__, __LINE__);

                } /* next var */

                /* Calculate the total size. */
                size_t tsize = 1;
                for (int i = 0; i < fndims; i++)
                    tsize *= count[i];

                /* Keep track of where we are in the buffer. */
                loffset += tsize;

                PLOG((3, " at bottom of loop regioncnt = %d tsize = %d loffset = %d", regioncnt,
                      tsize, loffset));
            } /* next regioncnt */
        } /* endif (rlen > 0) */
    } /* next rtask */

    return PIO_NOERR;
}

/**
 * Write a set of one or more aggregated arrays to output file in
 * serial mode. This function is called for netCDF classic and
 * netCDF-4 serial iotypes. Parallel iotypes use
 * write_darray_multi_par().
 *
 * @param file a pointer to the open file descriptor for the file
 * that will be written to.
 * @param nvars the number of variables to be written with this
 * decomposition.
 * @param fndims number of dims in the vars in the file.
 * @param varids an array of the variable ids to be written
 * @param iodesc pointer to the decomposition info.
 * @param fill Non-zero if this write is fill data.
 * @param frame the record dimension for each of the nvars variables
 * in iobuf. NULL if this iodesc contains non-record vars.
 * @return 0 for success, error code otherwise.
 * @ingroup PIO_write_darray_c
 * @author Jim Edwards, Ed Hartnett
 */
int
write_darray_multi_serial(file_desc_t *file, int nvars, int fndims, const int *varids,
                          io_desc_t *iodesc, int fill, const int *frame)
{
    iosystem_desc_t *ios;  /* Pointer to io system information. */
    var_desc_t *vdesc;     /* Contains info about the variable. */
    int ierr;              /* Return code. */

    /* Check inputs. */
    pioassert(file && file->iosystem && varids && varids[0] >= 0 &&
              varids[0] <= PIO_MAX_VARS && iodesc, "invalid input", __FILE__, __LINE__);

    PLOG((1, "write_darray_multi_serial nvars = %d fndims = %d iodesc->ndims = %d "
          "iodesc->mpitype = %d", nvars, fndims, iodesc->ndims, iodesc->mpitype));

    /* Get the iosystem info. */
    ios = file->iosystem;

    /* Get the var info. */
    if ((ierr = get_var_desc(varids[0], &file->varlist, &vdesc)))
        return pio_err(NULL, file, ierr, __FILE__, __LINE__);

    /* Set these differently for data and fill writing. iobuf may be
     * null if array size < number of nodes. */
    int num_regions = fill ? iodesc->maxfillregions: iodesc->maxregions;
    io_region *region = fill ? iodesc->fillregion : iodesc->firstregion;
    PIO_Offset llen = fill ? iodesc->holegridsize : iodesc->llen;
    void *iobuf = fill ? vdesc->fillbuf : file->iobuf;

#ifdef TIMING
    /* Start timer if desired. */
    if ((ierr = pio_start_timer("PIO:write_darray_multi_serial")))
        return pio_err(ios, NULL, ierr, __FILE__, __LINE__);
#endif /* TIMING */

    /* Only IO tasks participate in this code. */
    if (ios->ioproc)
    {
        size_t tmp_start[fndims * num_regions]; /* A start array for each region. */
        size_t tmp_count[fndims * num_regions]; /* A count array for each region. */

        PLOG((3, "num_regions = %d", num_regions));

        /* Fill the tmp_start and tmp_count arrays, which contain the
         * start and count arrays for all regions. */
        if ((ierr = find_all_start_count(region, num_regions, fndims, iodesc->ndims, vdesc,
                                         tmp_start, tmp_count)))
            return pio_err(ios, file, ierr, __FILE__, __LINE__);

        /* Tasks other than 0 will send their data to task 0. */
        if (ios->io_rank > 0)
        {
            /* Send the tmp_start and tmp_count arrays from this IO task
             * to task 0. */
            if ((ierr = send_all_start_count(ios, iodesc, llen, num_regions, nvars, fndims,
                                             tmp_start, tmp_count, iobuf)))
                return pio_err(ios, file, ierr, __FILE__, __LINE__);
        }
        else
        {
            /* Task 0 will receive data from all other IO tasks. */

            if ((ierr = recv_and_write_data(file, varids, frame, iodesc, llen, num_regions, nvars, fndims,
                                            tmp_start, tmp_count, iobuf)))
                return pio_err(ios, file, ierr, __FILE__, __LINE__);
        }
    }

#ifdef TIMING
    if ((ierr = pio_stop_timer("PIO:write_darray_multi_serial")))
        return pio_err(ios, NULL, ierr, __FILE__, __LINE__);
#endif /* TIMING */

    return PIO_NOERR;
}

/**
 * Read an array of data from a file using distributed arrays.
 *
 * @param file a pointer to the open file descriptor for the file
 * that will be read from.
 * @param iodesc a pointer to the defined iodescriptor for the buffer.
 * @param vid the variable id to be read.
 * @param iobuf the buffer to be read into from this mpi task. May be
 * null. (For example we have 8 ionodes and a distributed array with
 * global size 4, then at least 4 nodes will have a null iobuf. In
 * practice the box rearranger tries to have at least blocksize bytes
 * on each io task and so if the total number of bytes to write is
 * less than blocksize*numiotasks then some iotasks will have a NULL
 * iobuf.)
 * @return 0 on success, error code otherwise.
 * @ingroup PIO_read_darray_c
 * @author Jim Edwards, Ed Hartnett
 */
int
pio_read_darray_nc(file_desc_t *file, io_desc_t *iodesc, int vid, void *iobuf)
{
    iosystem_desc_t *ios;  /* Pointer to io system information. */
    var_desc_t *vdesc;     /* Information about the variable. */
    int ndims;             /* Number of dims in decomposition. */
    int fndims;            /* Number of dims for this var in file. */
    int ierr;              /* Return code from netCDF functions. */
#ifdef USE_VARD_READ
    MPI_Offset gdim0;
    gdim0 = 0;
#endif

    /* Check inputs. */
    pioassert(file && file->iosystem && iodesc && vid <= PIO_MAX_VARS, "invalid input",
              __FILE__, __LINE__);

    /* Get the IO system info. */
    ios = file->iosystem;
    PLOG((3, "pio_read_darray_nc ios->ioproc %d", ios->ioproc));

#ifdef TIMING
    /* Start timer if desired. */
    if ((ierr = pio_start_timer("PIO:read_darray_nc")))
        return pio_err(ios, NULL, ierr, __FILE__, __LINE__);
#endif /* TIMING */

    /* Get the variable info. */
    if ((ierr = get_var_desc(vid, &file->varlist, &vdesc)))
        return pio_err(NULL, file, ierr, __FILE__, __LINE__);

    /* Get the number of dimensions in the decomposition. */
    ndims = iodesc->ndims;

    /* Get the number of dims for this var in the file. */
    fndims = vdesc->ndims;
    PLOG((4, "fndims %d ndims %d", fndims, ndims));

    /* ??? */
#if USE_VARD_READ
    if(!ios->async || !ios->ioproc)
        ierr = get_gdim0(file, iodesc, vid, fndims, &gdim0);
#endif

    /* IO procs will read the data. */
    if (ios->ioproc)
    {
        io_region *region;
        size_t start[fndims];
        size_t count[fndims];
        size_t tmp_bufsize = 1;
        void *bufptr;
        int rrlen = 0;
        PIO_Offset *startlist[iodesc->maxregions];
        PIO_Offset *countlist[iodesc->maxregions];

        /* buffer is incremented by byte and loffset is in terms of
           the iodessc->mpitype so we need to multiply by the size of
           the mpitype. */
        region = iodesc->firstregion;

        /* There are different numbers of dims in the decomposition
         * and the file. */
        if (fndims > ndims)
        {
            /* If the user did not call setframe, use a default frame
             * of 0. This is required for backward compatibility. */
            if (vdesc->record < 0)
                vdesc->record = 0;
        }

        /* For each regions, read the data. */
        for (int regioncnt = 0; regioncnt < iodesc->maxregions; regioncnt++)
        {
            tmp_bufsize = 1;
            if (region == NULL || iodesc->llen == 0)
            {
                /* No data for this region. */
                for (int i = 0; i < fndims; i++)
                {
                    start[i] = 0;
                    count[i] = 0;
                }
                bufptr = NULL;
            }
            else
            {
                /* Get a pointer where we should put the data we read. */
                if (regioncnt == 0 || region == NULL)
                    bufptr = iobuf;
                else
                    bufptr=(void *)((char *)iobuf + iodesc->mpitype_size * region->loffset);

                PLOG((2, "iodesc->llen - region->loffset %d, iodesc->llen %d, region->loffset  %d vdesc->record %d",
                      iodesc->llen - region->loffset, iodesc->llen, region->loffset, vdesc->record));

                /* Get the start/count arrays. */
                if (vdesc->record >= 0 && fndims > 1)
                {
                    /* This is a record var. The unlimited dimension
                     * (0) is handled specially. */
                    start[0] = vdesc->record;
                    for (int i = 1; i < fndims; i++)
                    {
                        start[i] = region->start[i-1];
                        count[i] = region->count[i-1];
                    }

                    /* Read one record. */
                    if (count[1] > 0)
                        count[0] = 1;
                }
                else
                {
                    /* Non-time dependent array */
                    for (int i = 0; i < fndims; i++)
                    {
                        start[i] = region->start[i];
                        count[i] = region->count[i];
                    }
                }
            }

#ifdef PIO_ENABLE_LOGGING
            for (int i = 1; i < ndims; i++)
                PLOG((3, "start[%d] %d count[%d] %d", i, start[i], i, count[i]));
#endif /* LOGGING */
            /* Do the read. */
            switch (file->iotype)
            {
#ifdef _NETCDF4
            case PIO_IOTYPE_NETCDF4P:
                /* ierr = nc_get_vara(file->fh, vid, start, count, bufptr); */
                switch (iodesc->piotype)
                {
                case PIO_BYTE:
                    ierr = nc_get_vara_schar(file->fh, vid, start, count, (signed char*)bufptr);
                    break;
                case PIO_CHAR:
                    ierr = nc_get_vara_text(file->fh, vid, start, count, (char*)bufptr);
                    break;
                case PIO_SHORT:
                    ierr = nc_get_vara_short(file->fh, vid, start, count, (short*)bufptr);
                    break;
                case PIO_INT:
                    ierr = nc_get_vara_int(file->fh, vid, start, count, (int*)bufptr);
                    break;
                case PIO_FLOAT:
                    ierr = nc_get_vara_float(file->fh, vid, start, count, (float*)bufptr);
                    break;
                case PIO_DOUBLE:
                    ierr = nc_get_vara_double(file->fh, vid, start, count, (double*)bufptr);
                    break;
                case PIO_UBYTE:
                    ierr = nc_get_vara_uchar(file->fh, vid, start, count, (unsigned char*)bufptr);
                    break;
                case PIO_USHORT:
                    ierr = nc_get_vara_ushort(file->fh, vid, start, count, (unsigned short*)bufptr);
                    break;
                case PIO_UINT:
                    ierr = nc_get_vara_uint(file->fh, vid, start, count, (unsigned int*)bufptr);
                    break;
                case PIO_INT64:
                    ierr = nc_get_vara_longlong(file->fh, vid, start, count, (long long*)bufptr);
                    break;
                case PIO_UINT64:
                    ierr = nc_get_vara_ulonglong(file->fh, vid, start, count, (unsigned long long*)bufptr);
                    break;
                case PIO_STRING:
                    ierr = nc_get_vara_string(file->fh, vid, start, count, (char**)bufptr);
                    break;
                default:
                    return pio_err(ios, file, PIO_EBADTYPE, __FILE__, __LINE__);
                }
                break;
#endif
#ifdef _PNETCDF
            case PIO_IOTYPE_PNETCDF:
            {
                tmp_bufsize = 1;
                for (int j = 0; j < fndims; j++)
                    tmp_bufsize *= count[j];

                if (tmp_bufsize > 0)
                {
                    startlist[rrlen] = malloc(fndims * sizeof(PIO_Offset));
                    countlist[rrlen] = malloc(fndims * sizeof(PIO_Offset));

                    for (int j = 0; j < fndims; j++)
                    {
                        startlist[rrlen][j] = start[j];
                        countlist[rrlen][j] = count[j];
                    }
                    rrlen++;
                }

                /* Is this is the last region to process? */
                if (regioncnt == iodesc->maxregions - 1)
                {
#if USE_VARD_READ
                    MPI_Datatype filetype;
                    PIO_Offset unlimdimoffset;
                    int mpierr;
                    if (gdim0 == 0) /* if there is an unlimited dimension get the offset between records of a variable */
                    {
                        if((ierr = ncmpi_inq_recsize(file->fh, &unlimdimoffset)))
                            return pio_err(NULL, file, ierr, __FILE__, __LINE__);
                    }
                    else
                        unlimdimoffset = gdim0;

                    ierr = get_vard_mpidatatype(iodesc, gdim0, unlimdimoffset,
                                                rrlen, ndims, fndims,
                                                vdesc->record, startlist, countlist, &filetype);
                    ierr = ncmpi_get_vard_all(file->fh, vid, filetype, iobuf, iodesc->llen, iodesc->mpitype);
                    if(filetype != MPI_DATATYPE_NULL && (mpierr = MPI_Type_free(&filetype)))
                        return check_mpi(NULL, NULL, mpierr, __FILE__, __LINE__);

#else
                    /* Read a list of subarrays. */
                    ierr = ncmpi_get_varn_all(file->fh, vid, rrlen, startlist,
                                              countlist, iobuf, iodesc->llen, iodesc->mpitype);
#endif
                    /* Release the start and count arrays. */
                    for (int i = 0; i < rrlen; i++)
                    {
                        free(startlist[i]);
                        free(countlist[i]);
                    }
                }
            }
            break;
#endif
            default:
                return pio_err(ios, file, PIO_EBADIOTYPE, __FILE__, __LINE__);
            }

            /* Check return code. */
            if (ierr)
                return check_netcdf(file, ierr, __FILE__,__LINE__);

            /* Move to next region. */
            if (region)
                region = region->next;
        } /* next regioncnt */
    }

#ifdef TIMING
    if ((ierr = pio_stop_timer("PIO:read_darray_nc")))
        return pio_err(ios, NULL, ierr, __FILE__, __LINE__);
#endif /* TIMING */

    return PIO_NOERR;
}

/**
 * Read an array of data from a file to the (serial) IO library. This
 * function is only used with netCDF classic and netCDF-4 serial
 * iotypes.
 *
 * @param file a pointer to the open file descriptor for the file
 * that will be written to
 * @param iodesc a pointer to the defined iodescriptor for the buffer
 * @param vid the variable id to be read.
 * @param iobuf the buffer to be written from this mpi task. May be
 * null. for example we have 8 ionodes and a distributed array with
 * global size 4, then at least 4 nodes will have a null iobuf. In
 * practice the box rearranger trys to have at least blocksize bytes
 * on each io task and so if the total number of bytes to write is
 * less than blocksize * numiotasks then some iotasks will have a NULL
 * iobuf.
 * @returns 0 for success, error code otherwise.
 * @ingroup PIO_read_darray_c
 * @author Jim Edwards, Ed Hartnett
 */
int
pio_read_darray_nc_serial(file_desc_t *file, io_desc_t *iodesc, int vid,
                          void *iobuf)
{
    iosystem_desc_t *ios;  /* Pointer to io system information. */
    var_desc_t *vdesc;    /* Information about the variable. */
    int ndims;             /* Number of dims in decomposition. */
    int fndims;            /* Number of dims for this var in file. */
    MPI_Status status;
    int mpierr;  /* Return code from MPI functions. */
    int ierr;

    /* Check inputs. */
    pioassert(file && file->iosystem && iodesc && vid >= 0 && vid <= PIO_MAX_VARS,
              "invalid input", __FILE__, __LINE__);

    PLOG((2, "pio_read_darray_nc_serial vid = %d", vid));
    ios = file->iosystem;

#ifdef TIMING
    /* Start timer if desired. */
    if ((ierr = pio_start_timer("PIO:read_darray_nc_serial")))
        return pio_err(ios, NULL, ierr, __FILE__, __LINE__);
#endif /* TIMING */

    /* Get var info for this var. */
    if ((ierr = get_var_desc(vid, &file->varlist, &vdesc)))
        return pio_err(NULL, file, ierr, __FILE__, __LINE__);

    /* Get the number of dims in our decomposition. */
    ndims = iodesc->ndims;

    /* Get number of dims for this var. */
    fndims = vdesc->ndims;

    /* If setframe was not called, use a default value of 0. This is
     * required for backward compatibility. */
    if (fndims == ndims + 1 && vdesc->record < 0)
        vdesc->record = 0;
    PLOG((3, "fndims %d ndims %d vdesc->record %d vdesc->ndims %d", fndims,
          ndims, vdesc->record, vdesc->ndims));

    /* Confirm that we are being called with the correct ndims. */
    pioassert((fndims == ndims && vdesc->record < 0) ||
              (fndims == ndims + 1 && vdesc->record >= 0),
              "unexpected record", __FILE__, __LINE__);

    if (ios->ioproc)
    {
        io_region *region;
        size_t start[fndims];
        size_t count[fndims];
        size_t tmp_start[fndims * iodesc->maxregions];
        size_t tmp_count[fndims * iodesc->maxregions];
        size_t tmp_bufsize;
        void *bufptr;

        /* buffer is incremented by byte and loffset is in terms of
           the iodessc->mpitype so we need to multiply by the size of
           the mpitype. */
        region = iodesc->firstregion;

        /* If setframe was not set before this call, assume a value of
         * 0. This is required for backward compatibility. */
        if (fndims > ndims)
            if (vdesc->record < 0)
                vdesc->record = 0;

        /* Put together start/count arrays for all regions. */
        for (int regioncnt = 0; regioncnt < iodesc->maxregions; regioncnt++)
        {
            if (!region || iodesc->llen == 0)
            {
                /* Nothing to write for this region. */
                for (int i = 0; i < fndims; i++)
                {
                    tmp_start[i + regioncnt * fndims] = 0;
                    tmp_count[i + regioncnt * fndims] = 0;
                }
                bufptr = NULL;
            }
            else
            {
                if (vdesc->record >= 0 && fndims > 1)
                {
                    /* This is a record var. Find start for record dims. */
                    tmp_start[regioncnt * fndims] = vdesc->record;

                    /* Find start/count for all non-record dims. */
                    for (int i = 1; i < fndims; i++)
                    {
                        tmp_start[i + regioncnt * fndims] = region->start[i - 1];
                        tmp_count[i + regioncnt * fndims] = region->count[i - 1];
                    }

                    /* Set count for record dimension. */
                    if (tmp_count[1 + regioncnt * fndims] > 0)
                        tmp_count[regioncnt * fndims] = 1;
                }
                else
                {
                    /* Non-time dependent array */
                    for (int i = 0; i < fndims; i++)
                    {
                        tmp_start[i + regioncnt * fndims] = region->start[i];
                        tmp_count[i + regioncnt * fndims] = region->count[i];
                    }
                }
            }

#if PIO_ENABLE_LOGGING
            /* Log arrays for debug purposes. */
            PLOG((3, "region = %d", region));
            for (int i = 0; i < fndims; i++)
                PLOG((3, "tmp_start[%d] = %d tmp_count[%d] = %d", i + regioncnt * fndims, tmp_start[i + regioncnt * fndims],
                      i + regioncnt * fndims, tmp_count[i + regioncnt * fndims]));
#endif /* PIO_ENABLE_LOGGING */

            /* Move to next region. */
            if (region)
                region = region->next;
        } /* next regioncnt */

        /* IO tasks other than 0 send their starts/counts and data to
         * IO task 0. */
        if (ios->io_rank > 0)
        {
            if ((mpierr = MPI_Send(&iodesc->llen, 1, MPI_OFFSET, 0, ios->io_rank, ios->io_comm)))
                return check_mpi(NULL, file, mpierr, __FILE__, __LINE__);
            PLOG((3, "sent iodesc->llen = %d", iodesc->llen));

            if (iodesc->llen > 0)
            {
                if ((mpierr = MPI_Send(&(iodesc->maxregions), 1, MPI_INT, 0,
                                       ios->num_iotasks + ios->io_rank, ios->io_comm)))
                    return check_mpi(NULL, file, mpierr, __FILE__, __LINE__);
                if ((mpierr = MPI_Send(tmp_count, iodesc->maxregions * fndims, MPI_OFFSET, 0,
                                       2 * ios->num_iotasks + ios->io_rank, ios->io_comm)))
                    return check_mpi(NULL, file, mpierr, __FILE__, __LINE__);
                if ((mpierr = MPI_Send(tmp_start, iodesc->maxregions * fndims, MPI_OFFSET, 0,
                                       3 * ios->num_iotasks + ios->io_rank, ios->io_comm)))
                    return check_mpi(NULL, file, mpierr, __FILE__, __LINE__);
                PLOG((3, "sent iodesc->maxregions = %d tmp_count and tmp_start arrays", iodesc->maxregions));

                if ((mpierr = MPI_Recv(iobuf, iodesc->llen, iodesc->mpitype, 0,
                                       4 * ios->num_iotasks + ios->io_rank, ios->io_comm, &status)))
                    return check_mpi(NULL, file, mpierr, __FILE__, __LINE__);
                PLOG((3, "received %d elements of data", iodesc->llen));
            }
        }
        else if (ios->io_rank == 0)
        {
            /* This is IO task 0. Get starts/counts and data from
             * other IO tasks. */
            int maxregions = 0;
            size_t loffset, regionsize;
            size_t this_start[fndims * iodesc->maxregions];
            size_t this_count[fndims * iodesc->maxregions];

            for (int rtask = 1; rtask <= ios->num_iotasks; rtask++)
            {
                if (rtask < ios->num_iotasks)
                {
                    if ((mpierr = MPI_Recv(&tmp_bufsize, 1, MPI_OFFSET, rtask, rtask, ios->io_comm, &status)))
                        return check_mpi(NULL, file, mpierr, __FILE__, __LINE__);
                    PLOG((3, "received tmp_bufsize = %d", tmp_bufsize));

                    if (tmp_bufsize > 0)
                    {
                        if ((mpierr = MPI_Recv(&maxregions, 1, MPI_INT, rtask, ios->num_iotasks + rtask,
                                               ios->io_comm, &status)))
                            return check_mpi(NULL, file, mpierr, __FILE__, __LINE__);
                        if ((mpierr = MPI_Recv(this_count, maxregions * fndims, MPI_OFFSET, rtask,
                                               2 * ios->num_iotasks + rtask, ios->io_comm, &status)))
                            return check_mpi(NULL, file, mpierr, __FILE__, __LINE__);
                        if ((mpierr = MPI_Recv(this_start, maxregions * fndims, MPI_OFFSET, rtask,
                                               3 * ios->num_iotasks + rtask, ios->io_comm, &status)))
                            return check_mpi(NULL, file, mpierr, __FILE__, __LINE__);
                        PLOG((3, "received maxregions = %d this_count, this_start arrays ", maxregions));
                    }
                }
                else
                {
                    maxregions = iodesc->maxregions;
                    tmp_bufsize = iodesc->llen;
                }
                PLOG((3, "maxregions = %d tmp_bufsize = %d", maxregions, tmp_bufsize));

                /* Now get each region of data. */
                loffset = 0;
                for (int regioncnt = 0; regioncnt < maxregions; regioncnt++)
                {
                    /* Get pointer where data should go. */
                    bufptr = (void *)((char *)iobuf + iodesc->mpitype_size * loffset);
                    regionsize = 1;

                    /* ??? */
                    if (rtask < ios->num_iotasks)
                    {
                        for (int m = 0; m < fndims; m++)
                        {
                            start[m] = this_start[m + regioncnt * fndims];
                            count[m] = this_count[m + regioncnt * fndims];
                            regionsize *= count[m];
                        }
                    }
                    else
                    {
                        for (int m = 0; m < fndims; m++)
                        {
                            start[m] = tmp_start[m + regioncnt * fndims];
                            count[m] = tmp_count[m + regioncnt * fndims];
                            regionsize *= count[m];
                        }
                    }
                    loffset += regionsize;

                    /* Read the data. */
                    /* ierr = nc_get_vara(file->fh, vid, start, count, bufptr); */
                    switch (iodesc->piotype)
                    {
                    case PIO_BYTE:
                        ierr = nc_get_vara_schar(file->fh, vid, start, count, (signed char*)bufptr);
                        break;
                    case PIO_CHAR:
                        ierr = nc_get_vara_text(file->fh, vid, start, count, (char*)bufptr);
                        break;
                    case PIO_SHORT:
                        ierr = nc_get_vara_short(file->fh, vid, start, count, (short*)bufptr);
                        break;
                    case PIO_INT:
                        ierr = nc_get_vara_int(file->fh, vid, start, count, (int*)bufptr);
                        break;
                    case PIO_FLOAT:
                        ierr = nc_get_vara_float(file->fh, vid, start, count, (float*)bufptr);
                        break;
                    case PIO_DOUBLE:
                        ierr = nc_get_vara_double(file->fh, vid, start, count, (double*)bufptr);
                        break;
#ifdef _NETCDF4
                    case PIO_UBYTE:
                        ierr = nc_get_vara_uchar(file->fh, vid, start, count, (unsigned char*)bufptr);
                        break;
                    case PIO_USHORT:
                        ierr = nc_get_vara_ushort(file->fh, vid, start, count, (unsigned short*)bufptr);
                        break;
                    case PIO_UINT:
                        ierr = nc_get_vara_uint(file->fh, vid, start, count, (unsigned int*)bufptr);
                        break;
                    case PIO_INT64:
                        ierr = nc_get_vara_longlong(file->fh, vid, start, count, (long long*)bufptr);
                        break;
                    case PIO_UINT64:
                        ierr = nc_get_vara_ulonglong(file->fh, vid, start, count, (unsigned long long*)bufptr);
                        break;
                    case PIO_STRING:
                        ierr = nc_get_vara_string(file->fh, vid, start, count, (char**)bufptr);
                        break;
#endif /* _NETCDF4 */
                    default:
                        return pio_err(ios, file, PIO_EBADTYPE, __FILE__, __LINE__);
                    }

                    /* Check error code of netCDF call. */
                    if (ierr)
                        return check_netcdf(file, ierr, __FILE__, __LINE__);
                }

                /* The decomposition may not use all of the active io
                 * tasks. rtask here is the io task rank and
                 * ios->num_iotasks is the number of iotasks actually
                 * used in this decomposition. */
                if (rtask < ios->num_iotasks && tmp_bufsize > 0)
                    if ((mpierr = MPI_Send(iobuf, tmp_bufsize, iodesc->mpitype, rtask,
                                           4 * ios->num_iotasks + rtask, ios->io_comm)))
                        return check_mpi(NULL, file, mpierr, __FILE__, __LINE__);
            }
        }
    }

#ifdef TIMING
    if ((ierr = pio_stop_timer("PIO:read_darray_nc_serial")))
        return pio_err(ios, NULL, ierr, __FILE__, __LINE__);
#endif /* TIMING */

    PLOG((2, "pio_read_darray_nc_serial complete ierr %d", ierr));
    return PIO_NOERR;
}

/**
 * Flush the output buffer. This is only relevant for files opened
 * with pnetcdf.
 *
 * @param file a pointer to the open file descriptor for the file
 * that will be written to
 * @param force true to force the flushing of the buffer
 * @param addsize additional size to add to buffer (in bytes)
 * @return 0 for success, error code otherwise.
 * @ingroup PIO_write_darray_c
 * @author Jim Edwards, Ed Hartnett
 */
int
flush_output_buffer(file_desc_t *file, bool force, PIO_Offset addsize)
{
    int mpierr;  /* Return code from MPI functions. */
    int ierr = PIO_NOERR;

#ifdef _PNETCDF
    var_desc_t *vdesc;
    PIO_Offset usage = 0;

    /* Check inputs. */
    pioassert(file, "invalid input", __FILE__, __LINE__);
    PLOG((1, "flush_output_buffer"));
    /* Find out the buffer usage. */
    if ((ierr = ncmpi_inq_buffer_usage(file->fh, &usage)))
        /* allow the buffer to be undefined */
        if (ierr != NC_ENULLABUF)
            return pio_err(NULL, file, PIO_EBADID, __FILE__, __LINE__);

    /* If we are not forcing a flush, spread the usage to all IO
     * tasks. */
    if (!force && file->iosystem->ioproc)
    {
        usage += addsize;
        if ((mpierr = MPI_Allreduce(MPI_IN_PLACE, &usage, 1,  MPI_OFFSET,  MPI_MAX,
                                    file->iosystem->io_comm)))
            return check_mpi(NULL, file, mpierr, __FILE__, __LINE__);
    }

    /* Keep track of the maximum usage. */
    if (usage > maxusage)
        maxusage = usage;

    PLOG((2, "flush_output_buffer usage=%ld force=%d",usage, force));
    /* If the user forces it, or the buffer has exceeded the size
     * limit, then flush to disk. */
    if (force || (usage >= pio_buffer_size_limit))
    {
        int rcnt;
        int  maxreq;
        int reqcnt;
        maxreq = 0;
        reqcnt = 0;
        rcnt = 0;

        for (int i = 0; i < file->nvars; i++)
        {
            if ((ierr = get_var_desc(i, &file->varlist, &vdesc)))
                return pio_err(NULL, file, ierr, __FILE__, __LINE__);
            reqcnt += vdesc->nreqs;
            if (vdesc->nreqs > 0)
                maxreq = i;
        }
        int request[reqcnt];
        int status[reqcnt];

        if (file->varlist)
        {
            for (int i = 0; i <= maxreq; i++)
            {
                if ((ierr = get_var_desc(i, &file->varlist, &vdesc)))
                    return pio_err(NULL, file, ierr, __FILE__, __LINE__);
#ifdef MPIO_ONESIDED
                /*onesided optimization requires that all of the requests in a wait_all call represent
                  a contiguous block of data in the file */
                if (rcnt > 0 && (prev_record != vdesc->record || vdesc->nreqs == 0))
                {
                    ierr = ncmpi_wait_all(file->fh, rcnt, request, status);
                    rcnt = 0;
                }
                prev_record = vdesc->record;
#endif
                for (reqcnt = 0; reqcnt < vdesc->nreqs; reqcnt++)
                    request[rcnt++] = max(vdesc->request[reqcnt], NC_REQ_NULL);
                PLOG((3,"flush_output_buffer rcnt=%d",rcnt));

                if (vdesc->request != NULL)
                    free(vdesc->request);
                vdesc->request = NULL;
                vdesc->nreqs = 0;

#ifdef FLUSH_EVERY_VAR
                ierr = ncmpi_wait_all(file->fh, rcnt, request, status);
                rcnt = 0;
#endif
            }
        }

        if (rcnt > 0)
            ierr = ncmpi_wait_all(file->fh, rcnt, request, status);

        /* Release resources. */
        if (file->iobuf)
        {
            PLOG((3,"freeing variable buffer in flush_output_buffer"));
            free(file->iobuf);
            file->iobuf = NULL;
        }

        for (int v = 0; v < file->nvars; v++)
        {
            if ((ierr = get_var_desc(v, &file->varlist, &vdesc)))
                return pio_err(NULL, file, ierr, __FILE__, __LINE__);
            if (vdesc->fillbuf)
            {
                free(vdesc->fillbuf);
                vdesc->fillbuf = NULL;
            }
        }
    }

#endif /* _PNETCDF */
    return ierr;
}

/**
 * Flush the buffer.
 *
 * @param ncid identifies the netCDF file.
 * @param wmb pointer to the wmulti_buffer structure.
 * @param flushtodisk if true, then flush data to disk.
 * @returns 0 for success, error code otherwise.
 * @ingroup PIO_write_darray_c
 * @author Jim Edwards, Ed Hartnett
 */
int
flush_buffer(int ncid, wmulti_buffer *wmb, bool flushtodisk)
{
    file_desc_t *file;
    int ret;

    /* Check input. */
    pioassert(wmb, "invalid input", __FILE__, __LINE__);

    /* Get the file info (to get error handler). */
    if ((ret = pio_get_file(ncid, &file)))
        return pio_err(NULL, NULL, ret, __FILE__, __LINE__);

    PLOG((1, "flush_buffer ncid = %d flushtodisk = %d", ncid, flushtodisk));

    /* If there are any variables in this buffer... */
    if (wmb->num_arrays > 0)
    {
        /* Write any data in the buffer. */
        ret = PIOc_write_darray_multi(ncid, wmb->vid,  wmb->ioid, wmb->num_arrays,
                                      wmb->arraylen, wmb->data, wmb->frame,
                                      wmb->fillvalue, flushtodisk);
        PLOG((2, "return from PIOc_write_darray_multi ret = %d", ret));

        wmb->num_arrays = 0;

        /* Release the list of variable IDs. */
        free(wmb->vid);
        wmb->vid = NULL;

        /* Release the data memory. */
        free(wmb->data);
        wmb->data = NULL;

        /* If there is a fill value, release it. */
        if (wmb->fillvalue)
            free(wmb->fillvalue);
        wmb->fillvalue = NULL;

        /* Release the record number. */
        if (wmb->frame)
            free(wmb->frame);
        wmb->frame = NULL;

        if (ret)
            return pio_err(NULL, file, ret, __FILE__, __LINE__);
    }

    return PIO_NOERR;
}

/**
 * Sort the contents of an array.
 *
 * @param array pointer to the array
 * @param sortedarray pointer that gets the sorted array.
 * @param iodesc pointer to the iodesc.
 * @param nvars number of variables.
 * @param direction sort direction.
 * @returns 0 for success, error code otherwise.
 * @ingroup PIO_write_darray_c
 * @author Jim Edwards
 */
int
pio_sorted_copy(const void *array, void *sortedarray, io_desc_t *iodesc,
                int nvars, int direction)
{
    int maplen = iodesc->maplen;

    if (direction == 0){
        switch (iodesc->piotype)
        {
        case PIO_BYTE:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((signed char *)sortedarray)[m+maplen*v] = ((signed char *)array)[iodesc->remap[m]+maplen*v];
                }
            }
            break;
        case PIO_CHAR:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((char *)sortedarray)[m+maplen*v] = ((char *)array)[iodesc->remap[m]+maplen*v];
                }
            }
            break;
        case PIO_SHORT:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((short *)sortedarray)[m+maplen*v] = ((short *)array)[iodesc->remap[m]+maplen*v];
                }
            }

            break;
        case PIO_INT:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((int *)sortedarray)[m+maplen*v] = ((int *)array)[iodesc->remap[m]+maplen*v];
                }
            }
            break;
        case PIO_FLOAT:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((float *)sortedarray)[m+maplen*v] = ((float *)array)[iodesc->remap[m]+maplen*v];
                }
            }
            break;
        case PIO_DOUBLE:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((double *)sortedarray)[m+maplen*v] = ((double *)array)[iodesc->remap[m]+maplen*v];
                }
            }
            break;
        case PIO_UBYTE:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((unsigned char *)sortedarray)[m+maplen*v] = ((unsigned char *)array)[iodesc->remap[m]+maplen*v];
                }
            }
            break;
        case PIO_USHORT:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((unsigned short *)sortedarray)[m+maplen*v] = ((unsigned short *)array)[iodesc->remap[m]+maplen*v];
                }
            }
            break;
        case PIO_UINT:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((unsigned int *)sortedarray)[m+maplen*v] = ((unsigned int *)array)[iodesc->remap[m]+maplen*v];
                }
            }
            break;
        case PIO_INT64:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((long long *)sortedarray)[m+maplen*v] = ((long long *)array)[iodesc->remap[m]+maplen*v];
                }
            }
            break;
        case PIO_UINT64:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((unsigned long long *)sortedarray)[m+maplen*v] = ((unsigned long long *)array)[iodesc->remap[m]+maplen*v];
                }
            }
            break;
        case PIO_STRING:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((char **)sortedarray)[m+maplen*v] = ((char **)array)[iodesc->remap[m]+maplen*v];
                }
            }
            break;
        default:
            return pio_err(NULL, NULL, PIO_EBADTYPE, __FILE__, __LINE__);
        }
    }
    else
    {
        switch (iodesc->piotype)
        {
        case PIO_BYTE:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((signed char *)sortedarray)[iodesc->remap[m]+maplen*v] = ((signed char *)array)[m+maplen*v];
                }
            }
            break;
        case PIO_CHAR:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((char *)sortedarray)[iodesc->remap[m]+maplen*v] = ((char *)array)[m+maplen*v];
                }
            }
            break;
        case PIO_SHORT:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((short *)sortedarray)[iodesc->remap[m]+maplen*v] = ((short *)array)[m+maplen*v];
                }
            }

            break;
        case PIO_INT:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((int *)sortedarray)[iodesc->remap[m]+maplen*v] = ((int *)array)[m+maplen*v];
                }
            }
            break;
        case PIO_FLOAT:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((float *)sortedarray)[iodesc->remap[m]+maplen*v] = ((float *)array)[m+maplen*v];
                }
            }
            break;
        case PIO_DOUBLE:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((double *)sortedarray)[iodesc->remap[m]+maplen*v] = ((double *)array)[m+maplen*v];
                }
            }
            break;
        case PIO_UBYTE:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((unsigned char *)sortedarray)[iodesc->remap[m]+maplen*v] = ((unsigned char *)array)[m+maplen*v];
                }
            }
            break;
        case PIO_USHORT:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((unsigned short *)sortedarray)[iodesc->remap[m]+maplen*v] = ((unsigned short *)array)[m+maplen*v];
                }
            }
            break;
        case PIO_UINT:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((unsigned int *)sortedarray)[iodesc->remap[m]+maplen*v] = ((unsigned int *)array)[m+maplen*v];
                }
            }
            break;
        case PIO_INT64:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((long long *)sortedarray)[iodesc->remap[m]+maplen*v] = ((long long *)array)[m+maplen*v];
                }
            }
            break;
        case PIO_UINT64:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((unsigned long long *)sortedarray)[iodesc->remap[m]+maplen*v] = ((unsigned long long *)array)[m+maplen*v];
                }
            }
            break;
        case PIO_STRING:
            for (int v=0; v < nvars; v++)
            {
                for (int m=0; m < maplen; m++)
                {
                    ((char **)sortedarray)[iodesc->remap[m]+maplen*v] = ((char **)array)[m+maplen*v];
                }
            }
            break;
        default:
            return pio_err(NULL, NULL, PIO_EBADTYPE, __FILE__, __LINE__);
        }
    }
    return PIO_NOERR;
}

/**
 * Compute the maximum aggregate number of bytes. This is called by
 * subset_rearrange_create() and box_rearrange_create().
 *
 * @param ios pointer to the IO system structure.
 * @param iodesc a pointer to decomposition description.
 * @returns 0 for success, error code otherwise.
 * @author Jim Edwards
 */
int
compute_maxaggregate_bytes(iosystem_desc_t *ios, io_desc_t *iodesc)
{
    int maxbytesoniotask = INT_MAX;
    int maxbytesoncomputetask = INT_MAX;
    int maxbytes;
    int mpierr;  /* Return code from MPI functions. */

    /* Check inputs. */
    pioassert(iodesc, "invalid input", __FILE__, __LINE__);

    PLOG((2, "compute_maxaggregate_bytes iodesc->maxiobuflen = %d iodesc->ndof = %d",
          iodesc->maxiobuflen, iodesc->ndof));

    /* Determine the max bytes that can be held on IO task. */
    if (ios->ioproc && iodesc->maxiobuflen > 0)
        maxbytesoniotask = pio_buffer_size_limit / iodesc->maxiobuflen;

    /* Determine the max bytes that can be held on computation task. */
    if (ios->comp_rank >= 0 && iodesc->ndof > 0)
        maxbytesoncomputetask = pio_cnbuffer_limit / iodesc->ndof;

    /* Take the min of the max IO and max comp bytes. */
    maxbytes = min(maxbytesoniotask, maxbytesoncomputetask);
    PLOG((2, "compute_maxaggregate_bytes maxbytesoniotask = %d maxbytesoncomputetask = %d",
          maxbytesoniotask, maxbytesoncomputetask));

    /* Get the min value of this on all tasks. */
    PLOG((3, "before allreaduce maxbytes = %d", maxbytes));
    if ((mpierr = MPI_Allreduce(MPI_IN_PLACE, &maxbytes, 1, MPI_INT, MPI_MIN,
                                ios->union_comm)))
        return check_mpi(NULL, NULL, mpierr, __FILE__, __LINE__);
    PLOG((3, "after allreaduce maxbytes = %d", maxbytes));

    /* Remember the result. */
    iodesc->maxbytes = maxbytes;

    return PIO_NOERR;
}
