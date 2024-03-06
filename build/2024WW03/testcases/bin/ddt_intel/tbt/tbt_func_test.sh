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
# File:         tbt_func_test.sh
#
# Description:  tbt connect ssd read write test for Intel thunderbolt test
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      September 4 2017 - created - Pengfei Xu

# @desc test thunderbolt in none/user/secure/dp only mode
# @returns Fail if return code is non-zero

source "tbt_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-s SCENARIO][-t TYPE][-p PARM][-h]
  -s  SCENARIO such as none, user, secure_verify, rw and so on
  -t  Suspend type such as freeze, s2idle, deep
  -d  Device type like 2.0, 3.0, device
  -p  Parm such as tbt, ssd, monitor
  -h  show This
__EOF
}

# Suspend test
# Input $1: suspend_type like freeze s2idle
#       $2: parameter, like tbt, ssd, monitor
# Output: 0 for true, otherwise false or die
suspend_type_test() {
  local suspend_type=$1
  local parm=$2

  check_auto_connect
  case $parm in
    tbt)
      tbt_suspend_test "$suspend_type"
      test_dmesg_check "pcie" "$NULL" "Link Down"
      ;;
    ssd)
      suspend_test "$suspend_type"
      sleep 5
      test_dmesg_check "pcie" "$NULL" "Link Down"
      tbt_ssd_rw_test
      ;;
    monitor)
      tbt_monitor_check
      suspend_test "$suspend_type"
      sleep 35
      tbt_monitor_check
      test_dmesg_check "pcie" "$NULL" "Link Down"
      ;;
    swapoff)
      plug_out_tbt
      tbt_sysfs_info
      swapoff_partition
      test_print_trc "rtcwake -m $suspend_type -s 50"
      rtcwake -m "$suspend_type" -s 50
      # Wait whether there is Link Down event after S4
      sleep 20
      test_dmesg_check "pcie" "$NULL" "Link Down"
      tbt_sysfs_info
      swapon_partition
      ;;
    *)
      die "parm:$parm not support"
      ;;
  esac
}

# Present cfl-s_cnl-h could executed NVM test, other platform will be blocked
# No input
# Output: 0 for true, otherwise block test
check_platform() {
  if [[ "$PLATFORM" == "cfl-s_cnl-h" ]]; then
    test_print_trc "PLATFORM:$PLATFORM"
  else
    block_test "PLATFORM is not cfl-s_cnl-h:$PLATFORM, no need NVM flash test"
  fi
}

