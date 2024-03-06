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
#
# Hongyu Ning <hongyu.ning@intel.com> (intel)
#  - Fixed a script bug in function is_part_lvm_os()
#  - Fixed an ER comparision (=~) script bug in function check_mount_path()
#  - Fixed valid test device_node check missing on homefs partition issue
#    function is_part_homefs() added
#  - Add function is_part_specialfs() for valid test device_node check
#    on special fs partition
# Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#  - Added logic to create folders required to perform common test ops
#    (mount,read,write).
#  - Changed shebang and some cmd's to force the use busybox cmd set.
#  - Modified mount point and R/W ops folder due to permission restriction in
#    Android rootfs, change to /data.
#  - Removed code:
#    - Switch case for tool selection: fdisk, gdisk,
#      parted (fdisk is Busybox default)
#    - Not used vars and funcs.
#    - get_fs_root() - never used.
#    - printout_model() - not model entry for devices in Android.
#    - find_all_scsi_drives() - not scsi devices in DUT's ever.
#  - Added get_dev_node_fs() function.
#  - Added is_format_needed() function.
#  - Added is_dev_node_big_enough() function.
#  - Added calc_space_needed_for_test() function.
#  - Modified VARS containig paths with LTPROOT as base instead of harcoded.
#  - Added static support for SoFIA LTE SoC partition layout.
#
# Juan Carlos Alonso <juan.carlos.alonso@intel.com> (Intel)
#  - Modified get_part_size_of_devnode() function in order to get the correct
#    size of a partition.
#  - Replace 'EMMC_MMC_DRV_PATH' variable for 'EMMC_SD_DRV_PATH'
#  - Update 'get_part_size_of_devnode()' function to check the free space
#    available in device node to continue the test.
#
# Zelin Deng <zelinx.deng@intel.com> (Intel)
#  - Removed $BUSYBOX_DIR, since it'll be exported before test.
#  - Add get_blk_dev_dir() function to get devnode directory.
#  - Add $DD $DF etc. to seprated commands under /bin from those under
#    ${LTPROOT}/bin/.
#  - At function find_part_with_biggest_size(), I add logical to avoid getting
#    "Extended" partition.
#  - Add function get_blk_dev_dir(). This function is used to distinguish
#    the block device node directory in Android and Upstream.
#  - Add function get_blk_dev_node_specific(). This function is used to get
#    platform specific block device node.
#  - Add function get_mnt_point_field. This function is used to get mount
#    point field. The field of mount points between Android and upstream are
#    different:
#    - Upstream: /dev/sda1 on / type ext4 (rw,errors=remount-ro)
#    - Android: rootfs / rootfs ro,seclabel,size=432668k,nr_inodes=108167 0 0
#    So the field of mount point in android kernel is 2 and 3 in upstream kernel.
#  - Support USB storage in upstream kernel.
#  - Replaced sed by tr on calc_space_needed_for_test() due to hang on GSD Simics.
#  - Added goldsand case in get_blk_dev_node_specific().
#  - Added 'check_blk_test_env' function to check SATA test environment.
#
# Wenzhong Sun <wenzhong.sun@intel.com> (Intel)
#  - Remove get_blk_dev_node_specific function and merge its logic into
#    get_blk_device_node.sh.
#  - Refactore is_part_rootfs function.
#  - Add is_part_boot() function.
#  - Add is_part_swap() function.
###############################################################################

# @desc Provides common functions to obtain block dev nodes, partitiion and
#       its size
# @params <dev_base_node>  <device_type>
# @returns  The biggest partition no rootfs
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-16: Ported to work with Android on IA.
# @history 2015-04-17: Added funcs to determine if format is needed in dev node.
# @history 2015-04-26: Added funcs to check if dev_node is big enough for a test.
# @history 2015-04-27: Use LTPROOT as base in VARS storing paths.
# @history 2015-06-18: Modified get_part_size_of_devnode() function.
# @history 2015-08-10: Remove unnecessary variables $BUSYBOX_DIR
# @history 2015-08-21: Modified get_blk_dev_node_specific to support usb storage
# @history 2015-09-09: Added support for SoFIA LTE SoC.
# @history 2016-01-29: Added GSD case and sed replaced by tr.
# @history 2016-06-15: Remove get_blk_dev_node_specific function and merge its
#                      logic into get_blk_device_node.sh.
# @history 2017-02-07: Added 'check_blk_test_env' function.
# @history 2018-01-22: Added 'NVME_DRV_PATH' variable for NVME device.
# @history 2018-02-15: Replace 'EMMC_MMC_DRV_PATH' for 'EMMC_SD_DRV_PATH'
# @history 2018-02-26: Update 'get_part_size_of_devnode()' to check free
#                      space available in device node.
# @history 2018-04-02: add check_mount_path to judge the mount path
# @history 2018-08-20: fix script bug in function is_part_lvm_os(), to return correct ${is_boot}
# @history 2019-07-26: 1. fix valid test device_node check missing on homefs partition issue
#                         function is_part_homefs() added
#                      2. add function is_part_specialfs() for valid test device_node check
#                         on special fs partition scenarios

