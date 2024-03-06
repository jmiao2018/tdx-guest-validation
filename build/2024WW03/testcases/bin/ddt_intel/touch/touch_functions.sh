#!/bin/bash
#copyright 2015 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate Touch component
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Jose Perez Carranza <jose.perez.carranza@intel.com>
#             Luis Rivas <luis.miguel.rivas.zepeda@intel.com>
#
# History:
#             May. 25, 2015 - (jose.perez.carranza) Creation
#             June. 3, 2015 - (luis.miguel.rivas.zepeda) Updated functions
#
# @desc     Common fucntion and global variables for script testcases
# @returns  Fail the test if return code is non-zero (value set not found)

source "common.sh"

############################# Functions #######################################
print_touch_properties(){
  test_print_trc "******************** TOUCH PROPERTIES ********************"
  test_print_trc " TOUCH        : $TOUCH_NAME"
  test_print_trc " I2C_PATH     : $I2C_PATH"
  test_print_trc " PHYS         : $TOUCH_PHYS"
  test_print_trc " SYSFS        : $TOUCH_SYSFS"
  test_print_trc " INPUT        : $TOUCH_INPUT"
  test_print_trc " MIN_X        : $TOUCH_MIN_X"
  test_print_trc " MAX_X        : $TOUCH_MAX_X"
  test_print_trc " MIN_Y        : $TOUCH_MIN_Y"
  test_print_trc " MAX_Y        : $TOUCH_MAX_Y"
  test_print_trc " SLOTS        : $TOUCH_SLOTS"
  test_print_trc "***************** END OF TOUCH PROPERTIES ****************"
}

start_getevent() {
  local ev_count=$1

  rm $GETEVENT_LOG &> /dev/null #  Remove getevent log before recording

  # Getevent has a different behavior depending on arguments and redirection
  # If getevent output is  sent to a terminal, it will be line buffered
  # Otherwise, it will be buffered in a big chunck of data
  # In order to avoid redirection problems, we will use -c argument to specify
  # how many events to record. The main advantge with -c argument is that allows
  # to redirect the output as line-buffered
  getevent -c $ev_count $INPUTS_PATH$TOUCH_INPUT > $GETEVENT_LOG &
  GETEVENT_PID=$!
  if [ $GETEVENT_PID -gt 0 ]; then
    test_print_trc "Getevent started: $GETEVENT_PID"
    return 0
  else
    test_print_trc "Getevent not started"
    return 1
  fi
}

stop_getevent() {
  if [ $GETEVENT_PID -gt 0 ]; then
    kill -SIGKILL $GETEVENT_PID &> /dev/null  # Kill getevent and redirect ouput
    wait $GETEVENT_PID &> /dev/null # Avoid kill messages
    GETEVENT_PID=0
  fi
  test_print_trc "Getevent killed"
  return 0
}

wait_single_event() {
  local timeout=$1
  local count=0
  local result=0

  test_print_trc "Polling - Touch event for $timeout seconds"
  start_getevent 1 || return 1
  until [ -s $GETEVENT_LOG ]; do
    if [ $timeout -eq $count ]; then
      test_print_trc "Event not received"
      result=1  # Did not receive event
      break;
    fi
    sleep 1
    count=$((count + 1))
    test_print_trc "Elapsed time: $count seconds"
  done
  stop_getevent || return 1
  test $result -eq 0 && return 0 || return 1
}

random_X(){
  local x=$RANDOM
  let "x %= $TOUCH_MAX_X"
  echo $x
}

random_Y(){
  local y=$RANDOM
  let "y %= $TOUCH_MAX_Y"
  echo $y
}

random_tracking_id(){
  local id=$RANDOM
  let "id %= $TOUCH_MAX_TRACKING_ID"
  echo $id
}

dec_to_hex() {
  local decimal=$1
  local padding=$2
  if [ $decimal -ge 0 ]; then
    echo $(printf '%0'$padding'x' $decimal)
  else
    echo "ffffffff"
  fi
}

getevent_fmt() {
  local event=$1
  local event_type=$2
  local val=$3

  echo "$(dec_to_hex $event 4) $(dec_to_hex $event_type 4) $(dec_to_hex $val 8)"
}

