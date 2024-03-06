#!/usr/bin/env bash
###############################################################################
#
# Copyright (C) 2019 Intel - http://www.intel.com
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
# @desc     Uart data transmission test cases.
# @history  2019-01-31: First Version (Ning Han)

source common.sh
source uart_common.sh

usage() {
  cat << _EOF
    usage ${0##*/}
    -i input device.
    -o output device.
    -b baudrate.
    -h show this.
_EOF
}

check_prerequisite() {
  which uart_test.py &> /dev/null || block "uart_test.py not found."
  which python &> /dev/null || block "python not installed."
  python -c "import serial" &> /dev/null || \
          block "Python serial package not installed, try pip install pyserial"
}

: ${UART_INPUT_DEV:="/dev/ttyS0"}
: ${UART_OUTPUT_DEV:="/dev/ttyUSB0"}
: ${UART_BAUDRATE:="115200"}

while getopts "i:o:b:h" opt; do
  case $opt in
    i) UART_INPUT_DEV=$OPTARG ;;
    o) UART_OUTPUT_DEV=$OPTARG ;;
    b) UART_BAUDRATE=$OPTARG ;;
    h) usage ;;
    \?) usage && die "Invalid Option -$OPTARG" ;;
    :) usage && die "Option -$OPTARG requires an argument." ;;
  esac
done

check_prerequisite

uart_test.py -t transmit -i "$UART_INPUT_DEV" -o "$UART_OUTPUT_DEV" -b "$UART_BAUDRATE"
