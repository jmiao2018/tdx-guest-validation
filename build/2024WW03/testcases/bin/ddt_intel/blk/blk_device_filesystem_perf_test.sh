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
#   Juan Carlos Alonso <juan.carlos.alonso@intel.com> - (Intel)
#     -Changed shebang and some cmd's to force the use busybox cmd set.
#     -Modified mount point and R/W ops folder due to permission restriction in
#     -Add test case statement to check what platform is being used.
#     -Remove unnecesary code and add useful log prints to have a better debug.
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -Added logic for FS format check before test.
#     -Added support for SKPI_MOUNT, SKIP_FORMAT to use with SoFIA SOC
#   Zelin Deng <zelinx.deng@intel.com> (Intel)
#     -Removed logic to get platform-specific block device node:case $SOC in...
#     -Replaced it by function get_blk_dev_node_specific()
#     -Support mount blk device node back to its original mount point
###############################################################################

# @desc Helper for file system read/write performance
#  This script does: mount->write->umount->mount->read for different buffer size.
# @params [-f FS_TYPE] [-n DEV_NODE] [-m MOUNT POINT] [-B BUFFER SIZES] [-s FILE SIZE] [-d DEVICE TYPE] [-o SYNC or ASYNC] [-t TIME_OUT]
# @returns None
# @history 2011-03-05: First version
# @history 2015-02-16: Ported to work with Android on IA.
# @history 2015-04-17: Added logic for FS format check before test.
# @history 2015-06-26: Added test case statement to check SOC.
# @history 2015-08-13: Enhance test
# @history 2015-08-21: Fix an exit value bug at the last of this file
# @history 2015-09-09: Added SKPI_MOUNT and SKPI_FORMAT support.
# @history 2016-06-15: remove get_blk_dev_node_specific function
#                      use get_blk_device_node.sh as the unified method to get
#                      the available block device node for test
# @history 2018-02-14: Remove unnecesary code and add useful log prints to have
#                      a better debug.
# @history 2018-09-13: Fixed mount failure bug of ${original_mnt_point} claimed by OVSE on WindRiver Linux 10

source "blk_device_common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
usage: ./${0##*/} [-f FS_TYPE] [-n DEV_NODE] [-m MOUNT POINT] [-B BUFFER SIZES] [-s FILE SIZE] [-d DEVICE TYPE] [-o SYNC or ASYNC] [-t TIME_OUT]
  -f FS_TYPE      filesystem type like jffs2, ext2, etc
  -n DEV_NODE     optional param, block device node like /dev/block/mmcblk1
  -m MNT_POINT    optional param, mount point like /mnt/mmc
  -B BUFFER_SIZES optional param, buffer sizes for perf test like '102400 262144 524288 1048576 5242880'
  -s FILE SIZE    optional param, file size in MB for perf test
  -c SRCFILE SIZE optional param, srcfile size in MB for writing to device
  -d DEVICE_TYPE  device type like 'nand', 'mmc', 'usb' etc
  -o MNT_MODE     mount mode: sync or async. default is async
  -t TIME_OUT     time out duratiopn for copying
  -k SKIP_FORMAT  skip format part and just do r/w
  -K SKIP_MOUNT   skip mount/umount part and just do r/w
  -h Help         print this usage
EOF
exit 0
}

############################### CLI Params ###################################
SKIP_FORMAT=0
SKIP_MOUNT=0
FORMAT_NEEDED="no"

############################### CLI Params ##################################
while getopts :f:n:m:B:s:c:d:o:t:kKh arg; do
case "${arg}" in
  f)  FS_TYPE="$OPTARG" ;;
  n)  DEV_NODE="$OPTARG" ;;
  m)  MNT_POINT="$OPTARG" ;;
  B)  BUFFER_SIZES="$OPTARG" ;;
  s)  FILE_SIZE="$OPTARG" ;;
  c)  SRCFILE_SIZE="$OPTARG" ;;
  d)  DEVICE_TYPE="$OPTARG" ;;
  o)  MNT_MODE="$OPTARG" ;;
  t)  TIME_OUT="$OPTARG" ;;
  k)  SKIP_FORMAT=1 ;;
  K)  SKIP_MOUNT=1 ;;
  h)  usage ;;
  :)  test_print_err "$0: Must supply an argument to -$OPTARG."
      die
      ;;
  \?) test_print_err "Invalid Option -$OPTARG ignored."
      die
      ;;
esac
done

