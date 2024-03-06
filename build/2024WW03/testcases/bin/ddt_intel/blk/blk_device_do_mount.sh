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
#     -Modified mount point and R/W ops folder due to permission restriction in
#      Android rootfs, changed to /data.
#     -Removed code:
#     -Logic for ubifs - just for MTD and not present in DUT's.
#     -Use of get_device_type_map.sh - just for MTD and not present in DUT's.
#     -Added mount check and umount before mounting.
#     -Removed duplicated 'source' scripts.
#     -Enhance umount before mounting logic.
#     -Added arguments check  logic.
#   Zelin Deng <zelinx.deng@intel.com> (Intel)
#     -Replace the const field of mount point by get_mnt_point_field() to fit
#     the upstream kernel.
#     -Remove $BUSYBOX_DIR
#   Juan Carlos Alonso <juan.carlos.alonso@intel.com> (Intel)
#     -Remove unnecesary code and add useful log prints to have a better debug.
###############################################################################

# @desc Perform mount and check if mount ok
# @params [-f FS_TYPE] [-n DEV_NODE] [-m MNT_POINT] [-d DEVICE TYPE] [-o MNT_MODE
# @returns None
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-16: Ported to work with Android on IA.
# @history 2015-04-08: Added mount check.
# @history 2015-04-27: Removed duplicated 'source' scripts.
# @history 2015-05-13: Enhace umount before mounting logic.
#                      Added arguments check.
# @history 2015-08-15: Replaced mount point field
# @history 2018-02-14: Remove unnecesary code and add useful log prints to have
#                      a better debug.

source "blk_device_common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
  usage: ./${0##*/} [-f FS_TYPE] [-n DEV_NODE] [-m MNT_POINT] [-d DEVICE TYPE] [-o MNT_MODE]
    -f FS_TYPE   filesystem type like vfat, ext2, etc.
                 if it is not specified, all the filesystem types will be tried
    -n DEV_NODE  device_node like /dev/block/mmc1
    -m MNT_POINT mount point
    -d DEV_TYPE  device type like 'mmc', 'emmc'
    -o MNT_MODE  mount mode: either 'sync' or 'async'. default is 'async'
    -h Help      print this usage
EOF
exit 0
}
############################### CLI Params ###################################

while getopts :d:f:n:m:o:h arg; do
case "${arg}" in
  n)  DEV_NODE="$OPTARG" ;;
  d)  DEV_TYPE="$OPTARG" ;;
  f)  FS_TYPE="$OPTARG" ;;
  m)  MNT_POINT="$OPTARG" ;;
  o)  MNT_MODE="$OPTARG" ;;
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
: "${MNT_POINT:="$TEST_MNT_DIR/partition_${DEV_TYPE}_$$"}"
: "${MNT_MODE:="async"}"

############# Do the work ###########################################
# Check args
[[ -z "${DEV_TYPE}" ]] && die "Argument missing: DEV_TYPE can't be empty"

# Get dev_node if not provided
if [[ -z "${DEV_NODE}" ]]; then
  DEV_NODE=$(get_blk_device_node.sh -d "${DEV_TYPE}") \
    || block_test "Error getting device node for ${DEV_TYPE}: ${DEV_NODE}"
fi

# Get dev_node_entry something like /dev/mmcblk0, etc
DEV_NODE_ENTRY=$(get_devnode_entry.sh "${DEV_NODE}" "${DEV_TYPE}") \
  || die "Getting devnode entry for ${DEV_NODE}"

test_print_trc "Create MOUNT POINT directory"
[[ -d "${MNT_POINT}" ]] || do_cmd mkdir -p "${MNT_POINT}"

field=$(get_mnt_point_field)
# Umount dev_node if mounted either by VOLD or other
test_print_trc "Umount ${DEV_NODE} if it is mounted"
# Use "-w" to completely match the whole words for finding the mount point of
# the DEV_NODE_ENTRY.
# Eg: grep -w "mmcblk0p1" can only match lines with "mmcblk0p1" and lines with
# "mmcblk0p10" won't be matched.
mount | grep -w "${DEV_NODE}" \
  && CUR_MNT_POINT=$(mount | grep "${DEV_NODE}" | cut -d' ' -f"${field}") \
  && umount "${CUR_MNT_POINT}"
mount | grep "/dev/block/vold" \
  && CUR_MNT_POINT=$(mount | grep "/dev/block/vold" | cut -d' ' -f"${field}") \
  && umount "${CUR_MNT_POINT}"
sleep 2

# Umount mount point if previously mounted with other dev_node
test_print_trc "Umount ${MNT_POINT} if it is mounted"
mount | grep "${MNT_POINT}" && umount "${MNT_POINT}"
sleep 2

# Mount partition
test_print_trc "Mount ${DEV_NODE}"
if [[ -n "${FS_TYPE}" ]]; then
  do_cmd mount -t "${FS_TYPE}" -o "${MNT_MODE}" "${DEV_NODE}" "${MNT_POINT}"
  mount | grep "${MNT_POINT}"
else
  fs_to_try="vfat:ext2:ext3:ext4"
  # Try all FS's to mount
  oldIFS="${IFS}"
  IFS=":"
  for FS in ${fs_to_try}; do
    test_print_trc "---${FS}---"
    test_print_trc "Try to mount ${FS}"
    mount -t "${FS}" -o "${MNT_MODE}" "${DEV_NODE}" "${MNT_POINT}" || {
      test_print_trc "Failed to mount ${DEV_NODE} to ${MNT_POINT}, ret=$?"
      continue
    }

    sleep 1
    mount | grep "${MNT_POINT}"
    if [[ $? -eq 0 ]]; then
      test_print_trc "Mount ${DEV_NODE} to ${MNT_POINT} successfully"
      break
    fi
  done

IFS="${oldIFS}"
fi
