#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Description: test script for RAPL names and energy value
# Comparing among sysfs, perf and turbostat tool
# Which is supported on both client and server, covers
# Legacy intel_rapl and tpmi_rapl drivers
# RAPL: Runtime Average Power Limiting
#
# Authors:      wendy.wang@intel.com
# History:      Sep 15 2022 - Created - Wendy Wang

source "dmesg_functions.sh"
source "powermgr_common.sh"
source "common.sh"

CPU_LOAD="fspin"
CPU_LOAD_ARG="-i 10"
GPU_LOAD="glxgears"
GPU_LOAD_ARG="-display :1"

: "${CASE_NAME:=""}"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

rapl_perf_name_compare() {
  local driver_name=$1

  sysfs_names=$(cat /sys/class/powercap/"$driver_name":*/name 2>&1)
  test_print_trc "sysfs domain name: $sysfs_names"
  perf_names=$(perf list | grep energy 2>&1)
  test_print_trc "Perf event name: $perf_names"
  energy_event_sysfs=$(ls /sys/devices/power/events/ 2>&1)
  test_print_trc "Perf sysfs events:$energy_event_sysfs"
  turbostat_names=$("$PSTATE_TOOL/turbostat" -q --show power sleep 1 2>&1)
  test_print_trc "Turbostat log: $turbostat_names"

  sysfs_rapl_num=$(cat /sys/class/powercap/"$driver_name":*/name | wc -l 2>&1)
  perf_name_num=$(perf list | grep -c energy 2>&1)
  #Take RAPL sysfs domain as base, if perf energy name number
  #Is not aligned with sysfs, then fail the case
  [[ -n "$sysfs_names" ]] || block_test "RAPL sysfs does not exist: $sysfs_names"
  [[ -n "$perf_names" ]] || block_test "Did not get RAPL event by perf list:\
  $energy_event_sysfs"
  if [[ "$sysfs_rapl_num" -eq "$perf_name_num" ]]; then
    test_print_trc "RAPL domain number is aligned between sysfs and perf"
  else
    #Here will not die because perf list cannot display --per-socket energy value on server
    #So the rapl domain cannot compare between perf list tool and sysfs on server, only
    #Print the message, but not fail.
    test_print_trc "RAPL domain number is not aligned between sysfs and perf. \
sysfs shows: $sysfs_names, perf event shows:$perf_names"
  fi

  #Check sysfs,perf,turbostat tool RAPL domain name, take sysfs as base
  for ((i = 1; i <= sysfs_rapl_num; i++)); do
    sysfs_name=$(cat /sys/class/powercap/"$driver_name":*/name | sed -n "$i,1p")
    test_print_trc "RAPL Domain test name: $sysfs_name"
    if [[ $sysfs_name =~ package ]] && [[ $perf_names =~ pkg ]] &&
      [[ $turbostat_names =~ PkgWatt ]]; then
      test_print_trc "Package domain name is aligned among sysfs,perf and turbostat tool"
    elif [[ $sysfs_name =~ core ]] && [[ $perf_names =~ core ]] &&
      [[ $turbostat_names =~ CorWatt ]]; then
      test_print_trc "Core domain name is aligned among sysfs,perf and turbostat tool"
    elif [[ $sysfs_name =~ uncore ]] && [[ $perf_names =~ gpu ]] &&
      [[ $turbostat_names =~ GFXWatt ]]; then
      test_print_trc "Uncore(GFX) domain name is aligned among sysfs,perf and turbostat tool"
    elif [[ $sysfs_name =~ dram ]] && [[ $perf_names =~ ram ]] &&
      [[ $turbostat_names =~ RAMWatt ]]; then
      test_print_trc "Dram domain name is aligned among sysfs,perf and turbostat tool"
    elif [[ $sysfs_name =~ psys ]] && [[ $perf_names =~ psys ]]; then
      test_print_trc "Turbostat will not show psys, but sysfs and perf shows up, it's expected."
    else
      die "There is a domain name exception among sysfs, perf and turbostat comparing\
sysfs names: $sysfs_names, perf names: $perf_names, turbostat_name: $turbostat_names"
    fi
  done
}

