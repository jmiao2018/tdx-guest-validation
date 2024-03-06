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
##  Sept. 24, 2014 - (Wenzhong Sun) Created                                   ##
##                                                                            ##
################################################################################
#
# File:
#	BT_fPos_drv_test.sh
#
# Description:
#	This will run positive functional tests against BT driver.
#
# Setup:
#	DUT is connected via USB ADB
#	BT (A2DP/HID/BLE) devices are required
#
# Input:
#	-c <testcase ID> - Testcase ID
#		1		Test kernel module load/unload
#		2		Test BT HCI device is enumerated and MAC address is valid
#		3		Test switch on BT device
#		4		Test switch off BT device
#		5		Test BT scanning for Peer BT devices
#	-d <ADB S/N> - ADB serial number
#	-p <PLATFORM> - Platform file to identify HW/SW features for DUT
#					The specified file should be found in platforms/ dir
#		byt-cr-ecs
#		byt-cr-anchor8
#		byt-cr-mrd7
#		byt-cr-t100
#   -l  List all the test cases
#   -o  <DIR> Output directory for storing test log files
#   -O  <DIR> Output directory for storing test report files for TRC
#   -r  Report file(csv format) is generated for TRC
#   -i  <Info> Information used for generating TRC report
#   -f  Force to create a new Test Report file for TRC
#   -a  All tests are to be run in sequence
#   -P  <Peer Name> Peer BT device name
#
# Output:
#	RETURN: 0 is returned if test is PASS, 1 is returned if test is FAIL,
#           2 is returned if test is BLOCK.
#	LOG: test logs are stored at BT_$TSID_$PLATFORM_$(date +%Y%m%d%H%M).log
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
DRV_NAME="BT"
export DRV_NAME

#-----------------------------------------------------------------------
# Array: Test Info: type and descriptions
# Format: "Type,Name,Description"
# Type - BAT/FPos/FNeg/Perf/Power
declare -a TEST_INFO
TEST_INFO=(
"BAT,load/unload module,Test kernel module load and unload" \
"BAT,enumerate BT HCI device and check MAC address,Test ${DRV_NAME} device is enumerated and MAC address is valid" \
"BAT,switch on BT,Test switching on BT device" \
"BAT,switch off BT,Test switching off BT device" \
"fPos,BT scanning,Test BT scanning for Peer BT devices" \
"fPos,BT connecting to a HID device,Test BT connecting to a HID device" \
"fPos,BT connecting to an A2DP device,Test BT connecting to an A2DP device" \
"fPos,BT connecting to a BLE device,Test BT connecting to a BLE device" \
)

TIMEOUT_CMD="${BIN_DIR}/timeout"
BT_SYSFS_IF="/sys/class/bluetooth"
RFKILL_SYSFS_IF="/sys/class/rfkill"
RFKILL_DEV=""
BT_HCI_NAME="hci0"
BT_DEV_NAME="RTK_BT_4.0"
BT_MAC_ADDR=""
SCAN_RESULT="/data/scan_bt_list.txt"
PEER_BT_NAME="MDR-10RBT"
BT_HID_NAME="Bluetooth Mouse M557"

