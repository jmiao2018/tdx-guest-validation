#!/bin/bash
#
# Copyright (C) 2014 Intel Corporation - http://www.intel.com/
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

# Load I2C slave devices' driver

# Input: I2C Slave Device Name(s)
# Output:

source "common.sh"
SLAVE_DEVICES=""
############################### CLI Params ###################################
while [ -n "$1" ]; do
  SLAVE_DEVICES="$SLAVE_DEVICES $1"
  shift
done
: ${SLAVE_DEVICES:='default'}


############################ DYNAMIC-DEFINED Params ##############################

############################ USER-DEFINED Params ##############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically
case $ARCH in
esac
case $DRIVER in
esac
case $SOC in
esac
case $MACHINE in
esac

for SLAVE_DEVICE in $SLAVE_DEVICES; do
    MODULE_DIR="/system/lib/modules"
    case $SLAVE_DEVICE in
      accel*|ACCEL*)
        mod_list=$(get_module_config_name.sh Accelerometer $MACHINE)
      ;;
      compass|COMPASS)
        mod_list=$(get_module_config_name.sh Compass $MACHINE)
      ;;
      gyro*|GYRO*)
        mod_list=$(get_module_config_name.sh Gyroscope $MACHINE)
      ;;
      als|ALS)
        mod_list=$(get_module_config_name.sh ALS $MACHINE)
      ;;
      default)
		# Do nothing
      ;;
      *)
        die "Unknown slave device! Can not unload device driver."
      ;;
    esac

    for mod in $mod_list
    do
      insmod "$MODULE_DIR"/"$mod".ko 2> /dev/null
    done
done
exit 0
