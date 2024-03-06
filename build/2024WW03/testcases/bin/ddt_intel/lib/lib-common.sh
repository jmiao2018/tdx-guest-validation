#!/bin/bash
#
################################################################################
##                                                                            ##
## Copyright (c) Intel, 2014                                                  ##
##                                                                            ##
## Author:                                                                    ##
##  Wenzhong Sun <wenzhong.sun@intel.com>                                     ##
##                                                                            ##
## History:                                                                   ##
##  Aug 22, 2014 - (Wenzhong Sun) Created                                     ##
##  Sep 08, 2015 - (Jose Perez Carranza) Updated                              ##
##                  -Add Functions to check dependencies                      ##
##                  -Modify load_mod function to use modprobe                 ##
##  Oct 26, 2016 - (Kun Yan) Updated                                          ##
##		    -Change the kernel module path for Android M/N            ##
################################################################################
#
# File:
#	lib-common.sh
#
# Description:
#	A common library file for common functions and variables used by ALL driver test.
#
# Functions:
#	PnL
#	parse_platform_feature
#	get_kmod_name
#	chk_adb_connection
#	check_dmesg_error
#	is_mod_loaded
#	test_drv_loadable
#	load_mod
#	clear_holders
#	check_module_dependencies
#	unload_mod
#	prepare_drv_test
#	test_module_load_unload
#	cleanup
#	start_test
#	end_test
#	MUL
#	MUL_FO
#	DIV
#	SUB
#	CMP
#-----------------------------------------------------------------------
#shopt -s expand_aliases
#-----------------------------------------------------------------------
# Global variables
RET=0
RUNENV=""
RUNCMD=""
#ROOTDIR="../.."
DRV_NAME=""	# should be assigned in each test
MOD_BUILTIN_FILE="/lib/modules/$(uname -r)/modules.builtin"
MOD_DEP_FILE="/lib/modules/$(uname -r)/modules.dep"
MOD_ALIAS_FILE="/lib/modules/$(uname -r)/modules.alias"
TMP_LOG="/mnt/obb/_tmp.log"
# Flag to indicate whether to enable generating TRC report file, default is no
TRC_ENA="no"
# User specified info used for generating TRC report, eg. JIRA bug ID and desc
TRC_INFO=""
# Flag to indicate whether to create a new Test Report if already exist one, defalt is no(0)
NEW_TRC=0
TRC_DIR="${ROOTDIR}"
LOG_DIR="/data/ltp/test_log"
# BIN dir to store user-specific tools for test
BIN_DIR="/data/ltp/bin"
# Setup ADB shell environment
SETUP_ENV="export PATH=\$PATH:$BIN_DIR"
# Add var to handle special module names
MOD_NAME_ALIAS_FIXED=""
#-----------------------------------------------------------------------
# Function: PnL - Print log and save to Log file
# Input:
#	Arg1 - log type [0-PASS|1-FAIL|2-INFO|...]
#	Arg2 - string to print and log
#	Arg... - extra strings to print and log
# Output: None
#
function PnL()
{
	[ $# -lt 2 ] && return

	local LT="*LOG*"
	case $1 in
		0)	LT="*PASS*";;
		1)	LT="*FAIL*";;
		2)	LT="*INFO*";;
	esac
	shift
	if [ -n "${LOG_FILE}" ];then
		echo "$(date +%Y%m%d%H%M%S) [${DRV_NAME}] ${LT} $@" | tee -a ${LOG_FILE}
	else
		echo "$(date +%Y%m%d%H%M%S) [${DRV_NAME}] ${LT} $@"
	fi
}

