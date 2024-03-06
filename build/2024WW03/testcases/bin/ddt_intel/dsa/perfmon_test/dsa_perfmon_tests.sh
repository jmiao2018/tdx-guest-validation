#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2020 Intel Corporation
#
# File:         dsa_perfmon_tests.sh
#
# Description:  DSA perfmon test script
#
# Author(s):    Ammy Yi <ammy.yi@intel.com>
#
# Date:         11/18/2020
#


source "common.sh"
source "dmesg_functions.sh"
: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

DSA_TEST_BIN="dsa_test"
DSA_STRESS_TEST_BIN="run_test"


driver_test() {
  MODULE_NAME="idxd"
  load_unload_module.sh -u -d $MODULE_NAME
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  extract_case_dmesg | grep idxd | grep failed
  if [[ $? -eq 0 ]]; then
    die "There is some error in dmesg!"
  fi
  do_cmd "perf stat -e dsa0/event=0x8,event_category=0x3/ dsa_test -w 1 -l 1024 -o0x3 -t200"
}

dsa_config() {
  test_print_trc "Begin to config DSA!"
  config.sh
  enable.sh 
}

cpu_hotplug_test() {
  echo 0 > /sys/devices/system/cpu/cpu1/online
  echo 1 > /sys/devices/system/cpu/cpu1/online
  extract_case_dmesg | grep idxd | grep failed
  if [[ $? -eq 0 ]]; then
    die "There is some failed in dmesg!"
  fi
  extract_case_dmesg | grep idxd | grep ERR
  if [[ $? -eq 0 ]]; then
    die "There is some ERROR in dmesg!"
  fi
  extract_case_dmesg | grep idxd | grep WARN
  if [[ $? -eq 0 ]]; then
    die "There is some WARN in dmesg!"
  fi
}

counter_check() {
  logfile=$1
  counters=$(grep dsa $logfile | awk '{print $1}')
  sum=0
  for counter in $counters; do
    test_print_trc "sum=$sum, counter=$counter!"
    let sum=sum+counter 
  done
  test_print_trc "sum=$sum"
  [[ $sum -eq 0 ]] && die "counters is zero!"
}

all_test() {
  logfile="temp.log"
  p_path=$(pwd)
  test_print_trc "p_path=$p_path"
  cases=$(ls $p_path/ddt_intel/dsa/perfmon_test/ | grep testcase)
  test_print_trc "cases=$cases!"
  for case in $cases; do
    do_cmd "$case $logfile"
    if [[ $case = "testcase13" ]]; then
      counters=$(grep dsa $logfile | grep -c "not count")
      [[ $counters -eq 1 ]] || die "not count is not 1!"
      counters=$(grep dsa $logfile | grep -c "not support")
      [[ $counters -eq 1 ]] || die "not count is not 1!"
    else
      counter_check $logfile
    fi
  done
}

dsa_perfmon_test() {
  dsa_config
  case $TEST_SCENARIO in
    driver)
      driver_test
      ;;
    cpu_hotplug)
      cpu_hotplug_test
      ;;
    all)
      all_test
      ;;
    esac
  return 0
}

dsa_perfmon_teardown(){
  disable.sh
}

while getopts :t:w:H arg; do
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

dsa_perfmon_test
teardown_handler="dsa_perfmon_teardown"
# Call teardown for passing case
exec_teardown
