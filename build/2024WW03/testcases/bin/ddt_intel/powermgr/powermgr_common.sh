#!/bin/bash
###############################################################################
#
# Copyright (C) 2015 Intel - http://www.intel.com
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
# @Author   Zelin Deng <zelinx.deng@intel.com>
# @desc     common file of power management
# @returns  0 if the execution was finished successfully, else 1

source "common.sh"

CPU_SYSFS_PATH="/sys/devices/system/cpu"
CPU_BUS_SYSFS_PATH="/sys/bus/cpu/devices/"
POWER_SYSFS_PATH="/sys/power"
POWER_STATE_NODE="/sys/power/state"
POWER_DISK_NODE="/sys/power/disk"
POWER_PMTEST_NODE="/sys/power/pm_test"
POWER_IMGSIZE_NODE="/sys/power/image_size"
POWER_MEM_SLEEP_NODE="/sys/power/mem_sleep"
CPU_IDLE_SYSFS_PATH="/sys/devices/system/cpu/cpuidle"
CPU_POWER_SYSFS_PATH="/sys/devices/system/cpu/power"
CPU_NO_TURBO_NODE="/sys/devices/system/cpu/intel_pstate/no_turbo"
CPU_IDLE_NODE="current_driver current_governor_ro"
CPU_POWER_NODE="async autosuspend_delay_ms control runtime_active_kids
  runtime_active_time runtime_enabled runtime_status
  runtime_suspended_time runtime_usage"
CPU_PSTATE_SYSFS_PATH="/sys/devices/system/cpu/intel_pstate"
CPU_PSTATE_STATUS="/sys/devices/system/cpu/intel_pstate/status"
CPU_PSTATE_NODE="hwp_dynamic_boost max_perf_pct min_perf_pct no_turbo status"
CPU_CPUFREQ_NODE="affected_cpus cpuinfo_max_freq cpuinfo_min_freq
  cpuinfo_transition_latency related_cpus scaling_available_governors
  scaling_cur_freq scaling_driver scaling_governor scaling_max_freq
  scaling_min_freq scaling_setspeed"

SUPPORTED_POWER_STATE="freeze mem disk"
SUPPORTED_DISK_MODE="\[platform\] shutdown reboot suspend"

MEM_PROCFS_PATH="/proc/meminfo"
VM_PROCFS_PATH="/proc/sys/vm"
PCI_DEVICES_SYSFS_PATH="/sys/bus/pci/devices"
USB_DEVICES_SYSFS_PATH="/sys/bus/usb/devices"
AUDIO_POWER_SAVE_NODE="/sys/module/snd_hda_intel/parameters/power_save"

# Check cmdline, some options must be enabled.
CMDLINE=$(cat /proc/cmdline)
MSR_KOPTION="CONFIG_X86_MSR"
PMC_CORE_SYSFS_PATH="/sys/kernel/debug/pmc_core"
LTR_IGNORE_NODE="/sys/kernel/debug/pmc_core/ltr_ignor"
SLP_S0_RESIDENCY_USEC_NODE="/sys/kernel/debug/pmc_core/slp_s0_residency_usec"
TELEMETRY_SYSFS_PATH="/sys/kernel/debug/telemetry"
TELEMETRY_SOC_STATE_NODE="/sys/kernel/debug/telemetry/soc_states"

SATA_CONTROLLER_PARTTERN="SATA Controller"
VGA_CONTROLLER_PARTTERN="VGA compatible controller"
PSTATE_TOOL="$LTPROOT/testcases/bin/ddt_intel/powermgr"

SYSTEM_CLOCKSOURCE_AVAILABLE_NODE="/sys/devices/system/clocksource/clocksource0/available_clocksource"

S0IX_SUBSTATE_RESIDENCY="/sys/kernel/debug/pmc_core/substate_residencies"

PC10_REG_ADDR="0x632"
PKG_CST_CTL="0xe2"
MSR_PKG2="0x60d"
MSR_PKG6="0x3f9"
TOOL="$LTPROOT/testcases/bin"

