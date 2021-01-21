#!/usr/bin/csh
#./testpio_bench.pl --iofmt pnc --pecount 128 --bench POPC --numIO 8
#./testpio_bench.pl --maxiter 2 --iofmt pnc --pecount 64 --bench POPD --numIO 12
set id = `date "+%m%d%y-%H%M"`
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 1000 --bench POPC  --numIO 160 --log kraken.1000.pnc.iotask_160.log.${id}
./testpio_bench.pl --maxiter 5  --iofmt pnc --pecount 1000 --bench POPD  --numIO 160 --log kraken.1000.pnc.iotask_160.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 832  --bench CAM05 --numIO 140 --log kraken.0832.pnc.iotask_140.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 1000 --bench WRFB  --numIO 160 --log kraken.1000.pnc.iotask_160.log.${id}
