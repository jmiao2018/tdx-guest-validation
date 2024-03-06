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

# Author: sylvainx.heude@intel.com
#
# Jan, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#   - Ported from 'otc_kernel_qa-tp_tc_scripts_linux_core_kernel' project to
#     LCK project.
#   - Modified script in order to align it to LCK repository standard.
# Apr, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#   - Added logic to read LID button after 5 seconds when it has been closed
#     or opened by the user.
# May, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Added logic to execute the test $LOOP times.
# Dec, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Ported from LCK-GDC suite to LTP-DDT.

############################ DESCRIPTION ######################################

# @desc This script read the status of the LID, BATTERY AND DOCKIN button
#       and verify EC transactions.
# @params [-b BUTTON] [-l LOOP]
# @return
# @history 2016-01-10: Ported from LCK suite to LCK-GDC suite.
# 	  	       Uptaded script to use correctly in LCK-GDC suite.
# @history 2016-04-10: Added logic to read LID button when it is closed/open.
# @history 2016-05-10: Added logic to execute the test $LOOP times.
# @history 2016-12-01: Integrated to LTP-DDT.
#		       Added 'source ec_paths.sh'.

############################ FUNCTIONS ########################################

usage(){
cat <<-EOF >&2
  usage: ./${0##*/} [-b BUTTON] [-l LOOP]
    -b BUTTON	read EC events from BUTTON
    -l LOOP	test loop
    -h Help	print this usage
EOF
exit 0
}

############################ DO THE WORK ######################################

source "common.sh"
source "ec_paths.sh"

while getopts :b:l:h arg
do case $arg in
    b) BUTTON="$OPTARG";;
    l) LOOP="$OPTARG";;
    h) usage ;;
    :) test_print_trc "$0: Must supply an argument to -$OPTARG." >&2
       exit 1 ;;
    \?) test_print_trc "Invalid Option -$OPTARG ignored." >&2
	usage
	exit 1 ;;
  esac
done

# DEFAULT PARAMETERS
: ${LOOP:='1'}

x=0

while [ $x -lt $LOOP ]
do
  test_print_trc "============R/W LOOP: $x============"

  # DELETE RING BUFFER OF 'dmesg'
  do_cmd "dmesg -C"

  if ! [ -z $BUTTON ]; then

    # CLOSE THE BUTTON
    test_print_trc "=== Close the $BUTTON button. You have 5 seconds ==="
    sleep 5

    dmesg | grep -i "ACPI : EC"
    if [ $? -ne 0 ]; then
      die "$BUTTON button was not closed"
    fi

    # OPEN THE BUTTON
    test_print_trc "=== Open the $BUTTON button. You have 5 seconds ==="
    sleep 5

    dmesg | grep -i "ACPI : EC"
    if [ $? -ne 0 ]; then
      die "$BUTTON button was not closed"
    fi

  else
    # READ STATE OF LID BUTTON
    do_cmd "cat $LID_BUTTON"

    # VERIFY IF AN EC TRANSACTION WAS TRIGGERED
    dmesg | grep -i "ACPI : EC"
  fi

  x=$((x+1))
done
