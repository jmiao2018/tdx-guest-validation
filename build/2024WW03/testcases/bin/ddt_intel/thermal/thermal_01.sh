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
#     Rivas Luis <luis.miguel.rivasz.zepeda@intel.com> (Intel)
#       - modified check thermal zone mode, if mode is not present return success
#     Juan Pablo Gomez  <juan.p.gomez@intel.com> (Intel)
#       - check thermal zone mode function was deleted since mode is not available

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#thermal_01

source common.sh
source functions.sh
source thermal_functions.sh

############################# Functions #######################################
check_thermal_zone_attributes() {
  local zone_name=$1
  local dirpath=${THERMAL_PATH}/${zone_name}
  shift 1

  for i in $ATTRIBUTES; do
    check_file "$i" "$dirpath"
  done

  check_valid_temp "temp" "$zone_name" || return 1

  return 0
}

check_thermal_zone_trip_level() {
  local zone_name=$1

  for_each_trip_point_of_zone "$zone_name" "validate_trip_level" || return 1

  return 0
}

check_thermal_zone_bindings() {
  local zone_name=$1

  for_each_binding_of_zone "$zone_name" "validate_trip_bindings" || return 1

  return 0
}

############################ Script Variables ##################################
# Define default valus if possible
ATTRIBUTES="temp type uevent"

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
for_each_thermal_zone check_thermal_zone_attributes || exit 1

# Sofia uses iTux application to control cooling devices and thermal zones, and
# ITux defines its own trip points. Therefore, the trip points under thermal
# zones sysfs are invalid and not used
if ! [[ "$SOC" =~ sofia ]]; then
  for_each_thermal_zone check_thermal_zone_trip_level || exit 1
fi

for_each_thermal_zone check_thermal_zone_bindings || exit 1
