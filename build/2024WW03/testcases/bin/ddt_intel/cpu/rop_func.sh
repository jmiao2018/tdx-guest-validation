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
# File:         rop_func.sh
#
# Description: it's for rop function test: Return Oriented Programming
#
# This function set the Return Oriented, if overflow will return below events:
# * Rets: Counts the number of return instructions
# * Call-ret: Counts the difference between the number of return and call instructions
# * Rets-misp: Counts the number of Mispredicted return instructions
# * Branch-mish: Counts the number  of mispredicted branches
# * Indirect-branch-misp: Counts the number  of mispredicted indirect branch instructions
# * Far-branch: Counts the number of far branches
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      September 18 2017 - created - Pengfei Xu

# @desc check rop function
# @returns Fail if return code is non-zero

source "cpu_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-n BIN_NAME][-p parameter][-h]
  -n  Test cpu bin name like ret_128.bin and so on
  -p  Test bin file parameter like cmd,err_cmd
  -c  Test command need execute
  -f  filter useful result
  -r  Test expected result
  -h  show This
__EOF
}

main() {
  local func_name="rop"
  local fail="fail"
  local error="error"
  local success="success"
  local null="null"

  [[ -n "$PARM" ]] || die "No parameter for ROP test:$PARM"
  [[ -d "$INTEL_BM" ]] || na_test "$INTEL_BM folder is not exist"
  test_print_trc "Test $func_name $PARM, cmd:$CMD_NAME"
  case $PARM in
    ecmd)
      common_cmd "$CMD_NAME" "$FILTER" "$RESULT" "$func_name" "$error"
      sleep 2
      ;;
    err_cmd)
      cpu_cmd_test "$CMD_NAME" "$fail" "$null" "$func_name"
      sleep 2
      ;;
    pass_cmd)
      cpu_cmd_test "$CMD_NAME" "$success" "$null" "$func_name"
      sleep 2
      ;;
    *)
      cpu_func_rop_test "$BIN_NAME" "$PARM" "$RESULT" "$func_name"
      sleep 2
      ;;
  esac
}

while getopts :n:p:c:f:r:h arg; do
  case $arg in
    n)
      BIN_NAME=$OPTARG
      ;;
    p)
      PARM=$OPTARG
      ;;
    c)
      CMD_NAME=$OPTARG
      ;;
    f)
      FILTER=$OPTARG
      ;;
    r)
      RESULT=$OPTARG
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
exec_teardown
