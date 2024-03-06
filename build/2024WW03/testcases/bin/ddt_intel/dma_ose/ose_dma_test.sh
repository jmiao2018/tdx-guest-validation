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
# @desc Script to run ose dma test

source "common.sh"
source "ose_dma_common.sh"
############################# Functions #######################################
usage()
{
  cat <<-EOF >&2
    usage: ./${0##*/}  [-l TEST_LOOP] [-t TESTCASE_ID]
    -l TEST_LOOP  test loop
    -t TESTCASE_ID test case id, which case to be run
    -h Help   print this usage
EOF
  exit 0
}

ose_dma_pci_device_id_check() {
  dev_id_check=$1

  if [[ -n "${dev_id_check}" ]]; then
      test_print_trc "Start OSE DMA DEV_ID check:"
  else
      die "No OSE_DMA_DEV_ID info for platform ${PLATFORM}, \
        please check and add it to parameter files ${PLATFORM}"
  fi

  acpidump | grep -i "$dev_id_check"

  if [ $? -eq 0 ]; then
    test_print_trc "New device id check for device: ose_dma Pass!"
    test_print_trc "Device id is: ${dev_id_check}"
    exit 0
  else
    test_print_err "New device id for device: ose_dma not match expectation, check Failed"
    test_print_trc "Device id is: ${dev_id_check}"
    die "test failed"
  fi
}

#ose dma pci driver status check function
ose_dma_pci_driver_check() {
  dma_pci_driver_path=$1
  dma_pci_node_name=$2
  if [[ -n "${dma_pci_driver_path}" ]] && [[ -n "${dma_pci_node_name}" ]]; then
    if [[ -d "${dma_pci_driver_path}/${dma_pci_node_name}" ]]; then
      test_print_trc \
        "ose dma pci driver has been registered on node ${dma_pci_node_name}, check succeeded!"
    else
      test_print_trc \
        "ose dma pci driver has not been registered on node ${dma_pci_node_name}, check failed!"
      return 1
    fi
  elif [[ -z "${dma_pci_driver_path}" ]]; then
    die "No dma_pci_driver_path defined, can't do test"
  elif [[ -z "${dma_pci_node_name}" ]]; then
    die "No dma_pci_node_name defined, can't do test"
  else
    die "Wrong logic in dma_pci_driver_check function, please check"
  fi
}
############################### CLI Params ###################################
while getopts :l:t:h arg; do
  case $arg in
    l)  TEST_LOOP="$OPTARG";;
    t)  CASE_ID="$OPTARG";;
    h)  usage;;
    :)  test_print_err "$0: Must supply an argument to -$OPTARG."
        exit 1
    ;;
    \?) test_print_err "Invalid Option -$OPTARG ignored."
        usage
        exit 1
    ;;
  esac
done

########################### DYNAMICALLY-DEFINED Params ########################
: ${TEST_LOOP:='1'}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
test_print_trc "STARTING OSE DMA Test... "
test_print_trc "TEST_LOOP:${TEST_LOOP}"

# test loop
i=0
while [ $i -lt $TEST_LOOP ]; do
  test_print_trc "===LOOP: $i==="
  case $CASE_ID in
    1)
      ose_dma_pci_device_id_check "${OSE_DMA_DEV_ID_0}"
    ;;
    2)
      ose_dma_pci_device_id_check "${OSE_DMA_DEV_ID_1}"
    ;;
    3)
      ose_dma_pci_device_id_check "${OSE_DMA_DEV_ID_2}"
    ;;
    4)
      ose_dma_pci_driver_check "${OSE_DMA_PCI_DRV_PATH}" "${OSE_DMA_PCI_NODE_0}"
    ;;
    5)
      ose_dma_pci_driver_check "${OSE_DMA_PCI_DRV_PATH}" "${OSE_DMA_PCI_NODE_1}"
    ;;
    6)
      ose_dma_pci_driver_check "${OSE_DMA_PCI_DRV_PATH}" "${OSE_DMA_PCI_NODE_2}"
    ;;
  esac
  i=$((i+1))
done  # while loop
