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
# File:         POWER_MANAGEMENT_21_Check_we_can_suspend_to_freeze_state_and_resume_-_iteration_2.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=84
NAME="21 Check we can suspend to freeze state and resume - iteration 2"
AUTHOR=""
STATUS="Ready"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="1. Execute commands as root:
rtcwake -m on -s 30
echo freeze > /sys/power/state
2. Wait 30 seconds and check resume state
3. Check screen, mouse and keyboard
4. Execute commands: 
dmesg |grep \"PM: suspend\"
dmesg |grep \"PM: resume\"

1. System goes into \"freeze\" mode, black screen, no backlight
2. System resumes automatically after 30s. Desktop or login screen is displayed.
3. Screen, Mouse and keyboard are responding
4. Logs include \"PM: suspend of devices complete after <x> msecs\" and \"PM: resume of devices complete after <x> msecs\""
OBJECTIVE="We want to make sure we can suspend the device to FREEZE, wake it up 30 seconds later. We will do it 3 times during BATs."

TIMEOUT=0:00:00

##PRECONDITIONS##

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]="sudo rtcwake -m on -s 30 & sudo echo freeze > /sys/power/state"
step_status[0]=""
step_expected_result1[0]=""
step_expected_result2[0]=""
step_operator1[0]="1"
step_operator2[0]="0"
step_iteration[0]=

test_type[1]="2"
step_numero[1]="2"
step_cmd[1]="dmesg |grep -o -m1 \"PM: Syncing filesystems ... done.\" |tail -1"
step_status[1]=""
step_expected_result1[1]="PM: Syncing filesystems ... done."
step_expected_result2[1]=""
step_operator1[1]="2"
step_operator2[1]="0"
step_iteration[1]=

test_type[2]="2"
step_numero[2]="3"
step_cmd[2]="dmesg |grep -o -m1 \"PM: Preparing system for freeze sleep\" |tail -1"
step_status[2]=""
step_expected_result1[2]="PM: Preparing system for freeze sleep"
step_expected_result2[2]=""
step_operator1[2]="2"
step_operator2[2]="0"
step_iteration[2]=

test_type[3]="2"
step_numero[3]="4"
step_cmd[3]="dmesg |grep -o -m1 \"PM: Entering freeze sleep\" |tail -1"
step_status[3]=""
step_expected_result1[3]="PM: Entering freeze sleep"
step_expected_result2[3]=""
step_operator1[3]="2"
step_operator2[3]="0"
step_iteration[3]=

test_type[4]="2"
step_numero[4]="5"
step_cmd[4]="dmesg |grep -o -m1 \"PM: suspend of devices complete after .*. msecs\" |sed \"s/[0-9]*[.][0-9]*/x/\" |tail -1"
step_status[4]=""
step_expected_result1[4]="PM: suspend of devices complete after x msecs"
step_expected_result2[4]=""
step_operator1[4]="2"
step_operator2[4]="0"
step_iteration[4]=

test_type[5]="2"
step_numero[5]="7"
step_cmd[5]="dmesg |grep -o -m1 \"PM: late suspend of devices complete after .*. msecs\" |sed \"s/[0-9]*[.][0-9]*/x/\" |tail -1"
step_status[5]=""
step_expected_result1[5]="PM: late suspend of devices complete after x msecs"
step_expected_result2[5]=""
step_operator1[5]="2"
step_operator2[5]="0"
step_iteration[5]=

test_type[6]="2"
step_numero[6]="8"
step_cmd[6]="dmesg |grep -o -m1 \"PM: noirq suspend of devices complete after .*. msecs\" |sed \"s/[0-9]*[.][0-9]*/x/\" |tail -1"
step_status[6]=""
step_expected_result1[6]="PM: noirq suspend of devices complete after x msecs"
step_expected_result2[6]=""
step_operator1[6]="2"
step_operator2[6]="0"
step_iteration[6]=

test_type[7]="2"
step_numero[7]="9"
step_cmd[7]="dmesg |grep -o -m1 \"PM: noirq resume of devices complete after .*. msecs\" |sed \"s/[0-9]*[.][0-9]*/x/\" |tail -1"
step_status[7]=""
step_expected_result1[7]="PM: noirq resume of devices complete after x msecs"
step_expected_result2[7]=""
step_operator1[7]="2"
step_operator2[7]="0"
step_iteration[7]=

test_type[8]="2"
step_numero[8]="10"
step_cmd[8]="dmesg |grep -o -m1 \"PM: early resume of devices complete after .*. msecs\" |sed \"s/[0-9]*[.][0-9]*/x/\" |tail -1"
step_status[8]=""
step_expected_result1[8]="PM: early resume of devices complete after x msecs"
step_expected_result2[8]=""
step_operator1[8]="2"
step_operator2[8]="0"
step_iteration[8]=

test_type[9]="2"
step_numero[9]="11"
step_cmd[9]="dmesg |grep -o -m1 \"PM: resume of devices complete after .*. msecs\" |sed \"s/[0-9]*[.][0-9]*/x/\" |tail -1"
step_status[9]=""
step_expected_result1[9]="PM: resume of devices complete after x msecs"
step_expected_result2[9]=""
step_operator1[9]="2"
step_operator2[9]="0"
step_iteration[9]=

test_type[10]="2"
step_numero[10]="13"
step_cmd[10]="dmesg |grep -o -m1 \"PM: Finishing wakeup.\" |tail -1"
step_status[10]=""
step_expected_result1[10]="PM: Finishing wakeup."
step_expected_result2[10]=""
step_operator1[10]="2"
step_operator2[10]="0"
step_iteration[10]=

##POSTCONDITIONS##

postcondition_numero[0]="1"
postcondition_cmd[0]="sleep 10"
postcondition_status[0]=""
postcondition_expected_result[0]=""
postcondition_operator[0]="1"

. ../../test_framework.sh
