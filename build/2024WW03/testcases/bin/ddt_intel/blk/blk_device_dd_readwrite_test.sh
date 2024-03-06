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
#      Android rootfs, change to /data, and same with /tmp
#     -Fixed issues with -s flag and mount/umount.
#     -Added logic for FS format check before test.
#     -Added logic and calc_space_needed_for_test() to block test if not enough
#      space in dev_node to perform the test.
#     -Removed commented code which is no longer used.
#     -Added wo and ro options for -i flag to W_ONLY and R_ONLY respectively.
#     -Added -k -r options to keep test files and erase afterwards respectively.
#     -Added some comments to a better follow up of the code.
#     -Added -K flag to keep device mounted and  not umount.
#     -Added SKPI_MOUNT check before trying to mount to original mount point to
#      avoid failures when working with SoFIA SoC's
#   Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     -Change skip format logic.
#     -Added SKIP_MOUNT option to avoid mount of a partition.
#     -Change skip mount and skip format logic.
#     -Added case statement to check SOC in order to get dynamically the correct
#      partition depending on which platform is being used.
#     -Remove unnecesary code and add useful log prints to have a better debug.
#     -Add logic to check if there is enough space available for test.
#   Zelin Deng <zelinx.deng@intel.com>
#     -Removed codes to get platform-specific block device node: case $SOC in...
#      esac . It has been replaced by function get_blk_dev_node_specific() in file
#      blk_device_common.sh
#     -Removed $BUSYBOX_DIR to fit upstream kernel replaced by $DD,$LS e.g. to
#      execute some special options
#   Ammy Yi <ammy.yi@intel.com>
#     -Added cache sync test
###############################################################################

# @desc Perform dd read write test on blk device like mmc, emmc, in  mount point
# @params [-n DEV_NODE] [-d DEVICE_TYPE] [-f FS_TYPE] [-m MNT_POINT]
#         [-b DD_BUFSIZE] [-c DD_CNT] [-i IO_OPERATION] [-k FILE_NAME]
#         [-r FILE_NAME] [-l TEST_LOOP] [-s SKIP_FORMAT ] [-S SKIP_MOUNT]
#         [-w WRITE_TO_FILLUP]
# @returns None
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-16: Ported to work with Android on IA.
# @history 2015-04-10: Fixed issues with mount/umount when -s flag is provided.
# @history 2015-04-17: Added logic for FS format check before test.
# @history 2015-04-26: Added logic to check if enough space in dev_node for test.
# @history 2015-05-05: Change skip format logic.
# @history 2015-05-06: Added SKIP_MOUNT flag.
# @history 2015-05-07: Change skip mount and skip format logic.
# @history 2015-05-14: Removed commented code.
#                      Added wo and ro options for -i flag.
#                      Added -k -r options.
#                      Added some comments.
# @history 2015-05-15: Added -K option.
# @history 2015-05-22: Readded check space logic because it was removed by some
#                      merge conflict.
# @history 2015-06-18: Added case statement for SOC.
# @history 2015-08-12: Removed case $SOC in...esac..
# @history 2015-09-09: Added SKPI_MOUNT check before remounting..
# @history 2016-06-15: remove get_blk_dev_node_specific function
#                      use get_blk_device_node.sh as the unified method to get
#                      the available block device node for test
# @history 2018-02-14: Remove unnecesary code and add useful log prints to have
#                      a better debug.
# @history 2018-02-26: Add logic to check available space in device node.
# @history 2018-04-02: Add judgement of default mount path /home.

source "blk_device_common.sh"

SKIP_FORMAT=0
SKIP_MOUNT=0
WRITE_TO_FILL=0
FORMAT_NEEDED="no"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
  usage: ./${0##*/} [-n DEV_NODE] [-d DEVICE_TYPE] [-f FS_TYPE] [-m MNT_POINT]
                    [-b DD_BUFSIZE] [-c DD_CNT] [-i IO_OPERATION] [-k FILE_NAME]
                    [-r FILE_NAME] [-l TEST_LOOP] [-s SKIP_FORMAT ]
                    [-S SKIP_MOUNT] [-w WRITE_TO_FILLUP]

  -n DEV_NODE        optional param; device node like /dev/block/mmcblk1
  -f FS_TYPE         filesystem type like vfat, ext2, etc
  -m MNT_POINT       mount point
  -b DD_BUFSIZE      dd buffer size for 'bs'
  -c DD_CNT          dd count for 'count'
  -i IO_OPERATION    IO operation like 'wr', 'cp', default is 'wr'
                     'oversize_write' is to test if driver throw error when the size > partition size
                     'wo' write only option
                     'ro' read only option
  -k FILE_NAME       keep file for later used like read operation while still
                     writting
  -K KEEP_MOUNT      keep device mounted in mount point and do not umount
  -r FILE_NAME       remove file which probably was left by -k option.
  -g MOUNT_DIR       the directory of mount
  -d DEVICE_TYPE     device type like 'nand', 'mmc', 'usb' etc
  -l TEST_LOOP       test loop for r/w. default is 1.
  -s SKIP_FORMAT     skip format part and just do r/w
  -S SKIP_MOUNT      skip mount/umount part and just do r/w
  -w WRITE_TO_FILLUP keep writing different files TEST_LOOP times to device
  -h Help            print this usage
EOF
exit 0
}

