#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2019, Intel Corporation
#
# Author:
#             Yahui Cheng <yahuix.cheng@intel.com>
#
# History:
#             Dec. 17, 2019 - (Yahui Cheng) Creation

source common.sh
source powermgr_common.sh

LOG_DIR="$LTPROOT"/results
IASL_PATH="$PSTATE_TOOL"/iasl

check_iasl() {
  local iasl_version
  which iasl > /dev/null || block_test "iasl is not found."
  iasl_version=$(iasl -v | grep 'version' | awk -F 'version ' '{print $2}')
  [[ $iasl_version -ge 20191213 ]] || \
    block_test "Please upgrade iasl version to the latest!"
}

check_acpi_tool() {
  which acpidump > /dev/null || block_test "acpidump is not found."
  which acpixtract > /dev/null || block_test "acpixtract is not found."
}

# get the ACPI dump, extract the ASL files(dsdt and ssdt)
extract_asl_file() {
  [[ -d "$IASL_PATH" ]] || mkdir "$IASL_PATH"
  do_cmd "acpidump > $IASL_PATH/acpidump.out"
  cd "$IASL_PATH" || die "IASL path doesn't exist."
  do_cmd "acpixtract acpidump.out"
  do_cmd "iasl *.dat &> /dev/null"
}

# Compile dsdt and all ssdt files in version order
# and output all instances of unresolved ASL objects(Error code is 6164)
# At this point, external-resolution-errors.txt contains all unresolved errors,
# error-out.txt contains other potential errors.
handle_error_info() {
  local ssdts
  local error_content
  ssdts=$(ls -v "$IASL_PATH"/ssdt*.dsl)
  iasl -ve $IASL_PATH/dsdt.dsl $ssdts 2> $IASL_PATH/error-out.txt > /dev/null
  grep -B1 "6164" "error-out.txt" > "$IASL_PATH"/external-resolution-errors.txt
  error_content=$(cat external-resolution-errors.txt)
  [[ ! -s external-resolution-errors.txt ]] || die "$error_content"
  cp error-out.txt "$LOG_DIR"
  cp external-resolution-errors.txt "$LOG_DIR"
  cp acpidump.out "$LOG_DIR"
}

acpi_test_setup() {
  check_iasl
  check_acpi_tool
}

test_acpi_error() {
  extract_asl_file
  handle_error_info
}

acpi_teardown() {
  rm -rf "$IASL_PATH"
}

export teardown_handler="acpi_teardown"

acpi_test_setup
test_acpi_error
exec_teardown
