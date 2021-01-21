#!/usr/bin/csh
# ./testpio_bench.pl --iofmt pnc --pecount 128 --bench POPC --numIO 8
# ./testpio_bench.pl --maxiter 2 --iofmt pnc --pecount 64 --bench POPD --numIO 12
set id = `date "+%m%d%y-%H%M"`
# ./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 64 --bench POPC --numIO 6
# ./testpio_bench.pl --maxiter 1 --iofmt pnc --pecount 128 --bench POPD --numIO -8 --log frost.128.pnc.iotask_8.log.${id}
# ./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 64 --bench CAM05 --numIO 6
# ./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 256 --bench WRFB  --numIO 40

./testpio_bench.pl --bench CAM05 --iofmt pnc --pecount 256 --numIO -7
