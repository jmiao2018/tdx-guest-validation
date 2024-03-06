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
# File:         rdpid_func.sh
#
# Description: it's for rdpid function test:
#              Check vgetcpu and vdso getcpu workable and speed
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      October 12 2017 - created - Pengfei Xu

# @desc check rdpid function
# @returns Fail if return code is non-zero

source "cpu_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-n BIN_NAME][-p parameter][-h]
  -n  Test cpu bin name like test_vdso, timing_test and so on
  -p  Test bin file parameter '50M vgetcpu' and so on
  -h  show This
__EOF
}

main() {
  local func_name="rdpid"
  test_print_trc "Test $BIN_NAME, parameter: $UMIP_PARM"
  cpu_info_check "$func_name"
  cpu_func_parm_test "$BIN_NAME" "$UMIP_PARM" "$func_name"
}

while getopts :n:p:h arg; do
  case $arg in
    n)
      BIN_NAME=$OPTARG
      ;;
    p)
      UMIP_PARM=$OPTARG
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
