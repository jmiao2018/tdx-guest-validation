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
# @desc     Check charger curent and max control limit
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "charger_functions.sh"

############################# Functions #######################################
check_charger_limits() {
    local curr_limit=$(cat ${CHARGER_PATH}/charge_control_limit)
    local max_limit=$(cat ${CHARGER_PATH}/charge_control_limit_max)
    local msg=""

    test_print_trc "Checking charger control limits: $CHARGER_PATH"
    test_print_trc "Charger current control limit: $curr_limit"
    test_print_trc "Charger max control limit: $max_limit"

    msg="if current control limit is greater/equal to 0"
    check "$msg" test "$curr_limit -ge 0" || return 1

    msg="if max control limit is greater/equal to 0"
    check "$msg" test "$max_limit -ge 0" || return 1

    msg="if current control limit is lees/equal to max control limit"
    check "$msg" test "$curr_limit -le $max_limit" || return 1
    return 0
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
check_charger_limits || die "Error on charger control limits"
