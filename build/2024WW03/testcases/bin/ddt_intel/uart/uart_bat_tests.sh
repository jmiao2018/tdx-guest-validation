#!/usr/bin/env bash

###############################################################################
#
# Copyright (C) 2018 Intel - http://www.intel.com
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
# @Author   Ning Han (ning.han@intel.com)
# @desc     Uart basic acceptance test cases.
# @history  2018-11-15: First Version (Ning Han)

source common.sh
source dmesg_functions.sh
source uart_common.sh

TC=0
DMESG=""

usage() {
  cat << _EOF
    usage ${0##*/}
    -c case id
    -h show this
_EOF
}

check_ttySN() {
  local real_path
  local node_path
  local missing_nodes=()
  local ttySN=$1

  real_path=$(realpath "$SERIAL_SYS_CLASS_PATH/$ttySN") || \
    die "get real path of $ttySN failed"

  for node in "${SERIAL_SYS_NODES[@]}"; do
    node_path="$real_path/$node"
    [[ -e "$node_path" ]] || missing_nodes+=($node_path)
    test_print_trc "$node_path found."
  done

  if [[ ${#missing_nodes[@]} -ne 0 ]]; then
    for missing_node in "${missing_nodes[@]}"; do
      test_print_trc "$missing_node not found."
    done
  fi

  return ${#missing_nodes[@]}
}

sysfs_node_check() {
  local ttySNs
  local rc=0

  ttySNs=$(get_valid_ttySNs)
  [[ -n "$ttySNs" ]] || block_test "No valid tty serial node found."

  for ttySN in $ttySNs; do
    check_ttySN "$ttySN"
    rc=$((rc + $?))
  done

  [[ $rc -eq 0 ]] || die "Check ttySN failed."
}

check_8250_dw_module() {
  local serial8250_dw
  local case_dmesg

  serial8250_dw=$(get_kconfig "$SERIAL8250_DW_KCONFIG")
  if [[ "$serial8250_dw" == "y" ]]; then
    test_print_trc "serial8250 dw driver is built-in, no need to check."
    exit 0
  fi

  if lsmod | grep -q "$SERIAL8250_DW_MODULE"; then
    test_print_trc "$SERIAL8250_DW_MODULE has been loaded, remove it firstly."
    modprobe -r "$SERIAL8250_DW_MODULE"
  fi

  modprobe -q "$SERIAL8250_DW_MODULE"
  case_dmesg=$(extract_case_dmesg)
  grep -E "$SERIAL8250_DW_PATTERN" <<< "$case_dmesg" || \
    die "Check $SERIAL8250_DW_MODULE failed."
}

bind_unbind_device() {
  local real_path
  local rp_array
  local index
  local bus_id
  local case_dmesg
  local ttySN="$1"

  real_path=$(realpath "$SERIAL_SYS_CLASS_PATH/$ttySN") || \
    die "get real path of $ttySN failed"
  rp_array=($(tr "\/" " " <<< "$real_path"))
  index=$((${#rp_array[@]} - 3))
  bus_id=${rp_array[$index]}
  test_print_trc "BUS ID: $bus_id"

  cd "$real_path/device/driver" || \
    block "change directory to $real_path/device/driver failed."
  test_print_trc "unbind device firstly, don't care the result."
  echo -n "$bus_id" > "unbind"
  test_print_trc "bind device, check dmesg later."
  echo -n "$bus_id" > "bind" || \
    die "bind action failed."

  case_dmesg=$(extract_case_dmesg)
  grep "$bus_id" <<< "$case_dmesg" || \
    die "check bind dmesg failed."
}

check_device_bind_unbind() {
  local ttySNs
  local rc=0

  ttySNs=$(get_valid_ttySNs)
  [[ -n "$ttySNs" ]] || block_test "No valid tty serial node found."

  for ttySN in $ttySNs; do
      bind_unbind_device "$ttySN"
      rc=$((rc + $?))
  done

  [[ "$rc" -eq 0 ]] || die "Bind/unbind driver failed."
}

while getopts "c:h" opt; do
  case $opt in
    c) TC=$OPTARG ;;
    h) uage ;;
    \?) usage && die "Invalid Option -$OPTARG" ;;
    :) usage && die "Option -$OPTARG requires an argument." ;;
  esac
done

check_8250_kconfig

DMESG=$(dump_dmesg)

case $TC in
  0) dmesg_pattern_check "$DMESG" "${SERIAL8250_PATTERN}" ;;
  1) dmesg_pattern_check "$DMESG" "$SERIAL_PCI_PATTERN" ;;
  2) sysfs_node_check ;;
  3) check_8250_dw_module ;;
  4) check_device_bind_unbind ;;
  *) die "Invalid case id - $TC" ;;
esac