compare_md5sum() {

  FILE1=$1
  FILE2=$2

  a=$(md5sum "${FILE1}" | cut -d' ' -f1)
  test_print_trc "$1: ${a}"

  b=$(md5sum "${FILE2}" | cut -d' ' -f1)
  test_print_trc "$2: ${b}"

  [[ "${a}" = "${b}" ]]
}

############################### CLI Params ###################################

while getopts :d:f:m:n:b:c:i:k:r:g:l:KSswh arg; do
case "${arg}" in
  n)  DEV_NODE="$OPTARG" ;;
  d)  DEVICE_TYPE="$OPTARG" ;;
  f)  FS_TYPE="$OPTARG" ;;
  m)  MNT_POINT=$OPTARG
      # Add default mnt dir prefix if str does not contain it
      if [[ "${MNT_POINT}" != "${TEST_MNT_DIR}*" ]]; then
        test_print_trc "Adding ${TEST_MNT_DIR} prefix to ${MNT_POINT}"
        MNT_POINT="${TEST_MNT_DIR}/${OPTARG}"
      fi
      ;;
  b)  DD_BUFSIZE="$OPTARG" ;;
  c)  DD_CNT="$OPTARG" ;;
  i)  IO_OPERATION="$OPTARG" ;;
  k)  FILE_NAME="$OPTARG"
      KEEP_FILE_FLAG=1
      ;;
  K)  KEEP_MOUNT=1 ;;
  r)  FILE_NAME="$OPTARG"
      REMOVE_FILE_FLAG=1
      ;;
  g)  MOUNT_DIR="$OPTARG" ;;
  l)  TEST_LOOP="$OPTARG" ;;
  s)  SKIP_FORMAT=1 ;;
  S)  SKIP_MOUNT=1 ;;
  w)  WRITE_TO_FILL=1 ;;
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
: "${MNT_POINT:=$TEST_MNT_DIR/partition_${DEVICE_TYPE}_$$}"
: ${IO_OPERATION:='wr'}
: ${TEST_LOOP:='1'}
: ${KEEP_FILE_FLAG:='0'}
: ${REMOVE_FILE_FLAG:='0'}
: ${KEEP_MOUNT:='0'}
: ${MOUNT_DIR:='/home'}


# Get dev_node if not provided
if [[ -z "${DEV_NODE}" ]]; then
  DEV_NODE=$(get_blk_device_node.sh -d "${DEVICE_TYPE}" -s "${SKIP_MOUNT}" -f "${FS_TYPE}" -g "${MOUNT_DIR}") \
    || block_test "error getting device node for ${DEVICE_TYPE}: ${DEV_NODE}"
fi

# Debug prints
test_print_trc "DEVICE NODE: ${DEV_NODE}"
test_print_trc "MOUNT POINT: ${MNT_POINT}"
test_print_trc "FS TYPE: ${FS_TYPE}"

#We should mount the device back to its original mount point
if [[ "${SKIP_MOUNT}" -eq 0 ]]; then
  field=$(get_mnt_point_field)
  original_mnt_point=$(mount | grep -w "${DEV_NODE}" | cut -d' ' -f"${field}")
  test_print_trc "Original Mount Point of ${DEV_NODE}: ${original_mnt_point}"
fi

# Check test file persistency flags
[[ "${KEEP_FILE_FLAG}" -eq 1 && "${REMOVE_FILE_FLAG}" -eq 1 ]] \
  && die "-k and -r option can not be used at the same time"

# Prepare device to perform test
if [[ "${SKIP_MOUNT}" -ne 1 ]]; then
  # Check if format is needed
  if [[ "${SKIP_FORMAT}" -ne 1 && -n "$FS_TYPE" ]]; then
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

