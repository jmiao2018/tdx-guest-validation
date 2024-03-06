#!/bin/bash

###############################################################################
##                                                                           ##
## Copyright (c) 2017, Intel Corporation.                                    ##
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
# File:         powerclamp_idle_inject_tests.sh
#
# Description:  Idle injection tests for Intel Powerclamp
#
# Authors:      Jerry C. Wang - jerry.c.wang@intel.com
#
# History:      Jun 30 2017 - Created - Jerry C. Wang
#

source "powerclamp_common.sh"
source "functions.sh"

CPU_NUM=$(lscpu | grep -E "^CPU\(s\):" | cut -d":" -f2 | sed "s/^[ \t]*//")
IDLE_INJECT="kidle_inj"
MAX_INJECT=50
WAIT_TIME=3

usage() {
  cat <<-EOF >&2
  usage: ./${0##*/} [-c] [-f] [-o] [-i steps] [-l time] [-r time] [-s time] [-h]
    -c  Check active idle injection
    -f  Forced module unload during idle injection
    -o  Forced CPU offline during idle injection
    -p  Check CPU performance and power against idle injection
    -i  Incremental increase and decrease idle injection
    -l  Longlasting test on powerclamp driver
    -r  Random powerclamp on/off
    -s  Random shutdown CPU cores
    -h  Show this
EOF
  exit 0
}

# Check if the idle threads match to CPU
check_idle_threads() {
  [[ $(read_powerclamp_sysfs "$CLAMP_STATUS") -ne -1 ]] || \
    die "Idle injection is off"

  on_cpu=$(lscpu | grep "On-line CPU" | cut -d":" -f2 | sed "s/^[ \t]*//")
  off_cpu=$(lscpu | grep "Off-line CPU" | cut -d":" -f2 | sed "s/^[ \t]*//")

  IFS=","

  # There are two possible result: core number (x) or a range (x-y)
  for cpu in $on_cpu; do
    if [[ $cpu =~ ^[0-9]{1,3}$ ]]; then
      test_print_trc "Checking Online CPU core $cpu idle injection"
      [[ $(pgrep "^${IDLE_INJECT}/${cpu}$") ]] || \
          die "Unable to find idle injection thread for CPU core $cpu"
    else
      st=$(echo "$cpu" | awk -F'-' '{print $1}')
      en=$(echo "$cpu" | awk -F'-' '{print $2}')
      for core in $(seq -s, "$st" "$en"); do
        test_print_trc "Checking Online CPU core $core idle injection"
        [[ $(pgrep "^${IDLE_INJECT}/${core}$") ]] || \
            die "Unable to find idle injection thread for CPU core $core"
      done
    fi
  done

  for cpu in $off_cpu; do
    if [[ $cpu =~ ^[0-9]{1,3}$ ]]; then
      test_print_trc "Checking Offline CPU core $cpu idle injection"
      [[ $(pgrep "^${IDLE_INJECT}/${cpu}$") ]] && \
          die "Idle injection thread found on offline CPU core $cpu"
    else
      st=$(echo "$cpu" | awk -F'-' '{print $1}')
      en=$(echo "$cpu" | awk -F'-' '{print $2}')
      for core in $(seq -s, "$st" "$en"); do
        test_print_trc "Checking Offline CPU core $core idle injection"
        [[ $(pgrep "^${IDLE_INJECT}/${core}$") ]] && \
            die "Idle injection thread found on offline CPU core $cpu"
      done
    fi
  done
}

# Get average and standard deviation for long lasting tests
get_avg_std() {
  declare -a data_array=($@)
  [[ ${#data_array[@]} -ge 1 ]] || die "The data array is empty!"

  printf '%s\n' "${data_array[@]}" | \
     awk '{for(i=1;i<=NF;i++) {sum[i] += $i; sumsq[i] += ($i)^2}}
          END {for (i=1;i<=NF;i++) {
          printf "%f %f \n", sum[i]/NR, sqrt((sumsq[i]-sum[i]^2/NR)/NR)}}'
}

# Initialize test environment at start of each test
idle_inject_init() {
  test_print_trc "Initialize Test Environment ......"

  do_cmd "load_unload_module.sh -u -d $MODULE_NAME"

  test_print_trc "End of Initialization ......"
}

# Tear down test environment at end of each test
teardown_handler="idle_inject_teardown"
idle_inject_teardown() {
  test_print_trc "teardown: Remove powerclamp module."
  modprobe -r "$MODULE_NAME"

  test_print_trc "teardown: Restore CPU back online"
  for((i=1;i<CPU_NUM;i++)); do
    set_online "cpu$i"
  done

  test_print_trc "teardown: Kill all existing fspin"
  for pid in $(pgrep "$CPU_LOAD"); do
    { kill "$pid" && wait "$pid"; } 2>/dev/null
  done

  test_print_trc "teardown: Remove fspin log"
  rm -rf "$FSPIN_LOG"
}

main () {
  # TC: POWER_XS_FUNC_LOAD_UNLOAD_POWERCLAMP
  if [[ $CHECK_IDLE -eq 1 ]]; then
    enable_idle_injection 50
    generate_cpu_loads
    sleep $WAIT_TIME
    check_idle_threads

    disable_idle_injection
    sleep $WAIT_TIME
    kidle_pids=$(pgrep -c "$IDLE_INJECT")
    test_print_trc "There are $kidle_pids idle threads alive!"
    [[ "$kidle_pids" -eq 0 ]] || die "Failed to disable kernel idle injection!"
  fi

  # TC: POWER_XS_FUNC_POWERCLAMP_FORCED_MODULE_UNLOAD
  if [[ $UNLOAD_MODULE -eq 1 ]]; then
    enable_idle_injection 50
    generate_cpu_loads
    sleep $WAIT_TIME
    check_idle_threads

    do_cmd "load_unload_module.sh -u -d $MODULE_NAME"
    kidle_pids=$(pgrep -c "$IDLE_INJECT")
    test_print_trc "There are $kidle_pids idle threads alive!"
    [[ "$kidle_pids" -eq 0 ]] || die "Failed to disable kernel idle injection!"
  fi

  # TC: POWER_XS_FUNC_POWERCLAMP_CPU_ONLINE_OFFLINE
  if [[ $CPU_ON_OFF -eq 1 ]]; then
    enable_idle_injection 50
    generate_cpu_loads

    test_print_trc "Putting CPUs offline!"
    for((i=1;i<=CPU_NUM/2;i++)); do
      set_offline "cpu$i"
    done

    sleep $WAIT_TIME

    [[ $(nproc) == $((CPU_NUM/2)) ]] || die "Unable to reduce CPU core by half."
    check_idle_threads

    test_print_trc "Putting CPUs back online!"
    for((i=1;i<=CPU_NUM/2;i++)); do
      set_online "cpu$i"
    done

    sleep $WAIT_TIME
    test_print_trc "There are $(nproc) idle threads alive!"
    [[ $(nproc) == "$CPU_NUM" ]] || die "Unable to restore CPU."
    check_idle_threads
  fi

  # TC: POWER_XS_FUNC_POWERCLAMP_CHECK_PERF_POWER_CONTROL
  if [[ $CHECK_POWER -eq 1 ]]; then
    disable_idle_injection
    generate_cpu_loads
    sleep 5

    pwr_b4=$(get_rapl_power)
    perf_b4=$(get_cpu_score)
    test_print_trc "Before Idle Inject - Power: $pwr_b4 Performance: $perf_b4"

    enable_idle_injection 50

    pwr_now=$(get_rapl_power)
    perf_now=$(get_cpu_score)
    test_print_trc "After Idle Inject - Power: $pwr_now Performance: $perf_now"

    [[ $(echo "$pwr_b4 > $pwr_now" | bc) -eq 1 ]] || \
        die "No power reduction after idle injection!"

    [[ $(echo "$perf_b4 > $perf_now" | bc) -eq 1 ]] || \
        die "No performance reduction after idle injection!"
  fi

  # TC: POWER_XS_FUNC_POWERCLAMP_INCREMENTAL_IDLE_INJECT
  if [[ $INCREMENT -eq 1 ]]; then
    disable_idle_injection
    generate_cpu_loads
    sleep 5

    pwr_prv=9999999
    perf_prv=999999
    for((i=0;i<=MAX_INJECT;i+=STEPS)); do
      enable_idle_injection $i
      pwr=$(get_rapl_power)
      perf=$(get_cpu_score)
      test_print_trc "PCT: $i PWR: $pwr PERF: $perf"

      [[ $(echo "$pwr_prv > $pwr" | bc) -eq 1 &&  \
        $(echo "$perf_prv > $perf" | bc) -eq 1 ]] || \
        die "Expecting power and performance reduction after each increment!"

      pwr_prv=$pwr
      perf_prv=$perf
    done

    pwr_prv=0
    perf_prv=0
    for((i=MAX_INJECT;i>=0;i-=STEPS)); do
      enable_idle_injection $i
      pwr=$(get_rapl_power)
      perf=$(get_cpu_score)
      test_print_trc "PCT: $i PWR: $pwr PERF: $perf"

      [[ $(echo "$pwr_prv < $pwr" | bc) -eq 1 &&  \
        $(echo "$perf_prv < $perf" | bc) -eq 1 ]] || \
        die "Expecting power and performance increase after each decrement!"

      pwr_prv=$pwr
      perf_prv=$perf
    done
  fi

  # TC: POWER_S_FUNC_POWERCLAMP_LONG_LASTING_TEST
  if [[ $LONGLAST -eq 1 ]]; then
    enable_idle_injection 50
    generate_cpu_loads

    declare -a pwr_data
    declare -a perf_data
    for((t=0,i=0;t<=DURATION;t+=WAIT_TIME,i++)); do
      pwr_data[i]=$(get_rapl_power)
      perf_data[i]=$(get_cpu_score)
      test_print_trc "PCT: 50 PWR: ${pwr_data[$i]} PERF: ${perf_data[$i]}"
      sleep $WAIT_TIME
    done

    read -r pwr_avg pwr_std <<<"$(get_avg_std "${pwr_data[@]}")"
    test_print_trc "Power - Average: $pwr_avg Std: $pwr_std"
    [[ $(echo "scale=5;($pwr_std/$pwr_avg)<0.05" | bc) -eq 1 ]] | \
      die "Large variation found in the power measurement!"

    read -r perf_avg perf_std <<<"$(get_avg_std "${perf_data[@]}")"
    test_print_trc "Performance - Average: $perf_avg Std: $perf_std"
    [[ $(echo "scale=5;($perf_std/$perf_avg)<0.05" | bc) -eq 1 ]] | \
      die "Large variation found in the performance measurement!"
  fi

  # TC: POWER_S_FUNC_POWERCLAMP_RANDOM_IDLE_INJECT_ON_OFF
  if [[ $RANDOM_ON_OFF -eq 1 ]]; then
    enable_idle_injection 0
    generate_cpu_loads

    for((t=0;t<=DURATION;t+=WAIT_TIME)); do
      n=$(shuf -i "1-100" -n 1)
      [[ "$n" -gt 50 ]] && n=0

      test_print_trc "Setting idle injection to $n"
      enable_idle_injection $n

      if [[ $n -eq 0 ]]; then
        [[ $(pgrep -c $IDLE_INJECT) -eq 0 && \
          $(read_powerclamp_sysfs "$CLAMP_STATUS") -eq -1 ]] || \
            die "No idle injection is expected!"
      else
        check_idle_threads
      fi

      sleep $WAIT_TIME
    done
  fi

  # TC: POWER_S_FUNC_POWERCLAMP_RANDOM_CPU_ON_OFF
  if [[ $RANDOM_SHUTDOWN -eq 1 ]]; then
    [[ "$CPU_NUM" -gt 1 ]] || block_test "At least 2 CPU are needed!"
    enable_idle_injection 555550
    generate_cpu_loads

    for((t=0;t<=DURATION;t+=WAIT_TIME)); do
      n=$(shuf -i 1-$((CPU_NUM-1)) -n 1)
      core_list=$(shuf -i 1-$((CPU_NUM-1)) -n "$n")

      while read -r core; do
        set_offline "cpu$core"
      done <<< "$core_list"

      check_idle_threads

      while read -r core; do
        set_online "cpu$core"
      done <<< "$core_list"

      check_idle_threads

      sleep $WAIT_TIME
    done

  fi
}

: "${CHECK_IDLE:=0}"
: "${UNLOAD_MODULE:=0}"
: "${CPU_ON_OFF:=0}"
: "${CHECK_POWER:=0}"
: "${INCREMENT:=0}"
: "${LONGLAST:=0}"
: "${RANDOM_ON_OFF:=0}"
: "${RANDOM_SHUTDOWN:=0}"

while getopts 'cfopi:l:r:s:' flag; do
  case ${flag} in
    c)
      CHECK_IDLE=1
      ;;
    f)
      UNLOAD_MODULE=1
      ;;
    o)
      CPU_ON_OFF=1
      ;;
    p)
      CHECK_POWER=1
      ;;
    i)
      INCREMENT=1
      STEPS="${OPTARG}"
      ;;
    l)
      LONGLAST=1
      DURATION="${OPTARG}"
      ;;
    r)
      RANDOM_ON_OFF=1
      DURATION="${OPTARG}"
      ;;
    s)
      RANDOM_SHUTDOWN=1
      DURATION="${OPTARG}"
      ;;
    *)
      usage
      exit 0
      ;;
  esac
done

idle_inject_init
main "$@"
exec_teardown
