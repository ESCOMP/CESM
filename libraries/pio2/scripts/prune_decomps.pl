#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;

my $rundir="";
my $exe="";
my $nargs = 0;
my $verbose = 0;

# Reg expression that match the pio decomposition file names
my $PIO_DECOMP_FNAMES = "^piodecomp";
my $BEGIN_STACK_TRACE = "Obtained";

# Remove duplicate decomposition files in "dirname"
sub rem_dup_decomp_files
{
    my($dirname) = @_;
    # Find files in current directory that are
    # named *piodecomp* - these are the pio 
    # decomposition files
    opendir(F,$dirname);
    #my @decompfiles = grep(/^piodecomp/,readdir(F));
    my @decompfile_info_tmp = map{ {FNAME=>$_, SIZE=>-s $_, IS_DUP=>0} } grep(/${PIO_DECOMP_FNAMES}/,readdir(F));
    closedir(F);
    my @decompfile_info = sort { $a->{SIZE} <=> $b->{SIZE} } @decompfile_info_tmp;
    my $ndecompfile_info = @decompfile_info;

    #for(my $i=0; $i<$ndecompfile_info; $i++){
    #  print "File : $decompfile_info[$i]->{FNAME} , size = $decompfile_info[$i]->{SIZE}\n";
    #}
    
    my $rmfile=0;
    # Compare the decomposition files to find
    # duplicates - and delete the dups
    for(my $i=0; $i<$ndecompfile_info; $i++){
        my $file  = $decompfile_info[$i]->{FNAME};
        my $fsize  = $decompfile_info[$i]->{SIZE};
        next if($decompfile_info[$i]->{IS_DUP});
        for(my $j=$i+1;$j<$ndecompfile_info;$j++){
            my $nfile = $decompfile_info[$j]->{FNAME};
            my $f2size = $decompfile_info[$j]->{SIZE};
            next if($decompfile_info[$j]->{IS_DUP});
            last if($fsize != $f2size);
            if($verbose){
                print "Comparing $file, size=$fsize, $nfile, size=$f2size\n";
            }
            if($fsize == $f2size){
                open(F1,$file);
                my @file1 = <F1>;
                open(F2,$nfile);
                my @file2 = <F2>;
                $rmfile = 1;
                foreach my $line (@file1){
                    my $nline = shift (@file2);
                    # Ignore stack traces when comparing files
                    # The stack traces start with a line containing
                    # "Obtained" 
                    # Also, stack trace is the last line being
                    # compared
                    if(($line =~ /${BEGIN_STACK_TRACE}/)
                          && ($nline =~ /${BEGIN_STACK_TRACE}/)){
                        if($verbose){
                            print "Files $file and $nfile are the same (ignoring stack traces)\n";
                        }
                        last;
                    }
                    next if($line eq $nline);
                    # Files are different, don't remove    
                    $rmfile = 0;
                    last;
                }
                close(F1);
                close(F2);
                if($rmfile == 1){
                    $decompfile_info[$j]->{IS_DUP} = 1;
                }
            }
        }
    }
    for(my $i=0; $i<$ndecompfile_info; $i++){
        if($decompfile_info[$i]->{IS_DUP}){
            unlink($decompfile_info[$i]->{FNAME});
        }
    }
}

# Decode the stack traces in the pio decomposition files
sub decode_stack_traces
{
    # dirname => Directory that contains decomp files
    # exe => executable (including path) that generated
    #         the decomposition files
    my($dirname, $exe) = @_;
    # Decode/Translate the stack trace
    opendir(F,$dirname);
    my @decompfiles = grep(/${PIO_DECOMP_FNAMES}/,readdir(F));
    closedir(F);
    my $ndecompfiles = @decompfiles;
    for(my $i=0; $i< $ndecompfiles; $i++){
        my $file = $decompfiles[$i];
        open(F1,$file);
        my @file1 = <F1>;
        close(F1);
        open(F1,">$file");
        foreach(@file1){
            # Find stack addresses in the file and use
            # addrline to translate/decode the filenames and
            # line numbers from it
            if(/\[(.*)\]/){
                my $decode = `addr2line -e $exe $1`;
                print F1 "$decode\n";
                print  "$decode\n";
            }else{
                print F1 $_;
            }
        }
        close(F1);
    }
}

sub print_usage_and_exit()
{
    print "\nUsage :\n./prune_decomps.pl --decomp-prune-dir=<PRUNE_DECOMP_DIR> \n";
    print "\tOR\n";
    print "./prune_decomps.pl <PRUNE_DECOMP_DIR> \n";
    print "The above commands can be used to remove duplicate decomposition\n";
    print "files in <PRUNE_DECOMP_DIR> \n";
    print "Available options : \n";
    print "\t--decomp-prune-dir : Directory that contains the decomp files to be pruned\n";
    print "\t--exe      : Executable that generated the decompositions \n";
    print "\t--verbose  : Verbose debug output\n";
    exit;
}

# Main program

# Read input args
GetOptions(
    "decomp-prune-dir=s"    => \$rundir,
    "exe=s"             => \$exe,
    "verbose"               => \$verbose
);

$nargs = @ARGV;

if($rundir eq ""){
    $rundir = shift;
    if($rundir eq ""){
        &print_usage_and_exit();
    }
}
if($verbose){ print "Removing duplicate decomposition files from : \"", $rundir, "\"\n"; }
&rem_dup_decomp_files($rundir);

if($exe ne ""){
    if($verbose){ print "Decoding stack traces for decomposition files from : \"", $rundir, "\"\n"; }
    &decode_stack_traces($rundir, $exe);
}

    
