#!/bin/bash

###############################################################################
# Copyright (C) 2018 Intel - http://www.intel.com/
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
#
# File: blk_device_iozone_readwrite_test.sh
#
# Description: This script uses Iozone tool to write/read data in different
#              modes in order to can make transfer measurements.
#
# # Author(s): Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#
# Date: 2018-03-23: Initial Version
#
# History: 2018-03-23: First version
#
###############################################################################

source "blk_device_common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
  usage: ./${0##*/} [-n DEV_NODE] [-d DEVICE_TYPE] [-m MNT_POINT]
                    [-s FILE_SIZE] [-r RECORD_SIZE] [-i TEST_MODE]
                    [-t THREADS] [-F FILENAMES] [-k SKIP_MOUNT ]
                    [-h Help]

  -n DEV_NODE        optional param; device node like /dev/block/mmcblk1
  -d DEVICE_TYPE     device type like 'nand', 'mmc', 'usb' etc
  -m MNT_POINT       mount point
  -s FILE_SIZE       size in kilobytes of the file to test
  -r RECORD_SIZE     record size in kilobytes to tests
  -i TEST_MODE       which type mode of test like 0, 1, 2, 3.. 12
  -t THREADS         how many threads or proceses to have
  -f FILENAMES       temporary file names to be used in testing
  -k SKIP_MOUNT      skip mount/umount part and just do r/w
  -h Help            print this usage
EOF
exit 0
}

get_test_mode_name() {

  local test_mode=$1

  if [[ "${test_mode}" -eq 0 ]]; then
    test_mode_name="write/re-write"
  elif [[ "${test_mode}" -eq 1 ]]; then
    test_mode_name="read/re-read"
  elif [[ "${test_mode}" -eq 2 ]]; then
    test_mode_name="random-read/write"
  elif [[ "${test_mode}" -eq 3 ]]; then
    test_mode_name="read-backwards"
  elif [[ "${test_mode}" -eq 8 ]]; then
    test_mode_name="random mix"
  fi

  echo "${test_mode_name}"

}

############################### CLI Params ###################################

while getopts :n:d:s:r:i:m:t:F:kh arg; do
case "${arg}" in
  n)  DEV_NODE="${OPTARG}" ;;
  d)  DEV_TYPE="${OPTARG}" ;;
  s)  FILE_SIZE="${OPTARG}" ;;
  r)  RECORD_SIZE="${OPTARG}" ;;
  i)  TEST_MODE+=("${OPTARG}") ;;
  m)  MNT_POINT="${OPTARG}" ;;
  t)  THREADS="${OPTARG}" ;;
  F)  FILENAMES+=("${OPTARG}") ;;
  k)  SKIP_MOUNT="1" ;;
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
: "${MNT_POINT:=$TEST_MNT_DIR/partition_${DEV_TYPE}_$$}"
: ${FILE_SIZE:='8192k'}
: ${RECORD_SIZE:='4k'}
: ${TEST_MODE:='0'}
: ${THREADS:='1'}
: ${SKIP_MOUNT:='0'}

# Get dev_node if not provided
if [[ -z "${DEV_NODE}" ]]; then
  DEV_NODE=$(get_blk_device_node.sh -d "${DEV_TYPE}" -s "${SKIP_MOUNT}" -f "${FS_TYPE}") \
    || block_test "error getting device node for ${DEV_TYPE}: ${DEV_NODE}"
fi

# Set FILENAMES to test
if [[ -n "${MNT_POINT}" ]]; then
  if [[ "${THREADS}" -gt 1 ]]; then
    for (( i=1; i<=THREADS; i++ )); do
      FILENAMES+=("${MNT_POINT}/iozone${i}.tmp")
    done
  else
    FILENAMES+=("${MNT_POINT}/iozone1.tmp")
  fi
fi

if [[ "${THREADS}" -ne "${#FILENAMES[@]}" ]]; then
  die "The number of files should be equal to the number of processes!"
fi

# Get Test mode name
for mode in "${TEST_MODE[@]}"; do
  MODE+=($(get_test_mode_name "${mode}"))
done

for mode in "${MODE[@]}"; do
  MODE_A="${MODE_A}|${mode}"
done

# Debug prints
test_print_trc "DEVICE NODE: ${DEV_NODE}"
test_print_trc "MOUNT POINT: ${MNT_POINT}"
test_print_trc "FILE SIZE:   ${FILE_SIZE}"
test_print_trc "RECORD SIZE: ${RECORD_SIZE}"
test_print_trc "THREADS:     ${THREADS}"
test_print_trc "TEST MODE:   ${MODE_A}"

# Mount device node with 'discard' enabled
do_cmd blk_device_do_mount.sh -n "${DEV_NODE}" -d "${DEV_TYPE}" -m "${MNT_POINT}" -o "discard"

# Check if there;s enough space in dev_node to run the test
test_print_trc "Check free space available in ${DEV_NODE}"
TMP_FILE_SIZE=$(echo "${FILE_SIZE}" | tr '[:lower:]' '[:upper:]')
SPACE_NEEDED=$(calc_space_needed_for_test "${TMP_FILE_SIZE}")
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
  do_cmd blk_device_prepare_format.sh -d "${DEV_TYPE}" -n "${DEV_NODE}" -m "${MNT_POINT}" -i
  }

# We should mount the device back to its original mount point
if [[ "${SKIP_MOUNT}" -eq 0 ]]; then
  field=$(get_mnt_point_field)
  original_mnt_point=$(mount | grep -w "${DEV_NODE}" | cut -d' ' -f"${field}")
  test_print_trc "Original Mount Point of ${DEV_NODE}: ${original_mnt_point}"
fi

# Set test mode array
for (( n=0; n<${#TEST_MODE[@]}; n++ )); do
  TEST_MODE[$n]="-i ${TEST_MODE[$n]}"
done

# Perform Iozone tool
do_cmd iozone -s "${FILE_SIZE}" -r "${RECORD_SIZE}" "${TEST_MODE[@]}" -I -t "${THREADS}" -F "${FILENAMES[@]}"

# Umount device node
do_cmd blk_device_umount.sh -m "${MNT_POINT}"
