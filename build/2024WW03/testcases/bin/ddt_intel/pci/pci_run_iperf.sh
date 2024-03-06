#!/bin/bash

###############################################################################
#
# Copyright (C) 2017 Intel Corporation - http://www.intel.com/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
################################################################################

############################ CONTRIBUTORS #####################################

#
# @Author   Juan Pablo Gomez <juan.p.gomez@intel.com>
#
# 	Nov, 2017
#   	Juan Pablo Gomez (juan.p.gomez@intel.com)
#     	- Script that call iperf tool for PCI Performance Test Cases

############################ DESCRIPTION ######################################

#
# @desc   IPER tool should be installed on the system to work as designed
# @returns
# @history  2017-11-24
#
# If Iperf is not installed download iperf package by: sudo apt-get install iperf
# in the client and server platform
#

############################# FUNCTIONS #######################################

Checking_iperfhost() {
  test_print_trc "Checking if HOST IP is CONDIFURED"
  if [ -z $IPERFHOST ];then
    block_test "Please set the IP address from the Host to run Iperf in params/DEFAULT"
  else
    test_print_trc "IP from Host already set"
  fi
}

Checking_connection() {
  test_print_trc "Checking Connection with Host ${IPERFHOST}"
  do_cmd "ping -c 5 $IPERFHOST"
  if [ $? -eq 0 ];then
    test_print_trc "HOST is responding with this IP:$IPERFHOST"
  else
    test_print_trc "no valid pci device"
    exit 2
  fi
}

iperf_function() {
  test_print_trc "Starting IPERF TEST: ${IPERFHOST}"
  iperf -c ${IPERFHOST} ${*} || die "Iperf is not well configured"
}

############################ DO THE WORK ######################################
source "common.sh"
source "pciport_common.sh"

Checking_iperfhost
#Checking_connection
#iperf_function $*
