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
# File:         POWER_MANAGEMENT_11_Check_system_power_states_supported.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=75
NAME="11 Check system power states supported"
AUTHOR=""
STATUS="Ready"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="1. Execute command:
cat /sys/power/state

1. System power states supported are listed, command returns:
freeze mem disk"
OBJECTIVE="/sys/power/state controls system power state. Reading from this file
returns what states are supported, which is hard-coded to 'freeze',
'standby' (Power-On Suspend), 'mem' (Suspend-to-RAM), and 'disk'
(Suspend-to-Disk)."

TIMEOUT=0:00:00

##PRECONDITIONS##

precondition_numero[0]="1"
precondition_cmd[0]="cat /boot/config-\$(uname -r) |grep CONFIG_HIBERNATION=y"
precondition_status[0]=""
precondition_expected_result[0]="CONFIG_HIBERNATION=y"
precondition_operator[0]="2"

precondition_numero[1]="2"
precondition_cmd[1]="cat /boot/config-\$(uname -r) |grep CONFIG_SUSPEND=y"
precondition_status[1]=""
precondition_expected_result[1]="CONFIG_SUSPEND=y"
precondition_operator[1]="2"

precondition_numero[2]="3"
precondition_cmd[2]="cat /boot/config-\$(uname -r) |grep CONFIG_SUSPEND_FREEZER=y"
precondition_status[2]=""
precondition_expected_result[2]="CONFIG_SUSPEND_FREEZER=y"
precondition_operator[2]="2"

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]="cat /sys/power/state |grep -o mem"
step_status[0]=""
step_expected_result1[0]="mem"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]="0"
step_iteration[0]=

test_type[1]="2"
step_numero[1]="2"
step_cmd[1]="cat /sys/power/state |grep -o disk"
step_status[1]=""
step_expected_result1[1]="disk"
step_expected_result2[1]=""
step_operator1[1]="2"
step_operator2[1]="0"
step_iteration[1]=

test_type[2]="2"
step_numero[2]="3"
step_cmd[2]="cat /sys/power/state |grep -o freeze "
step_status[2]=""
step_expected_result1[2]="freeze"
step_expected_result2[2]=""
step_operator1[2]="2"
step_operator2[2]=
step_iteration[2]=

##POSTCONDITIONS##

. ../../test_framework.sh
