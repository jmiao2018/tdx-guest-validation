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
# @desc     Check if intel_soc_pmic_i2c driver is register under
#           /sys/bus/i2c/drivers, and check that intel_soc_pmic_i2c is attach to
#           a i2c adapater. The adapter should contains softlinks to pmic drivers
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "pmic_functions.sh"

############################# Functions #######################################
check_pmic_i2c() {
    local path=${I2C_PATH}/${PMIC_I2C_DRIVER}
    local i2c_adapter=
    local tmp=""

    check "$PMIC_I2C_DRIVER is registered under $I2C_PATH" test " -d $path" || \
           return 1

    i2c_adapter=$(ls $path | grep -e 'i2c-.*:.*$')
    check "if $path has an i2c adapter" test " -n $i2c_adapter" || return 1

    for driver in $PMIC_DRIVERS; do
        tmp=${path}/${i2c_adapter}/${driver}
        check "if $tmp directory exists" test " -d $tmp" || return 1
    done
    return 0
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
check_pmic_i2c || die "Error on pmic i2c sanity"
