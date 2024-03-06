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
#             Nov. 25, 2016 - (Ning Han)Creatioin
#             Aug. 29, 2017 - (Ammy Yi)Add msc test
#             Mar. 09, 2019 - (Zhang Chao)Add typec switch function


# @desc This script verify usb storage device read/write function
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

usage() {
  cat << EOF
  usage: ${0##*/}
    -p  protocol type, such as 2.0 3.0 3.1 3.2"
    -t  device type, such as flash uas"
    -b  block size, as parameter pass to dd command"
    -c  block count, as parameter pass to dd command"
    -e  hotplug/no hotplug
    -s  stress counts, hotplug recycle times
    -d  portid of hilboard/switch connected
    -f  hotplug type: hilboard/switch
    -g  test type: common/big data
    -h  usb hub number
    -H  show this"
EOF
}

main() {
  local usb_device_node=""
  local test_file=""
  local count=1
  check_test_env
  if [[ -z "$PROTOCOL_TYPE" || -z "$DEVICE_TYPE" ]]; then
    block_test "protocol type or device type info not provided!"
  fi
  if [[ "$HOTPLUG_FLAG" = "hotplug" ]]; then
    if [[ "$HOTP_TYPE" = "switch" ]]; then
      usb_hotplug_setup_switch "$PORT_ID"
      [[ $? -eq 0 ]] || block_test "fail to setup for usb hotplug!"
      usb_hotplug_switch "$PORT_ID"
    else
      usb_hotplug_setup "$PORT_ID"
      [[ $? -eq 0 ]] || block_test "fail to setup for usb hotplug!"
      usb_hotplug "$PORT_ID"
    fi
  fi

  for((i=0;i<"$STRESS_COUNT";i++)); do
    if [[ "$HOTPLUG_FLAG" = "hotplug" ]]; then
      if [[ "$HOTP_TYPE" = "switch" ]]; then
        usb_hotplug_switch "$PORT_ID"
      else
        usb_hotplug "$PORT_ID"
      fi
    fi
    # Get usb storage device node, such as: /dev/sdb
    usb_device_node=$(find_usb_storage_device "$PROTOCOL_TYPE" \
                                              "$DEVICE_TYPE" \
                                              "$BLOCK_SIZE" \
                                              "$BLOCK_COUNT" \
                                              "$USBHUB_NUM")
    [[ -n "$usb_device_node" ]] || block_test "fail to find usb storage device!"
    test_print_trc "usb storage device found: $usb_device_node"
    [ "$BIG_DATA" == "bigdata" ] && BLOCK_SIZE=$(cal_local_device_swap_space "$usb_device_node")
    if [[ -n "$TEMP_DIR" ]] && [[ -z "$BIG_DATA" ]]; then
      # Generate a file of a specific size which will be the source
      # file to perform w/r test
      test_file=$(generate_test_file "$BLOCK_SIZE" "$BLOCK_COUNT" "$TEMP_DIR")
      [[ -n "$test_file" ]] || block_test "fail to generate random file!"
      test_print_trc "temporary file: $test_file"
      write_test_with_file "$usb_device_node" "$test_file"
      read_test_with_file "$usb_device_node" "$test_file"
    else
      write_test_without_file "$usb_device_node" "$BLOCK_SIZE" "$BLOCK_COUNT"
      read_test_without_file "$usb_device_node" "$BLOCK_SIZE" "$BLOCK_COUNT"
    fi
    if [[ "$HOTPLUG_FLAG" != "hotplug" ]]; then
      rw_test_with_msc "$usb_device_node" "$count" || die "msc r/w fail"
    fi
    test_print_trc "finish $((i+1)) times"
  done
}

teardown() {
  rm -rf "$TEMP_DIR"
  [[ "$HOTPLUG_FLAG" = "hotplug" ]] && [[ "$HOTP_TYPE" != "switch" ]] && usb_hotplug_teardown
}

# Default size 1MB
: ${BLOCK_SIZE:="1MB"}
: ${BLOCK_COUNT:="1"}
: ${THRESHOLD:="10MB"}
: ${HOTPLUG_FLAG:=""}
: ${PORT_ID:=""}
: ${USBHUB_NUM:="0"}
: ${STRESS_COUNT:="1"}

while getopts :p:t:h:b:c:e:s:d:f:g:H arg; do
  case $arg in
    p)
      PROTOCOL_TYPE=$OPTARG
      ;;
    t)
      DEVICE_TYPE=$OPTARG
      ;;
    b)
      BLOCK_SIZE=$OPTARG
      ;;
    c)
      BLOCK_COUNT=$OPTARG
      ;;
    e)
      HOTPLUG_FLAG=$OPTARG
      ;;
    s)
      STRESS_COUNT=$OPTARG
      ;;
    d)
      PORT_ID=$OPTARG
      ;;
    f)
      HOTP_TYPE=$OPTARG
      ;;
    g)
      BIG_DATA=$OPTARG
      ;;
    h)
      USBHUB_NUM=$OPTARG
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

# If test file size is big than the threshold, directly write to/from
# usb device from /dev/zero and /dev/null
size_too_big "$THRESHOLD" "$BLOCK_SIZE" "$BLOCK_COUNT"
if [[ $? -ne 0 ]]; then
  TEMP_DIR=$(mktemp -d)
  [[ -e "$TEMP_DIR" ]] || die "fail to create temporary directory!"
  test_print_trc "temporary test directory:$TEMP_DIR"
fi

teardown_handler="teardown"
usb_setup
main
usb_trace_check || die "usb log check fail, please check detailed trace and dmesg logs!"
usb_log_teardown
exec_teardown
exit 0
