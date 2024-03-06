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
##  Aug. 21, 2014 - (Wenzhong Sun) Created                                    ##
##  Nov. 10, 2015 - (Jose Perez Carranza) Add function to test WiFi on        ##
##                                        IDI  bus                            ##
##                                                                            ##
################################################################################
#
# File:
#	WiFi_fPos_drv_test.sh
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
#		1		Test kernel module load/unload
#		2		Test SDIO driver bind/unbind or test_idi_drv_bind_unbind
#		3		Test WiFi device is enumerated and MAC address is valid
#		4		Test switch on WiFi device
#		5		Test switch off WiFi device
#		6		Test WiFi scanning for Access Point
#		7		Test WiFi connecting to a Non-encrypted AP
#		8		Test WiFi connecting to a WEP 128bit encrypted AP
#		9		Test WiFi connecting to a WPA-PSK encrypted AP
#		10		Test WiFi connecting to a WPA2-PSK encrypted AP
#		11		Test WiFi connecting to a WPA/WPA2-mixed encrypted AP
#		12		Test WiFi connecting to a WPA/WPA2-EAP TTLS encrypted AP
#		13		Test WiFi connecting to a WPA/WPA2-EAP PEAP encrypted AP
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
source "../lib/lib-sdio.sh"
source "../lib/lib-idi.sh"
source "../lib/lib-pci.sh"

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
"BAT,load/unload module,Test kernel module load and unload" \
"BAT,bind/unbind SDIO driver,Test SDIO driver bind and unbind" \
"BAT,enumerate wlan device and check MAC address,Test ${DRV_NAME} device is enumerated and MAC address is valid" \
"BAT,switch on WiFi,Test switching on WiFi device" \
"BAT,switch off WiFi,Test switching off WiFi device" \
"fPos,WiFi scanning,Test WiFi scanning for AP devices" \
"fPos,WiFi connecting to a non-encrypted AP,Test WiFi connecting to a non-encrypted AP" \
"fPos,WiFi connecting to a WEP(128bit)-encrypted AP,Test WiFi connecting to a WEP(128bit)-encrypted AP" \
"fPos,WiFi connecting to a WPA-PSK encrypted AP,Test WiFi connecting to a WPA-PSK encrypted AP" \
"fPos,WiFi connecting to a WPA2-PSK encrypted AP,Test WiFi connecting to a WPA2-PSK encrypted AP" \
"fPos,WiFi connecting to a WPA-PSK/WPA2-PSK mixed encrypted AP,Test WiFi connecting to a WPA-PSK/WPA2-PSK mixed encrypted AP" \
"fPos,WiFi connecting to a WPA2-EAP TTLS encrypted AP,Test WiFi connecting to a WPA2-EAP TTLS encrypted AP" \
"fPos,WiFi connecting to a WPA2-EAP PEAP encrypted AP,Test WiFi connecting to a WPA2-EAP PEAP encrypted AP" \
)

IFCONFIG_CMD="${BIN_DIR}/ifconfig"
IWLIST_CMD="${BIN_DIR}/iwlist"
IWCONFIG_CMD="${BIN_DIR}/iwconfig"
KILLALL_CMD="${BIN_DIR}/killall"
WLAN_SYSFS_IF="/sys/class/ieee80211"
WLAN_IF_NAME="wlan0"
WLAN_PHY_DEV=""
WLAN_MAC_ADDR=""
SCAN_RESULT="/data/scan_ap_list.txt"
TEST_AP_ESSID="Guest"
PLAINTEXT_CONFIG_FILE="plaintext.conf"
WEP_CONFIG_FILE="WEP-128bit.conf"
WPAPSK_CONFIG_FILE="WPA-PSK.conf"
WPA2PSK_CONFIG_FILE="WPA2-PSK.conf"
WPAMIX_CONFIG_FILE="WPA-WPA2-MIXED.conf"
WPA2EAPTTLS_CONFIG_FILE="WPA2-EAP-TTLS.conf"
WPA2EAPPEAP_CONFIG_FILE="WPA2-EAP-PEAP.conf"
DUT_DATA_DIR="."
WLAN_INFO="/sys/class/net"

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
ALL_TSID_LIST="1 2 3 4 5 6 7 8 9 10 11 12 13"
#-----------------------------------------------------------------------
# Function: print_test_list - Print all test cases' information
function print_test_list()
{
cat <<__EOF >&2
WiFi Driver Test Case List
   Test Case ID       Test Description
       1              Load/unload WiFi driver module
       2              Bind/unbind SDIO/IDI driver for WiFi
       3              Enumerate WiFi device and check MAC address
       4              Switch ON WiFi
       5              Switch OFF WiFi
       6              WiFi scanning
       7              WiFi connecting to a Non-encrypted AP
       8              WiFi connecting to a WEP(128bit) encrypted AP
       9              WiFi connecting to a WPA-PSK encrypted AP
       10             WiFi connecting to a WPA2-PSK encrypted AP
       11             WiFi connecting to a WPA/WPA2-PSK mixed encrypted AP
       12             WiFi connecting to a WPA2-EAP TTLS encrypted AP
       13             WiFi connecting to a WPA2-EAP PEAP encrypted AP
__EOF
exit 0
}

