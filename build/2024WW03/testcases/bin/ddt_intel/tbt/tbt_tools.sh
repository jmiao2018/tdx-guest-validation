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
# File:         tbt_tools.sh
#
# Description:  use tbt tools like tbtadm to check thunderbolt functions
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      March 26 2018 - created - Pengfei Xu

# @returns Fail if return code is non-zero

source "tbt_func.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-s SCENARIO][-h]
  -s  SCENARIO such as acl_check, act_clean, acl_wrong and so on
  -h  show This
__EOF
}

main() {
  local none="none"
  local dp="dponly"
  local swcm_file=""

  check_auto_connect
  # already auto connect, if still no tbt mode detect, will die
  check_security_mode

  case $SCENARIO in
    adm_topo)
      plug_out_check
      sleep 5
      plug_in_tbt
      sleep 5
      adm_topo_check
      ;;
    adm_approve_all)
      adm_approve_all
      ;;
    adm_devices)
      adm_devices
      ;;
    adm_acl)
      [[ "$SECURITY" == "$none" ]] \
        && skip_test "No need approve in $SECURITY for $SCENARIO, so skip"
      [[ "$SECURITY" == "$dp" ]] \
        && skip_test "No need approve in $SECURITY for $SCENARIO, so skip"
      swcm_file=$(ls /sys/bus/thunderbolt/devices/ | grep ":")
      [[ -n "$swcm_file" ]] \
        && skip_test "It's SW CM mode:$swcm_file, skip adm acl check"
      adm_acl
      ;;
    adm_remove_first)
      adm_remove_first
      ;;
    adm_remove_all)
      adm_remove_all
      ;;
    tbt4_topo)
      enable_authorized
      topo_tbt_show
      ;;
    tbt_stuff)
      enable_authorized
      find_tbt_dev_stuff
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
