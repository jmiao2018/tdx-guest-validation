#!/usr/bin/env bash

###############################################################################
#
# Copyright (C) 2018 Intel - http://www.intel.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
###############################################################################
# @Author   Ning Han (ningx.han@intel.com)
# @desc     Automate intel_pstate freq step test cases designed by Wendy Wang(wendy.wang@intel.com)
# @returns  0 if the execution was finished successfully, else 1
# @history  2018-05-11: First Version (Ning Han)

source "powermgr_common.sh"

usage() {
  cat <<_EOF
  -t turbo_on? yes or no
  -m governor type
  -c core, one or all
  -h show this
_EOF
}

while getopts t:m:c:h arg; do
  case $arg in
  t) turbo_on=$OPTARG ;;
  m) mode=$OPTARG ;;
  c) core=$OPTARG ;;
  h) usage && exit 1 ;;
  \?) die "You must supply an argument, ${0##*/} -h" ;;
  *) die "Invalid argument, ${0##*/} -h" ;;
  esac
done

: "${turbo_on:="no"}"
: "${mode:="powersave"}"
: "${core:="all"}"

check_non_hwp_cap() {
  local bios_control

  bios_control=$(dmesg | grep "intel_pstate: HWP enabled by BIOS")
  [[ -n "$bios_control" ]] &&
    block_test "The test platform does not support disable HWP from OS."
}

check_non_hwp_cap

pstate_freq_step_single_test() {
  local cpus
  local original_max_freq
  local original_min_freq
  local new_freq
  local current_freq
  local turbo_on

  #filter out cpu0
  cpus=$(seq 1 "$(cat "$CPU_SYSFS_PATH"/present | cut -d'-' -f2)")
  #Hot unplug all logic cpus except cpu0
  for cpu in $cpus; do
    test_print_trc "Hot unplug cpu$cpu"
    do_cmd "echo 0 > $CPU_SYSFS_PATH/cpu$cpu/online"
  done

  original_min_freq=$(cat "/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq")
  original_max_freq=$(cat "/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq")
  new_freq="$original_min_freq"

  while [[ "$new_freq" -lt "$original_max_freq" ]]; do
    echo "$new_freq" >"/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
    echo "$new_freq" >"/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq"
    "$PSTATE_TOOL/x86_cpuload" -s 0 -c 1 -b 100 -t 90 &
    x86_cpuload_pid=$!
    cpu_stat=$("$PSTATE_TOOL/turbostat" sleep 20 2>&1)
    current_freq=$(echo "$cpu_stat" | grep "Bzy_MHz" -A1 | tail -n1 | awk '{print $3}')
    do_kill_pid "$x86_cpuload_pid" &>/dev/null
    test_print_trc "current freq:  $current_freq MHz"
    test_print_trc "max freq:  $((new_freq / 1000)) MHz"
    [[ -n "$current_freq" ]] || {
      echo "$cpu_stat"
      echo "$original_max_freq" >"/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
      echo "$original_min_freq" >"/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq"
      die "can not get current freq"
    }
    delta=$(awk -v x="$((new_freq / 1000))" -v y="$current_freq" 'BEGIN{printf "%.1f\n", x-y}')

    if [[ $(echo "${delta#-} > 100" | bc) -eq 1 ]]; then
      msr_therm_status=$(rdmsr -p 1 0x19c 2>/dev/null | cut -b 5-)
      test_print_trc "msr thermal status: $msr_therm_status"
      [ "x$msr_therm_status" == "x0000" ] && {
        echo "$original_max_freq" >"/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
        echo "$original_min_freq" >"/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq"
        die "msr_powerlimit is not set, FAIL"
      }
      die "msr_powerlimit is not set, but actual freq is out of the expected range, FAIL"
    else
      test_print_trc "checking single cpu freq: PASS"
    fi
    new_freq=$((new_freq + 100000))
    test_print_trc "cpu freq increase 100MHz to $((new_freq / 1000)) MHz"
  done
  echo "$original_max_freq" >"/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
  echo "$original_min_freq" >"/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq"
  #Hot plug all logic cpus except cpu0
  for cpu in $cpus; do
    test_print_trc "Hot plug $cpu"
    do_cmd "echo 1 > $CPU_SYSFS_PATH/cpu${cpu}/online"
  done
}

