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
##  Nov. 04, 2015 - (Jose Perez - jose.perez.carranza@intel.com)              ##
##                  Add logic to handle multiple instances of same            ##
##                  alias name on the MOD_ALIAS_FILE                          ##
##                                                                            ##
################################################################################
#
# File:
#	lib-sdio.sh
#
# Description:
#	A library file for common functions and variables used by SDIO driver test.
#
# Functions:
#	get_sdio_devName
#	get_sdio_drvName
#	chk_sdio_sysfs
#	bind_sdio_drv
#	unbind_sdio_drv
#	test_sdio_drv_bind_unbind
#-----------------------------------------------------------------------
#shopt -s expand_aliases
#-----------------------------------------------------------------------
source "../lib/lib-common.sh"
#-----------------------------------------------------------------------
# Global variables
SDIO_DRV_IF="/sys/bus/sdio/drivers"
SDIO_DEV_IF="/sys/bus/sdio/devices"
SDIO_DEV_NAME=""
SDIO_DRV_NAME=""

#-----------------------------------------------------------------------
# Function: get SDIO device name
# Input: N/A
# Output: SDIO_DEV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_sdio_devName()
{
	local tmp_str=""
	local sdio_dev_list=""
	local sdio_alias_name_list=""

	sdio_alias_name_list=($(run_cmd 1 "test -f ${MOD_ALIAS_FILE} && \
					cat ${MOD_ALIAS_FILE} | \
					grep -E "\"${MOD_NAME}\|${MOD_NAME_ALIAS}\"" | \
					grep "sdio" | awk '{print \$2}' | cut -d":" -f2"))
	sdio_alias_name_list=$(echo "$sdio_alias_name_list" | tr -d '\r')
	if [ -z "${sdio_alias_name_list}" ];then
		PnL 1 "can NOT get sdio alias name for module ${MOD_NAME} from ${MOD_ALIAS_FILE}"
		RET=1
		return 1
	fi

	sdio_dev_list=$(run_cmd 1 "ls ${SDIO_DEV_IF} | tr '\n' '\t'")
	sdio_dev_list=$(echo "$sdio_dev_list" | tr -d '\r')
	if [ -z "${sdio_dev_list}" ];then
		PnL 1 "can NOT get sdio devices under directory: ${SDIO_DEV_IF}"
		RET=1
		return 1
	fi

	for sdio_dev in ${sdio_dev_list}
	do
		# To remove unecessary '\t'
		sdio_dev=$(echo "$sdio_dev" | tr -d '\t')
		for sdio_alias_name in ${sdio_alias_name_list[@]}
		do
			tmp_str=$(run_cmd 1 "test -f ${SDIO_DEV_IF}/${sdio_dev}/modalias && \
				cat ${SDIO_DEV_IF}/${sdio_dev}/modalias | grep ${sdio_alias_name}")
			if [ -n "${tmp_str}" ];then
				SDIO_DEV_NAME="${sdio_dev}"
				PnL 2 get "${MOD_NAME}" SDIO device name: "${SDIO_DEV_NAME}"
				return 0
			fi
		done
	done

	if [ -z "${SDIO_DEV_NAME}" ];then
		PnL 1 can NOT get "${MOD_NAME}" SDIO device name
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: get SDIO driver name
# Input: N/A
# Output: SDIO_DRV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_sdio_drvName()
{
	local tmp_str=""

	SDIO_DRV_NAME=$(run_cmd 1 "ls "${SDIO_DRV_IF}/" | grep ${MOD_NAME}")
	SDIO_DRV_NAME=$(echo "${SDIO_DRV_NAME}" | tr -d '\r')
	if [ -z "${SDIO_DRV_NAME}" ];then
		PnL 1 "can NOT get sdio drivers for ${MOD_NAME} under directory: ${SDIO_DRV_IF}"
		RET=1
		return 1
	fi

	tmp_str=$(run_cmd 1 "test -L ${SDIO_DRV_IF}/${SDIO_DRV_NAME}/${SDIO_DEV_NAME} && echo -n GOTYOU")
	if [ -n "${tmp_str}" -a "${tmp_str}" = "GOTYOU" ];then
		PnL 2 get "${MOD_NAME}" SDIO driver name: "${SDIO_DRV_NAME}"
		return 0
	else
		SDIO_DRV_NAME=""
		PnL 1 can NOT get "${MOD_NAME}" SDIO driver name
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: check sysfs interface for SDIO driver bind/unbind
# Input: N/A
# Output: return 0 if sysfs node is created, otherwise, 1 is returned
function chk_sdio_sysfs()
{
	local ret=$(run_cmd 1 "test -L ${SDIO_DEV_IF}/${SDIO_DEV_NAME}/driver/${SDIO_DEV_NAME} && echo -n GOTYOU")
	if [ -n "${ret}" -a "${ret}" = "GOTYOU" ];then
		return 0
	else
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: bind SDIO driver
# Input: N/A
# Output: return 0 is bind successfully, otherwise, 1 is returned
function bind_sdio_drv()
{
	# Get last dmesg's timestamp
	local last_ts=$(run_cmd 1 "dmesg | tail -n 1 | \
					sed -e 's/\[/\n/g' -e 's/\]/\n/g' | sed -n '2p'")

	# Bind SDIO driver
	run_cmd 1 "echo -n ${SDIO_DEV_NAME} > ${SDIO_DRV_IF}/${SDIO_DRV_NAME}/bind"

	if [ $? -eq 0 ] && chk_sdio_sysfs && \
			check_dmesg_error "${MOD_NAME}" "${last_ts}" && \
			check_dmesg_error "${MOD_NAME_ALIAS}" "${last_ts}";then
		PnL 0 "${SDIO_DEV_NAME}" is bound to SDIO driver successfully
		return 0
	else
		PnL 1 "${SDIO_DEV_NAME}" is not bound to SDIO driver
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: unbind SDIO driver
# Input: N/A
# Output: return 0 is bind successfully, otherwise, 1 is returned
function unbind_sdio_drv()
{
	run_cmd 1 "echo -n ${SDIO_DEV_NAME} > ${SDIO_DRV_IF}/${SDIO_DRV_NAME}/unbind"

	if [ $? -eq 0 ] && ! chk_sdio_sysfs;then
		PnL 0 "${SDIO_DEV_NAME}" is unbound to SDIO driver successfully
		return 0
	else
		PnL 1 "${SDIO_DEV_NAME}" failed to unbound to SDIO driver
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: test SDIO driver bind and unbind
# Input: N/A
# Output: N/A
function test_sdio_drv_bind_unbind()
{
	PnL 2 Test SDIO driver bind and unbind

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# get SDIO device name firstly
	get_sdio_devName
	[ $? -ne 0 ] && return

	# Get SDIO driver name
	get_sdio_drvName
	[ $? -ne 0 ] && return

	# Test bind SDIO driver
	unbind_sdio_drv

	# Test bind SDIO driver only if SDIO driveris unbound successfully
	if [ $? -eq 0 ];then
		bind_sdio_drv
	fi

	# Store kernel dmesg log at the end of test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"
}
