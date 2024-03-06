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
# @desc     Check userspace interface under sysfs or procfs and so on
# @returns  0 if the execution was finished successfully, else 1
# @history  2015-11-23: First Version (Zelin Deng)

source "powermgr_common.sh"

#check directory of file exists
#$1 type:d for directory f for file
#$2 path
function filesystem_verify(){
	[ $# -ne 2 ] && die "You must supply 2 parameters, ${0##*/} <TYPE> <PATH>"
	local TYPE="$1"
	local path="$2"
	#if TYPE is not d nor f, set it as e
	if [ "$TYPE" != "d" ] || [ "$TYPE" != "f" ];then
		TYPE="e"
	fi
	[ -${TYPE} "$path" ] || return 1
	echo $path does exist
	return 0
}

# Check whether swap partition exists and enabled
# return value:
#   0: swap partition exists and has been enabled.
#   1: no swap partition found or fail to enable it.
function check_swap_partition()
{
    local swap_partition=""
    local swap_pattern="\[SWAP\]"

    lsblk | grep -q "$swap_pattern"
    if [ $? -eq 0 ]; then
        test_print_trc "swapping partition has been enabled."
        return 0
    fi

    swap_partition=$(blkid -s TYPE | grep "swap" | awk -F: '{print $1}')
    if [ -z "$swap_partition" ]; then
        test_print_trc "no swap partition found!"
        return 1
    else
        swapon $swap_partition &> /dev/null
        if [ $? -eq 0 ]; then
            return 0
        else
            test_print_trc "fail to enable swapping partition: $swap_partition !"
            return 1
        fi
    fi
}

while getopts :c:h arg
do
	case $arg in
		c)
			CASE_ID="$OPTARG"
		;;
		h)
			die "${0##*/} -c <CASE_ID> -h
				-c CASE_ID: which case to launch
				-h: show help
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

