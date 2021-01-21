#!/usr/bin/csh
set id = `date "+%m%d%y-%H%M"`
set host = 'kraken'
#set host = 'hopper'

#------------------------------
# should increase queue runtime
#------------------------------
./testpio_bench.pl --maxiter 10 --iofmt snc --pecount 64   --bench POPD --numIO 1  --log ${host}.0064.snc.box.iotask_1.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt snc --pecount 128  --bench POPD --numIO 1  --log ${host}.0128.snc.box.iotask_1.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt snc --pecount 256  --bench POPD --numIO 1  --log ${host}.0256.snc.box.iotask_1.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt snc --pecount 512  --bench POPD --numIO 1  --log ${host}.0512.snc.box.iotask_1.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt snc --pecount 1000 --bench POPD --numIO 1 --log ${host}.1000.snc.box.iotask_1.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt snc --pecount 1600 --bench POPD --numIO 1 --log ${host}.1600.snc.box.iotask_1.log.${id}
./testpio_bench.pl --maxiter 10 --iofmt snc --pecount 2000 --bench POPD --numIO 1 --log ${host}.2000.snc.box.iotask_1.log.${id}
#  Don't execute this one yet because 4000 core job from previous set is still in queue
./testpio_bench.pl --maxiter 10 --iofmt snc --pecount 4000 --bench POPD --numIO 1 --log ${host}.4000.snc.box.iotask_1.log.${id}

#./testpio_bench.pl --maxiter 2 --iofmt pnc --pecount 8000 --bench POPD --numIO 640 --log ${host}.8000.pnc.iotask_640.log.${id}

