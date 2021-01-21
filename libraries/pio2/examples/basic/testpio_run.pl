#!/usr/bin/perl
use strict;
use Cwd;
use Getopt::Long;

my $twopass=0;
my $preambleResource;
my $projectInfo;
my $suites;
my $retry=0;
my $help=0;
my $host;
my $debug=0;
my $pecount=64;
my $enablenetcdf4;
my $result = GetOptions("suites=s@"=>\$suites,"retry"=>\$retry,"host=s"=>\$host,"pecount=i"=>\$pecount,"help"=>\$help,
                        "twopass"=>\$twopass,"debug"=>\$debug);

usage() if($help);
sub usage{
    print "--debug   : Generate the runscript but do not submit it\n";
    print "--help    : Print this message\n";
    print "--host    : Force a hostname for testing\n";
    print "--pecount : Select the processor count on which to run tests\n";
    print "--retry   : Do not repeat tests that have already passed\n";
    print "--suites  : Test only the listed suites (all, snet, pnet, mpiio, ant)\n";
    print "--twopass : Run in two passes - first builds on login node, second submits (required on some systems)\n";
    exit;
}




my $cfgdir = `pwd`;
chomp $cfgdir;
my $clean = 'yes';
my @valid_env = qw(NETCDF_PATH PNETCDF_PATH MPI_LIB MPI_INC F90 FC CC FFLAGS
                   MPICC MPIF90 LDLIBS MACHDEFS);


my @testsuites = qw(all snet pnet mpiio ant );



# The XML::Lite module is required to parse the XML configuration files.
(-f "$cfgdir/../testpio/perl5lib/XML/Lite.pm")  or  die <<"EOF";
** Cannot find perl module \"XML/Lite.pm\" in directory \"$cfgdir/../testpio/perl5lib\" **
EOF

unshift @INC, "$cfgdir/../testpio/perl5lib";
require XML::Lite;
require Utils;

$host = Utils->host() unless(defined $host);
print "host = $host\n";
Utils->loadmodules("$host");
print "host = $host\n";

#if($host eq "jaguar"){
#    print "Using twopass run method\n";
#    $twopass = 1;
#}


my $xml = XML::Lite->new( "build_defaults.xml" );

my $root = $xml->root_element();
my $settings = $xml->elements_by_name($host);
my %attributes = $settings->get_attributes;


foreach(keys %attributes){
    if($attributes{$_} =~  /\$\{?(\w+)\}?/){
	my $envvar = $ENV{$1};
	$attributes{$_}=~ s/\$\{?$1\}?/$envvar/
    }
#    if(/ADDENV_(.*)/){
#	print F "\$ENV{$1}=\"$attributes{$_}:\$ENV{$1}\n\"";
#    }elsif(/ENV_(.*)/){
#        print "set $1 $attributes{$_}\n";
#	print F "\$ENV{$1}=\"$attributes{$_}\n\"";
#    }	
    
}

if(defined $suites){
    @testsuites = @$suites;
}elsif(defined $attributes{testsuites}){
    @testsuites = split(' ',$attributes{testsuites});
}


my $workdir = $attributes{workdir};

print "preamble: $attributes{preamble}\n";
my $corespernode = $attributes{corespernode};
$pecount = $attributes{pecount} if(defined $attributes{pecount});


if(-d $workdir){
    print "Using existing directory $workdir\n";
}else{
    print "Creating directory: ($workdir)\n";
    mkdir $workdir or die "Could not create directory"
}

my $srcdir = "$workdir/src";
my $tstdir = "$srcdir/testpio";
my $testpiodir = cwd();
my $piodir = "$testpiodir/..";
my $date = `date +%y%m%d-%H%M%S`;
my $user = $ENV{USER};
chomp $date;

my $outfile = "$testpiodir/testpio.out.$date";
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
    }elsif(/(.?NETCDF_PATH)/){
	print  F "\$ENV{$1}=\"$attributes{$_}\"\;\n";
	if($attributes{netcdf4} =~ /true/){
	    $enablenetcdf4="--enable-netcdf4";
	}
    }

}

my $run = $attributes{run};
my $exename = "./testpio";
my $log     = "testpio.log.lid";
my $foo;

Utils->runString($host,$pecount,$run,$exename,$log)
    if($run ne "");


print "EXEC command: ($foo)\n";

print F << "EOF";
use strict;
use lib "$cfgdir";
use File::Copy;
use POSIX qw(ceil);

use Utils;

chdir ("$cfgdir");
my \$thispass = shift;
\$thispass = 2 unless(defined \$thispass);

mkdir "$srcdir" if(! -d "$srcdir");

my \$rc = 0xffff & system("rsync -rp $piodir $srcdir");
if(\$rc != 0) {
    system("cp -fr $piodir/pio $srcdir");
    system("cp -fr $piodir/mct $srcdir");
    system("cp -fr $piodir/timing $srcdir");
    system("cp -fr $piodir/testpio $srcdir");
}

my \$confopts = {all=>" --enable-pnetcdf --enable-mpiio --enable-netcdf --enable-timing $enablenetcdf4",
		snet=>"--disable-pnetcdf --disable-mpiio --enable-netcdf --enable-timing $enablenetcdf4",
		pnet=>"--enable-pnetcdf --disable-mpiio --disable-netcdf --enable-timing",
		ant=>"--enable-pnetcdf --enable-mpiio --enable-netcdf --disable-timing $enablenetcdf4",
		 mpiio=>"--disable-pnetcdf --enable-mpiio --disable-netcdf --enable-timing"};


