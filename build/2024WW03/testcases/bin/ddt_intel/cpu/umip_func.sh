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
# File:         umip_func.sh
#
# Description: it's for umip function test, below instructions could be GP or
# UD exception executed.
# There are the instructions covered by UMIP:
# * SGDT - Store Global Descriptor Table
# * SIDT - Store Interrupt Descriptor Table
# * SLDT - Store Local Descriptor Table
# * SMSW - Store Machine Status Word
# * STR  - Store Task Register
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      Aug 7 2017 - created - Pengfei Xu
#               Jun 4 2018 - add umip instruction #GP dmesg check - Pengfei Xu

# @desc check umip function
# @returns Fail if return code is non-zero

source "cpu_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-n BIN_NAME][-p parameter][-h]
  -n  Test cpu bin name like umip_test_basic_64 and so on
  -p  Test bin file parameter like l and so on
  -h  show This
__EOF
}

main() {
  local func_name="umip"
  local config_umip="CONFIG_X86_INTEL_UMIP|CONFIG_X86_UMIP"
  local config_ldt="CONFIG_MODIFY_LDT_SYSCALL"
  local config_y="y"
  local kernel_ver=""
  local ver=""
  local branch=""

  test_print_trc "Test $BIN_NAME, parameter: $UMIP_PARM"
  test_any_kconfig_match "$config_umip" "$config_y" || \
    block_test "None of $config_umip matches $config_y"
  cpu_info_check "$func_name"

  # umip_ldt_16 and umip_ldt_32 need kconfig CONFIG_MODIFY_LDT_SYSCALL=y
  case $BIN_NAME in
    umip_ldt_16)
      test_kconfigs "$config_y" "$config_ldt" \
        || block_test "$config_ldt not set $config_y, block $BIN_NAME test"
      ;;
    umip_ldt_32)
      test_kconfigs "$config_y" "$config_ldt" \
        || block_test "$config_ldt not set $config_y, block $BIN_NAME test"
      ;;
    *)
      test_print_trc "BIN name:$BIN_NAME"
      ;;
  esac

  case $DMESG_CHECK in
    sgdt|sidt|smsw)
      kernel_ver=$(uname -r | cut -d '-' -f 1)
      ver=$(echo "$kernel_ver" | cut -d '.' -f 1)
      branch=$(echo "$kernel_ver" | cut -d '.' -f 2)
      if [[ $ver -lt 5 ]] || [[ $ver -eq 5 && $branch -lt 4 ]]; then
        test_print_trc "Linux kernel version is before v5.4:$kernel_ver"
      else
        test_print_trc "Linux kernel version is after v5.4:$kernel_ver"
        cpu_func_parm_test "$BIN_NAME" "$UMIP_PARM" "$func_name" \
          "$DMESG_CHECK" "$NULL"
        return $?
      fi
      ;;
    sldt|str)
      kernel_ver=$(uname -r | cut -d '-' -f 1)
      ver=$(echo "$kernel_ver" | cut -d '.' -f 1)
      branch=$(echo "$kernel_ver" | cut -d '.' -f 2)
      if [[ $ver -lt 5 ]] || [[ $ver -eq 5 && $branch -lt 10 ]]; then
        test_print_trc "Linux kernel version is before v5.10:$kernel_ver"
      else
        test_print_trc "Linux kernel version is after v5.10:$kernel_ver"
        cpu_func_parm_test "$BIN_NAME" "$UMIP_PARM" "$func_name" \
          "$DMESG_CHECK" "$NULL"
        return $?
      fi
      ;;
    *)
      test_print_trc "-c with parm:$DMESG_CHECK"
      ;;
  esac
  cpu_func_parm_test "$BIN_NAME" "$UMIP_PARM" "$func_name" "$DMESG_CHECK" \
  "$CONTAIN"
}

while getopts :n:p:c:h arg; do
  case $arg in
    n)
      BIN_NAME=$OPTARG
      ;;
    p)
      UMIP_PARM=$OPTARG
      ;;
    c)
      DMESG_CHECK=$OPTARG
      ;;
    h)
      usage
      exit 0
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
