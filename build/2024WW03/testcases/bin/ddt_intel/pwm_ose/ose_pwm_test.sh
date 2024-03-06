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
# @desc Script to run ose pwm test

source "common.sh"
source "ose_pwm_common.sh"
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

ose_pwm_pci_device_id_check() {
  dev_node=$1
  dev_id_check=$2

  if [[ -n "${dev_id_check}" ]]; then
      test_print_trc "Start OSE PWM DEV_ID check:"
  else
      die "No OSE_PWM_DEV_ID info for platform ${PLATFORM}, \
        please check and add it to parameter files ${PLATFORM}"
  fi

  dev_id_tmp=$(lspci -nn | grep -w ${dev_node} | grep -oP "(?<=\[8086:)[^ ]+")
  dev_id=${dev_id_tmp%?}

  if [[ ${dev_id} == ${dev_id_check} ]]; then
    test_print_trc "New device id check for device: ose_dma Pass!"
    test_print_trc "Device id is: ${dev_id}"
    exit 0
  else
    test_print_err "New device id for device: ose_dma not match expectation, check Failed"
    test_print_trc "Device id is: ${dev_id}"
    die "test failed"
  fi
}

#ose pwm pci driver status check function
ose_pwm_pci_driver_check() {
  pwm_pci_driver_path=$1
  pwm_pci_node_name=$2
  if [[ -n "${pwm_pci_driver_path}" ]] && [[ -n "${pwm_pci_node_name}" ]]; then
    if [[ -d "${pwm_pci_driver_path}/${pwm_pci_node_name}" ]]; then
      test_print_trc \
        "ose pwm pci driver has been registered on node ${pwm_pci_node_name}, check succeeded!"
    else
      test_print_trc \
        "ose pwm pci driver has not been registered on node ${pwm_pci_node_name}, check failed!"
      return 1
    fi
  elif [[ -z "${pwm_pci_driver_path}" ]]; then
    die "No pwm_pci_driver_path defined, can't do test"
  elif [[ -z "${pwm_pci_node_name}" ]]; then
    die "No pwm_pci_node_name defined, can't do test"
  else
    die "Wrong logic in pwm_pci_driver_check function, please check"
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
test_print_trc "STARTING OSE PWM Test... "
test_print_trc "TEST_LOOP:${TEST_LOOP}"

# test loop
i=0
while [ $i -lt $TEST_LOOP ]; do
  test_print_trc "===LOOP: $i==="
  case $CASE_ID in
    1)
      ose_pwm_pci_device_id_check "${OSE_PWM_PCI_NODE_SHORT}" "${OSE_PWM_DEV_ID}"
    ;;
    2)
      ose_pwm_pci_driver_check "${OSE_PWM_PCI_DRV_PATH}" "${OSE_PWM_PCI_NODE}"
    ;;
  esac
  i=$((i+1))
done  # while loop
