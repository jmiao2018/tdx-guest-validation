#!/bin/bash
###############################################################################
# Copyright (C) 2020, Intel - http://www.intel.com
#
# SPDX-License-Identifier: GPL-2.0-or-later
###############################################################################

############################ DESCRIPTION ######################################
# @desc     This script is based on cpuid_check binary to check all amx/tmul
#           related cpuid, defined in glc-amx-eas-2020-01-08-rev-72.pdf
###############################################################################

############################# FUNCTIONS #######################################
usage() {
  cat <<-EOF
  usage: ./${0##*/} [-t CASE to run] [-h Help]
  -t 1D_0|1D_1|1E_0|D_17|D_18   CASE to run
  -h Help                       print this usage
EOF
}

# Function to get cpuid info of EAX/EBX/ECX/EDX alone based on cpuid_check bin
cpuid_checking() {
  # all cpu leaf number are valid
  local leaf_num=$1
  # subleaf number based on spec
  local subleaf_num=$2
  # section to check: eax, ebx, ecx, edx
  local section_num=$3
  local exx_raw
  case ${section_num} in
    eax)
      exx_raw=$(ddt_intel/cpu/cpuid_check "${leaf_num}" "0x0" "${subleaf_num}" "0x0" | \
        grep "out:" | awk -F, '{print $1}')
      ;;
    ebx)
      exx_raw=$(ddt_intel/cpu/cpuid_check "${leaf_num}" "0x0" "${subleaf_num}" "0x0" | \
        grep "out:" | awk -F, '{print $2}')
      ;;
    ecx)
      exx_raw=$(ddt_intel/cpu/cpuid_check "${leaf_num}" "0x0" "${subleaf_num}" "0x0" | \
        grep "out:" | awk -F, '{print $3}')
      ;;
    edx)
      exx_raw=$(ddt_intel/cpu/cpuid_check "${leaf_num}" "0x0" "${subleaf_num}" "0x0" | \
        grep "out:" | awk -F, '{print $4}')
      ;;
    *)
      die "Out of CPUID section scope, please specify eax, ebx, ecx or edx to check"
      ;;
  esac
  # output exx in fefe1212 format (8 hex digits)
  exx_value=${exx_raw##*=}
}

# Function to do the cpuid checking test based on cpuid_checking() function
do_cpuid_checking() {
  local leaf=$1
  local subleaf=$2
  local section=$3
  local expect_value=$4
  test_print_trc "Start to check CPUID leaf ${leaf} subleaf ${subleaf} section ${section}"
  cpuid_checking ${leaf} ${subleaf} ${section}
  test_print_trc "${section} return value: ${exx_value}"
  test_print_trc "${section} expected value: ${expect_value}"
  [ "${exx_value}" =  "${expect_value}" ] || \
    die "Check FAIL: CPUID leaf ${leaf} subleaf ${subleaf} section ${section}"
  test_print_trc "Above values matched, PASS"
  # reset exx_value for function cpuid_checking
  exx_value="00000000"
}

################################ DO THE WORK ##################################
source "common.sh"
source "functions.sh"
source "tmul_cpuid_common.sh"

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
  1D_0)
    # run CPUID leaf 1D subleaf 0 check, EAX to check
    # check EAX
    do_cpuid_checking 0x1d 0x0 eax ${EAX_1D_0}
    ;;
  1D_1)
    # run CPUID leaf 1D subleaf 1 check, EAX, EBX, ECX to check
    # check EAX
    do_cpuid_checking 0x1d 0x1 eax ${EAX_1D_1}
    # check EBX
    do_cpuid_checking 0x1d 0x1 ebx ${EBX_1D_1}
    # check ECX
    do_cpuid_checking 0x1d 0x1 ecx ${ECX_1D_1}
    ;;
  1E_0)
    # run CPUID leaf 1E subleaf 0 check, EBX to check
    # check EBX
    do_cpuid_checking 0x1e 0x0 ebx ${EBX_1E_0}
    ;;
  D_17)
    # run CPUID leaf D subleaf 17 check, EAX, EBX, ECX to check
    # check EAX
    do_cpuid_checking 0xd 0x11 eax ${EAX_D_17}
    # check EBX
    do_cpuid_checking 0xd 0x11 ebx ${EBX_D_17}
    # check ECX
    do_cpuid_checking 0xd 0x11 ecx ${ECX_D_17}
    ;;
  D_18)
    # run CPUID leaf D subleaf 18 check, EAX, EBX, ECX to check
    # check EAX
    do_cpuid_checking 0xd 0x12 eax ${EAX_D_18}
    # check EBX
    do_cpuid_checking 0xd 0x12 ebx ${EBX_D_18}
    # check ECX
    do_cpuid_checking 0xd 0x12 ecx ${ECX_D_18}
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