########################### DYNAMICALLY-DEFINED Params ########################
: ${BUFFER_SIZES:='102400 262144 524288 1048576 5242880'}
: ${FILE_SIZE:='100'}
: ${SRCFILE_SIZE:='10'}
: ${MNT_MODE:='async'}
: ${TIME_OUT:='10'}
: "${MNT_POINT:=$TEST_MNT_DIR/partition_${DEVICE_TYPE}_$$}"

if [[ -z "${DEV_NODE}" ]]; then
  DEV_NODE=$(get_blk_device_node.sh -d "${DEVICE_TYPE}" -s "${SKIP_MOUNT}" -f "${FS_TYPE}") \
    || block_test "Error while getting device node: ${DEV_NODE}"
#  test_print_trc "DEV_NODE return from get_blk_device_node is: ${DEV_NODE}"
fi

test_print_trc "STARTING FILE SYSTEM PERFORMANCE Test for ${DEVICE_TYPE}"
test_print_trc "FS_TYPE:${FS_TYPE}"
test_print_trc "DEV_NODE:${DEV_NODE}"
test_print_trc "MOUNT POINT:${MNT_POINT}"
test_print_trc "BUFFER SIZES:${BUFFER_SIZES}"
test_print_trc "FILE SIZE:${FILE_SIZE}MB"
test_print_trc "SRCFILE SIZE:${SRCFILE_SIZE}MB"
test_print_trc "DEVICE_TYPE:${DEVICE_TYPE}"
test_print_trc "SKIP_MOUNT:${SKIP_MOUNT}"
test_print_trc "SKIP_FORMAT:${SKIP_FORMAT}"

if [[ "$SKIP_MOUNT" -eq 0 ]]; then
  #We should mount the device back to its original mount point
  field=$(get_mnt_point_field)
  original_mnt_point=$(mount | grep -w "${DEV_NODE}" | cut -d' ' -f"${field}")
  test_print_trc "Original Mount Point of ${DEV_NODE}: ${original_mnt_point}"
fi

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.

# Check if input are valid for this machine
DEVICE_PART_SIZE=$(get_blk_device_part_size.sh -d "${DEVICE_TYPE}" -n "${DEV_NODE}") \
  || die "Error while getting device partition size: ${DEVICE_PART_SIZE}"
test_print_trc "Device ${DEV_NODE} size is ${DEVICE_PART_SIZE}MB"

[[ "${FILE_SIZE}" -gt "${DEVICE_PART_SIZE}" ]] \
  && block_test "File Size: ${FILE_SIZE} MB is not less than or equal to Device Partition Size: ${DEVICE_PART_SIZE} MB"

# Prepare device to perform test
if [[ "${SKIP_MOUNT}" -eq 0 ]]; then
  # Check if format is needed
  if [[ "${SKIP_FORMAT}" -eq 0 && -n "${FS_TYPE}" ]]; then
    FORMAT_NEEDED=$(is_format_needed "${DEV_NODE}" "${FS_TYPE}")
  fi
  #if original mount point is efi boot dir, force no format
  if [[ "${original_mnt_point}" == "/boot/efi" ]]; then
    FORMAT_NEEDED="no"
  fi
  # Prepare partition FS
  if [[ "${FORMAT_NEEDED}" = "yes" ]]; then
    do_cmd blk_device_prepare_format.sh -d "${DEVICE_TYPE}" -n "${DEV_NODE}" -f "${FS_TYPE}" -m "${MNT_POINT}" -i
  else
    do_cmd blk_device_prepare_format.sh -d "${DEVICE_TYPE}" -n "${DEV_NODE}" -m "${MNT_POINT}" -i
  fi
else
  test_print_trc "SKIP_MOUNT ${DEV_NODE} must not be mounted on ${MNT_POINT}"
fi


