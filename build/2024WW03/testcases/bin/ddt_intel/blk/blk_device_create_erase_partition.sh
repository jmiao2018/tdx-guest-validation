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
# Contributors:
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -First version.
#   Zelin Deng <zelinx.deng@intel.com> (Intel)
#     -Remove $BUSYBOX_DIR to fit the upstream kernel
#   Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     -Update script to create/delete 1 to 4 partitions in block devices.
#   Hongyu Ning <hongyu.ning@intel.com>
#     -Update Create partition part to avoid mount failure after partition created.
###############################################################################

# @desc This script is used to create partition(s); remove the partition if it exists.
#       Only support to create one or two partitions.
#       This script doesn't apply for MTD device.
# @params [-n DEV_NODE] [-d DEVICE TYPE] [-p NUM_PARTS] [-l LOGICAL_NUM_PARTS]
#         [-ceh]
# @returns None
# @history 2011-05-06: First version.
# @history 2018-23-03: Update script to create/delete several partitions.

source "blk_device_common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
  usage: ./${0##*/} <-d DEVICE TYPE> [-n DEV_NODE]  [-p PRIMARY_NUM_PARTS]
                    [-l LOGICAL_NUM_PARTS] [-ceh]
        -c                    only clear partition table in specified dev_node,
                              this will cause partition arguments to be ignored.
        -d DEVICE_TYPE        device type like 'mmc'.
        -e                    create an extended partition as last partition
                              in DEV_NODE.
        -l LOGICAL_NUM_PARTS  create the specified number of logical partitions
                              within an extended partition.
        -n DEV_NODE           device_node like /dev/sda1; /dev/block/mmcblk0p1.
        -p PRIMARY_NUM_PARTS  create the specified number of primary partitions.
           *NOTE: Please notice:
            - A maximum of 4 primary partitions can be created
            - Primary and Extended partitions will take same size.
            - Logical partitions will take same size.
            - Maximum Logical partitions is given by the size of the extended
              partition.
              i.e. L_SIZE = EXTENDED_SIZE / LOGICAL_NUM_PARTS.
            - If -l flag is used to create logical partitions and -e flag is not
              present, an extended partition will be created automatically.
        -h Help               print this usage
EOF
exit 0
}

