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
#     Rivas Luis <luis.miguel.rivas.zepeda> (Intel)
#       - changed CPU heat bin for stress tool
#       - added script parameter to setup stress time
#       - Replace test logic, the scripts get the temperature of each
#         thermal zone, stress the platform n seconds and verifies if the
#         temperature increased
#

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#thermal_03

source common.sh
source functions.sh
source thermal_functions.sh
source stress.sh

############################# Functions #######################################
usage() {
  cat << _EOF
    usage: ./${0##*/}  [-t TIME_OUT ] [-h Help]
      -t  TIME_OUT  time in seconds, default is 600
      -h  Help      print this usage
_EOF
}

get_init_temps() {
  local tzone=$1
  local tzone_path=${THERMAL_PATH}/${tzone}
  local temp=""

  temp=$(cat "$tzone_path"/temp)

  # Add a new entry to init temps for each thermal zone
  INIT_TEMPS="$INIT_TEMPS $tzone_path:$temp"
  TOTAL_TEMPS=$((TOTAL_TEMPS + 1))
  test_print_trc "Added entry to init temps: $tzone / $temp"

  return 0
}

start_stressing() {
  start_stress_brightness

  if [ $? -eq 0 ]; then
    test_print_trc "Stress brightness started!"
  else
    test_print_trc "Cannot start stress brightness"
    return 1
  fi

  $CPU_HEAT_BIN &
  HEAT_PID=$!
  if [ $HEAT_PID -gt 0 ]; then
    test_print_trc "CPU HEAT Started: $HEAT_PID"
  else
    test_print_trc "Cannot start CPU HEAT"
    return 1
  fi

  return 0
}

stop_stressing() {
  stop_stress_brightness

  if [ $? -eq 0 ]; then
    test_print_trc "Stress brightness stoped"
  else
    test_print_trc "Cannot stop stress brightness"
  fi

  if [ $HEAT_PID -gt 0 ]; then
    kill -9 $HEAT_PID
    test_print_trc "CPU HEAT Killed"
  fi

  return 0
}

sensing_test() {
  local tzone=""
  local init=0
  local final=0
  local time=0
  local count=0

  # Launch stress tools
  start_stressing

  # Start count down
  while [ $time -lt "$TIME_OUT" ] && [ $count -lt $TOTAL_TEMPS ]; do
    # Start polling tzone temps
    for entry in $INIT_TEMPS; do
      # Retrieve entry information: tzone path & initial temp
      arr=$(echo "$entry" | tr ':' ' ')
      read -a arr <<< $arr
      tzone=${arr[0]}
      init=${arr[1]}

      # Get final temperature
      final=$(cat "$tzone"/temp)

      # If temp is greater than init temp for the first ime, store the result
      if [ "$final" -gt "$init" ] && [[ ! "$FINAL_TEMPS" =~ $tzone ]]; then
        FINAL_TEMPS="$FINAL_TEMPS $tzone:$final:$time"
        test_print_trc "Added entry to final temps: $tzone - $final - $time"
        count=$((count + 1))
      fi
    done
    # Wait 1 seconds and increment time counter
    time=$((time + 1))
    sleep 1
  done

  # Stop stress tools
  stop_stressing

  return 0
}

report_results(){
  local count=0

  test_print_trc "############################################################"
  test_print_trc "SENSING RESULTS"
  test_print_trc "############################################################"
  for entry in $INIT_TEMPS; do
    # Retrieve entry information: tzone path & initial temp
    arr=$(echo "$entry" | tr ':' ' ')
    read -a arr <<< $arr
    tzone=${arr[0]}
    init=${arr[1]}
    if [[ "$FINAL_TEMPS" =~ $tzone ]]; then
      test_print_trc "TZone temperature increased: $tzone"
      count=$((count + 1))
    else
      test_print_trc "TZone temperature not increased: $tzone"
    fi
  done

  if [ $count -eq $TOTAL_TEMPS ]; then
    test_print_trc "ALL TEMPERATURES INCREASED"
    return 0
  else
    test_print_trc "SOME TZONES TEMPERATURES DID NOT INCREASE"
    return 1
  fi
}

############################ Script Variables ##################################
# Define default valus if possible
# We simply assume someone else provides these binaries
CPU_HEAT_BIN="stress --cpu 4"
HEAT_PID=0
TOTAL_TEMPS=0
INIT_TEMPS=""
FINAL_TEMPS=""

################################ CLI Params ####################################
# Please use getopts
while getopts  t:h arg
do case $arg in
  t) TIME_OUT=$OPTARG;;
  h) usage && exit;;
  \?)
    die "Invalid Option -$OPTARG "
    ;;
  :)
    die "$0: Must supply an argument to -$OPTARG."
    ;;
esac
done

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)

# Define default values for variables being overriden
: ${TIME_OUT:=600}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
for_each_thermal_zone get_init_temps || die "Cannot get tzones init temps"

sensing_test || die "Error while running sensing test"

report_results || die "Some Tzones temperatures did not increse"
