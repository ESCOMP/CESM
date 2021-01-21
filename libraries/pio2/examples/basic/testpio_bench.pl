#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use Getopt::Long;
use File::Copy;

my $preambleResource;
my $projectInfo;
my $project;
my $nodecount;
my $suites;
my $retry=0;
my $help=0;
my $host;
my $pecount = 0;
my $bname;
my $partdir;
my $iofmt;
my $rearr;
my $numIO;
my $stride;
my $maxiter;
my $dir;
my $debug=0;
my $numagg;
my $numvars;
my $iodecomp;
#my $logfile = 'testpio.out';

my $logfile = '';
my $logfile_date_suffix = '';  # Optional suffix to logfile date (e.g., a,b,c,etc.)
my $logfile_name_comment = '';
my $logfile_suffix;
my $logfile_name_user = '';  # Overrides automated logfile construction
my $enablenetcdf4;

my $root = '';
my $found = 0;
my $outfile = '';

my $date = '';
my $cal_date = '';  # 2-digit year, month, day

my $use_mpich_env = 1;  # Set to one for MPICH diagnostic environment settings
my $use_cray_env = 1;   # Set to one for use of Cray MPICH extensions
my $use_ibm_env = 1;    # Set to one for use of IBM PE extensions

my $set_mpi_values = 0;  # Set to one if standard MPI settings are present
my $mpi_cb_buffer_size = '';

my $set_romio_values = 0;  # Set to one if MPICH ROMIO settings are present
my $romio_cb_write = '';   # Use automatic, enable, or disable
my $romio_cb_read = '';    # Use automatic, enable, or disable
my $romio_direct_io = '';  # Use automatic, enable, or disable

my $set_ibm_io_values = 0;      # Set to one if IBM PE IO settings are present
my $ibm_io_buffer_size = '';
my $ibm_io_largeblock_io = '';  # Set to "true" or "false"
my $ibm_io_sparse_access = '';  # Set to "true" or "false"

my $set_lustre_values = 0;  # Set to one if Lustre settings are present
my $lfs_stripe_cmd = 'lfs setstripe';
my $lfs_ost_count = -1;
my $lfs_stripe_size = '';

my $argc = $#ARGV + 2;

my $result = GetOptions("suites=s@"=>\$suites,
                        "retry"=>\$retry,
                        "host=s"=>\$host,
			"pecount=i"=>\$pecount,
			"bench=s"=>\$bname,
                        "iofmt=s"=>\$iofmt,
                        "rearr=s"=>\$rearr,
			"numIO|numIOtasks=i"=>\$numIO,
                        "stride=i"=>\$stride,
 			"maxiter=i"=>\$maxiter,
                        "dir=s"=>\$dir,
			"partdir=s"=>\$partdir,
                        "numagg=i"=>\$numagg,
			"numvars=i"=>\$numvars,
                        "decomp=s"=>\$iodecomp,
			"debug"=>\$debug,
		        "log=s"=>\$logfile,
                        "logfile-date-suffix=s"=>\$logfile_date_suffix,
                        "logfile-name-comment=s"=>\$logfile_name_comment,
                        "mpi-env-mpich"=>\$use_mpich_env,
                        "mpi-env-cray"=>\$use_cray_env,
                        "mpi-env-ibm"=>\$use_ibm_env,
                        "mpi-cb-buffer-size=s"=>\$mpi_cb_buffer_size,
                        "romio-cb-write=s"=>\$romio_cb_write,
                        "romio-cb-read=s"=>\$romio_cb_read,
                        "romio-direct-io"=>\$romio_direct_io,
                        "ibm-io-buffer-size=s"=>\$ibm_io_buffer_size,
                        "ibm-io-largeblock-io=s"=>\$ibm_io_largeblock_io,
                        "ibm-io-sparse-access=s"=>\$ibm_io_sparse_access,
                        "lfs-ost-count=i"=>\$lfs_ost_count,
                        "lfs-stripe-size=s"=>\$lfs_stripe_size,
			"logfile-suffix=s"=>\$logfile_suffix,
		        "help"=>\$help);
