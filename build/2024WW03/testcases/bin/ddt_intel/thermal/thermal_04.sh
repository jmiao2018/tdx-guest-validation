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
#     Rivas Luis <luis.miguel.rivas.zepeda@intel> (Intel)
#       - changed CPU heat bin for stress tool
#       - only test thermal zone bounded to cdevs
#

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#thermal_04

source common.sh
source functions.sh
source thermal_functions.sh
source stress.sh

############################# Functions #######################################
verify_cooling_device_temp_change() {
  local zone_name=$1
  local cdev_name=$2
  shift 2

  local tzonepath=$THERMAL_PATH/$zone_name
  local cdevpath=$tzonepath/$cdev_name
  local max_state=""
  local prev_state_val=""
  local prev_mode_val=""
  echo -n disabled > "$tzonepath"/mode

  local count=1
  local init_temp=0
  local final_temp=0
  local cool_temp=0

  max_state=$(cat "$cdevpath"/max_state)
  prev_state_val=$(cat "$cdevpath"/cur_state)
  prev_mode_val=$(cat "$tzonepath"/mode)

  $HEAT_CPU_MODERATE &
  pid=$!
  check "check cpu heat binary" "test $pid -ne 0" || return 1
  check "stress brightness started" start_stress_brightness || return 1


  while (test $count -le "$max_state"); do
    echo 0 > "$cdevpath"/cur_state
    sleep 5
    init_temp=$(cat "$tzonepath"/temp)

    echo $count > "$cdevpath"/cur_state
    sleep 5
    final_temp=$(cat "$tzonepath"/temp)
    cool_temp=$((init_temp - final_temp))
    check "$cdev_name:state=$count effective cool=$cool_temp " \
          "test $cool_temp -ge 0"
      if [ $? -ne 0 ]; then
        pkill -KILL -P $pid
        check "stop stress birghtness" stop_stress_brightness || return 1
        echo "$prev_mode_val" > "$tzonepath"/mode
        echo "$prev_state_val" > "$cdevpath"/cur_state
        return 1
      fi
    count=$((count + 1))
  done

  pkill -KILL -P $pid
  check "stop stress birghtness" stop_stress_brightness || return 1
  echo "$prev_mode_val" > "$tzonepath"/mode
  echo "$prev_state_val" > "$cdevpath"/cur_state

  return 0
}

verify_thermal_zone_cdevs() {
  local zone_name=$1
  shift 1

  local tzonepath=$THERMAL_PATH/$zone_name
  local cdevs=""

  cdevs=$(regex_scan_dir "$tzonepath" "cdev[0-9]+$")

  if [ -z "$cdevs" ]; then
    test_print_trc "$zone_name does not have cdevs bonded"
    return 0
  fi

  for cdev in $cdevs; do
    verify_cooling_device_temp_change "$zone_name $cdev" || return 1
  done

  return 0
}

############################ Script Variables ##################################
# Define default valus if possible
# We simply assume someone else provides these binaries
HEAT_CPU_MODERATE="stress --cpu 2 --vm 4 --vm-bytes 128M"

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
for_each_thermal_zone verify_thermal_zone_cdevs || exit 1
