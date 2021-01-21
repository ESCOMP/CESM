#!/usr/bin/csh
set id = `date "+%m%d%y-%H%M"`
#set host = 'kraken'
set host = 'hopper'

./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 64   --bench POPD --numIO 10 --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 128  --bench POPD --numIO 20 --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 256  --bench POPD --numIO 40 --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 512  --bench POPD --numIO 80  --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 1000 --bench POPD --numIO 160 --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 1600 --bench POPD --numIO 320 --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 2000 --bench POPD --numIO 320  --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 4000 --bench POPD --numIO 320  --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 8000  --bench POPD --numIO 320 --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 12000 --bench POPD --numIO 320 --logfile-suffix trunk_close
./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 15000 --bench POPD --numIO 320 --logfile-suffix trunk_close

#./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 64   --bench POPD --numIO 10 --mpi-cb-buffer-size=8388608  --logfile-suffix DnR1
#./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 128  --bench POPD --numIO 20 --mpi-cb-buffer-size=8388608  --logfile-suffix DnR1
#./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 256  --bench POPD --numIO 40 --mpi-cb-buffer-size=8388608  --logfile-suffix DnR1
#./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 512  --bench POPD --numIO 80 --mpi-cb-buffer-size=8388608  --logfile-suffix DnR1

#./testpio_bench.pl --maxiter 10 --iofmt pnc -lfs-ost-count 4 --pecount 1000 --bench POPD --numIO 160 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR3
#./testpio_bench.pl --maxiter 10 --iofmt pnc -lfs-ost-count 8 --pecount 1000 --bench POPD --numIO 160 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR3
#./testpio_bench.pl --maxiter 10 --iofmt pnc -lfs-ost-count 10 --pecount 1000 --bench POPD --numIO 160 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR3
#./testpio_bench.pl --maxiter 10 --iofmt pnc -lfs-ost-count 16 --pecount 1000 --bench POPD --numIO 160 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR3
#./testpio_bench.pl --maxiter 10 --iofmt pnc -lfs-ost-count 20 --pecount 1000 --bench POPD --numIO 160 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR3
#./testpio_bench.pl --maxiter 10 --iofmt pnc -lfs-ost-count 24 --pecount 1000 --bench POPD --numIO 160 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR3
#./testpio_bench.pl --maxiter 10 --iofmt pnc -lfs-ost-count 32 --pecount 1000 --bench POPD --numIO 160 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR3
#./testpio_bench.pl --maxiter 10 --iofmt pnc -lfs-ost-count 40 --pecount 1000 --bench POPD --numIO 160 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR3
#./testpio_bench.pl --maxiter 10 --iofmt pnc -lfs-ost-count 64 --pecount 1000 --bench POPD --numIO 160 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR3
#./testpio_bench.pl --maxiter 10 --iofmt pnc -lfs-ost-count 80 --pecount 1000 --bench POPD --numIO 160 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR3
#./testpio_bench.pl --maxiter 10 --iofmt pnc -lfs-ost-count 160 --pecount 1000 --bench POPD --numIO 160 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR3

#./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 1600 --bench POPD --numIO 320 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR1
#./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 2000 --bench POPD --numIO 640 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR1
#./testpio_bench.pl --maxiter 10 --iofmt pnc --pecount 4000 --bench POPD --numIO 640 --mpi-cb-buffer-size=8388608 --logfile-suffix DnR1


