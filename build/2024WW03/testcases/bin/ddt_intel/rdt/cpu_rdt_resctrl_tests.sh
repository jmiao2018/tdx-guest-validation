#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2017 Intel - http://www.intel.com/
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
# Contributors:
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -Initial draft.
###############################################################################
# @desc Search for device nodes under sysfs (/sys/class/).
# @params s) device_type like: mmc, rtc, pwm.
# @returns Number of entries found.
# @history 2015-04-20: First version.

source "common.sh"  # Import do_cmd(), die() and other functions

############################# Functions #######################################
usage() {
  cat <<-EOF
    usage: ./${0##*/} [-t test_type]
    -t TEST_TYPE       test type like 'mbm', 'mba', 'mba4' 'iordt' etc...
    -o TEST_OPCODE     test opcode like 'sanity', 'function'
    -v TEST_VALUE      test value like '0', '1', '2', '3', '4'
    -h Help            print this usage.
EOF
}

# Run utility resctrl_tests and check its output.
# Input: test_type string containing the device type e.g. mbm, mba, etc...
# Return: 0 for pass, 1 for fail, 2 for block.
do_resctrl_test() {
  local test_type="$TYPE"
  local test_opcode="$TEST_OPCODE"
  local test_value="$TEST_VALUE"
  local ret_value

  if [ $test_opcode="mba4" ] || [ $test_opcode="iordt" ]; then
    ret_value=$(resctrl_tests -t $test_type -o $test_opcode -v $test_value 2>&1)
  else
    ret_value=$(resctrl_tests -t $test_type 2>&1)
  fi

  echo "$ret_value"
}

############################ Script Variables ##################################
# Define default values if possible
: "${EXPECT:='0'}"
TYPE=""
RET=""
TEST_OPCODE=""
TEST_VALUE=""

################################ CLI Params ####################################
while getopts :t:h:o:v: arg; do
  case $arg in
    t)  TEST_TYPE="$OPTARG";;
    o)  TEST_OPCODE="$OPTARG";;
    v)  TEST_VALUE="$OPTARG";;
    h)  usage && exit 0;;
    :)  die "$0: Must supply an argument to -$OPTARG.";;
   \?)  die "Invalid Option -$OPTARG ";;
  esac
done

########################### DYNAMICALLY-DEFINED Params #########################
if [[ -z "$TEST_TYPE" ]]; then
  die "Error: <device_type> argument is missing..."
fi

# Decide device type search folder
case "$TEST_TYPE" in
  "mbm")  TYPE="mbm";;
  "mba")  TYPE="mba";;
  "mba4") TYPE="mba4";;
  "iordt") TYPE="iordt";;
  # Add here any extra test_type
  *)    die "Error: $0 does not support $TEST_TYPE as TEST_TYPE";;
esac

# Call do_resctrl_test to do test
test_print_trc "Do resctrl test for $TEST_TYPE"
RET=$(do_resctrl_test -t "$TEST_TYPE")
test_print_trc "do_resctrl_test -t $TEST_TYPE -o $TEST_OPCODE -v $TEST_VALUE returned >>$RET<<."

########################### REUSABLE TEST LOGIC ###############################
# Check entries number
if [[ $RET =~ "Hardware does not support" ]]; then
  test_print_trc "test case not supported, exit."
  exit 2
fi

if [[ $RET =~ "Platform does not meet the test" ]]; then
  test_print_trc "Platform does not meet the test, exit."
  exit 2
fi

if [[ $RET =~ "MBM: bw change failed" ]]; then
  test_print_trc "test case failed."
  exit 1
fi

if [[ $RET =~ "Ending: mba_schemata_change failed" ]]; then
  test_print_trc "test case failed."
  exit 1
fi

if [[ $RET =~ "Ending: MBA4 non-competition function test failed" ]]; then
  test_print_trc "test case failed."
  exit 1
fi

if [[ $RET =~ "Ending: MBA4 competition function test failed" ]]; then
   test_print_trc "test case failed."
   exit 1
fi

if [[ $RET =~ "Ending MBA4 sanity test failed" ]]; then
   test_print_trc "test case failed."
   exit 1
fi

if [[ $RET =~ "Ending: CMT test failed" ]]; then
    test_print_trc "test case failed."
    exit 1
fi

if [[ $RET =~ "Ending: CAT test failed" ]]; then
     test_print_trc "test case failed."
     exit 1
fi

if [[ $RET =~ "io rdt sanity test failed" ]]; then
   test_print_trc "test case failed."
   exit 1
fi

if [[ $RET =~ "io rdt functional test failed" ]]; then
   test_print_trc "test case failed."
   exit 1
fi

exit 0
