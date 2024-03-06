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
# File:         rapl_common.sh
#
# Description:  Common file for Intel RAPL Test
#
# Authors:      Jerry C. Wang - jerry.c.wang@intel.com
#
# History:      Aug 01 2017 - Created - Jerry C. Wang
#                 - Add MSR registers
#                 - Read and Write MSR
#               Aug 07 2017 - Modified - Jerry C. Wang
#                 - Add RAPL Units (Time, Energy & Power)
#                 - Add RAPL init function
#
#

source "common.sh"
PSTATE_TOOL="$LTPROOT/testcases/bin/ddt_intel/powermgr"
RAPL_MODULE="intel_rapl_msr"
RAPL_SYSFS_PATH="/sys/class/powercap"

RAPL_TIME_UNIT=0   #Micro-second (us)
RAPL_ENERGY_UNIT=0 #Micro-Joules (uJ)
RAPL_POWER_UNIT=0  #Watts

MSR_RAPL_POWER_UNIT="0x606"

MSR_PKG_POWER_LIMIT="0x610"
MSR_PKG_ENERGY_STATUS="0x611"
MSR_PKG_POWER_INFO="0x614"
MSR_PKG_PERF_STATUS="0x613"

MSR_DRAM_POWER_LIMIT="0x618"
MSR_DRAM_ENERGY_STATUS="0x619"
MSR_DRAM_PERF_STATUS="0x61B"
MSR_DRAM_POWER_INFO="0x61C"

MSR_PP0_POWER_LIMIT="0x638"
MSR_PP0_ENERGY_STATUS="0x639"
MSR_PP0_POLICY="0x63A"
MSR_PP0_PERF_STATUS="0x63B"

MSR_PP1_POWER_LIMIT="0x640"
MSR_PP1_ENERGY_STATUS="0x641"
MSR_PP1_POLICY="0x642"

CPU_LOAD="fspin"
CPU_LOAD_ARG="-i 10"
GPU_LOAD="glxgears"
GPU_LOAD_ARG="-display :1"
DRAM_LOAD="stress"

NUM_CPU_PACKAGES=$(lscpu | grep "Socket(s)" | awk '{print $2}')
CPU_SYSFS="/sys/devices/system/cpu"
declare -A CPU_TOPOLOGY

: "${RAPL_DRAM_SUPPORT:="false"}"
: "${RAPL_GRAPHIC_SUPPORT:="false"}"

MSR_PLATFORM_ENERGY_STATUS="0X64D"

# Read value from MSR
# Input:
#     $1: Bit range to be read
#     $2: MSR Address
#     $3: (Optional) Select processor - default 0
# Output:
#   MSR_VAL: Value obtain from MSR
read_msr() {
  local fld=$1
  local reg=$2
  local cpu=$3

  : "${cpu:=0}"

  [[ -z $fld || $fld =~ [0-9]+:[0-9]+ ]] || die "Incorrect field format!"
  [[ -n $reg ]] || die "Unable to read register information"

  MSR_VAL=""
  is_kmodule_builtin msr || {
    load_unload_module.sh -c -d msr ||
      do_cmd "load_unload_module.sh -l -d msr"
  }

  if [[ $fld == "" ]]; then
    MSR_VAL=$(rdmsr -p "$cpu" "$reg")
  else
    MSR_VAL=$(rdmsr -p "$cpu" -f "$fld" "$reg")
  fi

  [[ -n $MSR_VAL ]] || die "Unable to read data from MSR $reg!"
  test_print_trc "Read MSR \"$reg\": value = \"$MSR_VAL\""
}

