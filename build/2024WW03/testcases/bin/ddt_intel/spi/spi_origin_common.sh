#!/bin/bash

###############################################################################
# Copyright (C) 2018, Intel - http://www.intel.com
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
# Nov, 2018. Hongyu Ning <hongyu.ning@intel.com>
#     - Revised to keep original support for platforms rather than icl-u-rvp,
#       such as tgl-generic-simics

############################ DESCRIPTION ######################################

# @desc     This script contains kmodules names and variables for WDT test
# @returns
# @history  2017-06-15: First version
# @history  2018-11-09: 1st revision

############################# FUNCTIONS #######################################

################################ DO THE WORK ##################################

# KMODULE NAME
DRV_MOD_NAME="spi_pxa2xx_platform"

# SYSFS DEVICE PATH
DRV_SYS_PATH="/sys/class/spi_master"

# SYSFS KMODULE PATH
# SPI_PLTF_PATH="/sys/bus/platform/drivers/pxa2xx-spi"

# ARRAY/HASH
declare -A DRV_HASH=(["CONFIG_SPI"]="" ["CONFIG_SPI_MASTER"]="" ["CONFIG_SPI_PXA2XX"]="spi_pxa2xx_platform")
declare -a DRVS_LOADED
declare -a DRVS_UNLOADED
declare -a ATTRIBUTE=('uevent')

# SPI related DRIVER PATH
SPI_PXA_DRV_PATH="/sys/bus/platform/drivers/pxa2xx-spi"
