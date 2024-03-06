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
##  Aug 25, 2014 - (Wenzhong Sun) Created                                     ##
##                                                                            ##
################################################################################
#
# File:
#	lib-acpi.sh
#
# Description:
#	A library file for common functions and variables used by ACPI driver test.
#
# Functions:
#	get_acpi_devName
#	test_acpi_dev_enumerated
#-----------------------------------------------------------------------

source "../lib/lib-common.sh"

#-----------------------------------------------------------------------
# Global variables
ACPI_DEV_IF="/sys/bus/acpi/devices"
ACPI_DEV_NAME=""

#-----------------------------------------------------------------------
# Function: get ACPI device name
# Input: N/A
# Output: ACPI_DEV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_acpi_devName()
{
	local acpi_alias_name=""
	local try_name=""
	local tmp_str=""

	acpi_alias_name=$(run_cmd 1 "test -f ${MOD_ALIAS_FILE} && \
				cat ${MOD_ALIAS_FILE} | grep -E "\"${MOD_NAME}\|${MOD_NAME_ALIAS}\"" | \
				grep "acpi" | awk '{print \$2}' | cut -d":" -f2 | tr '\n' '\t'")

	if [ -z "${acpi_alias_name}" ];then
		PnL 1 "can NOT get acpi alias name for module ${MOD_NAME} from ${MOD_ALIAS_FILE}"
		return 1
	fi

	for try_name in ${acpi_alias_name}
	do
		# To remove unnecessary '\t'
		try_name=$(echo "$try_name" | tr -d '\t')
		# ACPI device name has appended ":00" as the first deviceID
		try_name="${try_name}:00"
		tmp_str=$(run_cmd 1 "test -L ${ACPI_DEV_IF}/${try_name} && echo -n GOTYOU")
		if [ -n "${tmp_str}" -a "${tmp_str}" = "GOTYOU" ];then
			ACPI_DEV_NAME="${try_name}"
			PnL 2 get "${MOD_NAME}" ACPI device name: "${ACPI_DEV_NAME}"
			return 0
		fi
	done

	if [ -z "${ACPI_DEV_NAME}" ];then
		PnL 1 can NOT get "${MOD_NAME}" ACPI device name: "${ACPI_DEV_NAME}"
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: test ACPI device registered and enumerated in /sys/bus/acpi/devices
# Input: N/A
# Output: N/A
function test_acpi_dev_enumerated()
{
	PnL 2 Test ACPI device registered and enumerated in "${ACPI_DEV_IF}"

	get_acpi_devName
	if [ $? -eq 0 ];then
		PnL 0 ACPI device "${ACPI_DEV_NAME}" is registered and enumerated in "${ACPI_DEV_IF}"
	else
		PnL 1 ACPI device "${ACPI_DEV_NAME}" is not registered
		RET=1
	fi
}