pstate_freq_step_max_test() {
  local original_min_freq
  local original_max_freq
  local new_freq
  local cpus
  local interval
  local index0
  local index1
  local max
  local cpu_stat
  local x86_cpuload_pid
  local turbo_on

  cpus=$(ls /sys/devices/system/cpu/ | grep -cE "cpu[0-9]{1,}")
  interval=$((cpus / 2))
  max="$interval"
  index0=0
  index1=$((index0 + interval))
  while [[ "$index0" -lt "$max" ]]; do
    original_min_freq=$(cat "/sys/devices/system/cpu/cpu${index0}/cpufreq/scaling_min_freq")
    original_max_freq=$(cat "/sys/devices/system/cpu/cpu${index0}/cpufreq/scaling_max_freq")
    new_freq="$original_min_freq"
    while [[ "$new_freq" -lt "$original_max_freq" ]]; do
      # set min/max freq manually
      echo "$new_freq" >"/sys/devices/system/cpu/cpu${index0}/cpufreq/scaling_max_freq"
      echo "$new_freq" >"/sys/devices/system/cpu/cpu${index1}/cpufreq/scaling_max_freq"
      echo "$new_freq" >"/sys/devices/system/cpu/cpu${index0}/cpufreq/scaling_min_freq"
      echo "$new_freq" >"/sys/devices/system/cpu/cpu${index1}/cpufreq/scaling_min_freq"
      # 100% cpu workload for all cores
      "$PSTATE_TOOL/x86_cpuload" -s 0 -c "$cpus" -b 100 -t 90 &
      x86_cpuload_pid=$!
      cpu_stat=$("$PSTATE_TOOL/turbostat" sleep 20 2>&1)
      # collection cpuinformation using turbostat
      # extract real freq of logical cores of one physical core(MHz)
      current_freq0=$(echo "$cpu_stat" | sed -n '/Bzy_MHz/,$p' | awk '{if($2=='"$index0"'){print $5}}')
      current_freq1=$(echo "$cpu_stat" | sed -n '/Bzy_MHz/,$p' | awk '{if($2=='"$index1"'){print $5}}')
      # exit cpu workload process
      do_kill_pid "$x86_cpuload_pid" &>/dev/null
      # print some runtime information
      test_print_trc "core $index0 current freq:  $current_freq0 MHz"
      test_print_trc "core $index1 current freq:  $current_freq1 MHz"
      test_print_trc "max freq:  $((new_freq / 1000)) MHz"
      # check freq deltas and determinate whether need to do further tests
      delta0=$(awk -v x="$((new_freq / 1000))" -v y="$current_freq0" 'BEGIN{printf "%.1f\n", x-y}')
      delta1=$(awk -v x="$((new_freq / 1000))" -v y="$current_freq1" 'BEGIN{printf "%.1f\n", x-y}')
      if [[ $(echo "${delta0#-} > 100" | bc) -eq 1 ]] || [[ $(echo "${delta1#-} > 100" | bc) -eq 1 ]]; then
        msr_therm_status=$(rdmsr -p 1 0x19c 2>/dev/null | cut -b 5-)
        test_print_trc "msr thermal status: $msr_therm_status"
        [ "x$msr_therm_status" == "x0000" ] && {
          echo "$original_max_freq" >"/sys/devices/system/cpu/cpu${index0}/cpufreq/scaling_max_freq"
          echo "$original_max_freq" >"/sys/devices/system/cpu/cpu${index1}/cpufreq/scaling_max_freq"
          echo "$original_min_freq" >"/sys/devices/system/cpu/cpu${index0}/cpufreq/scaling_min_freq"
          echo "$original_min_freq" >"/sys/devices/system/cpu/cpu${index1}/cpufreq/scaling_min_freq"
          die "msr_powerlimit is not set, but actual freq is out of the expected range, FAIL"
        }
        test_print_trc "msr_powerlimit is set, PASS"
      else
        test_print_trc "checking cpu freq: PASS"
      fi
      # add 100 MHz
      new_freq=$((new_freq + 100000))
      test_print_trc "cpu freq increase 100MHz to $((new_freq / 1000)) MHz"
    done
    echo "$original_max_freq" >"/sys/devices/system/cpu/cpu${index0}/cpufreq/scaling_max_freq"
    echo "$original_max_freq" >"/sys/devices/system/cpu/cpu${index1}/cpufreq/scaling_max_freq"
    echo "$original_min_freq" >"/sys/devices/system/cpu/cpu${index0}/cpufreq/scaling_min_freq"
    echo "$original_min_freq" >"/sys/devices/system/cpu/cpu${index1}/cpufreq/scaling_min_freq"
    index0=$((index0 + 1))
    index1=$((index0 + interval))
  done
}

# enable or disable turbo according argument
if [[ "$turbo_on" == "yes" ]]; then
  echo 0 >"$CPU_NO_TURBO_NODE"
  if [[ $? -ne 0 ]]; then
    do_cmd "modprobe msr"
    turbo_value=$(rdmsr 0x1a0 -f 38:38)
    test_print_trc "turbo_value:$turbo_value"
    [[ $turbo_value -eq 0 ]] || die "Failed to write 0 to $CPU_NO_TURBO_NODE"
    test_print_trc "Turbo disabled by BIOS or unavailable on processor."
  fi
elif [[ "$turbo_on" == "no" ]]; then
  echo 1 >"$CPU_NO_TURBO_NODE"
  if [[ $? -ne 0 ]]; then
    do_cmd "modprobe msr"
    turbo_value=$(rdmsr 0x1a0 -f 38:38)
    test_print_trc "turbo_value:$turbo_value"
    [[ $turbo_value -eq 0 ]] || die "Failed to write 1 to $CPU_NO_TURBO_NODE"
    test_print_trc "Turbo disabled by BIOS or unavailable on processor."
  fi
else
  block_test "invalid value for cpu no_turbo node"
fi

# select which scaling governor mode to be set
if [[ "$mode" == "powersave" ]]; then
  set_scaling_governor "powersave"
elif [[ "$mode" == "performance" ]]; then
  set_scaling_governor "performance"
else
  block_test "invalid mode for scaling governor"
fi

if [[ "$core" == "all" ]]; then
  pstate_freq_step_max_test
elif [[ "$core" == "one" ]]; then
  pstate_freq_step_single_test
fi
