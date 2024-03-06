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
# File:         POWER_MANAGEMENT_02_Check_in_kernel_config_that_INTEL_PSTATE_is_well_configured.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=94
NAME="02 Check in kernel config that INTEL_PSTATE is well configured"
AUTHOR=""
STATUS="Designed"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="Execute commands:
cat /boot/config-\$(uname -r) |grep INTEL_PSTATE

Commands return:
CONFIG_X86_INTEL_PSTATE=y"
OBJECTIVE="We want to make sure intel_pstate is well configured"

TIMEOUT=0:00:00

##PRECONDITIONS##

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]="cat /boot/config-\$(uname -r) |grep INTEL_PSTATE"
step_status[0]=""
step_expected_result1[0]="CONFIG_X86_INTEL_PSTATE=y"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]=
step_iteration[0]=

##POSTCONDITIONS##

. ../../test_framework.sh