usage() if($help || ($argc < 2));

sub usage{
    print "--suites                : Test only the listed suites (all, snet, pnet, mpiio, ant, bench)\n";
    print "--retry                 : Do not repeat tests that have already passed\n";
    print "--host                  : Force a hostname for testing\n";
    print "--pecount               : Select the processor count on which to run benchmark (defined in config_bench.xml) \n";
    print "--bench                 : Select the name of the benchmark to run (defined in config_bench.xml)\n";
    print "--iofmt                 : Selects the type of file to write (pnc,snc,bin)\n";
    print "--rearr                 : Selects the type of rearrangement (box,mct,none)\n";
    print "--numIOtasks (--numIO)  : Sets the number of IO tasks used by PIO\n";
    print "--stride                : Sets the stride between IO tasks, Note this is ignored on Blue Gene\n";
    print "--mpi-env-mpich         : Adds MPICH environment settings\n";
    print "--mpi-env-cray          : Adds Cray MPI environment settings\n";
    print "--mpi-env-ibm           : Adds IBM (PE) MPI environment settings\n";
    print "--mpi-cb-buffer-size=N  : Set PIO hint for cb_buffer_size (in bytes)\n";
    print "--romio-cb-write=str    : romio_cb_write hint setting (\"automatic\",\n";
    print "                          \"enable\", or \"disable\") -- default is\n";
    print "                          automatic\n";
    print "--romio-cb-read=str     : romio_cb_write hint setting (\"automatic\",\n";
    print "                          \"enable\", or \"disable\") -- default is\n";
    print "                          automatic\n";
    print "--romio-direct-io=str   : romio_direct_io hint setting (\"automatic\",\n";
    print "                          \"enable\", or \"disable\") -- default is\n";
    print "                          automatic\n";
    print "--ibm-io-buffer-size=N  : Sets the IBM (PE) IO buffer size --\n";
    print "                          give number of bytes or append \"k\" or \"m\"\n";
    print "                          to denote kilobytes or megabytes, respectively\n";
    print "--ibm-io-largeblock-io=str\n";
    print "                        : Set to \"true\" or \"false\"\n";
    print "--ibm-io-sparse-access=str\n";
    print "                        : Set to \"true\" or \"false\"\n";
    print "--lfs-ost-count=N       : Sets the number of OSTs used for striping\n";
    print "                          on a Lustre filesystem\n";
    print "--lfs-stripe-size=N     : Sets the size of the stripe used in the\n";
    print "                          Lustre file system -- stripe size must include\n";
    print "                          units (e.g., \"128k\", \"2m\", \"4g\")\n";
    print "--maxiter               : Sets the number of files to write\n";
    print "--dir                   : Sets the subdirectory for which to write files \n";
    print "--numagg                : Sets the number of MPI-IO aggregators to use \n";
    print "--numvars               : Sets the number of variables to write to each file \n";
    print "--decomp                : Sets the form of the IO-decomposition (x,y,z,xy,xye,xz,xze,yz,yze,xyz,xyze,setblk,cont1d,cont1dm)\n";
    print "--help                  : Print this message\n";
    print "--debug		   : Generate the runscript but do not submit it\n";
    print "--log                   : Manually sets the log output file for the benchmark\n";
    print "--logfile-date-suffix=str\n";
    print "                        : Suffix (e.g., a,b,c,etc.) added to date\n";
    print "                          in logfile\n";
    print "--logfile-name-comment=str\n";
    print "                        : Comment string included in logfile name\n";
    print "--logfile-suffix=str    : Sets the final log file suffix\n";
    print "--partdir               : Sets the input data directory for the MPAS partitioning files\n";
    exit;
}

## Get a string to describe the date

$date = `date +%y%m%d-%H%M%S`;
$cal_date = `date +%y%m%d`;

chomp $date;
chomp $cal_date;

