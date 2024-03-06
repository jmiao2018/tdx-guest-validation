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
# File:         tpm_func.sh
#
# Description: it's for tpm function test: Return Oriented Programming
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      January 04 2018 - created - Pengfei Xu

# @desc check tpm function
# @returns Fail if return code is non-zero

source "tpm_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-c TEST_CMD][-p parameter][-h]
  -c  Test command need execute
  -p  parameter like ecmd
  -f  filter like fail
  -h  show This
__EOF
}

main() {
  local func_name="tpm"
  local error="error"
  local tpm_path="$(cd $(dirname ${BASH_SOURCE[0]}) > /dev/null 2>&1 && pwd)"

  [ -n "$PARM" ] || die "No parameter for tpm test:$PARM"
  test_print_trc "Test $func_name $PARM, cmd:$CMD_NAME"
  cd "$tpm_path" || test_print_wrg "cd $tpm_path fail"
  case $PARM in
    ecmd)
      com_cmd "$CMD_NAME" "$FILTER" "$func_name" "$error"
      sleep 2
      ;;
    *)
      block_test "Invalid PARM:$PARM"
      ;;
  esac
}

# Default value
: ${FILTER:="fail"}

while getopts :p:c:f:h arg; do
  case $arg in
    p)
      PARM=$OPTARG
      ;;
    c)
      CMD_NAME=$OPTARG
      ;;
    f)
      FILTER=$OPTARG
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
