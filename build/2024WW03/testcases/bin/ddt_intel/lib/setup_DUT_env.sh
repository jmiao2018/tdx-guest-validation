#!/bin/bash

DEVID=$1
BINDIR=$2
if [ $# -ne 2 ];then
	echo "$0 <ADB S/N> <bin dir>"
	exit 1
fi

adb -s ${DEVID} root
sleep 2
adb -s ${DEVID} shell mkdir /data/bin &> /dev/null
adb -s ${DEVID} push ${BINDIR} /data/bin
adb -s ${DEVID} shell /data/bin/env_setup.sh