rapl_perf_energy_compare() {
  local driver_name=$1
  local load=$2
  local load=$3
  local option
  local j=0
  local p=0
  local pkg0=package-0
  local pkg1=package-1

  sysfs_names=$(cat /sys/class/powercap/"$driver_name":*/name 2>&1)
  sysfs_rapl_num=$(cat /sys/class/powercap/"$driver_name":*/name | wc -l 2>&1)
  perf_names=$(perf list | grep energy- 2>&1)
  perf_name_num=$(perf list | grep -c energy- 2>&1)
  [[ -n $sysfs_names ]] || block_test "Please check if rapl driver loaded or not."
  [[ -n $perf_names ]] || block_test "Did not get RAPL event by perf list"

  #Read MSR RAW data before sleep
  #Package MSR is: 0x611
  #Core MSR is: 0x639
  #Psys MSR is: 0x64d
  #Dram MSR is: 0x619
  for ((i = 1; i <= sysfs_rapl_num; i++)); do
    sysfs_name=$(cat /sys/class/powercap/"$driver_name":*/name | sed -n "$i,1p" 2>&1)
    if [[ $sysfs_name =~ package ]]; then
      msr_raw_bf=$(rdmsr -f 31:0 0x611)
      test_print_trc "$sysfs_name MSR RAW value before: $msr_raw_bf"
    elif [[ $sysfs_name =~ core ]]; then
      msr_raw_bf=$(rdmsr -f 31:0 0x639)
      test_print_trc "$sysfs_name MSR RAW value before: $msr_raw_bf"
    elif [[ $sysfs_name =~ psys ]]; then
      msr_raw_bf=$(rdmsr -f 31:0 0x64d)
      test_print_trc "$sysfs_name MSR RAW value before: $msr_raw_bf"
    elif [[ $sysfs_name =~ dram ]]; then
      msr_raw_bf=$(rdmsr -f 31:0 0x619)
      test_print_trc "$sysfs_name MSR RAW value before: $msr_raw_bf"
    fi
  done

  #Will add the workload or idle
  [[ -z $LOAD_PID ]] || kill -9 "$LOAD_PID"

  load=$(echo "$load" | awk '{print tolower($0)}')
  case $load in
  pkg | core)
    which "$CPU_LOAD" &>/dev/null || die "fspin does not exist"
    do_cmd "$CPU_LOAD $CPU_LOAD_ARG > /dev/null &"
    ;;
  uncore)
    which "$GPU_LOAD" &>/dev/null || die "glxgears does not exist"
    do_cmd "$GPU_LOAD $GPU_LOAD_ARG > /dev/null &"
    ;;
  dram)
    which "stress" &>/dev/null || die "stress does not exist"
    mem_avail=$(grep MemAvailable /proc/meminfo | awk -F " " '{print $2}')
    mem_test=$(echo "$mem_avail"/10000000 | bc)
    do_cmd "stress --vm $mem_test --vm-bytes 1024M -t 30 > /dev/null &"
    ;;
  *)
    test_print_trc "Will not run workload but idle!"
    do_cmd "sleep 20"
    ;;
  esac

  LOAD_PID=$!

  #Read sysfs energy value before sleep
  sysfs_energy_uj_bf=$(cat /sys/class/powercap/"$driver_name":*/energy_uj 2>&1)
  test_print_trc "Sysfs energy events before:$sysfs_energy_uj_bf"
  #Sleep 20 seconds to capture the RAPL energy value
  for ((i = 1; i <= perf_name_num; i++)); do
    perf_name=$(echo "$perf_names" | awk '{print $1}' | sed -n "$i, 1p" 2>&1)
    test_print_trc "perf event name: $perf_name"
    option="$option -e $perf_name"
    test_print_trc "option name: $option"
  done
  do_cmd "perf stat -o $LOG_PATH/out.txt --per-socket $option sleep 20"
  sysfs_energy_uj_af=$(cat /sys/class/powercap/"$driver_name":*/energy_uj 2>&1)

  #Print the logs after sleep
  test_print_trc "Sysfs domain name after: $sysfs_names"
  test_print_trc "Sysfs energy events after: $sysfs_energy_uj_af"
  test_print_trc "Perf energy events log:"
  do_cmd "cat $LOG_PATH/out.txt"
  #Kill the workload if has
  [[ -z $LOAD_PID ]] || kill -9 "$LOAD_PID"

  #Calculate each energy delta in past 20 seconds idle, the unit is Joules
  for ((i = 1; i <= sysfs_rapl_num; i++)); do
    sysfs_name=$(cat /sys/class/powercap/"$driver_name":*/name | sed -n "$i,1p" 2>&1)
    sysfs_energy_uj_bf_per_domain=$(echo "$sysfs_energy_uj_bf" | sed -n "$i,1p")
    test_print_trc "Sysfs energy uj before for domain name $sysfs_name is: $sysfs_energy_uj_bf_per_domain"
    sysfs_energy_uj_af_per_domain=$(echo "$sysfs_energy_uj_af" | sed -n "$i,1p")
    test_print_trc "Sysfs energy uj after for domain name $sysfs_name is: $sysfs_energy_uj_af_per_domain"
    if [[ $sysfs_name =~ package ]]; then
      msr_raw_af=$(rdmsr -f 31:0 0x611)
      test_print_trc "$sysfs_name MSR RAW value after: $msr_raw_af"
    elif [[ $sysfs_name =~ core ]]; then
      msr_raw_af=$(rdmsr -f 31:0 0x639)
      test_print_trc "$sysfs_name MSR RAW value after: $msr_raw_af"
    elif [[ $sysfs_name =~ psys ]]; then
      msr_raw_af=$(rdmsr -f 31:0 0x64d)
      test_print_trc "$sysfs_name MSR RAW value after: $msr_raw_af"
    elif [[ $sysfs_name =~ dram ]]; then
      msr_raw_af=$(rdmsr -f 31:0 0x619)
      test_print_trc "$sysfs_name MSR RAW value after: $msr_raw_af"
    fi
    sysfs_energy_delta_uj=$(echo "scale=2; $sysfs_energy_uj_af_per_domain-$sysfs_energy_uj_bf_per_domain" | bc)
    test_print_trc "Sysfs energy delta ujoules for $sysfs_name is: $sysfs_energy_delta_uj"
    sysfs_energy_delta_j=$(echo "scale=2; $sysfs_energy_delta_uj/1000000" | bc)
    test_print_trc "Sysfs energy delta joules for $sysfs_name is: $sysfs_energy_delta_j"

    #Calculate perf energy delta, which is directly reading from perf log
    if ! counter=$(grep energy "$LOG_PATH"/out.txt | awk '{print $3}'); then
      block_test "Did not get energy $sysfs_name counter: $counter"
    else
      [[ $sysfs_name =~ dram ]] &&
        perf_energy_j=$(grep energy-ram "$LOG_PATH"/out.txt | grep S$j | awk '{print $3}' 2>&1) &&
        j=$(("$j" + 1))
      #Use j variable to judge how many dram domain name, initial value is 0
      [[ $sysfs_name == "$pkg0" ]] &&
        perf_energy_j=$(grep "energy-pkg" "$LOG_PATH"/out.txt | grep S0 | awk '{print $3}' 2>&1)
      [[ $sysfs_name == "$pkg1" ]] &&
        perf_energy_j=$(grep "energy-pkg" "$LOG_PATH"/out.txt | grep S1 | awk '{print $3}' 2>&1)
      [[ $sysfs_name =~ core ]] &&
        perf_energy_j=$(grep "energy-cores" "$LOG_PATH"/out.txt | grep S0 | awk '{print $3}' 2>&1)
      [[ $sysfs_name =~ uncore ]] &&
        perf_energy_j=$(grep "energy-gpu" "$LOG_PATH"/out.txt | grep S0 | awk '{print $3}' 2>&1)
      [[ $sysfs_name =~ psys ]] &&
        perf_energy_j=$(grep "energy-psys" "$LOG_PATH"/out.txt | grep S$p | awk '{print $3}' 2>&1) &&
        p=$(("$p" + 1))
      #Use p variable to judge how many psys domain name, initial value is 0
      #Perf tool will display 1,000 for 1000, so need to remove ","
      perf_energy_j_modify=$(echo "$perf_energy_j" | sed 's/,//' 2>&1)
      test_print_trc "Perf energy joules for $sysfs_name is: $perf_energy_j_modify"
    fi

    #Compare the sysfs_energy and perf_energy value
    energy_delta_j=$(awk -v x="$sysfs_energy_delta_j" -v y="$perf_energy_j_modify" \
      'BEGIN{printf "%.1f\n", x-y}')
    test_print_trc "The domain $sysfs_name energy delta joules between sysfs and perf event is:$energy_delta_j"

    #Set the error deviation is 20% of sysfs energy Joules
    energy_low_j=$(echo "scale=2; 20*$sysfs_energy_delta_j/100" | bc)
    energy_low_j=$(echo "scale=2; $sysfs_energy_delta_j-$energy_low_j" | bc)
    test_print_trc "The low energy error deviation is:$energy_low_j"
    energy_high_j=$(echo "scale=2; $sysfs_energy_delta_j+$energy_low_j" | bc)
    test_print_trc "The high energy error deviation is:$energy_high_j"
    if [[ $(echo "$perf_energy_j_modify < $energy_high_j" | bc) -eq 1 ]] &&
      [[ $(echo "$perf_energy_j_modify > $energy_low_j" | bc) -eq 1 ]]; then
      test_print_trc "The domain $sysfs_name energy delta between sysfs and perf event \
is within 20% of sysfs energy joules gap"
    elif [[ $(echo "$perf_energy_j_modify == 0" | bc) -eq 1 ]]; then
      test_print_trc "The domain $sysfs_name energy shows 0, if GFX related, it maybe expected"
    else
      die "The domain $sysfs_name energy delta between sysfs and perf event is \
beyond 20% of sysfs energy joules gap: $energy_delta_j"
    fi
  done
}

