#!/bin/bash
###############################################################################
# Copyright (C) 2018, Intel - http://www.intel.com
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

############################ CONTRIBUTORS #####################################

# @Author   Juan Pablo Gomez <juan.p.gomez@intel>
#
# Jan, 2018. Juan Pablo Gomez <juan.p.gomez@intel.com>
#     - Initial draft.

############################ DESCRIPTION ######################################

# @desc     This script runs PCI Ethernet tests.
# @returns
# @history  2018-01-23: First version
#           2018-04-02: Fix ifdown/up with ifconfig and support multi devices

############################# FUNCTIONS #######################################
source "common.sh"

usage() {
  cat <<-EOF >&2
    usage: ./${0##*/} [-i ETH_IFACE] [-o OPTION CASE]
    -a ACTION the ethernet test to be run .
    -h Help   print this usage
EOF

  exit 0
}

updown() {

 for interface_1 in ${IFACE_LIST}; do
   do_cmd "ifconfig $interface_1 down"
 done;

 for interface_2 in ${IFACE_LIST}; do
   do_cmd "ifconfig $interface_2 up"
   sleep 10
 done

 return 0
 }

############################ DO THE WORK ######################################

while getopts :i:abcdefh:o: arg
do case $arg in
  i)  ETH_IFACE="$OPTARG" ;;
  o)  OPTION="$OPTARG" ;;

  h)  usage ;;
  :)  test_print_trc "$0: Must supply an argument to -$OPTARG." >&2 &&  exit 1 ;;
  \?) test_print_trc "Invalid Option -$OPTARG ignored." >&2
      usage &&  exit 1 ;;
esac
done

if [ -z "${ETH_IFACE}" ]; then
  test_print_rtc "No Ethernet Interface provided"
  test_print_trc "Lookin for Ethernet Interface activated...."
  ETH_IFACE=$(pci_eth_search_device.sh) || die "error getting pcie eth interface name"
  test_print_trc "PCI Ethernet Interfaces activaded (eth iface): $ETH_IFACE"
fi

test_print_trc "ETH Interface active_IFACE: $ETH_IFACE"

# PREPARE PCI ETH TEST

IFACE_LIST=$(pci_get_active_eth_interfaces.sh)
test_print_trc "ALL Ethernet Ports: ${IFACE_LIST[*]}"

IFACE_CONFIG="iface ${ETH_IFACE} inet dhcp"
if [ -f /etc/network/interfaces ]; then
  grep "$IFACE_CONFIG" /etc/network/interfaces \
    || ( echo "#$IFACE_CONFIG" >> /etc/network/interfaces )
fi

# CLEAN UP BEFORE PCI ETH TEST
updown || die "Unable to clean adapters"

# Multi pci device, get host gateway one by one and test
for interface_3 in ${IFACE_LIST}; do

  HOST=$(pci_get_eth_gateway.sh -i "${interface_3}") || die "error getting eth gateway address"
  test_print_trc "This is the gateway host:${HOST}"

  # RUN ETH FUNCTIONAL TESTS
  case $OPTION in
    1)
      do_cmd "ping $HOST -c 10" ;;
    2)
      do_cmd "ping $HOST -c 10 -s 64" ;;
    3)
      for size in 64 128 512 1024 4096 8192 16384; do
        do_cmd "ping $HOST -c 10 -s $size"
      done ;;

  # STRESS TESTS

    4)
      do_cmd "ping $HOST -w 60" ;;
    5)
      do_cmd "ping $HOST -w 600 " ;;
    6)
      do_cmd "ping $HOST -w 1200" ;;
  esac

done
# CLEAN UP AFTER PCI ETH TEST
updown || die "Unable to clean adapters"