## See if standard MPI options are requested

if ($mpi_cb_buffer_size ne '') {
  $set_mpi_values = 1;  # True
}


## See if MPICH ROMIO options are requested

if (($romio_cb_write ne '') || ($romio_cb_read ne '')
    || ($romio_direct_io ne '')) {

  if (($romio_cb_write ne '') && ($romio_cb_write ne 'automatic')
      && ($romio_cb_write ne 'enable') && ($romio_cb_write ne 'disable')) {
    print "\nError: Invalid romio-cb-write entry\n\n";
    exit(-1);
  }

  if (($romio_cb_read ne '') && ($romio_cb_read ne 'automatic')
      && ($romio_cb_read ne 'enable') && ($romio_cb_read ne 'disable')) {
    print "\nError: Invalid romio-cb-read entry\n\n";
    exit(-1);
  }

  if (($romio_direct_io ne '') && ($romio_direct_io ne 'automatic')
      && ($romio_direct_io ne 'enable') && ($romio_direct_io ne 'disable')) {
    print "\nError: Invalid romio-direct-io entry\n\n";
    exit(-1);
  }

  $set_romio_values = 1;  # True
}

## See if IBM PE IO options are requested

if (($ibm_io_buffer_size ne '') || ($ibm_io_largeblock_io ne '')
    || ($ibm_io_sparse_access ne '')) {

  if (($ibm_io_largeblock_io ne '') && ($ibm_io_largeblock_io ne 'true')
      && ($ibm_io_largeblock_io ne 'false')) {
    print "\nError: Invalid ibm-io-largeblock-io entry\n\n";
    exit(-1);
  }

  if (($ibm_io_sparse_access ne '') && ($ibm_io_sparse_access ne 'true')
      && ($ibm_io_sparse_access ne 'false')) {
    print "\nError: Invalid ibm-io-sparse-access entry\n\n";
    exit(-1);
  }

  $set_ibm_io_values = 1;  # True
}

## See if Lustre settings are requested

if ($lfs_ost_count > 0) {
  $set_lustre_values = 1;  # True

  $lfs_stripe_cmd .= " -c " . $lfs_ost_count;
}

if ($lfs_stripe_size ne "") {
  $set_lustre_values = 1;  # True

  $lfs_stripe_cmd .= " -s " . $lfs_stripe_size;
}


## Append an underscore to an existing logfile name comment

if ($logfile_name_comment ne '') {
  $logfile_name_comment .= '_';
}

my $cfgdir = `pwd`;
chomp $cfgdir;
my $clean = 'yes';
my @valid_env = qw(NETCDF_PATH PNETCDF_PATH MPI_LIB MPI_INC F90 FC CC ALLCFLAGS FFLAGS
                   MPICC MPIF90 LDLIBS);

my @testsuites = qw(bench);

# The XML::Lite module is required to parse the XML configuration files.
(-f "$cfgdir/../testpio/perl5lib/XML/Lite.pm")  or  die <<"EOF";
** Cannot find perl module \"XML/Lite.pm\" in directory \"$cfgdir/../testpio/perl5lib\" **
EOF

unshift @INC, "$cfgdir/../testpio","$cfgdir/../testpio/perl5lib";
require XML::Lite;
require Utils;

$host = Utils->host() unless(defined $host);
Utils->loadmodules("$host");

my $xml = XML::Lite->new( "$cfgdir/../testpio/build_defaults.xml" );

$root = $xml->root_element();
my $settings = $xml->elements_by_name($host);
my %attributes = $settings->get_attributes;


foreach(keys %attributes){
    if(/ADDENV_(.*)/){
#	print F "\$ENV{$1}=\"$attributes{$_}:\$ENV{$1}\"\;\n";
	print "\$ENV{$1}=\"$attributes{$_}:\$ENV{$1}\"\;\n";
    }elsif(/ENV_(.*)/){
        print "set $1 $attributes{$_}\n";
#	print F "\$ENV{$1}=\"$attributes{$_}\"\;\n";
	print "\$ENV{$1}=\"$attributes{$_}\"\;\n";
    }elsif(/NETCDF_PATH/){
	if($attributes{NETCDF_PATH} =~ /netcdf-4/){
	    $enablenetcdf4="--enable-netcdf4";
	}
    }    
}