rapl_turbostat_energy_compare() {
  local driver_name=$1
  local load=$2
  local load=$3
  local j=3
  local pkg0=package-0
  local pkg1=package-1
  local corename=core
  local uncorename=uncore
  local dramname=dram
  local psysname=psys
  local psysname1=psys-1

  sysfs_names=$(cat /sys/class/powercap/"$driver_name":*/name 2>&1)
  sysfs_rapl_num=$(cat /sys/class/powercap/"$driver_name":*/name | wc -l 2>&1)
  [[ -n $sysfs_names ]] || block_test "Please check if rapl driver loaded or not"

  #Read MSR RAW data before sleep
  #Package MSR is: 0x611
  #Core MSR is: 0x639
  #Psys MSR is: 0x64d
  #Dram MSR is: 0x619
  for ((i = 1; i <= sysfs_rapl_num; i++)); do
    sysfs_name=$(cat /sys/class/powercap/"$driver_name":*/name | sed -n "$i,1p" 2>&1)
    [[ -n $sysfs_name ]] || block_test "No intel_rapl sysfs files."
    if [[ $sysfs_name =~ package ]]; then
      msr_raw_bf=$(rdmsr -f 31:0 0x611)
      test_print_trc "$sysfs_name MSR RAW value before: $msr_raw_bf"
    elif [[ $sysfs_name =~ core ]]; then
      msr_raw_bf=$(rdmsr -f 31:0 0x639)
      test_print_trc "$sysfs_name MSR RAW value before: $msr_raw_bf"
    elif [[ $sysfs_name =~ psys ]]; then
      msr_raw_bf=$(rdmsr -f 31:0 0x64d)
      test_print_trc "$sysfs_name MSR RAW value before: $msr_raw_bf"
    elif [[ $sysfs_name =~ dram ]]; then
      msr_raw_bf=$(rdmsr -f 31:0 0x619)
      test_print_trc "$sysfs_name MSR RAW value before: $msr_raw_bf"
    fi
  done

  #Will add the workload or idle
  [[ -z $LOAD_PID ]] || kill -9 "$LOAD_PID"

  load=$(echo "$load" | awk '{print tolower($0)}')
  case $load in
  pkg | core)
    which "$CPU_LOAD" &>/dev/null || die "fspin does not exist"
    do_cmd "$CPU_LOAD $CPU_LOAD_ARG > /dev/null &"
    ;;
  uncore)
    which "$GPU_LOAD" &>/dev/null || die "glxgears does not exist"
    do_cmd "$GPU_LOAD $GPU_LOAD_ARG > /dev/null &"
    ;;
  dram)
    which "stress" &>/dev/null || die "stress does not exist"
    mem_avail=$(grep MemAvailable /proc/meminfo | awk -F " " '{print $2}')
    mem_test=$(echo "$mem_avail"/10000000 | bc)
    do_cmd "stress --vm $mem_test --vm-bytes 1024M -t 90 > /dev/null &"
    ;;
  *)
    test_print_trc "Will not run workload but idle!"
    do_cmd "sleep 20"
    ;;
  esac

  LOAD_PID=$!

  #Read sysfs energy value before sleep
  sysfs_energy_uj_bf=$(cat /sys/class/powercap/"$driver_name":*/energy_uj 2>&1)
  [[ -n $sysfs_energy_uj_bf ]] || block_test "No intel_rapl sysfs energy_uj"
  test_print_trc "Sysfs energy events before:$sysfs_energy_uj_bf"

  #Sleep 20 seconds to capture the RAPL energy value
  tc_out=$("$PSTATE_TOOL/turbostat" -q --show power -i 1 sleep 20 2>&1)
  sysfs_energy_uj_af=$(cat /sys/class/powercap/"$driver_name":*/energy_uj 2>&1)

  #Print the logs after sleep
  test_print_trc "Sysfs domain name after: $sysfs_names"
  test_print_trc "Sysfs energy events after: $sysfs_energy_uj_af"
  test_print_trc "Turbostat output: $tc_out"
  #Kill the workload if has
  [[ -z $LOAD_PID ]] || kill -9 "$LOAD_PID"

  #Calculate each energy delta in past 20 seconds idle, the unit is Joules
  for ((i = 1; i <= sysfs_rapl_num; i++)); do
    sysfs_name=$(cat /sys/class/powercap/"$driver_name":*/name | sed -n "$i,1p" 2>&1)
    sysfs_energy_uj_bf_per_domain=$(echo "$sysfs_energy_uj_bf" | sed -n "$i,1p")
    test_print_trc "Sysfs energy uj before for domain name $sysfs_name is: $sysfs_energy_uj_bf_per_domain"
    sysfs_energy_uj_af_per_domain=$(echo "$sysfs_energy_uj_af" | sed -n "$i,1p")
    test_print_trc "Sysfs energy uj after for domain name $sysfs_name is: $sysfs_energy_uj_af_per_domain"
    if [[ $sysfs_name =~ package ]]; then
      msr_raw_af=$(rdmsr -f 31:0 0x611)
      test_print_trc "$sysfs_name MSR RAW value after: $msr_raw_af"
    elif [[ $sysfs_name =~ core ]]; then
      msr_raw_af=$(rdmsr -f 31:0 0x639)
      test_print_trc "$sysfs_name MSR RAW value after: $msr_raw_af"
    elif [[ $sysfs_name =~ psys ]]; then
      msr_raw_af=$(rdmsr -f 31:0 0x64d)
      test_print_trc "$sysfs_name MSR RAW value after: $msr_raw_af"
    elif [[ $sysfs_name =~ dram ]]; then
      msr_raw_af=$(rdmsr -f 31:0 0x619)
      test_print_trc "$sysfs_name MSR RAW value after: $msr_raw_af"
    fi
    sysfs_energy_delta_uj=$(echo "scale=2; $sysfs_energy_uj_af_per_domain-$sysfs_energy_uj_bf_per_domain" | bc)
    test_print_trc "Sysfs energy delta ujoules for $sysfs_name is: $sysfs_energy_delta_uj"
    sysfs_energy_delta_j=$(echo "scale=2; $sysfs_energy_delta_uj/1000000" | bc)
    test_print_trc "Sysfs energy delta joules for $sysfs_name is: $sysfs_energy_delta_j"

    #Calculate energy delta from turbostat tool, which unit is Watts
    #Joules=Watts * Seconds
    [[ -n "$tc_out" ]] || block_test "Did not get turbostat log"
    if [[ $sysfs_name == "$pkg0" ]]; then
      turbostat_watts=$(echo "$tc_out" | awk '{print $3}' | sed '/^$/d' | sed -n '3,1p' 2>&1)
      test_print_trc "Turbostat watts for $sysfs_name is: $turbostat_watts"
    elif [[ $sysfs_name == "$pkg1" ]]; then
      turbostat_watts=$(echo "$tc_out" | awk '{print $3}' | sed '/^$/d' | sed -n '4,1p' 2>&1)
      test_print_trc "Turbostat watts for $sysfs_name is: $turbostat_watts"
    elif [[ $sysfs_name == "$corename" ]]; then
      turbostat_watts=$(echo "$tc_out" | awk '{$1 = "";print $0}' | sed '/^$/d' |
        awk '{for(k=0;++k<=NF;)a[k]=a[k]?a[k] FS $k:$k} END{for(k=0;k++<NF;)print a[k]}' |
        grep "CorWatt" | awk -F " " '{print $3}')
      test_print_trc "Turbostat watts for $sysfs_name is: $turbostat_watts"
    elif [[ $sysfs_name == "$uncorename" ]]; then
      turbostat_watts=$(echo "$tc_out" | awk '{$1 = "";print $0}' | sed '/^$/d' |
        awk '{for(k=0;++k<=NF;)a[k]=a[k]?a[k] FS $k:$k} END{for(k=0;k++<NF;)print a[k]}' |
        grep "GFXWatt" | awk -F " " '{print $3}')
      test_print_trc "Turbostat watts for $sysfs_name is: $turbostat_watts"
    elif [[ $sysfs_name == "$dramname" ]]; then
      turbostat_watts=$(echo "$tc_out" | awk '{$1 = "";print $0}' | sed '/^$/d' |
        awk '{for(k=0;++k<=NF;)a[k]=a[k]?a[k] FS $k:$k} END{for(k=0;k++<NF;)print a[k]}' |
        grep "RAMWatt" | awk -F " " -v p=$j '{print $p}')
      j=$(("$j" + 1))
      test_print_trc "Turbostat watts for $sysfs_name is: $turbostat_watts"
    elif [[ "$sysfs_name" == "$psysname" ]] || [[ "$sysfs_name" == "$psysname1" ]]; then
      test_print_trc "The turbostat tool does not support $sysfs_name energy value."
      continue
    else
      die "Turbostat tool did not find matched RAPL domain name."
    fi
    turbostat_joules=$(echo "scale=2; $turbostat_watts*20" | bc)
    test_print_trc "Turbostat joules for $sysfs_name is: $turbostat_joules"

    #Compare the sysfs_energy and tubostat tool energy value
    energy_delta_j=$(awk -v x="$sysfs_energy_delta_j" -v y="$turbostat_joules" \
      'BEGIN{printf "%.1f\n", x-y}')
    test_print_trc "The domain $sysfs_name energy delta joules between sysfs and turbostat tool is:$energy_delta_j"

    #Set the error deviation is 20% of sysfs energy Joules
    energy_low_j=$(echo "scale=2; 20*$sysfs_energy_delta_j/100" | bc)
    energy_low_j=$(echo "scale=2; $sysfs_energy_delta_j-$energy_low_j" | bc)
    test_print_trc "The low energy error deviation is:$energy_low_j"
    energy_high_j=$(echo "scale=2; $sysfs_energy_delta_j+$energy_low_j" | bc)
    test_print_trc "The high energy error deviation is:$energy_high_j"
    if [[ $(echo "$turbostat_joules < $energy_high_j" | bc) -eq 1 ]] &&
      [[ $(echo "$turbostat_joules > $energy_low_j" | bc) -eq 1 ]]; then
      test_print_trc "The domain $sysfs_name energy delta between sysfs and turbostat tool \
is within 20% of sysfs energy joules gap"
    elif [[ $(echo "$turbostat_joules == 0" | bc) -eq 1 ]]; then
      test_print_trc "The domain $sysfs_name energy shows 0, if GFX related, it maybe expected"
    else
      die "The domain $sysfs_name energy delta between sysfs and turbostat tool is \
beyond 20% of sysfs energy joules gap: $energy_delta_j"
    fi
  done
}

