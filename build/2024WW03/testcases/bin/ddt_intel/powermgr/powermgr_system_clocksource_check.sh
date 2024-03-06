#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2021 Intel Corporation
# @Author   wendy.wang@intel.com
# @desc     Check system available clock source list

source "powermgr_common.sh"

check_available_clocksource() {

  local tsc_clocksource=""
  local hpet_clocksource=""
  local acpi_pm_clocksource=""

  tsc_clocksource=$(echo "$GET_AVAILABLE_CLOCKSOURCE" | grep "tsc" 2>&1)
  hpet_clocksource=$(echo "$GET_AVAILABLE_CLOCKSOURCE" | grep "hpet" 2>&1)
  acpi_pm_clocksource=$(echo "$GET_AVAILABLE_CLOCKSOURCE" | grep "acpi_pm" 2>&1)

  if [[ -n "$tsc_clocksource" ]]; then
    test_print_trc "system clocksource: tsc is available."
  else
    die "system clocksource: tsc is not available."
  fi

  if [[ -n "$hpet_clocksource" ]]; then
    test_print_trc "system clocksource: hpet is available."
  else
    expected_disable=$(dmesg | grep "HPET dysfunctional in PC10. Force disabled")
    if [[ -n "$expected_disable" ]]; then
      test_print_trc "HPET is disabled by kernel: $expected_disable"
    else
      die "HPET clocksource is not available."
    fi
  fi

  if [[ -n "$acpi_pm_clocksource" ]]; then
    test_print_trc "system clocksource: acpi_pm is available."
  else
    die "system clocksource: acpi_pm is not available."
  fi
}

if [[ ! -f $SYSTEM_CLOCKSOURCE_AVAILABLE_NODE ]]; then
  die "No such file: $SYSTEM_CLOCKSOURCE_AVAILABLE_NODE"
fi

GET_AVAILABLE_CLOCKSOURCE=$(cat "$SYSTEM_CLOCKSOURCE_AVAILABLE_NODE")
test_print_trc \
  "Available system clocksource lists are: $GET_AVAILABLE_CLOCKSOURCE"

check_available_clocksource