source "common.sh"

# Export some paths for MMC/SDHCI tests
export MMC_BUS_DRIVER_PATH="/sys/bus/mmc/drivers/mmcblk"
export DEBUGFS_MNT="/sys/kernel/debug"
export SDHCI_PCI_MOD_NAME="sdhci-pci"
export SDHCI_ACPI_MOD_NAME="sdhci-acpi"

BUSYBOX_DIR="${LTPROOT}/bin"
TEST_DIR="$LTPROOT/test_dir"
BLK_TEST_DIR="${TEST_DIR}/blk"
TEST_MNT_DIR="$TEST_DIR/mnt"
TEST_TMP_DIR="${TEST_DIR}/tmp"

# For basic func tests. uas is a common kernel module if you need to use
# usb storage
EMMC_SD_DEV_PATH="/sys/bus/mmc/devices"
EMMC_SD_DRV_PATH="/sys/bus/mmc/drivers/mmcblk"
SATA_DRV_PATH="/sys/bus/scsi/drivers/sd"
USBHOST_STORAGE_DRV_PATH="/sys/bus/usb/drivers/usb-storage"
USBHOST_STORAGE_MODULE="uas"
BLK_DEV_PATH="/sys/class/block"
NVME_DRV_PATH="/sys/bus/pci/drivers/nvme/"
UFS_DRV_PATH="/sys/bus/pci/drivers/ufshcd"

# Some special tools(such as: ls dd df etc.) on android may need replaced by
# busybox tools. So add this to support both android and upstream.
# Using $DD or $LS etc to replace dd or ls etc.
: ${DD:='dd'}
: ${LS:='ls'}
: ${DF:='df'}

# $OS will be exported by runltp when parsing platform file
if [[ "$OS" = "android" ]]; then
  DD="${BUSYBOX_DIR}/dd"
  LS="${BUSYBOX_DIR}/ls"
  DF="${BUSYBOX_DIR}/df"
fi

############################ Functions ################################

# CHECK TEST ENVIRONMENT
check_blk_test_env() {
  which lspci &> /dev/null
  [[ $? -eq 0 ]] || die "lspci is not in the current environment"
  which hdparm &> /dev/null
  [[ $? -eq 0 ]] || die "hdparm is not in the current environment"
}

