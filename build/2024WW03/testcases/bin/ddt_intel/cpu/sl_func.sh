#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2020 Intel Corporation
#
# Description:  Split lock function test script

source "sl_common.sh"
source "cpu_common.sh"

############################# FUNCTIONS #######################################

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-p Parameter] [-h]
  -t  Test case ID
  -p  Split lock detect is default off, warn,ratelimit
  -h  show this
__EOF
}

main() {
  # Check if test option is in boot command. Split lock test should have nothing
  if [ "$SPLIT_LOCK_DETECT" == "split_lock_detect=on" ]; then
    if grep -ow "split_lock_detect" "/proc/cmdline"; then
      die "Should be no split_lock_detect option in cmdline"
    fi
  else
    if ! grep -ow "$SPLIT_LOCK_DETECT" "/proc/cmdline"; then
      die "Should be have $SPLIT_LOCK_DETECT in cmdline"
    fi
  fi

  case $TESTCASE_ID in
    split_lock_ctrl)
      split_lock_control
      ;;
    user)
      user_test "$SPLIT_LOCK_DETECT"
      ;;
    root)
      root_test "$SPLIT_LOCK_DETECT"
      ;;
    user_s2idle)
      suspend_test "freeze"
      user_test "$SPLIT_LOCK_DETECT"
      ;;
    root_s2idle)
      suspend_test "freeze"
      root_test "$SPLIT_LOCK_DETECT"
      ;;
    user_s3)
      suspend_test "deep"
      user_test "$SPLIT_LOCK_DETECT"
      ;;
    root_s3)
      suspend_test "deep"
      root_test "$SPLIT_LOCK_DETECT"
      ;;
    user_s4)
      suspend_test "disk"
      user_test "$SPLIT_LOCK_DETECT"
      ;;
    root_s4)
      suspend_test "disk"
      root_test "$SPLIT_LOCK_DETECT"
      ;;
    *)
      usage
      die "Invalid Test ID!"
      ;;
    esac
  return 0
}

################################ DO THE WORK ##################################

TESTCASE_ID=""
SPLIT_LOCK_DETECT=""

while getopts :t:p:h arg; do
  case $arg in
    t)
      TESTCASE_ID=$OPTARG
      ;;
    p)
      SPLIT_LOCK_DETECT=$OPTARG
      ;;
    h)
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

main
exec_teardown