#-----------------------------------------------------------------------
# Function: is_valid_MAC - Test if the given MAC address is valid
# Input: MAC address
# Output: Return 0 if vaild, else, 1 is returned
function is_valid_MAC()
{
	VALID_MAC=$(echo $1 | egrep -i -o "(([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2})|(([0-9A-Fa-f]{4}.){2}[0-9A-Fa-f]{4})")
	if [ -n "${VALID_MAC}" ];then
		PnL 2 WLAN MAC address: $1 is valid
		return 0
	else
		PnL 2 WLAN MAC address: $1 is NOT valid
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: test_wifi_dev_enumerated - Test WiFi device is enumerated
#			and MAC address is valie
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_wifi_dev_enumerated()
{
	PnL 2 Test WiFi device is enumerated

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	WLAN_DEV_ENUMERATED=0
	phy_list=$(run_cmd 1 "ls ${WLAN_SYSFS_IF} | tr '\n' '\t'")
	phy_list=$(echo "${phy_list}" | tr -d '\r')

	for phy in ${phy_list}
	do
		# To remove unnecessary '\t'
		phy=$(echo "$phy" | tr -d '\t')
		WLAN_DEV_LIST=$(run_cmd 1 "ls ${WLAN_SYSFS_IF}/${phy}/device/net | tr '\n' '\t'")
		WLAN_DEV_LIST=$(echo "${WLAN_DEV_LIST}" | tr -d '\r')
		for WLAN_DEV in ${WLAN_DEV_LIST}
		do
			# To remove unnecessary '\t'
			WLAN_DEV=$(echo "$WLAN_DEV" | tr -d '\t')
			if [ "${WLAN_DEV}" = "${WLAN_IF_NAME}" ];then
				# Get WLAN PHY device
				WLAN_PHY_DEV=$(run_cmd 1 "cat ${WLAN_SYSFS_IF}/${phy}/device/net/${WLAN_DEV}/phy80211/name")
				WLAN_PHY_DEV=$(echo "${WLAN_PHY_DEV}" | tr -d '\r')
				if [ -n "${WLAN_PHY_DEV}" -a "${WLAN_PHY_DEV}" = "${phy}" ];then
					WLAN_DEV_ENUMERATED=1
					PnL 2 Get WLAN PHY device: ${WLAN_PHY_DEV}
					PnL 0 WLAN device ${WLAN_DEV} is enumerated at ${WLAN_SYSFS_IF}/${phy}/device/net
					break
				fi
			fi
		done
	done

	if [ ! "${WLAN_DEV_ENUMERATED}" ];then
		PnL 1 WLAN device ${WLAN_IF_NAME} can NOT be enumerated
		RET=1
		return
	fi

	# Get MAC address and check its validity
	WLAN_MAC_ADDR=$(run_cmd 1 "cat ${WLAN_SYSFS_IF}/${WLAN_PHY_DEV}/device/net/${WLAN_IF_NAME}/address")
	WLAN_MAC_ADDR=$(echo "${WLAN_MAC_ADDR}" | tr -d '\r')
	if [ -n "${WLAN_MAC_ADDR}" ] && is_valid_MAC "${WLAN_MAC_ADDR}";then
		PnL 0 "Get valid MAC Address: ${WLAN_MAC_ADDR} for WLAN device: ${WLAN_IF_NAME}"
	else
		RET=1
		PnL 1 "Unable to Get valid MAC Address: ${WLAN_MAC_ADDR} for WLAN device: ${WLAN_IF_NAME}"
	fi
}

#-----------------------------------------------------------------------
# Function: wifi_switch_onoff - Switch on/off WiFi device
# Input: "ON" || "OFF"
# Output: $RET, =0 if successful, =1 if failed.
# Return: 0 if successful, 1 if failed.
function wifi_switch_onoff()
{
	# Get last dmesg's timestamp
	local last_ts=$(run_cmd 1 "dmesg | tail -n 1 | \
					sed -e 's/\[/\n/g' -e 's/\]/\n/g' | sed -n '2p'")

	case $1 in
	ON|on)
		# Switch on WiFi
		PnL 2 Switching ON WiFi device ${WLAN_IF_NAME}...
		run_cmd 1 ${IFCONFIG_CMD} ${WLAN_IF_NAME} up
		sleep 2

		# Check WiFi state
		wifi_stat=$(run_cmd 1 "${IFCONFIG_CMD} ${WLAN_IF_NAME} | \
					grep -i -o "up" | tr '[:upper:]' '[:lower:]'")
		wifi_stat=$(echo "${wifi_stat}" | tr -d '\r')
		if [ -n "${wifi_stat}" -a "${wifi_stat}" = "up" ] && \
				check_dmesg_error "${WLAN_IF_NAME}" "${last_ts}";then
			PnL 0 Switching WiFi ${WLAN_IF_NAME} ON successfully
			return 0
		else
			RET=1
			PnL 1 Switching WiFi ${WLAN_IF_NAME} ON failed
			return 1
		fi
		;;
	OFF|off)
		# Switch off WiFi
		PnL 2 Switching OFF WiFi device ${WLAN_IF_NAME}...
		run_cmd 1 ${IFCONFIG_CMD} ${WLAN_IF_NAME} down
		sleep 2

		# Check WiFi state
		wifi_stat=$(run_cmd 1 "${IFCONFIG_CMD} ${WLAN_IF_NAME} | \
					grep -i -o "up" | tr '[:upper:]' '[:lower:]'")
		wifi_stat=$(echo "${wifi_stat}" | tr -d '\r')
		if [ -z "${wifi_stat}" ] && check_dmesg_error "${WLAN_IF_NAME}" "${last_ts}";then
			PnL 0 Switching WiFi \"${WLAN_IF_NAME}\" OFF successfully
			return 0
		else
			RET=1
			PnL 1 Switching WiFi \"${WLAN_IF_NAME}\" OFF failed
			return 1
		fi
		;;
	*)
		PnL 1 Invalid Input parameter: $1, should be ON|on or OFF|off
		return 1;;
	esac
}

