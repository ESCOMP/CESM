#!/usr/bin/csh
set id = `date "+%m%d%y-%H%M"`
set host = 'kraken'
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 64 --bench MPASA60km -numIO 12 --partdir /lustre/scratch/jdennis/MPAS --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 120 --bench MPASA60km -numIO 20 --partdir /lustre/scratch/jdennis/MPAS --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 240 --bench MPASA60km -numIO 40 --partdir /lustre/scratch/jdennis/MPAS --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 480 --bench MPASA60km -numIO 80 --partdir /lustre/scratch/jdennis/MPAS --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 960 --bench MPASA60km -numIO 160 --partdir /lustre/scratch/jdennis/MPAS --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 1020 --bench MPASA60km -numIO 170 --partdir /lustre/scratch/jdennis/MPAS --logfile-suffix trunk_close