# Run filesystem perf test
#do_cmd "mkdir -p ${MNT_POINT}"
for BUFFER_SIZE in ${BUFFER_SIZES}; do
  test_print_trc "BUFFER SIZE = ${BUFFER_SIZE}"
  test_print_trc "Checking if Buffer Size is valid"
  [[ "${BUFFER_SIZE}" -gt $(( FILE_SIZE * MB )) ]] \
    && die "Buffer size provided: ${BUFFER_SIZE} is not less than or equal to File size ${FILE_SIZE} MB"

  # Find out what is FS in the device
  if [[ -z "${FS_TYPE}" ]]; then
    FS_TYPE=$(mount | grep "${DEV_NODE}" | cut -d' ' -f5)
    test_print_trc "Existing FS_TYPE: ${FS_TYPE}"
  fi

  test_print_trc "Creating SOURCE FILE"
  TMP_FILE="${TEST_DIR}/tmp_test_file_${DEVICE_TYPE}_$$"
  do_cmd "${DD} if=/dev/urandom of=${TMP_FILE} bs=1048576 count=${SRCFILE_SIZE}"

  TEST_FILE="${TEST_DIR}/test_file_$$"
  test_print_trc "TEST FILE: ${TEST_FILE}"

  test_print_trc "WRITE File"
  do_cmd "filesystem_tests -write -src_file ${TMP_FILE} -srcfile_size ${SRCFILE_SIZE} -file ${TEST_FILE} -buffer_size ${BUFFER_SIZE} -file_size ${FILE_SIZE} -performance"
  do_cmd "rm ${TMP_FILE}"
  do_cmd "sync"

  # Check if mounting is forbbiden
  if [[ "${SKIP_MOUNT}" -eq 0 ]]; then
    # Should do umount and mount before read to force to write to device
    do_cmd blk_device_umount.sh -m "${MNT_POINT}"
    do_cmd "echo 3 > /proc/sys/vm/drop_caches"
    mount | grep -w "${DEV_NODE}" \
      || do_cmd blk_device_do_mount.sh -n "${DEV_NODE}" -f "${FS_TYPE}" -d "${DEVICE_TYPE}" -o "${MNT_MODE}" -m "${MNT_POINT}"
  else
    test_print_trc "Skipping umount - mount !"
  fi

  test_print_trc "READ File"
  do_cmd "filesystem_tests -read -file ${TEST_FILE} -buffer_size ${BUFFER_SIZE} -file_size ${FILE_SIZE} -performance"
  do_cmd "sync"
  do_cmd "echo 3 > /proc/sys/vm/drop_caches"

  # For copy test, only do half of file size to avoid out of space problem.
  test_print_trc "Creating file which is half size of ${FILE_SIZE} on ${MNT_POINT} to test copyfile"
  HALF_FILE_SIZE=$(awk "BEGIN {print $FILE_SIZE/2}")
  TEST_FILE="${TEST_DIR}/test_file_$$"
  DST_TEST_FILE="${TEST_DIR}/dst_test_file_$$"
  do_cmd "${DD} if=/dev/urandom of=${TEST_FILE} bs=524288 count=${FILE_SIZE}"
  test_print_trc "COPY File"
  do_cmd "filesystem_tests -copy -src_file ${TEST_FILE} -dst_file ${DST_TEST_FILE} -duration ${TIME_OUT} -buffer_size ${BUFFER_SIZE} -file_size ${HALF_FILE_SIZE} -performance"

  # Check if mounting is forbbiden
#  if [[ "${SKIP_MOUNT}" -eq 0 ]]; then
#    do_cmd "rm -f ${TEST_FILE}"
#    do_cmd "rm -f ${DST_TEST_FILE}"
#    test_print_trc "Unmount the device"
#    do_cmd blk_device_unprepare.sh -n "${DEV_NODE}" -d "${DEVICE_TYPE}" -f "${FS_TYPE}" -m "${MNT_POINT}"
    #if the orginal mount point is / (rootfs) or /boot/efi (boot partition),
    #it should be mounted back to orginal mount point
#    if [[ "${original_mnt_point}" == "/" ]] || [[ "${original_mnt_point}" == "/boot/efi" ]]; then
#      mount | grep -w "${DEV_NODE}" \
#        || do_cmd mount "${DEV_NODE}" "${original_mnt_point}"
#      do_cmd "sync"
#    fi
#  fi
  if [[ "${SKIP_MOUNT}" -eq 0 ]]; then
    test_print_trc "Remove TEST FILE"
    do_cmd rm "${TEST_FILE}"
    test_print_trc "Remove DST TEST FILE"
    do_cmd rm "${DST_TEST_FILE}"
    do_cmd blk_device_umount.sh -m "${MNT_POINT}"
    if [[ -n "${original_mnt_point}" ]]; then
      test_print_trc "Original mount point ${original_mnt_point}"
      test_print_trc "Mount ${DEV_NODE} to ${original_mnt_point} if it's not mounted"
      mount | grep -q -w ${original_mnt_point} || do_cmd mount "${DEV_NODE}" "${original_mnt_point}"
    fi
  fi
done
