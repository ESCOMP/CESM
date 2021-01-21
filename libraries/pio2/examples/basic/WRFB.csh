#!/usr/bin/csh
set id = `date "+%m%d%y-%H%M"`
set host = 'kraken'
#set host = 'hopper'
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 125  --bench WRFB --numIO 32  --log ${host}.0125.pnc.iotask_32.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 250  --bench WRFB --numIO 40  --log ${host}.0250.pnc.iotask_40.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 500  --bench WRFB --numIO 80  --log ${host}.0500.pnc.iotask_80.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 1000 --bench WRFB --numIO 160 --log ${host}.1000.pnc.iotask_160.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 2025 --bench WRFB --numIO 320 --log ${host}.2025.pnc.iotask_320.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 4050 --bench WRFB --numIO 640 --log ${host}.4050.pnc.iotask_640.log.${id}

#./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 8100 --bench WRFB --numIO 640 --log ${host}.8100.pnc.iotask_640.log.${id}
#./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 16200 --bench WRFB --numIO 640 --log ${host}.16200.pnc.iotask_640.log.${id}
