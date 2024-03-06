#!/bin/bash
#
# Copyright 2017 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate i2c component
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
#             Ning Han <ningx.han@intel.com>
#
# History:
#             Aug. 09, 2017 - (Ning Han)Creation

source common.sh

usage() {
  cat << _EOF
    i2c_tests.sh -c <case id> -l <loops> -h
      c: case id
      l: loops
      h: show this
_EOF
}

while getopts c:l:h opt; do
  case $opt in
    h) usage && exit ;;
    c) cid=$OPTARG ;;
    l) loops=$OPTARG ;;
    \?) die "Invalide option: -$OPTARG" ;;
    :) die "Option -$OPTARG requires an argument." ;;
  esac
done

modprobe i2c_dev || die "i2c-dev module load failed!"

case $cid in
  i2c_bus_detect)

    do_cmd "i2cdetect -l"
    ;;
  i2c_detect)
    i2c_bus_numbers=$(get_i2c_test_busses.sh) || die "No I2C buses found!"
    for bus in $i2c_bus_numbers; do
      echo "========= Testing i2c-$bus ... ========="
      i=0
      while (( i < loops )); do
        echo "=== i2cdetect loop $i ==="
        do_cmd i2cdetect -y -r "$bus"
        i=$((i + 1))
      done
    done
    ;;
  functionality)
    i2c_bus_numbers=$(get_i2c_test_busses.sh) || die "No I2C buses found!"
    for bus in $i2c_bus_numbers; do
      echo "========= Testing i2c-$bus ... ========="
      do_cmd "i2cdetect -F $bus"
    done
    ;;
  neg_invalid_addr)
    invalid_addr=$(get_i2c_invalid_addr.sh)
    i2c_bus_num=$(get_i2cbus_number.sh) || die "fail to get i2c bus number!"
    i2c_reg=$(get_i2c_slave_regoffset.sh | cut -d'-' -f1)
    should_fail "i2cget -y $i2c_bus_num $invalid_addr $i2c_reg"
    ;;
  i915_monitor_info)
    do_cmd i2c_setget.sh -d "i915"
    ;;
  *)
    die "Invalid case id: $cid!"
    ;;
esac
