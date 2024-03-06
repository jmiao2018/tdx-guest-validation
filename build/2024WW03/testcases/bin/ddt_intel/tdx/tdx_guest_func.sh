#!/bin/bash
###############################################################################
# Copyright (C) 2021, Intel - http://www.intel.com
#
# SPDX-License-Identifier: GPL-2.0-or-later
###############################################################################

############################ DESCRIPTION ######################################
# @desc     TDX guest functional validation
###############################################################################

source "common.sh"
source "functions.sh"

usage() {
  cat <<-EOF
  usage: ./${0##*/} [-t CASE to run] [-h Help]
  -t COPY_LARGE_FILE | BUILD_KERNEL to run
  -h print this usage
EOF
}

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

attest_result() {
  selftest_item=$1
  test_print_trc "TD attestation - $selftest_item"
  if [ -f "/root/attest.log" ]; then
    rm -rf /root/attest.log
  fi
  tdx_guest_test > /root/attest.log
  results=$(cat /root/attest.log | grep "not ok $selftest_item")
  if [ -z "$results" ]; then
    test_print_trc "TD attestation - $selftest_item PASS."
  else
    die "TD attestation - $selftest_item FAIL."
  fi
}

case $TESTCASE in
LAZY_ACCEPT_VMSTAT)
  test_print_trc "Start TDX guest lazy_accept vmstat checking:"
  stress=$(yum list installed | grep "stress.x86_64" | head -1)
  if [[ -z "$stress" ]]; then
    yum install stress -y
  fi
  bootup_vmstat=$(grep "nr_unaccepted" /proc/vmstat | cut -d' ' -f2)
  nohup stress --vm-bytes $(awk '/MemAvailable/{printf "%d\n", $2;}' </proc/meminfo)k --vm-keep -m 1 &
  # sleep 3s to wait for the vmstat indicator refreshed
  sleep 3
  stress_vmstat=$(grep "nr_unaccepted" /proc/vmstat | cut -d' ' -f2)
  if [[ $bootup_vmstat -gt $stress_vmstat ]]; then
    test_print_trc "TDX guest lazy_accept vmstat test PASS"
  else
    kill $(pidof stress)
    die "TDX guest lazy_accept vmstat test FAILED. Please make sure this TC executed once TDX guest bootup."
  fi
  kill $(pidof stress)
  ;;
LAZY_ACCEPT_MEMINFO)
  test_print_trc "Start TDX guest lazy_accept meminfo checking:"
  vmstat=$(grep "nr_unaccepted" /proc/vmstat | cut -d' ' -f2)
  meminfo=$(awk '/Unaccepted/{printf "%d\n", $2;}' </proc/meminfo)
  echo "vmstat: $vmstat; meminfo= $meminfo"
  if [[ $((vmstat * 4)) -eq $meminfo ]]; then
    test_print_trc "TDX guest lazy_accept meminfo test PASS"
  else
    die "TDX guest lazy_accept meminfo test FAILED."
  fi
  ;;
LAZY_ACCEPT_NEG)
  test_print_trc "Start TDX guest lazy_accept disable checking:"
  vmstat_disable=$(grep "nr_unaccepted" /proc/vmstat | cut -d' ' -f2)
  if [[ ${vmstat_disable} -eq 0 ]]; then
    test_print_trc "TDX guest lazy_accept disable test PASS"
  else
    die "TDX guest lazy_accept meminfo test FAILED with nr_unaccepted: ${vmstat_disable}"
  fi
  test_print_trc "Save full bootup dmesg."
  dmesg
  ;;
EBIZZY_FUNC)
  test_print_trc "Start TDX guest ebizzy test 10s with malloc"
  ebizzy -M
  ebizzy_malloc=$?
  test_print_trc "Start TDX guest ebizzy test 10s with mmap"
  ebizzy -m
  ebizzy_mmap=$?
  if [[ $ebizzy_malloc == 0 && $ebizzy_mmap == 0 ]]; then
    test_print_trc "TDX guest ebizzy test PASS"
  else
    die "TDX guest ebizzy test FAIL"
  fi
  ;;
COPY_LARGE_FILE)
  test_print_trc "Copy large file into TDX guest, under construction."
  test_print_trc "Already automated in XVS."
  ;;
BUILD_KERNEL)
  test_print_trc "Build kernel inside TDX guest, under construction."
  test_print_trc "Already automated in XVS."
  ;;
GET_TDREPORT)
  attest_result "1 global.verify_report"
  ;;
VERIFY_TDREPORT)
  attest_result "2 global.verify_reportmac"
  ;;
EXTEND_RTMR)
  attest_result "3 global.verify_rtmr_extend"
  ;;
GET_TDQUOTE)
  attest_result "4 global.verify_quote"
  ;;
VE_HALT)
  test_print_trc "Start to trigger hlt instruction for #VE handler test."
  test_module_halt=halt_test.ko
  tar -zxvf ddt_intel/tdx/ve_halt_testmodule.tgz --directory ddt_intel/tdx/ || \
    die "Fail to extract ve_halt_testmodule.tgz"
  cd ddt_intel/tdx/ve_halt_testmodule && make all
  [[ $? = 0 ]] || die "Fail to compile #VE handler test module halt_test.ko"
  [[ -f $test_module_halt ]] && insmod $test_module_halt
  [[ $? = 0 ]] || die "Fail to insmod $test_module_halt"
  test_print_trc "$test_module_halt inserted and hlt instruction triggered"
  rmmod $test_module_halt || die "Fail to rmmod $test_module_halt"
  make clean
  dmesg | grep "Complete of hlt instr. test" || \
    die "test module execution not as expected, please check dmesg"
  test_print_trc "Dumping dmesg:"
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
