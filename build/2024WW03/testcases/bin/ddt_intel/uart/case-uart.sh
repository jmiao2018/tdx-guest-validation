#!/bin/bash
#Copyright (C) 2015 Intel - http://www.intel.com
#Author:
#   Zelin Deng(zelinx.deng@intel.com)
#
#ChangeLog:
#   Jan 30th, 2015 - (Zelin) Created
#
#	4/16/2015: 1.modfied Set_ttySn and Set_baudrate fuction
#	4/17/2015: 	1.remove blank spaces, Replaced by TAB on top of line.
#				2.get tty device node by dynamic way
#				3.Define uart baudrate list as a global veriale
#	4/18/2015:  1.add 3 function: Get_serial_driver , Get_serial_device and prepare_to_test
#				2.remove an unused function
#	4/20/2015: Change static way to dynamic way to get variables
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
source "../lib/lib-common.sh"
source "../uart/lib-uart.sh"
#define some GLOBAL VARIABLES
UART_BAUDRATE_LIST="0 50 75 110 134 150 200 300 600 1200 1800 2400 4800 9600 \
			19200 38400 57600 115200 230400 460800 500000 576000 921600 \
			1000000 1152000 1500000 2000000 2500000 3000000 3500000 4000000"
#UART_DRV_MOD="8250_dw"
UART_SYSFS_DIR="/sys/class/tty"

#/sys/class/tty/ttyS*/ should contain those nodes
UART_SYSFS_NODE="close_delay closing_wait custom_divisor dev io_type \
				iomem_base iomem_reg_shift irq line port power type \
				uartclk uevent xmit_fifo_size"

############################### dynamic variables ##############################
#ttySx ignored when setting baudrate test
UART_PORT_IGNORE=""

UART_DRV_MOD=""

#3 drivers
UART_PNP_DRV_NAME=""
UART_PNP_DRV_DIR=""
UART_DW_DRV_NAME=""
UART_DW_DRV_DIR=""
UART_SERIAL_DRV_NAME=""
UART_SERIAL_DRV_DIR=""

#ttyS0 ttyS1 ttyS...under /sys/class/tty.divide into 3 categories
UART_TTY_LIST=""
UART_PNP_TTY_LIST=""
UART_DW_TTY_LIST=""
UART_SERIAL_TTY_LIST=""

#devices name that is using ttySn. Such as: 80860F0A:00, serial8250 .etc.
UART_PNP_DEV_NAME_LIST=""
UART_DW_DEV_NAME_LIST=""
UART_SERIAL_DEV_NAME_LIST=""

#global variables of xgold serial
UART_XGOLD_SERIAL_TTY_LIST=""
UART_XGOLD_SERIAL_DEV_NAME_LIST=""
UART_XGOLD_SERIAL_TTY_DRV_DIR_LIST=""
UART_XGOLD_SERIAL_TTY_DRV_NAME_LIST=""
################################# fucntional ###################################

