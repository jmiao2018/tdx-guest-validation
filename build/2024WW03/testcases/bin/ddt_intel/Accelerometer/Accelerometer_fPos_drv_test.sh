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
#	Accelerometer_fPos_drv_test.sh
#
# Description:
#	This will run positive functional tests against Accelerometer sensor driver.
#
# Setup:
#	DUT is connected via USB ADB
#
# Input:
#	-c <testcase ID> - Testcase ID
#		1		Test kernel module load/unload
#		2		Test I2C bus driver bind/unbind
#		3		Test Accelerometer device is enumerated in /sys/bus/iio/devices
#		4		Test Accelerometer device is enumerated in /sys/bus/acpi/devices
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
#	LOG: test logs are stored at Accelerometer_$TSID_$PLATFORM_$(date +%Y%m%d%H%M).log
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
DRV_NAME="Accelerometer"
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
ALL_TSID_LIST="1 2 3 4"
#-----------------------------------------------------------------------
# Function: print_test_list - Print all test cases' information
function print_test_list()
{
cat <<__EOF >&2
Accelerometer Driver Test Case List
   Test Case ID       Test Description
       1              Load/unload Accelerometer driver module
       2              Bind/unbind I2C bus driver for Accelerometer
       3              Enumerate Accelerometer device in /sys/bus/iio/devices
       4              Enumerate Accelerometer device in /sys/bus/acpi/devices
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

	case ${TSID} in
	1) test_module_load_unload;;
	2) test_i2c_bus_bind_unbind;;
	3) test_iio_dev_enumerated;;
	4) test_acpi_dev_enumerated;;
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
