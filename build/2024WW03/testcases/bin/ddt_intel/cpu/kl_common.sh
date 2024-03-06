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
# File:         kl_common.sh
#
# Description:  common file for key locker test
#

# @desc provide common functions for key locker
# @returns Fail if return code is non-zero (value set not found)

source "common.sh"
source "dmesg_functions.sh"

CRYPTO_MOD_NAME="aeskl_intel"
CRYPTO_TEST_MOD_NAME="kl_crypt_test"
IWKEY_TEST_MOD_NAME="load_iwkey_module"
CRYPTO_MOD_STATE=0
CRYPTO_TEST_MOD_STATE=0
BIN_NAME="kl_test"
KL_LOG_PATH="/tmp/kl"

teardown_handler="kl_teardown"
kl_teardown() {
  # unload test module if it is loaded
  if [[ ${CRYPTO_TEST_MOD_STATE} -ne 0 ]]; then
    lsmod | grep -q ${CRYPTO_TEST_MOD_NAME} && {
      rmmod ${CRYPTO_TEST_MOD_NAME}
      test_print_trc "remove ${CRYPTO_TEST_MOD_NAME}"
      sleep 1
    }
  fi

  lsmod | grep -q ${IWKEY_TEST_MOD_NAME} && {
    rmmod ${IWKEY_TEST_MOD_NAME}
    test_print_trc "remove ${IWKEY_TEST_MOD_NAME}"
    sleep 1
  }

  # unload crypto module if it is loaded
  if [[ ${CRYPTO_MOD_STATE} -ne 0 ]]; then
    lsmod | grep -q ${CRYPTO_MOD_NAME} && {
      modprobe -r ${CRYPTO_MOD_NAME}
      test_print_trc "remove ${CRYPTO_MOD_NAME}"
      sleep 1
    }
  fi
}

# Check load and unload mod thunderbolt
# $1: mode name
# Result: 0 for true, otherwise false or die
load_unload_mod() {
  local load_times=$1

  load_unload_module.sh -c -d "$CRYPTO_MOD_NAME" &&
    load_unload_module.sh -u -d "$CRYPTO_MOD_NAME"

  for((i=0;i<$load_times;i++)); do
    test_print_trc "Loading and Unloading Module #\"$i\"..."
    load_unload_module.sh -l -d "$CRYPTO_MOD_NAME"
    sleep 1
    load_unload_module.sh -c -d "$CRYPTO_MOD_NAME" || die "Load $CRYPTO_MOD_NAME fail"

    load_unload_module.sh -u -d "$CRYPTO_MOD_NAME"
    sleep 1
    load_unload_module.sh -c -d "$CRYPTO_MOD_NAME" && die "Unload $CRYPTO_MOD_NAME fail"
  done
  return 0
}

# If crypto is on, return 0
# If crypto is not modprobe, modprobe it
# Input: None
# Return: 0 for true, otherwise false or die
crypt_mod_check() {
  grep -q "aeskl_intel" /proc/crypto &> /dev/null && return 0

  do_cmd "modprobe $CRYPTO_MOD_NAME"
  CRYPTO_MOD_STATE=0

  test_print_trc "Modprobe $CRYPTO_MOD_NAME success"
  return 0
}

# If crypto test module is not insmod, insmod it
# Input: None
# Return: 0 for true, otherwise false or die
crypt_test_setup() {
  local test_mod_dir_name=""

  lsmod | grep -q ${CRYPTO_TEST_MOD_NAME} &> /dev/null

  if [[ $? -ne 0 ]]; then
    # Check test module is in packge
    test_mod_dir_name=$(which ${CRYPTO_TEST_MOD_NAME}.ko)
    [ -n "$test_mod_dir_name" ] || die "No ${CRYPTO_TEST_MOD_NAME}.ko in ltp-ddt package"
    do_cmd "insmod $test_mod_dir_name"
    CRYPTO_TEST_MOD_STATE=0
  fi

  test_print_trc "${CRYPTO_TEST_MOD_NAME}.ko load success"
  return 0
}

