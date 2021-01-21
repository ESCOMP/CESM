#!/usr/bin/csh
set id = `date "+%m%d%y-%H%M"`
set host = 'kraken'
#./testpio_bench.pl --maxiter 10 --iofmt pnc --numvars 10 --pecount 120 --bench MPASA30km -numIO 20 --partdir /lustre/scratch/jdennis/MPAS --logfile-suffix trunk_close 
#./testpio_bench.pl --maxiter 10 --iofmt pnc --numvars 10 --pecount 240 --bench MPASA30km -numIO 40 --partdir /lustre/scratch/jdennis/MPAS --logfile-suffix trunk_close
#./testpio_bench.pl --maxiter 10 --iofmt pnc --numvars 10 --pecount 480 --bench MPASA30km -numIO 80 --partdir /lustre/scratch/jdennis/MPAS --logfile-suffix trunk_close
#./testpio_bench.pl --maxiter 10 --iofmt pnc --numvars 10 --pecount 960 --bench MPASA30km -numIO 160 --partdir /lustre/scratch/jdennis/MPAS --logfile-suffix trunk_close
#./testpio_bench.pl --maxiter 10 --iofmt pnc --numvars 10 --pecount 1920 --bench MPASA30km -numIO 320 --partdir /lustre/scratch/jdennis/MPAS --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --numvars 10 --pecount 3840 --bench MPASA30km -numIO 320 --partdir /lustre/scratch/jdennis/MPAS --logfile-suffix trunk_close