multiple_packages_stress_compare() {
  local sockets=""
  local node_cpus=""

  mem_avail=$(grep MemAvailable /proc/meminfo | awk -F " " '{print $2}')
  mem_test=$(echo "$mem_avail"/10000000 | bc)

  sockets=$(lscpu | grep Socket | awk -F ":" '{print $2}')
  [[ -n "$sockets" ]] || block_test "Socket number is not available."
  [[ "$sockets" -eq 1 ]] && block_test "The platform only supports 1 socket."

  for ((i = 0; i < sockets; i++)); do
    #Get each socket Pkg power and dram power in watts unit, when stress is running
    #Then compare with total Pkg and dram power
    node_cpus=$(lscpu | grep "NUMA node$i CPU" | sed 's/ //g' | awk -F ":" '{print $2}')
    test_print_trc "Node CPUs for socket$i are: $node_cpus"

    node_cpu_start=$(echo "$node_cpus" | cut -d "-" -f 1 2>&1)
    test_print_trc "The 1st CPU of Node$i: $node_cpu_start"

    #Run CPU stress
    do_cmd "taskset -c $node_cpus stress -c $node_cpus -t 30 2>&1 &"

    #Run DRAM stress
    do_cmd "taskset -c $node_cpus stress --vm $mem_test --vm-bytes 1024M -t 30 2>&1 &"

    #Check CPU Pkg and Dram power from turbostat tool
    tc_out=$("$PSTATE_TOOL/turbostat" -q -c "$node_cpu_start" --show Package,Core,CPU,power -i 1 sleep 20 2>&1)
    [[ -n "$tc_out" ]] || block_test "Did not get turbostat log"
    test_print_trc "Turbostat log when sockets$i stress is running: $tc_out"
    pkg_total=$(echo "$tc_out" | awk '{print $6}' | sed '/^$/d' | sed -n '2,1p' 2>&1)
    test_print_trc "Total pkg power for socket$i is: $pkg_total watts"
    pkg_watts=$(echo "$tc_out" | awk '{print $6}' | sed '/^$/d' | sed -n '3,1p' 2>&1)
    test_print_trc "CPU Package power for socket$i is: $pkg_watts watts"
    dram_total=$(echo "$tc_out" | awk '{print $7}' | sed '/^$/d' | sed -n '2,1p' 2>&1)
    test_print_trc "Total dram power for socket$i is: $dram_total watts"
    dram_watts=$(echo "$tc_out" | awk '{print $7}' | sed '/^$/d' | sed -n '3,1p' 2>&1)
    test_print_trc "DRAM power for socket$i is: $dram_watts watts"

    #Judge each pkg and dram power with total pkg and dram
    #The error range is 20% of total
    pkg_delta=$(echo "scale=2; 20*$pkg_total/100" | bc)
    pkg_total_half=$(echo "scale=2; 50*$pkg_total/100" | bc)
    pkg_total_low=$(echo "scale=2; $pkg_total_half-$pkg_delta" | bc)
    test_print_trc "CPU Pkg power expected low value: $pkg_total_low watts"
    pkg_total_high=$(echo "scale=2; $pkg_total_half+$pkg_delta" | bc)
    test_print_trc "CPU Pkg power expected high value: $pkg_total_high watts"
    if [[ $(echo "$pkg_watts < $pkg_total_high" | bc) -eq 1 ]] &&
      [[ $(echo "$pkg_watts > $pkg_total_low" | bc) -eq 1 ]]; then
      test_print_trc "CPU Pkg power is in scope for socket$i: $pkg_watts watts"
    elif [[ $(echo "$pkg_watts == 0" | bc) -eq 1 ]]; then
      die "CPU Pkg power shows 0 for socket$i"
    else
      die "CPU Pkg power for socket$i is beyond 20% of half pkg power: $pkg_watts watts"
    fi

    dram_delta=$(echo "scale=2; 20*$dram_total/100" | bc)
    dram_total_half=$(echo "scale=2; 50*$dram_total/100" | bc)
    dram_total_low=$(echo "scale=2; $dram_total_half-$dram_delta" | bc)
    test_print_trc "DRAM power expected low value: $dram_total_low watts"
    dram_total_high=$(echo "scale=2; $dram_total_half+$dram_delta" | bc)
    test_print_trc "DRAM power expected high value: $dram_total_high watts"
    if [[ $(echo "$dram_watts < $dram_total_high" | bc) -eq 1 ]] &&
      [[ $(echo "$dram_watts > $dram_total_low" | bc) -eq 1 ]]; then
      test_print_trc "DRAM power is in scope for socket$i: $dram_watts watts"
    elif [[ $(echo "$dram_watts == 0" | bc) -eq 1 ]]; then
      die "DRAM power shows 0 for socket$i"
    else
      die "DRAM power for socket$i is beyond 20% of half dram power: $dram_watts watts"
    fi
  done
}

