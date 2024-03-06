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
# File:         POWER_MANAGEMENT_12_Check_supported_operating_modes_of_the_suspend-to-disk_mechanism.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=76
NAME="12 Check supported operating modes of the suspend-to-disk mechanism"
AUTHOR=""
STATUS="Ready"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="1. Execute command:
cat /sys/power/disk

1. All supported modes are displayed with the currently selected one in brackets. Command returns:
[platform] shutdown reboot suspend"
OBJECTIVE="/sys/power/disk controls the operating mode of the suspend-to-disk
mechanism. Suspend-to-disk can be handled in several ways. We have a
few options for putting the system to sleep - using the platform driver
(e.g. ACPI or other suspend_ops), powering off the system or rebooting the
system (for testing).

Reading from this file will display all supported modes and the currently
selected one in brackets, for example
 [shutdown] reboot test testproc"

TIMEOUT=0:00:00

##PRECONDITIONS##

precondition_numero[0]="1"
precondition_cmd[0]="cat /boot/config-\$(uname -r) |grep CONFIG_HIBERNATION=y"
precondition_status[0]=""
precondition_expected_result[0]="CONFIG_HIBERNATION=y"
precondition_operator[0]="2"

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]="cat /sys/power/disk | awk '{print \$1}'"
step_status[0]=""
step_expected_result1[0]="[platform]"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]="0"
step_iteration[0]=

test_type[1]="2"
step_numero[1]="2"
step_cmd[1]="cat /sys/power/disk |grep -o shutdown"
step_status[1]=""
step_expected_result1[1]="shutdown"
step_expected_result2[1]=""
step_operator1[1]="2"
step_operator2[1]="0"
step_iteration[1]=

test_type[2]="2"
step_numero[2]="3"
step_cmd[2]="cat /sys/power/disk |grep -o reboot"
step_status[2]=""
step_expected_result1[2]="reboot"
step_expected_result2[2]=""
step_operator1[2]="2"
step_operator2[2]="0"
step_iteration[2]=

test_type[3]="2"
step_numero[3]="4"
step_cmd[3]="cat /sys/power/disk |grep -o suspend"
step_status[3]=""
step_expected_result1[3]="suspend"
step_expected_result2[3]=""
step_operator1[3]="2"
step_operator2[3]="0"
step_iteration[3]=

##POSTCONDITIONS##

. ../../test_framework.sh