# Check if there;s enough space in dev_node to run the test
test_print_trc "Check free space available in ${DEV_NODE}"
if [[ "${WRITE_TO_FILL}" -eq 1 ]]; then
  SPACE_NEEDED=$(calc_space_needed_for_test "${DD_BUFSIZE}" "${DD_CNT}" "${TEST_LOOP}")
else
  SPACE_NEEDED=$(calc_space_needed_for_test "${DD_BUFSIZE}" "${DD_CNT}")
fi
is_dev_node_big_enough "${DEV_NODE}" "${SPACE_NEEDED}"
RET="$?"
[[ "$RET" -eq 0 ]] \
  || block_test "There's not enough space in dev_node, to perform the test."
test_print_trc "Space Needed: ${SPACE_NEEDED}MB"

# Check if there is space available in dev_node
FREE_SPACE=$(get_part_size_of_devnode "${DEV_NODE}" "space")
test_print_trc "Free Space in ${DEV_NODE}:${FREE_SPACE}MB"
[[ "${SPACE_NEEDED}" -gt "${FREE_SPACE}" ]] && {
  test_print_trc "There's not enough space available, proceed to erase/format ${DEV_NODE}"
  do_cmd blk_device_prepare_format.sh -d "${DEVICE_TYPE}" -n "${DEV_NODE}" -f "${FS_TYPE}" -m "${MNT_POINT}" -i
  }

test_print_trc "Doing read/write test for ${TEST_LOOP} times"

# Create dirs if not present
[[ -d "${BLK_TEST_DIR}" ]] || do_cmd mkdir -p "${BLK_TEST_DIR}" > /dev/null
[[ -d "${MNT_POINT}" ]] || do_cmd mkdir -p "${MNT_POINT}" > /dev/null

# Built name for src file
SRC_FILE="${BLK_TEST_DIR}/src_test_file_${DEVICE_TYPE}_$$"

# Skip src file write if we just want to read previuosly written files with -k
if [[ "${IO_OPERATION}" != "ro" ]]; then
  test_print_trc "Create SOURCE FILE: ${SRC_FILE}"
  do_cmd "${DD}" if="/dev/urandom" of="${SRC_FILE}" bs="${DD_BUFSIZE}" count="${DD_CNT}"
  sleep 10
  do_cmd "${LS}" -lh "${SRC_FILE}"
else
  test_print_trc "Skip wrtting SRC_FILE ! We just want to read ${FILE_NAME}"
fi

x='0'

