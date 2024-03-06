#!/bin/bash
#
# Copyright 2018-2019 Intel Corporation
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
#             Tony Zhu <tony.zhu@intel.com>
#
# History:
#             Aug. 6, 2019 - (Tony Zhu)Creation


# @desc This script verify fsgs base test
# @returns Fail the test if return code is non-zero (value set not found)


source "common.sh"
: ${CASE_NAME:=""}

BIN_NAME="fsgsbase_test"
LOG_PATH="/tmp/fsgsbase"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-H]
  -H  show this
__EOF
}

test_fsgs() {
  local bin_dir_name=""

  # Check bin file is there and log path
  bin_dir_name=$(which $BIN_NAME)
  [ -n "$bin_dir_name" ] || die "Test app $BIN_NAME is not found for execution"
  [ -d "$LOG_PATH" ] && echo "$LOG_PATH exist" || mkdir "$LOG_PATH"

  # Call test app and output log
  $bin_dir_name > ${LOG_PATH}/${BIN_NAME}.log
  fail_cases=$(grep "FAIL" ${LOG_PATH}/${BIN_NAME}.log | awk '{print $1}')
  for num in $fail_cases; do
    [[ $num -eq 0 ]] || die "Some cases are failed, please check detailed data!"
  done
  return 0
}

test_fsgs
# Call teardown for passing case
exec_teardown
