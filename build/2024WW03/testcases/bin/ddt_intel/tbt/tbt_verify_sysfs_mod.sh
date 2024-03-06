#!/bin/bash
#
# Copyright 2017 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate Thunderbolt component
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Pengfei Xu <pengfei.xu@intel.com>
#
# History:
#             August 1 2017 - (Pengfei Xu)Creation
# - Check tbt security mode and sysfsfiles
# - Check tbt mod uninstall and install test

source "tbt_common.sh"

usage()
{
  cat <<__EOF
  usage: ./${0##*/}  [-t SCENARIO][-h]
  -t  scenario: such as config, mod and so on
  -f  files: such as authorized device and so on
  -h  show This
__EOF
}

security_user_test()
{
  check_security_mode
  if [ "$SECURITY" == "user" ]; then
    enable_authorized
  fi
    check_tbt_sysfs || die "Check tbt sysfs file failed"
}

# Verify that tbt driver should initiate after boot up
# Input: NA
# Return 0 for true, otherwise false or die
tbt_boot_init() {
  local tbt_init_info=""
  local tbt_init_time=""
  local dmesg_start=""
  local cmdline_tbt="thunderbolt.dyndbg"
  local check_cmdline=""
  local domain0_folder="/sys/bus/thunderbolt/devices/domain0"

  dmesg_start=$(dmesg | head -n 1 \
                      | awk -F "]" '{print $1}' \
                      | awk -F " " '{print $2}' \
                      | cut -d "." -f 1)
  [[ "$dmesg_start" -eq 0 ]] \
    || skip_test "dmesg start time:$dmesg_start is not 0, skip"

  check_cmdline=$(cat /proc/cmdline | grep "thunderbolt.dyndbg")
  [[ -n "$check_cmdline" ]] \
    || skip_test "cmdline:$check_cmdline didn't contain $cmdline_tbt, skip"

  tbt_init_info=$(dmesg | grep "NHI initialized" | grep thunderbolt | head -n 1)
  if [[ -z "$tbt_init_info" ]]; then
    die "No TBT init info:$tbt_init_info after head and cmdline check passed"
  else
    test_print_trc "Find tbt_init info:$tbt_init_info"
  fi
  tbt_init_time=$(echo "$tbt_init_info" | awk -F "]" '{print $1}' \
                  | awk -F " " '{print $2}' \
                  | cut -d "." -f 1)

  # tbt init time should less than 30s after boot up
  [[ "$tbt_init_time" -lt 30 ]] || \
    die "tbt init time:$tbt_init_time more than 30s"

  [[ -d "$domain0_folder" ]] || \
    die "There is no tbt domain0 folder:$domain0_folder"
}

# Check tbt device id
# Input: NA
# Return 0 for true, otherwise false or die
tbt_device_id() {
  local pcis=""
  local pci=""
  local is_tbt_pci=""
  local pci_device=""
  local tbt_device_num=0
  local pcih=""
  local pcil=""

  pcis=$(lspci | cut -d ' ' -f 1)
  for pci in $pcis; do
    is_tbt_pci=""
    pci_device=""
    pcih=""
    pcil=""
    is_tbt_pci=$(lspci -vv -s "$pci"| grep "$MOD_NAME")
    if [[ -z "$is_tbt_pci" ]]; then
      continue
    else
      TBT_PCIS="$TBT_PCIS $pci"
      tbt_device_num=$((tbt_device_num + 1))
      pcil=$(lspci -xx -s "$pci" | grep "^00: 86" | cut -d " " -f 4 2>/dev/null)
      pcih=$(lspci -xx -s "$pci" | grep "^00: 86" | cut -d " " -f 5 2>/dev/null)
      pci_device="${pcih}${pcil}"
      [[ -n "$pci_device" ]] \
        || test_print_wrg "tbt device id is null->$(lspci | grep "$pci")"

      TBT_DEV_IDS="$TBT_DEV_IDS $pci_device"
      test_print_trc "Found TBT/USB4 PCI:$pci, device_id:$pci_device!"
    fi
  done

  test_print_trc "TBT_PCIS:$TBT_PCIS"
  test_print_trc "TBT_DEV_IDS:$TBT_DEV_IDS"
  if [[ "$tbt_device_num" -eq 0 ]]; then
    die "tbt_device_num is 0, need check dmesg, bios or PF is not supported tbt"
  fi
}

# check tbt PCI device types
# Input: NA
# Return 0 for true, otherwise false or die
tbt_type_check() {
  local tbt_types="tbt_types"
  local tbt_pci=""
  local tbt_id_low=""
  local tbt_id_high=""
  local tbt_pci_id=""
  local tbt_pci_type=""
  local err_num=0

  [[ -n "$TBT_PCIS" ]] || die "There was no TBT PCI in TBT_PCIS:$TBT_PCIS"
  tbt_types=$(which $tbt_types)
  for tbt_pci in $TBT_PCIS; do
    tbt_id_low=$(lspci -s $tbt_pci -xx | grep "00: " | cut -d ' ' -f 4)
    tbt_id_high=$(lspci -s $tbt_pci -xx | grep "00: " | cut -d ' ' -f 5)
    tbt_pci_id="${tbt_id_high}${tbt_id_low}"
    tbt_pci_type=$(cat $tbt_types | grep "$tbt_pci_id" | cut -d ' ' -f 1)
    [[ -n "$tbt_pci_type" ]] || {
      test_print_wrg "There was no tbt pci:$tbt_pci type found:$tbt_pci_type"
      err_num=$((err_num + 1))
    }
    test_print_trc "TBT PCI:$tbt_pci, PCI ID:$tbt_pci_id, type:$tbt_pci_type"
  done

  if [[ "$err_num" -ne 0 ]]; then
    die "TBT type check error num is not 0:$err_num"
  fi
}

# check full dmesg, check tbt is sw cm mode or firmware cm mode
# Input: NA
# Return 0 for true, otherwise false or die
tbt_cm_mode() {
  local sw_cm_info="ICM not supported"
  local dmesg_info=""

  dmesg_info=$(dmesg | grep "\[    0.000000\]" | head -n 1)
  [[ -n "$dmesg_info" ]] \
    || skip_test "dmesg was not started from 0.000000, skip test"
  dmesg_info=$(dmesg | grep "$MOD_NAME")
  [[ -n "$dmesg_info" ]] \
    || die "no $MOD_NAME in dmesg log, please check tbt was enabled in BIOS"
  dmesg_info=$(dmesg | grep "$sw_cm_info")
  if [[ -z "$dmesg_info" ]]; then
    test_print_trc "No '$sw_cm_info' find, it's tbt firmware CM mode"
  else
    test_print_trc "'$dmesg_info' find, it's tbt software CM mode"
  fi
}

main()
{
  check_auto_connect
  case $SCENARIO in
    config)
      config_tbt_check
      ;;
    user)
      security_user_test
      ;;
    mod_net)
      load_unload_mod "$MOD_NET_NAME"
      ;;
    mod)
      # thunderbolt_net driver need unload, other wise thunderbolt driver could
      # not unload due to under used by thunderbolt_net driver
      load_unload_module.sh -u -d "$MOD_NET_NAME"
      sleep 2
      load_unload_mod "$MOD_NAME"
      sleep 2
      load_unload_module.sh -l -d "$MOD_NET_NAME"
      sleep 2
      ;;
    mod_net_time)
      load_unload_mod "$MOD_NET_NAME"
      sleep 10
      mod_time_check "$MOD_NET_NAME"
      ;;
    mod_time)
      load_unload_module.sh -u -d "$MOD_NET_NAME"
      sleep 2
      load_unload_mod "$MOD_NAME"
      sleep 2
      load_unload_module.sh -l -d "$MOD_NET_NAME"
      sleep 10
      mod_time_check "$MOD_NAME"
      ;;
    bios_setting)
      bios_setting_check
      ;;
    item)
      check_device_sysfs "$REGEX_ITEM" "$FILE_NAME"
      ;;
    domain)
      check_device_sysfs "$REGEX_DOMAIN" "$FILE_NAME"
      ;;
    topo)
      topo_tbt_check
      ;;
    dual_domain)
      check_tbt_dir "$DOMAIN0"
      check_tbt_dir "$DOMAIN1"
      ;;
    dual_rp)
      check_tbt_dir "$RP0"
      check_tbt_dir "$RP1"
      ;;
    dual_pci)
      dual_pci_verify
      ;;
    dual_secure)
      dual_secure_verify
      ;;
    device_id)
      tbt_device_id
      ;;
    cm_mode)
      tbt_cm_mode
      ;;
    tbt_type)
      tbt_device_id
      tbt_type_check
      ;;
    boot_init)
      tbt_boot_init
      ;;
    *)
      usage && exit 1
      ;;
  esac

  fail_dmesg_check
}

while getopts ':t:f:h' flag; do
  case ${flag} in
    t)
      SCENARIO="$OPTARG"
      ;;
    f)
      FILE_NAME="$OPTARG"
      ;;
    h)
      usage && exit 0
      ;;
    \?)
      usage && exit 1
      ;;
    :)
      usage && exit 1
      ;;
  esac
done

main
exec_teardown
