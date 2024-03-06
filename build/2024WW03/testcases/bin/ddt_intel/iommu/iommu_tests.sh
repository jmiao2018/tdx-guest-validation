#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Author: Pengfei, Xu <pengfei.xu@intel.com>
# It's for IOMMU(input–output memory management unit) tests
#

source "iommu_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-s Scenario][-h]
  -s  Scenario like "no_pasid"
  -h  show This
__EOF
}

main() {
  local result=""

  case $SCENARIO in
    no_pasid)
      pasid_pcie_check "$NULL"
      result=$?
      [[ "$result" -eq 0 ]] || die "Should not exist PASID pcie"
      ;;
    no_prs)
      prs_check
      result=$?
      if [[ "$result" -eq 0 ]]; then
        die "Should not support PRS"
      elif [[ "$result" -eq 1 ]]; then
        test_print_trc "Could not support PRS as expected"
      else
        block_test "Return unexpected value:$result"
      fi
      ;;
    basic_mmio)
      mmio_test "$PARM"
      ;;
    mmio_support)
      if mmio_support; then
        test_print_trc "MMIO is supported"
      else
        die "MMIO is not supported"
      fi
      ;;
    *)
      usage && exit 1
      ;;
  esac
}

while getopts :s:p:h arg; do
  case $arg in
    s)
      SCENARIO=$OPTARG
      ;;
    p)
      PARM=$OPTARG
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
