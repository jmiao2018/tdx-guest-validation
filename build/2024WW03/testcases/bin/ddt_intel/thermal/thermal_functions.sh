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
#     Luis Rivas <luis.miguel.rivas.zepeda.intel.com> (Intel)
#       - modified max zone and max cdev
#       - modified for_each_thermal_zone
#       - modified functions to exit when failure is detected
#       - added filter thermal zone function
#       - added function to verify if cdev is a software device
#

source "xml_parser.sh"  # Common function to parse xml files

############################# Functions #######################################
check_valid_temp() {
  local file=$1
  local zone_name=$2
  local zero_included=${3:-0} # Default value is 0

  local dir=$THERMAL_PATH/$zone_name
  local temp_file=$dir/$file
  local temp_val=0
  local msg=""
  local test_cmd=""

  temp_val=$(cat "$temp_file")

  if [ "$zero_included" -eq 1 ]; then
    msg="if temp of $temp_file is greater/equal to 0, temp value: $temp_val"
    test_cmd="test $temp_val -ge 0"
  else
    msg="if temp of $temp_file is greater than 0, temp value: $temp_val"
    test_cmd="test $temp_val -gt 0"
  fi

  check "$msg" "$test_cmd" && return 0 || return 1
}

for_each_thermal_zone() {
  local func=$1
  shift 1
  local zones=""

  zones=$(regex_scan_dir "$THERMAL_PATH" "thermal_zone['$MAX_ZONE']")
  if [ -z "$zones" ]; then
    log_end "fail"
    return 1
  fi

  ALL_ZONE=$zones
  filter_thermal_zones

  for zone in $ALL_ZONE; do
    INC=0
    $func $zone $@
    if [ $? -ne 0 ]; then
      return 1
    fi
  done

  return 0
}

get_total_trip_point_of_zone() {
  local zone_path=$THERMAL_PATH/$1
  local count=0
  shift 1

  trips=$(regex_scan_dir "$zone_path" "trip_point_['$MAX_ZONE']_temp")
  for trip in $trips; do
    count=$((count + 1))
  done

  return $count
}

for_each_trip_point_of_zone() {
  local zone_path=$THERMAL_PATH/$1
  local count=0
  local func=$2
  local zone_name=$1
  shift 2

  trips=$(regex_scan_dir "$zone_path" "trip_point_['$MAX_ZONE']_temp")
  for trip in $trips; do
    $func $zone_name $count
    if [ $? -ne 0 ]; then
      return 1
    fi
    count=$((count + 1))
  done

  return 0
}

for_each_binding_of_zone() {
  local zone_path=$THERMAL_PATH/$1
  local count=0
  local func=$2
  local zone_name=$1
  shift 2

  trips=$(regex_scan_dir "$zone_path" "cdev['$MAX_CDEV']_trip_point")
  for trip in $trips; do
    $func $zone_name $count
    if [ $? -ne 0 ]; then
      return 1
    fi
    count=$((count + 1))
  done

  return 0
}

check_valid_binding() {
  local trip_point=$1
  local zone_name=$2
  local dirpath=$THERMAL_PATH/$2
  local temp_file=$2/$1
  local trip_point_val=""
  get_total_trip_point_of_zone "$zone_name"
  local trip_point_max=$?
  local descr="'$temp_file' valid binding"
  shift 2

  trip_point_val=$(cat "$dirpath/$trip_point")

  log_begin "checking $descr"
  if [ "$trip_point_val" -gt "$trip_point_max" ]; then
    log_end "fail"
    return 1
  fi
  log_end "pass"

  return 0
}

validate_trip_bindings() {
  local zone_name=$1
  local bind_no=$2
  local dirpath=$THERMAL_PATH/$1
  local trip_point=cdev$2_trip_point
  shift 2

  check_file "$trip_point" "$dirpath" || return 1
  check_valid_binding "$trip_point" "$zone_name" || return 1
}

validate_trip_level() {
  local zone_name=$1
  local trip_no=$2
  shift 2
  local dirpath=${THERMAL_PATH}/${zone_name}
  local trip_temp=trip_point_${trip_no}_temp
  local trip_type=trip_point_${trip_no}_type
  local tmp=""

  check_file "$trip_temp" "$dirpath" || return 1
  check_file "$trip_type" "$dirpath" || return 1

  tmp=$(cat "$dirpath/$trip_type")
  if [ "$tmp" != "passive" ]; then
    check_valid_temp "$trip_temp" "$zone_name" 1 \
      || return 1 # Greater or equal 0
  fi
}

for_each_cooling_device() {
  local func=$1
  local devices=""
  shift 1

  devices=$(regex_scan_dir "$THERMAL_PATH" "cooling_device['$MAX_CDEV']")

  ALL_DEVICE=$devices
  for device in $devices; do
    INC=0
    $func $device $@
    if [ $? -ne 0 ]; then
      return 1
    fi
  done

  return 0
}

