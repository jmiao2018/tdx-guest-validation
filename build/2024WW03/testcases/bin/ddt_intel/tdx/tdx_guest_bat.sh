#!/bin/bash
###############################################################################
# Copyright (C) 2023, Intel - http://www.intel.com
#
# SPDX-License-Identifier: GPL-2.0-or-later
###############################################################################

############################ DESCRIPTION ######################################
# @desc     BAT test case logic for TDX guest, covers:
#           1. TDX guest kconfig test
#           3. TDX guest attestation device test
###############################################################################

############################# FUNCTIONS #######################################

usage() {
  cat <<-EOF
  usage: ./${0##*/} [-t CASE to run] [-h Help]
  -t TD_KCONFIG to run
  -h print this usage
EOF
}

################################ DO THE WORK ##################################
source "common.sh"
source "functions.sh"

while getopts :t:h arg; do
  case $arg in
  t)
    TESTCASE=$OPTARG
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
TD_KCONFIG)
  test_print_trc "Start TDX guest kconfig checking:"
  test_kconfigs "y" "CONFIG_INTEL_TDX_GUEST" ||
    die "TDX guest kconfig CONFIG_INTEL_TDX_GUEST is not set to y"
  test_print_trc "TDX guest kconfig test PASS"
  ;;
TD_DRIVER_KCONFIG)
  test_print_trc "Start TDX guest driver kconfig checking:"
  test_kconfigs "y" "CONFIG_TDX_GUEST_DRIVER" || 
    test_kconfigs "m" "CONFIG_TDX_GUEST_DRIVER" ||
    die "TDX guest kconfig CONFIG_INTEL_TDX_GUEST is not set to y"
  test_print_trc "TDX guest driver kconfig test PASS"
  ;;
TD_ATTEST_DEV)
  test_print_trc "Start TDX guest attestation device checking:"
  attest_dev=/dev/tdx_guest
  if [ -c "${attest_dev}" ]; then
    test_print_trc "TDX guest attestation device exists."
  else
    die "TDX guest attestation device $attest_dev doesn't exist."
  fi
  ;;
TD_LAZY_ACCEPT_KCONFIG)
  # TDX guest lazy_accept kconfig test
  test_print_trc "Start TDX guest lazy_accept kconfig checking:"
  test_kconfigs "y" "CONFIG_UNACCEPTED_MEMORY" ||
    die "TDX guest kconfig CONFIG_UNACCEPTED_MEMORY is not set to y"
  test_print_trc "TDX guest lazy_accept kconfig test PASS"
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
