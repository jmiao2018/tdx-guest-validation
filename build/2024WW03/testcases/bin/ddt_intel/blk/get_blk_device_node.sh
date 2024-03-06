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
#   Hongyu Ning <hongyu.ning@intel.com> (Intel)
#     -Fixed a script bug in function try_format_dev_node().
#     -Fixed a logic bug in function find_scsi_node(), add homefs partition check
#      in valid test device_node check logic, to avoid miss operation on homefs partition
#     -Improved logic in function find_scsi_node(), add special fs partition check
#      in valid test device_node check logic, to avoid miss operation on specialfs partition
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -Changed shebang and some cmd's to force the use busybox cmd set.
#     -Modified mount point and R/W ops folder due to permission restriction in
#      Android rootfs, changed to /data.
#     -Removed code:
#     -find_scsi_node() func - no SCSI devs in DUT's.
#     -Logic for MTD cause not present in DUT's.
#     -Use of get_device_type_map.sh - just for MTD/SCSI devs, and not present in DUT's.
#     -Removed duplicated 'source' scripts.
#     -Added logic to create test partition if disk in empty.
#   Juan Carlos Alonso <juan.carlos.alonso@intel.com> (Intel)
#     -Add logic to get usb device node.
#     -Add find_scsi_node() function to get SCSI device node.
#     -Update code to support SD. Replace 'mmc' for 'sd'
#     -Update script to get device node dynamically and avoid parameters hardcoding.
#   Zelin Deng <zelinx.deng@intel.com> (Intel)
#     -Added variable BLK_DEV_DIR got by get_blk_dev_dir() to get block device
#     directory in devfs. In android is /dev/block/xxx and in upstream is /dev/
#   Zhang Chao <chaox.zhang@intel.com> (Intel)
###############################################################################

# @desc Get devnode for non mtd device like 'mmc', 'emmc', 'sata', 'usb'
# @params  <device_type>
# @returns device_node like /dev/block/mmcblk1
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-18: Ported to work with Android on IA.
# @history 2015-04-27: Removed duplicated 'source' scripts.
# @history 2015-05-12: Create test partition if empty device.
# @history 2015-05-22: Add logic to get usb device node.
# @history 2015-08-13: Support upstream kernel
# @history 2015-09-16: Fix an issue to get the right device node of usb storage
# @history 2016-06-15: refactor get_blk_device_node policy:
#                      1. try to get platform-specific block device from param files
#                      2. try to get available block device dynamically
# @history 2018-01-22: Add support for NVME device.
# @history 2018-02-15: Update code to support SD. Replace 'mmc' for 'sd'
# @history 2018-03-12: Update script to get device noce dynamically
# @history 2018-04-02: Update script to judge whether the default mount path is /home or others
# @history 2018-05-25: Update script for enhancement of getting ufs node
# @history 2018-08-20: Fix script bug in function try_format_dev_node, to correctly handle fs TYPE "LVM2_member"
# @history 2018-10-12: Remove "CD-ROM" device from sata $files
# @history 2018-10-12: Workaround, wait for 10 seconds before readlink operation, to secure the success return in
#                      Clear Linux environment
# @history 2019-07-26: 1. Fixed logic bug in function find_scsi_node(), add homefs partition check
#                         to avoid miss operation on homefs partition
#                      2. Improved logic in functino find_scsi_node(), add special fs partition check
#                         to avoid miss operation on special fs partition

source "blk_device_common.sh"

usage() {
cat <<-EOF >&2
  usage: ./${0##*/} <-d DEVICE_TYPE> [-s SKIP_MOUNT] [-f FS_TYPE] [-p WITH_PART] [-h]
    -d DEVICE_TYPE device type like 'mmc'
    -s SKIP_MOUNT  request blk device w/o mount it
    -f FS_TYPE     required filesystem type
    -g MOUNT_DIR   mount path
    -p WITH_PART   request blk device with partition
EOF
exit 0
}

while getopts :d:s:f:g:ph arg; do
case $arg in
  d)  DEVICE_TYPE="$OPTARG" ;;
  s)  SKIP_MOUNT="$OPTARG" ;;
  f)  FS_TYPE="$OPTARG" ;;
  g)  MOUNT_DIR="$OPTARG" ;;
  p)  WITH_PART="$OPTARG" ;;
  h)  usage ;;
  :)  test_print_err "$0: Must supply an argument to -$OPTARG."
      die
      ;;
  \?) test_print_err "Invalid Option -$OPTARG ignored."
      die
      ;;