if(defined $suites){
    @testsuites = @$suites;
}elsif(defined $attributes{testsuites}){
    @testsuites = split(' ',$attributes{testsuites});
}



my $workdir = $attributes{workdir};

$workdir =~ s/\${(.*)}/$ENV{$1}/;

if(-d $workdir){
    print "Using existing directory $workdir\n";
}else{
    print "Creating directory $workdir\n";
    mkdir $workdir or die "Could not create directory"
}

my $config = XML::Lite->new("$cfgdir/../testpio/config_bench.xml");
my $elm = $config->root_element();
print "pecount is $pecount\n";

my $ldx=0;
my $ldy=0;
my $ldz=0;
my $partfile;
my $nx_global=0;
my $ny_global=0;
my $nz_global=0;

my %configuration = ( ldx => 0,
                      ldy => 0,
                      ldz => 0,
                      partfile => 'null',
                      partdir  => 'foo',
                      iofmt => 'pnc', 
                      rearr => 'box',
                      numprocsIO => 10,
   		      stride => -1,
                      maxiter => 10,
                      dir => './none/',
		      iodecomp => 'yze',
                      numagg => -1,
                      numvars => 10,
                      set_mpi_values => 0,
                      mpi_cb_buffer_size => '',
                      set_romio_values => 0,
                      romio_cb_write => '',
                      romio_cb_read => '',
                      romio_direct_io => '',
                      set_ibm_io_values => 0,
                      ibm_io_buffer_size => '',
                      ibm_io_largeblock_io => '',
		      logfile_suffix => 'testpio.out',
                      ibm_io_sparse_access => '');

#-------------------------------------------------
# Modify the configuration based on arguments
#-------------------------------------------------
if (defined $iofmt)   {$configuration{'iofmt'} = $iofmt;}
if (defined $rearr)   {$configuration{'rearr'} = $rearr;}
if (defined $numIO)   {$configuration{'numprocsIO'} = $numIO;}
if (defined $stride)  {$configuration{'stride'} = $stride;}
if (defined $maxiter) {$configuration{'maxiter'} = $maxiter;}
if (defined $numvars) {$configuration{'numvars'} = $numvars;}
if (defined $dir)     {$configuration{'dir'} = $dir;}
if (defined $partdir) {$configuration{'partdir'} = $partdir;}
if (defined $numagg)  {$configuration{'numagg'} = $numagg;}
if (defined $logfile_suffix) {$configuration{'logfile_suffix'}=$logfile_suffix;}


if (defined $set_mpi_values) {
  $configuration{'set_mpi_values'} = $set_mpi_values;
}

if (defined $mpi_cb_buffer_size) {
  $configuration{'mpi_cb_buffer_size'} = $mpi_cb_buffer_size;
}

if (defined $set_romio_values) {
  $configuration{'set_romio_values'} = $set_romio_values;
}

if (defined $romio_cb_write) {
  $configuration{'romio_cb_write'} = $romio_cb_write;
}

if (defined $romio_cb_read) {
  $configuration{'romio_cb_read'} = $romio_cb_read;
}

if (defined $romio_direct_io) {
  $configuration{'romio_direct_io'} = $romio_direct_io;
}

if (defined $set_ibm_io_values) {
  $configuration{'set_ibm_io_values'} = $set_ibm_io_values;
}

if (defined $ibm_io_buffer_size) {
  $configuration{'ibm_io_buffer_size'} = $ibm_io_buffer_size;
}

if (defined $ibm_io_largeblock_io) {
  $configuration{'ibm_io_largeblock_io'} = $ibm_io_largeblock_io;
}