# Check this crypto could support the function which contain the parameter
# $1: Parameter should be support in crypto
# Return: 0 for true, otherwise false
crypto_info_check() {
  local crypto_func=$1

  # crypto module and test module should be loaded
  crypt_mod_check
  # Why put crypt_test_setup here, not in crypto_func_test? Because test module
  # is not signed it will cause 1 function test fail when first time insmod it.
  # Will modify it if there is better better solutions
  crypt_test_setup

  [ -n "$crypto_func" ] || die "crypto info check name is null:$crypto_func"
  grep -q "$crypto_func" /proc/crypto || block_test "crypto not support:$crypto_func"

  test_print_trc "/proc/crypto contain '$crypto_func'"
  return 0
}

# Call kl_test to verify key locker functions
# Input: None
# Return: 0 for true, otherwise false or die
crypto_func_test() {
  local crypto_params=$1
  local bin_dir_name=""
  local case_dmesg_log=""
  local success_result=""
  local failed_result=""

  # Check bin file is there and log path
  bin_dir_name=$(which $BIN_NAME)
  [ -n "$bin_dir_name" ] || die "Test app $BIN_NAME is not found for execution"
  [ -d "$KL_LOG_PATH" ] || mkdir "$KL_LOG_PATH"

  # Call test app and output log
  $bin_dir_name $crypto_params > ${KL_LOG_PATH}/${BIN_NAME}.log

  # call extract_case_dmesg to get case dmesg
  case_dmesg_log=$(extract_case_dmesg -f)
  [[ -e "$LOG_PATH/$case_dmesg_log" ]] \
    || die "No case dmesg:$LOG_PATH/$case_dmesg_log exist"
  # check dmesg function success
  success_result=$(grep -c "validation: success\|validation: matched" "$LOG_PATH/$case_dmesg_log")
  failed_result=$(grep -c "failed\|validation: mismatched" "$LOG_PATH/$case_dmesg_log")

  if [[ $success_result -ne 0 ]] && [[ $failed_result -eq 0 ]]; then
    test_print_trc "crypto test pass $(cat "$LOG_PATH"/"$case_dmesg_log")"
  else
    die "crypto test failedi $(cat "$LOG_PATH"/"$case_dmesg_log")"
  fi

  return 0
}

# Check if rdmsr and wrmsr installed and worked.
# Input: None
# Return: 1 not installed/worked. 0 works.
function checking_msr_precondition()
{
  command -v rdmsr &> /dev/null && command -v wrmsr &> /dev/null|| {
    test_print_trc "rdmsr-tool is not installed,BLOCKED"
  return 1
  }
  do_cmd "modprobe msr"
  return 0
}

# Read IA32_COPY_STATUS, it is to check status after IA32_COPY_LOCAL_TO_PLATFORM
# Input: $1 cpu process number 0, 1, etc
# Return: 0 for true - IA32_COPY_STATUS[0] is set
iwkey_backup_status_check() {
  local cpu=$1
  local MSR_VAL=""

  do_cmd checking_msr_precondition

  MSR_VAL=$(rdmsr -p "$cpu" 0x990 2>/dev/null)
  [[ "x$MSR_VAL" == "x1" ]] || die "backup status IA32_COPY_STATUS is $MSR_VAL, expect 1.FAILED"
}

# Read IA32_IWKeyBackup_Status, it is to check status after IA32_COPY_PLATFORM_TO_LOCAL
# Input: $1 cpu process number 0, 1, etc
# Return: 0 for true - IA32_IWKeyBackup_Status no errors
iwkey_restore_status_check() {
  local cpu=$1
  local MSR_VAL=""

  do_cmd checking_msr_precondition

  MSR_VAL=$(rdmsr -p "$cpu" 0x991 2>/dev/null)
  [[ "x$MSR_VAL" == "x9" ]] || die "restore status IA32_IWKeyBackup_Status is $MSR_VAL, expect b.FAILED"
}

# Write IA32_COPY_LOCAL_TO_PLATFORM to back up key to PTT
# Input: $1 cpu process number 0, 1, etc
# Return: 0 for true - write no errors
iwkey_backup_key() {
  local cpu=$1

  do_cmd checking_msr_precondition

  do_cmd "wrmsr -p $cpu 0xd91 0x1"
}

