#!/bin/bash
#
################################################################################
##                                                                            ##
## Copyright (c) Intel, 2014                                                  ##
##                                                                            ##
## Author:                                                                    ##
##  Wenzhong Sun <wenzhong.sun@intel.com>                                     ##
##                                                                            ##
## History:                                                                   ##
##  Aug 25, 2014 - (Wenzhong Sun) Created                                     ##
##                                                                            ##
################################################################################
#
# File:
#	get_serial_no.sh
#
# Description:
#	Get DUT's serial number
#
# Return:
#	Serial Number value
#-----------------------------------------------------------------------
# Get the serial no from the device
serialno=$(run_cmd 1 "getprop ro.boot.serialno | tr -d '\r' | tail -n 1")
if [ -n "$serialno" ] ; then
    echo $serialno
else
    exit -1
fi
