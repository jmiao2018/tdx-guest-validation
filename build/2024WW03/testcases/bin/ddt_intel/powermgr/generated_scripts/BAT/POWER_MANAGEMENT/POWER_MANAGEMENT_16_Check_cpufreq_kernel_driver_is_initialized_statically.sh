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
# File:         POWER_MANAGEMENT_16_Check_cpufreq_kernel_driver_is_initialized_statically.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=102
NAME="16 Check cpufreq kernel driver is initialized statically"
AUTHOR=""
STATUS="Designed"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="Execute commands:
1. dmesg |grep -E 'calling.*cpufreq_core_init'|'initcall.*cpufreq_core_init'
2. dmesg |grep -E 'calling.*cpufreq_gov_performance_init'|'initcall.*cpufreq_gov_performance_init'
3. dmesg |grep -E 'calling.*cpufreq_gov_powersave_init'|'initcall.*cpufreq_gov_powersave_init'"
OBJECTIVE="Commands return, e.g.:
1.
[    0.149974] calling  cpufreq_core_init+0x0/0x2c @ 1
[    0.149979] initcall cpufreq_core_init+0x0/0x2c returned 0 after 0 usecs
2.
[    0.516697] calling  cpufreq_gov_performance_init+0x0/0x12 @ 1
[    0.516705] initcall cpufreq_gov_performance_init+0x0/0x12 returned 0 after 1 usecs
3.
[    1.341110] calling  cpufreq_gov_powersave_init+0x0/0x12 @ 1
[    1.341118] initcall cpufreq_gov_powersave_init+0x0/0x12 returned 0 after 1 usecs"

TIMEOUT=0:00:00

##PRECONDITIONS##

precondition_numero[0]="1"
precondition_cmd[0]="cat /boot/config-\$(uname -r) |grep CONFIG_CPU_FREQ=y"
precondition_status[0]=""
precondition_expected_result[0]="CONFIG_CPU_FREQ=y"
precondition_operator[0]="2"

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]="dmesg |grep \"initcall.*cpufreq_core_init\" |grep -o \"returned 0\""
step_status[0]=""
step_expected_result1[0]="returned 0"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]="0"
step_iteration[0]=

test_type[1]="2"
step_numero[1]="2"
step_cmd[1]="dmesg |grep \"initcall.*cpufreq_gov_performance_init\" |grep -o \"returned 0\""
step_status[1]=""
step_expected_result1[1]="returned 0"
step_expected_result2[1]=""
step_operator1[1]="2"
step_operator2[1]="0"
step_iteration[1]=

test_type[2]="2"
step_numero[2]="3"
step_cmd[2]="dmesg |grep \"initcall.*cpufreq_gov_powersave_init\" |grep -o \"returned 0\""
step_status[2]=""
step_expected_result1[2]="returned 0"
step_expected_result2[2]=""
step_operator1[2]="2"
step_operator2[2]="0"
step_iteration[2]=

##POSTCONDITIONS##

. ../../test_framework.sh