multiple_packages_idle_compare() {
  local sockets=""
  local node_cpus=""

  sockets=$(lscpu | grep Socket | awk -F ":" '{print $2}')
  [[ -n "$sockets" ]] || block_test "Socket number is not available."
  [[ "$sockets" -eq 1 ]] && block_test "The platform only supports 1 socket."

  for ((i = 0; i < sockets; i++)); do
    #Get each socket Pkg power power in watts unit when idle
    #Then compare with total Pkg power
    node_cpus=$(lscpu | grep "NUMA node$i CPU" | sed 's/ //g' | awk -F ":" '{print $2}')
    test_print_trc "Node CPUs for socket$i are: $node_cpus"

    node_cpu_start=$(echo "$node_cpus" | cut -d "-" -f 1 2>&1)
    test_print_trc "The 1st CPU of Node$i: $node_cpu_start"

    #Check CPU Pkg power from turbostat tool
    tc_out=$("$PSTATE_TOOL/turbostat" -q -c "$node_cpu_start" --show Package,Core,CPU,power -i 1 sleep 20 2>&1)
    [[ -n "$tc_out" ]] || block_test "Did not get turbostat log"
    test_print_trc "Turbostat log when sockets$i idle: $tc_out"
    pkg_total=$(echo "$tc_out" | awk '{print $6}' | sed '/^$/d' | sed -n '2,1p' 2>&1)
    test_print_trc "Total pkg power for socket$i is: $pkg_total watts"
    pkg_watts=$(echo "$tc_out" | awk '{print $6}' | sed '/^$/d' | sed -n '3,1p' 2>&1)
    test_print_trc "CPU Package power for socket$i is: $pkg_watts watts"

    #Judge each pkg power with total pkg
    #The error range is 20% of total
    pkg_delta=$(echo "scale=2; 20*$pkg_total/100" | bc)
    pkg_total_half=$(echo "scale=2; 50*$pkg_total/100" | bc)
    pkg_total_low=$(echo "scale=2; $pkg_total_half-$pkg_delta" | bc)
    test_print_trc "CPU Pkg power expected low value: $pkg_total_low watts"
    pkg_total_high=$(echo "scale=2; $pkg_total_half+$pkg_delta" | bc)
    test_print_trc "CPU Pkg power expected high value: $pkg_total_high watts"
    if [[ $(echo "$pkg_watts < $pkg_total_high" | bc) -eq 1 ]] &&
      [[ $(echo "$pkg_watts > $pkg_total_low" | bc) -eq 1 ]]; then
      test_print_trc "CPU Pkg power is in scope for socket$i: $pkg_watts watts"
    elif [[ $(echo "$pkg_watts == 0" | bc) -eq 1 ]]; then
      die "CPU Pkg power shows 0 for socket$i"
    else
      die "CPU Pkg power for socket$i is beyond 20% of half pkg power: $pkg_watts watts"
    fi
  done
}

enable_rapl_control() {
  domain_num=$(ls /sys/class/powercap/ | grep -c intel-rapl:)
  [[ -n "$domain_num" ]] || block_test "intel-rapl sysfs is not available."

  for ((i = 1; i <= domain_num; i++)); do
    domain_name=$(ls /sys/class/powercap/ | grep intel-rapl: | sed -n "$i,1p")
    # Change each domain's power limit setting then enable the RAPL control

    default_power_limit=$(cat /sys/class/powercap/"$domain_name"/constraint_0_max_power_uw)
    if [[ "$default_power_limit" -eq 0 ]]; then
      continue
    else
      test_power_limit=$(("$default_power_limit" - 2000000))
      test_print_trc "Test power limit is: $test_power_limit uw"
    fi
    do_cmd "echo $test_power_limit > /sys/class/powercap/$domain_name/constraint_0_power_limit_uw"
    do_cmd "echo 1 > /sys/class/powercap/$domain_name/enabled"
    enabled_knob=$(cat /sys/class/powercap/"$domain_name"/enabled)
    # Recover the default constraint_0_power_limit_uw setting
    do_cmd "echo $default_power_limit > /sys/class/powercap/$domain_name/constraint_0_power_limit_uw"
    if [[ "$enabled_knob" -eq 1 ]]; then
      test_print_trc "Enabling RAPL control for $domain_name is PASS after power limit change."
    else
      die "Enabling RAPL control for $domain_name is Fail after power limit change"
    fi
  done
}

