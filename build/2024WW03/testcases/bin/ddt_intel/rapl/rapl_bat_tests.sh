#!/bin/bash

###############################################################################
##                                                                           ##
## Copyright (c) 2017, Intel Corporation.                                    ##
##                                                                           ##
## This program is free software; you can redistribute it and/or modify it   ##
## under the terms and conditions of the GNU General Public License,         ##
## version 2, as published by the Free Software Foundation.                  ##
##                                                                           ##
## This program is distributed in the hope it will be useful, but WITHOUT    ##
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or     ##
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for ##
## more details.                                                             ##
###############################################################################
#
# File:         rapl_bat_tests.sh
#
# Description:  Common file for Intel RAPL Test
#
# Authors:      Jerry C. Wang - jerry.c.wang@intel.com
#
# History:      Aug 01 2017 - Created - Jerry C. Wang
#
#
#
#

source "rapl_common.sh"

usage() {
  cat <<-EOF >&2
  usage: ./${0##*/} [-l iteration] [-i] [-p] [-c] [-g] [-d] [-h]
    -l  Load and Unload Modules
    -i  Check RAPL Interface
    -p  Check RAPL Package Domain
    -c  Check RAPL CPU Domain
    -g  Check RAPL Graphic Domain
    -d  Check RAPL DRAM Domain
    -h  Show this
EOF
  exit 1
}

# RAPL_XS_FUNC_LOAD_UNLOAD_MODULE
rapl_load_unload_module() {
  is_kmodule_builtin "$RAPL_MODULE" && skip_test

  load_unload_module.sh -c -d "$RAPL_MODULE" &&
    load_unload_module.sh -u -d "$RAPL_MODULE"

  for ((i = 0; i < LOAD_ITERATION; i++)); do
    test_print_trc "Loading and Unloading Module #\"$i\"..."
    load_unload_module.sh -l -d "$RAPL_MODULE"
    load_unload_module.sh -u -d "$RAPL_MODULE"
    load_unload_module.sh -l -d "$RAPL_MODULE"
  done
}

# RAPL_XS_FUNC_CHK_INTERFACE
rapl_check_interface() {
  test_print_trc "Check MSR_RAPL_POWER_UNIT..."
  read_msr "" "$MSR_RAPL_POWER_UNIT"

  test_print_trc "Check SYSFS - \"$RAPL_SYSFS_PATH\"intel-rapl..."
  [[ -d "$RAPL_SYSFS_PATH"/intel-rapl ]] ||
    die "Intel-RAPL SYSFS does not exist!"
  lines=$(grep . "$RAPL_SYSFS_PATH"/intel-rapl*/* 2>&1 |
    grep -v "Is a directory" | grep -v "No data available")
  for line in $lines; do
    test_print_trc "$line"
  done
}

# RAPL_XS_FUNC_CHK_PKG_DOMAIN
rapl_check_pkg_domain() {
  test_print_trc "Check MSR_PKG_POWER_LIMIT..."
  read_msr "" "$MSR_PKG_POWER_LIMIT"

  test_print_trc "Check MSR_PKG_ENERGY_STATUS..."
  read_msr "" "$MSR_PKG_ENERGY_STATUS"

  local domain_path="$RAPL_SYSFS_PATH/intel-rapl:"
  test_print_trc "Check SYSFS - \"$domain_path\"X..."

  if is_server_platform; then
    for ((i = 0; i < MAX_PKG_NUM; i++)); do
      for ((j = 0; j < MAX_DIE_NUM; j++)); do
        [[ -d "$domain_path""$i" ]] ||
          die "Intel-RAPL package domain folder does not exist!"
        grep -q "package-${i}-die-${j}" "${domain_path}${i}/name" ||
          test_print_trc "This server does not support package-${i}-die-${j}!"
      done
    done
  else
    for ((i = 0; i < NUM_CPU_PACKAGES; i++)); do
      [[ -d "$domain_path""$i" ]] ||
        die "Intel-RAPL package domain folder does not exist!"
      grep -q "package-${i}" "${domain_path}${i}/name" ||
        die "Intel-RAPL package domain name does not match!"
    done
  fi
  test_print_trc "\"$domain_path\"X existed!"
}

# RAPL_XS_FUNC_CHK_PSYS_DOMAIN
rapl_check_psys_domain() {
  local domain_path="$RAPL_SYSFS_PATH/intel-rapl:"
  test_print_trc "Check Platform domain sysfs - ${domain_path}X..."
  [[ -d "${domain_path}1" ]] ||
    block_test "Intel-RAPL Platform domain folder does not exist!"

  grep -q "psys" "${domain_path}1/name" ||
    na_test "Intel-RAPL Platform domain (aka Psys) does not exit!"
  test_print_trc "${domain_path}1/name psys file exists"
}

# RAPL_XS_FUNC_CHK_PP0_DOMAIN
rapl_check_pp0_domain() {
  test_print_trc "Check MSR_PP0_POWER_LIMIT..."
  read_msr "" "$MSR_PP0_POWER_LIMIT"

  test_print_trc "Check MSR_PP0_ENERGY_STATUS..."
  read_msr "" "$MSR_PP0_ENERGY_STATUS"

  local domain_path="$RAPL_SYSFS_PATH/intel-rapl:"
  test_print_trc "Check SYSFS - \"$domain_path\"X:0..."
  for ((i = 0; i < NUM_CPU_PACKAGES; i++)); do
    [[ -d "$domain_path""$i":0 ]] ||
      block_test "Intel-RAPL CPU domain folder does not exist!"
    grep -q "core" "${domain_path}${i}:0/name" ||
      block_test "Intel-RAPL CPU domain name does not match!"
  done
  test_print_trc "\"$domain_path\"X:0 existed!"
}

# RAPL_XS_FUNC_CHK_PP1_DOMAIN
rapl_check_pp1_domain() {
  test_print_trc "Check MSR_PP1_POWER_LIMIT..."
  read_msr "" "$MSR_PP1_POWER_LIMIT"

  test_print_trc "Check MSR_PP1_ENERGY_STATUS..."
  read_msr "" "$MSR_PP1_ENERGY_STATUS"

  local domain_path="$RAPL_SYSFS_PATH/intel-rapl:"
  test_print_trc "Check SYSFS - \"$domain_path\"X:1..."
  for ((i = 0; i < NUM_CPU_PACKAGES; i++)); do
    [[ -d "$domain_path""$i":1 ]] ||
      block_test "Intel-RAPL Graphic domain folder does not exist!"
    grep -q "uncore" "${domain_path}${i}:1/name" ||
      block_test "Intel-RAPL Graphic domain name does not match!"
  done
  test_print_trc "\"$domain_path\"X:1 existed!"
}

# RAPL_XS_FUNC_CHK_DRAM_DOMAIN
rapl_check_dram_domain() {
  test_print_trc "Check MSR_DRAM_POWER_LIMIT..."
  read_msr "" "$MSR_DRAM_POWER_LIMIT"

  test_print_trc "Check MSR_DRAM_ENERGY_STATUS..."
  read_msr "" "$MSR_DRAM_ENERGY_STATUS"

  domain_name=$(cat /sys/class/powercap/intel-rapl:*/*/name)
  test_print_trc "RAPL Domain name: $domain_name"
  [[ "$domain_name" =~ dram ]] ||
    block_test "intel_rapl DRAM domain folder does not exist!"
  test_print_trc "DRAM domain exists"
}

# RAPL_XS_FUNC_CHK_PKG_ENERGY_STATUS_MSR
rapl_check_pkg_energy_status_msr() {
  local pkg_energy_status_msr

  pkg_energy_status_msr=$(read_msr "" "$MSR_PKG_ENERGY_STATUS")
  test_print_trc "read_msr \"\" $MSR_PKG_ENERGY_STATUS"
  echo "$pkg_energy_status_msr"
  pkg_energy_status_msr=$(echo "$pkg_energy_status_msr" | awk -F"\"" END'{print $4}')
  pkg_energy_status_msr_10=$((16#${pkg_energy_status_msr}))

  if [[ "$pkg_energy_status_msr_10" -eq 0 ]]; then
    die "Your system failed to enable PKG RAPL ENERGY STATUS MSR: 0x611"
  fi
  test_print_trc "Your system enabled PKG RAPL ENERGY STATUS MSR 0x611 \
successfully: $pkg_energy_status_msr"
}

# RAPL_XS_FUNC_CHK_PSYS_ENERGY_STATUS_MSR
rapl_check_psys_domain_msr() {
  local psys_domain_msr

  psys_domain_msr=$(read_msr "31:0" "$MSR_PLATFORM_ENERGY_STATUS")
  test_print_trc "read_msr \"31:0\" $MSR_PLATFORM_ENERGY_STATUS"
  echo "$psys_domain_msr"
  psys_domain_msr=$(echo "$psys_domain_msr" | awk -F"\"" END'{print $4}')
  psys_domain_msr_10=$((16#${psys_domain_msr}))

  if [[ "$psys_domain_msr_10" -eq 0 ]]; then
    die "Your system failed to enable Platform RAPL Domain MSR: 0x64D"
  fi
  test_print_trc "Your system enabled Platform RAPL Domain MSR 0x64D \
successfully: $psys_domain_msr"
}

# RAPL_XS_FUNC_CHK_PKG_POWER_LIMIT_MSR
rapl_check_pkg_power_limit_msr() {
  local pkg_power_limit_msr

  pkg_power_limit_msr=$(read_msr "23:0" "$MSR_PKG_POWER_LIMIT")
  test_print_trc "The Package RAPL POWER LIMIT MSR 0x610 \"23:0\" shows value: $pkg_power_limit_msr"
  pkg_power_limit_msr=$(echo "$pkg_power_limit_msr" | awk -F"\"" END'{print $4}')
  pkg_power_limit_msr_10=$((16#${pkg_power_limit_msr}))

  if [[ "$pkg_power_limit_msr_10" -eq 0 ]]; then
    die "Your system failed to enable PKG RAPL POWER LIMIT MSR: 0x610"
  fi
  test_print_trc "Your system enabled PKG RAPL POWER LIMIT MSR 0x610 \
successfully: $pkg_power_limit_msr"
}

while getopts 'l:ipscgdxyo' flag; do
  case ${flag} in
  l)
    LOAD_ITERATION=${OPTARG}
    rapl_load_unload_module
    ;;
  i)
    rapl_check_interface
    ;;
  p)
    rapl_check_pkg_domain
    ;;
  s)
    rapl_check_psys_domain
    ;;
  c)
    rapl_check_pp0_domain
    ;;
  g)
    rapl_check_pp1_domain
    ;;
  d)
    rapl_check_dram_domain
    ;;
  x)
    rapl_check_pkg_energy_status_msr
    ;;
  y)
    rapl_check_psys_domain_msr
    ;;
  o)
    rapl_check_pkg_power_limit_msr
    ;;
  :)
    die "Option -$OPTARG requires an argument."
    ;;
  \?)
    die "Invalid option: -$OPTARG"
    ;;
  esac
done
