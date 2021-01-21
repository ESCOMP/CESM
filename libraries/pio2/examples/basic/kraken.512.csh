#!/usr/bin/csh
#./testpio_bench.pl --iofmt pnc --pecount 128 --bench POPC --numIO 8
#./testpio_bench.pl --maxiter 2 --iofmt pnc --pecount 64 --bench POPD --numIO 12

set id = `date "+%m%d%y-%H%M"`
#POPB
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 512 --bench POPC  --numIO 80 --log kraken.0512.pnc.iotask_80.log.${id}
./testpio_bench.pl --maxiter 2  --iofmt pnc --pecount 512 --bench POPD  --numIO 80 --log kraken.0512.pnc.iotask_80.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 416 --bench CAM05 --numIO 70 --log kraken.0416.pnc.iotask_70.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 500 --bench WRFB  --numIO 80 --log kraken.0500.pnc.iotask_80.log.${id}
