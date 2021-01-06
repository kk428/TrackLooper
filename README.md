# TrackLooper

## Quick start guide

Log on to phi3

    git clone git@github.com:SegmentLinking/TrackLooper.git
    cd TrackLooper/
    git checkout -b sgnoohc-add_cpu master
    git pull https://github.com/sgnoohc/TrackLooper.git add_cpu
    source setup.sh
    sh make_script.sh -m
    ./bin/sdl -i muonGun -o muonGun_200evt_gpu.root -n 200
    ./bin/sdl -i muonGun -o muonGun_200evt_cpu.root -n 200 --cpu
    cd efficiency/
    make -j
    sh run.sh -i ../muonGun_200evt_gpu.root -p 4 -g 13
    sh run.sh -i ../muonGun_200evt_cpu.root -p 4 -g 13

