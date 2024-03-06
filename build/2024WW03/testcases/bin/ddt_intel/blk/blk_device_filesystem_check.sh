#!/bin/bash

###############################################################################
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
#     -Initial draft.
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -Added logic to umount dev_node before FS check if mounted.
###############################################################################

# @desc Check FS integrity in the specified device.
# @params <-f FS_TYPE> [-n DEV_NODE] [-d DEVICE TYPE]
# @returns None
# @history 2015-05-11: Initial draft.
# @history 2015-05-13: Added logic to umount dev_node before FS check.

source "blk_device_common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
usage: ./${0##*/} [-f FS_TYPE] [-n DEV_NODE] [-d DEVICE TYPE]
  -f FS_TYPE     filesystem type like ext2, ext3, etc.
  -n DEV_NODE    device node like /dev/block/mmcblk1
  -d DEVICE_TYPE device type like 'mmc', 'emmc' etc
  -N             format whole dev_node_entry with no partition
  -h Help        print this usage
EOF
exit 0
}

############################ CLI Params ########################################
while getopts :d:n:f:h arg; do
case "${arg}" in
  d)  DEVICE_TYPE=$OPTARG ;;
  n)  DEV_NODE=$OPTARG ;;
  f)  FS_TYPE=$OPTARG ;;
  h)  usage ;;
  :)  die "$0: Must supply an argument to -$OPTARG." ;;
  \?) test_print_err "Invalid Option -$OPTARG ignored."
      die
      ;;
esac
done

############################ Reusable Logic  ##################################
# Check args
if [[ -z "${DEV_NODE}" ]]; then
  DEV_NODE=$(get_blk_device_node.sh -d "${DEVICE_TYPE}") \
    || block_test "Error getting device node for ${DEVICE_TYPE}: ${DEV_NODE}"
elif [[ -z "${FS_TYPE}" ]]; then
  die "Arguments missing: FS_TYPE can't be empty"
fi

# Block VFAT FS check, because mkfs.VFAT is not currently available
if [[ "${FS_TYPE}" == "vfat" ]]; then
  skip_test "Right now VFAT FS check is not supported !"
else
  FSCK="fsck.${FS_TYPE}"
fi

# Get dev_node_entry
DEV_NODE_ENTRY=$(get_devnode_entry.sh "${DEV_NODE}" "${DEVICE_TYPE}") \
  || die "Getting devnode entry for ${DEV_NODE}"

# Debug prints
test_print_trc "DEVICE TYPE: ${DEVICE_TYPE}"
test_print_trc "DEVICE NODE: ${DEV_NODE}"
test_print_trc "FS TYPE:     ${FS_TYPE}"

# Umount dev_node if mounted with VOLD or other
test_print_trc "Umount ${DEV_NODE} or ${DEV_NODE_ENTRY} if it is mounted"
MNT_POINT_FIELD=$(get_mnt_point_field)
# Use "-w" to completely match the whole words for finding the mount point of
# the DEV_NODE_ENTRY.
# Eg: grep -w "mmcblk0p1" can only match lines with "mmcblk0p1" and lines with
# "mmcblk0p10" won't be matched.
mount | grep -w "${DEV_NODE_ENTRY}" \
  && CUR_MNT_POINT=$(mount | grep -w "${DEV_NODE_ENTRY}" | cut -d' ' -f"${MNT_POINT_FIELD}") \
  && umount "${CUR_MNT_POINT}"
mount | grep -w "/dev/block/vold" \
  && CUR_MNT_POINT=$(mount | grep -w "${DEV_NODE}" | cut -d' ' -f"${MNT_POINT_FIELD}") \
  && umount "${CUR_MNT_POINT}"
sleep 2

# Check device's FS, "-p" option avoid it return an error code in a non-interactive mode
opt_repair=""
"${FSCK}" --help |& grep -q "Automatic repair" && opt_repair="-p"
do_cmd "${FSCK} ${opt_repair} ${DEV_NODE}"
