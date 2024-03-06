#!/usr/bin/env bash

###############################################################################
#
# Copyright (C) 2019 Intel - http://www.intel.com
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
# @Author   Yahui Cheng (yahuix.cheng@intel.com)
# @desc     Check the coretemp label list under hardware monitor sysfs
# @history  2019-7-14: First Version (Yahui Cheng)

source common.sh
source functions.sh
source thermal_functions.sh

############################ Script Variables ##################################
# Define default valus if possible
RAPL_SYSFS_PATH="/sys/class/powercap"
HWMON_SYSFS_PATH="/sys/class/hwmon"

############################# Functions #######################################

check_coretemp_label() {
  local duration=5
  which turbostat &> /dev/null || die "turbostat does not exist"
  do_cmd "turbostat --debug -o tur.log sleep $duration"
  TURBOSTAT_LABEL_NUM=$(grep -c "^cpu " tur.log)
  test_print_trc "Turbostat cpu number log: $TURBOSTAT_LABEL_NUM"

  [[ -d $RAPL_SYSFS_PATH  ]] || die "RAPL PKG Path does not exist!"
  PACKAGE_NUM=$(grep "package" $RAPL_SYSFS_PATH/intel-rapl:*/name | wc -l)
  test_print_trc "Package number log: $PACKAGE_NUM"

  [[ -d $HWMON_SYSFS_PATH   ]] || die "HWMON Path does not exist!"

  TEMP_PATH_ALL=$(grep 'coretemp' $HWMON_SYSFS_PATH/hwmon*/name | awk -F "name" '{print $1}')
  HWMON_LABEL_NUM=0
  for TEMP_PATH in $TEMP_PATH_ALL; do
    numb=$(grep . $TEMP_PATH/temp*_label | wc -l)
    let HWMON_LABEL_NUM=$HWMON_LABEL_NUM+$numb
  done

  LABEL_NUM=$(((HWMON_LABEL_NUM - PACKAGE_NUM) * 2))

  [[ $LABEL_NUM -eq $TURBOSTAT_LABEL_NUM ]] || die "The label number is not equal!"

}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
check_coretemp_label
