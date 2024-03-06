#!/bin/bash
#Copyright (C) 2015 Intel - http://www.intel.com
#Author:
#	Zelin Deng(zelinx.deng@intel.com)
#
#ChangeLog:
#	Jan 30th, 2015 - (Zelin) Created
#
#	4/20,2015:  1. remove unneccesary black space on top of line, replace by tab
#				2. add prepare_to_test in order to get dynamic variables
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.



debug=false

# Uncomment line below for debug output.
#debug=true
if "$debug" ; then
	set -x
fi
cd $(dirname $0)

#-----------------------------------------------------------------------
# ROOTDIR must be assigned specificly here before source any lib files
ROOTDIR=${PWD}/../../..
export ROOTDIR

#source "../lib/lib-sensor.sh"
source "../uart/case-uart.sh"
#source "./"
#-----------------------------------------------------------------------
# DRV_NAME must be assigned specificly here for every drver test
DRV_NAME="uart"
export DRV_NAME

#-----------------------------------------------------------------------
# Array: Test Info: type and descriptions
# Format: "Type,Name,Description"
# Type - BAT/FPos/FNeg/Perf/Power
declare -a TEST_INFO
TEST_INFO=(
"BAT,check /sys/class/tty, Test driver has registered file nodes under /sys/class/tty" \
"BAT,check 8250 driver, Test 8250 driver has been registered" \
"BAT,check 8250_dw driver, Test 8250_dw driver has been registered" \
"BAT,check 8250_pnp driver, Test 8250_pnp driver has been registered" \
"BAT,load/unload module,Test 8250_dw module load and unload" \
"BAT,bind/unbind 8250 device,Test 8250 driver bind and unbind" \
"BAT,bind/unbind 8250_dw device,Test 8250_dw driver bind and unbind" \
"BAT,bind/unbind 8250_pnp device,Test 8250_pnp driver bind and unbind"
)
#-----------------------------------------------------------------------
# Function: Usage
function Usage()
{
cat <<__EOF >&2
	Usage: ./${0##*/} [-c CASE_ID] [-d DEVICE_ID] [-p PLATFORM] -h
		-c CASE_ID      Test case ID to identify which case is selected to run
		-d DEVICE_ID    Device ID to identify the ADB device to be tested on
		-p PLATFORM     Platform to run tests on. The platform name must exist in platforms/ dir
						PLATFORM files to identify platform hardware and software features
		-l              List all the test cases
		-o              Output directory of storing test log files (default is /tmp/test_log)
		-O              Output directory of storing test report files (default is $ROOTDIR)
		-r              Report file(csv format) is generated for TRC
		-i              Information used for generating TRC report
		-f              Force to create a new Test Report file for TRC
		-a              All tests are to be run in sequence
		-h              Help. Print all available options

		Example: ${0##*/} -c 2 -d 013FB182 -p byt-cr-anchor8

__EOF
exit 0
}

# FIXME: All available test case ID list, need to be updated when adding a new case
ALL_TSID_LIST="1 2 3 4 5 6 7 8 9"
#-----------------------------------------------------------------------
# Function: print_test_list - Print all test cases' information
function print_test_list()
{
cat <<__EOF >&2
Accelerometer Driver Test Case List
	Test Case ID       Test Description
		1              Check /sys/class/tty
		2              Check 8250 driver
		3              Check 8250_dw driver
		4              Check 8250_pnp driver
		5              Load/unload 8250_dw.ko module
		6              Bind/unbind 8250 device
		7              Bind/unbind 8250_dw device
		8              Bind/unbind 8250_pnp device
		9              Setting baudrate
__EOF
exit 0
}

#-----------------------------------------------------------------------
# parse_opts - Parse paramaters from command lines
#
while getopts c:d:p:o:O:i:afrlh arg
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
		h)      Usage;;
		\?)     Usage;;
	esac
done

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

	case ${TSID} in
	1) Check_sys_class_tty;;
	2) Check_serial_driver;;
	3) Check_dw_driver;;
	4) Check_pnp_driver;;
	5) Load_unload_dw_mod;;
	6) Bind_unbind_serial;;
	7) Bind_unbind_dw;;
	8) Bind_unbind_pnp;;
	9) Set_baudrate;;
	10) Check_xgold_serial_driver;;
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
	prepare_to_test
	if [ $? -ne 0 ];then
		RET=1
		break
	fi
	# Start a test
	run_test
	# idx++
	idx=$(($idx+1))
done

# Exit here
exit "${RET}"
