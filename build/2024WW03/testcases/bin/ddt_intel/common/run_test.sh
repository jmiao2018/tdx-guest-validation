#!/bin/bash
###############################################################################
# Copyright (C) 2015 Intel - http://www.intel.com/
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
# Authors:
#         Wenzhong Sun <wenzhong.sun@intel.com>
###############################################################################

# @desc A lightweight test case launcher
# @params <test tag> <scenario file> <test loops> <verbose print>
# @returns 1  if any process returns non-zero value
#          0 otherwise
# @history 2015-04-16: Created

source "common.sh"  # Import do_cmd(), die() and other functions
############################# Functions #######################################
usage() {
  cat << _EOF
    Help:
    Execute test case by test tag"
    returns 0 if test pass, returns 1 otherwise"
    usage: run_tests.sh -t <test_tag> -f <scenario_file> -l <test_loops> -v"
_EOF
}

############################ Script Variables ##################################
RET=0
tst_tag=""
tst_loop=1
scen_file=""
verbose=false
cmdline=""
loop=1
log_dir="${LTPROOT}/test_log"
#BUSYBOX_DIR="${LTPROOT}/bin"

################################ CLI Params ####################################
while getopts "t:f:l:vh" opt; do
  case $opt in
    h) usage ;;
    t) tst_tag=$OPTARG ;;
    f) scen_file=$OPTARG ;;
    l) tst_loop=$OPTARG ;;
    v) verbose=true ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Syntax is -t <case_tag> -f <scenario_file> -l <test_loops> -v"
      ;;
    :)
      usage
      die "Option -$OPTARG requires an argument."
      ;;
  esac
done

############################ USER-DEFINED Params ##############################
# Define default values for variables being overriden

########################### DYNAMICALLY-DEFINED Params #########################

########################### REUSABLE TEST LOGIC ###############################

# Check required parameters
if [ -z "$tst_tag" ] || [ -z "$scen_file" ]; then
  usage
fi

# Preparation
mkdir -p "$log_dir" 2> /dev/null

# Get command line from $scen_file
[ -f "$scen_file" ] || scen_file="$LTPROOT/runtest/$scen_file"
[ -f "$scen_file" ] || die "test scenario file $scen_file is not found!"

cmdline=$(grep -E "$tst_tag" "$scen_file" | cut -d' ' -f2-)
if [ -n "$cmdline" ]; then
  test_print_trc "Get command line: \"$cmdline\""
else
  die "Failed to get command line for $tst_tag test"
fi

# Start launching test
while [ "$loop" -le "$tst_loop" ]; do
  test_print_trc "LOOP is $loop Running COMMAND: $cmdline"
  if "$verbose" ; then
    eval "$cmdline"
  else
    eval "$cmdline" > "$log_dir"/"$tst_tag"."$loop".log 2>&1
  fi
  RET=$?

  # print logs after every loops of test if not verbose print
  if ! "$verbose"; then
    echo "*************  start of $tst_tag test log [$loop]   ***************"
    cat "$log_dir"/"$tst_tag"."$loop".log
    echo "*************  end of $tst_tag test log [$loop]   ***************"
  fi

  # Exit test if test is failed
  [ $RET -ne 0 ] && die "[LOOP $loop] $tst_tag test failed, return $RET"

  loop=$((loop+1))
done

exit $RET
