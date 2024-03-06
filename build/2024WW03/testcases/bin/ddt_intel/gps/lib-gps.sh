#!/bin/sh
###############################################################################
# Copyright (c) 2015 Intel - http://www.intel.com
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
source "common.sh"  # Import do_cmd(), die() and other functions
############################# Default value ####################################
TEST_ID="1"
TEST_LOOP="1"

############################ USER-DEFINED Params ###############################
SYSFS_MODULE_DIR="/sys/module"
GPS_CONFIG_FILE="/system/etc/gps.xml"

RFKILL_SYSFS_LIST="claim device hard index name persistent power soft state type uevent"
########################### DYNAMICALLY-DEFINED Params #########################
GPS_ACPI_ALIAS=""
GPSRF_ACPI_ALIAS=""

GPS_MODULE=""
GPSRF_MODULE=""
GPS_DEV_NAME=""
GPSRF_DEV_NAME=""
GPS_DRV_NAME=""
GPSRF_DRV_NAME=""
GPS_DEV_DIR=""
GPSRF_DEV_DIR=""
GPS_SYSFS_DEV_DIR=""
GPSRF_SYSFS_DEV_DIR=""
GPS_DRV_DIR=""
GPSRF_DRV_DIR=""
GPS_BAUDRATE=""

GPS_DEV_NODE=""
########################### TEST FUNCTIONS ####################################
# Function: get_baudrate - get GPS baudrate of GPS from GPS config file
# Input: N/A
# Output: N/A
function get_baudrate()
{
	if [ ! -f ${GPS_CONFIG_FILE} ];then
		test_print_trc "Can not get gps configuration file,use default value"
		GPS_BAUDRATE="921600"
	else
		GPS_BAUDRATE=$(cat ${GPS_CONFIG_FILE} | grep BaudRate | sed 's/ \|"//g' | awk -F'=' '{print $2} | 'tr -d '\r')
		if [ -z ${GPS_BAUDRATE} ];then
			test_print_trc "Can not get gps configuration file,use default value"
			GPS_BAUDRATE="921600"
		else
			test_print_trc "Have got gps baudrate"
		fi
	fi
}
# Function: get_module_name - get GPS_MODULE & GPSRF_MODULE from module.alias file
# Input: N/A
# Output: N/A
function get_module_name()
{
	MODULES=$(get_platform_spec_gps.sh "$MACHINE")
	GPS_MODULE=$(echo ${MODULES} | awk -F' ' '{print $1}')
	GPSRF_MODULE=$(echo ${MODULES} | awk -F' ' '{print $2}')
	if [ -z "${GPS_MODULE}" ];then
		test_print_trc "Failed to get GPS modules name"
		return 1
	else
		test_print_trc "Succeeded to get GPS modules name:${GPS_MODULE}"
	fi
	if [ -z "${GPSRF_MODULE}" ];then
		test_print_trc "Device do not support GPS RF module"
	else
		test_print_trc "Device support GPS RF module, GPS RF module name is:${GPSRF_MODULE}"
	fi
	return 0
}

# Function: get_drv_name - get driver type and name
# Input: N/A
# Output: N/A
function get_drv_name()
{
	drv_type=$(ls ${SYSFS_MODULE_DIR}/${GPS_MODULE}/drivers | awk -F':' '{print $1}' | tr -d '\r')
	GPS_DRV_NAME=$(ls ${SYSFS_MODULE_DIR}/${GPS_MODULE}/drivers | awk -F':' '{print $2}' | tr -d '\r')
	GPS_SYSFS_DEV_DIR="/sys/bus/${drv_type}/devices"
	GPS_DRV_DIR="/sys/bus/${drv_type}/drivers/${GPS_DRV_NAME}"
	if [ -d "${GPS_DRV_DIR}" ];then
		test_print_trc "Succeeded to get GPS driver path:${GPSRF_DRV_DIR}"
	else
		test_print_trc "Failed to get GPS driver path"
		return 1
	fi
	if [ -n "${GPSRF_MODULE}" ];then
		drv_type=$(ls ${SYSFS_MODULE_DIR}/${GPSRF_MODULE}/drivers | awk -F':' '{print $1}' | tr -d '\r')
		GPSRF_DRV_NAME=$(ls ${SYSFS_MODULE_DIR}/${GPSRF_MODULE}/drivers | awk -F':' '{print $2}' | tr -d '\r')
		GPSRF_SYSFS_DEV_DIR="/sys/bus/${drv_type}/devices"
		GPSRF_DRV_DIR="/sys/bus/${drv_type}/drivers/${GPSRF_DRV_NAME}"
		if [ -d ${GPSRF_DRV_DIR} ];then
			test_print_trc "Succeeded to get GPS RF driver path:${GPSRF_DRV_DIR}"
		else
			test_print_trc "Failed to get GPS RF driver path"
			return 1
		fi
	else
		test_print_trc "Device does not support GPS RF moudule, no need to get GPS RF driver path"
	fi
	return 0
}

