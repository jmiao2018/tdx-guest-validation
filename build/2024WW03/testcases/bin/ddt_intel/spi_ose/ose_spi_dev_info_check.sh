#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2019, Intel - http://www.intel.com
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
# @history 2019-04-24: Revision to support EHL OSE OSE_SPI_XS_BAT_DEV_ID_CHECK test

############################# FUNCTIONS #######################################

usage() {
cat <<-EOF
  usage: ./${0##*/} [-d DEVICE] [-p check pci device id] or [-m check mtd device info] [-h Help]
  -d DEVICE   Device to test
  -p PCI      Check new device id on pci bus
  -h Help     Print this usage
EOF
}

check_pci_device_id() {
  device=$1
  dev_node=$2
  dev_id_check=$3

  if [[ ${device} == "ose_spi" ]]; then
    if [[ -n "${dev_id_check}" ]]; then
      test_print_trc "Start OSE SPI DEV_ID check:"
    else
      die "No OSE_SPI_DEV_ID info for platform ${PLATFORM}, \
        please check and add it to parameter files ${PLATFORM}"
    fi
  else
    test_print_err "Device to test is not supportted in EHL OSE type, please check"
    die "test failed"
  fi

  dev_id_tmp=$(lspci -nn | grep -w ${dev_node} | grep -oP "(?<=\[8086:)[^ ]+")
  dev_id=${dev_id_tmp%?}

  if [[ ${dev_id} == ${dev_id_check} ]]; then
    test_print_trc "New device id check for device: ${device} Pass!"
    test_print_trc "Device id is: ${dev_id}"
    exit 0
  else
    test_print_err "New device id for device: ${device} not match expectation, check Failed"
    test_print_trc "Device id is: ${dev_id}"
    die "test failed"
  fi
}

################################ DO THE WORK ##################################

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.

source "common.sh"

while getopts :d:ph arg; do
  case $arg in
    d)  DEVICE=$OPTARG ;;
    p)  PCI_CHECK=1 ;;
    h)  usage && exit 0;;
    :)  test_print_err "Must supply an argument to -$OPTARG."
        usage && die "please refer to test usage above"
        ;;
    \?) test_print_err "Invalid Option -$OPTARG ignored."
        usage && die "please refer to test usage above"
        ;;
  esac
done

: ${DEVICE:='ose_spi'}
: ${PCI_CHECK:='0'}

if [[ "${PCI_CHECK}" -eq 1 ]]; then
  test_print_trc "Start OSE SPI DEV_ID check on controller_0"
  check_pci_device_id "${DEVICE}" "${OSE_SPI_PCI_NODE_SHORT_0}" "${OSE_SPI_DEV_ID_0}"
  test_print_trc "Start OSE SPI DEV_ID check on controller_1"
  check_pci_device_id "${DEVICE}" "${OSE_SPI_PCI_NODE_SHORT_1}" "${OSE_SPI_DEV_ID_1}"
  test_print_trc "Start OSE SPI DEV_ID check on controller_2"
  check_pci_device_id "${DEVICE}" "${OSE_SPI_PCI_NODE_SHORT_2}" "${OSE_SPI_DEV_ID_2}"
  test_print_trc "Start OSE SPI DEV_ID check on controller_3"
  check_pci_device_id "${DEVICE}" "${OSE_SPI_PCI_NODE_SHORT_3}" "${OSE_SPI_DEV_ID_3}"
else
  test_print_err "Please specify pci dev id to check"
  usage && die "please refer to test usage above"
fi
