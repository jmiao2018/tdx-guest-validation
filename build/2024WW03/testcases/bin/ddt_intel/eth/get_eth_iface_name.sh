#!/bin/bash
#
# Copyright (C) 2015 Intel - http://www.intel.com/
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
# @desc Returns ethernet phy type for certain platforms
#	which require special handling
# @params
# @returns
# @history 2015-11-05: First version

source "eth_common.sh"

usage(){
	cat <<_EOF
		usage: ${0##*/} <-t TYPE> <-h>
		-t TYPE: "one" or "all", to get on iface or all
		-h: show the usage
_EOF
}

while getopts t:h arg
do
	case $arg in
		t)
			TYPE="$OPTARG"
		;;
		h)
			usage
			exit 1
		;;
	esac
done

: ${TYPE:="one"}

#First we should make sure ethernet cards have been sed as up, then we can check
#whether they have connected to cable or not
eths=`ls $NETWORK_SYSFS_PATH | grep -E "$NETWORK_SYSFS_NAME_PATTERNS"`
for eth in $eths
do
	ifconfig $eth up &> /dev/null
done
#We must get the eth cards that have connnected to cable.
#ethtool is a utility for Linux kernel-based operating system for
#displaying and modifying some parameters of network interface
#controllers (NICs) and their device drivers. ethtool is developed
#parallel to the Linux kernel.
#Almost all mainstream linux distributions have ethtool installed by default.
for eth in $eths
do
	if ethtool "$eth" 2> /dev/null | grep -q "Link detected: yes"; then
		ifaces="$ifaces $eth"
	fi
done

#we get the first one
if [ "$TYPE" == "one" ];then
	ifaces=`echo $ifaces | awk '{print $1}'`
fi

echo $ifaces
[ "x$ifaces" == "x" ] && exit 1 || exit 0
