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
# @desc     Check if battery attribute "present" is set to 1
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "battery_functions.sh"

############################# Functions #######################################
is_battery_active() {
    local present=$(cat ${BATTERY_PATH}/present)

    test_print_trc "Checking if battery is active: $BATTERY_PATH"
    check "if battery/present is set to 1" test "$present -eq 1" || return 1
    return 0
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
is_battery_active || die "Error on battery is active"
