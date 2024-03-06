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
#             Dec. 2, 2017 - (Ammy Yi)Creation


# @desc This script verify usb sysfs
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}


wakeup_e_check() {
  usb_device_dirs=$(ls $USB_SYS_DEVICE_PATH | xargs)
  #save default value
  for dir in $usb_device_dirs; do
    local i=0
    [ -f $USB_SYS_DEVICE_PATH/$dir/power/wakeup ] && sys[$i]=$(cat $USB_SYS_DEVICE_PATH/$dir/power/wakeup)
    let i=i+1
  done
  #wakeup as enable
  for dir in $usb_device_dirs; do
    ls $USB_SYS_DEVICE_PATH/$dir/power/ | grep wakeup
    [ $? -ne 0 ] || echo "enabled" > $USB_SYS_DEVICE_PATH/$dir/power/wakeup
  done
  suspend_to_resume "mem"
  #restore value
  for dir in $usb_device_dirs; do
    local i=0
    [ -f $USB_SYS_DEVICE_PATH/$dir/power/wakeup ] && echo sys[$i] > $USB_SYS_DEVICE_PATH/$dir/power/wakeup
    let i=i+1
  done
  return 0
}

wakeup_d_check() {
  usb_device_dirs=$(ls $USB_SYS_DEVICE_PATH | xargs)
  #save default value
  for dir in $usb_device_dirs; do
    local i=0
    [ -f $USB_SYS_DEVICE_PATH/$dir/power/wakeup ] && sys[$i]=$(cat $USB_SYS_DEVICE_PATH/$dir/power/wakeup)
    let i=i+1
  done
  #wakeup as disble
  for dir in $usb_device_dirs; do
    ls $USB_SYS_DEVICE_PATH/$dir/power/ | grep wakeup
    [ $? -ne 0 ] || echo "disabled" > $USB_SYS_DEVICE_PATH/$dir/power/wakeup
  done
  suspend_to_resume "mem"
  #restore value
  for dir in $usb_device_dirs; do
    local i=0
    [ -f $USB_SYS_DEVICE_PATH/$dir/power/wakeup ] && echo sys[$i] > $USB_SYS_DEVICE_PATH/$dir/power/wakeup
    let i=i+1
  done
  return 0
}

root_hotplug() {
  USBROOTHUBPATH="/sys/bus/pci/drivers/xhci_hcd"
  ls $USBROOTHUBPATH | grep "0000" > temp.txt
  cat temp.txt | while read line;do
    do_cmd "echo $line > $USBROOTHUBPATH/unbind"
    do_cmd "echo $line > $USBROOTHUBPATH/bind"
  done

}

main() {
  case $TEST_SCENARIO in
    wakeup_e)
      wakeup_e_check
      ;;
    wakeup_d)
      wakeup_d_check
      ;;
    ep)
      path_all_polling_check $USB_SYS_DEVICE_PATH
      ;;
    hotplug)
      root_hotplug
      ;;
    *)
      usage
      die "Invalid Test ID!"
      ;;
  esac
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

usb_setup
main
usb_trace_check || die "usb log check fail, please check detailed trace and dmesg logs!"
usb_log_teardown
# Call teardown for passing case
exec_teardown
