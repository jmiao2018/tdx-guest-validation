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
# Oct, 29, 2018. Hongyu Ning <hongyu.ning@intel.com>
#     - Define new SPI DRIVER PATH and DEVICE PATH

############################ DESCRIPTION ######################################

# @desc     This script contains kmodules names and variables for WDT test
# @returns
# @history  2017-06-15: First version
# @history  2018-10-29: 2nd version to suppot full spi devices and driver test
# @history  2019-01-16: Move SPI_DEV_ID related info into params file of each plf

############################# FUNCTIONS #######################################

################################ DO THE WORK ##################################

# KMODULE NAME
DRV_MOD_NAME="spi_pxa2xx_platform"
DRV_MOD_NAME_1="spidev"

# SYSFS DEVICE PATH
DRV_SYS_PATH="/sys/class/spi_master"
DRV_SYS_PATH_1="/sys/class/spidev"

# SYSFS KMODULE PATH
# SPI_PLTF_PATH="/sys/bus/platform/drivers/pxa2xx-spi"

# ARRAY/HASH
declare -A DRV_HASH=(["CONFIG_SPI"]="" ["CONFIG_SPI_MASTER"]="" ["CONFIG_SPI_PXA2XX"]="spi_pxa2xx_platform" ["CONFIG_SPI_SPIDEV"]="spidev")
declare -a DRVS_LOADED
declare -a DRVS_UNLOADED
declare -a ATTRIBUTE=('uevent')

# SPI related DRIVER PATH
SPI_DRV_PATH="/sys/bus/spi/drivers/spidev"
SPI_PXA_DRV_PATH="/sys/bus/platform/drivers/pxa2xx-spi"
SPI_PCI_DRV_PATH="/sys/bus/pci/drivers/intel-lpss"
