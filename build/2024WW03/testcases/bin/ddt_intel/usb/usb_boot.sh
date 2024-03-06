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
#             Zhang Chao <chaox.zhang@intel.com>
#
# History:
#             Apr. 20, 2018 - (Zhang Chao)Creation

# @desc This script test usb storage device suspend to resume
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

usage() {
  cat << EOF
  usage: ${0##*/}
    -s  stress counts
    -b  block size, as parameter pass to dd command
    -c  block count, as parameter pass to dd command
    -h  show this
    -H  show this
EOF
}

main() {
  local dmesg_count="/dmesg_count"
  local count_file="/count_file"
  local run_dir="/run_dir"
  local runtest_para="/runtest_para"
  local bootfile="/bootfile"

  check_test_env
  test_print_trc "*** This test needs to reboot for many times ***"
  echo "$RUNTEST_PARA" > "$runtest_para"
  sleep 3
  path=${PWD%/testcases*}
  echo "$path" > "$run_dir"
  state=$(systemctl status usbboot.service |grep -i loaded |awk -F ";" '{print $2}'|sed 's/ //g')
  if [ "$state" != "enabled" ]; then
    cp $PWD/ddt_intel/usb/usbboot.service /etc/systemd/system/
    cp $PWD/ddt_intel/usb/usbboot.local /etc/
    do_cmd "systemctl enable usbboot.service"
  fi
  [ -e "$count_file" ] && NUM_COUNT=$(cat "$count_file" | tail -n1)
  while [ "$NUM_COUNT" -le "$STRESS_COUNT" ]; do
    echo $((NUM_COUNT+1)) >> "$count_file"
    base_count=$(cat "$dmesg_count"|sed 's/ //g')
    [ $? == 0 ] || die "please make a file dmesg_count on / for initial dmesg fail|error count"
    err_count=$(dmesg| grep -iE "error|fail" |wc -l)
    [ "$err_count" == "$base_count" ] || die "find new error or failure"

    test_file=$(generate_test_file "$BLOCK_SIZE" "$BLOCK_COUNT" "$TEMP_DIR")
    [[ -n "$test_file" ]] || block_test "fail to generate random file!"
    test_print_trc "temporary file: $test_file"

    [ ! -e "$bootfile" ] && do_cmd "touch $bootfile"
    write_test_with_file "$bootfile" "$test_file" "$BLOCK_COUNT"
    [[ $? -eq 0 ]] || die "write test failed!"
    read_test_with_file "$bootfile" "$test_file" "$BLOCK_COUNT"
    [[ $? -eq 0 ]] || die "read test failed!"
    test_print_trc "finish $NUM_COUNT times , total is $STRESS_COUNT"
    sleep 10
    reboot
    sleep 100
  done
  test_print_trc "finish $((NUM_COUNT-1)) times."
  do_cmd "systemctl disable usbboot.service"
  rm /etc/usbboot.local
  rm /etc/systemd/system/usbboot.service
  rm $count_file
  rm $run_dir
  rm $runtest_para
  rm $bootfile
  rm $dmesg_count
}

: ${BLOCK_SIZE:="1MB"}
: ${BLOCK_COUNT:="1"}
: ${STRESS_COUNT:="10"}
: ${NUM_COUNT:="1"}

while getopts :b:c:s:hH arg
do
  case $arg in
    s) STRESS_COUNT=$OPTARG ;;
    b) BLOCK_SIZE=$OPTARG ;;
    c) BLOCK_COUNT=$OPTARG ;;
    h) usage && exit 1 ;;
    H) usage && exit 1 ;;
    \?) usage && die "Invalid Option -$OPTARG" ;;
    :) usage && die "Option -$OPTARG requires an argument." ;;
  esac
done

main
exit 0
