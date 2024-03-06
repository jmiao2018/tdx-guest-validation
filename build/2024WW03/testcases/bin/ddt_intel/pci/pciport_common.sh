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
source "common.sh"

# KMODULE NAME
DRV_MOD_NAME="pci_port"

# SYSFS DEVICE PATH
#DRV_SYS_PATH="/sys/bus/pci/drivers/pcieport"
PCI_DIR="/sys/bus/pci/drivers/pcieport"

# SYSFS KMODULE PATH
#ITH_BUS_PATH="/sys/bus/pci/drivers/pcieport"

# ENUMERATION DEVICE ID & KERNEL MODULE
ENUM_DEVICE="8086:31da"
KD="pcieport"

# ARRAY/HASH
declare -A DRV_HASH=(["CONFIG_PCI"]="pciport")
declare -a DRVS_LOADED
declare -a DRVS_UNLOADED
declare -a ATTRIBUTE=('broken_parity_status' 'class' 'config' 'consistent_dma_mask_bits' 'current_link_speed' 'current_link_width' 'd3cold_allowed' 'device' 'dma_mask_bits' 'driver_override' 'enable' 'irq' 'local_cpulist' 'local_cpus' 'max_link_speed' 'max_link_width' 'modalias' 'msi_bus' 'numa_node'  'remove' 'rescan' 'reset' 'resource' 'revision' 'secondary_bus_number' 'subordinate_bus_number' 'subsystem_device' 'subsystem_vendor' 'uevent' 'vendor')
