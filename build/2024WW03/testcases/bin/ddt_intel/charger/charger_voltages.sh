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
# @desc     Check charger current and max voltage
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "charger_functions.sh"

############################# Functions #######################################
check_charger_voltages() {
    local voltage=$(cat ${CHARGER_PATH}/charge_voltage)
    local max_voltage=$(cat ${CHARGER_PATH}/max_charge_voltage)
    local msg=""

    test_print_trc "Checking charger voltages: $CHARGER_PATH"
    test_print_trc "Charger voltage: $voltage"
    test_print_trc "Charger max voltage: $max_voltage"

    msg="if charge voltage is greater than 0"
    check "$msg" test "$voltage -gt 0" || return 1

    msg="if max charge voltage is greater than 0"
    check "$msg" test "$max_voltage -gt 0" || return 1

    msg="if charge voltage is lees/equal to max charge voltage"
    check "$msg" test "$voltage -le $max_voltage" || return 1
    return 0

}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
connect_OTG || die "Could not connect OTG cable"

check_charger_voltages || die "Error on charger voltages"
