#!/bin/bash
#
# Copyright 2018 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate rtc component
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
#             Wang Zhijiang <zhijiangx.wang@intel.com>
#
# History:
#             Sep. 27, 2018 - (Wang Zhijiang)Creation

source common.sh

usage() {
  cat << _EOF
    rtc_tests_android.sh -c <case id> -h
      c: case id
      h: show this
_EOF
}

while getopts c:l:h opt; do
  case $opt in
    h) usage && exit ;;
    c) cid=$OPTARG ;;
    l) loops=$OPTARG ;;
    \?) die "Invalide option: -$OPTARG" ;;
    :) die "Option -$OPTARG requires an argument." ;;
  esac
done

case $cid in
  set_alarm_30)
    DEV_NODE=$(get_devnode.sh "rtc") || block_test "error getting devnode for rtc"
    do_cmd "rtc_tests -device $DEV_NODE -ioctltest alarm -ioctltestarg 30"
    ;;
  ioctl_ronly_rd_1)
    DEV_NODE=$(get_devnode.sh "rtc") || block_test "error getting devnode for rtc"
    do_cmd "rtc_tests -device $DEV_NODE -loop 1 -ioctltest readtime -readonly"
    ;;
  ioctl_ronly_rd_10)
    DEV_NODE=$(get_devnode.sh "rtc") || block_test "error getting devnode for rtc"
    do_cmd "rtc_tests -device $DEV_NODE -loop 10 -ioctltest readtime -readonly"
    ;;
  readtime_1)
    DEV_NODE=$(get_devnode.sh "rtc") || block_test "error getting devnode for rtc"
    do_cmd "rtc_tests -device $DEV_NODE -ioctltest readtime"
    ;;
  setgettime)
    DEV_NODE=$(get_devnode.sh "rtc") || block_test "error getting devnode for rtc"
    do_cmd "rtc_tests -device $DEV_NODE -ioctltest setgettime"
    ;;
  neg_setgettime)
    DEV_NODE=$(get_devnode.sh "rtc") || block_test "error getting devnode for rtc"
    do_cmd "rtc_tests -device $DEV_NODE -ioctltest setgettime -readonly"
    ;;
  neg_setgettime)
    DEV_NODE=$(get_devnode.sh "rtc") || block_test "error getting devnode for rtc"
    do_cmd "rtc_tests -device $DEV_NODE -ioctltest setgettime -readonly"
    ;;
  setgettime_30_day)
    DEV_NODE=$(get_devnode.sh "rtc") || block_test "error getting devnode for rtc"
    do_cmd "rtc_tests -device $DEV_NODE  -ioctltest setgettime -ioctltestarg 1"
    ;;
  setgettime_leap)
    DEV_NODE=$(get_devnode.sh "rtc") || block_test "error getting devnode for rtc"
    do_cmd "rtc_tests -device $DEV_NODE  -ioctltest setgettime -ioctltestarg 2"
    ;;
  setgettime_nonleap)
    DEV_NODE=$(get_devnode.sh "rtc") || block_test "error getting devnode for rtc"
    do_cmd "rtc_tests -device $DEV_NODE  -ioctltest setgettime -ioctltestarg 3"
    ;;
  update_int_on_off)
    DEV_NODE=$(get_devnode.sh "rtc") || block_test "error getting devnode for rtc"
    do_cmd "rtc_tests -device $DEV_NODE  -ioctltest updateint"
    ;;
  *)
    die "Invalid case id: $cid!"
    ;;
esac
