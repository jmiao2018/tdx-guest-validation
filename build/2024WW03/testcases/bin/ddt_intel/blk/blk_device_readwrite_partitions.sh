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
# Contributors:
#   Alonso Juan Carlos <juan.carlos.alonso@intel.com> (Intel)
#    - Initial draft
###############################################################################

# @desc Format, Mount and Write/Read data between block devices partitions.
# @params [-n DEV_NODE] [-d DEVICE TYPE] [-p PARTITION] [-s FS_TYPE] [-f FORMAT]
#         [-m MOUNT] [-w WRITE] [-i IGNORE_PRINTS]
# @returns None
# @history 2018-04-18: Initial draft

source "blk_device_common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
  usage: ./${0##*/} [-n DEV_NODE] [-d DEVICE TYPE] [-p PARTITION] [-s FS_TYPE]
                    [-f FORMAT] [-m MOUNT] [-w WRITE] [-i IGNORE_PRINTS]
    -n DEV_NODE      device node like /dev/mtdblock3; /dev/sda1
    -d DEVICE_TYPE   device type like 'nand', 'mmc', 'usb' etc
    -p PARTITIONS    number of partitions to use
    -s FS_TYPE       filesystem type like jffs2, ext2, etc
    -f FORMAT        partitions will be format
    -m MNT_POINT     partitions will be mounted
    -w WRITE         write/read data between partitions
    -i IGNORE_PRINTS
    -h Help          print this usage
EOF
exit 0
}

############################ CLI Params ###########################################
while getopts :d:n:p:s:fmwih arg; do
  case "${arg}" in
    d)  DEVICE_TYPE=$OPTARG ;;
    n)  DEV_NODE=$OPTARG ;;
    p)  PARTITION=$OPTARG ;;
    s)  FS_TYPE=$OPTARG ;;
    f)  FORMAT=1 ;;
    m)  MOUNT=1 ;;
    w)  WRITE=1 ;;
    i)  IGNORE_PRINTS=1 ;;
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
: ${IGNORE_PRINTS:=0}
: ${FORMAT:=0}
: ${MOUNT:=0}
: ${WRITE:=0}

BUFSIZE='10M'
COUNT='10'
MKFS=('ext2' 'ext3' 'ext4' 'vfat')
MNT_MODE=('ro' 'rw' 'sync' 'async')
declare -a MNT_POINT_ARRAY

############################ Reusable Logic ##############################
# Check args
[[ -z "${DEVICE_TYPE}" ]] && die "Argument missing: DEVICE_TYPE can't be empty"

# Get dev_node if not provided
if [[ -z "${DEV_NODE}" ]]; then
  DEV_NODE=$(get_blk_device_node.sh -d "${DEVICE_TYPE}") \
    || block_test "Error getting device node for ${DEVICE_TYPE}: ${DEV_NODE}"
fi

# Get dev_node_entry
DEV_NODE_ENTRY=$(get_devnode_entry.sh "${DEV_NODE}" "${DEVICE_TYPE}") \
  || die "Getting devnode entry for ${DEV_NODE}"

# Get dev_node partitions
patt="/dev/sd*"
if [[ ${DEV_NODE_ENTRY} =~ $patt ]]; then
  PRESENT_PARTS=($(fdisk -l "${DEV_NODE_ENTRY}" | grep "${DEV_NODE_ENTRY}[0-9]" | awk '{print $1}'))
else
  PRESENT_PARTS=($(fdisk -l "${DEV_NODE_ENTRY}" | grep "${DEV_NODE_ENTRY}p" | awk '{print $1}'))
fi

test_print_trc "Current partitions in ${DEV_NODE_ENTRY}:${#PRESENT_PARTS[@]}"
if [[ "${#PRESENT_PARTS[@]}" -ne "${PARTITION}" ]]; then
  test_print_trc "Crete ${PARTITION} partitions in ${DEV_NODE_ENTRY}"
  do_cmd blk_device_create_erase_partition.sh -d "${DEVICE_TYPE}" -p "${PARTITION}"
  patt="/dev/sd*"
  if [[ ${DEV_NODE_ENTRY} =~ $patt ]]; then
    PRESENT_PARTS=($(fdisk -l "${DEV_NODE_ENTRY}" | grep "${DEV_NODE_ENTRY}[0-9]" | awk '{print $1}'))
  else
    PRESENT_PARTS=($(fdisk -l "${DEV_NODE_ENTRY}" | grep "${DEV_NODE_ENTRY}p" | awk '{print $1}'))
  fi
fi

