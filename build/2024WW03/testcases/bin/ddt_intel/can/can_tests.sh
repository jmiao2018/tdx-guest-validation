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
#             Feb. 19, 2019 - (Ammy Yi)Creation


# @desc This script verify CAN test
# @returns Fail the test if return code is non-zero (value set not found)


source "common.sh"
: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

PCI_PATH="/sys/bus/pci/devices/0000:00:18."

dev_enum_test() {
  id=1
  if [ "$id" -lt 3 ]; then
    device_nodes=$(cat /"$PCI_PATH"$id/device)
    if [[ "$device_nodes" != "0x4bc1" ]] && [[ "$device_nodes" != "0x4bc2" ]]; then
      die "no can devices under $PCI_PATH$id!"
    fi
    let id=id+1
  fi
}

dev_lspci() {
  for pattern in '4bc1' '4bc2'; do
    lspci -knnv | grep -i $pattern -A 9 | grep m_can_pci \
      || die "qep is not found in lspci with $pattern!"
  done
}

driver_check() {
  MODULE_NAME="m_can_pci"
  KOPTION="CONFIG_CAN_M_CAN_PCI"
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

interface_test() {
  num=$(ifconfig -a | grep -c can)
  [[ "$num" -eq 2 ]] || die "no can devices in ifconfig!"
}

rw_test() {
  file="temp.txt"
  type=$1
  for node in 'can0' 'can1'; do
    do_cmd "ip link set $node down"
    do_cmd "ip link set $node type can bitrate 100000 $type on"
    do_cmd "ip link set $node up"
    sleep 1
    cangen $node -g 4 -I 42A -L 1 -D i -v -v > $file &
    sleep 2
    id=$(ps -al | grep candump |awk '{print $1}')
    kill $id
    grep -rn "no buffer" $file
    [[ $? -ne 0 ]] || die "no buffer is found in output!"
    candump $node > $file &
    sleep 2
    lines=$(cat $file | wc -l)
    [[ "$lines" -ne 0 ]] || die "read lines = $lines!"
    do_cmd "ip link set $node down"
  done
}

basic_test() {
  for node in 'can0' 'can1'; do
    ip -details -statistics link show $node
  done
}

bitrate_test() {
  for node in 'can0' 'can1'; do
    do_cmd "ip link set $node down"
    do_cmd "ip link set $node type can bitrate 1250000"
  done
}

fd_test() {
  for node in 'can0' 'can1'; do
    do_cmd "ip link set $node down"
    do_cmd "ip link set $node up type can bitrate 500000 sample-point 0.75 dbitrate 4000000 dsample-point 0.8 fd on"
  done
}

ss_test() {
  for node in 'can0' 'can1'; do
    do_cmd "ip link set $node type can bitrate 1250000"
    do_cmd "ip link set $node up"
    do_cmd "cat /proc/interrupts | grep $node"
    do_cmd "ip link set $node down"
    should_fail "cat /proc/interrupts | grep $node"
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
  file="temp.txt"
  for node in 'can0' 'can1'; do
    do_cmd "ip link set $node down"
    do_cmd "ip link set $node type can bitrate 1000000 dbitrate 2000000 fd on"
    do_cmd "ip link set $node up"
  done
  sleep 1
  suspend_to_resume $1
  sleep 1
  do_cmd "candump can0 > $file & "
  sleep 1
  do_cmd "cansend can1 001#11223344AABBCCDD"
  do_cmd "grep AA $file"
  for node in 'can0' 'can1'; do
    do_cmd "ip link set $node down"
  done
}

can_test() {
  case $TEST_SCENARIO in
    dev_enum)
      dev_enum_test
      ;;
    driver)
      driver_check
      ;;
    dev)
      dev_lspci
      ;;
    interface)
      interface_test
      ;;
    rw_loop)
      rw_test loopback
      ;;
    rw_listen)
      rw_test listen-only
      ;;
    basic)
      basic_test
      ;;
    bitrate)
      bitrate_test
      ;;
    ss)
      ss_test
      ;;
    mem)
      sr_test mem
      ;;
    disk)
      sr_test disk
      ;;
    fd)
      fd_test
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

can_test
# Call teardown for passing case
exec_teardown
