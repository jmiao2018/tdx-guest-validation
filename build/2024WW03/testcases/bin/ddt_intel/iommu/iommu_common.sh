#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Author: Pengfei, Xu <pengfei.xu@intel.com>
# It's for IOMMU(input–output memory management unit) common functions
#

source "common.sh"

readonly PCIE_CHECK_TOOL="pcie_check"
readonly EXIST="exist"
readonly NULL="null"
readonly DMAR0="dmar0"
readonly ECAP="ecap"
readonly DEBUG_PATH="/sys/kernel/debug/tracing"
readonly MMIO_DEBUG="/tmp/mmio_debug.txt"

DMESG_FIND=""

# Verify whether requested key dmesg was exist
# Input:
#   $1: key1 content
#   $2: key2 content(optional)
# Output: return 0 otherwise for die
full_dmesg_check() {
  local key1=$1
  local key2=$2
  local start_time="[    0.000000]"
  local result=""

  result=$(dmesg | head | grep "$start_time")
  [[ -n "$result" ]] \
    || block_test "Dmesg was not started with $start_time:$result"

  DMESG_FIND=$(dmesg | grep "$key1" | grep "$key2")
  if [[ -z "$DMESG_FIND" ]]; then
    test_print_trc "Could not find $key1 and $key2 in dmesg"
    return 1
  else
    test_print_trc "Find $key1 and $key2 in dmesg:$DMESG_FIND"
    return 0
  fi
}

# Clear mmio and other debug trace
# Input: NA
# Output: return 0 otherwise 1 or die
clear_debug_trace() {
  do_cmd "echo nop > ${DEBUG_PATH}/current_tracer"
  do_cmd "echo 0 > ${DEBUG_PATH}/tracing_on"
}

# Verify whether mmio was really used
# Input: $1: keyword like "MAP" or null
# Output: return 0 otherwise 1 or die
mmio_test() {
  local key=$1
  local result=""

  do_cmd "sysctl kernel.ftrace_enabled=1"
  clear_debug_trace


  do_cmd "echo mmiotrace > ${DEBUG_PATH}/current_tracer"
  do_cmd "echo 1 > ${DEBUG_PATH}/tracing_on"
  do_cmd "modprobe -r thunderbolt"
  sleep 1
  do_cmd "modprobe thunderbolt"
  sleep 5
  echo 0 > "$DEBUG_PATH"/tracing_on
  cat "$DEBUG_PATH"/trace > "$MMIO_DEBUG"

  if [[ -z "$key" ]]; then
    result=$(cat "$MMIO_DEBUG" | grep -v "^#" | head -n 10)
  else
    result=$(cat "$MMIO_DEBUG" | grep -v "^#" | grep "$key")
  fi
  if [[ -n "$result" ]]; then
    test_print_trc "Get mmio info $key in $MMIO_DEBUG:$result, pass."
  else
    die "No mmio info:$result in $MMIO_DEBUG and do you connect one tbt device?"
  fi
}

# Verify whether requested PRS was supported
# Input: NA
# Output: return 0 otherwise 1
prs_check() {
  local result=""
  local ecap_value=""
  local check_value=""
  local check_bit="0x20000000"

  full_dmesg_check "$DMAR0" "$ECAP"
  [[ -z "$DMESG_FIND" ]] && block_test "Could not find $DMAR0 and $ECAP"
  ecap_value=$(echo "$DMESG_FIND" | awk -F "$ECAP " '{print $2}')
  echo "ecap_value:$ecap_value"
  [[ "$ecap_value" != "0x"* ]] && check_value="0x$ecap_value"
  result=$((check_value & check_bit))
  test_print_trc "$DMAR0 $ECAP:$check_value, check:$check_bit, result:$result"
  if [[ "$check_bit" -eq "$result" ]]; then
    test_print_trc "check_bit:$check_bit is equal to decimal result:$result"
    return 0
  else
    test_print_trc "check_bit:$check_bit is not equal to decimal result:$result"
    return 1
  fi
}

# Verify IOMMU could be supported by BIOS
# Input: NA
# Output: return 0 otherwise for die
mmio_support() {
  mmio_path="/sys/kernel/iommu_groups/*/devices/*"

  if compgen -G "$mmio_path" > /dev/null; then
    test_print_trc "Intel's VT-D is enabled in IFWI, check $mmio_path"
    return 0
  else
    test_print_trc "Intel's VT-D is not enabled in IFWI, none in $mmio_path"
    return 1
  fi
}

# Verify requested pasid pcie was exist or not
# Input:
#   $1: null or exist parm
# Output: return 0 otherwise for die
pasid_pcie_check() {
  local parm=$1
  local pice_bin=""
  local result=""

  pice_bin=$(which $PCIE_CHECK_TOOL)
  $pice_bin c 1b 4 16
  result=$?
  if [[ "$result" -eq 1 ]]; then
    test_print_trc "No PASID PCIe found"
  elif [[ "$result" -eq 0 ]]; then
    test_print_trc "There was PASID PCIe found"
  else
    block_test "Return not 0 or 1 value unexpectedly"
  fi

  case $parm in
    $EXIST)
      [[ "$result" -eq 0 ]] || {
        test_print_wrg "Should exist PASID PCIe"
        return 1
      }
      ;;
    $NULL)
      [[ "$result" -eq 1 ]] || {
        test_print_wrg "Should not exist PASID PCIe"
        return 1
      }
      ;;
    *)
      block_test "Invalid par:$par"
      ;;
  esac
}
