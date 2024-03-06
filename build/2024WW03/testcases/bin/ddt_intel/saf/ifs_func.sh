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

test_print_trc() {
	log_info=$1
	echo "|$(date +"$TIME_FMT")|TRACE|$log_info|"
}

test_print_err() {
	log_info=$1
	echo "|$(date +"$TIME_FMT")|ERROR|$log_info|"
}

############################# Global variables ################################
CUR_DIR="$(cd "$(dirname "$0")" && pwd)"
ALL_CORES=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sed -e 's/,.*//' | sort -n | uniq)
LOG_FILE=""

#### parameter list string
# other tools
ALARM_APP="${CUR_DIR}/alarm"
STRESS_APP=""

################parameter default value for CLI tools ###################
### R/W
DEFAULT_RELOAD=0

IFS_INST="0"
IFS_PATH="/sys/devices/virtual/misc/intel_ifs_${IFS_INST}"
IFS_DETAILS=${IFS_PATH}/details
IFS_STATUS=${IFS_PATH}/status
IFS_RUNTEST=${IFS_PATH}/run_test
IFS_RELOAD=${IFS_PATH}/reload
IFS_VERSION=${IFS_PATH}/image_version
IFS_UEVENT=${IFS_PATH}/uevent

readonly IFS_NAME="intel_ifs"
readonly IFS_TRACE="/sys/kernel/debug/tracing/events/intel_ifs"

#======================= functions ====================
# IFS includes 3 feature: 0: scan; 1:array; 2:SBFT
ifs_set_mode() {
	# the index of intel_ifs_x
	OPTIND=1
	while getopts "m:o:p:e:n:" arg; do
		echo "====$arg  $OPTARG===="
		case $arg in
		n) IFS_INST="$OPTARG" ;;
		*) ;;

		esac
	done

	case $IFS_INST in
	"0")
		echo "IFS function: SCAN."
		;;
	"1")
		echo "IFS function: ARRAY."
		;;
	"2")
		echo "IFS function: SBFT."
		;;
	*) exit 1 ;;
	esac

	IFS_PATH="/sys/devices/virtual/misc/intel_ifs_${IFS_INST}"
	IFS_DETAILS=${IFS_PATH}/details
	IFS_STATUS=${IFS_PATH}/status
	IFS_RUNTEST=${IFS_PATH}/run_test
	IFS_RELOAD=${IFS_PATH}/reload
	IFS_VERSION=${IFS_PATH}/image_version
	IFS_UEVENT=${IFS_PATH}/uevent
}

