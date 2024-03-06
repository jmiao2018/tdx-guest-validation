#!/bin/bash
#
# Copyright 2017 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate USB component
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Ammy Yi <ammy.yi@intel.com>
#
# History:
#             Aug. 2, 2017 - (Ammy Yi)Creation


# @desc This script verify usb pci id test
# @returns Fail the test if return code is non-zero (value set not found)

source "common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-d PCI_ID] [-t PCI_ID] [-H]
  -d  PCI ID
  -t  TEST CASE ID
  -H  show this
__EOF
}

pci_id_check() {
  [[ $PCI_ID == "0" ]] && skip_test
  lspci -nn | grep $PCI_ID || die "get usb new device is fail!"
  return 0
}

dwc3_module_check() {
  MODULE_NAME="dwc3-pci"
  MODULE_NAME_LOADED="dwc3_pci"
  load_unload_module.sh -c -d $MODULE_NAME_LOADED || \
    teardown_handler="pci_check_teardown"
  load_unload_module.sh -c -d $MODULE_NAME_LOADED || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  return 0
}

pci_check_teardown() {
  rmmod dwc3-pci
}

main() {
  case $TEST_SCENARIO in
    id_check)
      pci_id_check
      ;;
    module_check)
      dwc3_module_check
      ;;
    *)
      usage
      die "Invalid Test ID!"
      ;;
  esac
}


while getopts :t:d:H arg; do
  case $arg in
    d)
      PCI_ID=$OPTARG
      ;;
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    H)
      usage && exit 0
      ;;
    \?)
      usage
      die "Invalid Option -$OPTARG"
      ;;
    :)
      usage
      die "Option -$OPTARG requires an argument."
      ;;
  esac
done

main

# Call teardown for passing case
exec_teardown
