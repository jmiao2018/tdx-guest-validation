#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2020, Intel Corporation
#
# Author:
#             Yahui Cheng <yahuix.cheng@intel.com>
#
# History:
#             Jan. 21, 2020 - (Yahui Cheng) Creation

source common.sh
source thermal_common.sh

pkg_thermal=""
thermal_zone_number=""
temp=""
temp_high=""
TOOL="$LTPROOT/testcases/bin/ddt_intel/powermgr"

check_thermal_init_interrupt() {
  line=$(grep "Thermal event interrupts" /proc/interrupts)
  if [[ $? -eq 0 ]]; then
    interrupt_array_init=$(echo "$line" | tr -d "a-zA-Z:" | awk '{$1=$1;print}')
    test_print_trc "thermal_interrupt_array_init: $interrupt_array_init"
    num=$(echo "$interrupt_array_init" | sed "s/ /\n/g" | wc -l)
    test_print_trc "CPU core number: $num"
  else
    die "Thermal event interrupts is not found."
  fi
}

#wait until the temperature raised
check_temperature_raised() {
  time_init=0
  for i in {0..4}; do
    pkg_thermal=$(cat $THERMAL_PATH/thermal_zone$i/type | \
                 grep "x86_pkg_temp" 2>&1)
    if [[ -n $pkg_thermal ]];then
      thermal_zone_number=$i
      test_print_trc "Thermal_zone_number with type of x86_pkg_temp: $thermal_zone_number"
      break
    fi
  done
    if [[ -z $pkg_thermal ]]; then
      die "Test platform does not support x86_pkg_temp thermal zone"
    fi
      TEMP_DIR=$THERMAL_PATH/thermal_zone$thermal_zone_number/temp
      temp=$(cat "$TEMP_DIR")
      test_print_trc "Currently x86_pkg_temp available temp show $temp"
      [[ "$(echo "$temp <= 0" | bc)" -eq 1 ]] && block_test \
        "Test machine x86_pkg_temp is not enabled correctly yet, "\
        "which blocked this test case"
      temp_high=$(( temp + 10 ))
      echo $temp_high > "$THERMAL_PATH/thermal_zone$thermal_zone_number"/trip_point_1_temp
      test_print_trc "temp_high: $temp_high"
      while [[ $time_init -le 200 ]]; do
        "$TOOL/x86_cpuload" -s 0 -c $num -t 30 &
        sleep 10
        temp_cur=$(cat "$TEMP_DIR")
        test_print_trc "temp_cur: $temp_cur"
        [[ $temp_cur -gt $temp_high ]] && break
        time_init=$(( time_init + 1 ))
      done
      [[ $temp_cur -gt $temp_high ]] || die "Test-box doesn't heat up as expected."
}

compare_init_later_interrupt() {
  interrupt_array_later=$(grep "Thermal event interrupts" /proc/interrupts | \
                        tr -d "a-zA-Z:" | awk '{$1=$1;print}')
  test_print_trc "thermal_interrupt_array_later: $interrupt_array_later"
  for i in $(seq 1 "$num"); do
    interrupt_later=$(echo "$interrupt_array_later" | cut -d " " -f  "$i")
    interrupt_init=$(echo "$interrupt_array_init" | cut -d " " -f  "$i")
    test_print_trc "thermal_interrupt_later: $interrupt_later"
    test_print_trc "thermal_interrupt_init: $interrupt_init"
    if [[ $interrupt_later -lt $interrupt_init ]]; then
      die "x86 package thermal interrupt did not increase, case is FAILED"
    fi
  done
  test_print_trc "x86 package thermal interrupt increase, case is PASS"
}

check_thermal_init_interrupt
check_temperature_raised
compare_init_later_interrupt
