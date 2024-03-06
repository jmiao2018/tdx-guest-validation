#!/bin/bash
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
# File:         USB_HOST_Bulk_type_transmission_high_speed_mass_storage.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-16 11:32:45
#

NUMBER=198
NAME="Bulk_type_transmission_high_speed_mass_storage"
AUTHOR=""
STATUS="Ready"
TYPE="BAT"
COMPONENT="USB_HOST"

DESCRIPTION="Bulk_type_transmission_high_speed_mass_storage"
OBJECTIVE=""

TIMEOUT=0:00:00

##PRECONDITIONS##

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]=". ../../executables/Bulk_type_transmission_high_speed_mass_storage.sh"
step_status[0]="0"
step_expected_result1[0]=""
step_expected_result2[0]=""
step_operator1[0]="1"
step_operator2[0]="0"
step_iteration[0]=

##POSTCONDITIONS##

. ../../test_framework.sh
