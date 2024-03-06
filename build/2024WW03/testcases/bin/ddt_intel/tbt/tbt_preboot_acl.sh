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
# File:         tbt_preboot_acl.sh
#
# Description:  check thunderbolt preboot acl function works well or not
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      March 11 2018 - created - Pengfei Xu

# @desc test thunderbolt in preboot acl only in user/secure mode
# @returns Fail if return code is non-zero

source "tbt_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-s SCENARIO][-h]
  -s  SCENARIO such as acl_check, act_clean, acl_wrong and so on
  -h  show This
__EOF
}

main() {
  check_auto_connect
  # already auto connect, if still no tbt mode detect, will fail the case
  check_security_mode

  case $SCENARIO in
    acl_check)
      preboot_acl_check
      ;;
    acl_clean)
      acl_clean
      ;;
    acl_clean_plug)
      acl_clean_plug
      ;;
    acl_wrong)
      acl_wrong_set
      ;;
    acl_set_first)
      acl_set_first
      ;;
    acl_clean_recover)
      acl_clean
      acl_clean_plug
      ;;
    acl_set_all)
      acl_set_all
      ;;
    *)
      usage && exit 1
      ;;
  esac

  fail_dmesg_check
}

while getopts ':s:h' flag; do
  case ${flag} in
    s)
      SCENARIO=$OPTARG
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
exec_teardown