# Obtain the especified disk size in cylinders.
# Input: DEV_NODE_ENTRY disk / dev_node to obtain total size from.
# Return: DISK_CYL_SIZE Size of disk in cylinders.
get_disk_size() {
  [[ $# -ne 1 ]] && echo "0" && return 1

  local DEV_NODE_ENTRY=$1
  local FDISK_STR="c\nu\np\nq\n"
  local DISK_CYL_SIZE=0

  DISK_CYL_SIZE=$(echo -e "${FDISK_STR}" \
                  | "${FDISK}" "${DEV_NODE_ENTRY}" \
                  | grep "heads" \
                  | awk '{print $5}')

  echo "${DISK_CYL_SIZE}"
}

# Obtain specified partitions offsets in order to be all same size.
# Input: PRIMARY_PARTS_NUM  number of primary partitions.
#        PRIMARY_PART_SIZE  primary partition size.
#        LOGICAL_PARTS_NUM  number of logical partitions.
#        LOGICAL_PART_SIZE  primary partition size.
# Return: none
calc_parts_offsets() {

  [[ $# -ne 4 ]] && die "Arguments missing."

  # Get Args
  local PRIMARY_PARTS_NUM="$1"
  local PRIMARY_PART_SIZE="$2"
  local LOGICAL_PARTS_NUM="$3"
  local LOGICAL_PART_SIZE="$4"
  local PRIMARY_PARTS_NUM_CPY="${PRIMARY_PARTS_NUM}"
  local LAST_VAL=0
  local OFFSET=0
  local i=0

  # Calculate offsets
  while [[ "${PRIMARY_PARTS_NUM}" -gt 0 || "${LOGICAL_PARTS_NUM}" -gt 0 ]]; do

    # Calculate primary partitions offsets
    if [[ "${PRIMARY_PARTS_NUM}" -gt 0 ]]; then
      if [[ "${i}" -eq 0 ]]; then
        P_PART_OFFSET_ARRAY=( $PRIMARY_PART_SIZE )
      elif [[ "${PRIMARY_PARTS_NUM}" -gt 1 ]]; then
        LAST_VAL=${P_PART_OFFSET_ARRAY[${#P_PART_OFFSET_ARRAY[@]} - 1]}
        OFFSET=$(( LAST_VAL + PRIMARY_PART_SIZE ))
        P_PART_OFFSET_ARRAY+=( $OFFSET )
      fi
      PRIMARY_PARTS_NUM=$(( PRIMARY_PARTS_NUM - 1 ))
      echo "[P]P_PART_OFFSET_ARRAY[@] =" "${P_PART_OFFSET_ARRAY[@]}"

    # Calculate logical partitions offsets
    elif [[ "${LOGICAL_PARTS_NUM}" -gt 0 ]]; then
      if [[ "${i}" -eq "${PRIMARY_PARTS_NUM_CPY}" ]]; then
        LAST_VAL=${P_PART_OFFSET_ARRAY[${#P_PART_OFFSET_ARRAY[@]} - 1]}
      elif [[ "${LOGICAL_PARTS_NUM}" -gt 1 ]]; then
        LAST_VAL=${L_PART_OFFSET_ARRAY[${#L_PART_OFFSET_ARRAY[@]} - 1]}
      fi
      OFFSET=$(( LAST_VAL + LOGICAL_PART_SIZE ))
      L_PART_OFFSET_ARRAY+=( $OFFSET )
      LOGICAL_PARTS_NUM=$(( LOGICAL_PARTS_NUM - 1 ))
    fi

    i=$(( i + 1 ))
  done

  return 0
}

# Construct string to send fdisk in order to create/erase partitions in
# non-interactive manner
# Input:  STR_PURPOSE        one of 'create' or 'erase'.
#         PRIMARY_PART_NUM   number of primary partitions to creare erase.
#         LOGICAL_PART_NUM   number of logical partitions to create/erase.
#         EXTENDED_PART_FLAG make last of primary partitions extended.
# Return: FDISK_STR string to be sent to fdisk for non-interactive usage.
build_fdisk_str() {

  # Get args
  local STR_PURPOSE="$1"
  local PRIMARY_PART_NUM="$2"
  local LOGICAL_PART_NUM="$3"
  local EXTENDED_PART_FLAG="$4"
  local P_PART_SIZE="$5"
  local TOTAL_PART_NUM=$(( PRIMARY_PART_NUM + LOGICAL_PART_NUM ))
  local CREATE_PRIMARY_PART_BASE_STR="n\np\n"
  local CREATE_EXTEND_PART_BASE_STR="n\ne\n"
  local CREATE_LOGICAL_PART_BASE_STR="n\n"
  local ERASE_PART_BASE_STR="d\n"
  local FDISK_STR=""
  local PRIMARY_OFFSET_IDX=0
  local LOGICAL_OFFSET_IDX=0
  local CUR_OFFSET=0

  [[ "${PRIMARY_PART_NUM}" -lt 1 && "${LOGICAL_PART_NUM}" -lt 1 ]] && return 0

  # Construct specified str
  case "${STR_PURPOSE}" in
    create)
      for (( CNT=1; CNT<=TOTAL_PART_NUM; CNT++ )); do
        # Fill FDISK_STR for primary partitions
        if   [[ "${CNT}" -le "${PRIMARY_PART_NUM}" ]]; then
          # Add last primary partition as extended if required
          if [[ "${CNT}" -eq "${PRIMARY_PART_NUM}" ]] && \
             [[ "${LOGICAL_PART_NUM}" -gt 0 || "${EXTENDED_PART_FLAG}" -eq 1 ]]; then
            # Offset is not required due to end of disk
            FDISK_STR+="${CREATE_EXTEND_PART_BASE_STR}${CNT}\n\n\n"
          # Add partition as primary
          elif [[ "${CNT}" -lt "${PRIMARY_PART_NUM}" ]]; then
            CUR_OFFSET=${P_PART_OFFSET_ARRAY[$PRIMARY_OFFSET_IDX]}
            FDISK_STR+="${CREATE_PRIMARY_PART_BASE_STR}${CNT}\n\n+${P_PART_SIZE}G\n"
            PRIMARY_OFFSET_IDX=$(( PRIMARY_OFFSET_IDX + 1 ))
          # Add last partition as primary if not extended required
          else
            # Offset is not required due to end of disk
            FDISK_STR+="${CREATE_PRIMARY_PART_BASE_STR}${CNT}\n\n\n"
          fi

        # Fill FDISK_STR for logical partitions within extended partition
        elif [[ "${LOGICAL_PART_NUM}" -gt 1 ]]; then
          CUR_OFFSET=${L_PART_OFFSET_ARRAY[$LOGICAL_OFFSET_IDX]}
          if [[ "${PRIMARY_PART_NUM}" -lt 4 ]]; then
            # Add 'l' to str is required if primary parts < 4
            FDISK_STR+="${CREATE_LOGICAL_PART_BASE_STR}l\n${CNT}\n\n${CUR_OFFSET}\n"
          else
            FDISK_STR+="${CREATE_LOGICAL_PART_BASE_STR}${CNT}\n\n${CUR_OFFSET}\n"
          fi
          LOGICAL_OFFSET_IDX=$(( LOGICAL_OFFSET_IDX + 1 ))
          LOGICAL_PART_NUM=$(( LOGICAL_PART_NUM - 1 ))
        # Add last logical partition
        elif [[ "${LOGICAL_PART_NUM}" -eq 1 ]]; then
          # Offset is not required due to end of disk
          if [[ "${PRIMARY_PART_NUM}" -lt 4 ]]; then
            # Add 'l' to str is required if primary parts < 4
            FDISK_STR+="${CREATE_LOGICAL_PART_BASE_STR}l\n${CNT}\n\n\n"
          else
            FDISK_STR+="${CREATE_LOGICAL_PART_BASE_STR}${CNT}\n\n\n"
          fi
        fi
      done
    ;;
    erase)
      for (( CNT=1; CNT<=TOTAL_PART_NUM; CNT++ )); do
        if [[ "${CNT}" != "${TOTAL_PART_NUM}" ]]; then
          FDISK_STR+="${ERASE_PART_BASE_STR}$CNT\n"
        else
          FDISK_STR+="${ERASE_PART_BASE_STR}"
        fi
      done
    ;;
    *) die "Invalid option $STR_PURPOSE."
  esac

  # Add write partition table and quit opts
  FDISK_STR+="w\n"

  echo "${FDISK_STR}"
}

# Obtain the number of certain partittion type within a disk.
# Input: DEV_NODE_ENTRY  device node to look partitions on.
#        PART_TYPE type of partition to be counted. It may be one of:
#         -'P' for primary partitions.
#         -'L' for logical partitions.
#         -'A' all partitions
# Return: PART_CNT the number or partitions found in the dev_node.
get_partition_number() {

  [[ $# -ne 2 ]] && die "Arguments missing."

  #Get args
  local DEV_NODE_ENTRY="$1"
  local PART_TYPE="$2"
  local PART_CNT=0
  local PART_LIST=""
  local EXTENDED_PART=""

  local patt="/dev/sd*"

  # Get partitions
  if [[ ${DEV_NODE_ENTRY} =~ $patt ]]; then
    PART_LIST=$("${FDISK}" -l "${DEV_NODE_ENTRY}" | grep "${DEV_NODE_ENTRY}[0-9]")
  else
    PART_LIST=$("${FDISK}" -l "${DEV_NODE_ENTRY}" | grep "${DEV_NODE_ENTRY}p")
  fi

  EXTENDED_PART=$(echo "${PART_LIST}" | grep "Extended")

  # Check if logical partitions may be present
  if [[ -z "${EXTENDED_PART}" && "${PART_TYPE}" = "L" ]]; then
    echo "${PART_CNT}"; return 0;
  fi

  # Get partitions number
  PART_CNT=$(echo "${PART_LIST}" | wc -l)

  # Count partitions manually
  case "${PART_TYPE}" in
    P|L)
      PART_TYPE_LIST=( $(echo "${PART_LIST}" | awk '{print $6}') )
      PART_CNT=0
      XTND_PART_PASS=0

      for PART in "${PART_TYPE_LIST[@]}"; do
        # Count primary partitions
        if [[ "${PART_TYPE}" = "P" ]]; then
          # We are done with primary partitions at this point
          [[ "${XTND_PART_PASS}" -eq 1 ]] && break
          PART_CNT=$(( PART_CNT + 1 ))
        # Count logical partitions after extended partition
        elif [[ "${XTND_PART_PASS}" -eq 1 ]]; then
          PART_CNT=$(( PART_CNT + 1 ))
        fi

        # Check if we pass extended partition
        [[ "${PART}" = "Extended" ]] && XTND_PART_PASS=1
      done
    ;;
    A)  echo "${PART_CNT}";  return 0 ;;
    *)  die "Invalid option ${PART_TYPE}." ;;
  esac

  echo "${PART_CNT}"
}

# Print the specified disk partition table.
# Input: DEV_NODE_ENTRY  device node to look partitions on.
# Return: None.
print_part_table() {

  [[ $# -ne 1 ]] && die "Arguments missing."

  DEV_NODE_ENTRY="$1"
  PART_TABLE=$("${FDISK}" -l "${DEV_NODE_ENTRY}" | grep "Device")
  PART_TABLE+=$("${FDISK}" -l "${DEV_NODE_ENTRY}" \
                | grep "${DEV_NODE_ENTRY}p*")

  test_print_trc "+++++++++++++++P A R T I T I O N    T A B L E++++++++++++++++"

  while read -r PART; do
    test_print_trc "+ ${PART} +"
  done <<< "$PART_TABLE"

  test_print_trc "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

  return 0
}

############################ Script Variables #################################
TOTAL_PRIMARY_PART_NUM=0
LOGICAL_NUM_PARTS=0
PRIMARY_NUM_PARTS=0
EXTEND_PART_NEEDED=0
DISK_SIZE=0
CLEAR_ONLY=0
P_PART_SIZE=0
L_PART_SIZE=0
DEV_NODE_ENTRY=""
FDISK_CREATE_OPTS_STR=""
FDISK_ERASE_OPTS_STR=""
PRESENT_PRIMARY_PARTS_NUM=0
PRESENT_LOGICAL_PARTS_NUM=0
RET=0

############################ CLI Params ########################################
while getopts :d:n:p:l:ceh arg; do
  case "${arg}" in
    c)  CLEAR_ONLY=1 ;;
    e)  EXTEND_PART_NEEDED=1 ;;
    d)  DEVICE_TYPE="$OPTARG" ;;
    l)  LOGICAL_NUM_PARTS="$OPTARG"; EXTEND_PART_NEEDED=1 ;;
    n)  DEV_NODE="$OPTARG" ;;
    p)  PRIMARY_NUM_PARTS="$OPTARG" ;;
    h)  usage ;;
    :)  test_print_err "$0: Must supply an argument to -$OPTARG."
        die
        ;;
   \?)  test_print_err "Invalid Option -$OPTARG ignored."
        usage ;;
  esac
done

############################ USER-DEFINED Params ##############################
case $ARCH in
esac
case $DRIVER in
esac
case $SOC in
esac
case $MACHINE in
esac

############################ DEFAULT Params ###################################
FDISK="fdisk"

########################## Do the work #########################################
# Check args
[[ -z "${DEV_NODE}" && -z "${DEVICE_TYPE}" ]] && die "Arguments misssing !"

[[ "${CLEAR_ONLY}" -eq 0 && "${PRIMARY_NUM_PARTS}" -lt 1 ]] \
  && die "Missing Partition number arguments !"

# Get dev_node if not provided
if [[ -z ${DEV_NODE} ]]; then
  DEV_NODE=$(get_blk_device_node.sh -d "${DEVICE_TYPE}") \
    || block_test "Error getting device node for ${DEVICE_TYPE}: ${DEV_NODE}"
fi

# Get dev_node entry
DEV_NODE_ENTRY=$(get_devnode_entry.sh "${DEV_NODE}" "${DEVICE_TYPE}") \
  || block_test "Getting dev_node entry for ${DEV_NODE}"

# Debug prints
test_print_trc "DEVICE_TYPE = ${DEVICE_TYPE}"
test_print_trc "DEV_NODE = ${DEV_NODE}"
test_print_trc "DEV_NODE_ENTRY = ${DEV_NODE_ENTRY}"
test_print_trc "CLEAR_ONLY = ${CLEAR_ONLY}"
test_print_trc "PRIMARY_NUM_PARTS = ${PRIMARY_NUM_PARTS}"
test_print_trc "LOGICAL_NUM_PARTS = ${LOGICAL_NUM_PARTS}"
test_print_trc "EXTEND_PART_NEEDED = ${EXTEND_PART_NEEDED}"

# Umount dev_node if mounted either by VOLD or other
test_print_trc "Umount ${DEV_NODE} or ${DEV_NODE_ENTRY} if it is mounted"
filed=$(get_mnt_point_field)

# Use "-w" to completely match the whole words for finding the mount point of
# the DEV_NODE_ENTRY.
# Eg: grep -w "mmcblk0p1" can only match lines with "mmcblk0p1" and lines with
# "mmcblk0p10" won't be matched.
mount | grep -w "${DEV_NODE_ENTRY}" \
  && CUR_MNT_POINT=$(mount | grep "${DEV_NODE_ENTRY}" | cut -d' ' -f"${filed}") \
  && do_cmd "umount ${CUR_MNT_POINT}"

mount | grep "/dev/block/vold" \
  && CUR_MNT_POINT=$(mount | grep "/dev/block/vold" | cut -d' ' -f"${filed}") \
  && do_cmd "umount ${CUR_MNT_POINT}"

sleep 2

# Get partitions number
TOTAL_PRIMARY_PART_NUM=$(( PRIMARY_NUM_PARTS ))
if [[ "${EXTEND_PART_NEEDED}" -eq 1 ]]; then
  TOTAL_PRIMARY_PART_NUM=$(( TOTAL_PRIMARY_PART_NUM + 1 ))
fi

# Check if primary partitions number is ok
[[ "${TOTAL_PRIMARY_PART_NUM}" -gt 4 ]] && die "Maximum primary partitions is 4!"

# Calculate partitions size
DISK_SIZE=$(fdisk -l | grep -w "${DEV_NODE_ENTRY}" | awk '{print $3}' | cut -d'.' -f1)
RET=$?
[[ "${RET}" -ne 0 ]] && die "Could not obtain ${DEV_NODE_ENTRY} size=${DISK_SIZE}"

# Skip calculation if CLEAR_ONLY flag is set
[[ "${CLEAR_ONLY}" -ne 1 && "${PRIMARY_NUM_PARTS}" -gt 0 ]] \
  && P_PART_SIZE=$(( DISK_SIZE / TOTAL_PRIMARY_PART_NUM ))
[[ "${CLEAR_ONLY}" -ne 1 && "${LOGICAL_NUM_PARTS}" -gt 0 ]] \
  && L_PART_SIZE=$(( P_PART_SIZE / LOGICAL_NUM_PARTS ))

# Calculte partitions offsets
calc_parts_offsets "${TOTAL_PRIMARY_PART_NUM}" "${P_PART_SIZE}" \
                   "${LOGICAL_NUM_PARTS}" "${L_PART_SIZE}"
RET=$?
[[ "${RET}" -ne 0 ]] && die "Could not get partitions offsets."

# Build fdisk non-interactive strings
PRESENT_PRIMARY_PARTS_NUM=$(get_partition_number "${DEV_NODE_ENTRY}" "P")
PRESENT_LOGICAL_PARTS_NUM=$(get_partition_number "${DEV_NODE_ENTRY}" "L")
FDISK_CREATE_OPTS_STR=$(build_fdisk_str "create" "${TOTAL_PRIMARY_PART_NUM}" \
                        "${LOGICAL_NUM_PARTS}" "$EXTEND_PART_NEEDED" "${P_PART_SIZE}")
FDISK_ERASE_OPTS_STR=$(build_fdisk_str "erase" "$PRESENT_PRIMARY_PARTS_NUM" \
                        "$PRESENT_LOGICAL_PARTS_NUM" "$EXTEND_PART_NEEDED")

# Check if Device contains OS
if [[ "${PRESENT_PRIMARY_PARTS_NUM}" -ne 0 ]]; then

  patt="/dev/sd*"
  # Get partitions
  if [[ ${DEV_NODE_ENTRY} =~ $patt ]]; then
    PRESENT_PARTS=($(fdisk -l "${DEV_NODE_ENTRY}" | grep "${DEV_NODE_ENTRY}[0-9]" | awk '{print $1}'))
  else
    PRESENT_PARTS=($(fdisk -l "${DEV_NODE_ENTRY}" | grep "${DEV_NODE_ENTRY}p" | awk '{print $1}'))
  fi

  test_print_trc "Check if ${DEV_NODE_ENTRY} contains OS"

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
fi

# Debug Prints
test_print_trc "TOTAL_PRIMARY_PART_NUM = ${TOTAL_PRIMARY_PART_NUM}"
test_print_trc "PRESENT_PRIMARY_PARTS_NUM = ${PRESENT_PRIMARY_PARTS_NUM}"
test_print_trc "PRESENT_LOGICAL_PARTS_NUM = ${PRESENT_LOGICAL_PARTS_NUM}"
test_print_trc "FDISK_CREATE_OPTS_STR = ${FDISK_CREATE_OPTS_STR}"
test_print_trc "FDISK_ERASE_OPTS_STR = ${FDISK_ERASE_OPTS_STR}"
test_print_trc "P_PART_SIZE = ${P_PART_SIZE}"
test_print_trc "L_PART_SIZE = ${L_PART_SIZE}"

# Clear disk
test_print_trc "Clear partition table on ${DEV_NODE_ENTRY}"
# secure fdisk success operation in Clear Linux simics environment
sleep 10
echo -e "${FDISK_ERASE_OPTS_STR}" \
  | "${FDISK}" "${DEV_NODE_ENTRY}" > /dev/null \
  || die "Could not clear partition to ${DEV_NODE_ENTRY}"
sleep 3
print_part_table "${DEV_NODE_ENTRY}"

# Create partitions
if [[ "${CLEAR_ONLY}" -eq 0 ]]; then
  test_print_trc "Create partition table on ${DEV_NODE_ENTRY}"
  # secure fdisk success operation in Clear Linux simics environment
  sleep 10
  echo -e "${FDISK_CREATE_OPTS_STR}" \
    | "${FDISK}" "${DEV_NODE_ENTRY}" > /dev/null \
    || die "Could not create partition table to ${DEV_NODE_ENTRY}"
  sleep 3

  print_part_table "${DEV_NODE_ENTRY}"
  test_print_trc "Format partition on ${DEV_NODE} to update filesystem accounting info."
  mkfs.ext2 -F ${DEV_NODE} > /dev/null || die "Could not format and update filesystem accounting info on partition ${DEV_NODE}"
else
  test_print_trc "Skipping partition table creation"
fi

exit 0