# This function return DEVNODE with the biggest size.
#   If the partition is boot or rootfs partition, it will be skipped.
# Input: DEV_BASE_NODE: like /dev/mmcblk0 etc
#        device_type: like 'mmc', 'usb'
# It only tested on MMCSD and it should work on other block devices
find_part_with_biggest_size() {
  if [[ $# -ne 2 ]]; then
    die "Usage: $0 <dev_base_node like /dev/mmcblk0, /dev/sda> <device_type like mmc, usb>"
  fi

  DEV_BASE_NODE=$1
  DEVICE_TYPE=$2
  SIZE_BIGGEST=0
  TMP_IFS=$IFS
  IFS=$'\n'

  # We only need fdisk which comes with busybox
  MATCH=$(fdisk -l "${DEV_BASE_NODE}" | grep "${DEV_BASE_NODE}"p)
  for i in $MATCH; do
    LINE=$i
    DEVNODE=$(echo "${LINE}" | awk -F " " '{print $1}')
    NODE_SYSTEM=$(echo "${LINE}" | awk -F" " '{print $NF}')
    IS_ROOTFS=$(is_part_rootfs "${DEVICE_TYPE}" "${DEVNODE}") \
      || die "error when calling is_part_rootfs: ${IS_ROOTFS}"
    if [[ "${IS_ROOTFS}" = "no" ]]; then
      [[ "$NODE_SYSTEM" == "Extended" ]] && continue
      SIZE=$(echo "${LINE}" | awk -F " " '{print $4}' | sed s/+//)
      if [[ "${SIZE}" -gt "${SIZE_BIGGEST}" ]]; then
        SIZE_BIGGEST="${SIZE}"
        PART_DEVNODE="${DEVNODE}"
      fi
    fi
  done

  IFS=${TMP_IFS}
  if [[ -z "${PART_DEVNODE}" ]]; then
    die "Could not find the partition to test! Maybe all the existing partitions are either boot or rootfs partitions. Or may be there is no any partition on the card. Please create at least one test partition on ${DEVICE_TYPE} and make initial filesystem on it."
  fi

  echo "${PART_DEVNODE}"
}

# Get size of the partition with PART_DEVNODE
# Return size is in 'MBytes'
get_part_size_of_devnode() {
  PART_DEVNODE=$1
  CHECK_SPACE=$2

  if [[ ! -n "${CHECK_SPACE}" ]]; then
    PARTBYTES=$(fdisk -l "${PART_DEVNODE}" | grep "Disk ${PART_DEVNODE}:" \
      | awk '{print $5}' | head -1)
    if [[ "${PARTBYTES}" -le 0 ]]; then
      die "Could not get partition size from ${PART_DEVNODE}"
    fi
    PARTSIZE=$((PARTBYTES/MB))
    echo "${PARTSIZE}"

  else
    SIZEFREE=$(df | grep "${PART_DEVNODE}" | awk '{print $4}' | head -1)
    if [[ "${SIZEFREE}" -le 0 ]]; then
      die "Could not get space available from ${PART_DEVNODE}"
    fi
    SIZEFREE=$((SIZEFREE/K))
    echo "${SIZEFREE}"
  fi
}

# Check if the partition is holding the root fs
# Input: partition devnode: like /dev/mmcblk0p1
#        device_type: to decide which fs to try to mount
# Output: 0 for true, 1 for false
is_part_rootfs() {
  [[ $# -eq 2 ]] || die "Usage: $0 <device_type like 'mmc', 'usb'> <device_node like /dev/mmcblk0p1, /dev/sda1>"

  local dev_type=$1
  local dev_node=$2
  local mnt_point=""
  local need_umount=false
  local is_rootfs="no"

  mount | grep -q "${dev_node}"

  if [[ $? -eq 0 ]]; then
    local field=$(get_mnt_point_field)
    mnt_point=$(mount | grep "${dev_node}" | cut -d" " -f"${field}")
  else
    mnt_point="${TEST_MNT_DIR}/partition_${dev_type}_$$"
    blk_device_do_mount.sh -n "${dev_node}" -d "${dev_type}" -m "${mnt_point}" &> /dev/null
    need_umount="true"
  fi

  [[ -e "${mnt_point}/etc" ]] && [[ -e "${mnt_point}/dev" ]] && is_rootfs="yes"

  if ${need_umount}; then
    blk_device_umount.sh -m "${mnt_point}" &> /dev/null
  fi

  echo "${is_rootfs}"
}

# Check if the partition is holding the home fs standalone
# Input: partition devnod: like /dev/sda1
#       device_type: to decide which fs to try to mount
# Output: 0 for true, 1 for false
is_part_homefs() {
  [[ $# -eq 2 ]] || die "Usage: $0 <device_type like 'mmc', 'usb'> <device_node like /dev/mmcblk0p1, /dev/sda1>"
  local dev_type=$1
  local dev_node=$2
  local mnt_point=""
  local need_umount=false
  local is_homefs="no"

  mount | grep -q "${dev_node}"
  if [[ $? -eq 0 ]]; then
    local field=$(get_mnt_point_field)
    mnt_point=$(mount | grep "${dev_node}" | cut -d" " -f"${field}")
  else
    mnt_point="${TEST_MNT_DIR}/partition_${dev_type}_$$"
    blk_device_do_mount.sh -n "${dev_node}" -d "${dev_type}" -m "${mnt_point}" &> /dev/null
    need_umount="true"
  fi

  local username=""
  for username in $(cat /etc/passwd | awk -F: '{print $1}'); do
    [[ -e "${mnt_point}/${username}" ]] && is_homefs="yes" && break
  done

  if ${need_umount}; then
    blk_device_umount.sh -m "${mnt_point}" &> /dev/null
  fi

  echo "${is_homefs}"
}

# Check if the partition is holding any special fs
# Input: partition devnode: like /dev/sda1
# Output: 0 for true, 1 for false
is_part_specialfs() {
  [[ $# -eq 1 ]] || die "Usage: $0 <device_node like /dev/mmcblk0p1, /dev/sda1>"
  local dev_node=$1
  local mnt_point=""
  local is_specialfs="no"
  local field=$(get_mnt_point_field)

  #check only if it's mounted already
  mount | grep -q "${dev_node}"
  if [[ $? -eq 0 ]]; then
    local mnt_point=$(mount | grep "${dev_node}" | cut -d" " -f"${field}")
    local pathname_list="\
      /bin /config /dev /etc /home /lib /lib32 /lib64 /libx32 /lost+found\
      /media /opt /proc /root /run /sbin /snap /source_lib /srv /sys /tmp /usr /var\
      "
    local pathname=""
    for pathname in ${pathname_list}; do
      [[ "${mnt_point}" = "${pathname}" ]] && is_specialfs="yes" && break
    done
  fi

  echo "{is_specialfs}"
}

# Check if the partition is for os with lvm
# Input: partition dev_node: like /dev/sda1
# Output: 0 for true, 1 for false
is_part_lvm_os() {
  local dev_node="$1"
  local is_boot=1
  pvdisplay "${dev_node}" -m | grep -E 'root|home|swap' > /dev/null
  [[ $? -eq 0 ]] && is_boot=0
  return "${is_boot}"
}

# Check if the partition is for boot
# Input: partition dev_node: like /dev/sda1
# Output: 0 for true, 1 for false
is_part_boot() {
  local dev_node="$1"
  local mnt_point_field=""
  local mnt_point=""
  local temp_mnt_point=""
  local is_boot="1"

  # Fisrtly check whether this partition has been mounted, if mounted,
  # check whether the mount point is used for boot.
  mount | grep -qw "${dev_node}"

  if [[ $? -eq 0 ]]; then
    mnt_point_field=$(get_mnt_point_field)
    [[ -n "${mnt_point_field}" ]] || die "fail to get mount point field!"
    mnt_point=$(mount | grep -w "${dev_node}" | cut -d" " -f"${mnt_point_field}")
    [[ -n "${mnt_point}" ]] || die "fail to get mount point!"
    [[ "${mnt_point}" =~ "/boot" ]] && is_boot=0
    # Clear Linux boot partition is not automatically mounted as /boot/xxx
    # Skip Clear Linux boot partition when it's mounted manually
    [[ -e "${mnt_point}/EFI" ]] && is_boot=0
    [[ -e "${mnt_point}/grub" ]] && is_boot=0
    [[ -e "${mnt_point}/efi" ]] && is_boot=0
    [[ -e "${mnt_point}/grub2" ]] && is_boot=0
    [[ -e "${mnt_point}/loader" ]] && is_boot=0
  else
    # We shouldn't try to mount a swap partition, so check it before mounting it.
    # If it is swap partition, direcectly return 1
    is_part_swap "${dev_node}" && return "${is_boot}"
    # Mount this partition to a temporary mount point and check whether it
    # contains boot file/directory.
    temp_mnt_point=$(mktemp -d)
    [[ -n "${temp_mnt_point}" ]] || die "fail to create temporary mount point!"
    mount "${dev_node}" "${temp_mnt_point}" || die "fail to mount ${dev_node}!"
    [[ -e "${temp_mnt_point}/EFI" ]] && is_boot=0
    [[ -e "${temp_mnt_point}/grub" ]] && is_boot=0
    [[ -e "${temp_mnt_point}/efi" ]] && is_boot=0
    [[ -e "${temp_mnt_point}/grub2" ]] && is_boot=0
    [[ -e "${temp_mnt_point}/loader" ]] && is_boot=0
    umount "$dev_node"
  fi

  return "${is_boot}"
}

check_mount_path() {
  local dev_node="$1"
  local other="$2"
  local mnt_point_field=""
  local mnt_point=""
  local temp_mnt_point=""
  local is_other="1"

  # Fisrtly check whether this partition has been mounted, if mounted,
  # check whether the mount point is used for /home or others.
  mount | grep -qw "${dev_node}"

  if [[ $? -eq 0 ]]; then
    mnt_point_field=$(get_mnt_point_field)
    [[ -n "${mnt_point_field}" ]] || die "fail to get mount point field!"
    mnt_point=$(mount | grep -w "${dev_node}" | cut -d" " -f"${mnt_point_field}")
    [[ -n "${mnt_point}" ]] || die "fail to get mount point!"
    if [[ -z "$other" ]]; then
      #no argv $2 ($MOUNT_DIR) passed for special mount path check
      [[ -z "${mnt_point}" ]] && is_other=0
    else
      [[ "${mnt_point}" =~ $other ]] && is_other=0
    fi
  else
    # We shouldn't try to mount a swap partition, so check it before mounting it.
    # If it is swap partition, direcectly return 1
    is_part_swap "${dev_node}" && return "${is_other}"
    # Mount this partition to a temporary mount point and check whether it
    # contains other file/directory.
    temp_mnt_point=$(mktemp -d)
    [[ -n "${temp_mnt_point}" ]] || die "fail to create temporary mount point!"
    mount "${dev_node}" "${temp_mnt_point}" || die "fail to mount ${dev_node}!"
    [[ -e "${temp_mnt_point}/EFI" ]] && is_other=0
    [[ -e "${temp_mnt_point}/grub" ]] && is_other=0
    umount "$dev_node"
  fi

  return "${is_other}"
}

#Function: is_part_swap
#Desp: Check if the given partition is a SWAP
#Input: $1: disk partition
#Output: N/A
#Return:true:0 false:1
function is_part_swap() {
  blkid | grep "$1" | grep -q "TYPE=\"swap\""
}

# Obtain the File System type from an mounted/umounted device node.
# Input: device node to check: like /dev/block/mmcblk1p1.
# Return: File System type in dev node.
get_dev_node_fs() {
  if [[ $# -ne 1 ]]; then
    die "Usage: $0 <device_node> like /dev/block/mmcblk1p1"
  fi

  local DEV_NODE="$1"
  local DEV_NODE_FS=""

  DEV_NODE_FS=$(blkid "${DEV_NODE}" | grep -ioE "TYPE=\".*\" " | cut -d'"' -f2)

  echo "${DEV_NODE_FS}"
}

# Find out if a File System format is needed in case the dev node already
# contains a different FS.
# Input: device node to check: like /dev/block/mmcblk1p1
#        file system to check: like vfat
# Return: yes --> format is needed
#          no --> format is not needed
is_format_needed() {
  if [[ $# -ne 2 ]]; then
    die "Usage: $0 <device_node> <fs_type> like /dev/block/mmcblk1p1 vfat"
  fi

  local DEV_NODE="$1"
  local FS="$2"
  local DEV_NODE_FS=""
  local FORMAT_NEEDED="yes"

  DEV_NODE_FS=$(get_dev_node_fs "${DEV_NODE}")

  if [[ "${FS}" = "${DEV_NODE_FS}" ]]; then
    FORMAT_NEEDED="no"
  fi

  echo "${FORMAT_NEEDED}"
}

# Determine if space in there's enough space in dev_node to store the specified
# file size.
# Input: DEV_NODE to check: like /dev/block/mmcblk1p1
#        FILE_SIZE in Mb to check if it can be stored.
# Return: 0 --> FILE_SIZE can be stored.
#         1 --> FILE_SIZE can't be stored.
is_dev_node_big_enough() {
  if [[ $# -ne 2 ]]; then
    die "Usage: $0 <device_node> <file_size> in Mb like /dev/block/mmcblk1p1"
  fi

  # Get args
  local DEV_NODE=$1
  local FILE_SIZE=$2
  local DEV_NODE_SIZE=""
  local NUM_RGX="^[0-9]+$"
  local ENOUGH_FLAG=0

  DEV_NODE_SIZE=$(get_part_size_of_devnode "${DEV_NODE}")
  # Check if valid numbers
  [[ "$FILE_SIZE" =~ $NUM_RGX ]] \
    || die "FILE_SIZE= ${FILE_SIZE} is not a number"
  [[ "$DEV_NODE_SIZE" =~ $NUM_RGX ]] \
    || die "DEV_NODE_SIZE= ${DEV_NODE_SIZE} is not a number"

  # Check if there's enough space in dev_node
  ENOUGH_FLAG=$(echo | \
    awk -v x="${FILE_SIZE}" -v y="${DEV_NODE_SIZE}" '{r=y < x} {print r}')

  return "${ENOUGH_FLAG}"
}

# Calculate total space needed for a certain blk test.
# Input: BASE_FILE_SIZE which may be ni the form 250K, 300M, 12G, etc...
#             [CNT]     which is the coefficient for the BASE_FILE_SIZE.
#            [LOOP]     which may be an extra coefficient of previous args.
# Return FILE_SIZE_MB which is space needeed for test in MB.
calc_space_needed_for_test() {
  if [[ "$#" -lt 1 ]]; then
    die "Arguments missing..."
  fi

  # Get args
  local BASE_FILE_SIZE="$1"
  local CNT="$2"
  local LOOP="$3"
  [[ -z "${BASE_FILE_SIZE}" ]] && die "Not FILE_SIZE provided..."
  local FILE_SIZE_MB=""
  local BUFSIZE=""

  # Convert to MB
  case "${BASE_FILE_SIZE}" in
    *K)
        BUFSIZE=$(echo "${BASE_FILE_SIZE}" | tr -d [aA-zZ])
        BUFSIZE=$(echo \
          | awk -v x="${BASE_FILE_SIZE}" -v k="${KB}" '{mb= x / k} {print mb}')
        ;;
    *M)
        BUFSIZE=$(echo "${BASE_FILE_SIZE}" | tr -d [aA-zZ])
        ;;
    *G)
        BUFSIZE=$(echo "${BASE_FILE_SIZE}" | tr -d [aA-zZ])
        BUFSIZE=$(echo \
          | awk -v x="${BASE_FILE_SIZE}" -v k="${KB}" '{mb= x * k} {print mb}')
        ;;
    *)
        BUFSIZE=$(echo \
          | awk -v x="${BASE_FILE_SIZE}" -v m="${MB}" '{mb= x / m} {print mb}')
        ;;
  esac

  FILE_SIZE_MB="${BUFSIZE}"

  # Calculate needed space
  [[ -n "$CNT" ]] \
    && FILE_SIZE_MB=$(echo \
      | awk -v x="${FILE_SIZE_MB}" -v y="${CNT}" '{s= x * y} {print s}')

  if [[ -n "$LOOP" ]]; then
    [[ "$LOOP" -gt 1 ]] \
      && FILE_SIZE_MB=$(echo \
        | awk -v x="${FILE_SIZE_MB}" -v y="${LOOP}" '{s= x * y} {print s}')
  fi

  FILE_SIZE_MB=$(echo "${FILE_SIZE_MB}" | awk '{print int($1) + 1}')

  echo "${FILE_SIZE_MB}"
}

#platform specific, get block device directory. seperated by ','
#Input: N/A
#Output: "$SCSI_DEV_DIR,EMMC_DEV_DIR,MMC_DEV_DIR"
get_blk_dev_dir() {
  case "${OS}" in
    centos)  echo "/dev/disk/by-id,/dev,/dev" ;;
    ubuntu)  echo "/dev/disk/by-id,/dev,/dev" ;;
    android) echo "/dev/block,/dev/block,/dev/block" ;;
  esac
}

#to get mnt point field, it's different between android and upstream kernel
#on android mnt point field is 2, and 3 for other OS (Ubuntu/Debian) environment
#Input: N/A
#Output: $field
get_mnt_point_field() {
  local field=3

  echo "${field}"
}

############################ Do some settings ##############################
[ -d "${TEST_DIR}" ] || do_cmd mkdir -p "${TEST_DIR}" > /dev/null
[ -d "${BLK_TEST_DIR}" ] || do_cmd mkdir -p "${BLK_TEST_DIR}" > /dev/null
[ -d "${TEST_MNT_DIR}" ] || do_cmd mkdir -p "${TEST_MNT_DIR}" > /dev/null
[ -d "${TEST_TMP_DIR}" ] || do_cmd mkdir -p "${TEST_TMP_DIR}" > /dev/null
