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
# File:         xsave_func.sh
#
# Description: check xsave function works well or not
#
# There are several xsave check tests:
#  avxmdb: XSAVE for fractal calculus(avx2 support)
#  schedcheck: XSAVE area is not modified while scheduling
#  threadcheck_load: XSAVE area while threading test
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      March 17 2018 - created - Pengfei Xu

# @desc check XSAVE function
# @returns Fail if return code is non-zero

source "cpu_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-n BIN_NAME][-p parameter][-h]
  -n  Test cpu bin name like avxmdb and so on
  -p  Test bin file parameter like 1088 and so on
  -h  show This
__EOF
}

xsave_offset_check() {
  local offset_check=""
  local offset_content=""

  offset_check=$(dmesg | grep "xstate_offset\[" | head -n 1)
  if [[ -z "$offset_check" ]]; then
    test_print_trc "No xstate offset to check"
  else
    offset_content=$(dmesg \
                    | grep "xstate_offset\[" \
                    | head -n 1 \
                    | grep 576)
    if [[ -n "$offset_content" ]]; then
      test_print_trc "first xstate_offset is 576, pass:$offset_check"
    else
      die "xstate_offset[2] is not 576:$offset_check"
    fi
  fi
}

main() {
  local func_name="xsave"
  local avx_bin="avxmdb"
  local avx2="avx2"

  case $FUNCTION in
    program)
      test_print_trc "Test $BIN_NAME, parameter: $PARM"
      cpu_info_check "$func_name"

      # Check avx2 support in cpuinfo before test avxmdb
      [[ "$BIN_NAME" == "$avx_bin" ]] && {
        test_print_trc "Check $avx2 before test $avx_bin"
        cpu_info_check "$avx2"
      }
      cpu_func_parm_test "$BIN_NAME" "$PARM" "$func_name"
      ;;
    offset)
      xsave_offset_check
      ;;
    bad_fpu)
      cpu_func_parm_test "$BIN_NAME" "$PARM" "$func_name"
      dmesg_not_contain "Bad FPU"
      ;;
    *)
      usage && exit 1
      ;;
    esac
}

#set the default FUNCTION as program
: ${FUNCTION:="program"}
: ${PARM:="$NULL"}

while getopts :f:n:p:h arg; do
  case $arg in
    f)
      FUNCTION=$OPTARG
      ;;
    n)
      BIN_NAME=$OPTARG
      ;;
    p)
      PARM=$OPTARG
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
