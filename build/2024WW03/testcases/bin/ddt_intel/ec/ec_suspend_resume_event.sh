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
# May, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#    - Added logic to execute the test $LOOP times
#    - Added logic to get LID button events while system is suspended
#    - Added logic to get CAPS LOCK key events while system is suspended
#    - Added logic to get both LID button and CAPS LOCK key while system is
#      suspended.
# Dec, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#   - Ported from LCK-GDC suite to LTP-DDT.

############################ DESCRIPTION ######################################

# @desc    This script read the EC transactions while suspend/resume platform.
# @params  [-s] [-b] [-k] [-a] [-l LOOP]
# @return
# @history 2016-04-10: Created an initial draft.
# @history 2016-05-10: Added logic to execute the test $LOOP times.
#		       Added logic to get LID button events while system is
#		       suspended.
#		       Added logic to get CAPS LOCK key events while system
#		       is suspended.
#  		       Added logic to get both LID button and CAPS LOCK key
#		       while system is suspended.
# @history 2016-12-01: Integrated to LTP-DDT.
#		       Added 'source ec_paths.sh'.

############################ FUNCTIONS ########################################

usage(){
cat <<-EOF >&2
  usage: ./${0##*/} [-s] [-b] [-k] [-a] [-l LOOP]
    -s   	suspend/resume
    -b		get button EC events while suspend/resume
    -k		get key EC events while suspend/resume
    -a		get both button and key EC events while suspend/resume
    -l LOOP     execute test LOOP times
    -h Help     print this usage
EOF
exit 0
}

############################ DO THE WORK ######################################

source "common.sh"
source "ec_paths.sh"

while getopts :sbkal:h arg
do case $arg in
    s) SUSPEND=1 ;;
    b) GET_BUTTON=1 ;;
    k) GET_KEY=1 ;;
    a) BUTTON_KEY=1 ;;
    l) LOOP="$OPTARG" ;;
    h) usage ;;
    :) test_print_trc "$0: Must supply an argument to -$OPTARG." >&2
       exit 1 ;;
    \?) test_print_trc "Invalid Option -$OPTARG ignored." >&2
	usage
   	exit 1 ;;
  esac
done

# DEFAULT PARAMETERS
: ${SUSPEND:='0'}
: ${GET_BUTTON:='0'}
: ${GET_KEY:='0'}
: ${BUTTON_KEY:='0'}
: ${LOOP:='1'}

x=0

while [ $x -lt $LOOP ]
do
  echo "============R/W LOOP: $x============"

  do_cmd "dmesg -C"

  # GET EC EVENTS WHILE SUSPEND/RESUME SYSTEM
  if [ $SUSPEND -eq 1 ]; then
    do_cmd "rtcwake -m mem -s 15"
    sleep 10

    # VERIFY EC EVENTS STOPPED
    dmesg | grep "EC stopped"
    if [ $? -ne 0 ]; then
      die "EC not stopped"
    fi
    test_print_trc "EC events stopped for system suspend"

    # VERIFY EC EVENTS STARTED
    dmesg | grep "EC started"
    if [ $? -ne 0 ]; then
      die "EC not stopped"
    fi
    test_print_trc "EC events restarted after system suspend"

  # GET LID BUTTON EVENTS WHILE SUSPEND/RESUME
  elif [ $GET_BUTTON -eq 1 ]; then
    INIT_STATUS=`cat $LID_BUTTON | cut -d':' -f2 | sed 's/ //g'`
    test_print_trc "Iinitial status of LID button is $INIT_STATUS"

    test_print_trc "=== System will suspend ==="
    test_print_trc "=== While suspend, change state of LID button ==="
    sleep 5

    # SUSPEN/RESUME SYSTEM FOR 15 SECONDS
    do_cmd "rtcwake -m mem -s 15"
    NEW_STATUS=`cat $LID_BUTTON | cut -d':' -f2 | sed 's/ //g'`
    test_print_trc "New status of LID button is $NEW_STATUS"

    # CHECK IF THERE WAS EVENT
    if [[ $INIT_STATUS != $NEW_STATUS ]]; then
      test_print_trc "EC button event registered while system suspend"
    else
      die "EC button event not registered"
    fi

  # GET CAPS LOCK KEY EVENTS WHILE SUSPEND/RESUME
  elif [ $GET_KEY -eq 1 ]; then
    INIT_STATUS=`cat $PCI_CAPS_LOCK_DIR/brightness`
    test_print_trc "Iinitial status of CAPS LOCK Key is $INIT_STATUS"

    test_print_trc "=== System will suspend ==="
    test_print_trc "=== While suspend, change state of CAPS LOCK Key ==="
    sleep 5

    # SUSPEN/RESUME SYSTEM FOR 15 SECONDS
    do_cmd "rtcwake -m mem -s 15"
    NEW_STATUS=`cat $PCI_CAPS_LOCK_DIR/brightness`
    test_print_trc "New status of CAPS LOCK Key is $NEW_STATUS"

    # CEHCK IF THERE WAS EVENT
    if [[ $INIT_STATUS != $NEW_STATUS ]]; then
      test_print_trc "EC key event registered while system suspend"
    else
      die "EC key event not registered"
    fi

  # GET BOTH LID BUTTON AND CAPS LOCK EVENTS WHILE SUSPEND/RESUME
  elif [ $BUTTON_KEY -eq 1 ]; then
    INIT_STATUS_BUTTON=`cat $LID_BUTTON | cut -d':' -f2 | sed 's/ //g'`
    INIT_STATUS_KEY=`cat $PCI_CAPS_LOCK_DIR/brightness`

    test_print_trc "Iinitial status of LID button is $INIT_STATUS_BUTTON"
    test_print_trc "Iinitial status of CAPS LOCK Key is $INIT_STATUS_KEY"

    test_print_trc "=== System will suspend ==="
    test_print_trc "=== While suspend, change state of LID button and CAPS_LOCK Key ==="
    sleep 5

    # SUSPEND/RESUME SYSTEM FOR 15 SECONDS
    do_cmd "rtcwake -m mem -s 15"
    NEW_STATUS_BUTTON=`cat $LID_BUTTON | cut -d':' -f2 | sed 's/ //g'`
    NEW_STATUS_KEY=`cat $PCI_CAPS_LOCK_DIR/brightness`
    test_print_trc "New status of LID button is $NEW_STATUS_BUTTON"
    test_print_trc "New status of CAPS LOCK Key is $NEW_STATUS_KEY"

    # CHECK IF THERE WAS EVENTS
    if [[ $INIT_STATUS_BUTTON != $NEW_STATUS_BUTTON ]] && [[ $INIT_STATUS_KEY != $NEW_STATUS_KEY ]]; then
      test_print_trc "EC button and key events registered while system suspend"
    else
      die "EC button nor key event not registered"
    fi
  fi

  x=$((x+1))
done
