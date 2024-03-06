#!/bin/bash
#
# - linux
#
#   Copyright (c) Intel, 2012
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
# File:         POWER_MANAGEMENT_10_Check_the_pstate_control.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=99
NAME="10 Check the pstate control"
AUTHOR=""
STATUS="Designed"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="1.Execute command:
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver

1.Command returns:
intel_pstate"
OBJECTIVE="Starting with the 3.10 kernel, the Linux kernel has included the intel_pstate driver. This driver enumerates against the hardware capabilities of the CPU instead of depending upon the more limited ACPI enumeration. Because of this very basic change, the intel_pstate driver includes the control algorithms specific to a CPU.
In short this causes the system to more accurately judge what P-State a platform should be in, while maintain a superior battery life. "

TIMEOUT=0:00:00

##PRECONDITIONS##

precondition_numero[0]="1"
precondition_cmd[0]="cat /boot/config-\$(uname -r) |grep INTEL_PSTATE"
precondition_status[0]=""
precondition_expected_result[0]="CONFIG_X86_INTEL_PSTATE=y"
precondition_operator[0]="2"

precondition_numero[1]="2"
precondition_cmd[1]="dmesg |grep \"initcall.*intel_pstate_init\" |grep -o \"returned 0\""
precondition_status[1]=""
precondition_expected_result[1]="returned 0"
precondition_operator[1]="2"

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]="cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver |grep intel_pstate"
step_status[0]=""
step_expected_result1[0]="intel_pstate"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]="0"
step_iteration[0]=

##POSTCONDITIONS##

. ../../test_framework.sh