verify_touch_events() {
  local exp=$(echo $1| sed 's/^\s*//' | sed 's/\s*$//')
  local curr=$(cat $GETEVENT_LOG | tr '\n' ' ' | sed 's/^\s*//' | sed 's/\s*$//')

  if [ $(echo $exp | wc -w) -ne $(echo $curr |wc -w) ]; then
    test_print_trc "Number of current events is not the expected"
    test_print_trc "Expected touch events: $exp"
    test_print_trc "Current touch events: $curr"
    return 1
  elif [ "$exp" != "$curr" ]; then
    test_print_trc "Expected events are not equal to current events"
    test_print_trc "Expected touch events: $exp"
    test_print_trc "Current touch events: $curr"
    return 1
  else
    return 0
  fi
}

rnd_single_touch(){
  local release=$1
  shift 1
  local position_x=$(random_X)
  local position_y=$(random_Y)
  local tracking_id=$(random_tracking_id)
  local events=""

  : ${release:=1} # Default is release touch

  # TOUCH LOG INFO
  test_print_trc "**********************  SINGLE TOUCH **********************"

  ################# START COLLECTING GETEVENT INFO ############
  start_getevent 5 || return 1

  ################## EVENTS ####################
  # ABS_MT_TRACKING_ID
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_TRACKING_ID $tracking_id
  test_print_trc "EV_ABS ABS_MT_TRACKING_ID $tracking_id"
  events="$events $(getevent_fmt $EV_ABS $ABS_MT_TRACKING_ID $tracking_id)"

  # ABS_MT_POSITION_X
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_POSITION_X $position_x
  test_print_trc "EV_ABS ABS_MT_POSITION_X $position_x"
  events="$events $(getevent_fmt $EV_ABS $ABS_MT_POSITION_X $position_x)"

  # ABS_MT_POSITION_Y
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_POSITION_Y $position_y
  test_print_trc "EV_ABS ABS_MT_POSITION_Y $position_y"
  events="$events $(getevent_fmt $EV_ABS $ABS_MT_POSITION_Y $position_y)"

  # BTN_TOUCH DOWN
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_KEY $BTN_TOUCH $BTN_TOUCH_DOWN
  test_print_trc "EV_KEY BTN_TOUCH_DOWN $BTN_TOUCH_DOWN"
  events="$events $(getevent_fmt $EV_KEY $BTN_TOUCH $BTN_TOUCH_DOWN)"

  # SYN_REPORT
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_SYN $SYN_REPORT 0
  test_print_trc "EV_SYN SYN_REPORT 0"
  events="$events $(getevent_fmt $EV_SYN $SYN_REPORT 0)"

  ############## VERIFICATION ##################
  stop_getevent || return 1 # Stop collecting getevent information
  verify_touch_events "$events" || return 1 # Check if events were sent

  # TOUCH LOG INFO
  test_print_trc "******************* END OF SINGLE TOUCH ******************"

  ############## RELEASE ##################
  if [ $release -eq 1 ]; then
    release_single_touch || return 1
  fi

  return 0
}

rnd_single_drag(){
  local release=$1
  shift 1
  local position_x=$(random_X)
  local position_y=$(random_Y)
  local events=""

  : ${release:=1} # Default is release touch

  # TOUCH LOG INFO
  test_print_trc "**********************  SINGLE DRAG ***********************"

  ################# START COLLECTING GETEVENT INFO ############
  start_getevent 3 || return 1

  ################## EVENTS ####################
  # ABS_MT_POSITION_X1
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_POSITION_X $position_x
  test_print_trc "EV_ABS ABS_MT_POSITION_X $position_x"
  events="$events $(getevent_fmt $EV_ABS $ABS_MT_POSITION_X $position_x)"

  # ABS_MT_POSITION_Y1
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_POSITION_Y $position_y
  test_print_trc "EV_ABS ABS_MT_POSITION_Y $position_y"
  events="$events $(getevent_fmt $EV_ABS $ABS_MT_POSITION_Y $position_y)"

  # SYN_REPORT
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_SYN $SYN_REPORT 0
  test_print_trc "EV_SYN SYN_REPORT 0"
  events="$events $(getevent_fmt $EV_SYN $SYN_REPORT 0)"

  ############## VERIFICATION ##################
  stop_getevent || return 1 # Stop collecting getevent information
  verify_touch_events "$events" || return 1 # Check if events were sent

  # TOUCH LOG INFO
  test_print_trc "******************* END OF SINGLE DRAG *******************"

  ############## RELEASE ##################
  if [ $release -eq 1 ]; then
    release_single_touch || return 1
  fi

  return 0
}

