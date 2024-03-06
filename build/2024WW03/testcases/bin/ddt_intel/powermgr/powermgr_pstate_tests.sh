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
# @desc     Automate intel_pstate test cases designed by Wendy Wang(wendy.wang@intel.com)
# @returns  0 if the execution was finished successfully, else 1
# @history  2015-12-30: First Version (Zelin Deng)

source "powermgr_common.sh"

PSTATE_TOOL="$LTPROOT/testcases/bin/ddt_intel/powermgr"
while getopts c:h arg; do
	case $arg in
	c)
		CASE_ID=$OPTARG
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
#set the default case id as 1
: "${CASE_ID:="1"}"

#functions
function get_max_freq() {
	local turbo_state=""
	#check value of no_turto. If the value is 1,
	#the actual max cpu freq is read through /proc/cpuinfo
	#else if the value is 0, the actual max cpu freq should
	#be got from tubostat debug message
	turbo_state=$(cat "$CPU_SYSFS_PATH"/intel_pstate/no_turbo)
	test_print_trc "Get cpu_state from turbostat:"
	cpu_stat=$("$PSTATE_TOOL/turbostat" sleep 1 2>&1)
	test_print_trc "$cpu_stat"

	hybrid_sku=$(echo "$cpu_stat" | grep "MSR_SECONDARY_TURBO_RATIO_LIMIT")
	test_print_trc "Hybrid SKU status: $hybrid_sku"
	if [ "$turbo_state" -eq 0 ]; then
		if [ -n "$hybrid_sku" ]; then
			max_freq=$(echo "$cpu_stat" | grep -B 1 "MSR_SECONDARY_TURBO_RATIO_LIMIT" |
				head -1 | awk '{print $5}' 2>&1)
			test_print_trc "Max_freq_turbo_On on Hybrid SKU: $max_freq MHz"
		else
			max_freq=$(echo "$cpu_stat" | grep "max turbo" | awk 'END {print}' | awk '{print $5}')
			test_print_trc "Turbo is enabled, the supported max freq is:$max_freq MHz"
		fi
	else
		max_freq=$(echo "$cpu_stat" |
			grep "base frequency" |
			awk '{print $5}')
		test_print_trc "Turbo is disabled, the supported max freq is:$max_freq MHz"
	fi
	return 0
}

function checking_msr_precondition() {
	command -v rdmsr &>/dev/null && command -v wrmsr &>/dev/null || {
		test_print_trc "rdmsr-tool is not installed,BLOCKED"
		return 1
	}
	modprobe msr || die "Failed to load module msr,BLOCKED"
	return 0
}

#$1: flag
#flag can be S3 and S2idle
function checking_msr_hwp() {
	local flag=$1
	local param=""
	local msr_req_orig=""
	local msr_req_cur=""
	test_print_trc "Checking MSR REG 0x774 before $flag"

	#Output the stderr to /dev/null.
	msr_req_orig=$(rdmsr 0x774 2>/dev/null)
	[ "x$msr_req_orig" == "x" ] && die "No data in msr reg 0x774 -- MSR_HWP_REQUEST, FAIL"

	test_print_trc "MSR REG values before $flag, 0x774=$msr_req_orig"
	#If data has been read, suspend into S3 and wake it up after 20 second, then check the reg agian.
	#Now suspend into S3, wake up by rtcwake
	echo platform >${POWER_DISK_NODE} || die "Failed to suspend into $flag, FAIL"
	do_cmd "echo none > ${POWER_SYSFS_PATH}/pm_test"
	if [ "$flag" == "S3" ]; then
		param="mem"
		do_cmd "echo deep > $POWER_MEM_SLEEP_NODE"
	elif [ "$flag" == "S2idle" ]; then
		param="freeze"
	else
		die "Argument error: must be S3 or S2idle"
	fi
	do_cmd "rtcwake -m $param -s 20"
	#Sleep enough time to make sure system suspend into S3 successfully
	do_cmd "sleep 40"

	test_print_trc "Checking MSR REG 0x774 after $flag"
	#Output the stderr to /dev/null.
	msr_req_cur=$(rdmsr 0x774 2>/dev/null)
	[ "x$msr_req_cur" == "x" ] && die "No data in msr reg 0x774 -- MSR_HWP_REQUEST, FAIL"
	test_print_trc "MSR REG values after S3, 0x774=$msr_req_cur"
	if [ "$msr_req_cur" != "$msr_req_orig" ]; then
		die "MSR REG values have changed, FAIL"
	fi
	test_print_trc "MSR REG value before $flag are the same with value after $flag, PASS"
	return 0
}

