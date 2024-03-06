#!/bin/bash

###############################################################################
##                                                                           ##
## Copyright (c) 2017, Intel Corporation.                                    ##
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
# File:         powerclamp_module_tests.sh
#
# Description:  Basic module tests on Intel Powerclamp
#
# Authors:      Jerry C. Wang - jerry.c.wang@intel.com
#
# History:      Jun 28 2017 - Created - Jerry C. Wang
#

source "powerclamp_common.sh"

ENABLE_PATTERN="Start idle injection"
DISABLE_PATTERN="Stop forced idle injection"

usage() {
  cat <<-EOF >&2
  usage: ./${0##*/}  [-n] [-l] [-r] [-w VALUE] [-d MESG_PATTERN] [-h]
    -n  Negative tests
    -l  Load and unload powerclamp modules
    -r  Read value from powerclamp sysfs
    -w  Write value to powerclamp sysfs
    -d  Check powerclamp dmesg information
    -h  Show this
EOF
  exit 0
}

teardown_handler="powerclamp_teardown"

powerclamp_teardown() {
  load_unload_module.sh -u -d "$MODULE_NAME"
}

main() {

  if [[ $LOAD_UNLOAD_MODULE -eq 1 ]]; then
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
    do_cmd "load_unload_module.sh -u -d $MODULE_NAME"
  fi

  if [[ $READ_SYSFS -eq 1 ]]; then
    state=$(read_powerclamp_sysfs "$CLAMP_STATUS")
    check=$(echo "$state" | grep -E "^\-?[0-9]?+$")
    [[ -n $check ]] || die "Unable to read valid value from sysfs (val=$state)"
    test_print_trc "Current Powerclamp Status: $check"
  fi

  if [[ $WRITE_SYSFS -eq 1 ]]; then
    write_powerclamp_sysfs "$CLAMP_STATUS" "$WRITE_VAL" "$NEG_RES"
  fi

  if [[ $CHK_DMESG -eq 1 ]]; then
    enable_idle_injection
    last_dmesg=$(dmesg | grep "$MODULE_NAME" | tail -1)
    check=$(echo "$last_dmesg" | grep "$ENABLE_PATTERN")
    test_print_trc "$check"
    [[ -n $check ]] || die "Unable to find dmesg pattern: $ENABLE_PATTERN"

    disable_idle_injection
    last_dmesg=$(dmesg | grep "$MODULE_NAME" | tail -1)
    check=$(echo "$last_dmesg" | grep "$DISABLE_PATTERN")
    test_print_trc "$check"
    [[ -n $check ]] || die "Unable to find dmesg pattern: $DISABLE_PATTERN"
  fi
}


: "${NEG_RES:=0}"
: "${LOAD_UNLOAD_MODULE:=0}"
: "${READ_SYSFS:=0}"
: "${WRITE_SYSFS:=0}"
: "${WRITE_VAL:=50}"
: "${CHK_DMESG:=0}"

while getopts 'nlrw:dhH' flag; do
  case ${flag} in
    n)
      NEG_RES=1
      ;;
    l)
      LOAD_UNLOAD_MODULE=1
      ;;
    r)
      READ_SYSFS=1
      ;;
    w)
      WRITE_SYSFS=1
      WRITE_VAL="${OPTARG}"
      ;;
    d)
      CHK_DMESG=1
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

main "$@"
powerclamp_teardown