#-----------------------------------------------------------------------
# Function: run_cmd - Run a shell command on Host or Target
# Input:
#     arg1: Flag for HOST env only to seperate shell command into 2 part
#     by ">" or ">>". The first part will be applied to DUT while the second
#     part will be applied to HOST.
#     values can be:
#         0 - do separation;
#         1 - do not seperate shell command;
#     arg2...: shell command with parameters
# Output: N/A
function run_cmd()
{
	CMDFLAG=$1
	shift
	CMD=$*
	local char=""
	local CMD_DUT=""
	local CMD_HOST=""
	local REDIR_APPEND="no"
	local TOHOST="no"

	if [ "${RUNENV}" = "HOST" ];then
		if [ "${CMDFLAG}" -eq 0 ];then
			# Parse ">" and ">>" character to seperate it from adb shell command
			# as for HOST environment, we need to re-direct output to HOST not DUT.
			for char in $CMD
			do
				if [ "$char" = ">" ];then
					TOHOST="yes"
				elif [ "$char" = ">>" ];then
					REDIR_APPEND="yes"
					TOHOST="yes"
				elif [ "$TOHOST" = "yes" ];then
					CMD_HOST="$CMD_HOST $char"
				else
					CMD_DUT="$CMD_DUT $char"
				fi
			done

			CMD_HOST=$(echo "$CMD_HOST" | sed -e 's/^[ \t]*//g' -e 's/[ \t]*$//g')
			CMD_DUT=$(echo "$CMD_DUT" | sed -e 's/^[ \t]*//g' -e 's/[ \t]*$//g')

			if [ "$REDIR_APPEND" = "yes" ];then
				${RUNCMD} "${SETUP_ENV};${CMD_DUT}" >> "$CMD_HOST"
			else
				${RUNCMD} "${SETUP_ENV};${CMD_DUT}" > "$CMD_HOST"
			fi
		else
			${RUNCMD} "${SETUP_ENV};${CMD}"
		fi
	elif [ "${RUNENV}" = "DUT" ];then
		eval ${CMD}
	else
		PnL 2 Unknown Running Environment
	fi
}

#-----------------------------------------------------------------------
# Function: Parse PLATFORM file for HW/SW features
# Input: N/A
# Output:
#	ARCH - CPU Architecture
#	SOC - SoC name
#	MACHINE	- Platform device name
#	DRIVERS - Supported Driver list
parse_platform_feature()
{
if [ -n "${PLATFORM}" -a -f "${ROOTDIR}/platforms/${PLATFORM}" ];then
	local idx=0
	while read -r line
	do
		# bypass commented lines w/ "#" as the first character
		echo "${line}" | grep -e "^#.*" > /dev/null
		[ $? -eq 0 ] && continue

		case "${idx}" in
			0)	ARCH="${line}";;
			1)	SOC="${line}";;
			2)	MACHINE="${line}";;
			3)	DRIVERS="${line}";;
			*)	DRIVERS="${DRIVERS},${line}";;
		esac
		idx=$(expr ${idx} + 1)
	done < "${ROOTDIR}/platforms/${PLATFORM}"
fi
export ARCH
export SOC
export MACHINE
export DRIVERS
}

#-----------------------------------------------------------------------
# Function: get_kmod_name - Get Kernel module name based on MACHINE
# One driver may need multiple kernel modules to make it functional,
# arrays are used to store MOD_NAME and MOD_NAME_ALIAS
# Input: N/A
# Output:
#	MOD_NAME[]
#	MOD_NAME_ALIAS[]
#	MOD_NAME_ALIAS_FIXED[]
#
function get_kmod_name()
{
	MOD_NAME_LIST=$(../lib/get_module_config_name.sh "${DRV_NAME}" "${MACHINE}") || echo ""

	if [ -z "${MOD_NAME_LIST}" ];then
		PnL 2 "Module name for ${DRV_NAME} driver is not found"
		return
	fi

	local idx=0
	for mod_name in ${MOD_NAME_LIST}
	do
		MOD_NAME[$idx]="${mod_name}"

		# There are some cases that the module file name does not match with
		# the driver name exactly, which will cause test case fails to get
		# correct module info.
		# For example, accel driver name is bmc150_accel but its module file is
		# bmc150-accel.
		# MOD_NAME_ALIAS is used to fix this kind of issue, by providing an
		# alias name which will be used together with MOD_NAME to test module
		# load/unload.
		if $(echo "${MOD_NAME[$idx]}" | grep -qE "[-|_]");then
			partone=$(echo "${MOD_NAME[$idx]}" | awk -F"-|_" '{print $1}')
			parttwo=$(echo "${MOD_NAME[$idx]}" | awk -F"-|_" '{print $2}')
			if $(echo "${MOD_NAME[$idx]}" | grep -qE "-");then
				MOD_NAME_ALIAS[$idx]="$partone"_"$parttwo"
			else
				MOD_NAME_ALIAS[$idx]="$partone"-"$parttwo"
			fi
		# There is some cases that module does not match with the driver name
		# exactly, which will cause test failure, there's already a function to
		# create a mod_name_alias,but it does not cover all name module cases.
		# Example: accel driver name is kxcjk-1013, but module file is kxcjk1013
		# since module is included as built-in it is not listed on module.alias
		# this new mod_name_alias_fixed will cover this kind of cases.
			MOD_NAME_ALIAS_FIXED[$idx]="$partone""$parttwo"
		else
			# Keep MOD_NAME_ALIAS same with MOD_NAME if no such issue
			MOD_NAME_ALIAS[$idx]="${MOD_NAME[$idx]}"
			MOD_NAME_ALIAS_FIXED[$idx]="${MOD_NAME[$idx]}"
		fi
		idx=$(($idx+1))
	done
}

