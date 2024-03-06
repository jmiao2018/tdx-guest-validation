#!/bin/bash
###############################################################################
##                                                                           ##
## Copyright (c) 2018, Intel Corporation.                                    ##
##                                                                           ##
## This program is free software; you can redistribute it and/or modify it   ##
## under the terms and conditions of the GNU General Public License,         ##
## version 2, as published by the Free Software Foundation.                  ##
##                                                                           ##
## This program is distributed in the hope it will be useful, but WITHOUT    ##
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or     ##
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for ##
## more details.                                                             ##
###############################################################################
#
# File:         mfc_common.sh
#
# Description:  common file for cpu most favored core test
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      April 18 2018 - created - Pengfei Xu

# @desc provide common functions for cpu favored core features
# @returns Fail if return code is non-zero (value set not found)

source "common.sh"

CPU_NUM=$(cat /proc/cpuinfo| grep "processor"| wc -l)
CORE_NUM=$(cat /proc/cpuinfo| grep "cpu cores"| uniq | awk -F ' ' '{print $NF}')
CPU_CMD="dd if=/dev/zero of=/dev/null"

teardown_handler="mfc_teardown"

# For favored core taerdown
mfc_teardown() {
  [[ $(ps -ef | grep -q "$CPU_CMD" | grep -v grep) ]] || {
    test_print_trc "clean dd process after favored core test"
    do_cmd "pkill dd"
  }
}

# Convert logic cpu to core number
# Input:
# $1: logic cpu number
# Return: the core number thread used or false
cpu_to_core() {
  local cpu=$1
  local core=""

  if [[ "$cpu" -lt "$CORE_NUM" ]]; then
    core=$cpu
  else
    core=$((cpu-CORE_NUM))
  fi
  echo "$core"
}

favored_core_test() {
  local s1_pid=""
  local s1_cpu=""
  local s1_core=""
  local s2_pid=""
  local s2_cpu=""
  local s2_core=""
  local s2_cpu_move=""
  local s2_core_move=""

  test_print_trc "CORE_NUM: $CORE_NUM    CPU_NUM: $CPU_NUM"
  [[ $(ps -ef | grep -q "$CPU_CMD" | grep -v grep) ]] \
    || do_cmd "pkill dd"

  # start 1st cpu 100% thread and check thread and core
  do_cmd "$CPU_CMD &"
  sleep 1
  s1_pid=$(ps -aux \
            | grep "$CPU_CMD" \
            | grep -v grep \
            | tail -n 1 \
            | awk -F ' ' '{print $2}')
  s1_cpu=$(ps -o pid,psr -p "$s1_pid" \
          | grep "$s1_pid" \
          | awk -F ' ' '{print $2}')
  s1_core=$(cpu_to_core "$s1_cpu")

  test_print_trc "s1_pid:$s1_pid, s1_cpu:$s1_cpu, s1_core:$s1_core"

  # start 2nd cpu 100% thread and check thread and core
  do_cmd "$CPU_CMD &"
  sleep 1
  s2_pid=$(ps -aux \
            | grep "$CPU_CMD" \
            | grep -v grep \
            | grep -v "$s1_pid" \
            | tail -n 1 \
            | awk -F ' ' '{print $2}')
  s2_cpu=$(ps -o pid,psr -p "$s2_pid" \
          | grep "$s2_pid" \
          | awk -F ' ' '{print $2}')
  s2_core=$(cpu_to_core "$s2_cpu")
  test_print_trc "s2_pid:$s2_pid, s2_cpu:$s2_cpu, s2_core:$s2_core"

  do_cmd "kill -9 $s1_pid"
  sleep 2

  s2_cpu_move=$(ps -o pid,psr -p "$s2_pid" \
                | grep "$s2_pid" \
                | awk -F ' ' '{print $2}')
  s2_core_move=$(cpu_to_core "$s2_cpu_move")
  test_print_trc "s2_cpu_move:$s2_cpu_move, s2_core_move:$s2_core_move"

  if [[ "$s1_core" -eq "$s2_core" ]]; then
    if [[ "$s2_cpu" -eq "$s2_cpu_move" ]]; then
      test_print_trc "same core in favored core test pass"
    else
      die "same core in favored core test fail"
    fi
  else
    if [[ "$s2_cpu_move" -eq "$s1_core" ]]; then
      test_print_trc "different core in favored core test pass"
    else
      test_print_trc "s2_core_move expect:$s1_core, actual:$s2_cpu_move"
      die "different core in favored core test fail"
    fi
  fi
}

