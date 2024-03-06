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
#   Alonso Juan Carlos <juan.carlos.alonso@intel.com> (Intel)
#     -Changed shebang and some cmd's to force the use busybox cmd set.
#     -Removed not used code:
#       -Import for mtd_common.sh - not such devices available in DUT's.
#       -Logic for ubifs - just needed for MTD devices.
#     -Remove unnecesary code and add useful log prints to have a better debug.
#     -Add 'i' parameter in 'getopts' statement to avoid print extra logs.
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -Removed not used vars (FLASH_ERASEALL).
#     -Added umount sdcard when mounted by VOLD.
#     -Added -F option to mkfs.EXT/2/3/4 to make it non-interactive.
#     -Fixed VOLD umount typo.
#     -Added arguments check  logic.
#   Zelin Deng <zelinx.deng@intel.com> (Intel)
#     -Replaced "source common.sh" by "source blk_device_common.sh"
#     -Replaced const field of mount point by function get_mnt_point_field() to
#      fit upstream kernel
###############################################################################

# @desc Erase or format storage device based on type
# @params [-f FS_TYPE] [-n DEV_NODE] [-d DEVICE TYPE] [-m MNTPNT]
# @returns None
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-16: Ported to work with Android on IA.
# @history 2015-04-06: Added VOLD umount.
# @history 2015-04-29: Added -F option to mkfs.EXT/2/3/4.
# @history 2015-05-13: Fix VOLD umount typo.
#                      Added arguments check.
# @history 2015-08-13: To fit upstream kernel
# @history 2018-02-14: Remove unnecesary code and add useful log prints to have
#                      a better debug.
#                      Add 'i' parameter in 'getopts' statement.

source "blk_device_common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
  usage: ./${0##*/} [-f FS_TYPE] [-n DEV_NODE] [-d DEVICE TYPE] [-m MNT_POINT] [-i]
    -f FS_TYPE       filesystem type like jffs2, ext2, etc
    -n DEV_NODE      device node like /dev/mtdblock3; /dev/sda1
    -d DEVICE_TYPE   device type like 'nand', 'mmc', 'usb' etc
    -m MNT_POINT
    -i IGNORE_PRINTS
    -h Help          print this usage
EOF
exit 0
}

############################ CLI Params ###########################################
while getopts :d:n:f:m:ih arg; do
case "${arg}" in
  d)  DEVICE_TYPE=$OPTARG ;;
  n)  DEV_NODE=$OPTARG ;;
  f)  FS_TYPE=$OPTARG ;;
  m)  MNT_POINT=$OPTARG ;;
  i)  IGNORE_PRINTS=1 ;;
  h)  usage ;;
  :)  test_print_err "$0: Must supply an argument to -$OPTARG."
      die
      ;;
  \?) test_print_err "Invalid Option -$OPTARG ignored."
      usage
      ;;
esac
done

############################ DEFAULT Params #######################
: ${IGNORE_PRINTS:=0}

if [[ "${FS_TYPE}" = "vfat" ]]; then
  MKFS="mkfs.${FS_TYPE} -F 32"
elif [[ -n "${FS_TYPE}" ]]; then
  #On android,mkfs.ext4 utility does not support "-F" option
  case "${OS}" in
    android) MKFS="mkfs.${FS_TYPE}" ;;
    *)       MKFS="mkfs.${FS_TYPE} -F" ;;
  esac
else
  die "FS_TYPE can not be empty !"
fi

############################ Reusable Logic ##############################
# Check args
[[ -z "${DEVICE_TYPE}" ]] && die "Argument missing: DEVICE_TYPE can't be empty"

# Get dev_node if not provided
if [[ -z "${DEV_NODE}" ]]; then
  DEV_NODE=$(get_blk_device_node.sh -d "${DEVICE_TYPE}") \
    || block_test "Error getting device node for ${DEVICE_TYPE}: ${DEV_NODE}"
fi

# Get dev_node_entry
DEV_NODE_ENTRY=$(get_devnode_entry.sh "${DEV_NODE}" "${DEVICE_TYPE}") \
  || die "Getting devnode entry for ${DEV_NODE}"

# Debug prints
if [[ "${IGNORE_PRINTS}" -eq 0 ]]; then
  test_print_trc "DEVICE TYPE: ${DEVICE_TYPE}"
  test_print_trc "DEVICE NODE: ${DEV_NODE}"
  test_print_trc "FS TYPE: ${FS_TYPE}"
fi

field=$(get_mnt_point_field)

# Umount dev_node if mounted with VOLD or other
test_print_trc "Umount ${DEV_NODE} if it is mounted"
mount | grep -E "${DEV_NODE}" | grep "/dev/block/vold"
if [[ $? -eq 1 ]]; then
  CUR_MNT_POINT=$(mount | grep -w "${DEV_NODE}" | cut -d' ' -f"${field}")
  if [[ -n "${CUR_MNT_POINT}" ]]; then
    do_cmd "umount ${CUR_MNT_POINT}"
  fi
fi
sleep 2
# Format dev_node with specified FS type.
if [[ -n "${FS_TYPE}" ]]; then
   do_cmd "${MKFS} ${DEV_NODE}" > /dev/null
fi
