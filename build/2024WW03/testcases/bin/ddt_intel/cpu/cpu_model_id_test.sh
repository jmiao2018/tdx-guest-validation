#!/bin/bash

# SPDX-License-Identifier: GPL-2.0
# Author: Ammy, Yi <ammy.yi@intel.com>
# It's for CPU model ID function tests

source "common.sh"
: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}


cpu_model_id_check() {
  CPU_MODLE_ID=175
##for SRF
  MODELID=$(lscpu | grep Model: |  head -1 | awk '{print $2}')
  test_print_trc "MODELID=$MODELID, CPU_MODLE_ID=${CPU_MODLE_ID}!"
  if [ "$MODELID" -ne $CPU_MODEL_ID ] ; then
    die "CPU Model ID is not correct!"
  fi
}

while getopts :t:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    H)
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

cpu_model_id_check
# Call teardown for passing case
exec_teardown
