#!/bin/bash
###############################################################################
# Copyright (C) 2015, Intel - http://www.intel.com
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

# @Author   Luis Rivas <luis.miguel.rivas.zepeda@intel>
# @desc     Common functions and global variables for pwm scripts
# @returns  0 if the execution was finished succesfully, else 1
# @history 2015-05-25: First version

source "functions.sh"

############################# Functions #######################################
export_pwm() {
  local pwmchip=$1
  local path=${PWM_PATH}/${pwmchip}
  local pwms=$(ls ${PWM_PATH}/${pwmchip}/ | grep -E '^pwm[0-9]+$')

  if [ -z $pwms ]; then
    echo 0 > ${path}/export && return 0 || return 1
  else
    # Already exported
    return 0
  fi
}

unexport_pwm() {
  local pwmchip=$1
  local path=${PWM_PATH}/${pwmchip}
  local pwms=$(ls ${PWM_PATH}/${pwmchip}/ | grep -E '^pwm[0-9]+$')

  if [ -z $pwms ]; then
    # Already unexported
    return 0
  else
    echo 0 > ${path}/unexport && return 0 || return 1
  fi
}

enable_pwm() {
  local pwmchip=$1
  local pwm=$2
  local path=${PWM_PATH}/${pwmchip}/${pwm}

  test -d $path && return 0 || return 1
  echo 1 > ${path}/enable && return 0 || return 1
}

disable_pwm() {
  local pwmchip=$1
  local pwm=$2
  local path=${PWM_PATH}/${pwmchip}/${pwm}

  test -d $path && return 0 || return 1
  echo 0 > ${path}/enable && return 0 || return 1
}

set_duty_cycle() {
  local pwmchip=$1
  local pwm=$2
  local duty=$3
  local path=${PWM_PATH}/${pwmchip}/${pwm}

  test -d $path && return 0 || return 1
  echo $duty > ${path}/duty_cycle && return 0 || return 1
}

set_period() {
  local pwmchip=$1
  local pwm=$2
  local period=$3
  local path=${PWM_PATH}/${pwmchip}/${pwm}

  test -d $path && return 0 || return 1
  echo $period > ${path}/period && return 0 || return 1
}

set_polarity() {
  local pwmchip=$1
  local pwm=$2
  local polarity=$3
  local path=${PWM_PATH}/${pwmchip}/${pwm}

  test -d $path && return 0 || return 1
  echo $polarity > ${path}/polarity && return 0 || return 1
}

unlock_device() {
  # Menu key
  input keyevent 82
}

lock_device() {
  # Lock screen button
  input keyevent 26
}

############################ Script Variables ##################################
PWM_PATH="/sys/class/pwm"

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)
case $SOC in
  sofia*)
    BACKLIGHT_PATH='/sys/devices/virtual/leds'
    ENABLED_BLIGHT=0
    ;;
  iot_edison|iot_joule)
    BACKLIGHT_PATH='/sys/class/backlight'
    ENABLED_BLIGHT=0
    ;;
  *)
    if [[ -d "/sys/class/backlight" ]]; then
      BACKLIGHT_PATH='/sys/class/backlight'
      ENABLED_BLIGHT=1
    else
      die "Error on pwm_functions.sh, $SOC not supported"
    fi
    ;;
esac
