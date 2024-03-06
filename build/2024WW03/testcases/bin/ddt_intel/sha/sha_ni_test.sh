#!/bin/bash
#
# Copyright 2018 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate sha_ni
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 1, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Pengfei Xu <pengfei.xu@intel.com>
#
# History:
#             March 7 2018 - (Pengfei Xu)Creation
#
# - Check sha_ni should work in tcrypt SHA1 and SHA256 tests
#
source "sha_common.sh"

usage() {
  cat <<-EOF >&2
  usage: ./${0##*/} [-t SHA_TYPE] [-n SHA_NAME] [-a ACTION] [-h help]
  -t  SHA_TYPE, such as sha_ni
  -n  SHA_NAME like sha1 and sha256
  -a  ACTION, such as test
  -h  show this
EOF
}

shani_main() {
  local type_content=""
  local cpuinfo="/proc/cpuinfo"

  case $ACTION in
    test)
      [[ -z "$SHA_NAME" ]] && block_test "No SHA_NAME:$SHA_NAME"
      [[ -z "$SHA_TYPE" ]] && block_test "No SHA_TYPE:$SHA_TYPE"
      type_content=$(< $cpuinfo grep "$SHA_TYPE")
      [[ -n "$type_content" ]] || block_test "cpu info no $SHA_TYPE"
      test_shani "$SHA_NAME"
      ;;
    *)
      block_test "Invalid ACTION:$ACTION"
      ;;
  esac
}

while getopts :t:n:a:h: arg
do
  case $arg in
      t)
          SHA_TYPE=$OPTARG
          ;;
      n)
          SHA_NAME=$OPTARG
          ;;
      a)
          ACTION=$OPTARG
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

shani_main
