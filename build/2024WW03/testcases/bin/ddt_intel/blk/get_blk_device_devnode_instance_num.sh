#!/bin/bash

###############################################################################
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
# Copyright (C) 2015 Intel - http://www.intel.com/
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
# Contributors:
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -Changed shebang and some cmd's to force the use busybox cmd set.
###############################################################################

# @desc Get mmc instance number for mmc or emmc
# @params <device_type>
# @returns Instace number
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-19: Ported to work with Android on IA.

source "blk_device_common.sh"

if [[ $# -ne 1 ]]; then
  echo "Error: Invalid Argument Count"
  echo "Syntax: $0 <device_type>"
  exit 1
fi

############################ USER-DEFINED Params ##############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically
case $ARCH in
esac
case $DRIVER in
esac
case $SOC in
esac
case $MACHINE in
esac

######################### Logic here ###########################################
device_type=$1

dev_node=$(get_blk_device_node.sh -d "${device_type}") \
  || block_test "Failed to get device node for ${device_type}: ${dev_node}"

devnode_entry=$(get_devnode_entry.sh "${dev_node}" "${device_type}") \
  || die "Failed to get dev node entry for ${dev_node}: ${devnode_entry}"

instance_num=$(get_devnode_instance_num "${devnode_entry}") \
  || die "Failed to get instance number for ${devnode_entry}: ${instance_num}"

echo "${instance_num}"
