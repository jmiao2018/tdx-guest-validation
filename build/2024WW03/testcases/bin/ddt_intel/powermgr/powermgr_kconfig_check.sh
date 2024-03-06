#!/bin/bash
###############################################################################
#
# Copyright (C) 2015 Intel - http://www.intel.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
###############################################################################
# @Author   Zelin Deng (zelinx.deng@intel.com)
# @desc     Check kernel config of power managment
# @returns  0 if the execution was finished successfully, else 1
# @history  2015-11-23: First Version (Zelin Deng)

source "powermgr_common.sh"

#-o : value of config options, it can be y m ym or n
#-c: config options name, such as CONFIG_INTEL_IDLE
while getopts :o:c:h arg
do
	case $arg in
		o)
			OPTION="$OPTARG"
		;;
		c)
			CONFIG="$OPTARG"
		;;
		h)
			die "Please supply argument: \
				${0##*/} -o <OPTION> -c <CONFIG>
				OPTION: value of kernel config option, it can be y,m,ym,n
				CONFIG: kernel config option,such as CONFIG_INTEL_IDLE
			"
		;;
		\?)
			die "You must supply an argument, please try to use ${0##*/} -h"
		;;
		*)
			die "Invalid argument, please try to use ${0##*/} -h"
		;;
	esac
done

: ${OPTION:="y"}
[ "x${CONFIG}" == "x" ] && die "Kernel config can't be empty"
CONFIG=`echo $CONFIG | sed 's/^\"\|\"$//g'`
#test_kconfigs is defined in common.sh
do_cmd "test_kconfigs "$OPTION" \"$CONFIG\""

#if the value of kernel config option is expected as the argument exit 0, else exit 1
exit $?
