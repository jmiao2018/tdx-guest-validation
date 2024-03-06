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
#             Ammy Yi <ammy.yi@intel.com>
#
# History:
#             Jun. 07, 2018 - (Ammy Yi)Creatioin


# @desc This script verify usb storage device read/write function
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

usage() {
  cat << EOF
  usage: ${0##*/}
    -p  protocol type, such as 2.0 3.0 3.1 3.2"
    -t  device type, such as flash uas"
    -H  show this"
EOF
}

   # Default size 1M
: ${BLOCK_SIZE:="1MB"}
: ${BLOCK_COUNT:="1"}
: ${USBHUB_NUM:="0"}

main() {
  local usb_device_node=""
  check_test_env
  if [[ -z "$PROTOCOL_TYPE" || -z "$DEVICE_TYPE" ]]; then
    block_test "protocol type or device type info not provided!"
  fi

  # Get usb storage device node, such as: /dev/sdb
  usb_device_node=$(find_usb_storage_device "$PROTOCOL_TYPE" \
                                              "$DEVICE_TYPE" \
                                              "$BLOCK_SIZE" \
                                              "$BLOCK_COUNT" \
                                              "$USBHUB_NUM")
  [[ -n "$usb_device_node" ]] || block_test "fail to find usb storage device!"
  test_print_trc "usb storage device found: $usb_device_node"
  do_cmd "udisksctl power-off --block-device $usb_device_node"
  do_cmd "lsblk | grep -v $usb_device_node"
}


while getopts :p:t:H arg; do
  case $arg in
    p)
      PROTOCOL_TYPE=$OPTARG
      ;;
    t)
      DEVICE_TYPE=$OPTARG
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
usb_setup
main
usb_trace_check || die "usb log check fail, please check detailed trace and dmesg logs!"
usb_log_teardown
exec_teardown
exit 0
