#!/bin/bash
#
# - linux
#
#  (c) Intel Corporation 2015
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
#
#  Author: Christophe.Prigent@intel.com
#
#  Version: 0.1
#
#

intel_idle_init_status=$(dmesg |grep intel_idle_init |grep -o "returned 0");
cpuidle_init_status=$(dmesg |grep cpuidle_init |grep -o "returned 0");
current_idle_driver=$(cat /sys/devices/system/cpu/cpuidle/current_driver);

#Test is Pass in 2 cases:
# 1. cpuidle + intel_idle are successfully initialized -> current_driver is intel_idle
# 2. cpuidle is successfully initialized but intel_idle is not -> current_driver is acpi_idle

if [[ $intel_idle_init_status = "returned 0" ]] && [[ $cpuidle_init_status = "returned 0" ]] && [[ $current_idle_driver = "intel_idle" ]]; then
	echo 0
else
	if [[ $intel_idle_init_status != "returned 0" ]] && [[ $cpuidle_init_status = "returned 0" ]] && [[ $current_idle_driver = "acpi_idle" ]]; then
		echo 0
	else
		echo 1
	fi
fi