#-----------------------------------------------------------------------
# Function: Usage
function Usage()
{
cat <<__EOF >&2

    Usage: ./${0##*/} [-c CASE_ID] [-d DEVICE_ID] [-p PLATFORM] [-o LOG_DIR] \
[-O TR_DIR] [-i TR_MSG] [-P PEER_BT] -l -r -f -a -h
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
        -P PEER_BT      Peer BT device name
        -h              Help. Print all available options

        Example: ${0##*/} -c 2 -d 013FB182 -p byt-cr-anchor8

__EOF
exit 0
}

# FIXME: All available test case ID list, need to be updated when adding a new case
ALL_TSID_LIST="1 2 3 4 5"
#-----------------------------------------------------------------------
# Function: print_test_list - Print all test cases' information
function print_test_list()
{
cat <<__EOF >&2
BT Driver Test Case List
   Test Case ID       Test Description
       1              Load/unload BT driver module
       2              Enumerate BT HCI device and check MAC address
       3              Switch ON BT
       4              Switch OFF BT
       5              BT scanning
__EOF
exit 0
}

#-----------------------------------------------------------------------
# Function: get_rfkill_dev - Search rfkill devices to find one for BT
# Input: N/A
# Output: Return 0 if successful, otherwise, 1 is returned
function get_rfkill_dev()
{
	dev_list=$(run_cmd 1 "ls ${RFKILL_SYSFS_IF} | tr '\n' '\t'")
	dev_list=$(echo "${dev_list}" | tr -d '\r')

	for rf_dev in ${dev_list}
	do
		# To remove unnecessary '\t'
		rf_dev=$(echo "$rf_dev" | tr -d '\t')
		rf_type=$(run_cmd 1 cat "${RFKILL_SYSFS_IF}/${rf_dev}/type")
		rf_type=$(echo "${rf_type}" | tr -d '\r')
		if [ -n "${rf_type}" -a "${rf_type}" = "bluetooth" ];then
			rf_name=$(run_cmd 1 cat "${RFKILL_SYSFS_IF}/${rf_dev}/name")
			rf_name=$(echo "${rf_name}" | tr -d '\r')
			# As HCI will register a rfkill device as well, we need to filter it out
			if [ "${rf_name}" != "${BT_HCI_NAME}" ];then
				RFKILL_DEV="${rf_dev}"
				PnL 2 Get RFKILL device name: ${RFKILL_DEV}
				return 0
			fi
		fi
	done

	if [ -z "${RFKILL_DEV}" ];then
		RET=1
		PnL 1 Failed to get RFKILL device name For BT
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: switch_RF - switch on/off Radio Frequency
# Input: "ON"|"OFF"
# Output: Return 0 if successful, otherwise, 1 is returned
function switch_RF()
{
	# Get RFKILL device name
	[[ -n "${RFKILL_DEV}" ]] || get_rfkill_dev
	[[ -n "${RFKILL_DEV}" ]] || return 1

	case $1 in
	ON|on)
		# Switch on BT RF
		PnL 2 Switching ON BT RFKILL...
		run_cmd 1 "echo 0 > ${RFKILL_SYSFS_IF}/${RFKILL_DEV}/soft"
		read_val=$(run_cmd 1 "cat ${RFKILL_SYSFS_IF}/${RFKILL_DEV}/state")
		read_val=$(echo "${read_val}" | tr -d '\r')
		if [ "${read_val}" -ne 1 ];then
			RET=1
			PnL 1 Failed to change ${RFKILL_DEV} state to 1
			return 1
		fi
		sleep 5

		ret=$(run_cmd 1 "hciconfig ${BT_HCI_NAME} 2> /dev/null | \
			grep -q ${BT_HCI_NAME} && echo -n GOTYOU")
		if [ -n "${ret}" -a "${ret}" = "GOTYOU" ];then
			PnL 0 Switch BT ${RFKILL_DEV} ON successfully
			return 0
		else
			RET=1
			PnL 1 Failed to switch on ${RFKILL_DEV}
			return 1
		fi
		;;
	OFF|off)
		# Switch off BT RF
		PnL 2 Switching OFF BT RFKILL...

		run_cmd 1 "echo 1 > ${RFKILL_SYSFS_IF}/${RFKILL_DEV}/soft"
		read_val=$(run_cmd 1 "cat ${RFKILL_SYSFS_IF}/${RFKILL_DEV}/state")
		read_val=$(echo "${read_val}" | tr -d '\r')
		if [ "${read_val}" -ne 0 ];then
			RET=1
			PnL 1 Failed to change BT ${RFKILL_DEV} state to 0
			return 1
		fi
		sleep 2

		ret=$(run_cmd 1 "hciconfig ${BT_HCI_NAME} 2> /dev/null | \
			grep -q ${BT_HCI_NAME} && echo -n GOTYOU")
		if [ -z "${ret}" -o "${ret}" != "GOTYOU" ];then
			PnL 0 Switch off BT ${RFKILL_DEV} successfully
			return 0
		else
			RET=1
			PnL 1 Failed to switch off BT ${RFKILL_DEV}
			return 1
		fi
		;;
	*)
		PnL 1 Invalid Input parameter: $1, should be ON|on or OFF|off
		return 1;;
	esac
}

