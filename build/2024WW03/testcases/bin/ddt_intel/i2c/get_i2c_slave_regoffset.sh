#!/bin/bash
#
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
#

# Get I2C slave device register offset for different platform
# By default, this script return a default offset to testing
# If passing in slave_device name, this script will return the default
# offset for this slave device
# Input: (optional)slave_device;
# Output: slave_dev_regoffset

source "common.sh"

############################### CLI Params ###################################
#if [ $# -lt 1 ]; then
#        echo "Error: Invalid Argument Count"
#        echo "Syntax: $0 [slave_device] "
#        exit 1
#fi
if [ "$#" -ge 1 -a -n "$1" ]; then
	SLAVE_DEVICE=$1
fi

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
        am17x-evm)

                case $SLAVE_DEVICE in
                        *)
                                SLAVE_REGOFFSET=0x02
                        ;;
                esac
                ;;
		ecs|ECS)
				case $SLAVE_DEVICE in
						accel*|ACCEL*)
								SLAVE_REGOFFSET=0x11
						;;
						compass|COMPASS)
								SLAVE_REGOFFSET=0x4b
						;;
						gyro*|GYRO*)
								SLAVE_REGOFFSET=0x11
						;;
						als|ALS)
								SLAVE_REGOFFSET=0x02
						;;
						*)
								SLAVE_REGOFFSET=0x11
						;;
				esac
				;;
		anchor8|ANCHOR8)
				case $SLAVE_DEVICE in
						accel*|ACCEL*)
								SLAVE_REGOFFSET=0x11
						;;
						compass|COMPASS)
								SLAVE_REGOFFSET=0x4b
						;;
						gyro*|GYRO*)
								SLAVE_REGOFFSET=0x11
						;;
						als|ALS)
								SLAVE_REGOFFSET=""
						;;
						*)
								SLAVE_REGOFFSET=0x11
						;;
				esac
				;;
		ecs2_8a|ECS2_8A)
				case $SLAVE_DEVICE in
						accel*|ACCEL*)
								SLAVE_REGOFFSET=0x11
						;;
						*)
								SLAVE_REGOFFSET=0x11
						;;
				esac
				;;
		ecs2_7b|ECS2_7B)
				case $SLAVE_DEVICE in
						accel*|ACCEL*)
								SLAVE_REGOFFSET=0x11
						;;
						*)
								SLAVE_REGOFFSET=0x11
						;;
				esac
				;;
		malata8|MALATA8)
				case $SLAVE_DEVICE in
						accel*|ACCEL*)
								SLAVE_REGOFFSET=0x6b
						;;
						compass|COMPASS)
								SLAVE_REGOFFSET=
						;;
						gyro*|GYRO*)
								SLAVE_REGOFFSET=0x6b
						;;
						als|ALS)
								SLAVE_REGOFFSET=0x02
						;;
						*)
								SLAVE_REGOFFSET=0x11
						;;
				esac
				;;
		ecs2_10a|ECS2_10A)
				case $SLAVE_DEVICE in
						accel*|ACCEL*)
								SLAVE_REGOFFSET=0x11
						;;
						*)
								SLAVE_REGOFFSET=0x11
						;;
				esac
				;;
		t100|rvp|rvp-skly03|rvp-kbly|rvp-kblu|rvp-kblr|rvp-skls06|rvp-bxt)
				#monitor reg valid data is located at 0x08-0x7f
				case $SLAVE_DEVICE in
					monitor)
								SLAVE_REGOFFSET="0x08-0x7f"
					;;
					*)
								SLAVE_REGOFFSET="0x08-0x7f"
					;;
				esac
		;;
esac

: ${SLAVE_REGOFFSET:=0x2}
echo $SLAVE_REGOFFSET
