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
# @desc     Check if battery voltages are greater than 0
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "battery_functions.sh"

############################# Functions #######################################
check_battery_voltages() {
    local tmp=0

    test_print_trc "Checking battery voltages: $BATTERY_PATH"
    for volt in $BATTERY_VOLTAGE_ATTR; do
        tmp=$(cat ${BATTERY_PATH}/${volt})
        check "$volt is greater than 0" test "$tmp -gt 0" || return 1
    done
    return 0
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
check_battery_voltages || die "Error on battery voltages"
