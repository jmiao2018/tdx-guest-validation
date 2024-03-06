#!/usr/bin/env bash
#
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
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
# this file contains routines for printing the logs

TIME_FMT="%m%d_%H%M%S.%3N"

#
# prints the test start.
#
test_print_start(){
  id=$1        # testcase id

  # wait till all the kernel logs flushes out
  sleep 1

  echo "|$(date +"$TIME_FMT")|TEST START|$id|"
}

#
# prints the test end.
#
test_print_end(){
  id=$1        # testcase id

  # wait till all the kernel logs flushes out
  sleep 1

  echo "|$(date +"$TIME_FMT")|TEST END|$id|"
}

#
# prints the test result.
#
test_print_result(){
  result=$1     # testcase result
  id=$2         # testcase id

  # wait till all the kernel logs flushes out
  sleep 1

  echo "|$(date +"$TIME_FMT")|TEST RESULT|$result|$id|"
}

#
# prints the trace log.
#
test_print_trc(){
  log_info=$1      # trace information

  echo "|$(date +"$TIME_FMT")|TRACE|$log_info|"
}

#
# prints the test warning message.
#
test_print_wrg(){
  caller_info="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}:${FUNCNAME[1]}()"
  echo "|$(date +"$TIME_FMT")|WARNING| $caller_info - $*|" >&2
}

#
# prints the test error message.
#
test_print_err(){
  caller_info="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}:${FUNCNAME[1]}()"
  echo "|$(date +"$TIME_FMT")|ERROR| $caller_info - $*|" >&2
}

#test_print_start I2C_0_0_001
#test_print_trc  "I shouln't come"
#test_print_trc  "---I2C Testcase parameters---"
#test_print_trc  "Device Id: 0"
#test_print_trc  "Device name: /i2c0"
#test_print_trc  "Opmode (Polled/Int/DMA = 0/1/2): 1"
#test_print_trc  "Bus freq: 100000"
#test_print_trc  "Comm mode (Master/Slave = 0/1): 0"
#test_print_trc  "IO operation: (Read/Write = 0/1): 2"
#test_print_wrg  "WARNING MESSAGE"
#test_print_err  "ERROR MESSAGE"
#test_print_result PASS I2C_0_0_001
#test_print_end I2C_0_0_001
