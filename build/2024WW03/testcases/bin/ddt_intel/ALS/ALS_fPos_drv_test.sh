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
##  Aug 11, 2014 - (Wenzhong Sun) Created                                     ##
##  Aug 20, 2014 - (Wenzhong Sun) Re-arch the test case by abstracting the    ##
##                 common functions into a common file and use PLATFORM file  ##
##                 to identify platform hardware and software features        ##
##                                                                            ##
################################################################################
#
# File:
#	ALS_fPos_drv_test.sh
#
# Description:
#	This will run positive functional tests against ALS sensor driver.
#
# Setup:
#	DUT is connected via USB ADB
#
# Input:
#	-c <testcase ID> - Testcase ID
#		1		Test kernel module load/unload
#		2		Test I2C bus driver bind/unbind
#		3		Test ALS device is enumerated in /sys/bus/iio/devices
#		4		Test ALS device is enumerated in /sys/bus/acpi/devices
#		5		Test get sensor's illuminance value via in_illuminance_input
#		6		Test changing calibration scale value via in_illuminance_calibscale
#		7		Test changing sensor's integration time via in_illuminance_integration_time
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
#
# Output:
#	RETURN: 0 is returned if test is PASS, 1 is returned if test is FAIL,
#           2 is returned if test is BLOCK.
#	LOG: test logs are stored at ALS_$TSID_$PLATFORM_$(date +%Y%m%d%H%M).log
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

source "../lib/lib-sensor.sh"

#-----------------------------------------------------------------------
# DRV_NAME must be assigned specificly here for every drver test
DRV_NAME="ALS"
export DRV_NAME

