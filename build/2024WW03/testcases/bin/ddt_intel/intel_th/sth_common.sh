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

# @Author   Juan Pablo Gomez <juan.p.gomez@intel>
#
# Aug, 2017. Juan Pablo Gomez <juan.p.gomez@intel.com>
#     - Initial draft.

############################ DESCRIPTION ######################################

# @desc     This script contains kmodules names and variables for STH test
# @returns
# @history  2017-08-05: First version

############################# FUNCTIONS #######################################

################################ DO THE WORK ##################################

# KMODULE NAME
DRV_MOD_NAME="intel_th_sth"

# SYSFS DEVICE PATH
DRV_SYS_PATH="/sys/bus/intel_th/devices/0-sth"

# SYSFS KMODULE PATH
STH_BUS_PATH="/sys/bus/intel_th/drivers/sth"

# ARRAY/HASH
declare -A DRV_HASH=(["CONFIG_INTEL_TH_STH"]="intel_th_sth")
declare -a DRVS_LOADED
declare -a DRVS_UNLOADED
declare -a ATTRIBUTE=('uevent')
