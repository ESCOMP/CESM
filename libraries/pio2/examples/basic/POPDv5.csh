#!/usr/bin/csh
set id = `date "+%m%d%y-%H%M"`
set host = 'kraken'
#set host = 'hopper'

./testpio_bench.pl --maxiter 10 --rearr none --iofmt bin --pecount 64   --bench POPD --numIO 64   --log ${host}.0064.bin.none.iotask_64.log.${id}
./testpio_bench.pl --maxiter 10 --rearr none --iofmt bin --pecount 128  --bench POPD --numIO 128  --log ${host}.0128.bin.none.iotask_128.log.${id}
./testpio_bench.pl --maxiter 10 --rearr none --iofmt bin --pecount 256  --bench POPD --numIO 256  --log ${host}.0256.bin.none.iotask_256.log.${id}
./testpio_bench.pl --maxiter 10 --rearr none --iofmt bin --pecount 512  --bench POPD --numIO 512  --log ${host}.0512.bin.none.iotask_512.log.${id}
./testpio_bench.pl --maxiter 10 --rearr none --iofmt bin --pecount 1000 --bench POPD --numIO 1000 --log ${host}.1000.bin.none.iotask_1000.log.${id}
./testpio_bench.pl --maxiter 10 --rearr none --iofmt bin --pecount 1600 --bench POPD --numIO 1600 --log ${host}.1600.bin.none.iotask_1600.log.${id}
./testpio_bench.pl --maxiter 10 --rearr none --iofmt bin --pecount 2000 --bench POPD --numIO 2000 --log ${host}.2000.bin.none.iotask_2000.log.${id}
# waiting for another 4000 core job in queue
#./testpio_bench.pl --maxiter 10 --rearr none --iofmt bin --pecount 4000 --bench POPD --numIO 4000 --log ${host}.4000.bin.none.iotask_4000.log.${id}

#./testpio_bench.pl --maxiter 2 --iofmt pnc --pecount 8000 --bench POPD --numIO 640 --log ${host}.8000.pnc.iotask_640.log.${id}

