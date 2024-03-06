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
#             Mar. 4, 2019 - (Ammy Yi)Creation


# @desc This script verify ADC test
# @returns Fail the test if return code is non-zero (value set not found)


source "common.sh"
: ${CASE_NAME:=""}

readonly PCI_PATH="/sys/bus/pci/devices/0000:00:1d.7/"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -s  SOURCE TYPE
  -d  TEST DEVICE PONIT
  -p  PROFILE
  -H  show this
__EOF
}

adc_name="0000:00:1d.7"

dev_check() {
  device_nodes=$(ls $PCI_PATH | grep iio)
  [ -n "$device_nodes" ] || die "no iio devices under sysfs!"
  for node in $device_nodes; do
    name=$(cat "$PCI_PATH"/"$node"/name)
    test_print_trc "name = $name"
    if [[ $name = $adc_name ]]; then
      ls /dev/$node
      [[ $? -eq 0 ]] || die "adc devices is not found under $PCI_PATH!"
    fi
  done
}

dev_lspci() {
  lspci -knnv | grep -i 4bb8 -A 10 | grep intel_adc \
      || die "adc is not found in lspci with 4bb8!"
}

driver_check() {
  MODULE_NAME="intel_adc"
  KOPTION="CONFIG_INTEL_ADC"
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

pulling_check() {
  dev="iio:device0"
  device_nodes=$(ls $PCI_PATH/$dev | grep raw)
  test_print_trc "device_nodes = $device_nodes"
  [ -n "$device_nodes" ] || die "no raw data under $PCI_PATH/$dev!"
  for node in $device_nodes; do
    value=$(cat "$PCI_PATH"/"$dev"/"$node")
    test_print_trc "$node = $value"
    if [[ $value = "0000000" || $value = fffffff  ]]; then
      die "adc raw value is incorrect!"
    fi
  done
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
  pulling_check
}

adc_test() {
  case $TEST_SCENARIO in
    dev_check)
      dev_check
      ;;
    dev)
      dev_lspci
      ;;
    driver)
      driver_check
      ;;
    pulling)
      pulling_check
      ;;
    mem)
      sr_test mem
      ;;
    disk)
      sr_test disk
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

adc_test
# Call teardown for passing case
exec_teardown
