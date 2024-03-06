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
# File:         kl_func.sh
#
# Description:  It's for cpu key lock function test.
#

# @desc verify key locker function
# @returns Fail if return code is non-zero

source "kl_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-n NAME][-f INFO_NAME][-l ITERATION][-p CRYPTO_PARM][-h]
  -n  Test CRYPTO feature name like aes-aeskl,cbc-aes-aeskl
  -f  Test CRYPTO info name like __aes-aeskl,__cbc-aes-aeskl
  -i  iwkey test
  -l  Load and Unload Modules
  -p  Test CRYPTO func test parameter, like "base_ni base_kl"
  -h  show This
__EOF
}

while getopts :n:f:l:p:i:h arg
do
  case $arg in
    n)
      TEST_NAME=$OPTARG
      test_print_trc "Test $TEST_NAME:"
      ;;
    f)
      CRYPTO_FUNC=$OPTARG
      crypto_info_check "$CRYPTO_FUNC"
      ;;
    l)
      LOAD_ITERATION=${OPTARG}
      load_unload_mod $LOAD_ITERATION
      ;;
    p)
      CRYPTO_PARM=$OPTARG
      test_print_trc "Parameter: $CRYPTO_PARM"
      crypto_func_test "$CRYPTO_PARM"
      ;;
    i)
      IWKEY_PARM=$OPTARG
      test_print_trc "Parameter: $IWKEY_PARM"
      iwkey_func_test "$IWKEY_PARM"
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

exec_teardown
