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
# @desc     Check dmesg with key pattern
# @returns  0 if the execution was finished successfully, else 1
# @history  2015-11-23: First Version (Zelin Deng)

source "powermgr_common.sh"

#-t: what type of message to check, it can be "info" "debug" "time"
#-p: key pattern
#-h: show help
while getopts :t:p:h arg
do
	case $arg in
		t)
			TYPE="$OPTARG"
		;;
		p)
			PATTERN="$OPTARG"
		;;
		h)
			die "Usage: ${0##*/} -t <MSG_TYPE> -p <PATTERN> -h\
				-t <MSG_TYPE>: info ,debug or time
				-p <PATTERN>: key word to search
				-h: show this usage
			"
		;;
		\?)
			die "You must supply an argument, ${0##*/} -h"
		;;
		*)
			die "Invalid argument, ${0##*/} -h"
		;;
	esac
done
: ${TYPE:="info"}
[ "x$PATTERN" == "x" ] && die "Must supply a pattern"
PATTERN=`echo $PATTERN | sed 's/^\"\|\"$//g'`

#MSG to record every dmesg that will be printed
MSG=""

#PATTERN can be this format: pattern1&pattern2&pattern3, it means that each of them
#must be found at least once. set IFS="&"
oIFS="$IFS"
IFS="|"
for pattern in $PATTERN
do
	case $TYPE in
		info)
			test_print_trc "Checking dmesg for search $pattern"
			INFO=`dmesg | grep "$pattern"`
			;;
		#debug message only for initcall debug, to get its returned value
		debug)
			test_print_trc "Checking dmesg for search $pattern to verify initcall"
			INFO=`dmesg | grep "$pattern"`
		;;
		#time of initcall
		time)
			test_print_trc "Checking dmesg for search $pattern to verify initcall time"
			#All initcall_debug message follows this format:
			#[    0.437743] initcall intel_idle_init+0x0/0x3bf returned 0 after 191 usecs
			#get the time of initcall
			INFO=`dmesg | grep "$pattern" | sed 's/^.*after\s\|\susecs$//g'`
		;;
		*)
			die "Invalid option for argument -t"
		;;
	esac
	[ "x$INFO" == "x" ] && die "$pattern is not found in dmesg"
	[ "x${MSG}" == "x" ] &&  MSG="$INFO" || MSG="${MSG};${INFO}"
done
IFS="$oIFS"

echo $MSG
exit 0