#-----------------------------------------------------------------------
# Function: chk_adb_connection - Check ADB connection
# Input: N/A
# Output: return 0 if ADB is connected;
#	otherwise, exit the test, and BLOCK result is output
#
function chk_adb_connection()
{
	local ADBCMD="adb"
	test -z "$DEVID" || ADBCMD="adb -s ${DEVID}"

	# Make sure ADB is ready to use
	${ADBCMD} shell echo Hello > /dev/null
	# Verify we can connect to the DUT
	hello=$(${ADBCMD} shell echo Hello | tr -d '\r')
	if [ $? -ne 0 -o "$hello" != "Hello" ] ; then
		echo Test device: ${MACHINE}  is not connected correctly.
		PnL 2 Result: ====BLOCK====
		exit 2
	fi
	# Run as root
	${ADBCMD} root > /dev/null

	# Get DEVID if not specified
	test -n "$DEVID" || DEVID=$(${ADBCMD} shell getprop ro.serialno | tr -d '\r')
}

#-----------------------------------------------------------------------
# Function: check_dmesg_error - check dmesg log whether contain failed info
# Input: 1-keywords pattern - used for grep dmesg; 2-timestamp after which
#        the message is valid
# Output: return 0 if no failed info;
#	otherwise, 1 is returned, and dmesg is print and saved to log
#
function check_dmesg_error()
{
	PATTERN=$1
	LAST_TS=$2

	# Store kernel dmesg log into a tmp file
	run_cmd 0 "dmesg > ${TMP_LOG}"

	count=$(cat "${TMP_LOG}" | grep "${PATTERN}" | grep -i "failed" | wc -l)
	while [ "${count}" -gt 0 ]
	do
		GET_TS=$(cat "${TMP_LOG}" | grep "${PATTERN}" | grep -i "failed" | \
				sed -n ''$count'p' | sed -e 's/\[/\n/g' -e 's/\]/\n/g' | \
				sed -n '2p')
		ret=$(CMP "${GET_TS}" "${LAST_TS}")
		if [ "${ret}" -ge 0 ];then
			RET=1
			PnL 1 $(run_cmd 1 "dmesg | grep ${PATTERN}")
			return 1
		fi
		count=$(($count-1))
	done

	return 0
}

