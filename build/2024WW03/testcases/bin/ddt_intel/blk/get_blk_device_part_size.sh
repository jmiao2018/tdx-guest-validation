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
#     -Removed duplicated 'source' scripts.
###############################################################################

# @desc Get size of the specific partition
# @params [-n DEVICE_NODE] [-d DEVICE TYPE]
# @returns DEVICE_PART_SIZE which is the size of the partition
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-17: Ported to work with Android on IA.
# @history 2015-04-27: Removed duplicated 'source' scripts.

source "blk_device_common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
  usage: ./${0##*/} [-n DEVICE_NODE] [-d DEVICE TYPE]
    -n DEV_NODE    block device node like /dev/block/mmcblk1
    -d DEVICE_TYPE device type like 'mmc', 'emmc'
    -h Help        print this usage
EOF
exit 0
}

if [[ $# -lt 1 ]]; then
  test_print_err "Error: Invalid Argument Count"
  die
fi

############################### CLI Params ###################################
while getopts :n:d:h arg; do
  case "${arg}" in
    n)   DEV_NODE="$OPTARG" ;;
    d)   DEVICE_TYPE="$OPTARG" ;;
    h)   usage ;;
    :)   test_print_err "$0: Must supply an argument to -$OPTARG."
         die
         ;;
    \?)  test_print_err "Invalid Option -$OPTARG ignored."
         die
         ;;
  esac
done

SIZE=0

# Size is in MB
SIZE=$(get_part_size_of_devnode "${DEV_NODE}") \
  || die "Error getting partition size for ${DEV_NODE}: ${SIZE}"

echo "${SIZE}"