ifs_run_scan() {
	local cores=${ALL_CORES}
	if [ $# -gt 0 ]; then
		cores=$1
	fi

	local cnt=0
	local pass=0
	local fail=0
	local untest=0

	for cpu in $cores; do
		cnt=$((cnt + 1))
		echo "$cpu > $IFS_RUNTEST"
		echo "$cpu" >${IFS_RUNTEST}
		local ret="$?"

		if [ "$ret" = "0" ]; then
			echo "Core: $cpu Status: $(cat $IFS_STATUS) Details: $(cat $IFS_DETAILS)"
		else
			echo "[ERROR]::: run teset on core:$cpu return $ret;  status: $(cat $IFS_STATUS) Details: $(cat $IFS_DETAILS)"
		fi

		local status
		status=$(cat "$IFS_STATUS")
		if [ "$status" == "untested" ]; then
			untest=$((untest + 1))
		elif [ "$status" == "pass" ]; then
			pass=$((pass + 1))
		elif [ "$status" == "fail" ]; then
			fail=$((fail + 1))
		fi

		sleep 1
	done
	test_print_trc "TOTAL [$cnt] cores: [$pass] pass; [$fail] fail; [$untest] untested!"
	# return fail counter.
	return $fail
}

ifs_reload_blob() {
	echo "1 > $IFS_RELOAD"
	echo 1 >$IFS_RELOAD
	if [ $? = 0 ]; then
		echo "Core: $cpu Status: $(cat $IFS_STATUS) Details: $(cat $IFS_DETAILS)"
	else
		echo "[ERROR]::: Core: $cpu Status: $(cat $IFS_STATUS) Details: $(cat $IFS_DETAILS)"
	fi
	local ret
	ret=$(cat $IFS_STATUS)
	if [ "$ret" == "pass" ]; then
		ret=0
	else
		ret=1
	fi
	return $ret
}


TIME_FILE="/tmp/ifs_time"
SCAN_INTERVAL=1830
# 30 minutes interval between scans
saf_check_scan_interval() {
	if [ ! -f $TIME_FILE ]; then
		echo $SCAN_INTERVAL
		return
	fi
	local t_start
	t_start=$(date "+%Y-%m-%d %H:%M:%S")
	local pre_time
	pre_time=$(cat $TIME_FILE)
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
	local uptime
	uptime=$(awk -F. '{print $1}' /proc/uptime)
	#echo "==$uptime -lt $time_cnt "
	if [[ $uptime -lt $time_cnt ]]; then
		#echo "==$uptime -lt $time_cnt "
		time_cnt=$((time_cnt - uptime))
	else
		local intv
		intv=$(saf_check_scan_interval)
		time_cnt=$((time_cnt - intv))
	fi

	local timer_start
	timer_start=$(date "+%Y-%m-%d %H:%M:%S")
	while true; do
		local timer_end
		timer_end=$(date "+%Y-%m-%d %H:%M:%S")
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
	# check ift driver
	modinfo ${IFS_NAME} | grep -q filename
	if [[ $? -eq 0 ]]; then
		test_print_trc "Insmod SAF driver: ${IFS_NAME}"
		#insmod ift,
		modprobe intel_ifs
	fi
	# check sysfs files again
	# check the driver is loaded successfully
	if [ ! -d $IFS_PATH ]; then
		test_print_err "Failed to load driver(${IFS_NAME})! Please check dmesg!"
		exit 1
	fi

	version=$(cat ${IFS_VERSION})
	if [ "$version" == "none" ]; then
		test_print_err "Failed to get IFS version, please check blob or driver!"
		exit 1
	fi
	return 0
}

#show all of attribution or para
saf_show_options() {
	echo "====================OPTIONS VALUE========================="
	echo "# image_version: $(cat ${IFS_VERSION})"
	echo "# reload: $(cat ${IFS_RELOAD})"
	echo "# run_test: $(cat ${IFS_RUNTEST})"
	echo "# status: $(cat ${IFS_STATUS})"
	echo "# uevent: $(cat ${IFS_UEVENT})"
	echo "===================OPTIONS VALUE END======================"
}

#get the total count of physical cpus
saf_get_cpu_count() {
	local cnt
	cnt=$(grep "physical id" /proc/cpuinfo | sort -n | uniq | wc -l)
	echo "$cnt"
}

#get all cpu list
saf_get_all_cpus() {
	local cnt
	cnt=$(saf_get_core_count)
	ALL_CORES=$(seq 0 $((cnt - 1)))
	echo $ALL_CORES
}

#get the count of CORES
saf_get_core_count() {
	local cnt
	cnt=$(grep "processor" /proc/cpuinfo -c)
	echo "$cnt"
}

#For example family=6, model=85, stepping=6,
#, the corresponding files would be 06-55-06.hash/scan
saf_get_blob_name_fmt() {
	local fml
	fml=$(grep -m 1 "family" /proc/cpuinfo | awk '{printf "%02x",$4;}')
	local mdl
	mdl=$(grep -m 1 "model" /proc/cpuinfo | awk '{printf "%02x",$3;}')
	local stp
	stp=$(grep -m 1 "stepping" /proc/cpuinfo | awk '{printf "%02x",$3;}')

	local suffix=""
	case ${IFS_INST} in
		0) suffix="scan" ;;
		2) suffix="sbft" ;;
		*) ;;
	esac

	blob_name="${fml}-${mdl}-${stp}.${suffix}"

	test_print_trc "Get the format of name: $blob_name"
}

#check the sibling and remove core sibling from CPUlist
cpulist_no_sib=()

