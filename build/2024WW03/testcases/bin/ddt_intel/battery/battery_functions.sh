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
# @desc     Common code for battery scripts
# @history  2015-05-19: First version

source "common.sh"
source "functions.sh"

############################ Script Variables ##################################
# Define default valus if possible
POWER_SUPPLY_PATH="/sys/class/power_supply"
DOLLARCOVE_BATTERY="dollar_cove_battery"
SOFIA_BATTERY="battery"

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)
case $SOC in
    baytrail) BATTERY_PATH=${POWER_SUPPLY_PATH}/${DOLLARCOVE_BATTERY}
              BATTERY_CHARGE_ATTR="charge_full charge_full_design charge_now"
              BATTERY_VOLTAGE_ATTR="voltage_now voltage_ocv"
              BATTERY_SYSFS_ATTR="capacity charge_full charge_full_design \
              charge_now current_now health model_name present status \
              technology temp type uevent voltage_now voltage_ocv"
              ;;
    sofia*)   BATTERY_PATH=${POWER_SUPPLY_PATH}/${SOFIA_BATTERY}
              BATTERY_CHARGE_ATTR="charge_full_design charge_now"
              BATTERY_VOLTAGE_ATTR="voltage_now voltage_ocv"
              BATTERY_SYSFS_ATTR="capacity charge_counter charge_full_design \
              charge_now current_now health model_name present status \
              technology temp type uevent voltage_now voltage_ocv"
              ;;
    *)      die "$SOC not supported";;
esac
