#!/usr/bin/csh
set id = `date "+%m%d%y-%H%M"`
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 64 --bench WRFB --numIO 12 --log kraken.0064.pnc.iotask_12.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 80 --bench POPB --numIO 30 --log kraken.0080.pnc.iotask_30.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 64 --bench POPC --numIO 12 --log kraken.0064.pnc.iotask_12.log.${id}
./testpio_bench.pl --maxiter 2  --iofmt pnc --pecount 64 --bench POPD --numIO 12 --log kraken.0064.pnc.iotask_12.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 64 --bench CAM05 --numIO 12 --log kraken.0064.pnc.iotask_12.log.${id}
