#!/usr/bin/csh
set id = `date "+%m%d%y-%H%M"`
set host = 'bluefire'
# asfa
#set host = 'hopper'
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 64  --bench CAM05 --numIO 6  --log ${host}.0064.pnc.iotask_6.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 128 --bench CAM05 --numIO 10  --log ${host}.0128.pnc.iotask_10.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 256 --bench CAM05 --numIO 20  --log ${host}.0256.pnc.iotask_20.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 416 --bench CAM05 --numIO 36  --log ${host}.0416.pnc.iotask_36.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 832 --bench CAM05 --numIO 70 --log ${host}.0832.pnc.iotask_70.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 1664 --bench CAM05 --numIO 140 --log ${host}.1664.pnc.iotask_140.log.${id}
