#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2018, Intel - http://www.intel.com
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

############################ CONTRIBUTORS #####################################

# @Author   Hongyu Ning <hongyu.ning@intel.com>
#
# Oct, 30, 2018. Hongyu Ning <hongyu.ning@intel.com>
#     - 1st version

############################ DESCRIPTION ######################################

# @desc     Check the new device id of device spi and spi_nor on pci bus
#           Check the mtd bios device info
# @returns  0 if the execution was finished succesfully, else 1
# @history 2018-10-30: 1st version
# @history  2019-01-16: Add ${SPI_DEV_ID} valid check for more platform test support

############################# FUNCTIONS #######################################

usage() {
cat <<-EOF
  usage: ./${0##*/} [-d DEVICE] [-p check pci device id] or [-m check mtd device info] [-h Help]
  -d DEVICE   Device to test
  -p PCI      Check new device id on pci bus
  -m MTD      Check mtd device name and type
  -h Help     Print this usage
EOF
}

check_pci_device_id() {
  device=$1

  if [[ ${device} == "spi" ]]; then
    if [[ -n "${SPI_DEV_ID}" ]]; then
      dev_node=${SPI_PCI_NODE_SHORT}
      dev_id_check=${SPI_DEV_ID}
    else
      die "No SPI_DEV_ID info for platform ${PLATFORM}, " \
        "please check and add it to parameter files ${PLATFORM}"
    fi
  elif [[ ${device} == "spi_nor" ]]; then
    if [[ -n "${SPI_NOR_DEV_ID}" ]]; then
      dev_node=${SPI_NOR_PCI_NODE_SHORT}
      dev_id_check=${SPI_NOR_DEV_ID}
    else
      die "No SPI_NOR_DEV_ID info for platform ${PLATFORM}, " \
        "please check and add it to parameter files ${PLATFORM}"
    fi
  else
    test_print_trc "Device to test not support, please check"
    exit 1
  fi

  dev_id_tmp=$(lspci -nn | grep -w ${dev_node} | grep -w ${dev_id_check})
  dev_id=${dev_id_tmp}
  dev_id_new=$(lspci -nn | grep -w ${dev_node})

  if [[ -n ${dev_id} ]]; then
    test_print_trc "New device id check for device: ${device} Pass!"
    test_print_trc "Device id is: ${dev_id}"
    exit 0
  else
    test_print_err "New device id for device: ${device} not match expectation, check Failed"
    test_print_wrg "Device id is: ${dev_id_new}"
    exit 1
  fi
}

check_mtd_device() {
  do_cmd "cd ${DRV_SYS_PATH}"
  mtd_cnt=`ls | wc -l`
  for i in *; do
    let "mtd_cnt = mtd_cnt -1"
    if [ -r "${i}/name" ] || [ -r "${i}/type" ]; then
      if [ -r "${i}/name" ]; then
        mtd_name=$(cat "${i}/name")
        if [ ${mtd_name} == "BIOS" ]; then
          test_print_trc "mtd device name is BIOS, check Pass!"
          exit 0
        fi
      fi
      if [ -r "${i}/type" ]; then
        mtd_type=$(cat "${i}/type")
        if [ ${mtd_type} == "nor" ]; then
          test_print_trc "mtd device type is nor, check Pass!"
          exit 0
        fi
      fi
    fi
  done
  if [ $mtd_cnt -eq 0 ]; then
    test_print_trc "Failed to find matched mtd device, check Failed!"
    exit 1
  fi
}

################################ DO THE WORK ##################################

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.

source "common.sh"

while getopts :d:pmh arg; do
  case $arg in
    d)  DEVICE=$OPTARG ;;
    p)  PCI_CHECK=1 ;;
    m)  MTD_CHECK=1 ;;
    h)  usage && exit 0;;
    :)  test_print_err "Must supply an argument to -$OPTARG."
        usage && exit 1
        ;;
    \?) test_print_err "Invalid Option -$OPTARG ignored."
        usage && exit 1
        ;;
  esac
done

: ${DEVICE:='spi'}
: ${PCI_CHECK:='0'}
: ${MTD_CHECK:='0'}

source "${DEVICE}_common.sh"

if [[ "${PCI_CHECK}" -eq 1 ]]; then
  check_pci_device_id "${DEVICE}"
elif [[ "${MTD_CHECK}" -eq 1 ]] && [[ "${DEVICE}" == "spi_nor" ]]; then
  check_mtd_device
else
  test_print_err "Please specify pci dev id to check or mtd dev info to check"
  test_print_trc "Note mtd dev info check is only for device spi_nor"
  usage && exit 1
fi
