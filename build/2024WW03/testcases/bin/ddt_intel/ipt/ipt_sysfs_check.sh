#!/bin/bash
#
# Copyright 2018 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate IPT component
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
#             Jun. 11, 2018 - (Ammy Yi)Creation


# @desc This script verify ipt sysfs interface test
# @returns Fail the test if return code is non-zero (value set not found)

source "common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

caps_check() {
  do_cmd "cat /sys/bus/event_source/devices/intel_pt/caps/mtc | grep 1"
  do_cmd "cat /sys/bus/event_source/devices/intel_pt/caps/cr3_filtering | grep 1"
  do_cmd "cat /sys/bus/event_source/devices/intel_pt/caps/ip_filtering | grep 1"
  do_cmd "cat /sys/bus/event_source/devices/intel_pt/caps/topa_output | grep 1"
  do_cmd "cat /sys/bus/event_source/devices/intel_pt/caps/psb_cyc | grep 1"
  do_cmd "cat /sys/bus/event_source/devices/intel_pt/caps/topa_multiple_entries | grep 1"
}

time_check() {
  do_cmd "ls /sys/bus/event_source/devices/intel_pt/ | grep tsc_art_ratio"
  do_cmd "ls /sys/bus/event_source/devices/intel_pt/ | grep max_nonturbo_ratio"
}

ipt_sys_test() {
  case $TEST_SCENARIO in
    path)
      do_cmd "ls /sys/bus/event_source/devices | grep intel_pt"
      ;;
    caps)
      caps_check
      ;;
    time)
      time_check
      ;;
  esac
}

while getopts :t:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    H)
      usage && exit 0
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

ipt_sys_test
# Call teardown for passing case
exec_teardown
