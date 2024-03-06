#!/bin/bash
#
# Copyright 2017 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate USB component.
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
#             Sep. 7, 2017 - (Ammy Yi)Creation


# This script used for hotplug usb device w/ hil board
# This file is created for semi auto test case since LTP-DDT cannot run some scripts during suspended status.
# Please copy this file into another server connected w/ hil board to hotplug duirng suspended status.

CASE=$1
HIL_BOARD="http://localhost:9999/api/v1/stack"

# This function perform connection of usb device with hil board
# Input:
#       n/a
# Output: 0 as pass, 1 as fail
usb_connect_w_hilboard() {
  local result=0
  #start hil board service
  ./hil_server start &
  sleep 1
  #connect hil board
  result=$(curl -X POST $HIL_BOARD)
  result=$(echo $result | grep "201")
  [[ -z $result ]] && return 1
  sleep 1
  return 0
}


# This function perform disconnection of usb device with hil board
# Input:
#       n/a
# Output: 0 as pass, 1 as fail
usb_disconnect_w_hilboard() {
  local result=0
  #connect hil board
  result=$(curl -X DELETE $HIL_BOARD)
  result=$(echo $result | grep "201")
  [[ -z $result ]] && return 1
  sleep 1
  #stop hil board service
  ./hil_server stop
  return 0
}

# This function perform enable of usb device with hil board
# Input:
#       n/a
# Output as pass
usb_enable_w_hilboard() {
  curl -X PUT $HIL_BOARD/hil1/usb1 -H "Content-Type: application/json" -d "{\"state\": 1}"
  curl -X PUT $HIL_BOARD/hil1/usb2 -H "Content-Type: application/json" -d "{\"state\": 1}"
  curl -X PUT $HIL_BOARD/hil1/usb3 -H "Content-Type: application/json" -d "{\"state\": 1}"
  sleep 5
  lsusb -t
  return 0
}

# This function perform disable of usb device with hil board
# Input:
#       n/a
# Output as pass
usb_disable_w_hilboard() {
  curl -X PUT $HIL_BOARD/hil1/usb1 -H "Content-Type: application/json" -d "{\"state\": 0}"
  curl -X PUT $HIL_BOARD/hil1/usb2 -H "Content-Type: application/json" -d "{\"state\": 0}"
  curl -X PUT $HIL_BOARD/hil1/usb3 -H "Content-Type: application/json" -d "{\"state\": 0}"
  sleep 2
  lsusb -t
  return 0
}

# This function perform hotplug of usb device with hil board
# Input:
#       n/a
# Output as pass
usb_hotplug() {
  usb_disable_w_hilboard
  usb_enable_w_hilboard
  return 0
}


# This function perform hotplug setup of usb device with hil board
# Input:
#       n/a
# Output as pass
usb_hotplug_setup() {
  usb_connect_w_hilboard
  [[ $? -eq 0 ]] || return 1
  usb_enable_w_hilboard
  return 0
}

# This function perform hotplug teardown of usb device with hil board
# Input:
#       n/a
# Output: 0 as pass, 1 as fail
usb_hotplug_teardown() {
  usb_disconnect_w_hilboard
  return 0
}
main() {
  if [[ "$CASE" = "e" ]]; then
    usb_hotplug_setup
    [[ $? -eq 0 ]] || echo "hotplug setup failed, please check your hil board!"
  fi
  if [[ "$CASE" = "h" ]]; then
    usb_hotplug
  fi
  if [[ "$CASE" = "s" ]]; then
    usb_hotplug_teardown
  fi
}

main
