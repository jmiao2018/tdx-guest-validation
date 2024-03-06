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
#	get_sw_ver.sh
#
# Description:
#	Get SW version of release build
#
# Return:
#	SW build version of release
#-----------------------------------------------------------------------
# Get the build version from the device
buildver=$(run_cmd 1 "getprop ro.build.version.incremental | tr -d '\r' | tail -n 1")
if [ -n "$buildver" ] ; then
    echo $buildver
else
    exit -1
fi
