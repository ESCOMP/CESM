#!/usr/bin/csh
set id = `date "+%m%d%y-%H%M"`
set host = 'kraken'
#set host = 'hopper'
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 24  --bench POPB --numIO 4  --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 80  --bench POPB --numIO 12 --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 160 --bench POPB --numIO 24 --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 320 --bench POPB --numIO 48 --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 640 --bench POPB --numIO 96 --logfile-suffix trunk_close

