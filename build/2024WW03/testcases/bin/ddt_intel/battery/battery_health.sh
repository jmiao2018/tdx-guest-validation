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
# @desc     Check if battery health is "Good"
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "battery_functions.sh"

############################# Functions #######################################
check_battery_health() {
    local health=$(cat ${BATTERY_PATH}/health)

    test_print_trc "Checking battery health: $BATTERY_PATH"
    test_print_trc "Battery health: $health"
    if [ "$health" == "Good" ]; then
        test_print_trc "Battery health is Good!"
        return 0
    else
        test_print_trc "Battery health is not Good!"
        return 1
    fi
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
check_battery_health || die "Error on battery health"
