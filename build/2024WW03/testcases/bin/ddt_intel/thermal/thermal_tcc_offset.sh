#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2022, Intel Corporation
# Co-Authors:
#             rui.zhang@intel.com
#			  wendy.wang@intel.com
# History:
#             Nov, 2022 - Creation

source "common.sh"

MSR_THERMAL_TARGET=0x1a2
MSR_PACKAGE_THERMAL_STATUS=0x1b1
timeout=50
offset=20
offset_ori=""

d_tcc=$(grep . /sys/class/thermal/cooling*/type | grep "TCC Offset" |
	awk -F":" '{print $1}' | awk -F"/type" '{print $1}')
d_pkg_temp=$(grep . /sys/class/thermal/thermal_zone*/type | grep "x86_pkg_temp" |
	awk -F":" '{print $1}' | awk -F"/type" '{print $1}')

#Check TCC Offset cooling device from sysfs
if [ -z "$d_tcc" ]; then
	block_test "SUT does not support thermal tcc sysfs"
else
	offset_ori=$(cat "$d_tcc"/cur_state)
	test_print_trc "Found TCC Offset cooling device at $d_tcc"
	grep . "$d_tcc"/* 2>/dev/null
fi

#Reading TCC offset support status from MSR
#Bit 30 of MSR Platform Info (0xce) is Programmable TJ OFFSET
#When set to 1,indicates that MSR_TEMPERATURE_TARGET[27:24] is
#valid and writable to specify a temperature offset
check_tcc_offset_support() {
	sp=$(rdmsr -f 30:30 0xce)
	if [ "$sp" -eq 0 ]; then
		block_test "TCC Offset is not supported on this platform"
	fi
}

check_tcc_offset_support

#Function to get prochot# activation log from MSR bit 3
get_prochot() {
	#	echo ProcHot MSR: 0x$val
	val=$(rdmsr -f 3:0 $MSR_PACKAGE_THERMAL_STATUS)
	val=$((0x$val))
	#	echo ProcHot activated: $val
	return $val
}

clear_prochot() {
	val=$(rdmsr $MSR_PACKAGE_THERMAL_STATUS)
	#	echo ProcHot MSR: 0x$val
	val=$((0x$val))
	val=$(("$val" & ~15))
	do_cmd "wrmsr -a $MSR_PACKAGE_THERMAL_STATUS $val"
	val=$(rdmsr $MSR_PACKAGE_THERMAL_STATUS)
	#	echo ProcHot MSR new: 0x$val
	return "$val"
}

#Tjmax can also be considered as temperature target
get_tjmax() {
	val=$(rdmsr -f 23:16 $MSR_THERMAL_TARGET)
	val=$((0x$val))
	#	echo Tjmax: $val
	return $val
}

#MSR_PACKAGE_THERMAL_STATUS[23:16] is Package Digital Readout
#MSR_THERMAL_TARGET[23:16] is Temperature Target
get_temp() {
	tjmax=$(rdmsr -f 23:16 $MSR_THERMAL_TARGET)
	tjmax=$((0x$tjmax))
	raw=$(rdmsr -f 23:16 $MSR_PACKAGE_THERMAL_STATUS)
	raw=$((0x$raw))
	val=$(("$tjmax" - "$raw"))
	#	echo Temp: $val [ $tjmax - $raw ]
	return $val
}

#MSR_THERMAL_TARGET[29:24] is Target Offset
get_offset() {
	val=$(rdmsr -f 29:24 $MSR_THERMAL_TARGET)
	val=$((0x$val))
	#	echo TCC Offset: $val
	return $val
}

#Offset value should be less than max_state
set_offset() {
	max=$(cat "$d_tcc"/max_state)
	if [ "$1" -gt "$max" ]; then
		block_test "Invalid offset value $1"
	fi
	do_cmd "echo $1 >$d_tcc/cur_state"
	#	echo Set TCC Offset to $(cat $d_tcc/cur_state)
}

#MSR_THERMAL_TARGET[23:16] is Temperature Target
#MSR_THERMAL_TARGET[29:24] is Target Offset
get_tcc_act_temp() {
	tjmax=$(rdmsr -f 23:16 $MSR_THERMAL_TARGET)
	tjmax=$((0x$tjmax))
	offset=$(rdmsr -f 29:24 $MSR_THERMAL_TARGET)
	offset=$((0x$offset))
	val=$(("$tjmax" - "$offset"))
	echo Tcc activation Temp: $val [ $tjmax - $offset ]
	return $val
}

tcc_offset_test() {
	#$1 is the offset value pending for testing
	local offset=$1
	local cpu_num=""

	cpu_num=$(awk -F "-" '{print $2}' /sys/devices/system/cpu/present)
	cpu_num=$(("$cpu_num" + 1))
	set_offset "$offset"

	get_offset
	[ "$?" -ne "$offset" ] && die "Failed to set TCC Offset $offset"

	get_temp
	temp=$?
	get_tcc_act_temp
	tcc_temp=$?
	tcc_activated=1
	test_print_trc "tcc_temp: $tcc_temp. temp: $temp"
	test_print_trc "Will idle SUT for 10 loops to get cool before testing:"
	# Idle to make sure the test starts with cool
	loop=1
	while true; do
		if [ $loop -gt 10 ]; then
			if [ $tcc_temp -gt $temp ] && [ $tcc_activated -eq 0 ]; then
				break
			fi
		fi
		sleep 1

		if [ $loop -gt $timeout ]; then
			block_test "Too many tries. Temperature always high"
			break
		fi

		clear_prochot
		get_prochot
		tcc_activated=$?
		get_temp
		temp=$?
		test_print_trc "Idle Loop$loop: Temp $temp [ x86_pkg_temp: $(cat "$d_pkg_temp"/temp) ], TCC activated "?" $tcc_activated"
		loop=$(("$loop" + 1))
	done

	test_print_trc "Start to test Prochot offset activation:"
	clear_prochot
	get_prochot
	tcc_activated=$?
	[ $tcc_activated -ne 0 ] && test_print_trc "ProcHot is already activated after setting offset"

	loop=1
	while [ $temp -le $tcc_temp ] || [ $tcc_activated -eq 0 ]; do
		if [ $loop -gt $timeout ]; then
			block_test "Too many tries and did not get prochot activation"
			break
		fi
		do_cmd "stress -c $cpu_num -t 1 >/dev/null 2>&1"
		get_temp
		temp=$?
		get_prochot
		tcc_activated=$?
		test_print_trc "HEAT Loop$loop: Temp $temp [ x86_pkg_temp: $(cat "$d_pkg_temp"/temp) ], TCC activated "?" $tcc_activated"

		[ $tcc_activated -ne 0 ] && break
		loop=$(("$loop" + 1))
	done
	get_tjmax
	tjmax=$?
	test_print_trc "Current temp: $temp, tjmax: $tjmax, offset: $offset, TCC activation temp: $tcc_temp"

	if get_prochot; then
		die "Did not get prochot activation."
	else
		test_print_trc "Prochot activation is triggered with offset setting to $offset"
	fi

	#Recover the original offset value
	set_offset "$offset_ori"
}

#Set the tcc offset to 20s
tcc_offset_test 20
