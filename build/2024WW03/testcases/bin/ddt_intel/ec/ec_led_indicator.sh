#!/bin/bash

###############################################################################
#
# Copyright (C) 2016 Intel - http://www.intel.com/
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
###############################################################################

############################ CONTRIBUTORS #####################################

# Author: Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#
# Apr, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#   - Initial draft
#   - Added 'get_from_kbd()' function to read input from CAPS and NUM LOCK
#     keys
# May, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#    - Added logic to execute the test $LOOP times
# Dec, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#   - Ported from LCK-GDC suite to LTP-DDT.

############################ DESCRIPTION ######################################

# @desc    This script turn on/off LED indicators in platform and read input from
#          CAPS LOCK, NUM LOCK and SCROLL LOCK keys.
# @params  [-i INPUT] [-l LOOP] [-c CAPS_LOCK] [-n NUM_LOCK] [-s SCROLL_LOCK]
# @return
# @history 2016-04-10: Created an initial draft.
#                      Added 'get_from_kbd()'.
# @history 2016-05-10: Added logic to execute the test $LOOP times.
# @history 2016-12-01: Integrated to LTP-DDT.
#                      Added 'source ec_paths.sh'.

############################ FUNCTIONS ########################################

usage(){
cat <<-EOF >&2
  usage: ./${0##*/} [-i INPUT] [-l LOOP] [-c CAPS_LOCK] [-n NUM_LOCK] [-s SCROLL_LOCK]
    -i INPUT	From PS/2 or Keyboard
    -l LOOP	Test loop
    -c CAPS	Test Caps Lock LED/Key
    -n NUM	Test Num Lock LED/Key
    -s SCROLL	Test Scroll LED/Key
    -h HELP	Print this usage
EOF
exit 0
}

# TURN ON - OFF LED
on_off_led()
{
  init_status=$1
  dir=$2

  # GET INITIAL STATE OF LED
  if [[ $init_status -eq 1 ]]; then
    cur_state="on"
  else
    cur_state="off"
  fi

  # CHANGE STATE OF LED
  test_print_trc "Initial status of LED is $init_status - $cur_state"
  if [[ $cur_state == "on" ]]; then
    test_print_trc "Changing state of LED to off"
    do_cmd "echo 0 > $dir/brightness"
  elif [[ $cur_state == "off" ]]; then
    test_print_trc "Changing state of LED to on"
    do_cmd "echo 1 > $dir/brightness"
  fi

  sleep 3

  # CHECK IF LED STATE CHANGED
  do_cmd new_status=`cat $dir/brightness`
  if [[ $new_status -ne $init_status ]]; then
    test_print_trc "LED status has changed to $new_status"
  else
    die "Error. LED status did not chenge"
    return 1
  fi

  # RETURN LED STATE TO ITS INITIAL STATE
  if [[ $new_status -eq 1 ]]; then
    test_print_trc "Changin state of LED to its initial status off"
    do_cmd "echo 0 > $dir/brightness"
  elif [[ $new_status -eq 0 ]]; then
    test_print_trc "Changing state of LED to its initial status on"
    do_cmd "echo 1 > $dir/brightness"
  fi

  sleep 3

  # CHECK IF LED RETURNED TO ITS INITIAL STATE
  do_cmd final_status=`cat $dir/brightness`
  if [[ $final_status -eq $init_status ]]; then
    test_print_trc "LED has returned to its initial status"
  else
    die "Error. LED does not returned to its initial status"
  fi
}

# GET INPUT FROM KEYBOARD
get_from_kbd()
{
  init_status=$1
  dir=$2
  key=$3

  # GET INITIAL STATE
  if [[ $init_status -eq 1 ]]; then
    cur_state="on"
  else
    cur_state="off"
  fi

  test_print_trc "Initial status of $key key is $init_status - $cur_state"
  test_print_trc "=== Press $key key on the keyboard. You have 5 seconds ==="

  sleep 5

  # CHECK IF KEY STATE CHANGED
  do_cmd new_status=`cat $dir/brightness`
  if [[ $new_status -ne $init_status ]]; then
    test_print_trc "$key key status has changed to $new_status"
  else
    die "Error. $key LED status did not chenge"
    return 1
  fi

  test_print_trc "=== Press $key key on the keyboard to return to its initial status. You have 5 seconds ==="

  sleep 5

  # RETURN KEY STATE TO ITS INITIAL STATE
  do_cmd final_status=`cat $dir/brightness`
  if [[ $final_status -eq $init_status ]]; then
    test_print_trc "$key LED has returned to its initial status"
  else
    die "Error. $key LED does not returned to its initial status"
  fi
}

############################ DO THE WORK ######################################

source "common.sh"
source "ec_paths.sh"

while getopts :i:l:cnsh arg
do case $arg in
    i) INPUT="$OPTARG" ;;
    l) LOOP="$OPTARG" ;;
    c) CAPS_LOCK=1 ;;
    n) NUM_LOCK=1 ;;
    s) SCROLL_LOCK=1 ;;
    h) usage ;;
    :) test_print_trc "$0: Must supply an argument to -$OPTARG" >&2
       exit 1 ;;
    \?) test_print_trc "Invalid Option -$OPTARG ignored" >&2
        usage
        exit 1;;
  esac
done

# DEFAULT PARAMETER
: ${LOOP:='1'}
: ${CAPS_LOCK:='0'}
: ${NUM_LOCK:='0'}
: ${SCROLL_LOCK:='0'}

x=0

while [ $x -lt $LOOP ]
do
  echo "============R/W LOOP: $x============"

  # FROM PS/2 - LED ON PLATFORM
  if [[ $INPUT == "input4" ]]; then

    # GET CAPS, NUM AND SCROLL DIRECTORY
    if [ $CAPS_LOCK -eq 1 ]; then
      STATUS=`cat $SER_CAPS_LOCK_DIR/brightness`
      LED_DIR="$SER_CAPS_LOCK_DIR"
    elif [ $NUM_LOCK -eq 1 ]; then
      STATUS=`cat $SER_NUM_LOCK_DIR/brightness`
      LED_DIR="$SER_NUM_LOCK_DIR"
    elif [ $SCROLL_LOCK -eq 1 ]; then
      STATUS=`cat $SER_SCROLL_LOCK_DIR/brightness`
      LED_DIR="$SER_SCROLL_LOCK_DIR"
    fi

    # TURN ON/OFF LED
    on_off_led "$STATUS" "$LED_DIR"

  # FROM PCI - KEYBOARD
  elif [[ $INPUT == "input9" ]]; then

    # GET CAPS, NUM AND SCROLL DIRECTORY
    if [ $CAPS_LOCK -eq 1 ]; then
      STATUS=`cat $PCI_CAPS_LOCK_DIR/brightness`
      LED_DIR="$PCI_CAPS_LOCK_DIR"
      KEY="CAPS LOCK"
    elif [ $NUM_LOCK -eq 1 ]; then
      STATUS=`cat $PCI_NUM_LOCK_DIR/brightness`
      LED_DIR="$PCI_NUM_LOCK_DIR"
      KEY="NUM LOCK"
    fi

    # GET INPUT FROM KEYBOARD
    get_from_kbd "$STATUS" "$LED_DIR" "$KEY"

  fi

  x=$((x+1))
done