# get sibling of a core
saf_get_sibling() {
	local core=$1
	local i=0
	local sib
	sib=$(cat /sys/devices/system/cpu/cpu${core}/topology/thread_siblings_list | sed 's/,/ /g')
	for i in ${sib[*]}; do
		if [[ ! ${core} -eq ${i} ]]; then
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
	for j in ${cores[@]}; do
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
	local sum
	if [ $# -eq 0 ]; then
		sum=$(saf_get_core_count)
	else
		sum=$1
	fi

	# first to get the cpu number of cpu list
	nums=$(shuf -i 1-$sum -n 1)
	# get the list of cpu
	local cpus=$(expr $sum - 1)
	nlst=$(shuf -i 0-$cpus -n $nums | sort -n)
	echo $nlst
	#return $nlst
}

saf_gen_offline_list() {
	local cpuList=$1
	#echo "====3 $cpuList===="
	local offCpus=""
	if [ $# -eq 0 ]; then
		offCpus=$(saf_gen_cpu_list)
	else
		if [[ $cpuList == "-1" ]]; then
			offCpus=$(saf_gen_cpu_list)
		else
			cpuList=${cpuList//,/ }
			cnt=$(echo "$cpuList" | wc -w)
			local nums
			nums=$(shuf -i 0-$cnt -n 1)
			offCpus=$(shuf -e $cpuList -n $nums | sort -n)
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
	local acpulst
	local tmp=$2
	acpulst=${tmp//,/ }

	local cnt
	cnt=$(echo "$acpulst" | wc -w)
	test_print_trc "online cores:  count $cnt!!! set  $on"

	for j in $acpulst; do
		#echo "$on > /sys/devices/system/cpu/cpu${j}/online"
		echo "$on" >/sys/devices/system/cpu/cpu"${j}"/online
	done
}

#generate the list of cpu run scan
saf_gen_cpu_para() {
	nums=$(shuf -i 1-$num_cpus -n 1)
	test_print_trc "-----------CPU:$nums-----------"

	local cpus
	cpus=$((num_cpus - 1))
	test_print_trc "-----------CPU!!!!:$cpus-----------"
	nlst=$(shuf -i 0-$cpus -n $nums | sort -n)
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
		cpus=${j//-/ }
		cnt=$(echo $cpus | wc -w)
		[[ $cnt -gt 1 ]] && cpus=$(seq $cpus)
		for c in $cpus; do
			#set core to online
			echo 1 >>/sys/devices/system/cpu/cpu$c/online
		done
	done
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
	if [ -e "${IFS_TRACE}/enable" ]; then
		echo 0 >${IFS_TRACE}/enable
		echo 1 >${IFS_TRACE}/enable
	fi
	# clear trance info
	echo " " >/sys/kernel/debug/tracing/trace
	return
}

ifs_catch_event_trace_info() {
	local file=$1
	echo "=========/sys/kernel/debug/tracing/trace======" >>"$file"
	cat /sys/kernel/debug/tracing/trace >>"$file"
}

#run cli to do test
saf_run_cli() {
	local ret=0
	test_print_trc "##########################################"
	local para=$1
	#saf_show_options
	test_print_trc "run: ${CLI_PATH} ${para}"
	#$CLI_PATH $para
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
	for i in $(seq 0 $((cnt - 1))); do
		#ret=$(grep -o "${err_arrays[i]}" $dmsg | wc -l)
		ret=$(grep -o "${err_arrays[i]}" "$dmsg" -c)
		if [[ ${ret} -gt 0 ]]; then
			test_print_err "Get ${ret} errors: ${err_arrays[i]}"
			return "$i"
		fi
	done
	return 0
}

saf_check_scan_dmesg() {
	if [ "$IFS_INST" == "0" ]; then
		# PERIODIC scan kernel error message from scan_test_status in runtest.c
		err_arrays=(
			"Non valid chunks in the range"
			"Mismatch in arguments between"
			"Non ECC error"
			"Core not capable of performing SCAN"
			"Exceeded number of Logical"
			"Core Abort SCAN Response"
		)
	elif [ "$IFS_INST" == "2" ]; then
		# SBFT kernel error message from sbft_test_status in runtest.c
		err_arrays=(
			"Core Abort SBFT Response"
			"Non valid chunks in the range"
			"Non ECC error"
			"Mismatch in arguments"
			"Exceeded number of Logical Processors"
			"Core not capable of performing SBFT"
			"SBFT program index not valid"
		)
	else
		return 0
	fi
	echo "$1"
	saf_check_message "$1"
	return $?
}
#check CLI log
saf_check_scan_log() {
	err_arrays=(
		"Failing cpu"
		"FAILURE: Chunk  "
		"Core not capable of performing SCAN"
	)
	echo "$1"
	saf_check_message "$1"
	return $?
}

test_print_trc "====Finish $0====="
