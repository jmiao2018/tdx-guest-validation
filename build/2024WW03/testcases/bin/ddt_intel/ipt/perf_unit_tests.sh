#!/bin/bash
#
# Copyright 2018 Intel Corporation
#
# This file is part of LTP-DDT for IA
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
#             Ammy Yi <ammy.yi@intel.com>
#
# History:
#             Jun. 11, 2018 - (Ammy Yi)Creation


# @desc This script verify perf unit test
# @returns Fail the test if return code is non-zero (value set not found)

source "ipt_common.sh"
: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}


perfunittest() {
  local SKIP="Skip"
  local PASS="Ok"
  local FAIL="FAILED"
  local ret=1;
  local dret=0;
  local logfile="temp.log"
  
  perf test -s 34,36 2>&1 | tee $logfile
  if [ ! -s $logfile ]; then
    ret=2
  else
    grep "$FAIL" $logfile
    [[ $? -eq 0 ]] && ret=1
  fi

  dret=$(dmesg_check)
  [[ $dret -eq 1 ]] && ret=1
  return $ret
}

while getopts :t:H arg; do
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

perfunittest
# Call teardown for passing case
exec_teardown
