#!/bin/bash
#
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
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

# Get I2C Bus Number for different platform. Usually this number
# is the number appeared in /dev/i2c-1 or /dev/i2c/1

# Input:
# Output: i2cbus number

source "common.sh"

############################### CLI Params ###################################
DRMFS_PATH="/sys/class/drm"

############################ DYNAMIC-DEFINED Params ##############################
I2C_NODES=`ls /dev/i2c*` || die "No I2C nodes availble"
I2CBUS_NUM=`echo $I2C_NODES | cut -f1 -d' ' | awk '{print substr ($0, length($0))}'` || die "I2C bus number is not found"

#Function: get i915 monitor port controller i2c bus num
function get_i915_i2c_bus_num()
{
	#get the monitor port controller name
	monitor_dps=`ls $DRMFS_PATH | grep card0- | tr '\n' '\t' | tr -d '\r'`
	for dp in $monitor_dps
	do
		#port is connected
		isconnected=`cat "$DRMFS_PATH/$dp/status"`
		if [ $isconnected == "connected" ];then
			#contain i2c-* node
			if [ -f "$DRMFS_PATH/$dp/i2c-*" ];then
				echo `ls $DRMFS_PATH/$dp/ | grep i2c`
				return
			else
				dp_type=`echo $dp | cut -d'-' -f2`
				dp_order=`echo $dp | awk -F'-' '{print $NF}'`
				case $dp_type in
					DP|eDP)
						[ $dp_order == 1 ]  && \
						i2c_num=`i2cdetect -l | grep DPDDC | awk -F' ' '{print $1}' | head -1` || \
						i2c_num=`i2cdetect -l | grep DPDDC | awk -F' ' '{print $1}' | tail -l`
					;;
					DSI)
						i2c_num=`i2cdetect -l | grep -w i915 | grep -w ssc | awk -F' ' '{print $1}'`
					;;
					HDMI)
						[ $dp_order == 1 ]  && \
						i2c_num=`i2cdetect -l | grep -w i915 | grep -w dpc | awk -F' ' '{print $1}'` || \
						i2c_num=`i2cdetect -l | grep -w i915 | grep -w dpd | awk -F' ' '{print $1}'`
					;;
					VGA)
						i2c_num=`i2cdetect -l | grep -w i915 | grep -w vga | awk -F' ' '{print $1}'`
					;;
				esac
				echo `echo $i2c_num | cut -d'-' -f2`
				return
			fi
		else
			continue
		fi
	done
}

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
  am37x-evm) I2CBUS_NUM=3;;
  am43xx-gpevm) I2CBUS_NUM=1;;
  ecs|ECS) I2CBUS_NUM=2;;
  anchor8|ANCHOR8) I2CBUS_NUM=2;;
  ecs2_8a|ECS2_8A) I2CBUS_NUM=2;;
  ecs2_7b|ECS2_7B) I2CBUS_NUM=2;;
  malata8|MALATA8) I2CBUS_NUM=2;;
  ecs2_10a|ECS2_10A) I2CBUS_NUM=2;;
  edison|joule|gorden_peak) I2CBUS_NUM=2;;
  rvp*|simics) I2CBUS_NUM=2;;
  icl_presi) I2CBUS_NUM=2;;
  *)I2CBUS_NUM=`get_i915_i2c_bus_num`;;
esac

if [ -z "$I2CBUS_NUM" ]; then
    I2CBUS_NUM=2
fi
echo $I2CBUS_NUM
exit 0
