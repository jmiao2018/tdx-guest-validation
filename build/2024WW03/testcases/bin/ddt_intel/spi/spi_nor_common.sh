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

# @Author   Hongyu Ning <hongyu.ning@intel>
#
# Oct, 30, 2018. Hongyu Ning <hongyu.ning@intel.com>
#     - Define new SPI_NOR DRIVER PATH and DEVICE PATH

############################ DESCRIPTION ######################################

# @desc     This script contains kmodules names and variables for SPI-NOR test
# @returns
# @history  2018-10-30: 1st version: define spi-nor device and driver for test

############################# FUNCTIONS #######################################

################################ DO THE WORK ##################################

# KMODULE NAME
DRV_MOD_NAME="mtd"
DRV_MOD_NAME_1="spi_nor"
DRV_MOD_NAME_2="spi_intel"
DRV_MOD_NAME_3="spi_intel_pci"

# SYSFS DEVICE PATH
DRV_SYS_PATH="/sys/class/mtd"

# SYSFS KMODULE PATH
# SPI_PLTF_PATH="/sys/bus/platform/drivers/pxa2xx-spi"

# ARRAY/HASH
declare -A DRV_HASH=(["CONFIG_CMDLINE_PARTITION"]="cmdlinepart" ["CONFIG_SPI_INTEL_SPI_PCI"]="spi_intel_pci" ["CONFIG_SPI_INTEL_SPI"]="spi_intel_pci" ["CONFIG_MTD_SPI_NOR"]="spi_intel_pci" ["CONFIG_MTD"]="spi_intel_pci")
declare -a DRVS_LOADED
declare -a DRVS_UNLOADED
declare -a ATTRIBUTE=('uevent')

# SPI related DRIVER PATH
SPI_NOR_PCI_DRV_PATH="/sys/bus/pci/drivers/intel-spi"