# Read msr to confirm mfc was enabled to test
# rdmsr to check last 2 characters show different max frequencies,
# which multiplied by 100Mhz
# Input: null
# Output: Return 0, otherwise false or die
mfc_rdmsr() {
  local msr="msr"
  local mfc_mem="0x771"
  local mfc_info=""
  local cpu_hz=""
  local mfc_result=""

  load_unload_module.sh -c -d "$msr" || {
    test_print_trc "load module $msr"
    load_unload_module.sh -l -d "$msr"
  }
  sleep 2

  mfc_info=$(rdmsr -a $mfc_mem)
  test_print_trc "mfc rdmsr -a $mfc_mem:$mfc_info"

  # last 2 characters cpu hz should different when mfc enabled
  cpu_hz=$(echo $mfc_info | grep -o '..$' | sort -u)
  mfc_result=$(echo $mfc_info | grep -o '..$' | sort -u| wc -l)
  test_print_trc "cpu different hz:$cpu_hz"
  if [[ "$mfc_result" -eq 2 ]]; then
    test_print_trc "mfc rdmsr pass, expect 2 different cpu hz:$mfc_result"
  else
    die "mfc rdmsr check failed, expect 2 different but actually:$mfc_result"
  fi
}

# Kill 1st 100% cpu pid and launch 2nd 100% cpu pid,
# both pid core should same
# Input: null
# Output: Return 0, otherwise false or die
mfc_core_check() {
  local s1_pid=""
  local s1_cpu=""
  local s1_core=""
  local s2_pid=""
  local s2_cpu=""
  local s2_core=""

  [[ $(ps -ef | grep -q "$CPU_CMD" | grep -v grep) ]] \
    || do_cmd "pkill dd"
  do_cmd "$CPU_CMD &"
  sleep 1
  s1_pid=$(ps -aux \
            | grep "$CPU_CMD" \
            | grep -v grep \
            | tail -n 1 \
            | awk -F ' ' '{print $2}')
  s1_cpu=$(ps -o pid,psr -p "$s1_pid" \
          | grep "$s1_pid" \
          | awk -F ' ' '{print $2}')
  s1_core=$(cpu_to_core "$s1_cpu")

  test_print_trc "s1_pid:$s1_pid, s1_cpu:$s1_cpu, s1_core:$s1_core"
  do_cmd "kill -9 $s1_pid"
  sleep 1

  do_cmd "$CPU_CMD &"
  sleep 1
  s2_pid=$(ps -aux \
            | grep "$CPU_CMD" \
            | grep -v grep \
            | grep -v "$s1_pid" \
            | tail -n 1 \
            | awk -F ' ' '{print $2}')
  s2_cpu=$(ps -o pid,psr -p "$s2_pid" \
          | grep "$s2_pid" \
          | awk -F ' ' '{print $2}')
  s2_core=$(cpu_to_core "$s2_cpu")
  test_print_trc "s2_pid:$s2_pid, s2_cpu:$s2_cpu, s2_core:$s2_core"

  if [[ "$s1_core" == "$s2_core" ]]; then
    test_print_trc "s1 core:$s1_core, s2 core:$s2_core, core same, pass."
  else
    die "s1 core:$s1_core, s2 core:$s2_core, core different, fail"
  fi
}
