#!/bin/sh
#
# Copyright (c) Intel Corporation, 2015
#
# This program is free software; you can rediseventbute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is diseventbuted "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

# Get IIO event interface names for different platform

# Input: IIO device name
# Output: IIO event interface names for requested IIO device

source "common.sh"

iio_dev=$1
iioevent=
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


iio_event_list=$(lsiio -d "$iio_dev" -e | grep "Event" | cut -d":" -f2)
if [ -z "$iio_event_list" ];then
	test_print_trc "No IIO event interfaces found for IIO dev: $iio_dev"
	return 1
fi

first=1
if [ -n "$iio_event_list" ];then
	# Format to "a|b|c"
	for event in $iio_event_list
	do
		event=$(echo $event | sed -e 's/^[ ,\t]*//g' -e 's/[ ,\t]*$//g')
		if [ $first -eq 1 ];then
			first=0
			iioevent="$event"
		else
			iioevent="$iioevent|$event"
		fi
	done
	echo "$iioevent"
else
	test_print_err "Failed to get IIO event interface name for device: $iio_dev"
	return 1
fi