# Function: get_dev_name - get GPS RF device name and GPSRF device name
# Input: N/A
# Output: N/A
function get_dev_name()
{
	if [ -n "${GPSRF_MODULE}" ];then
		dev_name_list=$(ls ${GPSRF_SYSFS_DEV_DIR} | tr '\n' '\t' | tr -d '\r')
		for dev_name in ${dev_name_list}
		do
			dev_name=$(echo ${dev_name} | tr -d '\t')
			drv_name=$(ls  -al ${GPSRF_SYSFS_DEV_DIR}/${dev_name}/driver | awk -F'/' '{print $NF}')
			if [ "${drv_name}" == "${GPSRF_DRV_NAME}" ];then
				GPSRF_DEV_NAME=${dev_name}
				GPSRF_DEV_DIR=${GPSRF_SYSFS_DEV_DIR}/${GPSRF_DEV_NAME}
				test_print_trc "Succeeded to get GPS RF device name: ${GPSRF_DEV_NAME},GPS RF device path:${GPSRF_DEV_DIR}"
				break
			fi
		done
		if [ -z ${GPSRF_DEV_NAME} ];then
			test_print_trc "Failed to get devices name"
			return 1
		fi
	else
		test_print_trc "Device does not support GPS RF devices, no need to get GPS RF device name"
	fi
	dev_name_list=$(ls ${GPS_SYSFS_DEV_DIR} | tr '\n' '\t' | tr -d '\r')
	for dev_name in ${dev_name_list}
	do
		dev_name=$(echo ${dev_name} | tr -d '\t')
		drv_name=$(ls -al ${GPS_SYSFS_DEV_DIR}/${dev_name}/driver | awk -F'/' '{print $NF}')
		if [ "${drv_name}" == "${GPS_DRV_NAME}" ];then
			if [ -n "${GPSRF_DEV_NAME}" ];then
				if [ ! -d "${GPS_SYSFS_DEV_DIR}/${dev_name}/${GPSRF_DEV_NAME}" ];then
					 continue
				fi
			fi
			GPS_DEV_NAME=${dev_name}
			GPS_DEV_DIR=${GPS_SYSFS_DEV_DIR}/${GPS_DEV_NAME}
			test_print_trc "Succeeded to get GPS device name: ${GPS_DEV_NAME},GPS device path:${GPS_DEV_DIR}"
			break
		fi
	done
	if [ -z ${GPS_DEV_NAME} ];then
		test_print_trc "Failed to get devices name"
		return 1
	fi
	GPS_DEV_NODE=$(ls ${GPS_DEV_DIR}/tty | tr -d '\n')
	GPS_DEV_NODE="/dev/${GPS_DEV_NODE}"
	if [ -e "${GPS_DEV_NODE}" ];then
		test_print_trc "Suceeded to get GPS device node:${GPS_DEV_NODE}"
	else
		test_print_trc "Failed to get GPS device node"
		return 1
	fi
	return 0
}

# Function: prepare_to_test - prepare to test
# Input: N/A
# Output: N/A
function prepare_to_test()
{
	test_print_trc "Start to prepare to test"
	get_module_name || die "Failed to prepare to test, cause can not get module name ,exit"
	get_drv_name || die "Failed to prepare to test, cause can not get driver name ,exit"
	mod_load ${GPS_MODULE} || die "Failed to prepare to test, cause can not load GPS mod ,exit"
	if [ -n "${GPSRF_MODULE}" ];then
		mod_load ${GPSRF_MODULE} || die "Failed to prepare to test, cause can not load GPS RF mode ,exit"
	fi
	get_dev_name || die "Failed to prepare to test, cause can not get device name ,exit"
}

# Function: check_drv_sysfs - check GPS/RF driver sysfs
# Input: $1 gps/gpsrf
# Output: Return 0 if successful, otherwise, return 1
# NOTE: if GPS RF device has been bind or module loaded, under GPS_RF_DEV_DIR should contain driver and rfkill folders
function check_drv_sysfs()
{

	#driver should be registered in sysfs
	case $1 in
		gpsrf)
		if [ ! -d ${GPSRF_DRV_DIR} ] || [ ! -d ${GPSRF_DEV_DIR}/rfkill ] || [ ! -d ${GPSRF_DEV_DIR}/driver ];then
			test_print_trc "Failed to check GPS RF driver sysfs"
			return 1
		fi
		test_print_trc "Succeeded to check GPS RF driver sysfs"
		return 0
		;;
		gps)
		#driver should be registered in sysfs
		if [ ! -d ${GPS_DRV_DIR} ] || [ ! -d ${GPS_DEV_DIR}/tty ] || [ ! -d ${GPS_DEV_DIR}/driver ];then
			test_print_trc "Failed to check GPS driver sysfs"
			return 1
		fi
		test_print_trc "Succeeded to check GPS driver sysfs"
		return 0
		;;
	esac
}

