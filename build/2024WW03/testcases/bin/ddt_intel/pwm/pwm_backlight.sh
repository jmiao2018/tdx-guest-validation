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
# @desc     Changes the backlight's brightness in order to test the PWM used to
#           control the light intensity
# @params   b)  backlight to test; defualt intel_backlight
#           p)  brightness percentage to apply, e.g. 50; default rnd
#           i)  number of iteration to perfom the test; default 1
# @returns  0 if the execution was finished succesfully, else 1
# @history 2015-05-25: First version

source "pwm_functions.sh"

############################# Functions #######################################
usage()
{
  echo "usage: ./${0##*/}  [-b BACKLIGHT] [-p PERCENTAGE] [-i ITERATIONS]"
  echo "-b  optional; backlight driver to test; default intel_backlight"
  echo "-p  optional; brightness percentage to apply, e.g. 50; defualt rnd"
  echo "-i  optional; number of iteration to perform the test; default 1"
  echo "-h  Help print this usage"
	exit 1
}

enable_backlight() {
  local path=${BACKLIGHT_PATH}/${BACKLIGHT}
  local rcode=0

  test_print_trc "Backlight to enabled: $path"
  echo  0 > ${path}/bl_power
  rcode=$?
  check "if backlight was enable" test " $rcode -eq 0" || return 1
  return 0
}

update_val() {
  local path=${BACKLIGHT_PATH}/$BACKLIGHT
  local max=$(cat ${path}/max_brightness)

  if [[ $PERCENTAGE =~ ^[rR][nN][dD]$ ]]; then
    test_print_trc "Getting random brightness"
    BRIGHTNESS=$(((RANDOM % $max) + 1))
    test_print_trc "Random brightness: $BRIGHTNESS"
    return 0
  elif [[ $PERCENTAGE =~ ^[0-9]+$ ]]; then
    test_print_trc "Getting brightness value equivalent to $PERCENTAGE %"
    BRIGHTNESS=$((($PERCENTAGE * max) / 100))
    test_print_trc "$PERCENTAGE % brightness: $BRIGHTNESS"
    return 0
  else
    test_print_trc "Invalid percentage, must be a value between 0-100 or rnd"
    return 1
  fi
}

apply_brightness() {
  local path=${BACKLIGHT_PATH}/$BACKLIGHT
  local actual=""

  test_print_trc "Testing: $path"
  test_print_trc "Brightness to apply: $BRIGHTNESS"
  echo $BRIGHTNESS > ${path}/brightness
  actual=$(cat ${path}/brightness)
  test_print_trc "Current brightness: $actual"
  check "if brightness was changed to $BRIGHTNESS" test " $BRIGHTNESS -eq $actual " || return 1
  return 0
}

############################ Script Variables ##################################
BRIGHTNESS=0

################################ CLI Params ####################################
# Please use getopts
while getopts  :b:p:i:h arg
do case $arg in
        b)  BACKLIGHT="$OPTARG";;
        p)  PERCENTAGE="$OPTARG";;
        i)  ITERATIONS="$OPTARG";;
        h)  usage;;
        :)  die "$0: Must supply an argument to -$OPTARG.";;
        \?) die "Invalid Option -$OPTARG ";;
esac
done

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)

# Define default values for variables being overriden
: ${BACKLIGHT:="intel_backlight"}
: ${PERCENTAGE:='rnd'}
: ${ITERATIONS:='1'}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
test_print_trc "==============================================================="
test_print_trc "BACKLIGHT TEST - Backligh: $BACKLIGHT, Iterations: $ITERATIONS"
test_print_trc "==============================================================="
if [ $ENABLED_BLIGHT -eq 1 ]; then
  enable_backlight || die "Error, cannot enabled backlight"
fi
for i in $(seq 1 $ITERATIONS); do
  test_print_trc "======================ITERATION $i==========================="
  update_val || die "Error, cannot get brightness value to apply"
  is_intel_android && do_cmd unlock_device
  sleep 2
  apply_brightness || die "Error, cannot apply brightness"
  is_intel_android && do_cmd lock_device
done

# exit for passing case
exit 0
