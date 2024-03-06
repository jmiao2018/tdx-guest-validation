#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2020 Intel Corporation
# @Author   Furong Shen <furongx.shen@intel.com>
#           Wendy Wang  <wendy.wang@intel.com>
# @desc     Common file for Intel thermal test

source "common.sh"
MSR_TEMPERATURE_TARGET="0x1a2"
MSR_PACKAGE_THERMAL_STATUS="0x1b1"
THERMAL_PATH="/sys/class/thermal"

# Read value from MSR
# Input:
#     $1: Bit range to be read
#     $2: MSR Address
#     $3: (Optional) Select processor - default 0
# Output:
#   MSR_VAL: Value obtain from MSR
read_msr() {
  local fld=$1
  local reg=$2
  local cpu=$3

  : "${cpu:=0}"

  [[ -z $fld || $fld =~ [0-9]+:[0-9]+ ]] || die "Incorrect field format!"
  [[ -n $reg ]] || die "Unable to read register information"

  MSR_VAL=""
  is_kmodule_builtin msr || {
    load_unload_module.sh -c -d msr || \
      do_cmd "load_unload_module.sh -l -d msr"
  }

  if [[ $fld == "" ]]; then
    MSR_VAL=$(rdmsr -p "$cpu" "$reg")
  else
    MSR_VAL=$(rdmsr -p "$cpu" -f "$fld" "$reg")
  fi

  [[ -n $MSR_VAL ]] || die "Unable to read data from MSR $reg!"
  test_print_trc "Read MSR \"$reg\": value = \"$MSR_VAL\""
}