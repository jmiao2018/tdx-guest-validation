#!/bin/bash
#
# PM-QA validation test suite for the power management on Linux
#
# Copyright (C) 2011, Linaro Limited.
# Copyright (C) 2015, intel - http://www.intel.com/
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
#       - if cur_state cannot be changed and the cooling device is not a
#         software  device, fail the test
#     Juan Pablo Gomez <juan.p.gomez@intel.com> (Intel)
#       - if the device is software_cooling_device then do not test it

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#thermal_02

source common.sh
source functions.sh
source thermal_functions.sh

############################# Functions #######################################
check_cooling_device_attributes() {
  local dirpath=$THERMAL_PATH/$1
  local cdev_name=$1
  shift 1

  for i in $CDEV_ATTRIBUTES; do
    check_file "$i" "$dirpath" || return 1
  done

  return 0
}

check_cooling_device_states() {
  local dirpath=$THERMAL_PATH/$1
  local cdev_name=$1
  shift 1
  local max_state=""
  local prev_state_val=""
  local count=1
  local cur_state_val=0

  max_state=$(cat "$dirpath"/max_state)
  prev_state_val=$(cat "$dirpath"/cur_state)

  if is_software_cooling_device "$cdev_name"; then
    test_print_trc "Skiping Software Cooling Device:$cdev_name"
    return 0
  fi

  while (test $count -le "$max_state"); do
    echo $count > "$dirpath"/cur_state
    cur_state_val=$(cat "$dirpath"/cur_state)
    check "$cdev_name cur_state=$count" "test $cur_state_val -eq $count"
    count=$((count + 1))
  done
  echo "$prev_state_val" > "$dirpath"/cur_state

  return 0
}

############################ Script Variables ##################################
# Define default valus if possible
CDEV_ATTRIBUTES="cur_state max_state type uevent"

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
for_each_cooling_device check_cooling_device_attributes || exit 1

for_each_cooling_device check_cooling_device_states || exit 1
