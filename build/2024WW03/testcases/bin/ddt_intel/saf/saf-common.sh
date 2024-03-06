#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2019 Intel - http://www.intel.com/
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
###############################################################################
# @desc common functions or var used by testcase
# @resource
#	driver: intel_ifs
#	sysfs: /sys/devices/system/cpu/ifs/		//all core
#	       /sys/devices/system/cpu/cpux/ifs/	//specify core
#	CLI: in_field_scan_app
#	stress tool: stressapptest
#
# @history
#		2022-03-11: First version transfer from saf_common.sh!!!!
################################################################################

################################################################################
#/sys/devices/system/cpu/ifs/
#There are files showing which CPUs are in each of the pass/untested/fail states:
# cpu_pass_list			//
# cpu_untested_list
# cpu_fail_list
#
# image_version
# reload	//reload blob files
# run_test	//Run tests on all cores
# status	//global status. Shows the most serious status across all cores (fail > untested > pass)
# uevent
#
#/sys/devices/system/cpu/cpu1/ifs/
#the status of the most recent test on that core
# status
# run_test	//Run test
# detail	//The details file reports the hex value of the SCAN_STATUS MSR
################################################################################

source "common.sh" # Import do_cmd(), die() and other functions
source "dmesg_functions.sh"

###################################################################
#all function should use "ifs_" as prefix
###################################################################

############################# Global variables ################################
readonly SYSFS_CPU_DIR="/sys/devices/system/cpu/"
readonly SYSFS_CPU_SCAN_DIR="${SYSFS_CPU_DIR}/ifs/"
readonly IFS_PARA_DIR="/sys/module/intel_ifs/parameters/"
#### parameter list string
readonly SAF_PARAMETER_LIST=":c:m:r:q:s:t:d:w:p:f:i:a:z:o:I:R:"

readonly DEFAULT_NOINT=1
readonly DEFAULT_RETRY=5
readonly DEFAULT_CYCLE_WAIT=0

# driver var
CUR_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_PATH="CLI"
ALARM_APP="${CUR_DIR}/alarm"
STRESS_APP=""

#########################################
# CASE ID
CASE_RELOAD=0
CASE_BASIC_SCAN=1
CASE_CHECK_RACE=2
CASE_WITH_MCE=3
CASE_SCAN_STRESS=4
CASE_MEM_STRESS=5
#########################################

################parameter default value for CLI tools ###################
### R/W
DEFAULT_RELOAD=0
DEFAULT_NOINT=0

### trigger only

### Read only
# read from sysfs
CHUNK_SIZE=0
#======================= functions ====================

