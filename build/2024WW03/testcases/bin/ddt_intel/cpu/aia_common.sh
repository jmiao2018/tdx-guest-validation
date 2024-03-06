#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2020 Intel Corporation
#
# Description:  Accelerator Interfacing Architecture (AIA) test script

source "common.sh"

AIA_BIN_NAME="aia_test"
LOG_PATH="/tmp/aia"

# Call test app aia_test
aia_instruction_test()
{
  local test_option=$1
  local bin_dir_name=""

  # Check bin file is there and log path
  bin_dir_name=$(which $AIA_BIN_NAME)
  [ -n "$bin_dir_name" ] || die "Test app $AIA_BIN_NAME is not found for execution"
  [ -d "$LOG_PATH" ] || mkdir "$LOG_PATH"

  # Call test app and output log
  if $bin_dir_name "$test_option" > ${LOG_PATH}/${AIA_BIN_NAME}.log; then
    test_print_trc "AIA $test_option test pass"
  else
    die "AIA $test_option test failed"
  fi

  return 0
}
