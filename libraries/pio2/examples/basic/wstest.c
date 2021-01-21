#include <stdio.h>
#include <stdlib.h>
#include <pio.h>
#include <mpi.h>

int main(int argc, char *argv[])
{

 int mype, npe;
 int fh, ierr;
 MPI_Comm comm;
 int niotasks, stride, base;
 int iosysid;
 int *iarray;
 PIO_Offset *imap;
 int nx, ny, nz;

 int ncid;
 int iotype=PIO_IOTYPE_NETCDF;
 int dimids[3], gdim[3];
 int vid;
 int iodesc;
 int i, j, k, ii;
 MPI_Init(&argc,&argv);
 MPI_Comm_size(MPI_COMM_WORLD, &npe);
 MPI_Comm_rank(MPI_COMM_WORLD, &mype);

 PIOc_Init_Intracomm(MPI_COMM_WORLD, npe, 1, 0, PIO_REARR_SUBSET,&iosysid);

 // Create a weak scaling test - 
 nx=6;
 ny=6;
 nz=2;
 gdim[2] = nx;
 gdim[1] = ny*npe;
 gdim[0] = nz;

 iarray = (int *) malloc(nx*ny*nz*sizeof(int));
 imap = (PIO_Offset *) malloc(nx*ny*nz*sizeof(PIO_Offset));
 ii=0;
 for(j=mype*ny; j<(mype+1)*ny; j++){
   for(k=0; k<nz; k++){
     for(i=0; i<nx; i++, ii++){
       iarray[ii] = i + j*gdim[2] + k*gdim[2]*gdim[1];
       imap[ii] = (PIO_Offset) iarray[ii];
       //       printf("%d: imap[%d]=%ld\n",mype,ii,(long) imap[ii]);
     }
   }
 }

 PIOc_InitDecomp(iosysid, PIO_INT, 3, gdim,(PIO_Offset) (nx*ny*nz), imap, &iodesc, NULL, NULL, NULL);

 PIOc_createfile(iosysid, &ncid, &iotype, "wstest.nc", PIO_CLOBBER);
 // Order of dims in c is slowest first
 PIOc_def_dim(ncid, "nx", (PIO_Offset) gdim[2], dimids+2); 
 PIOc_def_dim(ncid, "ny", (PIO_Offset) gdim[1], dimids+1); 
 PIOc_def_dim(ncid, "nz", (PIO_Offset) gdim[0], dimids);

 PIOc_def_var(ncid, "idof", PIO_INT, 3, dimids, &vid);
 
 PIOc_enddef(ncid);

 

 PIOc_write_darray(ncid, vid, iodesc,(PIO_Offset) (nx*ny*nz), iarray, NULL);

 PIOc_closefile(ncid);

 MPI_Finalize();

}