#check system uptime
#ift from E0, ucode will enforce the rule of 30 minutes wait time between SAF runs on a core
saf_check_sys_uptime() {
	sys_uptime=$(awk -F. '{print $1}' /proc/uptime)
	#echo "====SYSTEM boot $sys_uptime seconds ago!"
	if [ $sys_uptime -lt 1800 ]; then
		test_print_err "Too short since system boot!:$sys_uptime"
		if [ $# -eq 0 ]; then
			exit 1
		fi
		return $sys_uptime
	fi
	return 0
}

# set/check CLI path
saf_confirm_CLI() {

	modinfo intel_ifs | grep -q filename
	if [[ $? -eq 0 ]]; then
		#change CLI to ift
		CLI_PATH="${CUR_DIR}/in_field_scan_app"
	else
		# check saf driver(below 5.15 linux kernel)
		modinfo saf | grep -q filename
		if [[ $? -eq 0 ]]; then
			CLI_PATH="${CUR_DIR}/scan_field_app"
		fi
	fi
	if [ -d $CLI_PATH ]; then
		test_print_err "CLI : $CLI_PATH is not exist!"
		exit -1
	fi
}

TIME_FILE="/tmp/ifs_time"
SCAN_INTERVAL=1830
# 30 minutes interval between scans
saf_check_scan_interval() {
	if [ ! -f $TIME_FILE ]; then
		echo $SCAN_INTERVAL
		return
	fi
	local t_start=$(date "+%Y-%m-%d %H:%M:%S")
	local pre_time=$(cat $TIME_FILE)
	#date +%s -d "${pre_time}"

	duration=$(($(date +%s -d "${t_start}") - $(date +%s -d "${pre_time}")))
	#echo "$(date +%s -d "${t_start}") $(date +%s -d "${pre_time}")"

	echo $duration
	return

}

# temp file records the end time for a scan
saf_save_scan_time() {
	date "+%Y-%m-%d %H:%M:%S" >$TIME_FILE
}

saf_time_tick() {
	local time_cnt=$SCAN_INTERVAL
	if [ $# -gt 0 ]; then
		time_cnt=$1
	fi
	local uptime=$(awk -F. '{print $1}' /proc/uptime)
	if [ $uptime -lt $time_cnt ]; then
		time_cnt=$(expr $(($time_cnt - $uptime)))
	else
		local intv=$(saf_check_scan_interval)
		time_cnt=$(expr $(($time_cnt - $intv)))
	fi

	local timer_start=$(date "+%Y-%m-%d %H:%M:%S")
	while [ 1 ]; do
		local timer_end=$(date "+%Y-%m-%d %H:%M:%S")
		local duration=$(($(date +%s -d "${timer_end}") - $(date +%s -d "${timer_start}")))
		echo -ne "Waiting ${time_cnt}: $duration seconds      \r"
		if [ $duration -gt $time_cnt ]; then
			return
		fi
		sleep 1

	done
}

####################################################
# check if the driver was loaded successfully
saf_probe_check() {
	# specify CLI path
	saf_confirm_CLI
	# first check sysfs
	if [ -d $SYSFS_CPU_SCAN_DIR ]; then
		return 0
	fi
	# check ift driver
	modinfo intel_ifs | grep -q filename
	if [[ $? -eq 0 ]]; then
		test_print_trc "Insmod SAF driver: intel_ifs"
		#insmod ift,
		modprobe intel_ifs
	else
		# check saf driver(below 5.15 linux kernel)
		modinfo saf | grep -q filename
		if [[ $? -eq 0 ]]; then
			test_print_trc "Insmod SAF driver: saf"
			#insmod saf,
			modprobe saf
		fi
	fi
	# check sysfs files
	#check the driver is loaded successfully
	if [ ! -d $SYSFS_CPU_SCAN_DIR ]; then
		test_print_err "Saf driver (ift/saf)  load failed! Please check the ift/saf driver or check the message (dmesg)!"
		#exit -1
		return
	fi

	#get the default parameter value
	saf_default_para_value
	return 0
}

#show all of attribution or para
saf_show_options() {
	echo "====================OPTIONS VALUE========================="
	echo "# cpu_pass_list: $(cat ${SYSFS_CPU_SCAN_DIR}\cpu_pass_list)"
	echo "# cpu_untested_list: $(cat ${SYSFS_CPU_SCAN_DIR}\cpu_untested_list)"
	echo "# cpu_fail_list: $(cat ${SYSFS_CPU_SCAN_DIR}\cpu_fail_list)"
	echo "# image_version: $(cat ${SYSFS_CPU_SCAN_DIR}\image_version)"
	echo "# reload: $(cat ${SYSFS_CPU_SCAN_DIR}\reload)"
	echo "# run_test: $(cat ${SYSFS_CPU_SCAN_DIR}\run_test)"
	echo "# status: $(cat ${SYSFS_CPU_SCAN_DIR}\status)"
	echo "# uevent: $(cat ${SYSFS_CPU_SCAN_DIR}\uevent)"
	echo "# ===================parameter============================"
	echo "# noint: $(cat ${IFS_PARA_DIR}\noint)"
	echo "# retry: $(cat ${IFS_PARA_DIR}\retry)"
	echo "===================OPTIONS VALUE END======================"

	# cpu_untested_list
	# cpu_fail_list

}
#get the default value of parameter
saf_default_para_value() {
	return
}

#get the total count of physical cpus
saf_get_cpu_count() {
	local cnt=$(cat /proc/cpuinfo | grep "physical id" | sort | uniq | wc -l)
	echo $cnt
}

#get the count of CORES
saf_get_core_count() {
	local cnt=$(cat /proc/cpuinfo | grep "processor" | wc -l)
	echo $cnt
}

#For example family=6, model=85, stepping=6,
#, the corresponding files would be 06-55-06.hash/scan
saf_get_blob_name_fmt() {
	local fml=$(cat /proc/cpuinfo | grep -m 1 "family" | awk '{printf "%02x",$4;}')
	local mdl=$(cat /proc/cpuinfo | grep -m 1 "model" | awk '{printf "%02x",$3;}')
	local stp=$(cat /proc/cpuinfo | grep -m 1 "stepping" | awk '{printf "%02x",$3;}')
	blob_name="$fml-$mdl-$stp"
	test_print_trc "Get the format of name: $blob_name"
}

#check the sibling and remove core sibling from CPUlist
cpulist_no_sib=()

# get sibling of a core
saf_get_sibling() {
	local core=$1
	local i=0
	local sib=$(cat /sys/devices/system/cpu/cpu${core}/topology/thread_siblings_list | sed 's/,/ /g')
	for i in ${sib[*]}; do
		if [ ! ${core} -eq ${i} ]; then
			return $i
		fi
	done
	return -1
}

saf_remove_sibling_cores() {
	[ $# -eq 0 ] && return 0
	local cpulist_no_sib=()
	local cores=$1
	local j=0
	local i=0
	#echo "####${cores[*]}"
	for j in ${cores[*]}; do
		local cur=$j
		saf_get_sibling $cur
		local sib=$?
		[ "$sib" == "-1" ] || {
			local ret=1
			for i in ${cpulist_no_sib[*]}; do
				[ "$sib" == "$i" ] && ret=0
			done
			#in_array "$sib"
			#	ret=$?
			if [ ! $ret -eq 0 ]; then
				for i in ${cpulist_no_sib[*]}; do
					[ "$cur" == "$i" ] && ret=0
				done
				#		in_array "$cur"
				#		ret=$?
				if [ $ret -eq 1 ]; then
					cpulist_no_sib=(${cpulist_no_sib[@]} $cur)
				fi
			fi
		}
		#echo "Get $cur=$sib ---> ${cupset[@]}"

	done

	echo ${cpulist_no_sib[*]}

}

#gen a list of cpus
saf_gen_cpu_list() {
	local sum=$1
	[ $# -eq 0 ] && {
		sum=$(saf_get_core_count)
	}
	# first to get the cpu number of cpu list
	nums=$(shuf -i 1-$sum -n 1)
	# get the list of cpu
	local cpus=$(expr $sum - 1)
	nlst=$(shuf -i 0-$cpus -n $nums | sort)
	echo $nlst
	#return $nlst
}

saf_gen_offline_list() {
	local cpuList=$1

	local offCpus=""
	if [ $# -eq 0 ]; then
		offCpus=$(saf_gen_cpu_list)
	else
		if [[ $cpuList == "-1" ]]; then
			offCpus=$(saf_gen_cpu_list)
		else
			cpuList=$(echo "$cpuList" | sed 's/,/ /g')
			cnt=$(echo $cpuList | wc -w)
			local nums=$(shuf -i 0-$cnt -n 1)
			offCpus=$(shuf -e $cpuList -n $nums | sort)
		fi
	fi
	echo "$offCpus"
}

#to offline cpus
#para1: 1:on  0:off
#para2: cpu_list to run scan
saf_set_online() {
	local fun_name="[set_online]"
	local on=$1
	local acpulst=$(echo $2 | sed 's/,/ /g')

	local cnt=$(echo $acpulst | wc -w)
	test_print_trc "online cores:  count $cnt!!! set  $on"

	for j in $acpulst; do
		#echo "$on > /sys/devices/system/cpu/cpu${j}/online"
		echo $on >/sys/devices/system/cpu/cpu${j}/online
	done
}

#generate the list of cpu run scan
saf_gen_cpu_para() {
	nums=$(shuf -i 1-$num_cpus -n 1)
	test_print_trc "-----------CPU:$nums-----------"

	local cpus=$(expr $num_cpus - 1)
	test_print_trc "-----------CPU!!!!:$cpus-----------"
	nlst=$(shuf -i 0-$cpus -n $nums | sort)
	local str=""
	for j in $nlst; do
		str="$j,${str}"
	done
	test_print_trc "Get cpulist:$str"

	cpu_para_list=$str
}

saf_restore_online() {
	#get core list of offline from /sys/offline
	offcpus=$(sed 's/,/ /g' /sys/devices/system/cpu/offline)
	for j in $offcpus; do
		cpus=$(echo $j | sed 's/-/ /g')
		cnt=$(echo $cpus | wc -w)
		[ $cnt -gt 1 ] && cpus=$(seq $cpus)
		for c in $cpus; do
			#set core to online
			echo 1 >>/sys/devices/system/cpu/cpu$c/online
		done

	done

}

# set parameter noint with zero or non-zero
saf_set_para_noint() {
	local v=$1
	echo "$v > $IFS_PARA_DIR/noint"
	return
}

# set parameter retry with 1 to 20
saf_set_para_retry() {
	local v=$1
	echo "$v > $IFS_PARA_DIR/retry"
	return
}

saf_set_cycle_wait() {
	return
}

saf_restore_default_all_parameter() {
	local fun_name="[restore_default_all_parameter] "
	test_print_trc "${fun_name} ------>::: "
	#
	#	# restore online parameter
	saf_restore_online

	test_print_trc "${fun_name}<-------::: <OVER> "
}

#get a number in range[start.. end]
saf_get_random_number() {
	local s=$1
	local e=$2
	local num=$(shuf -i $s-$e -n 1)
	#echo "shuf -i $s-$e -n 1"
	echo $num
}

# set event trace
ifs_interrupt_trace_init() {
	# enable trace function of intel_ifs
	local trcFile="/sys/kernel/debug/tracing/events/ifs/enable"
	if [ -e $trcFile ]; then
		echo 0 >/sys/kernel/debug/tracing/events/ifs/enable
		echo 1 >/sys/kernel/debug/tracing/events/ifs/enable
	fi
	# clear trance info
	echo " " >/sys/kernel/debug/tracing/trace

	return
}

ifs_catch_event_trace_info() {
	local file=$1
	echo "=========/sys/kernel/debug/tracing/trace======" >>$file
	cat /sys/kernel/debug/tracing/trace >>$file
}

#run cli to do test
saf_run_cli() {
	local ret=0
	test_print_trc "##########################################"
	local para=$1
	#saf_show_options
	test_print_trc "run: ${CLI_PATH} ${para}"
	$CLI_PATH $para
	ret=$?
	test_print_trc "Get result:$ret"
	test_print_trc "##########################################"
	return $ret
}

saf_show_title() {
	echo "##########################################"
	test_print_trc "$1"
	echo "##########################################"
}

#check kernel log
err_arrays=()
saf_check_message() {
	[ $# -eq 0 ] && return 0
	local dmsg=$1
	local cnt=${#err_arrays[@]}
	# check noraml errors
	for i in $(seq 0 $(($cnt - 1))); do
		#echo "===${err_arrays[i]}======"
		#grep -o "${errarrays[i]}" $dmsg
		ret=$(grep -o "${err_arrays[i]}" $dmsg | wc -l)
		if [ ${ret} -gt 0 ]; then
			test_print_err "Get ${ret} errors: ${err_arrays[i]}"
			return $i
		fi
	done
	return 0

}

saf_check_scan_dmesg() {
	err_arrays=(
		"Non valid chunks in the range"
		"Non ECC error"
		"Core not capable of performing SCAN"
	)
	echo $1
	saf_check_message $1
	return $?

}
#check CLI log
saf_check_scan_log() {
	err_arrays=(
		"Failing cpu"
		"FAILURE: Chunk  "
		"Core not capable of performing SCAN"
	)
	echo $1
	saf_check_message $1
	return $?
}

test_print_trc "====Finish saf-common.sh====="
