#!/bin/bash
#
################################################################################
##                                                                            ##
## Copyright (c) Intel, 2016                                                  ##
##                                                                            ##
## Author:                                                                    ##
##  Kun Yan <kunx.yan@intel.com>                                              ##
##                                                                            ##
## History:                                                                   ##
##  Oct  27, 2016 - (Kun Yan) Created                                         ##
################################################################################
#
# File:
#	lib-pci.sh
#
# Description:
#	A library file for common functions and variables used by PCI driver test.
#
# Functions:
#	get_pci_devName
#	get_pci_drvName
#	chk_pci_sysfs
#	bind_pci_drv
#	unbind_pci_drv
#	test_pci_drv_bind_unbind
#-----------------------------------------------------------------------
#shopt -s expand_aliases
#-----------------------------------------------------------------------
source "../lib/lib-common.sh"
#-----------------------------------------------------------------------
# Global variables
PCI_DRV_IF="/sys/bus/pci/drivers"
PCI_DEV_IF="/sys/bus/pci/devices"
PCI_DEV_NAME=""
PCI_DRV_NAME=""

#-----------------------------------------------------------------------
# Function: get PCI device name
# Input: N/A
# Output: PCI_DEV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_pci_devName()
{
	local tmp_str=""
	local pci_dev_list=""
	local pci_alias_name_list=""

	pci_alias_name_list=($(run_cmd 1 "test -f ${MOD_ALIAS_FILE} && \
					cat ${MOD_ALIAS_FILE} | \
					grep -E "\"${MOD_NAME}\|${MOD_NAME_ALIAS}\"" | \
					grep "pci" | awk '{print \$2}' | cut -d":" -f2"))
	pci_alias_name_list=$(echo "$pci_alias_name_list" | tr -d '\r')
	PnL 2 "pci_alias_name:${pci_alias_name_list}"
	if [ -z "${pci_alias_name_list}" ];then
		PnL 1 "can NOT get pci alias name for module ${MOD_NAME} from ${MOD_ALIAS_FILE}"
		RET=1
		return 1
	fi

	pci_dev_list=$(run_cmd 1 "ls ${PCI_DEV_IF} | tr '\n' '\t'")
	pci_dev_list=$(echo "$pci_dev_list" | tr -d '\r')
	PnL 2 "pci_dev_list:${pci_dev_list}"
	if [ -z "${pci_dev_list}" ];then
		PnL 1 "can NOT get pci devices under directory: ${PCI_DEV_IF}"
		RET=1
		return 1
	fi

	for pci_dev in ${pci_dev_list}
	do
		# To remove unecessary '\t'
		pci_dev=$(echo "$pci_dev" | tr -d '\t')
		for pci_alias_name in ${pci_alias_name_list}
		do
			tmp_str=$(run_cmd 1 "test -f ${PCI_DEV_IF}/${pci_dev}/modalias && \
				cat ${PCI_DEV_IF}/${pci_dev}/modalias | grep " $( echo ${pci_alias_name} | sed 's/\*.*/*/g') "")
			if [ -n "${tmp_str}" ];then
				PCI_DEV_NAME="${pci_dev}"
				PnL 2 get "${MOD_NAME}" PCI device name: "${PCI_DEV_NAME}"
				return 0
			fi
		done
	done

	if [ -z "${PCI_DEV_NAME}" ];then
		PnL 1 can NOT get "${MOD_NAME}" PCI device name
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: get PCI driver name
# Input: N/A
# Output: PCI_DRV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_pci_drvName()
{
	local tmp_str=""

	PCI_DRV_NAME=$(run_cmd 1 "ls ${PCI_DRV_IF}/ | grep "$(ls -l $PCI_DEV_IF/$PCI_DEV_NAME/driver | sed 's#.*drivers\/##g')"")
	PCI_DRV_NAME=$(echo "${PCI_DRV_NAME}" | tr -d '\r')
	if [ -z "${PCI_DRV_NAME}" ];then
		PnL 1 "can NOT get pci drivers for ${MOD_NAME} under directory: ${PCI_DRV_IF}"
		RET=1
		return 1
	fi

	tmp_str=$(run_cmd 1 "test -L ${PCI_DRV_IF}/${PCI_DRV_NAME}/${PCI_DEV_NAME} && echo -n GOTYOU")
	if [ -n "${tmp_str}" -a "${tmp_str}" = "GOTYOU" ];then
		PnL 2 get "${MOD_NAME}" PCI driver name: "${PCI_DRV_NAME}"
		return 0
	else
		PCI_DRV_NAME=""
		PnL 1 can NOT get "${MOD_NAME}" PCI driver name
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: check sysfs interface for PCI driver bind/unbind
# Input: N/A
# Output: return 0 if sysfs node is created, otherwise, 1 is returned
function chk_pci_sysfs()
{
	local ret=$(run_cmd 1 "test -L ${PCI_DEV_IF}/${PCI_DEV_NAME}/driver/${PCI_DEV_NAME} && echo -n GOTYOU")
	if [ -n "${ret}" -a "${ret}" = "GOTYOU" ];then
		return 0
	else
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: bind PCI driver
# Input: N/A
# Output: return 0 is bind successfully, otherwise, 1 is returned
function bind_pci_drv()
{
	# Get last dmesg's timestamp
	local last_ts=$(run_cmd 1 "dmesg | tail -n 1 | \
					sed -e 's/\[/\n/g' -e 's/\]/\n/g' | sed -n '2p'")

	# Bind PCI driver
	run_cmd 1 "echo -n ${PCI_DEV_NAME} > ${PCI_DRV_IF}/${PCI_DRV_NAME}/bind"

	if [ $? -eq 0 ] && chk_pci_sysfs && \
			check_dmesg_error "${MOD_NAME}" "${last_ts}" && \
			check_dmesg_error "${MOD_NAME_ALIAS}" "${last_ts}";then
		PnL 0 "${PCI_DEV_NAME}" is bound to PCI driver successfully
		return 0
	else
		PnL 1 "${PCI_DEV_NAME}" is not bound to PCI driver
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: unbind PCI driver
# Input: N/A
# Output: return 0 is bind successfully, otherwise, 1 is returned
function unbind_pci_drv()
{
	PnL 2 "${PCI_DEV_NAME}  ${PCI_DRV_IF}/${PCI_DRV_NAME}/unbind  "
	run_cmd 1 "echo -n ${PCI_DEV_NAME} > ${PCI_DRV_IF}/${PCI_DRV_NAME}/unbind"
	#PnL 2 "${PCI_DEV_NAME}  ${PCI_DRV_IF}/${PCI_DRV_NAME}/unbind  "
	if [ $? -eq 0 ] && ! chk_pci_sysfs;then
		PnL 0 "${PCI_DEV_NAME}" is unbound to PCI driver successfully
		return 0
	else
		PnL 1 "${PCI_DEV_NAME}" failed to unbound to PCI driver
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: test PCI driver bind and unbind
# Input: N/A
# Output: N/A
function test_pci_drv_bind_unbind()
{
	PnL 2 Test PCI driver bind and unbind

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# Preparation works for driver testing - load driver module
	prepare_drv_test
	[ $? -eq 1 ] && return

	# get PCI device name firstly
	get_pci_devName
	[ $? -ne 0 ] && return

	# Get PCI driver name
	get_pci_drvName
	[ $? -ne 0 ] && return

	# Test bind PCI driver
	unbind_pci_drv

	# Test bind PCI driver only if PCI driveris unbound successfully
	if [ $? -eq 0 ];then
		bind_pci_drv
	fi

	# Store kernel dmesg log at the end of test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"
}
