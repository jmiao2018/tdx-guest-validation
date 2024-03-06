#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only

# Description:  Test script for TPMI PEM feature, which is supported beginning
# from Granite Rapids platform
# TPMI:Topology Aware Register and PM Capsule Interface
# PEM: Pnp Excursion Monitor

# Authors:      wendy.wang@intel.com
# History:      April 1 2022 - Created - Wendy Wang

source "common.sh"
source "dmesg_functions.sh"
source "powermgr_common.sh"

PEM_DRIVER_PATH="/sys/bus/auxiliary/drivers/intel_tpmi_pem"
PEM_SYSFS_PATH="/sys/devices/pnp_excursion_monitor"
PEM_ATTR="cpumask events format perf_event_mux_interval_ms type"
EVENTS_ATTR="any hot_vr peci_pstate pl1_msr_tpmi pl2_mmio pl2_peci
prochot psys_pl1_msr_tpmi psys_pl2_mmio psys_pl2_peci thermal
fast_rapl itbm_3 pl1_mmio pl1_peci pl2_msr_tpmi pmax psys_pl1_mmio
psys_pl1_peci psys_pl2_msr_tpmi sst_pp"
LOG_PATH="$LTPROOT/testcases/bin/ddt_intel/tpmi"
RAPL_TPMI_PATH="/sys/class/powercap/intel-rapl:"

: "${CASE_NAME:=""}"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

