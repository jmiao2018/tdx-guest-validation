#!/bin/bash
###############################################################################
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
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
source "eth_common.sh"

############################# Functions #######################################
usage()
{
  echo "do_eth_up_down.sh <direction such as up/down> <interface_name such as eth0, eth1>"
  exit 1
}

################################ CLI Params ####################################
while getopts  ":h:d:i:" arg
do case $arg in
        h)      usage;;
  i)  p_interface=$OPTARG;;
  d)  p_direction=$OPTARG;;
        \?)     die "Invalid Option -$OPTARG ";;
esac
done
: ${p_direction:="up"}

[ "x$p_interface" == "x" ] && usage

if [ $p_direction == "up" ]
then
  ifconfig | grep -w $p_interface
  if [ $? -ne 0 ]; then
    do_cmd "ifconfig $p_interface up"
    udhcpc -i $p_interface || die "Failed to request IP by dhcp for $p_interface"
    if [ $? -ne 0 ]; then
      die "Failed to launch udhcpc"
    fi
  else
    test_print_trc "interface $p_interface is already up, ignore"
  fi
else
  ifconfig $p_interface down || die "Failed to ifconfig $p_interface down"
fi