esac
done

DEV_NODE=""

: ${SKIP_MOUNT:='1'}
: ${FS_TYPE:='ext4'}
: ${WITH_PART:='yes'}

BLK_DEV_DIR="$(get_blk_dev_dir)"

############################ Functions ################################

# This function checks the partitions, format them if necessary.
# Input: $1 -> device node to be checked and formated
#        $2 -> whether device node is just partitioned.
# Output: 0 on succee
#         1 on failure
# Example: try_format_dev_node /dev/sdb1 true usb
try_format_dev_node() {

  local dev_node=$1
  local parted=$2
  local dev_type=$3
  local fs_type=""

  fs_type=$(blkid "${dev_node}" \
    | grep -oE "TYPE=\"[a-zA-Z0-9_]*\"" \
    | sed 's/TYPE="\([a-zA-Z0-9_]*\)"/\1/')
  # Try to re-format a partition if it's existing filesystem is not expected.
  # Only "newly-partitioned" block device with unexpected filesystem will
  # be re-formated to the *expected* $FS_TYPE, to avoid wrongly formatting
  # root/boot/swap partitions as we don't have a check here.
  if [[ -n "${fs_type}" ]]; then
    if ${parted} && [[ "${fs_type}" != "${FS_TYPE}" ]]; then
      blk_device_erase_format_part.sh -f "${FS_TYPE}" -n "${dev_node}" -d "${dev_type}" &> /dev/null
    fi
  else
    blk_device_erase_format_part.sh -f "${FS_TYPE}" -n "${dev_node}" -d "${dev_type}" &> /dev/null
  fi
}

