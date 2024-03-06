#!/bin/bash
###############################################################################
##                                                                           ##
## Copyright (c) 2018, Intel Corporation.                                    ##
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
# File:         tpm_bat.sh
#
# Description:  it's for tpm bat test
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      January 3 2018 - created - Pengfei Xu

# @returns Fail if return code is non-zero

source "tpm_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-k CONTENT][-s SYSFS_CONTENT][-h]
  -k  Kconfig check like CONFIG_TCG_TPM=y
  -s  Sysfs file check like "/sys/devices/xxx=xxx"
  -h  show This
__EOF
}

while getopts :k:s:h arg
do
  case $arg in
    k)
      CONFIG=$OPTARG
      CONFIG_NAME=$(echo "$CONFIG" | cut -d '=' -f1)
      CONFIG_RESULT=$(echo "$CONFIG" | cut -d '=' -f2)
      test_kconfigs "$CONFIG_RESULT" "$CONFIG_NAME" \
        || die "$CONFIG_NAME not set $CONFIG_RESULT"
      ;;
    s)
      SYSFS=$OPTARG
      SYSFS_NAME=$(echo "$SYSFS" | cut -d '=' -f1)
      SYSFS_RESULT=$(echo "$SYSFS" | cut -d '=' -f2)
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