while [[ "${x}" -lt "${TEST_LOOP}" ]]; do
  test_print_trc "============ R/W LOOP: ${x} ============"
  # Set test file name
  if [[ -n "${FILE_NAME}" ]]; then
    if [[ "${WRITE_TO_FILL}" -ne 1 ]]; then
      TEST_FILE="${MNT_POINT}/${FILE_NAME}"
    else
      TEST_FILE="${MNT_POINT}/${FILE_NAME}_${x}"
    fi
  elif [[ "${WRITE_TO_FILL}" -ne 1 ]]; then
    TEST_FILE="${MNT_POINT}/test_file_$$"
  else
    # Write to different file to fill up the device
    TEST_FILE="${MNT_POINT}/test_file_$$_${x}"
  fi

  test_print_trc "TEST FILE: ${TEST_FILE}"

  # Select test type
  case "${IO_OPERATION}" in
    #write test file and do different sync operation
    fsync)
     # Write file with random data
      test_print_trc "Write data to ${DEV_NODE}"
      test_print_trc "ammy fsync"
      do_cmd "${DD}" if="${SRC_FILE}" of="${TEST_FILE}" bs="${DD_BUFSIZE}" count="${DD_CNT}" conv=fsync
      # Compare test and original files
      test_print_trc "Compare SOURCE FILE and TEST FILE"
      diff "${SRC_FILE}" "${TEST_FILE}"
      if [[ $? -ne 0 ]]; then
        do_cmd cmp -l "${SRC_FILE}" "${TEST_FILE}"
      fi
      # Clear test file
      test_print_trc "Clear TEST FILE"
      do_cmd "${DD}" if="${TEST_FILE}" of="/dev/null" bs="${DD_BUFSIZE}" count="${DD_CNT}"
      do_cmd sync
      ;;
    fdatasync)
      # Write file with random data
      test_print_trc "Write data to ${DEV_NODE}"
      do_cmd "${DD}" if="${SRC_FILE}" of="${TEST_FILE}" bs="${DD_BUFSIZE}" count="${DD_CNT}" conv=fdatasync
      # Compare test and original files
      test_print_trc "Compare SOURCE FILE and TEST FILE"
      diff "${SRC_FILE}" "${TEST_FILE}"
      if [[ $? -ne 0 ]]; then
        do_cmd cmp -l "${SRC_FILE}" "${TEST_FILE}"
      fi
      # Clear test file
      test_print_trc "Clear TEST FILE"
      do_cmd "${DD}" if="${TEST_FILE}" of="/dev/null" bs="${DD_BUFSIZE}" count="${DD_CNT}"
      do_cmd sync
      ;;
    dsync)
      # Write file with random data
      test_print_trc "Write data to ${DEV_NODE}"
      do_cmd "${DD}" if="${SRC_FILE}" of="${TEST_FILE}" bs="${DD_BUFSIZE}" count="${DD_CNT}" oflag=dsync
      # Compare test and original files
      test_print_trc "Compare SOURCE FILE and TEST FILE"
      diff "${SRC_FILE}" "${TEST_FILE}"
      if [[ $? -ne 0 ]]; then
        do_cmd cmp -l "${SRC_FILE}" "${TEST_FILE}"
      fi
      # Clear test file
      test_print_trc "Clear TEST FILE"
      do_cmd "${DD}" if="${TEST_FILE}" of="/dev/null" bs="${DD_BUFSIZE}" count="${DD_CNT}"
      do_cmd sync
      ;;
    sync)
      # Write file with random data
      test_print_trc "Write data to ${DEV_NODE}"
      do_cmd "${DD}" if="${SRC_FILE}" of="${TEST_FILE}" bs="${DD_BUFSIZE}" count="${DD_CNT}" oflag=sync
      # Compare test and original files
      test_print_trc "Compare SOURCE FILE and TEST FILE"
      diff "${SRC_FILE}" "${TEST_FILE}"
      if [[ $? -ne 0 ]]; then
        do_cmd cmp -l "${SRC_FILE}" "${TEST_FILE}"
      fi
      # Clear test file
      test_print_trc "Clear TEST FILE"
      do_cmd "${DD}" if="${TEST_FILE}" of="/dev/null" bs="${DD_BUFSIZE}" count="${DD_CNT}"
      do_cmd sync
      ;;
    nocache)
      # Write file with random data
      test_print_trc "Write data to ${DEV_NODE}"
      do_cmd "${DD}" if="${SRC_FILE}" of="${TEST_FILE}" bs="${DD_BUFSIZE}" count="${DD_CNT}" oflag=nocache
      # Compare test and original files
      test_print_trc "Compare SOURCE FILE and TEST FILE"
      diff "${SRC_FILE}" "${TEST_FILE}"
      if [[ $? -ne 0 ]]; then
        do_cmd cmp -l "${SRC_FILE}" "${TEST_FILE}"
      fi
      # Clear test file
      test_print_trc "Clear TEST FILE"
      do_cmd "${DD}" if="${TEST_FILE}" of="/dev/null" bs="${DD_BUFSIZE}" count="${DD_CNT}"
      do_cmd sync
      ;;

    wr)
      # Write file with random data
      test_print_trc "Write data to ${DEV_NODE}"
      do_cmd "${DD}" if="${SRC_FILE}" of="${TEST_FILE}" bs="${DD_BUFSIZE}" count="${DD_CNT}"
      do_cmd sync
      echo 3 > /proc/sys/vm/drop_caches
      # Compare test and original files
      test_print_trc "Compare SOURCE FILE and TEST FILE"
      diff "${SRC_FILE}" "${TEST_FILE}"
      if [[ $? -ne 0 ]]; then
        do_cmd cmp -l "${SRC_FILE}" "${TEST_FILE}"
      fi
      # Clear test file
      test_print_trc "Clear TEST FILE"
      do_cmd "${DD}" if="${TEST_FILE}" of="/dev/null" bs="${DD_BUFSIZE}" count="${DD_CNT}"
      do_cmd sync
      echo 3 > /proc/sys/vm/drop_caches
      ;;

    # Write test file and leave it there
    wo)
      # Write file with random data
      do_cmd "${DD}" if="${SRC_FILE}" of="${TEST_FILE}" bs="${DD_BUFSIZE}" count="${DD_CNT}"
      do_cmd sync
      echo 3 > /proc/sys/vm/drop_caches
      # Compare test and original files
      test_print_trc "diff ${SRC_FILE} ${TEST_FILE}"
      diff "${SRC_FILE}" "${TEST_FILE}"
      if [[ $? -ne 0 ]]; then
        do_cmd cmp -l "${SRC_FILE}" "${TEST_FILE}"
      fi
      ;;

    # Read file previously written with wo and -k options
    ro)
      # Read test file and copy it to another file
      do_cmd cat "${TEST_FILE}" > "${SRC_FILE}"
      do_cmd sync
      echo 3 > /proc/sys/vm/drop_caches
      # Get file sizes
      SRC_FILE_SIZE=$(du "${SRC_FILE}" | awk '{print $1}')
      TEST_FILE_SIZE=$(du "${TEST_FILE}" | awk '{print $1}')
      [[ "${TEST_FILE_SIZE}" -lt 1 || "${SRC_FILE_SIZE}" -lt "${TEST_FILE_SIZE}" ]] \
        && die "${TEST_FILE_SIZE} != ${SRC_FILE_SIZE}"
      ;;

    # Over size write
    oversize_write)
      test_print_trc "${DD} if=${SRC_FILE} of=${TEST_FILE} bs=${DD_BUFSIZE} count=${DD_CNT} > ${TMPDIR}/temp_$$ 2>&1"
      "${DD}" if="${SRC_FILE}" of="${TEST_FILE}" bs="${DD_BUFSIZE}" count="${DD_CNT}" > "${TMPDIR}/temp_$$" 2>&1
      if [[ $? -ne 0 ]]; then
        # Check if the failure is due to out of space; if not fail the test
        do_cmd "cat ${TMPDIR}/temp_$$ | grep -i "No space left""
        do_cmd rm "${BLK_TEST_DIR}/test_file_$$_*"
        test_print_trc "Writing a file after space is available to make sure the driver is ok"
        test_print_trc "${DD} if=${SRC_FILE} of=${TEST_FILE} bs=${DD_BUFSIZE} count=${DD_CNT}"
        "${DD}" if="${SRC_FILE}" of="${TEST_FILE}" bs="${DD_BUFSIZE}" count="${DD_CNT}" \
          || die "Write failed after overflowing the device" \
          && exit 0
      fi
      do_cmd "${DD}" if="${TEST_FILE}" of="/dev/null" bs="${DD_BUFSIZE}" count="${DD_CNT}"
      do_cmd sync
      echo 3 > /proc/sys/vm/drop_caches
      rm "${TMPDIR}/temp_$$"
      ;;

    # Write file in the background
    write_in_bg)
      do_cmd "${DD}" if="/dev/urandom" of="${TEST_FILE}" bs="${DD_BUFSIZE}" count="${DD_CNT}" &
      ;;

    # Copy src file
    cp)
      do_cmd cp "${SRC_FILE}" "${TEST_FILE}"
      do_cmd sync
      echo 3 > /proc/sys/vm/drop_caches

      "${LS}" -lh "${SRC_FILE}"
      "${LS}" -lh "${TEST_FILE}"

      # Check md5 summary
      do_cmd compare_md5sum "${SRC_FILE}" "${TEST_FILE}"
      do_cmd cp "${TEST_FILE}" "${TEST_FILE}_2"
      do_cmd sync
      echo 3 > /proc/sys/vm/drop_caches

      "${LS}" -lh "${TEST_FILE}_2"
      test_print_trc "compare_md5sum ${TEST_FILE} ${TEST_FILE}_2"
      compare_md5sum "${TEST_FILE}" "${TEST_FILE}_2"
      if [[ $? -ne 0 ]]; then
        do_cmd cmp -l "${TEST_FILE}" "${TEST_FILE}_2"
      fi
      sleep 1
      do_cmd rm "${TEST_FILE}_2"
      ;;
    *)
      test_print_err "Invalid IO operation type in $0 script"
      ;;
  esac

  # Erase test file
  if [[ "${WRITE_TO_FILL}" -ne 1 && "${KEEP_FILE_FLAG}" -ne 1 ]]; then
    test_print_trc "Remove TEST FILE"
    do_cmd rm "${TEST_FILE}"
  else
    # Don't remove the testfiles so that to fillup the device or to read files later
    test_print_trc "Did not remove the testfiles in order to fillup the device or to read them later"
  fi

  x=$(( x + 1 ))
done

test_print_trc "Remove SOURCE FILE"
do_cmd rm "${SRC_FILE}"

do_cmd blk_device_umount.sh -m "${MNT_POINT}" -k "${KEEP_FILE_FLAG}"

if [[ -n "${original_mnt_point}" ]] && [[ "${SKIP_MOUNT}" -eq 0 ]]; then
  test_print_trc "Original mount point ${original_mnt_point}"
  do_cmd mount "${DEV_NODE}" "${original_mnt_point}"
fi
