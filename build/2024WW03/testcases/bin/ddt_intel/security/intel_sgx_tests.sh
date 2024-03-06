#!/usr/bin/env bash
##
## Copyright (c) 2017, Intel Corporation.
##
## This program is free software; you can redistribute it and/or modify it
## under the terms and conditions of the GNU General Public License,
## version 2, as published by the Free Software Foundation.
##
## This program is distributed in the hope it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
## more details.
##

source security_common.sh
source dmesg_functions.sh

usage() {
  cat << _EOF
  usage: ${0##*/}
  -c case id
  -h show help info and exit
_EOF
}

check_sgx_init_pattern() {
  local temp_file

  temp_file="${LOG_PATH}/${TAG}.dmesg"
  dump_dmesg "$temp_file" || die "Fail to get dmesg"

  OIFS="$IFS"
  IFS="|"
  for pattern in $INTEL_SGX_INIT_PATTERNS; do
    test_print_trc "Try to find ($pattern) in dmesg"
    grep -q "$pattern" "$temp_file" || {
      # Remove temp file if test failed in the middle
      # of the test
      rm "$temp_file"
    IFS="$OIFS"
      die "($pattern) not found in dmesg"
    }
    test_print_trc "($pattern) found in dmesg"
  done
  IFS="$OIFS"
}

enclave_create_test() {
  local cmdline
  local output

  # Check whether seaccepttest is available
  which seaccepttest &> /dev/null || die "[seaccepttest] is not available"

  cmdline="seaccepttest -enclave: 4 -count: 10 -pas82 -noCheck"
  # Workaround for whl-u-rvp
  echo "$ENCLAVE_WORKAROUNDED_PLATFORM" | grep -q "$PLATFORM" && cmdline="$cmdline -valid0"
  output=$(eval "$cmdline")

  OIFS="$IFS"
  IFS="|"
  for pattern in $SEACCEPTTEST_CHECKING_PATTERNS; do
    test_print_trc "Try to find ($pattern) in the output"
    echo "$output" | grep -qE "$pattern" || {
      IFS="$OIFS"
      die "($pattern) not found in the output"
    }
    test_print_trc "($pattern) found in the output"
  done
  IFS="$OIFS"
}

enclave_create_test_with_key() {
  local msr_file
  local cmdline
  local cwd

  cwd=$(cd "$(dirname "$0")" && pwd)

  # Check whether msr module is loaded, if not, load it first.
  lsmod | grep -q msr || {
    test_print_trc "msr is not loaded, try to load it first."
    do_cmd "insmod /lib/modules/$(uname -r)/kernel/arch/x86/kernel/msr.ko"
  }

  # Check whether lcp_msr seaccepttest_with_key are available
  which lcp_msr &> /dev/null || \
    die "[lcp_msr] is not available"

  which seaccepttest_with_key &> /dev/null || \
    die "[seaccepttest_with_key] is not available"

  # Check whether msr file is available
  msr_file="$cwd/$MSR_FILE_NAME"
  [[ -e "$msr_file" ]] || block_test "msr file not exists."

  # Write crypto policy
  do_cmd "lcp_msr -w -f $msr_file"

  # Enclave create testing
  output=$(seaccepttest_with_key -kle -in-ker -NoLic -enclave: 4 -count: 2000 -bckgrd: 1000)
  success_ecall_num=$(echo "$output" | \
                      grep "Info: -> Success ecall: [0-9]" | \
                      grep -oE "[0-9]")

  [[ "$success_ecall_num" != "0" ]] || die "Success ecall is: 0, test failed."
}

: ${CASE_ID:=0}

while getopts c:h arg
do
  case $arg in
    c) CASE_ID=$OPTARG ;;
    h) usage && exit 1 ;;
    \?) usage && die "Invalid Option -$OPTARG" ;;
    :) usage && die "Option -$OPTARG requires an argument." ;;
  esac
done

case $CASE_ID in
  0)
    test_print_trc "Checking Intel SGX Init Pattern"
    check_sgx_init_pattern
    ;;
  1)
    test_print_trc "Enclave Create Testing"
    enclave_create_test
    ;;
  2)
    test_print_trc "Enclave Create Testing With Key"
    enclave_create_test_with_key
    ;;
  *)
    block_test "Invalid case id - [$CASE_ID]"
    ;;
esac
