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
# File:         POWER_MANAGEMENT_04_Check_intel_pstate_kernel_driver_is_initialized_statically.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=95
NAME="04 Check intel_pstate kernel driver is initialized statically"
AUTHOR=""
STATUS="Designed"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="Execute command:
dmesg |grep -E 'calling.*intel_pstate_init'|'initcall.*intel_pstate_init'

intel_pstate is initialized. Command returns something like:
[    2.723382] calling  intel_pstate_init+0x0/0x229 @ 1
[    2.723530] initcall intel_pstate_init+0x0/0x229 returned 0 after 141 usecs
"
OBJECTIVE="initcalls are used to initialize statically linked kernel drivers and subsystems and contribute a significant amount of time to the Linux boot process. We want to make sure Power kernel drivers are initialized. It is checked in the message buffer of the kernel (dmesg)."

TIMEOUT=0:00:00

##PRECONDITIONS##

precondition_numero[0]="1"
precondition_cmd[0]="cat /boot/config-\$(uname -r) |grep INTEL_PSTATE"
precondition_status[0]=""
precondition_expected_result[0]="CONFIG_X86_INTEL_PSTATE=y"
precondition_operator[0]="2"

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]="dmesg |grep \"initcall.*intel_pstate_init\" |grep -o \"returned 0\""
step_status[0]=""
step_expected_result1[0]="returned 0"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]="0"
step_iteration[0]=

##POSTCONDITIONS##

. ../../test_framework.sh
