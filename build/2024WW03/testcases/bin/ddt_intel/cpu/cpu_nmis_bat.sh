#!/bin/bash
###############################################################################
##                                                                           ##
## Copyright (c) 2017, Intel Corporation.                                    ##
##                                                                           ##
## This program is free software; you can redistribute it and/or modify it   ##
## under the terms and conditions of the GNU General Public License,         ##
## version 2, as published by the Free Software Foundation.                  ##
##                                                                           ##
## This program is distributed in the hope it will be useful, but WITHOUT    ##
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or     ##
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for ##
## more details.                                                             ##
###############################################################################
#
# File:         cpu_nmis_bat.sh
#
# Description:  it's for cpu nmis bat test
#
# Authors:      Farrah Chen - farrah.chen@intel.com
#
# History:      November 29 2023 - created - Farrah Chen

# @desc check nmis is support or not
# @returns Fail if return code is non-zero

source "common.sh"
source "functions.sh"
source "cpu_common.sh"

: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

nmis_ipi_test() {
    full_dmesg_check "NMI testsuite" "$CONTAIN"
    full_dmesg_check "NMI received src 1 IPI" "$CONTAIN"
    full_dmesg_check "Good, all   2 testcases passed!" "$CONTAIN"
}

nmis_pmi_test() {
    perf top &> /dev/null &
    pid=$!
    sleep 5
    kill -9 $pid
    dmesg_check "NMI received src 3 PERF_MON" "$CONTAIN"
}

nmis_bat_test() {
  case $TEST_SCENARIO in
    nmis_ipi_test)
      nmis_ipi_test
      ;;
    nmis_pmi_test)
      nmis_pmi_test
      ;;
    esac
  return 0
}

while getopts :t:w:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    H)
      usage && exit 0
      ;;
    \?)
      usage
      die "Invalid Option -$OPTARG"
      ;;
    :)
      usage
      die "Option -$OPTARG requires an argument."
      ;;
  esac
done

nmis_bat_test
# Call teardown for passing case
exec_teardown
