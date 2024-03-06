#! /bin/sh
#
# Copyright 2015 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate USB component
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
#             Rogelio Ceja <rogelio.ceja@intel.com>
#
# History:
#             May. 18, 2015 - (rogelio.ceja)Creation


# @desc This script  exercises new_id and remove_id usb sysfs exposure files
# @params Type: to choose new_id or remove_id
# @returns Fail the test if return code is non-zero (value set not found)

source "common.sh"  # Import do_cmd(), die() and other functions
############################# Functions ########################################
usage()
{
	cat <<-EOF >&2
	usage: ./${0##*/} [-t TYPE]
        -m MODULE	Module you want to verify is present.
	EOF
	exit 0
}
################################ CLI Params ####################################
# Please use getopts
while getopts  t:m:h: arg
do case $arg in
		t)      TYPE="$OPTARG";;
		h)      usage;;
		:)      die "$0: Must supply an argument to -$OPTARG.";;
		\?)     "Invalid Option -$OPTARG ";;
esac
done
############################ Default Values for Params##########################
: ${TYPE:='add_id'}
########################### REUSABLE TEST LOGIC ################################
# Avoid using echo. Instead use print functions provided by st_log.sh
USB_PATH="/sys/bus/usb/devices"
ID="8086 10f5"
REGEX='^[0-9]-[0-9]:[0-9].[0-9]$'
# do_cmd() will check return code and fail the test if return code is non-zero.
case "$TYPE" in

    add_id)
        for entry in  $(ls $USB_PATH |grep $REGEX)
        do
            echo "$ID" > $USB_PATH/$entry/driver/new_id
            if [ $? -ne 0 ]; then
                test_print_trc "New id $ID was not able to be added"
                exit 1
            else
                test_print_trc  "Check if $ID was added on list:"
                do_cmd cat $USB_PATH/$entry/driver/new_id | grep "$ID"
        fi
        done
    ;;

    remove_id)
        for entry in  $(ls $USB_PATH |grep $REGEX)
        do
            test_print_trc "Check if $ID is on list:"
            do_cmd cat $USB_PATH/$entry/driver/new_id |grep "$ID"
            echo "$ID" > $USB_PATH/$entry/driver/remove_id
            if [ $? -ne 0 ]; then
                test_print_trc "Id $ID was not able to be removed"
                exit 1
            fi
        done
        do_cmd cat $USB_PATH/$entry/driver/new_id |grep "$ID"
        if [  $? -eq 0 ]; then
            test_print_trc "Id $ID was not removed"
            exit 1
        fi
    ;;
esac
exit $?
