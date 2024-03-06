#!/bin/bash
#
# Copyright 2017 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate raid component
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Ammy Yi <ammy.yi@intel.com>
#
# History:
#             Aug. 2, 2017 - (Ammy Yi)Creation


# @desc This script verify raid test
# @returns Fail the test if return code is non-zero (value set not found)

source "common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-t TEST_ID] [-H]
  -t  test ID
  -H  show this
__EOF
}

cpuinfo_check() {
  grep -q avx /proc/cpuinfo || die "cpuinfo check is failed!"
  return 0
}

raid_check() {
  teardown_handler="raid_teardown"
  raid6test > temp.log &2>1
  grep ERR temp.log && die "raid6test failed!"
  return 0
}

raid_teardown() {
   rm -f temp.log
}

main() {
  case $TEST_ID in
    1)
      cpuinfo_check
      ;;
    2)
      raid_check
      ;;
    *)
      usage
      die "Invalid test ID: $TEST_ID"
      ;;
  esac
}

while getopts :t:H arg; do
  case $arg in
    t)
      TEST_ID=$OPTARG
      ;;
    H)
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

# Call teardown for passing case
exec_teardown
