#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2020 Intel Corporation
# @Author   Furong Shen <furongx.shen@intel.com>
#           Wendy Wang  <wendy.wang@intel.com>
# @desc     Automate intel s0ix substate test cases
# @returns  0 if the execution was finished successfully, else 1

source "powermgr_common.sh"

# We can say s0ix substate is achieved only the delta value is non-zero
function check_s0i2_1() {
  if [[ $s0i2_1_res -le 0 ]]; then
    die \
      "S0ix substate s0i2.1 is NOT available during s2idle path: $s0i2_1_res"
  fi
  test_print_trc \
    "S0ix substate s0i2.1 is available during s2idle path: $s0i2_1_res"
}

function check_s0i3_0() {
  if [[ $s0i3_0_res -le 0 ]]; then
    die \
      "S0ix substate s0i3.0 is NOT available during s2idle path: $s0i3_0_res"
  fi
  test_print_trc \
    "S0ix substate s0i3.0 is available during s2idle path: $s0i3_0_res"
}

function check_s0i3_2() {
  if [[ $s0i3_2_res -le 0 ]]; then
    die \
      "S0ix substate s0i3.2 is NOT available during s2idle path: $s0i3_2_res"
  fi
  test_print_trc \
    "S0ix substate s0i3.2 is available during s2idle path: $s0i3_2_res"
}

function check_s0i3_4() {
  if [[ $s0i3_4_res -le 0 ]]; then
    die \
      "S0ix substate s0i3.4 is NOT available during s2idle path: $s0i3_4_res"
  fi
  test_print_trc \
    "S0ix substate s0i3.4 is available during s2idle path: $s0i3_4_res"
}

duration=100

# Judge whether pmc_core sysfs is exits or not
[[ -d $PMC_CORE_SYSFS_PATH ]] || block_test \
  "pmc_core sysfs is not available,please check pmc_core driver load status"

# Print S0IX_SUBSTATE_RESIDENCY values before suspend to idle
test_print_trc \
  "S0ix substate residnecy value before suspend to idle: \
  $S0IX_SUBSTATE_RESIDENCY"

# Check if rtcwake exist in current environment
which rtcwake &> /dev/null || block_test \
  "rtcwake is not in current environment"

# Get s0ix substate residnecy before doing suspend to idle
s0i2_1_before=$(grep S0i2.1 "$S0IX_SUBSTATE_RESIDENCY" | awk '{print $2}')
test_print_trc \
  "S0ix substate s0i2.1 residency is before s2idle: $s0i2_1_before"
s0i3_0_before=$(grep S0i3.0 "$S0IX_SUBSTATE_RESIDENCY" | awk '{print $2}')
test_print_trc \
  "S0ix substate s0i3.0 residency is before s2idle: $s0i3_0_before"
s0i3_2_before=$(grep S0i3.2 "$S0IX_SUBSTATE_RESIDENCY" | awk '{print $2}')
test_print_trc \
  "S0ix substate s0i3.2 residency is before s2idle: $s0i3_2_before"
s0i3_4_before=$(grep S0i3.4 "$S0IX_SUBSTATE_RESIDENCY" | awk '{print $2}')
test_print_trc \
  "S0ix substate s0i3.4 residency is before s2idle: $s0i3_4_before"

# set rtc auto wake up for suspend to idle
echo 0 > /sys/class/rtc/rtc0/wakealarm || block_test \
  "echo 0 to wakealarm failed"
echo +$duration > /sys/class/rtc/rtc0/wakealarm || block_test \
  "echo +$duration to wakealarm failed"
echo freeze > /sys/power/state 2>&1
# print S0IX_SUBSTATE_RESIDENCY values after suspend to idle
test_print_trc \
  "S0ix substate residency value after suspend to idle: \
  $S0IX_SUBSTATE_RESIDENCY"

# Get s0ix substate residnecy after doing suspend to idle
s0i2_1_after=$(grep S0i2.1 "$S0IX_SUBSTATE_RESIDENCY" | awk '{print $2}')
test_print_trc "S0ix substate s0i2.1 residency is after s2idle: $s0i2_1_after"
s0i3_0_after=$(grep S0i3.0 "$S0IX_SUBSTATE_RESIDENCY" | awk '{print $2}')
test_print_trc "S0ix substate s0i3.0 residency is after s2idle: $s0i3_0_after"
s0i3_2_after=$(grep S0i3.2 "$S0IX_SUBSTATE_RESIDENCY" | awk '{print $2}')
test_print_trc "S0ix substate s0i3.2 residency is after s2idle: $s0i3_2_after"
s0i3_4_after=$(grep S0i3.4 "$S0IX_SUBSTATE_RESIDENCY" | awk '{print $2}')
test_print_trc "S0ix substate s0i3.4 residency is after s2idle: $s0i3_4_after"

# Get s0ix substate residency delta value between
# suspend to idle after and before
s0i2_1_res=$((s0i2_1_after - s0i2_1_before))
s0i3_0_res=$((s0i3_0_after - s0i3_0_before))
s0i3_2_res=$((s0i3_2_after - s0i3_2_before))
s0i3_4_res=$((s0i3_4_after - s0i3_4_before))

while getopts c:h arg; do
  case $arg in
    c)
      CASE_ID=$OPTARG
      test_print_trc "case is: $CASE_ID"
      ;;
    h)
      die "${0##*/} -c <CASE_ID> -h
          -c CASE_ID: which case to launch
          -h: show help
          "
      ;;
    \?)
      die "You must supply an argument, ${0##*/} -h"
      ;;
    *)
      die "Invalid argument, ${0##*/} -h"
      ;;
  esac
done

# Set the default case id as 1
: ${CASE_ID:="1"}

case $CASE_ID in
  1)
    test_print_trc "Start S0ix substate s2idle path s0i2.1 residency test."
    check_s0i2_1
    ;;
  2)
    test_print_trc "Start S0ix substate s2idle path s0i3.0 residency test."
    check_s0i3_0
    ;;
  3)
    test_print_trc "Start S0ix substate s2idle path s0i3.2 residency test."
    check_s0i3_2
    ;;
  4)
    test_print_trc "Start S0ix substate s2idle path s0i3.4 residency test."
    check_s0i3_4
    ;;
  *)
    block_test "Wrong Case Id is assigned: $CASE_ID"
    ;;
esac
