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
# File:         POWER_MANAGEMENT_13_Check_the_size_of_the_image_created_by_the_suspend-to-disk_mechanism.sh
#
# Description:  This script will execute a set of step designed in WATS (Web
#               Automation Test System).
#
# Author(s):    TGen - The Amazing Test Generator
#
# Date:         2015-07-09 10:33:37
#

NUMBER=77
NAME="13 Check the size of the image created by the suspend-to-disk mechanism"
AUTHOR=""
STATUS="Ready"
TYPE="BAT"
COMPONENT="Power Management"

DESCRIPTION="1. Execute command:
cat /sys/power/image_size
2. Execute command:
cat /proc/meminfo |grep MemTotal
3. Check image size is 2/5 of available RAM

1. Reading from this file will display the current image size limit, which
is set to 2/5 of available RAM by default. Command returns, e.g.: 1553981440
2. Command returns the total installed ram, e.g.: 3804132 kB
3. Image size is 2/5 of available RAM, e.g.: 1553981440*5/2=3884953600"
OBJECTIVE="/sys/power/image_size controls the size of the image created by
the suspend-to-disk mechanism.  It can be written a string
representing a non-negative integer that will be used as an upper
limit of the image size, in bytes.  The suspend-to-disk mechanism will
do its best to ensure the image size will not exceed that number.  However,
if this turns out to be impossible, it will try to suspend anyway using the
smallest image possible.  In particular, if \"0\" is written to this file, the
suspend image will be as small as possible.

Reading from this file will display the current image size limit, which
is set to 2/5 of available RAM by default."

TIMEOUT=0:00:00

##PRECONDITIONS##

##STEPS##

test_type[0]="2"
step_numero[0]="1"
step_cmd[0]=". ../../executables/size_image.sh"
step_status[0]=""
step_expected_result1[0]="0"
step_expected_result2[0]=""
step_operator1[0]="2"
step_operator2[0]="0"
step_iteration[0]=

##POSTCONDITIONS##

. ../../test_framework.sh
