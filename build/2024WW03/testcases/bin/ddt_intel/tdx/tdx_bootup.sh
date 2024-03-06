#!/bin/bash
###############################################################################
# Copyright (C) 2023, Intel - http://www.intel.com
#
# SPDX-License-Identifier: GPL-2.0-or-later
###############################################################################

############################ DESCRIPTION ######################################
# @desc     TD bootup with different qemu configurations, covers:
#           1. TD bootup with variant CPU, Socket, and Memory configurations
#           3. TD bootup with device filtering mechanism
###############################################################################

############################# FUNCTIONS #######################################

usage() {
  cat <<-EOF
  usage: ./${0##*/} [-t CASE to run] [-h Help]
  -t TD_BOOUP to run
  -h print this usage
EOF
}

################################ DO THE WORK ##################################
source "common.sh"
source "functions.sh"

while getopts :t:c:d:h arg; do
  case $arg in
  t)
    TESTCASE=$OPTARG
    ;;
  c)
    cpu=$OPTARG
    ;;
  d)
    debug_option=$OPTARG
    ;;
  h)
    usage && exit 0
    ;;
  :)
    test_print_err "Must supply an argument to -$OPTARG."
    usage && exit 1
    ;;
  \?)
    test_print_err "Invalid Option -$OPTARG ignored."
    usage && exit 1
    ;;
  esac
done

case $TESTCASE in
TD_BOOUP)
  test_print_trc "TD bootup and start cpu number checking:"
  tdx_flags=$(lscpu | grep "tdx_guest")
  if [ -z "$tdx_flags" ]; then
    die "Not a TD VM."
  else
    test_print_trc "TD bootup PASS."
  fi
  cpu_actual=$(lscpu | grep "CPU(s)" | head -1 | awk {'print $2'})
  if [ $cpu -ne $cpu_actual ]; then
    die "Actual cpu number is not the same as qemu configuration."
  else
    test_print_trc "CPU number checking PASS."
  fi
  test_print_trc "Save full bootup dmesg."
  dmesg
  ;;
DEBUG_OPTION)
  test_print_trc "TD bootup with debug=$debug_option."
  test_print_trc "Save full bootup dmesg."
  dmesg
  ;;
FILTER_PCI)
  test_print_trc "TD bootup with 00:03.0 net device passthrough"
  net_driver=$(lspci -s 00:03.0 -vn | grep "Kernel driver in use" | cut -d ":" -f 2)
  if [ $net_driver == *"igb"* ]; then
    test_print_trc "TD bootup with device allowed in cmdline PASS."
  else
    die "TD bootup with device allowed in cmdline FAIL."
  fi
  test_print_trc "Save full bootup dmesg."
  dmesg
  ;;
FILTER_ACPI)
  test_print_trc "TD bootup with WAET ACPI table allowed"
  if [ -f "/sys/firmware/acpi/tables/WAET" ]; then
    test_print_trc "TD bootup with WAET allowed in cmdline PASS."
  else
    die "TD bootup with WAET allowed in cmdline FAIL."
  fi
  test_print_trc "Save full bootup dmesg."
  dmesg
  ;;
FILTER_DISABLE)
  test_print_trc "TD bootup with filter disabled and check WAET ACPI table"
  if [ -f "/sys/firmware/acpi/tables/WAET" ]; then
    test_print_trc "TD bootup with filter disabled and WAER ACPI exists as expected - PASS."
  else
    die "TD bootup with filter disabled kernel cmdline but failed"
  fi
  test_print_trc "Save full bootup dmesg."
  dmesg
  ;;
FILTER_NEGATIVE)
  test_print_trc "TD bootup with 00:03.0 net device passthrough but not allowed in cmdline"
  net_driver=$(lspci -s 00:03.0 -vn | grep "Kernel driver in use" | cut -d ":" -f 2)
  if [ ! $net_driver == *"igb"* ]; then
    test_print_trc "TD bootup with device not allowed (negative case) in cmdline PASS."
  else
    die "TD bootup with device not allowed in cmdline FAIL."
  fi
  test_print_trc "Save full bootup dmesg."
  dmesg
  ;;
:)
  test_print_err "Must specify the test case option by [-t]"
  usage && exit 1
  ;;
\?)
  test_print_err "Input test case option $TESTCASE is not supported"
  usage && exit 1
  ;;
esac