get_cpu_stat() {
	local cpu_stat=""
	columns="Core,CPU,Avg_MHz,Busy%,Bzy_MHz,PkgWatt"
	cpu_stat=$($PSTATE_TOOL/turbostat -c 1 --show $columns -i 10 sleep 30 2>&1)
	echo "$cpu_stat"
}

function checking_msr_powerlimit() {
	local x86_cpuload_pid=""
	local cpu_stat=""
	local cpu_freq=""
	local max_perf_pct=""
	local delta=""

	test_print_trc "Executing x86_cpuload -s 1 -c 1 -t 90 & in background"
	"$PSTATE_TOOL"/x86_cpuload -s 1 -c 1 -t 90 &
	x86_cpuload_pid=$!
	test_print_trc "Executing turbostat -c 1 --show Core,CPU,Avg_MHz,Busy%,Bzy_MHz,PkgWatt -i 10 sleep 30 2>&1"
	cpu_stat=$(get_cpu_stat)
	echo -e "turbostat of msr reg 0x19c is:\n"
	echo -e "$cpu_stat\n"
	test_print_trc "Getting cpu1 freq from turbostat"
	cpu_freq=$(echo "$cpu_stat" | grep -E "^-" -A 2 | sed -n "2, 1p" | awk '{print $5}')
	test_print_trc "Actual max freq of cpu1 is: $cpu_freq Mhz, when cpu1 has 100% workload"
	[ -n "$x86_cpuload_pid" ] && do_cmd "do_kill_pid $x86_cpuload_pid"

	max_perf_pct=$(cat "$CPU_SYSFS_PATH"/intel_pstate/max_perf_pct)
	test_print_trc "The max_freq: $max_freq"
	delta=$(awk -v x="$max_freq" -v y="$cpu_freq" \
		'BEGIN{printf "%.1f\n", x-y}')
	test_print_trc "The delta value: $delta"
	#Unit of max_freq is Khz,but cpu_freq's is Mhz. Convert Mhz to Khz: $cpu_freq*1000
	#Remove possible "-"(minus) which will appear when $cpu_freq*1000 is large than
	#$max_freq*$max_perf_pct/100
	#100Mhz (100000Khz) error is acceptable.
	if [[ $(echo "$delta > 100" | bc) -eq 1 ]]; then
		die "Actual max freq of cpu1:$cpu_freq Mhz, doesn't match with the supported max freq $max_freq,FAIL"
		return 0
	else
		test_print_trc "Actual max freq of cpu1:$cpu_freq Mhz, matches with the supported max freq $max_freq,PASS"
	fi
}

