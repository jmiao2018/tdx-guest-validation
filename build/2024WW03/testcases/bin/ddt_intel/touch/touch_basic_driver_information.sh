#!/bin/bash
#
# Copyright 2015 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate Touch component
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Jose Perez Carranza <jose.perez.carranza@intel.com>
#
# History:
#             May. 25, 2015 - (jose.perez.carranza) Creation


# @desc: This script checks different properties of the assigned touch
#        driver
# @params:
#          - t) Type of test property to be validated
# @returns Fail the test if return code is non-zero (value set not found)

source "common.sh"  # Import do_cmd(), die() and other functions
source "touch_functions.sh" #All needed functions for touch test cases

usage()
{
	cat <<-EOF >&2
	usage: ./${0##*/} [-t TEST]
	-t TEST 	Test to be apllied as INPUT, SYSFS etc
	EOF
	exit 0
}

################################ CLI Params ####################################
# Please use getopts
while getopts  :t:h arg
do case $arg in
        t)      TEST="$OPTARG";;
        h)      usage;;
        :)      die "$0: Must supply an argument to -$OPTARG.";;
        \?)     die "Invalid Option -$OPTARG ";;
esac
done

############################ Utilities ###############################
# Call functions from "touch_utilities.sh" to get properties of event

#RELEASE=1
#single_touch $RELEASE $TRACKING_ID $POSITION_X $POSITION_Y $TOUCH_MAJOR
#do_cmd echo $POSITION_X - $POSITION_Y
#TOUCHES=3
#RELEASE_ALL=1
#multi_touch #$TOUCHES $RELEASE $TRACKING_ID $POSITION_X $POSITION_Y $TOUCH_MAJOR

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.

#Decide what should be validated according to the parameter received
case $TEST in
         T_INPUT) # Verify that there is assigned input for a touch screen
                 if [[ $TOUCH_INPUT =~ event[0-9]+$ ]]; then
                    test_print_trc "====> Event assigned is $TOUCH_INPUT"
                    exit 0
                 else
                    test_print_trc "====> Event not found for Touch Device"
                    exit 1
                 fi
               ;;
         T_NAME) # Verify that assigned name is equal to driver name defined depending of the platform
                 if [[ $TOUCH_NAME =~ $TOUCH_DRIVER ]]; then
                      test_print_trc "====> Assigned driver name is correct loaded on devices $TOUCH_DRIVER = $TOUCH_NAME"
                      exit 0
                 else
                      test_print_trc "====> Assigned driver name is not correct loaded on devices $TOUCH_DRIVER <> $TOUCH_NAME"
                      exit 1
               fi
               ;;
        T_SYSFS) # Verify that event is correctly registered in reported SYSFS path
                 do_cmd ls -l "/sys/"$TOUCH_SYSFS |grep "$INPUT"
                 if [ $? -ne 0 ]; then
                    test_print_trc "====> $INPUT not present in $TOUCH_SYSFS"
                    exit 1
                 fi
                 exit $?
               ;;
         T_PHYS) # Verify that physical path is correctly reported by device and found on SYSFS fo I2C
                 if [[ -z "$TOUCH_PHYS" ]]; then
                     test_print_trc "====> Physical Path  is empty"
                     exit 1
                 else
                     do_cmd ls -l "/sys"$I2C_PATH | grep "$TOUCH_PHYS"
                     if [ $? -ne 0 ]; then
                         test_print_trc "====> Physical Path  - $TOUCH_PHYS - not found"
                     exit 1
                     fi
                     exit $?
                 fi
                 ;;
         T_CONF) # Verify that configuration files are correctly loaded according to driver type
                 do_cmd ls $IDC_PATH | grep "$TOUCH_NAME.idc"
                 if [ $? -ne 0 ]; then
                    test_print_trc "====> .idc file not found for $TOUCH_NAME "
                    exit 1
                 fi
                 exit $?
                 ;;
       T_DRIVER) # Verify that driver is correctly registered on device properties and is found
                 # in given symbolic link registered on i2c bus drivers
                 do_cmd cd "/sys/"$TOUCH_SYSFS
                 do_cmd cd $TOUCH_DEVICE_PATH
                 TOUCH_DRVER_PATH=`do_cmd ls -l | tr '\n' ' ' | \
                                   sed 's/^.*'driver\ '/'driver\ '/' | \
                                   awk '/'driver\ '/{print $3}'`
                 do_cmd cd $TOUCH_DRVER_PATH
                 if [ $? -ne 0 ]; then
                    test_print_trc "====> Driver path not found - $TOUCH_DRVER_PATH "
                    exit 1
                 fi
                 exit $?
                 ;;
     T_FIRMWARE) # Verify that firmware is correctly registered on device properties and is found
                 # in given symbolic link registered on acpi node
                 do_cmd cd "/sys/"$TOUCH_SYSFS
                 do_cmd cd $TOUCH_DEVICE_PATH
                 TOUCH_FIRMWARE_PATH=`do_cmd ls -l | tr '\n' ' ' | \
                                   sed 's/^.*'firmware'/'firmware'/' | \
                                   awk '/'firmware'/{print $3}'`
                 do_cmd cd $TOUCH_FIRMWARE_PATH
                 if [ $? -ne 0 ]; then
                    test_print_trc "====> Firmware path not found - $TOUCH_FIRMWARE_PATH "
                    exit 1
                 fi
                 exit $?
                 ;;
              :) die "$0: Must supply an argument to -$OPTARG.";;
             \?) die "Invalid Option -$OPTARG ";;
esac
