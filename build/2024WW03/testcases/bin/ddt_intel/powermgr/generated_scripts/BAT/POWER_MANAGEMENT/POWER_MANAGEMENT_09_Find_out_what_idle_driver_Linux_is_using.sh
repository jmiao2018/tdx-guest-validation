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
# File:         POWER_MANAGEMENT_09_Find_out_what_idle_driver_Linux_is_using.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=98
NAME="09 Find out what idle driver Linux is using"
AUTHOR=""
STATUS="Ready"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="1.Execute command:
cat /sys/devices/system/cpu/cpuidle/current_driver

1.Command returns:
intel_idle"
OBJECTIVE="OS can request C-States either using the ACPI idle driver (acpi_idle) or through the use of the intel_idle driver.
intel_idle can request each of the individual Haswell c-states available, while acpi_idle can only request the ACPI C-States"

TIMEOUT=0:00:00

##PRECONDITIONS##

precondition_numero[0]="1"
precondition_cmd[0]="cat /boot/config-\$(uname -r) |grep INTEL_IDLE"
precondition_status[0]=""
precondition_expected_result[0]="CONFIG_INTEL_IDLE=y"
precondition_operator[0]="2"

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]=". ../../executables/idle_driver.sh"
step_status[0]=""
step_expected_result1[0]="0"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]=
step_iteration[0]=

##POSTCONDITIONS##

. ../../test_framework.sh
