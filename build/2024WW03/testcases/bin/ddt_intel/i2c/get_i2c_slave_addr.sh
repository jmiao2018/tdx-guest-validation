#!/usr/bin/env bash
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

# Get I2C slave device address for different platform
# By default, this script return a default addr for each platform so
# the sanity test case can be generic
# If passing in slave_device name, this script will return the addr for
# this slave device.
#
# Input: (optional)slave_device;
# Output: slave_dev_addr

source "common.sh"

############################### CLI Params ###################################
#if [ $# -lt 1 ]; then
#    echo "Error: Invalid Argument Count"
#    echo "Syntax: $0 [slave_device] "
#    exit 1
#fi
if [ "$#" -ge 1 ] && [ -n "$1" ]; then
  SLAVE_DEVICE=$1
fi
: ${SLAVE_DEVICE:='default'}

if [ "$#" -ge 2 ] && [ -n "$2" ]; then
  SLAVE_ADDR=$2
fi
: ${SLAVE_ADDR:='0x50'}

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
  ecs|ECS)
    case $SLAVE_DEVICE in
      accel*|ACCEL*)
        SLAVE_ADDR=0x11
        ;;
      compass|COMPASS)
        SLAVE_ADDR=0x13
        ;;
      gyro*|GYRO*)
        SLAVE_ADDR=0x68
        ;;
      als|ALS)
        SLAVE_ADDR=0x10
        ;;
      default)
        SLAVE_ADDR=0x11
        ;;
      *)
        die "Unknown slave device! Can not get slave address."
      ;;
    esac
    ;;
  anchor8|ANCHOR8)
    case $SLAVE_DEVICE in
      accel*|ACCEL*)
        SLAVE_ADDR=0x10
        ;;
      compass|COMPASS)
        SLAVE_ADDR=0x12
        ;;
      gyro*|GYRO*)
        SLAVE_ADDR=0x68
        ;;
      als|ALS)
        SLAVE_ADDR=0x39
        ;;
      default)
        SLAVE_ADDR=0x10
        ;;
      *)
        die "Unknown slave device! Can not get slave address."
        ;;
    esac
    ;;
  ecs2_8a|ECS2_8A)
    case $SLAVE_DEVICE in
      accel*|ACCEL*)
        SLAVE_ADDR=0x18
        ;;
      default)
        SLAVE_ADDR=0x18
        ;;
      *)
        die "Unknown slave device! Can not get slave address."
        ;;
    esac
    ;;
  ecs2_7b|ECS2_7B)
    case $SLAVE_DEVICE in
      accel*|ACCEL*)
        SLAVE_ADDR=0x18
        ;;
      default)
        SLAVE_ADDR=0x18
        ;;
      *)
        die "Unknown slave device! Can not get slave address."
        ;;
    esac
    ;;
  malata8|MALATA8)
    case $SLAVE_DEVICE in
      accel*|ACCEL*)
        SLAVE_ADDR=0x68
        ;;
      compass|COMPASS)
        SLAVE_ADDR=
        ;;
      gyro*|GYRO*)
        SLAVE_ADDR=0x68
        ;;
      als|ALS)
        SLAVE_ADDR=0x10
        ;;
      default)
        SLAVE_ADDR=0x11
        ;;
      *)
        die "Unknown slave device! Can not get slave address."
      ;;
    esac
    ;;
  ecs2_10a|ECS2_10A)
    case $SLAVE_DEVICE in
      accel*|ACCEL*)
        SLAVE_ADDR=0x18
      ;;
      default)
        SLAVE_ADDR=0x18
      ;;
      *)
        die "Unknown slave device! Can not get slave address."
      ;;
    esac
    ;;
  t100|rvp|nuc5i5ryh|rvp-skly03|rvp-bxt|rvp-kblu|rvp*|simics)
    case $SLAVE_DEVICE in
      i915)
        SLAVE_ADDR=0x50
        ;;
      *)
        die "Unknown slave device! Can not get slave address."
        ;;
    esac
    ;;
  *)
    die "Invalid Machine name! No I2C slave addr found"
    ;;
esac

echo $SLAVE_ADDR
