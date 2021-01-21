#!/usr/bin/perl
use strict;
use Getopt::Long;

my $host;
my @conopts;
my $result = GetOptions("host=s"=>\$host,"conopts=s@"=>\@conopts);


my $cfgdir = `pwd`;
chomp $cfgdir;
my $clean = 'yes';
my @valid_env = qw(NETCDF_PATH PNETCDF_PATH MPI_LIB MPI_INC  FC CC CFLAGS FFLAGS
                   MACHDEFS MPICC MPIFC LDLIBS CPPDEFS MEMMON_PATH CXX MPICXX);


# The XML::Lite module is required to parse the XML configuration files.
(-f "$cfgdir/perl5lib/XML/Lite.pm")  or  die <<"EOF";
** Cannot find perl module \"XML/Lite.pm\" in directory \"$cfgdir/perl5lib\" **
EOF

unshift @INC, "$cfgdir/perl5lib";
require XML::Lite;
require Utils;

my $xml = XML::Lite->new( "build_defaults.xml" );

$host = Utils->host() unless(defined $host);

print "host=$host\n";
my $root = $xml->root_element();
my $settings = $xml->elements_by_name($host);
my %attributes = $settings->get_attributes;
my @env;

foreach(@valid_env){
    push(@env,"$_=\"$attributes{$_}\"") if(defined($attributes{$_}));
}

foreach(keys %attributes){
    if($attributes{$_} =~  /\$\{?(\w+)\}?/){
	my $envvar = $ENV{$1};
	$attributes{$_}=~ s/\$\{?$1\}?/$envvar/
    }
    if(/ADDENV_(.*)/){
	$ENV{$1}="$attributes{$_}:$ENV{$1}";
    }elsif(/ENV_(.*)/){
        print "set $1 $attributes{$_}\n";
	$ENV{$1}="$attributes{$_}";
    }	
    
}


my $conopts = "@conopts $attributes{conopts}" if(defined($attributes{conopts}));

chdir('../pio');

my $syscmd = "./configure $conopts @env ";

print "Building for $host using $syscmd\n";

system($syscmd);

chdir('../timing');
my $dir;
foreach $dir (qw(timing pio testpio)){
    chdir("$cfgdir/../$dir") or die "Cannot cd to $cfgdir/../$dir: $!\n";;
    print "Building in $dir\n";
    system('gmake clean') if($clean eq 'yes');
    system('gmake');
}

