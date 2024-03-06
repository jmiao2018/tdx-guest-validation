#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2020 Intel Corporation
#
# Description:  Split lock function test script

source "common.sh"
source "dmesg_functions.sh"

MOD_NAME="split_lock_test_drv"

# Split lock detect test message patten
SL_TEST_MESSAGE_NAME=""
SL_ON_USER_MESSAGE="split lock detection: #AC"
SL_ON_ROOT_MESSAGE="RIP: 0010:split_lock_test_init"
SL_OFF_USER_MESSAGE="Split Lock test - exits normally"
SL_OFF_ROOT_MESSAGE="split lock kernel test passes"
SL_WARN_USER_MESSAGE="took a bus_lock trap at address"
SL_WARN_ROOT_MESSAGE="split lock kernel test passes"
SL_FATAL_USER_MESSAGE="Caught SIGBUS"
SL_FATAL_ROOT_MESSAGE="split lock kernel test passes"
SL_RATELIMIT_USER_MESSAGE="took a bus_lock trap at address"
SL_RATELIMIT_ROOT_MESSAGE="split lock kernel test passes"

# For original configuration record
# MOD_STATE: 0 means didn't install the mod, 1 means installed mod
MOD_STATE=0
BIN_NAME="sl_test"
#Added path variable to identify the location of the split lock test driver module
SL_TEST_MODULE_DIR_NAME=$(pwd)"/split_lock_test_drv.ko"
LOG_PATH="/tmp/sl"
CACHE_BIN_NAME="cache_contending_processes"

teardown_handler="sl_teardown"
sl_teardown() {
   # unload test module if it is on
   if [[ ${MOD_STATE} -ne 0 ]]; then
     lsmod | grep -q ${MOD_NAME} && {
       rmmod ${MOD_NAME}
       test_print_trc "remove ${MOD_NAME}"
       sleep 1
     }
   fi
}

# Check if rdmsr and wrmsr installed and worked.
function checking_msr_precondition()
{
  command -v rdmsr &> /dev/null && command -v wrmsr &> /dev/null|| {
    test_print_trc "rdmsr-tool is not installed,BLOCKED"
  return 1
  }
  do_cmd "modprobe msr"
  return 0
}

# To test control register 0x33 bit 29 writable
# Bit 29: Enable #AC(0) exception when split locked accesses
split_lock_control() {
  do_cmd checking_msr_precondition

  do_cmd "wrmsr -a 0x33 0x20000000"

  return 0
}

# Get the correct test message for user/root mode
get_test_message_name()
{
  local split_lock_detect=$1
  local user_root=$2
  local option=""
  case $split_lock_detect in
    *off*)
      option="OFF"
      ;;
    *warn*)
      option="WARN"
      ;;
    *fatal*)
      option="FATAL"
      ;;
    *ratelimit*)
      option="RATELIMIT"
      ;;
    *)
      option="ON"
      split_lock_control
      ;;
  esac
  SL_TEST_MESSAGE_NAME="SL_${option}_${user_root}_MESSAGE"
  test_print_trc "Split lock detect:${option}"
  test_print_trc "User or root:${user_root}"
  test_print_trc "Message to check:${!SL_TEST_MESSAGE_NAME}"
}

# Call test app sl_test to check if split lock is expect
user_test()
{
  local split_lock_detect=$1
  local bin_dir_name=""

  # Check bin file is there and log path
  bin_dir_name=$(which $BIN_NAME)
  [ -n "$bin_dir_name" ] || die "Test app $BIN_NAME is not found for execution"
  [ -d "$LOG_PATH" ] || mkdir "$LOG_PATH"

  get_test_message_name "${split_lock_detect}" USER

  # Call test app and output log
  $bin_dir_name > ${LOG_PATH}/${BIN_NAME}.log

  grep -q "${!SL_TEST_MESSAGE_NAME}" ${LOG_PATH}/${BIN_NAME}.log && return 0

  if extract_case_dmesg | grep "${!SL_TEST_MESSAGE_NAME}"; then
    test_print_trc "User test pass"
  else
    die "User test failed, no ${!SL_TEST_MESSAGE_NAME} in dmesg"
  fi

  return 0
}

# Insmod test module to check if split lock is expect
root_test() {
  local split_lock_detect=$1

  lsmod | grep -q ${MOD_NAME} && {
    rmmod ${MOD_NAME}
    test_print_trc "Unload ${MOD_NAME}"
    sleep 1
  }

  get_test_message_name "${split_lock_detect}" ROOT

  [ -n "$SL_TEST_MODULE_DIR_NAME" ] || die "No test module $SL_TEST_MODULE_DIR_NAME"

  insmod "$SL_TEST_MODULE_DIR_NAME" && MOD_STATE=1

  if extract_case_dmesg | grep "${!SL_TEST_MESSAGE_NAME}"; then
    test_print_trc "Root test pass"
  else
    die "Root test failed, no ${!SL_TEST_MESSAGE_NAME} in dmesg"
  fi

  return 0
}

# Call test binary to do cache contending stress
sl_stress_test() {
  local params=$1
  local bin_dir_name=""

  # Check bin file is there and log path
  bin_dir_name=$(which $CACHE_BIN_NAME)
  [ -n "$bin_dir_name" ] || die "Test app $CACHE_BIN_NAME is not found for execution"
  [ -d "$LOG_PATH" ] || mkdir "$LOG_PATH"

  # Call test app and output log
  if $bin_dir_name "$params" > ${LOG_PATH}/${CACHE_BIN_NAME}.log; then
    test_print_trc "cache contenting process pass"
  else
    die "cache contenting process failed"
  fi

  # check dmesg
  if ! extract_case_dmesg | grep "$SL_ON_ROOT_MESSAGE"; then
    test_print_trc "test pass"
  else
    die "Issue detected, failed"
  fi

  return 0
}
