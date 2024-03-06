#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2013 Texas Instruments Incorporated - http://www.ti.com/
# Copyright (C) 2017 Intel - http://www.intel.com/
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
# Contributors:
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#   -Changed shebang and some cmd's to force the use busybox cmd set.
#   -Added a cmd to  remove whitespaces when gettign IRQ num.
#   -Replaced die with block_test when not possible to find IRQ.
###############################################################################

# @desc Provides irq number associated with an interface
# @params i) interface
# @returns IRQ number
# @history 2013-04-22: First version
# @history 2015-03-19: Ported to work with Android on IA.

source "common.sh"

############################# Functions #######################################
usage() {
  echo "$0 -i <interface>. Where interface=eth0, mmc0, etc."
}

find_irq() {
  NAME=$(grep "$NAME" /proc/interrupts \
        | head -1 \
        | cut -d':' -f 1 \
        | sed 's/ //g')
}
############################ Script Variables ##################################
# Define default valus if possible

NAME=""

################################ CLI Params ####################################
# Please use getopts
while getopts :i:h arg; do
  case $arg in
   i)  INTERFACE="$OPTARG";;
   h)  usage && exit 0;;
   n)  NAME="$OPTARG";;
   :)  die "$0: Must supply an argument to -$OPTARG";;
   \?) die "$0: Invalid option -$OPTARG";;
  esac
done

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)

# Define default values for variables being overriden
IRQ=""

if [[ -z "$NAME" ]]; then
  NAME="$INTERFACE"
fi

# Map Interface name to name or irq in /proc/interrupts
case $INTERFACE in
  eth*)
    case $MACHINE in
      am335x-evm)
        NAME='93';;
      beaglebone)
        NAME='57';;
      omap5-evm)
        NAME='109';;
      dra7xx-evm)
        NAME='83';;
      keystone-evm)
        NAME='80';;
    esac
    ;;
esac

########################### DYNAMICALLY-DEFINED Params #########################
# Try to use /sys and /proc information to determine values dynamically.
# Alternatively you should check if there is an existing script to get the
# value you want
echo $NAME | grep -E '^[[:digit:]]+' > /dev/null || find_irq

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
echo $NAME | grep -E '^[[:digit:]]+' > /dev/null \
  || block_test "Could not find irq number for $NAME"
N=$(echo $NAME | cut -d' ' -f 1)
echo "$N"