# Write value to MSR
# Input:
#     $1: ["h:l"] Bit range to be written into MSR
#     $2: MSR Address
#     $3: Value to be written (Hex: Start with 0x, Dec: Numbers)
#     $4: (Optional) Select processor - default 0
write_msr() {
  local fld=$1
  local reg=$2
  local val=$3
  local cpu=$4

  : "${cpu:=0}"

  [[ $# -ge 3 ]] || die "Invalid input parameters!"

  # Check input value
  [[ $val =~ ^0x[0-9a-fA-F]+$ || $val =~ ^[0-9]+$ ]] || die "Invalid input value!"

  # Prepare input value in binary form
  [[ $fld == "" ]] && fld="0:63"
  st=$(echo "$fld" | cut -d":" -f2)
  en=$(echo "$fld" | cut -d":" -f1)
  bit_range=$((en - st + 1))
  [[ $bit_range -lt 0 ]] && die "Bit range is incorrect!"

  bin_val=$(perl -e "printf \"%b\", $val")
  [[ ${#bin_val} -le $bit_range ]] || die "Input value is greater the field range!"

  # Add zero padding on input binary value
  while [[ ${#bin_val} -lt $bit_range ]]; do
    bin_val="0$bin_val"
  done

  bin_val=$(echo "$bin_val" | rev)

  # Read register value and overwrite input value to form new register value
  read_msr "" "$reg"
  reg_val=$(perl -e "printf \"%064b\", 0x$MSR_VAL" | rev)
  new_val=$(echo "${reg_val:0:st}""$bin_val""${reg_val:$((st + ${#bin_val}))}" | rev)
  new_val=$(perl -e "printf \"%016x\n\", $((2#$new_val))")

  # write back to the register
  do_cmd "wrmsr -p \"$cpu\" \"$reg\" 0x$new_val"
}

# Read total energy comsumption from MSR
# Input:
#     $1: Select Processor
#     $2: Select Domain
# Output:
#   CUR_ENERGY: Current energy obtain from MSR
get_total_energy_consumed_msr() {
  local cpu=$1
  local domain=$2
  local reg=""

  [[ $# -eq 2 ]] || die "Invalid number of parameters - $#"
  [[ $RAPL_ENERGY_UNIT != 0 ]] || read_rapl_unit

  domain=$(echo "$domain" | awk '{print tolower($0)}')
  case $domain in
  pkg)
    reg=$MSR_PKG_ENERGY_STATUS
    ;;
  core)
    reg=$MSR_PP0_ENERGY_STATUS
    ;;
  uncore)
    reg=$MSR_PP1_ENERGY_STATUS
    ;;
  dram)
    reg=$MSR_DRAM_ENERGY_STATUS
    ;;
  *)
    die "Invalid Power Domain"
    ;;
  esac

  read_msr "31:0" "$reg" "$cpu"
  CUR_ENERGY=$(echo "$((16#$MSR_VAL)) * $RAPL_ENERGY_UNIT" | bc)
  CUR_ENERGY=${CUR_ENERGY%.*}
  test_print_trc "Total $domain Energy: $CUR_ENERGY uj"
}

# Read total energy comsumption from SYSFS
# Input:
#     $1: Select Package
#     $2: Select Domain
# Output:
#   CUR_ENERY: Current energy obtained from SYSFS
get_total_energy_consumed_sysfs() {
  local pkg=$1
  local domain=$2

  domain=$(echo "$domain" | awk '{print tolower($0)}')
  get_domain_path "$pkg" "$domain"

  local energy_path="$DOMAIN_PATH/energy_uj"
  [[ -f $energy_path ]] || die "Unable to find the energy data in SYSFS"
  CUR_ENERGY=$(cat "$energy_path")
  test_print_trc "Package-$pkg - Total $domain Energy: $CUR_ENERGY uj"
}

# Calculate power consumption over a set period
# Input:
#     $1: Energy measurement method (MSR or SYSFS)
#     $2: Select CPU package
#     $3: Select power domain
#     $4: (Optional) Measurement duration (Default: 15s)
get_power_consumed() {
  local method=$1
  local pkg=$2
  local domain=$3
  local duration=$4

  : "${duration:=15}"

  [[ $# -ge 3 ]] || die "Invalid parameters!"

  method=$(echo "$method" | awk '{print tolower($0)}')
  domain=$(echo "$domain" | awk '{print tolower($0)}')

  [[ $pkg -le $NUM_CPU_PACKAGES ]] || die "Package number is out of range!"
  [[ $domain =~ (pkg|core|uncore|dram) ]] || die "Invalid power domain!"

  case $method in
  msr)
    cpu=$(echo "${CPU_TOPOLOGY[$pkg]}" | cut -d" " -f1)
    get_total_energy_consumed_msr "$cpu" "$domain"
    energy_b4=$CUR_ENERGY

    sleep "$duration"

    get_total_energy_consumed_msr "$cpu" "$domain"
    energy_af=$CUR_ENERGY
    ;;
  sysfs)
    get_total_energy_consumed_sysfs "$pkg" "$domain"
    energy_b4=$CUR_ENERGY

    sleep "$duration"

    get_total_energy_consumed_sysfs "$pkg" "$domain"
    energy_af=$CUR_ENERGY
    ;;
  turbostat)
    which turbostat &>/dev/null || die "turbostat tool does not exist"
    columns="CPU,PkgWatt,CorWatt,GFXWatt,RAMWatt"
    do_cmd "$PSTATE_TOOL/turbostat --quiet --show $columns -o ts.log sleep $duration"
    test_print_trc "Turbostat log:"
    cat ts.log

    res=$(grep -e "^-" ts.log | awk '{print $2,$3,$4,$5}' | head -1)
    test_print_trc "Supported Domain zone columns from turbostat log: $res"
    [[ -n $res ]] || die "No result is obtained from turbostat!"

    case $domain in
    pkg)
      CUR_POWER=$(echo "$res" | awk '{print $1}')
      ;;
    core)
      CUR_POWER=$(echo "$res" | awk '{print $2}')
      ;;
    uncore)
      CUR_POWER=$(echo "$res" | awk '{print $3}')
      ;;
    dram)
      CUR_POWER=$(echo "$res" | awk '{print $4}')
      ;;
    *)
      die "Invalid Power Domain!"
      ;;
    esac
    return 0
    ;;
  *)
    die "Invalid Measurement Method!"
    ;;
  esac
  CUR_POWER=$(echo "scale=6;($energy_af - $energy_b4) / $duration / 10^6" | bc)
  test_print_trc "Package-$pkg $domain Power = $CUR_POWER Watts"
}

