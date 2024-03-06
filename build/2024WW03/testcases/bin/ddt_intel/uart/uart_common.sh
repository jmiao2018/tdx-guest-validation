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
# @desc     Common variables & functions for uart test cases
# @history  2018-11-15: First Version (Ning Han)

SERIAL8250_PATTERN="initcall serial8250_init\+0x0\/0x[0-9a-f]+ returned 0"
SERIAL_PCI_PATTERN="initcall serial_pci_driver_init\+0x0\/0x[0-9a-f]+ returned 0"
SERIAL8250_DW_PATTERN="initcall dw8250_platform_driver_init\+0x0\/0x[0-9a-f]+ \[8250_dw\] returned 0"

SERIAL8250_KCONFIG="CONFIG_SERIAL_8250"
SERIAL8250_DW_KCONFIG="CONFIG_SERIAL_8250_DW"

SERIAL_SYS_CLASS_PATH="/sys/class/tty"
SERIAL_SYS_NODES=(close_delay custom_divisor iomem_base io_type line \
  uartclk xmit_fifo_size closing_wait flags iomem_reg_shift irq port \
  rx_trig_bytes type)

SERIAL8250_DW_MODULE="8250_dw"

UART_BAUDRATE_LIST="0 50 75 110 134 150 200 300 600 1200 1800 2400 4800 9600 \
			19200 38400 57600 115200 230400 460800 500000 576000 921600 \
			1000000 1152000 1500000 2000000 2500000 3000000 3500000 4000000"

check_8250_kconfig() {
  local kconfig_value

  kconfig_value=$(get_kconfig $SERIAL8250_KCONFIG)

  [[ "$kconfig_value" == "y" ]] || \
    block_test "$SERIAL8250_KCONFIG should be set to y."
}

get_valid_ttySNs() {
  local ttySNs
  local nodes

  nodes=$(dmesg | \
    grep -E "ttyS[0-9]{1,}.* is a 16550" | \
    grep -oE "ttyS[0-9]{1,}")

  for ttySN in $nodes; do
    ttySNs="$ttySNs,$ttySN"
  done

  ttySNs=$(tr ',' '\n' <<< "$ttySNs" | sort -u)

  echo "$ttySNs"
}
