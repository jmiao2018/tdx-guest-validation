#!/bin/bash

###############################################################################
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
#
# File: blk_device_bat_test.sh
#
# Description: This script is used for bat tests such as: check drivers, check
#              modules, test mount/mount , bind/unbind
#
# Author(s): Zelin Deng <zelinx.deng@intel.com>
#
# Date: 2015-08-20: -Initial Version
#
# History: 2015-09-16: Refactor to separate different device type:sata/usb/mmc/emmc
#          2018-01-22: Add support for NVME device.
#          2018-02-15: Update code to support SD. Replace 'mmc' for 'sd'

source "blk_device_common.sh"

#Function: blk_mount_umount
#Desp: Do mount umount test
#Input $1: device node $2: mount point
#Output: N/A
#Return: succeeded:0 failed:1
function blk_mount_umount() {

  [[ $# -ne 2 ]] && return 1

  dev_node=$1
  mount_point=$2

  #if has been mounted, then umount->mount back
  mount | grep -w "${dev_node}" && {
    test_print_trc "${dev_node} has been mounted, now umount it"
    #get mount point field,it's different in android and upstream kernel
    field=$(get_mnt_point_field)
    current_mnt_point=$(mount | grep -w "${dev_node}" | cut -d' ' -f"${field}")

    umount -fl "${dev_node}" && {
      [[ ! -d "${current_mnt_point}" ]] && mkdir -p "${current_mnt_point}"
      mount "${dev_node}" "${current_mnt_point}" || return 1

      return 0
    }
  }

  mount -r "${dev_node}" "${mount_point}" || return 1
  # delay to ensure device is not busy
  sleep 5
  umount -fl "${dev_node}" || return 1

  return 0
}

#Function: blk_driver_check
#Desp: check if driver has been loaded
#Input: device type: emmc/mmc,sata,usb...
#Output: N/A
#Return:succeeded:0 failed:1
function blk_driver_check() {

  [[ $# -ne 1 ]] && return 1

  dev_type=$1
  local uas_koption="CONFIG_USB_UAS"

  case "${dev_type}" in
    sd | emmc)
      if [[ -d "${EMMC_SD_DRV_PATH}" ]]; then
        test_print_trc "${dev_type}'s driver has been registered,Check succeeded!"
        return 0
      else
        test_print_trc "${dev_type}'s driver has not been registered,Check failed!"
        return 1
      fi
      ;;
    sata)
      if [[ -d "${SATA_DRV_PATH}" ]]; then
        test_print_trc "${dev_type}'s driver has been registered,Check succeeded!"
        return 0
      else
        test_print_trc "${dev_type}'s driver has not been registered,Check failed!"
        return 1
      fi
      ;;
    ufs)
      if [[ -d "${UFS_DRV_PATH}" ]]; then
        test_print_trc "${dev_type}'s driver has been registered,Check succeeded!"
        return 0
      else
        test_print_trc "${dev_type}'s driver has not been registered,Check failed!"
        return 1
      fi
      ;;
    usb)
      # usb storage depends on kernel module "uas", first check this module
      lsmod | grep -w "${USBHOST_STORAGE_MODULE}" || { \
        if ! test_kconfigs y "${uas_koption}"; then
          test_kconfigs m "${uas_koption}" || block_test "${uas_koption} is not set!"
          #it's defined at blk_device_common.sh
          modprobe "${USBHOST_STORAGE_MODULE}"
          #this kernel module is: uas which means "usb attached scsi"
          if [[ $? -ne 0 ]]; then
            test_print_trc "Failed to load usb storage module, Test failed"
            return 1
          fi
        fi
      }
      if [[ -d "${USBHOST_STORAGE_DRV_PATH}" ]]; then
        test_print_trc "${dev_type}'s driver has been registered,Check succeeded!"
        return 0
      else
        test_print_trc "${dev_type}'s driver has not been registered,Check failed!"
        return 1
      fi
      ;;
    nvme)
      if [[ -d "${NVME_DRV_PATH}" ]]; then
        test_print_trc "${dev_type}'s driver has been registered,Check succeeded!"
        return 0
      else
        test_print_trc "${dev_type}'s driver has not been registered,Check failed!"
        return 1
      fi
      ;;
    *)
      test_print_trc "Invilid device type: ${dev_type}, Please check it"
      return 1
      ;;
  esac
}