# Write IA32_COPY_PLATFORM_TO_LOCAL to restore key to local
# Input: $1 cpu process number 0, 1, etc
# Return: 0 for true - write no errors
iwkey_restore_key() {
  local cpu=$1

  do_cmd checking_msr_precondition

  do_cmd "wrmsr -p $cpu 0xd92 0x1"
}

# Call kernel test module to refresh iwkey
# Input: $1 cpu process number 0, 1, etc
# Return: 0 for true, otherwise false or die
refresh_iwkey() {
  local cpu=$1
  local test_mod_dir_name=""
  local bin_dir_name=""

  lsmod | grep -q ${IWKEY_TEST_MOD_NAME} &> /dev/null

  if [[ $? -ne 0 ]]; then
    # Check test module is in packge
    test_mod_dir_name=$(which ${IWKEY_TEST_MOD_NAME}.ko)
    [ -n "$test_mod_dir_name" ] || die "No ${IWKEY_TEST_MOD_NAME}.ko in ltp-ddt package"
    do_cmd "insmod $test_mod_dir_name"
  fi

  bin_dir_name=$(which "load_iwkey")
  [ -n "$bin_dir_name" ] || die "Test app load_iwkey is not found for execution"
  do_cmd "$bin_dir_name cpu$cpu"
}

# Call kernel test module to refresh iwkey
# Input: $1 cpu process number 0, 1, etc
# Return: 0 for true, otherwise false or die
encode_key() {
  local cpu=$1
  local logfile=$2
  local bin_dir_name=""

  bin_dir_name=$(which "encode_key")
  [ -n "$bin_dir_name" ] || die "Test app encode_key is not found for execution"

  do_cmd "taskset -c $cpu $bin_dir_name > $logfile"
}

