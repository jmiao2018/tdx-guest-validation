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
# File:         POWER_MANAGEMENT_06_Check_intel_pstate_initialization_time_during_boot.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=96
NAME="06 Check intel_pstate initialization time during boot"
AUTHOR=""
STATUS="Ready"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="Execute commands:
dmesg |grep -E 'initcall.*intel_pstate_init' |grep -Po '(?<=after )[[:digit:]]* [^&]secs'

Commands return init times, e.g. 141 usecs
Value is lower than 50 ms"
OBJECTIVE="We want to make sure drivers are initialized with duration lower than 50 ms"

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
step_cmd[0]="dmesg |grep -E \"initcall.*intel_pstate_init\" |grep -Po \"(?<=after )[[:digit:]]*\""
step_status[0]=""
step_expected_result1[0]="50000"
step_expected_result2[0]=""
step_operator1[0]="5"
step_operator2[0]="0"
step_iteration[0]=

test_type[1]="2"
step_numero[1]="2"
step_cmd[1]="dmesg |grep -E \"initcall.*intel_pstate_init\" |grep -Po \"(?<=after )[[:digit:]]*\""
step_status[1]=""
step_expected_result1[1]="3"
step_expected_result2[1]=""
step_operator1[1]="4"
step_operator2[1]="0"
step_iteration[1]=

##POSTCONDITIONS##

. ../../test_framework.sh
