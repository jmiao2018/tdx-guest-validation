#!/usr/bin/env bash
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

# @desc Run IPERF http://sourceforge.net/projects/iperf/

source "eth_common.sh"  # Import do_cmd(), die() and other functions

############################# Functions #######################################
usage() {
  cat<<__EOF
  run_iperf.sh -H <host> [other iperf options (see iperf help)
    -H <host>: IP address of Host running iperf in server mode
    all other args are passed as-is to iperf
  iperf help:
    $(iperf -h)
__EOF
}

################################ CLI Params ####################################
# Please use getopts
#-H for host pc running iperf server
while getopts :H:h arg; do
  case $arg in
    H)  IPERFHOST="$OPTARG"; shift 2 ;;
    h)  usage && exit 0;;
    :)  test_print_err "Must supply an argument to -$OPTARG."
        usage
        exit 1
        ;;
    \?) test_print_err "Invalid Option -$OPTARG."
        usage
        exit 1
        ;;
  esac
done

########################### DYNAMICALLY-DEFINED Params #########################
# Try to use /sys and /proc information to determine values dynamically.
# Alternatively you should check if there is an existing script to get the
# value you want

#: ${IPERFHOST:=$(cat /proc/cmdline \
#                | awk '{for (i=1; i<=NF; i++) { print $i} }' \
#                | grep 'nfsroot=' \
#                | awk -F '[=:]' '{print $2}')}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
#if IPERFHOST hasn't been passed in, use $NFS_SERVER as the iperf server
[[ -n "$IPERFHOST" ]] || IPERFHOST="$NFS_SERVER"
[[ -n "$IPERFHOST" ]] || die "IPERF server IP address could not be determined \
dynamically. Please specify it when calling the script. \
(i.e. run_iperf.sh -H <host>)"

#IPERFCMD=$(echo $* | sed -r s/-H[[:space:]]+[0-9\.]+/-c $IPERFHOST/)

test_print_trc "Starting IPERF TEST"

do_cmd "iperf -c ${IPERFHOST} $*"