rapl_package_offline() {
  local sockets=""

  sockets=$(lscpu | grep Socket | awk -F ":" '{print $2}')
  [[ -n "$sockets" ]] || block_test "Socket number is not available."
  [[ "$sockets" -eq 1 ]] && block_test "The platform only supports 1 socket."

  rapl_domains_num=$(grep . /sys/class/powercap/intel-rapl/intel-rapl:*/name | wc -l)
  rapl_domains_name=$(cat /sys/class/powercap/intel-rapl/intel-rapl:*/name)
  test_print_trc "Initial rapl domain names:$rapl_domains_name"

  last_cpu=$(lscpu | grep "On-line CPU(s) list" | awk -F "-" '{print $3}')

  node0_2nd=$(awk -F - '{print $2}' "$CPU_SYSFS_PATH"/cpu0/topology/package_cpus_list |
    awk -F "," '{print $1}')
  test_print_trc "Node0_2nd: $node0_2nd"
  node0_3rd=$(awk -F - '{print $2}' "$CPU_SYSFS_PATH"/cpu0/topology/package_cpus_list |
    awk -F "," '{print $2}')
  test_print_trc "Node0_3rd: $node0_3rd"
  node0_4th=$(awk -F - '{print $NF}' "$CPU_SYSFS_PATH"/cpu0/topology/package_cpus_list)
  test_print_trc "Node0_4th: $node0_4th"

  node1_1st=$(awk -F - '{print $1}' "$CPU_SYSFS_PATH"/cpu"$last_cpu"/topology/package_cpus_list)
  test_print_trc "Node1_1st: $node1_1st"
  node1_2nd=$(awk -F - '{print $2}' "$CPU_SYSFS_PATH"/cpu"$last_cpu"/topology/package_cpus_list |
    awk -F "," '{print $1}')
  test_print_trc "Node1_2nd: $node1_2nd"
  node1_3rd=$(awk -F - '{print $2}' "$CPU_SYSFS_PATH"/cpu"$last_cpu"/topology/package_cpus_list |
    awk -F "," '{print $2}')
  test_print_trc "Node1_3rd: $node1_3rd"

  test_print_trc "Offline package 0 CPUs:"
  # Disable package0 CPUs:
  for ((i = 1; i <= node0_2nd; i++)); do
    do_cmd "echo 0 > /sys/devices/system/cpu/cpu$i/online"
  done
  for ((i = node0_3rd; i <= node0_4th; i++)); do
    do_cmd "echo 0 > /sys/devices/system/cpu/cpu$i/online"
  done
  sleep 1
  rapl_domains_pkg_0_disable=$(grep . /sys/class/powercap/intel-rapl/intel-rapl:*/name | wc -l)
  rapl_domains_name_pkg_0_disable=$(cat /sys/class/powercap/intel-rapl/intel-rapl:*/name)
  test_print_trc "RAPL domain names after package 0 disable:$rapl_domains_name_pkg_0_disable"
  # Enable package0 CPUs:
  for ((i = 1; i <= node0_2nd; i++)); do
    do_cmd "echo 1 > /sys/devices/system/cpu/cpu$i/online"
  done
  for ((i = node0_3rd; i <= node0_4th; i++)); do
    do_cmd "echo 1 > /sys/devices/system/cpu/cpu$i/online"
  done
  if [[ $rapl_domains_num -eq $rapl_domains_pkg_0_disable ]]; then
    test_print_trc "RAPL domains are expected after package0 CPUs disable."
  else
    die "RAPL domains is not expected after package0 CPUs disable."
  fi

  test_print_trc "Offline package 1 CPUs:"
  # Disable package1 CPUs:
  for ((i = node1_1st; i <= node1_2nd; i++)); do
    do_cmd "echo 0 > /sys/devices/system/cpu/cpu$i/online"
  done
  for ((i = node1_3rd; i <= last_cpu; i++)); do
    do_cmd "echo 0 > /sys/devices/system/cpu/cpu$i/online"
  done
  sleep 1
  rapl_domains_pkg_0_disable=$(grep . /sys/class/powercap/intel-rapl/intel-rapl:*/name | wc -l)
  rapl_domains_name_pkg_0_disable=$(cat /sys/class/powercap/intel-rapl/intel-rapl:*/name)
  test_print_trc "RAPL domain names after package 1 disable:$rapl_domains_name_pkg_0_disable"
  # Enable package1 CPUs:
  for ((i = node1_1st; i <= node1_2nd; i++)); do
    do_cmd "echo 1 > /sys/devices/system/cpu/cpu$i/online"
  done
  for ((i = node1_3rd; i <= last_cpu; i++)); do
    do_cmd "echo 1 > /sys/devices/system/cpu/cpu$i/online"
  done
  if [[ $rapl_domains_num -eq $rapl_domains_pkg_0_disable ]]; then
    test_print_trc "RAPL domains are expected after package1 CPUs disable."
  else
    die "RAPL domains is not expected after package1 CPUs disable."
  fi
}

