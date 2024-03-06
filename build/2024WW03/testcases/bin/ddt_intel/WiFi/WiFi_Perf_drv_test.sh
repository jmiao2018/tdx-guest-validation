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
##  Oct. 13, 2014 - (Wenzhong Sun) Created                                    ##
##                                                                            ##
################################################################################
#
# File:
#	WiFi_Perf_drv_test.sh
#
# Description:
#	This will run positive functional tests against WiFi driver.
#
# Setup:
#	DUT is connected via USB ADB
#	A wireless AP is well-configured for test (SSID,WPA/WPA2/WEP,...)
#
# Input:
#	-c <testcase ID> - Testcase ID
#		1		Test kernel module load time
#		2		Test kernel module unload time
#	-d <ADB S/N> - ADB serial number
#	-p <PLATFORM> - Platform file to identify HW/SW features for DUT
#					The specified file should be found in platforms/ dir
#		byt-cr-ecs
#		byt-cr-anchor8
#		byt-cr-mrd7
#		byt-cr-t100
#   -l  - List all the test cases
#   -o  - Output directory for storing test log files
#   -O  - Output directory for storing test report files for TRC
#   -r  Report file(csv format) is generated for TRC
#   -i  Information used for generating TRC report
#   -f  Force to create a new Test Report file for TRC
#   -a  All tests are to be run in sequence
#	-s	SSID of an AP
#
# Output:
#	RETURN: 0 is returned if test is PASS, 1 is returned if test is FAIL,
#           2 is returned if test is BLOCK.
#	LOG: test logs are stored at WiFi_$TSID_$PLATFORM_$(date +%Y%m%d%H%M).log
#
#-----------------------------------------------------------------------
debug=false
# Uncomment line below for debug output.
#debug=true
if "$debug" ; then
	set -x
fi
cd $(dirname $0)

#-----------------------------------------------------------------------
# ROOTDIR must be assigned specificly here before source any lib files
ROOTDIR=${PWD}/../../../..
export ROOTDIR

source "../lib/lib-common.sh"

#-----------------------------------------------------------------------
# DRV_NAME must be assigned specificly here for every drver test
DRV_NAME="WiFi"
export DRV_NAME

#-----------------------------------------------------------------------
# Array: Test Info: type and descriptions
# Format: "Type,Name,Description"
# Type - BAT/FPos/FNeg/Perf/Power
declare -a TEST_INFO
TEST_INFO=(
"Perf,kernel module loading time,Test kernel module loading time" \
"Perf,kernel module unloading time,Test kernel module unloading time" \
)

PATTERN_MOD_LOAD_START="module init start"
PATTERN_MOD_LOAD_END="module init ret"
PATTERN_MOD_UNLOAD_START="module exit start"
PATTERN_MOD_UNLOAD_END="module exit success"

#-----------------------------------------------------------------------
# Function: Usage
function Usage()
{
cat <<__EOF >&2

    Usage: ./${0##*/} [-c CASE_ID] [-d DEVICE_ID] [-p PLATFORM] [-o LOG_DIR] \
[-O TR_DIR] [-i TR_MSG] [-s SSID] -l -r -f -a -h
        -c CASE_ID      Test case ID (list) to identify which case(s) is(are) selected to run
        -d DEVICE_ID    Device ID to identify the ADB device to be tested on
        -p PLATFORM     Platform to run tests on. The platform name must exist in platforms/ dir
                        PLATFORM files to identify platform hardware and software features
        -l              List all the test cases
        -o LOG_DIR      Output directory of storing test log files (default is /tmp/test_log)
        -O TR_DIR       Output directory of storing test report files (default is $ROOTDIR)
        -r              Report file(csv format) is generated for TRC
        -i TR_MSG       Information used for generating TRC report
        -f              Force to create a new Test Report file for TRC
        -a              All tests are to be run in sequence
        -s SSID         SSID of an AP for test
        -h              Help. Print all available options

        Example: ${0##*/} -c 2 -d 013FB182 -p byt-cr-anchor8

__EOF
exit 0
}

# FIXME: All available test case ID list, need to be updated when adding a new case
ALL_TSID_LIST="1 2"
#-----------------------------------------------------------------------
# Function: print_test_list - Print all test cases' information
function print_test_list()
{
cat <<__EOF >&2
WiFi Driver Test Case List
   Test Case ID       Test Description
       1              Time for loading WiFi driver module
       2              Time for unloading WiFi driver module
__EOF
exit 0
}

#-----------------------------------------------------------------------
# parse_opts - Parse paramaters from command lines
#
while getopts c:d:p:o:O:i:s:afrlh arg
	do case $arg in
		c)
		TSID="$OPTARG";;
		d)
		DEVID="$OPTARG";;
		p)
		PLATFORM="$OPTARG";;
		o)
		LOG_DIR="$OPTARG";;
		O)
		TRC_DIR="$OPTARG";;
		a)
		TSID="$ALL_TSID_LIST";;
		r)
		TRC_ENA="yes";;
		i)
		TRC_INFO="$OPTARG";;
		l)
		print_test_list;;
		f)
		NEW_TRC=1;;
        s)
		TEST_AP_ESSID="$OPTARG";;
		h)		Usage;;
		\?)		Usage;;
	esac
