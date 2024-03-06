#!/bin/sh
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

# Get IIO devices' names for different platform

# Input: Attribute IIO device should have
# Output: IIO device name

source "common.sh"

iio_attr=$1
iiodev=
############################### CLI Params ###################################

############################ DYNAMIC-DEFINED Params ##############################

############################ USER-DEFINED Params ##############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically
case $ARCH in
esac
case $DRIVER in
esac
case $SOC in
esac
case $MACHINE in
esac

case $iio_attr in
	"buffer"|"Buffer"|"BUFFER")
		iio_dev=$(lsiio -b | grep -B 1 "Buffer" | grep "Device" | cut -d" " -f2)
	;;
	"trigger"|"Trigger"|"TRIGGER")
		iio_dev_list=$(lsiio | cut -d" " -f2)
		iio_trigger_dev=$(lsiio -t | grep "Trigger" | cut -d" " -f2)
		if [ -z "$iio_trigger_dev" ];then
			test_print_trc "No IIO trigger device is registered"
			return 1
		fi

		for dev_name in $iio_dev_list
		do
			for tri_name in $iio_trigger_dev
			do
				echo "$tri_name" | grep -q "$dev_name"
				if [ $? -eq 0 ];then
					iio_dev="$iio_dev $dev_name"
					break 1
				fi
			done
		done
	;;
	"event"|"Event"|"EVENT")
		iio_dev=$(lsiio -e | grep -B 1 "Event" | grep "Device" | cut -d" " -f2)
	;;
	*)
		test_print_err "Unknown iio attr: $iio_attr"
		return 1
	;;
esac

first=1
if [ -n "$iio_dev" ];then
	# Format to "a|b|c"
	for dev in $iio_dev
	do
		dev=$(echo $dev | sed -e 's/^[ ,\t]*//g' -e 's/[ ,\t]*$//g')
		if [ $first -eq 1 ];then
			first=0
			iiodev="$dev"
		else
			iiodev="$iiodev|$dev"
		fi
	done
	echo "$iiodev"
else
	test_print_err "Failed to get IIO device name"
	return 1
fi
