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
#     -Modified mount point and R/W ops folder due to permission
#      restriction in Android rootfs, change to /data.
#     -Added verification before umount and mount_point removal.
#     -Removed duplicated 'source' scripts.
#     -Removed useless logic.
#     -Added -k option to not erase  mount point and its files.
#     -Removed unused options from getops.
#     -Removed VOLD remount, it is not necessary.
###############################################################################

# @desc Perform umount etc on blk device like mmc, emmc, mount point
# @params [-m MNT_POINT] [-k KEEP_FILE_FLAG]
# @returns None
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-18: Ported to work with Android on IA.
# @history 2015-04-07: Added verification before umount and mount_point removal.
# @history 2015-04-27: Removed duplicated 'source' scripts.
# @history 2015-05-13: Removed useless logic.
# @history 2015-05-14: Added -k option.
#                      Removed unused options.
#                      Removed VOLD remount.

source "blk_device_common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
  usage: ./${0##*/} [-m MNT_POINT] [-k KEEP_FILE_FLAG]
    -m MNT_POINT
    -k KEEP_FILE_FLAG whether to erase or not MNT_POINT
    -h Help           print this usage
EOF
exit 0
}

############################### CLI Params ###################################

while getopts :m:k:h arg; do
case "${arg}" in
  m)  MNT_POINT="$OPTARG" ;;
  k)  KEEP_FILE_FLAG="$OPTARG" ;;
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
: ${KEEP_FILE_FLAG:='0'}

############# Do the work ###########################################
test_print_trc "Umounting device"
test_print_trc "MNT_POINT: ${MNT_POINT}"
if [[ "${MNT_POINT}" = "/" ]] || [[ "${MNT_POINT}" = "/boot/efi" ]]; then
  test_print_trc "Mount point is rootfs or boot partition, should not umount"
  exit
fi
MNT_POINT=$( readlink -f "${MNT_POINT}")
mount | grep -q "${MNT_POINT}"
[[ $? -eq 0 ]] && do_cmd "umount ${MNT_POINT}"

if [[ -d "${MNT_POINT}" && "${KEEP_FILE_FLAG}" -ne 1 ]]; then
  do_cmd "rm -r -f ${MNT_POINT}"
fi