done

#-----------------------------------------------------------------------
# Function: get_LMP_timestamp - Get Last Matched Pattern's timestamp from
#           dmesg log file
# Input: 1). dmesg log file. 2). string pattern.
# Output: GET_TS
# Return: 0 if successful, 1 if failed.
function get_LMP_timestamp()
{
	[ $# -ne 2 ] && return 1

	local LOG_FILE=$1
	local PATTERN=$2

	count=$(cat "${LOG_FILE}" | grep "${PATTERN}" | wc -l)
	if [ "${count}" -eq 0 ];then
		PnL 1 "[${PATTERN}] pattern can NOT be found in dmesg"
		RET=1
		return 1
	fi

	# Get timestamp in the last matched line
	GET_TS=$(cat "${LOG_FILE}" | grep "${PATTERN}" | \
		tail -n 1 | sed -e 's/\[/\n/g' -e 's/\]/\n/g' | sed -n '2p')
}

#-----------------------------------------------------------------------
# Function: test_module_load_time - Test WiFi driver module load time
# Input: N/A
# Output:
#  1. Time in microsecond for loading a driver module
#  2. $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_module_load_time()
{
	PnL 2 Test WiFi driver loading time

	test_drv_loadable "${MOD_NAME}" "${MOD_NAME_ALIAS}"
	if [ $? -eq 0 ];then
		# Unload the module if it had already been loaded
		if is_mod_loaded "${MOD_NAME}" "${MOD_NAME_ALIAS}";then
			unload_mod "${MOD_NAME}" "${MOD_NAME_ALIAS}"
			[ $? -ne 0 ] && return
			sleep 5
		fi

		# Store kernel dmesg log before starting a test
		run_cmd 0 "dmesg >> ${KLOG_FILE}"

		LAST_TS=$(run_cmd 1 "dmesg | tail -n 1 | sed -e 's/\[/\n/g' \
				-e 's/\]/\n/g' | sed -n '2p'")

		# Load kernel module
		load_mod "${MOD_NAME}" "${MOD_NAME_ALIAS}"
		[ $? -ne 0 ] && return

		# Store kernel dmesg log into a tmp file
		run_cmd 0 "dmesg > ${TMP_LOG}"

		# Parse the dmesg log file to get the start/end time
		if [ -f "${TMP_LOG}" ];then
			unset GET_TS
			get_LMP_timestamp "${TMP_LOG}" "${PATTERN_MOD_LOAD_START}"
			# Check the validity of the timestamp, should be bigger than $LAST_TS
			ret=$(CMP "${GET_TS}" "${LAST_TS}")
			if [ "$ret" -ge 0 ];then
				START_TS="${GET_TS}"
			else
				PnL 1 "[${PATTERN_MOD_LOAD_START}] pattern is found, "
					"but timestamp is not valid"
				RET=1
				return
			fi

			unset GET_TS
			get_LMP_timestamp "${TMP_LOG}" "${PATTERN_MOD_LOAD_END}"
			# Check the validity of the timestamp, should be bigger than $START_TS
			ret=$(CMP "${GET_TS}" "${START_TS}")
			if [ "$ret" -ge 0 ];then
				END_TS="${GET_TS}"
			else
				PnL 1 "[${PATTERN_MOD_LOAD_END}] pattern is found, "
					"but timestamp is not valid"
				RET=1
				return
			fi

			MOD_LOAD_TS=$(SUB "${END_TS}" "${START_TS}")
			MOD_LOAD_TS=$(MUL_FO "${MOD_LOAD_TS}" 1000000 "%0.2f")
			PnL 0 Kernel module loading time is "${MOD_LOAD_TS}" \(us\)
		fi
		# Store kernel dmesg log at the end of test
		run_cmd 0 "dmesg >> ${KLOG_FILE}"
	elif [ $? -eq 1 ];then
		PnL 2 [SKIP] kernel module "${KMOD_NAME}" loading time testing
	fi
}

#-----------------------------------------------------------------------
# Function: test_module_unload_time - Test WiFi driver module unload time
# Input: N/A
# Output:
#  1. Time in microsecond for unloading a driver module
#  2. $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_module_unload_time()
{
	PnL 2 Test WiFi driver unloading time

	test_drv_loadable "${MOD_NAME}" "${MOD_NAME_ALIAS}"
	if [ $? -eq 0 ];then
		# load the module if it was not loaded
		if ! is_mod_loaded "${MOD_NAME}" "${MOD_NAME_ALIAS}";then
			load_mod "${MOD_NAME}" "${MOD_NAME_ALIAS}"
			[ $? -ne 0 ] && return
			sleep 5
		fi

		# Store kernel dmesg log before starting a test
		run_cmd 0 "dmesg >> ${KLOG_FILE}"

		LAST_TS=$(run_cmd 1 "dmesg | tail -n 1 | sed -e 's/\[/\n/g' \
				-e 's/\]/\n/g' | sed -n '2p'")

		# Load kernel module
		unload_mod "${MOD_NAME}" "${MOD_NAME_ALIAS}"
		[ $? -ne 0 ] && return

		# Store kernel dmesg log into a tmp file
		run_cmd 0 "dmesg > ${TMP_LOG}"

		# Parse the dmesg log file to get the start/end time
		if [ -f "${TMP_LOG}" ];then
			unset GET_TS
			get_LMP_timestamp "${TMP_LOG}" "${PATTERN_MOD_UNLOAD_START}"
			# Check the validity of the timestamp, should be bigger than $LAST_TS
			ret=$(CMP "${GET_TS}" "${LAST_TS}")
			if [ $ret -ge 0 ];then
				START_TS="${GET_TS}"
			else
				PnL 1 "[${PATTERN_MOD_UNLOAD_START}] pattern is found, "
					"but timestamp is not valid"
				RET=1
				return
			fi

			unset GET_TS
			get_LMP_timestamp "${TMP_LOG}" "${PATTERN_MOD_UNLOAD_END}"
			# Check the validity of the timestamp, should be bigger than $START_TS
			ret=$(CMP "${GET_TS}" "${START_TS}")
			if [ $ret -ge 0 ];then
				END_TS="${GET_TS}"
			else
				PnL 1 "[${PATTERN_MOD_UNLOAD_END}] pattern is found, "
					"but timestamp is not valid"
				RET=1
				return
			fi

			MOD_UNLOAD_TS=$(SUB "${END_TS}" "${START_TS}")
			MOD_UNLOAD_TS=$(MUL_FO "${MOD_UNLOAD_TS}" 1000000 "%0.2f")
			PnL 0 Kernel module unloading time is "${MOD_UNLOAD_TS}" \(us\)
		fi
		# Store kernel dmesg log at the end of test
		run_cmd 0 "dmesg >> ${KLOG_FILE}"
	elif [ $? -eq 1 ];then
		PnL 2 [SKIP] kernel module "${KMOD_NAME}" unloading time testing
	fi
}

#-----------------------------------------------------------------------
# Check the validity of parameters
if [ -z "${TSID}" -o -z "${PLATFORM}" ];then
	Usage
fi

#-----------------------------------------------------------------------
# Function: run_test - Start running a test
# Input: N/A
# Output: N/A
function run_test()
{
	# Start the test on "HOST" running environment
	# Param: "HOST" - run test on host Linux
	#                 DUT should be connected to HOST via ADB
	#        "DUT"  - run test on DUT directly
	start_test "DUT"

	# Disable Android WiFi services before test
	run_cmd 1 svc wifi disable

	case ${TSID} in
	1) test_module_load_time;;
	2) test_module_unload_time;;
	*) PnL 1 Unknown Testcase ID;RET=1;;
	esac

	# Do some special cleanups

	# Test end
	end_test "${TEST_INFO[$((${TSID}-1))]}"
}

#-----------------------------------------------------------------------
# Main entry here
INPUT_TSID="${TSID}"
NUM=$(echo "${INPUT_TSID}" | awk '{print NF}')
idx=1
while [ "${idx}" -le "${NUM}" ]
do
	# Get TSID from inputted TSID list
	TSID=$(echo "${INPUT_TSID}" | awk '{print $'$idx'}')
	# Reset RET value to 0 before test
	RET=0
	# Start a test
	run_test
	# idx++
	idx=$(($idx+1))
done

# Exit here
exit "${RET}"
