#!/usr/bin/env bash

source common.sh
source dmesg_functions.sh

which x86_cpuload  &> /dev/null || block_test "x86_cpuload is not installed"

num_cpus=$(dmidecode -t processor | grep "Thread Count" | awk -F' ' '{print $3}')
[[ -n "$num_cpus" ]] || die "fail"

thermal_zones=""
for file in /sys/class/thermal/thermal_zone*; do
  thermal_zones="$thermal_zones ${file: -1}"
done

interrupt_before=$(cat /sys/kernel/debug/pkg_temp_thermal/pkg_thres_interrupt)
[[ -n "$interrupt_before" ]] || block_test "pkg_thres_interrupt sysfs file do not exist."

for i in $thermal_zones; do
  pkg=$(cat "/sys/class/thermal/thermal_zone${i}/type")

  if [ "$pkg" = "x86_pkg_temp" ]; then
    cur_temp=$(cat "/sys/class/thermal/thermal_zone${i}/temp")
    test_print_trc "cur_temp: $cur_temp"

    low=$((cur_temp - 500))
    high=$((cur_temp + 500))

    echo "$low" > "/sys/class/thermal/thermal_zone${i}/trip_point_0_temp"
    echo "$high" > "/sys/class/thermal/thermal_zone${i}/trip_point_1_temp"

    x86_cpuload -s 0 -c "$num_cpus" -t 20

    cur_temp=$(cat "/sys/class/thermal/thermal_zone${i}/temp")
    test_print_trc "cur_temp: $cur_temp"

    interrupt_after=$(cat "/sys/kernel/debug/pkg_temp_thermal/pkg_thres_interrupt")

    test_print_trc "before: $interrupt_before, after: $interrupt_after"
    if [[ "$interrupt_after" -gt "$interrupt_before" ]]; then
      test_print_trc "Package thermal interrupt increased after setting trip_point_temp threshhold"
    else
      die "Package thermal interrupt did not increase after setting trip_point_temp threshhold"
    fi
  else
      test_print_trc "Thermal zone: $pkg does not support to set thermal throttling"
  fi
done

dmesg=$(extract_case_dmesg)

if echo "$dmesg" | grep -iqE "error|fail|warning"; then
  die "error message deceted during thermal throttling testing"
else
  test_print_trc "Thermal throttling testing PASS"
fi