# Call kl_test to verify key locker functions
# Input: None
# Return: 0 for true, otherwise false or die
iwkey_func_test() {
  local iwkey_params=$1
  local outlog1="$KL_LOG_PATH/case_${iwkey_params}_out1.log"
  local outlog2="$KL_LOG_PATH/case_${iwkey_params}_out2.log"

  [ -d "$KL_LOG_PATH" ] || mkdir "$KL_LOG_PATH"

  case $iwkey_params in
    1)
      test_print_trc "IWKEY cpu0 default backup/restore status"
      iwkey_backup_status_check  0
      iwkey_restore_status_check 0
      ;;
    2)
      test_print_trc "IWKEY cpu1 default backup/restore status"
      iwkey_backup_status_check  1
      iwkey_restore_status_check 1
      ;;
    3)
      test_print_trc "IWKEY cpu0 backup status after copy local handler to platform"
      iwkey_backup_key 0
      iwkey_backup_status_check  0
      ;;
    4)
      test_print_trc "IWKEY cpu0 restore status after restore from platform"
      iwkey_restore_key 0
      iwkey_restore_status_check 0
      ;;
    5)
      test_print_trc "IWKEY cpu1 backup status after copy local handler to platform"
      iwkey_backup_key 1
      iwkey_backup_status_check  1
      ;;
    6)
      test_print_trc "IWKEY cpu1 restore status after restore from platform"
      iwkey_restore_key 1
      iwkey_restore_status_check 1
      ;;
    7)
      test_print_trc "IWKEY cpu0 backup/restore test"
      encode_key 0 "$outlog1"
      refresh_iwkey 0
      encode_key 0 "$outlog2"
      diff "$outlog1" "$outlog2" && die "Expect cpu0 KL handler is diff, but it is same after refresh"
      iwkey_backup_key 0
      # refresh cpu0 local KL handler again
      refresh_iwkey 0
      encode_key 0 "$outlog1"
      diff "$outlog1" "$outlog2" && die "Expect cpu0 KL handler is diff, but it is same after refresh"
      iwkey_restore_key 0
      encode_key 0 "$outlog1"
      diff "$outlog1" "$outlog2" || die "Expect cpu0 KL handler is same, but it is diff after restored"
      ;;
    8)
      test_print_trc "IWKEY cpu1 backup/restore test"
      encode_key 1 "$outlog1"
      refresh_iwkey 1
      encode_key 1 "$outlog2"
      diff "$outlog1" "$outlog2" && die "Expect cpu1 KL handler is diff, but it is same after refresh"
      iwkey_backup_key 1
      refresh_iwkey 1
      # refresh cpu0 local KL handler again
      encode_key 1 "$outlog1"
      diff "$outlog1" "$outlog2" && die "Expect cpu1 KL handler is diff, but it is same after refresh"
      iwkey_restore_key 1
      encode_key 1 "$outlog1"
      diff "$outlog1" "$outlog2" || die "Expect cpu1 KL handler is same, but it is diff after restored"
      ;;
    9)
      test_print_trc "IWKEY cpu0 backup and cpu1 restore test"
      # Pre-condition cpu0 and cpu1 KL handler is difference
      refresh_iwkey 0
      refresh_iwkey 1
      encode_key 0 "$outlog1"
      encode_key 1 "$outlog2"
      diff "$outlog1" "$outlog2" && die "Expect cpu0 KL handler is different from cpu1, but it is same after refresh"
      iwkey_backup_key 0
      iwkey_restore_key 1
      encode_key 1 "$outlog2"
      diff "$outlog1" "$outlog2" || die "Expect cpu1 KL handler is same as cpu0, but it is diff after restored"
      ;;
    10)
      test_print_trc "IWKEY cpu1 backup and cpu0 restore test"
      # Pre-condition cpu0 and cpu1 KL handler is difference
      refresh_iwkey 0
      refresh_iwkey 1
      encode_key 0 "$outlog1"
      encode_key 1 "$outlog2"
      diff "$outlog1" "$outlog2" && die "Expect cpu0 KL handler is different from cpu1, but it is same after refresh"
      iwkey_backup_key 1
      iwkey_restore_key 0
      encode_key 0 "$outlog1"
      diff "$outlog1" "$outlog2" || die "Expect cpu0 KL handler is same as cpu1, but it is diff after restored"
      ;;
    11)
      test_print_trc "freeze test,refresh iwkey on cpu0"
      refresh_iwkey 0

      test_print_trc "execute encode key cpu0"
      encode_key 0 "$outlog1"

      test_print_trc "freeze test"
      suspend_test "freeze"

      test_print_trc "backup and restore, check status"
      iwkey_backup_status_check  0
      iwkey_restore_status_check 0

      test_print_trc "execute encode key cpu0 after freeze"
      encode_key 0 "$outlog2"

      test_print_trc "check encode key results from origin/after freeze"
      diff "$outlog1" "$outlog2" || die "iwkey freeze test fail"
      ;;
    12)
      test_print_trc "suspend test, refresh iwkey on cpu1"
      refresh_iwkey 1

      test_print_trc "execute encode key cpu1"
      encode_key 1 "$outlog1"

      test_print_trc "suspend test"
      suspend_test "deep"

      test_print_trc "backup and restore, check status"
      iwkey_backup_status_check  1
      iwkey_restore_status_check 1

      test_print_trc "execute encode key cpu1 after suspend"
      encode_key 1 "$outlog2"

      test_print_trc "check encode key results from origin/after suspend"
      diff "$outlog1" "$outlog2" || die "iwkey suspend test fail"
      ;;
    13)
      test_print_trc "resume test,refresh iwkey on cpu0"
      refresh_iwkey 0

      test_print_trc "execute encode key cpu0"
      encode_key 0 "$outlog1"

      test_print_trc "resume test"
      suspend_test "disk"

      test_print_trc "backup and restore, check status"
      iwkey_backup_status_check  0
      iwkey_restore_status_check 0

      test_print_trc "execute encode key cpu0 after resume"
      encode_key 0 "$outlog2"

      test_print_trc "check encode key results from origin/after resume"
      diff "$outlog1" "$outlog2" || die "iwkey freeze test fail"
      ;;
    :)
      #skip if it is not pci bridge
      test_print_trc "Invalid input"
      ;;
  esac

  return 0
}
