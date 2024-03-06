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
# File:         cpu_common.sh
#
# Description:  common file for cpu features test
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      January 03 2018 - created - Pengfei Xu

# @desc provide common functions for tpm features
# @returns Fail if return code is non-zero (value set not found)

source "common.sh"

FILTER=""

teardown_handler="tpm_teardown"

# Reserve for taerdown, present no change for cpu test
tpm_teardown() {
  [ -z "$FILTER" ] || {
    FILTER=""
    test_print_trc "set null for FILTER"
  }
}

# Check the result by filter matched content last line and 1st part value
# Input:
#   $1: log file path
#   $2: filter string should not exist in the test log
# Return: 0 for true, otherwise false or die
result_no_filter_str() {
  local log_file=$1
  local filter=$2
  local log_detail=""
  local actual_result=""

  [ -n "$log_file" ] || die "No log file:$log_file"
  [ -n "$filter" ] || die "No filter:$filter"

  [ -e "$log_file" ] || die "Check log file:$log_file was not exist"
  log_detail=$(cat "$log_file")
  test_print_trc "$log_file:"
  test_print_trc "$log_detail"
  test_print_trc "$log_file end"
  actual_result=$(echo "$log_detail" \
                  | grep -i "$filter")
  if [ -z "$actual_result" ]; then
    test_print_trc "Check $log_file pass, no $filter in the log."
  else
    die "Check $log_file fail, contain $filter in log:$actual_result"
  fi
}

# Executed common command
# Inupt:
#   $1: common command need execute
#   $2: filter content to filter useful result value
#   $3: function name to create log path and log file
#   $4: out put info, error means check error log, pass check pass log
# Return: 0 for true, otherwise false or die
com_cmd() {
  local cmd_name=$1
  local filter=$2
  local func=$3
  local err_pass=$4
  local log_path="/tmp/$func"
  local log_file="${log_path}/${func}.log"

  [ -n "$cmd_name" ] || die "Command was not exist:$cmd_name"
  [ -n "$filter" ] || die "Filter content was not exist:$filter"
  [ -n "$func" ] || die "function name was not exist:$func"

  [ -d "$log_path" ] || mkdir "$log_path"

  # due to fake tpm issue LCK-4995: all object that are subject to
  # DA (dictionary attack) will return RC_RETRY after boot, this
  # is by the spec 1.38, the second try should succeed.
  # skip 1st time try results
  [[ "$cmd_name" == *"test_seal_with_auth" ]] && {
    ${cmd_name} 2> $log_file
    cat "$log_file"
  }

  case $err_pass in
    error)
      ${cmd_name} 2> $log_file
      [ $? -eq 0 ] || {
        cat "$log_file"
        die "Executed $cmd_name fail"
      }
      ;;
    *)
      ${cmd_name} > $log_file
      ;;
  esac

  [ -e "$log_file" ] || die "$cmd_name fail, $log_file was not exist"

  case $func in
    tpm)
      result_no_filter_str "$log_file" "$filter"
      ;;
    *)
      test_print_trc "No need extra check for $func"
      ;;
  esac
  do_cmd "rm -rf $log_file"
}

# Check sysfs file content is our expect
# $1: sysfs file path
# $2: expected sysfs file content
# Return: 0 for true, otherwise false or die
sysfs_check() {
  local sysfs_path=$1
  local expect_result=$2
  local actual_result=""

  actual_result=$(cat "$sysfs_path")
  [ -n "$expect_result" ] || die "expect result is null:$expect_result"
  if [ "$actual_result" != "$expect_result" ]; then
    die "$sysfs_path content is not $expect_result:$actual_result"
  else
    test_print_trc "$sysfs_path:$actual_result, pass"
  fi
}
