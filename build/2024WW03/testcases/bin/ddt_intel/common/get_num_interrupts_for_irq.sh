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
#     -Changed shebang and some cmd's to force the use busybox cmd set.
#     -Added cmd's to properly parse interrupts output (remove whitespaces);
#     -Modify the empty string check ([ -z "$STR" ]).
###############################################################################


# @desc returns numbers of interrupts raised for a given irq on a given cpu
# @params -i irq number or name (as shown in /proc/interrupts)
#         -c cpu number
# @returns
# @history 2013-04-22: First version
# @history 2015-03-19: Ported to work with Android on IA.

source "common.sh"

############################# Functions #######################################
usage() {
  echo "$0 -i <irq number> -c <0-based cpu number>."
}

############################ Script Variables ##################################
# Define default valus if possible
IRQ_NUM=''
CPU_NUM=''

################################ CLI Params ####################################
# Please use getopts
while getopts :i:c:h arg; do
  case $arg in
    i)  IRQ_NUM="$OPTARG";;
    c)  CPU_NUM="$OPTARG";;
    h)  usage && exit 0;;
    :)  die "$0: Must supply an argument to -$OPTARG.";;
    \?) die "$0: Invalid Option -$OPTARG ";;
  esac
done

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
if [[ -z "$IRQ_NUM"  ]]; then
  die "Must supply -i <irq number> argument"
fi

if [[ -z "$CPU_NUM" ]]; then
  die "Must supply -c <cpu number> argument"
fi

interrupts=$(grep "${IRQ_NUM}:" /proc/interrupts \
            | cut -d':' -f 2 \
            | head -1 \
            | sed 's/         //g')
INT_NUM=$(echo "$interrupts" | cut -d' ' -f $((CPU_NUM+1)) )

if [[ -z "$INT_NUM" ]]; then
  die "Could not parse number of interrupts for IRQ $IRQ_NUM and CPU $CPU_NUM"
fi

# Return number of interrupts
echo "$INT_NUM"
