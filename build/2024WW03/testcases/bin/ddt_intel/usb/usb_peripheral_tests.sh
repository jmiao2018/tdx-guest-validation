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
#             Sep. 27, 2017 - (Ammy Yi)Creation


# @desc This script verify usb printer function
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

usage() {
  cat << EOF
  usage: ${0##*/}
    -e  hotplug flag"
    -d  hil board port"
    -s  suspend state to test"
    -t  hub number"
    -m  peripheral"
    -p  product id:device id"
    -n  product detail name"
    -H  show this"
EOF
}

usb_printer_check() {
  sleep 2m
  lsusb | grep "$ID"
  [[ $? -eq 0 ]] || die "USB printer is not enumed, please check HW and scenario file -p -n parameter are correct first!"
  lsusb -t | grep usblp
  [[ $? -eq 0 ]] || die "USB printer is not enabled, please check HW and scenario file -p -n parameter are correct first!"
  return 0
}

usb_scanner_check() {
  lsusb | grep "$ID"
  [[ $? -eq 0 ]] || die "USB scanner is not enumed, please check HW and scenario file -p -n parameter are correct first!"
  sane-find-scanner | grep "$NAME"
  [[ $? -eq 0 ]] || die "USB scanner is not found, please check HW and scenario file -p -n parameter are correct first!"
  return 0
}

usb_headset_check() {
  lsusb | grep "$ID"
  [[ $? -eq 0 ]] || die "USB headset is not enumed, please check HW and scenario file -p -n parameter are correct first!"
  aplay -l | grep "$NAME"
  [[ $? -eq 0 ]] || die "USB headset is not found, please check HW and scenario file -p -n parameter are correct first!"
  usb_hs_id=$(aplay -l | grep USB | awk '{print $2}')
  usb_hs_id=$(echo ${usb_hs_id%:})
  arecord -D plughw:$usb_hs_id -f cd -d 2 $AUDIO
  [[ $? -eq 0 ]] || die "USB headset record failed!"
  aplay -D plug:hw:$usb_hs_id $AUDIO
  [[ $? -eq 0 ]] || die "USB headset play failed!"
  return 0
}

usb_low_keyboard_check() {
  lsusb -v | grep -E 'bInterfaceProtocol.*Keyboard' -B 35 | grep -E 'bcdUSB.*1'
  [[ $? -eq 0 ]] || die "USB Low Speed Keyboard is not enumed!"
  return 0
}

usb_high_keyboard_check() {
  lsusb -t | grep usbhid | grep 12M
  [[ $? -eq 0 ]] || die "USB High Speed Keyboard is not enumed!"
  return 0
}

usb_mouse_check() {
  lsusb -v | grep -E 'bInterfaceProtocol.*Mouse'
  [[ $? -eq 0 ]] || die "USB Mouse is not enumed!"
  return 0
}

usb_camera_check() {
  lsusb -t | grep  'uvcvideo'
  [[ $? -eq 0 ]] || die "USB Camera is not enumed!"
  return 0
}

usb_ethernet_check() {
  lsusb -v | grep -i ethernet
  [[ $? -eq 0 ]] || die "USB Ethernet is not enumed!"
  return 0
}

teardown() {
  case $MODE in
    scanner)
      rm test.tiff
      ;;
    headset)
      rm $AUDIO
      ;;
  esac
}

hub_num_common(){
  local dev_name=$1
  local dev_node=$2
  local hub_num=$3
  local num=0
  local usb_base=4
  sleep 1

  num1=$(lsusb -t |grep -i "$dev_node" | tail -n 1 | awk -F "|" '{print$1}' | \
        awk -v RS="@#$" '{print gsub(/ /,"&")}')
  echo num1=$num1
  num2=$((num1 - usb_base))
  num=$((num2/4))
  if [ $dev_name == "ethernet" ] || [ $dev_name == "hkeyboard" ]; then
    num=$((num-1))
  fi

  if [[ $num -eq $hub_num ]]; then
    test_print_trc "*** $dev_name link hub number : $num , (PASS) ! ***"
    return 0
  else
    test_print_trc "*** $dev_name link hub number : $num , defined : $hub_num , (FAIL) ! ***"
    return 1
  fi

}

usb_hub_check() {
  case $MODE in
    printer)
      [ -z "$HUB_NUM" ] ||  hub_num_common printer "usblp" $HUB_NUM
      ;;
    scanner)
      ;;
    headset)
      [ -z "$HUB_NUM" ] ||  hub_num_common headset "usb-audio, 12M" $HUB_NUM
      ;;
    lkeyboard)
      [ -z "$HUB_NUM" ] ||  hub_num_common lkeyboard "usbhid, 1.5M" $HUB_NUM
      ;;
    hkeyboard)
      [ -z "$HUB_NUM" ] ||  hub_num_common hkeyboard "usbhid, 12M" $HUB_NUM
      ;;
    mouse)
      ;;
    camera)
      [ -z "$HUB_NUM" ] ||  hub_num_common camera "video" $HUB_NUM
      ;;
    ethernet)
      [ -z "$HUB_NUM" ] ||  hub_num_common ethernet "r8152" $HUB_NUM
      ;;
  esac
}


usb_pe_check() {
  case $MODE in
    printer)
      usb_printer_check
      ;;
    scanner)
      usb_scanner_check
      ;;
    headset)
      usb_headset_check
      ;;
    lkeyboard)
      usb_low_keyboard_check
      ;;
    hkeyboard)
      usb_high_keyboard_check
      ;;
    mouse)
      usb_mouse_check
      ;;
    camera)
      usb_camera_check
      ;;
    ethernet)
      usb_ethernet_check
      ;;
  esac
}

main() {
  if [[ $HOTPLUG_FLAG = "hotplug" ]]; then
    usb_hotplug_setup $PORT_ID
    [[ $? -eq 0 ]] || block_test "fail to setup for usb hotplug!"
  fi
  usb_hub_check || die "USB hub number check fail!"
  sleep 1
  usb_pe_check || die "USB peripheral check fail!"
  if [[ $HOTPLUG_FLAG = "hotplug" ]]; then
    usb_hotplug $PORT_ID
    usb_pe_check || die "USB peripheral check fail!"
  fi
  if [[ $SUSPEND_STATE != "NO" ]]; then
    suspend_to_resume "$SUSPEND_STATE"
    wait $!
    sleep 5
    usb_pe_check || die "USB peripheral check fail!"
  fi
  return 0
}

: ${HOTPLUG_FLAG:=""}
: ${PORT_ID:=""}
: ${SUSPEND_STATE:="NO"}
: ${ID:=""}
: ${NAME:=""}
: ${AUDIO:="test.wav"}

while getopts :e:d:s:t:m:p:n:H arg; do
  case $arg in
    e)
      HOTPLUG_FLAG=$OPTARG
      ;;
    d)
      PORT_ID=$OPTARG
      ;;
    s)
      SUSPEND_STATE=$OPTARG
      ;;
    t)
      HUB_NUM=$OPTARG
      ;;
    m)
      MODE=$OPTARG
      ;;
    p)
      ID=$OPTARG
      ;;
    N)
      NAME=$OPTARG
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

teardown_handler="teardown"
usb_setup
main
usb_trace_check || die "usb log check fail, please check detailed trace and dmesg logs!"
usb_log_teardown
exec_teardown
exit 0