get_power_consumed_server() {
  local method=$1
  local pkg=$2
  local domain=$3
  local duration=$4

  : "${duration:=15}"

  [[ $# -ge 3 ]] || die "Invalid parameters!"

  method=$(echo "$method" | awk '{print tolower($0)}')
  domain=$(echo "$domain" | awk '{print tolower($0)}')

  [[ $pkg -le $NUM_CPU_PACKAGES ]] || die "Package number is out of range!"
  [[ $domain =~ (pkg|dram) ]] || die "Invalid power domain!"

  case $method in
  msr)
    cpu=$(echo "${CPU_TOPOLOGY[$pkg]}" | cut -d" " -f1)
    get_total_energy_consumed_msr "$cpu" "$domain"
    energy_b4=$CUR_ENERGY

    sleep "$duration"

    get_total_energy_consumed_msr "$cpu" "$domain"
    energy_af=$CUR_ENERGY
    ;;
  sysfs)
    get_total_energy_consumed_sysfs "$pkg" "$domain"
    energy_b4=$CUR_ENERGY

    sleep "$duration"

    get_total_energy_consumed_sysfs "$pkg" "$domain"
    energy_af=$CUR_ENERGY
    ;;
  turbostat)
    which turbostat &>/dev/null || die "turbostat tool does not exist"
    columns="CPU,PkgWatt,RAMWatt"
    do_cmd "$PSTATE_TOOL/turbostat --quiet --show $columns -o ts.log sleep $duration"
    test_print_trc "Turbostat log:"
    cat ts.log

    res=$(grep -e "^-" ts.log | awk '{print $2,$3}' | head -1)
    test_print_trc "Supported Domain zone columns from turbostat log: $res"
    [[ -n $res ]] || die "No result is obtained from turbostat!"

    case $domain in
    pkg)
      CUR_POWER=$(echo "$res" | awk '{print $1}')
      test_print_trc "Pkg current power: $CUR_POWER"
      ;;
    dram)
      CUR_POWER=$(echo "$res" | awk '{print $2}')
      test_print_trc "Dram current power: $CUR_POWER"
      ;;
    *)
      die "Invalid Power Domain!"
      ;;
    esac
    return 0
    ;;
  *)
    die "Invalid Measurement Method!"
    ;;
  esac
  CUR_POWER=$(echo "scale=6;($energy_af - $energy_b4) / $duration / 10^6" | bc)
  test_print_trc "Package-$pkg $domain Power = $CUR_POWER Watts"
}

