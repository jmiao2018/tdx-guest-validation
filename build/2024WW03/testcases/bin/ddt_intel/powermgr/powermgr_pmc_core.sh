#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only

# Description:  Test script for Intel PMC Core debug driver
# which is designed to support CPU Package C-states and S0ix debugging
# PMC: Power Management Controller

# Authors:      wendy.wang@intel.com
# History:      May 24 2023 - Created - Wendy Wang

source "common.sh"
source "dmesg_functions.sh"
source "powermgr_common.sh"

: "${CASE_NAME:=""}"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

load_unload_module() {
  # $1 is the driver module name
  local module_name=$1
  is_kmodule_builtin "$module_name" && skip_test
  dmesg -C

  load_unload_module.sh -c -d "$module_name" &&
    do_cmd "load_unload_module.sh -u -d $module_name"

  do_cmd "load_unload_module.sh -l -d $module_name -p dyndbg"
  do_cmd "load_unload_module.sh -u -d $module_name"
  do_cmd "load_unload_module.sh -l -d $module_name -p dyndbg"
}

pmc_pci_device() {
  local pmc_device="INT33A1:00"
  test_print_trc "Check pmc pci device:"
  do_cmd "cat /sys/bus/acpi/devices/$pmc_device/status"

  if [[ -d /sys/bus/platform/devices/"$pmc_device" ]]; then
    test_print_trc "pmc pci device is available."
  else
    die "pmc pci device is not available."
  fi
}

pmc_core_attr() {
  local cpu_model
  local attr="die_c6_us_show lpm_latch_mode ltr_ignore ltr_show package_cstate_show
pch_ip_power_gating_status slp_s0_residency_usec substate_live_status_registers
substate_residencies substate_status_registers"

  cpu_model=$(lscpu | grep Model: | awk '{print $2}')

  test_print_trc "Check intel_pmc_core driver debugfs attributes:"
  for i in $attr; do
    if [[ -e "$PMC_CORE_SYSFS_PATH"/"$i" ]]; then
      test_print_trc "$i file exist"
    elif [[ "$i" = die_c6_us_show ]] && [[ "$cpu_model" -eq 189 ]]; then
      test_print_trc "LNL-M does not support Die C6, it is expected"
    else
      die "$i does not exist!"
    fi
  done
}

dmesg_check() {
  local dmesg_log

  dmesg_log=$(extract_case_dmesg)

  if echo "$dmesg_log" | grep -iE "fail|Call Trace|error|BUG"; then
    die "Kernel dmesg shows failure: $dmesg_log"
  else
    test_print_trc "Kernel dmesg shows Okay."
  fi
}

pmc_core_test() {
  case $TEST_SCENARIO in
  load_unload_pmc_core)
    load_unload_module intel_pmc_core
    ;;
  check_pmc_device)
    pmc_pci_device
    ;;
  check_pmc_core_attr)
    pmc_core_attr
    ;;
  esac
  dmesg_check
  return 0
}

while getopts :t:H arg; do
  case $arg in
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

pmc_core_test