release_single_touch(){
  local events=""

  # TOUCH LOG INFO
  test_print_trc "****************** RELEASE SINGLE TOUCH ******************"

  ################# START COLLECTING GETEVENT INFO ############
  start_getevent 3 || return 1

  ################## EVENTS ####################
  # ABS_MT_TRACKING_ID
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_TRACKING_ID -1
  test_print_trc "EV_ABS ABS_MT_TRACKING_ID -1"
  events="$events $(getevent_fmt $EV_ABS $ABS_MT_TRACKING_ID -1)"

  # BTN_TOUCH UP
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_KEY $BTN_TOUCH $BTN_TOUCH_UP
  test_print_trc "EV_KEY BTN_TOUCH_UP $BTN_TOUCH_UP"
  events="$events $(getevent_fmt $EV_KEY $BTN_TOUCH $BTN_TOUCH_UP)"

  # SYN_REPORT
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_SYN $SYN_REPORT 0
  test_print_trc "EV_SYN SYN_REPORT 0"
  events="$events $(getevent_fmt $EV_SYN $SYN_REPORT 0)"

  ############## VERIFICATION ##################
  stop_getevent || return 1 # Stop collecting getevent information
  verify_touch_events "$events" || return 1 # Check if events were sent

  # TOUCH LOG INFO
  test_print_trc "*************** END OF RELEASE SINGLE TOUCH **************"

  return 0
}

rnd_multi_touch(){
  local release=$1
  local slots=$2
  shift 2
  local total_slots=$(echo $slots | wc -w)
  local tracking_id=$(random_tracking_id)
  local position_x=$(random_X)
  local position_y=$(random_Y)
  local events=""

  : ${release:='1'} # Default is release touch
  : ${slots:="0 1"} # Default is two slots

  ################## VALIDATE INPUT ####################
  if [ -z "$slots" ]; then
    test_print_trc "MULTI-TOUCH: Empty slote list, nothing to do!"
    return 0
  fi

  # MULTI TOUCH LOG INFO
  test_print_trc "*********************** MULTI TOUCH **********************"

  ################# START COLLECTING GETEVENT INFO ############
  # Start collecting getevent information
  # The number of events to collect are equal to 2 (ButtonDown, Sync) plus
  # touches * 4 (Events require to update slot info)
  start_getevent  $((2 + $total_slots * 4)) || return 1

  ################## EVENTS ####################
  # Sent touch info for each slot
  for slot in $slots; do
    # ABS MT SLOT
    sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_SLOT $slot
    test_print_trc "EV_ABS ABS_MT_SLOT $slot"
    events="$events $(getevent_fmt $EV_ABS $ABS_MT_SLOT $slot)"

    # ABS_MT_TRACKING_ID
    sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_TRACKING_ID $tracking_id
    test_print_trc "EV_ABS ABS_MT_TRACKING_ID $tracking_id"
    events="$events $(getevent_fmt $EV_ABS $ABS_MT_TRACKING_ID $tracking_id)"

    # ABS_MT_POSITION_X
    sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_POSITION_X $position_x
    test_print_trc "EV_ABS ABS_MT_POSITION_X $position_x"
    events="$events $(getevent_fmt $EV_ABS $ABS_MT_POSITION_X $position_x)"

    # ABS_MT_POSITION_Y
    sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_POSITION_Y $position_y
    test_print_trc "EV_ABS ABS_MT_POSITION_Y $position_y"
    events="$events $(getevent_fmt $EV_ABS $ABS_MT_POSITION_Y $position_y)"

    tracking_id=$((tracking_id + 1))  # Get new tracking id
    position_y=$(random_Y)            # Update y position
    position_x=$(random_X)            # Update x positin
  done

  # BTN_TOUCH DOWN
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_KEY $BTN_TOUCH $BTN_TOUCH_DOWN
  test_print_trc "EV_KEY BTN_TOUCH BTN_TOUCH_DOWN"
  events="$events $(getevent_fmt $EV_KEY $BTN_TOUCH $BTN_TOUCH_DOWN)"

  # SYN_REPORT
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_SYN $SYN_REPORT 0
  test_print_trc "EV_SYN SYN_REPORT 0"
  events="$events $(getevent_fmt $EV_SYN $SYN_REPORT 0)"

  ############## VERIFICATION ##################
  stop_getevent || return 1 # Stop collecting getevent information
  verify_touch_events "$events" || return 1 # Check if events were sent

  # MULTI TOUCH LOG INFO
  test_print_trc "******************* END OF MULTI TOUCH *******************"

  ############## RELEASE ##################
  if [ $release -eq 1 ]; then
    release_multi_touch "$slots" || return 1
  fi

  return 0
}