# this function is to get SCSI device usb or sata node based on by-id
# input is either 'sata' or 'usb' or 'usbxhci'
find_scsi_node() {
  local scsi_dev=$1
  local files=""
  local dev_node=""
  local need_partition=false
  local is_rootfs="no"
  local blk_dev_dir=""

  blk_dev_dir=$(echo "${BLK_DEV_DIR}" | cut -d',' -f1)

  case "${scsi_dev}" in
    usb | usbxhci)
      # remove DVD
      files=$(ls ${blk_dev_dir}/* \
        | grep -v "DRW" \
        | grep -v "DVD" \
        | grep -i "usb-.*-part[0-9]")
      # get parent dev node if there is no partition created
      if [[ -z "${files}" ]]; then
        files=$(ls ${blk_dev_dir}/* \
          | grep -v "DRW" \
          | grep -v "DVD" \
          | grep -i "usb")
        need_partition=true
      fi
      ;;
    sata)
      # remove DVD
      files=$(ls ${blk_dev_dir}/* \
        | grep -v "DRW" \
        | grep -v "DVD"\
        | grep -v "CD-ROM" \
        | grep -i "ata-.*-part[0-9]")
      ;;
    nvme)
      files=$(ls ${blk_dev_dir}/* \
        | grep -v "DRW" \
        | grep -v "DVD"\
        | grep -i "nvme-.*-part[0-9]")
      ;;
  esac

  for file in ${files}; do
    #wait for 2 seconds before readlink operation, to secure the success return
    sleep 2
    dev_node=$(readlink -e "${file}") || continue
    if [[ "${file}" != "${file#*/usb-}" ]] && "${need_partition}"; then
      echo -e "n\np\n1\n\n\nw\n" | fdisk "${dev_node}" &> /dev/null || return 1
      sleep 1
      file=$(ls ${blk_dev_dir}/* \
        | grep -v "DRW" \
        | grep -v "DVD" \
        | grep -i "usb-.*-part[0-9]")
      dev_node=$(readlink -e "${file}") || continue
    fi
    # check whether we need to format device node before do other things.
    try_format_dev_node "${dev_node}" "${need_partition}" "${scsi_dev}" \
      || block_test "Error happend while formating ${dev_node}!"
    # Do NOT do mount/umount, format test on rootfs or homefs or other special fs or boot or swap partition
    # handle special partition on CentOS8.3 server
    local fs_type=""
    fs_type=$(blkid "${dev_node}" \
      | grep -oE "TYPE=\"[a-zA-Z0-9_]*\"" \
      | sed 's/TYPE="\([a-zA-Z0-9_]*\)"/\1/')
    [[ "${fs_type}" == "dos" ]] && continue
    [[ "${fs_type}" == "xfs" ]] && continue
    # check the partition with function is_part_lvm_os only if the partition has lvm
    lsblk "${dev_node}" | grep -i "lvm" > /dev/null \
      && is_part_lvm_os "${dev_node}" && continue
    is_rootfs=$(is_part_rootfs "${scsi_dev}" "${dev_node}")
    [[ "${is_rootfs}" == "yes" ]] && continue
    is_homefs=$(is_part_homefs "${scsi_dev}" "${dev_node}")
    [[ "${is_homefs}" == "yes" ]] && continue
    is_specialfs=$(is_part_specialfs "${dev_node}")
    [[ "${is_specialfs}" == "yes" ]] && continue
    is_part_boot "${dev_node}" && continue
    is_part_swap "${dev_node}" && continue
    check_mount_path "${dev_node}" "${MOUNT_DIR}" && continue

    echo "${dev_node}"

    return 0

  done

  return 1
}

# return: /dev/block/mmcblk0
find_emmc_basenode() {

  local emmc_type=""

  emmc_type=$(ls /sys/bus/mmc/devices/mmc*/type)

  for type in ${emmc_type}; do
    grep -q -e ^MMC$ "${type}" \
      && emmc_dev=$(basename $(ls -d ${type%/*}/block/mmcblk*))
  done

  [[ -n "${emmc_dev}" ]] \
    || block_test "Could not find eMMC base node by checking /sys/bus/mmc/devices/mmc*"

  emmc_node=$(echo "${BLK_DEV_DIR}" | cut -d ',' -f2)/"${emmc_dev}"

  echo "${emmc_node}"
}

find_sd_basenode() {

  local sd_type=""

  sd_type=$(ls /sys/bus/mmc/devices/mmc*/type)

  for type in ${sd_type}; do
    grep -q -e ^SD$ "${type}" \
      && sd_dev=$(basename $(ls -d ${type%/*}/block/mmcblk*))
  done

  [[ -n "${sd_dev}" ]] \
    || block_test "Could not find SD base node by checking /sys/bus/mmc/devices/mmc*"

  sd_node=$(echo "${BLK_DEV_DIR}" | cut -d ',' -f3)/"${sd_dev}"

  echo "${sd_node}"
}

# create one test partition if mmc or emmc doesn't have any partition on it
# and create the default EXT2 filesystem on it.
# $1: basenode like /dev/block/mmcblk0, /dev/block/mmcblk1
create_mmc_partition() {

  basenode=$1

  [[ -z "${basenode}" ]] && return 1

  echo -e "n\np\n1\n\n\nw\n" | fdisk "${basenode}" || return 1
  sleep 1
  mkfs.ext2 "${basenode}p1"
}

get_sd_devnode() {

  local sd_basenode=""

  sd_basenode=$(find_sd_basenode)

  [[ -z "${sd_basenode}" ]] && block_test "Failed to find mmc base device node"

  if [[ "${WITH_PART}" = "yes" ]]; then
    PRESENT_PARTS=$(fdisk -l "${sd_basenode}" | grep -c "${sd_basenode}p")
    if [[ "${PRESENT_PARTS}" -lt 1 ]]; then
      create_mmc_partition "${sd_basenode}" > /dev/null 2>&1 \
        || block_test "Failed to create a mmc partition !"
    fi
    # Add some delay after formatting a new filesystem
    sleep 3
    DEV_NODE=$(find_part_with_biggest_size "${sd_basenode}" "mmc") \
      || block_test "Error getting partition with biggest size: ${DEV_NODE}"
  else
    DEV_NODE="${sd_basenode}"
  fi
}

get_emmc_devnode() {

  local emmc_basenode=""

  emmc_basenode=$(find_emmc_basenode)
  [[ -z "${emmc_basenode}" ]] && block_test "Failed to find eMMC base device node"

  if [[ "${OS}" == "ubuntu" || "${OS}" == "centos" ]]; then
    for emmc_dev_node in ${emmc_basenode}p*; do
      lsblk "${emmc_dev_node}" | grep -i "lvm" > /dev/null \
        && is_part_lvm_os "${emmc_dev_node}" && continue
      is_rootfs=$(is_part_rootfs "emmc" "${emmc_dev_node}")
      [[ "${is_rootfs}" == "yes" ]] && continue
      is_homefs=$(is_part_homefs "emmc" "${emmc_dev_node}")
      [[ "${is_homefs}" == "yes" ]] && continue
      is_specialfs=$(is_part_specialfs "${emmc_dev_node}")
      [[ "${is_specialfs}" == "yes" ]] && continue
      is_part_boot "${emmc_dev_node}" && continue
      is_part_swap "${emmc_dev_node}" && continue
      check_mount_path "${emmc_dev_node}" "${MOUNT_DIR}" && continue
      DEV_NODE=${emmc_dev_node}
      [[ -e "${DEV_NODE}" ]] && break
    done
    [[ -e "${DEV_NODE}" ]] || block_test "Fail to get emmc device node."
  else
    DEV_NODE=$(find_part_with_biggest_size "${emmc_basenode}" "emmc") \
      || block_test "Error getting partition with biggest size: ${DEV_NODE}"
  fi
}


get_ufs_devnode() {
  if [[ "${OS}" == "ubuntu" || "${OS}" == "centos" ]]; then
    DEV_NODE=$(ls /sys/bus/pci/drivers/ufshcd/*/host*/target*/*/block | grep sd | head -n 1)
    [[ -n "${DEV_NODE}" ]] || block_test "Fail to get UFS device node."
    DEV_NODE=$(ls /dev/${DEV_NODE}* | tail -n1)
  fi
}

############################ Default Params ##############################

############################ USER-DEFINED Params ##############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically
case $ARCH in
esac
case $DRIVER in
esac
case $SOC in
  baytrail|goldsand)
    if [[ "${DEVICE_TYPE}" = "emmc" ]]; then
      if [[ "${SKIP_MOUNT}" = "1" ]]; then
        DEV_NODE="/dev/block/mmcblk0p9"
      else
        DEV_NODE="/dev/block/mmcblk0p5"
      fi
    fi
    ;;
  sofia)
    if [[ "${DEVICE_TYPE}" = "emmc" ]]; then
      if [[ "${SKIP_MOUNT}" = "1" ]];then
        DEV_NODE="/dev/block/mmcblk0p18"
      else
        DEV_NODE="/dev/block/mmcblk0p8"
      fi
    fi
    ;;
  sofia-lte)
    if [[ "${DEVICE_TYPE}" = "emmc" ]]; then
      if [[ "${SKIP_MOUNT}" = "1" ]]; then
        DEV_NODE="/dev/block/mmcblk0p7"
      else
        DEV_NODE="/dev/block/mmcblk0p3"
      fi
    fi
    ;;
esac
case $MACHINE in
  t100)
    if [[ "${DEVICE_TYPE}" = "emmc" && -n "${FS_TYPE}" ]]; then
      DEV_NODE=$(mount | grep "mmcblk0p" | grep "${FS_TYPE}" | cut -d' ' -f1)
    fi
    ;;
esac

[[ -n "${DEV_NODE}" ]] && echo "${DEV_NODE}" && exit 0

######################### Logic here ###########################################

case "${DEVICE_TYPE}" in
  sd)   get_sd_devnode ;;
  emmc) get_emmc_devnode ;;
  ufs) get_ufs_devnode ;;
  sata) DEV_NODE=$(find_scsi_node "${DEVICE_TYPE}" "$MOUNT_DIR") \
          || block_test "Failed to get available SATA device node"
        ;;
  nvme) DEV_NODE=$(find_scsi_node "${DEVICE_TYPE}" "$MOUNT_DIR") \
          || block_test "Failed to get available NVME device node"
        ;;
  usb|usbxhci)
        DEV_NODE=$(find_scsi_node "${DEVICE_TYPE}" "$MOUNT_DIR") \
          || block_test "Failed to get available USB device node"
        ;;
  *)    block_test "Unknown device type: ${DEVICE_TYPE}"
        ;;
esac

echo "${DEV_NODE}"
