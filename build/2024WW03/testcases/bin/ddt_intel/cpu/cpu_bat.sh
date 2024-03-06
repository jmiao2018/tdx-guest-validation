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
# File:         cpu_bat.sh
#
# Description:  it's for cpu bat test
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      August 7 2017 - created - Pengfei Xu

# @desc check cpu info and cpu id
# @returns Fail if return code is non-zero

source "cpu_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-n NAME][-f INFO_NAME][-p CPU_PARM][-h]
  -n  Test CPU feature name like umip
  -f  Test CPU info name like umip
  -p  Test CPU id parameter, like "7 1 0 1 c 2" for umip
  -k  Kconfig check like CONFIG_PERF_EVENTS_INTEL_BM=y
  -s  Sysfs file check like "/sys/devices/intel_bm/threshold=127"
  -h  show This
__EOF
}

while getopts :n:f:p:k:d:s:h arg
do
  case $arg in
    n)
      TEST_NAME=$OPTARG
      test_print_trc "Test $TEST_NAME:"
      ;;
    f)
      CPU_FUNC=$OPTARG
      cpu_info_check "$CPU_FUNC"
      ;;
    p)
      CPU_PARM=$OPTARG
      test_print_trc "Parameter: $CPU_PARM"
      cpu_id_check "$CPU_PARM"
      ;;
    k)
      CONFIG=$OPTARG
      CONFIG_NAME=$(echo "$CONFIG" | cut -d '=' -f1)
      CONFIG_RESULT=$(echo "$CONFIG" | cut -d '=' -f2)
      test_any_kconfig_match "$CONFIG_NAME" "$CONFIG_RESULT" || \
        die "None of $CONFIG_NAMES matches $CONFIG_RESULT"
      ;;
    d)
      DMESG_KEYWORD=$OPTARG
      full_dmesg_check "$DMESG_KEYWORD"
      ;;
    s)
      SYSFS=$OPTARG
      SYSFS_NAME=$(echo "$SYSFS" | cut -d '=' -f1)
      # get 1st match '=' behind string
      SYSFS_RESULT=$(echo "$SYSFS" | sed -n 's/.[^\=]*.//1p')
      sysfs_check "$SYSFS_NAME" "$SYSFS_RESULT"
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

exec_teardown
