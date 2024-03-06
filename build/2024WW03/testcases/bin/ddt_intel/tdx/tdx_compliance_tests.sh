#!/bin/bash
###############################################################################
# Copyright (C) 2021, Intel - http://www.intel.com
#
# SPDX-License-Identifier: GPL-2.0-or-later
###############################################################################

############################ DESCRIPTION ######################################
# @desc     TDX compliance validation
###############################################################################
source "common.sh"
source "functions.sh"
DIR_DDT_INTEL=$LTPROOT/testcases/bin/ddt_intel/

MODULE_NAME=tdx-compliance.ko
MODULE_PATH=$DIR_DDT_INTEL/lkvs/tdx-compliance/
ROOT_PATH=$LTPROOT
DEBUGFS=/sys/kernel/debug/tdx/tdx-tests
VERINFO=""

if [ "$PLATFORM" = "spr" ]; then
  VERINFO="1.0"
elif [ "$PLATFORM" = "emr" ]; then
  VERINFO="1.5"
elif [ "$PLATFORM" = "gnr" ]; then
  VERINFO="2.0"
else
  VERINFO=""
fi

usage() {
  cat <<-EOF
  usage: ./${0##*/} [-t CASE to run] [-h Help]
  -t input case name
  -h print this usage
EOF
}

while getopts :t:h arg; do
  case $arg in
  t)
    TESTCASE=$OPTARG
    ;;
  h)
    usage && exit 0
    ;;
  :)
    test_print_err "Must supply an argument to -$OPTARG."
    usage && exit 1
    ;;
  \?)
    test_print_err "Invalid Option -$OPTARG ignored."
    usage && exit 1
    ;;
  esac
done

modprobe tdx-compliance

# Check if the module is already loaded
if lsmod | grep -q "tdx_compliance"; then
    test_print_trc "Module '${MODULE_NAME}' is already loaded"
else
    output=$(do_cmd "insmod ${MODULE_PATH}/${MODULE_NAME} 2>&1")
    if [[ $? -ne 0 ]]; then
        test_print_err "Failed to load module '${MODULE_NAME}': $output"
        exit 1
    fi
fi

test_print_trc "Module '${MODULE_NAME}' loaded successfully"

CASENAME=${TESTCASE#TDX_COMP_}
echo $CASENAME $VERINFO > $DEBUGFS

if [[ $? != 0 ]] ;then
die "can't echo case to debugfs"
fi

result=$(grep -a "Total" $DEBUGFS | tr -d '\r')
echo "/***************************/"
echo $result
if echo "$result" | grep -Eq "FAIL:[[:space:]]*1"; then
  cat $DEBUGFS
  die "Find FAIL:1"
elif echo "$result" | grep -Eq "PASS:[[:space:]]*1"; then
  test_print_trc "Find PASS:1"
else
  test_print_err "Error: Total line not found or does not contain PASS:1 or FAIL:1"
  die "Unexpected Error! None case in test "
fi
