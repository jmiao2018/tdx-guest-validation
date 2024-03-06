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
# @desc     Check if the regulators has users registered
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "pmic_functions.sh"

############################# Functions #######################################
check_reg_users() {
    local rgx=$( echo $PMIC_ACTIVE_REG | tr " " \| )
    local active=$(find ${REG_PATH}/regulator.*/name -type f -print0 | \
                   xargs -0 grep -El "${rgx}")
    local path=""
    local tmp=0

    test_print_trc "Active regulators: $PMIC_ACTIVE_REG"
    for reg in $active; do
        path=$(dirname $reg)
        tmp=$(cat ${path}/num_users)
        check "if ${path}/num_users is greater than 0" test " $tmp -gt 0" || \
               return 1
    done
    return 0
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
$PMIC_REG_ON
sleep 2
check_reg_users || die "Error on regulator users"
$PMIC_REG_OFF
