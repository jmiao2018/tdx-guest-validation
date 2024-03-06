#!/bin/bash
#
# Copyright 2017 Intel Corporation
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
#             Nov. 25, 2017 - (Ammy Yi)Creation


# @desc This script verify usb trace test
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-t $TEST_SCENARIO][-H]
  -t  test scenario
  -H  show This
__EOF
}

: ${TEST_SCENARIO:=""}
: ${TRACE_PATH:="/sys/kernel/debug/tracing/"}

trace_teardown() {
  case $TEST_SCENARIO in
    host)
      do_cmd "echo 0 > $TRACE_PATH/events/xhci-hcd/enable"
      ;;
    gadget)
      do_cmd "echo 0 > $TRACE_PATH/events/dwc3/enable"
      modprobe g_zero
      ;;
    ucsi)
      do_cmd "echo 0 > $TRACE_PATH/events/ucsi/enable"
      ;;
  esac
  do_cmd "echo > $TRACE_PATH/trace"
}

host_trace_check() {
  do_cmd "echo > $TRACE_PATH/trace"
  do_cmd "echo 1 > $TRACE_PATH/events/xhci-hcd/enable"
  do_cmd "rtcwake -m freeze -s 5"
  do_cmd "grep xhci $TRACE_PATH/trace -q"
  return 0
}

dwc3_trace_check() {
  do_cmd "echo > $TRACE_PATH/trace"
  do_cmd "echo 1 > $TRACE_PATH/events/dwc3/enable"
  do_cmd "modprobe g_zero"
  do_cmd "grep dwc3 $TRACE_PATH/trace -q"
  return 0
}

ucsi_trace_check() {
  do_cmd "echo > $TRACE_PATH/trace"
  do_cmd "echo 1 > $TRACE_PATH/events/ucsi/enable"
  do_cmd "rtcwake -m freeze -s 5"
  do_cmd "grep ucsi $TRACE_PATH/trace -q"
  return 0
}

main() {
  teardown_handler="trace_teardown"
  case $TEST_SCENARIO in
    host)
      host_trace_check
      ;;
    gadget)
      dwc3_trace_check
      ;;
    ucsi)
      ucsi_trace_check
      ;;
    *)
      usage
      die "Invalid Test ID!"
      ;;
  esac
}

while getopts :t:H: arg
do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
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

main

# Call teardown for passing case
exec_teardown