#-----------------------------------------------------------------------
# Function: test_wifi_on - Test switch on WiFi device
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_wifi_on()
{
	PnL 2 Test WiFi device switch ON

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	wifi_switch_onoff "ON"

	# Store kernel dmesg log at the end of test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

}

#-----------------------------------------------------------------------
# Function: test_wifi_off - Test switch off WiFi device
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_wifi_off()
{
	PnL 2 Test WiFi device switch OFF

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	wifi_switch_onoff "OFF"

	# Store kernel dmesg log at the end of test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"
}

#-----------------------------------------------------------------------
# Function: wifi_scan - Start WiFi scanning
# Input:
#    Arg1: SSID of an AP for verifing scan result
#    Arg2: 1-dump scan result; 0-no dump(default)
# Output: $RET, =0 if successful, =1 if failed.
# Return: 0 if successful; 1 if failed.
function wifi_scan()
{
	local SCAN_SSID=$1
	[ -n "${SCAN_SSID}" ] || return 1
	local SCAN_DUMP=$2
	[ -n "${SCAN_DUMP}" ] || SCAN_DUMP=0

	PnL 2 WiFi Scanning ...

	run_cmd 0 "${IWLIST_CMD} ${WLAN_IF_NAME} scan > ${SCAN_RESULT}"
	if [ -f "${SCAN_RESULT}" ];then
		cat "${SCAN_RESULT}" | grep "ESSID:" | grep -q "${SCAN_SSID}"
		if [ $? -eq 0 ];then
			AP_NUM=$(cat "${SCAN_RESULT}" | grep "ESSID:" | wc -l)
			PnL 0 WiFi Scan result: ${AP_NUM} APs are found
			[ "${SCAN_DUMP}" -eq 1 ] && cat "${SCAN_RESULT}"
			return 0
		else
			RET=1
			PnL 1 WiFi Scan result: failed to find test AP: "${SCAN_SSID}"
			return 1
		fi
	else
		RET=1
		PnL 1 WiFi Scan: No Aceess Point is Found
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: test_wifi_scan - Test WiFi scanning AP
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_wifi_scan()
{
	PnL 2 Test WiFi scanning

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# Switch on WiFi
	wifi_switch_onoff "ON"
	[ $? -eq 1 ] && return

	# Start WiFi scanning
	wifi_scan "${TEST_AP_ESSID}" 1

	# Store kernel dmesg log at the end of test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"
}

#-----------------------------------------------------------------------
# Function: wifi_connect_AP - WiFi connects to an AP
# Input: wpa_config_file
# Output: $RET, =0 if successful, =1 if failed.
# Return: 0 if successful; 1 if failed.
function wifi_connect_AP()
{
	wpa_config_file=$1

	# Check if wpa config file is valid
	ret=$(run_cmd 1 "test -f ${wpa_config_file} && echo -n GOTYOU")
	if [ -n "${ret}" -a "${ret}" = "GOTYOU" ];then
		SSID=$(run_cmd 1 "cat ${wpa_config_file} | grep ssid | cut -d"=" -f2")
		SSID=$(echo "${SSID}" | tr -d '"|\r')
		if [ -z "${SSID}" ];then
			RET=1
			PnL 1 Invalid wpa configuration file: ${wpa_config_file}, missing SSID.
			return 1
		fi
        # check whether SSID is existed
        wifi_scan "${SSID}"
        if [ $? -ne 0 ];then
			RET=2
			PnL 2 "Please make sure AP [${SSID}] is available for testing."
			return 1
        fi
	else
		RET=1
		PnL 1 wpa_supplicant configuration file ${wpa_config_file} is not existed.
		return 1
	fi

	# Killing existed wpa_supplicant process
	run_cmd 1 ${KILLALL_CMD} wpa_supplicant > /dev/null
	sleep 1
	ret=$(run_cmd 1 "ps | grep -i -q wpa && echo -n GOTYOU")
	if [ -n "${ret}" -a "${ret}" = "GOTYOU" ];then
		RET=1
		PnL 1 failed to kill wpa_supplicant process
		return 1
	fi

	PnL 2 Starting to connect to AP, SSID=${SSID}...
	# Start wpa_supplicant process
	run_cmd 1 wpa_supplicant -i ${WLAN_IF_NAME} -c ${wpa_config_file} &
	if [ $? -ne 0 ];then
		RET=1
		PnL 1 WiFi connecting: wpa_supplicant returns non-zero value
		return 1
	fi
	PID=$!
	sleep 5

	# Check connecting result
	ret=$(run_cmd 1 "${IWCONFIG_CMD} ${WLAN_IF_NAME} | grep -q "ESSID:\"${SSID}\"" && echo -n GOTYOU")
	if [ -n "${ret}" -a "${ret}" = "GOTYOU" ];then
		PnL 0 WiFi connect to AP ${SSID} successfully
	else
		RET=1
		PnL 1 WiFi failed connect to an AP
	fi

	# Kill background child process
	ps aux | grep -q "${PID}"
	[ $? -eq 0 ] && kill -9 "${PID}"

	return "${RET}"
}

#-----------------------------------------------------------------------
# Function: wpa_config - Configure WPA configuration file
# Input: WPA configuration file
# Output: $RET, =0 if successful, =1 if failed.
#
function wpa_config()
{
	local config_file=$1

	# Check validaty of the config file
	if [ ! -f "${config_file}" ];then
		PnL 1 WPA config file: ${config_file} is not found!
		RET=1
		return 1
	fi

	# Check default SSID value in the config file and update it
	# if it does not match with user-specified one $TEST_AP_ESSID
	default_ssid=$(cat "${config_file}" | \
			awk -F'=' '/ssid/{split($2,_," ");print _[1]}' | tr -d '\"|\r' )
	if [ "${TEST_AP_ESSID}" != "${default_ssid}" ];then
		PnL 2 Update SSID from "${default_ssid}" to "${TEST_AP_ESSID}"
		sed -i 's/'${default_ssid}'/'${TEST_AP_ESSID}'/' "${config_file}"
	fi

	# Install configure file to DUT
	adb -s ${DEVID} push "${config_file}" "${DUT_DATA_DIR}/${config_file}"

	return 0
}

#-----------------------------------------------------------------------
# Function: test_wifi_connect_AP - Test WiFi connecting to a non-encrypted AP
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_wifi_connect_AP()
{
	PnL 2 Test WiFi connecting to a Non-encrypted AP

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# Switch on WiFi
	wifi_switch_onoff "ON"
	[ $? -eq 1 ] && return

	# Prepare WPA configuration file
	wpa_config "${PLAINTEXT_CONFIG_FILE}"

	# Start WiFi connecting
	[ $? -ne 0 ] || \
	wifi_connect_AP "${DUT_DATA_DIR}/${PLAINTEXT_CONFIG_FILE}"
}

#-----------------------------------------------------------------------
# Function: test_wifi_connect_AP_WEP
#	- Test WiFi connecting to a WEP(128bit)-encrypted AP
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_wifi_connect_AP_WEP()
{
	PnL 2 Test WiFi connecting to a WEP\(128bit\)-encrypted AP

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# Switch on WiFi
	wifi_switch_onoff "ON"
	[ $? -eq 1 ] && return

	# Prepare WPA configuration file
	wpa_config "${WEP_CONFIG_FILE}"

	# Start WiFi connecting
	[ $? -ne 0 ] || \
	wifi_connect_AP "${DUT_DATA_DIR}/${WEP_CONFIG_FILE}"
}

#-----------------------------------------------------------------------
# Function: test_wifi_connect_AP_WPAPSK
#	- Test WiFi connecting to a WPA-PSK encrypted AP
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_wifi_connect_AP_WPAPSK()
{
	PnL 2 Test WiFi connecting to a WPA-PSK encrypted AP

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# Switch on WiFi
	wifi_switch_onoff "ON"
	[ $? -eq 1 ] && return

	# Prepare WPA configuration file
	wpa_config "${WPAPSK_CONFIG_FILE}"

	# Start WiFi connecting
	[ $? -ne 0 ] || \
	wifi_connect_AP "${DUT_DATA_DIR}/${WPAPSK_CONFIG_FILE}"
}

#-----------------------------------------------------------------------
# Function: test_wifi_connect_AP_WPA2PSK
#	- Test WiFi connecting to a WPA2-PSK encrypted AP
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_wifi_connect_AP_WPA2PSK()
{
	PnL 2 Test WiFi connecting to a WPA2-PSK encrypted AP

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# Switch on WiFi
	wifi_switch_onoff "ON"
	[ $? -eq 1 ] && return

	# Prepare WPA configuration file
	wpa_config "${WPA2PSK_CONFIG_FILE}"

	# Start WiFi connecting
	[ $? -ne 0 ] || \
	wifi_connect_AP "${DUT_DATA_DIR}/${WPA2PSK_CONFIG_FILE}"
}

#-----------------------------------------------------------------------
# Function: test_wifi_connect_AP_WPA12MIXED
#	- Test WiFi connecting to a WPA-PSK/WPA2-PSK mixed encrypted AP
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_wifi_connect_AP_WPA12MIXED()
{
	PnL 2 Test WiFi connecting to a WPA/WPA2-PSK mixed encrypted AP

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# Switch on WiFi
	wifi_switch_onoff "ON"
	[ $? -eq 1 ] && return

	# Prepare WPA configuration file
	wpa_config "${WPAMIX_CONFIG_FILE}"

	# Start WiFi connecting
	[ $? -ne 0 ] || \
	wifi_connect_AP "${DUT_DATA_DIR}/${WPAMIX_CONFIG_FILE}"
}

#-----------------------------------------------------------------------
# Function: test_wifi_connect_AP_WPA2EAPTTLS
#	- Test WiFi connecting to a WPA2-EAP TTLS encrypted AP
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_wifi_connect_AP_WPA2EAPTTLS()
{
	PnL 2 Test WiFi connecting to a WPA2-EAP encrypted AP

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# Switch on WiFi
	wifi_switch_onoff "ON"
	[ $? -eq 1 ] && return

	# Prepare WPA configuration file
	wpa_config "${WPA2EAPTTLS_CONFIG_FILE}"

	# Start WiFi connecting
	[ $? -ne 0 ] || \
	wifi_connect_AP "${DUT_DATA_DIR}/${WPA2EAPTTLS_CONFIG_FILE}"
}

#-----------------------------------------------------------------------
# Function: test_wifi_connect_AP_WPA2EAPPEAP
#	- Test WiFi connecting to a WPA2-EAP PEAP encrypted AP
# Input: N/A
# Output: $RET, =0 if successful, =1 if failed.
# Return: N/A
function test_wifi_connect_AP_WPA2EAPPEAP()
{
	PnL 2 Test WiFi connecting to a WPA2-EAP encrypted AP

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# Switch on WiFi
	wifi_switch_onoff "ON"
	[ $? -eq 1 ] && return

	# Prepare WPA configuration file
	wpa_config "${WPA2EAPPEAP_CONFIG_FILE}"

	# Start WiFi connecting
	[ $? -ne 0 ] || \
	wifi_connect_AP "${DUT_DATA_DIR}/${WPA2EAPPEAP_CONFIG_FILE}"
}

#-----------------------------------------------------------------------
# Function: get_wifi_BUS - get the correct bus for the WiFi driver
# Input: N/A
# Output: N/A
function get_wifi_bus()
{
	#For some cases there is the tag "MODALIAS=<bus>:XXXX", the second cut is
  #to ensure to get only the name of the bus.
	WLAN_BUS=$(run_cmd 1 "cat '${WLAN_INFO}/${WLAN_IF_NAME}/device/modalias' | \
  cut -d ':' -f 1 | cut -d '=' -f 2")
	PnL 2 "Bus for WiFi driver is ${WLAN_BUS}"
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
	1) test_module_load_unload;;
	2) get_wifi_bus
	   case ${WLAN_BUS} in
           sdio|SDIO) test_sdio_drv_bind_unbind;;
             idi|IDI) test_idi_drv_bind_unbind;;
	     pci|PCI) test_pci_drv_bind_unbind;;
		               *) PnL 1 Unknown Bus;RET=1;;
	   esac
	   ;;
	3) test_wifi_dev_enumerated;;
	4) test_wifi_on;;
	5) test_wifi_off;;
	6) test_wifi_scan;;
	7) test_wifi_connect_AP;;
	8) test_wifi_connect_AP_WEP;;
	9) test_wifi_connect_AP_WPAPSK;;
	10) test_wifi_connect_AP_WPA2PSK;;
	11) test_wifi_connect_AP_WPA12MIXED;;
	12) test_wifi_connect_AP_WPA2EAPTTLS;;
	13) test_wifi_connect_AP_WPA2EAPPEAP;;
	*) PnL 1 Unknown Testcase ID;RET=1;;
	esac


	# Resotre Android WiFi services after test
	run_cmd 1 svc wifi enable

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
