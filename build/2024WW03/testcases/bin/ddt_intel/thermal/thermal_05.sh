#!/bin/bash
#
# PM-QA validation test suite for the power management on Linux
#
# Copyright (C) 2011, Linaro Limited.
# Copyright (C) 2015, Intel - http://www.intel.com/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
# Contributors:
#     Amit Daniel <amit.kachhap@linaro.org> (Samsung Electronics)
#       - initial API and implementation
#     Rivas Luis <luis.miguel.rivas.zepeda@intel.com> (Intel)
#       - addded function to verify if there are cooling device of type cpufreq
#

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#thermal_05

source common.sh
source functions.sh
source thermal_functions.sh

############################# Functions #######################################
verify_cpufreq_cooling_device_action() {
  local dirpath=$THERMAL_PATH/$1
  local cdev_name=$1
  shift 1

  local cpufreq_cdev=""
  local max_state=""
  local prev_state_val=""

  cpufreq_cdev=$(cat "$dirpath"/type)

  grep -q cpufreq "$dirpath"/type
  if [ $? -ne 0  ]; then
    test_print_trc "$cdev_name is not type cpufreq"
    return 0
  fi

  max_state=$(cat "$dirpath"/max_state)
  prev_state_val=$(cat "$dirpath"/cur_state)
  disable_all_thermal_zones

  local count=1
  local before_scale_max=0
  local after_scale_max=0
  local change=0

  while (test $count -le "$max_state"); do
    echo 0 > "$dirpath"/cur_state
    sleep 1

    store_scaling_maxfreq
    before_scale_max="$scale_freq"

    echo $count > "$dirpath"/cur_state
    sleep 1

    store_scaling_maxfreq
    after_scale_max=$scale_freq

    check_scaling_freq "$before_scale_max" "$after_scale_max"
    change=$?

    check "cdev=$cdev_name state=$count" "test $change -ne 0"
    if [ $? -ne 0 ]; then
      enable_all_thermal_zones
      echo "$prev_state_val" > "$dirpath"/cur_state
      return 1
    fi

    count=$((count+1))
  done

  enable_all_thermal_zones
  echo "$prev_state_val" > "$dirpath"/cur_state
}

search_cpufreq_devices() {
  local grep_optioin="--exclude-dir=thermal_zone*"

  if grep -r cpufreq "$grep_optioin" "$THERMAL_PATH" 2> /dev/null; then
    return 0
  else
    return 1
  fi
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
search_cpufreq_devices || block_test "Cooling devices of type cpufreq were not found"

for_each_cooling_device verify_cpufreq_cooling_device_action || exit 1
