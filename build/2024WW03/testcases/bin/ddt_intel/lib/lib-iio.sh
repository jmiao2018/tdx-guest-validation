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
#	lib-iio.sh
#
# Description:
#	A library file for common functions and variables used by IIO driver test.
#
# Functions:
#	test_iio_dev_enumerated
#	test_iio_dev_enumerated_by_acpi
#	test_iio_dev_enumerated_by_alias
#	test_iio_dev_enumerated_by_mod_alias
#-----------------------------------------------------------------------
#shopt -s expand_aliases
#-----------------------------------------------------------------------
source "../lib/lib-common.sh"
source "../lib/lib-acpi.sh"
source "../lib/lib-i2c.sh"
#-----------------------------------------------------------------------
# Global variables
IIO_DEV_IF="/sys/bus/iio/devices"
IIO_DEV_ID=""



#-----------------------------------------------------------------------
# Function: test IIO device registered and enumerated in /sys/bus/iio/devices
#           by matching the name. The device name should be same as either
#			kernel module name or ACPI device name
# Input: N/A
# Output: N/A
function test_iio_dev_enumerated_by_acpi()
{
	local num_iio_dev=""
	local dev_id=0
	local iio_dev_name=""

	# Get ACPI device name for matching IIO device name
	get_acpi_devName

	# IIO devices are enumerated as "iio:device{0...N}", whereis N is the largest IIO device ID
	# Get IIO device number firstly
	num_iio_dev=$(run_cmd 1 "ls -l ${IIO_DEV_IF}/iio:device* | wc -l")
	num_iio_dev=$(echo "$num_iio_dev" | tr -d '\r')

	while [ "${dev_id}" -lt "${num_iio_dev}" ]
	do
		iio_dev_name=$(run_cmd 1 cat "${IIO_DEV_IF}"/iio:device"${dev_id}"/name)
		echo  "${iio_dev_name}" | grep -qE "${MOD_NAME}|${MOD_NAME_ALIAS}"
		if [ $? -eq 0 ];then
			IIO_DEV_ID="${dev_id}"
			PnL 0 IIO device iio:device"${dev_id}" is registered and enumerated in "${IIO_DEV_IF}"
			return 0
		fi

		if [ -n "${ACPI_DEV_NAME}" ];then
			echo  "${iio_dev_name}" | grep -q "${ACPI_DEV_NAME}"
			if [ $? -eq 0 ];then
				IIO_DEV_ID="${dev_id}"
				PnL 0 IIO device iio:device"${dev_id}" is registered and enumerated in "${IIO_DEV_IF}"
				return 0
			fi
		fi
		dev_id=$((${dev_id}+1))
	done

	# IIO device not found
	return 1
}

