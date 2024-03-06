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
# File:         POWER_MANAGEMENT_08_Check_intel_pstate_sysfs_interface.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=97
NAME="08 Check intel_pstate sysfs interface"
AUTHOR=""
STATUS="Ready"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="Execute command:
1. \$ ls -l /sys/devices/system/cpu/intel_pstate/"
OBJECTIVE="Information about devices and drivers is displayed.
Command return something like:
1. max_perf_pct, min_perf_pct, no_turbo"

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
step_cmd[0]="ls /sys/devices/system/cpu |grep intel_pstate"
step_status[0]=""
step_expected_result1[0]="intel_pstate"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]="0"
step_iteration[0]=

test_type[1]="2"
step_numero[1]="2"
step_cmd[1]="ls /sys/devices/system/cpu/intel_pstate/ |grep max_perf_pct"
step_status[1]=""
step_expected_result1[1]="max_perf_pct"
step_expected_result2[1]=""
step_operator1[1]="2"
step_operator2[1]="0"
step_iteration[1]=

test_type[2]="2"
step_numero[2]="3"
step_cmd[2]="ls /sys/devices/system/cpu/intel_pstate/ |grep min_perf_pct"
step_status[2]=""
step_expected_result1[2]="min_perf_pct"
step_expected_result2[2]=""
step_operator1[2]="2"
step_operator2[2]="0"
step_iteration[2]=

test_type[3]="2"
step_numero[3]="4"
step_cmd[3]="ls /sys/devices/system/cpu/intel_pstate/ |grep no_turbo"
step_status[3]=""
step_expected_result1[3]="no_turbo"
step_expected_result2[3]=""
step_operator1[3]="2"
step_operator2[3]="0"
step_iteration[3]=

##POSTCONDITIONS##

. ../../test_framework.sh
