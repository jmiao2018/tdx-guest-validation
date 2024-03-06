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
# @desc     All suspend states should be disabled
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "pmic_functions.sh"

############################# Functions #######################################
check_reg_susp_states() {
    local reg=$1
    local path=${REG_PATH}/${reg}
    shift 1

    for attr in $SUSP_ATTR; do
        tmp=$(cat ${path}/${attr})
        if [ "$tmp" == "disabled" ]; then
            test_print_trc "${path}/${attr} is disabled"
        else
            test_print_trc "${path}/${attr} is not disabled"
            return 1
        fi
    done
    return 0
}

############################ Script Variables ##################################
# Define default valus if possible
SUSP_ATTR="suspend_disk_state suspend_mem_state suspend_standby_state"

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
for_each_regulator check_reg_susp_states || die "Error on regulators susp states"
