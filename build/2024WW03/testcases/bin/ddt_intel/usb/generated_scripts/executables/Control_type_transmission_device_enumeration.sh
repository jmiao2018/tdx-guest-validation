#!/bin/bash
#
# - linux
#
#   Copyright (c) Intel, 2015
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2.1 of the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#
#
# File:         Control_type_transmission_device_enumeration.sh
#
# Description:
#
# Author(s):    Sebastien Dufour <sebastien.dufour@intel.com>
#
# Date:         2015-07-15
#
# Updated by:   Helia Correia <helia.correia@intel.com>
#
#

# Final code result of test is PASS=0 / FAIL=1 / BLOCK=2
result=2

# this step writes in usbdev.txt file a sorted vid:pid list from usb-devices output
usb-devices | grep P: | awk -F "=" '{print $2 " " $3}' | awk '{print $1 ":" $3}' > usbdev.txt
sort -b usbdev.txt>usbdev.txt

# this step writes in lsusb.txt file the output of lsusb command but sorted as well
lsusb | awk '{print $6}'>lsusb.txt
sort -b lsusb.txt > lsusb.txt

# this step compares those 2 files and put the result in a variable
compare=$(cmp lsusb.txt usbdev.txt)

if [ -z $compare ]; then 
	echo -e "   [\033[1;32mPASS\033[0;0m]: lsusb & sysfs think the same way"
	result=0
else
	echo -e "   [\033[1;31mFAIL\033[0;0m]: there is a difference between lsusb and sysfs"
	result=1
fi

# lets clean work environnment
rm lsusb.txt
rm usbdev.txt

exit $result
