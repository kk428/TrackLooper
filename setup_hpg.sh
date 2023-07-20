#!/bin/bash

# HiPerGator module setup for cuda
module load cuda/11.4.3 git
# module use ~/module
# module load root/6.22.08

###########################################################################################################
# Setup environments
###########################################################################################################
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/code/rooutil/thisrooutil.sh

export SCRAM_ARCH=el8_amd64_gcc10
export CMSSW_VERSION=CMSSW_13_0_0_pre2
export CUDA_HOME=${HPC_CUDA_DIR}

source /cvmfs/cms.cern.ch/cmsset_default.sh
cd /cvmfs/cms.cern.ch/$SCRAM_ARCH/cms/cmssw/$CMSSW_VERSION/src
eval `scramv1 runtime -sh`
cd - > /dev/null
echo "Setup following ROOT. Make sure the appropriate setup file has been run. Otherwise the looper won't compile."
which root

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export LD_LIBRARY_PATH=$DIR:$LD_LIBRARY_PATH
export PATH=$DIR/bin:$PATH
export PATH=$DIR/efficiency/bin:$PATH
export PATH=$DIR/efficiency/python:$PATH
export TRACKLOOPERDIR=$DIR
export TRACKINGNTUPLEDIR=/blue/p.chang/p.chang/data/lst/CMSSW_12_2_0_pre2
export PIXELMAPDIR=/blue/p.chang/p.chang/data/lst/pixelmap_neta20_nphi72_nz24_ipt2
export LSTOUTPUTDIR=.
export LSTPERFORMANCEWEBDIR=/home/users/phchang/public_html/LSTPerformanceWeb

###########################################################################################################
# Validation scripts
###########################################################################################################

# List of benchmark efficiencies are set as an environment variable
export LATEST_CPU_BENCHMARK_EFF_MUONGUN=
export LATEST_CPU_BENCHMARK_EFF_PU200=

source /cvmfs/cms.cern.ch/el8_amd64_gcc10/external/alpaka/develop-20220902-e80d13b043e1608b43d2007d06ad7e2f/etc/profile.d/init.sh
export BOOST_ROOT="/cvmfs/cms.cern.ch/el8_amd64_gcc10/external/boost/1.78.0-12075919175e8d078539685f9234134a"
export ALPAKA_ROOT="/cvmfs/cms.cern.ch/el8_amd64_gcc10/external/alpaka/develop-20220902-e80d13b043e1608b43d2007d06ad7e2f"
#eof
