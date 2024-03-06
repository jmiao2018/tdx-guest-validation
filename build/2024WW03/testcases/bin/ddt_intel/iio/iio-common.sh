#! /bin/sh
#
# Copyright (c) Intel Corporation, 2015
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

# This script defines common functions and variables for all IIO tests.

source "common.sh"

IIO_SYS_DIR="/sys/bus/iio/devices"

############################# Functions #######################################
get_iio_devid()
{
	local dev_name=$1
	local dev_id=0
	local dev_is_found=0

	# Get IIO device number firstly
	num_iio_dev=$(ls $IIO_SYS_DIR/iio:device* | wc -l)

	# Find the device ID by matching the name
	while [ $dev_id -lt $num_iio_dev ]
	do
		name=$(cat $IIO_SYS_DIR/iio:device$dev_id/name)
		if [ "$name" = "$dev_name" ];then
			dev_is_found=1
			break
		fi
		dev_id=$(($dev_id+1))
	done

	if [ $dev_is_found -eq 1 ];then
		echo "$dev_id"
	else
		return 1
	fi
}
