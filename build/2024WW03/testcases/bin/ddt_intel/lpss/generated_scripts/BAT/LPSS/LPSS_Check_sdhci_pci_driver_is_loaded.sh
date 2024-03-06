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
# File:         LPSS_Check_sdhci_pci_driver_is_loaded.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-08-21 14:57:13
#

NUMBER=214
NAME="Check_sdhci_pci_driver_is_loaded"
AUTHOR=""
STATUS="Ready"
TYPE="BAT"
COMPONENT="LPSS"

DESCRIPTION="Check_sdhci_pci_driver_is_loaded"
OBJECTIVE=""

TIMEOUT=0:00:00

##PRECONDITIONS##

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]=". ../../executables/LPSS_check_drivers_are_loaded.sh sdhci-pci pci_driver"
step_status[0]="0"
step_expected_result1[0]=""
step_expected_result2[0]=""
step_operator1[0]="1"
step_operator2[0]="0"
step_iteration[0]=

##POSTCONDITIONS##

. ../../test_framework.sh
