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

# Copyright (C) 2015, Intel - http://www.intel.com
# @Author   Luis Rivas <luis.miguel.rivas.zepeda@intel.com>
# @desc     All sysfs entries are named with their code_id (represented here by
#           'X'). https://wwww.kernel.org/doc/Documentation/hwmon/coretemp.
#           The objective is to check coretemp sysfs
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-02-24: First version (Luis Rivas)

source common.sh
source functions.sh
source thermal_functions.sh

############################# Functions #######################################
check_coretemp_attributes() {
  for attr in $ATTRIBUTES; do
    check_file "$attr" "$CORETEMP_PATH" || return 1
  done

  return 0
}

check_coretemp_temps() {
  local indices=""

  indices=$(ls "$CORETEMP_PATH" \
                | grep -oE "$RGX_TMP_INPUT" \
                | grep -oE "$RGX_INDEX")
  for index in $indices; do
    check_file "temp""$index""_crit" "$CORETEMP_PATH" || return 1
    check_file "temp""$index""_crit_alarm" "$CORETEMP_PATH" || return 1
    check_file "temp""$index""_max" "$CORETEMP_PATH" || return 1
    check_file "temp""$index""_max" "$CORETEMP_PATH" || return 1
  done

  return 0
}

############################ Script Variables ##################################
# Define default valus if possible
ATTRIBUTES="name uevent"
RGX_TMP_INPUT="'temp[0-9]_input'"
RGX_INDEX="'[0-9]+'"

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
check_coretemp_attributes || exit 1

check_coretemp_temps || exit 1