# Function: is_load_unload - to determin if mod is loaded or unloaded
# Input: module name
# Output: Return 0 if successful, otherwise, return 1
function is_load_unload()
{
	mod_name=$1
	lsmod | grep ${mod_name} &> /dev/null
	if [ $? -eq 0 ];then
		test_print_trc "${mod_name} is loaded"
		return 0
	else
		test_print_trc "${mod_name} is not loaded"
		return 1
	fi
}

# Function: mod_load - load module into kernel
# Input: module name
# Output: Return 0 if successful, otherwise, return 1
function mod_load()
{
	mod_name=$1
	modprobe ${mod_name}
	is_load_unload ${mod_name}
	if [ $? -eq 0 ];then
		test_print_trc "Succeeded to modprobe ${mod_name}"
		return 0
	else
		test_print_trc "Failed to modprobe ${mod_name}"
		return 1
	fi
}

# Function: mod_unload - unload module into kernel
# Input: module name
# Output: Return 0 if successful, otherwise, return 1
function mod_unload()
{
	mod_name=$1
	modprobe -r ${mod_name}
	is_load_unload ${mod_name}
	if [ $? -eq 1 ];then
		test_print_trc "Succeeded to remove ${mod_name}"
		return 0
	else
		test_print_trc "Failed to remove ${mod_name}"
		return 1
	fi
}

# Function: drv_bind - bind device to driver
# Input: $1:driver path, $2:device name
# Output: Return 0 if successful, otherwise, return 1
function drv_bind()
{

	drv_path=$1
	device=$2
	echo ${device} > ${drv_path}/bind
	if [ $? -eq 0 ];then
		test_print_trc "Succeeded to bind ${device} to ${drv_path}"
		return 0
	else
		test_print_trc "Failed to bind ${device} to ${drv_path}"
		return 1
	fi
}

# Function: drv_unbind - unbind device from driver
# Input: $1:driver path, $2:device name
# Output: Return 0 if successful, otherwise, return 1
function drv_unbind()
{
	drv_path=$1
	device=$2
	echo ${device} > ${drv_path}/unbind
	if [ $? -eq 0 ];then
		test_print_trc "Succeeded to unbind ${device} from ${drv_path}"
		return 0
	else
		test_print_trc "Failed to unbind ${device} from ${drv_path}"
		return 1
	fi
}

# Function: switch_RF - switch on/off Radio Frequency
# Input: "ON"|"OFF"
# Output: Return 0 if successful, otherwise, return 1
function switch_RF()
{
	# Get rfkill device name
	RFKILL_DEV=$(ls ${GPSRF_DEV_DIR}/rfkill | tr -d '\r')
	if [ -z $RFKILL_DEV ];then
		test_print_trc "Can not get rfkill port name"
	fi
	test_print_trc "Got rfkill port name: $RFKILL_DEV"
	case $1 in
	ON|on)
		# Switch on GPS RF
		ret=$(cat ${GPSRF_DEV_DIR}/rfkill/${RFKILL_DEV}/state | tr -d '\r')
		if [ ${ret} -eq 1 ];then
			test_print_trc "GPS RF switch is already ON"
			return 0
		fi
		test_print_trc "Turning ON GPS RF switch..."
		echo 0 > ${GPSRF_DEV_DIR}/rfkill/${RFKILL_DEV}/soft
		ret=$(cat ${GPSRF_DEV_DIR}/rfkill/${RFKILL_DEV}/state | tr -d '\r')
		if [ "${ret}" -ne 1 ];then
			test_print_trc "Failed to change ${RFKILL_DEV} state to 1"
			return 1
		fi
		sleep 2
		test_print_trc "GPS RF switch has been turned on"
		;;
	OFF|off)
		# Switch off GPS RF
		ret=$(cat ${GPSRF_DEV_DIR}/rfkill/${RFKILL_DEV}/state | tr -d '\r')
		if [ ${ret} -eq 0 ];then
			test_print_trc "GPS RF switch is already OFF"
			return 0
        fi
		test_print_trc "Turing OFF GPS RF switch"
		echo 1 > ${GPSRF_DEV_DIR}/rfkill/${RFKILL_DEV}/soft
		ret=$(cat ${GPSRF_DEV_DIR}/rfkill/${RFKILL_DEV}/state | tr -d '\r')
		if [ "${ret}" -ne 0 ];then
			test_print_trc "Failed to change ${RFKILL_DEV} state to 0"
			return 1
		fi
		sleep 2
		test_print_trc "GPS RF switch has been turned off"
		;;
	*)
		test_print_trc "Invalid Input parameter: $1, should be ON|on or OFF|off"
		return 1;;
	esac
}
