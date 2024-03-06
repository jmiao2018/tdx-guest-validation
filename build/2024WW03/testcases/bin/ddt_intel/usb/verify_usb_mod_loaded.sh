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


# @desc This script checks that USB  modules are correct loaded in /sys/module/
# @params None
# @returns Fail the test if return code is non-zero (value set not found)

source "common.sh"  # Import do_cmd(), die() and other functions
############################# Functions ########################################
usage()
{
	cat <<-EOF >&2
	usage: ./${0##*/} [-m MODULE]
        -m MODULE	Module you want to verify is present.
	EOF
	exit 0
}

################################ CLI Params ####################################
# Please use getopts
while getopts  m:h: arg
do case $arg in
		m)  MODULE="$OPTARG";;
		h)	usage;;
		:)	die "$0: Must supply an argument to -$OPTARG.";;
		\?)	die "Invalid Option -$OPTARG ";;
esac
done
############################ Default Values for Params##########################
: ${MODULE:='xhci_hcd'}

########################### REUSABLE TEST LOGIC ################################
# Avoid using echo. Instead use print functions provided by st_log.sh

#Define Path to search for modules
MODULE_PATH="/sys/module"

# do_cmd() will check return code and fail the test if return code is non-zero.
# Verify that information of USB modules is found

	do_cmd ls $MODULE_PATH|grep $MODULE
	do_cmd modprobe $MODULE
	if [ $? -ne 0 ]; then
		test_print_trc "USB $MODULE  module load failed"
		exit 1
    else
        do_cmd ls $MODULE_PATH/$MODULE/ |grep drivers
        if [ $? -ne 0 ];then
           test_print_trc "USB module:$MODULE is on $MODULE_PATH but not drivers
           related"
        else
            test_print_trc "Drivers related are:"
            ls $MODULE_PATH/$MODULE/drivers
        fi
	fi

exit $?
