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
##  Sep 08, 2015 - (Rogelio Ceja) Add Support for Sensors on Sofia            ##
##                                                                            ##
################################################################################
#
# File:
#	lib-i2c.sh
#
# Description:
#	A library file for common functions and variables used by I2C driver test.
#
# Functions:
#	get_i2c_devName
#	get_i2c_devName_by_if
#	get_i2c_devName_by_alias
#	get_i2c_devName_by_uevent
#	get_i2c_drvName
#	chk_i2c_sysfs
#	bind_i2c_drv
#	unbind_i2c_drv
#	test_i2c_bus_bind_unbind
#-----------------------------------------------------------------------
#shopt -s expand_aliases
#-----------------------------------------------------------------------
source "../lib/lib-common.sh"
#-----------------------------------------------------------------------
# Global variables
I2C_DRV_IF="/sys/bus/i2c/drivers"
I2C_DEV_IF="/sys/bus/i2c/devices"
I2C_DEV_NAME=""
I2C_DRV_NAME=""

#-----------------------------------------------------------------------
# Function: get I2C bus client device name by uevent
# Input: N/A
# Output: I2C_DEV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_i2c_devName_by_uevent()
{
  local try_name=""

  if [ -z "${I2C_DEV_NAME}" ];then
    for dev_name in $(ls ${I2C_DEV_IF})
    do
      try_name=$(run_cmd 1 "test -f ${I2C_DEV_IF}/${dev_name}/uevent \
        && cat ${I2C_DEV_IF}/${dev_name}/uevent |grep DRIVER | \
        cut -d"=" -f2")
      if [ -n "${try_name}" ]; then
        echo  "${try_name}" | grep -qE \
        "${MOD_NAME}|${MOD_NAME_ALIAS}|${MOD_NAME_ALIAS_FIXED}"
        if [ $? -eq 0 ]; then
          I2C_DEV_NAME="${dev_name}"
          PnL 2 get "${MOD_NAME}" I2C device name: "${I2C_DEV_NAME}"
          return 0
        fi
      fi
    done
  fi
  return 1
}

