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
# File:         POWER_MANAGEMENT_15_Check_cpufreq_kernel_configuration.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=101
NAME="15 Check cpufreq kernel configuration"
AUTHOR=""
STATUS="Designed"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="Execute commands:
1. cat /boot/config-\$(uname -r) |grep CONFIG_CPU_FREQ
2. cat /boot/config-\$(uname -r) |grep -i cpufreq

Commands return:
1.
CONFIG_CPU_FREQ=y
CONFIG_CPU_FREQ_GOV_COMMON=y
CONFIG_CPU_FREQ_STAT=y
CONFIG_CPU_FREQ_STAT_DETAILS=y
CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y
# CONFIG_CPU_FREQ_DEFAULT_GOV_POWERSAVE is not set
# CONFIG_CPU_FREQ_DEFAULT_GOV_USERSPACE is not set
# CONFIG_CPU_FREQ_DEFAULT_GOV_ONDEMAND is not set
# CONFIG_CPU_FREQ_DEFAULT_GOV_CONSERVATIVE is not set
CONFIG_CPU_FREQ_GOV_PERFORMANCE=y
CONFIG_CPU_FREQ_GOV_POWERSAVE=y
CONFIG_CPU_FREQ_GOV_USERSPACE=y
CONFIG_CPU_FREQ_GOV_ONDEMAND=y
CONFIG_CPU_FREQ_GOV_CONSERVATIVE=y
2.
CONFIG_X86_PCC_CPUFREQ=m
CONFIG_X86_ACPI_CPUFREQ=y
CONFIG_X86_ACPI_CPUFREQ_CPB=y

"
OBJECTIVE="We want to make sure cpufreq is well configured"

TIMEOUT=0:00:00

##PRECONDITIONS##

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]="cat /boot/config-\$(uname -r) |grep CONFIG_CPU_FREQ=y"
step_status[0]=""
step_expected_result1[0]="CONFIG_CPU_FREQ=y"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]="0"
step_iteration[0]=

test_type[1]="2"
step_numero[1]="2"
step_cmd[1]="cat /boot/config-\$(uname -r) |grep CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y"
step_status[1]=""
step_expected_result1[1]="CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y"
step_expected_result2[1]=""
step_operator1[1]="2"
step_operator2[1]="0"
step_iteration[1]=

test_type[2]="2"
step_numero[2]="3"
step_cmd[2]="cat /boot/config-\$(uname -r) |grep CONFIG_CPU_FREQ_GOV_PERFORMANCE=y"
step_status[2]=""
step_expected_result1[2]="CONFIG_CPU_FREQ_GOV_PERFORMANCE=y"
step_expected_result2[2]=""
step_operator1[2]="2"
step_operator2[2]="0"
step_iteration[2]=

test_type[3]="2"
step_numero[3]="4"
step_cmd[3]="cat /boot/config-\$(uname -r) |grep CONFIG_CPU_FREQ_GOV_POWERSAVE=y"
step_status[3]=""
step_expected_result1[3]="CONFIG_CPU_FREQ_GOV_POWERSAVE=y"
step_expected_result2[3]=""
step_operator1[3]="2"
step_operator2[3]="0"
step_iteration[3]=

##POSTCONDITIONS##

. ../../test_framework.sh
