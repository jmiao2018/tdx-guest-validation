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
# @desc Script to get platform specific variables
# @params $1 <uart_sysfs_dir> $2 <uart_serial_tty_list>
# @history 2015-07-10: First version by zelinx.deng@intel.com
source "common.sh"

uart_port_ignored=""
uart_sysfs_dir=""
uart_serial_tty_list=""
if [ $# -ne 2 ];then
	exit 1
fi

function get_uart_ignored()
{
	case "$MACHINE" in
		oars7a)
		#bluetooth port device num is:4:204 and GPS port device num is 4:208
		#both of them should be ignored
		uart_port_ignored="4:204 4:208"
		;;
		*)
		uart_sysfs_dir="$1"
		uart_serial_tty_list="$2"
		for tty_name in ${uart_serial_tty_list}
		do
			port_ignore=$(cat ${uart_sysfs_dir}/${tty_name}/dev)
			uart_port_ignored=$(echo ${uart_port_ignored} | sed "s/$/ ${port_ignore}/g" | sed "s/^\ *\|\ *$//g")
		done
		;;
	esac
}
get_uart_ignored "$1" "$2"
echo "${uart_port_ignored}"
