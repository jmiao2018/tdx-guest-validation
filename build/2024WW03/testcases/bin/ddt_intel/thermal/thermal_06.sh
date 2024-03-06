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
#       - changed CPU and GPU heat bin for stress tool
#       - only checks cpu thermal zones
#

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#thermal_06

source common.sh
source functions.sh
source thermal_functions.sh
source stress.sh

############################# Functions #######################################
check_trip_point_change() {
  local count=0
  local trip_temp=0
  local temp=0
  local tzonepath=""
  local trips_log=""

  if [ "$TRIP_INDEX" -le 0 ]; then
    block_test "There are no trip points registered, skipping test"
  fi

  test_print_trc "Testing: ${TZONE_TRIPS[*]}"

  $CPU_HEAT_BIN &
  cpu_pid=$!
  check "start cpu heat binary" "test $cpu_pid -ne 0" || return 1
  sleep 5
  check "stress brightness started" start_stress_brightness || return 1

  while (test $count -lt "$TEST_LOOP"); do
    trip_crossed=0
    trips_log=""
    sleep 5

    for tzone_trip in "${TZONE_TRIPS[@]}"; do
      tzonepath=$(dirname "$THERMAL_PATH"/"$tzone_trip"'temp')
      temp=$(cat "$tzonepath"/temp)
      trip_temp=$(cat "$THERMAL_PATH"/"$tzone_trip"'temp')

      if [ "$temp" -ge "$trip_temp" ]; then
        trip_crossed=$((trip_crossed + 1))
      else
        trips_log="$trips_log - $THERMAL_PATH/$tzone_trip'trip' temp=$temp"
      fi
    done

    if [ $trip_crossed -eq "$TRIP_INDEX" ]; then
      test_print_trc "Trip points crossed... PASS"
      return 0
    fi
    count=$((count + 1))
  done

  if [ $cpu_pid != 0 ]; then
    pkill -KILL -P $cpu_pid
    stop_stress_brightness
  fi

  test_print_trc "Trip not crrossed: $trips_log"
  test_print_trc "Trip points not crossed... FAIL"

  return 1
}

get_trips_to_monitor() {
  local zone_name=$1
  local tzonepath=$THERMAL_PATH/$zone_name
  local trip_type=""
  shift 1

  local trips=""
  local tzone_type=""

  trips=$(ls "$tzonepath" | grep -Eo "^trip_point_['$MAX_ZONE']+_" | uniq)
  tzone_type=$(cat "$tzonepath"/'type')

  if [[ $tzone_type =~ $FILTER ]]; then
    for trip in $trips; do
      trip_type=$(cat "$THERMAL_PATH"/"$zone_name"/"$trip"'type')

      # Trip can be one off critical, hot, passive, active[0-*] for ACPI
      # thermal zone. If temp is greater than or equal to critical trip
      # point then the device will be shutdown. Therefore, we omit the
      # validation of critical trip points
      if [ "$trip_type" != "critical" ]; then
        test_print_trc "Adding ${zone_name}/${trip} to trips  list"
        TZONE_TRIPS[$TRIP_INDEX]=$zone_name/$trip
        TRIP_INDEX=$((TRIP_INDEX + 1))
      fi
    done
  fi

  return 0
}

############################ Script Variables ##################################
# Define default valus if possible
# We simply assume someone else provides these binaries
CPU_HEAT_BIN="stress --cpu 4 --io 4 --vm 4 --vm-bytes 128M"
TEST_LOOP=600
TZONE_TRIPS=
TRIP_INDEX=0

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)

# Define default values for variables being overriden
case $SOC in
  baytrail) FILTER="aux_dts[0-9]+" ;;
  *) FILTER=".*" ;;
esac

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
for_each_thermal_zone get_trips_to_monitor || exit 1

check_trip_point_change || exit 1
