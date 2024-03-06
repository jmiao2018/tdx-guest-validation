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
# @desc     Test the sysfs attributes of all the pwmchips under /sys/class/pwm
# @returns  0 if the execution was finished succesfully, else 1
# @history 2015-05-25: First version

source "pwm_functions.sh"

############################# Functions #######################################
check_pwmchip_sysfs() {
  for chip in $(ls $PWM_PATH); do
    test_print_trc "==========================================================="
    test_print_trc "Testing $chip sysfs"
    test_print_trc "==========================================================="
    for attr in $ATTR; do
      check_file $attr  ${PWM_PATH}/${chip} || return 1
    done
  done
  return 0
}

############################ Script Variables ##################################
ATTR="export unexport npwm uevent"

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
check_pwmchip_sysfs || die "Error on pwmchips sysfs"
