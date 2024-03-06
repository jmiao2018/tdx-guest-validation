#!/usr/bin/env bash
#
# Copyright (C) 2018 Intel - http://www.intel.com/
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

# This script contains i2c basic acceptance tests

source common.sh
source i2c_common.sh

usage() {
  cat << _EOF
    usage: ${0##*/} [-c CASE_ID]
    -c CASE_ID  specific test case id
    -h          print this message
_EOF

  exit 0
}

check_i2c_character_nodes() {
  local config_value

  config_value=$(get_kconfig "$I2C_CHARACTER_KCONIFG")

  if [ "$config_value" == "y" ]; then
    test_print_trc "$I2C_CHARACTER_KCONIFG has been configured as built-in"
  elif [ "$config_value" == "m" ]; then
    modprobe i2c_dev || die "i2c-dev module load failed!"
  else
    block_test "$I2C_CHARACTER_KCONIFG is not set."
  fi

  i2c_char_dev_nodes=($(ls /dev/i2c-*))
  if [[ "${#i2c_char_dev_nodes[@]}" -eq 0 ]]; then
    die "No i2c character device node found."
  else
    test_print_trc "Found ${#i2c_char_dev_nodes[@]} i2c character device nodes:"
    for node in "${i2c_char_dev_nodes[@]}"; do
      test_print_trc "$node"
    done
  fi
}

CASE_ID=""

while getopts c:h arg; do
  case $arg in
    c) CASE_ID="$OPTARG" ;;
    h) usage ;;
    :) test_print_trc "$0: Must supply an argument to -$OPTARG." && exit 1 ;;
    \?) test_print_trc "Invalid Option -$OPTARG, ignored" && usage && exit 1 ;;
  esac
done

[[ -n "$CASE_ID" ]] || block_test "Invalid case id."

case $CASE_ID in
  check_char_node) check_i2c_character_nodes ;;
  *) block_test "Invalid case id: $CASE_ID" ;;
esac
