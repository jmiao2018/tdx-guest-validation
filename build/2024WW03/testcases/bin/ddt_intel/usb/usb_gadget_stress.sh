#!/bin/bash
#
# Copyright 2018 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate USB component
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
#             Ammy Yi<ammy.yi@intel.com>
#
# History:
#             Feb. 8, 2018 - (Ammy Yi)Creatioin


# @desc This script verify usb gadget/host stess test with test.sh tool
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

usage() {
  cat << EOF
  usage: ${0##*/}
    -t  stress times"
    -H  show this"
EOF
}

 # This function perform write test on usb device w/ test.sh tool
# Input:
#       t: times for test.sh loop
# Return: check tes.sh result, fail = 1
rw_test_with_test_sh() {
  local count=$1
  local val_re=0
  do_cmd "modprobe g_zero"
  sleep 3
  lsusb -t | grep "usbtest"
  if [ $? -ne 0 ]; then
    die "usb zero device fail to enumrate!"
  fi
  sh usbtest.sh -n $count > usbtest_temp.txt
  grep usbtest_temp.txt -e "FAIL"
  if [ $? -eq 0 ]; then
    val_re=1
    cat usbtest_temp.txt
  fi
  rm usbtest_temp.txt
  return $val_re
}

main() {
  rw_test_with_test_sh "$STRESS_TIMES" || die "test.sh failed"
}


# Default stress times is 1000
: ${STRESS_TIMES:="1000"}

while getopts :t:H arg; do
  case $arg in
    t)
      STRESS_TIMES=$OPTARG
      ;;
    H)
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
exit 0