#Function: blk_device_check
#Desp: check if device has been registered.Check the softlink
#Input: $1:$dev_node
#Output: N/A
#Return:succeeded:0 failed:1
function blk_device_check() {

  [[ $# -ne 1 ]] && return 1

  dev_node=$1

  if [[ -d "${BLK_DEV_PATH}/${dev_node}" ]]; then
    dev_path=$(readlink -e "${BLK_DEV_PATH}/${dev_node}")
    if [[ -n "${dev_path}" ]]; then
      test_print_trc "${dev_node} is registered at ${dev_path}"
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

#Function: blk_device_get_name
#Desp: get blk device name
#Input: $1:device type: emmc/mmc,sata,usb... $2:$dev_node
#Output: $dev_name: device name
#Return:succeeded:0 failed:1
function blk_device_get_name() {

  [[ $# -ne 2 ]] && return 1

  dev_type=$1
  dev_node=$2

  case "${dev_type}" in
    sd | emmc)
      blk_device_check "${dev_node}" || return 1
      dev_basenode=$(echo "${dev_node}" | cut -d'p' -f1)
      dev_name=$(cat "${BLK_DEV_PATH}/${dev_basenode}/device/name") || return 1
      ;;
    ufs |sata | usb)
      blk_device_check "${dev_node}" || return 1
      dev_basenode=$(echo "${dev_node}" | sed 's/[0-9]//g')
      dev_name=$(cat "${BLK_DEV_PATH}/${dev_basenode}/device/model") || return 1
      ;;
    nvme)
      dev_path=$(blk_device_check "${dev_node}") || return 1
      dev_basenode=$(echo "${dev_node}" | cut -d'p' -f1)
      dev_name=$(cat "${BLK_DEV_PATH}/${dev_basenode}/device/model") || return 1
      ;;
  esac

  echo "${dev_name}"

  return 0
}

#Function: is_swap
#Desp: Check if the given partition is a SWAP
#Input: $1: disk partition
#Output: N/A
#Return:true:0 false:1
function is_swap() {
  blkid | grep "$1" | grep -q "TYPE=\"swap\""
}

#Function: is_root
#Desp: Check if the given partition is root
#Input: $1: disk partition
#Output: N/A
#Return:true:0 false:1
function is_root() {
  mount | grep -w "/" | grep -q "$1"
}

#Function: is_boot
#Desp: Check if the given partition is for EFI boot
#Input: $1: disk partition
#Output: N/A
#Return:true:0 false:1
function is_boot() {
  mount | grep -w "/boot" | grep -q "$1"
}

#Function: is_basenode
#Desp: Check if the given node is basenode
#Input: $1: disk node
#Output: N/A
#Return:true:0 false:1
function is_basenode() {
  lsblk | grep "^${1##*/}"
}

usage() {
cat <<__EOF
  Usage:${0##*/} [ -d DEVICE_TYPE ] [ -c CASE_ID ]
  DEVICE_TYPE: mmc,emmc,sata,ufs
  CASE_ID: launch whitch case
__EOF
}

while getopts :d:c:h arg; do
  case "${arg}" in
    d)  DEV_TYPE="$OPTARG" ;;
    c)  CASE_ID="$OPTARG" ;;
    h)  usage
        exit 1
        ;;
    :)  test_print_err "$0: Must supply arguments to -$OPTARG."
        exit 1
        ;;
    \?) usage
        test_print_err "Invalid Option -$OPTARG ignored."
        exit 1
        ;;
esac
done

: ${CASE_ID:="1"}

if [[ -z "$DEV_TYPE" ]]; then
  test_print_trc "Please input device type"
  exit 1
fi

DEV_NODE=$(get_blk_device_node.sh -d "${DEV_TYPE}")

if [[ "$?" -ne "0" ]]; then
  test_print_trc "Failed to get device node"
  exit 1
fi

test_print_trc "Device type: ${DEV_TYPE}, Device node: ${DEV_NODE}"

case "${CASE_ID}" in
  1)
     test_print_trc "Start to check block device ${DEV_TYPE} driver"
     blk_driver_check "${DEV_TYPE}" || exit 1
     exit 0
     ;;
  2)
     test_print_trc "Start to check $DEV_TYPE block device node under sysfs"
     DEV_NODE=$(echo "${DEV_NODE}" | awk -F'/' '{print $NF}')
     blk_device_check "${DEV_NODE}" || { \
       test_print_err "${DEV_TYPE} device ${DEV_NODE} is not located at sysfs, Failed!"
       exit 1
     }
     test_print_trc "${DEV_TYPE} device all nodes are located at sysfs, Succeeded!"
     exit 0
     ;;
  3)
     test_print_trc "Start to get ${DEV_TYPE} block device name"
     DEV_NODE=$(echo "${DEV_NODE}" | awk -F'/' '{print $NF}')
     blk_name=$(blk_device_get_name "${DEV_TYPE}" "${DEV_NODE}") || { \
       test_print_err "$DEV_TYPE device $DEV_NODE has no name, Failed!"
       exit 1
     }
     test_print_trc "${DEV_TYPE} device ${DEV_NODE}'s name is: ${blk_name}, succeded!"
     exit 0
     ;;
  4)
     test_print_trc "Start to mount/umount block device ${DEV_NODE}"

     MNT_POINT="${TEST_MNT_DIR}_$$"
     [[ ! -d ${MNT_POINT} ]] && do_cmd mkdir -p "${MNT_POINT}"

    # skip mount/umount SWAP partition
    is_swap "${DEV_NODE}" \
      && block_test "${DEV_NODE} is a SWAP partition, skip mount/umount test"
    # skip mount/umount root partition
    is_root "${DEV_NODE}" \
      && block_test "${DEV_NODE} is a root partition, skip mount/umount test"
    # skip mount/umount boot partition
    is_boot "${DEV_NODE}" \
      && block_test "${DEV_NODE} is a boot partition, skip mount/umount test"
    # skip mount/umount disk basenode
    if [[ ${DEV_TYPE} != "ufs" ]]; then
      is_basenode "${DEV_NODE}" \
        && block_test "${DEV_NODE} is not a partition, skip mount/umount test"
    fi
    if blk_mount_umount "${DEV_NODE}" "${MNT_POINT}" ; then
      test_print_trc "Succeeded mount/umount ${DEV_NODE}"
      exit_code=0
    else
      test_print_err "Failed mount/umount ${DEV_NODE}"
      exit_code=1
    fi

    rm -rf "${MNT_POINT}"

    exit "${exit_code}"
    ;;
  esac
