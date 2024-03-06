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
#             Feb. 14, 2019 - (Ammy Yi)Creation


# @desc This script verify TGPIO test
# @returns Fail the test if return code is non-zero (value set not found)


source "common.sh"
: ${CASE_NAME:=""}

readonly PTP_SYS_DEVICE_PATH="/sys/class/ptp/"

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

tgpio_ose_name="Intel TGPIO"
tgpio_pmc_name="Intel PMC TGPIO"
MODE="default"
PIN_COUNT=0

sysfs_test() {
  type=$1

  device_nodes=$(ls $PTP_SYS_DEVICE_PATH)
  [ -n "$device_nodes" ] || die "no ptp devices under sysfs!"
  for node in $device_nodes
  do
    name=$(cat "$PTP_SYS_DEVICE_PATH"/"$node"/clock_name)
    test_print_trc "name = $name"
    if [[ $name = $tgpio_name ]]; then
      if [[ $type = "max_adj" ]]; then
        max_v=$(cat "$PTP_SYS_DEVICE_PATH"/"$node"/max_adjustment)
        [[ $max_v -eq 50000000 ]] || die "max adjust value is not correct!"
      elif [[ $type = "pins_count" ]]; then
        n_pins=$(cat "$PTP_SYS_DEVICE_PATH"/"$node"/n_programmable_pins)
        test_print_trc "PIN_COUNT = $PIN_COUNT, n_pins=$n_pins"
        [[ $n_pins -eq $PIN_COUNT ]] || die "pins count value is not correct!"
      fi
    fi
  done
}

dev_check() {
  device_nodes=$(ls $PTP_SYS_DEVICE_PATH)
  [ -n "$device_nodes" ] || die "no ptp devices under sysfs!"
  for node in $device_nodes
  do
    name=$(cat "$PTP_SYS_DEVICE_PATH"/"$node"/clock_name)
    test_print_trc "name = $name"
    if [[ $name = $tgpio_name ]]; then
      ls /dev/$node
      [[ $? -eq 0 ]] || die "ptp devices is not found under /dev!"
    fi
  done
}

driver_ose_check() {
  MODULE_NAME="ptp-intel-tgpio"
  KOPTION="CONFIG_PTP_INTEL_TGPIO"
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

driver_check() {
  MODULE_NAME="ptp-intel-pmc-tgpio"
  KOPTION="CONFIG_PTP_INTEL_PMC_TGPIO"
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

dev_lspci_ose() {
  lspci -knnv | grep -i 4b88 -A 3 | grep ptp_intel_tgpio
  [[ $? -eq 0 ]] || die "tgpio is not found in lspci with 4b88!"
  lspci -knnv | grep -i 4b89 -A 3 | grep ptp_intel_tgpio
  [[ $? -eq 0 ]] || die "tgpio is not found in lspci with 4b89!"
}

ptp_test() {
  SCENARIO=$1
  device_nodes=$(ls $PTP_SYS_DEVICE_PATH)
  [ -n "$device_nodes" ] || die "no ptp devices under sysfs!"
  for node in $device_nodes; do
    name=$(cat "$PTP_SYS_DEVICE_PATH"/"$node"/clock_name)
    test_print_trc "name = $name"
    if [[ "$name" == "$tgpio_name" ]]; then
      case $TEST_SCENARIO in
        cap)
          do_cmd "testptp -d /dev/$node -c"
          ;;
        gtime)
          do_cmd "testptp -d /dev/$node -g"
          time1=$(testptp -d /dev/$node -g)
          test_print_trc "time1 = $time1"
          sleep 5
          time2=$(testptp -d /dev/$node -g)
          test_print_trc "time2 = $time2"
          [[ "$time1" == "$time2" ]] && die "time no change!"
          ;;
        stime)
          do_cmd "testptp -d /dev/$node -T 50"
          ;;
        adjf)
          do_cmd "testptp -d /dev/$node -f 50000"
          should_fail "testptp -d /dev/$node -f 500000000"
          ;;
        agjt)
          do_cmd "testptp -d /dev/$node -s"
          ;;
        input)
          if [[ $MODE = "ose" ]]; then
            for id in 6 18; do
              do_cmd "testptp -d /dev/$node -L $id,1"
              do_cmd "testptp -d /dev/$node -i $id -e 100"
            done
          fi
          if [[ $MODE = "pmc" ]]; then
            for id in 0 1; do
              do_cmd "testptp -d /dev/$node -i $id -L $id,1"
              do_cmd "testptp -d /dev/$node -i $id -e 100 -E"
            done
          fi

          ;;
        output)
          if [[ $MODE = "ose" ]]; then
            for id in 6 18; do
              do_cmd "testptp -d /dev/$node -L $id,2"
              do_cmd "testptp -d /dev/$node -i $id -p 1000000"
            done
          fi
          if [[ $MODE = "pmc" ]]; then
            for id in 0 1; do
              do_cmd "testptp -d /dev/$node -i $id -L $id,2"
              do_cmd "testptp -d /dev/$node -i $id -p 1000000"
            done
          fi
          ;;
          # let count=PIN_COUNT-1
          # for id in $(seq 0 $count); do
          #   do_cmd "testptp -d /dev/$node -L $id,2"
          #   do_cmd "testptp -d /dev/$node -i $id -p 1000000"
          # done
          # ;;
      esac
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
  ptp_test gtime
}

tpgio_test() {
  if [[ $MODE = "ose" ]]; then
    tgpio_name=$tgpio_ose_name
    PIN_COUNT=20
  fi
  if [[ $MODE = "pmc" ]]; then
    tgpio_name=$tgpio_pmc_name
    PIN_COUNT=2
  fi
  case $TEST_SCENARIO in
    max_adj)
      sysfs_test max_adj
      ;;
    pins_count)
      sysfs_test pins_count
      ;;
    dev_check)
      dev_check
      ;;
    driver)
      driver_check
      ;;
    driver_ose)
      driver_ose_check
      ;;
    dev_ose)
      dev_lspci_ose
      ;;
    cap)
      ptp_test cap
      ;;
    gtime)
      ptp_test gtime
      ;;
    stime)
      ptp_test gtime
      ;;
    agjf)
      ptp_test agjf
      ;;
    agjt)
      ptp_test agjt
      ;;
    input)
      ptp_test input
      ;;
    output)
      ptp_test output
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

while getopts :t:m:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    m)
      MODE=$OPTARG
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

tpgio_test
# Call teardown for passing case
exec_teardown