# Get the corresponding domain SYSFS path
# Input:
#     $1: Select CPU Package
#     $2: Select Power Domain
# Output:
#     DOMAIN_PATH: SYSFS PATH for the select domain
get_domain_path() {
  local pkg=$1
  local domain=$2
  local name=""

  DOMAIN_PATH="$RAPL_SYSFS_PATH/intel-rapl:$pkg"

  [[ -d $DOMAIN_PATH ]] || die "RAPL PKG Path does not exist!"

  domain=$(echo "$domain" | awk '{print tolower($0)}')

  case $domain in
  pkg)
    name="package-$pkg"
    ;;
  core)
    DOMAIN_PATH="$DOMAIN_PATH:0"
    name="core"
    ;;
  uncore)
    DOMAIN_PATH="$DOMAIN_PATH:1"
    name="uncore"
    ;;
  dram)
    DOMAIN_PATH="$DOMAIN_PATH/intel-rapl:$pkg:0"
    name="dram"
    ;;
  *)
    die "Invalid Power Domain!"
    ;;
  esac
}

# Enable power limit from sysfs
# Inputs:
#      $1: Select CPU package
#      $2: Select Domain
#      $3: Select state (0=disable, 1=enable)
enable_power_limit() {
  local pkg=$1
  local domain=$2
  local state=$3

  [[ $# -ge 3 ]] || die "Invalid inputs!"

  domain=$(echo "$domain" | awk '{print tolower($0)}')
  get_domain_path "$pkg" "$domain"

  do_cmd "echo \"$state\" > \"$DOMAIN_PATH/enabled\""
}

power_limit_unlock_check() {
  # domain name should be PKG or PP0
  declare -u domain=$1
  local rc
  local power_limit_unlock=""

  which turbostat &>/dev/null || die "turbostat tool does not exist"
  do_cmd "$PSTATE_TOOL/turbostat --debug -o ts.log sleep 2"
  test_print_trc "Turbostat log to check power limit unlock status:"
  cat ts.log
  power_limit_unlock=$(grep UNlocked ts.log |
    grep MSR_"$domain"_POWER_LIMIT)
  test_print_trc "RAPL test domain name: MSR_${domain}_POWER_LIMIT"
  if [[ -n $power_limit_unlock ]]; then
    test_print_trc "RAPL $domain Power limit is unlocked"
  else
    skip_test "RAPL $domain Power limit is locked by BIOS, skip this case."
  fi
  return $rc
}

# Enable power limit from sysfs
# Inputs:
#      $1: Select CPU package
#      $2: Select Domain
#      $3: Select Power Limit
#      $4: Select Time Windows
set_power_limit() {
  local pkg=$1
  local domain=$2
  local limit=$3
  local time_win=$4

  domain=$(echo "$domain" | awk '{print tolower($0)}')
  test_print_trc "The RAPL pkg name is: $pkg"
  test_print_trc "The RAPL domain name is: $domain"
  get_domain_path "$pkg" "$domain"

  do_cmd "echo \"$time_win\" > \"$DOMAIN_PATH/constraint_0_time_window_us\""
  do_cmd "echo \"$limit\" > \"$DOMAIN_PATH/constraint_0_power_limit_uw\""
}

# Create workloads on the specified domain
# Input:
#   $1: Select Domain
# Output:
#   LOAD_PID: PID of the test workload
create_test_load() {
  local domain=$1

  [[ -z $LOAD_PID ]] || kill -9 "$LOAD_PID"

  domain=$(echo "$domain" | awk '{print tolower($0)}')
  case $domain in
  pkg | core)
    which "$CPU_LOAD" &>/dev/null || die "fspin does not exist"
    do_cmd "$CPU_LOAD $CPU_LOAD_ARG > /dev/null &"
    ;;
  uncore)
    which "$GPU_LOAD" &>/dev/null || die "glxgears does not exist"
    do_cmd "$GPU_LOAD $GPU_LOAD_ARG > /dev/null &"
    ;;
  dram)
    which "$DRAM_LOAD" &>/dev/null || die "stress does not exist"
    mem_avail=$(grep MemAvailable /proc/meminfo | awk -F " " '{print $2}')
    mem_test=$(echo "$mem_avail"/10000000 | bc)
    do_cmd "$DRAM_LOAD --vm $mem_test --vm-bytes 1024M -t 30 > /dev/null &"
    ;;
  *)
    die "Invalid domain!"
    ;;
  esac

  LOAD_PID=$!
}

