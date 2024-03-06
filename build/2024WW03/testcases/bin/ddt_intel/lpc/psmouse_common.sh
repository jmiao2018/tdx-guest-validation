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

# @desc     This script contains kmodules names and variables for PSMOUSE test
# @returns
# @history  2017-08-05: First version

############################# FUNCTIONS #######################################

################################ DO THE WORK ##################################
source "common.sh"

# KMODULE NAME
DRV_MOD_NAME="psmouse"

# SYSFS DEVICE PATH
DRV_SYS_PATH="/sys/bus/platform/devices/i8042/serio1"

# SYSFS KMODULE PATH
PSMOUSE_BUS_PATH="/sys/bus/serio/drivers"

# ARRAY/HASH
declare -A DRV_HASH=(["CONFIG_MOUSE_PS2"]="psmouse")
declare -a DRVS_LOADED
declare -a DRVS_UNLOADED
declare -a ATTRIBUTE=('bind_mode' 'description' 'drvctl' 'firmware_id' 'modalias' 'protocol' 'rate' 'resetafter' 'resolution' 'resync_time' 'uevent')