# Debug prints
if [[ "${IGNORE_PRINTS}" -eq 0 ]]; then
  test_print_trc "DEVICE TYPE:${DEVICE_TYPE}"
  test_print_trc "DEVICE NODE:${DEV_NODE}"
  echo "CURRENT PARTITIONS:" "${PRESENT_PARTS[@]}"
fi

for part in "${PRESENT_PARTS[@]}"; do
  # Check if partition is /boot/efi
  test_print_trc "Check if ${part} is /boot/efi"
  mount | grep -w "${part}" | grep -wq "/boot/efi"
  if [[ "$?" -eq 0 ]]; then
    block_test "${part} is /boot/efi partition. You should provide an empty Device Node Partition."
  fi

  # Check if partition is root
  test_print_trc "Check if ${part} is root"
  mount | grep -w "${part}" | grep -wq "/"
  if [[ "$?" -eq 0 ]]; then
    block_test "${part} is root partition. You should provide an empty Device Node Partition."
  fi

  # Check if partition is SWAP
  test_print_trc "Check if ${part} is SWAP"
  blkid | grep -w "${part}" | grep -wq "swap"
  if [[ "$?" -eq 0 ]]; then
    block_test "${part} is SWAP partition. You should provide an empty Device Node Partition."
  fi
done

# Format and Mount/Umount device block partitions
if [[ "${FORMAT}" -eq 1 ]]; then
  for part in "${PRESENT_PARTS[@]}"; do
    for fs in "${MKFS[@]}"; do
      test_print_trc "====== Format ${part} in ${fs} ======"
      do_cmd blk_device_erase_format_part.sh -d "${DEVICE_TYPE}" -n "${part}" -f "${fs}" -i
      sleep 2
      if [[ "${MOUNT}" -eq 1 ]]; then
        for mode in "${MNT_MODE[@]}"; do
          test_print_trc "==== Mount ${part} as ${mode} mode"
          do_cmd blk_device_do_mount.sh -d "${DEVICE_TYPE}" -n "${part}" -f "${fs}" -o "${mode}"
          sleep 2
          CUR_MNT_POINT=$(mount | grep "${part}" | cut -d' ' -f3)
          do_cmd blk_device_umount.sh -m "${CUR_MNT_POINT}"
        done
      fi
    done
  done
fi

# Write/Read data between block device partitions
if [[ "${WRITE}" -eq 1 ]]; then
  test_print_trc "Write/Read data between ${PARTITION} partitions"

  for part in "${PRESENT_PARTS[@]}"; do
    test_print_trc "Format ${part} in ${FS_TYPE} FS"
    do_cmd blk_device_erase_format_part.sh -d "${DEVICE_TYPE}" -n "${part}" -f "${FS_TYPE}" -i
    sleep 2

    part_entry=$(echo "${part}" | cut -d'/' -f3)
    MNT_POINT="$TEST_MNT_DIR/partition_${part_entry}"
    MNT_POINT_ARRAY+=("${MNT_POINT}")
    test_print_trc "Mount ${part} in ${MNT_POINT}"
    do_cmd blk_device_do_mount.sh -d "${DEVICE_TYPE}" -n "${part}" -f "${FS_TYPE}" -m "${MNT_POINT}"
  done

  test_print_trc "Perform Write/Read data between ${DEV_NODE_ENTRY} partitions"
  NUM_PART="${#PRESENT_PARTS[@]}"
  SRC_PART="${PRESENT_PARTS[0]}"
  SRC_PART_MNT="${MNT_POINT_ARRAY[0]}"
  SRC_FILE="${SRC_PART_MNT}/src_file_${DEVICE_TYPE}"

  test_print_trc "Create source file in ${SRC_PART}"
  do_cmd "${DD}" if="/dev/urandom" of="${SRC_FILE}" bs="${BUFSIZE}" count="${COUNT}"
  sleep 5
  do_cmd ls -lh "${SRC_FILE}"

  for((i=1; i<NUM_PART; i++)); do
    test_print_trc "Write from ${SRC_PART} to ${PRESENT_PARTS["$i"]}"
    DEST_FILE="${MNT_POINT_ARRAY[$i]}/dest_file_${DEVICE_TYPE}"
    do_cmd "${DD}" if="${SRC_FILE}" of="${DEST_FILE}" bs="${BUFSIZE}" count="${COUNT}"
    sleep 5
    do_cmd ls -lh "${DEST_FILE}"
    do_cmd diff "${SRC_FILE}" "${DEST_FILE}"
  done

  test_print_trc "Umount ${DEV_NODE_ENTRY} partitions"
  for mnt_point in "${MNT_POINT_ARRAY[@]}"; do
    do_cmd blk_device_umount.sh -m "${mnt_point}"
  done
fi
