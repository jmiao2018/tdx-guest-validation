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

# Get IIO trigger devices' names for different platform

# Input: IIO device name
# Output: IIO trigger device name for requested IIO device

source "common.sh"

iio_dev=$1
iio_tri=
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


iio_trigger_dev=$(lsiio -t | grep "Trigger" | cut -d" " -f2)
if [ -z "$iio_trigger_dev" ];then
	test_print_trc "No IIO trigger device is registered"
	return 1
fi

for tri_name in $iio_trigger_dev
do
	echo "$tri_name" | grep -q "$iio_dev"
	if [ $? -eq 0 ];then
		iio_tri="$iio_tri $tri_name"
	fi
done

first=1
if [ -n "$iio_tri" ];then
	# Format to "a|b|c"
	for tri in $iio_tri
	do
		tri=$(echo $tri | sed -e 's/^[ ,\t]*//g' -e 's/[ ,\t]*$//g')
		if [ $first -eq 1 ];then
			first=0
			iiotri="$tri"
		else
			iiotri="$iiotri|$tri"
		fi
	done
	echo "$iiotri"
else
	test_print_err "Failed to get IIO trigger name for IIO device: $iio_dev"
	return 1
fi
