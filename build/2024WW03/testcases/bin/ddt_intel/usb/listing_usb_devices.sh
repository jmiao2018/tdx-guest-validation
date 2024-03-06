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


# @desc This script checks that USB devices are reported correctly
# @params None
# @returns Fail the test if return code is non-zero (value set not found)

source "common.sh"  # Import do_cmd(), die() and other functions
############################# Functions ########################################
usage()
{
	cat <<-EOF >&2
	usage: ./${0##*/}
        -n NO_PARMS 	No parameters required.
	EOF
	exit 0
}

################################ CLI Params ####################################
# Please use getopts
while getopts  h: arg
do case $arg in
		h)	usage;;
		:)	die "$0: Must supply an argument to -$OPTARG.";;
		\?)	die "Invalid Option -$OPTARG ";;
esac
done
############################ Default Values for Params##########################
: ${MODULE:='uhci_hcd'}

########################### REUSABLE TEST LOGIC ################################
# Avoid using echo. Instead use print functions provided by st_log.sh

#Define Path to search for modules
DEVICE_PATH="/sys/kernel/debug/usb/devices"
DEV_FILE="usbdev.txt"
DEV_OUT="usbdev.out"
LSUSB_FILE="lsusb.txt"
LSUSB_OUT="lsusb.out"
# do_cmd() will check return code and fail the test if return code is non-zero.
# get usb devices info from 2 different points
cat $DEVICE_PATH | grep P: | awk -F "=" '{print $2 " " $3}'\
       | awk '{print $1 ":" $3}' > $DEV_FILE
sort -b $DEV_FILE>$DEV_OUT
cat $DEV_OUT
lsusb | awk '{print $6}'>$LSUSB_FILE
sort -b $LSUSB_FILE > $LSUSB_OUT
cat $LSUSB_OUT
# this step compares those 2 files and put the result in a variable
compare=`cmp $DEV_OUT $LSUSB_OUT`

if [ -z $compare ]; then
    test_print_trc "PASS"
else
    test_print_trc "FAIL: they is a difference between lsusb and sysfs"
    exit 1
fi
# lets clean work environnment
rm $LSUSB_FILE ;rm $DEV_FILE;rm $LSUSB_OUT;rm $DEV_OUT
exit $?