#-----------------------------------------------------------------------
# Function: check whether kernel module is loaded or not
# Input: arg1 - module name; arg2 - module alias
# Output: return 0 if loaded, 1 if not loaded
#
function is_mod_loaded()
{
	local mod_name=$1
	local mod_name_alias=$2

	ret1=$(run_cmd 1 "lsmod | grep -q "${mod_name}" && echo -n GOTYOU")
	ret2=$(run_cmd 1 "lsmod | grep -q "${mod_name_alias}" && echo -n GOTYOU")

	if [ -n "${ret1}" -a "${ret1}" = "GOTYOU" ] || [ -n "${ret2}" -a "${ret2}" = "GOTYOU" ];then
		PnL 2 kernel module "${mod_name}" is loaded
		return 0
	else
		PnL 2 kernel module "${mod_name}" is not loaded
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: test if driver is loadable(built as a module) or not (kernel built-in)
# Input: arg1 - module name; arg2 - module alias
# Output: return 0 if built as kernel module; return 1 if built-in;
#         otherwise, RET=1 && 2 is returned
function test_drv_loadable()
{
	local mod_name=$1
	local mod_name_alias=$2

	ret1=$(run_cmd 1 "test -f ${MOD_BUILTIN_FILE} && cat ${MOD_BUILTIN_FILE} | \
			grep -q "${mod_name}" && echo -n GOTYOU")
	ret2=$(run_cmd 1 "test -f ${MOD_BUILTIN_FILE} && cat ${MOD_BUILTIN_FILE} | \
			grep -q "${mod_name_alias}" && echo -n GOTYOU")

	if [ -n "${ret1}" -a "${ret1}" = "GOTYOU" ] || [ -n "${ret2}" -a "${ret2}" = "GOTYOU" ];then
		PnL 0 Driver "${mod_name}" is registered and built-in kernel, is NOT loadable.
		return 1
	else
		ret1=$(run_cmd 1 "test -f /lib/modules/${mod_name}.ko && echo -n GOTYOU")
		ret2=$(run_cmd 1 "test -f /lib/modules/${mod_name_alias}.ko && echo -n GOTYOU")
		if [ -n "${ret1}" -a "${ret1}" = "GOTYOU" ] || [ -n "${ret2}" -a "${ret2}" = "GOTYOU" ];then
			PnL 0 Driver "${mod_name}" is registered and loadable as a kernel module.
			return 0
		else
			PnL 1 Driver "${mod_name}" can NOT be identified as kernel module or built-in.
			RET=1
			return 2
		fi
	fi
}

#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
# Function: clear_holders - Clear holders for load/unload driver
# Input: arg1 - module name: arg2 - module alias
# Return: 0 if successful; 1 if failed.
function clear_holders()
{
	local module_name_clear=$1
	local module_name_alias_clear=$2
	local holders_array=($(run_cmd 1 "ls /sys/module/$module_name_clear/holders"))

	if [ -z "${holders_array}" ];then
		holders_array=($(run_cmd 1 "ls /sys/module/$module_name_alias_clear/holders"))
		if [ -z "${holders_array}" ];then
			PnL 2 There are no Holders for "$module_name_clear" nor "$module_name_alias_clear"
			return
		fi
	fi

	idx=$((${#holders_array[@]}-1))
	while [ "${idx}" -ge 0 ]
	do
		# Unload kernel holder module
		#unload_mod "${holders_array[$idx]}" " "
		#[ $? -ne 0 ] && return 1
		PnL 2 Unloading Kernel Module Holder: "${holders_array[$idx]}" ...
		run_cmd 0 "rmmod ${holders_array[$idx]}"
		idx=$(($idx-1))
	done
	return 0
}

#-----------------------------------------------------------------------
# Function: check_module_dependencies - check if module has dependencies
# Input: arg1 - module name; arg2 - module alias
# Output: return 0 if succeed, otherwise, 1 is returned
#
function check_module_dependencies()
{
	local kmodule_search="$1.ko:\ [a-zA-Z0-9]"
	local kmodule_alias_search="$2.ko:\ [a-zA-Z0-9]"


	ret1=$(run_cmd 1 "test -f ${MOD_DEP_FILE} && cat ${MOD_DEP_FILE} | \
			grep -qe "${kmodule_search}" && echo -n GOTYOU")
	ret2=$(run_cmd 1 "test -f ${MOD_DEP_FILE} && cat ${MOD_DEP_FILE} | \
			grep -qe "${kmodule_alias_search}" && echo -n GOTYOU")

	if [ -n "${ret1}" -a "${ret1}" = "GOTYOU" ] || [ -n "${ret2}" -a "${ret2}" = "GOTYOU" ];then
		PnL 2  Driver "${mod_name}" Has dependencies.
		return 0
	else
		PnL 2  Driver "${mod_name}" Does not has dependencies.
		return 1
	fi
}
# Function: load a kernel module
# Input: arg1 - module name; arg2 - module alias
# Output: return 0 if succeed, otherwise, 1 is returned
#
function load_mod()
{
	local mod_name=$1
	local mod_name_alias=$2
	local ret=""
	local pattern="${mod_name}"
	local kmod_name="/lib/modules/${mod_name}.ko"

	if [ "${mod_name_alias}" != "${mod_name}" ];then
		# weaken the pattern to be partial of module name if driver name is
		# different from module name
		pattern=$(echo ${mod_name} | awk -F"-|_" '{print $2}')

		ret=$(run_cmd 1 "test -f ${kmod_name} && echo -n GOTYOU")
		if [ -z "${ret}" ];then
			kmod_name="/lib/modules/${mod_name_alias}.ko"
		fi
	fi

	ret=$(run_cmd 1 "test -f ${kmod_name} && echo -n GOTYOU")
	if [ -z "${ret}" ];then
		PnL 1 "${kmod_name}" does not existed.
		RET=1
		return 1
	fi

	PnL 2 Loading Kernel Module: ${kmod_name}...

	# Get last dmesg's timestamp
	local last_ts=$(run_cmd 1 "dmesg | tail -n 1 | \
					sed -e 's/\[/\n/g' -e 's/\]/\n/g' | sed -n '2p'")

	# If module has dependencies use modprobe to solve them
	check_module_dependencies "${mod_name}" "${mod_name_alias}"
	if [ $? -eq 0 ];then
		PnL 2 Using "< modprobe >" ...
		run_cmd 1 modprobe "${kmod_name}"
	else
		PnL 2 Using "< insmod >"  ...
		run_cmd 1 insmod "${kmod_name}"
	fi

	if [ $? -eq 0 ] && is_mod_loaded "${mod_name}" "${mod_name_alias}" && \
			check_dmesg_error "${pattern}" "${last_ts}";then
		PnL 0 kernel module "${kmod_name}" is loaded successfully
		return 0
	else
		PnL 1 kernel module "${kmod_name}" can not be loaded
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: unload a kenrel module
# Input: arg1 - module name; arg2 - module alias
# Output: return 0 if succeed, otherwise, 1 is returned
#
function unload_mod()
{
	local mod_name=$1
	local mod_name_alias=$2
	local kmod_name="/lib/modules/${mod_name}.ko"

	if [ "${mod_name_alias}" != "${mod_name}" ];then
		ret=$(run_cmd 1 "test -f ${kmod_name} && echo -n GOTYOU")
		if [ -z "${ret}" ];then
			kmod_name="/lib/modules/${mod_name_alias}.ko"
		fi
	fi

	ret=$(run_cmd 1 "test -f ${kmod_name} && echo -n GOTYOU")
	if [ -z "${ret}" ];then
		PnL 1 "${kmod_name}" does not existed.
		RET=1
		return 1
	fi

	PnL 2 Unloading Kernel Module: ${kmod_name}...

	run_cmd 0 "rmmod ${kmod_name} > ${TMP_LOG}"

	ret=$(grep -q "failed" "${TMP_LOG}" && echo -n GOTYOU)
	if [ -z "${ret}" -o "${ret}" != "GOTYOU" ] && ! is_mod_loaded "${mod_name}" "${mod_name_alias}";then
		PnL 0 kernel module "${kmod_name}" is unloaded successfully
		return 0
	else
		PnL 1 kernel module "${kmod_name}" can not be unloaded
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: prepare_drv_test - Preparation works before starting driver test
# Input: N/A
# Return: 0 if successful; 1 if failed.
function prepare_drv_test()
{
	local idx=0
	local mod_name_alias

	for mod_name in ${MOD_NAME[@]}
	do
		mod_name_alias=${MOD_NAME_ALIAS[$idx]}

		# Check driver build type, Load driver module if not loaded
		test_drv_loadable "${mod_name}" "${mod_name_alias}"
		if [ $? -eq 0 ];then
			if ! is_mod_loaded "${mod_name}" "${mod_name_alias}";then
				load_mod "${mod_name}" "${mod_name_alias}"
				[ $? -ne 0 ] && return 1
			fi
		elif [ $? -eq 2 ];then
			return 1
		fi
		idx=$(($idx+1))
	done

	return 0
}

#-----------------------------------------------------------------------
# Function: get_module_refcnt - get module reference count
# Input: Arg1 - module name; Arg2 - module alias
# Output: refcnt
#
function get_module_refcnt()
{
	local module_name=$1
	local module_name_alias=$2
	local refcnt=""

	refcnt=$(run_cmd 1 "test -f /sys/module/$module_name/refcnt && \
			cat /sys/module/$module_name/refcnt")
	if [ -z "$refcnt" ];then
		refcnt=$(run_cmd 1 "test -f /sys/module/$module_name_alias/refcnt && \
			cat /sys/module/$module_name_alias/refcnt")
	fi
	refcnt=$(echo "$refcnt" | tr -d '\r')

	echo "$refcnt"
}

#-----------------------------------------------------------------------
# Function: test kernel module unload and load
# Input: N/A
# Output: N/A
#
function test_module_load_unload()
{
	local idx=0
	local mod_name_alias

	PnL 2 Test Kernel Module Load and Unload

	# test if driver is loadable
	for mod_name in ${MOD_NAME[@]}
	do
		mod_name_alias=${MOD_NAME_ALIAS[$idx]}
		test_drv_loadable "${mod_name}" "${mod_name_alias}"
		if [ $? -eq 1 ];then
			PnL 2 [SKIP] kernel module "${mod_name}" load/unload testing
			return
		elif [ $? -eq 2 ];then
			return
		fi
		idx=$(($idx+1))
	done

	# Check whether modules are loaded or not
	idx=0
	for mod_name in ${MOD_NAME[@]}
	do
		mod_name_alias=${MOD_NAME_ALIAS[$idx]}

		if is_mod_loaded "${mod_name}" "${mod_name_alias}";then
			MOD_LOAD_STAT[$idx]=1
			#Clear all holders to be able to unload driver
			clear_holders "${mod_name}" "${mod_name_alias}"
		else
			MOD_LOAD_STAT[$idx]=0
		fi
		idx=$(($idx+1))
	done

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	idx=$((${#MOD_LOAD_STAT[@]}-1))
	while [ "${idx}" -ge 0 ]
	do
		if [ "${MOD_LOAD_STAT[$idx]}" -eq 1 ];then
			mod_refcnt=$(get_module_refcnt ${MOD_NAME[$idx]} ${MOD_NAME_ALIAS[$idx]})
			if [ -n "${mod_refcnt}" -a "${mod_refcnt}" -eq 0 ];then
				# Test unload kernel module
				unload_mod "${MOD_NAME[$idx]}" "${MOD_NAME_ALIAS[$idx]}"
				[ $? -ne 0 ] && return
			else
				RET=2
				PnL 2 Kernel module is used by other threads, refcnt is "$mod_refcnt"
				PnL 2 [SKIP] kernel module "${MOD_NAME[$idx]}" load/unload testing
				return
			fi
		fi
		idx=$(($idx-1))
	done

	idx=0
	while [ "${idx}" -lt "${#MOD_NAME[@]}" ]
	do
		# Test load kernel module
		load_mod "${MOD_NAME[$idx]}" "${MOD_NAME_ALIAS[$idx]}"
		[ $? -ne 0 ] && return

		idx=$(($idx+1))
	done

	# Store kernel dmesg log at the end of test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"
}

#-----------------------------------------------------------------------
# Function: cleanup - Clean up tmp files
# Input: N/A
# Output: N/A
function cleanup()
{
	rm -rf "${TMP_LOG}" >& /dev/null
}

#-----------------------------------------------------------------------
# Function: create log files
# Input: N/A
# Output: N/A
function create_log_files()
{
	LOG_FILE="${LOG_DIR}/${DRV_NAME}/${DRV_NAME}_drvTest_TSID${TSID}_${MACHINE}_$(date +%Y%m%d%H%M).log"
	KLOG_FILE="${LOG_DIR}/${DRV_NAME}/${DRV_NAME}_Kdmesg_TSID${TSID}_${MACHINE}_$(date +%Y%m%d%H%M).log"
	mkdir -p "${LOG_DIR}/${DRV_NAME}" 2> /dev/null
	rm -rf "${LOG_FILE}" 2> /dev/null
	touch "${LOG_FILE}"
	rm -rf "${KLOG_FILE}" 2> /dev/null
	touch "${KLOG_FILE}"
}

#-----------------------------------------------------------------------
# Function: start_test - do some preparations and cliam to start the test
# Input: Arg1 - Run environment: HOST|DUT
# Output: N/A
function start_test()
{
	RUNENV=$1

	PnL 2 Starting ${DRV_NAME} Driver Test [${TSID}]

	if [ "$RUNENV" = "HOST" ];then
		chk_adb_connection
		if [ -n "${DEVID}" ];then
			RUNCMD="adb -s ${DEVID} shell"
		else
			RUNCMD="adb shell"
		fi
	elif [ "$RUNENV" = "DUT" ];then
		RUNCMD=""
	fi
	export RUNENV
	export RUNCMD

	# preparation works
	parse_platform_feature
	get_kmod_name
	create_log_files
}

#-----------------------------------------------------------------------
# Function: gen_test_report - Generate test report file for TRC
# Input:
#	Arg1 - Case Name
#	Arg2 - Case Description
#	Arg3 - Test Result
# Output: Test report file (.csv)
function gen_test_report()
{
	local case_name=$1
	local case_desc=$2
	local test_result=$3
	local dut_name=$(echo "${MACHINE}" | tr [:lower:] [:upper:])
	../lib/generate_test_report.sh "${dut_name}" "${case_name}" "${test_result}" "${case_desc}" "${TRC_INFO}" "${TRC_DIR}" "${NEW_TRC}"
}

#-----------------------------------------------------------------------
# Function: end_test - Print test result at the end of the test
# Input: 1). Test description, used for generate test report
# Output: N/A
function end_test()
{
	local tst_info=$1
	local tst_type=$(echo ${tst_info} | awk -F"," '{print $1}')
	local tst_name=$(echo ${tst_info} | awk -F"," '{print $2}')
	local tst_desc=$(echo ${tst_info} | awk -F"," '{print $3}')

	PnL 2 Ending of ${DRV_NAME} Driver Test [${TSID}]
	if [ "${RET}" -eq 0 ];then
		PnL 2 Result: ====PASS====
		[ "${TRC_ENA}" = "yes" -a -n "${tst_info}" ] && gen_test_report "${tst_type}/${DRV_NAME}:${tst_name}" "${tst_desc}" 0
	elif [ "${RET}" -eq 1 ];then
		PnL 2 Result: ====FAIL====
		[ "${TRC_ENA}" = "yes" -a -n "${tst_info}" ] && gen_test_report "${tst_type}/${DRV_NAME}:${tst_name}" "${tst_desc}" 1
	elif [ "${RET}" -eq 2 ];then
		PnL 2 Result: ====BLOCK====
		[ "${TRC_ENA}" = "yes" -a -n "${tst_info}" ] && gen_test_report "${tst_type}/${DRV_NAME}:${tst_name}" "${tst_desc}" 2
	else
		PnL 2 Result: ====UNKNOWN====
	fi
	cleanup
	#exit "${RET}"
}

#-----------------------------------------------------------------------
# Function: MUL - multiply two integers
# Input: multiplier1, multiplier2
# Output: integer result is returned
function MUL()
{
	echo $1 $2 | awk '{a=$1;b=$2;c=a*b}END{printf "%d\n", c}'
}

#-----------------------------------------------------------------------
# Function: MUL_FP - multiply two numbers with formatted output
# Input: multiplier1, multiplier2, output format
# Output: multiply result is returned, with specific output format: integer/FP
function MUL_FO()
{
	echo $1 $2 | awk '{a=$1;b=$2;c=a*b}END{printf "'$3'\n", c}'
}

#-----------------------------------------------------------------------
# Function: DIV - divide two integers
# Input: divisor, dividend
# Output: integer result is returned
function DIV()
{
	echo $1 $2 | awk '{a=$1;b=$2;c=a/b}END{printf "%d\n", c}'
}

#-----------------------------------------------------------------------
# Function: SUB - Subtraction of two decimals
# Input: decimal-A, decimal-B
# Output: result of (A-B) is returned
function SUB()
{
	echo $1 $2 | awk '{a=$1;b=$2;c=a-b}END{printf "%f\n", c}'
}

#-----------------------------------------------------------------------
# Function: CMP - Compare two decimals
# Input: decimal-A, decimal-B.
# Output: return 0 if A=B; return 1 if A>B; return -1 if B>A;
function CMP()
{
	echo $1 $2 | awk '{if($1 == $2){print 0}else if($1 > $2){print 1}else{print -1}}'
}