# Clear all workload from system
clear_all_test_load() {
  for load in "$CPU_LOAD" "$GPU_LOAD" "$DRAM_LOAD"; do
    for pid in $(pgrep "$load"); do
      kill -9 "$pid"
    done
  done
}

# Read the scaling factors for the respective RAPL value.
read_rapl_unit() {
  read_msr "3:0" "$MSR_RAPL_POWER_UNIT"
  RAPL_POWER_UNIT=$(echo "scale=12; 1 / 2^$((16#$MSR_VAL))" | bc)
  test_print_trc "RAPL Power Unit = $RAPL_POWER_UNIT Watts"

  read_msr "12:8" "$MSR_RAPL_POWER_UNIT"
  RAPL_ENERGY_UNIT=$(echo "scale=12; 1 / 2^$((16#$MSR_VAL)) * 10^6" | bc)
  test_print_trc "RAPL Energy Unit = $RAPL_ENERGY_UNIT uj"

  read_msr "19:16" "$MSR_RAPL_POWER_UNIT"
  RAPL_TIME_UNIT=$(echo "scale=12; 1 / 2^$((16#$MSR_VAL)) * 10^6" | bc)
  test_print_trc "RAPL Time Unit = $RAPL_TIME_UNIT micro-seconds"
}

# Build CPU Package Topology
# Output:
#   CPU_TOPOLOGY: an array of packages each containing a list of CPUs
build_cpu_topology() {
  CPU_TOPOLOGY=()

  for ((i = 0; i < NUM_CPU_PACKAGES; i++)); do
    CPU_TOPOLOGY+=([$i]="")
  done

  for topo in $(grep . $CPU_SYSFS/cpu*/topology/physical_package_id); do
    pkg=$(echo "$topo" | cut -d":" -f2)
    cpu=$(echo "$topo" | cut -d"/" -f6)
    CPU_TOPOLOGY[$pkg]+="${cpu:3} "
  done

  for pkg in "${!CPU_TOPOLOGY[@]}"; do
    test_print_trc "Package $pkg has CPUs: ${CPU_TOPOLOGY[$pkg]}"
  done
}

# Check if the target machine is a server platform
is_server_platform() {
  local rc

  grep "dram" $RAPL_SYSFS_PATH/intel-rapl:*/name
  rc=$?

  [[ $rc -eq 0 ]] && {
    NAMES=$(grep -E "package-([0-9]{1})" $RAPL_SYSFS_PATH/intel-rapl:*/name)
    PKG_NUM=$(awk -F- '{print $3}' <<<"$NAMES" | sort -n | tail -n1)
    MAX_PKG_NUM=$((PKG_NUM + 1))
    DIE_NUM=$(awk -F- '{print $NF}' <<<"$NAMES" | sort -n | tail -n1)
    MAX_DIE_NUM=$((DIE_NUM + 1))
  }

  return $rc
}

# Initialize RAPL
init_rapl() {
  clear_all_test_load
  read_rapl_unit
  build_cpu_topology
}

init_rapl