function checking_pstate_turbo() {
	local turbo_state=""
	local x86_cpuload_pid=""
	local cpu_stat=""
	local cpu_freq_noturbo=""
	local cpu_freq_turbo=""
	#Disable turbo mode
	test_print_trc "Disable turbo mode"
	#Save turbo state, after test has finished, restore it
	turbo_state=$(cat $CPU_SYSFS_PATH/intel_pstate/no_turbo)
	do_cmd "echo 1 > $CPU_SYSFS_PATH/intel_pstate/no_turbo"
	test_print_trc "Executing x86_cpuload -s 1 -c 1 -t 90 & in background"
	"$PSTATE_TOOL"/x86_cpuload -s 1 -c 1 -t 90 &
	x86_cpuload_pid=$!
	test_print_trc "Executing turbostat --show Core,CPU,Avg_MHz,Busy%,Bzy_MHz,PkgWatt -i 10 sleep 30 2>&1"
	cpu_stat=$(get_cpu_stat)
	echo -e "turbostat is:\n"
	echo -e "$cpu_stat\n"
	test_print_trc "Getting freq of cpu1 from turbostat"
	cpu_freq_noturbo=$(echo "$cpu_stat" | grep -E "^-" -A 2 | sed -n "2, 1p" | awk '{print $5}')
	test_print_trc "Actual max freq of cpu1 is: $cpu_freq_noturbo Mhz, when turbo mode is disabled and cpu1 has 100% workload"
	[ -n "$x86_cpuload_pid" ] && do_cmd "do_kill_pid $x86_cpuload_pid"

	#Enable turbo mode
	test_print_trc "Enable turbo mode"
	do_cmd "echo 0 > $CPU_SYSFS_PATH/intel_pstate/no_turbo"
	test_print_trc "Executing x86_cpuload -s 1 -c 1 -t 90 & in background"
	"$PSTATE_TOOL"/x86_cpuload -s 1 -c 1 -t 90 &
	x86_cpuload_pid=$!
	test_print_trc "Executing turbostat --show Core,CPU,Avg_MHz,Busy%,Bzy_MHz,PkgWatt -i 10 sleep 30 2>&1"
	cpu_stat=$(get_cpu_stat)
	echo -e "turbostat is:\n"
	echo -e "$cpu_stat\n"
	test_print_trc "Getting cpu freq from turbostat"
	cpu_freq_turbo=$(echo "$cpu_stat" | grep -E "^-" -A 2 | sed -n "2, 1p" | awk '{print $5}')
	test_print_trc "Actual max freq of cpu1 is: $cpu_freq_turbo Mhz, when turbo mode is enabled and cpu1 has 100% workload"
	[ -n "$x86_cpuload_pid" ] && do_cmd "do_kill_pid $x86_cpuload_pid"
	echo $turbo_state >$CPU_SYSFS_PATH/intel_pstate/no_turbo
	if [ $cpu_freq_noturbo -lt $cpu_freq_turbo ]; then
		test_print_trc "CPU freq of cpu1 is larger when turbo is enabled than diabled, PASS"
		return 0
	else
		die "CPU freq of cpu1 is less when turbo is enabled than disabled, FAIL"
	fi
}