rnd_multi_drag(){
  local release=$1
  local slots=$2
  shift 2
  local total_slots=$(echo $slots | wc -w)
  local tracking_id=$(random_tracking_id)
  local position_x=$(random_X)
  local position_y=$(random_Y)
  local events=""

  : ${release:='1'} # Default is release drag
  : ${slots:="0 1"} # Default is two slots

  ################## VALIDATE INPUT ####################
  if [ -z "$slots" ]; then
    test_print_trc "MULTI-DRAG: Empty slote list, nothing to do!"
    return 0
  fi

  # MULTI TOUCH LOG INFO
  test_print_trc "*********************** MULTI DRAG ***********************"

  ################# START COLLECTING GETEVENT INFO ############
  # Start collecting getevent information
  # The number of events to collect are equal to touches * 4 (Events required to
  # update slot info
  start_getevent  $((total_slots * 4)) || return 1

  ################## EVENTS ####################
  # Sent touch info for each slot
  for slot in $slots; do
    # ABS MT SLOT
    sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_SLOT $slot
    test_print_trc "EV_ABS ABS_MT_SLOT $slot"
    events="$events $(getevent_fmt $EV_ABS $ABS_MT_SLOT $slot)"

    # ABS_MT_POSITION_X
    sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_POSITION_X $position_x
    test_print_trc "EV_ABS ABS_MT_POSITION_X $position_x"
    events="$events $(getevent_fmt $EV_ABS $ABS_MT_POSITION_X $position_x)"

    # ABS_MT_POSITION_Y
    sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_POSITION_Y $position_y
    test_print_trc "EV_ABS ABS_MT_POSITION_Y $position_y"
    events="$events $(getevent_fmt $EV_ABS $ABS_MT_POSITION_Y $position_y)"

    # SYN_REPORT
    sendevent $INPUTS_PATH$TOUCH_INPUT $EV_SYN $SYN_REPORT 0
    test_print_trc "EV_SYN SYN_REPORT 0"
    events="$events $(getevent_fmt $EV_SYN $SYN_REPORT 0)"

    tracking_id=$((tracking_id + 1))  # Get new tracking id
    position_y=$(random_Y)            # Update y position
    position_x=$(random_X)            # Update x positin
  done

  ############## VERIFICATION ##################
  stop_getevent || return 1 # Stop collecting getevent information
  verify_touch_events "$events" || return 1 # Check if events were sent

  # MULTI TOUCH LOG INFO
  test_print_trc "******************* END OF MULTI DRAG ********************"

  ############## RELEASE ##################
  if [ $release -eq 1 ]; then
    release_multi_touch "$slots" || return 1
  fi

  return 0
}

