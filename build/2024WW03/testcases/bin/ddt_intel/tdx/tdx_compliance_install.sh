#!/bin/bash

source "common.sh"
source "functions.sh"

DIR_DDT_INTEL=$LTPROOT/testcases/bin/ddt_intel/
DIR_LKVS=$DIR_DDT_INTEL/lkvs

cd $DIR_DDT_INTEL
tar xvf lkvs.tar
cd lkvs
make docker_image
make docker-build tdx-compliance
#cp tdx-compliance/tdx-compliance.ko $DIR_DDT_INTEL/
