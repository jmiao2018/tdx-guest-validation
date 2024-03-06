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
# @desc     Check if charger attributes "online" and "present" are set to 1
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "charger_functions.sh"

############################# Functions #######################################
is_charger_active() {
    local online=$(cat ${CHARGER_PATH}/online)
    local present=$(cat ${CHARGER_PATH}/present)

    test_print_trc "Checking if charger is active: $CHARGER_PATH"
    check "if charger/online is set to 1" test "$online -eq 1" ||  return 1
    check "if charger/present is set to 1" test "$present -eq 1" || return 1
    return 0
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
connect_OTG || die "Could not connect OTG cable"

is_charger_active || die "Error on charger is active"