# $1: pct_type: min or max
# $2: value to change max/min_perf_pct
# $3: load_flag: indicate that if cpu should have 100% workload
function checking_perf_pct() {
	[ $# -ne 3 ] && die "You must supply 3 parameters"
	local pct_type="$1"
	local value="$2"
	local load_flag="$3"
	#Save scaling_governor setting of each cpu, so that we can restore it after the case has finished
	echo $pct_type | grep -E "^max$|^min$" &>/dev/null || die "The first parameter - pct_type must be min or max"
	pct_type="${pct_type}_perf_pct"
	[ "x$(echo $value | sed 's/[0-9]//g')" == "x" ] || [ $value -gt 100 ] || die "The second paramter - value\
	must be positive integer 0-100"
	[ "$load_flag" != "1" ] || [ "$load_flag" != "0" ] || die "The third parameter - load_flag must be 1 or 0"

	local perf_pct_value=""
	local x86_cpuload_pid=""
	local cpu_stat=""
	#Save perf_pct_value before change it
	perf_pct_value=$(cat $CPU_SYSFS_PATH/intel_pstate/$pct_type)
	test_print_trc "The orginal $pct_type value is $perf_pct_value, now set it as $value"
	do_cmd "echo $value > $CPU_SYSFS_PATH/intel_pstate/$pct_type"
	#Read new value from $CPU_SYSFS_PATH/intel_pstate/$pct_type
	value=$(cat $CPU_SYSFS_PATH/intel_pstate/$pct_type)
	test_print_trc "$pct_type value has already been set as $value"

	[ "$load_flag" -eq 1 ] && {
		test_print_trc "Executing x86_cpuload -s 1 -c 1 -b 100 -t 100 & in background"
		"$PSTATE_TOOL"/x86_cpuload -s 1 -c 1 -b 100 -t 100 &
		x86_cpuload_pid=$!
	}
	test_print_trc "Executing turbostat --show Core,CPU,Avg_MHz,Busy%,Bzy_MHz,PkgWatt -i 10 sleep 30 2>&1"
	cpu_stat=$(get_cpu_stat)
	echo -e "turbostat is:\n"
	echo -e "$cpu_stat\n"
	test_print_trc "Getting freq of cpu1 from turbostat"
	CPU_FREQ_CUR=$(echo "$cpu_stat" | grep -E "^-" -A 2 | sed -n "2, 1p" | awk '{print $5}')
	[ "x$x86_cpuload_pid" != "x" ] && do_cmd "do_kill_pid $x86_cpuload_pid"

	#Covert Mhz to Khz.
	CPU_FREQ_CUR=$(echo "$CPU_FREQ_CUR * 1000" | bc)
	test_print_trc "Actual freq of cpu1 when $pct_type has been set as $value is $CPU_FREQ_CUR Khz."
	#restore max_perf_pct or min_perf_pct every time.
	do_cmd "echo $perf_pct_value > $CPU_SYSFS_PATH/intel_pstate/$pct_type"
	return 0
}

#$1: flag
#flag can be 1,performance and powersave.
#If flag=1: Restore scaling_governor setting. The setting is saved in global variable $GOVERNOR_STATES
#If flag=performance or powersave: It means we are intending to change scaling_governor setting.
function do_change_governor() {
	[ $# -ne 1 ] && die "You must supply 1 paramter"
	local cpus=""
	local cpu=""
	local flag="$1"
	local cnt="0"
	cpus=$(ls $CPU_SYSFS_PATH | grep "cpu[0-9]\+")
	#Original governor setting will be saved in global variable $GOVERNOR_STATES
	if [ $flag == "1" ]; then
		test_print_trc "Restoring scaling_governor setting"
		GOVERNOR_STATES=($GOVERNOR_STATES)
		for cpu in $cpus; do
			if [ "x${GOVERNOR_STATES[$cnt]}" != "x" ]; then
				do_cmd "echo ${GOVERNOR_STATES[$cnt]} > $CPU_SYSFS_PATH/$cpu/cpufreq/scaling_governor"
			fi
			cnt=$(($cnt + 1))
		done
	elif [ $flag == "performance" ] || [ $flag == "powersave" ]; then
		test_print_trc "Changing scaling_governor setting to $flag"
		for cpu in $cpus; do
			[ "x$GOVERNOR_STATES" == "x" ] && GOVERNOR_STATES=$(cat $CPU_SYSFS_PATH/$cpu/cpufreq/scaling_governor) ||
				GOVERNOR_STATES="$GOVERNOR_STATES $(cat $CPU_SYSFS_PATH/$cpu/cpufreq/scaling_governor)"
			do_cmd "echo $flag > $CPU_SYSFS_PATH/$cpu/cpufreq/scaling_governor"
		done
	else
		die "The parameter must be 1, performance or powersave"
	fi
}

#$1: flag
#flag can be performance, balance_performance, balance_power and power.
#If flag=performance, balance_performance, balance_power or power:
#It means we are intending to change energy_performance_preference setting.
function do_change_epp() {
	[ $# -ne 1 ] && die "You must supply 1 paramter"
	local cpus=""
	local cpu=""
	local flag="$1"
	local epp_state=""
	cpus=$(ls $CPU_SYSFS_PATH | grep "cpu[0-9]\+")

	if [ $flag == "performance" ] || [ $flag == "balance_performance" ] ||
		[ $flag == "power" ] || [ $flag == "balance_power" ]; then
		test_print_trc "Changing energy_performance_preference setting to $flag"
		for cpu in $cpus; do
			do_cmd "echo $flag > $CPU_SYSFS_PATH/$cpu/cpufreq/energy_performance_preference"
			epp_state=$(cat $CPU_SYSFS_PATH/$cpu/cpufreq/energy_performance_preference)
			[ $flag == $epp_state ] || die "Change energy_performance_preference setting to $flag Failed"
		done
	else
		die "The parameter must be performance, balance_performance, balance_power or power"
	fi
}

#$1: actual_freq: The actual freq got by turbostat
#$2: cmp_freq:
#$3: compare_type: eq or gt
function do_compare() {
	[ $# -ne 3 ] && die "You must supply 3 parameters"
	local actual_freq="$1"
	local cmp_freq="$2"
	local cmp_type="$3"
	[ "x$(echo $actual_freq | sed 's/[0-9]//g')" == "x" ] || die "The first paramter -- actual_freq must be positive integer"
	[ "x$(echo $cmp_freq | sed 's/[0-9]//g')" == "x" ] || die "The second parameter -- cmp_freq  must be positive integer"
	echo $cmp_type | grep -E "^eq$|^gt$" &>/dev/null || die "The third parameter -- cmp_type must be eq or gt"
	case $cmp_type in
	eq)
		#If cmp type is eq, the actual freq must be equal to cmp freq
		#100Mhz (100000Hkz) error is acceptable. In other words, it must be larger
		#than cmp_freq-100000 Khz and less than cmp_freq+100000 Khz
		local expected_freq_high=""
		local expected_freq_low=""
		expected_freq_high=$(("$cmp_freq" + 100000))
		expected_freq_low=$(("$cmp_freq" - 100000))
		test_print_trc "Acceptable reference freq with 100000Khz error is:$expected_freq_low Khz to $expected_freq_high Khz"
		if [ "$actual_freq" -lt "$expected_freq_low" ] || [ "$actual_freq" -gt "$expected_freq_high" ]; then
			if [ "$actual_freq" -lt "$expected_freq_low" ] && [ "x$MSR_THERM_PL" == "xc" ]; then
				test_print_trc "Since RAPL limitation is working, actual freq of cpu1 may not reach the expected limitation"
			else
				die "The error between actual freq and expected freq is larger than 100 Mhz (100000Khz)"
			fi
		fi
		;;
	gt)
		#If cmp type is gt, the actual freq must be larger than cmp freq
		#100Mhz (100000Khz) error is acceptable. In other words, it must be larger than cmp_freq-100000
		local expected_freq=""
		expected_freq=$(("$cmp_freq" - 100000))
		test_print_trc "Acceptable reference freq with 100000Khz error is:$expected_freq"
		if [ "$actual_freq" -le "$expected_freq" ]; then
			die "The error between actual freq and expected freq is larger than 100 Mhz (100000Khz)"
		fi
		;;
	esac
	return 0
}

function do_cpu_hotplug() {
	#cat $CPU_SYSFS_PATH will get a value like this: 0-3
	#filter out cpu0
	cpus=$(seq 1 $(cat $CPU_SYSFS_PATH/present | cut -d'-' -f2))
	#Hot unplug all logic cpus except cpu0
	for cpu in $cpus; do
		test_print_trc "Hot unplug cpu$cpu"
		do_cmd "echo 0 > $CPU_SYSFS_PATH/cpu$cpu/online"
	done
	sleep 10
	#Hot plug all logic cpus except cpu0
	for cpu in $cpus; do
		test_print_trc "Hot plug $cpu"
		do_cmd "echo 1 > $CPU_SYSFS_PATH/cpu$cpu/online"
	done
	sleep 10
	#Restore cpuset setting if cpuset pseudo filesystem is mounted.
	cpuset_is_mounted=$(cat /etc/mtab | grep "/sys/fs/cgroup/cpuset")
	if [ "x$cpuset_is_mounted" != "x" ]; then
		#$online_cpu cpus are online, so the number of cpus shoud be
		#0 to $online_cpu-1. Write this value into all cpuset.cpus files under /sys/fs/cgroup/cpuset/user.slice
		cpu_nr=$(("$online_cpu" - 1))
		#Find all cpuset.cpus file under that folder.
		lists=$(find /sys/fs/cgroup/cpuset/user.slice -name cpuset.cpus 2>/dev/null | sort)
		for setting in $lists; do
			test_print_trc "Write 0-$cpu_nr back to $setting"
			echo 0-$cpu_nr >$setting || die "Failed to write 0-$cpu_nr back to $setting, FAIL"
		done
	fi
	return 0
}

function checking_cpu_hotplug() {
	local cpu_stat_before_hotplug=""
	local bzy_mhz_before=""
	local cpu_stat_after_hotplug=""
	local bzy_mhz_after=""
	local delta=0

	columns="Core,CPU,Avg_MHz,Busy%,Bzy_MHz"

	test_print_trc "Read CPU states before hot plug CPU"
	cpu_stat_before_hotplug=$($PSTATE_TOOL/turbostat --show $columns sleep 10 2>&1)
	test_print_trc "$cpu_stat_before_hotplug"
	[ "x$cpu_stat_before_hotplug" == "x" ] && die "Cannot read CPU states before hot plug CPU, FAIL"
	bzy_mhz_before=$(echo "$cpu_stat_before_hotplug" | grep -E "^-" | awk '{print $5}')
	test_print_trc "Bzy_MHz before CPU hotplug is: $bzy_mhz_before"
	do_cmd do_cpu_hotplug
	test_print_trc "Read CPU states after hot plug CPU"
	cpu_stat_after_hotplug=$($PSTATE_TOOL/turbostat --show $columns sleep 10 2>&1)
	test_print_trc "$cpu_stat_after_hotplug"
	[ "x$cpu_stat_after_hotplug" == "x" ] && die "Cannot read CPU states after hot plug CPU, FAIL"
	bzy_mhz_after=$(echo "$cpu_stat_after_hotplug" | grep -E "^-" | awk '{print $5}')
	test_print_trc "Bzy_MHz after CPU hotplug is: $bzy_mhz_after"
	delta=$(($bzy_mhz_after - $bzy_mhz_before))
	[ ${delta#-} -gt 100 ] && die "Bzy_MHz has changed more than 100Mhz after CPU hot plug, FAIL"
	test_print_trc "Hotplug CPU PASS"
	return 0
}

function checking_hwp_cpu_hotplug() {
	local CAP_before_cpu_hotplug=""
	local REQ_before_cpu_hotplug=""
	local CAP_after_cpu_hotplug=""
	local REQ_after_cpu_hotplug=""

	test_print_trc "Read HWP CAP and HWP REQ before CPU hotplug"
	CAP_before_cpu_hotplug=$(rdmsr 0x771 2>/dev/null)
	[[ $CAP_before_cpu_hotplug != 0 ]] || die "Not get HWP CAP value before CPU hotplug, FAIL"
	test_print_trc "HWP CAP before is: $CAP_before_cpu_hotplug"
	REQ_before_cpu_hotplug=$(rdmsr 0x774 2>/dev/null)
	[[ $REQ_before_cpu_hotplug != 0 ]] || die "Not get HWP REQ before CPU hotplug, FAIL"
	test_print_trc "HWP REQ before is: $REQ_before_cpu_hotplug"
	do_cmd do_cpu_hotplug
	test_print_trc "Read HWP CAP and HWP REQ after CPU hotplug"
	CAP_after_cpu_hotplug=$(rdmsr 0x771 2>/dev/null)
	[[ $CAP_after_cpu_hotplug != 0 ]] || die "Not get CAP after CPU hotplug, FAIL"
	test_print_trc "HWP CAP after is: $CAP_after_cpu_hotplug"
	REQ_after_cpu_hotplug=$(rdmsr 0x774 2>/dev/null)
	[[ $REQ_after_cpu_hotplug != 0 ]] || die "Not get REQ after CPU hotplug, FAIL"
	test_print_trc "HWP REQ after is: $REQ_after_cpu_hotplug"
	[[ "$REQ_before_cpu_hotplug" == "$REQ_after_cpu_hotplug" ]] || die "HWP REQ has changed after CPU hotplug"
	test_print_trc "HWP REQ and HWP CAP CPU hotplug case PASS"
	return 0
}

#$1:case_flag
function checking_epp_req() {
	local case_flag="$1"
	local ret_num=0
	local x86_cpuload_pid=""
	[ $# -ne 1 ] && die "You must supply 1 paramter"
	num_cpus=$(ls /sys/devices/system/cpu | grep -c "cpu[0-9].*")
	test_print_trc "CPU numbers: $num_cpus"
	test_print_trc "Give all the CPUs 50% work load"
	"$PSTATE_TOOL"/x86_cpuload -s 0 -c "$num_cpus" -b 50% -t 50 &
	x86_cpuload_pid=$!

	case $case_flag in
	default)
		epp_req=0
		;;

	performance)
		epp_req=0
		;;

	balance_performance)
		epp_req=128
		;;

	balance_power)
		epp_req=192
		;;

	power)
		epp_req=255
		;;
	esac
	for ret_num in $($PSTATE_TOOL/x86_energy_perf_policy --cpu all | grep "cpu" | grep -oP '\d+ (?=window)'); do
		test_print_trc "$ret_num"
		[ $ret_num == $epp_req ] || die "checking_epp_req FAIL: it should be $epp_req, but $ret_num"
	done
	test_print_trc " checking_epp_req PASS"
	[ "x$x86_cpuload_pid" != "x" ] && do_cmd "do_kill_pid $x86_cpuload_pid"
}