my \$testlist = {all=>["sn01","sn02","sn03","sb01","sb02","sb03","sb04","sb05","sb06","sb07","sb08",
                      "pn01","pn02","pn03","pb01","pb02","pb03","pb04","pb05","pb06","pb07","pb08",
                      "bn01","bn02","bn03","bb01","bb02","bb03","bb04","bb05","bb06","bb07","bb08",
                      "wr01","rd01","apb05","asb01","asb04"],
		snet=>["sn01","sn02","sn03","sb01","sb02","sb03","sb04","sb05","sb06","sb07","sb08","asb01","asb04" ],
		pnet=>["pn01","pn02","pn03","pb01","pb02","pb03","pb04","pb05","pb06","pb07","pb08","apb05"],
		ant=>["sn02","sb02","pn02","pb02","bn02","bb02"],
		mpiio=>["bn01","bn02","bn03","bb01","bb02","bb03","bb04","bb05","bb06","bb07","bb08"]};


my \@netcdf4tests = ("n4n01","n4n02","n4n03","n4b01","n4b02","n4b03","n4b04","n4b05","n4b06","n4b07","n4b08");

if(\"x$attributes{netcdf4}\" eq "xtrue" ){
    \$confopts->{all} .= " --enable-netcdf4";
    \$confopts->{snet} .= " --enable-netcdf4";
    push(\@{\$testlist->{all}},\@netcdf4tests);
    push(\@{\$testlist->{snet}},\@netcdf4tests);
}




#my \$pecnt = $corespernode*ceil($pecount/$corespernode);

unlink("$workdir/wr01.dof.txt") if(-e "$workdir/wr01.dof.txt");
my \$suite;
my \$passcnt=0;
my \$failcnt=0;
my \$host   = "$host";
my \$pecount = $pecount;
my \$run     = "$attributes{run}";

foreach \$suite (qw(@testsuites)){
    my \$confopts = \$confopts->{\$suite};
    my \@testlist = \@{\$testlist->{\$suite}};


    chdir ("$tstdir");
    unless($twopass && \$thispass==2){
	unlink("../pio/Makefile.conf");
	my \$saveprocs;
	# allows for mpi build in configure
       # if("$host" eq "erebus" or "$host" =~ /^yellowstone/){
	#  \$saveprocs=\$ENV{MP_PROCS};
         # \$ENV{MP_PROCS} = 1;
          #system("hostname > $tstdir/hostfile");
          #\$ENV{MP_HOSTFILE}="$tstdir/hostfile";
	  
       # }
	if("$host" eq "yellowstone_pgi") {
	    \$ENV{LD_PRELOAD}="/opt/ibmhpc/pe1304/ppe.pami/gnu/lib64/pami64/libpami.so";
	}
	system("perl ./testpio_build.pl --conopts=\\"\$confopts\\" --host=$host");
        if("$host" eq "erebus" or "$host" =~ /^yellowstone/){
        #  \$ENV{MP_PROCS}=\$saveprocs;
         # delete \$ENV{MP_HOSTFILE};
        } 
    }
    my \$test;

    if($twopass && \$thispass==1 ) {
	if(-e "testpio"){
	    rename("testpio","testpio.\$suite");
	}else{
	    die "Build of testpio.\$suite failed";
	}
    }elsif(($twopass && \$thispass==2 && -e "testpio.\$suite")  or  (-e "../pio/Makefile.conf" && -e "testpio")){
	foreach \$test (\@testlist){
	    if(\$host eq "intrepid" && (\$test =~ /^a/)) {
		print "Skipping async test \$test on \$host\n";
		next;
	    }

	    my \$casedir = "$workdir/\$suite.\$test";
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
            if($twopass){
		copy("$tstdir/testpio.\$suite","testpio");  
            }else{
		copy("$tstdir/testpio","testpio");  
	    }
	    chmod 0755,"testpio";

	    copy("$tstdir/namelists/testpio_in.\$test","testpio_in");
	    if("$host" eq "intrepid"){
		open(F,"$tstdir/namelists/testpio_in.\$test");
		my \@nl = <F>;
		close(F);
		open(F,">testpio_in");
		foreach(\@nl){
		    if(/nprocsIO/){
			print F " nprocsIO = 0\n";
			next;
		    }
		    print F \$_;
		}
		close(F);
	    }


	    mkdir "none" unless(-d "none");
            my \$exename = "./testpio";
	    my \$log = "\$casedir/testpio.out";
#	    my \$log = "\$casedir/testpio.out.$date";
#	    my \$sysstr;
#            if (\$run ne ""){
#		\$sysstr =  Utils->runString(\$host,\$pecount,\$run,\$exename,\$log);
#            }else{
#		\$sysstr = "\$exename > \$log";
#	    }
            my \$sysstr =  Utils->runString(\$host,\$pecount,\$run,\$exename,\$log);
            # Utils->runString($host,$pecount,$run,$exename,$log);
            # print "value for foo is (\$foo)\\n";
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
if($twopass && \$thispass==1){
    chdir("$cfgdir");
    my \$subsys = Utils->submitString("$host",$pecount,$corespernode,"$attributes{submit}","$script");
    if($debug) {
	print "Run ($script) second pass with \$subsys\n";
    }else{
	exec(\$subsys);
    }   
}

print "test complete on $host \$passcnt tests PASS, \$failcnt tests FAIL\\n";
EOF
close(F);
chmod 0755, $script;
my $subsys = Utils->submitString($host,$pecount,$corespernode,$attributes{submit},$script);
if($debug) {
    print "Created script ($script)\n";
}elsif($twopass){
    exec("$script 1");
}else{
    exec($subsys);
}
