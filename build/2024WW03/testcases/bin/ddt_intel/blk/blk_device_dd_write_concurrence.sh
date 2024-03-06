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
#     -Modified mount point and R/W ops folder due to permission restriction in
#      Android rootfs, change to /data.
#     -Removed duplicated 'source' scripts.
###############################################################################

# @desc Perform dd read write concurrently on blk device like mmc,emmc in mount point
# @params [-n DEV_NODE] [-d DEVICE_TYPE] [-f FS_TYPE] [-b DD_BUFSIZE] [-c DD_CNT]
# @returns None
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-16: Ported to work with Android on IA.
# @history 2015-04-27: Removed duplicated 'source' scripts.

source "blk_device_common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
  usage: ./${0##*/} [-n DEV_NODE] [-d DEVICE_TYPE] [-f FS_TYPE] [-b DD_BUFSIZE] [-c DD_CNT]
    -n DEV_NODE    optional param; device node like /dev/mtdblock2; /dev/sda1
    -f FS_TYPE     filesystem type like ext2, etc
    -b DD_BUFSIZE  dd buffer size for 'bs'
    -c DD_CNT      dd count for 'count'
    -d DEVICE_TYPE device type like 'nand', 'mmc', 'usb' etc
    -h Help        print this usage
EOF
exit 0
}

############################### CLI Params ###################################

while getopts :d:f:n:b:c:h arg; do
case "${arg}" in
  n)  DEV_NODE="$OPTARG" ;;
  d)  DEVICE_TYPE="$OPTARG" ;;
  f)  FS_TYPE="$OPTARG" ;;
  b)  DD_BUFSIZE="$OPTARG" ;;
  c)  DD_CNT="$OPTARG" ;;
  h)  usage ;;
  :)  test_print_err "$0: Must supply an argument to -$OPTARG."
      exit 1
      ;;
  \?) test_print_err "Invalid Option -$OPTARG ignored."
      usage
      ;;
esac
done

############################ DEFAULT Params #######################
if [[ -z "${DEV_NODE}" ]]; then
  DEV_NODE=$(get_blk_device_node.sh -d "$DEVICE_TYPE") \
    || block_test "Error getting device node for ${DEVICE_TYPE}"
fi

MNT_POINT="${TEST_MNT_DIR}/partition_${DEVICE_TYPE}_$$"

############# Do the work ###########################################
if [[ -n "${FS_TYPE}" ]]; then
  do_cmd blk_device_prepare_format.sh -d "${DEVICE_TYPE}" -n "${DEV_NODE}" -f "${FS_TYPE}" -m "${MNT_POINT}"
else
  do_cmd blk_device_prepare_format.sh -d "${DEVICE_TYPE}" -n "${DEV_NODE}" -m "${MNT_POINT}"
fi

test_print_trc "Doing write concurrence test"
SRC_FILE="${BLK_TEST_DIR}/src_test_file_${DEVICE_TYPE}_$$"
do_cmd "time ${DD} if=/dev/urandom of=${SRC_FILE} bs=${DD_BUFSIZE} count=${DD_CNT}"
do_cmd "${DD} if=${SRC_FILE} of=${MNT_POINT}/test1.file bs=${DD_BUFSIZE} count=${DD_CNT}" &
do_cmd "${DD} if=${SRC_FILE} of=${MNT_POINT}/test2.file bs=$DD_BUFSIZE count=$DD_CNT"
do_cmd sleep 10

FILE_SIZE=$(($(caculate_size_in_bytes "${DD_BUFSIZE}") * $(caculate_size_in_bytes "${DD_CNT}")))
TEST1_FILE_SIZE=$(get_filesize "${MNT_POINT}/test1.file")
TEST2_FILE_SIZE=$(get_filesize "${MNT_POINT}/test2.file")

echo "${TEST1_FILE_SIZE}" | grep "${FILE_SIZE}" \
  || die "error: file1 size is not expected file size"
echo "${TEST2_FILE_SIZE}" | grep "${FILE_SIZE}" \
  || die "error: file2 size is not expected file size"

do_cmd diff "${SRC_FILE}" "${MNT_POINT}/test1.file"
do_cmd diff "${SRC_FILE}" "${MNT_POINT}/test2.file"
do_cmd rm "${MNT_POINT}/test1.file" "${MNT_POINT}/test2.file"

test_print_trc "Umounting device"
do_cmd blk_device_umount.sh -m "${MNT_POINT}"
