#!/bin/bash
#
# Copyright 2016 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate USB component
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
#             Nov. 25, 2016 - (Ning Han)Creation


# @desc This script verify usb lpm funtion
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

usage() {
  cat << EOF
  usage: ./${0##*/}
    -p  protocol type, such as 2.0 3.0
    -t  device type, such as flash uas
    -b  block size, as parameter pass to dd command
    -c  block count, as parameter pass to dd command
    -H  show this
EOF
}

: ${BLOCK_SIZE:="1MB"}
: ${BLOCK_COUNT:="1"}

while getopts :p:t:b:c:H: arg
do
  case $arg in
    p)
      PROTOCOL_TYPE=$OPTARG
      ;;
    t)
      DEVICE_TYPE=$OPTARG
      ;;
    b)
      BLOCK_SIZE=$OPTARG
      ;;
    c)
      BLOCK_COUNT=$OPTARG
      ;;
    H)
      usage && exit 1
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

if [[ -z "$PROTOCOL_TYPE" || -z "$DEVICE_TYPE" ]]; then
  die "protol type or device type not provided!"
fi

POWER_ATTR_DIR=$(get_power_attrs_dir "$PROTOCOL_TYPE" "$DEVICE_TYPE")
[[ -n "$POWER_ATTR_DIR" ]] || die "fail to get power attributions directory!"
test_print_trc "power attributions directory: $POWER_ATTR_DIR"

POWER_ATTRS=( $POWER_ATTR_DIR/usb3_hardware_lpm_u1 \
              $POWER_ATTR_DIR/usb3_hardware_lpm_u2 )

case $PROTOCOL_TYPE in
  2.0)
    # Check whether power attributions exist. for usb2.0, the
    # power attributions should not exist
    for i in "${POWER_ATTRS[@]}"; do
      [[ -e "$i" ]] && die "it's unreasonable for the existence of $i!"
    done
    exit 0
    ;;
  3.0|3.1|Type-C)
    # Check power attributions value, for usb usb3.0/3.1/Type-C, it's
    # value should be 'enabled'
    for i in "${POWER_ATTRS[@]}"; do
      [[ -e "$i" ]] || die "$i not found!"
      EXPECTED_VAL="enabled"
      [[ "$(cat "$i")" == "$EXPECTED_VAL" ]] || die "$i is not enabled!"
    done
    ;;
esac

USB_DEVICE_NODE=$(find_usb_storage_device "$PROTOCOL_TYPE" "$DEVICE_TYPE")
[[ -n "$USB_DEVICE_NODE" ]] || die "no usb storage device node found!"

which dd &> /dev/null || die "dd is not in current environment!"
# Do basic write test on the usb storage device
do_cmd "dd if=/dev/zero of=$USB_DEVICE_NODE bs=$BLOCK_SIZE count=$BLOCK_COUNT"
