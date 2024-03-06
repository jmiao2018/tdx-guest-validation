#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Author: Pengfei, Xu <pengfei.xu@intel.com>
# It's for RAR(TLB shoot down) function tests
#

source "cpu_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-n BIN_NAME][-s speed|msr][-p parameter][-h]
  -n  Test cpu bin name like test-tlb and so on
  -s  Test speed or msr, like "speed"
  -p  Test bin file parameter like "0x100000000 0x1000 3.4" and so on
  -h  show This
__EOF
}

rar_support() {
  local key_word=$1
  local dmesg_head=""
  local check_log=""

  dmesg_head=$(dmesg | grep "\[    0.000000\]" | head -n 1)
  check_log=$(dmesg | grep "$key_word")
  [[ -n $dmesg_head ]] || {
    [[ -n "$check_log" ]] || {
      test_print_trc "dmesg is not started from 0.000000, unknow RAR status"
      return 0
    }
  }
  if [[ -n "$check_log" ]]; then
    test_print_trc "RAR is supported, dmesg $check_log contains:'$key_word'"
    return 0
  else
    test_print_trc "RAR is not supported, dmesg does not contain:'$key_word'"
    return 1
  fi
}

main() {
  local func_name="rar"
  local parm=""
  local freq=""
  local rar_key="RAR: support"
  local times=100

  rar_support "$rar_key"
  case $SCENARIO in
    speed)
      freq=$(cat /proc/cpuinfo \
            | grep -i ghz \
            | head -n 1 \
            | awk -F " " '{print $NF}' \
            | awk -F "GH" '{print $1}')
      parm="$PARM $freq"
      test_print_trc "Test $BIN_NAME, parameter: $parm"
      cpu_func_parm_test "$BIN_NAME" "$parm" "$func_name"
      ;;
    test)
      test_print_trc "Test $BIN_NAME, parameter: $PARM"
      cpu_func_parm_test "$BIN_NAME" "$PARM" "$func_name"
      ;;
    msr)
      parm=$PARM
      msr_test "$parm" || die "msr test '$PARM' failed"
      ;;
    dmesg)
      full_dmesg_check "$rar_key"
      ;;
    huge_page)
      freq=$(cat /proc/cpuinfo \
            | grep -i ghz \
            | head -n 1 \
            | awk -F " " '{print $NF}' \
            | awk -F "GH" '{print $1}')
      parm="$PARM $freq"
      test_print_trc "Test $BIN_NAME, parameter: $parm"
      do_cmd "echo always > $HP_FILE"
      do_cmd "echo always > $HP_DEFRAG"
      for((i=1;i<=times;i++)); do
        test_print_trc "Huge page tests in $i round:"
        cpu_func_parm_test "$BIN_NAME" "$parm" "$func_name"
      done
      ;;
    s2idle|s3|s4)
      rar_support || block_test "RAR is not supported, block rar sleep test"
      test_print_trc "Before $SCENARIO, tried $BIN_NAME $PARM"
      cpu_func_parm_test "$BIN_NAME" "$PARM" "$func_name"
      suspend_test "$SCENARIO"
      test_print_trc "After $SCENARIO, tried $BIN_NAME $PARM"
      cpu_func_parm_test "$BIN_NAME" "$PARM" "$func_name"
      ;;
    *)
      usage && exit 1
      ;;
  esac
}

while getopts :n:s:p:h arg; do
  case $arg in
    n)
      BIN_NAME=$OPTARG
      ;;
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
exec_teardown
