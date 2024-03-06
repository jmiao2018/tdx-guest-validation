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
# @desc     Check charger current and max charge current
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "charger_functions.sh"

############################# Functions #######################################
check_charger_currents() {
    local current=$(cat ${CHARGER_PATH}/charge_current)
    local max_current=$(cat ${CHARGER_PATH}/max_charge_current)
    local msg=""

    test_print_trc "Checking charger currents: $CHARGER_PATH"
    test_print_trc "Charger charge current: $current"
    test_print_trc "Charger max charge current: $max_current"

    msg="if charge current is greater than 0"
    check "$msg" test "$current -gt 0" || return 1

    msg="if max charge current is greater than to 0"
    check "$msg" test "$max_current -gt 0" || return 1

    msg="if charge current is lees/equal to max charge current"
    check "$msg" test "$current -le $max_current" || return 1
    return 0
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
connect_OTG || die "Could not connect OTG cable"

check_charger_currents || die "Error on charger currents"
