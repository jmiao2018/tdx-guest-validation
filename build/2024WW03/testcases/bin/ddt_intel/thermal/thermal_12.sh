#!/bin/bash
###############################################################################
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

# Copyright (C) 2015 Intel - http://www.intel.com
# @Author   Juan Pablo Gomez <juan.p.gomez@intel.com>
# @desc     Check package RAPL domain sysfs, RAPL driver binds with supported CPU ids during probing phase.
#	    Once domains are discovered,objets are created for each domain which are also linked with cooling devices
#	    after its registration with the generic thermal layer.
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-02-24: First Version (Juan Pablo Gomez)

source common.sh
source functions.sh
source thermal_functions.sh

############################# Functions #######################################
check_rapl_top_level() {
  local path=$INTEL_RAPL_PATH

  test_print_trc "Cheking Top Level: $path"
  check_file 'enabled' "$path" || return 1
  check_file 'uevent' "$path" || return 1

  return 0
}

check_attributes() {
  local path=$1
  shift 1

  for attr in $ATTRIBUTES; do
    check_file "$attr" "$path" || return 1
  done

  check_max_ranges "$path" || return 1
  check_constraints "$path" || return 1

  return 0
}

check_max_ranges() {
  local path=$1
  shift 1

  if check_file "power_uw" "$path"; then
    check_file "max_power_range_uw" "$path" || return 1
  elif check_file "energy_uj" "$path"; then
    check_file "max_energy_range_uj" "$path" || return 1
  else
    return 1
  fi

  return 0
}

check_constraints() {
  local path=$1
  shift 1
  local indices=""

  indices=$(ls "$path" | grep -Eo 'constraint_[0-9]+_power_limit_uw' |
    grep -Eo '[0-9]+')
  for index in $indices; do
    check_file 'constraint_'"$index"'_power_limit_uw' "$path" || return 1
    check_file 'constraint_'"$index"'_time_window_us' "$path" || return 1
  done

  return 0
}

check_zones_recursive() {
  local root=$1
  local level=$2
  shift 2
  local childs=""
  local next_level=""

  childs=$(regex_scan_dir "$root" "$RGX_PACKAGE")
  next_level=$((level + 1))

  test_print_trc "Checking level $level: $root"
  if [ "$level" -ne 0 ]; then
    check_attributes "$root" || return 1
  fi

  for child in $childs; do
    check_zones_recursive "$root"/"$child" $next_level
  done

  return 0
}

############################ Script Variables ##################################
INTEL_RAPL_PATH="/sys/devices/virtual/powercap/intel-rapl"
INTEL_TPMI_RAPL_PATH="/sys/devices/virtual/powercap/intel-rapl-tpmi"
TOP_LEVEL=0
ATTRIBUTES="name uevent enabled"
RGX_PACKAGE='intel-rapl:[0-9]+'
REQUEST_KCONFIG="CONFIG_INTEL_RAPL"
RAPL_MODULE="intel_rapl_msr"
########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.

# Uncomment the following line if you want the change the behavior of
# do_cmd to treat non-zero values as pass and zero as fail.
# inverted_return="true"
koption=$(get_kconfig "$REQUEST_KCONFIG") ||
  die "Failed to verify kernel config"
if [ "$koption" == "m" ]; then
  test_print_trc "$REQUEST_KCONFIG has been built as module"
  lsmod | grep -q "$RAPL_MODULE"
  if [ $? -ne 0 ]; then
    modprobe "$RAPL_MODULE" || die "Failed to load $RAPL_MODULE module"
  fi
fi

if [ -d /sys/class/powercap/intel-rapl-tpmi ]; then
  check_zones_recursive $INTEL_TPMI_RAPL_PATH $TOP_LEVEL || exit 1
else
  check_rapl_top_level || exit 1
  check_zones_recursive $INTEL_RAPL_PATH $TOP_LEVEL || exit 1
fi
