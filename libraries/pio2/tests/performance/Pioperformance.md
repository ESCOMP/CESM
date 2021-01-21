# Using pioperf to Measure Performance

To run pioperformance you need a dof input file. I have a whole repo
of them here:
<https://svn-ccsm-piodecomps.cgd.ucar.edu/trunk>

You need an input namelist:

    &pioperf
    decompfile=   '/gpfs/fs1/work/jedwards/sandboxes/piodecomps/576/piodecomp576tasks03dims01.dat',
     pio_typenames = 'pnetcdf'
     rearrangers = 1,2
     nframes = 1
     nvars = 1
     niotasks = 64, 32, 16
     /

in the namelist all of the inputs are arrays and it will test all
combinations of the inputs.  You need to run it on the number of tasks
specified by the input dof There are also some options to use simple
generated dof's instead of files.

## Testing

For the automated test you can generate a decomp internally by setting
decompfile="ROUNDROBIN", or decompfile="BLOCK"

They call init_ideal_dof which internally generates a dof as follows:

    if(doftype .eq. 'ROUNDROBIN') then                                          
       do i=1,varsize                                                           
          compmap(i) = (i-1)*npe+mype+1                                         
       enddo                                                                    
    else if(doftype .eq. 'BLOCK') then                                          
       do i=1,varsize                                                           
          compmap(i) =  (i+varsize*mype)                                        
       enddo                                                                    
    endif
    
The size of the variable is npes*varsize where varsize can be set in
the namelist. varsize is the variable array size per task. You can add
variables by changing nvars in the namelist.

When this is run, output like the following will appear:

    mpiexec -n 4 ./pioperf
    (t_initf) Read in prof_inparm namelist from: pioperf.nl
     Testing decomp: BLOCK
    iotype=           1
    pioperformance.F90         298 Frame:                     1
    pioperformance.F90         301 var:            1
    RESULT: write       BOX         1         4         1        0.0319221529
     RESULT: read       BOX         1         4         1        0.1658564029
    pioperformance.F90         298 Frame:                     1
    pioperformance.F90         301 var:            1
    RESULT: write    SUBSET         1         4         1        0.0438470950
     RESULT: read    SUBSET         1         4         1        0.1623275432

These are read and write rates in units of MB/s for Box and Subset
rearrangers - the time measured is from the call to readdof or
writedof to the completion of the close (since writes are buffered the
close needs to be included).