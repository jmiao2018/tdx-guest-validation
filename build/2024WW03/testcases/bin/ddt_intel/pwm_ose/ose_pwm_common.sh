#!/bin/bash

###############################################################################
# Copyright (C) 2019, Intel - http://www.intel.com
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

# @Author   Tony Zhu <tony.zhu@intel>
#
# June, 18, 2019. Tony Zhu <tony.zhu@intel.com>
#     - Define OSE PWM DRIVER PATH and DEVICE PATH

############################ DESCRIPTION ######################################

# @desc     This script contains ose pwm path and driver config
# @returns
# @history  2019-05-29: First version

############################# FUNCTIONS #######################################

################################ DO THE WORK ##################################

# PWM related DRIVER PATH
OSE_PWM_PCI_DRV_PATH="/sys/bus/pci/drivers/pwm-dwc/"
