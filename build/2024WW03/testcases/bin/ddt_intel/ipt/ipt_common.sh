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

source "common.sh"
source "dmesg_functions.sh"

#will dump logs
dump_log() {
  #dump dmesg
  extract_case_dmesg > $LOG_PATH/${TAG}_dmesg.log
  echo "dmesg is $LOG_PATH/${TAG}_dmesg.log"
  return 0
}

#usb log check
dmesg_check() {
  while read line
  do
    extract_case_dmesg | grep "${line}"
    if [[ $? -eq 0 ]]; then
      dump_log
      echo "find dmesg error log"
      return 1
    fi
  done < $PWD/ddt_intel/usb/dmesg_error.dat

  extract_case_dmesg |  grep ERR
  if [[ $? -eq 0 ]]; then
    dump_log
    echo "find dmesg error log"
    return 1
  fi

  extract_case_dmesg |  grep WARN
  if [[ $? -eq 0 ]]; then
    dump_log
    echo "find dmesg waring log, please check detailed logs"
    return 1
  fi

  extract_case_dmesg |  grep "Call Trace"
  if [[ $? -eq 0 ]]; then
    dump_log
    echo "find dmesg waring log, please check detailed logs"
    return 1
  fi

  return 0
}
