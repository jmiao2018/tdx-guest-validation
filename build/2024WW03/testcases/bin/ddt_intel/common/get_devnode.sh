#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
# Copyright (C) 2017 Intel Corperation - http://www.intel.com/
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
#     -Modify devnode adquisition to do dynamically (it was hardcoded).
#     -Added case for mmc/emmc dev types (it was default before but changed due
#      mtd,scsi devs are not present in our DUT's).
#     -Modify default case to raise error.
###############################################################################

# @desc Get devnode for all device types
# @params <device_type> like 'rtc', 'i2c', 'mmc'
# @returns devnode
# @history 2015-03-15: Copied from ddt -> ddt_intel
# @history 2015-03-19: Ported to work with Android on IA.

source "common.sh"

if [[ $# -ne 1 ]]; then
  echo "Error: Invalid Argument Count"
  echo "Syntax: $0 <device_type>"
  exit 1
fi
DEVICE_TYPE=$1

############################ Default Params ##############################
case $DEVICE_TYPE in
  rtc)
    DEV_NODE=$(find /dev -name "rtc[0,9]" | head -1)
    ;;
  i2c)
    DEV_NODE=$(find /dev -name "i2c-*" | head -1)
    ;;
  wdt)
    DEV_NODE=$(find /dev -name watchdog | head -1)
    ;;
  mmc | emmc)
    DEV_NODE=$(get_blk_device_node.sh "$DEVICE_TYPE") \
      || block_test "error getting $DEV_TYPE devnode"
    ;;
  *)
    die "Error no such $DEVICE_TYPE device_type "
    ;;
esac

######################### Logic here ###########################################
echo "$DEV_NODE"
