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
# @desc     Common code for pmic scripts
# @history  2015-05-19: First version

source "functions.sh"

############################# Functions #######################################
for_each_regulator() {
    local func=$1
    shift 1

    local regulators=$(ls $REG_PATH)
    local path=""
    local name=""

    test_print_trc "Available regulators: $regulators"
    for reg in $regulators; do
        path=${REG_PATH}/$reg
        name=$(cat ${path}/name)

        # skip dummy regulator
        if [ "$name" == "regulator-dummy" ]; then
            test_print_trc "Skipping regulator-dummy"
            continue
        fi

        # check regulator
        test_print_trc "Validating regulator: $path"
        $func $reg $@
        if [ $? -ne 0 ]; then
            test_print_trc "$func $param failed"
            return 1
        fi
    done
    return 0
}

turn_on_byt_reg() {
  # Turn on all pmic /sys/class/regulators
  test_print_trc "Enabling all regulators"
  unlock_device
}

turn_on_sofia_lte_reg() {
  # Turn on all pmic /sys/class/regulators
  test_print_trc "Enabling all regulators"
  unlock_device
  # Wifi must be always enabled
  svc wifi enable
}

turn_off_sofia_lte_reg(){
  # Turn off display, we keep wifi enabled to avoid error in future tests
  test_print_trc "Disabling all regulators"
  lock_device
}

turn_off_byt_reg() {
  # Turn off all pmic /sys/class/regulators
  test_print_trc "Disabling all regulators"
  lock_device
}

turn_on_reg_dummy() {
  test_print_trc "[turn_on_reg_dummy]: Enabling all regulators"
}

turn_off_reg_dummy() {
  test_print_trc "[turn_off_reg_dummy]: Disabling all regulators"
}

is_reg_sysfs_simplified() {
  local reg=$1
  local dir=${REG_PATH}/${reg}

  if [ -f ${dir}/min_microvolts ] && [ -f ${dir}/max_microvolts ]; then
    test_print_trc "$reg has min_microvolts, max_microvoltas and microvolts attr"
    return 1
  else
    test_print_trc "$reg has a simplified sysfs, it only has microvolts attr"
    return 0
  fi
}

unlock_device() {
    # Menu key
    input keyevent 82
}

lock_device() {
    # Lock screen button
    input keyevent 26
}

############################ Script Variables ##################################
# Define default valus if possible
PMIC_NAME=""
PMIC_GPIO_CHIPSET=""
PMIC_I2C_DRIVER=""
PMIC_DRIVERS=""
PMIC_PWSRC_DRIVER=""
PMIC_ACTIVE_REG=""
PMIC_REG_ON=
PMIC_REG_OFF=

REG_PATH="/sys/class/regulator"
GPIO_PATH="/sys/class/gpio"
I2C_PATH="/sys/bus/i2c/drivers"

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)
case $MACHINE in
  ecs* | malata*) PMIC_NAME="dollar_cove"
                  PMIC_GPIO_CHIPSET="axp288-gpio"
                  PMIC_I2C_DRIVER="intel_soc_pmic_i2c"
                  PMIC_PWSRC_DRIVER="dollar_cove_pwrsrc"
                  PMIC_ACTIVE_REG="LDO_3"
                  PMIC_REG_ON=turn_on_byt_reg
                  PMIC_REG_OFF=turn_off_byt_reg
                  PMIC_DRIVERS="dcovex_regulator.8 dcovex_regulator.9 /
                  dollar_cove_adc dollar_cove_battery dollar_cove_charger /
                  dollar_cove_gpio dollar_cove_power_button /
                  dollar_cove_pwrsrc dollar_cove_region"
                  ;;
  mrd6s)  PMIC_ACTIVE_REG="lmmc1"
          PMIC_REG_ON=turn_on_reg_dummy
          PMIC_REG_OFF=turn_off_reg_dummy
          ;;
  mrd6sl_*)   PMIC_ACTIVE_REG="lmmc1 wlan_ldo"
              PMIC_REG_ON=turn_on_sofia_lte_reg
              PMIC_REG_OFF=turn_off_sofia_lte_reg
              ;;
  edison) PMIC_ACTIVE_REG="vprog1"
	  PMIC_I2C_DRIVER="max17042"
	  ;;
    *)  die "$MACHINE not supported";;
esac