#-----------------------------------------------------------------------
# Function: get I2C bus client device name by alias
# Input: N/A
# Output: I2C_DEV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_i2c_devName_by_alias()
{
  local i2c_alias_name=""
  local try_name=""

  i2c_alias_name=$(run_cmd 1 "test -f ${MOD_ALIAS_FILE} && \
  cat ${MOD_ALIAS_FILE} | grep -E "\"${MOD_NAME}\|${MOD_NAME_ALIAS}\"" | \
  grep "i2c" | awk '{print \$2}' | cut -d":" -f2 | tr '\n' '\t'")

  if [ -z "${i2c_alias_name}" ];then
    PnL 1 "can NOT get i2c alias name for module ${MOD_NAME} from ${MOD_ALIAS_FILE}"
    return 1
  fi

  for alias_name in ${i2c_alias_name}
  do
    for dev_name in $(ls ${I2C_DEV_IF})
    do
      try_name=$(run_cmd 1 cat "${I2C_DEV_IF}"/"${dev_name}"/name)
      echo  "${try_name}" | grep -qE \
      "${MOD_NAME}|${MOD_NAME_ALIAS}|${MOD_NAME_ALIAS_FIXED}|${alias_name}"
      if [ $? -eq 0 ]; then
        I2C_DEV_NAME="${dev_name}"
        PnL 2 get "${MOD_NAME}" I2C device name: "${I2C_DEV_NAME}"
        return 0
      fi
    done
  done
  return 1
}
#-----------------------------------------------------------------------
# Function: get I2C bus client device name by Interface
# Input: N/A
# Output: I2C_DEV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_i2c_devName_by_if()
{
  local try_name=""

  for dev_name in $(ls ${I2C_DEV_IF})
  do
    try_name=$(run_cmd 1 cat "${I2C_DEV_IF}"/"${dev_name}"/name)
    echo  "${try_name}" | grep -qE \
    "${MOD_NAME}|${MOD_NAME_ALIAS}|${MOD_NAME_ALIAS_FIXED}"
    if [ $? -eq 0 ]; then
      I2C_DEV_NAME="${dev_name}"
      PnL 2 get "${MOD_NAME}" I2C device name: "${I2C_DEV_NAME}"
      return 0
    fi
  done
  return 1
}

#-----------------------------------------------------------------------
# Function: get I2C bus client device name by acpi dev name
# Input: N/A
# Output: I2C_DEV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_i2c_devName_by_acpi()
{
  local tmp_str=""

  # Get ACPI device name first, as I2C device name is based on ACPI device name
  get_acpi_devName
  [ $? -ne 0 ] && return 1

  I2C_DEV_NAME="i2c-${ACPI_DEV_NAME}"
  tmp_str=$(run_cmd 1 "test -L ${I2C_DEV_IF}/${I2C_DEV_NAME} && echo -n GOTYOU")
  if [ -n "${tmp_str}" -a "${tmp_str}" = "GOTYOU" ];then
    PnL 2 get "${MOD_NAME}" I2C device name: "${I2C_DEV_NAME}"
    return 0
  else
    PnL 1 can NOT get "${MOD_NAME}" I2C device name: "${I2C_DEV_NAME}"
    I2C_DEV_NAME=""
    return 1
  fi
}

#-----------------------------------------------------------------------
# Function: get I2C bus client device name
# Input: N/A
# Output: I2C_DEV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_i2c_devName()
{

  get_i2c_devName_by_acpi [ -n "${I2C_DEV_NAME}" ] || get_i2c_devName_by_if
    [ -n "${I2C_DEV_NAME}" ] || get_i2c_devName_by_alias
    [ -n "${I2C_DEV_NAME}" ] || get_i2c_devName_by_uevent
    [ -z "${I2C_DEV_NAME}" ] &&  RET=1 && return 1

  if [ -n "${I2C_DEV_NAME}" ]; then
    return 0
  fi
}
#-----------------------------------------------------------------------
# Function: get I2C driver name
# Input: N/A
# Output: I2C_DRV_NAME
# Return: 0 if get; otherwise, RET=1 && 1 is returned
function get_i2c_drvName()
{
	local i2c_alias_name=""
	local try_name=""
	local tmp_str=""

	i2c_alias_name=$(run_cmd 1 "test -f ${MOD_ALIAS_FILE} && \
					cat ${MOD_ALIAS_FILE} | \
					grep -E "\"${MOD_NAME}\|${MOD_NAME_ALIAS}\"" | \
					grep "i2c" | awk '{print \$2}' | cut -d":" -f2 | tr '\n' '\t'")

	if [ -n "${i2c_alias_name}" ];then
		for try_name in ${i2c_alias_name}
		do
			# To remove unnecessary '\t'
			try_name=$(echo "$try_name" | tr -d '\t')
			tmp_str=$(run_cmd 1 "test -d ${I2C_DRV_IF}/${try_name} && echo -n GOTYOU")
			if [ -n "${tmp_str}" -a "${tmp_str}" = "GOTYOU" ];then
				I2C_DRV_NAME="${try_name}"
				PnL 2 get "${MOD_NAME}" I2C driver name: "${I2C_DRV_NAME}"
				return 0
			fi
		done
	fi

	# FIXME: some driver's name does not match the name in modules.alias,
	# thus, we have to rely on uevent info to catch DRIVER name.
	if [ -z "${I2C_DRV_NAME}" ];then
		[ -n "${I2C_DEV_NAME}" ] || get_i2c_devName
		if [ -n "${I2C_DEV_NAME}" ];then
			try_name=$(run_cmd 1 "test -f ${I2C_DEV_IF}/${I2C_DEV_NAME}/uevent \
				&& cat ${I2C_DEV_IF}/${I2C_DEV_NAME}/uevent | grep DRIVER | \
					cut -d"=" -f2")
			tmp_str=$(run_cmd 1 "test -d ${I2C_DRV_IF}/${try_name} && echo -n GOTYOU")
			if [ -n "${tmp_str}" -a "${tmp_str}" = "GOTYOU" ];then
				I2C_DRV_NAME="${try_name}"
				PnL 2 get "${MOD_NAME}" I2C driver name: "${I2C_DRV_NAME}"
				return 0
			fi
		fi
	fi

	if [ -z "${I2C_DRV_NAME}" ];then
		PnL 1 can NOT get "${MOD_NAME}" I2C driver name: "${I2C_DRV_NAME}"
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: check sysfs interface for I2C bus driver bind/unbind
# Input: N/A
# Output: return 0 if sysfs node is created, otherwise, 1 is returned
function chk_i2c_sysfs()
{
	local ret=$(run_cmd 1 "test -L ${I2C_DEV_IF}/${I2C_DEV_NAME}/driver/${I2C_DEV_NAME} && echo -n GOTYOU")
	if [ -n "${ret}" -a "${ret}" = "GOTYOU" ];then
		return 0
	else
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: bind I2C bus driver
# Input: N/A
# Output: return 0 is bind successfully, otherwise, 1 is returned
function bind_i2c_drv()
{
	# Get last dmesg's timestamp
	local last_ts=$(run_cmd 1 "dmesg | tail -n 1 | \
					sed -e 's/\[/\n/g' -e 's/\]/\n/g' | sed -n '2p'")

	# Bind I2C driver
	run_cmd 1 "echo -n ${I2C_DEV_NAME} > ${I2C_DRV_IF}/${I2C_DRV_NAME}/bind"

	if [ $? -eq 0 ] && chk_i2c_sysfs && \
			check_dmesg_error "${MOD_NAME}" "${last_ts}" && \
			check_dmesg_error "${MOD_NAME_ALIAS}" "${last_ts}";then
		PnL 0 "${I2C_DEV_NAME}" is bound to I2C bus driver successfully
		return 0
	else
		PnL 1 "${I2C_DEV_NAME}" is not bound to I2C bus driver
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: unbind I2C bus driver
# Input: N/A
# Output: return 0 is bind successfully, otherwise, 1 is returned
function unbind_i2c_drv()
{
	run_cmd 1 "echo -n ${I2C_DEV_NAME} > ${I2C_DRV_IF}/${I2C_DRV_NAME}/unbind"

	if [ $? -eq 0 ] && ! chk_i2c_sysfs;then
		PnL 0 "${I2C_DEV_NAME}" is unbound to I2C bus driver successfully
		return 0
	else
		PnL 1 "${I2C_DEV_NAME}" failed to unbound to I2C bus driver
		RET=1
		return 1
	fi
}

#-----------------------------------------------------------------------
# Function: test I2C bus driver bind and unbind
# Input: N/A
# Output: N/A
function test_i2c_bus_bind_unbind()
{
	PnL 2 Test I2C bus driver bind and unbind

	# Store kernel dmesg log before starting a test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"

	# get I2C bus client device name firstly
	get_i2c_devName
	[ $? -ne 0 ] && return

	# Get I2C driver name
	get_i2c_drvName
	[ $? -ne 0 ] && return

	# Test bind I2C bus driver
	unbind_i2c_drv

	# Test bind I2C bus driver only if I2C bus driveris unbound successfully
	if [ $? -eq 0 ];then
		bind_i2c_drv
	fi

	# Store kernel dmesg log at the end of test
	run_cmd 0 "dmesg >> ${KLOG_FILE}"
}
