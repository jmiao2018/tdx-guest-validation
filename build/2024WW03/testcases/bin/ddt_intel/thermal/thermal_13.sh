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
# @desc     Check the limit value of cur_state attribute for each cooling device
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-03-17: First Version (Luis Rivas)

source common.sh
source functions.sh
source thermal_functions.sh

############################# Functions #######################################
check_max_state() {
  local cdev_name=$1
  local cdevpath=$THERMAL_PATH/$cdev_name
  shift 1
  local max_state=""
  local cur_state=""
  local prev_state=0
  local invalid_state=$((max_state + 1))
  local is_intel_powerclamp=""

  max_state=$(cat "$cdevpath"/max_state)
  cur_state=$(cat "$cdevpath"/cur_state)
  is_intel_powerclamp=$(cat "$cdevpath"/type)

  if [ "x$is_intel_powerclamp" != "xintel_powerclamp" ]; then
    check "$cdev_name cur_state=$cur_state, max_state=$max_state" \
          "test $max_state -ge $cur_state" || return 1
    prev_state=$cur_state
    test_print_trc "Change $cdev_name cur_state to invalid state: $invalid_state"
    echo $invalid_state > "$cdevpath"/cur_state 2> /dev/null
    cur_state=$(cat "$cdevpath"/cur_state)
    check "$cdev_name cur_state=$cur_state, max_state=$max_state" \
          "test $max_state -ge $cur_state"
    if [ $? -ne 0 ]; then
      echo "$prev_state" > "$cdevpath"/cur_state
      return 1
    fi

    echo "$prev_state" > "$cdevpath"/cur_state
    return 0
  else
    test_print_trc "$cdev_name is intel_powerclamp, not managered by kernel, skip"
    return 0
  fi
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
for_each_cooling_device check_max_state || exit 1