#-----------------------------------------------------------------------
# Function: is_valid_MAC - Test if the given MAC address is valid
# Input: MAC address
# Output: Return 0 if vaild, else, 1 is returned
function is_valid_MAC()
{
	VALID_MAC=$(echo $1 | egrep -i -o "(([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2})|(([0-9A-Fa-f]{4}.){2}[0-9A-Fa-f]{4})")
	if [ -n "${VALID_MAC}" ];then
		PnL 2 BT MAC address: $1 is valid
		return 0
	else
		PnL 2 BT MAC address: $1 is NOT valid
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: test_BT_dev_enumerated - Test BT device is enumerated
#			and MAC address is valie
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_BT_dev_enumerated()
{
	PnL 2 Test BT device is enumerated

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# Switch on BT RF
	switch_RF "ON"
	[ $? -ne 0 ] && return

	BT_DEV_ENUMERATED=0
	hci_list=$(run_cmd 1 "ls ${BT_SYSFS_IF}" | tr '\n' '\t')
	hci_list=$(echo "${hci_list}" | tr -d '\r')

	for hci in ${hci_list}
	do
		# To remove unnecessary '\t'
		hci=$(echo "$hci" | tr -d '\t')
		ret=$(run_cmd 1 "test -d ${BT_SYSFS_IF}/${hci} && echo -n GOTYOU")
		[ -z "${ret}" -o "${ret}" != "GOTYOU" ] && continue

		bt_name=$(run_cmd 1 "cat ${BT_SYSFS_IF}/${hci}/name 2> /dev/null")
		bt_name=$(echo "${bt_name}" | tr -d '\r')
		if [ -n "${bt_name}" -a "${bt_name}" = "${BT_DEV_NAME}" ];then
			BT_DEV_ENUMERATED=1
			BT_HCI_NAME="${hci}"
			PnL 2 Get BT device: ${BT_DEV_NAME}
			PnL 0 BT HCI device ${BT_HCI_NAME} is enumerated at ${BT_SYSFS_IF}/
			break
		fi
	done

	if [ ! "${BT_DEV_ENUMERATED}" ];then
		PnL 1 BT HCI device ${BT_HCI_NAME} can NOT be enumerated
		RET=1
		return
	fi

	# Get MAC address and check its validity
	BT_MAC_ADDR=$(run_cmd 1 "cat ${BT_SYSFS_IF}/${BT_HCI_NAME}/address")
	BT_MAC_ADDR=$(echo "${BT_MAC_ADDR}" | tr -d '\r')
	if [ -n "${BT_MAC_ADDR}" ] && is_valid_MAC "${BT_MAC_ADDR}";then
		PnL 0 "Get valid MAC Address: ${BT_MAC_ADDR} for BT device: ${BT_HCI_NAME}"
	else
		RET=1
		PnL 1 "Unable to Get valid MAC Address: ${BT_MAC_ADDR} for BT device: ${BT_HCI_NAME}"
	fi

	# Switch off BT RF
	switch_RF "OFF"
}

#-----------------------------------------------------------------------
# Function: BT_switch_onoff - Switch on/off BT device
# Input: "ON" || "OFF"
# Output: $RET, =0 if successful, =1 if failed.
# Return: 0 if successful, 1 if failed.
function BT_switch_onoff()
{
	# Get last dmesg's timestamp
	local last_ts=$(run_cmd 1 "dmesg | tail -n 1 | \
					sed -e 's/\[/\n/g' -e 's/\]/\n/g' | sed -n '2p'")

	case $1 in
	ON|on)
		# Switch on BT RF
		switch_RF "ON"
		[ $? -ne 0 ] && return 1

		# Switch on BT HCI
		PnL 2 Switching ON BT device ${BT_HCI_NAME}...
		run_cmd 1 hciconfig ${BT_HCI_NAME} up
		sleep 2

		# Check BT state
		BT_stat=$(run_cmd 1 "hciconfig ${BT_HCI_NAME} | grep -i -o "UP" | tr '[:upper:]' '[:lower:]'")
		BT_stat=$(echo "${BT_stat}" | tr -d '\r')
		if [ -n "${BT_stat}" -a "${BT_stat}" = "up" ] && \
				check_dmesg_error "Bluetooth" "${last_ts}";then
			PnL 0 Switching BT \"${BT_HCI_NAME}\" ON successfully
			return 0
		else
			RET=1
			PnL 1 Switching BT \"${BT_HCI_NAME}\" ON failed
			return 1
		fi
		;;
	OFF|off)
		# Switch off BT
		PnL 2 Switching OFF BT device ${BT_HCI_NAME}...
		run_cmd 1 hciconfig ${BT_HCI_NAME} down
		sleep 2

		# Check BT state
		BT_stat=$(run_cmd 1 "hciconfig ${BT_HCI_NAME} | grep -i -o "DOWN" | tr '[:upper:]' '[:lower:]'")
		BT_stat=$(echo "${BT_stat}" | tr -d '\r')
		if [ -n "${BT_stat}" -a "${BT_stat}" = "down" ] && \
				check_dmesg_error "Bluetooth" "${last_ts}";then
			PnL 0 Switching BT \"${BT_HCI_NAME}\" OFF successfully
		else
			RET=1
			PnL 1 Switching BT \"${BT_HCI_NAME}\" OFF failed
			return 1
		fi

		# Switch off BT RF
		switch_RF "OFF"
		[ $? -ne 0 ] && return 1
		;;
	*)
		PnL 1 Invalid Input parameter: $1, should be ON|on or OFF|off
		return 1;;
	esac
}

