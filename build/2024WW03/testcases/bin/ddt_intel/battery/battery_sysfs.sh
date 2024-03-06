#!/bin/bash
###############################################################################
# Copyright (C) 2015 Intel - http://www.intel.com
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

# @Author   Luis Rivas(luis.miguel.rivas.zepeda@intel.com)
# @desc     Check if required attributes exist on battery sysfs
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "battery_functions.sh"

############################# Functions #######################################
check_battery_sysfs() {
    for attr in $BATTERY_SYSFS_ATTR; do
       check_file $attr $BATTERY_PATH || return 1
    done
    return 0
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
check_battery_sysfs || die "Error on battery $BATTERY_PATH sysfs"
