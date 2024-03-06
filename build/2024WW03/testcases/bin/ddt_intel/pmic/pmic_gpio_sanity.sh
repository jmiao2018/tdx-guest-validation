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
# @desc     Check if pmic gpio chipset is register under /sys/class/gpios
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "pmic_functions.sh"

############################# Functions #######################################
check_pmic_gpio() {
    local label=$(find ${GPIO_PATH}/gpio*/label -type f -print0 | \
                  xargs -0 grep -l $PMIC_GPIO_CHIPSET)
    local path=$(dirname $label)
    local msg="if $PMIC_GPIO_CHIPSET is registered under $GPIO_PATH"

    check "$msg" test " -n $path" || return 1
    test_print_trc "$PMIC_GPIO_CHIPSET path: $path"
    return 0
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
check_pmic_gpio || die "Error on pmic gpio sanity"
