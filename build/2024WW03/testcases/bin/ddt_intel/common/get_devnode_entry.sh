#!/usr/bin/env bash
################################################################################
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
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
#  -Juan Carlos Alonso <juan.carlos.alonso@intel.com> (Intel)
#     -Changed shebang and some cmd's to force the use busybox cmd set.
#     -Changed 'mmc' to 'sd' in case statement
#     -Added support for 'nvme' in case statement
###############################################################################

# @desc Get devnode entry; like /dev/block/mmcblk0 from /dev/block/mmcblk0p1
# @params <dev_node like /dev/sda1> <device_type like 'usb', 'mmc'>
# @returns None
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-16: Ported to work with Android on IA.
# @history 2018-03-23: Changed 'mmc' to 'sd' in case statement
#                      Added support for 'nvme' in case statement

# Input:  $1 - DEV_NODE like "/dev/block/mmcblk0p1"
#         $2 - DEVICE_TYPE like 'mmc', 'emmc'
# Output: DEVNODE_ENTRY like /dev/block/mmcblk0

source "common.sh"

if [[ $# -ne 2 ]]; then
  echo "Error: Invalid Argument Count"
  echo "Syntax: $0 <dev_node like /dev/block/mmcmblk0> <device_type like 'mmc'>"
  exit 1
fi

######################### Logic here ###########################################
DEV_NODE=$1
DEVICE_TYPE=$2
case $DEVICE_TYPE in
  sd | emmc | nvme)
    DEVNODE_ENTRY=$(echo $DEV_NODE | sed 's/p[0-9]*$//')
    ;;
  *)
    DEVNODE_ENTRY=$(echo $DEV_NODE | sed 's/[0-9]*$//')
    ;;
esac
[[ -n $DEVNODE_ENTRY ]] || die "$0: DEVNODE_ENTRY is empty!"
echo $DEVNODE_ENTRY