main() {
  local zero="zero"
  local nonzero="non-zero"
  local update="update"
  local verify="verify"
  local block_size="1MB"
  local block_count="100"
  local protocol_type=""
  local device_type="flash"

  check_auto_connect
  # already ftdi auto connect, if still no tbt mode detect, will die
  check_security_mode

  case $SCENARIO in
    none)
      if [ "$SECURITY" == "none" ]; then
        none_mode_test
      else
        block_test "It's $SECURITY mode, so block none mode test"
      fi
      ;;
    user)
      if [ "$SECURITY" == "user" ]; then
        enable_authorized
        check_tbt_sysfs
      else
        block_test "It's $SECURITY mode, so block user mode test"
      fi
      ;;
    secure_wrong)
      if [ "$SECURITY" == "secure" ]; then
        wrong_password_test
        check_device_sysfs "$REGEX_ITEM" "$AUTHORIZE_FILE"
      else
        block_test "It's $SECURITY mode, so block secure mode wrong password test"
      fi
      ;;
    secure_verify)
      if [ "$SECURITY" == "secure" ]; then
        secure_mode_test
        check_tbt_sysfs
      else
        block_test "It's $SECURITY mode, so block secure mode verify password test"
      fi
      ;;
    dp)
      if [ "$SECURITY" == "dponly" ]; then
        check_tbt_sysfs
        enable_authorized
        check_tbt_sysfs
      else
        block_test "It's $SECURITY mode, so block dponly mode test"
      fi
      ;;
    monitor_none)
      if [ "$SECURITY" == "none" ]; then
        tbt_monitor_check
        check_authorize "$TBT_MONITOR_FILE" "1"
      else
        block_test "It's $SECURITY mode, so block monitor in none mode test"
      fi
      ;;
    monitor_user)
      if [ "$SECURITY" == "user" ]; then
        tbt_monitor_check
        enable_authorized
        check_authorize "$TBT_MONITOR_FILE" "1"
        check_tbt_sysfs
      else
        block_test "It's $SECURITY mode, so block monitor in user mode test"
      fi
      ;;
    monitor_secure)
      if [ "$SECURITY" == "secure" ]; then
        tbt_monitor_check
        secure_mode_test
        check_authorize "$TBT_MONITOR_FILE" "2"
        check_tbt_sysfs
      else
        block_test "It's $SECURITY mode, so block monitor in secure mode test"
      fi
      ;;
    monitor_dp)
      if [ "$SECURITY" == "dponly" ]; then
        tbt_monitor_check
        check_tbt_sysfs
        enable_authorized
        check_tbt_sysfs
      else
        block_test "It's $SECURITY mode, so block dponly mode test"
      fi
      ;;
    suspend)
      suspend_type_test "$SUSPEND_TYPE" "$PARM"
      ;;
    pmc)
      check_pmc_counter
      suspend_type_test "$SUSPEND_TYPE" "$PARM"
      check_pmc_counter
      if [[ "$PMC_INCREASE_NUM" -gt 0 ]]; then
        test_print_trc "PMC_INCREASE_NUM:$PMC_INCREASE_NUM greater than 0"
      else
        die "PMC_INCREASE_NUM:$PMC_INCREASE_NUM is 0 or less than 0"
      fi
      ;;
    nvm_downgrade)
      check_platform
      tbt_downgrade "$NVM_OLD" "$NVMEM" "$TBT_HOST_PATH"
      ;;
    nvm_upgrade)
      check_platform
      tbt_upgrade "$NVM_NEW" "$NVMEM" "$TBT_HOST_PATH"
      ;;
    ep_downgrade)
      ep_nvm_flash "$EP_OLD"
      ;;
    ep_upgrade)
      ep_nvm_flash "$EP_NEW"
      ;;
    po)
      # po: Plug Out: check all tbt info and status should be as expected
      plug_out_check
      ;;
    upic)
      # upic: User mode Plug In, Check thunderbolt status and info
      if [ "$SECURITY" == "user" ]; then
        authorized_check "$zero"
      else
        block_test "It's $SECURITY mode, so block upic in user mode test"
      fi
      ;;
    upie)
      # upie: User mode Plug In, no approve yet, Error value fill in authorized
      if [ "$SECURITY" == "user" ]; then
        authorized_check "$zero"
        authorized_error
      else
        block_test "It's $SECURITY mode, so block upie in user mode test"
      fi
      ;;
    upiac)
      # upiac: User mode Plug In Access approve and check devices
      if [ "$SECURITY" == "user" ]; then
        user_access_check
      else
        block_test "It's $SECURITY mode, so block upiac in user mode test"
      fi
      ;;
    upiae)
      # upiae: User mode Plug In Access Error value fill in authorized check
      if [ "$SECURITY" == "user" ]; then
        authorized_check "$nonzero"
        authorized_error
      else
        block_test "It's $SECURITY mode, so block upiae in user mode test"
      fi
      ;;
    uvtd)
      # uvtd: User mode VT-d test
      if [[ "$SECURITY" == "user" ]]; then
        vtd_support_check
        if [[ $? -eq 0 ]]; then
          enable_authorized
          check_tbt_sysfs
        else
          block_test "Environment not support VT-d tests"
        fi
      else
       block_test "It's $SECURITY mode, so block upiae in user mode test"
      fi
      ;;
    spic)
      # spic: Secure mode Plug In, Check thunderbolt status and info
      if [ "$SECURITY" == "secure" ]; then
        authorized_check "$zero"
      else
        block_test "It's $SECURITY mode, so block spic in secure mode test"
      fi
      ;;
    spie)
      # spie: Secure mode Plug In, not approved, Error value fill in authorized
      if [ "$SECURITY" == "secure" ]; then
        authorized_check "$zero"
        authorized_error
      else
        block_test "It's $SECURITY mode, so block spie in secure mode test"
      fi
      ;;
    spiaw)
      # spiaw: Secure mode Plug In, Approved without key
      if [ "$SECURITY" == "secure" ]; then
        enable_authorized
        tbt_sysfs_info
        authorized_check "$nonzero"
      else
        block_test "It's $SECURITY mode, so block spiaw in secure mode test"
      fi
      ;;
    spiu)
      # spiu: Secure mode Plug In, Update the key password
      if [ "$SECURITY" == "secure" ]; then
        plug_out_check
        sleep 10
        plug_in_tbt
        sleep 10
        authorized_check "$zero"
        # update the new password in secure mode
        secure_key "$update"
        authorized_check "$nonzero"
      else
        block_test "It's $SECURITY mode, so block spiu in secure mode test"
      fi
      ;;
    spiv)
      # spiav: Secure mode Plug In, Verify saved password works well
      if [ "$SECURITY" == "secure" ]; then
        plug_out_check
        sleep 10
        plug_in_tbt
        sleep 10
        # error password should not successful
        authorized_error
        # verify saved key should successful
        secure_key "$verify"
        authorized_check "$nonzero"
      else
        block_test "It's $SECURITY mode, so block spiv in secure mode test"
      fi
      ;;
    svtd)
      # svtd: Secure mode VT-d test
      if [[ "$SECURITY" == "secure" ]]; then
        vtd_support_check
        if [[ $? -eq 0 ]]; then
          secure_mode_test
          check_tbt_sysfs
        else
          block_test "Environment not support VT-d tests"
        fi
      else
      block_test "It's $SECURITY mode, so block upiae in secure mode test"
      fi
      ;;
    vtd_enable)
      vtd_support_check
      if [[ $? -eq 0 ]]; then
        dmesg_verify "$SCENARIO"
      else
        block_test "VT-d is disabled, could not execute vtd enabled test"
      fi
      ;;
    iommu_verify)
      dmesg_verify "$SCENARIO"
      ;;
    swcm_verify)
      dmesg_verify "$SCENARIO"
      ;;
    loop_transfer)
      loop_transfer_pkg
      ;;
    po_transfer)
      # po_transfer: plug out when ssd/2.0/3.0 transfer file connected with tbt
      po_transfer_file "$PARM" "$DEVICE_TYPE"
      ;;
    poi)
      po_stress_test "$PARM"
      ;;
    usb_check)
      usb_basic_check
      ;;
    usb_po)
      [[ "$SECURITY" == "usbonly" ]] \
        || block_test "It's $SECURITY mode, so block $SCENARIO in usb mode"
      plug_out_check
      ;;
    usb_poi)
      [[ "$SECURITY" == "usbonly" ]] \
        || block_test "It's $SECURITY mode, so block $SCENARIO in usb mode"
      authorized_check "$nonzero"
      ;;
    usb_ahci_ssd)
      [[ "$SECURITY" == "usbonly" ]] \
        || block_test "It's $SECURITY mode, so block $SCENARIO in usb mode"
      find_tbt_ssd
      # In usbonly mode, should reject all tbt ssd connect
      [[ "$?" -ne 0 ]] || die "In usbonly, all tbt ssd should be reject"
      ;;
    usb_2.0_check)
      [[ "$SECURITY" == "usbonly" ]] \
        || block_test "It's $SECURITY mode, so block $SCENARIO in usb mode"
      protocol_type="2.0"
      tbt_transfer "$block_size" "$block_count" "$protocol_type" "$device_type"
      ;;
    usb_3.0_check)
      [[ "$SECURITY" == "usbonly" ]] \
        || block_test "It's $SECURITY mode, so block $SCENARIO in usb mode"
      protocol_type="3.0"
      tbt_transfer "$block_size" "$block_count" "$protocol_type" "$device_type"
      ;;
    usb_freeze)
      [[ "$SECURITY" == "usbonly" ]] \
        || block_test "It's $SECURITY mode, so block $SCENARIO in usb mode"
      SUSPEND_TYPE="freeze"
      PARM="tbt"
      suspend_type_test "$SUSPEND_TYPE" "$PARM"
      ;;
    usb_s3)
      [[ "$SECURITY" == "usbonly" ]] \
        || block_test "It's $SECURITY mode, so block $SCENARIO in usb mode"
      SUSPEND_TYPE="freeze"
      PARM="tbt"
      suspend_type_test "$SUSPEND_TYPE" "$PARM"
      ;;
    usb_s4)
      [[ "$SECURITY" == "usbonly" ]] \
        || block_test "It's $SECURITY mode, so block $SCENARIO in usb mode"
      SUSPEND_TYPE="disk"
      PARM="tbt"
      suspend_type_test "$SUSPEND_TYPE" "$PARM"
      ;;
    nvmem_check)
      tbt_nvmem_check
      ;;
    mrg_sysfs)
      enable_authorized
      find_tbt_mrg
      check_mrg_sysfs "${TBT_MRG}/caps"
      check_mrg_sysfs "${TBT_MRG}/${LANES}"
      check_mrg_sysfs "${TBT_MRG}/${MARGIN}"
      check_mrg_sysfs "${TBT_MRG}/mode"
      check_mrg_sysfs "${TBT_MRG}/test"
      ;;
    mrg_run)
      enable_authorized
      find_tbt_mrg
      run_mrg_sysfs "${TBT_DBG}"
      ;;
    mrg_time)
      enable_authorized
      find_tbt_mrg
      run_mrg_time "${TBT_DBG}"
      ;;
    mrg_random)
      enable_authorized
      find_tbt_mrg
      run_mrg_random "${TBT_DBG}"
      ;;
    plugout_cld)
      plug_out_check
      check_clx "0-1" "CLd"
      ;;
    plugin_cl0)
      plug_in_tbt
      check_clx "auto" "CL0"
      ;;
    *)
      usage && exit 1
      ;;
  esac

  fail_dmesg_check
}

# Default value
: ${SUSPEND_TYPE:="freeze"}
: ${PARM:="tbt"}
: ${DEVICE_TYPE:="device"}

while getopts ':s:t:p:d:h' flag; do
  case ${flag} in
    s)
      SCENARIO=$OPTARG
      ;;
    t)
      SUSPEND_TYPE=$OPTARG
      ;;
    p)
      PARM=$OPTARG
      ;;
    d)
      DEVICE_TYPE=$OPTARG
      ;;
    h)
      usage && exit 0
      ;;
    \?)
      usage
      die "Invalid Option -$OPTARG"
      ;;
    :)
      usage
      die "Option -$OPTARG requires an argument."
      ;;
  esac
done

main
exec_teardown