#-----------------------------------------------------------------------
# Array: Test Info: type and descriptions
# Format: "Type,Name,Description"
# Type - BAT/FPos/FNeg/Perf/Power
declare -a TEST_INFO
TEST_INFO=(
"BAT,load/unload module,Test kernel module load and unload" \
"BAT,bind/unbind I2C bus,Test I2C bus driver bind and unbind" \
"BAT,enumerate IIO device,Test ${DRV_NAME} device is enumerated in /sys/bus/iio/devices" \
"BAT,enumerate ACPI device,Test ${DRV_NAME} device is enumerated in /sys/bus/acpi/devices" \
"BAT,read illuminance value under normal ambient light,Test getting ${DRV_NAME} sensor's illuminance value via in_illuminance_input under normal ambient light" \
"FPos,change calibscale value,Test changing different calibscale values via in_illuminance_calibscale and check the effect on illuminance value" \
"FPos,change integration time,Test changing different integration times via in_illuminance_integration_time" \
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
ALL_TSID_LIST="1 2 3 4 5 6 7"
#-----------------------------------------------------------------------
# Function: print_test_list - Print all test cases' information
function print_test_list()
{
cat <<__EOF >&2
Ambient Light Sensor (ALS) Driver Test Case List
   Test Case ID       Test Description
       1              Load/unload ALS driver module
       2              Bind/unbind I2C bus driver for ALS
       3              Enumerate ALS device in /sys/bus/iio/devices
       4              Enumerate ALS device in /sys/bus/acpi/devices
       5              Read ALS's illumination value via in_illuminance_input
       6              Change calibration scale value via in_illuminance_calibscale
       7              Change integration time via in_illuminance_integration_time
__EOF
exit 0
}

READ_ILLUM_VAL=0
#-----------------------------------------------------------------------
# Function: read_illum_val - Read illuminance value via in_illuminance_xxx
# Input: N/A
# Output: READ_ILLUM_VAL
function read_illum_val()
{
	local postfix
	local illum_val=0

	for postfix in ${ALS_GET_ILLUM_POSTFIX}
	do
		GET_ILLUM_IF="${IIO_DEV_IF}/iio:device${IIO_DEV_ID}/${ALS_PREFIX}${postfix}"
		ret=$(run_cmd 1 "test -f ${GET_ILLUM_IF} && echo -n FOUND")
		if [ -n "${ret}" -a "${ret}" = "FOUND" ];then
			PnL 2 Reading illuminance via "${GET_ILLUM_IF}"
			READ_ILLUM_VAL=$(run_cmd 1 "cat ${GET_ILLUM_IF}")
			READ_ILLUM_VAL=$(echo "$READ_ILLUM_VAL" | tr -d '\r')
			PnL 2 Get current illuminance value is "${READ_ILLUM_VAL}"
			break
		fi
	done
}

#-----------------------------------------------------------------------
# Function: test_get_lux_value - Get illuminance value
# Input: N/A
# Output: N/A
function test_get_lux_value()
{
	declare -a illum_value
	local max_iter=5
	local idx=0
	local zero_cnt=0
	local value=""
	local all_values=""

	# Get IIO device ID by matching device name w/ module name
	test_iio_dev_enumerated
	[ $? -ne 0 ] && return

	# Read illuminance values for $max_iter times
	PnL 2 Starting to get ALS illuminance value ...
	while [ "${idx}" -lt "${max_iter}" ]
	do
		read_illum_val
		illum_value["${idx}"]="${READ_ILLUM_VAL}"
		sleep 1
		idx=$(($idx+1))
	done

	# check the validaty of illum_value
	for value in ${illum_value[*]}
	do
		if [ "${value}" -lt 0 ];then
			PnL 1 Get invalid ALS illuminance ["${value}"]
			RET=1
			return
		# Count the times of zero value, which is used as a criteria for pass or fail
		elif [ "${value}" -eq 0 ];then
			zero_cnt=$(expr ${zero_cnt} + 1)
		fi
		all_values="${all_values} ${value}"
	done

	if [ "${zero_cnt}" -eq "${max_iter}" ];then
		RET=1
		PnL 1 "Get ALS illuminance value "${max_iter}" times, all of them are 0"
	else
		PnL 0 Successfully get ALS illuminance values: "${all_values}"
	fi
}

#-----------------------------------------------------------------------
# Function: set_calibscale_val - Set calibscale value
# Input: N/A
# Output: return: 0 if succeed, 1 if failed
function set_calibscale_val()
{
	local cur_val
	local set_val=$1

	[ $# -ne 1 ] && return

	PnL 2 Setting calibscale value to "${set_val}"
	$(run_cmd 1 "echo ${set_val} > ${CFG_CALIB_IF}")
	PnL 2 Reading calibscale value via ${CFG_CALIB_IF} ...
	cur_val=$(run_cmd 1 "cat ${CFG_CALIB_IF}")
	cur_val=$(echo "$cur_val" | tr -d '\r')
	PnL 2 Get current calibscale value is "${cur_val}"
	if [ "${cur_val}" -ne "${set_val}" ];then
		PnL 1 "Get Calibscale value ${cur_val} is not equal to set value ${set_val}"
		RET=1
		return 1
	fi
	return 0
}

#-----------------------------------------------------------------------
# Function: test_change_calibscale - Change calibscale value and verify
#			whether it is functional to the illuminance value
# Input: N/A
# Output: N/A
function test_change_calibscale()
{
	local old_val
	local set_val
	local old_illum_val
	local new_illum_val
	local scale

	test_iio_dev_enumerated
	[ $? -ne 0 ] && return

	CFG_CALIB_IF="${IIO_DEV_IF}/iio:device${IIO_DEV_ID}/${ALS_PREFIX}${ALS_CALIBSCALE_POSTFIX}"
	ret=$(run_cmd 1 "test -f ${CFG_CALIB_IF} && echo -n FOUND")
	if [ -n "${ret}" -a "${ret}" = "FOUND" ];then
		PnL 2 Reading calibscale value via ${CFG_CALIB_IF} ...
		old_val=$(run_cmd 1 "cat ${CFG_CALIB_IF}")
		old_val=$(echo "$old_val" | tr -d '\r')
		PnL 2 Get default calibscale value is "${old_val}"
		read_illum_val
		old_illum_val="${READ_ILLUM_VAL}"
		# Illuminance value should be zero if calibscale=0
		if [ "${old_val}" -eq 0 -a "${old_illum_val}" -ne 0 ];then
			PnL 1 "Illuminance value ${old_illum_val} is not equal to 0 while reading calibscale value is 0"
			RET=1
			return
		fi
		# Illuminance value should be larger than 30 for this test, otherwise, test is BLOCKED
		if [ "${old_illum_val}" -lt 30 ];then
			PnL 2 "Illuminance value ${old_illum_val} is less than 30, pls check the ambient light to make sure the lux value > 30"
			PnL 2 "[SKIP] test of changing different calibscale values"
			RET=2
			return
		fi

		# Test change calibscale value to 10x of its default
		if [ "${old_val}" -ne 0 ];then
			set_val=$(MUL "${old_val}" 10)
		else
			# Set calibscale value to 4000 if its default value is 0
			set_val=4000
		fi
		set_calibscale_val "${set_val}"
		[ $? -ne 0 ] && return

		# Read illuminance value to check whether calibscale changes take effect
		read_illum_val
		new_illum_val="${READ_ILLUM_VAL}"

		# Check whether new_illum_val/old_illum_val is within range [7,13]
		# A loose criteria is used to judge the test result as illuminance
		# may vary againt ambient environment
		if [ "${old_illum_val}" -ne 0 ];then
			scale=$(DIV "${new_illum_val}" "${old_illum_val}")
			if [ "${scale}" -lt 7 -o "${scale}" -gt 13 ];then
				PnL 1 Change calibscale value from ${old_val} to ${set_val} does NOT take effect on illuminance - old:${old_illum_val} new:${new_illum_val}
				RET=1
				return
			fi
		else
			if [ "${new_illum_val}" -le 0 ];then
				PnL 1 Change calibscale value from ${old_val} to ${set_val} does NOT take effect on illuminance - old:${old_illum_val} new:${new_illum_val}
				RET=1
				return
			fi
		fi
		PnL 0 Change calibscale value from ${old_val} to ${set_val} take effect on illuminance - old:${old_illum_val} new:${new_illum_val}

		# Test change calibscale value to 0.1x of its default
		if [ "${old_val}" -ne 0 ];then
			set_val=$(DIV "${old_val}" 10)
		else
			# Set calibscale value to 400 if its default value is 0
			set_val=400
		fi
		set_calibscale_val "${set_val}"
		[ $? -ne 0 ] && return

		# Read illuminance value to check whether calibscale changes take effect
		read_illum_val
		new_illum_val="${READ_ILLUM_VAL}"

		# Check whether old_illum_val/new_illum_val is within range [7,13]
		# A loose criteria is used to judge the test result as illuminance
		# may vary againt ambient environment
		if [ "${old_illum_val}" -ne 0 -a "${new_illum_val}" -ne 0 ];then
			scale=$(DIV "${old_illum_val}" "${new_illum_val}")
			if [ "${scale}" -lt 7 -o "${scale}" -gt 13 ];then
				PnL 1 Change calibscale value from ${old_val} to ${set_val} does NOT take effect on illuminance - old:${old_illum_val} new:${new_illum_val}
				RET=1
				return
			fi
		else
			if [ "${new_illum_val}" -le 0 ];then
				PnL 1 Change calibscale value from ${old_val} to ${set_val} does NOT take effect on illuminance - old:${old_illum_val} new:${new_illum_val}
				RET=1
				return
			fi
		fi
		PnL 0 Change calibscale value from ${old_val} to ${set_val} take effect on illuminance - old:${old_illum_val} new:${new_illum_val}

		# restore original value
		set_calibscale_val "${old_val}"
	else
		RET=1
		PnL 1 "${CFG_CALIB_IF}" does not exist
	fi
}

#-----------------------------------------------------------------------
# Function: set_it_val - Set integration time
# Input: N/A
# Output: return: 0 if succeed, 1 if failed
function set_it_val()
{
	local cur_val
	local set_val=$1

	[ $# -ne 1 ] && return

	PnL 2 Setting integration time to "${set_val}"
	$(run_cmd 1 "echo ${set_val} > ${CFG_IT_IF}")
	PnL 2 Reading integration time via ${CFG_IT_IF} ...
	cur_val=$(run_cmd 1 "cat ${CFG_IT_IF}")
	cur_val=$(echo "$cur_val" | tr -d '\r')
	if [ "${cur_val}" -ne "${set_val}" ];then
		PnL 1 "Get Integration Time value ${cur_val} is not equal to set value ${set_val}"
		RET=1
		return 1
	fi
	PnL 0 Get current integration time is "${cur_val}"
	return 0
}

#-----------------------------------------------------------------------
# Function: test_change_integration_time - Change integration time
#			via in_illuminance_integration_time
# Input: N/A
# Output: N/A
function test_change_integration_time()
{
	local old_val
	local set_val
	local avail_it_val

	test_iio_dev_enumerated
	[ $? -ne 0 ] && return

	IT_AVAIL_IF="${IIO_DEV_IF}/iio:device${IIO_DEV_ID}/${ALS_PREFIX}${ALS_IT_AVAIL_POSTFIX}"
	ret=$(run_cmd 1 "test -f ${IT_AVAIL_IF} && echo -n FOUND")
	if [ -n "${ret}" -a "${ret}" = "FOUND" ];then
		avail_it_val=$(run_cmd 1 cat ${IT_AVAIL_IF})
		if [ -z "${avail_it_val}" ];then
			RET=1
			PnL 1 Failed to get available integration time via "${IT_AVAIL_IF}"
			return
		fi
		PnL 0 Get Available Integration Time: "${avail_it_val}"
	else
		RET=1
		PnL 1 "${IT_AVAIL_IF}" does not exist
	fi

	CFG_IT_IF="${IIO_DEV_IF}/iio:device${IIO_DEV_ID}/${ALS_PREFIX}${ALS_IT_POSTFIX}"
	ret=$(run_cmd 1 "test -f ${IT_AVAIL_IF} && echo -n FOUND")
	if [ -n "${ret}" -a "${ret}" = "FOUND" ];then
		PnL 2 Reading integration time via ${CFG_IT_IF} ...
		old_val=$(run_cmd 1 cat ${CFG_IT_IF})
		PnL 2 Get default integration time is "${old_val}"

		for set_val in $(echo "${avail_it_val}" | tr -d '\r')
		do
			set_it_val "${set_val}"
		done
	else
		RET=1
		PnL 1 "${IT_AVAIL_IF}" does not exist
	fi
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
		h)		Usage;;
		\?)		Usage;;
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

	case "${TSID}" in
	1) test_module_load_unload;;
	2) test_i2c_bus_bind_unbind;;
	3) test_iio_dev_enumerated;;
	4) test_acpi_dev_enumerated;;
	5) test_get_lux_value;;
	6) test_change_calibscale;;
	7) test_change_integration_time;;
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