if (defined $ibm_io_sparse_access) {
  $configuration{'ibm_io_sparse_access'} = $ibm_io_sparse_access;
}

# See if you can find the general benchmark description first
my @blist = $config->elements_by_name("BenchConfig");
my $bchildren = $elm->get_children();

$found=0;

foreach my $child (@blist) {
  my %atts = $child->get_attributes;
  my $bn = $atts{"bench_name"};
  if ($bn =~ $bname) {
     my $nx_global = $atts{"nx_global"}; $configuration{'nx_global'} = $nx_global;
     my $ny_global = $atts{"ny_global"}; $configuration{'ny_global'} = $ny_global;
     my $nz_global = $atts{"nz_global"}; $configuration{'nz_global'} = $nz_global;
     $found = 1;
  }
}
if(!$found) {
  printf "Could not find configuration for benchmark: %s\n" ,$bname;
  exit(-1);
} else {
  print "nx_global: $configuration{'nx_global'} ny_global: $configuration{'ny_global'} nz_global: $configuration{'nz_global'}\n";
}

$root = "CompConfig";
my @list = $config->elements_by_name($root);
my $children = $elm->get_children();

$found=0;

foreach my $child (@list ) {
  my %atts = $child->get_attributes;
  my $name = $child->get_name();
  my @keys = keys(%atts);
  my $np = $atts{"nprocs"};
  my $bn = $atts{"bench_name"};
#  printf "bench_name is $bn\n";
#  printf "bname is $bname\n";
  if(($np eq $pecount) & ($bn =~ $bname)) {
     my @gchildren = $child->get_children();
     foreach my $grandchild (@gchildren) {
	   my $name  = $grandchild->get_name();
           my $value = $grandchild->get_text();
	   $configuration{$name}=$value;
     }
     $found = 1;
  } 
}
#my $suffix = $bname . "-" . $pecount;
my $suffix = $bname . "_PE-" . $pecount . "_IO-" . $iofmt . "-" . $numIO;

## Add standard MPI values to the suffix

if ($set_mpi_values != 0) {
  $suffix .= "_MPI";

  if ($mpi_cb_buffer_size ne '') { $suffix .= '-b' . $mpi_cb_buffer_size; }
}

## Add MPICH/ROMIO values to the suffix

if ($set_romio_values != 0) {
  $suffix .= "_ROMIO";

  if ($romio_cb_write ne "") {
    $suffix .= "-w";

    if ($romio_cb_write eq "automatic") { $suffix .= "A"; }
    elsif ($romio_cb_write eq "enable") { $suffix .= "E"; }
    elsif ($romio_cb_write eq "disable") { $suffix .= "D"; }
  }

  if ($romio_cb_read ne "") {
    $suffix .= "-r";

    if ($romio_cb_read eq "automatic") { $suffix .= "A"; }
    elsif ($romio_cb_read eq "enable") { $suffix .= "E"; }
    elsif ($romio_cb_read eq "disable") { $suffix .= "D"; }
  }

  if ($romio_direct_io ne "") {
    $suffix .= "-d";

    if ($romio_direct_io eq "automatic") { $suffix .= "A"; }
    elsif ($romio_direct_io eq "enable") { $suffix .= "E"; }
    elsif ($romio_direct_io eq "disable") { $suffix .= "D"; }
  }
}


## Add IBM PE IO values to the suffix

if ($set_ibm_io_values != 0) {
  $suffix .= "_IBM";

  if ($ibm_io_buffer_size ne '') { $suffix .= "-b" . $ibm_io_buffer_size; }

  if ($ibm_io_largeblock_io ne '') {
    $suffix .= "-l";

    if ($ibm_io_largeblock_io eq "true") { $suffix .= "T"; }
    elsif ($ibm_io_largeblock_io eq "false") { $suffix .= "F"; }
  }

  if ($ibm_io_sparse_access ne '') {
    $suffix .= "-s";

    if ($ibm_io_sparse_access eq "true") { $suffix .= "T"; }
    elsif ($ibm_io_sparse_access eq "false") { $suffix .= "F"; }
  }

}

