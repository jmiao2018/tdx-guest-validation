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
#   Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     -Changed shebang and some cmd's to force the use busybox cmd set.
#     -Removed logic to work with ubifs - This FS will not be met in DUT's.
#    Ruben A. Diaz Jimenez <ruben.a.diaz.jimenez@intel.com> - Intel
#     -Added -k option to not erase  mount point and its files.
###############################################################################

# @desc Perform umount etc on blk device like mmc,emmc mount point
# @params [-n DEV_NODE] [-k KEEP_FILE_FLAG]
# @returns None
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-16: Ported to work with Android on IA.
# @history 2015-05-14: Added -k option.

source "common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
  usage: ./${0##*/} [-n DEV_NODE] [-d DEVICE_TYPE] [-m MNT_POINT]
                    [-k KEEP_FILE_FLAG]
    -n DEV_NODE       optional param; device node like /dev/mtdblock2; /dev/sda1
    -d DEVICE_TYPE    device type like 'nand', 'mmc', 'usb' etc
    -m MNT_POINT
    -f FS_TYPE        file system type
    -k KEEP_FILE_FLAG whether to erase or not MNT_POINT
    -h Help           print this usage
EOF
exit 0
}

############################### CLI Params ###################################
while getopts :n:d:f:m:k:h arg; do
case "${arg}" in
  n)   DEV_NODE="$OPTARG" ;;
  d)   DEVICE_TYPE="$OPTARG" ;;
  f)   FS_TYPE="$OPTARG" ;;
  m)   MNT_POINT="$OPTARG" ;;
  k)   KEEP_FILE_FLAG="$OPTARG" ;;
  h)   usage ;;
  :)   test_print_err "$0: Must supply an argument to -$OPTARG."
       die
       ;;
  \?)  test_print_err "Invalid Option -$OPTARG ignored."
       die
       ;;
esac
done

############################ DEFAULT Params #######################
: ${KEEP_FILE_FLAG:='0'}

if [[ -z "${DEV_NODE}" ]]; then
  DEV_NODE=$(get_blk_device_node.sh -d "${DEVICE_TYPE}") \
    || block_test "Error getting device node for ${DEVICE_TYPE}: ${DEV_NODE}"
fi
############# Do the work ###########################################

do_cmd blk_device_umount.sh -m "${MNT_POINT}" -k "${KEEP_FILE_FLAG}"
