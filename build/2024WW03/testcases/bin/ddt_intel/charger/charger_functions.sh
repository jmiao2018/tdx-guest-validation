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
# @desc     Common code for charger scripts
# @history  2015-05-19: First version

source "functions.sh"

############################# Functions #######################################
connect_OTG() {
    # For the moment the function does not perform anything, but once the usb
    # switch is enabled, the function will be used to connect the OTG cable to
    # the android device. So, the idea is to only modify this function, and keep
    # the charger scripts as they are.

    # For the moment the OTG cable is always connected. Therefore, return 0
    return 0
}

############################ Script Variables ##################################
# Define default valus if possible
POWER_SUPPLY_PATH="/sys/class/power_supply"
DOLLARCOVE_CHARGER="dollar_cove_charger"
SOFIA_AC_CHARGER="ac_charger"

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)
case $MACHINE in
    ecs* | malata*) CHARGER_PATH=${POWER_SUPPLY_PATH}/${DOLLARCOVE_CHARGER}
                    CHARGER_SYSFS_ATTR="cable_type charge_control_limit \
                                  charge_control_limit_max charge_current \
                                  charge_term_cur charge_voltage enable_charger \
                                  enable_charging health input_cur_limit \
                                  max_charge_current max_charge_voltage \
                                  max_temp min_temp online present type uevent"
                    ;;
    mrd6s)  CHARGER_PATH=${POWER_SUPPLY_PATH}/${SOFIA_AC_CHARGER}
            CHARGER_SYSFS_ATTR="uevent type present online model_name \
                                manufacturer input_cur_limit \
                                constant_charge_current constant_charge_voltage \
                                charge_control_limit_max charge_control_limit"
            ;;
    mrd6sl_*)  CHARGER_PATH=${POWER_SUPPLY_PATH}/${SOFIA_AC_CHARGER}
              CHARGER_SYSFS_ATTR="uevent type present online model_name \
                                  manufacturer input_cur_limit"
              ;;
    *)        die "$MACHINE not supported";;
esac
