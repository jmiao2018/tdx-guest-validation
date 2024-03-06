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
# File:         Bulk_type_transmission_super_speed_mass_storage.sh
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
# === Super speed copy file ==
# ============================
# device used is 1b1c:1a03 Corsair
# file is create to distant driv
# need yet to code a dinamic MS detection system to be able to perform the test watever the MS is.
# precondition must evaluate MS speed & MS controller.
# best point would be to detect block protocol (HS or SS)
ms=$(ls /media/`logname`|grep -o USB30)
if [ -z $ms ]; then
	echo -e "   [\033[1;33mBlock\033[0;0m]: SS drive named USB30 is not detected"
else
	sspeed1=$(lsusb -d 1b1c:1a03 -vvv 2> /dev/null | grep -i bcdusb | awk '{print $2}')
	if [ "$sspeed1" = "3.00" ]; then
		dd if=/dev/urandom of=/media/`logname`/USB30/test.bin count=1024 bs=1024 2> /dev/null
		cp /media/`logname`/USB30/test.bin ~/Desktop/test.bin
		sspeed2=$(lsusb -d 1b1c:1a03 -vvv 2> /dev/null | grep -i bcdusb | awk '{print $2}')
		compare=$(cmp /media/$ln/USB30/test.bin ~/Desktop/test.bin)
		if [ -z "$compare" ]; then 
			if [ "$sspeed2" = "$sspeed1" ]; then
				echo -e "   [\033[1;32mPASS\033[0;0m]: SuperSpeed copy succeeded"
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
rm /media/`logname`/USB30/test.bin; rm ~/Desktop/test.bin

exit $result
