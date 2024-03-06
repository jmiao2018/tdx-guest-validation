#!/bin/bash
###############################################################################
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

# @Author   Luis Rivas(luis.miguel.rivas.zepeda@intel.com)
# @desc     Turn on regulator and check regulator state & microvolts
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "pmic_functions.sh"

############################# Functions #######################################
test_reg_on_off() {
  local rgx=$( echo $PMIC_ACTIVE_REG | tr " " \| )
  local active=$(find ${REG_PATH}/regulator.*/name -type f -print0 | \
                   xargs -0 grep -El "${rgx}")
  local path=""

  test_print_trc "Active regulators: $PMIC_ACTIVE_REG"
  for reg in $active; do
    path=$(dirname $reg)
    $PMIC_REG_ON
    sleep 2
    check_reg_state $path "enabled" || return 1
    check_reg_microvolts $path || return 1

    if [ $TURN_REG_OFF_ON_EXIT -eq 1 ]; then
      $PMIC_REG_OFF
      test_print_trc "Waiting 10 seconds..."
      sleep 10
      check_reg_state $path "disabled" || return 1
    fi
  done
  return 0
}

check_reg_state() {
  local reg=$1
  local exp=$2
  shift 2

  local curr=$(cat ${reg}/state)

  test_print_trc "$reg state: $curr"
  if [ "$curr" == "$exp" ]; then
    test_print_trc "$reg state is equal to $exp"
    return 0
  else
    test_print_trc "$reg state is not equal to $exp"
    return 1
  fi
}

check_reg_microvolts() {
  local reg=$1
  local reg_basename=$(basename $reg)
  shift 1

  local m_volts=$(cat ${reg}/microvolts)
  local max=""
  local min=""

  test_print_trc "$reg microvolts: $m_volts"
  if is_reg_sysfs_simplified $reg_basename; then
    check "if microvolts is greater/equal to zero" test "$m_volts -ge 0" || \
           return 1
  else
    max=$(cat ${reg}/max_microvolts)
    min=$(cat ${reg}/min_microvolts)
    test_print_trc "$reg max microvolts: $max"
    test_print_trc "$reg min microvolts: $min"
    check "if microvolts is less/equal to max" test "$m_volts -le $max" || \
           return 1
    check "if microvolts is greater/equal to min" test "$m_volts -ge $min" || \
           return 1
  fi
  return 0
}

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)
case $SOC in
  sofia*)  TURN_REG_OFF_ON_EXIT=0;; # Regulators are always on
  *)  TURN_REG_OFF_ON_EXIT=1;;
esac

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
test_reg_on_off || die "Error on test regulator on/off"
