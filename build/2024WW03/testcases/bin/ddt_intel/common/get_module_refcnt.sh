#!/usr/bin/env bash
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
#

# Get kernel module's reference count

# Input: Kernel Module Name
# Output:

source "common.sh"

KERNEL_MODULES=""
############################### CLI Params ###################################
while [[ -n "$1" ]]; do
  KERNEL_MODULES="$KERNEL_MODULES $1"
  shift
done
: "${KERNEL_MODULES:='default'}"

############################ DYNAMIC-DEFINED Params ##############################
MOD_NAME=""
MOD_REFCNT=""

############################ USER-DEFINED Params ##############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically
for KERNEL_MODULE in $KERNEL_MODULES; do
  case $MACHINE in
    ecs|ECS)
      case $KERNEL_MODULE in
        [Aa]ccel*|ACCEL*)
          MOD_NAME="bmc150_accel";;
        [Cc]ompass|COMPASS)
          MOD_NAME="bmc150_magn";;
        [Gg]yro*|GYRO*)
          MOD_NAME="bmg160";;
        [Aa]ls|ALS)
          MOD_NAME="cm32181";;
        default)
          # Do nothing
          ;;
        *)
          die "Unknown kernel module! Can not get module's refcnt.";;
      esac
      ;;
    anchor8|ANCHOR8)
      case $KERNEL_MODULE in
        [Aa]ccel*|ACCEL*)
          MOD_NAME="bmc150_accel";;
        [Cc]ompass|COMPASS)
          MOD_NAME="bmc150_magn";;
        [Gg]yro*|GYRO*)
          MOD_NAME="bmg160";;
        [Aa]ls|ALS)
          MOD_NAME="jsa1127";;
        default)
          # Do nothing
          ;;
        *)
          die "Unknown kernel module! Can not get module's refcnt.";;
      esac
      ;;
    ecs2_8a|ECS2_8A)
      case $KERNEL_MODULE in
        [Aa]ccel*|ACCEL*)
          MOD_NAME="bmc150_accel";;
        default)
          # Do nothing
          ;;
        *)
          die "Unknown kernel module! Can not get module's refcnt.";;
      esac
      ;;
    ecs2_7b|ECS2_7B)
      case $KERNEL_MODULE in
        [Aa]ccel*|ACCEL*)
          MOD_NAME="bmc150_accel";;
        default)
          # Do nothing
          ;;
        *)
          die "Unknown kernel module! Can not get module's refcnt.";;
      esac
      ;;
    malata8|MALATA8)
      case $KERNEL_MODULE in
        [Aa]ccel*|ACCEL*)
          MOD_NAME="inv_mpu6050";;
        [Cc]ompass|COMPASS)
          MOD_NAME="ak8975";;
        [Gg]yro*|GYRO*)
          MOD_NAME="inv_mpu6050";;
        [Aa]ls|ALS)
          MOD_NAME="cm3232";;
        default)
          # Do nothing
          ;;
        *)
          die "Unknown kernel module! Can not get module's refcnt.";;
      esac
      ;;
    malata8_low|MALATA8_LOW)
      case $KERNEL_MODULE in
        [Aa]ccel*|ACCEL*)
          MOD_NAME="kxcjk_1013";;
        default)
          # Do nothing
          ;;
        *)
          die "Unknown kernel module! Can not get module's refcnt.";;
      esac
      ;;
    ecs2_10a|ECS2_10A)
      case $KERNEL_MODULE in
        [Aa]ccel*|ACCEL*)
          MOD_NAME="bmc150_accel";;
        default)
          # Do nothing
          ;;
        *)
          die "Unknown kernel module! Can not get module's refcnt.";;
      esac
      ;;
    mrd6s|MRD6S)
      case $KERNEL_MODULE in
        [Aa]ccel*|ACCEL*)
          MOD_NAME="kxcjk_1013";;
        default)
          # Do nothing
          ;;
        *)
          die "Unknown kernel module! Can not get module's refcnt.";;
      esac
      ;;
    mrd6sl_a|MRD6SL_A)
      case $KERNEL_MODULE in
        [Aa]ccel*|ACCEL*)
          MOD_NAME="kxcjk_1013";;
        default)
          # Do nothing
          ;;
        *)
          die "Unknown kernel module! Can not get module's refcnt.";;
      esac
      ;;
    mrd6sl_b|MRD6SL_B)
      case $KERNEL_MODULE in
        [Aa]ccel*|ACCEL*)
          MOD_NAME="kxcjk_1013";;
        default)
          # Do nothing
          ;;
        *)
          die "Unknown kernel module! Can not get module's refcnt.";;
      esac
      ;;
    *)
      die "Unknown MACHINE name.";;
  esac
done

[[ -z "$MOD_NAME" ]] \
  || MOD_REFCNT=$(cat /sys/module/$MOD_NAME/refcnt | tr -d '\r')
if [[ -z "$MOD_REFCNT" ]]; then
  die "Failed to get $KERNEL_MODULE refcnt"
else
  echo "$MOD_REFCNT"
fi
