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
# File:         rdt_func.sh
#
# Description:  It's for rdt function test.
#

# @desc verify rdt functions
# @returns Fail if return code is non-zero

source "rdt_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID][-p TEST_PARM][-h]
  -t  TESTCASE_ID
  -p  Test parameters
  -h  show This
__EOF
}

main() {
  case $TESTCASE_ID in
    mba_perthread_enable)
      mba_perthread_enable_check
      ;;
    cache_processes_test)
      cache_processes_test "$TEST_PARM"
      ;;
    *)
      usage
      die "Invalid Test ID!"
      ;;
    esac
  return 0
}

while getopts :t:p:h arg
do
  case $arg in
    t)
      TESTCASE_ID=$OPTARG
      ;;
    p)
      TEST_PARM=$OPTARG
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
