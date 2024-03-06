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
# File:         POWER_MANAGEMENT_18_Check_cpufreq_sysfs_interface.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=104
NAME="18 Check cpufreq sysfs interface"
AUTHOR=""
STATUS="Designed"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="The cpufreq interface is located in a subdirectory \"cpufreq\" within the cpu-device directory
(e.g. /sys/devices/system/cpu/cpu0/cpufreq/ for the first CPU).

1. Execute command:
ls /sys/devices/system/cpu/cpu0/cpufreq/

1. Command returns:
affected_cpus
cpuinfo_max_freq
cpuinfo_transition_latency
scaling_available_governors
scaling_governor
scaling_min_freq
cpuinfo_cur_freq
cpuinfo_min_freq
related_cpus
scaling_driver
scaling_max_freq
scaling_setspeed"
OBJECTIVE=""

TIMEOUT=0:00:00

##PRECONDITIONS##

precondition_numero[0]="1"
precondition_cmd[0]="cat /boot/config-\$(uname -r) |grep CONFIG_CPU_FREQ=y"
precondition_status[0]=""
precondition_expected_result[0]="CONFIG_CPU_FREQ=y"
precondition_operator[0]="2"

precondition_numero[1]="2"
precondition_cmd[1]="dmesg |grep \"initcall.*cpufreq_core_init\" |grep -o \"returned 0\""
precondition_status[1]=""
precondition_expected_result[1]="returned 0"
precondition_operator[1]="2"

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]="ls /sys/devices/system/cpu/cpu0/cpufreq/ |grep affected_cpus"
step_status[0]=""
step_expected_result1[0]="affected_cpus"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]="0"
step_iteration[0]=

test_type[1]="2"
step_numero[1]="2"
step_cmd[1]="ls /sys/devices/system/cpu/cpu0/cpufreq/ |grep cpuinfo_max_freq"
step_status[1]=""
step_expected_result1[1]="cpuinfo_max_freq"
step_expected_result2[1]=""
step_operator1[1]="2"
step_operator2[1]="0"
step_iteration[1]=

test_type[2]="2"
step_numero[2]="3"
step_cmd[2]="ls /sys/devices/system/cpu/cpu0/cpufreq/ |grep cpuinfo_transition_latency"
step_status[2]=""
step_expected_result1[2]="cpuinfo_transition_latency"
step_expected_result2[2]=""
step_operator1[2]="2"
step_operator2[2]="0"
step_iteration[2]=

test_type[3]="2"
step_numero[3]="4"
step_cmd[3]="ls /sys/devices/system/cpu/cpu0/cpufreq/ |grep scaling_available_governors"
step_status[3]=""
step_expected_result1[3]="scaling_available_governors"
step_expected_result2[3]=""
step_operator1[3]="2"
step_operator2[3]="0"
step_iteration[3]=

test_type[4]="2"
step_numero[4]="5"
step_cmd[4]="ls /sys/devices/system/cpu/cpu0/cpufreq/ |grep scaling_governor"
step_status[4]=""
step_expected_result1[4]="scaling_governor"
step_expected_result2[4]=""
step_operator1[4]="2"
step_operator2[4]="0"
step_iteration[4]=

test_type[5]="2"
step_numero[5]="6"
step_cmd[5]="ls /sys/devices/system/cpu/cpu0/cpufreq/ |grep scaling_min_freq"
step_status[5]=""
step_expected_result1[5]="scaling_min_freq"
step_expected_result2[5]=""
step_operator1[5]="2"
step_operator2[5]="0"
step_iteration[5]=

test_type[6]="2"
step_numero[6]="7"
step_cmd[6]="ls /sys/devices/system/cpu/cpu0/cpufreq/ |grep cpuinfo_cur_freq"
step_status[6]=""
step_expected_result1[6]="cpuinfo_cur_freq"
step_expected_result2[6]=""
step_operator1[6]="2"
step_operator2[6]="0"
step_iteration[6]=

test_type[7]="2"
step_numero[7]="8"
step_cmd[7]="ls /sys/devices/system/cpu/cpu0/cpufreq/ |grep cpuinfo_min_freq"
step_status[7]=""
step_expected_result1[7]="cpuinfo_min_freq"
step_expected_result2[7]=""
step_operator1[7]="2"
step_operator2[7]="0"
step_iteration[7]=

test_type[8]="2"
step_numero[8]="9"
step_cmd[8]="ls /sys/devices/system/cpu/cpu0/cpufreq/ |grep related_cpus"
step_status[8]=""
step_expected_result1[8]="related_cpus"
step_expected_result2[8]=""
step_operator1[8]="2"
step_operator2[8]="0"
step_iteration[8]=

test_type[9]="2"
step_numero[9]="10"
step_cmd[9]="ls /sys/devices/system/cpu/cpu0/cpufreq/ |grep scaling_driver"
step_status[9]=""
step_expected_result1[9]="scaling_driver"
step_expected_result2[9]=""
step_operator1[9]="2"
step_operator2[9]="0"
step_iteration[9]=

test_type[10]="2"
step_numero[10]="11"
step_cmd[10]="ls /sys/devices/system/cpu/cpu0/cpufreq/ |grep scaling_max_freq"
step_status[10]=""
step_expected_result1[10]="scaling_max_freq"
step_expected_result2[10]=""
step_operator1[10]="2"
step_operator2[10]="0"
step_iteration[10]=

test_type[11]="2"
step_numero[11]="12"
step_cmd[11]="ls /sys/devices/system/cpu/cpu0/cpufreq/ |grep scaling_setspeed"
step_status[11]=""
step_expected_result1[11]="scaling_setspeed"
step_expected_result2[11]=""
step_operator1[11]="2"
step_operator2[11]="0"
step_iteration[11]=

##POSTCONDITIONS##

. ../../test_framework.sh
