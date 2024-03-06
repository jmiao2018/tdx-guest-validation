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
# File:         sl_stress.sh
#
# Description:  It's for cpu split lock stress test.
#               Check enabled with root and user mode
#
# Authors:      Tony Zhu - tony.zhu@intel.com
#
# History:      Oct. 20 2018 - created - Tony Zhu

# @desc chec split lock stress
# @returns Fail if return code is non-zero

source "sl_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-a AC][-m MODE][-p Parmater][-h]
  -a  AC: split lock is on=1,off=0
  -m  MODE: user mode or root mode, ltp defalt is root mode
  -p  parameter
  -h  show This
__EOF
}


# Default value
: ${SPLIT_LOCK_AC:="on"}
: ${MODE:="user"}
: ${SL_PARM:="100 80 4096 100"}

while getopts ':a:m:p:h' flag; do
  case ${flag} in
    a)
      SPLIT_LOCK_AC=$OPTARG
      ;;
    m)
      MODE=$OPTARG
      ;;
    p)
      SL_PARM=$OPTARG
      test_print_trc "Parameter: $SL_PARM"
      sl_stress_test "$SL_PARM"
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