# Function to verify if 0x601 (PL4) will change after RAPL control enable and disable
# Also PL1/PL2 power limit value change will not impact PL4
# Meanwhile judge if RAPL control disable expected or not
# PL1 is mapping constraint_0 (long term)
# PL2 is mapping constraint_1 (short term)
# PL4 is mapping constraint_2 (peak power)
# Linux does not support PL3
rapl_control_enable_disable_pl() {
  local pl_id=$1

  domain_num=$(ls /sys/class/powercap/ | grep -c intel-rapl:)
  [[ -n "$domain_num" ]] || block_test "intel-rapl sysfs is not available."

  for ((i = 1; i <= domain_num; i++)); do
    domain_name=$(ls /sys/class/powercap/ | grep intel-rapl: | sed -n "$i,1p")
    test_print_trc "------Testing domain name: $domain_name------"

    # Read default PL4, PL1, PL2 value
    pl4_default=$(rdmsr 0x601)
    [[ -n "$pl4_default" ]] && test_print_trc "PL4 value before RAPL Control enable and disable: $pl4_default"

    pl1_default=$(cat /sys/class/powercap/"$domain_name"/constraint_0_max_power_uw)
    [[ -n "$pl1_default" ]] && test_print_trc "PL1 value before RAPL Control enable and disable: $pl1_default"

    pl2_default=$(cat /sys/class/powercap/"$domain_name"/constraint_1_max_power_uw)
    [[ -n "$pl2_default" ]] && test_print_trc "PL2 value before RAPL Control enable and disable: $pl2_default"

    # Enable RAPL control
    do_cmd "echo 1 > /sys/class/powercap/$domain_name/enabled"
    enabled_knob=$(cat /sys/class/powercap/"$domain_name"/enabled)
    if [[ "$enabled_knob" -eq 1 ]]; then
      test_print_trc "Enabling RAPL control for $domain_name is PASS"
    else
      die "Enabling RAPL control for $domain_name is Fail"
    fi

    # Change each domain's $pl_id power limit setting then enable the RAPL control
    default_power_limit=$(cat /sys/class/powercap/"$domain_name"/constraint_"$pl_id"_max_power_uw)
    [[ -n "$default_power_limit" ]] && test_print_trc "Domain $domain_name's constraint_'$pl_id'_max_power_uw \
default value is: $default_power_limit"
    # Use package PL1 to judge SUT is client or Server
    # Usually the largest PL1 for Client Desktop is 125 Watts, Client mobile PL1 will be 9/15/45/65 Watts etc.
    pl1_edge=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_max_power_uw)
    [[ -n "$pl1_edge" ]] || block_test "Package PL1 power value is not available."
    if [[ $pl1_edge -le 125000000 ]]; then
      test_print_trc "The SUT should be client:"
      if [[ "$default_power_limit" -eq 0 ]]; then
        test_power_limit=$(("$default_power_limit" + 10000000))
        test_print_trc "Test power limit is: $test_power_limit uw"
      else
        test_power_limit=$(("$default_power_limit" - 5000000))
        [[ $test_power_limit -lt 0 ]] && test_power_limit=0
        test_print_trc "Test power limit is: $test_power_limit uw"
      fi
    else
      test_print_trc "The SUT should be server:"
      if [[ "$default_power_limit" -eq 0 ]]; then
        test_power_limit=$(("$default_power_limit" + 100000000))
        test_print_trc "Test power limit is: $test_power_limit uw"
      else
        test_power_limit=$(("$default_power_limit" - 100000000))
        [[ $test_power_limit -lt 0 ]] && test_power_limit=0
        test_print_trc "Test power limit is: $test_power_limit uw"
      fi
    fi
    [[ -d /sys/class/powercap/"$domain_name"/constraint_"$pl_id"_power_limit_uw ]] &&
      echo "$test_power_limit" >/sys/class/powercap/"$domain_name"/constraint_"$pl_id"_power_limit_uw

    # Recover the default constraint_$pl_id_power_limit_uw setting
    [[ -d /sys/class/powercap/"$domain_name"/constraint_"$pl_id"_power_limit_uw ]] &&
      echo "$default_power_limit" >/sys/class/powercap/"$domain_name"/constraint_"$pl_id"_power_limit_uw

    # Disable RAPL control
    do_cmd "echo 0 > /sys/class/powercap/$domain_name/enabled"
    disabled_knob=$(cat /sys/class/powercap/"$domain_name"/enabled)

    # Get Enable power limit value by reading 0x610 bit 15
    enable_power_limit=$(rdmsr 0x610 -f 15:15)
    test_print_trc "Enable RAPL Limit shows: $enable_power_limit"

    # Check if RAPL control disable works as expected
    if [[ $disabled_knob -eq 0 ]]; then
      test_print_trc "RAPL Control is not expected to be set to 0."
    elif [[ $enable_power_limit -eq 0 ]]; then
      die "System allows to disable PL, while writing RAPL control disable fail."
    else
      # Trying to manually write 0x610 bit 15 to 0
      # If it can't be set then you are OK as system is not allowing to disable PL1.
      # But wrmsr can write bit 15 to 0 and enabled is still 1, then this is a bug
      change_bit15=$(wrmsr 0x610 $(($(rdmsr -d 0x610) & ~(1 << 15))))
      test_print_trc "Verify if 0x610 bit 15 can be set to 0: $change_bit15"
      read_bit15=$(rdmsr 0x610 -f 15:15)
      if [[ $read_bit15 -eq 0 ]]; then
        die "0x610 bit 15 can change to 0, while RAPL control disable still 1."
      else
        test_print_trc "0x610 bit 15 cannot change to 0, so RAPL control enable shows 1 is expected."
      fi
    fi

    # Check if PL4 value changed after RAPL control enable and disable
    pl4_test=$(rdmsr 0x601)
    test_print_trc "PL4 value after RAPL Control enable and disable: $pl4_test"
    if [[ "$pl4_test" == "$pl4_default" ]]; then
      test_print_trc "PL4 shows the same value as default after RAPL Control enable and disable"
    else
      die "PL4 value changed after RAPL Control enable and disable: $pl4_test"
    fi

    # Check if PL1 value changed after RAPL control enable and disable
    pl1_recovered=$(cat /sys/class/powercap/"$domain_name"/constraint_0_max_power_uw)
    if [[ -z "$pl1_default" ]]; then
      test_print_trc "constraint_0_max_power_uw is not available for $domain_name"
    elif [[ "$pl1_recovered" == "$pl1_default" ]]; then
      test_print_trc "PL1 shows the same value as default after RAPL Control enable and disable"
    else
      die "PL1 value changed after RAPL Control enable and disable: $pl1_recovered"
    fi

    # Check if PL2 value changed after RAPL control enable and disable
    pl2_recovered=$(cat /sys/class/powercap/"$domain_name"/constraint_1_max_power_uw)
    if [[ -z "$pl2_default" ]]; then
      test_print_trc "constraint_1_max_power_uw is not available for $domain_name"
    elif [[ "$pl2_recovered" == "$pl2_default" ]]; then
      test_print_trc "PL2 shows the same value as default after RAPL Control enable and disable"
    else
      die "PL2 value changed after RAPL Control enable and disable: $pl2_recovered"
    fi

    # Re-enable RAPL control
    do_cmd "echo 1 > /sys/class/powercap/$domain_name/enabled"

  done
}

