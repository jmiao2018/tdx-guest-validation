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
#   Juan Carlos Alonso <juan.carlos.alonso@intel.com> (Intel)
#     -Changed shebang and some cmd's to force the use busybox cmd set.
#     -Modified mount point and R/W ops folder due to permission restriction in
#      Android rootfs, change to /data.
#     -Removed unnecessary code:
#       -Import of mtd_common.sh - Not MTD devices present in DUT's.
#       -Fix diffs among Linux & Android (/mnt, cmd's etc...).
#     -Removed duplicated 'source' scripts.
#     -Remove unnecesary code and add useful log prints to have a better debug.
#     -Add 'i' parameter in 'getopts' statement to avoid print extra logs.
###############################################################################

# @desc Erase/format/mount device to prepare test on blk device like mtd, mmc, mount point
# @params [-n DEV_NODE] [-d DEVICE_TYPE] [-f FS_TYPE] [-m MNT_POINT] [-o MNT_MODE]
# @returns None
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-16: Ported to work with Android on IA.
# @history 2015-04-27: Removed duplicated 'source' scripts.
# @history 2018-02-14: Remove unnecesary code and add useful log prints to have
#                      a better debug.
#                      Add 'i' parameter in 'getopts' statement.

source "blk_device_common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
usage: ./${0##*/} [-n DEV_NODE] [-d DEVICE_TYPE] [-f FS_TYPE] [-m MNT_POINT] [-o MNT_MODE] [-i]
  -n DEV_NODE      optional param; device node like /dev/mtdblock2; /dev/sda1
  -f FS_TYPE       filesystem type like vfat, ext2, etc
  -m MNT_POINT     mount point
  -o MNT_MODE      mount mode: 'async' or 'sync'. default is 'async'
  -d DEVICE_TYPE   device type like 'mmc', 'emmc'
  -i IGNORE_PRINTS
  -h Help          print this usage
EOF
exit 0
}

############################### CLI Params ###################################
while getopts :d:f:m:n:o:ih arg; do
case "${arg}" in
  n)  DEV_NODE="$OPTARG" ;;
  d)  DEVICE_TYPE="$OPTARG" ;;
  f)  FS_TYPE="$OPTARG" ;;
  m)  MNT_POINT="$OPTARG" ;;
  o)  MNT_MODE="$OPTARG" ;;
  i)  IGNORE_PRINTS=1 ;;
  h)  usage ;;
  :)  test_print_err "$0: Must supply an argument to -$OPTARG."
      die
      ;;
  \?) test_print_err "Invalid Option -$OPTARG ignored."
      die
      ;;
esac
done

############################ DEFAULT Params #######################
if [[ -z "${DEV_NODE}" ]]; then
  DEV_NODE=$(get_blk_device_node.sh -d "${DEVICE_TYPE}") \
    || block_test "Error getting device node for ${DEVICE_TYPE}: ${DEV_NODE}"
fi

: "${MNT_POINT:=$TEST_MNT_DIR/partition_$DEVICE_TYPE_$$}"
: "${MNT_MODE:='async'}"
: ${IGNORE_PRINTS:=0}

if [[ "${IGNORE_PRINTS}" -eq 0 ]]; then
  test_print_trc "DEV_NODE: ${DEV_NODE}"
  test_print_trc "MNT_POINT:${MNT_POINT}"
  test_print_trc "FS_TYPE:  ${FS_TYPE}"
  test_print_trc "MNT_MODE: ${MNT_MODE}"
fi

is_rf=$(is_part_rootfs "${DEVICE_TYPE}" "${DEV_NODE}")
[[ "${is_rf}" == "yes" ]] && {
  test_print_trc "${DEV_NODE} is rootfs, should not format or mount/umnount"
  exit
}

############# Do the work ###########################################
if [[ -n "${FS_TYPE}" ]]; then
  test_print_trc "Erase/Format ${DEV_NODE}, then mount it"
  do_cmd blk_device_erase_format_part.sh -d "${DEVICE_TYPE}" -n "${DEV_NODE}" -f "${FS_TYPE}" -m "${MNT_POINT}" -i
  do_cmd blk_device_do_mount.sh -n "${DEV_NODE}" -f "${FS_TYPE}" -d "${DEVICE_TYPE}" -m "${MNT_POINT}" -o "${MNT_MODE}"
else
  test_print_trc "Mount ${DEV_NODE} with the existing FS"
  EXISTING_FS=$(get_dev_node_fs "${DEV_NODE}")
  do_cmd blk_device_do_mount.sh -n "${DEV_NODE}" -f "${EXISTING_FS}" -d "${DEVICE_TYPE}" -m "${MNT_POINT}" -o "${MNT_MODE}"
fi
