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
# File:         tbt_rtd3.sh
#
# Description:  use tbt_rtd3 to check thunderbolt RTD3 functions
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      May 14 2018 - created - Pengfei Xu

# @returns Fail if return code is non-zero

source "tbt_common.sh"

CHECK_TIME=0

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-i CONNECT][-s SCENARIO][-h]
  -c  CONNECT such as 0 for disconnect, 1 for connect
  -s  SCENARIO such as rtd3_init and so on
  -h  show This
__EOF
}

main() {
  check_auto_connect
  get_tbt_pci
  if [[ -z "$TBT_ROOT_PCI" ]]; then
    if [[ "$CHECK_TIME" -eq 0 ]]; then
      CHECK_TIME=1
      check_auto_connect
      find_root_pci
      sleep 2
      plug_out_check
    else
      die "ICL could not find PCI in 2nd time check."
    fi
  fi

  # check_auto_connect
  # already auto connect, if still no tbt mode detect, will die
  # security=$(check_security_mode)
  # [ "$?" -eq 0 ] || die "Detect mode fail, possible no TBT connected!"

  if [[ "$CONNECT" -eq 0 ]]; then
    plug_out_check
  elif [[ "$CONNECT" -eq 1 ]]; then
    check_auto_connect
  else
    block_test "Invalid CONNECT:$CONNECT"
  fi

  case $SCENARIO in
    rtd3_init)
      rtd3_init
      ;;
    rtd3_host_d3)
      rtd3_host_d3 "$TBT_ROOT_PCI"
      ;;
    rtd3_host_busy)
      rtd3_host_busy "$TBT_ROOT_PCI"
      ;;
    rtd3_host_on)
      rtd3_host_on "$TBT_ROOT_PCI"
      ;;
    rtd3_xhci)
      rtd3_xhci "$TBT_ROOT_PCI"
      ;;
    rtd3_host_unload_driver)
      rtd3_host_unload_driver "$TBT_ROOT_PCI"
      ;;
    rtd3_host_load_driver)
      rtd3_host_load_driver "$TBT_ROOT_PCI"
      ;;
    rtd3_host_freeze)
      rtd3_host_sleep "$TBT_ROOT_PCI" "freeze"
      ;;
    rtd3_host_s3)
      rtd3_host_sleep "$TBT_ROOT_PCI" "mem"
      ;;
    rtd3_host_s4)
      rtd3_host_sleep "$TBT_ROOT_PCI" "disk"
      ;;
    rtd3_plugin_host)
      rtd3_plugin_host "$TBT_ROOT_PCI"
      ;;
    rtd3_plugin_ahci)
      rtd3_plugin_ahci "$TBT_ROOT_PCI"
      ;;
    *)
      usage && exit 1
      ;;
  esac
}

while getopts ':c:s:h' flag; do
  case ${flag} in
    c)
      CONNECT=$OPTARG
      ;;
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