## Add Lustre values to the suffix

if ($set_lustre_values != 0) {
  $suffix .= "_OST";

  if ($lfs_ost_count != 0) {
    $suffix .= "-c" . $lfs_ost_count;
  }

  if ($lfs_stripe_size ne "") {
    $suffix .= "-s". $lfs_stripe_size;
  }
}

## Build the logfile name

if ($logfile_name_user ne '') {
  $logfile = $logfile_name_user;
} else {
#  $logfile = $cal_date . $logfile_date_suffix . "_" . $host . "_"
    $logfile = $host . "_" . $logfile_name_comment . $suffix . "_" . $logfile_suffix;
}

my $testname = "bench." . $date . "." . $suffix;

printf "testname: %s\n",$testname;

if (defined $iodecomp) {$configuration{'iodecomp'} = $iodecomp;}

#print "ldx: $configuration{'ldx'} ldy: $ldy ldz: $ldz\n";

if ($found) {
  print "ldx: $configuration{'ldx'} ldy: $configuration{'ldy'} ldz: $configuration{'ldz'}\n";
  $outfile = "$cfgdir/testpio_in." . $suffix;
  unlink("$outfile") if(-e "$outfile");

  open(F,"+> $outfile");
  gen_io_nml();       # Generate the io_nml namelist
  gen_compdof_nml();  # Generate the compdof_nml namelist
  if(defined $iodecomp) {
      gen_iodof_nml();    # Generate the iodof_nml namelist
  }
  gen_prof_inparm();  # Generate the prof_inparm namelist

  close(F);
} else {
  printf "Could not find configuration for benchmark: %s on %d MPI tasks \n" ,$bname, $pecount;
  exit(-1);
}

my $corespernode = $attributes{corespernode};

my $srcdir = "$workdir/src";
my $tstdir = "$srcdir/testpio";
copy("$outfile","$tstdir");
my $testpiodir = cwd();
my $piodir = "$testpiodir/..";
# my $date = `date +%y%m%d-%H%M%S`;
my $user = $ENV{USER};
chomp $date;

$outfile = "$testpiodir/testpio.out.$date";
my $script  = "$testpiodir/testpio.sub.$date";

open(F,">$script");
print F "#!/usr/bin/perl\n";
$preambleResource = Utils->preambleResource("$host","$pecount","$corespernode");
print F $preambleResource;
print F "$attributes{preamble}\n";

# Create a valid project string for this user
$projectInfo = Utils->projectInfo("$host","$user");
print F $projectInfo;

my @env;
foreach(keys %attributes){
#    if($attributes{$_} =~  /\$\{?(\w+)\}?/){
#	my $envvar = $ENV{$1};
#	$attributes{$_}=~ s/\$\{?$1\}?/$envvar/
#    }
    if(/ADDENV_(.*)/){
	print F "\$ENV{$1}=\"$attributes{$_}:\$ENV{$1}\"\;\n";
    }elsif(/ENV_(.*)/){
        print "set $1 $attributes{$_}\n";
	print F "\$ENV{$1}=\"$attributes{$_}\"\;\n";
    }	
    
}


my $run = $attributes{run};
my $exename = "./testpio";

#my $foo= Utils->runString($host,$pecount,$run,$exename,$log);
#print "EXEC command: ($foo)\n";

print F << "EOF";
use strict;
use lib "$cfgdir";
use File::Copy;
use File::Path;
use POSIX qw(ceil);
#unshift \@INC, "$cfgdir/../testpio";

#chmod 0755,"$cfgdir/../testpio/Utils.pm";
use Utils;

chdir ("$cfgdir");



mkdir "$srcdir" if(! -d "$srcdir");

my \$rc = 0xffff & system("rsync -rp $piodir $srcdir");
if(\$rc != 0) {
    print "rsync failed with \$rc, copying files\n";
    system("cp -fr $piodir/pio $srcdir");
    system("cp -fr $piodir/mct $srcdir");
    system("cp -fr $piodir/timing $srcdir");
    system("cp -fr $piodir/testpio $srcdir");
}

