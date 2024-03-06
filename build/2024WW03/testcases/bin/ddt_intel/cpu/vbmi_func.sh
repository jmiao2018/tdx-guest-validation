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
# File:         vbmi_func.sh
#
# Description: it's for vbmi function test, will test vpmultishiftqb and so on
# vbmi instructions:
# * vpmultishiftqb - Select Packed Unaligned Bytes from Quadword Sources
#   This instruction selects eight unaligned bytes from each input qword
#   element of the second source operand (the third operand) and writes eight
#   assembled bytes for each qword element in the destination operand
#   (the first operand).
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      October 23 2017 - created - Pengfei Xu

# @desc check vbmi function
# @returns Fail if return code is non-zero

source "cpu_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-n BIN_NAME][-p parameter][-h]
  -n  Test cpu bin name like vpmadd and so on
  -p  Test bin file parameter like "2 3 b" and so on
  -h  show This
__EOF
}

main() {
  local func_name="vbmi"
  local random_par=""
  local a=""
  local b=""
  local ax=""
  local bx=""
  local times=10
  local t=1

  test_print_trc "Test $BIN_NAME, parameter: $PARM"
  cpu_info_check "$func_name"
  if [ "$PARM" == "random" ]; then
    for((t=1;t<=times;t++)); do
      test_print_trc "******* $t round test:"
      ((a=RANDOM%256))
      ((b=RANDOM%256))
      ax=$(echo "obase=16;$a"|bc)
      bx=$(echo "obase=16;$b"|bc)
      random_par="$ax"' '"$bx"' '"b"
      cpu_func_parm_test "$BIN_NAME" "$random_par" "$func_name"
    done
  else
    cpu_func_parm_test "$BIN_NAME" "$PARM" "$func_name"
  fi
}

while getopts :n:p:h arg; do
  case $arg in
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
