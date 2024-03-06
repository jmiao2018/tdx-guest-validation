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

# @desc     This script contains kmodules names and variables for LPC test
# @returns
# @history  2017-08-05: First version

############################# FUNCTIONS #######################################

################################ DO THE WORK ##################################
source "common.sh"

# SYSFS DEVICE PATH
ATKBD_SYSFS="/sys/bus/serio/drivers/atkbd/serio0"
PSMOUSE_SYSFS="/sys/bus/serio/drivers/psmouse/serio1"

# ARRAY/HASH
declare -a ATTRIBUTE_ATKBD=('scroll' 'set' 'softrepeat' 'bind_mode' 'bind_mode' 'description' 'drvctl' 'firmware_id' 'modalias')
declare -a ATTRIBUTE_PSMOUSE=('bind_mode' 'description' 'drvctl' 'firmware_id' 'modalias' 'resync_time')
