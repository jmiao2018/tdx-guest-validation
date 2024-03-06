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
#             Aug. 29, 2018 - (Ammy Yi)Creation


# @desc This script verify ipt non priviledge test
# @returns Fail the test if return code is non-zero (value set not found)

source "ipt_common.sh"
source "common.sh"
: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

ipt_nonroot_test() {
  local MODE=0
  case $TEST_SCENARIO in
    ft)
      MODE=1
      ;;
    sn)
      MODE=2
      ;;
  esac
  user_do "nonroot_test $MODE"
  [[ $? -ne 0 ]] && die "nonroot_test failed!"
  clean_temp_users
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

ipt_nonroot_test
# Call teardown for passing case
exec_teardown