release_multi_touch(){
  local slots=$1
  shift 1
  local total_slots=$(echo $slots | wc -w)
  local events=""
  local count=1

  ################## VALIDATE INPUT ####################
  if [ -z "$slots" ]; then
    test_print_trc "MULTI-TOUCH-RELEASE: Empty slote list, nothing to do!"
    return 0
  fi

  # MULTI TOUCH LOG INFO
  test_print_trc "******************* RELEASE MULTI TOUCH ******************"

  ################# START COLLECTING GETEVENT INFO ############
  # Start collecting getevent information
  # The number of events to collect are equal to 1 (ButtonUp) plus
  # number of slots * 3 (MT_SLOT, MT_TRACKING_ID, SYNC_REPORT)
  start_getevent  $((1 + total_slots * 3)) || return 1

  ################## EVENTS ####################
  for slot in $slots; do
    # ABS MT SLOT
    sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_SLOT $slot
    test_print_trc "EV_ABS ABS_MT_SLOT $slot"
    events="$events $(getevent_fmt $EV_ABS $ABS_MT_SLOT $slot)"

    # ABS_MT_TRACKING_ID
    sendevent $INPUTS_PATH$TOUCH_INPUT $EV_ABS $ABS_MT_TRACKING_ID -1
    test_print_trc "EV_ABS ABS_MT_TRACKING_ID -1"
    events="$events $(getevent_fmt $EV_ABS $ABS_MT_TRACKING_ID -1)"

    if [ $count -lt $total_slots ]; then
      # SYN_REPORT
      sendevent $INPUTS_PATH$TOUCH_INPUT $EV_SYN $SYN_REPORT 0
      test_print_trc "EV_SYN SYN_REPORT 0"
      events="$events $(getevent_fmt $EV_SYN $SYN_REPORT 0)"
    fi

    count=$((count + 1))
  done

  # BTN_TOUCH UP
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_KEY $BTN_TOUCH $BTN_TOUCH_UP
  test_print_trc "EV_KEY BTN_TOUCH BTN_TOUCH_UP"
  events="$events $(getevent_fmt $EV_KEY $BTN_TOUCH $BTN_TOUCH_UP)"

  # SYN_REPORT
  sendevent $INPUTS_PATH$TOUCH_INPUT $EV_SYN $SYN_REPORT 0
  test_print_trc "EV_SYN SYN_REPORT 0"
  events="$events $(getevent_fmt $EV_SYN $SYN_REPORT 0)"

  ############## VERIFICATION ##################
  stop_getevent || return 1 # Stop collecting getevent information
  verify_touch_events "$events" || return 1 # Check if events were sent

  # MULTI TOUCH LOG INFO
  test_print_trc "*************** END OF RELEASE MULTI TOUCH ***************"

  return 0
}

touch_cleanup() {
  test_print_trc "********************* TOUCH CLEAN-UP *********************"

  test_print_trc "Clean up - Multi touch slots"
  (release_multi_touch "$(seq -s  0 $((TOUCH_SLOTS - 1)))")&> /dev/null

  test_print_trc "Clean up - Stop getevent"
  stop_getevent

  test_print_trc "********************* END TOUCH CLEAN-UP *********************"
  return 0
}

############################ Script Variables ##################################
# Paths
readonly INPUTS_PATH="/dev/input/"
readonly IDC_PATH="/system/usr/idc/"

# Event Type
readonly EV_SYN=0
readonly EV_KEY=1
readonly EV_ABS=3

# Event Code
readonly ABS_MT_TRACKING_ID=57
readonly ABS_MT_POSITION_X=53
readonly ABS_MT_POSITION_Y=54
readonly ABS_MT_TOUCH_MAJOR=48
readonly ABS_MT_WIDTH_MAJOR=50
readonly ABS_MT_PRESSURE=58
readonly ABS_MT_SLOT=47
readonly BTN_TOUCH=330
readonly SYN_REPORT=0

# Default values
readonly BTN_TOUCH_UP=0
readonly BTN_TOUCH_DOWN=1
readonly GETEVENT_LOG=/data/tmp/getevent.log

# Variables to stored PIDs
GETEVENT_PID=0

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)
# Assign corresponding driver name by platform
case $MACHINE in
  ecs)     TOUCH_DRIVER="ft5x0x";;
  ecs2_10a | ecs2_7b | ecs2_8a | malata8 | mrd6s) TOUCH_DRIVER="goodix_ts";;
  :)  die "Unknown platform $MACHINE";;
  \?) die "Unknown platform $MACHINE ";;
