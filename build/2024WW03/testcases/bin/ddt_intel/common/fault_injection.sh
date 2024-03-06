#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2019, Intel Corporation

source "common.sh"

setup_failslab() {
  local FAILTYPE=failslab
  test_print_trc "Setting up $FAILTYPE ..."
  [[ -d /sys/kernel/debug/$FAILTYPE ]] || die "$FAILTYPE is not set"
  echo Y > /sys/kernel/debug/$FAILTYPE/task-filter
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo 2 > /sys/kernel/debug/$FAILTYPE/probability
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo -1 > /sys/kernel/debug/$FAILTYPE/times
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo 0 > /sys/kernel/debug/$FAILTYPE/space
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo 2 > /sys/kernel/debug/$FAILTYPE/verbose
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo Y > /sys/kernel/debug/$FAILTYPE/ignore-gfp-wait
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
}

setup_fail_page_alloc() {
  local FAILTYPE=fail_page_alloc
  test_print_trc "Setting up $FAILTYPE ..."
  [[ -d /sys/kernel/debug/$FAILTYPE ]] || die "$FAILTYPE is not set"
  echo Y > /sys/kernel/debug/$FAILTYPE/task-filter
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo 2 > /sys/kernel/debug/$FAILTYPE/probability
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo -1 > /sys/kernel/debug/$FAILTYPE/times
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo 0 > /sys/kernel/debug/$FAILTYPE/space
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo 2 > /sys/kernel/debug/$FAILTYPE/verbose
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo Y > /sys/kernel/debug/$FAILTYPE/ignore-gfp-wait
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo Y > /sys/kernel/debug/$FAILTYPE/ignore-gfp-highmem
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
}

setup_fail_futex() {
  local FAILTYPE=fail_futex
  test_print_trc "Setting up $FAILTYPE ..."
  [[ -d /sys/kernel/debug/$FAILTYPE ]] || die "$FAILTYPE is not set"
  echo Y > /sys/kernel/debug/$FAILTYPE/task-filter
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo 2 > /sys/kernel/debug/$FAILTYPE/probability
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo -1 > /sys/kernel/debug/$FAILTYPE/times
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo 0 > /sys/kernel/debug/$FAILTYPE/space
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
  echo 2 > /sys/kernel/debug/$FAILTYPE/verbose
  [[ $? -eq 0 ]] || die "Setup $FAILTYPE failed"
}

disable_fault_inj() {
  local FAILTYPE=failslab
  echo 0 > /sys/kernel/debug/$FAILTYPE/probability
  FAILTYPE=fail_page_alloc
  echo 0 > /sys/kernel/debug/$FAILTYPE/probability
  FAILTYPE=fail_futex
  echo 0 > /sys/kernel/debug/$FAILTYPE/probability
}

faulty_system() {
  bash -c "echo 1 > /proc/self/make-it-fail && exec $*"
  test_print_trc "retult: $?"
}

# load unload 1-3 dirvers 100 times with fault injected
# $1,$2,$3: driver(s) to be inserted/removed. $2/$3 is optional.
#           Insert order - 1,2,3
#           Remove order - 3,2,1
load_unload_driver_100() {
  if [[ $# -eq 0 ]]; then
  	test_print_err "Usage: $0 module_1 [ module_2 module_3 ]"
  	exit 1
  fi

  local m1=$1
  local m2=""
  local m3=""
  [[ $# -le 2 ]] && m2=$2
  [[ $# -le 3 ]] && m3=$3

  echo "7" > /proc/sys/kernel/printk
  setup_failslab
  setup_fail_page_alloc
  setup_fail_futex

  for i in {1..10}; do
    test_print_trc "time $i/100 (no fault injected)"
    for m in $m1 $m2 $m3; do
      test_print_trc "inserting $m ..."
      modprobe "$m"
      test_print_trc "ret: $?"
      sleep 1
    done
    for m in $m3 $m2 $m1; do
      test_print_trc "removing $m ..."
      modprobe -r "$m"
      test_print_trc "ret: $?"
      sleep 1
    done
  done
  for i in {11..100}; do
    test_print_trc "time $i/100"
    for m in $m1 $m2 $m3; do
      test_print_trc "inserting $m ..."
      faulty_system modprobe "$m"
      test_print_trc "ret: $?"
      sleep 1
    done
    for m in $m3 $m2 $m1; do
      test_print_trc "removing $m ..."
      faulty_system modprobe -r "$m"
      test_print_trc "ret: $?"
      sleep 1
    done
  done

  disable_fault_inj
  return 0
}
