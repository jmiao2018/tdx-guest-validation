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
# File:         Init_xHCI_pci_driver.sh
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

driver=$(cat /boot/config-`uname -r`|grep -i CONFIG_USB_XHCI_PCI)

if [ "$driver" != "CONFIG_USB_XHCI_PCI=m" ]; then 
	echo -e "   [\033[1;33mSkip\033[0;0m]: $driver"
else
	xhciMod=$(lsmod | grep -i 'xhci_pci' | awk '{print $1}' | grep -i 'xhci_pci')
	if [ "$xhciMod" != "xhci_pci" ]; then
		echo -e "   [\033[1;33mSkip\033[0;0m]: module is not load"
	else
		respReq=50000
		xhciInit=$(sudo modprobe -rf xhci_pci; sleep 10; sudo modprobe xhci_pci; dmesg | grep -i initcall | grep -i xhci_pci | tail -n 1 | awk '{print $9}')
		if [ $xhciInit -lt $respReq ]; then 
			echo -e "   [\033[1;32mPASS\033[0;0m]: time to initiate xhci_pci module is $xhciInit µs"
			result=0
		else
			echo -e "   [\033[1;31mFAIL\033[0;0m]: time to initiate xhci_pci module is \033[1;31m$xhciInit µs\033[0;0m]"
			result=1
		fi
	fi
fi

exit $result