esac

########################### DYNAMICALLY-DEFINED Params #########################
# Try to use /sys and /proc information to determine values dynamically.
# Alternatively you should check if there is an existing script to get the
# value you want

#Search if there is a property for multi-touch and get assigned name
TOUCH_NAME=`do_cmd getevent -pl | sed -e ':a;N;$!ba;s/\n / /g' | \
            awk '/ABS_MT_TOUCH/{print $6}' | sed 's/\"//g'`

#Using assigned name search for properties registered in devices
TOUCH_SYSFS=`do_cmd cat /proc/bus/input/devices | tr '\n' ' ' | \
            sed 's/^.*'$TOUCH_NAME'/'$TOUCH_NAME'/' | \
            awk '/'$TOUCH_NAME'/{print $5}'`
TOUCH_SYSFS=${TOUCH_SYSFS#'Sysfs='}

I2C_PATH=$(echo $TOUCH_SYSFS | grep -Eo ".*/i2c-[0-9]+")

TOUCH_INPUT=`do_cmd cat /proc/bus/input/devices | tr '\n' ' ' | \
              sed 's/^.*'$TOUCH_NAME'/'$TOUCH_NAME'/' | \
              awk '/'$TOUCH_NAME'/{print $9}'`
TOUCH_INPUT=${TOUCH_INPUT#'Handlers='}

TOUCH_PHYS=`do_cmd cat /proc/bus/input/devices | tr '\n' ' ' | \
            sed 's/^.*'$TOUCH_NAME'/'$TOUCH_NAME'/' | \
            awk '/'$TOUCH_NAME'/{print $3}' | sed  's/\/input[0-9]//g'`
TOUCH_PHYS=${TOUCH_PHYS#'Phys='}

TOUCH_DEVICE_PATH=`do_cmd ls -l "/sys/$TOUCH_SYSFS" | tr '\n' ' ' | \
                   sed 's/^.*'device'/'device'/' | \
                   awk '/'device'/{print $3}'`

# Search for min and max values of the given event
TOUCH_MIN_X=`do_cmd getevent -pl $INPUTS_PATH$TOUCH_INPUT | \
            grep ABS_MT_POSITION_X | sed 's/^.*'min'/"min"/' | \
            awk '/'min'/{print $2}' | grep -Eo "[0-9]+"`

TOUCH_MAX_X=`do_cmd getevent -pl $INPUTS_PATH$TOUCH_INPUT | \
            grep ABS_MT_POSITION_X | sed 's/^.*'max'/'max'/' | \
            awk '/'max'/{print $2}' | grep -Eo "[0-9]+"`

TOUCH_MIN_Y=`do_cmd getevent -pl $INPUTS_PATH$TOUCH_INPUT | \
            grep ABS_MT_POSITION_Y | sed 's/^.*'min'/'min'/' | \
            awk '/'min'/{print $2}' | grep -Eo "[0-9]+"`

TOUCH_MAX_Y=`do_cmd getevent -pl $INPUTS_PATH$TOUCH_INPUT | \
            grep ABS_MT_POSITION_Y | sed 's/^.*'max'/'max'/' | \
            awk '/'max'/{print $2}' | grep -Eo "[0-9]+"`

TOUCH_SLOTS=`do_cmd getevent -pl $INPUTS_PATH$TOUCH_INPUT | \
            grep ABS_MT_SLOT | sed 's/^.*'max'/'max'/' | \
            awk '/'max'/{print $2}' | grep -Eo "[0-9]+"`

TOUCH_MAX_TRACKING_ID=`do_cmd getevent -pl $INPUTS_PATH$TOUCH_INPUT | \
                      grep ABS_MT_TRACKING_ID | sed 's/^.*'max'/'max'/' | \
                      awk '/'max'/{print $2}' | grep -Eo "[0-9]+"`

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
print_touch_properties || die "Cannot print touch properties"
trap "touch_cleanup" 0  # Cleanup touch events
