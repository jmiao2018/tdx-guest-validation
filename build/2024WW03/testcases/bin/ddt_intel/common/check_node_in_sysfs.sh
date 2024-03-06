#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2017 Intel - http://www.intel.com/
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
# Contributors:
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -Initial draft.
###############################################################################
# @desc Search for device nodes under sysfs (/sys/class/).
# @params s) device_type like: mmc, rtc, pwm.
# @returns Number of entries found.
# @history 2015-04-20: First version.

source "common.sh"  # Import do_cmd(), die() and other functions

############################# Functions #######################################
usage() {
  cat <<-EOF
    usage: ./${0##*/} [-d device_type] [-m minimum_entries] [-s specific_device]
    -d DEVICE_TYPE     device type like 'mmc', 'rtc', 'pwm', etc...
    -m MINIMUM_ENTRIES to find under sysfs.
    -s SPECIFIC_DEVICE to match under sysfs like rtc0, mmcblk1, etc...
    -h Help            print this usage.
EOF
}

# Obtain the number of entries of a certain device in sysfs.
# Input: dev_type string containing the device type e.g. mmc, rtc, etc...
#        search_dir folder to search device entries.
# Return: number of entries of dev_type in search_dir.
get_num_entries_in_sysfs() {
  if [[ $# -ne 2 ]]; then
    die "Error: in ${FUNCNAME[0]}() not enough args..."
  fi
  local dev_type="$1"
  local search_dir="$2"
  local sysfs_entries
  sysfs_entries=$(ls "$search_dir" | grep -c "$dev_type" 2>&1)
  echo "$sysfs_entries"
}

# Check if a specific device is present in sysfs.
# Input: dev_2_match device to match e.g. mmcblk0, rtc0, etc...
#        search_dir
# Return:
is_device_present() {
  if [[ $# -ne 2 ]]; then
    die "Error: in ${FUNCNAME[0]}() not enough args..."
  fi
  local dev_2_match="$1"
  local search_dir="$2"
  local dev_present="no"
  local dev_found
  dev_found=$(find "$search_dir" -name "$dev_2_match" 2>&1)
  [[ -n "$dev_found" ]] && dev_present="yes"
  echo "$dev_present"
}


############################ Script Variables ##################################
# Define default values if possible
: "${MINIMUM_ENTRIES:='1'}"
SYSFS_PATH="/sys/class"
DEV_TYPE_FOLDER=""
SEARCH_DIR=""
NUM_ENTRIES=""

################################ CLI Params ####################################
while getopts  :d:m:s:h arg; do
  case $arg in
    d)  DEVICE_TYPE="$OPTARG";;
    h)  usage && exit 0;;
    m)  MINIMUM_ENTRIES="$OPTARG";;
    s)  SPECIFIC_DEVICE="$OPTARG";;
    :)  die "$0: Must supply an argument to -$OPTARG.";;
   \?)  die "Invalid Option -$OPTARG ";;
  esac
done

########################### DYNAMICALLY-DEFINED Params #########################
if [[ -z "$DEVICE_TYPE" ]]; then
  die "Error: <device_type> argument is missing..."
fi

# Decide device type search folder
case "$DEVICE_TYPE" in
  mmc)  DEV_TYPE_FOLDER="block";;
  rtc)  DEV_TYPE_FOLDER="rtc";;
  pwm)  DEV_TYPE_FOLDER="pwm";;
  # Add here any extra device_type
  *)    die "Error: $0 does not support $DEVICE_TYPE as DEVICE_TYPE";;
esac
SEARCH_DIR="${SYSFS_PATH}/${DEV_TYPE_FOLDER}/"

# Get number of entries in sysfs
test_print_trc "Searching for entries in $SEARCH_DIR"
NUM_ENTRIES=$(get_num_entries_in_sysfs "$DEVICE_TYPE" $SEARCH_DIR)
test_print_trc "$NUM_ENTRIES obtained in ${DEV_TYPE_FOLDER} for $DEVICE_TYPE"

########################### REUSABLE TEST LOGIC ###############################
# Check entries number
if [[ "$NUM_ENTRIES" -lt "$MINIMUM_ENTRIES" ]]; then
  die "Error: $MINIMUM_ENTRIES entries are required and $NUM_ENTRIES were found"
fi

# Check specific device
if [[ -n "$SPECIFIC_DEVICE" ]]; then
  DEV_PRESENT=$(is_device_present "$SPECIFIC_DEVICE" $SEARCH_DIR)
  [[ "$DEV_PRESENT" = "no" ]] && die "Error: specific device is not present !"
fi
exit 0
