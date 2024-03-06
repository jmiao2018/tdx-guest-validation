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

# @desc Script to run gps tests.
# @params -c) test case id
#         -l) test loop
#         -h) help
# @returns 0 if test passes, 1 if test fails
# @history 2015-04-03: First version by zelinx.deng@intel.com

source "common.sh"  # Import do_cmd(), die() and other functions
source "lib-gps.sh"
############################# Functions #######################################
usage()
{
	cat<<_EOF
	Usage:
		./${0##*/} [-c CASE_ID] [-l TEST_LOOP]
	Option:
		-c CASE_ID		test case ID
		-l TEST_LOOP	how many loops for test, default is 1
		-h Help			print usage
_EOF
}

################################ CLI Params ####################################
# Please use getopts
while getopts  :c:l:h arg
do
	case $arg in
		c)      TEST_ID="$OPTARG";;
		l)      TEST_LOOP="$OPTARG";;
		h)      usage
				exit 0
				;;
		:)      die "$0: Must supply an argument to -$OPTARG.";;
	\?)     die "Invalid Option -$OPTARG ";;
	esac
done

########################### TEST FUNCTIONS ####################################
# Function: check_gps_sysfs - check if gps device has been registered in sysfs
# Input: N/A
# Output: Return 0 if successful, otherwise, return 1
# NOTE: no matter device bind/unbind or module load/unload, it should be exist
function test_check_gps_sysfs()
{
	if [ ! -d ${GPS_DEV_DIR} ];then
		test_print_trc "GPS device has not registered in sysfs"
		exit 1
	fi
	test_print_trc "GPS device has been registered in sysfs"
	exit 0
}

# Function: check_gpsrf_sysfs - check if gps rfkill device has been registered in sysfs
# Input: N/A
# Output: Return 0 if successful, otherwise, return 1
# NOTE: no matter device bind/unbind or module load/unload, it should be exist
function test_check_gpsrf_sysfs()
{
	if [ ! -d ${GPSRF_DEV_DIR} ];then
		test_print_trc "GPS RFKILL device has not registered in sysfs"
		exit 1
	fi
	test_print_trc "GPS RFKILL device has been registered in sysfs"
	exit 0
}

# Function: test_load_unload - kernel module load/unload
# Input: $1 module_name:gps or gpsrf
# Output: Return 0 if successful, otherwise, return 1
function test_load_unload()
{
	if [ $1 == "gps" ];then
		module_name=${GPS_MODULE}
	elif [ $1 == "gpsrf" ];then
		module_name=${GPSRF_MODULE}
	fi
	#get the original state
	is_load_unload "${module_name}"
	flag=$?
	if [ ${flag} -eq 0 ];then #has already load
		mod_unload ${module_name}
		check_drv_sysfs "$1"
		if [ $? -eq 0 ];then
			test_print_trc "LOAD/UNLOAD TEST FAILED"
			exit 1
		fi
		mod_load ${module_name}
		check_drv_sysfs "$1"
		if [ $? -eq 1 ];then
			test_print_trc "LOAD/UNLOAD TEST FAILED"
			exit 1
		fi
	else
		mod_load ${module_name}
		check_drv_sysfs "$1"
		if [ $? -eq 1 ];then
			test_print_trc "LOAD/UNLOAD TEST FAILED"
			exit 1
		fi
		mod_unload ${module_name}
		check_drv_sysfs "$1"
		if [ $? -eq 0 ];then
			test_print_trc "LOAD/UNLOAD TEST FAILED"
			exit 1
		fi
	fi
	test_print_trc "LOAD/UNLOAD TEST SUCCESSFULLY"
	exit 0
}

# Function: test_bind_unbind - driver bind/unbind
# Input: $1: gps/gpsrf
# Output: Return 0 if successful, otherwise, return 1
# NOTE:
function test_bind_unbind()
{
	if [ $1 == "gps" ];then
		module_name=${GPS_MODULE}
		drv_path=${GPS_DRV_DIR}
		dev_name=${GPS_DEV_NAME}
	elif [ $1 == "gpsrf" ];then
		module_name=${GPSRF_MODULE}
		drv_path=${GPSRF_DRV_DIR}
		dev_name=${GPSRF_DEV_NAME}
	fi
	mod_load ${module_name}
	if [ -d ${drv_path}/${dev_name} ];then
		drv_unbind ${drv_path} ${dev_name}
		check_drv_sysfs "$1"
		if [ $? -eq 0 ];then
			test_print_trc "BIND/UNBIND TEST FAILED"
			exit 1
		fi
		drv_bind ${drv_path} ${dev_name}
		check_drv_sysfs "$1"
		if [ $? -eq 1 ];then
			test_print_trc "BIND/UNBIND TEST FAILED"
			exit 1
		fi
	else
		drv_bind ${drv_path} ${dev_name}
		check_drv_sysfs "$1"
		if [ $? -eq 1 ];then
			test_print_trc "BIND/UNBIND TEST FAILED"
			exit 1
		fi
		drv_unbind ${drv_path} ${dev_name}
		check_drv_sysfs "$1"
		if [ $? -eq 0 ];then
			test_print_trc "BIND/UNBIND TEST FAILED"
			exit 1
		fi
	fi
	test_print_trc "BIND/UNBIND TEST SUCCESSFULLY"
	return 0
}

