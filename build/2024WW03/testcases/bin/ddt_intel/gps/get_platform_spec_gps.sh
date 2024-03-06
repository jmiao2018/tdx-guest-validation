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
# @params $1: MACHINE
# @returns 0 if test passes, 1 if test fails
# @history 2015-04-23: First version by zelinx.deng@intel.com
source "common.sh"

GPS_ACPI_ALIAS=""
GPSRF_ACPI_ALIAS=""
GPS_MODULE=""
GPSRF_MODULE=""
MOD_ALIAS_FILE="/system/lib/modules/$(uname -r)/modules.alias"
if [ $# -ne 1 ];then
	exit 1
fi

function get_platform_gps()
{
	local machine="$1"
	#set default variables
	case "$machine" in
		oars7a)
		GPS_MODULE="gnss_drv"
		GPSRF_MODULE=""
		return 0
		;;
		*)
		GPS_ACPI_ALIAS="80860F0A"
		GPSRF_ACPI_ALIAS="BCM4752E"
		GPS_MODULE=$(cat ${MOD_ALIAS_FILE} | grep ${GPS_ACPI_ALIAS} | awk -F' ' '{print $3}' | tr -d '\r')
		GPSRF_MODULE=$(cat ${MOD_ALIAS_FILE} | grep ${GPSRF_ACPI_ALIAS} | awk -F' ' '{print $3}' | tr -d '\r')
		return 0
		;;
	esac
}
get_platform_gps $1
echo "$GPS_MODULE $GPSRF_MODULE"
exit 0
