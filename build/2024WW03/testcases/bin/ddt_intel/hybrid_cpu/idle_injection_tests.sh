#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2021 Intel Corporation
#
# File:         idle_injection_tests.sh
#
# Description:  idle injection test script
#
# Author(s):    Ammy Yi <ammy.yi@intel.com>
#
# Date:         12/31/2021
#


source "common.sh"
source "functions.sh"
: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

INJECTION_VALUE=0

valid_list="v_cpu.list"
cpu_utilization=0

get_valid_core_list() {
  temp_log="temp.log"
  level_4_list="l_4_cpu.list"
  all_list="cpu.list"
  ##get all perf-profile-level-4 core list
  intel-speed-select -o $temp_log perf-profile info
  grep perf-profile-level-4 -A 6 $temp_log | grep enable-cpu-list | awk -F ":" '{print $2}' | tr "," "\n"> $level_4_list
  ##get all core list
  cat /proc/cpuinfo | grep processor | awk '{print $3}' > $all_list
  ##get all idle injection supported core list
  grep -vwf $level_4_list $all_list > $valid_list
}

get_cpu_utilization() {
  core_id=$1
  turbostat_log="turbostat.log"
  turbostat -c $core_id --show Package,Core,CPU,Busy%,Bzy_MHz,TSC_MHz -n 5 -i 1 > $turbostat_log
  sleep 1
  cpu_utilization=$(grep -w $core_id $turbostat_log | grep -v "-" |  awk '{print $4}' |awk '{sum+=$1} END {print "", sum/NR}')
}

kill_stress() {
  pids=$(ps | grep "stress" | awk '{print $1}')
  for pid in $pids; do
    kill -9 $pid
  done
}

result_check() {
  diff=0
  begin_v=$begin_v
  end_v=$end_v
  [[ $begin_v -eq $end_v ]] && die "CPU utilization no change!"
  let diff=100-end_v-INJECTION_VALUE
  if [[ $diff -lt 0 ]]; then
    let diff=0-$diff
  fi
  test_print_trc "*******core_id=$core_id, diff=$diff, end_v=$end_v, INJECTION_VALUE=$INJECTION_VALUE"
  [[ $diff -le 10 ]] || die "There is > 10% diff with target!"
} 

hfi_idle_test() {
  temp_t_log="temp_t.log"
  core_ids=$(cat $valid_list)
  for core_id in $core_ids; do
    ##set core busy
    taskset -c $core_id stress -c 1 &
    sleep 5
    ##get cpu utilization for core
    get_cpu_utilization $core_id
    begin_v=$cpu_utilization
    ###enable idle injection
    intel-speed-select perf-profile set-config-level -l 4
    [[ $? -eq 0 ]] || die "intel-speed-select set level 4 failed!"
    sleep 5
    ##get cpu utilization for core
    get_cpu_utilization $core_id
    end_v=$cpu_utilization
    kill_stress
    test_print_trc "*******core_id=$core_id, begin_v=$begin_v, end_v=$end_v"
    result_check $begin_v $end_v
  done 
}


idle_injection_test() {
  get_valid_core_list
  case $TEST_SCENARIO in
  hfi_idle)
    hfi_idle_test
      ;;
    esac
  return 0
}

while getopts :t:d:w:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    d)
      INJECTION_VALUE=$OPTARG
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

idle_injection_test
# Call teardown for passing case
exec_teardown
