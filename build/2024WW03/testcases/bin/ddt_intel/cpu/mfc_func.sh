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
# File:         mfc_func.sh
#
# Description: it's for most favored core cpu function test.
#
# Each Processor has different "Best Core"(higher performance/ lower voltage)
# than others due to production issue(In-Die Variation naturally produces),
# so we want to use the "Best Core" as "Most favored core" first for
# high load thread.
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      April 18 2018 - created - Pengfei Xu
# History:      July  23 2018 - add rdmsr and function check

# @desc check most favored core function
# @returns Fail if return code is non-zero

source "mfc_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-p parameter][-h]
  -p  Test type like basic
  -h  show This
__EOF
}

main() {
  case $PARM in
    basic)
      favored_core_test
      ;;
    mfc_msr)
      mfc_rdmsr
      ;;
    core_check)
      local n=6
      for ((a=1; a<n; a++)); do
        test_print_trc "mfc core check $a times:"
        mfc_core_check
      done
      ;;
    *)
      usage && exit 1
      ;;
  esac
}

while getopts :p:h arg; do
  case $arg in
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
exec_teardown
