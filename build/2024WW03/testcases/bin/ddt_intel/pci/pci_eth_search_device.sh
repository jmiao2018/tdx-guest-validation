#!/bin/bash

###############################################################################
#
# Copyright (C) 2018 Intel - http://www.intel.com/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
################################################################################

############################ CONTRIBUTORS #####################################

# Author: Juan Pablo Gomez (juan.p.gomez@intel.com)
#
# Jan, 2018. Juan Pablo Gomez <juan.p.gomez@intel.com>
#   - Create script to run PCIe Ethernet Search Device

############################ DESCRIPTION ######################################

# This script search for PCI Ethernet devices

############################# FUNCTIONS #######################################
source common.sh

ETHDEV=''
DEVICES=$(ls /sys/class/net)

for device in $DEVICES
do
  PCI_INTERFACE=$(udevadm info --attribute-walk --path=/sys/class/net/"$device" | grep -m 1 -i "pci")
  if [ -n "$PCI_INTERFACE" ]; then
    echo "$device"
    ETHDEV=$device
  fi
done

if [ -z "$ETHDEV" ];
then
  echo "::"
  echo ":: Failed to find PCI Ethernet interface. Exiting PCI Ethernet tests..."
  echo "::"
  exit 2
fi
