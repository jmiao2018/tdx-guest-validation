#!/bin/bash
#
# Copyright 2019 Intel Corporation
#
# This file is part of LTP-DDT for IA
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
#             Feb. 26, 2019 - (Ammy Yi)Creation


# @desc This script verify QEP test
# @returns Fail the test if return code is non-zero (value set not found)


source "common.sh"
: ${CASE_NAME:=""}

readonly SYS_DEVICE_PATH="/sys/bus/pci/devices/0000:00:18.4/"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

sysfs_test() {
  type=$1
  device_nodes=$(ls $SYS_DEVICE_PATH | grep counter)
  [ -n "$device_nodes" ] || die "no counter devices under $SYS_DEVICE_PATH!"
  for node in $device_nodes; do
    counts=$(ls -F "$SYS_DEVICE_PATH"/"$node" | grep '/$' | grep count)
    for count in $counts; do
      value=$(cat "$SYS_DEVICE_PATH"/"$node"/$count/$type)
      [[ $? -eq 0 ]] || die "$type is not correct!"
      test_print_trc "$type = $value"
    done
  done
}

dev_lspci() {
  for pattern in '4bc3' '4b81' '4b82' '4b83'; do
    lspci -knnv | grep -i $pattern -A 10 | grep intel-qep \
      || die "qep is not found in lspci with $pattern!"
  done
}

driver_check() {
  MODULE_NAME="intel_qep"
  KOPTION="CONFIG_INTEL_QEP"
  kconfig=$(get_kconfig "$KOPTION")
  if [[ "$kconfig" == "m" ]]; then
    load_unload_module.sh -c -d $MODULE_NAME || \
      do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  elif [[ "$kconfig" == "y" ]]; then
    test_print_trc "$KOPTION is built-in"
  else
    block_test "$KOPTION is not set!"
  fi
  do_cmd "load_unload_module.sh -u -d $MODULE_NAME"
  do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
}

readonly POWER_DISK_NODE="/sys/power/disk"
readonly POWER_PM_TEST_NODE="/sys/power/pm_test"

suspend_to_resume() {
  local state=$1
  local rtc_time=20

  echo platform > "$POWER_DISK_NODE"
  echo none > "$POWER_PM_TEST_NODE"

  case $state in
    freeze)
      echo freeze > "$POWER_STATE_NODE" &
      rtcwake -m no -s "$rtc_time"
      [[ $? -eq 0 ]] || die "fail to resume from $state!"
      wait $!
      [[ $? -eq 0 ]] || die "fail to echo $state > $POWER_STATE_NODE!"
      ;;
    mem|disk)
      echo deep > /sys/power/mem_sleep
      rtcwake -m "$state" -s "$rtc_time"
      [[ $? -eq 0 ]] || die "fail to resume from $state!"
      ;;
    *)
      die "state: $state not supported!"
      ;;
  esac
}

sr_test() {
  suspend_to_resume $1
  sleep 1
  sysfs_test capture_data
}

qep_test() {
  case $TEST_SCENARIO in
    dev)
      dev_lspci
      ;;
    driver)
      driver_check
      ;;
    mem)
      sr_test mem
      ;;
    disk)
      sr_test disk
      ;;
    capture_data)
      sysfs_test capture_data
      ;;
    count)
      sysfs_test count
      ;;
    direction)
      sysfs_test direction
      ;;
    capture_mode)
      sysfs_test capture_mode
      ;;
    esac
  return 0
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

qep_test
# Call teardown for passing case
exec_teardown
