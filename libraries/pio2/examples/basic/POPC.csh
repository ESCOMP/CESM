#!/usr/bin/csh
set id = `date "+%m%d%y-%H%M"`
set host = 'kraken'
#set host = 'hopper'
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 64  --bench POPC  --numIO 10  --log ${host}.0064.pnc.iotask_10.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 128 --bench POPC  --numIO 20  --log ${host}.0128.pnc.iotask_20.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 256 --bench POPC  --numIO 40  --log ${host}.0256.pnc.iotask_40.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 512 --bench POPC  --numIO 80  --log ${host}.0512.pnc.iotask_80.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 1000 --bench POPC --numIO 160 --log ${host}.1000.pnc.iotask_160.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 1600 --bench POPC --numIO 160 --log ${host}.1600.pnc.iotask_160.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 2000 --bench POPC --numIO 320 --log ${host}.2000.pnc.iotask_320.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 4000 --bench POPC --numIO 640 --log ${host}.4000.pnc.iotask_640.log.${id}
#./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 8000 --bench POPC --numIO 640 --log ${host}.8000.pnc.iotask_640.log.${id}
