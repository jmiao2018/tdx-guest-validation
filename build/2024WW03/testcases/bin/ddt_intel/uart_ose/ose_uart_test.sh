#! /bin/bash
#
# Copyright (C) 2015-2019 Intel - http://www.intel.com/
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
# @desc Script to run ose uart test

source "common.sh"
source "ose_uart_common.sh"
############################# Functions #######################################
usage()
{
  cat <<-EOF >&2
    usage: ./${0##*/}  [-l TEST_LOOP] [-t TESTCASE_ID]
    -l TEST_LOOP  test loop
    -t TESTCASE_ID test case id, which case to be run
    -h Help   print this usage
EOF
}

ose_uart_pci_device_id_check() {
  dev_node=$1
  dev_id_check=$2

  if [[ -n "${dev_id_check}" ]]; then
      test_print_trc "Start OSE UART DEV_ID check:"
  else
      die "No OSE_UART_DEV_ID info for platform ${PLATFORM}, \
        please check and add it to parameter files ${PLATFORM}"
  fi

  dev_id_tmp=$(lspci -nn | grep -w ${dev_node} | grep -oP "(?<=\[8086:)[^ ]+")
  dev_id=${dev_id_tmp%?}

  if [[ ${dev_id} == ${dev_id_check} ]]; then
    test_print_trc "New device id check for device: ose_uart Pass!"
    test_print_trc "Device id is: ${dev_id}"
    exit 0
  else
    test_print_err "New device id for device: ose_uart not match expectation, check Failed"
    test_print_trc "Device id is: ${dev_id}"
    die "test failed"
  fi
}

#ose uart pci driver status check function
ose_uart_pci_driver_check() {
  uart_pci_driver_path=$1
  uart_pci_node_name=$2
  if [[ -n "${uart_pci_driver_path}" ]] && [[ -n "${uart_pci_node_name}" ]]; then
    if [[ -d "${uart_pci_driver_path}/${uart_pci_node_name}" ]]; then
      test_print_trc \
        "ose uart pci driver has been registered on node ${uart_pci_node_name}, check succeeded!"
    else
      test_print_trc \
        "ose uart pci driver has not been registered on node ${uart_pci_node_name}, check failed!"
      return 1
    fi
  elif [[ -z "${uart_pci_driver_path}" ]]; then
    die "No uart_pci_driver_path defined, can't do test"
  elif [[ -z "${uart_pci_node_name}" ]]; then
    die "No uart_pci_node_name defined, can't do test"
  else
    die "Wrong logic in uart_pci_driver_check function, please check"
  fi
}
############################### CLI Params ###################################
while getopts :l:t:h arg; do
  case $arg in
    l)  TEST_LOOP="$OPTARG";;
    t)  CASE_ID="$OPTARG";;
    h)  usage && exit 0;;
    :)  test_print_err "Must supply an argument to -$OPTARG."
        usage && die "please refer to test usage above"
        ;;
    \?) test_print_err "Invalid Option -$OPTARG ignored."
        usage && die "please refer to test usage above"
        ;;
  esac
done

########################### DYNAMICALLY-DEFINED Params ########################
: ${TEST_LOOP:='1'}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
test_print_trc "STARTING OSE UART Test... "
test_print_trc "TEST_LOOP:${TEST_LOOP}"

# test loop
i=0
while [ $i -lt $TEST_LOOP ]; do
  test_print_trc "===LOOP: $i==="
  case $CASE_ID in
    1)
      ose_uart_pci_device_id_check "${OSE_UART_PCI_NODE_SHORT_0}" "${OSE_UART_DEV_ID_0}"
      ose_uart_pci_device_id_check "${OSE_UART_PCI_NODE_SHORT_1}" "${OSE_UART_DEV_ID_1}"
      ose_uart_pci_device_id_check "${OSE_UART_PCI_NODE_SHORT_2}" "${OSE_UART_DEV_ID_2}"
      ose_uart_pci_device_id_check "${OSE_UART_PCI_NODE_SHORT_3}" "${OSE_UART_DEV_ID_3}"
      ose_uart_pci_device_id_check "${OSE_UART_PCI_NODE_SHORT_4}" "${OSE_UART_DEV_ID_4}"
      ose_uart_pci_device_id_check "${OSE_UART_PCI_NODE_SHORT_5}" "${OSE_UART_DEV_ID_5}"
    ;;
    2)
      ose_uart_pci_driver_check "${OSE_UART_PCI_DRV_PATH}" "${OSE_UART_PCI_NODE_0}"
      ose_uart_pci_driver_check "${OSE_UART_PCI_DRV_PATH}" "${OSE_UART_PCI_NODE_1}"
      ose_uart_pci_driver_check "${OSE_UART_PCI_DRV_PATH}" "${OSE_UART_PCI_NODE_2}"
      ose_uart_pci_driver_check "${OSE_UART_PCI_DRV_PATH}" "${OSE_UART_PCI_NODE_3}"
      ose_uart_pci_driver_check "${OSE_UART_PCI_DRV_PATH}" "${OSE_UART_PCI_NODE_4}"
      ose_uart_pci_driver_check "${OSE_UART_PCI_DRV_PATH}" "${OSE_UART_PCI_NODE_5}"
    ;;
  esac
  i=$((i+1))
done  # while loop
