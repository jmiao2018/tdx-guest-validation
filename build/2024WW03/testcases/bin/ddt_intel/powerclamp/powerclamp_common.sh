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
# File:         powerclamp_common.sh
#
# Description:  Common file for Intel Powerclamp Test
#
# Authors:      Jerry C. Wang - jerry.c.wang@intel.com
#
# History:      Jun 28 2017 - Created - Jerry C. Wang
#               - Get powerclamp device in sysfs
#               - Read and write powerclamp sysfs
#               - Enable/Disable powerclamp idle injection
#               - Create/Distroy CPU loading in background

source "common.sh"

MODULE_NAME="intel_powerclamp"
CLAMP_SYSFS_PATH="/sys/class/thermal"
CLAMP_INTERFACE=""
CLAMP_STATUS="cur_state"
RAPL_SYSFS_PATH="/sys/class/powercap/intel-rapl"
RAPL_CONTROL="intel-rapl"
RAPL_DOMAIN="0"
RAPL_SAMPLE_TIME=5
CPU_LOAD="fspin"
FSPIN_LOG="/tmp/fspin.log"

# Obtain powerclamp interface within sysfs
# Global:
#     CLAMP_INTERFACE: Absolute path to powerclamp interface
# Return:
#     0: Powerclamp interface is identified and stored in CLAMP_INTERFACE
#     1: Failed to identify powerclamp interface
get_interface() {
  local ret_type=""

  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"

  ret_type=$(grep -n "$MODULE_NAME" $CLAMP_SYSFS_PATH/cooling_device*/type)
  if [[ -z "$ret_type" ]]; then
    test_print_err "Unable to detect powerclamp interface in sysfs!"

    exit 1
  fi

  CLAMP_INTERFACE="$CLAMP_SYSFS_PATH/$(echo "$ret_type" | cut -d'/' -f5)"
  return 0
}


# Read value from powerclamp interface in sysfs
# Input:
#     $1: File to be read
# Output:
#     content from the file
read_powerclamp_sysfs() {
  local filename=$1

  [[ -n "$CLAMP_INTERFACE" ]] || get_interface
  cat "$CLAMP_INTERFACE/$filename"
}

# Write to powerclamp interface in sysfs
# Input:
#     $1: File to be written
#     $2: Written value
write_powerclamp_sysfs() {
  local filename=$1
  local input_val=$2
  local neg_res=$3

  : "{$neg_res:=0}"

  [[ -n "$CLAMP_INTERFACE" ]] || get_interface

  if [[ $neg_res -eq 1 ]]; then
    should_fail \
      "eval \"echo $input_val > $CLAMP_INTERFACE/$filename\" 2>/dev/null"
  else
    do_cmd "eval \"echo $input_val > $CLAMP_INTERFACE/$filename\" 2>/dev/null"
  fi
}

# Enable idle injection in powerclamp
# Input:
#     $1: Percentage of Idle injection (optional)
enable_idle_injection() {
  local idle_percent=$1
  local state=0

  : "${idle_percent:=50}"

  write_powerclamp_sysfs "$CLAMP_STATUS" "$idle_percent"
}

# Disable idle injection in powerclamp
disable_idle_injection() {
  local state=0

  load_unload_module.sh -c -d $MODULE_NAME || return 0

  state=$(read_powerclamp_sysfs "$CLAMP_STATUS")
  if [[ $state -ne -1 ]]; then
    write_powerclamp_sysfs "$CLAMP_STATUS" 0
  fi
}

# Clear all CPU loads
clear_cpu_loads() {
  [[ $(which pgrep) ]] || die "pgrep is not found"

  for pid in $(pgrep "$CPU_LOAD"); do
    { kill "$pid" && wait "$pid"; } 2>/dev/null
  done
}

# Generate CPU loads
generate_cpu_loads() {
  clear_cpu_loads
  [[ $(which $CPU_LOAD) ]] || die "$CPU_LOAD is not found."
  do_cmd "$CPU_LOAD -i 1 -l $FSPIN_LOG &"
}

# Read RAPL Power Comsumption
get_rapl_power() {
  [[ -r "$RAPL_SYSFS_PATH/$RAPL_CONTROL:$RAPL_DOMAIN/energy_uj" ]] || \
     die "Failed to read RAPL power value"

  p1=$(cat "$RAPL_SYSFS_PATH/$RAPL_CONTROL:$RAPL_DOMAIN/energy_uj")
  sleep $RAPL_SAMPLE_TIME
  p2=$(cat "$RAPL_SYSFS_PATH/$RAPL_CONTROL:$RAPL_DOMAIN/energy_uj")
  echo "scale=2;(($p2-$p1)/1000000/$RAPL_SAMPLE_TIME)" | bc
}

# Get CPU Performance
get_cpu_score() {
  [[ $(pgrep "$CPU_LOAD") && -f $FSPIN_LOG ]] || \
      die "fspin is not running or fspin log is not found"

  cat $FSPIN_LOG
}
