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
# @desc     Script to test single touch, single drag, multi touch and multi drag
# @params   g)  Gestures to test, e.g., single_touch, single_drag, mt_touch and
#               mt_drag; default single_touch
#           t)  Time between gesture and release; default 0 (immediately release)
#           i)  Number of times to perform touch gesture; default 1
#           r)  Use random numbers for multi touch slots and time between gesture
#               and release; default disabled
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-06-03: First version (Luis Rivas)

source "touch_functions.sh"

############################# Functions #######################################
usage() {
    echo "usage: ./${0##*/}  [-g GESTURES]  [-t TIME] [-i ITERATIONS] [-s]"
    echo "-g  Gestures to test, e.g., single_touch, single_drag, mt_touch"
    echo "    and mt_drag; default single_touch"
    echo "-t  Time between gesture and release; default 0 (immediately release)"
    echo "-i  Number of times to perform touch gesture; default 1"
    echo "-r  Use random numbers for multi touch and time between gesture and"
    echo "    release; default disabled"
    echo "-h  Help print this usage"
    exit 1
}

test_gesture() {
  local gesture=$1
  shift 1
  local release=0
  local time=$(test $RANDOMNESS -eq 1 && echo $((RANDOM % TIME + 1)) || \
              echo $TIME)
  local slots=$(test $RANDOMNESS -eq 1 && \
              echo $((RANDOM % $((TOUCH_SLOTS - 1)) + 2)) || echo $TOUCH_SLOTS)
  local slots_list=$(seq -s ' ' 0 $((slots - 1)))

  #########################  TEST INFO #########################
  test_print_trc "Testing gesture: $gesture"
  test_print_trc "Release timeout: $TIME"
  if [[ $gesture =~ ^mt.*$ ]]; then
    test_print_trc "Number of slots: $slots"
    test_print_trc "Slots: $slots_list"
  fi

  #########################  GESTURES ##########################
  if [ $gesture == "$TOUCH_GESTURE" ]; then
    rnd_single_touch $release || return 1
  elif [ "$gesture" == "$DRAG_GESTURE" ]; then
    rnd_single_touch $release || return 1
    rnd_single_drag $release || return 1
  elif [ "$gesture" == "$MT_TOUCH_GESTURE" ]; then
    rnd_multi_touch $release "$slots_list" || return 1
  elif [ "$gesture" == "$MT_DRAG_GESTURE" ]; then
    rnd_multi_touch $release "$slots_list" || return 1
    rnd_multi_drag $release "$slots_list" || return 1
  else
    test_print_trc "Invalid gesture: $gesture"
    return 1
  fi

  # POLLING-TOUCH EVENT
  wait_single_event $time && return 1

  #####################  RELEASE GESTURES ######################
  if [[ $gesture =~ ^mt.*$ ]]; then
    # Release multi touch receives a list of slots. For example, it can receive
    # a sequence like 2 4 or 0 1 2. The main goal of multi touch release is to
    # release aleatory slots. For this particular case we want to release all
    # the slots pressed
    release_multi_touch "$slots_list" || return 1
  else
    release_single_touch || return 1
  fi
  return 0
}
############################ Script Variables ##################################
TOUCH_GESTURE="single_touch"
DRAG_GESTURE="single_drag"
MT_TOUCH_GESTURE="mt_touch"
MT_DRAG_GESTURE="mt_drag"

################################ CLI Params ####################################
while getopts  g:t:i:rsh arg
do case $arg in
        g)      GESTURES="$OPTARG";;
        t)      TIME="$OPTARG";;
        i)      ITERATIONS="$OPTARG";;
        r)      RANDOMNESS=1;;
        h)      usage;;
        :)      test_print_trc "$0: Must supply an argument to -$OPTARG." >$2
                exit 1
                ;;
        \?)     test_print_trc "Invalid Option -$OPTARG " >$2
                usage
                exit 1
                ;;
esac
done

########################### DYNAMICALLY-DEFINED Params #########################
# Try to use /sys and /proc information to determine values dynamically.
# Alternatively you should check if there is an existing script to get the
# value you want
: ${GESTURES:="single_touch"}
: ${TIME:='0'}
: ${ITERATIONS:='1'}
: ${RANDOMNESS:='0'}

ARR=($GESTURES)

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
for it in $(seq 1 $ITERATIONS); do
  test_print_trc "Clean up touch slots before test"
  touch_cleanup
  sleep 5
  test_print_trc "==================TEST ITERATION $it=================="
  test_gesture ${ARR[$(( $RANDOM % ${#ARR[@]} ))]} || exit 1
done
