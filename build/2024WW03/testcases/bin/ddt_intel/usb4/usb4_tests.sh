#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Author: Pengfei, Xu <pengfei.xu@intel.com>
# It's for USB4 function tests
#

source "usb4_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-s Scenario][-h]
  -s  Scenario like "generation"
  -h  show This
__EOF
}

# Suspend test
# Input $1: type like freeze s2idle deep disk
#       $2: parameter, like usb4
# Output: 0 for true, otherwise false or die
suspend_type_test() {
  local suspend_type=$1
  local parm=$2
  local result=0

  check_auto_connect
  case $parm in
    usb4)
      usb4_suspend_test "$suspend_type"
      ;;
    *)
      die "Suspend test invalid parm:$parm"
      ;;
  esac
}

main() {
  case $SCENARIO in
    generation)
      is_usb4_sysfs || die "It's not usb4 controller sysfs"
      ;;
    usb4_device)
      is_usb4_device_connected || die "There is no usb4 device connected"
      ;;
    usb4_rtd3)
      plug_in_tbt
      enable_authorized
      is_only_usb4_device_connected \
        || die "Not meet usb4_rtd3 test requirement"
      usb4_rtd3_test
      ;;
    plugin_usb4_noauth_CL1)
      check_usb4_version
      if [[ "$USB4_VER" == "2.0" ]]; then
        test_print_trc "It's USB4v2, please prepare USB4 GR device for test"
        plug_out_tbt
        sleep 5
        plug_in_tbt
        check_clx "auto" "CL1"
      else
        test_print_trc "Not USB4v2, it's USB4 $USB4_VER, just check CLx"
        tblink.sh
      fi
      ;;
    plugin_usb4_auth_CL0)
      check_usb4_version
      if [[ "$USB4_VER" == "2.0" ]]; then
        test_print_trc "It's USB4v2, please prepare USB4 GR device for test"
        plug_in_tbt
        enable_authorized
        check_clx "auto" "CL0"
      else
        test_print_trc "Not USB4v2, it's USB4 $USB4_VER, just check CLx"
        enable_authorized
        tblink.sh
      fi
      ;;
    usb4_type)
      tbt_device_id
      usb4_type_check
      ;;
    usb4v2_type)
      tbt_device_id
      usb4v2_type_check
      ;;
    usb4_device_nvm_restore)
      find_usb4_device
      restore_usb4_device_nvm "$USB4_DEVICE"
      ;;
    usb4_gr_nvm_flash)
      find_usb4_device
      flash_gr_nvm "$PARM" "$USB4_DEVICE"
      ;;
    usb4_hotplug_rtd3)
      for ((i = 1; i <= 3; i++)); do
        test_print_trc "The $i round plug out/in USB4 device rtd3 test:"
        plug_in_tbt
        is_only_usb4_device_connected \
          || die "Not meet hot plug and usb4_rtd3 test requirement"
        usb4_rtd3_test
        plug_out_tbt
        no_tbt_device_check
        usb4_rtd3_test
      done
      plug_in_tbt
      ;;
    suspend)
      plug_in_tbt
      enable_authorized
      is_usb4_device_connected || die "There is no usb4 device connected"
      suspend_type_test "$TYPE" "$PARM"
      ;;
    usb4_gr_boot)
      plug_in_tbt
      is_only_usb4_device_connected \
        || die "Could not find USB4 GR device after boot up"
      find_tbt_device "1MB" "1" "3.0" "flash"
      [[ -n "$DEVICE_NODE" ]] || die "No USB3.0 node:$DEVICE_NODE under GR"
      rtd3_test
      result=$?
      if [[ "$result" -eq 1 ]]; then
        test_print_trc "Connect USB3.0 with GR still in D0 as expected, pass"
      else
        die "Connect USB3.0 with GR should not access D3. Result:$result"
      fi
      ;;
    *)
      usage && exit 1
      ;;
  esac
}

while getopts :s:t:p:h arg; do
  case $arg in
    s)
      SCENARIO=$OPTARG
      ;;
    t)
      TYPE=$OPTARG
      ;;
    p)
      PARM=$OPTARG
      ;;
    h)
      usage
      exit 0
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
