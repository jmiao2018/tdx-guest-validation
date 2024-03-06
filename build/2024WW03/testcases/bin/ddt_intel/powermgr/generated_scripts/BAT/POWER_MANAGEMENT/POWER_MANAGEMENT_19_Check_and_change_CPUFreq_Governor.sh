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
# File:         POWER_MANAGEMENT_19_Check_and_change_CPUFreq_Governor.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=100
NAME="19 Check and change CPUFreq Governor"
AUTHOR=""
STATUS="Ready"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="1. Check available governors with command:
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
2. Check current governor with command:
grep . /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
3. Set governor to another one, e.g. powersave:
sudo -s
echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
4. Check with:
grep . /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

1. Command returns, e.g.:
performance powersave
2. Command returns for each cpu id, e.g.:
performance
3. No error
4. Command returns for each cpu id:
powersave"
OBJECTIVE="The CPUfreq governor performance sets the CPU statically to the highest frequency within the borders of scaling_min_freq and scaling_max_freq.
The CPUfreq governor powersave sets the CPU statically to the lowest frequency within the borders of scaling_min_freq and scaling_max_freq."

TIMEOUT=0:00:00

##PRECONDITIONS##

precondition_numero[0]="1"
precondition_cmd[0]="cat /boot/config-\$(uname -r) |grep CONFIG_CPU_FREQ=y"
precondition_status[0]=""
precondition_expected_result[0]="CONFIG_CPU_FREQ=y"
precondition_operator[0]="2"

precondition_numero[1]="2"
precondition_cmd[1]="cat /boot/config-\$(uname -r) |grep CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y"
precondition_status[1]=""
precondition_expected_result[1]="CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y"
precondition_operator[1]="2"

precondition_numero[2]="3"
precondition_cmd[2]="cat /boot/config-\$(uname -r) |grep CONFIG_CPU_FREQ_GOV_PERFORMANCE=y"
precondition_status[2]=""
precondition_expected_result[2]="CONFIG_CPU_FREQ_GOV_PERFORMANCE=y"
precondition_operator[2]="2"

precondition_numero[3]="4"
precondition_cmd[3]="cat /boot/config-\$(uname -r) |grep CONFIG_CPU_FREQ_GOV_POWERSAVE=y"
precondition_status[3]=""
precondition_expected_result[3]="CONFIG_CPU_FREQ_GOV_POWERSAVE=y"
precondition_operator[3]="2"

precondition_numero[4]="5"
precondition_cmd[4]="dmesg |grep \"initcall.*cpufreq_core_init\" |grep -o \"returned 0\""
precondition_status[4]=""
precondition_expected_result[4]="returned 0"
precondition_operator[4]="2"

precondition_numero[5]="6"
precondition_cmd[5]="dmesg |grep \"initcall.*cpufreq_gov_performance_init\" |grep -o \"returned 0\""
precondition_status[5]=""
precondition_expected_result[5]="returned 0"
precondition_operator[5]="2"

precondition_numero[6]="7"
precondition_cmd[6]="dmesg |grep \"initcall.*cpufreq_gov_powersave_init\" |grep -o \"returned 0\""
precondition_status[6]=""
precondition_expected_result[6]="returned 0"
precondition_operator[6]="2"

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]="cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors |grep -o performance"
step_status[0]=""
step_expected_result1[0]="performance"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]="0"
step_iteration[0]=

test_type[1]="2"
step_numero[1]="2"
step_cmd[1]="cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors |grep -o powersave"
step_status[1]=""
step_expected_result1[1]="powersave"
step_expected_result2[1]=""
step_operator1[1]="2"
step_operator2[1]="0"
step_iteration[1]=

test_type[2]="2"
step_numero[2]="3"
step_cmd[2]="cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor |grep performance"
step_status[2]=""
step_expected_result1[2]="performance"
step_expected_result2[2]=""
step_operator1[2]="2"
step_operator2[2]="0"
step_iteration[2]=

test_type[3]="2"
step_numero[3]="4"
step_cmd[3]="cat /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor |grep performance"
step_status[3]=""
step_expected_result1[3]="performance"
step_expected_result2[3]=""
step_operator1[3]="2"
step_operator2[3]="0"
step_iteration[3]=

test_type[4]="2"
step_numero[4]="5"
step_cmd[4]="cat /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor |grep performance"
step_status[4]=""
step_expected_result1[4]="performance"
step_expected_result2[4]=""
step_operator1[4]="2"
step_operator2[4]="0"
step_iteration[4]=

test_type[5]="2"
step_numero[5]="6"
step_cmd[5]="cat /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor |grep performance"
step_status[5]=""
step_expected_result1[5]="performance"
step_expected_result2[5]=""
step_operator1[5]="2"
step_operator2[5]="0"
step_iteration[5]=

test_type[6]="2"
step_numero[6]="7"
step_cmd[6]="echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
step_status[6]=""
step_expected_result1[6]=""
step_expected_result2[6]=""
step_operator1[6]="1"
step_operator2[6]="0"
step_iteration[6]=

test_type[7]="2"
step_numero[7]="8"
step_cmd[7]="echo powersave > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor"
step_status[7]=""
step_expected_result1[7]=""
step_expected_result2[7]=""
step_operator1[7]="1"
step_operator2[7]="0"
step_iteration[7]=

test_type[8]="2"
step_numero[8]="9"
step_cmd[8]="echo powersave > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor"
step_status[8]=""
step_expected_result1[8]=""
step_expected_result2[8]=""
step_operator1[8]="1"
step_operator2[8]="0"
step_iteration[8]=

test_type[9]="2"
step_numero[9]="10"
step_cmd[9]="echo powersave > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor"
step_status[9]=""
step_expected_result1[9]=""
step_expected_result2[9]=""
step_operator1[9]="1"
step_operator2[9]="0"
step_iteration[9]=

test_type[10]="2"
step_numero[10]="11"
step_cmd[10]="cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor |grep powersave"
step_status[10]=""
step_expected_result1[10]="powersave"
step_expected_result2[10]=""
step_operator1[10]="2"
step_operator2[10]="0"
step_iteration[10]=

test_type[11]="2"
step_numero[11]="12"
step_cmd[11]="cat /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor |grep powersave"
step_status[11]=""
step_expected_result1[11]="powersave"
step_expected_result2[11]=""
step_operator1[11]="2"
step_operator2[11]="0"
step_iteration[11]=

test_type[12]="2"
step_numero[12]="13"
step_cmd[12]="cat /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor |grep powersave"
step_status[12]=""
step_expected_result1[12]="powersave"
step_expected_result2[12]=""
step_operator1[12]="2"
step_operator2[12]="0"
step_iteration[12]=

test_type[13]="2"
step_numero[13]="14"
step_cmd[13]="cat /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor |grep powersave"
step_status[13]=""
step_expected_result1[13]="powersave"
step_expected_result2[13]=""
step_operator1[13]="2"
step_operator2[13]="0"
step_iteration[13]=

test_type[14]="2"
step_numero[14]="15"
step_cmd[14]="cat /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor |grep powersave"
step_status[14]=""
step_expected_result1[14]="powersave"
step_expected_result2[14]=""
step_operator1[14]="2"
step_operator2[14]="0"
step_iteration[14]=

##POSTCONDITIONS##

. ../../test_framework.sh