#-----------------------------------------------------------------------
# Function: test_BT_on - Test switch on BT device
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_BT_on()
{
	PnL 2 Test BT device switch ON

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	BT_switch_onoff "ON"

	# Store kernel dmesg log at the end of test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"
}

#-----------------------------------------------------------------------
# Function: test_BT_off - Test switch off BT device
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_BT_off()
{
	PnL 2 Test BT device switch OFF

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	BT_switch_onoff "OFF"

	# Store kernel dmesg log at the end of test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"
}

#-----------------------------------------------------------------------
# Function: BT_scan - Start BT scanning
# Input:
#    Arg1: Name of Peer BT device for verifing scan result
#    Arg2: 1-dump scan result; 0-no dump(default)
# Output: $RET, =0 if successful, =1 if failed.
# Return: 0 if successful; 1 if failed.
function BT_scan()
{
	local SCAN_BT_NAME=$1
	[ -n "${SCAN_BT_NAME}" ] || return 1
	local SCAN_DUMP=$2
	[ -n "${SCAN_DUMP}" ] || SCAN_DUMP=0

	PnL 2 BT Scanning ...

	run_cmd 0 "${TIMEOUT_CMD} -t 60 hcitool -i ${BT_HCI_NAME} scan > ${SCAN_RESULT}"
	if [ -f "${SCAN_RESULT}" ];then
		cat "${SCAN_RESULT}" | grep -q "${SCAN_BT_NAME}"
		if [ $? -eq 0 ];then
			PEER_NUM=$(cat "${SCAN_RESULT}" | wc -l)
			# Minus the first line
			PEER_NUM=$(($PEER_NUM-1))
			PnL 0 BT Scan result: ${PEER_NUM} BT devices are found
			[ "${SCAN_DUMP}" -eq 1 ] && cat "${SCAN_RESULT}"
			return 0
		else
			RET=1
			PnL 1 BT Scan result: failed to find BT device: "${SCAN_BT_NAME}"
			return 1
		fi
	else
		RET=1
		PnL 1 BT Scan: No BT device is Found
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: test_BT_scan - Test BT scanning AP
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_BT_scan()
{
	PnL 2 Test BT scanning

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# Switch on BT
	BT_switch_onoff "ON"
	[ $? -eq 1 ] && return

	# Start BT scanning
	BT_scan "${PEER_BT_NAME}" 1

	# Switch off BT
	BT_switch_onoff "OFF"

	# Store kernel dmesg log at the end of test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"
}

#-----------------------------------------------------------------------
# parse_opts - Parse paramaters from command lines
#
while getopts c:d:p:o:O:i:P:afrlh arg
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
        P)
		PEER_BT_NAME="$OPTARG";;
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
	2) test_BT_dev_enumerated;;
	3) test_BT_on;;
	4) test_BT_off;;
	5) test_BT_scan;;
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