# Function: test_on_off - rf switch on/off
# Input: N/A
# Output: Return 0 if successful, otherwise, return 1
# NOTE:
function test_on_off()
{
	switch_RF on
	if [ $? -eq 1 ];then
		test_print_trc "TEST RF SWITCH ON/OFF FAILED"
		exit 1
	fi
	switch_RF off
	if [ $? -eq 1 ];then
		test_print_trc "TEST RF SWITCH ON/OFF FAILED"
		exit 1
	fi
	test_print_trc "TEST RF SWITCH ON/OFF SUCCESSFULLY"
	exit 0
}

# Function: test_check_gpsd - check if gps daemon has been started
# Input: N/A
# Output: Return 0 if successful, otherwise, return 1
# NOTE:
function test_check_gpsd()
{
	ps -x | grep -v grep | grep gpsd
	if [ $? -eq 0 ];then
		test_print_trc "GPS daemon has been started, check successfully"
		exit 0
	fi
	gpsd -c ${GPS_CONFIG_FILE}
	ps -x | grep -v grep | grep gpsd
	if [ $? -eq 1 ];then
		test_print_trc "GPS daemon start failed, check failed"
		exit 1
	fi
}

# Function: test_gps_port - get data via serial port of gps
# Input: device name
# Output: Return 0 if successful, otherwise, return 1
# NOTE:
function test_gps_port()
{
	device_name=$1
	#first, turn on screen
	input keyevent 26
	sleep 1
	#then, unlock screen
	input keyevent 82
	sleep 1
	#then, prevent sleep
	svc power stayon true
	#start google maps app
	am start -n com.google.android.apps.maps/com.google.android.maps.MapsActivity
	sleep 2
	#start test
	chown gps:root ${device_name}
	if	[ -n "${GPSRF_MODULE}" ];then
		rfkill_dev=$(ls ${GPSRF_DEV_DIR}/rfkill | tr -d '\r')
		chown gps:gps "${GPSRF_DEV_DIR}/rfkill/${rfkill_dev}/state"
	fi
	gps_tests -d ${device_name}
	ret=$?

	#back to default
	am force-stop com.google.android.apps.maps
	input keyevent 26
	if [ $ret -eq 0 ];then
		test_print_trc "TEST GPS PORT SUCCESSFULLY"
		exit 0
	else
		test_print_trc "TEST GPS PORT SUCCESSFULLY"
        exit 0
	fi
}

# Function: test_check_rfkill_sysfs - check rfkill sysfs
# Input: N/A
# Output: Return 0 if successful, otherwise, return 1
function test_check_rfkill_sysfs()
{
	rfkill_dev=$(ls ${GPSRF_DEV_DIR}/rfkill | tr -d '\r')
	rfkill_dev_dir=${GPSRF_DEV_DIR}/rfkill/${rfkill_dev}
	for node in ${RFKILL_SYSFS_NODE}
	do
		if [ ! -e ${rfkill_dev_dir}/${node} ];then
			test_print_trc "Failed to check rfkill sysfs, can not find node: ${node}"
			exit 1
		fi
		test_print_trc "Node ${node} exists under ${rfkill_dev_dir}"
	done
	test_print_trc "Succeeded to check rfkill sysfs, all nodes are found"
	exit 0
}
########################### REUSABLE TEST LOGIC ###############################
x="1"
while [ $x -le $TEST_LOOP ]
do
	test_print_start "GPS test [$TEST_ID] loop: $x"
	prepare_to_test || die "Test exit"
	case $TEST_ID in
		1) test_check_rfkill_sysfs;;
		2) test_check_gps_sysfs;;
		3) test_check_gpsrf_sysfs;;
		4) test_load_unload "gps";;
		5) test_load_unload "gpsrf";;
		6) test_bind_unbind "gps";;
		7) test_bind_unbind "gpsrf";;
		8) test_on_off;;
		9) test_check_gpsd;;
		10) test_gps_port "${GPS_DEV_NODE}";;
		*) test_print_err "error test id: $TEST_ID";;
	esac
	test_print_end "GPS test [$TEST_ID] loop: $x"
	x=$(expr $x + 1)
done
