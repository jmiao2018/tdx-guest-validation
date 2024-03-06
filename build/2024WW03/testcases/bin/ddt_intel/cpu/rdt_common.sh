#!/bin/bash
###############################################################################
##                                                                           ##
## Copyright (c) 2018, Intel Corporation.                                    ##
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
# File:         rdt_common.sh
#
# Description:  common file for rdt test
#

# @desc provide common functions for rdt
# @returns Fail if return code is non-zero (value set not found)

source "common.sh"

CACHE_BIN_NAME="cache_contending_processes"
RDT_LOG_PATH="/tmp/rdt"
MBA_TRHREAD_THROTTLE_MODE_FILE="/sys/fs/resctrl/info/MB/thread_throttle_mode"

teardown_handler="rdt_teardown"
rdt_teardown() {
  test_print_trc "rdt tear down"
}

# Check if mba perthread is enabled
mba_perthread_enable_check() {
  local params=$1
  [[ -e "${MBA_TRHREAD_THROTTLE_MODE_FILE}" ]] \
    || mount -t resctrl resctrl /sys/fs/resctrl/
  grep -q "per-thread" "${MBA_TRHREAD_THROTTLE_MODE_FILE}" \
    || die "${MBA_TRHREAD_THROTTLE_MODE_FILE} is not per-thread"

  return 0
}

# Call test binary to test cache contending
# Input: None
# Return: 0 for true, otherwise false or die
cache_processes_test() {
  local params=$1
  local bin_dir_name=""

  # Check bin file is there and log path
  bin_dir_name=$(which $CACHE_BIN_NAME)
  [ -n "$bin_dir_name" ] || die "Test app $CACHE_BIN_NAME is not found for execution"
  [ -d "$RDT_LOG_PATH" ] || mkdir "$RDT_LOG_PATH"

  # Call test app and output log
  $bin_dir_name $params > ${RDT_LOG_PATH}/${CACHE_BIN_NAME}.log

  if [ $? -eq 0 ]; then
    test_print_trc "cache contenting process pass"
  else
    die "cache contenting process failed"
  fi

  return 0
}
