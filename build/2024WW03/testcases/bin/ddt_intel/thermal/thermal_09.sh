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
# @Author   Juan Pablo Gomez(juan.p.gomez@intel.com)
# @desc     Check if the powerclamp driver is registered to the generic thermal layer as a cooling device
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-02-24: First Version (Juan Pablo Gomez)

source common.sh
source functions.sh
source thermal_functions.sh

############################# Functions #######################################
check_power_clamp() {
  local power_clamps=""
  local grep_options=""

  grep_options="--include=type $THERMAL_PATH"
  power_clamps=$(grep -Elr 'intel_powerclamp' 2>/dev/null "$grep_options" \
    | grep -oE 'cooling_device[0-9]+')
  check "Intel Power Clamp exists..." "test " "${#power_clamps[@]} -ne 0" \
    || return 1
  for power_clamp in $power_clamps; do
    check_power_clamp_attr "$power_clamp" || return 1
  done

  return 0
}

check_power_clamp_attr() {
  local pc_path=$THERMAL_PATH/$1

  test_print_trc "Checking $pc_path"
  for attr in $ATTRIBUTES; do
    check_file "$attr" "$pc_path" || return 1
  done

  return 0
}

############################ Script Variables ##################################
ATTRIBUTES="cur_state max_state"
########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.

# Uncomment the following line if you want the change the behavior of
# do_cmd to treat non-zero values as pass and zero as fail.
# inverted_return="true"
check_power_clamp || exit 1
