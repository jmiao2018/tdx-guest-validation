#!/bin/bash
#
# Copyright 2018-2019 Intel Corporation
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
#             Apr. 26, 2019 - (Ammy Yi)Creation


# @desc This script verify Adaptive PEBS test
# @returns Fail the test if return code is non-zero (value set not found)


source "common.sh"
source "functions.sh"
: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-H]
  -H  show this
__EOF
}

CPU_SYS_PATH="/sys/devices/system/cpu/"

run_pmu_suite() {
  log="/tmp/pmu.log"
  cd ddt_intel/pmu/
  [[ -d os.linux.perf.test-suite ]] || tar -xvzf pmu_test_suite.tar &> /dev/null
  rm os.linux.perf.test-suite/test_suite/test-primitives-scripts/backup_log -rf
  rm os.linux.perf.test-suite/test_suite/test-primitives-scripts/backup_log_$TAG -rf
  rm os.linux.perf.test-suite/test_suite/test-primitives-scripts/hybrid_triad_loop.sh -rf
  cd os.linux.perf.test-suite
  ./prepare.sh > $log
  grep perf_test $log | grep sanity | grep fail
  [[ $? -ne 1 ]] && die "Please check test enviroment!! pref_test failed!!"
  cd test_suite/test-primitives-scripts
  ./test_suite_function_test.sh
  cp -r backup_log backup_log_$TAG
  cd backup_log
  fail_cases=$(grep "fail" test_summary.log | awk '{print $1}')

  for num in $fail_cases; do
    [[ $num -eq 0 ]] || die "Some cases are failed, please check detailed data!"
  done
  return 0
}

get_core_ids() {
  local list="thread_siblings_list"
  CORE_IDS=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
             | grep - | cut -d \- -f 1 | sort | uniq)
  SMT_IDS=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
            | grep - | cut -d \- -f 2 | sort | uniq)
  ATOM_IDS=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
             | grep -v - | sort | uniq)
  test_print_trc "CORE_IDS=$CORE_IDS; SMT_IDS=$SMT_IDS; ATOM_IDS=$ATOM_IDS"
}


core_offline(){
    #let core offline
  for id in $CORE_IDS; do
    set_offline "cpu$id"
  done
  for id in $SMT_IDS; do
    set_offline "cpu$id"
  done
}

atom_offline(){
  for id in $ATOM_IDS; do
    set_offline "cpu$id"
  done
}

core_atom_online(){
  #let core online
  for id in $CORE_IDS; do
    set_online "cpu$id"
  done
  for id in $SMT_IDS; do
    set_online "cpu$id"
  done
  for id in $ATOM_IDS; do
    set_online "cpu$id"
  done
}


pmu_suite_test() {
  get_core_ids
  case $TEST_SCENARIO in
    core)
      core_offline
      ;;
    atom)
      atom_offline
      ;;
    esac
  run_pmu_suite
  return 0
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
teardown_handler="core_atom_online"
pmu_suite_test
# Call teardown for passing case
exec_teardown
