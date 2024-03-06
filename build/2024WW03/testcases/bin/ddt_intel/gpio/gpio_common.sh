#!/bin/bash

###############################################################################
# Copyright (C) 2017, Intel - http://www.intel.com
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
# Aug, 2017. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Initial draft.

############################ DESCRIPTION ######################################

# @desc     This script contains kmodules names and variables for GPIO test
# @returns
# @history  2017-07-07: First version

############################# FUNCTIONS #######################################

################################ DO THE WORK ##################################

# KMODULE NAME
DRV_MOD_NAME="gpio-generic"

# SYSFS DEVICE PATH
DRV_SYS_PATH="/sys/class/gpio"

# SYSFS KMODULE PATH
GPIO_BASE=""
N_GPIO=""

# ARRAY/HASH
declare -A DRV_HASH=(["CONFIG_GPIO_GENERIC"]="gpio-generic" ["CONFIG_GPIO_ACPI"]="" ["CONFIG_GPIO_SYSFS"]="" ["CONFIG_GPIOLIB"]="")
declare -a ATTRIBUTE=('base' 'label' 'ngpio' 'uevent' )
declare -a GPIOS
declare -a GPIO_NUM
declare -a GPIO_CHIPS
declare -a GPIO_SKIPPED
