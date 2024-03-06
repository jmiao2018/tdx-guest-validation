#!/bin/bash

###############################################################################
# Copyright (C) 2017, Intel - http://www.intel.com
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

############################ CONTRIBUTORS #####################################

# @Author   Zelin Deng <zelinx.deng@intel.com>
#
# Oct, 2015 Zeling Deng <zelinx.deng@intel.com>
#    - Initial draft.
#
# Aug, 2017. Juan Pablo Gomez <juan.p.gomez@intel.com>
#     - Modified this script to get device node and PCI Device List

############################ DESCRIPTION ######################################

# @desc     This sctip gets PCI Device List
# @returns
# @history  2015-10-19: Initial Draft

############################# FUNCTIONS #######################################
source "common.sh"

PCI_DEV_LIST=""
FILTER_OUT_DEV=""

#$DEV_TYPE to get PCI device name by this pattern
#$OUT_TYPE to dedicate what should be returned by this script
DEV_TYPE=""
: ${OUT_TYPE:="id"}

if [ $# -eq 1 ];then
  DEV_TYPE="$1"
elif [ $# -eq 2 ];then
  DEV_TYPE="$2"
  OUT_TYPE="$1"
fi

#1.our DUTs does not have SMBus driver and device, ignore SMBus.
#2.Only one SATA controller on our DUTs, PCI tests will do bind/unbind remove/rescan
#  operations. If we do this, hard driver error will always occur and we can't
#  access file system any more. So ignore it.
#3.DUTs are connected by ssh. It requires Network. Because of the same operations
#  with SATA controller, network will be lost if we do thos operations. Ignore it
case $MACHINE in
    rvp|t100|nuc5i5ryh)
    FILTER_OUT_DEV="SATA|SMBus|Ethernet|Wireless"
    ;;
  *)
    FILTER_OUT_DEV="SMBus|SATA"
    ;;
esac

#if cmdline has set "nomodeset", kernel won't load i915 driver but load vesa driver
#which will directly access memory of gfx to render. In that case, we should check
#cmdline to check if "nomodeset" has been set. If it has been set, we should filter
#out VGA device too.
NOMODESET=$(cat /proc/cmdline | grep -iow "nomodeset")
if [ -z "${NOMODESET}" ];then
  FILTER_OUT_DEV="$FILTER_OUT_DEV|VGA"
fi

#Make sure ethernet card which directly connected to the PCI slot or indirectly
#connected to the USB controller will be filter out
ifaces=$(mii-tool 2>/dev/null | grep "link ok" | cut -d":" -f1 | tr '\n' '\t')

#Get pci alias of ethernet card, the format is xxxx:xxxx.xx.
#Then we will filter this alias out when we are getting pci devices' names.
for iface in $ifaces
do
  is_pci_eth=$(readlink /sys/class/net/$iface \
    | grep -Eo "pci[0-9a-f]+:[0-9a-f]+/[0-9a-f]+:[0-9a-f]+:[0-9a-f]+\.[0-9a-f]+/"\
    | cut -d'/' -f2\
    | cut -d':' -f2-)
  if [ -z "$is_pci_eth" ];then
    FILTER_OUT_DEV="$FILTER_OUT_DEV|$is_pci_eth"
  fi
done

#like name, id
#if OUT_TYPE is name, return value will be "xx:xx.xx",otherwise "xxxx:xxxx"
case $OUT_TYPE in
  name) PCI_DEV_LIST=$(lspci -nn | grep -w "$DEV_TYPE" | grep -viE "$FILTER_OUT_DEV" \
  | awk -F' ' '{print $1}');;
  id)	PCI_DEV_LIST=$(lspci -nn | grep -w "$DEV_TYPE" | grep -viE "$FILTER_OUT_DEV" \
  | sed 's/\[\|\]\|(rev [0-9a-f]\+)//g' | awk -F' ' '{print $NF}' | sort | uniq);;
  *)	exit 1 ;;
esac

echo $PCI_DEV_LIST
[ -z "$PCI_DEV_LIST" ] && exit 2 || exit 0
