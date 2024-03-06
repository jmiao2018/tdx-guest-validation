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
# File:         xHCI_driver_load_and_controller_enum_module.sh
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
	xhciMod=$(lsmod | grep -i 'xhci_pci' | awk '{print $1}' | grep -o xhci_pci)
	if [ -z $xhciMod ]; then
		echo -e "   [\033[1;33mSkip\033[0;0m]: module is not load"
	else
		systCont=$(cat ~/Root/Datas/templog/lshwbuspci.txt | grep -i capabilities | grep -o xhci)
		if [ $systCont ]; then 
			echo -e "   [\033[1;32mPASS\033[0;0m]: controller exists"
		else
			echo -e "   [\033[1;31mFAIL\033[0;0m]: no USB bus detected"
			result=1
		fi

		driver=$(ls /sys/bus/pci/drivers/ | grep -o xhci_hcd)
		if [ $driver ]; then 
			echo -e "   [\033[1;32mPASS\033[0;0m]: xhci driver is loaded"
		else
			echo -e "   [\033[1;31mFAIL\033[0;0m]: no xhci driver in sysfs detected"
			result=1
		fi

		lshwXhciAdr=$(cat ~/Root/Datas/templog/lshwpci.txt | grep "xhci bus_master" -B 4 | grep "bus info" | awk -F "@" '{print $2}')
		bindedController=$(ls /sys/bus/pci/drivers/xhci_hcd/ | grep $lshwXhciAdr)
		if [ $bindedController ]; then 
			echo -e "   [\033[1;32mPASS\033[0;0m]: xhci driver binds to controller"
		else
			echo -e "   [\033[1;31mFAIL\033[0;0m]: xhci driver does not bind to xhci controller"
			result=1
		fi

		xhciIrq=$(lspci -k -v | grep -i 00:14.0 -A 7 | grep -i irq | awk '{print $9}')
		iQ=$(cat /proc/interrupts | awk '{print $1}' | grep -o $xhciIrq)
		if [ $iQ ]; then 
			echo -e "   [\033[1;32mPASS\033[0;0m]: xhci controller has an IRQ in the system"
			result=0
		else
			echo -e "   [\033[1;31mFAIL\033[0;0m]: IRQ $xhciIrq not found in interrupts list"
			result=1
		fi
	fi
fi

exit $result
