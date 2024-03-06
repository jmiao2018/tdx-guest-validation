#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2020 Intel Corporation
# @Author   Wendy Wang  <wendy.wang@intel.com>
#           Furong Shen <furongx.shen@intel.com>
# @desc     For Intel thermal test

source common.sh
source thermal_common.sh

thermal_flag=""
temp_value=""

# Check thermal_flag to see digital thermal sensor is enabled or not
digital_sensor_check() {
  thermal_flag=$(read_msr "31:31" "$MSR_PACKAGE_THERMAL_STATUS")
  test_print_trc "read_msr \"31:31\" $MSR_PACKAGE_THERMAL_STATUS"
  echo "$thermal_flag"
  thermal_flag=$(echo "$thermal_flag" | awk -F"\"" END'{print $4}')
  thermal_flag_10=$((16#${thermal_flag}))

  if [[ "$thermal_flag_10" -ne 1 ]]; then
    die "Your system digital thermal sensor is not enable, thermal_flag is " \
      "$thermal_flag"
  fi
  test_print_trc "Your system digital thermal sensor is enabled, \
    thermal_flag is $thermal_flag"
}

# Check CPU package digital thermal temp value
pkg_temp_check() {
  temp_target_16=$(read_msr "22:16" "$MSR_TEMPERATURE_TARGET")
  test_print_trc "read_msr \"22:16\" $MSR_TEMPERATURE_TARGET"
  echo "$temp_target_16"
  temp_target_16=$(echo "$temp_target_16" | awk -F"\"" END'{print $4}')
  temp_target_10=$((16#${temp_target_16}))
  test_print_trc "CPU pkg thermal temp target value is: $temp_target_16"
  test_print_trc "Converted to decimal is: $temp_target_10"

  temp_status_16=$(read_msr "22:16" "$MSR_PACKAGE_THERMAL_STATUS")
  test_print_trc "read_msr \"22:16\" $MSR_PACKAGE_THERMAL_STATUS"
  echo "$temp_status_16"
  temp_status_16=$(echo "$temp_status_16" | awk -F"\"" END'{print $4}')
  temp_status_10=$((16#${temp_status_16}))
  test_print_trc "CPU pkg thermal temp status value is: $temp_status_16"
  test_print_trc "Converted to decimal is: $temp_status_10"

  # temp_value : Decimal
  temp_value=$((temp_target_10 - temp_status_10))
  if [[ $temp_value -le 0 ]]; then
    die "CPU Package Digital thermal sensor temperature value is wrong: " \
      "$temp_value, please check temp_target value and temp_status value."
  fi
  test_print_trc "CPU Package Digital thermal sensor temperature value is \
    available: $temp_value"
}

digital_sensor_check
pkg_temp_check
