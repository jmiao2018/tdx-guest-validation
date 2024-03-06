#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2020 Intel Corporation
#
# Description:  Accelerator Interfacing Architecture (AIA) test script

source "aia_common.sh"

############################# FUNCTIONS #######################################

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID][-p TEST_PARM][-h]
  -t  TESTCASE_ID
  -p  Test parameters
  -h  show This
__EOF
}

main() {
  case $TESTCASE_ID in
    aia_test)
      aia_instruction_test "$TEST_PARM"
      ;;
    *)
      usage
      die "Invalid Test ID!"
      ;;
    esac
  return 0
}

while getopts :t:p:h arg
do
  case $arg in
    t)
      TESTCASE_ID=$OPTARG
      ;;
    p)
      TEST_PARM=$OPTARG
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
