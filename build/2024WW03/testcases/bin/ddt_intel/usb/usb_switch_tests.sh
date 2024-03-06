#!/bin/bash
#
# Copyright 2017 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate USB component with switch
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Chao Zhang <chaox.zhang@intel.com>
#
# History:
#             Dec. 21, 2017 - (Chao Zhang)Creation


# @desc This script verify usb switch test with storages or peripherals
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

STOR0="2.0/-t/flash"
STOR1="3.0/-t/flash"
STOR2="3.0/-t/uas"
STOR3="3.1/-t/uas"
printer="printer/-p/\"03f0:df11\"/-n/\"DeskJet-1110-series\""
scanner="scanner/-p/\"04a9:190e\"/-n/\"Canon/LiDE/120\""
headset="headset/-p/\"046d:0a38\"/-n/\"Headset\""
camera="camera"
stress_num=0
sleep_t=2
PORT_DEVICE=()

usage() {
  cat << EOF
  usage: ${0##*/}
    -p  port1-storage|peripheral"
    -q  port2-storage|peripheral"
    -r  port3-storage|peripheral"
    -s  port4-storage|peripheral"
    -t  switch times"
    -h  show this"
    -H  show this"
EOF
}

usb_read_write(){
  sleep $sleep_t
  usb_read_write_tests.sh -b 1MB -c 100 -p $*
}

usb_peripheral(){
  sleep $sleep_t
  usb_peripheral_tests.sh -m $*
}

parse_port(){
  local var[0]="2.0-flash"
  local var[1]="3.0-flash"
  local var[2]="3.0-uas"
  local var[3]="3.1-uas"
  local var[4]="printer"
  local var[5]="scanner"
  local var[6]="headset"
  local var[7]="camera"
  local num=0
  local port_num=0

  for k in ${PORT[@]}; do
    for v in ${var[@]}; do
      if [ $k == $v ]; then
        num=$((num+1))
        DEVICE[$num]=$k
      fi
    done
  done
  for i in ${DEVICE[@]}; do
    [ $i == ${var[0]} ] && port_num=$((port_num+1)) && PORT_DEVICE[$port_num]=${STOR0}
    [ $i == ${var[1]} ] && port_num=$((port_num+1)) && PORT_DEVICE[$port_num]=${STOR1}
    [ $i == ${var[2]} ] && port_num=$((port_num+1)) && PORT_DEVICE[$port_num]=${STOR2}
    [ $i == ${var[3]} ] && port_num=$((port_num+1)) && PORT_DEVICE[$port_num]=${STOR3}
    [ $i == ${var[4]} ] && port_num=$((port_num+1)) && PORT_DEVICE[$port_num]=${printer}
    [ $i == ${var[5]} ] && port_num=$((port_num+1)) && PORT_DEVICE[$port_num]=${scanner}
    [ $i == ${var[6]} ] && port_num=$((port_num+1)) && PORT_DEVICE[$port_num]=${headset}
    [ $i == ${var[7]} ] && port_num=$((port_num+1)) && PORT_DEVICE[$port_num]=${camera}
  done
}

stress_test(){
  parse_port
  while [ $SW_NUM -gt 0 ]; do
    port=1
    for i in ${PORT_DEVICE[@]}; do
      python2 $PWD/ftdi/FtdiWrapper/cswitch.py $port
      sleep 8
      echo $i |egrep "flash|uas" > /dev/null
      if [ $? -eq 0 ]; then
        device=$(echo $i| sed 's/\// /g')
        usb_read_write $device || die "fail to test usb_read_write $i"
      else
        device=$(echo $i| sed 's/\// /g')
        usb_peripheral $device || die "fail to test usb_peripheral $i"
      fi
      port=$((port+1))
    done
    SW_NUM=$((SW_NUM-1))
    stress_num=$((stress_num+1))
    test_print_trc "finish $stress_num round stress."
  done
}

main(){
  check_test_env
  rmmod ftdi_sio
  rmmod usbserial
  stress_test
}

while getopts :p:q:r:s:t:h:H: arg; do
  case $arg in
    p)
      PORT[0]=$OPTARG
      ;;
    q)
      PORT[1]=$OPTARG
      ;;
    r)
      PORT[2]=$OPTARG
      ;;
    s)
      PORT[3]=$OPTARG
      ;;
    t)
      SW_NUM=$OPTARG
      ;;
    H|h)
      usage && exit 1
      ;;
    \?)
      usage
      die "Invalid Option -$OPTARG"
      ;;
    :)
      usage
      die "Option -$OPTARG requires an argument."
      ;;
  esac
done

usb_setup
main
usb_trace_check || die "usb log check fail, please check detailed trace and dmesg logs!"
usb_log_teardown
exec_teardown
exit 0