#$1:should be off/passive/active
function do_change_operation_mode() {
	dest_mode=$1
	[ "x$dest_mode" == "x" ] && die "operation mode needed, it can be off/passive/active"
	#get default pstate status
	default_mode=$(cat $CPU_PSTATE_STATUS)
	echo $dest_mode >$CPU_PSTATE_STATUS
	current_mode=$(cat $CPU_PSTATE_STATUS)
	if [ "$current_mode" == "$dest_mode" ]; then
		test_print_trc "Change operation mode to $dest_mode successfully"
		echo $default_mode >$CPU_PSTATE_STATUS
	else
		die "change operation mode to $dest_mode fail"
	fi
	return 0
}

online_cpu=$(cat /proc/stat | grep -c "^cpu[0-9]\+")
max_freq=""
CPU_FREQ_CUR=""
MSR_THERM_PL=""
GOVERNOR_STATES=""
platform_base_freq=""
min_perf_pct=$(cat $CPU_SYSFS_PATH/intel_pstate/min_perf_pct)
max_perf_pct=$(cat $CPU_SYSFS_PATH/intel_pstate/max_perf_pct)
test_print_trc "Original min_perf_pct is $min_perf_pct, max_perf_pct is $max_perf_pct"
get_max_freq || block_test
test_print_trc "$online_cpu are online"
case $CASE_ID in
1)
	#Check msr reg 0x774 before and after S3
	checking_msr_precondition || block_test
	checking_msr_hwp S3 || die
	;;
