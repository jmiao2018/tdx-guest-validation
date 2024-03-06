#!/bin/sh
#
# Copyright (c) Intel Corporation, 2015
#
# This program is free software; you can redischannelbute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is dischannelbuted "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

# Get IIO channel interface names for different platform

# Input: IIO device name
# Output: IIO channel interface names for requested IIO device

source "common.sh"

iio_dev=$1
iiochannel=
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


iio_channel_list=$(lsiio -d "$iio_dev" -c | grep "Channel" | cut -d":" -f2)
if [ -z "$iio_channel_list" ];then
	test_print_trc "No IIO channel interfaces found for IIO dev: $iio_dev"
	return 1
fi

first=1
if [ -n "$iio_channel_list" ];then
	# Format to "a|b|c"
	for channel in $iio_channel_list
	do
		channel=$(echo $channel | sed -e 's/^[ ,\t]*//g' -e 's/[ ,\t]*$//g')
		if [ $first -eq 1 ];then
			first=0
			iiochannel="$channel"
		else
			iiochannel="$iiochannel|$channel"
		fi
	done
	echo "$iiochannel"
else
	test_print_err "Failed to get IIO channel interface name for device: $iio_dev"
	return 1
fi
