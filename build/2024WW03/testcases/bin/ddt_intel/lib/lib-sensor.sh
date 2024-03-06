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
#	lib-sensor.sh
#
# Description:
#	A library file for common functions and variables used by sensor driver test.
#
# Functions:
#-----------------------------------------------------------------------
#shopt -s expand_aliases
#-----------------------------------------------------------------------
source "../lib/lib-common.sh"
source "../lib/lib-acpi.sh"
source "../lib/lib-i2c.sh"
source "../lib/lib-iio.sh"

#-----------------------------------------------------------------------
# Global variables
ALS_PREFIX="in_illuminance_"
ALS_GET_ILLUM_POSTFIX="input raw"
ALS_CALIBSCALE_POSTFIX="calibscale"
ALS_IT_POSTFIX="integration_time"
ALS_IT_AVAIL_POSTFIX="integration_time_available"
#-----------------------------------------------------------------------
# Function:
# Input: N/A
# Output: N/A

