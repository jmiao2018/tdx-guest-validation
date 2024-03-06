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

# @desc     This script contains kmodules names and variables for ITH test
# @returns
# @history  2017-08-05: First version

############################# FUNCTIONS #######################################

################################ DO THE WORK ##################################

# KMODULE NAME
DRV_MOD_NAME="intel_th"

# SYSFS DEVICE PATH
DRV_SYS_PATH="/sys/bus/intel_th/devices/0-gth"

# SYSFS KMODULE PATH
ITH_BUS_PATH="/sys/bus/intel_th/drivers/gth"

# SYSFS STP POLICIES PATH
SP_SYSFS_PATH="/config/stp-policy"

# MY TRACE FILE PATH
if [[ "$OS" = "android"   ]]; then
MY_TRACE="/data/ltp/tmp/my_trace"
else
MY_TRACE="/home/qa/my_trace"
fi

# ENUMERATION DEVICE ID & KERNEL MODULE
ENUM_DEVICE="8086:318e"
KD="intel_th_pci"

# ARRAY/HASH
declare -A DRV_HASH=(["CONFIG_INTEL_TH"]="intel_th")
declare -a DRVS_LOADED
declare -a DRVS_UNLOADED
declare -a ATTRIBUTE=('uevent')
