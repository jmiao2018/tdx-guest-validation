#!/usr/bin/env bash
###############################################################################
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

# @desc the script contains function to stress different components
# @history 2015-03-03: First version

source "functions.sh"

############################# Functions #######################################
start_stress_brightness() {
  local max=0

  max=$(cat "$BRIGHTNESS_PATH/max_brightness")
  PREV_BRIGHTNESS=$(cat "$BRIGHTNESS_PATH/brightness")
  is_intel_android && unlock_device
  echo "$max" > "$BRIGHTNESS_PATH/brightness"
  if [[ $?  -ne 0 ]]; then
    return 1
  fi
  stress_brightness &
  PID_BRIGHTNESS=$!
  if [[ $PID_BRIGHTNESS -le 0 ]]; then
    echo "$PREV_BRIGHTNESS" > "$BRIGHTNESS_PATH/brightness"
    return 1
  fi
  return 0
}

stop_stress_brightness() {
  echo "$PREV_BRIGHTNESS" > "$BRIGHTNESS_PATH/brightness"
  is_intel_android && lock_device
  if [[ $PID_BRIGHTNESS -gt 0 ]]; then
    disown $PID_BRIGHTNESS
    kill -9 $PID_BRIGHTNESS
    PID_BRIGHTNESS=0
  fi
}

stress_brightness() {
  while true; do
    # Unlocking the device each 5 second to avoid that screen turn off
    is_intel_android && unlock_device
    sleep 5
  done
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
# Define default valus if possible
# We simply assume someone else provides these binaries
PREV_BRIGHTNESS=0
PID_BRIGHTNESS=0

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)
case $SOC in
  baytrail)
    BRIGHTNESS_PATH='/sys/class/backlight/intel_backlight'
    ;;
  sofia*)
    BRIGHTNESS_PATH='/sys/class/leds/lcd-backlight'
    ;;
  *)
    BRIGHTNESS_PATH="/sys/class/backlight/$(ls /sys/class/backlight | head -1)"
    ;;
esac

#if there's no device node under /sys/class/backligh, "ls /sys/class/backlight"
#will return NULL, so BRIGHTNESS_PATH=/sys/class/backlight which means it's failed
#to get backlight device path. exit block
[[ "$BRIGHTNESS_PATH" == "/sys/class/backlight/" ]] && {
  test_print_trc "No backlight device, test blocked"
  exit 2
}
