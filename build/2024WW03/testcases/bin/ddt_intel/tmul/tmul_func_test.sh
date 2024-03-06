#!/bin/bash
###############################################################################
# Copyright (C) 2020, Intel - http://www.intel.com
#
# SPDX-License-Identifier: GPL-2.0-or-later
###############################################################################

############################ DESCRIPTION ######################################
# @desc     This script is based on tmul binary to do func test of
#           amx/tmul.
###############################################################################

source "common.sh"
source "functions.sh"

test_print_trc "Run TMUL test " \

break_reason=0
instruction=0
rtn=1

while getopts "b:i:" arg ; do
	case $arg in
	b)
		break_reason=$OPTARG
		;;
	i)
		instruction=$OPTARG
		;;
	esac
done

if [[ "$break_reason" = "4" ]]; then
	tmul -b "$break_reason" -t 10 -c 100000 -i "$instruction"
	rtn=$?
else
	tmul -b "$break_reason" -t 10 -c 10 -i "$instruction"
	rtn=$?
fi

exit $rtn

