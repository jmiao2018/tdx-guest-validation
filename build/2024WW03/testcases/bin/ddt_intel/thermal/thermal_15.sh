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
# @desc     Check the coretemp under hardware monitor sysfs
# @history  2019-7-14: First Version (Yahui Cheng)

source common.sh
source functions.sh
source thermal_functions.sh

############################# Functions #######################################
check_hwmon_coretemp() {

  ls $HWMON_PATH/hwmon*/name &> /dev/null || die "There is no name in hwmon path"
  grep -q "coretemp" $HWMON_PATH/hwmon*/name || die "There is no coretemp"

}

############################ Script Variables ##################################
# Define default valus if possible
HWMON_PATH="/sys/class/hwmon"

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
check_hwmon_coretemp