sysfs_verify() {
  [ $# -ne 2 ] && die "You must supply 2 parameters, ${0##*/} <TYPE> <PATH>"
  local TYPE="$1"
  local path="$2"
  #if TYPE is not d nor f, set it as e
  if [[ "$TYPE" != "d" ]] && [[ "$TYPE" != "f" ]]; then
    TYPE="e"
  fi
  test_print_trc "$path does exist"
  return 0
}

load_unload_module() {
  # $1 is the driver module name
  local module_name=$1
  is_kmodule_builtin "$module_name" && skip_test
  dmesg -C

  load_unload_module.sh -c -d "$module_name" &&
    do_cmd "load_unload_module.sh -u -d $module_name"

  do_cmd "load_unload_module.sh -l -d $module_name"
  do_cmd "load_unload_module.sh -u -d $module_name"
  do_cmd "load_unload_module.sh -l -d $module_name"
}

pem_unbind_bind() {
  test_print_trc "Doing intel_tpmi_pem unbind"
  do_cmd "echo intel_vsec.tpmi-pem.1 > $PEM_DRIVER_PATH/unbind"
  test_print_trc "Doing intel_tpmi_pem bind"
  do_cmd "echo intel_vsec.tpmi-pem.1 > $PEM_DRIVER_PATH/bind"
}

pem_instance_per_package() {
  test_print_trc "Check TPMI-PEM device instance:"

  [[ -d "$PEM_DRIVER_PATH" ]] ||
    die "TPMI-PEM driver SYSFS does not exist!"

  pem_instance=$(ls "$PEM_DRIVER_PATH" | grep -c intel_vsec.tpmi-pem 2>&1)
  test_print_trc "TPMI-PEM device instance number: $pem_instance"
  pkg_num=$(lscpu | grep Socket | awk -F ":" '{print $2}' 2>&1)
  test_print_trc "Package number: $pkg_num"

  if [ "$pem_instance" -eq "$pkg_num" ]; then
    test_print_trc "TPMI-PEM device instance number is aligned with Package number."
  else
    die "TPMI-PEM device instance number is not aligned with Package number."
  fi

  test_print_trc "Print TPMI-PEM driver interface and instance list:"
  lines=$(grep . "$PEM_DRIVER_PATH"/*/* 2>&1 |
    grep -v "Is a directory" | grep -v "Permission denied")
  for line in $lines; do
    test_print_trc "$line"
  done
}

pem_sysfs_attr() {
  local attr

  test_print_trc "Check TPMI_PEM driver sysfs attribute:"
  for attr in $PEM_ATTR; do
    sysfs_verify f "$PEM_SYSFS_PATH"/"$attr" ||
      die "$attr does not exist!"
  done

  if ! lines=$(ls "$PEM_SYSFS_PATH"); then
    die "intel_tpmi_pem driver sysfs does not exist!"
  else
    for line in $lines; do
      test_print_trc "$line"
    done
  fi
}

pem_events_attr() {
  local event

  test_print_trc "Check TPMI_PEM events sysfs attribute:"
  for event in $EVENTS_ATTR; do
    sysfs_verify f "$PEM_SYSFS_PATH"/events/"$event" ||
      die "$attr does not exist!"
  done

  if ! lines=$(ls "$PEM_SYSFS_PATH"/events); then
    die "intel_tpmi_pem events sysfs attr does not exist!"
  else
    for line in $lines; do
      test_print_trc "$line"
    done
  fi
}

pem_cpumask() {
  die_id=$(grep . "$CPU_SYSFS_PATH"/cpu*/topology/* | grep die_id | awk -F ":" '{print $2}' | uniq)
  test_print_trc "The CPU Topology shows die_id is: $die_id"

  cpumask_value=$(cat "$PEM_SYSFS_PATH"/cpumask)
  test_print_trc "The PEM sysfs shows cpumask value is: $cpumask_value"

  if [ "$cpumask_value" -eq "$die_id" ]; then
    test_print_trc "The PEM cpumask value is aligned with CPU Topology die_id."
  else
    die "The PEM cpumask value is not aligned with CPU Topology die_id."
  fi
}

#Use perf list to detect PEM events
perf_list_pem_event() {
  local pem_event
  local pem_event_num

  pem_event=$(perf list | grep pnp)
  test_print_trc "perf list for PEM events: $pem_event"
  pem_event_num=$(perf list | grep -c pnp)
  test_print_trc "perf list for PEM events: $pem_event_num"

  if [[ -n "$pem_event" ]] && [[ "$pem_event_num" -eq 21 ]]; then
    test_print_trc "pnp_excursion_monitor events are detected in perf list: $pem_event"
  else
    test_print_trc "Detected PEM events: $pem_event"
    test_print_trc "Detected PEM events number: $pem_event_num"
    die "pnp_excursion_monitor events detection fails by perf list command!"
  fi
}

#Collect system-wide all CPU PEM perf for event "any"
perf_stat_all_cpu_pem_event() {
  local counter
  local e_name=$1
  local max_cpu
  local duration=$2

  #Disable CPU turbo
  test_print_trc "Disable CPU Turbo"
  do_cmd "echo 1 > $CPU_SYSFS_PATH/intel_pstate/no_turbo"

  #Get online CPU to read the base_freq
  max_cpu=$(lscpu --online --extended | awk '{print $1}' | sed -n '$p')
  test_print_trc "The max cpu number is: $max_cpu"
  all_cpus_num=$(("$max_cpu" + 1))

  base_freq_khz=$(cat "$CPU_SYSFS_PATH"/cpu"$max_cpu"/cpufreq/base_frequency)
  base_freq_mhz=$(echo "$base_freq_khz/1000" | bc)
  [[ -n "$base_freq_mhz" ]] || block_test "Did not get test freq from turbostat tool."
  test_print_trc "The base freq of max cpu is: $base_freq_mhz"

  #Run CPU stress on all on-line CPUs
  do_cmd "stress -c $all_cpus_num -t 120 &"

  test_print_trc "perf stat -o $LOG_PATH/out.txt -a -e pnp_excursion_monitor/$e_name,frequency_threshold=$base_freq_mhz,duration=10/ sleep $duration"
  perf stat -o "$LOG_PATH"/out.txt -a -e pnp_excursion_monitor/"$e_name",frequency_threshold="$base_freq_mhz",duration=10/ sleep "$duration" &
  test_print_trc "Collect system-wide all CPU PEM perf for events for $e_name:"

  #Use wait command to have perf stat process finish and get perf outputs
  test_print_trc "Will wait for ~$duration seconds to get PEM telemetry counter return from perf tool:"
  wait

  #Recover CPU turbo default setting: enable
  test_print_trc "Enable CPU Turbo"
  do_cmd "echo 0 > $CPU_SYSFS_PATH/intel_pstate/no_turbo"

  if [[ -s "$LOG_PATH/out.txt" ]]; then
    do_cmd "cat $LOG_PATH/out.txt"
    counter=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
    test_print_trc "Telemetry counter value: $counter"
    #Remove the perf output to invoid another refer to it
    do_cmd "rm -f $LOG_PATH/out.txt"

    if [[ "$counter" -eq 0 ]]; then
      test_print_trc "There is not any event report for all CPU PEM perf for non-turbo."
    else
      die "There is PnP excursion event report when perf stat all CPU PEM perf for non-turbo: $counter"
    fi

  else
    die "Failed to get perf tool output"
  fi
}

#Collect system-wide all CPU PEM perf for events in a group
perf_stat_all_cpu_pem_event_group() {
  local counter
  local max_cpu
  local e_name1=$1
  local e_name2=$2
  local e_name3=$3
  local e_name4=$4
  local e_name5=$5
  local duration=$6

  #Disable CPU turbo
  test_print_trc "Disable CPU Turbo"
  do_cmd "echo 1 > $CPU_SYSFS_PATH/intel_pstate/no_turbo"

  #Get online CPU to read the base_freq
  max_cpu=$(lscpu --online --extended | awk '{print $1}' | sed -n '$p')
  test_print_trc "The max cpu number is: $max_cpu"
  all_cpus_num=$(("$max_cpu" + 1))

  base_freq_khz=$(cat "$CPU_SYSFS_PATH"/cpu"$max_cpu"/cpufreq/base_frequency)
  base_freq_mhz=$(echo "$base_freq_khz/1000" | bc)
  [[ -n "$base_freq_mhz" ]] || block_test "Did not get test freq from turbostat tool."
  test_print_trc "The base freq of max cpu is: $base_freq_mhz"

  #Run CPU stress on all on-line CPUs
  do_cmd "stress -c $all_cpus_num -t 120 &"

  test_print_trc "perf stat -o $LOG_PATH/out.txt -a \
    -e {pnp_excursion_monitor/$e_name1,frequency_threshold=$base_freq_mhz,duration=10/,pnp_excursion_monitor/$e_name2/,\
pnp_excursion_monitor/$e_name3/,pnp_excursion_monitor/$e_name4/,\
pnp_excursion_monitor/$e_name5/} sleep $duration"

  perf stat -o "$LOG_PATH"/out.txt -a \
    -e "{pnp_excursion_monitor/$e_name1,frequency_threshold=$base_freq_mhz,duration=10/,pnp_excursion_monitor/$e_name2/,\
pnp_excursion_monitor/$e_name3/,pnp_excursion_monitor/$e_name4/,\
pnp_excursion_monitor/$e_name5/}" sleep "$duration" &
  test_print_trc "Collect system-wide all CPU PEM perf for events for a group events:\
  $e_name1, $e_name2, $e_name3, $e_name4, $e_name5"

  #Use wait command to have perf stat process finish and get perf outputs
  test_print_trc "Will wait for ~$duration seconds to get PEM telemetry counter return from perf tool:"
  wait

  #Recover CPU turbo default setting: enable
  test_print_trc "Enable CPU Turbo"
  do_cmd "echo 0 > $CPU_SYSFS_PATH/intel_pstate/no_turbo"

  if [[ -s "$LOG_PATH/out.txt" ]]; then
    do_cmd "cat $LOG_PATH/out.txt"
    counter=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
    test_print_trc "Telemetry counter value: $counter"

    counter_lines=$(grep -c pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
    for ((i = 1; i <= counter_lines; i++)); do
      counter_value=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}' | sed -n "$i,1p")
      event=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $2}' | sed -n "$i,1p")

      if [[ "$counter_value" -eq 0 ]]; then
        test_print_trc "There is not any pnp excursion event count report for $event for all CPUs non-turbo."
      else
        die "There is PnP excursion event report for $event when perf stat all CPUs non-turbo: $counter_value"
      fi
    done

  else
    die "Failed to get perf tool output"
  fi
}

#Collect system-wide all CPU PEM perf for freq Pm
perf_stat_all_cpu_pem_event_pm() {
  local counter
  local e_name=$1
  local max_cpu
  local duration=$2

  #Get online CPUs to read the Pm based on turbostat tool debug message
  max_cpu=$(lscpu --online --extended | awk '{print $1}' | sed -n '$p')
  test_print_trc "The max cpu number is: $max_cpu"
  all_cpus_num=$(("$max_cpu" + 1))

  cpu_stat_debug=$("$PSTATE_TOOL/turbostat" -i 1 sleep 1 2>&1)
  max_freq=$(echo "$cpu_stat_debug" |
    grep "MHz max turbo" | head -n 1 | awk '{print $5}')
  max_freq_mhz=$(echo "$max_freq" | cut -d '.' -f1)
  [[ -n "$max_freq_mhz" ]] || block_test "Did not get test freq from turbostat tool."
  test_print_trc "Pm from turbostat: $max_freq_mhz"

  #Run CPU stress on all on-line CPUs
  do_cmd "stress -c $all_cpus_num -t 120 &"

  test_print_trc "perf stat -o $LOG_PATH/out.txt -a -e pnp_excursion_monitor/$e_name,frequency_threshold=$max_freq_mhz,duration=10/ sleep $duration"
  perf stat -o "$LOG_PATH"/out.txt -a -e pnp_excursion_monitor/"$e_name",frequency_threshold="$max_freq_mhz",duration=10/ sleep "$duration" &
  test_print_trc "Collect system-wide all CPU PEM perf for events for $e_name:"

  #Use wait command to have perf stat process finish and get perf outputs
  test_print_trc "Will wait for ~$duration seconds to get PEM telemetry counter return from perf tool:"
  wait

  if [[ -s "$LOG_PATH/out.txt" ]]; then
    do_cmd "cat $LOG_PATH/out.txt"
    counter=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
    test_print_trc "Telemetry counter value: $counter"
    #Remove the perf output to invoid another refer to it
    do_cmd "rm -f $LOG_PATH/out.txt"

    if [[ "$counter" -eq 0 ]]; then
      test_print_trc "There is not any event report for all CPU PEM perf for freq Pm."
    else
      die "There is PnP excursion event report when perf stat all CPU PEM perf for freq Pm: $counter"
    fi

  else
    die "Failed to get perf tool output"
  fi
}

#Collect system-wide all CPU PEM perf for freq Pm in a group events
perf_stat_all_cpu_pem_event_pm_group() {
  local counter
  local max_cpu
  local e_name1=$1
  local e_name2=$2
  local e_name3=$3
  local e_name4=$4
  local e_name5=$5
  local duration=$6

  #Get online CPUs to read the Pm based on turbostat tool debug message
  max_cpu=$(lscpu --online --extended | awk '{print $1}' | sed -n '$p')
  test_print_trc "The max cpu number is: $max_cpu"
  all_cpus_num=$(("$max_cpu" + 1))

  cpu_stat_debug=$("$PSTATE_TOOL/turbostat" -i 1 sleep 1 2>&1)
  max_freq=$(echo "$cpu_stat_debug" |
    grep "MHz max turbo" | head -n 1 | awk '{print $5}')
  max_freq_mhz=$(echo "$max_freq" | cut -d '.' -f1)
  [[ -n "$max_freq_mhz" ]] || block_test "Did not get test freq from turbostat tool."
  test_print_trc "Pm from turbostat: $max_freq_mhz"

  #Run CPU stress on all on-line CPUs
  do_cmd "stress -c $all_cpus_num -t 120 &"

  test_print_trc "perf stat -o $LOG_PATH/out.txt -a \
    -e {pnp_excursion_monitor/$e_name1,frequency_threshold=$max_freq_mhz,duration=10/,pnp_excursion_monitor/$e_name2/,\
pnp_excursion_monitor/$e_name3/,pnp_excursion_monitor/$e_name4/,\
pnp_excursion_monitor/$e_name5/} sleep $duration"

  perf stat -o "$LOG_PATH"/out.txt -a \
    -e "{pnp_excursion_monitor/$e_name1,frequency_threshold=$max_freq_mhz,duration=10/,pnp_excursion_monitor/$e_name2/,\
pnp_excursion_monitor/$e_name3/,pnp_excursion_monitor/$e_name4/,\
pnp_excursion_monitor/$e_name5/}" sleep "$duration" &
  test_print_trc "Collect system-wide all CPU PEM perf for freq Pm for a group events:\
  $e_name1, $e_name2, $e_name3, $e_name4, $e_name5"

  #Use wait command to have perf stat process finish and get perf outputs
  test_print_trc "Will wait for ~$duration seconds to get PEM telemetry counter return from perf tool:"
  wait

  if [[ -s "$LOG_PATH/out.txt" ]]; then
    do_cmd "cat $LOG_PATH/out.txt"
    counter=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
    test_print_trc "Telemetry counter value: $counter"

    counter_lines=$(grep -c pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
    for ((i = 1; i <= counter_lines; i++)); do
      counter_value=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}' | sed -n "$i,1p")
      event=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $2}' | sed -n "$i,1p")

      if [[ "$counter_value" -eq 0 ]]; then
        test_print_trc "There is not any pnp excursion event count report for $event for all CPUs for Pm."
      else
        die "There is PnP excursion event report for $event when perf stat all CPUs for Pm: $counter_value"
      fi
    done

  else
    die "Failed to get perf tool output"
  fi
}

#Collect CPU1 in system-wide all CPU PEM perf for event "any" for base_frequency
perf_stat_single_cpu_pem_event_any() {
  local id=$1
  local counter
  local duration=$2

  #Disable CPU turbo
  test_print_trc "Disable CPU Turbo"
  do_cmd "echo 1 > $CPU_SYSFS_PATH/intel_pstate/no_turbo"

  #Get CPU$1 base_freq
  base_freq_khz=$(cat "$CPU_SYSFS_PATH"/cpu"$id"/cpufreq/base_frequency)
  base_freq_mhz=$(echo "$base_freq_khz/1000" | bc)
  test_print_trc "The base freq of max cpu is: $base_freq_mhz"
  [[ -n "$base_freq_mhz" ]] || block_test "Did not get test freq from turbostat tool."

  #Run CPU stress on single CPU
  do_cmd "taskset -c $id stress -c 1 -t 120 &"

  test_print_trc "perf stat -o $LOG_PATH/out.txt -C $id -e pnp_excursion_monitor/any,frequency_threshold=$base_freq_mhz,duration=10/ sleep $duration"
  perf stat -o "$LOG_PATH"/out.txt -C "$id" -e pnp_excursion_monitor/any,frequency_threshold="$base_freq_mhz",duration=10/ sleep "$duration" &
  test_print_trc "Collect CPU1 in system-wide all CPU PEM perf for events for any by sleep $duration seconds:"

  #Use wait command to have perf stat process finish and get perf outputs
  test_print_trc "Will wait for ~$duration seconds to get PEM telemetry counter return from perf tool:"
  wait

  #Recover CPU turbo default setting: enable
  test_print_trc "Enable CPU Turbo"
  do_cmd "echo 0 > $CPU_SYSFS_PATH/intel_pstate/no_turbo"

  if [[ -s "$LOG_PATH/out.txt" ]]; then
    do_cmd "cat $LOG_PATH/out.txt"
    counter=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
    test_print_trc "Telemetry counter value: $counter"
    #Remove the perf output to invoid another refer to it
    do_cmd "rm -f $LOG_PATH/out.txt "

    if [[ "$counter" -eq 0 ]]; then
      test_print_trc "There is not any event report for single CPU for base_freq."
    else
      die "There is PnP excursion event report when perf stat single CPU for base_freq: $counter"
    fi

  else
    die "Failed to get perf tool output"
  fi
}

#Collect CPU1 in system-wide all CPU PEM perf for event "any" for P01 (one core turbo freq)
perf_stat_single_cpu_pem_event_any_p01() {
  local id=$1
  local counter
  local duration=$2

  #Get single CPU$1 scaling_max_freq (P01)
  P0_khz=$(cat "$CPU_SYSFS_PATH"/cpu"$id"/cpufreq/scaling_max_freq)
  P0_mhz=$(echo "$P0_khz/1000" | bc)
  [[ -n "$P0_mhz" ]] || block_test "Did not get test freq from turbostat tool."
  test_print_trc "The base freq of max cpu is: $P0_mhz"

  #Run CPU stress on single CPU
  do_cmd "taskset -c $id stress -c 1 -t 120 &"

  test_print_trc "perf stat -o $LOG_PATH/out.txt -C $id -e pnp_excursion_monitor/any,frequency_threshold=$P0_mhz,duration=10/ sleep $duration"
  perf stat -o "$LOG_PATH"/out.txt -C "$id" -e pnp_excursion_monitor/any,frequency_threshold="$P0_mhz",duration=10/ sleep "$duration" &
  test_print_trc "Collect CPU1 in system-wide all CPU PEM perf for events for any by sleep $duration seconds:"

  #Use wait command to have perf stat process finish and get perf outputs
  test_print_trc "Will wait for ~$duration seconds to get PEM telemetry counter return from perf tool:"
  wait

  if [[ -s "$LOG_PATH/out.txt" ]]; then
    do_cmd "cat $LOG_PATH/out.txt"
    counter=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
    test_print_trc "Telemetry counter value: $counter"
    #Remove the perf output to invoid another refer to it
    do_cmd "rm -f $LOG_PATH/out.txt "

    if [[ "$counter" -eq 0 ]]; then
      test_print_trc "There is not any event report for single CPU for P01 turbo freq."
    else
      die "There is PnP excursion event report when perf stat single CPU for P01 turbo freq: $counter"
    fi

  else
    die "Failed to get perf tool output"
  fi
}

perf_stat_raw_event() {
  local num=$1
  local counter
  local max_cpu
  local duration=$2

  #Disable CPU turbo
  test_print_trc "Disable CPU Turbo"
  do_cmd "echo 1 > $CPU_SYSFS_PATH/intel_pstate/no_turbo"

  #Get online CPUs to read the base_freq
  max_cpu=$(lscpu --online --extended | awk '{print $1}' | sed -n '$p')
  test_print_trc "The max cpu number is: $max_cpu"
  all_cpus_num=$(("$max_cpu" + 1))

  base_freq_khz=$(cat "$CPU_SYSFS_PATH"/cpu"$max_cpu"/cpufreq/base_frequency)
  base_freq_mhz=$(echo "$base_freq_khz/1000" | bc)
  [[ -n "$base_freq_mhz" ]] || block_test "Did not get test freq from turbostat tool."
  test_print_trc "The base freq of max cpu is: $base_freq_mhz"

  #Run CPU stress on all on-line CPUs
  do_cmd "stress -c $all_cpus_num -t 120 &"

  test_print_trc "perf stat -o $LOG_PATH/out.txt -e pnp_excursion_monitor/event=$num,frequency_threshold=$base_freq_mhz,duration=10/ sleep $duration"
  perf stat -o "$LOG_PATH"/out.txt -e pnp_excursion_monitor/event="$num",frequency_threshold="$base_freq_mhz",duration=10/ sleep "$duration" &
  test_print_trc "Collect system-wide all CPU PEM perf for events $num:"

  #Use wait command to have perf stat process finish and get perf outputs
  test_print_trc "Will wait for ~$duration seconds to get PEM telemetry counter return from perf tool:"
  wait

  #Recover CPU turbo default setting: enable
  test_print_trc "Enable CPU Turbo"
  do_cmd "echo 0 > $CPU_SYSFS_PATH/intel_pstate/no_turbo"

  if [[ -s "$LOG_PATH/out.txt" ]]; then
    do_cmd "cat $LOG_PATH/out.txt"
    counter=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
    test_print_trc "Telemetry counter value: $counter"
    #Remove the perf output to invoid another refer to it
    do_cmd "rm -f $LOG_PATH/out.txt "

    if [[ "$counter" -eq 0 ]]; then
      test_print_trc "There is not any event $num report for all the CPUs perf state."
    else
      die "There is PnP excursion event $num report when perf stat all CPUs: $counter"
    fi
  else
    die "Failed to get perf tool output"
  fi
}

rapl_pl_change() {
  local pl=$1
  local e_name=$2
  local duration=$3

  #Get the sockets or packages number
  pkg_num=$(lscpu | grep "Socket(s)" | awk -F " " '{print $2}' 2>&1)
  test_print_trc "Check how many sockets the system supports: $pkg_num"

  #Save original RAPL Power limit value, assume each package has the same PL1 and PL2 value
  pl_ori=$(cat "${RAPL_TPMI_PATH}""$pkg_num"/constraint_"$pl"_power_limit_uw)
  test_print_trc "pl_ori value: $pl_ori"

  #Get online CPU to read the base_freq
  max_cpu=$(lscpu --online --extended | awk '{print $1}' | sed -n '$p')
  test_print_trc "The max cpu number is: $max_cpu"
  all_cpus_num=$(("$max_cpu" + 1))

  base_freq_khz=$(cat "$CPU_SYSFS_PATH"/cpu"$max_cpu"/cpufreq/base_frequency)
  base_freq_mhz=$(echo "$base_freq_khz/1000" | bc)
  [[ -n "$base_freq_mhz" ]] || block_test "Did not get test freq from turbostat tool."
  test_print_trc "The base freq of max cpu is: $base_freq_mhz"

  #Run CPU stress on all on-line CPUs
  do_cmd "stress -c $all_cpus_num -t 120 &"

  #Start perf tool monitor before RAPL Power limit change
  test_print_trc "perf stat -o $LOG_PATH/out.txt -a -e pnp_excursion_monitor/$e_name,frequency_threshold=$base_freq_mhz,duration=10/ sleep $duration"
  perf stat -o "$LOG_PATH"/out.txt -a -e pnp_excursion_monitor/"$e_name",frequency_threshold="$base_freq_mhz",duration=10/ sleep "$duration" &
  test_print_trc "Collect system-wide all CPU PEM perf for events for $e_name:"

  #Let stress running for 10 seconds then change the RAPL Power Limit to trigger pnp excursion
  sleep 10

  #Change RAPL Power Limit
  for ((i = 0; i < "$pkg_num"; i++)); do
    test_print_trc "Set RAPL power limit $pl to 20 percentage of original value"
    pl_change=$((20 * "$pl_ori" / 100))
    do_cmd "echo $pl_change > ${RAPL_TPMI_PATH}$i/constraint_${pl}_power_limit_uw"
  done

  #Use wait command to have perf stat process finish and get perf outputs
  test_print_trc "Will wait for ~$duration seconds to get PEM telemetry counter return from perf tool:"
  wait

  #Recover RAPL Power Limit setting
  for ((i = 0; i < "$pkg_num"; i++)); do
    do_cmd "echo $pl_ori > ${RAPL_TPMI_PATH}$i/constraint_${pl}_power_limit_uw"
  done

  if [[ -s "$LOG_PATH/out.txt" ]]; then
    do_cmd "cat $LOG_PATH/out.txt"
    counter=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
    test_print_trc "Telemetry counter value: $counter"
    #Remove the perf output to invoid another refer to it
    do_cmd "rm -f $LOG_PATH/out.txt "

    if [[ "$counter" -eq 0 ]]; then
      dmesg | grep "pem_*" | grep -v LTP
      die "Did not get PnP excursion event counter: $counter after RAPL Power limit change."
    elif [[ "$(echo "scale=2; $counter/$duration > 80.00" | bc)" -eq 1 ]]; then
      test_print_trc "The PnP excursion ratio is larger than 80% during past $duration seconds \
when perf stat all CPUs after RAPL Power Limit change to 20% of original value: $counter"
    else
      die "The counter is: $counter, the excursion ratio is less than 80% in past $duration seconds"
    fi
  else
    die "Failed to get perf tool output"
  fi
}

rapl_pl_change_group_event() {
  local pl=$1
  local e_name1=$2
  local e_name2=$3
  local e_name3=$4
  local duration=$5

  #Get the sockets or packages number
  pkg_num=$(lscpu | grep "Socket(s)" | awk -F " " '{print $2}' 2>&1)
  test_print_trc "Check how many sockets the system supports: $pkg_num"

  #Save original RAPL Power limit value, assume each package has the same PL1 and PL2 value
  pl_ori=$(cat "${RAPL_TPMI_PATH}""$pkg_num"/constraint_"$pl"_power_limit_uw)

  #Get online CPU to read the base_freq
  max_cpu=$(lscpu --online --extended | awk '{print $1}' | sed -n '$p')
  test_print_trc "The max cpu number is: $max_cpu"
  all_cpus_num=$(("$max_cpu" + 1))

  base_freq_khz=$(cat "$CPU_SYSFS_PATH"/cpu"$max_cpu"/cpufreq/base_frequency)
  base_freq_mhz=$(echo "$base_freq_khz/1000" | bc)
  [[ -n "$base_freq_mhz" ]] || block_test "Did not get test freq from turbostat tool."
  test_print_trc "The base freq of max cpu is: $base_freq_mhz"

  #Run CPU stress on all on-line CPUs
  do_cmd "stress -c $all_cpus_num -t 120 &"

  #Start perf tool monitor before RAPL Power limit change
  test_print_trc "perf stat -o $LOG_PATH/out.txt -a \
    -e {pnp_excursion_monitor/$e_name1,frequency_threshold=$base_freq_mhz,duration=10/,pnp_excursion_monitor/$e_name2/,pnp_excursion_monitor/$e_name3/} sleep $duration"

  perf stat -o "$LOG_PATH"/out.txt -a \
    -e "{pnp_excursion_monitor/$e_name1,frequency_threshold=$base_freq_mhz,duration=10/,pnp_excursion_monitor/$e_name2/,pnp_excursion_monitor/$e_name3/}" sleep "$duration" &
  test_print_trc "Collect system-wide all CPU PEM perf for freq Pm for a group events:\
  $e_name1, $e_name2, $e_name3"

  #Let stress running for 10 seconds then change the RAPL Power Limit to trigger pnp excursion
  sleep 10

  #Change RAPL Power Limit
  for ((i = 0; i < "$pkg_num"; i++)); do
    test_print_trc "Set RAPL power limit $pl to 20 percentage of original value"
    pl_change=$((20 * "$pl_ori" / 100))
    do_cmd "echo $pl_change > ${RAPL_TPMI_PATH}$i/constraint_${pl}_power_limit_uw"
  done

  #Use wait command to have perf stat process finish and get perf outputs
  test_print_trc "Will wait for ~$duration seconds to get PEM telemetry counter return from perf tool:"
  wait

  #Recover RAPL Power Limit setting
  for ((i = 0; i < "$pkg_num"; i++)); do
    do_cmd "echo $pl_ori > ${RAPL_TPMI_PATH}$i/constraint_${pl}_power_limit_uw"
  done

  if [[ -s "$LOG_PATH/out.txt" ]]; then
    do_cmd "cat $LOG_PATH/out.txt"
    counter=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
    test_print_trc "Telemetry counter value: $counter"

    if [[ -z "$counter" ]]; then
      dmesg | grep "pem_*" | grep -v LTP
      do_cmd "cat /sys/kernel/debug/tpmi-0000:00:03.1/tpmi-id-01/mem_dump"
      block_test "Did not get PnP excursion event counter: $counter"
    else
      counter_lines=$(grep -c pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
      for ((i = 1; i <= counter_lines; i++)); do
        counter_value=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}' | sed -n "$i,1p")
        test_print_trc "counter_value for line $i: $counter_value"
        event=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $2}' | sed -n "$i,1p")
        if [[ "$counter_value" -gt 0 ]] &&
          [[ "$(echo "scale=2; $counter_value/$duration < 80.00" | bc)" -eq 1 ]]; then
          test_print_trc "The PnP excursion ratio for $event is acceptable \
during past $duration seconds when perf stat all CPUs for RAPL Power limit change: $counter_value"
        elif [[ "$counter_value" -eq 0 ]]; then
          dmesg | grep "pem_*" | grep -v LTP
          die "The telemetry counter is: $counter, did not get expected telemetry counter updates."
        else
          die "The telemetry counter is: $counter, the excursion ratio of $event \
is more than 80% in past $duration seconds when perf stat all CPUs for RAPL Power Limit change"
        fi
      done
    fi
  else
    die "Failed to get perf tool output"
  fi
}

rapl_pl_change_multi_group_event() {
  local pl1=$1
  local pl2=$2
  local e_name1=$3
  local e_name2=$4
  local e_name3=$5
  local e_name4=$6
  local e_name5=$7
  local duration=$8

  #Get the sockets or packages number
  pkg_num=$(lscpu | grep "Socket(s)" | awk -F " " '{print $2}' 2>&1)
  test_print_trc "Check how many sockets the system supports: $pkg_num"

  #Save original RAPL Power limit value
  pl1_ori=$(cat "${RAPL_TPMI_PATH}""$pkg_num"/constraint_"$pl1"_power_limit_uw)
  pl2_ori=$(cat "${RAPL_TPMI_PATH}""$pkg_num"/constraint_"$pl2"_power_limit_uw)

  #Get online CPU to read the base_freq
  max_cpu=$(lscpu --online --extended | awk '{print $1}' | sed -n '$p')
  test_print_trc "The max cpu number is: $max_cpu"
  all_cpus_num=$(("$max_cpu" + 1))

  base_freq_khz=$(cat "$CPU_SYSFS_PATH"/cpu"$max_cpu"/cpufreq/base_frequency)
  base_freq_mhz=$(echo "$base_freq_khz/1000" | bc)
  [[ -n "$base_freq_mhz" ]] || block_test "Did not get test freq from turbostat tool."
  test_print_trc "The base freq of max cpu is: $base_freq_mhz"

  #Run CPU stress on all on-line CPUs
  do_cmd "stress -c $all_cpus_num -t 120 &"

  #Start perf tool monitor before RAPL Power limit change
  test_print_trc "perf stat -o $LOG_PATH/out.txt -a \
    -e {pnp_excursion_monitor/$e_name1,frequency_threshold=$base_freq_mhz,duration=10/,pnp_excursion_monitor/$e_name2/,\
pnp_excursion_monitor/$e_name3/} \
    -e {pnp_excursion_monitor/$e_name4,frequency_threshold=$base_freq_mhz,duration=10/,pnp_excursion_monitor/$e_name5/} sleep $duration "

  perf stat -o "$LOG_PATH"/out.txt -a \
    -e "{pnp_excursion_monitor/$e_name1,frequency_threshold=$base_freq_mhz,duration=10/,pnp_excursion_monitor/$e_name2/,\
pnp_excursion_monitor/$e_name3/}" \
    -e "{pnp_excursion_monitor/$e_name4,frequency_threshold=$base_freq_mhz,duration=10/,pnp_excursion_monitor/$e_name5/}" sleep "$duration" &
  test_print_trc "Collect system-wide all CPU PEM perf for freq Pm for a group events:\
  $e_name1, $e_name2, $e_name3,$e_name4, $e_name5"

  #Let stress running for 10 seconds then change the RAPL Power Limit to trigger pnp excursion
  sleep 10

  #Change RAPL Power Limit to 20% of original value
  for ((i = 0; i < "$pkg_num"; i++)); do
    test_print_trc "Set RAPL power limit $pl1, $pl2 to 20 percentage of original value"
    pl1_change=$((20 * "$pl1_ori" / 100))
    pl2_change=$((20 * "$pl2_ori" / 100))

    do_cmd "echo $pl1_change > ${RAPL_TPMI_PATH}$i/constraint_${pl1}_power_limit_uw"
    do_cmd "echo $pl2_change > ${RAPL_TPMI_PATH}$i/constraint_${pl2}_power_limit_uw"
  done

  #Use wait command to have perf stat process finish and get perf outputs
  test_print_trc "Will wait for ~$duration seconds to get PEM telemetry counter return from perf tool:"
  wait

  #Recover RAPL Power Limit setting
  for ((i = 0; i < "$pkg_num"; i++)); do
    do_cmd "echo $pl1_ori > ${RAPL_TPMI_PATH}$i/constraint_${pl1}_power_limit_uw"
    do_cmd "echo $pl2_ori > ${RAPL_TPMI_PATH}$i/constraint_${pl2}_power_limit_uw"
  done

  if [[ -s "$LOG_PATH/out.txt" ]]; then
    do_cmd "cat $LOG_PATH/out.txt"
    counter=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
    test_print_trc "Telemetry counter value: $counter"

    if [[ -z "$counter" ]]; then
      dmesg | grep "pem_*" | grep -v LTP
      do_cmd "cat /sys/kernel/debug/tpmi-0000:00:03.1/tpmi-id-01/mem_dump"
      block_test "Did not get PnP excursion event counter: $counter"
    else
      counter_lines=$(grep -c pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}')
      for ((i = 1; i <= counter_lines; i++)); do
        counter_value=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}' | sed -n "$i,1p")
        test_print_trc "counter_value for line $i: $counter_value"
        event=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $2}' | sed -n "$i,1p")
        if [[ "$counter_value" -gt 0 ]] &&
          [[ "$(echo "scale=2; $counter_value/$duration < 80.00" | bc)" -eq 1 ]]; then
          test_print_trc "The PnP excursion ratio for $event is acceptable \
during past $duration seconds when perf stat all CPUs for RAPL Power limit change: $counter_value"
        elif [[ "$counter_value" -eq 0 ]]; then
          dmesg | grep "pem_*" | grep -v LTP
          die "The telemetry counter is: $counter, did not get expected telemetry counter updates."
        else
          die "The telemetry counter is: $counter, the excursion ratio of $event \
is more than 80% in past $duration seconds when perf stat all CPUs for RAPL Power Limit change"
        fi
      done
    fi
  else
    die "Failed to get perf tool output"
  fi
}

sst_pp_change() {
  local level_id=$1
  local duration=$2

  #Get the sockets or packages number
  pkg_num=$(lscpu | grep "Socket(s)" | awk -F " " '{print $2}' 2>&1)
  test_print_trc "Check how many sockets the system supports: $pkg_num"

  #Get original sst perf profile level, assume each package has the same sst-pp value
  do_cmd "intel-speed-select -o pp.out perf-profile get-config-current-level"
  test_print_trc "The system perf profile config current level info:"
  do_cmd "cat pp.out"

  cur_level=$(grep get-config-current_level pp.out | awk -F ":" '{print $2}')
  cur_level_num=$(grep get-config-current_level pp.out | awk -F ":" '{print $2}' | wc -l)

  #Get online CPU to read the base_freq
  max_cpu=$(lscpu --online --extended | awk '{print $1}' | sed -n '$p')
  test_print_trc "The max cpu number is: $max_cpu"
  all_cpus_num=$(("$max_cpu" + 1))

  base_freq_khz=$(cat "$CPU_SYSFS_PATH"/cpu"$max_cpu"/cpufreq/base_frequency)
  base_freq_mhz=$(echo "$base_freq_khz/1000" | bc)
  test_print_trc "The base freq of max cpu is: $base_freq_mhz"

  #Run CPU stress on all on-line CPUs
  do_cmd "stress -c $all_cpus_num -t 120 &"

  #Start perf tool monitor before ISST perf profile level change
  [[ -n "$base_freq_mhz" ]] || block_test "Did not get test freq from turbostat tool."
  test_print_trc " perf stat -o $LOG_PATH/out.txt -a -e pnp_excursion_monitor/sst_pp,frequency_threshold=$base_freq_mhz,duration=10/ sleep $duration"
  perf stat -o "$LOG_PATH"/out.txt -a -e pnp_excursion_monitor/sst_pp,frequency_threshold="$base_freq_mhz",duration=10/ sleep "$duration" &
  test_print_trc "Collect system-wide all CPU PEM perf for sst_pp event:"

  #Let stress running for 10 seconds then change ISST perf profile level to trigger pnp excursion
  sleep 10

  #Change sst perf profile level
  test_print_trc "Will change the config level from $cur_level to $level_id:"
  do_cmd "intel-speed-select -o pp.out perf-profile set-config-level -l $level_id"
  test_print_trc "The system perf profile config level change log:"
  do_cmd "cat pp.out"

  set_tdp_level_status=$(grep set_tdp_level pp.out | awk -F ":" '{print $2}')
  set_tdp_level_status_num=$(grep set_tdp_level pp.out | awk -F ":" '{print $2}' | wc -l)

  for ((i = 1; i <= set_tdp_level_status_num; i++)); do
    j=$(("$i" - 1))
    set_tdp_level_status_by_num=$(echo "$set_tdp_level_status" | sed -n "$i, 1p")
    if [ "$set_tdp_level_status_by_num" = success ]; then
      test_print_trc "The system package $j set tdp level status is $set_tdp_level_status_by_num"
      test_print_trc "The system package $j set tdp level success."
    else
      test_print_trc "The system package $j set tdp level status is $set_tdp_level_status_by_num"
      die "The system package $j set tdp level fails"
    fi
  done

  test_print_trc "Confirm the changed config current level:"
  do_cmd "intel-speed-select -o pp.out perf-profile get-config-current-level"
  test_print_trc "The system perf profile config current level info:"
  do_cmd "cat pp.out"

  cur_level=$(grep get-config-current_level pp.out | awk -F ":" '{print $2}')
  cur_level_num=$(grep get-config-current_level pp.out | awk -F ":" '{print $2}' | wc -l)

  for ((i = 1; i <= cur_level_num; i++)); do
    j=$(("$i" - 1))
    cur_level_by_num=$(echo "$cur_level" | sed -n "$i, 1p")
    if [ "$cur_level_by_num" -eq "$level_id" ]; then
      test_print_trc "The system package $j config current level: $cur_level_by_num"
      test_print_trc "The system package $j config current level is $level_id after successfully setting"
    else
      test_print_trc "The system package $j config current level: $cur_level_by_num"
      die "The system package $j set tdp level fails"
    fi
  done

  #Use wait command to have perf stat process finish and get perf outputs
  test_print_trc "Will wait for ~$duration seconds to get PEM telemetry counter return from perf tool:"
  wait

  #Recover SST perf profile default setting
  test_print_trc "Recover the config level to the default setting: 0"
  do_cmd "intel-speed-select -o pp.out perf-profile set-config-level -l 0"

  #Expect there is pnp excursion occurs for the base_freq drop due to SST perf profile level change from 0 to others
  if ! counter=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}'); then
    do_cmd "cat /sys/kernel/debug/tpmi-0000:00:03.1/tpmi-id-01/mem_dump"
    block_test "Did not get PnP excursion event counter: $counter"
  elif [[ "$(echo "scale=2; $counter/$duration > 80.00" | bc)" -eq 1 ]]; then
    test_print_trc "The PnP excursion ratio is $counter, which is larger than 80% during past $duration seconds \
when perf stat all CPUs after SST Perf profile level change to $level_id"
  else
    die "The counter is: $counter, the excursion ratio is less than 80% in past $duration seconds"
  fi
}

sst_pp_change_group_event() {
  local level_id=$1
  local e_name1=$2
  local e_name2=$3
  local e_name3=$4
  local e_name4=$5
  local duration=$6

  #Get the sockets or packages number
  pkg_num=$(lscpu | grep "Socket(s)" | awk -F " " '{print $2}' 2>&1)
  test_print_trc "Check how many sockets the system supports: $pkg_num"

  #Get original sst perf profile level, assume each package has the same sst-pp value
  do_cmd "intel-speed-select -o pp.out perf-profile get-config-current-level"
  test_print_trc "The system perf profile config current level info:"
  do_cmd "cat pp.out"

  cur_level=$(grep get-config-current_level pp.out | awk -F ":" '{print $2}')
  cur_level_num=$(grep get-config-current_level pp.out | awk -F ":" '{print $2}' | wc -l)

  #Get online CPU to read the base_freq
  max_cpu=$(lscpu --online --extended | awk '{print $1}' | sed -n '$p')
  test_print_trc "The max cpu number is: $max_cpu"
  all_cpus_num=$(("$max_cpu" + 1))

  base_freq_khz=$(cat "$CPU_SYSFS_PATH"/cpu"$max_cpu"/cpufreq/base_frequency)
  base_freq_mhz=$(echo "$base_freq_khz/1000" | bc)
  test_print_trc "The base freq of max cpu is: $base_freq_mhz"

  #Run CPU stress on all on-line CPUs
  do_cmd "stress -c $all_cpus_num -t 120 &"

  [[ -n "$base_freq_mhz" ]] || block_test "Did not get test freq from turbostat tool."
  test_print_trc "perf stat -o $LOG_PATH/out.txt -a \
    -e {pnp_excursion_monitor/$e_name1,frequency_threshold=$base_freq_mhz,duration=10/,pnp_excursion_monitor/$e_name2/,\
pnp_excursion_monitor/$e_name3/,pnp_excursion_monitor/$e_name4/} sleep $duration"

  perf stat -o "$LOG_PATH"/out.txt -a \
    -e "{pnp_excursion_monitor/$e_name1,frequency_threshold=$base_freq_mhz,duration=10/,pnp_excursion_monitor/$e_name2/,\
pnp_excursion_monitor/$e_name3/,pnp_excursion_monitor/$e_name4/}" sleep "$duration" &
  test_print_trc "Collect system-wide all CPU PEM perf for freq Pm for a group events:\
  $e_name1, $e_name2, $e_name3,$e_name4"

  #Let stress running for 10 seconds then change ISST perf profile level to trigger pnp excursion
  sleep 10

  #Change sst perf profile level
  test_print_trc "Will change the config level from $cur_level to $level_id:"
  do_cmd "intel-speed-select -o pp.out perf-profile set-config-level -l $level_id"
  test_print_trc "The system perf profile config level change log:"
  do_cmd "cat pp.out"

  set_tdp_level_status=$(grep set_tdp_level pp.out | awk -F ":" '{print $2}')
  set_tdp_level_status_num=$(grep set_tdp_level pp.out | awk -F ":" '{print $2}' | wc -l)

  for ((i = 1; i <= set_tdp_level_status_num; i++)); do
    j=$(("$i" - 1))
    set_tdp_level_status_by_num=$(echo "$set_tdp_level_status" | sed -n "$i, 1p")
    if [ "$set_tdp_level_status_by_num" = success ]; then
      test_print_trc "The system package $j set tdp level status is $set_tdp_level_status_by_num"
      test_print_trc "The system package $j set tdp level success."
    else
      test_print_trc "The system package $j set tdp level status is $set_tdp_level_status_by_num"
      die "The system package $j set tdp level fails"
    fi
  done

  test_print_trc "Confirm the changed config current level:"
  do_cmd "intel-speed-select -o pp.out perf-profile get-config-current-level"
  test_print_trc "The system perf profile config current level info:"
  do_cmd "cat pp.out"

  cur_level=$(grep get-config-current_level pp.out | awk -F ":" '{print $2}')
  cur_level_num=$(grep get-config-current_level pp.out | awk -F ":" '{print $2}' | wc -l)

  for ((i = 1; i <= cur_level_num; i++)); do
    j=$(("$i" - 1))
    cur_level_by_num=$(echo "$cur_level" | sed -n "$i, 1p")
    if [ "$cur_level_by_num" -eq "$level_id" ]; then
      test_print_trc "The system package $j config current level: $cur_level_by_num"
      test_print_trc "The system package $j config current level is $level_id after successfully setting"
    else
      test_print_trc "The system package $j config current level: $cur_level_by_num"
      die "The system package $j set tdp level fails"
    fi
  done

  #Use wait command to have perf stat process finish and get perf outputs
  test_print_trc "Will wait for ~$duration seconds to get PEM telemetry counter return from perf tool:"
  wait

  #Recover SST perf profile default setting
  test_print_trc "Recover the config level to the default setting: 0"
  do_cmd "intel-speed-select -o pp.out perf-profile set-config-level -l 0"

  #Expect there is pnp excursion occurs for the base_freq drop due to SST perf profile level change from 0 to others
  if ! counter=$(grep pnp_excursion_monitor "$LOG_PATH"/out.txt | awk '{print $1}'); then
    do_cmd "cat /sys/kernel/debug/tpmi-0000:00:03.1/tpmi-id-01/mem_dump"
    block_test "Did not get PnP excursion event counter: $counter"
  elif [[ "$(echo "scale=2; $counter/$duration > 80.00" | bc)" -eq 1 ]]; then
    test_print_trc "The PnP excursion ratio is $counter, which is larger than 80% during past $duration seconds \
when perf stat all CPUs after SST Perf profile level change to $level_id"
  else
    die "The counter is: $counter, the excursion ratio is less than 80% in past $duration seconds"
  fi
}

dmesg_check() {
  local dmesg_log

  dmesg_log=$(extract_case_dmesg)

  if echo "$dmesg_log" | grep -iE "fail|Call Trace|error|BUG"; then
    die "Kernel dmesg shows failure: $dmesg_log"
  else
    test_print_trc "Kernel dmesg shows Okay."
  fi
}

tpmi_pem_test() {
  case $TEST_SCENARIO in
  load_unload_pem)
    load_unload_module intel_tpmi_pem
    ;;
  check_pem_unbind_bind)
    pem_unbind_bind
    ;;
  pem_instance_check)
    pem_instance_per_package
    ;;
  pem_sysfs_attr)
    pem_sysfs_attr
    pem_events_attr
    ;;
  pem_cpumask_check)
    pem_cpumask
    ;;
  check_pem_events)
    perf_list_pem_event
    ;;
  perf_stat_all_cpu_event_any)
    perf_stat_all_cpu_pem_event any 60
    ;;
  perf_stat_all_cpu_event_fast_rapl)
    perf_stat_all_cpu_pem_event fast_rapl 60
    ;;
  perf_stat_all_cpu_event_hot_vr)
    perf_stat_all_cpu_pem_event hot_vr 60
    ;;
  perf_stat_all_cpu_event_itbm_3)
    perf_stat_all_cpu_pem_event itbm_3 60
    ;;
  perf_stat_all_cpu_event_peci_pstate)
    perf_stat_all_cpu_pem_event peci_pstate 60
    ;;
  perf_stat_all_cpu_event_pl1_mmio)
    perf_stat_all_cpu_pem_event pl1_mmio 60
    ;;
  perf_stat_all_cpu_event_pl1_msr_tpmi)
    perf_stat_all_cpu_pem_event pl1_msr_tpmi 60
    ;;
  perf_stat_all_cpu_event_pl1_peci)
    perf_stat_all_cpu_pem_event pl1_peci 60
    ;;
  perf_stat_all_cpu_event_pl2_mmio)
    perf_stat_all_cpu_pem_event pl2_mmio 60
    ;;
  perf_stat_all_cpu_event_pl2_msr_tpmi)
    perf_stat_all_cpu_pem_event pl2_msr_tpmi 60
    ;;
  perf_stat_all_cpu_event_pl2_peci)
    perf_stat_all_cpu_pem_event pl2_peci 60
    ;;
  perf_stat_all_cpu_event_pmax)
    perf_stat_all_cpu_pem_event pmax 60
    ;;
  perf_stat_all_cpu_event_prochot)
    perf_stat_all_cpu_pem_event prochot 60
    ;;
  perf_stat_all_cpu_event_psys_pl1_mmio)
    perf_stat_all_cpu_pem_event psys_pl1_mmio 60
    ;;
  perf_stat_all_cpu_event_psys_pl1_msr_tpmi)
    perf_stat_all_cpu_pem_event psys_pl1_msr_tpmi 60
    ;;
  perf_stat_all_cpu_event_psys_pl1_peci)
    perf_stat_all_cpu_pem_event psys_pl1_peci 60
    ;;
  perf_stat_all_cpu_event_psys_pl2_mmio)
    perf_stat_all_cpu_pem_event psys_pl2_mmio 60
    ;;
  perf_stat_all_cpu_event_psys_pl2_msr_tpmi)
    perf_stat_all_cpu_pem_event psys_pl2_msr_tpmi 60
    ;;
  perf_stat_all_cpu_event_psys_pl2_peci)
    perf_stat_all_cpu_pem_event psys_pl2_peci 60
    ;;
  perf_stat_all_cpu_event_sst_pp)
    perf_stat_all_cpu_pem_event sst_pp 60
    ;;
  perf_stat_all_cpu_event_thermal)
    perf_stat_all_cpu_pem_event thermal 60
    ;;
  perf_stat_all_cpu_event_any_pm)
    perf_stat_all_cpu_pem_event_pm any 60
    ;;
  perf_stat_cpu_1_event_any)
    perf_stat_single_cpu_pem_event_any 1 60
    ;;
  perf_stat_cpu_1_event_any_p01)
    perf_stat_single_cpu_pem_event_any_p01 1 60
    ;;
  perf_stat_raw_event_0)
    perf_stat_raw_event 0 60
    ;;
  perf_stat_raw_event_8)
    perf_stat_raw_event 8 60
    ;;
  perf_stat_raw_event_24)
    perf_stat_raw_event 24 60
    ;;
  perf_stat_raw_event_26)
    perf_stat_raw_event 26 60
    ;;
  perf_stat_rapl_pl1_change)
    rapl_pl_change 0 pl1_msr_tpmi 120
    ;;
  perf_stat_rapl_pl2_change)
    rapl_pl_change 1 pl2_msr_tpmi 120
    ;;
  perf_stat_rapl_pl1_group_tpmi_change)
    rapl_pl_change_group_event 0 any pl1_msr_tpmi psys_pl1_msr_tpmi 120
    ;;
  perf_stat_rapl_pl2_group_tpmi_change)
    rapl_pl_change_group_event 1 any pl2_msr_tpmi psys_pl2_msr_tpmi 120
    ;;
  perf_stat_rapl_pl1_group_peci_change)
    rapl_pl_change_group_event 0 any pl1_peci psys_pl1_peci 120
    ;;
  perf_stat_rapl_pl2_group_peci_change)
    rapl_pl_change_group_event 1 any pl2_peci psys_pl2_peci 120
    ;;
  perf_stat_rapl_pl1_pl2_multi_group_tpmi_change)
    rapl_pl_change_multi_group_event 0 1 any psys_pl1_msr_tpmi any pl2_msr_tpmi psys_pl2_msr_tpmi 120
    ;;
  perf_stat_rapl_pl1_pl2_multi_group_peci_change)
    rapl_pl_change_multi_group_event 0 1 any pl1_peci psys_pl1_peci pl2_peci psys_pl2_peci 120
    ;;
  perf_stat_sst_pp_change_to_level3)
    sst_pp_change 3 120
    ;;
  perf_stat_sst_pp_change_to_level4)
    sst_pp_change 4 120
    ;;
  perf_stat_sst_pp_change_to_level3_group)
    sst_pp_change_group_event 3 any itbm_3 peci_pstate sst_pp 120
    ;;
  perf_stat_sst_pp_change_to_level4_group)
    sst_pp_change_group_event 4 any itbm_3 peci_pstate sst_pp 120
    ;;
  perf_state_all_cpu_group_mmio)
    perf_stat_all_cpu_pem_event_group any pl1_mmio pl2_mmio psys_pl1_mmio psys_pl2_mmio 60
    ;;
  perf_state_all_cpu_group_tpmi)
    perf_stat_all_cpu_pem_event_group any pl1_msr_tpmi pl2_msr_tpmi psys_pl1_msr_tpmi psys_pl2_msr_tpmi 60
    ;;
  perf_state_all_cpu_group_peci)
    perf_stat_all_cpu_pem_event_group any pl1_peci pl2_peci psys_pl1_peci psys_pl2_peci 60
    ;;
  perf_state_all_cpu_group_platfrom)
    perf_stat_all_cpu_pem_event_group any thermal pmax prochot hot_vr 60
    ;;
  perf_state_all_cpu_group_freq)
    perf_stat_all_cpu_pem_event_group any itbm_3 peci_pstate sst_pp fast_rapl 60
    ;;
  perf_state_all_cpu_pm_group_mmio)
    perf_stat_all_cpu_pem_event_pm_group any pl1_mmio pl2_mmio psys_pl1_mmio psys_pl2_mmio 60
    ;;
  perf_state_all_cpu_pm_group_tpmi)
    perf_stat_all_cpu_pem_event_pm_group any pl1_msr_tpmi pl2_msr_tpmi psys_pl1_msr_tpmi psys_pl2_msr_tpmi 60
    ;;
  perf_state_all_cpu_pm_group_peci)
    perf_stat_all_cpu_pem_event_pm_group any pl1_peci pl2_peci psys_pl1_peci psys_pl2_peci 60
    ;;
  perf_state_all_cpu_pm_group_platfrom)
    perf_stat_all_cpu_pem_event_pm_group any thermal pmax prochot hot_vr 60
    ;;
  perf_state_all_cpu_pm_group_freq)
    perf_stat_all_cpu_pem_event_pm_group any itbm_3 peci_pstate sst_pp fast_rapl 60
    ;;
  perf_stat_rapl_pl1_pl2_multi_group_tpmi_change_1hr)
    rapl_pl_change_multi_group_event 0 1 any psys_pl1_msr_tpmi any pl2_msr_tpmi psys_pl2_msr_tpmi 3600
    ;;
  perf_stat_rapl_pl1_pl2_multi_group_peci_change_1hr)
    rapl_pl_change_multi_group_event 0 1 any pl1_peci psys_pl1_peci pl2_peci psys_pl2_peci 3600
    ;;
  perf_stat_sst_pp_change_to_level3_group_1hr)
    sst_pp_change_group_event 3 any itbm_3 peci_pstate sst_pp 3600
    ;;
  perf_stat_sst_pp_change_to_level4_group_1hr)
    sst_pp_change_group_event 4 any itbm_3 peci_pstate sst_pp 3600
    ;;
  perf_stat_all_cpu_event_any_1hr)
    perf_stat_all_cpu_pem_event any 3600
    ;;
  perf_stat_cpu_1_event_any_p01_1hr)
    perf_stat_single_cpu_pem_event_any_p01 1 3600
    ;;
  perf_stat_all_cpu_event_any_pm_1hr)
    perf_stat_all_cpu_pem_event_pm any 3600
    ;;
  perf_stat_all_cpu_event_any_pm_12hr)
    perf_stat_all_cpu_pem_event_pm any 43200
    ;;
  esac
  dmesg_check
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

tpmi_pem_test