# if CHK_CMDLINE_PATTERN has not be defined in parameter file,
# set default value
: "${CHK_CMDLINE_PATTERN:="log_buf_len=4M no_console_suspend
  ignore_loglevel resume="}"
CHK_CMDLINE_PATTERN=$(echo "$CHK_CMDLINE_PATTERN" | sed 's/^\"\|\"$//g')

for pattern in ${CHK_CMDLINE_PATTERN}; do
  if [ "$pattern" == "resume=" ]; then
    # S4 mode will store the current system into swap partition.
    # When system resume from S4 mode, kernel will restore the stored image
    # in swap partition. So make sure this pattern is in your cmdline.
    # partition name should be like this: /dev/sda1 /dev/mmcblk0p2
    is_pattern=$(echo "$CMDLINE" |
      grep -o "resume=/dev/[a-z0-9]\+" |
      cut -d'=' -f2)
    swap_partition=$(sed -n '2p' /proc/swaps | awk '{print $1}')
    if [ -n "$is_pattern" ] &&
      [ -n "$swap_partition" ] &&
      [ "$is_pattern" == "$swap_partition" ]; then
      continue
    else
      # Don't exist anymore. Just print prompt.
      test_print_trc "Your swap partition is $swap_partition, \
but the current setting is $is_pattern"
    fi
  else
    is_pattern=$(echo "$CMDLINE" | grep -o "$pattern")
    if [ -n "$is_pattern" ]; then
      continue
    else
      # Don't exist anymore. Just print prompt.
      test_print_trc "Recommended cmdline is:${CHK_CMDLINE[*]}, \
$pattern is not found in current cmdline:$CMDLINE"
    fi
  fi
done

power_limit_check() {
  pkg_power_limitation_log=$(rdmsr -p 1 0x1b1 -f 11:11 2>/dev/null)
  test_print_trc "The power limitation log from package thermal status 0x1b1 bit 11 is: \
$pkg_power_limitation_log"
  core_power_limitation_log=$(rdmsr -p 1 0x19c -f 11:11 2>/dev/null)
  test_print_trc "The power limitation log from IA32 thermal status 0x19c bit 11 is: \
$core_power_limitation_log"
  hwp_cap_value=$(rdmsr -a 0x771)
  test_print_trc "MSR HWP Capabilities shows: $hwp_cap_value"
  hwp_req_value=$(rdmsr -a 0x774)
  test_print_trc "MSR HWP Request shows: $hwp_req_value"

  core_perf_limit_reason=$(rdmsr -a 0x64f 2>/dev/null)
  test_print_trc "The core perf limit reasons msr 0x64f value is: $core_perf_limit_reason"
  if [ "$pkg_power_limitation_log" == "1" ] && [ "$core_power_limitation_log" == "1" ]; then
    return 0
  else
    return 1
  fi
}

set_scaling_governor() {
  local mode=$1

  cpus=$(ls "$CPU_BUS_SYSFS_PATH" | grep cpu -c)
  for i in $(seq 0 $((cpus - 1))); do
    do_cmd "echo $mode >/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor"
  done
}

#This function is used to set intel_pstate to passive mode
set_intel_pstate_mode() {
  local mode=$1

  do_cmd "echo passive > $CPU_PSTATE_SYSFS_PATH/status"
}

