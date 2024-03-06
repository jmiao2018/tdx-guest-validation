#!/bin/bash
###############################################################################
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

# Copyright (C) 2015 Intel - http://www.intel.com
# @Author   Juan Pablo Gomez(juan.p.gomez@intel.com)
# @desc     Check critical, hot, passive, active trip points
#	    From /sys/class/thermal/thermal_zone[0-*]:
#	    trip_point_[0-*]_type gives the Trip point type
#	    trip_point_[0-*]_temp gives the Trip point temperature
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-02-24: First Version (Juan Pablo Gomez)

source common.sh
source thermal_functions.sh
source functions.sh

############################# Functions #######################################
check_type() {
  local path=$THERMAL_PATH/$1
  local trip_types=""
  local tmp=""

  trip_types=$(regex_scan_dir "$path" "trip_point_[0-9]_type")

  test_print_trc "Checking trip point types of $path"
  for ttype in $trip_types; do
    tmp=$(cat "$path/$ttype")
    valid_trip_type "$tmp" "$ttype"
    check "Valid trip type value of $ttype" valid_trip_type "$tmp" "$ttype" ||
      return 1
  done

  return 0
}

check_temp() {
  local path=$THERMAL_PATH/$1
  local trip_temps=""
  local tmp=0
  local default=-274000

  trip_temps=$(regex_scan_dir "$path" "trip_point_[0-9]_temp")

  test_print_trc "Checking trip point temperatures of $path"
  for temp in $trip_temps; do
    tmp=$(cat "$path/$temp")
    if [ "$tmp" -ge 0 ] || [ "$tmp" -eq "$default" ]; then
      test_print_trc "Temperature value of $temp: $tmp is expected"
      return 0
    else
      return 1
    fi
  done
}

valid_trip_type() {
  local my_type=$1
  shift 2

  for trip in $TRIP_TYPES; do
    if [ "$trip" == "$my_type" ]; then
      return 0
    fi
  done

  return 1
}

############################ Script Variables ##################################
TRIP_TYPES="active critical passive hot"

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.

# Uncomment the following line if you want the change the behavior of
# do_cmd to treat non-zero values as pass and zero as fail.
# inverted_return="true"
for_each_thermal_zone check_type || return 1
for_each_thermal_zone check_temp || return 1
