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
# File:         Bulk_type_transmission_high_speed_mass_storage.sh
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

ln=`logname`

# ============================
# === High speed copy file ===
# ============================
# device used is 0781:5530 SanDisk Corp. Cruzer
# file is create to distant drive using its name
# testing drive speed using lsusb before and after the operation
ms=$(ls /media/`logname`|grep -o USB20)
if [ -z $ms ]; then
	echo -e "   [\033[1;33mBlock\033[0;0m]: HS drive named USB20 is not detected"
else
	hspeed1=$(lsusb -d 0781:5530 -vvv 2> /dev/null | grep -i bcdusb -m 1 | awk '{print $2}')
	if [ "$hspeed1" = "2.00" ]; then
		dd if=/dev/urandom of=/media/`logname`/USB20/test.bin count=1024 bs=1024 2> /dev/null
		cp /media/`logname`/USB20/test.bin ~/Desktop/test.bin
		hspeed2=$(lsusb -d 0781:5530 -vvv 2> /dev/null | grep -i bcdusb -m 1 | awk '{print $2}')
		compare=$(cmp /media/$ln/USB20/test.bin ~/Desktop/test.bin)
		if [ -z "$compare" ]; then 
			if [ "$hspeed2" = "$hspeed1" ]; then
				echo -e "   [\033[1;32mPASS\033[0;0m]: HighSpeed copy succeeded"
				result=0
			else
				echo -e "   [\033[1;31mFAIL\033[0;0m]: copy succeeded but speed has changed during copy"
				result=1
			fi
		else
			echo -e "   [\033[1;31mFAIL\033[0;0m]: copy has failed"
			result=1
		fi
	else
		echo -e "   [\033[1;33mBlock\033[0;0m]: wrong Speed detected for Pendrive"
	fi
fi
# Post condition
rm /media/`logname`/USB20/test.bin; rm ~/Desktop/test.bin

exit $result
