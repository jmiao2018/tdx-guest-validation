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


# @desc This script verify dev files exist on sysfs
# @params None
# @returns Fail the test if return code is non-zero (value set not found)

source "common.sh"  # Import do_cmd(), die() and other functions
############################# Functions ########################################
usage()
{
	cat <<-EOF >&2
	usage: ./${0##*/} [-t TYPE]
	EOF
	exit 0
}
################################ CLI Params ####################################
# Please use getopts
while getopts  :h: arg
do case $arg in
		h)      usage;;
		:)      die "$0: Must supply an argument to -$OPTARG.";;
		\?)     "Invalid Option -$OPTARG ";;
esac
done
############################ Default Values for Params##########################
########################### REUSABLE TEST LOGIC ################################
# Avoid using echo. Instead use print functions provided by st_log.sh
USB_PATH="/sys/bus/usb/devices"
REGEX='^[0-9]+-[1-9]:[0-9]+.[0-9]'
FILES=("async" "runtime_active_kids" "runtime_enabled" "runtime_status"
"runtime_usage")
# do_cmd() will check return code and fail the test if return code is non-zero.

for DEVICE in $(ls $USB_PATH |grep $REGEX)
do
    test_print_trc "Files For Controller: $DEVICE"
    for ENTRY_FILE in "${FILES[@]}"
    do
        do_cmd ls $USB_PATH/$DEVICE/power |grep "$ENTRY_FILE"
        if [ $? -ne 0 ];then
            test_print_trc "$ENTRY_FILE was not found on
            $USB_PATH/$DEVICE/power"
            exit 1
        fi
        test_print_trc "Entry File Found: $ENTRY_FILE"
    done
done
exit $?