# This function is used to kill x86_cpuload process if it is still running.
# We do this to release cpu resource.
do_kill_pid() {
  [[ $# -ne 1 ]] && die "You must supply 1 parameter"
  local upid="$1"
  upid=$(ps -e | awk '{if($1~/'"$upid"'/) print $1}')
  [[ -n "$upid" ]] && do_cmd "kill -9 $upid"
}

checking_single_cpu_freq() {
  local cpus=0
  local x86_cpuload_pid=""
  local cpu_stat=""
  local max_freq=""
  local current_freq=""
  local delta=0
  local turbo_on=""

  turbo_on=$(cat "$CPU_NO_TURBO_NODE")

  # filter out cpu0
  cpus=$(seq 1 "$(cut -d'-' -f2 $CPU_SYSFS_PATH/present)")
  # Hot unplug all logic cpus except cpu0
  for cpu in $cpus; do
    test_print_trc "Hot unplug cpu$cpu"
    do_cmd "echo 0 > $CPU_SYSFS_PATH/cpu$cpu/online"
  done
  test_print_trc "Executing x86_cpuload -s 0 -c 1 -b 100 -t 90 & in background"
  "$PSTATE_TOOL/x86_cpuload" -s 0 -c 1 -b 100 -t 90 &
  x86_cpuload_pid=$!
  cpu_stat_debug=$("$PSTATE_TOOL/turbostat" -i 1 sleep 1 2>&1)
  test_print_trc "Turbostat debug output is:"
  test_print_trc "$cpu_stat_debug"
  cpu_stat=$("$PSTATE_TOOL/turbostat" -q -i 1 sleep 1 2>&1)
  test_print_trc "Turbostat output is:"
  test_print_trc "$cpu_stat"

  hybrid_sku=$(echo "$cpu_stat_debug" | grep "MSR_SECONDARY_TURBO_RATIO_LIMIT" 2>&1)
  if [[ "$turbo_on" -eq 0 ]]; then
    if [ -n "$hybrid_sku" ]; then
      max_freq=$(echo "$cpu_stat_debug" | grep -B 1 "MSR_SECONDARY_TURBO_RATIO_LIMIT" |
        head -1 | awk '{print $5}' 2>&1)
      test_print_trc "Max_freq_turbo_On: $max_freq"
    else
      max_freq=$(echo "$cpu_stat_debug" |
        grep "MHz max turbo" | tail -n 1 | awk '{print $5}')
      test_print_trc "Max_freq_turbo_On: $max_freq"
    fi
  else
    max_freq=$(echo "$cpu_stat_debug" |
      grep "base frequency" |
      awk '{print $5}')
    test_print_trc "Max_freq_turbo_off: $max_freq"
  fi

  current_freq=$(echo "$cpu_stat" |
    awk '{for(k=0;++k<=NF;)a[k]=a[k]?a[k] FS $k:$k} END{for(k=0;k++<NF;)print a[k]}' |
    grep "Bzy_MHz" | awk -F " " '{print $2}')
  do_cmd "do_kill_pid $x86_cpuload_pid"
  test_print_trc "current freq: $current_freq"
  test_print_trc "max freq: $max_freq"

  # Hot plug all logic cpus except cpu0
  for cpu in $cpus; do
    test_print_trc "Hot plug $cpu"
    do_cmd "echo 1 > $CPU_SYSFS_PATH/cpu$cpu/online"
  done

  [[ -n "$max_freq" ]] || {
    echo "$cpu_stat"
    die "Cannot get the max freq"
  }
  [[ -n "$current_freq" ]] || {
    echo "$cpu_stat"
    die "Cannot get current freq"
  }
  delta=$(awk -v x="$max_freq" -v y="$current_freq" \
    'BEGIN{printf "%.1f\n", x-y}')
  test_print_trc "Delta freq between max_fre and current_freq is:$delta MHz"

  if [[ $(echo "$delta > 100" | bc) -eq 1 ]]; then
    if power_limit_check; then
      test_print_trc "The package and core power limitation is asserted."
      test_print_trc "$current_freq is lower than $max_freq with power limitation assert"
    else
      test_print_trc "The package and core power limitation is NOT assert."
      die "$current_freq is lower than $max_freq without power limitation assert"
    fi
  else
    test_print_trc "checking single cpu freq: PASS"
  fi
}

checking_max_cores_freq() {
  local cpus=""
  local x86_cpuload_pid=""
  local cpu_stat=""
  local max_freq=""
  local current_freq=""
  local delta=0
  local turbo_on=""

  turbo_on=$(cat "$CPU_NO_TURBO_NODE")

  cpus=$(ls "$CPU_BUS_SYSFS_PATH" | grep cpu -c)
  "$PSTATE_TOOL/x86_cpuload" -s 0 -c "$cpus" -b 100 -t 90 &
  x86_cpuload_pid=$!
  cpu_stat_debug=$("$PSTATE_TOOL/turbostat" -i 1 sleep 1 2>&1)
  test_print_trc "Turbostat debug output is:"
  test_print_trc "$cpu_stat_debug"
  cpu_stat=$("$PSTATE_TOOL/turbostat" -q -i 1 sleep 1 2>&1)
  test_print_trc "Turbostat output is:"
  test_print_trc "$cpu_stat"

  hybrid_sku=$(echo "$cpu_stat_debug" | grep "MSR_SECONDARY_TURBO_RATIO_LIMIT" 2>&1)
  # The low power cpu on SoC die does not have the cache index3 directory
  # So use this cache index3 information to judge if SUT supports SoC die or not
  cache_index=$(grep . /sys/devices/system/cpu/cpu*/cache/index3/shared_cpu_list | sed -n '1p' |
    awk -F "-" '{print $NF}' 2>&1)
  cache_index=$(("$cache_index" + 1))
  test_print_trc "CPU number from cache index3: $cache_index"
  cpu_list=$("$TOOL"/cpuid | grep -c "core type" 2>&1)
  test_print_trc "CPU number from cpuid: $cpu_list"

  if [[ "$turbo_on" -eq 0 ]]; then
    # For SoC die not supported Hybrid SKU
    if [[ -n "$hybrid_sku" ]] && [[ "$cache_index" = "$cpu_list" ]]; then
      pcore_max_turbo=$(echo "$cpu_stat_debug" | grep -A 2 "MSR_TURBO_RATIO_LIMIT" |
        sed -n "2, 1p" | awk '{print $5}' 2>&1)
      test_print_trc "The Pcore max turbo freq is: $pcore_max_turbo MHz"
      ecore_max_turbo=$(echo "$cpu_stat_debug" | grep -A 2 "MSR_SECONDARY_TURBO_RATIO_LIMIT" |
        sed -n "2, 1p" | awk '{print $5}' 2>&1)
      test_print_trc "The Ecore max turbo freq is: $ecore_max_turbo MHz"
      pcore_last=$(cat /sys/devices/system/cpu/types/intel_core_*/cpulist | cut -d - -f 2)
      pcore_1st=$(cat /sys/devices/system/cpu/types/intel_core_*/cpulist | cut -d - -f 1)
      pcore_online=$(("$pcore_last" - "$pcore_1st" + 1))
      test_print_trc "Pcore Online CPUs:$pcore_online"
      ecore_last=$(cat /sys/devices/system/cpu/types/intel_atom_*/cpulist | cut -d - -f 2)
      ecore_1st=$(cat /sys/devices/system/cpu/types/intel_atom_*/cpulist | cut -d - -f 1)
      ecore_online=$(("$ecore_last" - "$ecore_1st" + 1))
      test_print_trc "Ecore online CPUs:$ecore_online"
      cpus_online=$(("$pcore_online" + "$ecore_online"))
      test_print_trc "Online CPUs:$cpus_online"
      max_freq=$(echo "scale=2; ($pcore_max_turbo * $pcore_online + $ecore_max_turbo * $ecore_online) / \
      $cpus_online" | bc)
      test_print_trc "The expected average CPU max freq on Hybrid SKU: $max_freq MHz"

      # For SoC die supported Hybrid SKU
    elif [[ -n "$hybrid_sku" ]] && [[ "$cache_index" != "$cpu_list" ]]; then
      test_print_trc "SUT supports SoC die"
      pcore_max_turbo=$(echo "$cpu_stat_debug" | grep -A 2 "MSR_TURBO_RATIO_LIMIT" |
        sed -n "2, 1p" | awk '{print $5}' 2>&1)
      test_print_trc "The Pcore max turbo freq is: $pcore_max_turbo MHz"
      ecore_max_turbo=$(echo "$cpu_stat_debug" | grep -A 2 "MSR_SECONDARY_TURBO_RATIO_LIMIT" |
        sed -n "2, 1p" | awk '{print $5}' 2>&1)
      test_print_trc "The Ecore max turbo freq is: $ecore_max_turbo MHz"
      lp_cpu=$(("$cpu_list" - 1))
      lp_max_turbo_hex=$(rdmsr -p $lp_cpu -f 15:8 0x771)
      lp_max_turbo_dec=$((16#$lp_max_turbo_hex))
      lp_max_turbo_mhz=$(("$lp_max_turbo_dec" * 100))
      test_print_trc "The low power core max turbo freq is $lp_max_turbo_mhz MHz"
      pcore_last=$(cat /sys/devices/system/cpu/types/intel_core_*/cpulist | cut -d - -f 2)
      pcore_1st=$(cat /sys/devices/system/cpu/types/intel_core_*/cpulist | cut -d - -f 1)
      pcore_online=$(("$pcore_last" - "$pcore_1st" + 1))
      test_print_trc "Pcore Online CPUs:$pcore_online"
      ecore_last=$(cat /sys/devices/system/cpu/types/intel_atom_*/cpulist | cut -d - -f 2)
      # Remove 2 low power cores from ecore number
      ecore_last=$(("$ecore_last" - 2))
      ecore_1st=$(cat /sys/devices/system/cpu/types/intel_atom_*/cpulist | cut -d - -f 1)
      ecore_online=$(("$ecore_last" - "$ecore_1st" + 1))
      test_print_trc "Ecore online CPUs:$ecore_online"
      test_print_trc "LP core online number: 2"
      cpus_online=$(("$pcore_online" + "$ecore_online" + 2))
      test_print_trc "Online CPUs:$cpus_online"
      max_freq=$(echo "scale=2; ($pcore_max_turbo * $pcore_online + $ecore_max_turbo * \
      $ecore_online + $lp_max_turbo_mhz * 2) / $cpus_online" | bc)
      test_print_trc "The expected average CPU max freq on Hybrid SKU: $max_freq MHz"

      # For non-Hybrid SKU
    else
      max_freq=$(echo "$cpu_stat_debug" |
        grep "MHz max turbo" | head -n 1 | awk '{print $5}')
      test_print_trc "Max_freq_turbo_On on non-Hybrid SKU: $max_freq MHz"
    fi
  else
    max_freq=$(echo "$cpu_stat_debug" |
      grep "base frequency" |
      awk '{print $5}')
    test_print_trc "Max_freq_turbo_off: $max_freq MHz"
  fi

  current_freq=$(echo "$cpu_stat" |
    awk '{for(k=0;++k<=NF;)a[k]=a[k]?a[k] FS $k:$k} END{for(k=0;k++<NF;)print a[k]}' |
    grep "Bzy_MHz" | awk -F " " '{print $2}')
  do_cmd "do_kill_pid $x86_cpuload_pid"
  test_print_trc "current freq: $current_freq MHz"
  test_print_trc "expected max freq: $max_freq MHz"

  [[ -n "$max_freq" ]] || {
    echo "$cpu_stat"
    die "Cannot get the max freq"
  }
  [[ -n "$current_freq" ]] || {
    echo "$cpu_stat"
    die "Cannot get current freq"
  }
  delta=$(awk -v x="$max_freq" -v y="$current_freq" \
    'BEGIN{printf "%.1f\n", x-y}')

  if [[ $(echo "$delta > 100" | bc) -eq 1 ]]; then
    if power_limit_check; then
      test_print_trc "The package and core power limitation is assert."
      test_print_trc "$current_freq is lower than $max_freq with power limitation assert"
    else
      test_print_trc "The package and core power limitation is NOT assert."
      die "$current_freq is lower than $max_freq without power limitation assert"
    fi
  else
    test_print_trc "No thermal limitation, checking all CPUs freq: PASS"
  fi
}

#Function to check the 1st Atom cpu freq with stress on Hybrid CPU
checking_hybrid_atom_single_cpu_freq() {
  local cpu_present=""
  local atom_cpu=""
  local turbo_on=""
  local cpu_stat=""
  local max_freq=""
  local actual_freq_temp=""
  local actual_freq=""
  local delta=""

  turbo_on=$(cat "$CPU_NO_TURBO_NODE")
  columns="Core,CPU,Avg_MHz,Busy%,Bzy_MHz,PkgWatt"
  #Get presented cpu number
  cpu_present=$(awk -F "-" '{print $2}' /sys/devices/system/cpu/present)

  #Get the 1st Hybrid ATOM cpu number
  atom_cpu=$("$TOOL"/cpuid | grep "core type" | grep -n "Intel Atom" | head -n 1 | awk -F ":" '{print $1}')
  #Get expected atom cpu max frequency when turbostat is on or off
  if [[ "$turbo_on" -eq 0 ]]; then
    max_freq=$(cat $CPU_SYSFS_PATH/cpu"$atom_cpu"/cpufreq/scaling_max_freq)
  else
    max_freq=$(cat $CPU_SYSFS_PATH/cpu"$atom_cpu"/cpufreq/base_frequency)
  fi

  #Offline all the other Hybrid Core and Atom CPUs except the 1st ATOM CPU
  for ((i = 0; i <= "$cpu_present"; i++)); do
    if [[ "$i" -ne "$atom_cpu" ]]; then
      test_print_trc "Offline CPU$i"
      do_cmd "echo 0 > $CPU_SYSFS_PATH/cpu$i/online"
    else
      test_print_trc "Keep the 1st ATOM CPU$i online"
    fi
  done

  #Add 100% workload for the online ATOM CPU
  test_print_trc "Executing stress -c $atom_cpu -t 90 & in background"
  stress -c "$atom_cpu" -t 90 &
  stress_pid=$!
  cpu_stat=$("$PSTATE_TOOL/turbostat" --show $columns -i 1 sleep 1 2>&1)
  test_print_trc "Turbostat output is:"
  echo -e "$cpu_stat"

  #Print the 1st ATOM CPU freq from turbostat log
  #The freq get from sysfs file is KhZ, while turbostat calculated freq is Mhz
  #So transfer the turbostat value from Mhz to Khz
  actual_freq_temp=$(echo "$cpu_stat" | grep -E "^-" | awk '{print $4}')
  actual_freq=$(echo "$actual_freq_temp*1000" | bc)
  test_print_trc "The 1st ATOM CPU actual freq during stress is:$actual_freq"
  test_print_trc "The expected ATOM CPU max freq during stress is:$max_freq"

  #Kill stress thread and recover atom online setting
  do_cmd "do_kill_pid $stress_pid"

  #Online all the cpus
  for ((i = 0; i <= "$cpu_present"; i++)); do
    do_cmd "echo 1 > $CPU_SYSFS_PATH/cpu$i/online"
  done

  delta=$(("$max_freq" - "$actual_freq"))
  test_print_trc "The delta cpu freq between sysfs expected and turbostat reported is: $delta"

  #If the delta freq is larger than 100 MHz(100000Khz), check if thermal limitation is achieved.
  #Otherwise, expect the delta value is within 100Mhz(100000Khz).
  if [[ $(echo "$delta > 100000" | bc) -eq 1 ]]; then
    if power_limit_check; then
      test_print_trc "The package and core power limitation is assert."
      test_print_trc "$actual_freq is lower than $max_freq with power limitation assert"
    else
      test_print_trc "The package and core power limitation is NOT assert."
      die "$actual_freq is lower than $max_freq without power limitation assert"
    fi
  else
    test_print_trc "No thermal limitation, the 1st ATOM CPU freq when stress on Hybrid SKU: PASS"
  fi
}
