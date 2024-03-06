#!/bin/bash

########################################################################
#
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
#
########################################################################
#
# File: blk_native_command_queueing.sh
#
# Description: This script is used to check Native Command Queueing
#              support in block devices like emmc, sata.
#
# Author(s): Juan Carlos Alonso <juan.carlos.alonso@@intel.com>
#
# Date: 2018-03-09: - Initial Version
#
# History: 2018-03-09: Initial draft
#          2018-08-10: -Hongyu Ning: Fix bug of $sata_dev empty in Simics Environment
#          2018-10-12: -Hongyu Ning: Remove "CD-ROM" device from $devices

source "common.sh"
source "blk_device_common.sh"

while getopts :d:n:h arg; do
  case "${arg}" in
    d)  DEV_TYPE="${OPTARG}" ;;
    n)  DEV_NODE="${OPTARG}" ;;
    h)  usage ;;
    :)  test_print_err "$0: Must supply an argument to -$OPTARG."
        die
        ;;
    \?) test_print_err "Invalid Option -$OPTARG ignored."
        usage
        ;;
  esac
done

if [[ -z "${DEV_TYPE}" ]]; then
  test_print_trc "Please input device type"
  exit 1
fi

DEV_NODE=$(get_blk_device_node.sh -d "${DEV_TYPE}")

test_print_trc "DEVICE TYPE:${DEV_TYPE}"
test_print_trc "DEVICE NODE:${DEV_NODE}"
test_print_trc "Check NCQ support for ${DEV_TYPE}"

if [[ "${DEV_TYPE}" == "emmc" ]]; then
  devices=($(ls "${EMMC_SD_DEV_PATH}" | cut -d':' -f1))

  for device in "${devices[@]}"; do
    dev=$(cat "${EMMC_SD_DEV_PATH}"/"${device}"*/type)
    if [[ "$dev" == "MMC" ]]; then
      test_print_trc "EMMC DEV: ${device}"
      emmc_dev="${device}"
    fi
  done

  dmesg | grep "${emmc_dev}" | grep -wq "Command Queue Engine enabled"
  if [[ $? -ne 0 ]]; then
    die "Native Command Queueing is not enable or not supported for ${emmc_dev}"
  else
    test_print_trc "Native Command Queueing is supported"
    dmesg | grep "${emmc_dev}" | grep -w "Command Queue Engine enabled"
  fi

elif [[ "${DEV_TYPE}" == "sata" ]]; then

  blk_dev_dir=$(get_blk_dev_dir)
  sata_dev_dir=$(echo "${blk_dev_dir}" | cut -d',' -f1)

  devices=$(ls "${sata_dev_dir}"/* \
   | grep -v "DRW" \
   | grep -v "DVD" \
   | grep -v "CD-ROM" \
   | grep -i "ata"-.* \
   | grep -v "part[0-9]")

  #fix bug of $sata_dev empty in Simics Environment
  for DEVICE in ${devices}
  do
    sata_dev=$(readlink -e "${DEVICE}")
    break
  done

  hdparm -iI "${sata_dev}" | grep -wq "Native Command Queueing"
  if [[ $? -ne 0 ]]; then
    die "Native Command Queueing is not enable or not supported for ${sata_dev}"
  else
    test_print_trc "Native Command Queueing is supported"
    hdparm -iI "${sata_dev}" | grep -w "Native Command Queueing"
  fi
fi
