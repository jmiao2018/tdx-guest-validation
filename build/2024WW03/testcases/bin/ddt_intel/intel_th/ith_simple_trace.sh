#!/bin/bash

###############################################################################
# Copyright (C) 2017, Intel - http://www.intel.com
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

############################ CONTRIBUTORS #####################################

# @Author   Juan Pablo Gomez <juan.p.gomez@intel>
#
# Aug, 2017. Juan Pablo Gomez <juan.p.gomez@intel.com>
#     - Initial draft.

############################ DESCRIPTION ######################################

# @desc     This 'simple_trace()' function checks a simple trace using ITH driver
# @returns
# @history  2017-08-05: First version

############################# FUNCTIONS #######################################
source common.sh
source ith_common.sh

simple_trace(){

  MSC0=$(cat /sys/bus/intel_th/devices/0-msc0/port)
  test_print_trc "MSC0 port is:$MSC0"
  do_cmd "echo 0 > /sys/bus/intel_th/devices/0-gth/masters/256+"
  if [ "$?" -ne 0 ]; then
    die "Master could not be set"
  else
    test_print_trc "Master 256 was successfully set"
  fi

  #before the trace config setting, make sure it deactive.
  if [[ "$OS" = "android"    ]]; then
    do_cmd "echo 0 > /sys/bus/intel_th/devices/0-msc0/active"
    if [ "$?" -ne 0 ]; then
      die "MSC0 was not deactivaed"
    else
      test_print_trc "Msc0 was successfully deactivated"
    fi
  fi

  do_cmd "echo multi > /sys/bus/intel_th/devices/0-msc0/mode"
  if [ "$?" -ne 0 ]; then
    die "Multi-mode could not be set"
  else
    test_print_trc "Multi-mode was correctly set to MSC0"
  fi

  do_cmd "echo 64,64 > /sys/bus/intel_th/devices/0-msc0/nr_pages"
  if [ "$?" -ne 0 ]; then
    die "2 Windowed multiblock buffer on the first memory controller, with 64 pages failed"
  else
    test_print_trc "2 Windowed multiblock buffer on the first memory controller, with 64 pages are set"
  fi

  do_cmd "echo 1 > /sys/bus/intel_th/devices/0-msc0/wrap"
  if [ "$?" -ne 0 ]; then
    die "Wraper is not activated"
  else
    test_print_trc "Wraper is activated"
  fi

  do_cmd "echo 1 > /sys/bus/intel_th/devices/0-msc0/active"
  if [ "$?" -ne 0 ]; then
    die "MSC0 is not activated"
  else
    test_print_trc "MSC0 is activated"
  fi

  do_cmd "echo 'Hello Trace Hub' > /dev/0-sth"
  if [ "$?" -ne 0 ]; then
    die "Trace was not created"
  else
    test_print_trc "Trace was created"
  fi

  do_cmd "echo 0 > /sys/bus/intel_th/devices/0-msc0/active"
  if [ "$?" -ne 0 ]; then
    die "MSC0 was not deactivaed"
  else
    test_print_trc "Msc0 was successfully deactivated"
  fi
   test_print_trc "Checking the content of the trace...."

  if [[ "$OS" = "android"   ]]; then
   do_cmd "cat /dev/0-msc0 > $MY_TRACE"
   TRACE=$(stat -c "%s" $MY_TRACE)
   if [ "$TRACE" -eq 0 ]; then
    die "Trace was not created"
   else
    test_print_trc "Traces was collected,size=$TRACE"
   fi
  else
   do_cmd "rm -r $MY_TRACE"
   do_cmd "cat /dev/intel_th0/msc0 > $MY_TRACE"
   TRACE=$(ls $MY_TRACE)
   if [ "$?" -ne 0 ]; then
    die "Trace was not created"
   else
    test_print_trc "Traces was collected"
    test_print_trc "==========================================================="
    test_print_trc "TRACE: $TRACE"
    test_print_trc "==========================================================="
   fi
  fi

}
################################ DO THE WORK ##################################
simple_trace