my \$confopts = {bench=>"--enable-pnetcdf --enable-mpiio --enable-netcdf --enable-timing $enablenetcdf4"};
#my \$confopts = {bench=>""};

my \$testlist = {bench=>["generated"]};

unlink("$workdir/wr01.dof.txt") if(-e "$workdir/wr01.dof.txt");
my \$suite;
my \$passcnt=0;
my \$failcnt=0;
my \$host   = "$host";
my \$pecount = $pecount;
my \$run     = "$attributes{run}";

if ($use_mpich_env != 0) {
    \$ENV{'MPICH_ENV_DISPLAY'} = '1'; # this displays all the MPICH environment variables
}

if ($use_cray_env != 0) {
    \$ENV{'MPICH_MPIIO_XSTATS'} = '1'; # this outputs MPI-IO statistics
    \$ENV{'MPICH_MPIIO_HINTS_DISPLAY'} = '1';  # Displays hints for each file
    \$ENV{'MPICH_MPIIO_CB_ALIGN'} = '2';  # Do not allign to lustre stripes
}

if ($use_ibm_env != 0) {
    if ('$ibm_io_buffer_size' ne '') {
        \$ENV{'MP_IO_BUFFER_SIZE'} = "$ibm_io_buffer_size";
    }
}

foreach \$suite (qw(@testsuites)){
    my \$confopts = \$confopts->{\$suite};
#    my \@testlist = \@{\$testlist->{\$suite}};
    my \@testlist = \"$suffix";
#    unlink("../pio/Makefile.conf");
#    copy("testpio_in","$tstdir"); # copy the namelist file into test directory
    
    chdir ("$tstdir");
    my \$test;
    my \$run = "$attributes{run}";
    unless(-e "$tstdir/testpio"){
      system("perl ./testpio_build.pl --conopts=\\"\$confopts\\" --host=$host");
    }
    if(-e "../pio/Makefile.conf" && -e "testpio"){
	foreach \$test (\@testlist){
	    my \$casedir = "$workdir/\$suite.$date.\$test";
	    mkdir \$casedir unless(-d \$casedir);
	    chdir(\$casedir) or die "Could not cd to \$casedir";
	    print "\$suite \$test    ";
	    if($retry && -e "TestStatus"){
		open(T,"TestStatus");
		my \$result = <T>;
		close(T);
		if(\$result =~ /PASS/){
		    \$passcnt++;
		    print "Test already PASSED\\n";
		    next;
		}
	    }

	    unlink("testpio") if(-e "testpio");

	    copy("$tstdir/testpio","testpio");


	    chmod 0755,"testpio";
#	    symlink("$tstdir/namelists/testpio_in.\$test","testpio_in");
#	    symlink("$tstdir/testpio_in.\$test","testpio_in");
	    symlink("$tstdir/testpio_in.\$test","testpio_in");
            rmtree "none" unless(! -d "none");
	    mkdir "none" unless(-d "none");

            if ($set_lustre_values != 0) {
              system("$lfs_stripe_cmd" . " " . "none");
            }

	    my \$exename = "./testpio";
            my \$log = "\$casedir/$logfile";
	    unlink("\$log") if(-e "\$log");

            my \$sysstr =  Utils->runString(\$host,\$pecount,\$run,\$exename,\$log);
            print "Running \$sysstr\\n";
	    system(\$sysstr);
	    open(LOG,\$log);
	    my \@logout = <LOG>;
	    close(LOG);
	    
	    my \$cnt = grep /testpio completed successfully/ , \@logout;
            open(T,">TestStatus");
	    if(\$cnt>0){
		\$passcnt++;
		print "PASS \\n";
		print T "PASS \\n";
	    }else{
		\$failcnt++;
		print "FAIL \\n";
		print T "FAIL \\n";
	    }
	    close(T);
	}
    }else{
	print "suite \$suite FAILED to configure or build\\n";	
    }
}
print "test complete on $host \$passcnt tests PASS, \$failcnt tests FAIL\\n";
EOF
close(F);
chmod 0755, $script;
my $subsys = Utils->submitString($host,$pecount,$corespernode,$attributes{submit},$script);

