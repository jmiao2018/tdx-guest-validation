#!/usr/bin/env bash
#
# Copyright (C) 2019 Intel - http://www.intel.com/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

# This script contains Asymmetric Multi Threading(asmt) basic acceptance tests

source common.sh

usage() {
  cat << _EOF
    usage: ${0##*/} [-c CASE_ID] [-n ASMT_CPU_NUMBER]
    -c CASE_ID  specific test case id
    -n ASMT_CPU_NUMBER  Asymmetric cpu numbers
    -h          print this message
_EOF

  exit 0
}

check_physical_logical_cores() {
  local asmt_core_number=$1
  processors=$(grep -c "processor" /proc/cpuinfo)
  cpu_cores=$(grep "cpu cores" /proc/cpuinfo | cut -f 2 -d ':'| sed 's/ //' | uniq)
  [[ $cpu_cores -gt $asmt_core_number ]] || die "physical cores should be great than asmt cores $cpu_cores,$asmt_core_number"
  [[ $processors -gt $cpu_cores ]] || die "logic cores $processors, physical cores $cpu_cores, asmt number $asmt_core_number"
}

CASE_ID=""
ASMT_NUMBER=0

while getopts c:n:h arg; do
  case $arg in
    c) CASE_ID="$OPTARG" ;;
    n) ASMT_NUMBER=$OPTARG ;;
    h) usage ;;
    :) test_print_trc "$0: Must supply an argument to -$OPTARG." && exit 1 ;;
    \?) test_print_trc "Invalid Option -$OPTARG, ignored" && usage && exit 1 ;;
  esac
done

[[ -n "$CASE_ID" ]] || block_test "Invalid case id."

case $CASE_ID in
  asmt) check_physical_logical_cores "$ASMT_NUMBER" ;;
  *) block_test "Invalid case id: $CASE_ID" ;;
esac
