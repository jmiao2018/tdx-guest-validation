#!/bin/bash
###############################################################################
# Copyright (C) 2021, Intel - http://www.intel.com
#
# SPDX-License-Identifier: GPL-2.0-or-later
###############################################################################

############################ DESCRIPTION ######################################
# @desc     TDX guest attestation test
###############################################################################

source "common.sh"
source "functions.sh"

RESULT_FILE="result.out"
SPEED_FILE="speed.out"
NUM_FILE="rand_num"

usage() {
  cat <<-EOF
  usage: ./${0##*/} [-t CASE to run] [-h Help]
  -t SPECIFIED_CASE to run
  -h print this usage
EOF
}

read_from_urandom() {
  declare -i i=0
  sum_speed=0.0
  echo "Read from /dev/urandom for $1 times with bs=$2 bytes"

  if [[ -f "$SPEED_FILE" ]]; then
    rm -f "$SPEED_FILE"
  fi

  while [[ "$i" -lt "$1" ]]; do
    dd if=/dev/urandom of=$NUM_FILE count=1 bs="$2" 2>$RESULT_FILE
    tail -1 $RESULT_FILE >>$SPEED_FILE
    i+=1
  done

  while IFS= read -r line; do
    # echo "Text read from file: $line"
    speed="$(echo "$line" | rev | cut -d " " -f2 | rev)"
    # without rev
    tag="$(echo "$line" | rev | cut -d " " -f1)"
    # echo $tag

    if [[ "$tag" == "s/Bk" ]]; then
      speed=$(echo "$speed / 1024" | bc -l)
    fi

    sum_speed=$(echo "$sum_speed + $speed" | bc -l)
  done <$SPEED_FILE

  echo "sum_speed: $sum_speed"
  avg_speed=$(echo "scale=10; $sum_speed / $1" | bc)
  echo "avg_speed: $avg_speed"
}

rng_stress() {
  declare -i loop=0
  declare -i count=10
  declare -i bytes=512

  # loop with different count scale
  while [ $loop -lt 10 ]; do
    read_from_urandom $count $bytes
    count=$((count * 10))
    loop+=1
  done

  count=500
  loop=0
  # loop with different bytes scale
  while [ $loop -lt 20 ]; do
    read_from_urandom $count $bytes
    bytes=$((bytes * 2))
    loop+=1
  done
}

clean_tmp_files() {
  echo "Remove temporary files..."
  if [[ -f "$SPEED_FILE" ]]; then
    rm -f "$SPEED_FILE"
  fi
  if [[ -f "$RESULT_FILE" ]]; then
    rm -f "$RESULT_FILE"
  fi
  if [[ -f "$NUM_FILE" ]]; then
    rm -f "$NUM_FILE"
  fi
}

while getopts :t:h arg; do
  case $arg in
  t)
    TESTCASE=$OPTARG
    ;;
  h)
    usage && exit 0
    ;;
  :)
    test_print_err "Must supply an argument to -$OPTARG."
    usage && exit 1
    ;;
  \?)
    test_print_err "Invalid Option -$OPTARG ignored."
    usage && exit 1
    ;;
  esac
done

case $TESTCASE in
TDX_GUEST_RANDOM_NUMBER_GENERATION)
  test_print_trc "Start TDX guest read from /dev/urandom stress test"
  rng_stress
  if rng_stress ; then
    test_print_trc "TDX guest read from /dev/urandom stress test PASS"
    clean_tmp_files
  else
    test_print_trc "Exit status: $?"
    clean_tmp_files
    die "TDX guest read from /dev/urandom stress test FAILED"
  fi
  ;;
TDX_GUEST_RANDOM_NUMBER_GENERATION_BACKUP)
  # TODO: will finalize after we have one stable TDX-dedicated machine
  test_print_trc "Start TDX guest read from /dev/urandom stress test"
  # copy the rand_loop process to host
  ddt_intel/tdx/tdx_guest_expect_stresshostrng.exp copy
  # start the process stressing the DRNG of host
  ddt_intel/tdx/tdx_guest_expect_stresshostrng.exp start
  rng_stress
  if rng_stress ; then
    test_print_trc "TDX guest read from /dev/urandom stress test PASS"
    clean_tmp_files
  else
    test_print_trc "Exit status: $?"
    clean_tmp_files
    die "TDX guest read from /dev/urandom stress test FAILED"
  fi
  # stop the process stressing the DRNG of host
  # TODO: properly stop the host stress process
  ddt_intel/tdx/tdx_guest_expect_stresshostrng.exp stop
  ;;
TDX_FUNC_GUEST_EBIZZY)
  test_print_trc "Start TDX guest ebizzy test 10s with malloc"
  ./ebizzy -M
  ebizzy_malloc=$?
  test_print_trc "Start TDX guest ebizzy test 10s with mmap"
  ./ebizzy -m
  ebizzy_mmap=$?
  if [[ $ebizzy_malloc == 0 && $ebizzy_mmap == 0 ]]; then
    test_print_trc "TDX guest ebizzy test PASS"
  else
    die "TDX guest ebizzy test FAILED"
  fi
  ;;
TDX_STRESS_GUEST_EBIZZY)
  test_print_trc "Start TDX guest ebizzy test 1800s with malloc"
  ./ebizzy -M -S 1800
  ebizzy_malloc=$?
  test_print_trc "Start TDX guest ebizzy test 1800s with mmap"
  ./ebizzy -m -S 1800
  ebizzy_mmap=$?
  if [[ $ebizzy_malloc == 0 && $ebizzy_mmap == 0 ]]; then
    test_print_trc "TDX guest ebizzy test PASS"
  else
    die "TDX guest ebizzy test FAILED"
  fi
  ;;
:)
  test_print_err "Must specify the test case option by [-t]"
  usage && exit 1
  ;;
\?)
  test_print_err "Input test case option $TESTCASE is not supported"
  usage && exit 1
  ;;
esac
