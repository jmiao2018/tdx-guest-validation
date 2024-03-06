#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only

# Description:  Test script for thermal DPTF sysfs check
# DPTF: Intel(R) Dynamic Platform and Thermal Framework (DPTF)
# Which is supported on Client Platforms

# Authors:      wendy.wang@intel.com
# History:      July 01 2022 - Created - Wendy Wang

source "common.sh"

DPTF_ACPI_DRIVER_PATH="/sys/bus/platform/devices"
DPTF_PROCESSOR_THERMAL="/sys/bus/pci/devices/0000:00:04.0"
DPTF_PROCESSOR_THERMAL_WORKLOAD="/sys/bus/pci/devices/0000:00:04.0/workload_request"
DPTF_PROCESSOR_THERMAL_WORKLOAD_HINT="/sys/bus/pci/devices/0000:00:04.0/workload_hint"
WORKLOAD_TYPE="idle semi_active bursty sustained battery_life"

: "${CASE_NAME:=""}"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

sysfs_verify() {
  [ $# -ne 2 ] && die "You must supply 2 parameters, ${0##*/} <TYPE> <PATH>"
  local TYPE="$1"
  local path="$2"
  #if TYPE is not d nor f, set it as e
  if [[ "$TYPE" != "d" ]] && [[ "$TYPE" != "f" ]]; then
    TYPE="e"
  fi
  test_print_trc "$path does exist"
  return 0
}

# Each client generation supports different DPTF thermal PCI Device
# So use CPU model ID to distinguish
CPU_MODEL=$(lscpu | grep Model: | awk '{print $2}')
# On MTL/ARL platform, the dptf thermal PCI device is: "INTC1042:00"
if [[ $CPU_MODEL -eq 170 ]] || [[ $CPU_MODEL -eq 172 ]] ||
  [[ $CPU_MODEL -eq 198 ]]; then
  DPTF_DEVICE="INTC1042:00"
# On RPL platform, the dptf thermal PCI device is: "INTC10A0:00"
elif [[ $CPU_MODEL -eq 186 ]] || [[ $CPU_MODEL -eq 183 ]]; then
  DPTF_DEVICE="INTC10A0:00"
# On ADL platform, the dptf thermal PCI device is: "INTC1041:00"
elif [[ $CPU_MODEL -eq 190 ]] || [[ $CPU_MODEL -eq 151 ]]; then
  DPTF_DEVICE="INTC1041:00"
elif [[ $CPU_MODEL -eq 189 ]]; then
  DPTF_DEVICE="INTC1068:00"
else
  block_test "Unknown CPU model, need to update test case."
fi

write_uuid() {
  local passive_uuid="42A441D6-AE6A-462b-A84B-4A8CE79027D3"
  local active_uuid="3A95C389-E4B8-4629-A526-C52C88626BAE"
  local critical_uuid="97C68AE7-15FA-499c-B8C9-5DA81D606E0A"
  local uuid_list="$passive_uuid $active_uuid $critical_uuid"

  if [[ -d "$DPTF_ACPI_DRIVER_PATH"/"$DPTF_DEVICE" ]]; then
    for j in $uuid_list; do
      do_cmd "echo $j > $DPTF_ACPI_DRIVER_PATH/$DPTF_DEVICE/uuids/current_uuid"
      test_print_trc "Writing $j string successfully to $DPTF_DEVICE successfully."
    done
  else
    block_test "There is no INT3400 thermal PCI device available."
  fi
}

read_odvp() {
  test_print_trc "Reading odvp:firmware thermal status variable values"
  if [[ -d "$DPTF_ACPI_DRIVER_PATH"/"$DPTF_DEVICE" ]]; then
    if ! lines=$(grep . "$DPTF_ACPI_DRIVER_PATH"/"$DPTF_DEVICE"/odvp* 2>&1); then
      die "odvp does not exist for $DPTF_ACPI_DRIVER_PATH/$DPTF_DEVICE"
    else
      for line in $lines; do
        test_print_trc "$line"
      done
    fi
  else
    block_test "There is no INT3400 thermal PCI device available."
  fi
}

read_processor_thermal() {
  test_print_trc "Reading DPTF Processor thermal power limits values:"

  if [[ -d "$DPTF_PROCESSOR_THERMAL" ]]; then
    if ! lines=$(grep . "$DPTF_PROCESSOR_THERMAL"/power_limits/* 2>&1); then
      die "power limits value does not exit for $DPTF_PROCESSOR_THERMAL"
    else
      for line in $lines; do
        test_print_trc "$line"
      done
    fi
  else
    die "There is no $DPTF_PROCESSOR_THERMAL node"
  fi
}

# Below function does not support on v6.3 and futhur kernel driver
processor_thermal_workload_type() {
  local workload_type

  test_print_trc "Reading Processor thermal workload available type:"
  for workload_type in $WORKLOAD_TYPE; do
    sysfs_verify f "$DPTF_PROCESSOR_THERMAL_WORKLOAD"/workload_available_types ||
      die "$workload_type does not exist!"
  done

  if ! lines=$(cat "$DPTF_PROCESSOR_THERMAL_WORKLOAD"/workload_available_types); then
    die "Processor thermal workload available type does not exist!"
  else
    for line in $lines; do
      test_print_trc "$line"
    done
  fi
}

# Below function does not support on v6.3 and futhur kernel driver
write_workload() {
  local workload="idle semi_active bursty sustained battery_life"

  for i in $workload; do
    do_cmd "echo $i > $DPTF_PROCESSOR_THERMAL_WORKLOAD/workload_type"
    test_print_trc "Writing workload type $i to process thermal successfully"
    do_cmd "echo none > $DPTF_PROCESSOR_THERMAL_WORKLOAD/workload_type"
    test_print_trc "Recover to default workload type:none"
  done
}

# DTT means: Dynamic Tuning Technology
dtt_device_check() {
  local dtt=''

  dtt=$(lspci -vvv | grep "proc_thermal_pci" 2>&1)
  if [[ -n "$dtt" ]]; then
    test_print_trc "DTT device kernel driver proc_thermal_pci is in use."
    #Assume the DTT device device.funcion ID: 04.0, it may change per different SKU
    #Client different SKU will have different DTT device ID, which needs to
    #refer to EDS spec.
    lspci -vvv -s04.0
  else
    block_test "DTT device driver proc_thermal_pci driver is not in use, please check DTT device ID"
  fi
}

# Workload type index meaning: 0 – Idle 1 – Battery Life 2 – Sustained 3 – Bursty 4 – Unknown
workload_type() {
  local online_cpus=""
  [[ -d "$DPTF_PROCESSOR_THERMAL_WORKLOAD_HINT" ]] || die "workload_hint sysfs is not available."

  test_print_trc "Will enable workload hint:"
  do_cmd "echo 1 > $DPTF_PROCESSOR_THERMAL_WORKLOAD_HINT/workload_hint_enable"

  workload_default_type=$(cat "$DPTF_PROCESSOR_THERMAL_WORKLOAD_HINT"/workload_type_index)
  if [[ $workload_default_type -eq 1 ]]; then
    test_print_trc "workload type index is $workload_default_type - Battery Life"
  elif [[ $workload_default_type -eq 0 ]]; then
    test_print_trc "workload type index is $workload_default_type - Idle"
  elif [[ $workload_default_type -eq 2 ]]; then
    test_print_trc "workload type index is $workload_default_type - Sustained"
  elif [[ $workload_default_type -eq 3 ]]; then
    test_print_trc "workload type index is $workload_default_type - Bursty"
  else
    die "workload type index is $workload_default_type - Unknown"
  fi

  online_cpus=$(lscpu | grep "CPU(s)" | sed -n '1,1p' | awk '{print $2}')
  # Run stress to change the workload type
  do_cmd "stress -c $online_cpus -t 10 2>&1 &"
  sleep 5
  workload_stress_type=$(cat "$DPTF_PROCESSOR_THERMAL_WORKLOAD_HINT"/workload_type_index)
  if [[ $workload_stress_type -ne $workload_default_type ]]; then
    test_print_trc "Workload type change to $workload_stress_type after stress running."
  else
    die "Workload type does not change after stress running."
  fi

  sleep 15
  workload_idle_type=$(cat "$DPTF_PROCESSOR_THERMAL_WORKLOAD_HINT"/workload_type_index)
  if [[ $workload_idle_type -ne $workload_stress_type ]]; then
    test_print_trc "Workload type change to $workload_idle_type after stress finished."
  else
    die "Workload type does not change after stress finished."
  fi
}

thermal_dptf_sysfs_test() {
  case $TEST_SCENARIO in
  write_dptf_acpi_uuid)
    write_uuid
    ;;
  read_dptf_acpi_odvp)
    read_odvp
    ;;
  read_dptf_processor_thermal_power_limit)
    read_processor_thermal
    ;;
  read_dptf_processor_thermal_workload_type)
    processor_thermal_workload_type
    ;;
  write_dptf_processor_thermal_workload_type)
    write_workload
    ;;
  check_dtt_device_driver)
    dtt_device_check
    ;;
  check_workload_type_change)
    workload_type
    ;;
  esac
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

thermal_dptf_sysfs_test
