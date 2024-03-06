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
# @desc     Check if charger health is "Good"
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "charger_functions.sh"

############################# Functions #######################################
check_charger_health() {
    local health=$(cat ${CHARGER_PATH}/health)

    test_print_trc "Checking charger health: $CHARGER_PATH"
    test_print_trc "Charger health: $health"
    if [ "$health" == "Good" ]; then
        test_print_trc "Charger health is good!"
        return 0
    else
        test_print_trc "Charger health is not good!"
        return 1
    fi
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
connect_OTG || die "Could not connect OTG cable"

check_charger_health || die "Error on charger health"