#1,check cpu idle sysfs
#2,check pstate sysfs
#3,check the current driver being used by Linux
#4,check pstate control
#5,check system power state support
#6,check mode of suspend-to-disk mechanism
#7,check image size of suspend-to-disk mechanism
#8,check swap partition size
#9,check cpufreq sysfs interface
#10,check and change cpufreq governor
#11,check s0ix status enable flag
case $CASE_ID in
	1)
		powermgr_dmesg_check.sh -t debug -p initcall.*intel_idle_init &> /dev/null || die "Intel idle has not been loaded successfully"
		filesystem_verify d "$CPU_IDLE_SYSFS_PATH" || die "$CPU_IDLE_SYSFS_PATH does not exist"
		filesystem_verify d "$CPU_POWER_SYSFS_PATH" || die "$CPU_POWER_SYSFS_PATH dose not exit"
		for node in $CPU_IDLE_NODE
		do
			filesystem_verify f $CPU_IDLE_SYSFS_PATH/$node || die "$node does not exist"
		done
		for node in $CPU_POWER_NODE
		do
			filesystem_verify f $CPU_POWER_SYSFS_PATH/$node || die "$node does not exist"
		done
	;;
	2)
		powermgr_dmesg_check.sh -t debug -p initcall.*intel_pstate_init &> /dev/null || die "Intel_Pstate driver has not been loaded successfully"
		filesystem_verify d "$CPU_PSTATE_SYSFS_PATH" || die "$CPU_PSATE_SYSFS_PATH does not exist"
		lines=$(grep -s . "$CPU_PSTATE_SYSFS_PATH"/*)
		[[ -n "$lines" ]] || die "Intel_pstate sysfs file does not exist, please check current cpufreq driver"
		for line in $lines; do
			test_print_trc $line
		done
		for node in $CPU_PSTATE_NODE
		do
			filesystem_verify f $CPU_PSTATE_SYSFS_PATH/$node || die "$node does not exist"
		done
	;;
	3)
		intel_idle_init_status=`powermgr_dmesg_check.sh -t debug -p "initcall.*intel_idle_init" &>/dev/null && echo yes || echo no`
		cpuidle_init_status=`powermgr_dmesg_check.sh -t debug -p "initcall.*cpuidle_init" &>/dev/null && echo yes || echo no`
		current_idle_driver=`cat "${CPU_IDLE_SYSFS_PATH}/current_driver"`
		[ "x$current_idle_driver" == "x" ] && die "Can't get current driver of cpu idle"
		echo ====intel_idle_init_status=$intel_idle_init_status,cpuidle_init_stats=$cpuidle_init_status,current_idle_driver=$current_idle_driver====
		if [ "$intel_idle_init_status" == "yes" ] && [ "$cpuidle_init_status" == "yes" ] && [ "$current_idle_driver" == "intel_idle" ];then
			exit 0
		else
			if [ "$intel_idle_init_status" == "no" ] && [ "$cpuidle_init_status" == "yes" ] && [ "$current_idle_driver" == "acpi_idle" ];then
				exit 0
			else
				exit 1
			fi
		fi
	;;
	4)
		#multi core cpu
		cpulist=`ls $CPU_SYSFS_PATH | grep -Ew "cpu[0-9]+"`
		for cpu in $cpulist
		do
			pstate_control=`cat "${CPU_SYSFS_PATH}/$cpu/cpufreq/scaling_driver"`
			[ "x$pstate_control" == "x" ] && die "Failed to get pstate control"
			test_print_trc "$cpu's pstate control is $pstate_control"
		done
	;;
	5)
		cat $POWER_STATE_NODE | grep "$SUPPORTED_POWER_STATE" || \
		die "power state:$SUPPORTED_POWER_STATE are not all supported"
		test_print_trc "power state:$SUPPORTED_POWER_STATE are all supported"
	;;
	6)
		cat $POWER_DISK_NODE | grep "$SUPPORTED_DISK_MODE" || \
		die "suspend-to-disk mode:$SUPPORTED_DISK_MODE are not all supported"
		test_print_trc "suspend-to-disk mode:$SUPPORTED_DISK_MODE are all supported"
	;;
	7)
		image_size=`cat "$POWER_IMGSIZE_NODE"`
		mem_total=`cat "$MEM_PROCFS_PATH" | grep MemTotal | grep -oE [0-9]+`
		let mem_total=$mem_total*1000
		let high_limit=$image_size+$image_size*3/100
		let low_limit=$image_size-$image_size*3/100
		let check=$mem_total*2/5
		test_print_trc "mem=$check, high limit=$high_limit, low_limit=$low_limit"
		[ $check -gt $low_limit ] && [ $check -lt $high_limit ] && exit 0 || exit 1
	;;
	8)
		# check swap partition, block this case if the checking fails.
		check_swap_partition || exit 2
		mem_total=`free | grep Mem | grep -oE [0-9]+ | head -n 1`
		swap_size=`free | grep Swap | grep -oE [0-9]+ | head -n 1`
		test_print_trc "total mem size is:$mem_total, swap size is:$swap_size"
		[ $swap_size -ge $mem_total ] && exit 0 || exit 1
	;;
	9)
		cpulist=`ls $CPU_SYSFS_PATH | grep -Ew "cpu[0-9]+"`
		for cpu in $cpulist
		do
			for node in $CPU_CPUFREQ_NODE
			do
				filesystem_verify f $CPU_SYSFS_PATH/$cpu/cpufreq/$node || \
				die "$node does not exist under $CPU_SYSFS_PATH/$cpu/cpufreq for $cpu"
			done
		done
	;;
	10)
		cpulist=`ls $CPU_SYSFS_PATH | grep -Ew "cpu[0-9]+"`
		for cpu in $cpulist
		do
			available_governor=`cat "$CPU_SYSFS_PATH/$cpu/cpufreq/scaling_available_governors"`
			[ "x${available_governor}" != "performance powersave" ] || \
			die "scaling_available_governors's value is not\"performance powersave\""
			test_print_trc "available governor of $cpu is:$available_governor"
			current_governor=`cat "$CPU_SYSFS_PATH/$cpu/cpufreq/scaling_governor"`
			test_print_trc "current governor of $cpu is:$current_governor"
			if [ "x$current_governor" == "xperformance" ];then
				do_cmd "echo powersave > $CPU_SYSFS_PATH/$cpu/cpufreq/scaling_governor"
				new_governor=`cat "$CPU_SYSFS_PATH/$cpu/cpufreq/scaling_governor"`
				[ "x$new_governor" != "xpowersave" ] && die "Failed to change scaling governor"
				test_print_trc "new governor of $cpu is:$new_governor"
			elif [ "x$current_governor" == "xpowersave" ];then
				do_cmd "echo performance > $CPU_SYSFS_PATH/$cpu/cpufreq/scaling_governor"
				new_governor=`cat "$CPU_SYSFS_PATH/$cpu/cpufreq/scaling_governor"`
				[ "x$new_governor" != "xperformance" ] && die "Failed to change scaling governor"
				test_print_trc "new governor of $cpu is:$new_governor"
			else
				die "Invalid scaling governor"
			fi
		done
	;;
    11)
	    [ -f "$S0IX_SUBSTATE_RESIDENCY" ] || na_test "Test platform does not support this case."
		s0ix_enable_flag=`cat "$S0IX_SUBSTATE_RESIDENCY" | grep "Enabled"`
		test_print_trc "Intel_PMC_CORE S0ix substate enable status file:"
		cat $S0IX_SUBSTATE_RESIDENCY
		if [ -z "$s0ix_enable_flag" ];then
			die "S0ix enable status flag is not ready: Failed"
		fi
		if [ -n "$s0ix_enable_flag" ];then
			test_print_trc "S0ix enable status flag is ready: Pass"
		fi
	;;
	*)
		die "Invalid case ID, the currently supported case IDs range from 1-10"
	;;
esac