if ($debug) {
  print "Submission command: ($subsys)\n";
} else {
  print "submit: ($subsys)\n";
}

if($debug) {
    print "Created script ($script)\n";
} else {
#    exec("$subsys");
    my @foo2 = `$subsys`;
    my $jobid;
    foreach my $i (@foo2) {
     ($jobid) = ($i =~/([0-9]+)/);
#     print "jobid: ($jobid)\n";
    }
#    exec("cqwait $jobid");
}


sub gen_compdof_nml{
  print F "&compdof_nml\n";
  print F "grddecomp = 'setblk'\n";
  print F "gdx = $configuration{'ldx'}\n";
  print F "gdy = $configuration{'ldy'}\n";
  print F "gdz = $configuration{'ldz'}\n";
  print F "/\n";
}
sub gen_iodof_nml {
  print F "&iodof_nml\n";
  print F "grddecomp = '$configuration{'iodecomp'}'\n";
  print F "/\n";
}
sub gen_prof_inparm {
  print F "&prof_inparm\n";
  print F "profile_disable = .false.\n";
  print F "profile_barrier = .true.\n";
  print F "profile_single_file = .false.\n";
  print F "profile_depth_limit = 10\n";
  print F "profile_detail_limit = 0\n";
  print F "/\n";
}
sub gen_io_nml {
  print F "&io_nml\n";
  print F "casename       = '$suffix'\n";
  print F "nx_global      = $configuration{'nx_global'}\n";
  print F "ny_global      = $configuration{'ny_global'}\n";
  print F "nz_global      = $configuration{'nz_global'}\n";
  print F "nvars        = $configuration{'numvars'}\n";
  print F "iofmt          = '$configuration{'iofmt'}'\n";
  print F "rearr          = '$configuration{'rearr'}'\n";
  print F "nprocsIO       = $configuration{'numprocsIO'}\n";
  print F "stride         = $configuration{'stride'}\n";
  print F "maxiter        = $configuration{'maxiter'}\n";
  print F "dir            = '$configuration{'dir'}'\n";
  print F "part_input     = '$configuration{'partdir'}/$configuration{'partfile'}'\n";
  print F "num_aggregator = $configuration{'numagg'}\n";

  print F "set_mpi_values = $configuration{'set_mpi_values'}\n";

  if ($configuration{'set_mpi_values'} != 0) {
    print F "mpi_cb_buffer_size = '$configuration{'mpi_cb_buffer_size'}'\n";
  }

  print F "set_romio_values = $configuration{'set_romio_values'}\n";

  if ($configuration{'set_romio_values'} != 0) {
    print F "romio_cb_write = '$configuration{'romio_cb_write'}'\n";
    print F "romio_cb_read = '$configuration{'romio_cb_read'}'\n";
    print F "romio_direct_io = '$configuration{'romio_direct_io'}'\n";
  }

  print F "set_ibm_io_values = $configuration{'set_ibm_io_values'}\n";

  if ($configuration{'set_ibm_io_values'} != 0) {
    print F "ibm_io_buffer_size = '$configuration{'ibm_io_buffer_size'}'\n";
    print F "ibm_io_largeblock_io = '$configuration{'ibm_io_largeblock_io'}'\n";
    print F "ibm_io_sparse_access = '$configuration{'ibm_io_sparse_access'}'\n";
  }

  print F "DebugLevel  = 0\n";
  print F "compdof_input = 'namelist'\n";
  if(defined $iodecomp) {
     print F "iodof_input = 'namelist'\n";
  }
  print F "compdof_output = 'none'\n";
  print F "/\n";
}