#-----------------------------------------------------------------------
# Function: test IIO device registered and enumerated in /sys/bus/iio/devices
#           by matching the name. The device name should be same as either
#			kernel mod alias name or I2C device name
# Input: N/A
# Output: N/A
function test_iio_dev_enumerated_by_alias()
{
  local num_iio_dev=""
  local dev_id=0
  local iio_dev_name=""
  local alias_name=""
  local i2c_alias_name=""

  i2c_alias_name=$(run_cmd 1 "test -f ${MOD_ALIAS_FILE} && \
    cat ${MOD_ALIAS_FILE} |grep -E "\"${MOD_NAME}\|${MOD_NAME_ALIAS}\"" | \
    grep "i2c" | awk '{print \$2}' | cut -d":" -f2 | tr '\n' '\t'")
  if [ -z "${i2c_alias_name}" ]; then
    PnL 1 "can NOT get i2c alias name for module ${MOD_NAME} from \
    ${MOD_ALIAS_FILE}"
    return 1
  fi

  # IIO devices are enumerated as "iio:device{0...N}", whereis N is the largest IIO device ID
  # Get IIO device number firstly
  num_iio_dev=$(run_cmd 1 "ls -l ${IIO_DEV_IF}/iio:device* | wc -l")
  num_iio_dev=$(echo "$num_iio_dev" | tr -d '\r')
  for alias_name in ${i2c_alias_name}
  do
    while [ "${dev_id}" -lt "${num_iio_dev}" ]
    do
      iio_dev_name=$(run_cmd 1 cat "${IIO_DEV_IF}"/iio:device"${dev_id}"/name)
      echo  "${iio_dev_name}" | grep -qE "${alias_name}"
      if [ $? -eq 0 ];then
        IIO_DEV_ID="${dev_id}"
        PnL 0 IIO device iio:device"${dev_id}" is registered and enumerated in "${IIO_DEV_IF}"
        return 0
      fi

      dev_id=$((${dev_id}+1))
    done
    dev_id=0
  done

  # IIO device not found
  return 1
}

#-----------------------------------------------------------------------
# Function: test IIO device registered and enumerated in /sys/bus/iio/devices
#           by matching the name. The device name should be same as either
#			kernel mod alias name or I2C device name
# Input: N/A
# Output: N/A
function test_iio_dev_enumerated_by_mod_alias()
{
  local num_iio_dev=""
  local dev_id=0
  local iio_dev_name=""
  local i2c_mod_alias=""

  get_i2c_devName
  [ $? -ne 0 ] && return 1
  # IIO devices are enumerated as "iio:device{0...N}", whereis N is the largest IIO device ID
  # Get IIO device number firstly
  num_iio_dev=$(run_cmd 1 "ls -l ${IIO_DEV_IF}/iio:device* | wc -l")
  num_iio_dev=$(echo "$num_iio_dev" | tr -d '\r')
  while [ "${dev_id}" -lt "${num_iio_dev}" ]
  do
    iio_dev_name=$(run_cmd 1 cat "${IIO_DEV_IF}"/iio:device"${dev_id}"/name)
    i2c_mod_alias=$(run_cmd 1 "cat \
      "${I2C_DEV_IF}"/"${I2C_DEV_NAME}"/modalias | cut -d":" -f2")
    echo  "${iio_dev_name}" | grep -q "${i2c_mod_alias}"
    if [ $? -eq 0 ];then
      IIO_DEV_ID="${dev_id}"
      PnL 0 IIO device iio:device"${dev_id}" is registered and enumerated in \
      "${IIO_DEV_IF}"
      return 0
    fi
    dev_id=$((${dev_id}+1))
  done
  # IIO device not found
  return 1
}
#-----------------------------------------------------------------------
# Function: test IIO device registered and enumerated in /sys/bus/iio/devices
#           by matching the name. The device name should be same as either
#           kernel mod alias name or I2C device name
# Input: N/A
# Output: N/A
function test_iio_dev_enumerated_by_uevent()
{
  local num_iio_dev=""
  local dev_id=0
  local iio_dev_name=""
  local try_name=""

  get_i2c_devName
  [ $? -ne 0 ] && return 1

  num_iio_dev=$(run_cmd 1 "ls -l ${IIO_DEV_IF}/iio:device* | wc -l")
  num_iio_dev=$(echo "$num_iio_dev" | tr -d '\r')
  while [ "${dev_id}" -lt "${num_iio_dev}" ]
  do
    iio_dev_name=$(run_cmd 1 cat "${IIO_DEV_IF}"/iio:device"${dev_id}"/name)
    try_name=$(run_cmd 1 "cat \
      "${I2C_DEV_IF}"/"${I2C_DEV_NAME}"/uevent |grep DRIVER | cut -d"=" -f2")
    echo  "${iio_dev_name}" | grep -q "${try_name}"
    if [ $? -eq 0 ];then
      IIO_DEV_ID="${dev_id}"
      PnL 0 IIO device iio:device"${dev_id}" is registered and enumerated in \
      "${IIO_DEV_IF}"
      return 0
    fi
    dev_id=$((${dev_id}+1))
  done
  # IIO device not found
  return 1
}
#-----------------------------------------------------------------------
# Function: test IIO device registered and enumerated in /sys/bus/iio/devices
#           by matching the name. The device name should be same as either
#           kernel mod alias name or I2C device name
# Input: N/A
# Output: N/A
function test_iio_dev_enumerated()
{
	PnL 2 Test IIO device registered and enumerated in "${IIO_DEV_IF}"

  # Make sure kernel module is loaded or driver is built-in kernel
  test_drv_loadable ${MOD_NAME} ${MOD_NAME_ALIAS}
  # Return directly if kernel driver type can NOT be identified
  if [ $? -eq 2 ];then
    return
  fi

  test_iio_dev_enumerated_by_acpi
  if [ $? -ne 0 ];then
    test_iio_dev_enumerated_by_alias
    if [ $? -ne 0 ];then
      test_iio_dev_enumerated_by_mod_alias
      if [ $? -ne 0 ];then
        test_iio_dev_enumerated_by_uevent
        if [ $? -ne 0 ];then
          RET=1
          PnL 1 IIO device can NOT be enumerated in "${IIO_DEV_IF}"
          return 1
        fi
      fi
    fi
  fi
}
