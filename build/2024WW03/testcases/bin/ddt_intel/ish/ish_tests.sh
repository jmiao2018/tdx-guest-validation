#!/usr/bin/env bash
##
## Copyright (c) 2017, Intel Corporation.
##
## This program is free software; you can redistribute it and/or modify it
## under the terms and conditions of the GNU General Public License,
## version 2, as published by the Free Software Foundation.
##
## This program is distributed in the hope it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
## more details.
##

# File: ish_tests.sh
#
# Description:  This script implement tests for ish component.
#
# Authors:      Yixin Zhang - yixin.zhang@intel.com
#
# History:      Aug 10 2017 - Creation - Yixin Zhang


source "common.sh"
source "dmesg_functions.sh"

ISH_DRIVER='intel_ish_ipc'
INIT_STATUS='0' #driver init status, 0 - unloaded, 1 - loaded

usage() {
  cat <<__EOF
  usage: ./${0##*/} [testcase]
    testcase: dmesg_check/load_unload_driver
__EOF
}

#ISH_XS_BAT_DMESG
dmesg_check_ish_ipc() {
  if check_dmesg_keyword intel_ish_ipc ; then
    return 0
  elif ! is_boot_dmesg_included; then
    test_print_wrg "Boot demsg is not included in current dmesg."
    block_test
  else
    die "Keyword \"intel_ish_ipc\" not found in dmesg!"
  fi
}

#ISH_XS_BAT_LOAD_UNLOAD_DRIVER
load_unload_ish_ipc() {
  is_kmodule_builtin "$ISH_DRIVER" && {
    test_print_trc "Driver $ISH_DRIVER is built-in, skipping test."
    skip_test
  }

  if load_unload_module.sh -c -d $ISH_DRIVER ; then
    INIT_STATUS='1'
    load_unload_module.sh -u -d $ISH_DRIVER || die "Unload $ISH_DRIVER failed!"
    load_unload_module.sh -l -d $ISH_DRIVER || die "Load $ISH_DRIVER failed!"
  else
    INIT_STATUS='0'
    load_unload_module.sh -l -d $ISH_DRIVER || die "Load $ISH_DRIVER failed!"
    load_unload_module.sh -u -d $ISH_DRIVER || die "Unload $ISH_DRIVER failed!"
  fi
}

ish_teardown() {
  is_kmodule_builtin "$ISH_DRIVER" && return 0

  if [[ $INIT_STATUS == '0' ]] && load_unload_module.sh -c -d $ISH_DRIVER; then
    test_print_trc "Inital status of driver $ISH_DRIVER is unloaded, unloading it."
    load_unload_module.sh -u -d $ISH_DRIVER \
      || test_print_err "Unload $ISH_DRIVER failed!"
  elif [[ $INIT_STATUS == '1' ]] && ! load_unload_module.sh -c -d $ISH_DRIVER; then
    test_print_trc "Inital status of driver $ISH_DRIVER is loaded, loading it."
    load_unload_module.sh -l -d $ISH_DRIVER \
      || test_print_err "Load $ISH_DRIVER failed!"
  fi
}

main() {
  [[ $# -eq 1 ]] || die "1 and only 1 argument is required."
  TC_ID=$1

  case $TC_ID in
    dmesg_check)
      dmesg_check_ish_ipc
      ;;
    load_unload_driver)
      teardown_handler='ish_teardown'
      load_unload_ish_ipc
      ;;
    *)
      usage
      die "Testcase ID $TC_ID is not supported!"
  esac
}

main "$@"
# Call teardown for passing case
exec_teardown
