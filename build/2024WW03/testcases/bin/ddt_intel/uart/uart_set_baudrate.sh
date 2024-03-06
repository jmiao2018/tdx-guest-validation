#!/usr/bin/env bash

###############################################################################
#
# Copyright (C) 2018 Intel - http://www.intel.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
###############################################################################
# @Author   Ning Han (ning.han@intel.com)
# @desc     set uart baudrate.
# @history  2018-11-21: First Version (Ning Han)

source common.sh
source uart_common.sh

uage() {
  cat << _EOF
    usage ${0##*/}
_EOF
}

baudrate_setting_test() {
  local ttySNs
  local valid_items=()
  local invalid_items=()

  ttySNs=$(get_valid_ttySNs)
  [[ -n "$ttySNs" ]] || block_test "No valid tty serial node found."

  for ttySN in $ttySNs; do
    test_print_trc "========check $ttySN========"
    for baudrate in $UART_BAUDRATE_LIST; do
      if uart_tests "/dev/$ttySN" "$baudrate" &> /dev/null; then
        valid_items+=($baudrate)
      else
        invalid_items+=($baudrate)
      fi
    done

    test_print_trc "Valid baudrates: ${valid_items[*]}"
    test_print_trc "Invalid baudrates: ${invalid_items[*]}"

    [[ ${#valid_items[@]} -ne 0 ]] || die "set baudrate for $ttySN failed."
    valid_items=()
    invalid_items=()
  done
}

baudrate_setting_test
