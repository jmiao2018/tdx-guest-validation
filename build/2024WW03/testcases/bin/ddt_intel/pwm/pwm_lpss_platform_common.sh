#!/bin/bash

###############################################################################
# Copyright (C) 2015, Intel - http://www.intel.com
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

############################ CONTRIBUTORS #####################################

# @Author   Juan Carlos Alonso <juan.carlos.alonso@intel>
#
# Jun, 2017. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Initial draft.

############################ DESCRIPTION ######################################

# @desc     This script contains kmodules names and variables for PWM test
# @returns
# @history  2017-06-15: First version

############################# FUNCTIONS #######################################

################################ DO THE WORK ##################################

# KMODULE NAME
DRV_MOD_NAME="pwm_lpss_platform"

# SYSFS DEVICE PATH
DRV_SYS_PATH="/sys/class/pwm"

# SYSFS KMODULE PATH
PWM_PCI_PATH="/sys/bus/pci/drivers/pwm-lpss/"

# ARRAY/HASH
#declare -A DRV_HASH=(["CONFIG_PWM"]="" ["CONFIG_PWM_SYSFS"]="" ["CONFIG_PWM_LPSS_PCI"]="pwm_lpss")
declare -a DRVS_LOADED
declare -a DRVS_UNLOADED
declare -a ATTRIBUTE=('export' 'npwm' 'uevent' 'unexport')