# Function to change 0x601 (PL4) value and RAPL control enable and disable
# Meanwhile judge if RAPL control disable expected or not
rapl_control_enable_disable_pl4() {
  local test_pl4=$1

  domain_num=$(ls /sys/class/powercap/ | grep -c intel-rapl:)
  [[ -n "$domain_num" ]] || block_test "intel-rapl sysfs is not available."

  for ((i = 1; i <= domain_num; i++)); do
    domain_name=$(ls /sys/class/powercap/ | grep intel-rapl: | sed -n "$i,1p")
    test_print_trc "------Testing domain name: $domain_name------"
    ori_pl4=$(rdmsr 0x601)

    # Read default PL4, PL1, PL2 value
    pl4_default=$(cat /sys/class/powercap/"$domain_name"/constraint_2_max_power_uw)
    [[ -n "$pl4_default" ]] && test_print_trc "PL4 value before RAPL Control enable and disable: $pl4_default"

    pl1_default=$(cat /sys/class/powercap/"$domain_name"/constraint_0_max_power_uw)
    [[ -n "$pl1_default" ]] && test_print_trc "PL1 value before RAPL Control enable and disable: $pl1_default"

    pl2_default=$(cat /sys/class/powercap/"$domain_name"/constraint_1_max_power_uw)
    [[ -n "$pl2_default" ]] && test_print_trc "PL2 value before RAPL Control enable and disable: $pl2_default"

    # Enable RAPL control
    do_cmd "echo 1 > /sys/class/powercap/$domain_name/enabled"
    enabled_knob=$(cat /sys/class/powercap/"$domain_name"/enabled)
    if [[ "$enabled_knob" -eq 1 ]]; then
      test_print_trc "Enabling RAPL control for $domain_name is PASS"
    else
      die "Enabling RAPL control for $domain_name is Fail"
    fi

    # Write a low value to 0x601 then enable the RAPL control
    # Only cover on Client platform
    # Low value will be written 0
    # High value will be written
    do_cmd "wrmsr 0x601 $test_pl4"

    # Disable RAPL control
    do_cmd "echo 0 > /sys/class/powercap/$domain_name/enabled"
    disabled_knob=$(cat /sys/class/powercap/"$domain_name"/enabled)

    # Get Enable power limit value by reading 0x610 bit 15
    enable_power_limit=$(rdmsr 0x610 -f 15:15)
    test_print_trc "Enable RAPL Limit shows: $enable_power_limit"

    # Check if RAPL control disable works as expected
    if [[ $disabled_knob -eq 0 ]]; then
      test_print_trc "RAPL Control is not expected to be set to 0, so 1 is PASS."
    elif [[ $enable_power_limit -eq 0 ]]; then
      die "System allows to disable PL, while writing RAPL control disable fail."
    else
      # Trying to manually write 0x610 bit 15 to 0
      # If it can't be set then you are OK as system is not allowing to disable PL1.
      # But wrmsr can write bit 15 to 0 and enabled is still 1, then this is a bug
      change_bit15=$(wrmsr 0x610 $(($(rdmsr -d 0x610) & ~(1 << 15))))
      test_print_trc "Verify if 0x610 bit 15 can be set to 0: $change_bit15"
      read_bit15=$(rdmsr 0x610 -f 15:15)
      if [[ $read_bit15 -eq 0 ]]; then
        die "0x610 bit 15 can change to 0, while RAPL control disable still 1."
      else
        test_print_trc "0x610 bit 15 cannot change to 0, so RAPL control enable shows 1 is expected."
      fi
    fi

    # Check if PL4 value changed after RAPL control enable and disable
    pl4_recovered=$(cat /sys/class/powercap/"$domain_name"/constraint_2_max_power_uw)
    test_print_trc "PL4 value after RAPL Control enable and disable: $pl4_recovered"
    if [[ -z "$pl4_recovered" ]]; then
      test_print_trc "constraint_2_max_power_uw is not available for $domain_name"
    elif [[ "$pl4_recovered" == "$pl4_default" ]]; then
      test_print_trc "PL4 shows the same value as default after RAPL Control enable and disable"
    else
      die "PL4 value changed after RAPL Control enable and disable: $pl4_recovered"
    fi

    # Check if PL1 value changed after RAPL control enable and disable
    pl1_recovered=$(cat /sys/class/powercap/"$domain_name"/constraint_0_max_power_uw)
    if [[ -z "$pl1_default" ]]; then
      test_print_trc "constraint_0_max_power_uw is not available for $domain_name"
    elif [[ "$pl1_recovered" == "$pl1_default" ]]; then
      test_print_trc "PL1 value after RAPL Control enable and disable:$pl1_recovered"
      test_print_trc "PL1 shows the same value as default after RAPL Control enable and disable"
    else
      die "PL1 value changed after RAPL Control enable and disable: $pl1_recovered"
    fi

    # Check if PL2 value changed after RAPL control enable and disable
    pl2_recovered=$(cat /sys/class/powercap/"$domain_name"/constraint_1_max_power_uw)
    if [[ -z "$pl2_default" ]]; then
      test_print_trc "constraint_1_max_power_uw is not available for $domain_name"
    elif [[ "$pl2_recovered" == "$pl2_default" ]]; then
      test_print_trc "PL2 value after RAPL Control enable and disable:$pl2_recovered"
      test_print_trc "PL2 shows the same value as default after RAPL Control enable and disable"
    else
      die "PL2 value changed after RAPL Control enable and disable: $pl2_recovered"
    fi

    # Re-enable RAPL control
    do_cmd "echo 1 > /sys/class/powercap/$domain_name/enabled"

    # Re-cover the 0x601 original setting
    do_cmd "wrmsr 0x601 $ori_pl4"

  done
}

dmesg_check() {
  local dmesg_log

  dmesg_log=$(extract_case_dmesg)

  if echo "$dmesg_log" | grep -iE "fail|Call Trace|error"; then
    die "Kernel dmesg shows failure: $dmesg_log"
  else
    test_print_trc "Kernel dmesg when case running shows Okay."
  fi
}

rapl_perf_compare_test() {
  case $TEST_SCENARIO in
  legacy_sysfs_perf_name_compare)
    rapl_perf_name_compare intel-rapl
    ;;
  tpmi_sysfs_perf_name_compare)
    rapl_perf_name_compare intel-rapl-tpmi
    ;;
  legacy_sysfs_perf_energy_compare_workload_server)
    rapl_perf_energy_compare intel-rapl pkg dram
    ;;
  legacy_sysfs_perf_energy_compare_workload_client)
    rapl_perf_energy_compare intel-rapl pkg uncore
    ;;
  legacy_sysfs_turbostat_energy_compare_workload_server)
    rapl_turbostat_energy_compare intel-rapl pkg dram
    ;;
  legacy_sysfs_turbostat_energy_compare_workload_client)
    rapl_turbostat_energy_compare intel-rapl pkg uncore
    ;;
  tpmi_sysfs_perf_energy_compare_workload_server)
    rapl_perf_energy_compare intel-rapl-tpmi pkg dram
    ;;
  tpmi_sysfs_turbostat_energy_compare_workload_server)
    rapl_turbostat_energy_compare intel-rapl-tpmi pkg dram
    ;;
  multiple_packages_stress_power_compare)
    multiple_packages_stress_compare
    ;;
  multiple_packages_idle_power_compare)
    multiple_packages_idle_compare
    ;;
  enable_rapl_control_after_power_limit_change)
    enable_rapl_control
    ;;
  # This case only supports on GNR and further TPMI based server platforms
  verify_rapl_domains_package_offline)
    rapl_package_offline
    ;;
  rapl_control_enable_disable_pl1)
    rapl_control_enable_disable_pl 0
    ;;
  rapl_control_enable_disable_pl2)
    rapl_control_enable_disable_pl 1
    ;;
  rapl_control_enable_disable_pl4)
    rapl_control_enable_disable_pl 2
    ;;
  rapl_control_pl4_low_value)
    rapl_control_enable_disable_pl4 0
    ;;
  rapl_control_pl4_high_value)
    rapl_control_enable_disable_pl4 0x500
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

rapl_perf_compare_test
