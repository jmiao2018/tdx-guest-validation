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
# @desc     Test LPPS/pwms by varying parameters such as duty cycle, period and
#           polatiry
# @params   p)  pwmchips to test, e.g. "pwmchip0 pwmchip1"; default all
#           d)  duty cycle to apply to each pwm; default 50
#           o)  polatiry to apply to each pwm; default normal
#           e)  period to apply to each pwm; default 50000
# @returns  0 if the execution was finished succesfully, else 1
# @history 2015-05-25: First version

source "pwm_functions.sh"

############################# Functions #######################################
usage()
{
  echo "usage: ./${0##*/}  [-p PWMCHIPS] [-d DUTY] [-e PERIOD] [-o POLARITY]"
  echo "-p  optional; pwmchipts to test, e.g. "pwmchip0 pwmchip1"; default all"
  echo "-d  optional; duty cycle to apply to each pwm; default 50"
  echo "-o  optional; polarity to apply to each pwm; default normal"
  echo "-e  optional; period to apply to each pwm; default 50000"
  echo "-h  Help print this usage"
	exit 1
}

test_pwmchips() {
  for chip in $PWMCHIPS; do
    test_print_trc "==========================================================="
    test_print_trc "Testing pwmchip: $chip"
    test_print_trc "==========================================================="
    check "Export $chip" export_pwm $chip || return 1
    for pwm in $(ls ${PWM_PATH}/${chip}/ | grep -E '^pwm[0-9]+$'); do
      check "Disable $pwm" disable_pwm $chip $pwm || return 1
      check "Set $pwm duty cycle to $DUTY" set_duty_cycle $chip $pwm $DUTY || return 1
      check "Set $pwm period to $PERIOD" set_period $chip $pwm $PERIOD || return 1
      check "Set $pwm polarity to $POLARITY" set_polarity $chip $pwm $POLARITY || return 1
      check "Enable $pwm" enable_pwm $chip $pwm || return 1
      test_print_trc "Leave $pwm active for 5 seconds"
      sleep 5
      check "Disable $pwm" disable_pwm $chip $pwm || return 1
    done
    check "Unexport $chip" unexport_pwm $chip || return 1
  done
  return 0
}

################################ CLI Params ####################################
# Please use getopts
while getopts  :p:d:e:o:h arg
do case $arg in
        p)      PWMCHIPS="$OPTARG";;
        d)      DUTY="$OPTARG";;
        e)      PERIOD="$OPTARG";;
        o)      POLARITY="$OPTARG";;
        h)      usage;;
        :)      die "$0: Must supply an argument to -$OPTARG.";;
        \?)     die "Invalid Option -$OPTARG ";;
esac
done

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)

# Define default values for variables being overriden
: ${PWMCHIPS:="all"}
: ${DUTY:=0}
: ${PERIOD:=0}
: ${POLARITY:="normal"}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
if [[ "$PWMCHIPS" =~ ^[aA][lL]{2}$ ]]; then
  PWMCHIPS=$(ls $PWM_PATH)
fi

test_pwmchips || die "Error while testing pwmchips"
