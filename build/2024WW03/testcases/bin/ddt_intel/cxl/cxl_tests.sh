#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Author: Pengfei, Xu <pengfei.xu@intel.com>
# It's for CXL(Compute eXpress Link) tests
#

source "cxl_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-s Scenario][-h]
  -s  Scenario like "cxl_dmesg"
  -h  show This
__EOF
}

main() {
  local cxl_info=" CXL:"
  local cxl_pci="CXL: cap"
  local osc_success="OSC"
  local osc_fail="Failed run OSC"
  local rcec_name="Root Complex Event Collector"
  local aer_name="Advanced Error Reporting"
  local cxl=""
  local mem_cap="mem_cap"
  local hdm1="hdm1"
  local hdm2="hdm2"
  local mem_capable=""
  local hdm_count=""
  local err=0
  local fatal_handle="has been reset"
  local cxl_dev="CXL device"
  local cxl_iso_dport=""

  case $SCENARIO in
    cxl3_pcie_list)
      # Check cxl pcie and cxl3.0 pcie list
      list_cxl_pcie
      if [[ -z "$CXL3_PCIES" ]]; then
        die "No cxl3.0 pcie found in file $CXL3_LIST_FILE:$CXL3_PCIES"
      else
        test_print_trc "Found cxl3.0 PCIe($CXL3_LIST_FILE):$CXL3_PCIES"
      fi
      ;;
    cxl_list_mem)
      local cxl_mem=""

      check_cxl_tool
      cxl_mem=$(cxl list -u)
      if [[ "$cxl_mem" == *"mem"* ]]; then
        test_print_trc "Found cxl attached mem:$cxl_mem"
      else
        die "No cxl attached mem found:$cxl_mem"
      fi
      ;;
    cxl_dmesg)
      cxl_dmesg_check "$cxl_info" \
        || die "There is no cxl info in dmesg"
      ;;
    cxl_lspci)
      cxl_lspci_check || block_test "There is no supported cxl pci in lspci"
      ;;
    cxl_pci_dmesg)
      cxl_dmesg_check "$cxl_pci" \
        || die "There is no cxl pci info in dmesg"
      ;;
    cxl_osc_dmesg)
      cxl_dmesg_check "$osc_fail" && die "There is OSC run failed for cxl"
      cxl_dmesg_check "$osc_success" || die "There is no OSC run for cxl"
      ;;
    kconfig)
      CONFIG_NAME=$(echo "$PARM" | cut -d '=' -f1)
      CONFIG_RESULT=$(echo "$PARM" | cut -d '=' -f2)
      test_any_kconfig_match "$CONFIG_NAME" "$CONFIG_RESULT" || \
        die "None of $CONFIG_NAME matches $CONFIG_RESULT"
      ;;
    cxl_acpi)
      local cxl_list=""
      check_cxl_tool
      cxl_list=$(cxl list -p root -b ACPI.CXL)
      if [[ -z "$cxl_list" ]]; then
        die "No cxl list:$cxl_list in cxl list -p root -b ACPI.CXL"
      else
        test_print_trc "cxl list -p root -b ACPI.CXL:$cxl_list"
      fi
      ;;
    cxl_root)
      local cxl_root=""
      check_cxl_tool

      cxl_root=$(cxl list -d root -u)
      if [[ -z "$cxl_root" ]]; then
        die "No cxl root:$cxl_root in cxl list -d root -u"
      else
        test_print_trc "cxl list -d root -u:$cxl_root"
      fi
      do_cmd "cxl list -v -u"
      [[ -e "$CEDT_PATH" ]] || die "No CEDT path: $CEDT_PATH"
      ;;
    cxl_mailbox)
      local check_mailbox=""

      check_mailbox=$(dmesg | grep -i "cxl" | grep -i "mailbox")
      if [[ -z "$check_mailbox" ]]; then
        die "No cxl mailbox in dmesg:$check_mailbox"
      else
        test_print_trc "Found cxl mailbox in dmesg:$check_mailbox"
      fi
      ;;
    cxl_lspci_rcec)
      cxl_lspci_check || block_test "There is no supported cxl pci in lspci"
      lspci_check "$CXL_PCIS" "$aer_name"
      ;;
    cxl_tool)
      cxl_tool_test "$BIN_NAME" "$PARM" "$FILTER" || \
        die "No $FILTER in $BIN_NAME $PARM test"
      ;;
    cxl_mem_hdm)
      find_cxl_pcie
      cxl_reg_check "pcie_check" "X 0xa 16 0x4" "$mem_cap"
      cxl_reg_check "pcie_check" "X 0xa 8 0x10" "$hdm1"
      cxl_reg_check "pcie_check" "X 0xa 8 0x20" "$hdm2"
      for cxl in $CXLS; do
        mem_capable=""
        hdm_count=""
        cxl_verify "$cxl" "$mem_cap"
        mem_capable="$RESULT"
        cxl_verify "$cxl" "$hdm1"
        hdm_count="$RESULT"
        cxl_verify "$cxl" "$hdm2"
        hdm_count=$((RESULT || hdm_count))
        test_print_trc "mem_capable:$mem_capable, hdm_count:$hdm_count"
        if [[ "$mem_capable" -eq 1 ]]; then
          [[ "$hdm_count" -eq 1 ]] || {
            ((err++))
            test_print_wrg "mem capable but hdm null:$hdm_count"
          }
        else
          [[ "$mem_capable" -eq 0 ]] || {
            test_print_wrg "mem:$mem_capable not 1 or 0"
            ((err++))
          }
          [[ "$hdm_count" -eq 0 ]] || {
            test_print_wrg "No mem, hdm is not null:$hdm_count"
            ((err++))
          }
        fi
      done
      if [[ "$err" -eq 0 ]]; then
        test_print_trc "Check CXL PCIe mem logic passed, err:$err"
      else
        die "Check CXL PCIe mem logic failed, see above, err:$err"
      fi
      ;;
    cxl_rcec)
      cxl_rcec_test "$PARM"
      ;;
    cxl_mem)
      cxl_mem_check "$PARM"
      ;;
    cxl_rcec_handle)
      cxl_rcec_test "$PARM"
      dmesg_check "$fatal_handle" "$CONTAIN"
      ;;
    cxl_driver)
      cxl_driver_test "$BIN_NAME"
      case $FILTER in
        abnormal)
          dmesg_check "error" "$PARM"
          dmesg_check "$cxl_dev" "$CONTAIN"
          ;;
        *)
          dmesg_check "$FILTER" "$PARM"
          ;;
      esac
      ;;
    cxl_mem_dport_isolation)
      check_cxl_mem_dport_isolation
      ;;
    cxl_mem_isolation)
      [[ -z "$CXL_ISO_DPORTS" ]] && check_cxl_mem_dport_isolation
      cxl_iso_dport=""
      for cxl_iso_dport in $CXL_ISO_DPORTS; do
        enable_cxl_mem_isolation "$cxl_iso_dport"
      done
      ;;
    cxl_mem_iso_interrupt)
      [[ -z "$CXL_ISO_DPORTS" ]] && check_cxl_mem_dport_isolation
      cxl_iso_dport=""
      for cxl_iso_dport in $CXL_ISO_DPORTS; do
        enable_cxl_mem_isolation "$cxl_iso_dport"
        enable_cxl_mem_interrupt "$cxl_iso_dport"
      done
      ;;
    dcd_dmesg)
      check_dmesg_keywords "$NULL" "DCD not supported" "cxl"
      check_dmesg_keywords "$NULL" "DCD unsupported" "cxl"
      check_dmesg_keywords "$CONTAIN" "Total dynamic capacity" "cxl"
      ;;
    dcd_region)
      cxl_dcd_region
      ;;
    create_dcd_region)
      create_cxl_dcd_region
      ;;
    cxl_dmesg_check)
      check_dmesg_keywords "$CONTAIN" "$PARM" "$FILTER"
      ;;
    *)
      test_print_wrg "Invalid SCENARIO:$SCENARIO, exit"
      usage && exit 1
      ;;
  esac
}

while getopts :s:b:p:f:h arg; do
  case $arg in
    s)
      SCENARIO=$OPTARG
      ;;
    b)
      BIN_NAME=$OPTARG
      ;;
    p)
      PARM=$OPTARG
      ;;
    f)
      FILTER=$OPTARG
      ;;
    h)
      usage
      exit 0
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
