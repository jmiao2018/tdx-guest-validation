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
# File:         POWER_MANAGEMENT_07_Check_intel_idle_sysfs_interface.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=74
NAME="07 Check intel_idle sysfs interface"
AUTHOR=""
STATUS="Ready"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="Execute commands:
1. \$ ls -l /sys/devices/system/cpu/
2. \$ ls -l /sys/devices/system/cpu/cpuidle/

Information about devices and drivers is displayed.
Commands return something like:
1. cpu0, cpu1, cpu2, cpu3, cpuidle, intel_pstate, kernel_max, microcode, modalias, offline, online, possible, power, present, probe, release, uevent
2. current_driver, current_governor_ro"
OBJECTIVE="Check sysfs exports information about devices and drivers (intel_idle) from the kernel device model to user space"

TIMEOUT=0:00:00

##PRECONDITIONS##

precondition_numero[0]="1"
precondition_cmd[0]="cat /boot/config-\$(uname -r) |grep INTEL_IDLE"
precondition_status[0]=""
precondition_expected_result[0]="CONFIG_INTEL_IDLE=y"
precondition_operator[0]="2"

precondition_numero[1]="2"
precondition_cmd[1]="dmesg |grep \"initcall.*intel_idle_init\" |grep -o \"returned 0\""
precondition_status[1]=""
precondition_expected_result[1]="returned 0"
precondition_operator[1]="2"

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]="ls /sys/devices/system/cpu |grep cpuidle"
step_status[0]=""
step_expected_result1[0]="cpuidle"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]="0"
step_iteration[0]=

test_type[1]="2"
step_numero[1]="3"
step_cmd[1]="ls /sys/devices/system/cpu |grep power"
step_status[1]=""
step_expected_result1[1]="power"
step_expected_result2[1]=""
step_operator1[1]="2"
step_operator2[1]="0"
step_iteration[1]=

test_type[2]="2"
step_numero[2]="4"
step_cmd[2]="ls /sys/devices/system/cpu/cpuidle/ |grep current_driver"
step_status[2]=""
step_expected_result1[2]="current_driver"
step_expected_result2[2]=""
step_operator1[2]="2"
step_operator2[2]="0"
step_iteration[2]=

test_type[3]="2"
step_numero[3]="5"
step_cmd[3]="ls /sys/devices/system/cpu/cpuidle/ |grep current_governor_ro"
step_status[3]=""
step_expected_result1[3]="current_governor_ro"
step_expected_result2[3]=""
step_operator1[3]="2"
step_operator2[3]="0"
step_iteration[3]=

test_type[4]="2"
step_numero[4]="9"
step_cmd[4]="ls /sys/devices/system/cpu/power/ |grep async"
step_status[4]=""
step_expected_result1[4]="async"
step_expected_result2[4]=""
step_operator1[4]="2"
step_operator2[4]="0"
step_iteration[4]=

test_type[5]="2"
step_numero[5]="10"
step_cmd[5]="ls /sys/devices/system/cpu/power/ |grep autosuspend_delay_ms"
step_status[5]=""
step_expected_result1[5]="autosuspend_delay_ms"
step_expected_result2[5]=""
step_operator1[5]="2"
step_operator2[5]="0"
step_iteration[5]=

test_type[6]="2"
step_numero[6]="11"
step_cmd[6]="ls /sys/devices/system/cpu/power/ |grep control"
step_status[6]=""
step_expected_result1[6]="control"
step_expected_result2[6]=""
step_operator1[6]="2"
step_operator2[6]="0"
step_iteration[6]=

test_type[7]="2"
step_numero[7]="12"
step_cmd[7]="ls /sys/devices/system/cpu/power/ |grep runtime_active_kids"
step_status[7]=""
step_expected_result1[7]="runtime_active_kids"
step_expected_result2[7]=""
step_operator1[7]="2"
step_operator2[7]="0"
step_iteration[7]=

test_type[8]="2"
step_numero[8]="13"
step_cmd[8]="ls /sys/devices/system/cpu/power/ |grep runtime_active_time"
step_status[8]=""
step_expected_result1[8]="runtime_active_time"
step_expected_result2[8]=""
step_operator1[8]="2"
step_operator2[8]="0"
step_iteration[8]=

test_type[9]="2"
step_numero[9]="14"
step_cmd[9]="ls /sys/devices/system/cpu/power/ |grep runtime_enabled"
step_status[9]=""
step_expected_result1[9]="runtime_enabled"
step_expected_result2[9]=""
step_operator1[9]="2"
step_operator2[9]="0"
step_iteration[9]=

test_type[10]="2"
step_numero[10]="15"
step_cmd[10]="ls /sys/devices/system/cpu/power/ |grep runtime_status"
step_status[10]=""
step_expected_result1[10]="runtime_status"
step_expected_result2[10]=""
step_operator1[10]="2"
step_operator2[10]="0"
step_iteration[10]=

test_type[11]="2"
step_numero[11]="16"
step_cmd[11]="ls /sys/devices/system/cpu/power/ |grep runtime_suspended_time"
step_status[11]=""
step_expected_result1[11]="runtime_suspended_time"
step_expected_result2[11]=""
step_operator1[11]="2"
step_operator2[11]="0"
step_iteration[11]=

test_type[12]="2"
step_numero[12]="17"
step_cmd[12]="ls /sys/devices/system/cpu/power/ |grep runtime_usage"
step_status[12]=""
step_expected_result1[12]="runtime_usage"
step_expected_result2[12]=""
step_operator1[12]="2"
step_operator2[12]="0"
step_iteration[12]=

##POSTCONDITIONS##

. ../../test_framework.sh