2)
	#Check msr reg 0x19c when CPU1 has 100% workload
	checking_msr_precondition || block_test
	checking_msr_powerlimit || die
	;;
3)
	#Check actual CPU freq of CPU1 is larger when turbo is enabled than disabled
	checking_pstate_turbo || die
	;;
4)
	#Check actual CPU freq of CPU1 with different max_perf_pct setting under
	#performance scaling_governor setting
	#First min_perf_pct -> max_perf_pct, no need to restore scaling_governor setting
	test_print_trc "Now change scaling_governor to performance, change max_perf_pct to $min_perf_pct"
	do_cmd "do_change_governor performance"
	checking_perf_pct max $min_perf_pct 1 || die
	actual_freq_orig="$CPU_FREQ_CUR"
	#Then 100 -> max_perf_pct, restore scaling_governor setting
	test_print_trc "Now change scaling_governor to performance, change max_perf_pct to 100"
	checking_perf_pct max 100 1 || die
	do_cmd "do_change_governor 1"
	actual_freq_cur="$CPU_FREQ_CUR"
	test_print_trc "Actual_freq_cur:$actual_freq_cur"
	test_print_trc "Actual_freq_original:$actual_freq_orig"
	do_compare $actual_freq_cur $actual_freq_orig gt ||
		die "Actual freq of cpu1 with max_perf_pct=100 is less than actual freq with max_perf_pct=$min_perf_pct, FAIL"
	test_print_trc "Actual freq of cpu1 with max_perf_pct=100 is larger than actual freq with max_perf_pct=$min_perf_pct, PASS"
	;;
