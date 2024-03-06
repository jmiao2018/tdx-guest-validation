#!/bin/bash
#
################################################################################
##                                                                            ##
## Copyright (c) Intel, 2014                                                  ##
##                                                                            ##
## Author:                                                                    ##
##  Jose Perez Carranza <jose.perez.carranza@intel.com>                       ##
##                                                                            ##
## History:                                                                   ##
##  Nov. 06, 2015 - (Jose Perez Carranza) Created                             ##
##                                                                            ##
################################################################################
#
# File:
#	lib-idi.sh
#
# Description:
#	A library file for common functions and variables used by IDI driver test.
#
# Functions:
#	get_idi_devName
#	get_idi_drvName
#	chk_idi_sysfs
#	bind_idi_drv
#	unbind_idi_drv
#	test_idi_drv_bind_unbind
#-----------------------------------------------------------------------
#shopt -s expand_aliases
#-----------------------------------------------------------------------
source "../lib/lib-common.sh"
#-----------------------------------------------------------------------
# Global variables
IDI_DRV_IF="/sys/bus/idi/drivers"
IDI_DEV_IF="/sys/bus/idi/devices"
IDI_DEV_NAME=""
IDI_DRV_NAME=""

#-----------------------------------------------------------------------
# Function: get IDI device name
# Input: N/A
# Output: IDI_DEV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_idi_devName()
{
	local tmp_str=""
	local idi_dev_list=""
	local idi_alias_name_list=""

	idi_alias_name_list=($(run_cmd 1 "test -f ${MOD_ALIAS_FILE} && \
					cat ${MOD_ALIAS_FILE} | \
					grep -E "\"${MOD_NAME}\|${MOD_NAME_ALIAS}\"" | \
					grep "idi" | awk '{print \$2}' | cut -d":" -f2"))
	idi_alias_name_list=$(echo "$idi_alias_name_list" | tr -d '\r')
	if [ -z "${idi_alias_name_list}" ];then
		PnL 1 "can NOT get idi alias name for module ${MOD_NAME} from ${MOD_ALIAS_FILE}"
		RET=1
		return 1
	fi

	idi_dev_list=$(run_cmd 1 "ls ${IDI_DEV_IF} | tr '\n' '\t'")
	idi_dev_list=$(echo "$idi_dev_list" | tr -d '\r')
	if [ -z "${idi_dev_list}" ];then
		PnL 1 "can NOT get idi devices under directory: ${IDI_DEV_IF}"
		RET=1
		return 1
	fi

	for idi_dev in ${idi_dev_list}
	do
		# To remove unnecessary '\t'
		idi_dev=$(echo "$idi_dev" | tr -d '\t')
		for idi_alias_name in ${idi_alias_name_list[@]}
		do
			idi_alias_name="${idi_alias_name%?}"
			tmp_str=$(run_cmd 1 "test -f ${IDI_DEV_IF}/${idi_dev}/modalias && \
				cat ${IDI_DEV_IF}/${idi_dev}/modalias | grep ${idi_alias_name}")
			if [ -n "${tmp_str}" ];then
				IDI_DEV_NAME="${idi_dev}"
				PnL 2 get "${MOD_NAME}" IDI device name: "${IDI_DEV_NAME}"
				IDI_DRV_NAME=$(run_cmd 1 "ls -l ${IDI_DEV_IF}/${IDI_DEV_NAME}/ | grep 'driver'")
				IDI_DRV_NAME=${IDI_DRV_NAME##*/}
				PnL 2 Driver "${IDI_DRV_NAME}"
				return 0
			fi
		done
	done

	if [ -z "${IDI_DEV_NAME}" ];then
		PnL 1 can NOT get "${MOD_NAME}" IDI device name
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: get IDI driver name
# Input: N/A
# Output: IDI_DRV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_idi_drvName()
{
	local tmp_str=""

	if [ -z "${IDI_DRV_NAME}" ];then
		PnL 1 "can NOT get idi drivers for ${MOD_NAME} under directory: ${IDI_DRV_IF}"
		RET=1
		return 1
	fi

	tmp_str=$(run_cmd 1 "test -L ${IDI_DRV_IF}/${IDI_DRV_NAME}/${IDI_DEV_NAME} && echo -n GOTYOU")
	if [ -n "${tmp_str}" -a "${tmp_str}" = "GOTYOU" ];then
		PnL 2 get "${MOD_NAME}" IDI driver name: "${IDI_DRV_NAME}"
		return 0
	else
		IDI_DRV_NAME=""
		PnL 1 can NOT get "${MOD_NAME}" IDI driver name
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: check sysfs interface for IDI driver bind/unbind
# Input: N/A
# Output: return 0 if sysfs node is created, otherwise, 1 is returned
function chk_idi_sysfs()
{
	local ret=$(run_cmd 1 "test -L ${IDI_DEV_IF}/${IDI_DEV_NAME}/driver/${IDI_DEV_NAME} && echo -n GOTYOU")
	if [ -n "${ret}" -a "${ret}" = "GOTYOU" ];then
		return 0
	else
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: bind IDI driver
# Input: N/A
# Output: return 0 is bind successfully, otherwise, 1 is returned
function bind_idi_drv()
{
	# Get last dmesg's timestamp
	local last_ts=$(run_cmd 1 "dmesg | tail -n 1 | \
					sed -e 's/\[/\n/g' -e 's/\]/\n/g' | sed -n '2p'")

	# Bind IDI driver
	run_cmd 1 "echo -n ${IDI_DEV_NAME} > ${IDI_DRV_IF}/${IDI_DRV_NAME}/bind"

	if [ $? -eq 0 ] && chk_idi_sysfs && \
			check_dmesg_error "${MOD_NAME}" "${last_ts}" && \
			check_dmesg_error "${MOD_NAME_ALIAS}" "${last_ts}";then
		PnL 0 "${IDI_DEV_NAME}" is bound to IDI driver successfully
		return 0
	else
		PnL 1 "${IDI_DEV_NAME}" is not bound to IDI driver
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: unbind IDI driver
# Input: N/A
# Output: return 0 is bind successfully, otherwise, 1 is returned
function unbind_idi_drv()
{
	run_cmd 1 "echo -n ${IDI_DEV_NAME} > ${IDI_DRV_IF}/${IDI_DRV_NAME}/unbind"

	if [ $? -eq 0 ] && ! chk_idi_sysfs;then
		PnL 0 "${IDI_DEV_NAME}" is unbound to IDI driver successfully
		return 0
	else
		PnL 1 "${IDI_DEV_NAME}" failed to unbound to IDI driver
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: test IDI driver bind and unbind
# Input: N/A
# Output: N/A
function test_idi_drv_bind_unbind()
{
	PnL 2 Test IDI driver bind and unbind

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# get IDI device name firstly
	get_idi_devName
	[ $? -ne 0 ] && return

	# Get IDI driver name
	get_idi_drvName
	[ $? -ne 0 ] && return

	# Test bind IDI driver
	unbind_idi_drv

	# Test bind IDI driver only if IDI driveris unbound successfully
	if [ $? -eq 0 ];then
		bind_idi_drv
	fi

	# Store kernel dmesg log at the end of test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"
}