#Function: Get device list from ${UART_SYSFS_DIR}
#Input: $1: <tty_list>
#Output: Device name list of ${device type}
#Return: N/A
function Get_device_list()
{
	local tmp_dev_name_list=""
	[ $# -ne 1 ] && return
	tty_list=$1
	for tty_name in ${tty_list}
	do
		tty_name=$(echo ${tty_name} | tr -d '\t') #remove the \t charactor
		dev=$(ls -al ${UART_SYSFS_DIR}/${tty_name}/device | awk -F'../' '{print $NF}')
		#this loop for combine the dev list
		tmp_dev_name_list=$(echo ${tmp_dev_name_list} | sed "s/$/ ${dev}/g" | sed "s/^\ *\|\ *$//g")
	done
	echo $tmp_dev_name_list
}

#Function: Get serial device name from ${UART_SYSFS_DIR}
#Intput: N/A
#Output: N/A
#Returen: N/A
function Get_serial_device()
{
	PnL 2 Get serial device name from ${UART_SYSFS_DIR}
	UART_XGOLD_SERIAL_TTY_LIST=$(ls -al ${UART_SYSFS_DIR} | grep "tty" | grep -v "virtual" | grep "soc0" | awk -F'/' '{print $NF}' | tr '\n' '\t' | tr -d '\r')
	if [ -n "${UART_XGOLD_SERIAL_TTY_LIST}" ];then
		UART_XGOLD_SERIAL_DEV_NAME_LIST=$(Get_device_list "${UART_XGOLD_SERIAL_TTY_LIST}")
	else
		PnL 2 Not Found xgold serial tty device, may not support
	fi

	UART_PNP_TTY_LIST=$(ls -al ${UART_SYSFS_DIR} | grep "tty" | grep -v "virtual"| grep "pnp0" | awk -F'/' '{print $NF}' | tr '\n' '\t' | tr -d '\r')
	if [ -n "${UART_PNP_TTY_LIST}" ];then
		UART_PNP_DEV_NAME_LIST=$(Get_device_list "${UART_PNP_TTY_LIST}")
	else
		PnL 2 Not Found pnp tty device, may not support
	fi

	UART_DW_TTY_LIST=$(ls -al ${UART_SYSFS_DIR} | grep "tty" | grep -v "virtual" | grep "80860F0A" | awk -F'/' '{print $NF}' | tr '\n' '\t' | tr -d '\r')
	if [ -n "${UART_DW_TTY_LIST}" ];then
		UART_DW_DEV_NAME_LIST=$(Get_device_list "${UART_DW_TTY_LIST}")
	else
		PnL 2 Not Found dw tty device, may not support
	fi

	UART_SERIAL_TTY_LIST=$(ls -al ${UART_SYSFS_DIR} | grep "tty" | grep -v "virtual" |  grep "serial8250" | awk -F'/' '{print $NF}' | tr '\n' '\t' | tr -d '\r')
	if [ -n "${UART_SERIAL_TTY_LIST}" ];then
		UART_SERIAL_DEV_NAME_LIST=$(Get_device_list "${UART_SERIAL_TTY_LIST}")
	else
		PnL 2 Not Found serial tty device, may not support
	fi
}

#Function: Get serial driver name from ${UART_SYSFS_DIR}
#Intput: N/A
#Output: N/A
#Returen: 0 if get; otherwise 1
function Get_serial_driver()
{
	PnL 2 Get serial driver name from ${UART_SYSFS_DIR}
	if [ -n "$UART_XGOLD_SERIAL_TTY_LIST" ];then
		for tty in $UART_XGOLD_SERIAL_TTY_LIST
		do
			tty_drv=$(ls -al ${UART_SYSFS_DIR}/${tty}/device/driver | awk -F'/' '{print $NF}')
			sub=$(readlink ${UART_SYSFS_DIR}/${tty}/device/subsystem | sed 's/\.\.\///g')
			UART_XGOLD_SERIAL_TTY_DRV_NAME_LIST=$(echo ${UART_XGOLD_SERIAL_TTY_DRV_NAME_LIST} | sed "s/$/ ${tty_drv}/g" | sed "s/^\ *\|\ *$//g")
			tty_drv_dir="/sys/${sub}/drivers"
			UART_XGOLD_SERIAL_TTY_DRV_DIR_LIST=$(echo ${UART_XGOLD_SERIAL_TTY_DRV_DIR_LIST} | sed "s|$| ${tty_drv_dir}|g" | sed "s/^\ *\|\ *$//g")
			PnL 2 "Got UART XGOLD_SERIAL driver name list:${UART_XGOLD_SERIAL_TTY_DRV_NAME_LIST},located at those directories:${UART_XGOLD_SERIAL_TTY_DRV_DIR_LIST}"
		done
	else
		PnL 2 "Do not support UART XGOLD_SERIAL driver"
	fi

	if [ -n "${UART_PNP_TTY_LIST}" ];then
		try_name=$(echo $UART_PNP_TTY_LIST | awk -F' ' '{print $1}')
		if [ -n ${try_name} ];then
			UART_PNP_DRV_NAME=$(ls -al ${UART_SYSFS_DIR}/${try_name}/device/driver | awk -F'/' '{print $NF}' | tr -d '\r')
			UART_PNP_DRV_DIR="/sys/$(readlink ${UART_SYSFS_DIR}/${try_name}/device/driver | sed 's/\.\.\///g')"
			PnL 2 "Got UART PNP driver name:${UART_PNP_DRV_NAME}"
		fi
	else
		PnL 2 "Do not support UART PNP driver"
	fi

	if [ -n "${UART_DW_TTY_LIST}" ];then
		try_name=$(echo $UART_DW_TTY_LIST | awk -F' ' '{print $1}')
		if [ -n ${try_name} ];then
			UART_DW_DRV_NAME=$(ls -al ${UART_SYSFS_DIR}/${try_name}/device/driver | awk -F'/' '{print $NF}' | tr -d '\r')
			UART_DW_DRV_DIR="/sys/$(readlink ${UART_SYSFS_DIR}/${try_name}/device/driver | sed 's/\.\.\///g')"
			PnL 2 "Got UART DW driver name:${UART_DW_DRV_NAME}"
		fi
	else
		PnL 2 "Do not support UART DW driver"
	fi

	if [ -n "${UART_SERIAL_TTY_LIST}" ];then
		try_name=$(echo $UART_SERIAL_TTY_LIST | awk -F' ' '{print $1}')
		if [ -n ${try_name} ];then
			UART_SERIAL_DRV_NAME=$(ls -al ${UART_SYSFS_DIR}/${try_name}/device/driver | awk -F'/' '{print $NF}' | tr -d '\r')
			UART_SERIAL_DRV_DIR="/sys/$(readlink ${UART_SYSFS_DIR}/${try_name}/device/driver | sed 's/\.\.\///g')"
			PnL 2 "Got UART SERIAL driver name:${UART_SERIAL_DRV_NAME}"
		fi
	else
		PnL 2 "Do not support UART SERIAL driver"
	fi
}

#Function: prepare for uart test, get devices & drivers name
#Intput: N/A
#Output: N/A
#Returen: 0 if get; otherwise 1
function prepare_to_test()
{
	UART_TTY_LIST=$(ls -al ${UART_SYSFS_DIR} | grep -E "ttyS[0-9]+" | awk -F'/' '{print $NF}' | tr '\n' '\t' | tr -d '\r')
	#oars7a's uart drvier is not a kernel module
	UART_DRV_MOD=$(../lib/get_module_config_name.sh "${DRV_NAME}" "${MACHINE}")
	if [ "x${UART_DRV_MOD}" != "x" ];then
		PnL 2 Got uart module name:${UART_DRV_MOD}
		ret=$(lsmod | grep ${UART_DRV_MOD})
		if [ -z "${ret}" ]; then
			Load_mod "${UART_DRV_MOD}"
			if [ $? -eq 1 ];then
				PnL 2 ${UART_DRV_MOD} has not been loaded, Failed to prepare to test.
				return 1
			fi
		fi
	else
		PnL 2 Device does not have uart kernel module
	fi
	Get_serial_device
	Get_serial_driver
	return 0
}

#Function: check /sys/class/tty
#Intput: ttySn
#Output: N/A
#Returen: 0 if get; otherwise 1
function Check_ttyS_n()
{
	#check parameter
	[ $# -ne 1 ] && return 1
	local dev_name=$1
	local dev_name_available=""
	dev_name_available=$(echo -n ${dev_name} | grep tty)
	if [ -z "${dev_name_available}" ]; then
		PnL 2 ${dev_name} is invalid
		return 1
	fi

	for node in ${UART_SYSFS_NODE}
	do
		if [ -e ${UART_SYSFS_DIR}/${dev_name}/${node} ]; then
			PnL 2 ${node} has been SUCCESSFULLY found under ${UART_SYSFS_DIR}/${dev_name}
			continue
		fi
		PnL 2 ${node} has been FAILED found under ${UART_SYSFS_DIR}/${dev_name}
		return 1
	done
	return 0
}
#1. Check tty sysfs
#Function: check /sys/class/tty
#Intput: N/A
#Output: RET=1 if failed
#Returen: 0 if get; otherwise 1
function Check_sys_class_tty()
{
	local try_name=""

	PnL 2 Check tty node under ${UART_SYSFS_DIR}

	for try_name in ${UART_TTY_LIST}
	do
		Check_ttyS_n ${try_name}
		if [ $? -ne 0 ];then
			PnL 1 Check ${UART_SYSFS_DIR} FAILED
			RET=1
			return 1
		fi
	done
	PnL 0 Check ${UART_SYSFS_DIR} SUCCESSFULLY
	return 0
}
#2. 8250 driver registered or not
#Function: check if serial8250 driver has been registered
#Intput: N/A
#Output: RET=1 if failed
#Returen: 0 if get; otherwise 1
function Check_serial_driver()
{
	PnL 2 Check 8250 serial driver
	Verified_driver "${UART_SERIAL_DRV_DIR}"
	if [ $? -eq 0 ];then
		PnL 0 Check ${UART_SERIAL_DRV_NAME} driver SUCCESSFULLY,Its under ${UART_SERIAL_DRV_DIR}
		return 0
	else
		PnL 1 Check ${UART_SERIAL_DRV_NAME} driver FAILED,,Its not under ${UART_SERIAL_DRV_DIR}
		RET=1
		return 1
	fi
}

#3. 8250_dw driver registered or not
#Function: check if 8250_dw driver has been registered
#Intput: N/A
#Output: RET=1 if failed
#Returen: 0 if get; otherwise 1
function Check_dw_driver()
{
	Verified_mod "${UART_DRV_MOD}"
	if [ $? -ne 0 ];then
		Load_mod "${UART_DRV_MOD}"
	fi
	PnL 2 Check 8250_dw driver
	#Get_dw_driver_name
	Verified_driver "${UART_DW_DRV_DIR}"
	if [ $? -eq 0 ];then
		PnL 0 Check ${UART_DW_DRV_NAME} driver SUCCESSFULLY,Its under ${UART_DW_DRV_DIR}
		return 0
	else
		PnL 1 Check ${UART_DW_DRV_NAME} driver FAILED,Its under ${UART_DW_DRV_DIR}
		RET=1
		return 1
	fi
}

#4. test ${UART_DRV_MOD} rmmod / modprobe function
#Function: Test ${UART_DRV_MOD} load/unload
#Intput: N/A
#Output:  RET=1 if failed
#Returen: 0 if get; otherwise 1
function Load_unload_dw_mod()
{
	Verified_mod "${UART_DRV_MOD}"
	if [ $? -ne 0 ];then
		PnL 1 FAILED to load/unload ${UART_DRV_MOD} kernel module
		RET=1
		return 1
	fi

	Remove_mod "${UART_DRV_MOD}"
	if [ $? -eq 0 ];then
		#Check_dw_driver
		Verified_driver "${UART_DW_DRV_DIR}"
		if [ $? -ne 0 ];then
			Load_mod "${UART_DRV_MOD}"
			if [ $? -eq 0 ];then
				Verified_driver "${UART_DW_DRV_DIR}"
				if [ $? -eq 0 ];then
					PnL 0 SUCCESSFULLY to load/unload ${UART_DRV_MOD} kernel module
					return 0
				fi
			fi
		fi
	fi
	PnL 1 FAILED to load/unload ${UART_DRV_MOD} kernel module
	RET=1
	return 1
}

#5. 8250_pnp driver registerd or not
#Function: check if 8250_pnp driver has been registered
#Intput: N/A
#Output: RET=1 if failed
#Returen: 0 if get; otherwise 1
function Check_pnp_driver
{
	PnL 2 Check 8250_pnp driver
	#Get_dw_driver_name
	Verified_driver "${UART_PNP_DRV_DIR}"
	if [ $? -eq 0 ];then
		PnL 0 Check ${UART_PNP_DRV_NAME} driver SUCCESSFULLY,,Its under ${UART_PNP_DRV_DIR}
		return 0
	else
		PnL 1 Check ${UART_PNP_DRV_NAME} driver FAILED,,Its not under ${UART_SERIAL_DRV_DIR}
		RET=1
		return 1
	fi
}

#Function: Check if xgold_serial tty driver has been registered
#Input: N/A
#Output: RET=1 if failed
#Return: 0 if get; otherwise 1
function Check_xgold_serial_driver()
{
	local tty_drv=""
	local cnt="0"
	UART_XGOLD_SERIAL_TTY_DRV_DIR_LIST=(${UART_XGOLD_SERIAL_TTY_DRV_DIR_LIST})
	PnL 2 Check xgold serial serial driver
	for tty_drv in ${UART_XGOLD_SERIAL_TTY_DRV_NAME_LIST}
	do
		if [ -e "${UART_XGOLD_SERIAL_TTY_DRV_DIR_LIST[${cnt}]}/${tty_drv}" ];then
			PnL 0 Check ${tty_drv} driver SUCCESSFULLY,,Its under ${UART_XGOLD_SERIAL_TTY_DRV_DIR_LIST[${cnt}]}
		else
			PnL 1 Check ${tty_drv} driver FAILED,,Its not under ${UART_XGOLD_SERIAL_TTY_DRV_DIR_LIST[${cnt}]}
			RET=1
			return 1
		fi
		cnt=$(($cnt+1))
	done
	return 0
}

#6. 8250 driver bind / unbind
#Function: Test serial8250 bind/unbind
#Intput: N/A
#Output: RET=1 if failed
#Returen: 0 if get; otherwise 1
function Bind_unbind_serial()
{
	PnL 2 Test serial driver Bind/unbind
	if [ -z "${UART_SERIAL_DEV_NAME_LIST}" ];then
		PnL 1 Do not support UART SERIAL devices
		RET=1
		return 1
	fi
	for try_name in ${UART_SERIAL_DEV_NAME_LIST}
	do
		Unbind_device "${UART_SERIAL_DRV_DIR}" "${try_name}"

		if [ $? -eq 0 ]; then
			Bind_device "${UART_SERIAL_DRV_DIR}" "${try_name}"
		fi
	done
}

#7. 8250_dw driver bind / unbind
#Function: Test 8250_dw  bind/unbind
#Intput: N/A
#Output: RET=1 if failed
#Returen: 0 if get; otherwise 1
function Bind_unbind_dw()
{
	PnL 2 Test dw driver Bind/unbind

	Load_mod "${UART_DRV_MOD}"
	if [ -z "${UART_DW_DEV_NAME_LIST}" ];then
		PnL 1 Do not support UART DW devices
		RET=1
		return 1
	fi
	for try_name in ${UART_DW_DEV_NAME_LIST}
	do
		Unbind_device "${UART_DW_DRV_DIR}" "${try_name}"

		if [ $? -eq 0 ]; then
			Bind_device "${UART_DW_DRV_DIR}" "${try_name}"
		fi
	done
}

#8. 8250_pnp driver bind / unbind
#Function: Test 8250_pnp bind/unbind
#Intput: N/A
#Output: RET=1 if failed
#Returen: 0 if get; otherwise 1
function Bind_unbind_pnp()
{
	PnL 2 Test serial driver Bind/unbind
	if [ -z ${UART_PNP_DEV_NAME_LIST} ];then
		PnL 1 Do not support UART PNP devices
		RET=1
		return 1
	fi
	for try_name in ${UART_PNP_DEV_NAME_LIST}
	do
		Unbind_device "${UART_PNP_DRV_DIR}" "${UART_PNP_DEV_NAME}"

		if [ $? -eq 0 ]; then
			Bind_device "${UART_PNP_DRV_DIR}" "${UART_PNP_DEV_NAME}"
		fi
	done
}

#Function:set ttySn's badurate
#Input: /dev/ttySn (like /dev/ttyS0)
#Output: N/A
#Returen: return 0 successful , 1 faild
function Set_ttySn()
{
	local ttySn=""
	local tmp=""
	local cnt="0"
	[ $# -ne 1 ] && return 1
	ttySn=$1
	PnL 2 testing baudrate setting, now is testting $ttySn
	for tmp in $UART_BAUDRATE_LIST
	#at least one of baudrate_list can be set for ttySn, cnt to count how many baudrate can be set
	do
		uart_tests "$ttySn" "$tmp"
		if [ $? -eq 0 ];then
			PnL 2 setting baudrate at $tmp sucessful
			cnt=`expr $cnt + 1`
		else
			PnL 2 setting baudrate at $tmp failed
		fi
	done
	if [ $cnt -eq 0 ];then
		return 1
	else
		return 0
	fi
}

#Function: setting baudrate test
#Input: N/A
#Output: RET=1 if failed
#Return: 0 if successful, 1 if failed
function Set_baudrate()
{
	PnL 2 Test baudrate setting
	tty_dev_list=${UART_TTY_LIST}
	#get the device number of ignored uart port
	UART_PORT_IGNORE=$(get_platform_spec_uart.sh "${UART_SYSFS_DIR}" "${UART_SERIAL_TTY_LIST}")
	PnL 2 Device number should be ignored:${UART_PORT_IGNORE}
	if [ -z "${tty_dev_list}" ];then
		PnL 1 can not get tty device node under /dev, setting baudrate FAILED
		RET=1
		return 1
	fi
	for tty_dev_node in ${tty_dev_list}
	do
		#get tty_dev_node device number by /dev/ttyS
		tty_dev_no=$(cat "${UART_SYSFS_DIR}/${tty_dev_node}/dev")
		uart_ignore_flag=$(echo ${UART_PORT_IGNORE} | grep ${tty_dev_no})
		if [ -n "${uart_ignore_flag}" ]; then
			PnL 2 $tty_dev_node device number is:${tty_dev_no}, has been ignored
			continue
		fi
		Set_ttySn "/dev/${tty_dev_node}"
		if [ $? -ne 0 ];then
			PnL 1 setting ${tty_dev_node} baudrate testing FAILED
			RET=1
			return 1
		fi
	done

	PnL 0 setting baudrate testing SUCCESSFUL
	return 0
}