5)
	#Check actual CPU freq of CPU1 with different max_perf_pct setting under
	#powersave scaling_governor
	#First min_perf_pct -> max_perf_pct, no need to restore scaling_governor setting
	test_print_trc "Now change scaling_governor to powersave, change max_perf_pct to $min_perf_pct"
	do_cmd "do_change_governor powersave"
	checking_perf_pct max $min_perf_pct 1 || die
	actual_freq_orig="$CPU_FREQ_CUR"
	#Then 100 -> max_perf_pct, restore scaling_governor setting
	test_print_trc "Now change scaling_governor to powersave, change max_perf_pct to 100"
	checking_perf_pct max 100 1 || die
	do_cmd "do_change_governor 1"
	actual_freq_cur="$CPU_FREQ_CUR"
	test_print_trc "Actual_freq_cur:$actual_freq_cur"
	test_print_trc "Actual_freq_original:$actual_freq_orig"
	do_compare $actual_freq_cur $actual_freq_orig gt ||
		die "Actual freq of cpu1 with max_perf_pct=100 is less than actual freq with max_perf_pct=$min_perf_pct, FAIL"
	test_print_trc "Actual freq of cpu1 with max_perf_pct=100 is larger than actual freq with max_perf_pct=$min_perf_pct, PASS"
	;;