check_scaling_freq() {
  local before_freq_list=$1
  shift 2
  local index=0
  local flag=0

  for cpu in $(regex_scan_dir "$CPU_PATH" "cpu[0-9].*"); do
    if [ "$before_freq_list[$index]" != "$afterf_req_list[$index]" ] ; then
      flag=1
    fi
    index=$((index + 1))
  done

  return $flag
}

store_scaling_maxfreq() {
  scale_freq=
  local index=0

  for cpu in $(regex_scan_dir "$CPU_PATH" "cpu[0-9].*"); do
    scale_freq[$index]=$(cat "$CPU_PATH"/"$cpu"/cpufreq/scaling_max_freq)
    index=$((index + 1))
  done

  return 0
}

get_trip_id() {
  local trip_name=$1
  shift 1
  local id1=""
  local id2=""

  id1=$(echo "$trip_name" | cut -c12)
  id2=$(echo "$trip_name" | cut -c13)
  if [ "$id2" != "_" ]; then
    id1=$((id2 + 10 * id1))
  fi

  return $id1
}

disable_all_thermal_zones() {
  mode_list=
  local index=0
  local th_zones=""

  th_zones=$(regex_scan_dir "$THERMAL_PATH" "thermal_zone['$MAX_ZONE']")
  for zone in $th_zones; do
    mode_list[$index]=$(cat "$THERMAL_PATH"/"$zone"/mode)
    index=$((index + 1))
    echo -n "disabled" > "$THERMAL_PATH"/"$zone"/mode
  done

  return 0
}

enable_all_thermal_zones() {
  local index=0
  local th_zones=""

  th_zones=$(regex_scan_dir "$THERMAL_PATH" "thermal_zone['$MAX_ZONE']")
  for zone in $th_zones; do
    echo "$mode_list[$index]" > "$THERMAL_PATH"/"$zone"/mode
    index=$((index + 1))
  done

  return 0
}

filter_thermal_zones() {
  local count=0
  local ztype=
  local ztemp=0
  local tmp_zones=$ALL_ZONE

  ALL_ZONE=

  for zone in $tmp_zones; do
    ztype=$(cat "$THERMAL_PATH"/"$zone"/'type')
    ztemp=$(cat "$THERMAL_PATH"/"$zone"/temp)

    # Thermal zones with a temperature value of -273200 are not available
    # because the temperature is the default offset. Also, INT3400 thermal
    # is a virtual sensor that has hardcoded value of 20C
    # Also, the zone type must be in the list of active thermal zones
    if [ "$ztemp" -ne -273200 ] && [ "$ztype" != "INT3400 Thermal" ] && \
      [[ $ACT_TZONES =~ $ztype ]]; then
      ALL_ZONE="$ALL_ZONE $zone"
    fi
  done
}

is_software_cooling_device() {
  local cdev=$1
  shift 1

  test -d "$THERMAL_PATH"/"$cdev"/device
  if [ $? -ne 0 ]; then
    return 0
  fi

  return 1
}

get_active_tzones_sofia() {
  local active=""
  local tmp_arr=""
  local my_subchilds=""
  local my_childs=""

  my_childs=$(get_xml_childs "thermalconfig")
  # On sofia SoC the active thermal zones are defined in a xml file used by iTUX
  for child in $my_childs; do
    tmp_arr=($(echo "$child" | tr ':' ' '))
    if [ "${tmp_arr[0]}" == "Sensor" ]; then
      my_subchilds=$(get_xml_childs ${tmp_arr[0]} ${tmp_arr[1]})
      for subchild in $my_subchilds; do
        tmp_arr=($(echo "$subchild" | tr ':' ' '))
        if [ "${tmp_arr[0]}" == "SensorName" ]; then
          active="$active $(get_xml_content ${tmp_arr[1]})"
        fi
      done
    fi
  done
  echo "$active"

  return 0
}

get_active_tzones_baytrail() {
  # All thermal zone should be tested on baytrail
  local tzones=""

  tzones=$(cat "${THERMAL_PATH}"/thermal_zone*/type)
  echo "$tzones"
}

############################ Script Variables ##################################
THERMAL_PATH="/sys/devices/virtual/thermal"
ITUX_XML="/etc/thermal_sensor_config.xml"
MAX_ZONE=0-9
MAX_CDEV=0-9
ALL_ZONE=
ALL_CDEV=
#if linux version later then 3.15, coretemp directory has been changed.
#pleas check this article: https://lkml.org/lkml/2014/5/5/420
CUR_VERSION=$(uname -r | cut -d'-' -f1)
[ $CUR_VERSION \< "3.15" ] && CORETEMP_PATH="/sys/devices/platform/coretemp.0" || \
  CORETEMP_PATH="/sys/devices/platform/coretemp.0/hwmon/$(ls /sys/devices/platform/coretemp.0/hwmon | head -1)"
############################ USER-DEFINED Params ###############################
case $SOC in
  sofia*)
    load_xml  "$ITUX_XML"
    ACT_TZONES=$(get_active_tzones_sofia)
    unload_xml
    ;;
  *)
    ACT_TZONES=$(get_active_tzones_baytrail)
    ;;
esac

test_print_trc "Thermal Zones Enabled: $ACT_TZONES"
