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
###############################################################################

############################ CONTRIBUTORS #####################################

# Author: Juan Pablo Gomez (juan.p.gomez@intel.com)
#
# Jan, 2018. Juan Pablo Gomez <juan.p.gomez@intel.com>
#   - Create script to run PCIe Ethernet Search Device

############################ DESCRIPTION ######################################

# This script checks for all eth interfaces supported and creates an array.

############################# FUNCTIONS #######################################

J=0
for device in $(find /sys/class/net/en*)
do
  INTERFACE=$(echo "$device"  | cut -c 16- )
  if [[ "$(cat /sys/class/net/"$INTERFACE"/operstate)" == "up" ]]
  then
    INT_NAME[J]=$INTERFACE
    J+=1
  fi
done
echo "${INT_NAME[@]}"