6)
	# max_pert_pct/2 -> max_perf_pct, CPU1 has 100% workload
	pct=$(("$max_perf_pct" / 2))
	[ $pct -lt $min_perf_pct ] && pct=$min_perf_pct
	test_print_trc "Now change scaling_governor to powersave, change max_perf_pct to $pct"
	do_cmd "do_change_governor powersave"
	checking_perf_pct max $pct 1 || die
	do_cmd "do_change_governor 1"
	actual_freq_cur="$CPU_FREQ_CUR"
	test_print_trc "Actual_freq_cur: $actual_freq_cur KHz"
	platform_base_freq=$(echo "$cpu_stat" |
		grep "base frequency" |
		awk '{print $5}')
	#Covert float to integer
	platform_base_freq=${platform_base_freq%.*}
	echo "platform base freq: $platform_base_freq MHz"
	max_freq=${max_freq%.*}
	expected_freq=$(echo "scale=1;$max_freq * $pct / 100" | bc)
	#Covert float to integer
	expected_freq=${expected_freq%.*}
	echo "original expected freq: $expected_freq MHz"
	[ $max_freq -eq $platform_base_freq ] && expected_freq=$max_freq
	#Covert Mhz to Khz
	expected_freq=$(echo "$expected_freq * 1000" | bc)
	test_print_trc "Actual Expected_freq: $expected_freq KHz"
	do_compare $actual_freq_cur $expected_freq eq ||
		die "Actual freq of cpu1 didn't reach the expected freq when max_perf_pct was changed from $max_perf_pct to $pct, FAIL"
	test_print_trc "Actual freq of cpu1 reached the expected freq when max_perf_pct was changed from $max_perf_pct to $pct, PASS"
	;;
7)
	# max_perf_pct/2 -> min_perf_pct, CPU1 has 100% workload
	pct=$(("$max_perf_pct" / 2))
	[ $pct -gt $max_perf_pct ] && pct=$max_perf_pct
	test_print_trc "Now change scaling_governor to powersave, change min_perf_pct to $pct"
	do_cmd "do_change_governor powersave"
	checking_perf_pct min $pct 1 || die
	do_cmd "do_change_governor 1"
	actual_freq_cur="$CPU_FREQ_CUR"
	test_print_trc "Actual_freq_cur: $actual_freq_cur KHz"
	platform_base_freq=$(echo "$cpu_stat" |
		grep "base frequency" |
		awk '{print $5}')
	#Covert float to integer
	platform_base_freq=${platform_base_freq%.*}
	echo "Debug platform base freq: $platform_base_freq MHz"
	max_freq=${max_freq%.*}
	expected_freq=$(echo "scale=1;$max_freq * $pct / 100" | bc)
	#Covert float to integer
	expected_freq=${expected_freq%.*}
	echo "Debug original expected freq: $expected_freq MHz"
	[ $max_freq -eq $platform_base_freq ] && expected_freq=$max_freq
	#Covert Mhz to Khz
	expected_freq=$(echo "$expected_freq * 1000" | bc)
	#Covert float to integer
	test_print_trc "Actual Expected_freq: $expected_freq KHz"
	do_compare $actual_freq_cur $expected_freq gt ||
		die "Actual freq of cpu1 is less than the expected freq when min_perf_pct was changed from $min_perf_pct to $pct, FAIL"
	test_print_trc "Actual freq of cpu1 reached the expected freq when min_perf_pct was changed from $min_perf_pct to $pct, PASS"
	;;
8)
	checking_cpu_hotplug || die
	;;
9)
	#Check msr reg 0x774 before and after S2idle
	checking_msr_precondition || block_test
	checking_msr_hwp S2idle || die
	;;
10)
	do_change_governor performance || die
	do_change_epp performance || die
	checking_epp_req default || die
	;;
11)
	do_change_governor performance || die
	do_change_epp performance || die
	checking_epp_req performance || die
	;;
15)
	do_change_governor powersave || die
	do_change_epp performance || die
	checking_epp_req performance || die
	;;
16)
	do_change_governor powersave || die
	do_change_epp balance_performance || die
	checking_epp_req balance_performance || die
	;;
17)
	do_change_governor powersave || die
	do_change_epp balance_power || die
	checking_epp_req balance_power || die
	;;
18)
	do_change_governor powersave || die
	do_change_epp power || die
	checking_epp_req power || die
	;;
19)
	checking_hwp_cpu_hotplug || die
	;;
20)
	checking_single_cpu_freq || die
	;;
21)
	do_cmd "do_change_operation_mode off"
	;;
22)
	do_cmd "do_change_operation_mode passive"
	;;
23)
	do_cmd "do_change_operation_mode active"
	;;
esac
