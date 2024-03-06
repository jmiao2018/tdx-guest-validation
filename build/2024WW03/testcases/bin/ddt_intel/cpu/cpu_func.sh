#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Author: Pengfei, Xu <pengfei.xu@intel.com>
# It's for CPU common function tests
#

source "cpu_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-n BIN_NAME][-s speed|msr][-p parameter][-h]
  -n  Test cpu bin name or module name like "sync_core_timing.ko"
  -s  Test scenario, like "driver"
  -p  Parameter like "PASS"
  -h  show This
__EOF
}

main() {

  case $SCENARIO in
    driver)
      driver_test "$BIN_NAME"
      dmesg_check "$PARM" "$CONTAIN"
      ;;
    *)
      usage && exit 1
      ;;
  esac
}

while getopts :n:s:p:h arg; do
  case $arg in
    n)
      BIN_NAME=$OPTARG
      ;;
    s)
      SCENARIO=$OPTARG
      ;;
    p)
      PARM=$OPTARG
      ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 0
      ;;
  esac
done

main
exec_teardown
