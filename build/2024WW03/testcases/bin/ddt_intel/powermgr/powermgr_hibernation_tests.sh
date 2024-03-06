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
# @desc     verify modes of hibernation: freeze,s3,s4
# @returns  0 if the execution was finished successfully, else 1
# @history  2015-11-25: First Version (Zelin Deng)

source "powermgr_common.sh"

SUPPORTED_STATE="^freeze$|^mem$|^disk$"
SUPPORTED_MODE="^none$|^freezer$|^devices$|^platform$|^processors$|^core$"

#-s: which state to be suspend: freeze, mem, disk
#-m: which mode for pm test: none,freezer,devices,platform,core,processors
#-p: sleep time between loops
#-t: time for rtcwake set by -s. When you set none pm test mode, should be waked up by rtcw
#-d: dmesg pattern
#-h: help message
while getopts :s:m:p:t:d:h arg; do
	case $arg in
	s)
		STATE="$OPTARG"
		;;
	m)
		MODE="$OPTARG"
		;;
	p)
		PAUSE="$OPTARG"
		;;
	t)
		TIME="$OPTARG"
		;;
	d)
		PATTERN="$OPTARG"
		;;
	h)
		die "Usage: ${0##*/} -s <STATE> -m <MODE> -p <PAUSE> -t <TIME> -h
				-s STATE: state to be suspend: freeze,mem,disk
				-m MODE: mode for pm test:none,freezer,devices,platform,core,processors
				-p PAUSE: sleep time between loops
				-t TIME: time for rtcwake, set by -s. If you set pm test mode as none,
						device should be waked up by rtc.
				-d: PATTERN: patterns to be searched in dmesg
				-h: show this Usage
			"
		;;
	\?)
		die "You must supply argument: ${0##*/} -h"
		;;
	*)
		die "Invalid options: ${0##*/} -h"
		;;
	esac
done
#set default value
POWERMGR_SUSPEND_LOOP=$(echo $POWERMGR_SUSPEND_LOOP | sed 's/^\"\|\"$//g')
if [ "x$POWERMGR_SUSPEND_LOOP" == "x" ] || [ "$POWERMGR_SUSPEND_LOOP" -le "0" ] || [[ ! "$POWERMGR_SUSPEND_LOOP" =~ [0-9]+ ]]; then
	test_print_trc "Format of POWERMGR_SUSPEND_LOOP, it must be positive integers, default value 10 will be set"
	POWERMGR_SUSPEND_LOOP=10
fi
PAUSE=$(echo $PAUSE | sed 's/^\"\|\"$//g')
if [ "x$PAUSE" == "x" ] || [ "$PAUSE" -le "0" ] || [[ ! "$PAUSE" =~ [0-9]+ ]]; then
	test_print_trc "Format of -p option is illegal, it must be positive integers, default value 10 will be set"
	PAUSE=10
fi
TIME=$(echo $TIME | sed 's/^\"\|\"$//g')
if [ "x$TIME" == "x" ] || [ "$TIME" -le "0" ] || [[ ! "$TIME" =~ [0-9]+ ]]; then
	test_print_trc "Format of -t option is illegal, it must be positive integers, default value 10 will be set"
	TIME=10
fi
: ${STATE:="freeze"}
: ${MODE:="freezer"}
: ${PATTERN:="PM: Syncing filesystem|PM: Preparing system for sleep.*freeze|PM: Finishing wakeup"}

# Servers does not "Platfrom" mode for /sys/power, while client supports
if [[ -e /sys/power/platform ]]; then
	test_print_trc "Set to platform mode hibernation "
	echo platform >${POWER_DISK_NODE}
else
	test_print_trc "SUT does not support /sys/power/platform, keep default shutdome mode"
fi

echo $STATE | grep -E "$SUPPORTED_STATE" ||
	die "state must be one of $SUPPORTED_STATE"
echo $MODE | grep -E "$SUPPORTED_MODE" ||
	die "mode must be one of $SUPPORTED_MODE"
echo $MODE >${POWER_SYSFS_PATH}/pm_test ||
	die "Failed to set pm test mode"
pmtestmode=$(cat ${POWER_SYSFS_PATH}/pm_test)

# For S3, need echo deep > /sys/power/mem_sleep at the very beginning of the test
[[ "$STATE" == "mem" ]] && do_cmd "echo deep > $POWER_MEM_SLEEP_NODE"

while [ $POWERMGR_SUSPEND_LOOP -gt 0 ]; do
	# wait 2 seconds in case the device is still in use.
	sleep 2
	test_print_trc "====loop:$POWERMGR_SUSPEND_LOOP for state:$STATE,pm test mode:$pmtestmode "
	#before we change power status, get the last timestamp
	lasttime=$(dmesg | tail -1 | cut -d']' -f1 | sed 's/.*\[\|\s//g')
	test_print_trc "last timestamp is $lasttime"
	#If pm test mode is none. We have to wake up our machine by rtcwake after the
	#machine having been suspended. Rtcwake -m xxx will make the machine into suspend
	# If pm test mode is not none, we only need to echo pm state to ${POWER_SYSFS_PATH}/state to trigger the pm test.
	#However, as rtcwake does not support freeze state. we have to do "echo freeze > ${POWER_SYSFS_PATH}/state"
	#after we having executed "rtcwake -m on -s xxx".
	if [ "$MODE" != "none" ]; then
		echo $STATE >${POWER_SYSFS_PATH}/state || die "Failed to set state $STATE"
	else
		if [ "$STATE" == "freeze" ]; then
			rtcwake -m on -s $TIME &
			echo freeze >${POWER_SYSFS_PATH}/state
		else
			rtcwake -m $STATE -s $TIME
		fi
	fi
	#Once we have set machine to hibernation, the kernel have to do some preparation
	#for going into the suspend state which. This process needs a few seconds.
	#To insure we can get the right dmesg, we have to delay enough time to insure
	#the kernel complete the preparation.
	do_cmd sleep $PAUSE
	#delete lines before last timestamp
	result=$(dmesg | sed "1,/$lasttime/d" | grep -iv Call)
	test_print_trc "latest dmesg is: $result"
	PATTERN=$(echo $PATTERN | sed 's/^\"\|\"$//g')
	echo ====PATTERN=${PATTERN[@]}===
	oIFS=$IFS
	IFS="|"
	if [ "x$PATTERN" != "x" ]; then
		test_print_trc "Now check if the pattern is in result"
		for pattern in ${PATTERN[@]}; do
			test_print_trc "checking pattern:$pattern"
			echo "$result" | grep -E "$pattern"
			[ $? -ne 0 ] && {
				IFS=$oIFS
				die "Failed to find $pattern in $result"
			}
		done
	fi
	IFS=$oIFS
	POWERMGR_SUSPEND_LOOP=$(expr $POWERMGR_SUSPEND_LOOP - 1)
done

exit 0
