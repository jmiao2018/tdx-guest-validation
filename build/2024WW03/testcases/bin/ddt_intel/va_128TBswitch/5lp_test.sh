#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2019, Intel - http://www.intel.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
###############################################################################

############################ CONTRIBUTORS #####################################
# @Author   Shen, Furongx <furongx.shen@intel.com>
#
# Mar, 06, 2019. Shen, Furongx <furongx.shen@intel.com>
#     - Initial version, calling va_128TBswitch
#       to execute the basic "5-level-page" feature basic test

############################ DESCRIPTION ######################################

# @desc     This script is based on va_128TBswitch
#           to execute the basic "5-level-page" feature basic test
# @returns
# @history  2019-03-06: First version

############################# FUNCTIONS #######################################
source "common.sh"
source "st_log.sh"

usage() {
 cat <<__EOF
 usage: ./${0##*/} [-r CASE to run] [-h Help]
 -r BASIC_TEST|HUGETLB_TEST|KCONFIG_TEST  CASE to run
 -h Help        print this usage
__EOF
}

run_test() {
  local FEATURE_NAME="5-level-page"

  if [ "$1" == "BASIC_TEST" ]; then
    test_print_trc "Begin to run $FEATURE_NAME BASIC_TEST"
    va_128TBswitch || die "$FEATURE_NAME BASIC_TEST check failed"
    test_print_trc "double check $FEATURE_NAME BASIC_TEST"
    va_128TBswitch | grep -qw "FAILED" && die "$FEATURE_NAME BASIC_TEST check failed"
    test_print_trc "$FEATURE_NAME BASIC_TEST check pass"
  elif [ "$1" == "HUGETLB_TEST" ]; then
    test_print_trc "Begin to run $FEATURE_NAME HUGETLB_TEST"
    va_128TBswitch --run-hugetlb || die "$FEATURE_NAME HUGETLB_TEST check failed"
    test_print_trc "double check $FEATURE_NAME HUGETLB_TEST"
    va_128TBswitch --run-hugetlb | grep -qw "FAILED" && die "$FEATURE_NAME HUGETLB_TEST check failed"
    test_print_trc "$FEATURE_NAME HUGETLB_TEST check pass"
  elif [ "$1" == "KCONFIG_TEST" ]; then
    test_print_trc "Begin to run $FEATURE_NAME KCONFIG_TEST"
    test_kconfigs "y" "CONFIG_X86_5LEVEL" || die "$FEATURE_NAME KCONFIG_TEST check failed"
    test_print_trc "$FEATURE_NAME KCONFIG_TEST check pass"
  else
    die "Invalid argument."
  fi
}

############################# DO THE WORK #######################################
while getopts :r:h arg; do
  case $arg in
    r)
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
  BASIC_TEST)
    run_test "BASIC_TEST"
    ;;
  HUGETLB_TEST)
    run_test "HUGETLB_TEST"
    ;;
  KCONFIG_TEST)
    run_test "KCONFIG_TEST"
    ;;
  *)
    usage && exit 1
    ;;
esac
