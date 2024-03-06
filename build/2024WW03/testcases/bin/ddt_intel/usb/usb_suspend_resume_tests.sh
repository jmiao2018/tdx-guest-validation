#!/bin/bash
#
# Copyright 2016 Intel Corporation
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
#             Ning Han <ningx.han@intel.com>
#
# History:
#             Nov. 25, 2016 - (Ning Han)Creation
#             Sep. 18, 2017 - (Ammy Yi)Add hotplug semi auto part
#             Apr. 12, 2018 - (Zhang Chao)Add S3 stress tests

# @desc This script test usb storage device suspend to resume
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

usage() {
  cat << EOF
  usage: ${0##*/}
    -p  protocol type, such as 2.0 3.0 ...
    -t  device type, such as flash uas ...
    -b  block size, as parameter pass to dd command
    -c  block count, as parameter pass to dd command
    -s  suspend state to test
    -m  stress counts
    -H  show this
EOF
}

main() {
  local usb_device_node=""
  local usb_device_node_temp=""
  local test_file=""

  if [[ $HOTPLUG_FLAG = "hotplug" ]]; then
    test_print_trc "******************************************************************"
    test_print_trc "**This test is semi-auto test case. Please follow step: **********"
    test_print_trc "**1. connect hil board with another server to control ************"
    test_print_trc "**2. connect device with DUT w/ hil board ************************"
    test_print_trc "**3. run hotplug.sh after system is suspended on another server **"
    test_print_trc "******************************************************************"
  fi

  check_test_env

  if [[ -z "$PROTOCOL_TYPE" || -z "$DEVICE_TYPE" ]]; then
    block_test "protocol type or device type info not provided!"
  fi

  for((i=0;i<"$STRESS_COUNT";i++)); do
    usb_device_node=$(find_usb_storage_device "$PROTOCOL_TYPE" \
                                              "$DEVICE_TYPE" \
                                              "$BLOCK_SIZE" \
                                              "$BLOCK_COUNT" \
                                              "$USBHUB_NUM")
    [[ -n "$usb_device_node" ]] || block_test "fail to find usb storage device!"
    test_print_trc "usd storage device found: $usb_device_node"

    test_file=$(generate_test_file "$BLOCK_SIZE" "$BLOCK_COUNT" "$TEMP_DIR")
    [[ -n "$test_file" ]] || block_test "fail to generate random file!"
    test_print_trc "temporary file: $test_file"

    if [[ $HOTPLUG_FLAG = "hotplug" ]]; then
      test_print_trc "**********************************************************************"
      test_print_trc "**Please run hotplug.sh after system is suspended on another server **"
      test_print_trc "**********************************************************************"
    fi

    write_test_with_file "$usb_device_node" "$test_file" &
    suspend_to_resume "$SUSPEND_STATE"
    wait $!
    sleep 5
    [[ $? -eq 0 ]] || die "write test failed!"
    read_test_with_file "$usb_device_node" "$test_file"

    # Check whether usb storage device node changes after suspend-to-resume
    usb_device_node_temp=$(find_usb_storage_device "$PROTOCOL_TYPE" \
                                                   "$DEVICE_TYPE" \
                                                   "1" \
                                                   "1" \
                                                   "$USBHUB_NUM")
    [[ "$usb_device_node" == "$usb_device_node_temp" ]] || \
      die "usb storage device node changed!"
    test_print_trc "finish $((i+1)) times"
  done
}

teardown() {
  rm -rf "$TEMP_DIR"
  [[ $HOTPLUG_FLAG = "hotplug" ]] && usb_hotplug_teardown
}

: ${BLOCK_SIZE:="1MB"}
: ${BLOCK_COUNT:="1"}
: ${HOTPLUG_FLAG:=""}
: ${USBHUB_NUM:="0"}
: ${STRESS_COUNT:="1"}

while getopts :p:t:b:c:s:m:e:d:h:H arg
do
  case $arg in
    p) PROTOCOL_TYPE=$OPTARG ;;
    t) DEVICE_TYPE=$OPTARG ;;
    b) BLOCK_SIZE=$OPTARG ;;
    c) BLOCK_COUNT=$OPTARG ;;
    m) STRESS_COUNT=$OPTARG;;
    s) SUSPEND_STATE=$OPTARG ;;
    e) HOTPLUG_FLAG=$OPTARG ;;
    h) USBHUB_NUM=$OPTARG ;;
    H) usage && exit 1 ;;
    \?) usage && die "Invalid Option -$OPTARG" ;;
    :) usage && die "Option -$OPTARG requires an argument." ;;
  esac
done

TEMP_DIR=$(mktemp -d)
[[ -e "$TEMP_DIR" ]] || die "fail to create temporary directory for test!"

teardown_handler="teardown"
usb_setup
main
usb_trace_check || die "usb log check fail, please check detailed trace and dmesg logs!"
usb_log_teardown
exec_teardown
exit 0
