#!/bin/bash
###############################################################################
#
# Copyright (C) 2015 Intel - http://www.intel.com
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
# @Author   Zelin Deng (zelinx.deng@intel.com)
# @desc     check dmesg of xhci module init
# @returns  0 if the execution was finished successfully, else 1
# @history  2015-12-22: First Version (Zelin Deng)

source "common.sh"

: ${XHCI_PCI_MOD_NAME:="xhci_pci"}
XHCI_PCI_KOPTION="CONFIG_USB_XHCI_PCI"

get_xhci_init_time() {
  local init_time=""
  local perl_compatible_pattern="(?<=after )[[:digit:]]*"

  init_time=$(dmesg | grep -iE "initcall\s{1,}$XHCI_PCI_MOD_NAME" | tail -n 1 | grep -Po "$perl_compatible_pattern")
  echo $init_time
}

[ $# -ne 1 ] && die "You must appoint which case to be executed: initcall or dmesg. ${0##*/} <CASE_ID>"

CASE_ID="$1"

# check precondition. xhci must be configured as module or built-in
kconfig=$(get_kconfig "$XHCI_PCI_KOPTION")
if [[ "$kconfig" == "m" ]]; then
  modprobe "$XHCI_PCI_MOD_NAME" || block_test "fail to load module: $XHCI_PCI_MOD_NAME!"
elif [[ "$kconfig" == "y" ]]; then
  test_print_trc "$XHCI_PCI_KOPTION is built-in"
else
  block_test "$XHCI_PCI_KOPTION is not set!"
fi

lane_test() {
  host_rx_tag=0
  host_tx_tag=0
  device_rx_tag=0
  device_tx_tag=0
  sysbus="/sys/bus/usb/devices/"
  usb_nodes=$(ls $sysbus | grep usb)
  [[ -n "$usb_nodes" ]] || die "No usb host found!"
  for hostnode in $usb_nodes; do
    val=0
    val=$(cat $sysbus/$hostnode/rx_lanes)
    [[ $val -eq 2 ]] && host_rx_tag=1

    val=0
    val=$(cat $sysbus/$hostnode/tx_lanes)
    [[ $val -eq 2 ]] && host_tx_tag=1

    if [[ $val -eq 2 ]] && [[ $val -eq 2 ]]; then
      device_nodes=$(find $hostnode/*/ -type f | grep rx)
      for devicenode in $device_nodes; do
        val=0
        val=$(cat $devicenode)
        [[ $val -eq 2 ]] && device_rx_tag=1
      done
      device_nodes=$(find $hostnode/*/ -type f | grep tx)
      for devicenode in $device_nodes; do
        val=0
        val=$(cat $devicenode)
        [[ $val -eq 2 ]] && device_tx_tag=1
      done
    fi
  done

  if [[ $host_rx_tag -ne 1 ]] || [[ $host_tx_tag -ne 1 ]] || [[ $device_rx_tag -ne 1 ]] || [[ $device_tx_tag -ne 1 ]]; then
    test_print_trc "host_rx_tag=$host_rx_tag; host_tx_tag=$host_tx_tag; device_rx_tag=$device_rx_tag; device_tx_tag=$device_tx_tag"
    die "rx_tag/tx_tag not right!"
  fi
}

case $CASE_ID in
  initcall)
    #Check if initcall_debug has been enabled in cmdline
    cat /proc/cmdline | grep -ow initcall_debug
    if [ $? -ne 0 ]; then
      test_print_trc "initcall_debug option must be enabled in cmdline"
      exit 2
    fi

    respReq=50000
    xhciInit=$(get_xhci_init_time)
    [ -n "$xhciInit" ] || die "fail to get xhci init time!"

    if [ $xhciInit -lt $respReq ]; then
      test_print_trc "Successfully, time to initiate $XHCI_PCI_MOD_NAME module is $xhciInit less than $respReq"
      exit 0
    else
      die "Failed, time to initiate $XHCI_PCI_MOD_NAME module is $xhciInit larger than $respReq"
    fi
  ;;
  dmesg)
    #check dmesg to check if there's any issue
    dmesg | grep -iE "00:14|$XHCI_PCI_MOD_NAME" | grep -iE "error|fatal|unable|fail" > temp.txt
    if [ $? -eq 0 ]; then
      error_num=$(grep temp.txt -e "error -2" | awk -v RS="@#$j" '{print gsub(/error\ -2/,"&")}')
      fake_error_num=$(grep temp.txt -e "error -2" | awk -v RS="@#$j" '{print gsub(/firmware/,"&")}')
      [ $error_num -eq $fake_error_num ] || die "Failed, XHCI errors in dmesg detected"
    fi
    test_print_trc "Successfully, no XHCI errors in dmesg detected"
    rm temp.txt
    exit 0
  ;;
  sysfs)
    do_cmd "find /sys/kernel/debug/usb/xhci/ -type f -exec cat {} + > /dev/null"
    exit 0
  ;;
  3.1|3.2)
    #check 3.1 | 3.2 roothub speed
    [ "$CASE_ID" == "3.1" ] && SPEED="10000M"
    [ "$CASE_ID" == "3.2" ] && SPEED="20000M"
    lsusb -t | grep root_hub | grep "$SPEED" || die "$CASE_ID $SPEED fail"
    exit 0
  ;;
  10Gps)
    dmesg | grep "SuperSpeed Gen 1x2 USB device number" || die "10Gps dmesg check fail"
    exit 0
  ;;
  20Gps)
    dmesg | grep "SuperSpeed Plus Gen 2x2 USB device number" || die "20Gps dmesg check fail"
    exit 0
  ;;
  lanes)
    lane_test
    exit 0
  ;;
  3.2_info)
    dmesg | grep "Host supports USB 3.2 Enhanced SuperSpeed" || die "3.2 root hub dmesg check fail"
    exit 0
  ;;
  3.1_info)
    dmesg | grep "Host supports USB 3.1 Enhanced SuperSpeed" || die "3.1 root hub dmesg check fail"
    exit 0
  ;;
esac
